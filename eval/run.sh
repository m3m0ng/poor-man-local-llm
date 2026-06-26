#!/usr/bin/env bash
# Run the extraction-accuracy eval (eval/samples.json) against one Ollama
# model. Prints model output for each sample so it can be saved and scored
# with eval/score.py.
#
# Usage: eval/run.sh <model> > eval/out-<model>.jsonl
set -euo pipefail

MODEL="${1:-}"
if [[ -z "$MODEL" ]]; then
  echo "Usage: $0 <model>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLES="$SCRIPT_DIR/samples.json"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

LEN=$(jq 'length' "$SAMPLES")
for ((i = 0; i < LEN; i++)); do
  ID=$(jq -r ".[$i].id" "$SAMPLES")
  TEXT=$(jq -r ".[$i].text" "$SAMPLES")
  PROMPT="Extract the following fields from the text below and respond with ONLY valid JSON, no markdown fences, no explanation. Keys: date (YYYY-MM-DD), amount (numeric string, no currency symbol), payee, transaction_type. Text: \"$TEXT\""
  RAW=$(echo "$PROMPT" | ollama run "$MODEL")
  jq -n --arg id "$ID" --arg model "$MODEL" --arg raw "$RAW" '{id: $id, model: $model, raw: $raw}'
done
