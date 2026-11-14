#!/bin/sh
# Temporary public HTTPS address for the local server (for phones on 5G).
# Prints a https://....trycloudflare.com URL; it changes every time this restarts.
exec cloudflared tunnel --no-autoupdate --url http://localhost:8765
