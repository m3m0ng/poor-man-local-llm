# apollolake-e4b-reality-check — PRD

## Verified model & hardware facts (May 2026)

- **Hardware:** ZimaBlade 7700 — Intel Apollo Lake (N3450 / J3455 / E3950 variant). 4C4T, Goldmont architecture, 1.1–1.6 GHz base / 2.0–2.3 GHz burst, 2MB L2, no AVX/AVX2 (SSE4.2 only), 16GB RAM, 32GB eMMC, no discrete GPU.
- **Model target:** Gemma 4 E4B — 4.5B effective params (8B with embeddings), 128K context, multimodal (text + image + audio + video input, text output). ~5 GB at Q4_K_M, ~9.6 GB default Ollama tag.
- **Performance estimate (Apollo Lake):** 0.5–1.5 tok/s on 4B Q4_K_M. No direct benchmarks exist; extrapolated from architecture (no-AVX scalar path, low IPC, low clock).
- **Ollama requirement:** ≥ v0.5.2 (older versions crash on no-AVX CPUs with SIGILL).
- **Fallback candidate models:** Phi-2 2.7B, Qwen2.5-1.5B, Gemma 2B — 2–3× faster on this hardware (~1.5–4.5 tok/s), may suffice for structured extraction from bank statements.

## Problem Statement

The user wants to process bank statements (privacy-sensitive documents) once per month via an automated n8n workflow. Hosted APIs (Gemini, OpenAI) are ruled out for this use case on privacy grounds. The user's existing ZimaBlade 7700 (Apollo Lake) must run a local LLM to extract structured data from these documents. The question: is this hardware capable of running Gemma 4 E4B (or a suitable fallback), and if so, how to set it up so n8n can call it without timeout errors?

Specific needs:
1. An honest assessment: will this hardware handle the workload with any model?
2. A step-by-step guide to install Ollama (≥ v0.5.2) and test candidate models on Apollo Lake.
3. A benchmark so the user can measure actual performance and decide on the model.
4. Instructions to expose the local Ollama endpoint to n8n on the same LAN.
5. Clear guidance on which model to use (E4B vs. smaller fallback).

## Solution

A written guide that covers: (1) hardware capability reality-check for ZimaBlade 7700 + candidate models, (2) installing Ollama ≥ v0.5.2 and pulling Gemma 4 E4B (Q4_K_M) plus one fallback model, (3) verifying basic generation works on no-AVX hardware, (4) exposing Ollama on the LAN for n8n, (5) a benchmark recipe to measure actual tok/s, and (6) a model recommendation based on benchmark results and the user's bank-statement extraction needs.

## User Stories

**US1 — As the user, I want to know whether my ZimaBlade 7700 (Apollo Lake) can run any local LLM for bank-statement extraction, before I invest time installing anything.**
- **Given** the ZimaBlade 7700 has an Apollo Lake CPU (N3450/J3455/E3950), 16GB RAM, no GPU
- **When** the user reads the hardware capability section
- **Then** they see a clear verdict on which models are viable (E4B at ~0.5–1.5 tok/s, fallback models at ~1.5–4.5 tok/s)
- **And** they see what these speeds mean in practice (e.g., "200-token output = 2–7 minutes")
- **And** they see the conditions under which they should just use a smaller model instead of E4B

**US2 — As the user, I want to install Ollama ≥ v0.5.2 and pull Gemma 4 E4B plus one fallback model (e.g., Phi-2 2.7B) on the ZimaBlade 7700, so that I can test both and pick the right one.**
- **Given** the ZimaBlade 7700 is on the LAN, has 16GB RAM, 32GB eMMC, and runs a Linux OS capable of running Ollama
- **When** the user follows the install steps
- **Then** `ollama --version` reports ≥ 0.5.2 (no-AVX support)
- **And** `ollama run gemma4:e4b` returns a valid completion to a test prompt within 10 minutes of warm start
- **And** `ollama run phi2:2.7b` (or chosen fallback) also returns a valid completion
- **And** RAM usage during inference stays under ~12GB so the OS stays responsive
- **And** a pre-install disk check (`df -h ~`) confirms ≥ 10GB free on eMMC (OS ~10GB + E4B ~5GB + fallback ~1-2GB)
- **And** if `ollama pull` is interrupted (network drop, SSH timeout), re-running the same command resumes or cleanly re-pulls
- **And** if a pull is corrupted, `ollama rm <model>` then re-pull restores clean state
- **And** the guide documents `ollama rm gemma4:e4b` for cleaning up E4B when switching to fallback (Ollama itself stays installed)

**US3 — As the user, I want the ZimaBlade's Ollama endpoint reachable from my self-hosted n8n instance (running on a separate host), so that n8n can send documents to it.**
- **Given** Ollama is running on the ZimaBlade and n8n runs on a separate host with network access to the same LAN
- **When** the user configures Ollama to bind on `0.0.0.0:11434`
- **Then** an HTTP request from the n8n host to `http://<zimablade-ip>:11434/api/tags` returns a valid response
- **And** the guide warns about keeping port 11434 off WAN
- **And** the user verifies their n8n `EXECUTIONS_TIMEOUT` is ≥ 300 seconds (5 minutes) to cover slow inference
- **And** the guide notes: ZimaBlade runs Ollama only; n8n is on a separate host — no resource competition

