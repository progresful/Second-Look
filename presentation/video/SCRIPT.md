# Second Look: 60-second video

Every claim is in LEDGER.md. Format 16:9, 1080p, captions burned in. Real phone footage only.

| Time | Picture | Sound (voiceover unless noted) |
|---|---|---|
| 0:00–0:04 | Black. Then the phone's live view lands on the PayPal email. Red boxes appear. | **The app's own voice:** "Hold on. This looks like a scam." |
| 0:04–0:12 | Title card on the warm aura background: **"Scams don't wait in your spam folder."** Quick cuts: a letter, a webshop on a laptop, a text message. | "Scams don't wait in your spam folder. They're on paper, on a laptop screen, in a text. And they hit at the moment you're about to pay." |
| 0:12–0:16 | Logo card: eye icon + **Second Look**. | "Second Look gives you a second opinion, right then." |
| 0:16–0:34 | **Hero demo (real screen recording, with app audio).** Point at the PayPal email: yellow frame around the message → "checking" → red boxes with labels → spoken warning. Small corner label: *shown on iPhone · built for Meta AI glasses*. | Low voiceover, then let the app's warning play in full. |
| 0:34–0:44 | Second real clip: the fake webshop. Red boxes on the prices and the web address. Text callout: **"–36% of €187 is €120. The €20 is bait."** | "It doesn't just look for scary words. It checks whether the prices add up, and whether the web address copies a real shop." |
| 0:44–0:52 | Simple animated diagram, three steps: **Phone reads the text (on device) → Only when it matters, Gemini judges (~2 s) → You hear why.** Under it: "24 kinds of scam signs, each explained." | "Your phone reads the text itself. Only when something matters is a frame checked by Gemini, in about two seconds, against twenty-four kinds of scam signs." |
| 0:52–0:57 | Trust card, three short lines: **Nothing stored. Personal numbers removed first. It never says "safe".** | "Nothing is stored. Personal numbers are removed first. And it never tells you something is safe." |
| 0:57–1:00 | End card: **Second Look**. *A second opinion before you pay.* Below: "Built for Meta AI glasses. Junction 2026." | "Second Look. A second opinion before you pay." |

## Honesty rules for this video
- Say "shown on iPhone" whenever footage is the phone. Glasses haven't been tested.
- No scam statistics, no user numbers, no partners.
- Only real recordings of the app; no mock-ups presented as the product.

## Footage needed from the team (phone screen recordings, microphone ON)
1. **PayPal email, 15–20 s:** open live scan, hold on the email until the warning finishes speaking. Hold steady.
2. **Fake webshop, 10–15 s:** live scan on the Ray-Ban webshop photo (`ios/SecondLook/Resources/demo-webshop.jpg` opened full-screen on the Mac).
3. **Optional, 3 × 2 s:** phone camera clips (not screen recordings) of a paper letter, a laptop webshop, a text on another phone. Used in the "scams are everywhere" cuts.

## How the final cut was made (`second-look-60s.mp4`, 59.5 s)
- **Footage:** team's iPhone camera clips `IMG_8789` (webshop at ray-band.com) and `IMG_8790` (UNICEF job email).
- **Verdicts, boxes, explanations:** real output of the Second Look server (`/analyze-image`, gemini-3.5-flash) on frames of those clips, saved in `build/results.json`. Nothing was edited by hand.
- **App overlay** (status label, yellow frame, red boxes, verdict card): recreated in HTML from the app's live-scan design, because these are camera clips, not screen recordings. The video says so in a corner label.
- **Voice:** Kokoro-82M (narrator `af_heart`, app voice `bf_emma`). The app's lines use the app's own sentence template and the server's explanations.
- **Rebuild:** `build/build.py` (needs the clips in ~/Downloads, Chrome, ffmpeg; voice from `build/kokoro_gen.py`).
- Making it surfaced a real bug, fixed in the server: Gemini's web-address and price findings were dropped from the verdict, so the webshop came back "looks okay".

## Version 2 (current `second-look-60s.mp4`, 58.4 s)
Dark, fast cut. Adds the problem size, the app itself, call check and options.
- **Problem figures (sourced, in LEDGER.md):** 57% of adults worldwide ran into a scam, 23% lost money (GASA, Global State of Scams 2025); $20.9B reported online-crime losses in the US in 2025 (FBI IC3).
- **App screens:** iOS simulator recordings of the real app: choosing what to guard, on request / always on, the menu, a real check ending in "likely scam", and call check.
- **Call check:** a scripted bank-impersonation call fed word by word into the app's real call check (`--demo-call`; the simulator has no microphone). Labelled "scripted call audio". Not yet tested on a live call.
- **Music:** Lyria 3 Pro (Gemini API), ducked under the voice. **Voice:** Kokoro-82M.
- **Rebuild:** `build/build2.py` with `build/lines_v2.json`.
