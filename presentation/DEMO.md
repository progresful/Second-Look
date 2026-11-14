# Demo journey

> An older adult sees a too-good Ray-Ban deal on `blickerz.com`. They **look at the screen and tap "check"** (or press the glasses capture button). Second Look **reads the page, checks the wording, prices and web address**, and they **hear and see "likely scam" with one plain reason**. We show the improvement through the **evidence it names on the real page** (lookalike domain, prices that don't add up).

## Must work (reliably, repeated runs)
| Step | Status |
|---|---|
| Backend `/analyze` running, returns verdict + reasons | Verified (local, 132 requests) |
| Price-consistency and lookalike-domain checks on the webshop text | Verified |
| iOS app: photo → check → red screen + notification + one paragraph | Verified in simulator with the bundled photo (phone-image path) |
| Glasses capture → check | **Not verified** (code built; mock glasses didn't link; no real device yet) |
| Spoken answer | Code path ran in simulator; audio not checked by ear |

## Must prove
- First-person capture works on Meta glasses (needs device time at the Meta booth).
- Trust: nothing stored, "not sure" instead of guessing, offline fallback. Partially shown in code and onboarding text; offline path ran once in the simulator (server image endpoint unavailable → on-device text reading).

## Optional
- Always-on mode (every 15 s), call listening, Ray-Ban Display card, Gemini photo reading (needs `GEMINI_API_KEY`), Hostinger deployment, the 17-scenario web simulation (`api/static/glasses.html`).

## Demo resilience
| Item | Status |
|---|---|
| Seeded demo data | Yes: bundled `demo-webshop.jpg` + "Demo: webshop photo" menu item (debug build) |
| Guest mode, no login | Yes |
| Tested on a phone | **No**, simulator only |
| API rate limits / costs | Rules engine is local; Gemini not enabled, so no costs checked |
| Recorded backup | `video/backup-demo.mp4` (simulator, phone-image path); see REPORT.md |
