# Submission form: copy-paste blocks

Every statement below is in LEDGER.md. Re-check against REPORT.md before pasting.

## Name (30 max)
```
Second Look
```
(11 characters)

## Punchline (200 max; target 80–120)
```
Look at a letter, text or webshop through your Meta glasses and hear in seconds if it shows scam signs, and why.
```
(112 characters)

## Description (5,000 max, markdown)
```markdown
### The problem
Scams reach people where a phone filter can't see them: a paper letter, a fake webshop on a laptop, a text on someone else's phone, a caller asking for a code. The risky moment is when you are about to pay, often with your hands full, and few people stop to screenshot it into a checker app. We built for older adults and anyone who wants a second opinion at that moment.

### What we built
Second Look is an iPhone app for Meta AI glasses plus a small checking server.
- Look at the thing and tap **check** (or press the glasses capture button). The photo is read and checked.
- You get one short answer: **likely scam / be careful / looks okay / not sure**, as a notification with one plain-language paragraph, read aloud.
- Choose what you want protection from (letters & bills, messages, websites, webshops, QR codes, phone calls), and whether it works **on request** or **always on**.

### How to try it
1. Start the server: `cd api && pip install -r requirements.txt && uvicorn app.main:app --port 8765`
2. Open `ios/SecondLook.xcodeproj` (generate with `xcodegen generate`) and run it in the iOS simulator.
3. In the "⋯" menu choose **Demo: webshop photo**. Look for: the screen turns red and says *"Uses the name 'blickers.com' but blickerz.com is not its official website. Don't pay."*

### The technical part
Shop scams often have no "scam words". So besides 17 wording rules (codes, gift cards, "safe account", urgency, "hi mum, new number"…), the server checks **whether the prices on the page add up** (–36% of €187 is €120, the cart says €120, so the €20 headline is bait) and **whether the web address imitates a real store** (`blickerz.com` vs `blickers.com`). That's 24 kinds of signs in total, each with an explanation and the exact text it found. If the server can't be reached, the phone reads the text itself (Apple Vision) and runs basic rules offline, and it says "not sure, don't pay yet" rather than guessing.

### Evidence
- On the team's own photo of a fake Ray-Ban webshop, the app answers "likely scam" with four warning signs (iOS simulator).
- Text check speed on a laptop: median 5.6 ms, 95th percentile 450 ms (132 requests).
- A 44-example regression set (Finnish and English, scams and real notices) passes. We wrote it together with the rules, so it is **not** an accuracy measure.

### Trust and accessibility
- Camera and microphone are used only for the check you start; nothing is stored.
- Personal numbers (IBAN, card, Finnish personal ID, phone, email) are removed before text leaves the phone.
- Meta's toolkit analytics and crash reporting are switched off.
- Audio-first: works by voice on glasses without a display; Ray-Ban Display card is built.
- It never says "safe", only "no scam signs found".

### Challenge fit
First-person view of the thing you are about to pay for, hands-free, built on Meta's Device Access Toolkit (iOS), audio-first with a Display option, with consent and no data kept.

### Limitations and next step
- **Not yet run on Meta glasses.** The glasses capture, capture button, Display card and call listening are built but untested; in the simulator the mock glasses did not connect.
- Photo reading with Gemini is built but not enabled (no API key yet).
- No user tests yet.
- Next: run the webshop check through Ray-Ban Display at the Meta booth, then test with three older adults.
```
(Check the length with `wc -m` before pasting. Current draft: 3,385 characters.)

## Challenge
**Meta: AI Glasses for Everyone, Everyday.** Why it fits: a first-person, hands-free check at the moment of payment, built on DAT, with consent and no data kept.

## Tech challenges
Tick **none** unless verified before submitting:
- Hostinger: only if the server is deployed on Hostinger and the public URL works.
- Gemini: only if `/analyze-image` works with a real `GEMINI_API_KEY`.
(Also confirm that one project may enter several challenges; see BRIEF.md.)

## Links
| Link | Status |
|---|---|
| Demo | **Missing.** No public URL. Simulator-only. |
| Source | **Missing.** No repository yet (folder isn't a git repo). |
| Video | **Missing.** Not made (see REPORT.md). |
| Other | None |
Each link must open in an incognito window on a phone before submitting.