**US4 — As the user, I want a benchmark recipe to measure actual tok/s for E4B and the fallback model on my ZimaBlade, so that I can decide which model to use for production.**
- **Given** Ollama with E4B and one fallback model are installed
- **When** the user runs the documented benchmark command (generation with a fixed text prompt, timing the output)
- **Then** the output prints generation tok/s for each model
- **And** the guide explains how to interpret the results with this decision table:

| tok/s | Recommendation |
|-------|----------------|
| > 2 | Use E4B — good quality, acceptable for monthly async |
| 1–2 | Try E4B, but fallback recommended for reliability |
| < 1 | Use fallback model — E4B is too slow for practical use |

- **And** the guide provides a decision framework: when to use E4B vs. fallback based on speed vs. extraction quality

**US5 — As the user, I want the guide to be honest about what won't work on this hardware, so that I don't waste time chasing impossible targets.**
- **Given** the ZimaBlade 7700 has no GPU and a low-power Apollo Lake CPU
- **When** the user reads the guide
- **Then** it states explicitly that interactive chat is not viable (< 2 tok/s on any model)
- **And** it states that E4B at Q4_K_M will take 2–7 minutes for a typical bank-statement extraction
- **And** it tells the user the conditions under which even the fallback model is too slow (e.g., "if benchmark shows < 1 tok/s on fallback, this hardware cannot do local LLM inference in any usable form")

**US6 — As the user, I want to test the full pipeline (n8n → Ollama → bank statement → structured output) once, so that I know the workflow actually works end-to-end.**
- **Given** Ollama is running, accessible from n8n, and a model is selected based on benchmarks
- **When** the user configures a simple n8n workflow that sends a sample bank statement (text or image) to Ollama and captures the response
- **Then** the workflow completes without timeout (within n8n's `EXECUTIONS_TIMEOUT`)
- **And** the response contains structured data extracted from the bank statement
- **And** the user confirms this is usable for their once-per-month automated workflow

## Implementation Decisions

- **Models to test:** Gemma 4 E4B (Q4_K_M, ~5GB) as primary; Phi-2 2.7B (Q4_K_M, ~1.6GB) or Qwen2.5-1.5B (Q4_K_M, ~1GB) as fallback. User will decide fallback after benchmarking.
- **Ollama version:** ≥ v0.5.2 (required for no-AVX CPU support).
- **OS recommendation:** Lightweight Debian 12 minimal netinst or Ubuntu Server 24.04 LTS (user choice; Debian preferred for lower RAM footprint).
- **Document ingestion path:** NAS or Google Drive → n8n trigger → Ollama. Path TBD in Design.
- **n8n timeout:** User to verify `EXECUTIONS_TIMEOUT` ≥ 300s (5 min). Default is usually sufficient.

## Testing Decisions

For a research-doc run, "tests" are: each user story's Given-When-Then runnable by the user as a manual verification step. The guide must include a verification checklist matching the acceptance criteria above.

## Anti-goal (verbatim from interview)

> "Must never become a homelab rabbit hole — no driver tuning, no BIOS flashing, no exotic builds."
> "Must never creep into buying new hardware for this specific use case."
> "Must never quietly depend on a paid API for the bank-statement path."
> "Must never become an always-on space heater or high-wattage system."

## Out of Scope (verbatim from interview)

> "Cases / aesthetics / RGB — cut."
> "Silent operation as a hard requirement — cut."
> "Multi-GPU or second-GPU upgrade path — cut."
> "NVMe / fast storage requirement — cut."
> "Running models larger than ~4B — keep. (Gemma 4 E4B is the target, but open to recommendation for a better-fit model on this hardware.)"
> "Fine-tuning / training on this rig — cut."
> "Co-hosting Whisper / TTS / image-generation — cut."
> "Exposing Ollama outside LAN — cut. (Slow anyway, moot point.)"
> "Interactive chat as a hard requirement — cut. (Async bank statements only.)"
> "Specific n8n workflow design — cut. (Connectivity only.)"

## Open Questions

- Which Apollo Lake variant does the user's ZimaBlade have (N3450 / J3455 / E3950)? Affects exact clock speeds but not order-of-magnitude performance.
- What OS is currently on the ZimaBlade? (Affects install steps — likely needs wipe + fresh install.)
- Document ingestion: NAS watch folder vs. Google Drive trigger? User undecided; affects n8n workflow design (out of scope for this guide, but the user needs to know for their own workflow).
- n8n `EXECUTIONS_TIMEOUT` value — user to verify.
- Which fallback model to recommend definitively? Will be answered by user's benchmark results, but guide should provide 2–3 candidates (Phi-2 2.7B, Qwen2.5-1.5B, Gemma 2B).
- Thermal throttling on sustained Apollo Lake load — to be researched in Design; ZimaBlade is passively cooled.
- Model transition: after benchmarking, user may want to `ollama rm gemma4:e4b` to free ~5GB, then `ollama pull <fallback>` — guide must document this linear path (E4B first → benchmark → decide → cleanup → pull fallback).

## Cross-Run Check

This run references `gemma-e4b-rig-30tps` (prior run). It **does not supersede** that run — it corrects the hardware assumption (Apollo Lake vs. J4125) and produces a new assessment. The prior run's artifacts remain valid for Gemini Lake / J4125 hardware, but are inaccurate for Apollo Lake.

## References

- Prior run: `eddie/gemma-e4b-rig-30tps/` (J4125-based assessment, now known to be incorrect for this hardware)
- Research agent findings: Apollo Lake + llama.cpp benchmarks (0.5–1.5 tok/s estimate, no direct benchmarks exist)
