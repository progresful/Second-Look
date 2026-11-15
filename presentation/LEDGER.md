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
| Glasses session, camera video and scam check on real Meta glasses | observed | Real glasses, 14 Nov: compressed video (HEVC, 720×1280, 7 fps) decoded on the phone → text read on-device → frame sent to the server → verdict in about 2–3 s → spoken through the glasses. App log and debug viewer. Glasses capture button not confirmed | 14 Nov | SUBMISSION, DEMO |
| Gemini reads the photo and marks suspicious spots | observed | Real iPhone 16, real key, 14 Nov: red boxes on a PayPal phishing email; team saw it | 14 Nov | Video |
| Call listening: warns when the caller asks for a code or a "safe account" | observed | Real glasses, 14 Nov: glasses microphone (Bluetooth) used for listening; the team heard the glasses warn when someone asked for a PIN. Earlier: scripted call in the simulator | 14 Nov | SUBMISSION, DEMO |
| Always-on and on-request modes | observed | Real glasses, 14 Nov: always-on runs live scan from the glasses video and speaks only on a finding; on request runs one check | 14 Nov | SUBMISSION, DEMO |
| Public server and landing page at https://secondlook.pgf.lv | observed | Hetzner (not Hostinger), nginx + HTTPS, Gemini enabled; checks need the app token | 14 Nov | SUBMISSION links. Do not claim Hostinger |
| Any number of people affected by scams, losses (e.g. FBI IC3 figure) | **removed** | Not verified against a primary source; prefer a Finnish/EU source (Traficom, Finnish police) | n/a | Needed from team / research |
| Users want it | **none** | No user tests yet | n/a | Don't claim |
| Pilot partner (bank, senior association) | **none** | No contact | n/a | Only as "we'd like to pilot with…", no names implying support |
| Live scan: phone reads text on-device twice a second, boxes the message, sends at most one frame per 2 s, only when worth checking | observed + measured (code) | Real iPhone 16 over 5G, 14 Nov; `CheckCoordinator.swift` | 14 Nov | Video |
| Live verdict from Gemini in about 2 s | measured | 3 runs on a frame from the team's recording: 1.7, 2.0, 1.7 s (server-side, gemini-3.1-flash-lite) | 14 Nov | Video |
| Spoken warning on the phone | observed | Team heard it on the iPhone, 14 Nov | 14 Nov | Video |
| Runs on Meta glasses | observed | See the glasses row above. The 60 s video predates this and shows the iPhone | 14 Nov | SUBMISSION |
| 57% of adults worldwide experienced a scam in the past year; 23% lost money; shopping scams affected 54% of victims | sourced | Global Anti-Scam Alliance with Feedzai, *Global State of Scams 2025*, 46,000 adults in 42 markets, 7 Oct 2025: https://www.gasa.org/post/global-scams-on-the-rise-over-half-of-adults-worldwide-report-scam-encounters | 14 Nov | Video |
| $20.877 billion in reported internet-crime losses in the US in 2025 (reported only; real total higher) | sourced | FBI IC3 *2025 Internet Crime Report*, p. 5: https://www.ic3.gov/AnnualReport/Reports/2025_IC3Report.pdf | 14 Nov | Video |
| Finland 2025: €148M attempted digital fraud; €72.5M lost (€62.9M in 2024); €38.4M via "safe account" scams; phishing targeted almost 17,000 people | sourced | Finance Finland (bank data), 20 Feb 2026: https://www.finanssiala.fi/en/news/total-value-of-attempted-digital-fraud-climbed-to-148-million/ | 14 Nov | Landing page |
| EEA 2024: €4.2B payment fraud (€3.5B in 2023); users bore ~85% of credit-transfer fraud losses, mainly from scams that manipulate payers | sourced | EBA–ECB joint report on payment fraud, 15 Dec 2025: https://www.eba.europa.eu/publications-and-media/press-releases/joint-eba-ecb-report-payment-fraud-strong-authentication-remains-effective-fraudsters-are-adapting | 14 Nov | Landing page |
| Spoken answer uses an on-device voice (Kokoro-82M via FluidAudio), works offline | observed | Heard by the team on the iPhone and through the glasses, 14 Nov; `ios/project.yml` | 14 Nov | SUBMISSION |
| The reason names the real sender shown, never a company that isn't in the picture | observed | Fixed after a Netflix email was described as a "bank" message; `api/app/llm.py`, `scorer.py` | 14 Nov | SUBMISSION |
| Alert card on the glasses display | **not working** | Built; app reports "display: not available on these glasses or not ready" | 14 Nov | SUBMISSION limitations only |
| Web simulator shows real output | measured | `web/media/sim/detections.json` holds the server's verdicts, reasons and boxes for the four example images; the call example is scripted | 14 Nov | SUBMISSION ("Try it") |
| Source is public | **not yet** | github.com/progresful/Second-Look is private | 15 Nov | Make public before submitting |
