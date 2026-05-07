# gemma-e4b-rig-30tps — Interview

## Phase 1 — Vision

**Who it's for:** Single user (the project owner) running Gemma 3n E4B locally on one machine, integrated with a personal n8n instance for async workflow tasks. Primary workload: processing bank statements (privacy-sensitive, multimodal — PDFs/images). Secondary: occasional interactive chat and serving as fallback for non-sensitive workflows.

**Why now:** User is starting to wire personal-finance / sensitive-document workflows into n8n. Bank statements cannot be sent to a hosted API on principle, so a local-capable inference path is needed before those workflows can be built. E4B chosen because it fits a floor-budget used-hardware build *and* is multimodal (text + image + audio).

**Success picture (synthesis — user did not give a verbatim 6-month picture):**
> n8n routes bank-statement workflows to a local Ollama instance running Gemma 3n E4B. Non-sensitive workflows use Gemini API free tier with the local box as automatic fallback. Local box handles ~30 tok/s on chat as a comfort target so it stays usable for occasional interactive use.

**Build-cost vs. alternatives:**
- Free Gemini/Gemma API tier (~1,500 req/day) was considered and is **adopted as the default path for non-sensitive workloads.** It is not sufficient for bank-statement processing because the data is privacy-sensitive.
- Existing hardware was inventoried: Zimaboard (16GB, better-CPU SKU) and an i5 2nd-gen / 8GB box. Zimaboard could run E4B on CPU at ~2–5 tok/s (acceptable for async only, fails the 30 tok/s chat-headroom target). i5 2nd gen ruled out (Sandy Bridge, AVX1 only, 8GB binding).
- Conclusion: a small new (used-parts) build IS justified by the bank-statement privacy constraint plus the chat-headroom target. This is not a hobby-only build.

## Phase 3 — Scope

**Anti-goals (all four accepted by user):**
1. Must never become a homelab rabbit hole — no driver tuning, no exotic GPUs, no BIOS flashing. *Load-bearing for this run.*
2. Must never creep from ~$400 to $1500.
3. Must never quietly depend on a paid API — local path must work fully standalone for bank statements.
4. Must never become a 400W always-on space heater.

**What user brings:**
- Existing n8n instance (deployment unspecified — to be confirmed in Define if relevant).
- Spare Zimaboard (16GB, better-CPU) — eligible as the *fallback / always-on* host if useful.
- Spare i5 2nd-gen + 8GB (ruled out for inference).
- Comfort with installing Ollama and wiring n8n nodes; no comfort assumed with kernel/driver tuning.

**Where the gaps are (deferred to Design's research):**
- Concrete used-parts pricing for cheapest GPU that achieves ≥30 tok/s on Gemma 3n E4B (Q4) with multimodal headroom.
- CPU/RAM/PSU/mobo pairings that don't bottleneck a single inference GPU at this budget tier.
- Idle wattage of candidate builds (anti-goal #4).
- Whether Zimaboard CPU-only inference is fast enough to absorb the bank-statement workload by itself, eliminating the need for any new build.
- OS recommendation for the inference host (Linux vs. Windows) given Ollama + n8n integration.

**Out of scope for v1:**
- Cases / aesthetics / RGB.
- Quiet / silent operation as a hard requirement.
- Multi-GPU or upgrade-path-to-second-GPU.
- NVMe / fast storage requirement (any used SATA SSD acceptable).
- Running models larger than E4B as a *hard* requirement (VRAM headroom kept as soft nice-to-have).
- Fine-tuning / training on this rig — inference only.
- Co-hosting Whisper / TTS / image-generation alongside the LLM.
- Networking / remote access from outside LAN.

**In scope (kept):**
- Power-efficiency / idle wattage as a soft constraint (per anti-goal #4).
- OS / software stack recommendation for the inference host.
- Some VRAM headroom beyond strict E4B minimum (soft).
