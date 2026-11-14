# Second Look: a scam check at the moment you pay

Working name. Junction 2026 entry for two challenges:
- **Meta, AI Glasses for Everyone, Everyday:** the wearable client.
- **Hostinger, Decode the Noise:** the detection engine and public API, live on Hostinger.

> **Before starting, confirm:** (1) Junction allows one project in two challenges; (2) the Hostinger challenge is still open (its page showed "Status: Closed").

---

## 1. One-liner

Look at a letter, text, email, website or payment screen and ask "Is this real?" Second Look tells you, out loud, whether it's a likely scam and why, before you pay.

## 2. Problem

- Scams increasingly target older adults and people with low digital confidence. They arrive by paper letter, SMS, phone, email and fake websites.
- Existing protection is phone-only (spam filters, paste-a-screenshot checkers) or acts after the money has moved (bank monitoring).
- The risky moment is physical: holding a letter, standing at an ATM, looking at a relative's phone. Nobody stops to take a screenshot and paste it into an app.

**Data points for slides (verify every number before presenting):**
| Claim | Source to check |
|---|---|
| People 60+ reported about $4.9B in fraud losses in the US in 2024, the most of any age group | FBI IC3 2024 Internet Crime Report / Elder Fraud Report |
| Phishing and "bank call" scams are rising in Finland | Traficom NCSC-FI, Finnish police, Finance Finland |
| 7M+ Meta AI glasses sold in 2025 (the hardware is arriving) | EssilorLuxottica annual report 2025 (verified via press, Feb 2026) |

## 3. Users

- **Primary:** older adults living independently (65+), including early cognitive decline.
- **Secondary:** people with low vision, dyslexia or limited Finnish/English; anyone in a hurry.
- **Supporting:** family members who help set it up and can (opt-in) receive an "are you sure?" ping.

## 4. Solution

### User flow
1. The user looks at a letter, SMS, email, website or payment screen.
2. They say "Hey, is this real?" or tap the glasses.
3. The glasses capture one frame, and the phone extracts the text and URL and strips personal data.
4. The Hostinger API analyzes it and returns a verdict, techniques, a source score and an explanation.
5. The glasses speak: "Likely scam. Banks never ask for your PIN by text. Call the number on your card." On Ray-Ban Display, a red, yellow or green card appears.
6. Optional, opt-in: "Ask Anna?" sends the verdict (not the content) to a trusted family member.

### Verdict levels
| Level | Spoken as | When |
|---|---|---|
| Scam | "Likely scam. Don't pay." | Strong signals plus high confidence |
| Suspicious | "Be careful." + reason | Some signals |
| Looks OK | "No scam signs found. Still check if unsure." | No signals, good source |
| Not sure | "I can't tell. Don't pay yet. Call the official number." | Low confidence, unreadable or offline |

We never say "safe". The strongest positive is "no scam signs found".

## 5. Architecture

```
[Meta glasses] --camera frame/voice--> [Phone app: OCR, PII redaction, TTS]
                                              |
                                     HTTPS (text + URL only)
                                              v
                    [Hostinger VPS: FastAPI /analyze  +  public web checker  +  metrics dashboard]
                       |-- rules engine (red-flag patterns, FI + EN)
                       |-- LLM classifier via Hostinger AI Router (techniques + explanation)
                       |-- source scoring (RDAP domain age, lookalike domains, phishing feeds)
                       '-- calibration -> verdict + confidence
```

- **Glasses client:** Meta web app or Device Access Toolkit (DAT) mobile app. Pick on day 1 with the Meta mentors.
- **Backend:** Python FastAPI in Docker on the Hostinger KVM 2 VPS, with a free domain and HTTPS.
- **Models:** Hostinger AI Router (one key, many models). A small model for speed and a larger one as a fallback for hard cases.
- **Public web checker:** a paste-text-or-URL page that gives the same verdict, so the Hostinger judges can test it without glasses.

## 6. Detection logic (Hostinger: 40% of the score)

Three independent signal groups, combined and calibrated:

