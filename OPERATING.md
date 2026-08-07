# Operating the monthly extraction job

> Everything you need to run this once a month without re-reading the research.
> If you only remember one thing: **`gemma4:e4b` with `--think=false`, and it
> takes minutes, not seconds — that's normal.**
>
> ⏳ Entries marked **[pending first run]** get filled in from the real
> end-to-end run ([#8](https://github.com/m3m0ng/poor-man-local-llm/issues/8)).

## The 60-second version

1. Drop the statement where your n8n trigger watches.
2. n8n POSTs it to Ollama on the ZimaBlade.
3. Wait. E4B generates at ~1.2 tok/s — a single statement takes minutes.
4. Check the output is valid JSON. If it isn't, see [Troubleshooting](#troubleshooting).

## Configuration that matters

| Setting | Value | Why |
|---------|-------|-----|
| Model | `gemma4:e4b` | Best accuracy measured; only model clean on all three suite prompts |
| Thinking | **off** (`"think": false`) | ≥1.7B models are faster *and* no less accurate without it |
| `format` | `"json"` | Constrains output; the model emitting prose around JSON is a real observed failure |
| `temperature` | `0` | Extraction is not creative work |
| `stream` | `false` | n8n wants one response, not a token stream |
| n8n HTTP timeout | **1800000 ms** (30 min) | ⚠️ The default (~300s) **will** cut off an E4B run |
| `EXECUTIONS_TIMEOUT_MAX` | ≥ 600 | Workflow-level ceiling |

### The `--think=false` rule

For **≥1.7B** models, disabling reasoning is a strict win — faster, never less
accurate, and on Qwen3 1.7B and E2B it actually *fixed* format violations.

At **0.6B it reverses**: `qwen3:0.6b` needs thinking **on**, or it miscounts
(it read "14 transactions" as "two"). If you ever fall back that far, turn
reasoning back on.

## Expected timings

So you can tell "slow" from "broken." From the `bench/` suite, `--think=false`:

| Model | Gen speed | 3-prompt suite | Cold load |
|-------|-----------|----------------|-----------|
| `gemma4:e4b` (default) | ~1.2 tok/s | 5m43s | 29–73s |
| `qwen3:1.7b` (fallback) | ~2.5–2.7 tok/s | 2m13s | ~2.5s |

**Cold load is normal and unavoidable.** The model is evicted from RAM between
monthly runs; expect ~30s before the first token. Deliberately not optimized —
keeping 9.6 GB resident year-round for a monthly job isn't worth it
([#7](https://github.com/m3m0ng/poor-man-local-llm/issues/7)).

**Per-statement wall clock, end to end: [pending first run]**

**A gotcha worth knowing:** with thinking off, generation is tiny, so
**prompt processing dominates**. Long multi-page statements are slow because of
their *input* size, not the output. Prompt-eval runs ~1.6 tok/s on E4B — a
2,000-token statement is ~20 minutes of prompt processing alone. Chunk large
statements rather than sending one huge prompt.

## Disk: the constraint that bites

**Only ~4.3 GB free with E4B installed.** You can hold E4B (9.6 GB) **or** a
couple of small models — never both. Pulling anything new usually means removing
something first.

```bash
df -h ~                    # check before any pull
ollama list                # what's installed
ollama rm <model>          # free space
```

This has already forced removing `phi` and `gemma4:e2b` once. Check disk before
pulling, not after the pull fails.

## Security

- **Ollama has no authentication.** The `ufw` rule restricting 11434 to your LAN
  subnet is the only access control. Verify with `sudo ufw status verbose`.
- Re-check after any network change — a rule lost in a router reshuffle silently
  exposes an unauthenticated endpoint that reads your bank statements.
- **Never commit real statements.** The repo holds synthetic samples only.

## Troubleshooting

### Output isn't valid JSON

The most likely failure, and the workflow routes it to a separate branch.

1. **Check `raw_response`** in the failed branch — usually the JSON is there,
   wrapped in ```` ```json ```` fences or prose.
2. **Confirm `"format": "json"` is set.** It's the strongest guard.
3. **Confirm thinking is off** — reasoning traces leak into output.
4. **Try the fallback:** `qwen3:1.7b --think=false` returned bare JSON reliably.
5. **Never** `phi:2.7b` — it ran 549 tokens into a hallucinated puzzle instead
   of stopping after the JSON.

### The run times out

Almost always the n8n HTTP timeout, not the box. E4B legitimately takes minutes.
Set the HTTP Request node timeout to 1800000 ms; the default kills it.

### Values are wrong rather than malformed

Watch specifically for **hallucinated dates** (Phi-2 turned 2026 into 2006) and
**miscounted totals**. On financial data a silently wrong number is worse than a
crash. Spot-check the date and amount on the first run each month.

### It's much slower than the table

1. `ollama ps` — is something else resident and competing for RAM?
2. Long input? Prompt processing dominates; chunk it.
3. Thermal: check `sensors` and whether CPU MHz is pinned near 800 (idle clock)
   right after a run. The box is passively cooled.

## Reference

| What | Where |
|------|-------|
| Measured benchmarks, all models | [`RESULTS.md`](RESULTS.md) |
| Build/setup plan | [`APPROACH.md`](APPROACH.md) |
| Re-run benchmarks | [`bench/README.md`](bench/README.md) |
| Accuracy eval harness | `eval/run.sh`, `eval/score.py` |
| Starter n8n workflow | [`n8n/extract-statement.json`](n8n/extract-statement.json) |
| Collect diagnostics | `scripts/collect.sh` |
| Configure LAN access | `scripts/lan-setup.sh` |
