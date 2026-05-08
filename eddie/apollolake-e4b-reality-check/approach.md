# apollolake-e4b-reality-check — Approach

## Approach Summary

Wipe the ZimaBlade 7700 and install Debian 12 minimal netinst on the 32GB eMMC, optimized for flash longevity. Install Ollama ≥ v0.5.2 (auto-detects no-AVX Apollo Lake CPU), pull Gemma 4 E4B at Q4_K_M, run a benchmark to measure actual tok/s, then decide: keep E4B if ≥ 1 tok/s, switch to a smaller fallback model (Phi-2 2.7B or Qwen2.5-1.5B) if not. Expose Ollama on the LAN for n8n. Output the entire process as a written guide the user can follow step-by-step.

## Steps Overview

1. **Prep & flash Debian 12** — Flash Debian 12 minimal netinst to a USB drive, boot ZimaBlade from USB, install to 32GB eMMC with flash-friendly mount options.
2. **eMMC hardening** — Configure `noatime`, tmpfs for `/tmp` and `/var/log`, enable `fstrim.timer`, tune journald for volatile/minimal logging, set `vm.swappiness=10`.
3. **Install Ollama ≥ v0.5.2** — Use official install script (`curl -fsSL https://ollama.com/install.sh | sh`), verify version, confirm no-AVX auto-detection in server logs.
4. **Pull Gemma 4 E4B** — Pull `gemma4:e4b` (Q4_K_M, ~5GB), verify disk free space with `df -h`, run a smoke test prompt to confirm inference works.
5. **Benchmark E4B** — Run a standardized benchmark using `curl` + `jq` against Ollama's `/api/generate`, capture `eval_count / eval_duration * 1e9` for generation tok/s.
6. **Decide: E4B or fallback?** — If benchmark returns ≥ 1 tok/s, keep E4B. If < 1 tok/s, `ollama rm gemma4:e4b` to free space, then `ollama pull phi2:2.7b` (or `qwen2.5:1.5b`), re-benchmark.
7. **Expose Ollama on LAN** — Configure systemd override to bind Ollama on `0.0.0.0:11434`, add firewall rule to limit access to LAN subnet only.
8. **n8n connectivity smoke test** — From the n8n host, verify reachability with `curl http://<zimablade-ip>:11434/api/tags`. Confirm `EXECUTIONS_TIMEOUT_MAX` and `N8N_AI_TIMEOUT_MAX` are sufficient (≥ 5 minutes execution, ≥ 10 minutes AI HTTP timeout).
9. **Write the guide** — Assemble all steps, command examples, expected output, troubleshooting notes, and the verification checklist into a single document under `guide.md` in the run folder.

## Tools / Materials / Inputs Needed

| Item | Purpose | Source | Cost |
|------|---------|--------|------|
| ZimaBlade 7700 | Inference host | Already owned | $0 |
| USB flash drive (≥ 1GB) | Debian installer | User already has | $0 |
| Ethernet cable + LAN access | Network for Debian install + Ollama pull | Existing network | $0 |
| n8n host (separate machine) | Workflow engine that calls Ollama | Already running | $0 |
| Temporary external hard drive (optional) | Extra storage during model transitions | User can provide | $0 |
| SSH client | Remote access to ZimaBlade after install | Any laptop/desktop | $0 |

## Decision Points & Branches

### 1. OS choice: Debian 12 netinst (recommended) vs Ubuntu Server 24.04

| Factor | Debian 12 | Ubuntu 24.04 |
|--------|-----------|--------------|
| Idle RAM | ~80-120 MB | ~250-400 MB (snapd overhead) |
| Disk footprint | ~650 MB | ~2-3 GB |
| eMMC writes | None unnecessary | snapd + cloud-init write regularly |
| Ollama support | Via upstream install script | Same |
| Community support | Excellent, but less Ollama-specific | More Ubuntu-specific forum threads |

**Recommendation:** Debian 12 netinst. Every 200MB saved matters when the model uses 5GB and the system needs 10GB+ free.

### 2. Benchmarked E4B usable (> 1 tok/s) vs. too slow → fallback

- **Path A (E4B ≥ 1 tok/s):** Keep E4B. Guide documents keeping it for monthly bank statements.
- **Path B (E4B < 1 tok/s):** Document the transition: `ollama rm gemma4:e4b` → `ollama pull phi2:2.7b` → re-benchmark.
- **Reasoning:** The PRD decision table (| >2: E4B \| 1-2: try E4B, fallback recommended \| <1: use fallback |) captured in US4.

### 3. Fallback model: Phi-2 2.7B (recommended) vs Qwen2.5-1.5B vs Gemma 2B

