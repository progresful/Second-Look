"""LLM second opinion. Providers:

- gemini (default when GEMINI_API_KEY is set): Gemini API with structured JSON output.
  Also supports images: Gemini reads the photo, extracts text + URL, and returns
  bounding boxes (box_2d, 0-1000 scale) for each suspicious element.
- router: any OpenAI-compatible endpoint (e.g. Hostinger AI Router), text only.

The LLM adds findings and a plain-language reason; it never overrides rule evidence.
"""
import json
import os
import re
from typing import Optional

import httpx

ALLOWED = ["credential_request", "unusual_payment", "false_urgency", "threat", "authority_claim",
           "relative_impersonation", "too_good", "small_fee", "click_link", "remote_access", "secrecy",
           "changed_bank_details", "unrealistic_offer", "advance_fee", "receive_money_link", "money_request",
           "bait_unlock", "lookalike_domain", "price_mismatch", "price_too_low"]

INSTRUCTIONS = """You check messages, web pages and documents for scams, for older adults.
Use only these technique ids: {ids}.
Quote short evidence exactly as it appears. If it looks like a normal legitimate notice or shop,
return no techniques and a low scam_likelihood. Do not guess: if unreadable, say so in reason.
reason: one plain sentence a 75-year-old understands."""

IMAGE_EXTRA = """This is a photo taken through smart glasses. First read all visible text (including the
browser address bar) into extracted_text and the page address into url. For each technique, give box_2d
as [ymin, xmin, ymax, xmax] on a 0-1000 scale around the evidence in the image."""

GEMINI_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "extracted_text": {"type": "STRING"},
        "url": {"type": "STRING"},
        "techniques": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {
            "id": {"type": "STRING", "enum": ALLOWED},
            "evidence": {"type": "STRING"},
            "box_2d": {"type": "ARRAY", "items": {"type": "INTEGER"}},
        }, "required": ["id", "evidence"]}},
        "scam_likelihood": {"type": "NUMBER"},
        "reason": {"type": "STRING"},
    },
    "required": ["techniques", "scam_likelihood", "reason"],
}


def provider() -> Optional[str]:
    if os.getenv("GEMINI_API_KEY"):
        return "gemini"
    if os.getenv("AI_ROUTER_API_KEY") and os.getenv("AI_ROUTER_BASE_URL"):
        return "router"
    return None


def enabled() -> bool:
    return provider() is not None


def _clean(data: dict) -> dict:
    data["techniques"] = [t for t in data.get("techniques", []) if t.get("id") in ALLOWED]
    for t in data["techniques"]:
        box = t.get("box_2d")
        if not (isinstance(box, list) and len(box) == 4 and all(isinstance(v, (int, float)) for v in box)):
            t.pop("box_2d", None)
    data["scam_likelihood"] = max(0.0, min(1.0, float(data.get("scam_likelihood", 0))))
    data["reason"] = str(data.get("reason", ""))[:300]
    return data


# Model routing by content and moment (timed on 14 Nov 2026 with this key):
#   plain short text          -> FAST  gemini-3.5-flash-lite (~1 s)
#   text with money/links/long -> RICH gemini-3.1-flash-lite (~1.7 s)
#   live camera frames        -> FAST_IMAGE gemini-3.1-flash-lite (~3 s)
#   a photo the user asked to check -> DEEP gemini-3.5-flash (~4 s text, ~8.5 s photo)
# A borderline answer (likelihood 0.3-0.7) from a fast model is re-asked to DEEP,
# except in live mode, which must stay quick.
FAST_MODEL = os.getenv("GEMINI_MODEL_FAST", "gemini-3.5-flash-lite")
RICH_MODEL = os.getenv("GEMINI_MODEL_RICH", "gemini-3.1-flash-lite")
FAST_IMAGE_MODEL = os.getenv("GEMINI_MODEL_FAST_IMAGE", "gemini-3.1-flash-lite")
DEEP_MODEL = os.getenv("GEMINI_MODEL_DEEP", "gemini-3.5-flash")
TIMEOUTS = {FAST_MODEL: 4.0, RICH_MODEL: 5.0, FAST_IMAGE_MODEL: 6.0, DEEP_MODEL: 12.0}
_RICH = re.compile(r"(https?://|www\.|\b[a-z0-9-]+\.[a-z]{2,6}\b|€|\$|£|\d+[.,]\d{2}\b|\biban\b|\bfi\d{2}\b)", re.I)
_ERRORS = (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError)


