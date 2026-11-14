"""Price-consistency checks for shop pages: do the shown prices and discount add up?"""
import re
from typing import List

# "€20" or "20 €" / "20 euros". The suffix form must not be followed by another number ("C55 €20").
PRICE_RX = re.compile(r"(?:€\s?(\d{1,5}(?:[.,]\d{2})?)|(?<![\w.,])(\d{1,5}(?:[.,]\d{2})?)\s?(?:€|eur\b|euros?\b)(?!\s?\d))", re.I)
PCT_RX = re.compile(r"-\s?(\d{1,2})\s?%")


def _prices(text: str) -> List[float]:
    out = []
    for a, b in PRICE_RX.findall(text):
        v = float((a or b).replace(",", "."))
        if v > 0:
            out.append(v)
    return out


def analyze(text: str) -> List[dict]:
    prices = _prices(text)
    if len(prices) < 2:
        return []
    signals = []
    lo, hi = min(prices), max(prices)

    if hi >= 50 and lo <= hi * 0.25:
        signals.append({"id": "price_too_low", "label": "Price far below normal", "weight": 0.5,
                        "explanation": f"€{lo:g} for an item normally €{hi:g} is over 75% off. Too cheap is a common fake-shop sign.",
                        "evidence": f"€{lo:g}", "source": "prices"})

    for pct in {int(p) for p in PCT_RX.findall(text)}:
        expected = hi * (1 - pct / 100)
        matches = [p for p in prices if abs(p - expected) <= max(2, expected * 0.03)]
        if matches and lo < min(matches) * 0.8:
            signals.append({"id": "price_mismatch", "label": "Prices don't add up", "weight": 0.6,
                            "explanation": f"-{pct}% off €{hi:g} is €{expected:.0f}, and the cart says €{min(matches):g}, "
                                           f"but the page shows €{lo:g}. The cheap price is bait.",
                            "evidence": f"-{pct}", "source": "prices"})
            break
    return signals
