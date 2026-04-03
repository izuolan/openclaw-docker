#!/usr/bin/env bash
set -euo pipefail

# Wait for the desktop environment to be ready
sleep 5

# Set up environment
export OPENCLAW_HOME="${OPENCLAW_HOME:-/config}"
export NODE_ENV="${NODE_ENV:-production}"
export DISPLAY=:1
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/usr/lib/playwright}"

CONFIG_DIR="$OPENCLAW_HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

# Create directories if not exists
mkdir -p "$OPENCLAW_HOME"
mkdir -p "$CONFIG_DIR"

update_gateway_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[openclaw] Config file not found, skip gateway update: $CONFIG_FILE"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "[openclaw] Ensuring gateway is in remote/lan mode; disabling config-file live reload (no in-process restart)"

        tmpfile="$(mktemp)"
        # gateway.reload.mode "off" = ignore openclaw.json edits until explicit restart.
        # Prefer restarting the container so logs stay on one process attached to Docker.
        jq '.gateway.port = 18789
            | .gateway.mode = "remote"
            | .gateway.bind = "lan"
            | .gateway.remote.url = "ws://127.0.0.1:18789"
            | .gateway.reload = (.gateway.reload // {})
            | .gateway.reload.mode = "off"
            | .browser.enabled = true
            | .browser.defaultProfile = "openclaw"
            | .browser.headless = true
            | .browser.attachOnly = false
            | .browser.noSandbox = true
            ' \
            "$CONFIG_FILE" > "$tmpfile" && mv "$tmpfile" "$CONFIG_FILE"
    else
        echo "[openclaw] jq not found, skip automatic gateway update"
    fi
}

# First-run setup
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[openclaw] First run detected, config not found: $CONFIG_FILE"
    echo "[openclaw] Running initial setup..."
    /bin/openclaw setup

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[openclaw] Error: setup finished but config file was not created"
        exit 1
    fi

    update_gateway_config
else
    update_gateway_config
fi

echo "[openclaw] Starting OpenClaw gateway (foreground → Docker logs). After changing config, restart the container to apply."
exec /bin/openclaw gateway --allow-unconfigured
