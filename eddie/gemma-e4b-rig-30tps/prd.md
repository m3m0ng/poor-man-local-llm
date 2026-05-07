# gemma-e4b-rig-30tps — PRD

> Note on run name: the original "30 tok/s rig shopping guide" framing was superseded during Explore. The deliverable is now a **hardware capability assessment and setup guide** for running **Gemma 4 E4B** (released April 2026, Apache 2.0; tag `gemma4:e4b` on Ollama) locally on the user's existing ZimaBlade 7700, wired into n8n. No hardware purchase. The run slug is preserved for traceability.

## Verified model facts (May 2026)

- **Model:** Gemma 4 E4B — 4.5B effective params (8B with embeddings), 128K context.
- **Modalities:** Text + image + audio + video input; text output. ~150M-param vision encoder.
- **Sizes:** ~5 GB at Q4, ~8 GB at Q8, ~15 GB at FP16. Default Ollama tag is 9.6 GB.
- **Hosted availability:** **NOT on Google AI Studio or OpenRouter.** Google AI Studio hosts only Gemma 4 26B MoE and 31B Dense. E4B is on-device-only by design (Google AI Edge Gallery, HF, Kaggle, Ollama).

## Problem Statement

The user wants to know whether their existing ZimaBlade 7700 (Celeron J4125, 16GB RAM, no GPU) is capable of running Gemma 4 E4B locally, and if so, how to set it up so n8n can call it. They need:
1. A clear assessment: will this hardware handle their workload, or do they need more capable hardware?
2. A step-by-step guide to install Ollama + Gemma 4 E4B on the ZimaBlade 7700.
3. A benchmark so they can see actual performance and decide for themselves.
4. Instructions to expose the local Ollama endpoint to n8n on the same LAN.

Specific use cases, workflow design, and n8n node configuration are out of scope — those are the user's domain.

## Solution

A written guide that covers: (1) hardware capability reality-check for ZimaBlade 7700 + Gemma 4 E4B, (2) installing Ollama and pulling the model at Q4_K_M quantization, (3) verifying basic generation works, (4) exposing Ollama on the LAN so n8n can reach it, (5) a basic connectivity smoke test from n8n, and (6) a benchmark recipe so the user can measure actual tok/s and make an informed decision about hardware sufficiency.

## User Stories

1. **As the user, I want to know whether my ZimaBlade 7700 can run Gemma 4 E4B before I invest time installing it.**
   - **Given** the ZimaBlade 7700 has a Celeron J4125 CPU, 16GB LPDDR4 RAM, and no discrete GPU
   - **When** the user reads the hardware capability section
   - **Then** they see a clear verdict: E4B at Q4_K_M will fit in RAM and run, but at ~2–5 tok/s on CPU only
   - **And** they see what "2–5 tok/s" means in practical terms (usable for async tasks, too slow for interactive chat)
   - **And** they see the concrete conditions under which they should consider more capable hardware

2. **As the user, I want to install Ollama and Gemma 4 E4B on the ZimaBlade 7700 at a quantization that fits 16GB CPU-only inference, so that the local LLM endpoint exists.**
   - **Given** the ZimaBlade 7700 is on the LAN, has 16GB RAM, no discrete GPU, and an OS capable of running Ollama (Linux x86_64)
   - **When** the user follows the install steps in the guide
   - **Then** `ollama run gemma4:e4b` returns a valid completion to a test prompt within 60 seconds of warm start
   - **And** RAM usage during inference stays under ~12GB so the OS stays responsive

3. **As the user, I want the ZimaBlade 7700's Ollama endpoint reachable from my n8n instance, so that n8n can call it.**
   - **Given** Ollama is running on the ZimaBlade 7700 and n8n runs on a host with network access to the same LAN
   - **When** the user configures Ollama to bind on `0.0.0.0:11434` (or documented equivalent)
   - **Then** an HTTP request from the n8n host to `http://<zimablade-ip>:11434/api/tags` returns a valid response
   - **And** the guide warns about *not* exposing port 11434 outside the LAN

