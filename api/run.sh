#!/bin/sh
# Start the server for the phone (same Wi-Fi). Reads keys from .env.
cd "$(dirname "$0")" && exec .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8765 --env-file .env
