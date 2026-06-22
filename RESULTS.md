# Real-World Results — Local LLM on ZimaBlade 7700

> Measured on actual hardware. Numbers here replace the estimates in
> [`APPROACH.md`](APPROACH.md). Only measured values are recorded; anything
> not yet tested is marked **pending**.

## Test rig

- **Host:** ZimaBlade 7700 (Intel Apollo Lake, no AVX/AVX2, no GPU, 16 GB RAM)
- **Runtime:** Ollama (CPU runner)

## Benchmarks

### Phi-2 (`phi:2.7b`) — fallback model ✅ tested

Prompt: `"Write a 200 word essay about energy efficiency"` (run with `ollama run phi:2.7b --verbose`)

| Metric | Value |
|--------|-------|
| **Generation rate (eval)** | **2.69 tok/s** |
| Prompt eval rate | 5.13 tok/s |
| Eval count | 566 tokens |
| Eval duration | 3m 30.4s |
| Prompt eval count | 42 tokens |
| Prompt eval duration | 8.19s |
| Load duration | 209 ms (model already warm — *not* cold start) |
| Total duration | 3m 39.3s |

**Quality:** Output was coherent, fluent, and on-topic — a usable 200-word
essay plus follow-up Q&A. Instruction-following held up.

**vs. estimate:** APPROACH.md estimated 1.5–4.5 tok/s for Phi-2. Measured
2.69 tok/s lands squarely in range — the estimate was sound.

**Decision gate:** 2.69 tok/s is in the `> 2` band → **keep this model.**

### Gemma 4 E2B (`gemma4:e2b`) — 2B variant ✅ tested

Prompt: `"Write a 200 word essay about energy efficiency"` (run with `ollama run gemma4:e2b --verbose`)

| Metric | Value |
|--------|-------|
| **Generation rate (eval)** | **1.91 tok/s** |
| Prompt eval rate | 3.40 tok/s |
| Eval count | 549 tokens |
| Eval duration | 4m 47.9s |
| Prompt eval count | 27 tokens |
| Prompt eval duration | 7.94s |
| Load duration | 21.1s (cold load from eMMC) |
| Total duration | 5m 18.7s |

**Quality:** Noticeably better than Phi-2. The model ran a visible
reasoning/"Thinking..." phase before answering and produced a tighter,
better-structured essay. The reasoning phase does burn extra tokens/time.

**Decision gate:** 1.91 tok/s is in the `1–2` band → "try, but fallback
recommended." Slower than Phi-2 but higher output quality.

**Note:** This is the **E2B** (2B) variant, not the primary E4B candidate.
E4B will be slower still — treat 1.91 tok/s as an upper bound for E4B.

### Gemma 4 E4B (`gemma4:e4b`) — primary candidate ⏳ pending

Not yet benchmarked on hardware. Expect below E2B's 1.91 tok/s.

## Speed vs. quality (measured)

| Model | tok/s | Quality | Cold load | Gate |
|-------|-------|---------|-----------|------|
| Phi-2 `phi:2.7b` | 2.69 | good | (warm) | keep |
| Gemma 4 E2B `gemma4:e2b` | 1.91 | better (reasons first) | 21.1s | try/fallback |

For unattended monthly batch extraction, both are workable; Gemma 4 E2B's
higher quality likely wins for accuracy-sensitive field extraction despite
being ~30% slower.

## Open items still pending

- [ ] Benchmark Gemma 4 E4B on the ZimaBlade (does it fit/run in 16 GB? tok/s?)
- [x] Measure cold-load latency — Gemma 4 E2B loaded from eMMC in **21.1s**
- [ ] Observe thermal behavior under sustained back-to-back inference
- [ ] End-to-end n8n bank-statement extraction test

## Verdict (interim)

For the actual job — **monthly, unattended, batch** extraction of structured
fields from bank statements — speeds of 1.9–2.7 tok/s are slow but workable.
A typical extraction output is a few hundred tokens; at these rates that's a
few minutes per statement plus a ~21s model load, which is fine for a
once-a-month job that nobody waits on.

**Two viable models on the ZimaBlade:** Phi-2 (faster, 2.69 tok/s) and
Gemma 4 E2B (slower at 1.91 tok/s but higher quality with built-in
reasoning). For accuracy-sensitive field extraction, **Gemma 4 E2B is the
better default**, with Phi-2 as the speed-first fallback.

Final go/no-go waits on the E4B benchmark (the original headline question)
and the n8n end-to-end test.
