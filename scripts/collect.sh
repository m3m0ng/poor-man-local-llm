#!/usr/bin/env bash
# One-shot data collection for the v1.0 closure checklist.
#
# Run this ON THE ZIMABLADE, redirect it to a file, and paste the file back.
# It is READ-ONLY: it inspects configuration and runs models, but changes
# nothing. Use scripts/lan-setup.sh for the one step that does change state.
#
# Covers in a single session:
#   - LAN/firewall verification evidence          (issue #17)
#   - Extraction-accuracy eval for both models    (issue #4)
#   - Thermal observation, first vs last          (folded in from #6)
#
# Usage:
#   scripts/collect.sh > collect-$(date +%Y%m%d).txt 2>&1
#
# Takes roughly 25-40 min, dominated by the E4B eval. Nothing waits on you.
set -uo pipefail   # deliberately no -e: a failing probe must not abort the run

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

section() { printf '\n\n========== %s ==========\n' "$1"; }
probe()   { printf '\n--- %s ---\n' "$1"; }

printf 'poor-man-local-llm — collection run\nDate: %s\nHost: %s\n' \
  "$(date -Is)" "$(hostname)"

# ---------------------------------------------------------------- environment
section "1. ENVIRONMENT"

probe "OS / kernel";      uname -a; cat /etc/os-release 2>/dev/null | head -2
probe "CPU";              lscpu 2>/dev/null | grep -Ei 'model name|^cpu\(s\)|mhz' | head -6
probe "AVX check";        grep -o -m1 -E 'avx[0-9_]*|sse4_2' /proc/cpuinfo | sort -u | tr '\n' ' '; echo
probe "Memory";           free -h
probe "Disk";             df -h / /root 2>/dev/null | sort -u
probe "Ollama version";   ollama --version 2>&1
probe "Installed models"; ollama list 2>&1

# --------------------------------------------------------- LAN + firewall (#17)
section "2. LAN EXPOSURE + FIREWALL  (issue #17)"

probe "Ollama systemd environment"
systemctl show ollama.service -p Environment 2>&1
echo "^ expect OLLAMA_HOST=0.0.0.0:11434 for LAN access"

probe "What is actually listening on 11434"
{ ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null; } | grep -E '11434|LISTEN' | head -10
echo "^ 0.0.0.0:11434 = LAN-reachable; 127.0.0.1:11434 = localhost only"

probe "Firewall status"
if command -v ufw >/dev/null; then
  sudo -n ufw status verbose 2>&1 || \
    echo "(needs sudo — re-run this script with sudo, or run 'sudo ufw status verbose' by hand)"
else
  echo "ufw NOT INSTALLED — port 11434 has no firewall in front of it."
  echo "Ollama has no authentication. Install ufw before binding to 0.0.0.0."
fi

probe "Local API reachability"
curl -s -m 10 http://localhost:11434/api/tags >/dev/null \
  && echo "localhost:11434 OK" || echo "localhost:11434 FAILED"

probe "This host's LAN addresses"
ip -4 addr show 2>/dev/null | awk '/inet /{print $2, $NF}' | grep -v '127.0.0.1'
cat <<'EOF'

>> MANUAL STEP — cannot be done from this box:
>>   From the n8n host, run:   curl http://<zimablade-ip>:11434/api/tags
>>   Paste the result. That single curl is the only thing proving the
>>   network path n8n depends on actually works.
EOF

# ------------------------------------------------------- accuracy eval (#4)
section "3. EXTRACTION-ACCURACY EVAL  (issue #4)"

if [[ ! -f "$REPO_DIR/eval/run.sh" ]]; then
  echo "eval/ harness missing — merge the branch from issue #16 first. SKIPPING."
else
  have_model() { ollama list 2>/dev/null | awk 'NR>1{print $1}' | grep -qx "$1"; }

  # Default pick + fast fallback. Both no-think, per RESULTS.md.
  for M in gemma4:e4b qwen3:1.7b; do
    probe "eval: $M (--think=false)"
    if ! have_model "$M"; then
      echo "NOT INSTALLED — skipping."
      echo "(disk is tight: 'ollama pull $M' may need an 'ollama rm' first)"
      continue
    fi
    OUT="$REPO_DIR/eval/out-${M//[:\/]/-}.jsonl"
    echo "start: $(date -Is)"
    if "$REPO_DIR/eval/run.sh" "$M" > "$OUT" 2>/dev/null; then
      echo "end:   $(date -Is)"
      echo "raw output saved: $OUT"
      probe "score: $M"
      python3 "$REPO_DIR/eval/score.py" "$OUT" 2>&1
    else
      echo "eval run FAILED for $M"
    fi
  done
fi

# ------------------------------------------------- thermal observation (#6)
section "4. THERMAL OBSERVATION  (folded in from issue #6)"

if command -v sensors >/dev/null; then
  probe "Temps after the sustained eval above"
  sensors 2>&1
else
  echo "lm-sensors not installed — no temperature reading."
  echo "Optional: sudo apt install lm-sensors && sudo sensors-detect"
fi

probe "Current CPU MHz (throttle indicator)"
grep -i 'mhz' /proc/cpuinfo 2>/dev/null | head -4
echo "^ J3455: 1.5 GHz base, 2.3 GHz burst, 800 MHz idle."
echo "  Sitting near 800 MHz right after a long run suggests throttling."

section "DONE"
cat <<'EOF'
Paste this whole file back into the Claude session.

Still needed from you, and only these:
  1. The curl output from the n8n host (section 2)
  2. One statement through the n8n workflow (issue #8)
EOF
