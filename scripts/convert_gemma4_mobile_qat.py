#!/usr/bin/env python3
"""Convert Google's mobile QAT Gemma 4 E2B into the MLX checkpoint ReEnchanted hosts.

Source: google/gemma-4-E2B-it-qat-mobile-transformers (quant_method "gemma").
Google stores int2/int4 weights unsigned (value + 2^(b-1)), packed least-significant
bits first into uint8, int8 weights signed, and one float32 scale per output row (per
token and 256-wide layer slice for the PLE table). That is MLX affine quantization with
scale = row scale and bias = -2^(b-1) * scale, and MLX packs LSB-first into little-endian
uint32, so the packed bytes are reused as is: nothing is re-quantized. Scales are stored
as bf16 like every MLX checkpoint (about 0.2% rounding). Static activation scales are
dropped for text layers (Unsloth's llama.cpp measurements, KLD 0.004, also run without
them); for the vision tower they become ClippedLinear bounds, since SRQ clamps to
[-128 s, 127 s]. KV-shared layers' k/v projections and the audio tower are dropped
because the MLX loaders drop them anyway. The config, tokenizer and processor files come
from the MLX checkpoint the app shipped before, so the Swift loaders see the same shape;
the chat template is Google's canonical 2026-07-09 one.

Pipeline (needs ~5 GB free, numpy; `verify` also needs `mlx`):
  scripts/convert_gemma4_mobile_qat.py fetch  WORK
  scripts/convert_gemma4_mobile_qat.py convert WORK
  scripts/convert_gemma4_mobile_qat.py verify  WORK
  scripts/convert_gemma4_mobile_qat.py stage   WORK VERSION
then upload WORK/stage/* to r2://reenchanted-models/gemma-4-e2b-it-qat-mobile-mlx/VERSION/
with `npx wrangler r2 object put ... --remote` from docs/physical-book-backend (files
first with --cache-control "public, max-age=31536000, immutable", manifest.json last),
served at https://models.reenchanted.app/. Wrangler uploads at most 300 MiB per object,
which is why `stage` splits large shards into parts the app joins and re-verifies.
"""
import json, re, struct, sys, os, hashlib, urllib.request, shutil
import numpy as np

SOURCE_REPO = "google/gemma-4-E2B-it-qat-mobile-transformers"
SOURCE_REVISION = "dd693ff40353f057ca5f07e945ad867f4afbf2ec"
SOURCE_SHA256 = "efab429012b97ab986c4d4838a46ff3ad95d618b42ce514771ca40fadc76a9a4"
SHAPE_REPO = "mlx-community/gemma-4-e2b-it-4bit"
SHAPE_REVISION = "238767527555cb75a05732a84dff5d6ba0dd6809"
TEMPLATE_REPO = "google/gemma-4-E2B-it"
TEMPLATE_REVISION = "3e22461f65e89153144f8adb70e3b8c2cc9845a7"
SHARD_BYTES = 240 * 1024 * 1024
PART_BYTES = 256 * 1024 * 1024
UPLOAD_LIMIT = 290 * 1024 * 1024
GROUP = 64


def hf(repo, rev, name, dest):
    urllib.request.urlretrieve(f"https://huggingface.co/{repo}/resolve/{rev}/{name}", dest)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def safetensors_header(path):
    with open(path, "rb") as f:
        n = struct.unpack("<Q", f.read(8))[0]
        h = json.loads(f.read(n))
    h.pop("__metadata__", None)
    return h, 8 + n


def fetch(work):
    src = os.path.join(work, "src"); shape = os.path.join(work, "shape")
    os.makedirs(src, exist_ok=True); os.makedirs(shape, exist_ok=True)
    for name in ["model.safetensors", "config.json"]:
        hf(SOURCE_REPO, SOURCE_REVISION, name, os.path.join(src, name))
    assert sha256_file(os.path.join(src, "model.safetensors")) == SOURCE_SHA256
    for name in ["config.json", "generation_config.json", "processor_config.json", "tokenizer_config.json", "tokenizer.json"]:
        hf(SHAPE_REPO, SHAPE_REVISION, name, os.path.join(shape, name))
    # only the header of the shipped weights is needed, for in_features
    url = f"https://huggingface.co/{SHAPE_REPO}/resolve/{SHAPE_REVISION}/model.safetensors"
    rng = lambda a, b: urllib.request.urlopen(urllib.request.Request(url, headers={"Range": f"bytes={a}-{b}"})).read()
    n = struct.unpack("<Q", rng(0, 7))[0]
    h = json.loads(rng(8, 8 + n - 1)); h.pop("__metadata__", None)
    json.dump({"tensors": h}, open(os.path.join(shape, "weights-header.json"), "w"))
    hf(TEMPLATE_REPO, TEMPLATE_REVISION, "chat_template.jinja", os.path.join(shape, "chat_template.jinja"))


