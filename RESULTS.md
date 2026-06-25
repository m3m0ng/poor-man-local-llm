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

## Fixed benchmark suite (bench/) — measured

> These numbers come from the canonical [`bench/`](bench/) suite (three fixed
> prompts: field extraction, document-chunk summary, strict JSON output), not
> the legacy single essay prompt above. Run via the inline "no repo on the box"
> form (`M=phi:2.7b` + the three `echo … | ollama run $M --verbose` lines).
> First model recorded on the suite; others **pending** re-run.

### Phi-2 (`phi:2.7b`) ✅ tested

| Prompt | eval rate | prompt eval rate | eval/prompt tokens | load | total |
|--------|-----------|------------------|--------------------|------|-------|
| 01 field-extraction | **3.49 tok/s** | 4.90 tok/s | 62 / 98 | 2.82s | 40.7s |
| 02 document-chunk | **3.24 tok/s** | 5.91 tok/s | 76 / 136 | 0.15s | 46.7s |
| 03 json-output | **2.59 tok/s** | 7.88 tok/s | 549 / 76 | 0.17s | **3m 42s** |

**Quality, per prompt:**

- **01 — field extraction:** All four values correct (date `03/14/2026`,
  amount `$128.50`, payee `Greenfield Hardware`, type `Store Purchase`). But it
  returned a **Markdown table** despite the prompt asking for plain
  `key: value` lines — a format-following miss that would break a naive
  line-parser downstream.
- **02 — document-chunk summary:** Two clean sentences, balances and
  "good standing" carried over correctly — but it **hallucinated the year as
  `March, 2006`** when the source clearly says 2026. On financial documents a
  silently wrong date is a serious accuracy defect.
- **03 — strict JSON:** Produced exactly the right JSON object
  (`{"name":"Maria","age":34,"city":"Lisbon"}`) — and then **ignored the
  "Respond with ONLY valid JSON, no other text" instruction**, running on for
  549 tokens into an unrelated, fully hallucinated "game AI logic puzzle." This
  is the worst failure of the run: no stop after the answer, ~3.5 min of wasted
  generation, and output a strict JSON parser would choke on unless it grabs
  only the first object. Consistent with Phi-2 being a weakly
  instruction-tuned, completion-style model.

