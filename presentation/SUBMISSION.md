# Submission form: copy-paste blocks

Updated 15 Nov 2026 (after video v5 and the site update). Every statement below is in LEDGER.md. Re-check against REPORT.md before pasting.

## Name (30 max)
```
Second Look
```
(11 characters)

## Punchline (200 max; target 80–120)
```
Look at a letter, text or webshop. Your Meta glasses tell you in seconds if it shows scam signs, and why.
```

## Description (5,000 max, markdown)
```markdown
### The problem
Scams don't wait in your spam folder. They come on paper, on screens and on the phone, and they want more than a payment: a bank code, a password, your details, or remote access to your computer. Most arrive where no filter sees them: a letter, a webshop on a laptop, a text, a caller who sounds like your bank. People in Finland lost €72.5 million to digital fraud in 2025, up from €62.9 million in 2024. Fake "safe account" calls alone took €38.4 million (Finance Finland).

Second Look is for everyone, especially the people who think they'd never fall for one.

### The solution
An iPhone app for Meta AI glasses. Look at it. In 2–3 seconds the glasses say whether it shows scam signs, and why.

### Each problem, solved
| Problem | Second Look |
|---|---|
| Scams arrive on paper, screens and calls, outside any filter | The glasses camera and microphone check whatever is in front of you |
| Your hands are full when you pay | Hands-free. Always on, it speaks only when something looks wrong. Or tap **check** |
| "Suspicious" explains nothing | One verdict and one reason that names the sender: *"This address is ray-band.com, not ray-ban.com."* The phone marks the evidence |
| Fake shops use no scam words | It checks whether the prices add up and whether the address imitates a brand, on top of 17 wording rules |
| A caller pressures you live | It listens through the glasses, shows a live caption and warns when the caller asks for a code or a "safe account" |
| A wrong "safe" costs money | It says "not sure, don't pay yet". It never says "safe" |

### Built for real conditions
- **Permissions:** camera and microphone are asked for in plain words. If refused, the app says so and you check with the phone camera.
- **No connection:** the phone reads the text itself and applies basic rules.
- **Glasses hot, low on battery or disconnected:** the app says so and you check with the phone camera.
- **Speed and battery:** the glasses send compressed video at 7 frames a second. The phone reads the text and sends a frame only when there is something to check.
- **Consent and data:** nothing is stored. Card, IBAN, ID, phone and email numbers are removed before text leaves the phone. The voice is generated on the phone. Meta analytics are off.

### Proof
- Ran on real Meta glasses on 14 Nov: glasses video, verdict, spoken warning. The call warning ran through the glasses microphone.
- Server verdict in about 2 s (timed: 1.7, 2.0, 1.7 s).
- 44 Finnish and English examples pass as a regression set. It is not an accuracy measure.
- Try it without glasses: **https://secondlook.pgf.lv**, section **Try it**. Pick messages, emails, websites, webshops, letters & bills, QR codes or phone calls. Each photo's verdict is real server output, shown in the same alert card the app uses. The website's spoken lines are recorded jokes for the demo; the app itself speaks with a voice generated on the phone.

### Next
1. Show the alert on the glasses display. It is built and does not show yet; today the answer is spoken and shown on the phone.
2. Test with 3 people of different ages, including at least one older adult.
3. Pilot with a bank's fraud team or a consumer organisation.
```

## How the description maps to the judging criteria (25% each)
| Criterion | Where it is answered |
|---|---|
| Creativity and use case | The problem; Each problem, solved |
| Technical execution | Built for real conditions; Proof |
| Real-world value and feasibility | The problem (sourced figure); Proof; Next (pilot) |
| User experience: input, accessibility, trust | Hands-free and voice rows; Consent and data; "never says safe" |
| Required: functional prototype **and deck** | Prototype: yes. Deck: 8 slides, made (private artifact; export it as PDF). Video: v5, 52 s. |

## Challenge
**Meta: AI Glasses for Everyone, Everyday.** Why it fits: a first-person, hands-free check at the moment of payment, built on DAT, running on real glasses, with consent and no data kept.

## Tech challenges
- **Gemini:** can be ticked. Photo and live-frame checks run on Gemini with a real key (LEDGER.md).
- **Hostinger:** do **not** tick. The server runs on Hetzner (secondlook.pgf.lv), not Hostinger.
- Confirm that one project may enter several challenges (BRIEF.md).

## Links
| Link | Status |
|---|---|
| Demo | https://secondlook.pgf.lv. Live: 3D glasses opening that leads into the "Try it" simulator (7 scenes), the feature sections, one alert design throughout. |
| Source | https://github.com/progresful/Second-Look is **private**. Make it public before submitting, and check that no keys are in it. |
| Video | https://youtu.be/4tVMIr4o9ec (52 s, public). Same file as `video/second-look-v5.mp4`. It shows the team wearing the glasses, the Finland figures with sources, the website, the feature screens on the demo phone, and the call check. It does **not** show the app running on the glasses; the phone screens are the website's demo phone. |
| Deck | https://claude.ai/artifact/9GpxoaA6dua53fNpzwUTyL is **private**, and team names are placeholders. Fill in names, then export the PDF. |
| Other | None |
Each link must open in an incognito window on a phone before submitting.