def convert(work):
    SRC = os.path.join(work, "src")
    OUT = os.path.join(work, "out")
    SHIPPED_HEADER = os.path.join(work, "shape", "weights-header.json")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(SRC, "model.safetensors"), "rb") as f:
        n = struct.unpack("<Q", f.read(8))[0]
        header = json.loads(f.read(n))
    data_start = 8 + n
    meta = header.pop("__metadata__", None)
    blob = np.memmap(os.path.join(SRC, "model.safetensors"), dtype=np.uint8, mode="r")
    shipped = json.load(open(SHIPPED_HEADER))["tensors"]
    gconfig = json.load(open(os.path.join(SRC, "config.json")))
    module_bits = gconfig["quantization_config"]["module_quant_configs"]

    DT = {"BF16": np.uint16, "F32": np.float32, "U8": np.uint8, "I8": np.int8, "F16": np.float16}


    def raw(key):
        t = header[key]
        a, b = t["data_offsets"]
        return np.asarray(blob[data_start + a:data_start + b]).view(DT[t["dtype"]]).reshape(t["shape"])


    def to_bf16_bits(x):
        x = np.asarray(x, dtype=np.float32)
        u = np.ascontiguousarray(x).view(np.uint32)
        return ((u + (((u >> 16) & 1) + 0x7FFF)) >> 16).astype(np.uint16).reshape(x.shape)


    def bf16_to_f32(bits):
        return (bits.astype(np.uint32) << 16).view(np.float32)


    def mlx_name(k):
        k = re.sub(r"^model\.language_model\.", "language_model.model.", k)
        k = re.sub(r"^lm_head(?=\.|$)", "language_model.lm_head", k)
        k = re.sub(r"^model\.", "", k)
        return k


    def regex_bits(module):
        # HF matches these patterns in order; the first hit wins.
        for pattern, cfg in module_bits.items():
            if re.search(pattern, module):
                return cfg["num_bits"]
        return gconfig["quantization_config"]["num_bits"]


    out_tensors = []  # (name, dtype_str, shape, bytes)
    overrides = {}
    provenance = {}


    def emit(name, dtype, arr):
        # np.ascontiguousarray promotes 0-d arrays to shape (1,); record the real shape first.
        shape = list(np.shape(arr))
        out_tensors.append((name, dtype, shape, np.ascontiguousarray(arr).tobytes()))


    def quantized(prefix_g, weight_key, scale_key, is_embedding):
        w = raw(weight_key)
        s = raw(scale_key).astype(np.float32)
        rows = w.shape[0]
        module = re.sub(r"^model\.", "", prefix_g)
        if w.dtype == np.int8:
            bits = 8
            q = (w.view(np.uint8) ^ 0x80)  # signed -> unsigned with zero point 128
            width = w.shape[1]
        else:
            # in_features: from the scale layout for embeddings, else from the shipped 4-bit tensor
            mlx_prefix = mlx_name(prefix_g)
            shipped_key = mlx_prefix + ".weight"
            if is_embedding:
                width = {"language_model.model.embed_tokens": 1536,
                         "language_model.model.embed_tokens_per_layer": 35 * 256}[mlx_prefix]
            elif mlx_prefix == "language_model.lm_head":
                width = 1536
            else:
                width = shipped[shipped_key]["shape"][1] * 8  # shipped is 4-bit: 8 values per uint32
            bits = w.shape[1] * 8 // width
            assert bits in (2, 4) and w.shape[1] * 8 == width * bits, (weight_key, w.shape, width)
            q = w
        rb = regex_bits(module)
        assert rb == bits, (weight_key, "regex says", rb, "shape says", bits)
        assert width % GROUP == 0 and (q.shape[1] % 4) == 0, (weight_key, width)
        groups = width // GROUP
        # Row scale -> one scale per group. The PLE table carries one scale per 256-wide layer slice.
        if s.shape[1] == 1:
            g_scale = np.repeat(s, groups, axis=1)
        else:
            per = groups // s.shape[1]
            assert per * s.shape[1] == groups, (scale_key, s.shape, groups)
            g_scale = np.repeat(s, per, axis=1)
        scale_bits = to_bf16_bits(g_scale)
        zp = 2 ** (bits - 1)
        bias_bits = to_bf16_bits(-zp * bf16_to_f32(scale_bits))  # exact: power-of-two multiple
        packed = np.ascontiguousarray(q).view(np.uint32).reshape(rows, -1)
        base = mlx_name(prefix_g)
        emit(base + ".weight", "U32", packed)
        emit(base + ".scales", "BF16", scale_bits)
        emit(base + ".biases", "BF16", bias_bits)
        if bits != 4:
            overrides[base] = {"group_size": GROUP, "bits": bits}
        provenance[base] = {"bits": bits, "in": width, "out": rows}


    skip = re.compile(r"(audio_tower|embed_audio)|\.(input_activation_scale|output_activation_scale|k_cache_scale|v_cache_scale)$")
    kv_shared = re.compile(r"^model\.language_model\.layers\.(\d+)\.self_attn\.(k_proj|v_proj|k_norm)\.")
    first_shared = gconfig["text_config"]["num_hidden_layers"] - gconfig["text_config"]["num_kv_shared_layers"]
    done = set()
    for key in sorted(header):
        if key in done or skip.search(key):
            continue
        m = kv_shared.match(key)
        if m and int(m.group(1)) >= first_shared:
            continue
        if key.endswith(".embedding_quantized"):
            prefix = key.removesuffix(".embedding_quantized")
            quantized(prefix, key, prefix + ".embedding_scale", True)
            done |= {key, prefix + ".embedding_scale"}
            continue
        if key.endswith(".embedding_scale"):
            continue
        if key.endswith(".weight") and (key.removesuffix(".weight") + ".weight_scale") in header:
            prefix = key.removesuffix(".weight")
            quantized(prefix, key, prefix + ".weight_scale", False)
            done |= {key, prefix + ".weight_scale"}
            # Vision tower: static activation ranges become ClippedLinear bounds.
            if ".vision_tower." in "." + key:
                outer = mlx_name(prefix).removesuffix(".linear")
                for side in ("input", "output"):
                    sk = prefix + f".{side}_activation_scale"
                    sv = float(raw(sk).reshape(()))
                    emit(outer + f".{side}_min", "BF16", to_bf16_bits(np.array(-128.0 * sv, dtype=np.float32)))
                    emit(outer + f".{side}_max", "BF16", to_bf16_bits(np.array(127.0 * sv, dtype=np.float32)))
            continue
        if key.endswith(".weight_scale"):
            continue
        # Unquantized tensor: copy, casting stray float32 weights to bf16 like the rest.
        t = header[key]
        arr = raw(key)
        name = mlx_name(key)
        if t["dtype"] == "F32" and (name in shipped and shipped[name]["dtype"] == "BF16" or name == "embed_vision.embedding_projection.weight"):
            emit(name, "BF16", to_bf16_bits(arr))
        else:
            emit(name, t["dtype"], arr)

    # The untied lm_head: if it is byte-identical to embed_tokens, tie it and save the space.
    names = {n: i for i, (n, *_ ) in enumerate(out_tensors)}
    tied = all(out_tensors[names[f"language_model.lm_head.{s}"]][3] == out_tensors[names[f"language_model.model.embed_tokens.{s}"]][3]
               for s in ("weight", "scales", "biases"))
    if tied:
        out_tensors = [t for t in out_tensors if not t[0].startswith("language_model.lm_head.")]
        overrides.pop("language_model.lm_head", None)

    # Shard and write.
    shards, cur, size = [], [], 0
    for t in out_tensors:
        if cur and size + len(t[3]) > SHARD_BYTES:
            shards.append(cur); cur, size = [], 0
        cur.append(t); size += len(t[3])
    if cur:
        shards.append(cur)
    index = {"metadata": {"total_size": sum(len(t[3]) for t in out_tensors)}, "weight_map": {}}
    for i, shard in enumerate(shards):
        fname = f"model-{i + 1:05d}-of-{len(shards):05d}.safetensors"
        hdr, off = {"__metadata__": {"format": "mlx"}}, 0
        for name, dtype, shape, b in shard:
            hdr[name] = {"dtype": dtype, "shape": shape, "data_offsets": [off, off + len(b)]}
            off += len(b)
            index["weight_map"][name] = fname
        hj = json.dumps(hdr, separators=(",", ":")).encode()
        hj += b" " * ((8 - len(hj) % 8) % 8)
        with open(os.path.join(OUT, fname), "wb") as f:
            f.write(struct.pack("<Q", len(hj))); f.write(hj)
            for *_, b in shard:
                f.write(b)
    json.dump(index, open(os.path.join(OUT, "model.safetensors.index.json"), "w"), indent=2, sort_keys=True)
    json.dump({"tied_lm_head": tied, "overrides": overrides, "modules": provenance},
              open(os.path.join(OUT, "conversion-report.json"), "w"), indent=1, sort_keys=True)
    print("tensors", len(out_tensors), "shards", len(shards), "bytes", index["metadata"]["total_size"], "tied lm_head", tied,
          "overrides", len(overrides))

