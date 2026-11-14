# Decision sheet

| Question | Answer |
|---|---|
| Who is the first user? | An older adult living alone who gets letters, texts and web offers asking them to pay, and who wouldn't think to screenshot them into a checker app. |
| What goes wrong today? | A scam arrives on paper, on a screen or on a call; the person pays before anyone can check. (Typical scam patterns are in our test set; we have **no** sourced incident or statistic yet, see LEDGER.md.) |
| What do they do currently? | Nothing, ask a relative later, or use phone-only filters and paste-a-screenshot checkers that miss paper letters and other people's screens. |
| What is our single promise? | Look at it, ask, and hear within seconds whether it shows scam signs and why, before you pay. |
| What works now? | A backend that flags 24 kinds of scam signs (wording, prices, lookalike web addresses) with explanations, and an iPhone app that checks a photo and answers as a notification plus one spoken paragraph. Tested with a phone photo in the iOS simulator; **the glasses capture path is built but not yet run on real or mock glasses**. |
| What is the decisive demo moment? | Looking at a fake Ray-Ban webshop (`blickerz.com`, €20 bait price, cart €120), the screen turns red and says: "Uses the name 'blickers.com' but blickerz.com is not its official website. Don't pay." |
| Why is our approach better? | It explains *why* in plain words and points to the exact evidence (domain, price mismatch), instead of a bare "spam" label, and it is meant to work hands-free at the moment of payment. |
| What was difficult to build? | Catching shop scams that have no "scam words": we check whether the prices on the page add up (–36% of €187 is €120, so the €20 is bait) and whether the domain imitates a real store. Shown on the text of the team's own photo; in the app, on-device text reading missed the small crossed-out price, so this check needs Gemini or a closer photo. |
| What evidence do we have? | 44 hand-written examples all classified correctly, **but written alongside the rules (in-sample, not an accuracy figure)**; local latency p50 5.6 ms / p95 450 ms over 132 requests; simulator run on the real photo. No user tests yet. |
| Why does this fit the challenge? | First-person capture of the thing you are about to pay for, audio-first with an optional Display card, built on DAT, with consent, no storage and honest "not sure" answers, which match the "input, accessibility and trust" criterion. |
| What is the largest unresolved weakness? | Not yet run on Meta glasses (mock glasses didn't link; no device time yet). Next test: the same webshop photo captured through Ray-Ban Display via DAT at the Meta booth. |
