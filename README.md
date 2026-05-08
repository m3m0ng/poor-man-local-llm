# poor-man-llm

Running modern multimodal LLMs on hardware nobody wants anymore.

## The story

I had a ZimaBlade 7700 lying around (Intel Apollo Lake N3450/J3455/E3950, 16 GB RAM, no GPU, 32 GB eMMC). I wanted to wire a local LLM into my n8n workflows for privacy-sensitive documents — bank statements, personal records, anything I won't send to a hosted API.

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

## What's coming next

- [ ] Execute the build on the ZimaBlade 7700
- [ ] Run benchmarks for E4B and fallback model
- [ ] Wire n8n connectivity and test end-to-end
- [ ] Go/no-go verdict with real numbers
