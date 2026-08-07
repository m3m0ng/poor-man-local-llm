#!/usr/bin/env bash
# Run the extraction-accuracy eval (eval/samples.json) against one Ollama
# model. Prints model output for each sample so it can be saved and scored
# with eval/score.py.
#
# Reasoning is disabled by default (--think=false), matching the recommendation
# in RESULTS.md: for the >=1.7B models it is faster and never less accurate.
# Pass --think to keep reasoning on (correct for qwen3:0.6b, where the
# reasoning phase is load-bearing for accuracy).
#
# Usage: eval/run.sh <model> [--think] > eval/out-<model>.jsonl
set -euo pipefail

MODEL="${1:-}"
if [[ -z "$MODEL" ]]; then
  echo "Usage: $0 <model> [--think]" >&2
  exit 1
fi

# Default to no-think; `--think` restores reasoning.
THINK_FLAG="--think=false"
if [[ "${2:-}" == "--think" ]]; then
  THINK_FLAG=""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLES="$SCRIPT_DIR/samples.json"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

LEN=$(jq 'length' "$SAMPLES")
for ((i = 0; i < LEN; i++)); do
  ID=$(jq -r ".[$i].id" "$SAMPLES")
  TEXT=$(jq -r ".[$i].text" "$SAMPLES")
  PROMPT="Extract the following fields from the text below and respond with ONLY valid JSON, no markdown fences, no explanation. Keys: date (YYYY-MM-DD), amount (numeric string, no currency symbol), payee, transaction_type. Text: \"$TEXT\""
  # shellcheck disable=SC2086 # THINK_FLAG is intentionally unquoted (may be empty)
  RAW=$(echo "$PROMPT" | ollama run "$MODEL" $THINK_FLAG)
  jq -n --arg id "$ID" --arg model "$MODEL" --arg raw "$RAW" '{id: $id, model: $model, raw: $raw}'
done
