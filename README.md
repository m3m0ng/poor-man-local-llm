# poor-man-llm

Running modern multimodal LLMs on hardware nobody wants anymore.

## The story

I had a ZimaBlade 7700 lying around (Intel Apollo Lake N3450/J3455/E3950, 16 GB RAM, no GPU, 32 GB eMMC). I wanted to wire a local LLM into my n8n workflows for privacy-sensitive documents — bank statements, personal records, anything I won't send to a hosted API.

The question: can a $0 hand-me-down mini-PC handle a 2026-level model like **Gemma 4 E4B**? Or is this a fool's errand?

This repo documents the journey, from first-principles research through the final build, benchmark, and go/no-go verdict.

## What's here now

A structured research trail under [`eddie/`](eddie/), produced with the [EDDIE](https://github.com/m3m0ng/eddie) methodology (Explore → Define → Design → Implement → Evaluate).

| Run | What it covers | Status |
|-----|----------------|--------|
| [`apollolake-e4b-reality-check`](eddie/apollolake-e4b-reality-check/) | Current plan — hardware assessment + setup guide for Apollo Lake ZimaBlade 7700 | Complete |
| [`gemma-e4b-rig-30tps`](eddie/gemma-e4b-rig-30tps/) | Original plan (J4125-based, superseded by corrected hardware specs) | Archived |

## Navigating the `eddie/` folder

Each EDDIE run is a self-contained folder with a clear lifecycle:

```
eddie/
├── index.md                  # Master index of all runs in this project
└── <run-name>/
    ├── interview.md          # Explore phase — vision, scope, anti-goals
    ├── prd.md                # Define phase — requirements, user stories, acceptance criteria
    ├── approach.md           # Design phase — architecture, trade-offs, step-by-step plan
    ├── README.md             # Run summary — status, locked decisions, key risks
    └── RESUME.md             # State for resuming a paused run
```

### Quick guide to each artifact

| File | Phase | Why read it |
|------|-------|-------------|
| `interview.md` | Explore | The original intent, constraints, and what problem we're actually solving. |
| `prd.md` | Define | Locked requirements, user stories with Given-When-Then acceptance criteria, and what's explicitly out of scope. |
| `approach.md` | Design | The concrete plan: OS choice, install steps, networking, benchmarks, and ADR-style decision points (e.g. Debian vs Ubuntu, swap vs no-swap). |
| `README.md` | — | One-page summary of the run: current status, locked decisions, surfaced risks, and next step. |
| `RESUME.md` | — | Internal state; safe to ignore unless you're continuing the run. |

## What's coming next

- [ ] Execute the build on the ZimaBlade 7700
- [ ] Run benchmarks for E4B and fallback model
- [ ] Wire n8n connectivity and test end-to-end
- [ ] Go/no-go verdict with real numbers
