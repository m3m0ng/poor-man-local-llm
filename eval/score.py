#!/usr/bin/env python3
"""Score eval/run.sh output against eval/samples.json ground truth.

Usage: python3 eval/score.py eval/out-<model>.jsonl
Prints per-field accuracy and counts JSON-parse failures as a distinct
failure mode (the model emitted non-JSON or malformed JSON).
"""
import json
import re
import sys
from pathlib import Path

FIELDS = ["date", "amount", "payee", "transaction_type"]


def extract_json(raw: str):
    raw = raw.strip()
    raw = re.sub(r"^```(json)?", "", raw).strip()
    raw = re.sub(r"```$", "", raw).strip()
    match = re.search(r"\{.*\}", raw, re.DOTALL)
    if not match:
        return None
    try:
        return json.loads(match.group(0))
    except json.JSONDecodeError:
        return None


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <out.jsonl>", file=sys.stderr)
        sys.exit(1)

    samples_path = Path(__file__).parent / "samples.json"
    samples = {s["id"]: s["truth"] for s in json.loads(samples_path.read_text())}

    field_correct = {f: 0 for f in FIELDS}
    field_total = {f: 0 for f in FIELDS}
    json_failures = 0
    n = 0

    for line in Path(sys.argv[1]).read_text().splitlines():
        if not line.strip():
            continue
        rec = json.loads(line)
        truth = samples.get(rec["id"])
        if truth is None:
            continue
        n += 1
        parsed = extract_json(rec["raw"])
        if parsed is None:
            json_failures += 1
            continue
        for f in FIELDS:
            field_total[f] += 1
            got = str(parsed.get(f, "")).strip().lower()
            want = str(truth.get(f, "")).strip().lower()
            if got == want:
                field_correct[f] += 1

    print(f"Samples: {n}, JSON-parse failures: {json_failures}")
    for f in FIELDS:
        total = field_total[f]
        correct = field_correct[f]
        pct = (correct / total * 100) if total else 0.0
        print(f"  {f}: {correct}/{total} ({pct:.0f}%)")


if __name__ == "__main__":
    main()
