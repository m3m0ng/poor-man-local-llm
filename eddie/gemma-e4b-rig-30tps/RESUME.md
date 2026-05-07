# Resume notes — gemma-e4b-rig-30tps

**Paused:** 2026-05-07, mid-Define.

## What's done
- Explore phase complete (`interview.md`).
- PRD draft written (`prd.md`) with 6 user stories + Given-When-Then.
- Model facts verified via web (Gemma 4 released April 2026; E4B is on-device only, NOT hosted on AI Studio).
- Locked in: **Path B (multimodal direct, no OCR)** as primary input path; Path A (Tesseract) as contingency.

## Where we stopped
Mid-Define probing. PRD has Open Questions still unresolved:
1. What OS is currently on the Zimaboard? (Affects install steps.)
2. What is the trigger source for the bank-statement workflow — manual upload, watched folder, email, something else?
3. Where does n8n run (same Zimaboard, different host, Docker, cloud)?

Still owed in Define before gate-to-Design:
- YAGNI walkthrough of all 6 user stories.
- Anti-pattern probe.
- Edge-case probe (what happens when Zimaboard offline, when API quota hits, when bank statement is corrupt PDF, etc.).

## To resume
Run `/eddie` — orchestrator will detect `.eddie-current` and offer to resume this run. Pick up at "finishing Define probes."