1. **Manipulation techniques** (Hostinger's "Name the technique" direction)
   - False urgency ("within 24 hours", "account closed today")
   - Fake authority (bank, police, Posti, Kela, tax office, Microsoft)
   - Fear or threat appeal
   - Unusual payment (gift cards, crypto, "safe account", money transfer)
   - Relative impersonation ("Hi mum, new number")
   - Credential requests (PIN, banking codes, verification code)
   - Too good to be true (prize, refund, inheritance)
2. **Source trust** (Hostinger's "Trust the source" direction)
   - Domain age via RDAP (newly registered = risk)
   - Lookalike or typosquat domains vs. a whitelist of real Finnish banks and agencies
   - Matches against phishing feeds (PhishTank / OpenPhish; check terms)
   - Mismatch between the claimed sender and the actual link or number
3. **AI-text signals** (weak signal only, never decisive)

**Combination:** rules give explainable evidence; the LLM labels techniques and writes the plain-language reason; a final scorer maps the evidence to a verdict. If the signals disagree or confidence is low, the answer is "Not sure".

### Evaluation (show it live on the dashboard)
- **Datasets** (check licenses): UCI SMS Spam Collection; a public phishing email set; PhishTank / OpenPhish URLs vs. Tranco top domains; SemEval-2020 Task 11 for techniques.
- **Own set:** 100 hand-written Finnish and English examples (50 scams, 50 legitimate: real bank notices, real Posti messages), held out.
- **Metrics:** precision, recall, **false-positive rate**, and the share of "not sure" answers, per data source.
- **Error analysis slide:** three false positives and three misses, and what we'd change.

## 7. Privacy, consent and safety (Meta judges + Hostinger honesty)

- Capture only on explicit request (voice or tap); nothing runs in the background.
- The glasses' recording indicator is visible; the app also confirms "checking" by voice.
- **PII redaction on the phone** before upload: names, addresses, IBANs, card numbers, personal IDs.
- **No content stored** on the server. Only anonymous counts are logged for metrics.
- EU hosting (confirm the Hostinger data-center region).
- No financial advice: we flag risk and point to official channels, never "pay" or "don't pay to X".
- Family alerts are opt-in by the user; they share the verdict, not the content. No surveillance.

## 8. Accessibility and device states (Meta requirement)

| Situation | Behaviour |
|---|---|
| Audio-only glasses (RBM Gen 2) | Full experience by voice |
| Ray-Ban Display | Short card: color, verdict, one reason, large text |
| Low vision or dyslexia | Voice-first; "read it to me" reads the message aloud |
| Camera permission denied | Explains why it's needed and how to enable it; offers paste mode on the phone |
| No network | "Can't check right now. Don't pay yet." plus offline rule checks only |
| Unreadable or blurry | "I can't read it. Hold it closer and steady." |
| Glasses disconnected or low battery | Phone takes over with its own camera; tells the user |
| Slow response (>3 s) | "Still checking..." then the result; timeout leads to "Not sure" |

## 9. Competitors

| Competitor | What it does | Gap we fill |
|---|---|---|
| Bank and telco SMS filters, Android scam detection | Blocks known spam on the phone | Miss paper letters, other people's devices, ATMs |
| Norton Genie, Bitdefender Scamio | Paste or screenshot to check | You must already suspect it and know how to screenshot |
| Bank monitoring (e.g. Carefull, EverSafe) | Alerts after transactions | Acts after the money is gone |
| Meta AI / Be My Eyes | General "what is this?" | Not a scam checker, no evidence, no source scoring |

## 10. Pilot path

- **Partner:** a Finnish bank's senior program or a senior-citizen association (e.g. Vanhustyön keskusliitto / local pensioner clubs). Confirm the names before the pitch.
- **Pilot:** 4 weeks, 20 users with family helpers.
- **Measures:** checks per week, scams flagged, false alarms reported by users, confidence survey before and after.
- **Business model options:** bank-paid (fraud costs banks too), insurer-paid, or a family subscription.

## 11. Team split

| Role | Owns |
|---|---|
| Detection lead | Rules, LLM prompts, scoring, eval set and metrics |
| Backend / deploy | FastAPI, Docker, Hostinger VPS, domain, web checker, dashboard |
| Glasses client | Meta web app or DAT, capture, OCR, redaction, TTS, device states |
| Pitch and design | Decks (two versions), demo script, video backup, user test |

(With 3 people, merge pitch into glasses client.)

## 12. 48-hour plan

| Hours | Detection + backend | Glasses client | Pitch |
|---|---|---|---|
| 0-3 | Confirm rules and challenge status. VPS up, Docker hello-world, domain. | Meet Meta mentors, choose web app vs. DAT, get a device slot. | Name, problem statement, user. |
| 3-10 | `/analyze` v0: rules engine (FI + EN) + LLM technique labels. | Capture a frame on the glasses, OCR on the phone, speak a canned answer. | Collect and verify data points. |
| 10-18 | Source scoring: RDAP, lookalike domains, phishing feed. Build the 100-example eval set. | Call the live API, speak the real verdict. Display card. | Write 20 Finnish/English test examples. |
| 18-26 | Eval script: precision, recall, FPR. Calibrate thresholds. Add "Not sure". | PII redaction. Device states: offline, permission, blur, timeout. | Draft both decks. |
| 26-34 | Public web checker + metrics dashboard live on Hostinger. | Accessibility: audio-only mode, large card, "read it to me". | Test with 1-2 older adults if possible. |
| 34-40 | Error analysis, fix the worst false positives, freeze the model. | Real-world run-through: letter, SMS, fake website, ATM-like screen. Record backup video. | Rehearse both pitches. |
| 40-44 | Load test, logs scrubbed, README. | Bug fixes only. | Final slides with real metrics. |
| 44-48 | **Code freeze.** Submit to both challenges. | | Rehearse, submit. |

## 13. Deliverables checklist

**Meta**
- [ ] Working prototype on glasses (or simulator + video backup)
- [ ] Deck: problem, audience, wearable benefit, demo, accessibility, consent, pilot
- [ ] Handles permissions, errors, connectivity, device state, latency

**Hostinger**
- [ ] Public URL on Hostinger, live at judging
- [ ] API + web checker + metrics dashboard
- [ ] Precision and false-positive rate shown, with the eval method
- [ ] Explainable verdicts in plain language

## 14. Demo script (3 minutes)

1. **(0:00) Hook.** "Last year a friend's grandmother paid a fake Posti fee. She never thought to screenshot it." (Use a real story only if it's true; otherwise use a clearly hypothetical one.)
2. **(0:20) Letter.** The user holds a fake "bank" letter and asks "Is this real?" The glasses answer: "Likely scam. Real banks never ask for codes by letter. Call the number on your card."
3. **(0:50) SMS on someone else's phone.** A fake Posti text. "Suspicious. The link was registered 3 days ago and isn't posti.fi."
4. **(1:15) Real message.** A genuine bank notice. "No scam signs found." This shows we don't cry wolf.
5. **(1:35) Failure handling.** Turn off wifi: "Can't check right now. Don't pay yet." Blurry photo: "Hold it closer."
6. **(1:55) Under the hood.** Show the public web checker and dashboard with precision, FPR and the technique breakdown.
7. **(2:30) Privacy.** No content stored, PII stripped on the phone, family alerts opt-in.
8. **(2:45) Close.** Pilot plan and ask.

## 15. Pitch

### Meta version (lead with the person)

> Every day, someone's parent opens a letter, a text or a website that says "pay now or lose your account". The scam works because it arrives at the worst moment, in your hands, away from any filter.
>
> **Second Look** puts a second pair of eyes there. Look at it, ask "Is this real?", and your glasses tell you in seconds: likely scam, and why. Banks never ask for codes. This link is three days old. This isn't Posti's website.
>
> Only glasses can do this. They see the paper letter, the ATM screen and your friend's phone, hands-free, at the exact moment you'd pay. It's audio-first, works on glasses without a display, and is built for people who would never think to take a screenshot.
>
> We built it to be trusted. It only looks when you ask, removes personal data on your phone, stores nothing, and says "I'm not sure, don't pay yet" instead of guessing.
>
> Next: a 4-week pilot with 20 older adults and their families in Helsinki, with a Finnish bank or senior association. Our goal: fewer people losing their savings, and more people staying independent with confidence.

### Hostinger version (lead with detection)

> Scams are the most personal form of bad-actor content online. **Second Look** is a live, explainable scam and manipulation detector running on Hostinger.
>
> It combines three signal groups: manipulation techniques in the text, such as false urgency, fake authority and unusual payment demands; source trust, from domain age, lookalike domains and phishing feeds; and weak AI-text signals. Every verdict comes with a plain-language reason, so users learn why something is a scam.
>
> We measured it honestly: here are our precision, recall and false-positive rate on public datasets and our own 100-example Finnish and English set, plus the cases we still get wrong. When the signals disagree, it says "Not sure" instead of guessing.
>
> It's live now at our public URL: an API, a paste-and-check page and a metrics dashboard. And it already powers a real client: Meta AI glasses that check a letter or website at the moment someone is about to pay.

### 30-second version

> Scams win at the moment you're holding the letter or looking at the link. Second Look lets you ask your glasses "Is this real?" and get an answer in seconds, with the reason. Behind it is a live, explainable detector on Hostinger, measured for false positives, that says "not sure" instead of guessing. Next step: a pilot with older adults and their families in Helsinki.

## 16. Risks

| Risk | Mitigation |
|---|---|
| Two challenges dilute the effort | Shared engine; split the team; one demo, two framings |
| False positives annoy users | "Not sure" class, threshold tuning, show FPR openly |
| Model latency | Small fast model first, rules-only offline mode, 3 s timeout |
| Privacy vs. server processing | On-phone redaction, no content logs, EU hosting |
| Glasses availability | Book device time early; phone-camera fallback and backup video |
| Overclaiming | Never say "safe"; it's a second opinion, not a guarantee or financial advice |
| Unverified stats in the deck | Verify every number; cite sources on slides |

## 17. Open questions

- Is a multi-challenge submission allowed?
- Meta web app or DAT: which gets camera access fastest at the event?
- Which Finnish bank or senior organization can we name as a pilot target?
- Hostinger data-center region for EU hosting?
