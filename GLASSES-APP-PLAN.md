# Second Look: Meta glasses app plan

Status: decisions made (14 Nov 2026). Remaining: iPhone + Apple ID signing, Wearables Developer Center account.

**Decisions**
- Platform: **native iOS (Swift + SwiftUI)**
- Glasses: **both**, Ray-Ban Display (card + voice) and Ray-Ban Meta Gen 2 (voice only)
- Images: **always sent to Gemini** via our backend `/analyze-image` (the API key stays on the server, never in the app). On-device OCR is kept only as the offline fallback.
- Scope: **photo check (core) + call listening mode**. Family alert and Finnish UI are stretch goals.
Backend already exists: `second-look/api` (`/analyze` text, Gemini provider added; `/analyze-image` next).

## 1. Tech stack check (Nov 2026)

| Item | Finding | Source |
|---|---|---|
| SDK | Meta Wearables Device Access Toolkit (DAT) **1.0.1, developer preview** | [DAT iOS](https://github.com/facebook/meta-wearables-dat-ios), [DAT Android](https://github.com/facebook/meta-wearables-dat-android) |
| iOS install | Swift Package Manager: `https://github.com/facebook/meta-wearables-dat-ios` | DAT iOS README |
| Android install | Maven Central, `mwdat = "1.0.1"`, app ID in `AndroidManifest.xml` | DAT Android README |
| Stable features | Camera stream + **photo capture during stream**, Display (Ray-Ban Display), Inputs (button, capture, navigation, drag), Motion, **on-device Speech recognition**, **"Hey Meta" voice invocation**, session/device state, permissions and registration | READMEs |
| Experimental (OK for demo, not for publishing) | Standalone high-quality photo capture; synced PCM audio from the glasses mics | READMEs |
| Testing without glasses | **MockDeviceKit** (`mwdat-mockdevice`) | READMEs |
| Known issue | Device-state session unreliable together with camera stream; detect drops from stream errors and timeouts | [Known issues](https://wearables.developer.meta.com/docs/knownissues) |
| Privacy default | **DAT analytics and crash reporting are ON by default.** Opt out in Info.plist (`MWDAT > Analytics > OptOut`) | DAT iOS README |
| AI dev help | Docs MCP server `https://mcp.developer.meta.com/wearables` (no auth); Claude Code plugin `mwdat-ios` | READMEs |
| Setup | Wearables Developer Center: organization, project, release channel for test users, app ID | wearables.developer.meta.com |
| This Mac | **Xcode 27.2 installed.** No Java, adb, Android Studio or Flutter | local check |

**Recommendation: native iOS (Swift + SwiftUI).** The tools are already installed, the SDK is official, and Apple Vision (OCR + QR) and AVSpeech are built in.

## 2. Architecture

```
Glasses (camera, mics, speakers, Display, button)
   │  DAT session (Bluetooth / Wi-Fi via Meta AI app)
   ▼
iPhone app "Second Look" (SwiftUI)
   ├─ Trigger: "Hey Meta" voice invocation | glasses capture button | in-app button
   ├─ Capture: camera stream (low res) → photo capture on trigger
   ├─ On-device: Apple Vision OCR (fi + en) + QR decode → PII redaction (Swift port of redact.py)
   ├─ Call mode: DAT Speech (on-device) live transcript → chunked checks
   ├─ Network: POST /analyze-image (photo → Gemini via backend)  |  POST /analyze (call transcript text)
   ├─ Offline: Swift rules subset → "Can't check fully. Don't pay yet."
   └─ Output: AVSpeechSynthesizer → glasses speakers; DAT Display card (Ray-Ban Display)
   ▼
Hostinger VPS: FastAPI (rules + prices + source + Gemini)  ── Gemini API
```

### Screens (phone)
1. **Onboarding:** what it does, consent (camera and mic only on request, nothing stored), language, voice speed, optional trusted contact.
2. **Connect glasses:** DAT registration and permissions, status (connected, battery, streaming).
3. **Home:** big "Check this" button, "Listen to this call" button, last result card.
4. **Result:** verdict color, spoken text, reasons, evidence, "Call official number" helper.
5. **Settings:** image mode (send photo to Gemini) on/off, offline mode, delete everything, about privacy.

### Glasses experience
- **Audio-first (all glasses):** a "Checking…" earcon, then the spoken verdict plus one reason, max ~12 seconds.
- **Ray-Ban Display:** card with color dot, verdict, up to 3 reasons, next step. Large text, high contrast.
- **Inputs:** capture button = check; long press = repeat the answer; a gesture to dismiss.

## 3. Detailed flows

**A. "Is this real?" (photo check)**
1. Trigger (voice, button, app), then speak "Checking" and turn the recording indicator on.
2. Start the stream if needed, capture one photo, then stop the stream (saves battery, ends the capture).
3. OCR + QR on the phone. If no text: "I can't read it. Hold it closer and steady."
4. Send the photo to `/analyze-image` (8 s timeout). The backend sends it to Gemini, then runs the rules, price and domain checks on Gemini's extracted text, and returns the verdict + boxes. If offline or timed out: on-device OCR + offline rules.
5. Speak the verdict, show the card, store nothing; delete the photo from memory.

**B. "Listen to this call" (call mode)**
1. The user starts it explicitly; a "Mic on: this call only" banner shows.
2. DAT Speech gives an on-device transcript (or Apple Speech on the phone as a fallback).
3. Every ~10 s, or on keywords (code, safe account, AnyDesk, gift card), send the transcript text to `/analyze`.
4. On "scam", play a discreet warning in the ear: "This sounds like a scam. Hang up and call your bank."
5. Stop on hang-up or a button press; the transcript is discarded.

**C. Device states and errors (Meta judging)**
| Event | Behaviour |
|---|---|
| Not registered or permission denied | Guided fix screen; fallback to the phone camera |
| Glasses disconnected or stream error | "Glasses disconnected, using phone camera" |
| Low battery | Warn under 15%; stream stays off between checks |
| No network | Offline Swift rules + "Don't pay yet" |
| API slow | "Still checking…" at 2 s, "Not sure" at timeout |
| Unreadable photo | Ask to hold closer, retry once automatically |

## 4. Build plan (hours from start)

| Hours | Work | Done when |
|---|---|---|
| 0-2 | Developer Center org, project, app ID, release channel. Xcode project, add DAT via SPM, Info.plist (analytics opt-out, permissions). Install the docs MCP and Claude plugin. | App builds and runs on an iPhone |
| 2-5 | MockDeviceKit: session, stream, photo capture against the mock. Simple SwiftUI home. | Mock photo appears in the app |
| 5-9 | `/analyze-image` client (photo upload), AVSpeech output, offline fallback (Vision OCR + Swift rules). | Photo of an SMS gives a spoken verdict (phone camera ok) |
| 9-13 | Real glasses: registration, permissions, capture button, "Hey Meta" invocation. | Check works hands-free on glasses |
| 13-17 | Display card (Ray-Ban Display), audio-only path (Gen 2). | Both glasses work |
| 17-22 | Device states: disconnect, offline, timeout, permission, battery. | Each state demoable on cue |
| 22-27 | Call mode: speech transcript, chunked checks, warning in the ear. | Fake "OP Security" call flagged live |
| 27-31 | Backend `/analyze-image` hardening, Gemini prompt tuning on real glasses photos, consent text. | Webshop photo gets Gemini boxes |
| 31-36 | Accessibility pass (Dynamic Type, VoiceOver, speech speed), Finnish strings. | Usable with VoiceOver |
| 36-42 | Real-world run: letter, SMS, webshop, QR sticker, call. Record backup video. | Video recorded |
| 42-48 | Freeze, bug fixes, rehearse. | Submitted |

## 5. Repo layout (planned)

```
second-look/
  api/                 # existing FastAPI backend
  ios/SecondLook/      # new Xcode project
    App/               # SwiftUI app, onboarding, settings
    Glasses/           # DAT session, camera, display, inputs, speech
    Check/             # OCR, QR, redaction, offline rules, API client
    Voice/             # AVSpeech output, earcons
```

## 6. Risks

| Risk | Mitigation |
|---|---|
| Developer preview APIs change or break | Pin 1.0.1; follow the samples folder; ask mentors early |
| Device time is limited | Build everything on MockDeviceKit and the phone camera first |
| Experimental audio/capture features | Use stable in-stream photo capture; Apple Speech as the call-mode fallback |
| Photo always goes to Gemini (Google): weaker privacy story for Meta judges | Say it plainly in onboarding; capture only on request; photo downscaled and not stored by us; Gemini API data terms checked and cited; offer on-device mode as the roadmap |
| Code signing on a real iPhone | Apple ID with a personal team works for a demo; set it up in hour 0 |

## 7. Still open
- iPhone model + Apple ID for code signing?
- Wearables Developer Center organization and app ID created?
- Gemini API key (from the Junction credits form) for testing `/analyze-image`.
- Check Gemini API data-use terms for paid vs. free tier before claiming anything about image retention.
