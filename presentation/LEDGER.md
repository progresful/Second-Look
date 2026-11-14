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
| Always-on mode, call listening | **planned** (code built, not run) | `CheckCoordinator.swift` | n/a | Don't claim as working |
| Deployed on Hostinger | **planned** | Not deployed | n/a | Don't claim |
| Any number of people affected by scams, losses (e.g. FBI IC3 figure) | **removed** | Not verified against a primary source; prefer a Finnish/EU source (Traficom, Finnish police) | n/a | Needed from team / research |
| Users want it | **none** | No user tests yet | n/a | Don't claim |
| Pilot partner (bank, senior association) | **none** | No contact | n/a | Only as "we'd like to pilot with…", no names implying support |
| Live scan: phone reads text on-device twice a second, boxes the message, sends at most one frame per 2 s, only when worth checking | observed + measured (code) | Real iPhone 16 over 5G, 14 Nov; `CheckCoordinator.swift` | 14 Nov | Video |
| Live verdict from Gemini in about 2 s | measured | 3 runs on a frame from the team's recording: 1.7, 2.0, 1.7 s (server-side, gemini-3.1-flash-lite) | 14 Nov | Video |
| Spoken warning on the phone | observed | Team heard it on the iPhone, 14 Nov | 14 Nov | Video |
| Runs on Meta glasses | **planned** | Not run. Video must say "shown on iPhone" | n/a | Say clearly |
