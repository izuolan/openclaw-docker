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

# Connect Playwright to the VNC desktop display (headed mode)
export DISPLAY=:1
export PLAYWRIGHT_BROWSERS_PATH=/usr/lib/playwright
export CHROMIUM_PATH=$(find /usr/lib/playwright -name "chrome" -type f 2>/dev/null | head -1)
# Disable headless so browser MCP operations are visible in VNC
export PLAYWRIGHT_CHROMIUM_USE_HEADLESS_NEW=0

# Start OpenClaw gateway
echo "[openclaw] Starting OpenClaw gateway..."
# /bin/openclaw --appimage-extract-and-run setup
/bin/openclaw --appimage-extract-and-run gateway
