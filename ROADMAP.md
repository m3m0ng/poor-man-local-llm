# Roadmap to v1.0 — the closing checklist

> **Purpose of this file:** define a finish line for this project and list
> exactly what stands between here and there. When every box below is checked,
> the repo is **done** — tagged `v1.0`, docs frozen, no open issues. Not
> archived, not abandoned: *finished*.

---

## The endpoint

**v1.0 = one real bank statement goes through n8n → Ollama on the ZimaBlade →
structured output, and it is documented well enough to repeat next month
without re-deriving anything.**

That's it. Not a service, not a product, not the fastest possible model.

### Why this is the right line

The project's founding question was *"can a $0 hand-me-down Apollo Lake box run
a 2026-level 4B model?"* — and [`RESULTS.md`](RESULTS.md) already answers it:
**yes, 1.07 tok/s, GO for monthly batch.** Five models measured, think/no-think
swept, default picked. In the words of RESULTS.md itself:

> The model question itself is settled.

What is *not* settled is the thing the whole exercise was for. From the README:

> I wanted to wire a local LLM into my n8n workflows for privacy-sensitive
> documents.

The README's "What's coming next" list has exactly **one** unchecked box:
*"Wire n8n connectivity and test end-to-end."* Everything else is checked.

So the endpoint isn't a judgment call — the repo has been pointing at it the
whole time. The risk to closing this project was never that the work is
unfinished; it's that benchmarking is *pleasant and infinite* while integration
is fiddly and finite. This roadmap closes the finite thing and stops the
infinite one.

### Explicitly out of scope for v1.0

These are good ideas. They are not this project.

