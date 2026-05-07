# gemma-e4b-rig-30tps — Run Deliverables

**Status:** Done (2026-05-07)
**Type:** research-doc
**Scope:** Hardware capability assessment and setup guide for running Gemma 4 E4B on a ZimaBlade 7700, wired into n8n.

## Output artifacts

| File | Phase | Description |
|------|-------|-------------|
| [interview.md](interview.md) | Explore | Vision, scope, anti-goals, and constraints from the initial interview |
| [prd.md](prd.md) | Define | PRD with 5 user stories, Given-When-Then acceptance criteria, locked decisions (Q4_K_M, Path B multimodal), out-of-scope cuts, open questions |
| [approach.md](approach.md) | Design | Step-by-step approach: wipe + OS install → Ollama + E4B → LAN exposure → benchmark & go/no-go. Includes ADR-style decision points, tools/materials, open risks, and PRD alignment table |

## Locked decisions

- **Hardware:** ZimaBlade 7700 (Celeron J4125, 16GB LPDDR4, 32GB eMMC 5.1), no GPU, no new hardware purchase
- **Quantization:** Q4_K_M only
- **OS:** Debian 12 minimal recommended (Ubuntu Server acceptable)
- **Install target:** Fresh wipe of existing TrueNAS Scale

## Key risks surfaced

- No verified J4125 + Gemma 4 E4B benchmark exists — user must measure their own hardware
- 32GB eMMC fits only 1–2 models; storage management is critical
- Thermal throttling possible under sustained load
- eMMC cold-start latency: 30–60s model load time

## Next step (outside EDDIE)

Follow `approach.md` to execute the setup. If benchmark shows < 2 tok/s and the user's workload is unacceptably slow, open a new EDDIE run for hardware upgrade research.
