#!/usr/bin/env bash
# Run the fixed benchmark prompts (bench/prompts/) against a single Ollama
# model, one at a time, using Ollama's own --verbose stats output (eval
# rate, load duration, prompt eval rate, etc.) — no curl/jq required.
#
# Usage: bench/run.sh <model>
#
# Run once per model you want to compare:
#   bench/run.sh qwen3:0.6b
#   bench/run.sh phi:2.7b
#   bench/run.sh gemma4:e4b
set -euo pipefail

MODEL="${1:-}"
if [[ -z "$MODEL" ]]; then
  echo "Usage: $0 <model>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_DIR="$SCRIPT_DIR/prompts"

PROMPT_FILES=(
  "01-field-extraction.txt"
  "02-document-chunk.txt"
  "03-json-output.txt"
)

for PFILE in "${PROMPT_FILES[@]}"; do
  echo "===== $MODEL / $PFILE ====="
  cat "$PROMPT_DIR/$PFILE" | ollama run "$MODEL" --verbose
  echo
done
