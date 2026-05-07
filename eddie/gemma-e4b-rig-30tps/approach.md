# gemma-e4b-rig-30tps — Approach

## Approach Summary

Wipe the ZimaBlade 7700 and install a lightweight Debian-based server OS, then install Ollama, pull Gemma 4 E4B in Q4_K_M quantization, and verify basic inference. Expose the Ollama API on the LAN so n8n can reach it. Run a benchmark to measure actual generation tok/s. The resulting guide will give the user an honest reality check on hardware capability before they invest time in dependent workflows.

## Steps Overview

1. **Wipe & OS install** — Flash Debian 12 minimal netinst (or Ubuntu Server 24.04 LTS) to the 32GB eMMC, then configure networking and SSH so the device is reachable headless.
2. **Install Ollama & pull E4B** — Install Ollama via official install script, pull `gemma4:e4b` (default tag ~9.6GB on disk; this is Q4_K_M), run a basic smoke-test prompt to confirm inference works, assess RAM usage, and set eMMC-friendly storage habits (swap tuning, `noatime`, minimal log churn).
3. **LAN exposure & n8n connectivity** — Configure Ollama to bind on `0.0.0.0:11434` (or use a reverse proxy / firewall rule), verify reachability from the n8n host, and document the security warning about keeping 11434 off WAN.
4. **Benchmark & go/no-go** — Run a standardized generation-tok/s test with a fixed text prompt, explain what the number means in real terms, and lay out clear conditions for when the user should consider more capable hardware.

## Tools / Materials / Inputs Needed

| Item | Purpose | Source / Where to get | Cost |
|------|---------|------------------------|------|
| ZimaBlade 7700 | Inference host | Already owned | $0 |
| USB flash drive (≥2GB) | OS installer | User already has | $0 |
| Internet access on ZimaBlade 7700 | Download Ollama + model | Existing home network | $0 |
| n8n host | Workflow engine that calls Ollama | Already running (location TBD) | $0 |

## Decision Points & Branches

- **Condition:** User prefers minimal RAM overhead vs. widest forum support
  - **Path A (recommended):** Debian 12 minimal netinst. Smaller footprint (~1GB RAM idle), faster cold boots, less background churn. Slightly more manual for first-time users, but user is comfortable with bare-metal install.
  - **Path B:** Ubuntu Server 24.04 LTS. Larger footprint (~1.5GB+ idle) but Ollama install is one-liner-copy-paste from ollama.com, and Ubuntu-specific forum threads are more common if something breaks.
  - **Reasoning:** Debian Path A keeps more RAM free for model weights. On 16GB total, every 500MB matters. Path B is acceptable if the user wants slightly more hand-holding.

- **Condition:** n8n runs on the same ZimaBlade 7700 vs. a different host
  - **Path A (recommended if n8n is external):** Bind Ollama on `0.0.0.0:11434` and firewall it to LAN only (e.g., `ufw allow from 192.168.x.0/24 to any port 11434`). This is the simplest, most robust integration.
  - **Path B (if n8n is co-hosted):** Bind on `127.0.0.1:11434` and have n8n call `localhost:11434`. No firewall needed, but both services compete for CPU/RAM.
  - **Reasoning:** The PRD user story assumes n8n runs on a separate host, so Path A is the primary documented path. Path B gets a sidebar note.

- **Condition:** Whether to use swap on 32GB eMMC
  - **Path A (recommended):** Create a small swapfile (1–2GB) with `vm.swappiness=10` to avoid OOM kills, but keep it minimal because eMMC writes wear the flash.
  - **Path B:** No swap at all. Eliminates flash wear, but if inference pushes over committed RAM, the OOM killer terminates Ollama.
  - **Reasoning:** With 16GB RAM and a ~5GB model + system overhead, there's headroom, but during model load (weights + context) spikes can briefly exceed available memory. A small, low-swappiness swap is a safer safety net.

- **Condition:** Performance comes in below the 2 tok/s floor during benchmarking
  - **Path A:** Accept the limitation for async/non-interactive workloads only.
  - **Path B:** Hardware upgrade recommendation triggered — a low-profile used GPU (e.g., GTX 1060 6GB, RTX 3050, or similar) on a cheap used mini-ITX board would hit 30+ tok/s for under ~$200.
  - **Reasoning:** This is the user's go/no-go decision, not architecturally prescriptive. The guide makes the threshold explicit and provides the criteria.

## Open Risks

- **No verified J4125 + Gemma 4 E4B benchmark exists.** Current tok/s estimate (0.5–2 tok/s for 4–8B models, and Gemma 4 E4B may be 2–5 tok/s at Q4_K_M due to smaller effective params and better KV-cache efficiency) is architecture-based, not measured. This translates to a high uncertainty band on the "go/no-go" decision. *Mitigation:* specify that the guide provides the benchmark recipe so the user measures their own hardware, rather than relying on the estimate.
- **32GB eMMC is tight.** OS + one model leaves ~15GB free, but Ollama caches in `~/.ollama/models`; if the user pulls a second model or accidentally pulls the wrong tag, they run out of storage. Ollama then fails with a cryptic write error. *Mitigation:* include a pre-install disk-check and document how to remove unused models.
- **Thermal throttling on sustained load.** The J4125 is a 10W TDP passively-cooled part. Sustained 100% CPU during a long inference session may cause frequency drop after several minutes, lowering tok/s mid-run. *Mitigation:* mention this as a known behavior and advise the user that short bursts (typical n8n workflow calls) are unlikely to trigger throttling; long continuous loads may.
- **eMMC read throughput may bottleneck cold model load.** eMMC 5.1 sequential read is ~200–400MB/s, but random reads are far slower. Loading ~5GB of weights into RAM may take 30–60 seconds, meaning the first call after Ollama starts (cold start) has high latency even before inference begins. *Mitigation:* document that warm inference is acceptable; cold-start latency is a one-time cost per Ollama restart.

## PRD Alignment

| PRD User Story | Step Number(s) |
|-----------|----------------|
| 1 — hardware capability reality-check | 1, 4 |
| 2 — install Ollama & pull E4B | 2 |
| 3 — LAN exposure & n8n connectivity | 3 |
| 4 — benchmark & go/no-go | 4 |
| 5 — honest limits disclosure | 1, 4 (Open Risks) |