**Throughput drift:** eval rate fell monotonically across the three
back-to-back runs (3.49 → 3.24 → 2.59 tok/s). Could be thermal throttling
under sustained load (an [open item](#open-items-still-pending)) or just
longer generations; worth watching when more models are run on the suite.

**Takeaway:** Phi-2's *speed* is fine for batch, but on the real
extraction/JSON workload it shows three instruction/accuracy problems (wrong
format, hallucinated date, runaway non-JSON output). For the bank-statement use
case this argues against Phi-2 as the extraction model and in favor of the
reasoning models (Qwen3 / Gemma 4) once they're run on the same suite.

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

## Bench-suite results — canonical workload (`bench/`)

> First run of the fixed `bench/` prompt suite (field extraction, document-chunk
> summary, strict JSON), the realistic extraction workload that replaces the
> generic essay prompt used above. Run with the inline three-prompt form from
> `bench/README.md` (`ollama run <model> --verbose`).

### Qwen3 1.7B (`qwen3:1.7b`) ✅ tested

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 2.10 | 2.62s | 79 tok @ 3.64 t/s | 676 tok | 5m48.2s |
| 02 | doc chunk → 2 sentences | 2.26 | 0.78s | 124 tok @ 3.66 t/s | 357 tok | 3m13.4s |
| 03 | sentence → JSON | 2.32 | 0.67s | 52 tok @ 3.84 t/s | 424 tok | 3m18.1s |

**Generation rate (2.10–2.32 tok/s) matches the 2.32 tok/s essay figure** — the
realistic workload doesn't change the throughput number. What it *does* expose
is what raw tok/s hides:

- **Accuracy was good.** Field extraction returned all four fields correctly
  (`date`, `amount`, `payee`, `transaction_type: payment`). JSON output was
  valid, exactly the three required keys, with `age` as a number (`34`) — clean.
- **Instruction-following missed one constraint.** Prompt 02 asked for *exactly
  two sentences*; the model returned a single run-on sentence. Content was
  accurate, format was not.
- **The mandatory reasoning phase dominates wall-clock time.** Extracting four
  fields burned **676 generated tokens** of "Thinking…" before a 4-line answer
  — **5m48s for a trivial extraction**. On these short tasks the reasoning tax,
  not the tok/s, is the real cost: every prompt took 3–6 minutes regardless of
  how short the actual answer was.

**Implication for the batch use case:** budget by *generated tokens including
reasoning*, not by answer length. A reasoning model like Qwen3 inflates short
extraction tasks 5–10×; a non-reasoning model (Phi-2) would finish these in a
fraction of the time. For per-field extraction at scale, disable thinking (see
below); reserve the reasoning models for tasks where the extra deliberation
actually improves accuracy.

#### Thinking off (`--think=false`) — same model, same prompts ✅ tested

Re-ran the identical three prompts with Ollama's native `--think=false` switch
(the `/no_think` prompt tag was *not* honored by this build — Ollama 0.23.2 —
so the runtime flag is the reliable way to disable reasoning).

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 2.62 | 2.64s | 85 tok @ 3.63 t/s | 37 tok | 40.4s |
| 02 | doc chunk → 2 sentences | 2.49 | 0.52s | 130 tok @ 3.64 t/s | 75 tok | 1m06.4s |
| 03 | sentence → JSON | 2.72 | 0.60s | 58 tok @ 3.84 t/s | 27 tok | 25.7s |

**Head-to-head (thinking vs. no-think):**

| # | Generated tokens | Wall time | Quality change |
|---|------------------|-----------|----------------|
| 01 | 676 → **37** (18×↓) | 5m48s → **40s** (8.6×↓) | fields still correct |
| 02 | 357 → **75** (4.8×↓) | 3m13s → **1m06s** (2.9×↓) | **now exactly 2 sentences** — thinking had failed this |
| 03 | 424 → **27** (16×↓) | 3m18s → **26s** (7.6×↓) | valid JSON, identical result |

**Total wall time 12m20s → 2m13s — ~5.6× faster — with quality equal or
better.** The decisive result is prompt 02: with thinking *on* the model broke
the "exactly two sentences" rule (one run-on sentence); with thinking *off* it
followed it. On this extraction workload the reasoning phase bought **no**
measurable accuracy and actively hurt instruction-following, at 3–6× the cost.

The only content difference: prompt 01's `transaction_type` came back `payment`
(thinking) vs. `store purchase` (no-think) — both defensible readings of the
source sentence, neither clearly better.

**New bottleneck once thinking is off:** generation is now tiny, so **prompt
processing dominates** (prompt 01 = 23s prompt-eval + 14s generation). At
~3.6 tok/s prompt-eval, long multi-page bank statements — large *inputs* — will
be the limiting factor, not output length. Budget accordingly for real
documents.

**Recommendation:** run Qwen3 1.7B with **`--think=false`** for the bank-statement
extraction job. Keep reasoning on only for tasks that need genuine multi-step
judgment (e.g. reconciliation: opening + deposits − debits = closing, or
anomaly flagging), where the deliberation earns its cost.

### Gemma 4 E4B (`gemma4:e4b`) ✅ tested

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 1.20 | 49.5s | 84 tok @ 1.61 t/s | 37 tok | 2m13.2s |
| 02 | doc chunk → 2 sentences | 1.04 | 1.76s | 128 tok @ 1.72 t/s | 505 tok | 9m23.2s |
| 03 | sentence → JSON | 1.26 | 1.52s | 58 tok @ 1.95 t/s | 21 tok | 48.0s |

**Generation rate (1.04–1.26 tok/s) matches the 1.07 tok/s essay figure** — as
with Qwen3, the realistic workload doesn't move the throughput number. The
load on prompt 01 (49.5s) is the cold load from eMMC; prompts 02–03 reuse the
warm model (~1.6s).

- **Accuracy was a clean sweep — the best of any model on this suite.** Field
  extraction returned all four values correctly (`date 03/14/2026`,
  `amount $128.50`, `payee Greenfield Hardware`,
  `transaction_type: store purchase`) as **plain `key: value` lines** — no
  Markdown table (Phi-2's format miss) and no parser-breaking decoration. The
  summary was **exactly two sentences** with balances, transaction count, and
  "good standing" all carried over and the year correct as **2026** (Phi-2
  hallucinated 2006 here; Qwen3-with-thinking broke the two-sentence rule).
  JSON output was valid, exactly the three required keys, `age` as a number
  (`34`), with no trailing text (Phi-2's runaway non-JSON). E4B is the only
  model so far to satisfy all three format constraints *and* every value.
- **E4B reasons adaptively — it skipped the thinking phase on the easy
  prompts.** Prompts 01 and 03 generated just **37 and 21 tokens** and answered
  directly, with *no* visible "Thinking…" block; only prompt 02 (the summary)
  ran a reasoning phase, burning **505 tokens**. This is the key contrast with
  Qwen3 1.7B, which reasoned unconditionally (676 tokens even for the trivial
  field extraction). E4B spends the reasoning tax only where it judges the task
  warrants it.
- **Where it did reason, the tax is steep at 1 tok/s.** Prompt 02's 505 thinking
  tokens at ~1.04 tok/s is what pushed a two-sentence summary to **9m23s** — by
  far the slowest single prompt in the suite. The two no-reasoning prompts
  finished in 48s–2m13s despite the same throughput, because the answers are
  tiny.

**Takeaway:** on the canonical workload E4B delivers the highest accuracy *and*
the best instruction-following of everything tested, and its adaptive reasoning
avoids the across-the-board 5–10× inflation Qwen3 pays. The one expensive prompt
(02) is the case where E4B chose to reason; if summary latency matters, a
`--think=false` run (as done for Qwen3) is the obvious next probe. For the
unattended monthly extraction job, the all-correct result reinforces E4B as the
accuracy-first default.

#### Thinking off (`--think=false`) — same model, same prompts ✅ tested

Re-ran the identical three prompts with `--think=false`, the probe flagged
above.

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 1.21 | 1m12.7s | 77 tok @ 1.61 t/s | 37 tok | 2m31.7s |
| 02 | doc chunk → 2 sentences | 1.16 | 1.56s | 121 tok @ 1.63 t/s | 79 tok | 2m24.3s |
| 03 | sentence → JSON | 1.26 | 1.59s | 51 tok @ 1.73 t/s | 21 tok | 47.7s |

**Head-to-head (thinking vs. no-think):**

| # | Generated tokens | Wall time | Quality change |
|---|------------------|-----------|----------------|
| 01 | 37 → **37** (no change) | 2m13s → 2m31s | identical answer; wall variance is the cold load (49.5s → 72.7s) |
| 02 | 505 → **79** (6.4×↓) | 9m23s → **2m24s** (3.9×↓) | still exactly 2 sentences, accurate, year 2026 correct |
| 03 | 21 → **21** (no change) | 48s → 48s | identical JSON |

**This is the cleanest confirmation of the adaptive-reasoning finding.**
`--think=false` changed **only prompt 02** — the single prompt E4B chose to
reason on. Prompts 01 and 03 were *already* generating 37 and 21 tokens with no
thinking block, so disabling reasoning left them byte-for-byte identical
(the prompt-01 wall difference is purely a slower cold load, not compute).

The win is concentrated in prompt 02: **505 → 79 tokens, 9m23s → 2m24s (~3.9×
faster)** with the summary still exactly two sentences and accurate. Unlike
Qwen3 — where no-think actively *fixed* a broken constraint (the two-sentence
rule) — here thinking-on already produced a correct summary, so the no-think
gain is pure latency with no quality change either way.

**Recommendation:** run E4B with **`--think=false`** for the extraction job.
Because E4B only reasons on the harder prompt, the flag costs nothing on the
prompts it would have skipped anyway and removes the one expensive reasoning
burst on the summary — total suite wall **12m24s → 5m43s** with no accuracy
loss. As with Qwen3, keep reasoning on only for tasks needing genuine
multi-step judgment (reconciliation, anomaly flagging).

## Open items still pending

- [x] Run the canonical `bench/` suite for Qwen3 1.7B — 2.10–2.32 tok/s; accurate extraction/JSON, but reasoning phase inflates short-task wall time 5–10×
- [x] Re-run Qwen3 1.7B with `--think=false` — ~5.6× faster overall (12m20s → 2m13s), quality equal or better; use no-think for the extraction job
- [x] Run the `bench/` suite for Gemma 4 E4B — 1.04–1.26 tok/s; clean sweep on accuracy and all three format constraints, adaptive reasoning (skips thinking on easy prompts)
- [x] Re-run Gemma 4 E4B with `--think=false` — only prompt 02 changed (505→79 tok, 9m23s→2m24s); suite wall 12m24s→5m43s, no accuracy loss
- [ ] Run the `bench/` suite for the remaining models (E2B, 0.6B) for a like-for-like comparison on the real workload
- [x] Benchmark Gemma 4 E4B on the ZimaBlade — **runs at 1.07 tok/s, fits in 16 GB**
- [x] Measure cold-load latency — E2B 21.1s, E4B 28.8s from eMMC
- [ ] Observe thermal behavior under sustained back-to-back inference —
  *first hint:* Phi-2's eval rate drifted down 3.49 → 3.24 → 2.59 tok/s across
  the three back-to-back suite runs (see the Phi-2 entry under "Fixed
  benchmark suite (bench/)" above)
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