4. **As the user, I want a benchmark recipe to measure actual tok/s on my ZimaBlade 7700, so that I can decide if this hardware is sufficient or if I need more capable hardware.**
   - **Given** Ollama with E4B is installed
   - **When** the user runs the documented benchmark command (a simple generation-tok/s test with a fixed text prompt)
   - **Then** the output prints generation tok/s
   - **And** the guide explains how to interpret it (e.g., "if generation tok/s is 2–5, your workloads will run but slowly; if < 2, consider more capable hardware")

5. **As the user, I want the guide to be honest about what won't work, so that I don't waste time chasing a target that's physically impossible on this hardware.**
   - **Given** the ZimaBlade 7700 has no GPU and a low-power CPU
   - **When** the user reads the guide
   - **Then** it states explicitly that 30 tok/s is unachievable on this hardware (realistic range for E4B on ZimaBlade 7700 CPU-only is 2–5 tok/s)
   - **And** it tells the user the conditions under which they should re-open the "buy more capable hardware" question (e.g., benchmark below acceptable floor)

## Implementation Decisions

- **Quantization: Q4_K_M only.** For a 16GB CPU-only ZimaBlade 7700, Q4_K_M is the single recommended quantization. Q8 is noted as not fitting; lower quants are not recommended.
- Ollama vs. llama.cpp directly
- OS recommendation for the ZimaBlade 7700 host (likely Debian / Ubuntu Server)

## Testing Decisions

For a research-doc run, "tests" are: each user story's Given-When-Then runnable by the user as a manual verification step. The guide must include a verification checklist matching the acceptance criteria above.

## Out of Scope

> "Cases / aesthetics / RGB" — cut.
> "Quiet / silent operation as a hard requirement" — cut.
> "Multi-GPU or upgrade-path-to-second-GPU" — cut.
> "NVMe / fast storage requirement" — cut.
> "Running models larger than E4B as a hard requirement" — cut as hard requirement.
> "Fine-tuning / training on this rig" — cut hard. Inference only.
> "Co-hosting Whisper / TTS / image-generation alongside the LLM" — cut.
> "Networking / remote access from outside LAN" — cut.

Additional cuts:
> Specific n8n workflow design — cut. The guide covers connectivity only; how the user builds workflows is their domain.
> API-fallback architecture in n8n — cut. Whether to use Gemini API as primary with local fallback is a workflow design decision, not a hardware/setup concern.
> Bank-statement-specific processing logic — cut. The user confirmed: "it might not be bank statement in the end."
> Multimodal input path discussion (Path A vs Path B) — cut as use-case-specific. The guide covers that E4B is multimodal-capable; how the user feeds documents is their decision.
> Buying any new hardware — cut for this run. (Re-openable in a follow-up run if the benchmark shows the ZimaBlade 7700 is insufficient.)
> Targeting 30 tok/s on the local path — cut as physically impossible on ZimaBlade 7700.

## Anti-goal

> "A homelab rabbit hole. It must never become a project where I'm spending weekends tuning ROCm drivers or flashing BIOS to get 2 more tok/s. I want a parts list, I buy it, I install Ollama, it works." (Load-bearing — confirmed by user.)

Plus three secondary anti-goals (all confirmed):
> "A $1500 build that crept up from $400."
> "Cloud-dependent in disguise."
> "A space heater."

## Supersedes

None. This is the first run in this project.

## Open Questions

(To be resolved in Design via research subagents and one more user pass.)

- What OS to install fresh on the ZimaBlade 7700 after wiping TrueNAS Scale? Affects install steps. Likely lightweight Debian/Ubuntu Server or Debian minimal.
- Where does n8n itself run (same ZimaBlade 7700, different host, Docker, cloud)? Affects networking decisions in story #3.
- Thermal throttling expectations for sustained J4125 inference load — to be researched in Design.
- **Resolved:** 32GB eMMC 5.1. Tight but workable: OS (~10GB) + E4B Q4_K_M (~5GB) + headroom = ~15GB free. No room for multiple models or large swap. Guide must warn about storage constraint.

## Further Notes

- Sibling artifacts in this run folder: `interview.md` (Explore output).
