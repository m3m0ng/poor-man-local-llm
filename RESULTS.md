# Real-World Results — Local LLM on ZimaBlade 7700

> Measured on actual hardware. Numbers here replace the estimates in
> [`APPROACH.md`](APPROACH.md). Only measured values are recorded; anything
> not yet tested is marked **pending**.
>
> The authoritative results are the **[canonical benchmark suite](#canonical-benchmark-suite-bench)**
> below — three fixed prompts (field extraction, document-chunk summary, strict
> JSON) that mirror the real bank-statement workload. The
> [earlier essay benchmarks](#earlier-essay-benchmarks-superseded) are kept for
> the record but are superseded by the suite.

## Contents

- [Test rig](#test-rig)
- [Summary — at a glance](#summary--at-a-glance)
- [Canonical benchmark suite (`bench/`)](#canonical-benchmark-suite-bench)
- [Earlier essay benchmarks (superseded)](#earlier-essay-benchmarks-superseded)
- [Open items](#open-items)
- [Verdict](#verdict)

## Test rig

- **Host:** ZimaBlade 7700 — Intel Celeron **J3455** (Apollo Lake, 4C4T, 2.3 GHz burst, no AVX, SSE4.2 only), **16 GB DDR3L-1333 single-channel** (~10.6 GB/s), 32 GB eMMC (29 GB usable), no GPU
- **OS / runtime:** Debian 13 (trixie), kernel 6.12; Ollama 0.23.2 (CPU runner)
- **Note:** CPU inference here is memory-bandwidth bound — at ~10.6 GB/s, tok/s ≈ bandwidth ÷ model size (E4B 9.6 GB → ~1.1 predicted vs 1.07 measured)

## Summary — at a glance

All five candidate models, on the canonical `bench/` suite, in their
**recommended** configuration. "Suite wall" is the total wall-clock for all
three prompts back-to-back.

| Model | Size | Best mode | Gen speed | Suite wall | Quality on suite | Role |
|-------|------|-----------|-----------|-----------:|------------------|------|
| **Gemma 4 E4B** | 4B | `--think=false` | 1.2 tok/s | 5m43s | ★ **best** — clean sweep, adaptive reasoning | Monthly batch (accuracy pick) |
| **Gemma 4 E2B** | 2B | `--think=false` | 2.1–2.4 tok/s | 2m38s | accurate; no-think *fixed* its JSON fence | Balance |
| **Qwen3 1.7B** | 1.7B | `--think=false` | 2.5–2.7 tok/s | **2m13s** | accurate; no-think *fixed* its 2-sentence miss | Fast fallback |
| **Qwen3 0.6B** | 0.6B | **thinking ON** | ~5 tok/s | 3m26s | accurate *with* reasoning; no-think miscounts | Speed champ (keep thinking on) |
| Phi-2 2.7B | 2.7B | (no reasoning) | 2.6–3.5 tok/s | 5m9s | ✗ failed all 3 (table, wrong year, runaway) | Avoid for extraction |

**Key takeaways:**

- **Accuracy winner: Gemma 4 E4B.** The only model to satisfy all three format
  constraints *and* every value on its default run — and the only one that
  reasons *adaptively* (skips the thinking phase on the easy prompts).
- **Speed-with-accuracy winner: Qwen3 1.7B.** Fastest *trustworthy* suite wall
  (2m13s) once thinking is off.
- **`--think=false` is a strict win for the ≥1.7B models** (faster, never worse,
  sometimes *fixing* a constraint) — but **not for 0.6B**, where the reasoning
  phase is load-bearing for accuracy (see the [cross-cutting finding](#cross-cutting-the---thinkfalse-rule)).
- **Phi-2 is out for extraction:** wrong output format, a hallucinated year, and
  a runaway non-JSON generation.

## Canonical benchmark suite (`bench/`)

> The fixed [`bench/`](bench/) prompt suite — three prompts (field extraction,
> document-chunk summary, strict JSON output) that match the real extraction
> workload, replacing the generic essay prompt. Run with the inline three-prompt
> form from `bench/README.md` (`ollama run <model> --verbose`), once per model,
> and again with `--think=false` for the reasoning models. **Sweep complete
> across all five models.**

### Phi-2 (`phi:2.7b`)

| # | Prompt | eval tok/s | prompt eval tok/s | eval / prompt tokens | load | wall (total) |
|---|--------|-----------:|------------------:|---------------------:|-----:|-------------:|
| 01 | field extraction | **3.49** | 4.90 | 62 / 98 | 2.82s | 40.7s |
| 02 | doc chunk → 2 sentences | **3.24** | 5.91 | 76 / 136 | 0.15s | 46.7s |
| 03 | sentence → JSON | **2.59** | 7.88 | 549 / 76 | 0.17s | **3m42s** |

Phi-2 does not reason, so there is no `--think=false` variant. **It failed all
three prompts on output discipline:**

- **01 — field extraction:** all four values correct, but returned a **Markdown
  table** despite the prompt asking for plain `key: value` lines — a format miss
  that would break a naive line-parser.
- **02 — document-chunk summary:** two clean sentences, balances carried over —
  but it **hallucinated the year as `March, 2006`** when the source says 2026. On
  a financial document a silently wrong date is a serious accuracy defect.
- **03 — strict JSON:** produced the right object
  (`{"name":"Maria","age":34,"city":"Lisbon"}`) then **ignored "ONLY valid JSON,
  no other text"**, running on for 549 tokens into a hallucinated "game AI logic
  puzzle." The worst failure of the run: ~3.5 min of wasted generation and output
  a strict parser chokes on. Consistent with Phi-2 being a weakly
  instruction-tuned, completion-style model.

**Throughput drift:** eval rate fell monotonically across the three back-to-back
runs (3.49 → 3.24 → 2.59 tok/s) — possible thermal throttling (an
[open item](#open-items)) or just longer generations; worth watching.

**Verdict:** speed is fine for batch, but the three instruction/accuracy
failures rule Phi-2 out as the extraction model in favor of the reasoning models.

### Qwen3 1.7B (`qwen3:1.7b`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 2.10 | 2.62s | 79 tok @ 3.64 t/s | 676 tok | 5m48.2s |
| 02 | doc chunk → 2 sentences | 2.26 | 0.78s | 124 tok @ 3.66 t/s | 357 tok | 3m13.4s |
| 03 | sentence → JSON | 2.32 | 0.67s | 52 tok @ 3.84 t/s | 424 tok | 3m18.1s |

**Generation rate (2.10–2.32 tok/s) matches the 2.32 tok/s essay figure** — the
realistic workload doesn't change throughput. What it *does* expose is what raw
tok/s hides:

- **Accuracy was good.** All four fields correct
  (`transaction_type: payment`); JSON valid, exactly three keys, `age` numeric.
- **Instruction-following missed one constraint.** Prompt 02 asked for *exactly
  two sentences*; it returned a single run-on sentence. Content accurate, format
  not.
- **The mandatory reasoning phase dominates wall time.** Extracting four fields
  burned **676 tokens** of "Thinking…" before a 4-line answer — **5m48s for a
  trivial extraction**. Every prompt took 3–6 minutes regardless of answer
  length.

**Implication:** budget by *generated tokens including reasoning*, not answer
length. A reasoning model inflates short extraction tasks 5–10×.

#### Thinking off (`--think=false`)

Re-ran the identical prompts with Ollama's native `--think=false` switch (the
`/no_think` prompt tag was *not* honored by this build — Ollama 0.23.2 — so the
runtime flag is the reliable way to disable reasoning).

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 2.62 | 2.64s | 85 tok @ 3.63 t/s | 37 tok | 40.4s |
| 02 | doc chunk → 2 sentences | 2.49 | 0.52s | 130 tok @ 3.64 t/s | 75 tok | 1m06.4s |
| 03 | sentence → JSON | 2.72 | 0.60s | 58 tok @ 3.84 t/s | 27 tok | 25.7s |

| # | Generated tokens | Wall time | Quality change |
|---|------------------|-----------|----------------|
| 01 | 676 → **37** (18×↓) | 5m48s → **40s** (8.6×↓) | fields still correct |
| 02 | 357 → **75** (4.8×↓) | 3m13s → **1m06s** (2.9×↓) | **now exactly 2 sentences** — thinking had failed this |
| 03 | 424 → **27** (16×↓) | 3m18s → **26s** (7.6×↓) | valid JSON, identical result |

**Total wall 12m20s → 2m13s — ~5.6× faster — with quality equal or better.** The
decisive result is prompt 02: thinking *on* broke the two-sentence rule; thinking
*off* followed it. The only content difference: prompt 01's `transaction_type`
came back `payment` (thinking) vs. `store purchase` (no-think) — both defensible.

**New bottleneck once thinking is off:** generation is tiny, so **prompt
processing dominates** (prompt 01 = 23s prompt-eval + 14s generation). At
~3.6 tok/s prompt-eval, long multi-page statements — large *inputs* — become the
limiting factor, not output length.

**Recommendation:** run Qwen3 1.7B with **`--think=false`** for the extraction
job; keep reasoning on only for genuine multi-step judgment (reconciliation,
anomaly flagging).

### Gemma 4 E4B (`gemma4:e4b`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 1.20 | 49.5s | 84 tok @ 1.61 t/s | 37 tok | 2m13.2s |
| 02 | doc chunk → 2 sentences | 1.04 | 1.76s | 128 tok @ 1.72 t/s | 505 tok | 9m23.2s |
| 03 | sentence → JSON | 1.26 | 1.52s | 58 tok @ 1.95 t/s | 21 tok | 48.0s |

**Generation rate (1.04–1.26 tok/s) matches the 1.07 tok/s essay figure.** The
load on prompt 01 (49.5s) is the cold load from eMMC; prompts 02–03 reuse the
warm model (~1.6s).

- **Accuracy was a clean sweep — the best of any model on this suite.** All four
  fields correct as **plain `key: value` lines** (no Markdown table); summary
  **exactly two sentences** with the year correct as **2026** (Phi-2 hallucinated
  2006; Qwen3-with-thinking broke the two-sentence rule); JSON valid, three keys,
  `age` numeric, no trailing text (Phi-2's runaway). The only model to satisfy
  all three format constraints *and* every value.
- **E4B reasons adaptively — it skipped the thinking phase on the easy prompts.**
  Prompts 01 and 03 generated just **37 and 21 tokens** with *no* "Thinking…"
  block; only prompt 02 (the summary) reasoned, burning **505 tokens**. The key
  contrast with Qwen3 1.7B, which reasoned unconditionally (676 tokens even for
  field extraction). E4B spends the reasoning tax only where it judges it
  warranted.
- **Where it did reason, the tax is steep at ~1 tok/s.** Prompt 02's 505 thinking
  tokens pushed a two-sentence summary to **9m23s** — the slowest single prompt
  in the suite.

**Takeaway:** E4B delivers the highest accuracy *and* the best
instruction-following, and adaptive reasoning avoids the across-the-board 5–10×
inflation Qwen3 pays. For the unattended monthly job, the all-correct result
makes it the accuracy-first default.

#### Thinking off (`--think=false`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 1.21 | 1m12.7s | 77 tok @ 1.61 t/s | 37 tok | 2m31.7s |
| 02 | doc chunk → 2 sentences | 1.16 | 1.56s | 121 tok @ 1.63 t/s | 79 tok | 2m24.3s |
| 03 | sentence → JSON | 1.26 | 1.59s | 51 tok @ 1.73 t/s | 21 tok | 47.7s |

| # | Generated tokens | Wall time | Quality change |
|---|------------------|-----------|----------------|
| 01 | 37 → **37** (no change) | 2m13s → 2m31s | identical answer; wall variance is the cold load (49.5s → 72.7s) |
| 02 | 505 → **79** (6.4×↓) | 9m23s → **2m24s** (3.9×↓) | still exactly 2 sentences, accurate, year 2026 correct |
| 03 | 21 → **21** (no change) | 48s → 48s | identical JSON |

**The cleanest confirmation of the adaptive-reasoning finding:** `--think=false`
changed **only prompt 02** — the single prompt E4B chose to reason on. Prompts 01
and 03 were *already* generating 37 and 21 tokens with no thinking block, so
disabling reasoning left them byte-for-byte identical (the prompt-01 wall
difference is purely a slower cold load).

The win is concentrated in prompt 02 (**505 → 79 tokens, 9m23s → 2m24s**), still
exactly two sentences and accurate. Unlike Qwen3 — where no-think *fixed* a
broken constraint — here thinking-on already produced a correct summary, so the
no-think gain is pure latency.

**Recommendation:** run E4B with **`--think=false`** — total suite wall
**12m24s → 5m43s** with no accuracy loss.

### Gemma 4 E2B (`gemma4:e2b`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 1.72 | 11.06s | 84 tok @ 3.32 t/s | 374 tok | 4m14.9s |
| 02 | doc chunk → 2 sentences | 1.86 | 1.57s | 128 tok @ 3.51 t/s | 425 tok | 4m27.5s |
| 03 | sentence → JSON | 2.07 | 1.38s | 58 tok @ 4.04 t/s | 269 tok | 2m26.6s |

**Generation rate (1.72–2.07 tok/s) is ~1.7× E4B's** — the expected gain from the
smaller 2B model; prompt-eval (3.3–4.0 t/s) is about double E4B's.

- **Accuracy held up on values.** All four fields correct as plain `key: value`
  lines; summary **exactly two sentences**, year correct as **2026**; JSON with
  the right three keys, `age` numeric.
- **One format miss: prompt 03 wrapped its JSON in a ```` ```json ```` fenced
  block.** Values correct, but the fences are exactly the "other text" the prompt
  said to omit — a strict parser chokes unless it strips them. E4B returned the
  bare object here; E2B did not.
- **E2B reasons *unconditionally* — the key contrast with E4B.** A "Thinking…"
  phase on **all three** prompts (374 / 425 / 269 tokens), including the trivial
  extraction and one-line JSON. E4B skipped reasoning on exactly those two short
  prompts (37 / 21 tokens). The smaller sibling is the *less* judicious of the
  two: even the JSON conversion took **2m26s** behind 269 thinking tokens.

**Takeaway:** faster than E4B and accurate on values, but it loses E4B's two
quality edges — the bare-JSON output and adaptive reasoning.

#### Thinking off (`--think=false`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 2.27 | 13.76s | 77 tok @ 3.33 t/s | 37 tok | 53.8s |
| 02 | doc chunk → 2 sentences | 2.11 | 1.49s | 123 tok @ 3.32 t/s | 87 tok | 1m19.9s |
| 03 | sentence → JSON | 2.38 | 1.45s | 51 tok @ 3.66 t/s | 21 tok | 24.3s |

| # | Generated tokens | Wall time | Quality change |
|---|------------------|-----------|----------------|
| 01 | 374 → **37** (10×↓) | 4m15s → **54s** (4.7×↓) | fields still correct |
| 02 | 425 → **87** (4.9×↓) | 4m28s → **1m20s** (3.3×↓) | still exactly 2 sentences, accurate |
| 03 | 269 → **21** (13×↓) | 2m27s → **24s** (6.0×↓) | **now bare JSON — the ```` ```json ```` fences are gone** |

**Total wall 11m9s → 2m38s — ~4.2× faster — and the no-think run *fixed* the one
format defect.** Prompt 03 returned the bare object a strict parser accepts
directly. As with Qwen3 (the two-sentence rule) and unlike E4B (which had nothing
to fix), disabling reasoning on E2B both sped it up *and* removed a real miss.
Because E2B reasons on every prompt, the speedup is broad-based (all three shrank
3–6×), not concentrated in one prompt the way it was for E4B.

**Recommendation:** run E2B with **`--think=false`** — both faster and *more*
correct. At 2.11–2.38 tok/s it clears all three format constraints.

### Qwen3 0.6B (`qwen3:0.6b`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 4.71 | 2.15s | 79 tok @ 9.53 t/s | 333 tok | 1m21.9s |
| 02 | doc chunk → 2 sentences | 4.56 | 0.58s | 127 tok @ 9.37 t/s | 293 tok | 1m18.9s |
| 03 | sentence → JSON | 5.36 | 0.59s | 52 tok @ 10.35 t/s | 211 tok | 45.4s |

**By far the fastest model on the suite** — 4.56–5.36 tok/s generation (~2× Qwen3
1.7B, ~4× E4B) and 9.4–10.4 t/s prompt-eval. Matches its 5.13 tok/s essay figure
and confirms small models are compute/overhead-bound, not bandwidth-bound here.

- **Accuracy was correct on every value — better than expected for 0.6B.** All
  four fields right; summary **exactly two sentences**, year correct as **2026**;
  JSON the **bare** `{"name":"Maria","age":34,"city":"Lisbon"}` object — no fence,
  no runaway. It cleanly passed the two constraints that tripped bigger models
  (E2B's ```` ```json ```` fence, Qwen3-1.7B's two-sentence miss).
- **One minor format slip on prompt 01:** it prefixed each line with a `- ` bullet
  (`- date: 03/14/2026`). A parser splitting on `": "` still recovers every
  field, so this is cosmetic rather than breaking — much milder than Phi-2's full
  Markdown table — but not the literal format requested.
- **It reasons unconditionally** (333 / 293 / 211 tokens). The reasoning tax holds
  total wall to **3m26s** despite the high tok/s.

**Takeaway — the surprise of the sweep.** Far more capable than its "basic" essay
rating suggested: correct on every value, clean bare JSON, exact sentence count,
at 2–4× everyone else's speed. It does **not** dethrone E4B on quality (E4B is
still the cleanest and the only adaptive reasoner), but it is a legitimate
fast-fallback contender, and on raw throughput it wins outright. The open risk is
**robustness**: these are single, short, clean inputs; a 0.6B model is the most
likely to degrade on long, messy, multi-page real statements — validate it on
real documents before trusting it in production.

#### Thinking off (`--think=false`)

| # | Prompt | eval tok/s | load | prompt eval | eval count | wall (total) |
|---|--------|-----------:|-----:|------------:|-----------:|-------------:|
| 01 | field extraction | 5.93 | 0.38s | 85 tok @ 9.87 t/s | 41 tok | 16.0s |
| 02 | doc chunk → 2 sentences | 5.20 | 0.49s | 133 tok @ 9.23 t/s | 101 tok | 34.5s |
| 03 | sentence → JSON | 6.38 | 0.56s | 58 tok @ 10.28 t/s | 27 tok | 10.5s |

**Total wall 3m26s → 1m01s — ~3.4× faster — the whole suite ran in about a
minute**, the fastest end-to-end result of any model in any mode. **But this is
the first time `--think=false` made quality *worse* on a value:**

| # | Generated tokens | Wall | Quality change |
|---|------------------|------|----------------|
| 01 | 333 → **41** (8.1×↓) | 1m22s → 16s | fields still correct; still `- ` bulleted |
| 02 | 293 → **101** (2.9×↓) | 1m19s → 34s | **regressed: says "two transactions" — the source says 14** |
| 03 | 211 → **27** (7.8×↓) | 45s → 10s | valid bare JSON (pretty-printed); still correct |

On prompt 02 the no-think summary reads *"…and two transactions recorded…"* — it
miscounted **14 → 2**, latching onto the two transactions it chose to name. The
thinking-on run got this right. On a financial document a wrong transaction count
is a real accuracy defect.

**Recommendation:** if 0.6B is used at all, keep **thinking on** despite the
cost — it's still the fastest model in the suite *with* reasoning enabled (3m26s
total), and that's the configuration that read the document correctly.

### Cross-cutting: the `--think=false` rule

Pulling the four reasoning models together, disabling thinking is **not** a
uniform win — it depends on model size:

| Model | Suite wall (think → no-think) | Speedup | Effect on quality |
|-------|------------------------------|--------:|-------------------|
| Qwen3 1.7B | 12m20s → 2m13s | 5.6× | **fixed** the two-sentence miss |
| Gemma 4 E4B | 12m24s → 5m43s | 2.2× | no change (was already correct) |
| Gemma 4 E2B | 11m9s → 2m38s | 4.2× | **fixed** the JSON fence |
| Qwen3 0.6B | 3m26s → 1m01s | 3.4× | **regressed** — miscounted 14 → 2 |

**The rule:** for the **≥1.7B** models, `--think=false` is a strict win — faster,
never worse, sometimes *fixing* a constraint, so use it for the extraction job.
At **0.6B** the reasoning phase is **load-bearing for accuracy**; removing it
bought speed but introduced a factual miscount. The smaller the model, the more
the deliberation is doing real work rather than burning tokens.

## Earlier essay benchmarks (superseded)

> These numbers predate the `bench/` suite and were gathered with a single
> hand-typed essay prompt (`"Write a 200 word essay about energy efficiency"`,
> run with `ollama run <model> --verbose`). Kept for the record — the suite
> above is the authoritative workload — but useful for cold-load latency and the
> APPROACH.md estimate validation.

### Phi-2 (`phi:2.7b`)

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

Coherent, fluent, on-topic — a usable essay plus follow-up Q&A. APPROACH.md
estimated 1.5–4.5 tok/s; measured 2.69 lands squarely in range.

### Gemma 4 E2B (`gemma4:e2b`)

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

Noticeably better than Phi-2 — a visible reasoning phase and a tighter essay.
This is the **E2B** (2B) variant; treat 1.91 tok/s as an upper bound for E4B.

### Qwen3 1.7B (`qwen3:1.7b`)

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

Good — reasons before answering, clean on-topic essay. Newer than the
`qwen2.5:1.5b` the plan originally listed.

### Gemma 4 E4B (`gemma4:e4b`)

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

**It runs.** E4B fits and executes in 16 GB on Apollo Lake with no GPU and no AVX
— answering the project's founding question. Best essay quality of the four.
APPROACH.md estimated 0.5–1.5 tok/s; measured 1.07 was accurate. At ~9 minutes
for a short response, E4B is **batch-only — never interactive**.

### Qwen3 0.6B (`qwen3:0.6b`)

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

Coherent and on-topic, hit the 200-word target — impressive for 0.6B but thinner
than the larger models. At 522 MB the bandwidth ceiling would be ~20 tok/s;
actual 5.13 confirms small models are compute/overhead-bound, not bandwidth-bound
on this CPU. (Its real accuracy was later answered by the bench suite above.)

### Speed vs. quality (essay pass)

| Model | tok/s | Quality | Reasons? | Cold load |
|-------|-------|---------|----------|-----------|
| Qwen3 `qwen3:0.6b` | 5.13 | basic | yes | 5.1s |
| Phi-2 `phi:2.7b` | 2.69 | good | no | (warm) |
| Qwen3 `qwen3:1.7b` | 2.32 | good | yes | 2.5s |
| Gemma 4 E2B `gemma4:e2b` | 1.91 | very good | yes | 21.1s |
| Gemma 4 E4B `gemma4:e4b` | 1.07 | best | yes | 28.8s |

Clear speed/quality gradient on the essay: E4B best but ~5× slower than 0.6B.
(The bench suite later showed 0.6B is far more accurate on the real workload than
"basic" suggested.)

## Open items

- [x] Run the `bench/` suite for Qwen3 1.7B — 2.10–2.32 tok/s; accurate, but reasoning inflates short-task wall time 5–10×
- [x] Re-run Qwen3 1.7B with `--think=false` — ~5.6× faster (12m20s → 2m13s), quality equal or better
- [x] Run the `bench/` suite for Gemma 4 E4B — 1.04–1.26 tok/s; clean sweep on accuracy and all three format constraints, adaptive reasoning
- [x] Re-run Gemma 4 E4B with `--think=false` — only prompt 02 changed; suite wall 12m24s → 5m43s, no accuracy loss
- [x] Run the `bench/` suite for Gemma 4 E2B — 1.72–2.07 tok/s; accurate values but reasons on all prompts and fenced its JSON
- [x] Re-run Gemma 4 E2B with `--think=false` — 11m9s → 2m38s (~4.2×) and *fixed* the JSON fencing
- [x] Run the `bench/` suite for Qwen3 0.6B — fastest model; correct on every value with thinking on, only a cosmetic bullet prefix. **Bench sweep complete across all models.**
- [x] Re-run Qwen3 0.6B with `--think=false` — 3.4× faster (3m26s → 1m01s) but **regressed accuracy** (miscounted 14 → 2); keep thinking *on* for 0.6B
- [x] Benchmark Gemma 4 E4B on the ZimaBlade — **runs at 1.07 tok/s, fits in 16 GB**
- [x] Measure cold-load latency — E2B 21.1s, E4B 28.8s from eMMC
- [ ] Observe thermal behavior under sustained back-to-back inference — *first hint:* Phi-2's eval rate drifted down 3.49 → 3.24 → 2.59 tok/s across the three back-to-back suite runs (see the [Phi-2 bench entry](#phi-2-phi27b))
- [ ] End-to-end n8n bank-statement extraction test
- [ ] Validate Qwen3 0.6B on long, messy, multi-page real statements before trusting it in production

## Verdict

**The founding question is answered: yes, a $0 hand-me-down Apollo Lake box
(no GPU, no AVX, 16 GB RAM) can run a 2026-level 4B model.** Gemma 4 E4B fits in
memory and produces the best-quality output of everything tested — it is simply
slow (1.07 tok/s; ~5m43s for the full extraction suite with `--think=false`).

This is a clear **GO for the intended use case** — a monthly, unattended, batch
extraction of structured fields from bank statements. Nobody waits on the output,
so even E4B's pace is acceptable for a once-a-month job. It is just as clearly a
**NO for anything interactive**.

Model recommendation by priority (all reasoning models run with `--think=false`
**except 0.6B**, which keeps thinking on):

| If you want… | Use | Why |
|--------------|-----|-----|
| Best extraction accuracy | **Gemma 4 E4B** (`--think=false`) | Clean sweep on the suite; slow (5m43s) but fine for batch |
| Best all-round balance | **Gemma 4 E2B** (`--think=false`) | Accurate, 2m38s, clears all format constraints |
| Fastest verified-accurate | **Qwen3 1.7B** (`--think=false`) | Fastest trustworthy suite wall (2m13s), 2.5s load |
| Fastest raw (with caveat) | **Qwen3 0.6B** (thinking **on**) | ~5 tok/s, but keep thinking on or it miscounts; needs real-doc validation |
| — | ~~Phi-2 2.7B~~ | **Avoid for extraction** — failed all three suite prompts |

**Default pick: Gemma 4 E4B for the monthly run** (accuracy matters most on
financial data and time doesn't), with **Qwen3 1.7B** as the fast fallback if a
run needs to turn around quickly.

Remaining before a full end-to-end sign-off: thermal behavior under sustained
load, the 0.6B real-document robustness check, and the n8n connectivity /
extraction test. The model question itself is settled.
