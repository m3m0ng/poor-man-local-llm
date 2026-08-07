#!/usr/bin/env bash
# Sustained-load throttling test (issue #6). Runs the same prompt N times
# back-to-back against one model, logging CPU temp/MHz before each run via
# lm-sensors, so first-vs-last tok/s and temp can be compared.
#
# Prereq: sudo apt install lm-sensors && sudo sensors-detect (accept defaults)
#
# Usage: bench/thermal/run.sh <model> [iterations]
set -euo pipefail

MODEL="${1:-}"
ITER="${2:-15}"
if [[ -z "$MODEL" ]]; then
  echo "Usage: $0 <model> [iterations]" >&2
  exit 1
fi

command -v sensors >/dev/null || { echo "lm-sensors not installed — run: sudo apt install lm-sensors && sudo sensors-detect" >&2; exit 1; }

PROMPT="Summarize the following document chunk in exactly two sentences. Document: \"Monthly Account Statement - Checking Account ending in 4471. Statement period: March 1-31, 2026. Opening balance \$2,340.18. Closing balance \$1,987.42. 14 transactions recorded, including a rent payment of \$1,200.00 and a payroll deposit of \$1,200.00. No overdraft fees. Account in good standing.\""

for ((i = 1; i <= ITER; i++)); do
  echo "===== iteration $i/$ITER ====="
  echo "--- sensors before ---"
  sensors
  echo "--- generation ---"
  echo "$PROMPT" | ollama run "$MODEL" --verbose
  echo
done
