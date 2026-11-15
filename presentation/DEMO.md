# Demo journey

Updated 15 Nov 2026.

> Someone sees a too-good Ray-Ban deal on `ray-band.com`. They **look at the screen through their Meta glasses**. Second Look **reads the page, checks the wording, prices and web address**, and they **hear "likely scam" with one plain reason** through the glasses, and see the marked evidence on the phone. Then a "bank" calls and asks for a code: the glasses warn mid-call.

## Must work (reliably, repeated runs)
| Step | Status |
|---|---|
| Glasses connect (Meta AI app, developer mode) and stream video to the app | Verified on real glasses, 14 Nov |
| Glasses video → check → verdict in about 2–3 s | Verified on real glasses, 14 Nov (app log + debug viewer) |
| Spoken answer through the glasses, warm on-device voice | Heard by the team, 14 Nov |
| Phone shows the alert card with marked evidence | Verified on iPhone 16 |
| Always-on and on-request modes | Verified on real glasses, 14 Nov |
| Call listening through the glasses microphone, warning on "read me the code" | Heard by the team, 14 Nov |
| Server at https://secondlook.pgf.lv (Gemini enabled) | Live |
| Web simulator ("Try it" on the landing page) | Live; desktop and phone |

## Not working / not confirmed
- **Alert card on the glasses display**: built, does not show ("display not available on these glasses or not ready").
- **Glasses capture button** as the trigger: not confirmed. Use always-on mode or the phone's check button in the demo.
- Small or distant text: the frame is 720×1280, so hold the thing close or large. The app takes a full-resolution photo when it sees text it can't read.

## Demo resilience
| Item | Status |
|---|---|
| Works without glasses | Yes: phone camera check and live scan; web simulator needs nothing |
| Works without network | Partly: on-device text reading + basic rules, says "not sure" |
| Debug view for the booth | https://secondlook.pgf.lv/debug shows the glasses frame and the app log (turn on "Debug mirror" in settings) |
| Guest mode, no login | Yes |
| Recorded backup | `video/second-look-60s.mp4` (iPhone, made before the glasses worked). **No recording of the glasses journey yet: make one.** |
| App install | Development build, expires 7 days after install: reinstall before the demo |