| Not doing | Why |
|-----------|-----|
| More candidate models (Granite, Llama 3.2, SmolLM3, Phi-4-mini) | Model question is settled. Five measured is enough. |
| Quantization sweep of E4B | Optimizing a number that doesn't hurt: 5m43s is fine for a monthly unattended job. |
| `OLLAMA_KEEP_ALIVE` tuning | Already decided against ([#7](https://github.com/m3m0ng/poor-man-local-llm/issues/7)) — a ~30s cold load once a month is not a problem. |
| Vision/OCR models for scanned PDFs | Genuinely new project. If statements arrive as scans, that's v2 or a new repo. |
| Standalone thermal study | Folded into the real run as a logged observation (C4), not its own investigation. |
| Anything touching BIOS, drivers, cooling mods, new hardware | Locked anti-goals in [`APPROACH.md`](APPROACH.md). |

**The rule for anything new:** if it doesn't get one statement through n8n, it
goes in a "someday" note, not an issue.

---

## The checklist

Six items, in dependency order. C1 unblocks C3; C2 unblocks C4; C4 is the
endpoint itself.

### C1 — Land the stranded work

**There is finished, unmerged work on `claude/github-issues-triage-4mx017`
that no PR was ever opened for.** It has been sitting there since June:

| File | What it does | Status |
|------|--------------|--------|
| `eval/samples.json` | 8 synthetic labeled statements + ground-truth JSON | written, never run |
| `eval/run.sh` | Prompts a model for strict JSON per sample | written, never run |
| `eval/score.py` | Scores per-field accuracy, counts JSON-parse failures | written, never run |
| `bench/thermal/run.sh` | Sustained-load loop with `sensors` logging | written, never run |

Nothing else is on that branch — it's a clean 4-file, 168-line addition on top
of current `main`, no conflicts. Merge it, or the eval work in C3 gets rewritten
from scratch by someone who doesn't know it exists.

- [ ] Merge `claude/github-issues-triage-4mx017` into `main`
- [ ] Delete the other five stale `claude/*` branches (all already merged via PRs #1, #10–#15)

### C2 — Verify the LAN path actually exists

`APPROACH.md` steps 7–8 (bind Ollama to `0.0.0.0`, restrict with `ufw`, curl
from the n8n host) are **written as a plan and never confirmed done.** Every
benchmark so far ran locally on the box via `ollama run`. The network hop is
untested.

- [ ] `OLLAMA_HOST=0.0.0.0:11434` set via systemd override; service restarted
- [ ] `ufw` restricts 11434 to the LAN subnet — verified, not assumed
- [ ] `curl http://<zimablade-ip>:11434/api/tags` succeeds **from the n8n host**
- [ ] Confirm from outside the LAN that the port is *not* reachable

> ⚠️ Ollama has no authentication. The firewall rule is the only thing between
> your bank statements and the network. Verify it rather than trusting it.

### C3 — Measure extraction accuracy (was [#4](https://github.com/m3m0ng/poor-man-local-llm/issues/4))

The quality ranking in `RESULTS.md` is a **qualitative read of three prompts** —
"clean sweep", "failed all three". Useful, but it is not an error rate, and the
default model was picked on it. Before trusting extracted numbers off a
financial document, get a real per-field score. The harness already exists (C1).

```bash
eval/run.sh gemma4:e4b  > eval/out-gemma4-e4b.jsonl
eval/run.sh qwen3:1.7b  > eval/out-qwen3-1.7b.jsonl
python3 eval/score.py eval/out-gemma4-e4b.jsonl
python3 eval/score.py eval/out-qwen3-1.7b.jsonl
```

- [ ] Score the default (E4B) and the fast fallback (Qwen3 1.7B), both `--think=false`
- [ ] Record per-field accuracy + JSON-parse failure count in `RESULTS.md`
- [ ] If accuracy contradicts the current pick, change the default and say so

Two models is the bar. Scoring all five is the rabbit hole.

### C4 — The endpoint: one statement, end to end (was [#8](https://github.com/m3m0ng/poor-man-local-llm/issues/8))

**This is the item the project exists for.** Everything else is support.

- [ ] n8n workflow built: trigger → HTTP Request to `/api/generate` (`stream:false`) → parse JSON → write output
- [ ] Workflow exported to the repo as `n8n/extract-statement.json`
- [ ] **One statement processed end to end**, output landed where it's meant to go
- [ ] End-to-end wall-clock recorded, and the overhead over raw `ollama run` noted
- [ ] Timeouts confirmed sufficient against the slowest path (`EXECUTIONS_TIMEOUT_MAX`, `N8N_AI_TIMEOUT_MAX`) — E4B runs are minutes long, defaults will cut you off
- [ ] *Folded in from [#6](https://github.com/m3m0ng/poor-man-local-llm/issues/6):* note CPU temp / tok/s at the start vs end of the run — one line in RESULTS.md, not a study

> ⚠️ Synthetic or redacted input only in the repo. Run the real thing on the
> box; commit the sanitized version.

**Thermal, honestly:** the only evidence of throttling is Phi-2 drifting
3.49 → 3.24 → 2.59 tok/s across three back-to-back prompts — which is equally
explained by the third prompt being a 549-token runaway. For one document a
month it does not matter. Observe it during C4; don't build a test rig for it.

### C5 — Write the runbook

The gap between "it worked once" and "finished" is whether you can do it again
in a month without re-reading three research documents.

- [ ] `OPERATING.md`: how to run the monthly job, start to finish
- [ ] Which model, which flags, and *why* (`--think=false` for ≥1.7B, thinking **on** for 0.6B)
- [ ] Expected wall-clock, so a slow run is recognizable as normal
- [ ] Disk management: only ~4.3 GB free — you hold E4B **or** a couple of small models, never both. `ollama rm` is part of the routine.
- [ ] What to check when output isn't valid JSON

### C6 — Reconcile the docs and freeze

The docs accumulated drift while the results moved. Fix the contradictions, then
stop.

Known drift to fix in `APPROACH.md`:

- [ ] Step 1 says *"Install Debian 12"*; the confirmed hardware section says Debian 13 (trixie) is already installed
- [ ] Step 5's benchmark still uses the `curl`/`jq` recipe that PR #12 deliberately replaced with `bench/run.sh --verbose`
- [ ] Step 6 *"Decide: E4B or Fallback"* is a decision gate that has already been passed — record the outcome, drop the gate
- [ ] The fallback table mixes measured numbers with estimates and still lists Gemma 2B, which was never tested
- [ ] Open Risks: mark thermal resolved-by-observation (C4); the eMMC and no-auth risks stay as permanent operating constraints

Then:

- [ ] README "What's coming next" — check the last box
- [ ] `RESULTS.md` Open items — close out or move to a short "known limitations" note
- [ ] Tag **`v1.0`** with a release note pointing at RESULTS.md's verdict
- [ ] Final README line: what this project concluded, and that it's done

---

## Progress

Split by **who can actually do it**. The dividing line is physical access: the
ZimaBlade and the n8n instance are reachable only from your hardware. Everything
else is automatable and is already done.

### Needs you — two sittings, both "run it, paste output"

| # | Issue | Action | Blocked by |
|---|-------|--------|------------|
| C2+C3 | [#17](https://github.com/m3m0ng/poor-man-local-llm/issues/17) | Run `scripts/lan-setup.sh` then `scripts/collect.sh` on the box; curl from the n8n host | — |
| C4 | [#8](https://github.com/m3m0ng/poor-man-local-llm/issues/8) | **Import the workflow, run one statement** — the endpoint | #17 |

### Done, or mine to finish once data lands

| # | Issue | Item | Status |
|---|-------|------|--------|
| C1 | [#16](https://github.com/m3m0ng/poor-man-local-llm/issues/16) | Stranded branch merged; `eval/run.sh` no-think defect fixed | ✅ done |
| C5 | [#18](https://github.com/m3m0ng/poor-man-local-llm/issues/18) | `OPERATING.md` written; 2 timing gaps pending | ◐ drafted |
| C6 | [#19](https://github.com/m3m0ng/poor-man-local-llm/issues/19) | `APPROACH.md` drift fixed; results + tag pending | ◐ partial |

Also built rather than delegated: `scripts/lan-setup.sh`, `scripts/collect.sh`,
and `n8n/extract-statement.json`.

**Closed as out-of-scope during this triage:** [#5](https://github.com/m3m0ng/poor-man-local-llm/issues/5) (quantization sweep),
[#6](https://github.com/m3m0ng/poor-man-local-llm/issues/6) (standalone thermal study — folded into C4),
[#9](https://github.com/m3m0ng/poor-man-local-llm/issues/9) (more candidate models).
Previously closed: [#2](https://github.com/m3m0ng/poor-man-local-llm/issues/2), [#3](https://github.com/m3m0ng/poor-man-local-llm/issues/3), [#7](https://github.com/m3m0ng/poor-man-local-llm/issues/7).

## If you only do one thing

**C4.** With C2 as its prerequisite. The eval (C3), the runbook (C5), and the
doc cleanup (C6) all make v1.0 *better*; C4 is what makes it *finished*.
