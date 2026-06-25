# poor-man-llm

Running modern multimodal LLMs on hardware nobody wants anymore.

## The story

I had a ZimaBlade 7700 lying around (Intel Celeron J3455 / Apollo Lake, no AVX, 16 GB DDR3L, no GPU, 32 GB eMMC). I wanted to wire a local LLM into my n8n workflows for privacy-sensitive documents — bank statements, personal records, anything I won't send to a hosted API.

The question: can a $0 hand-me-down mini-PC handle a 2026-level model like **Gemma 4 E4B**? Or is this a fool's errand?

## Current plan

→ **[`APPROACH.md`](APPROACH.md)** — the consolidated build plan.

Covers the full step-by-step: OS install, eMMC hardening, Ollama setup, model selection, benchmarking, LAN exposure, and n8n connectivity. Includes decision gates (E4B vs fallback), estimated performance numbers, and open risks.

## History

The plan was produced using the [EDDIE](https://github.com/m3m0ng/eddie) methodology (Explore → Define → Design). Full research artifacts live under [`eddie/`](eddie/) for posterity.

| Run | What it covers | Status |
|-----|----------------|--------|
| [`apollolake-e4b-reality-check`](eddie/apollolake-e4b-reality-check/) | Hardware assessment + setup plan for Apollo Lake ZimaBlade 7700 | Complete |
| [`gemma-e4b-rig-30tps`](eddie/gemma-e4b-rig-30tps/) | Original plan (J4125-based, superseded by corrected hardware specs) | Archived |

## Benchmarking

→ **[`bench/`](bench/)** — the canonical benchmark suite. Fixed prompts +
`bench/run.sh <model>` (run once per model) give reproducible tok/s numbers
via Ollama's own `--verbose` stats; use this for any future model comparison
instead of ad-hoc prompts.

## Results

→ **[`RESULTS.md`](RESULTS.md)** — real-world numbers measured on the ZimaBlade.

**Verdict: yes — a $0 Apollo Lake box can run a 2026-level 4B model.** Gemma 4
E4B fits in 16 GB and runs at **1.07 tok/s** (best quality, batch-only). Four
models measured, all viable for a monthly unattended batch job:

| Model | tok/s | Quality |
|-------|-------|---------|
| Gemma 4 E4B `gemma4:e4b` | 1.07 | best |
| Gemma 4 E2B `gemma4:e2b` | 1.91 | very good |
| Qwen3 `qwen3:1.7b` | 2.32 | good (best balance) |
| Phi-2 `phi:2.7b` | 2.69 | good (fastest) |

GO for the monthly batch use case; not for interactive use. n8n end-to-end test
still pending.

## What's coming next

- [x] Execute the build on the ZimaBlade 7700 (Ollama up, models running)
- [x] Run benchmarks for E4B and fallback models (E4B, E2B, Qwen3, Phi-2 all measured)
- [ ] Wire n8n connectivity and test end-to-end
- [x] Go/no-go verdict with real numbers — **GO for monthly batch** (see [`RESULTS.md`](RESULTS.md))
