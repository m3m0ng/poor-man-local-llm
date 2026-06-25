# bench/

Fixed, reproducible prompt suite for comparing Ollama models on this rig.
Replaces ad-hoc single-prompt testing (`ollama run <model> --verbose`) with a
small, deterministic set of prompts that match the real workload (structured
extraction from documents), not a generic essay.

## Prompts (`bench/prompts/`)

| File | Shape |
|------|-------|
| `01-field-extraction.txt` | Short field extraction (date/amount/payee/type) |
| `02-document-chunk.txt` | Longer document chunk, summarize in 2 sentences |
| `03-json-output.txt` | Strict JSON-only output instruction |

Each call sets `options.temperature: 0` and `options.seed: 42` for
repeatability.

## Usage

Requires `curl` and `jq` on the machine running the suite (the Ollama host
itself, or any box with network access to it).

```bash
bench/run.sh "gemma4:e4b qwen3:1.7b phi:2.7b"
```

Or via env var:

```bash
MODELS="gemma4:e4b qwen3:1.7b" bench/run.sh
```

Add `--verbose` to also print the full per-call metrics (eval/prompt-eval
counts and durations, load duration, total duration, and the raw response
text) before each table row:

```bash
bench/run.sh "gemma4:e4b" --verbose
```

Point at a non-default Ollama host with `OLLAMA_HOST_URL` (default
`http://localhost:11434`):

```bash
OLLAMA_HOST_URL=http://192.168.0.50:11434 bench/run.sh "qwen3:1.7b"
```

## Output

A table with one row per model x prompt:

```
MODEL            PROMPT                    TOK/S    LOAD_MS   EVAL_N
---------------- ---------------------- -------- ---------- --------
gemma4:e4b       01-field-extraction.txt    1.05       28.8       62
gemma4:e4b       02-document-chunk.txt      1.02      130.2      94
gemma4:e4b       03-json-output.txt         1.11       19.4       18
```
