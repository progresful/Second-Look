<p align="center">
  <img src="docs/images/banner.jpg" alt="Second Look: for people too smart to get scammed. So, everyone." width="100%">
</p>

<h1 align="center">Second Look</h1>

<p align="center">
  <b>A second opinion before you pay, through your Meta AI glasses.</b><br>
  Look at a letter, a text, a webshop or listen to a call. In about two seconds you hear whether it shows scam signs, and why.
</p>

<p align="center">
  <a href="https://youtu.be/4tVMIr4o9ec"><b>▶ Watch the video</b></a> &nbsp;·&nbsp;
  <a href="https://secondlook.pgf.lv"><b>Try it in the browser</b></a> &nbsp;·&nbsp;
  <a href="ios"><b>iOS app</b></a> &nbsp;·&nbsp;
  <a href="api"><b>Server</b></a>
</p>

<p align="center">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white">
  <img alt="iOS 17.2+" src="https://img.shields.io/badge/iOS-17.2%2B-000000?logo=apple&logoColor=white">
  <img alt="Meta Wearables DAT" src="https://img.shields.io/badge/Meta%20Wearables-DAT%201.0.1-0467DF?logo=meta&logoColor=white">
  <img alt="FastAPI" src="https://img.shields.io/badge/FastAPI-Python-009688?logo=fastapi&logoColor=white">
  <img alt="Gemini" src="https://img.shields.io/badge/Gemini-image%20checks-8E75B2?logo=googlegemini&logoColor=white">
  <img alt="Junction 2026" src="https://img.shields.io/badge/Junction-2026-FF453A">
</p>

---

## The problem

Scams don't wait in your spam folder. They come on paper, on screens and on the phone, and they want more than a payment: a bank code, a password, your details, or remote access to your computer. Most arrive where no filter sees them.

| | |
|---|---|
| **€72.5M** | lost to scams in Finland in 2025, up from €62.9M in 2024 |
| **€38.4M** | of that taken by fake "safe account" calls |
| **57%** | of adults worldwide met a scam last year; 23% lost money |

<sub>Sources: Finance Finland (bank data), 20 Feb 2026; Global Anti-Scam Alliance, *Global State of Scams 2025*. Details in [`presentation/LEDGER.md`](presentation/LEDGER.md).</sub>

Everyone thinks they'd never fall for one. That's the point.

## What Second Look does

<p align="center">
  <img src="docs/images/app-screens.jpg" alt="The app: pick what to guard, just look, hear why, calls too" width="100%">
</p>

- **Just look.** Tap check or press the glasses' capture button. One photo, an answer in about 2 seconds, spoken through the glasses.
- **Always on, if you want.** A quiet check every 15 seconds; it only speaks when something looks wrong.
- **It tells you why.** One verdict, what to do, one plain reason and the signs it noticed. *"Uses the name 'ray-ban.com' but ray-band.com is not its official website."*
- **It checks what scam words miss.** Look-alike web addresses and prices that don't add up, not only urgent wording.
- **It listens to calls.** A live caption on the phone, and a warning the moment a caller asks for a code or a "safe account".
- **It never says "safe".** When unsure: "not sure, don't pay yet".

## How it works

```mermaid
flowchart LR
  G[Meta glasses<br/>camera + mic] -->|compressed video<br/>or one photo| P[iPhone app<br/>Vision OCR, redaction]
  P -->|one frame, only when<br/>there is something to read| S[Server<br/>rules + Gemini]
  P -.->|offline| R[Rules on the phone]
  S --> V[Verdict, reason, signs]
  R --> V
  V --> O[Spoken on the glasses<br/>card on the phone]
```

| Part | Stack | Read more |
|---|---|---|
| **iOS app** | SwiftUI, Meta Wearables Device Access Toolkit 1.0.1, Apple Vision, HEVC decoding, Kokoro-82M voice on device (FluidAudio), Apple speech recognition | [`ios/`](ios) |
| **Server** | Python, FastAPI, Gemini, English and Finnish rules, look-alike domain and price checks, redaction | [`api/`](api) |
| **Website** | HTML, GSAP, a Blender-rendered 3D intro, an in-browser simulator with real server results | [`web/`](web) |

## Built for real conditions

- **Permissions** are asked for in plain words; refused, the app says so and the phone camera still works.
- **No connection:** the phone reads the text itself and applies basic rules.
- **Glasses hot, low or disconnected:** the app tells you, and you check with the phone camera.
- **Speed and battery:** the glasses send 7 frames a second; a frame leaves the phone only when there is something to check.
- **Privacy:** nothing is stored. Card, IBAN, ID, phone and email numbers are removed before text leaves the phone. Audio is never uploaded. Meta analytics are off.

## Proof

- Ran on **real Meta glasses** on 14 Nov 2026: glasses video in, verdict and spoken warning out. Call check ran through the glasses microphone.
- **~2 s** from frame to verdict (timed at 1.7, 2.0 and 1.7 s).
- **44** Finnish and English examples pass as a regression set. This is not an accuracy claim.
- **Try it without glasses** at [secondlook.pgf.lv](https://secondlook.pgf.lv): the verdicts in the simulator are real server output on real photos.

## Repository

```
ios/            iPhone app for Meta glasses (Swift)
api/            FastAPI server: rules, Gemini, eval set
web/            Landing page and Try it simulator
deploy/         nginx + systemd config for the server
presentation/   Submission text, sources, report, video
docs/           Images for this README
```

Quick start: the app in [`ios/README.md`](ios/README.md), the server in [`api/README.md`](api/README.md). Secrets live in `api/.env` and `ios/Config.xcconfig`, which are git-ignored; copy the `.example` files to start.

## What's next

1. Show the alert on the Ray-Ban Display (built, not showing yet).
2. Test with people of different ages.
3. Pilot with a bank's fraud team or a consumer organisation.

<p align="center"><br><img src="web/media/icon.png" width="64" alt="Second Look icon"><br><i>Built at Junction 2026 for the Meta challenge "AI Glasses for Everyone, Everyday".</i></p>
