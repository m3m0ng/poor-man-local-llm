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

### Gemma 4 E4B (`gemma4:e4b`) — primary candidate ⏳ pending

Not yet benchmarked on hardware.

## Open items still pending

- [ ] Benchmark Gemma 4 E4B on the ZimaBlade (does it fit/run in 16 GB? tok/s?)
- [ ] Measure true cold-start latency (load from eMMC after Ollama restart;
      the Phi-2 run above was warm at 209 ms)
- [ ] Observe thermal behavior under sustained back-to-back inference
- [ ] End-to-end n8n bank-statement extraction test

## Verdict (interim)

For the actual job — **monthly, unattended, batch** extraction of structured
fields from bank statements — 2.69 tok/s is slow but workable. A typical
extraction output is a few hundred tokens; at this rate that's a couple of
minutes per statement, which is fine for a once-a-month job that nobody waits
on. **Phi-2 on the ZimaBlade is a viable fallback.** Final go/no-go waits on
the E4B benchmark and the n8n end-to-end test.
