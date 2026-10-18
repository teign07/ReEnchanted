# Our iPad: Gemma install test crash

Investigated October 12, 2026. Device: Our iPad, ninth-generation iPad,
`iPad12,2`, running iPadOS 26.3.1. The downloaded model is the intended compact
checkpoint, `mlx-community/gemma-3-1b-it-4bit`; the device file inventory shows
its 698.6 MB weights and tokenizer/configuration files, without an active marker.

The app reports from 10:46 and 11:08 both show `EXC_BREAKPOINT / SIGTRAP`, through
`ErrorHandler.dispatch`, `mlx_async_eval`, and `Gemma3TextModel.prepare` during
prefill. Each failure coincides with multiple `MTLCompilerService` crashes. The
paired 11:08 Metal report shows an LLVM backend fatal error during instruction
emission, in the Book's process coalition. These are compiler/evaluation failures;
the retrieved reports do not identify a jetsam memory termination.

Apple's Metal feature table identifies A13 as Apple6 and places SIMD matrix
multiply and SIMD reduction support at Apple7 (A14/M1). The pinned MLX Metal
quantized kernels use these operations. This is a supported compatibility
explanation for the observed compiler failures; the exact compiler message was
not available in the crash reports. Device unified-log collection requires a
system password, so that message has not been retrieved.

The source changes select MLX CPU execution and the compact model when
`MTLDevice.supportsFamily(.apple7)` is false. Installation and subsequent text
generation share that device policy. Direct vision remains disabled on that
path. CPU text prefill uses smaller chunks. A scoped MLX error handler converts
reported MLX failures to Swift errors rather than the library's default fatal
assertion. The install test also uses the ordinary inference gate, with the
downloaded directory supplied explicitly because activation has not happened yet.
Vision validation now follows the device's actual vision eligibility.

Verification so far: Swift frontend syntax parsing and `git diff --check` passed.
No build, installation, or post-change device generation was performed, following
the user's instruction not to build without being asked. CPU correctness,
latency, and memory use on this iPad remain unverified.

Next device gate, after a build is requested: install the updated app while
preserving onboarding data, complete the Welcome brain test, confirm activation,
generate a real text reply, and inspect fresh reports and memory logs. Expect
slower writing on CPU; do not describe the crash as fixed on-device until that
gate passes.

Reference: [Apple Metal Feature Set Tables](https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf).
