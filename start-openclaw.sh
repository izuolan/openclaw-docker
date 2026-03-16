#!/usr/bin/env bash
# OpenClaw gateway startup script
# Runs as a custom service inside linuxserver/webtop

# Wait for the desktop environment to be ready
sleep 5

# Set up environment
export OPENCLAW_HOME="${OPENCLAW_HOME:-/config/}"
export NODE_ENV="${NODE_ENV:-production}"

# Create openclaw home directory if not exists
mkdir -p "$OPENCLAW_HOME"

# Playwright headed mode via VNC display
export DISPLAY=:1
export PLAYWRIGHT_BROWSERS_PATH=/usr/lib/playwright

# Start OpenClaw gateway directly from AppImage
echo "[openclaw] Starting OpenClaw gateway..."
APPIMAGE=$(ls /dist/OpenClaw-*.AppImage 2>/dev/null | head -1)
if [[ -z "$APPIMAGE" ]]; then
    echo "[openclaw] Error: No AppImage found in /dist/"
    exit 1
fi
exec "$APPIMAGE" --appimage-extract-and-run gateway
