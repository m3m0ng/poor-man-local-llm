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

### 1. Install Debian on the ZimaBlade ✅ done

Flash a Debian minimal netinst to USB → boot ZimaBlade → install to 32GB eMMC.

> **Done:** the box runs **Debian 13 (trixie), kernel 6.12**. The original plan
> said Debian 12; 13 was current at install time and works fine.

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

### 5. Benchmark ✅ done

Use the canonical suite — it replaced the old `curl`/`jq` one-liner, which
measured a single ad-hoc prompt and needed extra tooling:

```bash
bench/run.sh gemma4:e4b          # three fixed prompts, Ollama's own --verbose stats
bench/run.sh qwen3:1.7b
```

See [`bench/README.md`](bench/README.md) for the no-repo-on-the-box variant.

### 6. Decide: E4B or Fallback ✅ decided

The original gate was "> 2 tok/s keep E4B, < 1 switch." **E4B measured 1.07
tok/s** — landing in the ambiguous middle band, where the gate said "fallback
recommended."

**We kept E4B anyway, and the gate was wrong.** It assumed speed was the
deciding factor. For a monthly unattended batch nobody waits on, throughput
below the interactive threshold costs nothing, while accuracy on financial data
costs a great deal. On the `bench/` suite E4B was the only model to get every
value *and* every format constraint right.

**Outcome:** `gemma4:e4b` with `--think=false` is the default;
`qwen3:1.7b --think=false` is the fast fallback. Phi-2 is ruled out — it failed
all three suite prompts. Full reasoning in [`RESULTS.md`](RESULTS.md).

### 7. Expose Ollama on LAN

Scripted — it firewalls *before* binding, so the port is never briefly open and
unfiltered:

```bash
scripts/lan-setup.sh 192.168.0.0/24 --dry-run   # show the changes
scripts/lan-setup.sh 192.168.0.0/24             # apply, with confirmation
```

Equivalent by hand: a systemd override setting
`Environment="OLLAMA_HOST=0.0.0.0:11434"`, `daemon-reload`, `restart ollama`,
plus `ufw allow from <subnet> to any port 11434 proto tcp`.

⚠️ Ollama has no authentication. The firewall rule is the only access control —
never expose outside the LAN.

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

A starter workflow ships with the repo:
[`n8n/extract-statement.json`](n8n/extract-statement.json) — import it, set your
ZimaBlade IP in the **Config** node, and run. It handles the JSON-parse failure
mode explicitly and reports Ollama's own timing.

1. Drop bank statement into NAS watched folder or Google Drive
2. n8n trigger fires → sends to Ollama on ZimaBlade
3. Ollama returns structured data
4. n8n writes output to spreadsheet/database

Swap the manual trigger and the terminal no-op nodes for your real source and
destination — the middle of the workflow is the part this project settles.

Day-to-day operation: [`OPERATING.md`](OPERATING.md).

## Model Recommendation (all measured)

Every row below is measured on this box — no estimates. Speeds are from the
canonical `bench/` suite in each model's **recommended** mode.

| Model | Size | tok/s | Mode | Role |
|-------|------|-------|------|------|
| **Gemma 4 E4B** (`gemma4:e4b`) | ~9.6 GB | 1.2 | `--think=false` | **Default** — best accuracy, clean sweep on the suite |
| **Qwen3 1.7B** (`qwen3:1.7b`) | ~1.4 GB | 2.5–2.7 | `--think=false` | **Fast fallback** — fastest trustworthy result (2m13s suite) |
| Gemma 4 E2B (`gemma4:e2b`) | ~2 GB | 2.1–2.4 | `--think=false` | Middle ground; no-think fixed its JSON fencing |
| Qwen3 0.6B (`qwen3:0.6b`) | ~522 MB | ~5 | thinking **ON** | Fastest, but miscounts without reasoning |
| ~~Phi-2 2.7B~~ (`phi:2.7b`) | ~1.6 GB | 2.6–3.5 | — | **Avoid for extraction** — failed all three suite prompts |

> Gemma 2B was listed as a candidate in the original plan and never tested; it
> was dropped once four better-characterized models were measured.

**The `--think=false` rule:** for models ≥1.7B, disabling reasoning is a strict
win — faster, never less accurate, and it *fixed* format misses on Qwen3 1.7B
and E2B. At 0.6B the reasoning phase is load-bearing: disabling it introduced a
factual miscount. See [`RESULTS.md`](RESULTS.md).

## Open Risks

- ~~**No verified Apollo Lake benchmarks exist** — tok/s are estimates.~~ **Resolved:**
  all four models measured on the J3455 ([`RESULTS.md`](RESULTS.md)).
- **Thermal throttling** — passively cooled ZimaBlade may slow down under sustained
  inference. Downgraded from a risk to an observation: the workload is one document
  a month, not a sustained batch. The only hint is Phi-2's eval rate drifting
  3.49 → 3.24 → 2.59 tok/s across three back-to-back prompts, which is equally
  explained by the third being a 549-token runaway. Being observed during the
  end-to-end run rather than studied separately.
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
