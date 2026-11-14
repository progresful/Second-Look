"""Rule-based manipulation-technique detection (English + Finnish).

Each technique has regex patterns, a weight (0-1) and a plain-language
explanation. Rules are the explainable backbone; the LLM only adds to them.
"""
import re
from dataclasses import dataclass
from typing import List


@dataclass
class Technique:
    id: str
    label: str
    weight: float
    explanation: str
    patterns: List[str]


TECHNIQUES: List[Technique] = [
    Technique(
        "credential_request", "Asks for codes or passwords", 0.9,
        "Real banks and authorities never ask for PINs, passwords or banking codes by message.",
        [r"\b(pin|password|passcode|verification code|one[- ]time code|bank(ing)? (codes?|id|credentials)|card details|read me the code|tell me the code)\b",
         r"\b(tunnusluku|salasana|pankkitunnu\w*|vahvistuskoodi\w*|varmenn\w*koodi\w*|tunnuksesi)\b"],
    ),
    Technique(
        "unusual_payment", "Unusual payment method", 0.8,
        "Gift cards, crypto or moving money to a 'safe account' are classic scam payment methods.",
        [r"\b(gift ?cards?|itunes card|google play card|bitcoin|crypto(currency)?|usdt|safe account|western union|moneygram|only (by |via )?bank transfer|bank transfer only)\b",
         r"\b(lahjakort\w*|bitcoin\w*|kryptovaluut\w*|turvatili\w*|turvalliselle tilille)\b"],
    ),
    Technique(
        "false_urgency", "False urgency", 0.5,
        "Pressure to act within hours is used to stop you from thinking or checking.",
        [r"\b(urgent(ly)?|immediately|within (24|48) hours|today only|act now|final (notice|warning)|last chance|expires? (today|soon))\b",
         r"\b(kiireellinen|välittömästi|heti|24 tunnin|48 tunnin|viimeinen (muistutus|varoitus|mahdollisuus)|vanhenee)\b"],
    ),
    Technique(
        "threat", "Threat or fear appeal", 0.5,
        "Threats of closed accounts, fines or police action are used to scare you into paying.",
        [r"\b(account (will be )?(closed|suspended|blocked|locked)|legal action|arrest(ed)?|fine of|penalty|debt collection)\b",
         r"\b(tili(si)? (suljetaan|lukitaan|jäädytetään)|sakko|perintä\w*|poliisi\w* (ryhtyy|toimenpite)|oikeustoim\w*)\b"],
    ),
    Technique(
        "authority_claim", "Claims to be an authority or brand", 0.25,
        "Mentions a bank, delivery firm or authority. Not a scam sign alone, but check the sender is real.",
        [r"\b(bank|police|tax (office|administration)|customs|microsoft|apple support|dhl|ups|fedex|amazon)\b",
         r"\b(pankki|poliisi|verohallinto|vero|tulli|posti|kela|op|nordea|danske|s-pankki|aktia|mobilepay)\b"],
    ),
    Technique(
        "relative_impersonation", "Pretends to be a relative", 0.8,
        "'Hi mum, this is my new number' messages are a common scam. Call your relative on their old number.",
        [r"\b(hi|hello|hey) (mum|mom|dad)\b", r"\bmy (new|other) (number|phone)\b", r"\bphone (broke|is broken)\b",
         r"\bmoi (äiti|isä|iskä|mutsi)\b", r"\b(uusi|tämä on uusi) numero\w*\b", r"\bpuhelin (hajosi|meni rikki)\b"],
    ),
    Technique(
        "too_good", "Too good to be true", 0.6,
        "Unexpected prizes, refunds or inheritances are used as bait.",
        [r"\b(you('ve| have) won|winner|prize|lottery|inheritance|claim your (refund|reward|prize)|tax refund)\b",
         r"\b(olet voittanut|voittaja|palkinto|arvonta|perintö|veronpalautu\w* odottaa|lunasta)\b"],
    ),
    Technique(
        "small_fee", "Small fee to release something", 0.6,
        "A small 'customs' or 'delivery' fee via a link is a common parcel scam.",
        [r"\b(customs fee|delivery fee|shipping fee|pay (a )?(small )?fee|redelivery)\b",
         r"\b(tullimaksu|toimitusmaksu|lähetysmaksu|maksa \d+[,.]?\d* ?(€|eur)|paketti\w* odottaa)\b"],
    ),
    Technique(
        "remote_access", "Asks to control your device", 0.9,
        "Never install AnyDesk, TeamViewer or similar apps because a caller asks. Real support doesn't call you first.",
        [r"\b(anydesk|teamviewer|quick ?support|remote access|install (this|an|the) app so (i|we) can)\b",
         r"\b(etäyhteys\w*|asenna sovellus)\b"],
    ),
    Technique(
        "secrecy", "Asks you to keep it secret", 0.6,
        "Scammers tell you not to talk to family or the bank, because they would stop it.",
        [r"\b(don'?t tell (anyone|your family|the bank|your bank)|keep (this|it) (a )?secret|between (us|you and me))\b",
         r"\b(älä kerro|pidä tämä salassa)\b"],
    ),
    Technique(
        "changed_bank_details", "Says bank details have changed", 0.7,
        "'Our account number has changed' is a common invoice scam. Confirm by phone using a number you already know.",
        [r"\b((bank|account|payment) details have changed|new (bank )?account (number)?|updated (bank|payment) details)\b",
         r"\b(tilinumero(mme)? on muuttunut|uusi tilinumero)\b"],
    ),
    Technique(
        "unrealistic_offer", "Unrealistic offer or returns", 0.6,
        "Huge discounts, guaranteed profits or easy daily income are classic bait.",
        [r"(-[5-9]\d ?%|\b[5-9]\d ?% (off|discount)\b)", r"\bguaranteed (returns?|profits?|income)\b", r"\b\d{3,} ?% (returns?|profit)\b",
         r"\bearn \d+ ?(€|eur|euros?) (a|per) day\b", r"\b(double your money)\b",
         r"\b([5-9]\d ?% alennus\w*|taattu tuotto|tienaa \d+ ?€ päivässä)\b"],
    ),
    Technique(
        "advance_fee", "Pay a fee to get money", 0.7,
        "Paying a fee to receive a job, a prize or recovered money is a scam pattern.",
        [r"\b(registration|activation|release|recovery|processing|unlock) fee\b", r"\bpay (a )?fee to (receive|release|unlock|recover)\b",
         r"\b(rekisteröintimaksu|aktivointimaksu|käsittelymaksu)\b"],
    ),
    Technique(
        "receive_money_link", "Link to 'receive' a payment", 0.8,
        "You never need to enter card details or log in to receive money. Common marketplace (Tori) scam.",
        [r"\b(click (here )?to receive (the )?(money|payment)|enter (your )?card details to (receive|get))\b",
         r"\b(vastaanota (maksu|rahat)|syötä korttitietosi)\b"],
    ),
    Technique(
        "money_request", "Asks you to send money", 0.4,
        "A message asking you to send money. Check by calling the person on a number you already know.",
        [r"\b(send|transfer|pay|lend) (me )?\d[\d ,.]* ?(€|eur|euros?)\b", r"\b(send|transfer) (me )?(the )?money\b",
         r"\b(lähetä|siirrä|maksa) \d[\d ,.]* ?(€|euroa)\b"],
    ),
    Technique(
        "bait_unlock", "Hides the real price behind 'unlock'", 0.3,
        "Making you 'unlock' a deal or 'get access' first is used to collect your details or rush you.",
        [r"\bunlock (black friday|your (access|deal|discount|price)|the (deal|price|discount))\b", r"\bunlock your access now\b",
         r"\b(avaa tarjous|lunasta pääsy)\b"],
    ),
    Technique(
        "click_link", "Pushes you to a link", 0.3,
        "Asking you to log in or pay through a link in a message is risky. Use the official app or website instead.",
        [r"\b(click (here|the link|below)|log ?in (here|via)|verify (your )?(account|identity) (here|via|at))\b",
         r"\b(klikkaa|kirjaudu (linkin|tästä)|vahvista (tietosi|henkilöllisyytesi))\b"],
    ),
]

_COMPILED = [(t, [re.compile(p, re.IGNORECASE) for p in t.patterns]) for t in TECHNIQUES]


def detect(text: str) -> List[dict]:
    """Return matched techniques with the evidence snippet that triggered them."""
    found = []
    for tech, regexes in _COMPILED:
        for rx in regexes:
            m = rx.search(text)
            if m:
                found.append({
                    "id": tech.id, "label": tech.label, "weight": tech.weight,
                    "explanation": tech.explanation, "evidence": m.group(0), "source": "rules",
                })
                break
    return found
