#!/usr/bin/env python3
"""The phone's Gemma on a local port, so Swift can braid on the Mac.

The Swift side runs the app's own braid code (planner, wonder braid, scrub,
audit) and calls this for every model turn, exactly where the phone calls
MLXLocalTextGenerator. Same weights, same sampling, no thinking channel, and
the worn-image mask the phone applies (the caller sends the masked words).

    ~/ReEnchanted-models/venv/bin/python scripts/braid_lab_server.py --port 8765

POST / {"system", "user", "temperature", "topP", "maxTokens", "maskWords", "maskPairs"}
  -> {"text", "tokens", "finish"}
"""
import argparse, json, os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

MODEL = os.path.expanduser("~/ReEnchanted-models/gemma-4-e2b-it-4bit")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()

    from mlx_lm import load, stream_generate
    from mlx_lm.sample_utils import make_sampler

    model, tokenizer = load(MODEL)

    def single(text):
        ids = tokenizer.encode(text, add_special_tokens=False)
        return ids[0] if len(ids) == 1 else None

    def processor(words, pairs):
        always = [i for i in (single(w) for w in words) if i is not None]
        paired = []
        for after, word in pairs:
            trig = single(after)
            ids = tokenizer.encode(word, add_special_tokens=False)
            if trig is not None and ids:
                paired.append((trig, ids[0]))

        def proc(tokens, logits):
            if always:
                logits[:, always] = -1e9
            if paired and tokens.size:
                last = int(tokens[-1])
                for trig, banned in paired:
                    if last == trig:
                        logits[:, banned] = -1e9
            return logits
        return proc

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            messages = [{"role": "system", "content": body["system"]}, {"role": "user", "content": body["user"]}]
            prompt = tokenizer.apply_chat_template(messages, add_generation_prompt=True, tokenize=False,
                                                   enable_thinking=False)
            words = [w for w in body.get("maskWords", []) if w]
            pairs = [p for p in body.get("maskPairs", []) if len(p) == 2]
            sampler = make_sampler(temp=float(body.get("temperature", 0.7)), top_p=float(body.get("topP", 0.9)))
            text, last = "", None
            for resp in stream_generate(model, tokenizer, prompt, max_tokens=int(body.get("maxTokens", 420)),
                                        sampler=sampler, logits_processors=[processor(words, pairs)]):
                text += resp.text
                last = resp
            out = json.dumps({"text": text.strip(), "tokens": getattr(last, "generation_tokens", None),
                              "finish": getattr(last, "finish_reason", None)}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(out)))
            self.end_headers()
            self.wfile.write(out)

    print(f"braid lab server on :{args.port}", flush=True)
    HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
