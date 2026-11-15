# Second Look API

Explainable scam and manipulation detector. FastAPI, no content stored.

## Run locally
```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/python -m eval.run_eval          # writes eval/results.json
.venv/bin/uvicorn app.main:app --reload    # http://localhost:8000
```
Copy `.env.example` to `.env` and set `GEMINI_API_KEY` to enable photo checks and the LLM second opinion (`--llm` flag for eval).

## Endpoints
| Method | Path | Purpose |
|---|---|---|
| POST | `/analyze-image` | `{"image_base64": "...", "mime_type": "image/jpeg"}` → Gemini reads the photo (text, address, boxes), then the same rules run; the image is not stored |
| POST | `/analyze` | `{"text": "...", "url": null, "use_llm": true}` → verdict, confidence, spoken line, signals with evidence |
| GET | `/` | Public paste-and-check page + accuracy table |
| GET | `/metrics` | Latest eval results (precision, recall, FPR, not-sure rate) |
| GET | `/stats` | Verdict counts only (no content) |
| GET | `/health` | Liveness + whether the LLM is configured |

Verdicts: `scam`, `suspicious`, `looks_ok`, `not_sure`. It never says "safe".

## How it decides
1. `app/rules.py`: EN + FI regex rules for 9 techniques (credential request, unusual payment, urgency, threat, authority, relative impersonation, too good to be true, small fee, link push).
2. `app/source.py`: URL signals: official domain, lookalike/brand-in-domain, risky TLD, shortener, raw IP, domain age via RDAP.
3. `app/llm.py`: Gemini pass (photo reading and a second opinion on text); LLM-only findings get 60% weight. `app/prices.py` checks whether discounts and totals add up.
4. `app/scorer.py`: weighted sum → thresholds (`SCAM_AT`, `SUSPICIOUS_AT`). Weak evidence without LLM → `not_sure`.
5. `app/redact.py`: strips IBAN, card numbers, Finnish personal IDs, emails, phones before analysis.

## Deploy
```bash
docker build -t second-look .
docker run -d --restart unless-stopped -p 8000:8000 --env-file .env second-look
```
Production runs on a Hetzner server behind nginx at https://secondlook.pgf.lv (see [`../deploy`](../deploy)).

## Honest caveats
- The 44-example `eval/sample.jsonl` was written alongside the rules, so its 100% score is not a real accuracy figure. Add a held-out set (and public datasets) before quoting numbers.
- Regex rules are deliberately simple; tune with `eval/run_eval.py` and log every false positive.
