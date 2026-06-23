# Current Plan — Local LLM on ZimaBlade 7700

> Latest run: **apollolake-e4b-reality-check** (May 2026)
> This is a consolidated plan from the EDDIE research methodology (Explore → Define → Design).
> Full artifacts in [`eddie/apollolake-e4b-reality-check/`](eddie/apollolake-e4b-reality-check/).

---

## What we're doing

Running a local LLM on a **ZimaBlade 7700 (Intel Apollo Lake: N3450/J3455/E3950)** to extract structured data from bank statements once per month via an automated n8n workflow. Privacy-sensitive documents cannot go to a hosted API.

## Hardware Reality (confirmed on the box)

- **CPU:** Intel Celeron **J3455** (Apollo Lake / Goldmont), 4C4T, 1.5 GHz base / 2.3 GHz burst (800 MHz idle), ~4 MiB L2 (2 MiB × 2 modules)
- **No AVX/AVX2 — confirmed:** flags top out at `sse4_2` (has AES-NI + SHA-NI, no AVX)
- **RAM:** 16 GB DDR3L-1333, **single channel (~10.6 GB/s)** — this bandwidth is the real bottleneck for CPU inference
- **Storage:** 32 GB eMMC (29 GB usable), non-rotational; **currently 83% full, ~4.3 GB free** with E4B installed
- **No GPU**
- **OS:** Debian 13 (trixie), kernel 6.12
- **Ollama:** 0.23.2 (satisfies the ≥ 0.5.2 no-AVX requirement)
- **Estimated performance:** 0.5–1.5 tok/s on 4B, 1.5–4.5 tok/s on 1.5–2.7B
- **Measured:** Gemma 4 E4B = **1.07**, E2B = **1.91**, Qwen3 1.7B = **2.32**, Phi-2 = **2.69** tok/s — see [`RESULTS.md`](RESULTS.md)

> **Why the speeds land where they do:** CPU LLM inference is memory-bandwidth
> bound. At ~10.6 GB/s single-channel, throughput ≈ bandwidth ÷ model size.
> E4B (9.6 GB) → ~1.1 tok/s predicted vs **1.07 measured** — the bandwidth
> ceiling, not the clock speed, is what caps this box.

## Anti-Goals (locked)

- No homelab rabbit hole — no driver tuning, no BIOS flashing
- No buying new hardware for this
- No paid API for bank statements
- No space heater / high-wattage system

## Step-by-Step Plan

### 1. Install Debian 12 on the ZimaBlade

Flash Debian 12 minimal netinst to USB → boot ZimaBlade → install to 32GB eMMC.

### 2. Harden eMMC for longevity

```bash
# /etc/fstab
# Add: noatime to root partition
# Add: tmpfs /tmp tmpfs defaults,noatime,size=2G 0 0
# Add: tmpfs /var/log tmpfs defaults,noatime,size=100M 0 0

# /etc/sysctl.d/99-swappiness.conf
vm.swappiness = 10

# Enable periodic TRIM
sudo systemctl enable fstrim.timer

# /etc/systemd/journald.conf
# Set: Storage=volatile, SystemMaxUse=50M
```

### 3. Install Ollama ≥ v0.5.2

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama --version  # must be ≥ 0.5.2
```

The standard install works — the binary auto-detects no-AVX and uses the `cpu` runner.

### 4. Pull Gemma 4 E4B

```bash
df -h ~  # check ≥ 10GB free
ollama pull gemma4:e4b
```

E4B pulls as **~9.6 GB** (measured — larger than a typical Q4_K_M 4B; budget
disk accordingly). It fits in 16 GB RAM with headroom. Verify with a smoke test.

### 5. Benchmark

```bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "gemma4:e4b",
  "prompt": "Extract the following fields from this bank statement: date, amount, payee, transaction type.",
  "stream": false
}' | jq '{tok_per_sec: (.eval_count / .eval_duration * 1e9)}'
```

### 6. Decide: E4B or Fallback

| tok/s | Decision |
|-------|----------|
| > 2 | Keep E4B — great |
| 1–2 | Try E4B, but fallback recommended |
| < 1 | Switch to fallback model |

If switching:

```bash
ollama rm gemma4:e4b
ollama pull phi:2.7b     # recommended fallback (~1.6GB)
# or: ollama pull qwen2.5:1.5b  # alternative (~1.0GB)
```

Re-run benchmark with the fallback model.

### 7. Expose Ollama on LAN

```bash
sudo systemctl edit ollama.service
```

Add:

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Restrict to LAN only:

```bash
sudo ufw allow from 192.168.0.0/24 to any port 11434
```

⚠️ Ollama has no authentication. Never expose outside LAN.

### 8. Verify n8n Connectivity

From the n8n host:

```bash
curl http://<zimablade-ip>:11434/api/tags
```

Check n8n timeout settings:

```bash
cat /proc/$(pgrep -f n8n)/environ | tr '\0' '\n' | grep TIMEOUT
```

Set if needed:

```bash
# Docker env vars or systemd Environment=
EXECUTIONS_TIMEOUT_MAX=600        # 10 min per workflow
N8N_AI_TIMEOUT_MAX=1800000       # 30 min for LLM HTTP calls (ms)
```

### 9. Run Monthly Workflow

1. Drop bank statement into NAS watched folder or Google Drive
2. n8n trigger fires → sends to Ollama on ZimaBlade
3. Ollama returns structured data
4. n8n writes output to spreadsheet/database

The user designs their own n8n workflow — this plan covers only connectivity.

## Fallback Model Recommendation

| Model | Size | Est. tok/s | Notes |
|-------|------|-----------|-------|
| **Gemma 4 E2B** (`gemma4:e2b`) | ~2 GB | **1.91 measured** | Highest quality, reasons before answering; 21s cold load |
| **Qwen3 1.7B** (`qwen3:1.7b`) | ~1.4 GB | **2.32 measured** | Best balance — reasons, fast-ish, 2.5s load |
| **Phi-2 2.7B** (`phi:2.7b`) | ~1.6 GB | **2.69 measured** | Fastest; good instruction-following, no reasoning |
| Gemma 2B | ~1.4 GB | 1.5–4 | Google-trained, good text understanding |

## Open Risks

- ~~**No verified Apollo Lake benchmarks exist** — tok/s are estimates.~~ **Resolved:**
  all four models measured on the J3455 ([`RESULTS.md`](RESULTS.md)).
- **Thermal throttling** — passively cooled ZimaBlade may slow down under sustained inference. Still unmeasured.
- **Cold-start latency** — confirmed: loading from eMMC took **21–29s** (E2B 21.1s, E4B 28.8s).
- **32GB eMMC is tight — confirmed real:** only **4.3 GB free** with E4B (9.6 GB) installed,
  which already forced removing `phi` and `gemma4:e2b`. You can hold E4B **or** a couple of
  small models, not both. Keep `ollama rm` in the loop.
- **No Ollama auth** — firewall restriction is critical for LAN binding.

## Files

| File | What |
|------|------|
| [`eddie/apollolake-e4b-reality-check/interview.md`](eddie/apollolake-e4b-reality-check/interview.md) | Vision, scope, anti-goals |
| [`eddie/apollolake-e4b-reality-check/prd.md`](eddie/apollolake-e4b-reality-check/prd.md) | Requirements, user stories, acceptance criteria |
| [`eddie/apollolake-e4b-reality-check/approach.md`](eddie/apollolake-e4b-reality-check/approach.md) | Full design with ADR-style decisions |
| [`eddie/index.md`](eddie/index.md) | All EDDIE runs in this project |
