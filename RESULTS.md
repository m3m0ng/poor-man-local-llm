# Real-World Results — Local LLM on ZimaBlade 7700

> Measured on actual hardware. Numbers here replace the estimates in
> [`APPROACH.md`](APPROACH.md). Only measured values are recorded; anything
> not yet tested is marked **pending**.
>
> Numbers below predate the fixed benchmark suite and were gathered with a
> single hand-typed essay prompt (`ollama run <model> --verbose`). The
> canonical, reproducible method going forward is **[`bench/`](bench/)** —
> run `bench/run.sh <model>` (once per model) to regenerate these numbers
> on the realistic extraction/summarization/JSON workload.

## Test rig

- **Host:** ZimaBlade 7700 — Intel Celeron **J3455** (Apollo Lake, 4C4T, 2.3 GHz burst, no AVX, SSE4.2 only), **16 GB DDR3L-1333 single-channel** (~10.6 GB/s), 32 GB eMMC (29 GB usable), no GPU
- **OS / runtime:** Debian 13 (trixie), kernel 6.12; Ollama 0.23.2 (CPU runner)
- **Note:** CPU inference here is memory-bandwidth bound — at ~10.6 GB/s, tok/s ≈ bandwidth ÷ model size (E4B 9.6 GB → ~1.1 predicted vs 1.07 measured)

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

### Qwen3 1.7B (`qwen3:1.7b`) — small reasoning model ✅ tested

Prompt: `"Write a 200 word essay about energy efficiency"` (run with `ollama run qwen3:1.7b --verbose`)

| Metric | Value |
|--------|-------|
| **Generation rate (eval)** | **2.32 tok/s** |
| Prompt eval rate | 3.67 tok/s |
| Eval count | 468 tokens |
| Eval duration | 3m 21.7s |
| Prompt eval count | 22 tokens |
| Prompt eval duration | 5.99s |
| Load duration | 2.5s |
| Total duration | 3m 31.0s |

**Quality:** Good — like Gemma 4 E2B it runs a visible reasoning phase before
answering, and produced a clean, on-topic essay. Newer than the `qwen2.5:1.5b`
the plan originally listed.

**Decision gate:** 2.32 tok/s is in the `> 2` band → **keep.** A strong middle
ground: faster than Gemma 4 E2B, reasons before answering (unlike Phi-2), and a
smaller footprint.

### Gemma 4 E4B (`gemma4:e4b`) — primary candidate ✅ tested

Prompt: `"Write a 200 word essay about energy efficiency"` (run with `ollama run gemma4:e4b --verbose`)

| Metric | Value |
|--------|-------|
| **Generation rate (eval)** | **1.07 tok/s** |
| Prompt eval rate | 1.63 tok/s |
| Eval count | 528 tokens |
| Eval duration | 8m 11.7s |
| Prompt eval count | 27 tokens |
| Prompt eval duration | 16.59s |
| Load duration | 28.8s (cold load from eMMC) |
| Total duration | 8m 58.9s |

**It runs.** E4B fits and executes in 16 GB on Apollo Lake with no GPU and no
AVX — answering the project's founding question. Output quality was the best of
all four models: a polished, well-structured essay with a visible reasoning
phase and sophisticated vocabulary.

**vs. estimate:** APPROACH.md estimated 0.5–1.5 tok/s for a 4B model. Measured
1.07 tok/s — the estimate was accurate.

**Decision gate:** 1.07 tok/s is in the `1–2` band (near the `<1` edge) → "try,
but fallback recommended." At ~9 minutes for a short response, E4B is
**batch-only — never interactive**.

### Qwen3 0.6B (`qwen3:0.6b`) — tiny model ✅ tested

Prompt: `"Write a 200 word essay about energy efficiency"` (run with `ollama run qwen3:0.6b --verbose`)

| Metric | Value |
|--------|-------|
| **Generation rate (eval)** | **5.13 tok/s** |
| Prompt eval rate | 9.97 tok/s |
| Eval count | 318 tokens |
| Eval duration | 1m 2.0s |
| Prompt eval count | 22 tokens |
| Prompt eval duration | 2.21s |
| Load duration | 5.07s |
| Total duration | 1m 9.8s |

**Quality:** Coherent and on-topic, hit the 200-word target — impressive for a
0.6B model — but noticeably thinner than the larger models (less nuance, more
generic). It still ran a reasoning phase before answering.

**Decision gate:** 5.13 tok/s is the fastest measured — 2× the next model — so
firmly in the `> 2` "keep" band on speed. The real question is whether 0.6B is
*accurate* enough for field extraction; defer to the accuracy eval (#4).

**Bandwidth note:** at 522 MB the bandwidth ceiling would be ~20 tok/s; actual
5.13 confirms small models are compute/overhead-bound, not bandwidth-bound on
this CPU.

## Speed vs. quality (measured)

| Model | tok/s | Quality | Reasons? | Cold load | Gate |
|-------|-------|---------|----------|-----------|------|
| Qwen3 `qwen3:0.6b` | 5.13 | basic | yes | 5.1s | keep (speed) |
| Phi-2 `phi:2.7b` | 2.69 | good | no | (warm) | keep |
| Qwen3 `qwen3:1.7b` | 2.32 | good | yes | 2.5s | keep |
| Gemma 4 E2B `gemma4:e2b` | 1.91 | very good | yes | 21.1s | try/fallback |
| Gemma 4 E4B `gemma4:e4b` | 1.07 | best | yes | 28.8s | try/fallback |

Clear speed/quality gradient: E4B is best quality but ~5× slower than the
0.6B. Qwen3 0.6B is the speed champion (5.13 tok/s, 2× the next) but quality
is only "basic" — accuracy on real extraction is the open question (#4). Qwen3
1.7B remains the best all-round balance for general use.

## Open items still pending

- [x] Benchmark Gemma 4 E4B on the ZimaBlade — **runs at 1.07 tok/s, fits in 16 GB**
- [x] Measure cold-load latency — E2B 21.1s, E4B 28.8s from eMMC
- [ ] Observe thermal behavior under sustained back-to-back inference
- [ ] End-to-end n8n bank-statement extraction test

## Verdict

**The founding question is answered: yes, a $0 hand-me-down Apollo Lake box
(no GPU, no AVX, 16 GB RAM) can run a 2026-level 4B model.** Gemma 4 E4B fits
in memory and produces the best-quality output of everything tested — it is
simply slow (1.07 tok/s, ~9 min for a 200-word response).

This is a clear **GO for the intended use case** — a monthly, unattended,
batch extraction of structured fields from bank statements. Nobody waits on
the output, so even E4B's ~9-min-per-document pace is acceptable for a
once-a-month job. It is just as clearly a **NO for anything interactive**.

Model recommendation by priority:

| If you want… | Use | Why |
|--------------|-----|-----|
| Best extraction accuracy | **Gemma 4 E4B** | Highest quality; slow but fine for batch |
| Best all-round balance | **Qwen3 1.7B** | Reasons, 2.32 tok/s, 2.5s load |
| Fastest throughput | **Phi-2 2.7B** | 2.69 tok/s, no reasoning |

**Default pick: Gemma 4 E4B for the monthly run** (accuracy matters most on
financial data and time doesn't), with **Qwen3 1.7B** as the fast fallback if a
run needs to turn around quickly.

Remaining before a full end-to-end sign-off: thermal behavior under sustained
load, and the n8n connectivity / extraction test. The model question itself is
settled.
