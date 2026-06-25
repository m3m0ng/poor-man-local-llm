# bench/

Fixed, reproducible prompt suite for comparing Ollama models on this rig.
Replaces ad-hoc single-prompt testing (a hand-typed essay prompt) with a
small, deterministic set of prompts that match the real workload (structured
extraction from documents), not a generic essay.

## Prompts (`bench/prompts/`)

| File | Shape |
|------|-------|
| `01-field-extraction.txt` | Short field extraction (date/amount/payee/type) |
| `02-document-chunk.txt` | Longer document chunk, summarize in 2 sentences |
| `03-json-output.txt` | Strict JSON-only output instruction |

## Usage

Run once per model. `bench/run.sh` pipes each prompt into
`ollama run <model> --verbose`, so the generation rate, prompt eval rate,
load duration, and eval/prompt-eval counts print after every prompt —
straight from Ollama, no extra tooling needed.

```bash
bench/run.sh qwen3:0.6b
```

Move to the next model and run it again:

```bash
bench/run.sh phi:2.7b
bench/run.sh gemma4:e4b
```

### No repo on the box?

If you're SSH'd into the Ollama host without this repo cloned, run the same
three prompts directly:

```bash
M=qwen3:0.6b
echo "Extract the following fields from the text below and list them as plain key: value pairs, one per line: date, amount, payee, transaction_type. Text: \"On 03/14/2026, a payment of \$128.50 was made to Greenfield Hardware for a store purchase.\"" | ollama run $M --verbose
echo "Summarize the following document chunk in exactly two sentences. Document: \"Monthly Account Statement - Checking Account ending in 4471. Statement period: March 1-31, 2026. Opening balance \$2,340.18. Closing balance \$1,987.42. 14 transactions recorded, including a rent payment of \$1,200.00 and a payroll deposit of \$1,200.00. No overdraft fees. Account in good standing.\"" | ollama run $M --verbose
echo "Convert the following sentence into JSON with exactly these keys: name, age, city. Respond with ONLY valid JSON, no other text. Sentence: \"Maria is 34 years old and lives in Lisbon.\"" | ollama run $M --verbose
```

Change `M=` and re-run the three lines for the next model.

## Output

For each prompt, Ollama prints the response followed by stats like:

```
total duration:       3m30.4s
load duration:        209ms
prompt eval count:    42 token(s)
prompt eval duration: 8.19s
prompt eval rate:     5.13 tokens/s
eval count:           566 token(s)
eval duration:        3m30.4s
eval rate:             2.69 tokens/s
```

Record the **eval rate** (tok/s) and **load duration** for each
model x prompt — that's the number that goes in `RESULTS.md`.
