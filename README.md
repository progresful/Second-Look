# Second Look

**For people too smart to get scammed. So, everyone.**

Look at a letter, a text, a webshop or a caller through your Meta AI glasses. In about two seconds Second Look says whether it shows scam signs, and why. Built at Junction 2026 for the Meta challenge "AI Glasses for Everyone, Everyday".

- **Video (52 s):** https://youtu.be/4tVMIr4o9ec (file: [`presentation/video/second-look-v5.mp4`](presentation/video/second-look-v5.mp4))
- **Try it without glasses:** https://secondlook.pgf.lv (section *Try it*)

## What's in this repo

| Folder | What it is |
|---|---|
| [`ios/`](ios) | The iPhone app for Meta AI glasses (Device Access Toolkit): live camera check, call check, spoken answers |
| [`api/`](api) | The FastAPI server that judges a frame with Gemini plus deterministic checks (prices, look-alike addresses, 17 wording rules) |
| [`web/`](web) | The landing page with the 3D glasses opening and the *Try it* simulator |
| [`presentation/`](presentation) | Submission text, sources ([`LEDGER.md`](presentation/LEDGER.md)), status report, video |
| [`deploy/`](deploy) | Server setup |

## Privacy

Nothing is stored. Card, IBAN, ID, phone and email numbers are removed before text leaves the phone. The app never calls anything "safe": when unsure it says "not sure, don't pay yet".

Secrets live in `api/.env` and `ios/Config.xcconfig`, which are not in the repo.
