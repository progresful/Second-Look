"""Evaluate the detector on a labelled JSONL set and write eval/results.json.

Usage (from api/):  python -m eval.run_eval [path.jsonl] [--llm]
"Scam" and "suspicious" count as a positive flag. "Not sure" is reported separately
and counts as a miss for scams and as no false alarm for legit messages.
"""
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("ENABLE_RDAP", "0")  # deterministic, offline by default

from app.scorer import analyze  # noqa: E402

HERE = Path(__file__).resolve().parent


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    use_llm = "--llm" in sys.argv
    path = Path(args[0]) if args else HERE / "sample.jsonl"
    rows = [json.loads(l) for l in path.read_text().splitlines() if l.strip()]

    tp = fp = fn = tn = unsure = 0
    errors = []
    for r in rows:
        res = analyze(r["text"], use_llm=use_llm)
        flagged = res["verdict"] in ("scam", "suspicious")
        if res["verdict"] == "not_sure":
            unsure += 1
        if r["label"] == "scam":
            tp += flagged
            fn += not flagged
        else:
            fp += flagged
            tn += not flagged
        if flagged != (r["label"] == "scam"):
            errors.append({"label": r["label"], "verdict": res["verdict"], "text": r["text"][:120],
                           "signals": [s["id"] for s in res["signals"]]})

    def ratio(a, b):
        return round(a / b, 3) if b else None

    out = {
        "dataset": path.name, "n": len(rows), "llm_used": use_llm,
        "tp": tp, "fp": fp, "fn": fn, "tn": tn,
        "precision": ratio(tp, tp + fp), "recall": ratio(tp, tp + fn),
        "false_positive_rate": ratio(fp, fp + tn), "not_sure_rate": ratio(unsure, len(rows)),
        "errors": errors,
    }
    (HERE / "results.json").write_text(json.dumps(out, indent=2, ensure_ascii=False))
    print(json.dumps({k: v for k, v in out.items() if k != "errors"}, indent=2))
    for e in errors:
        print(f"MISS [{e['label']} -> {e['verdict']}] {e['text']}  signals={e['signals']}")


if __name__ == "__main__":
    main()
