# Claim-and-evidence ledger

Labels: `measured`, `observed`, `sourced`, `estimated`, `planned`. Claims not here must not appear in any asset.

| Claim | Label | Support / source | Date | Used in |
|---|---|---|---|---|
| Backend flags 24 kinds of scam signs (17 wording rules, 2 price checks, 5 web-address checks) and explains each in plain words | measured | `api/app/rules.py`, `prices.py`, `source.py`; responses inspected | 14 Nov | SUBMISSION |
| The fake webshop photo is flagged "likely scam" with lookalike domain, price-too-low, unlock-bait and unrealistic-offer signs | observed | iOS simulator, phone-image path, on-device text reading + server rules; `screens/03-result.png` (a system notification prompt overlaps the middle) | 14 Nov | SUBMISSION, demo |
| Price check catches the €20 bait: –36% of €187 = €120, matching the cart | measured (typed text only) | `prices.py` on a typed transcript of the photo returns `price_mismatch`. In the app run, on-device text reading missed the small "€187", so only `price_too_low` showed. | 14 Nov | SUBMISSION (say "on the page text") |
| Local text check latency p50 5.6 ms, p95 450 ms (n=132, MacBook, rules only, website-age lookup on) | measured | Timing script in this session | 14 Nov | SUBMISSION |
| 44 of 44 hand-written examples classified correctly | measured, **in-sample** | `api/eval/run_eval.py`. Written alongside the rules, so **not an accuracy claim**. Use only as "regression set passes". | 14 Nov | SUBMISSION (with caveat) |
| Answer arrives as a notification plus one short paragraph, spoken aloud | observed | Simulator: notification banner seen; speech not checked by ear | 14 Nov | SUBMISSION |
| Works without network: on-device text reading + basic rules | observed (partial) | Simulator run where the image endpoint was unavailable → on-device text reading → result | 14 Nov | SUBMISSION |
| Nothing is stored; personal numbers are removed before text leaves the phone | measured (code) | `Redactor` in `OfflineChecker.swift`, `redact.py`; server keeps counts only (`/stats`) | 14 Nov | SUBMISSION |
| Meta toolkit analytics and crash reporting turned off | measured (config) | `Info.plist` MWDAT `Analytics/CrashReporting OptOut`, present in the built app | 14 Nov | SUBMISSION |
| Glasses capture, capture button, Display card, on-glasses speech | **planned** (code built, not run) | `GlassesManager.swift`; mock glasses never linked | n/a | Must be labelled "built, not yet tested on glasses" |
| Gemini reads the photo and marks suspicious spots | observed | Real iPhone 16, real key, 14 Nov: red boxes on a PayPal phishing email; team saw it | 14 Nov | Video |
| Call listening: live caption of the call, and a warning when the caller asks for a code or a "safe account" | observed (scripted audio) | iOS simulator, 14 Nov: scripted bank-impersonation call fed word by word into the real call check (`--demo-call`, no microphone in the simulator) → server → "likely scam". Live microphone on a real call not tested | 14 Nov | Video: label "scripted call" |
| Always-on mode | observed (UI only) | Simulator: switch and "watching" state shown; periodic glasses capture not run | 14 Nov | Show as option only |
| Deployed on Hostinger | **planned** | Not deployed | n/a | Don't claim |
| Any number of people affected by scams, losses (e.g. FBI IC3 figure) | **removed** | Not verified against a primary source; prefer a Finnish/EU source (Traficom, Finnish police) | n/a | Needed from team / research |
| Users want it | **none** | No user tests yet | n/a | Don't claim |
| Pilot partner (bank, senior association) | **none** | No contact | n/a | Only as "we'd like to pilot with…", no names implying support |
| Live scan: phone reads text on-device twice a second, boxes the message, sends at most one frame per 2 s, only when worth checking | observed + measured (code) | Real iPhone 16 over 5G, 14 Nov; `CheckCoordinator.swift` | 14 Nov | Video |
| Live verdict from Gemini in about 2 s | measured | 3 runs on a frame from the team's recording: 1.7, 2.0, 1.7 s (server-side, gemini-3.1-flash-lite) | 14 Nov | Video |
| Spoken warning on the phone | observed | Team heard it on the iPhone, 14 Nov | 14 Nov | Video |
| Runs on Meta glasses | **planned** | Not run. Video must say "shown on iPhone" | n/a | Say clearly |
| 57% of adults worldwide experienced a scam in the past year; 23% lost money; shopping scams affected 54% of victims | sourced | Global Anti-Scam Alliance with Feedzai, *Global State of Scams 2025*, 46,000 adults in 42 markets, 7 Oct 2025: https://www.gasa.org/post/global-scams-on-the-rise-over-half-of-adults-worldwide-report-scam-encounters | 14 Nov | Video |
| $20.877 billion in reported internet-crime losses in the US in 2025 (reported only; real total higher) | sourced | FBI IC3 *2025 Internet Crime Report*, p. 5: https://www.ic3.gov/AnnualReport/Reports/2025_IC3Report.pdf | 14 Nov | Video |
| Finland 2025: €148M attempted digital fraud; €72.5M lost (€62.9M in 2024); €38.4M via "safe account" scams; phishing targeted almost 17,000 people | sourced | Finance Finland (bank data), 20 Feb 2026: https://www.finanssiala.fi/en/news/total-value-of-attempted-digital-fraud-climbed-to-148-million/ | 14 Nov | Landing page |
| EEA 2024: €4.2B payment fraud (€3.5B in 2023); users bore ~85% of credit-transfer fraud losses, mainly from scams that manipulate payers | sourced | EBA–ECB joint report on payment fraud, 15 Dec 2025: https://www.eba.europa.eu/publications-and-media/press-releases/joint-eba-ecb-report-payment-fraud-strong-authentication-remains-effective-fraudsters-are-adapting | 14 Nov | Landing page |
