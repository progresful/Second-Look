# Meta glasses: what Second Look needs

Based on one search of public sources (Nov 2026). **Confirm everything with the Meta mentors on day 1**, especially the items marked ❓.

## 1. Which build path

| Path | What it gives | Camera? | Fits us? |
|---|---|---|---|
| **Device Access Toolkit (DAT), iOS or Android** | Native SDK: `MWDATCamera` (stream, pick resolution and frame rate, **capture a single frame**), `MWDATDisplay` (text, images, lists, buttons on Ray-Ban Display), experimental audio | **Yes** | **Yes. Use this.** |
| **Web Apps (Ray-Ban Display only)** | HTML/CSS/JS on a 600×600 display, Neural Band gestures | ❓ Not documented in what I found | Display only. Good for a result card, not for capture. |

**Decision:** a DAT mobile app on the phone. The glasses capture a frame and the phone does OCR, redaction, the API call and text-to-speech. Ray-Ban Display gets a card through `MWDATDisplay`; RBM Gen 2 is audio-only.

**iOS or Android:** pick the platform of the strongest mobile dev on the team. Mentors: Dennis Punjabi (DAT iOS), Amanda Le (DAT Android). A community Flutter wrapper exists (`flutter_meta_wearables_dat`), but stick to the official SDKs for reliability.

## 2. What we need

**Hardware and accounts**
- [ ] A slot on Ray-Ban Display (visual card demo) and RBM Gen 2 (audio-only demo). Book early.
- [ ] Meta developer account on wearables.developer.meta.com and the glasses paired to a test phone with Meta AI app ❓ (developer mode steps).
- [ ] **Mock Device Kit** so we can build without hardware. Start with this in hour 0.
- [ ] Phone: iPhone with Xcode, or Android with Android Studio, plus a cable.

**Code (phone app)**
- [ ] Connect to the glasses and handle permissions (camera, Bluetooth, microphone).
- [ ] Trigger: an app button, a Neural Band gesture (Display) or a phone voice command. ❓ Ask whether a custom "Is this real?" voice trigger or a glasses tap is available to third-party apps.
- [ ] Capture one frame, then run on-device OCR (Apple Vision or Google ML Kit), so images never leave the phone.
- [ ] PII redaction on the phone, then `POST /analyze` to the Hostinger API.
- [ ] Speak the `spoken` field with phone TTS through the glasses speakers.
- [ ] Display card: color, verdict, one reason, large text (Ray-Ban Display only).

**Device states (judges asked for these)**
| State | Handling |
|---|---|
| Glasses disconnected, low battery, removed | Fall back to the phone camera and say so |
| Camera permission denied | Explain why, offer paste mode |
| No network | Offline rules only: "Can't check fully. Don't pay yet." |
| Blurry or no text from OCR | "Hold it closer and steady." |
| Slow API (>3 s) | "Still checking…", then time out to "Not sure" |

Known issue in Meta's docs: `DeviceStateSession` (iOS) / `DeviceSession` (Android) is **unreliable together with a camera stream**. Plan to detect disconnects from stream errors and timeouts instead, and ask the mentors for the current workaround.

## 3. Meta judging checklist

- [ ] **First-person benefit:** demo a paper letter and someone else's phone, things a phone filter can't see.
- [ ] **Audio-first and display:** same flow on Gen 2 (voice) and Display (card).
- [ ] **Inclusive:** large text, plain words, no jargon, works without looking at the phone.
- [ ] **Consent:** capture only on request, recording LED visible, nothing stored, family alerts opt-in.
- [ ] **Robustness:** show at least two failures live (offline, blurry).
- [ ] **Performance:** show latency. On-device OCR keeps the upload small.
- [ ] **Adoption:** pilot slide (bank or senior association, 20 users, 4 weeks).

## 4. Questions for the Meta mentors (hour 0)

1. Can third-party DAT apps use a voice trigger or glasses tap, or only an in-app button or Neural Band?
2. Is synced audio out to the glasses speakers fine through normal Bluetooth audio, or should we use the DAT audio module?
3. Can Web Apps access the camera at all?
4. Single-frame capture latency and the best resolution for reading text?
5. Workaround for the device-state + camera-stream known issue?
6. Any rules on recording indicators or bystander privacy we must show?

## Sources
- [Meta DAT iOS (GitHub)](https://github.com/facebook/meta-wearables-dat-ios), [Meta DAT Android (GitHub)](https://github.com/facebook/meta-wearables-dat-android)
- [DAT integration overview](https://wearables.developer.meta.com/docs/develop/dat/build-overview/), [Known issues](https://wearables.developer.meta.com/docs/knownissues)
- [Two SDK paths for Display glasses (PPC Land)](https://ppc.land/meta-opens-display-glasses-to-developers-with-two-sdk-paths/)
- [DAT public preview (UploadVR)](https://www.uploadvr.com/meta-wearables-device-access-toolkit-public-preview/)
