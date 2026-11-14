# Report: Second Look, Meta track

Date: 14 Nov 2026. Nothing has been submitted, posted or uploaded.

## What is implemented and working (verified by running)
- Backend (`api/`): `/analyze` with 17 wording rules, 2 price checks, 5 web-address checks; plain-language reasons; PII redaction; counts-only stats. Ran locally; latency p50 5.6 ms, p95 450 ms (n=132).
- Regression set: 44/44 pass (**in-sample**, not accuracy).
- iOS app (`ios/`): builds; in the iOS simulator, the bundled webshop photo → server image endpoint unavailable → on-device text reading → server rules → "likely scam", red screen, one paragraph (`screens/01–03`).
- **Real iPhone 16 (14 Nov):** app installed and run. The phone-camera check works, and live scan works: it reads the camera text on the phone twice a second, boxes the message, and sends at most one frame every 2 s to Gemini (fast model) when it's worth checking. Red boxes mark the scam signs. It ran over 5G through a temporary Cloudflare tunnel, which only accepts requests carrying the app token; the team reported it working. No glasses involved.
- **Gemini enabled (14 Nov):** real key. Models are chosen by content: live frame ~1.8 s (phone sends its own text reading; Gemini only judges and marks where), tapped photo 8.6 s, text 0.8–1.8 s (timed on the server).
- Web simulation of the glasses view (`api/static/glasses.html`, 17 scenarios): runs in a browser. It is a **simulation**, not glasses.

## Planned, simulated or unverified
- Meta glasses capture, capture button, Ray-Ban Display card, on-glasses speech (code built; **never run**: mock glasses didn't connect, no device time).
- Call listening and always-on mode (code built, not run; simulator has no mic).
- Gemini photo reading now works with a real key (see above). Not yet checked for accuracy.
- Hostinger deployment (not done). Spoken output (not checked by ear). Notification banner seen once on the other simulator; failed in the recording because permission wasn't granted.

## Why the deck and video were not made
The user's rule: stop before deck/video if the product can't be run. The phone path runs, but the **core journey for this track, the glasses capture, has never run**, and the only recording has a system permission prompt over the screen. A deck or video now would show a phone app as a glasses product. Make them after the "Needed from team" items 1–3.

## Release gates (section 12)
| Gate | Result | Note |
|---|---|---|
| Core journey completes reliably over repeated runs | **FAIL** | Phone-image path ran 3× in simulators; glasses journey never ran |
| A stranger can explain it after a short viewing | **FAIL** | Communication test not run (VALIDATION.md) |
| Every important claim is in the ledger with support | **PASS** | LEDGER.md; unsupported claims removed (scam statistics, users, partners) |
| Strongest technical contribution is visible | **PASS (text only)** | Price-consistency + lookalike-domain checks in SUBMISSION.md; no deck yet |
| Challenge fit is explicit | **PASS** | SUBMISSION.md "Challenge fit", BRIEF.md |
| Demo and repo work incognito, on a phone, no login | **FAIL** | No public demo URL, no repository |
| Recorded backup of the demo exists | **FAIL (draft only)** | `video/backup-demo-DRAFT.mp4`: real, but permission prompt covers the screen, and it's the phone path |
| Name, promise, numbers consistent, no typos | **PASS (current files)** | "Second Look", 24 sign types, 5.6/450 ms, 44 in-sample. Re-check when the deck/video exist |
| PDF readable and within limit | **FAIL** | No deck/PDF yet |
| Every field and link checked | **FAIL** | Links missing (demo, source, video) |
| Final submission confirmed | **FAIL** | For the team to do; status page says "Closed" (unverified) |

## Open items (in priority order)
1. Run the webshop check on Meta glasses (Ray-Ban Display via DAT); record it. This is the core journey.
2. Re-record the simulator backup cleanly: tap **Allow** once on the iPhone Air simulator's notification prompt (or grant Claude access in the simulator panel), then rerun with `xcrun simctl launch <device> fi.junction.secondlook --demo-check`.
3. Run the communication test (3 people) and, if possible, a product test (VALIDATION.md).
4. Publish the source (git repo + README with ≤3-command setup, screenshots, limitations, disclosure of Meta DAT, Apple Vision, FastAPI, Gemini).
5. Done 14 Nov: server deployed at https://secondlook.pgf.lv (Hetzner, Ubuntu, nginx + HTTPS, systemd). Checks need the app token; the public web demo pages load but their checks are refused without it. Gemini enabled.
6. Then make the video (60 s) and the 6-slide deck + PDF; make `cover.png`.
7. Remove the debug-only `--demo-check` flag effect from release builds (it's `#if DEBUG` already; confirm).

## Needed from team
- **Device time** on Ray-Ban Display and RBM Gen 2 at the Meta booth, and help from the DAT iOS mentor if mock/real glasses still don't connect.
- **Developer Center** app ID and client token (or confirmation that Developer Mode is on), plus the Apple Team ID for signing on a real iPhone.
- **A real iPhone** for testing.
- **Team** names, roles, photos (for the deck).
- **Real user observations**: 3 people for the communication test; older adults for the product test if possible.
- **A sourced statistic** on scams in Finland (Traficom / Finnish police / Finance Finland) if you want a problem number; we removed the unverified FBI figure.
- Any **pilot partner** contact (bank, senior association). We won't name one without permission.
- **Gemini API key** (if you want to claim Gemini) and **Hostinger** access (if you want a public demo URL).
- **Rules confirmation**: what "Status: Closed" means, the deadline, video/pitch limits, and whether one project may enter Meta + Hostinger + Gemini.
- **Approval** of the punchline and description in SUBMISSION.md, and the final **Submit** click.
