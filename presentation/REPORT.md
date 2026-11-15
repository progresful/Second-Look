# Report: Second Look, Meta track

Date: 15 Nov 2026 (the gates and open items below were last reviewed 14 Nov; items marked there may be older than the section above). Nothing has been submitted, posted or uploaded.

## What is implemented and working (verified by running)
- **Real Meta glasses (14 Nov):** the app connects through Meta's Device Access Toolkit and receives compressed video (HEVC, 720×1280, 7 fps), decoded on the phone. Text is read on-device; a frame goes to the server only when it is worth checking; the verdict comes back in about 2–3 s and is spoken through the glasses. Always-on and on-request modes both run.
- **Calls:** listening uses the glasses microphone; the team heard the glasses warn when a caller asked for a PIN.
- **Voice:** warm on-device voice (Kokoro), works offline.
- **iPhone 16:** phone-camera check and live scan; alert card with the action, the reason (naming the real sender) and the marked evidence.
- **Server** (`api/`, live at https://secondlook.pgf.lv): 17 wording rules, 2 price checks, 5 web-address checks, Gemini for pictures (models chosen by content), PII redaction, counts-only stats, app-token check. Live frame about 2 s server-side.
- **Regression set:** 44/44 pass (**in-sample**, not accuracy).
- **Landing page** (https://secondlook.pgf.lv): story, sourced scam figures, and a "Try it" simulator with real server output for four examples plus a scripted call.
- **Debug viewer** (https://secondlook.pgf.lv/debug): the glasses frame and the app log.

## Not working, unverified or unfinished
- **Alert card on the glasses display:** built, does not show.
- **Glasses capture button** as the trigger: not confirmed.
- **Landing page opening (3D glasses into the simulator):** in progress locally, not deployed.
- **Simulator:** letters & bills and QR codes have no example yet; the phone-in-hand call picture is a placeholder.
- **Video:** `video/second-look-60s.mp4` predates the glasses run and shows the iPhone. No recording of the glasses journey.
- **Deck / PDF:** not made.
- **User tests:** none. No accuracy measurement on unseen scams.
- **Repository:** private.

## Release gates
| Gate | Result | Note |
|---|---|---|
| Core journey completes reliably over repeated runs | **PASS (once observed)** | Glasses video → check → spoken warning ran on 14 Nov. Repeat it several times before the demo |
| A stranger can explain it after a short viewing | **FAIL** | Communication test not run (VALIDATION.md) |
| Every important claim is in the ledger with support | **PASS** | LEDGER.md, updated 15 Nov |
| Strongest technical contribution is visible | **PASS (text and page)** | SUBMISSION.md and the landing page; no deck |
| Challenge fit is explicit | **PASS** | SUBMISSION.md "Challenge fit" |
| Demo and repo work incognito, on a phone, no login | **FAIL** | Demo URL works; repository is private |
| Recorded backup of the demo exists | **FAIL** | Only the iPhone video; no glasses recording |
| Name, promise, numbers consistent, no typos | **PASS (current files)** | "Second Look", 17 + 2 + 5 sign types, 44 in-sample, about 2–3 s |
| PDF readable and within limit | **FAIL** | No deck/PDF |
| Every field and link checked | **FAIL** | Source and video links not ready |
| Final submission confirmed | **FAIL** | For the team to do |

## Open items (in priority order)
1. Record the glasses journey (webshop check and the call warning) as the backup and for the video.
2. Make the repository public; check it holds no keys or tokens first.
3. Finish and deploy the landing page opening (3D glasses into the simulator).
4. Upload a video: re-cut the 60 s video with the glasses recording, or label it "shown on iPhone".
5. Get the alert card to show on the glasses display.
6. Run the communication test (3 people); a product test with older adults if possible.
7. Deck (6 slides) + PDF and `cover.png`, if the form needs them.
8. Reinstall the app before the demo (development build expires after 7 days).

## Needed from team
- The phone-in-hand call photo and examples for letters & bills and QR codes (simulator).
- Team names, roles, photos (for the deck).
- 3 people for the communication test.
- Rules confirmation: deadline, video and pitch limits, and whether one project may enter Meta + Gemini.
- Approval of the punchline and description in SUBMISSION.md, and the final **Submit** click.
