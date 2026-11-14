# Second Look: iOS app for Meta glasses

SwiftUI app using Meta Wearables Device Access Toolkit (DAT) **1.0.1** (pinned).

## Run
```bash
cd second-look/ios
xcodegen generate                       # creates SecondLook.xcodeproj from project.yml
open SecondLook.xcodeproj
```
Start the backend first (`second-look/api`, port 8765). The simulator reaches it at `localhost`; on a real iPhone set the server URL in Settings (your Mac's LAN IP or the Hostinger URL).

First copy the template: `cp Config.example.xcconfig Config.xcconfig` (it is git-ignored; it holds your team ID and app token). Fill `Config.xcconfig` for real glasses: `DEVELOPMENT_TEAM`, and `META_APP_ID` + `CLIENT_TOKEN` from the Wearables Developer Center (not needed if the glasses are in Developer Mode).

## What's in it
| Area | File |
|---|---|
| Glasses: registration, session, photo capture, capture button, Display card, on-glasses speech | `Glasses/GlassesManager.swift`, `Glasses/DisplayCards.swift` |
| Check flow, fallbacks, call mode | `Check/CheckCoordinator.swift` |
| Server client (`/analyze-image` → Gemini, `/analyze`) | `Check/APIClient.swift` |
| Offline: Vision OCR + rules + PII redaction | `Check/OfflineChecker.swift` |
| Voice out, phone-mic fallback for calls | `Voice/` |
| UI: home, result with Gemini boxes, onboarding/consent, settings | `Views/` |
| Mock glasses (DEBUG) | `Glasses/MockGlasses.swift` |

Privacy: DAT analytics and crash reporting are opted out in `Info.plist`.

## Status (14 Nov 2026)
- Builds for the simulator and runs.
- New design (animated aura background, protection list, on request / always on, results as a notification + one paragraph). Verified: demo photo turns the screen red with a "Likely scam" notification.
- Verified earlier: demo photo → server unavailable for images (no Gemini key) → on-device OCR → server rules → "Likely scam" with 4 warning signs, spoken.
- **Mock glasses link: retest.** It reported `linkState = disconnected`, but at that time XcodeGen had overwritten `Info.plist` (no `MWDAT` keys). Fixed now (`INFOPLIST_FILE` in project.yml); not re-verified because the simulator was in use by another session.
- Don't put `info:` back in project.yml: XcodeGen would regenerate and wipe `Info.plist`.
- Not tested yet: real glasses, Display card, capture button, call mode, Gemini image mode (needs `GEMINI_API_KEY` on the server).
