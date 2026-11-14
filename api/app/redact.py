"""PII redaction. The phone should redact first; the server does it again as a safety net."""
import re

_RULES = [
    ("[IBAN]", re.compile(r"\b[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){3,7}(?: ?[A-Z0-9]{1,4})?\b")),
    ("[CARD]", re.compile(r"\b(?:\d[ -]?){13,19}\b")),
    ("[HETU]", re.compile(r"\b\d{6}[-+AaBCDEFYXWVU]\d{3}[0-9A-Ya-y]\b")),  # Finnish personal ID
    ("[EMAIL]", re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")),
    ("[PHONE]", re.compile(r"(?<!\w)(?:\+358|0)[\s-]?\d{1,3}(?:[\s-]?\d{2,4}){2,3}(?!\w)")),
]


def redact(text: str) -> str:
    for token, rx in _RULES:
        text = rx.sub(token, text)
    return text