def finish(work):
    """Config, tokenizer and processor files: the shipped MLX shape plus our overrides."""
    out = os.path.join(work, "out"); shape = os.path.join(work, "shape")
    sc = json.load(open(os.path.join(shape, "config.json")))
    rep = json.load(open(os.path.join(out, "conversion-report.json")))
    gc = json.load(open(os.path.join(work, "src", "config.json")))
    q = {"group_size": GROUP, "bits": 4, "mode": "affine"}; q.update(rep["overrides"])
    sc["quantization"] = q; sc["quantization_config"] = dict(q)
    sc["vision_config"]["use_clipped_linears"] = True
    assert sc["tie_word_embeddings"] is True and rep["tied_lm_head"]
    diff = {k for k in set(gc["text_config"]) | set(sc["text_config"])
            if gc["text_config"].get(k) != sc["text_config"].get(k) and k != "tie_word_embeddings"}
    assert not diff, diff
    json.dump(sc, open(os.path.join(out, "config.json"), "w"), indent=2)
    for name in ["generation_config.json", "processor_config.json", "tokenizer_config.json", "tokenizer.json", "chat_template.jinja"]:
        shutil.copy(os.path.join(shape, name), os.path.join(out, name))


def verify(work):
    """Every sampled module dequantizes (in float32) exactly to Google's ints times the bf16 scale."""
    import mlx.core as mx
    src = os.path.join(work, "src", "model.safetensors"); out = os.path.join(work, "out")
    H, ds = safetensors_header(src)
    blob = np.memmap(src, dtype=np.uint8, mode="r")
    DT = {"BF16": np.uint16, "F32": np.float32, "U8": np.uint8, "I8": np.int8}
    graw = lambda k: np.asarray(blob[ds + H[k]["data_offsets"][0]:ds + H[k]["data_offsets"][1]]).view(DT[H[k]["dtype"]]).reshape(H[k]["shape"])
    def unpack(p, bits):  # transformers/integrations/gemma_quant.py
        p = p.astype(np.uint8)
        if bits == 4:
            v = np.stack([(p & 0x0F).astype(np.int16) - 8, (p >> 4).astype(np.int16) - 8], -1)
        else:
            v = np.stack([((p >> (2 * i)) & 3).astype(np.int16) - 2 for i in range(4)], -1)
        return v.reshape(p.shape[0], -1)
    idx = json.load(open(os.path.join(out, "model.safetensors.index.json")))["weight_map"]
    rep = json.load(open(os.path.join(out, "conversion-report.json")))["modules"]
    loaded = {}
    rng = np.random.default_rng(0); ok = True
    for mname, info in sorted(rep.items()):
        if mname + ".weight" not in idx:
            continue  # the lm_head, tied to embed_tokens and not written separately
        gprefix = "model." + mname.replace("language_model.model.", "language_model.") if not mname.startswith("language_model.lm_head") else "lm_head"
        emb = mname.endswith(("embed_tokens", "embed_tokens_per_layer"))
        gw = graw(gprefix + (".embedding_quantized" if emb else ".weight"))
        gs = graw(gprefix + (".embedding_scale" if emb else ".weight_scale")).astype(np.float32)
        rows = np.sort(rng.choice(gw.shape[0], size=min(8, gw.shape[0]), replace=False))
        ints = gw[rows].astype(np.int16) if gw.dtype == np.int8 else unpack(gw[rows], info["bits"])
        srow = np.repeat(gs[rows], ints.shape[1] // gs.shape[1], axis=1)
        u = np.ascontiguousarray(srow).view(np.uint32); u = ((u + (((u >> 16) & 1) + 0x7FFF)) >> 16) << 16
        ref = (ints * u.view(np.float32)).astype(np.float32)
        for suffix in (".weight", ".scales", ".biases"):
            shard = idx[mname + suffix]
            if shard not in loaded:
                loaded[shard] = mx.load(os.path.join(out, shard))
        W, S, B = (loaded[idx[mname + s]][mname + s] for s in (".weight", ".scales", ".biases"))
        r = mx.array(rows)
        deq = np.array(mx.dequantize(W[r], S[r].astype(mx.float32), B[r].astype(mx.float32), group_size=GROUP, bits=info["bits"]))
        if not np.array_equal(deq, ref):
            ok = False; print("MISMATCH", mname)
    print("verified", len(rep), "quantized modules:", "ALL EXACT" if ok else "FAILED")
    return ok


def stage(work, version):
    out = os.path.join(work, "out"); st = os.path.join(work, "stage")
    shutil.rmtree(st, ignore_errors=True); os.makedirs(st)
    names = ["config.json", "generation_config.json", "tokenizer.json", "tokenizer_config.json", "chat_template.jinja",
             "processor_config.json", "model.safetensors.index.json"] + sorted(f for f in os.listdir(out) if f.endswith(".safetensors"))
    entries = []
    for name in names:
        path = os.path.join(out, name); size = os.path.getsize(path)
        entry = {"path": name, "size": size, "sha256": sha256_file(path)}
        if size > UPLOAD_LIMIT:
            parts = []
            with open(path, "rb") as f:
                for i, chunk in enumerate(iter(lambda: f.read(PART_BYTES), b""), start=1):
                    pname = f"{name}.part{i:02d}"
                    open(os.path.join(st, pname), "wb").write(chunk)
                    parts.append({"path": pname, "size": len(chunk), "sha256": hashlib.sha256(chunk).hexdigest()})
            entry["parts"] = parts
        else:
            os.link(path, os.path.join(st, name))
        entries.append(entry)
    manifest = {"schema": 1, "id": "reenchanted/gemma-4-e2b-it-qat-mobile-mlx", "version": version,
                "source": {"repo": SOURCE_REPO, "revision": SOURCE_REVISION, "model_safetensors_sha256": SOURCE_SHA256,
                           "chat_template": f"{TEMPLATE_REPO}@{TEMPLATE_REVISION}", "config_base": f"{SHAPE_REPO}@{SHAPE_REVISION}"},
                "license": "Gemma 4 (Apache 2.0): https://ai.google.dev/gemma/docs/gemma_4_license",
                "files": entries}
    json.dump(manifest, open(os.path.join(st, "manifest.json"), "w"), indent=1)
    print("staged", len(entries), "files,", sum(e["size"] for e in entries), "bytes")


if __name__ == "__main__":
    cmd, work = sys.argv[1], sys.argv[2]
    if cmd == "fetch":
        fetch(work)
    elif cmd == "convert":
        convert(work); finish(work)
    elif cmd == "verify":
        sys.exit(0 if verify(work) else 1)
    elif cmd == "stage":
        stage(work, sys.argv[3])
    else:
        sys.exit(__doc__)