| Model | Size Q4_K_M | Estimated tok/s on Apollo Lake | Extraction quality |
|-------|-------------|-------------------------------|-------------------|
| Phi-2 2.7B | ~1.6 GB | ~1.5-4.5 | Good for structured extraction, Microsoft-trained, strong on instruction-following |
| Qwen2.5-1.5B | ~1.0 GB | ~2-5 | Faster, but smaller = less nuance. Alibaba-trained, strong multilingual |
| Gemma 2B | ~1.4 GB | ~1.5-4 | Google-trained, good for text understanding but less testing on extraction tasks |

**Recommendation:** Phi-2 2.7B as primary fallback. It's the sweet spot: enough parameters for reliable extraction from structured documents, known for instruction-following which matters for "extract these fields" prompts. Qwen2.5-1.5B as alternative if user wants maximum speed.

### 4. Swap: small disk swap vs. zram-only

- **Path A (zram-only, recommended):** No eMMC writes. Compressed RAM swap (~3:1 ratio). 2GB zram = ~6GB effective. Enough as OOM insurance.
- **Path B (4GB disk swap with swappiness=10):** Small safety net on eMMC. Minimal wear at low swappiness.
- **Reasoning:** zram eliminates eMMC wear entirely while still preventing OOM kills. Apollo Lake's RAM bandwidth is the bottleneck for inference, not compression overhead.

### 5. n8n timeout configuration

- **Default:** `EXECUTIONS_TIMEOUT_MAX = 3600` (1 hour), `N8N_AI_TIMEOUT_MAX = 3600000` ms (1 hour). These are generous.
- **Recommendation:** Set `EXECUTIONS_TIMEOUT_MAX = 600` (10 min) and `N8N_AI_TIMEOUT_MAX = 1800000` (30 min) if using E4B. If using fallback, keep defaults.
- **Verification:** Guide includes `cat /proc/$(pgrep -f n8n)/environ | tr '\0' '\n' | grep TIMEOUT` to check current values.

## Open Risks

1. **No verified Apollo Lake model benchmarks exist.** All tok/s numbers are architecture-based estimates. Real-world performance may deviate significantly, especially under thermal throttling. Mitigation: the guide's benchmark step measures actual performance on the user's hardware.

2. **Thermal throttling on sustained load.** Apollo Lake is passively cooled. Sustained inference (long bank statement extraction) may cause frequency drops after 2-5 minutes, lowering tok/s mid-run. Mitigation: short prompts and using fallback model reduce sustained load. Document as known behavior.

3. **eMMC read throughput bottlenecks cold model load.** eMMC 5.1 sequential read is ~200-400 MB/s. Loading ~5GB of weights into RAM on first call after Ollama starts may take 30-60 seconds. Mitigation: document that warm inference is acceptable; cold-start latency is a one-time cost per Ollama restart.

4. **32GB eMMC is tight after OS + E4B + fallback.** OS (~10GB) + E4B (~5GB) + fallback (~1-2GB) + headroom = tight. If user pulls both models simultaneously without cleanup, may hit disk full. Mitigation: pre-install disk check step, document `ollama rm` cleanup flow.

5. **n8n AI node HTTP timeout even with generous settings.** If E4B runs at 0.5 tok/s and the user requests a 400-token output, it takes ~13 minutes (above default 10-min recommendation). Mitigation: document that the fallback model is safer for n8n timeout compliance; set `N8N_AI_TIMEOUT_MAX` aggressively high if sticking with E4B.

6. **Ollama has no authentication.** Binding to `0.0.0.0:11434` exposes the API to all LAN devices. Mitigation: firewall rule restricting port 11434 to known hosts only (or just the n8n host IP).

## PRD Alignment

| PRD User Story | Step Number(s) |
|----------------|----------------|
| US1 — hardware capability reality-check | 1, 2, 5 |
| US2 — install Ollama + pull models | 3, 4 |
| US3 — LAN exposure & n8n connectivity | 7, 8 |
| US4 — benchmark & decision table | 5, 6 |
| US5 — honest limits disclosure | 6, Open Risks |
| US6 — full pipeline smoke test | 8, 9 |

## References

- Research: Ollama on no-AVX CPUs (GitHub issues #2187, #7499; PR #7499 merged Dec 10 2024 → v0.5.2)
- Research: Debian 12 vs Ubuntu Server 24.04 comparison, eMMC longevity configuration, n8n timeout settings
- Prior run: `eddie/gemma-e4b-rig-30tps/approach.md` (J4125-based, superseded by corrected hardware specs)
- PRD: `eddie/apollolake-e4b-reality-check/prd.md`