def pick_model(text: str, image: bool = False, live: bool = False) -> str:
    if image:
        return FAST_IMAGE_MODEL if live else DEEP_MODEL
    if len(text) > 1200 or _RICH.search(text):
        return RICH_MODEL
    return FAST_MODEL


def _borderline(out: Optional[dict]) -> bool:
    return bool(out) and 0.3 <= out["scam_likelihood"] <= 0.7


def _gemini(text: str, image_b64: Optional[str] = None, mime: str = "image/jpeg", model: Optional[str] = None) -> Optional[dict]:
    model = model or pick_model(text, image=bool(image_b64))
    prompt = INSTRUCTIONS.format(ids=", ".join(ALLOWED))
    parts = [{"text": prompt + ("\n" + IMAGE_EXTRA if image_b64 else "") + (f'\nMessage:\n"""{text[:4000]}"""' if text else "")}]
    if image_b64:
        parts.append({"inline_data": {"mime_type": mime, "data": image_b64}})
    r = httpx.post(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        headers={"x-goog-api-key": os.environ["GEMINI_API_KEY"]},
        json={"contents": [{"parts": parts}],
              "generationConfig": {"temperature": 0, "responseMimeType": "application/json",
                                   "responseSchema": GEMINI_SCHEMA}},
        timeout=TIMEOUTS.get(model, 8.0),
    )
    r.raise_for_status()
    content = r.json()["candidates"][0]["content"]["parts"][0]["text"]
    out = _clean(json.loads(content))
    out["model"] = model
    return out


def _router(text: str) -> Optional[dict]:
    prompt = INSTRUCTIONS.format(ids=", ".join(ALLOWED)) + \
        '\nReturn ONLY JSON: {"techniques":[{"id":"...","evidence":"..."}],"scam_likelihood":0.0,"reason":"..."}' + \
        f'\nMessage:\n"""{text[:4000]}"""'
    r = httpx.post(
        os.environ["AI_ROUTER_BASE_URL"].rstrip("/") + "/chat/completions",
        headers={"Authorization": f"Bearer {os.environ['AI_ROUTER_API_KEY']}"},
        json={"model": os.getenv("AI_ROUTER_MODEL", "claude-haiku-5-5"),
              "messages": [{"role": "user", "content": prompt}], "temperature": 0, "max_tokens": 400},
        timeout=float(os.getenv("LLM_TIMEOUT", "4")),
    )
    r.raise_for_status()
    content = r.json()["choices"][0]["message"]["content"]
    return _clean(json.loads(content[content.find("{"): content.rfind("}") + 1]))


def analyze(text: str) -> Optional[dict]:
    """Text second opinion. Returns None on any failure (caller falls back to rules)."""
    try:
        p = provider()
        if p == "gemini":
            out = _gemini(text)
            if _borderline(out):  # fast model unsure: ask the stronger one once
                try:
                    return _gemini(text, model=DEEP_MODEL) or out
                except _ERRORS:
                    return out
            return out
        if p == "router":
            return _router(text)
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError):
        return None
    return None


def analyze_image(image_b64: str, mime: str = "image/jpeg", live: bool = False) -> Optional[dict]:
    """Image mode (Gemini only): extracted text, url, techniques with boxes.
    live=True: a frame from live scan -> fast model only."""
    if provider() != "gemini":
        return None
    try:
        return _gemini("", image_b64, mime, model=pick_model("", image=True, live=live))
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError):
        return None
