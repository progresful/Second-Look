"""Source-trust signals for URLs: lookalike domains, risky TLDs, shorteners, domain age."""
import os
import re
from datetime import datetime, timezone
from difflib import SequenceMatcher
from functools import lru_cache
from typing import List, Optional
from urllib.parse import urlparse

import httpx

# Real domains of brands that scammers commonly impersonate in Finland.
KNOWN_GOOD = {
    "op.fi", "nordea.fi", "nordea.com", "danskebank.fi", "s-pankki.fi", "aktia.fi", "spankki.fi",
    "posti.fi", "kela.fi", "vero.fi", "poliisi.fi", "tulli.fi", "suomi.fi", "mobilepay.fi",
    "traficom.fi", "dhl.com", "dhl.fi", "microsoft.com", "apple.com", "amazon.com",
    "tori.fi", "blickers.com", "verkkokauppa.com", "gigantti.fi", "zalando.fi", "ikea.com", "nike.com",
}
BRAND_WORDS = {"op", "nordea", "danske", "spankki", "aktia", "posti", "kela", "vero", "poliisi",
               "tulli", "suomi", "mobilepay", "dhl", "microsoft", "apple", "amazon", "paypal",
               "tori", "verkkokauppa", "gigantti", "zalando", "ikea", "nike", "parkki", "easypark"}
RISKY_TLDS = {"xyz", "top", "click", "shop", "online", "site", "icu", "buzz", "live", "info", "monster", "cyou", "sbs", "store", "sale", "bond", "lat"}
SHORTENERS = {"bit.ly", "tinyurl.com", "t.co", "is.gd", "cutt.ly", "rebrand.ly", "ow.ly", "shorturl.at"}

URL_RX = re.compile(r"\b((?:https?://|www\.)[^\s<>\"']+|[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}(?:/[^\s<>\"']*)?)", re.I)


def extract_urls(text: str) -> List[str]:
    urls = []
    for m in URL_RX.findall(text or ""):
        u = m.rstrip(".,);!?")
        if "@" in u:  # skip e-mail addresses
            continue
        urls.append(u)
    return urls


def registered_domain(host: str) -> str:
    parts = host.lower().strip(".").split(".")
    return ".".join(parts[-2:]) if len(parts) >= 2 else host.lower()


@lru_cache(maxsize=512)
def domain_age_days(domain: str) -> Optional[int]:
    """Look up registration date via RDAP. Returns None if unknown or disabled."""
    if os.getenv("ENABLE_RDAP", "1") != "1":
        return None
    try:
        r = httpx.get(f"https://rdap.org/domain/{domain}", timeout=3.0, follow_redirects=True)
        if r.status_code != 200:
            return None
        for ev in r.json().get("events", []):
            if ev.get("eventAction") == "registration":
                created = datetime.fromisoformat(ev["eventDate"].replace("Z", "+00:00"))
                return (datetime.now(timezone.utc) - created).days
    except (httpx.HTTPError, ValueError, KeyError):
        return None
    return None


def analyze_url(url: str) -> List[dict]:
    """Return risk signals for one URL, each with weight and plain-language explanation."""
    signals = []
    parsed = urlparse(url if "://" in url else "http://" + url)
    host = (parsed.hostname or "").lower()
    if not host:
        return signals
    domain = registered_domain(host)
    tld = domain.rsplit(".", 1)[-1]

    if domain in KNOWN_GOOD:
        signals.append({"id": "known_good_domain", "label": "Official domain", "weight": -0.4,
                        "explanation": f"{domain} is the official domain.", "evidence": host, "source": "source"})
        return signals

    if re.fullmatch(r"[\d.]+", host):
        signals.append({"id": "ip_url", "label": "Link is a raw IP address", "weight": 0.7,
                        "explanation": "Real organisations don't send links to bare IP addresses.",
                        "evidence": host, "source": "source"})
    if domain in SHORTENERS:
        signals.append({"id": "shortener", "label": "Hidden link (shortener)", "weight": 0.3,
                        "explanation": "A link shortener hides where the link really goes.",
                        "evidence": host, "source": "source"})
    if tld in RISKY_TLDS:
        signals.append({"id": "risky_tld", "label": f"Unusual domain ending .{tld}", "weight": 0.35,
                        "explanation": f"Scam sites often use cheap endings like .{tld}.",
                        "evidence": host, "source": "source"})

    # Brand name used inside a domain that isn't the brand's real domain.
    tokens = set(re.split(r"[.\-]", host))
    brands = tokens & BRAND_WORDS
    near = [g for g in KNOWN_GOOD if SequenceMatcher(None, domain, g).ratio() > 0.8]
    if brands or near:
        claimed = sorted(brands)[0] if brands else near[0]
        signals.append({"id": "lookalike_domain", "label": "Lookalike domain", "weight": 0.75,
                        "explanation": f"Uses the name '{claimed}' but {domain} is not its official website.",
                        "evidence": host, "source": "source"})

    age = domain_age_days(domain)
    if age is not None and age < 90:
        signals.append({"id": "new_domain", "label": "Very new website", "weight": 0.6,
                        "explanation": f"This website was registered only {age} days ago.",
                        "evidence": domain, "source": "source"})
    return signals
