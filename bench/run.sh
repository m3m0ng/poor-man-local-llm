#!/usr/bin/env bash
# Benchmark suite for comparing Ollama models on a fixed set of reproducible
# prompts (see bench/prompts/). Loops models x prompts, calls the Ollama
# /api/generate endpoint with stream:false, and prints a tok/s table.
#
# Usage:
#   bench/run.sh "model1 model2 ..." [--verbose]
#   MODELS="model1 model2 ..." bench/run.sh [--verbose]
#
# Examples:
#   bench/run.sh "gemma4:e4b qwen3:1.7b phi:2.7b"
#   bench/run.sh "gemma4:e4b" --verbose
#
# Requires: curl, jq. Override the Ollama endpoint with OLLAMA_HOST_URL.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPT_DIR="$SCRIPT_DIR/prompts"
HOST="${OLLAMA_HOST_URL:-http://localhost:11434}"

VERBOSE=0
MODELS_ARG=""
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    *) MODELS_ARG="$arg" ;;
  esac
done

MODELS="${MODELS_ARG:-${MODELS:-}}"
if [[ -z "$MODELS" ]]; then
  echo "Usage: $0 \"model1 model2 ...\" [--verbose]" >&2
  echo "   or: MODELS=\"model1 model2 ...\" $0 [--verbose]" >&2
  exit 1
fi

PROMPT_FILES=(
  "01-field-extraction.txt"
  "02-document-chunk.txt"
  "03-json-output.txt"
)

printf "%-16s %-22s %8s %10s %8s\n" "MODEL" "PROMPT" "TOK/S" "LOAD_MS" "EVAL_N"
printf "%-16s %-22s %8s %10s %8s\n" "----------------" "----------------------" "--------" "----------" "--------"

for MODEL in $MODELS; do
  for PFILE in "${PROMPT_FILES[@]}"; do
    PROMPT_TEXT="$(cat "$PROMPT_DIR/$PFILE")"

    RESPONSE="$(curl -s "$HOST/api/generate" -d "$(jq -n \
      --arg model "$MODEL" \
      --arg prompt "$PROMPT_TEXT" \
      '{model: $model, prompt: $prompt, stream: false, options: {temperature: 0, seed: 42}}')")"

    if [[ "$VERBOSE" -eq 1 ]]; then
      echo "----- $MODEL / $PFILE -----"
      echo "$RESPONSE" | jq '{
        response,
        eval_count, eval_duration,
        prompt_eval_count, prompt_eval_duration,
        load_duration, total_duration
      }'
    fi

    echo "$RESPONSE" | jq -r --arg model "$MODEL" --arg prompt "$PFILE" '
      [
        $model,
        $prompt,
        (if (.eval_duration // 0) > 0 then (.eval_count / .eval_duration * 1e9) else 0 end | tostring),
        ((.load_duration // 0) / 1e6 | tostring),
        ((.eval_count // 0) | tostring)
      ] | @tsv
    ' | awk -F'\t' '{printf "%-16s %-22s %8.2f %10.1f %8s\n", $1, $2, $3, $4, $5}'
  done
done
