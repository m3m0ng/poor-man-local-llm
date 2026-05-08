# apollolake-e4b-reality-check — Interview

## Phase 1 — Vision

**Who it's for:** Single user (the project owner) running a local LLM on their existing ZimaBlade 7700 for privacy-sensitive n8n workflows.

**Why now:** User is wiring personal-finance / bank-statement workflows into n8n. Bank statements cannot be sent to a hosted API on principle, so a local inference path is needed. Apollo Lake hardware reality (N3450/J3455/E3950, 0.5–1.5 tok/s on 4B) discovered after initial assumptions were wrong.

**Success picture (in user's words):**
> "Once a month, I drop a bank statement into a watched folder / Google Drive. n8n picks it up, sends it to the ZimaBlade's local LLM, and writes the extracted data to a spreadsheet or database. I never wait for it, and it never times out."

**Build-cost vs. alternatives:**
- Free Gemini API (~1,500 req/day) ruled out for bank statements on privacy grounds — valid.
- Google Drive's built-in OCR — extracts text but no structured understanding; insufficient alone.
- Smaller local model (Phi-2 2.7B, Qwen2.5-1.5B) — faster on Apollo Lake, may be "good enough" for structured extraction. User will test Gemma 4 E4B first, then fallback to recommended model if too difficult.
- n8n is self-hosted, execution timeout configurable. Default ~5 minutes covers even the slowest inference scenario.

**Frequency:** Once per month, automated (set-and-forget). Documents arrive via local NAS or Google Drive (undecided).

---

## Phase 3 — Scope

**Anti-goals (in user's words):**
> "Must never become a homelab rabbit hole — no driver tuning, no BIOS flashing, no exotic builds."
> "Must never creep into buying new hardware for this specific use case."
> "Must never quietly depend on a paid API for the bank-statement path."
> "Must never become an always-on space heater or high-wattage system."

**What user brings:**
- ZimaBlade 7700 (Intel Apollo Lake N3450/J3455/E3950, 16GB RAM, 32GB eMMC, no GPU)
- Self-hosted n8n instance (already running)
- USB flash drive for OS installer
- Comfort with bare-metal OS install and Ollama setup
- Willingness to accept slow inference if predictable and automated

**Where the gaps are:**
- Document ingestion path (NAS vs Google Drive) not decided — to be addressed in Design
- n8n execution timeout setting not verified — user to check `EXECUTIONS_TIMEOUT` config
- Actual benchmark numbers on Apollo Lake — none exist; user will do real-world testing
- Model choice: Gemma 4 E4B first, fallback to smaller recommended model (Phi-2 2.7B, Qwen2.5-1.5B) if too slow/difficult
- Ollama ≥ v0.5.2 required (no-AVX CPU support)

**Out of scope for v1:**
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
