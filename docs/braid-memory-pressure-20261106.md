# Rabbit braid memory termination, November 6, 2026

Rabbit's retrieved `JetsamEvent-2026-11-06-174129.ips` and
`JetsamEvent-2026-11-06-180411.ips` identify `InsideCoverApp`, active and
frontmost, as a `per-process-limit` victim. With 16,384-byte pages, their
reported footprints were 4,097.28 MiB and 4,097.78 MiB. The reader reported
that no writing had appeared. The later 18:05 report did not contain the app.

The victim UUID, `82C3968A-BF14-3C6E-96D1-54C8B09196B5`, matches the local
Debug app dated November 6 at 17:05. Its signed increased-memory entitlement
is present. The pinned MLX runtime and cold-admission constants predate this
regression; they did not change in the last two days. Neither the jetsam
reports nor the absence of visible text identifies the exact allocation or
regressing commit. Device unified-log collection required administrator
access and was not available. Raw reports remain in `/private/tmp/braid-JetsamEvent-2026-11-06-*.ips`.

## Source repair

- Own the inference gate before any suspension, admission, or cache mutation.
  Previously a concurrent caller could unload a running model before the
  eventual busy check. Schedule eviction before relinquishing the gate, so
  delayed cleanup cannot evict a subsequent run's warm model.
- Measure admission after the writing UI appears. Use the current reading
  after reclamation, including a decrease. On iOS, zero available bytes means
  exhaustion, not permission to use a 4 GiB fallback.
- Release the cache's strong model reference before clearing MLX's buffer
  pool. Try reclaiming app buffers before discarding a reusable warm model.
- On the existing iPhone 15-class path, prefill uses 64-token chunks and waits
  for each submitted chunk on its MLX stream. This bounds queued temporary
  work without reducing prompt material or the existing output limits. It
  may trade some prefill throughput for lower peak memory; latency is unmeasured.
- Check memory after model load, before prefill, after every prefill chunk,
  and per generated token. Cancel the producer task on pressure, then clear
  the session and unload the model through the normal error path. A latched
  pressure stop prevents cleanup from turning a partial reply into success.
- A terminal native memory/foreground refusal ends the braid instead of
  repeatedly attempting the same allocation. Busy requests still wait.

The 320 MiB prefill admission reserve retains the existing warm-admission
threshold. The 192 MiB in-flight stop reserve is provisional headroom for
already-submitted work to drain. These are cooperative safeguards, not a
guarantee against an individual allocation spike during model loading or
kernel evaluation. The initial allocation responsible for this regression
remains unisolated.

## Validation

Swift syntax parsing and `git diff --check` passed. The edited native cache,
gate, memory guard, install validator, and generation lifecycle were also
typechecked for iOS against the existing pinned MLX modules, with app-service
stubs; no executable or app was built. Six regression tests cover memory
thresholds, zero allowance, sticky interruption across cleanup, a fresh run,
and terminal braid refusal without retries. They were added but not run,
because running the updated Swift tests would require a build.

The remaining device check is a real braid from the same kept material,
including warm follow-up paragraphs and retry after a graceful refusal.
Compare model-load, prefill, first-text, floor, and release checkpoints;
inspect fresh jetsam reports and responsiveness while writing. A successful
build or launch alone will not establish that this crash or smoothness
regression is resolved.
