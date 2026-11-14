"""Second Look API. Run: uvicorn app.main:app --reload"""
import json
import os
from pathlib import Path
from typing import Optional

import hmac

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import llm, scorer

ROOT = Path(__file__).resolve().parent.parent
app = FastAPI(title="Second Look", version="0.1.0",
              description="Explainable scam and manipulation detector. Stores no message content.")
app.add_middleware(CORSMiddleware, allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
                   allow_methods=["GET", "POST"], allow_headers=["*"])

# Over the public tunnel, checks need the app's token, so strangers can't spend the
# Gemini quota. Direct local requests (Mac, same Wi-Fi, web demo) don't.
APP_TOKEN = os.getenv("APP_TOKEN", "")


@app.middleware("http")
async def require_token_via_tunnel(request: Request, call_next):
    via_tunnel = "cf-connecting-ip" in request.headers
    if APP_TOKEN and via_tunnel and request.method == "POST" and \
            not hmac.compare_digest(request.headers.get("x-app-token", ""), APP_TOKEN):
        return JSONResponse({"detail": "Missing or wrong app token."}, status_code=401)
    return await call_next(request)


app.mount("/static", StaticFiles(directory=ROOT / "static"), name="static")

STATS = {"checks": 0, "scam": 0, "suspicious": 0, "looks_ok": 0, "not_sure": 0}  # counts only, no content


class AnalyzeIn(BaseModel):
    text: str = Field("", max_length=8000, description="Message text (redact PII on the device first).")
    url: Optional[str] = Field(None, max_length=2000)
    use_llm: bool = True


@app.post("/analyze")
def analyze(body: AnalyzeIn):
    if not body.text.strip() and not body.url:
        raise HTTPException(422, "Send text or url.")
    result = scorer.analyze(body.text, body.url, use_llm=body.use_llm)
    STATS["checks"] += 1
    STATS[result["verdict"]] += 1
    return result


class ImageIn(BaseModel):
    image_base64: str = Field(..., max_length=8_000_000, description="JPEG/PNG, base64. Downscale to ~1280 px first.")
    mime_type: str = Field("image/jpeg", pattern=r"^image/(jpeg|png|webp|heic)$")
    live: bool = Field(False, description="Frame from live scan: use the fast model.")


@app.post("/analyze-image")
def analyze_image(body: ImageIn):
    """Photo mode via Gemini. The image is forwarded to Gemini and not stored by this server."""
    if llm.provider() != "gemini":
        raise HTTPException(503, "Image mode needs GEMINI_API_KEY on the server.")
    result = scorer.analyze_image(body.image_base64, body.mime_type, live=body.live)
    if result is None:
        raise HTTPException(502, "Image check failed. Client should fall back to on-device text check.")
    STATS["checks"] += 1
    STATS[result["verdict"]] += 1
    return result


@app.get("/health")
def health():
    return {"ok": True, "llm_enabled": llm.enabled(), "llm_provider": llm.provider(), "image_mode": llm.provider() == "gemini"}


@app.get("/stats")
def stats():
    return STATS


@app.get("/metrics")
def metrics():
    path = ROOT / "eval" / "results.json"
    if not path.exists():
        return JSONResponse({"error": "Run python -m eval.run_eval first."}, status_code=404)
    return json.loads(path.read_text())


@app.get("/")
def index():
    return FileResponse(ROOT / "static" / "index.html")


@app.get("/glasses")
def glasses_demo():
    return FileResponse(ROOT / "static" / "glasses.html")
