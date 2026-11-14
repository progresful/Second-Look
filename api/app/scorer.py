"""Combine rule, source and LLM signals into one calibrated, explainable verdict."""
import time
from typing import List, Optional

from . import llm, prices, rules, source
from .redact import redact
from .rules import TECHNIQUES

# Thresholds: tune these with eval/run_eval.py, then freeze.
SCAM_AT = 1.2
SUSPICIOUS_AT = 0.55
MIN_CHARS = 12

SPOKEN = {
    "scam": "Likely scam. Don't pay or reply.",
    "suspicious": "Be careful.",
    "looks_ok": "No scam signs found. If unsure, check with the official number.",
    "not_sure": "I can't tell. Don't pay yet. Call the official number.",
}
_TECH = {t.id: t for t in TECHNIQUES}


def analyze(text: str, url: Optional[str] = None, use_llm: bool = True) -> dict:
    started = time.time()
    clean = redact((text or "").strip())
    urls = source.extract_urls(clean) + ([url] if url else [])

    if len(clean) < MIN_CHARS and not urls:
        return _result("not_sure", 0.0, [], "There isn't enough readable text to check.", started, clean, llm_used=False)

    signals: List[dict] = rules.detect(clean) + prices.analyze(clean)
    for u in urls[:5]:
        signals.extend(source.analyze_url(u))

    llm_out = llm.analyze(clean) if use_llm else None
    if llm_out:
        have = {s["id"] for s in signals}
        for t in llm_out["techniques"]:
            if t["id"] not in have and t["id"] in _TECH:  # source/price ids come from deterministic checks only
                base = _TECH[t["id"]]
                # LLM-only findings count for less than rule evidence.
                signals.append({"id": base.id, "label": base.label, "weight": round(base.weight * 0.6, 2),
                                "explanation": base.explanation, "evidence": t.get("evidence", ""), "source": "llm"})

    score = sum(s["weight"] for s in signals)
    if llm_out:
        score += (llm_out["scam_likelihood"] - 0.5) * 0.6

    strong = [s for s in signals if s["weight"] >= 0.7]
    if score >= SCAM_AT or (strong and score >= SUSPICIOUS_AT + 0.3):
        verdict = "scam"
    elif score >= SUSPICIOUS_AT:
        verdict = "suspicious"
    elif llm_out is None and 0.3 <= score < SUSPICIOUS_AT:
        verdict = "not_sure"  # weak evidence and no second opinion
    else:
        verdict = "looks_ok"

    top = sorted([s for s in signals if s["weight"] > 0], key=lambda s: -s["weight"])
    reason = top[0]["explanation"] if top and verdict != "looks_ok" else (
        llm_out["reason"] if llm_out and verdict != "looks_ok" else "")
    confidence = min(1.0, abs(score - SUSPICIOUS_AT) / SCAM_AT)
    return _result(verdict, round(confidence, 2), signals, reason, started, clean, llm_used=bool(llm_out),
                   model=(llm_out or {}).get("model"))


def _result(verdict, confidence, signals, reason, started, clean, llm_used, model=None) -> dict:
    spoken = SPOKEN[verdict] + (" " + reason if reason and verdict in ("scam", "suspicious") else "")
    return {
        "verdict": verdict,
        "confidence": confidence,
        "spoken": spoken,
        "reason": reason,
        "signals": signals,
        "redacted_text": clean,
        "llm_used": llm_used,
        "model": model,
        "latency_ms": int((time.time() - started) * 1000),
    }


def analyze_image(image_b64: str, mime: str = "image/jpeg", live: bool = False, phone_text: str = "") -> Optional[dict]:
    """Photo mode: Gemini reads the image (text, url, boxes), then the deterministic checks
    run on what it read. Gemini findings carry boxes so the client can highlight them."""
    started = time.time()
    g = llm.analyze_image(image_b64, mime, live=live, text=phone_text)
    if g is None:
        return None
    text = g.get("extracted_text", "") or phone_text  # live: the phone's own (redacted) reading
    url = g.get("url") or None
    res = analyze(text, url, use_llm=False)  # rules + prices + domain on Gemini's reading

    have = {s["id"] for s in res["signals"]}
    boxes = []
    for t in g["techniques"]:
        base = _TECH.get(t["id"])
        label = base.label if base else t["id"].replace("_", " ").capitalize()
        if "box_2d" in t:
            boxes.append({"id": t["id"], "label": label, "evidence": t.get("evidence", ""), "box_2d": t["box_2d"]})
        if base and t["id"] not in have:
            res["signals"].append({"id": base.id, "label": base.label, "weight": round(base.weight * 0.6, 2),
                                   "explanation": base.explanation, "evidence": t.get("evidence", ""), "source": "gemini"})
    # Re-score with Gemini's extra findings and its overall likelihood.
    score = sum(s["weight"] for s in res["signals"]) + (g["scam_likelihood"] - 0.5) * 0.6
    strong = [s for s in res["signals"] if s["weight"] >= 0.7]
    if score >= SCAM_AT or (strong and score >= SUSPICIOUS_AT + 0.3):
        verdict = "scam"
    elif score >= SUSPICIOUS_AT:
        verdict = "suspicious"
    elif not text.strip():
        verdict = "not_sure"
    else:
        verdict = "looks_ok"
    top = sorted([s for s in res["signals"] if s["weight"] > 0], key=lambda s: -s["weight"])
    reason = (top[0]["explanation"] if top else g["reason"]) if verdict in ("scam", "suspicious") else (
        "I couldn't read it. Hold it closer and steady." if verdict == "not_sure" else "")
    out = _result(verdict, round(min(1.0, abs(score - SUSPICIOUS_AT) / SCAM_AT), 2), res["signals"], reason,
                  started, res["redacted_text"], llm_used=True, model=g.get("model"))
    out.update({"boxes": boxes, "url": url, "gemini_reason": g["reason"]})
    return out
