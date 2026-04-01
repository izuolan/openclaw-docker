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
        echo "[openclaw] Ensuring gateway is in remote/lan mode via jq"

        tmpfile="$(mktemp)"
        jq '.gateway.port = 18789
            | .gateway.mode = "remote"
            | .gateway.bind = "lan"
            | .gateway.remote.url = "ws://127.0.0.1:18789"
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

    # 首次生成后，更新 gateway 配置
    update_gateway_config
else
    # 非首次启动也确保 gateway 为 remote/lan，防止被手动改成 local/127.0.0.1
    update_gateway_config
fi

# Start OpenClaw gateway
echo "[openclaw] Starting OpenClaw gateway..."
exec /bin/openclaw gateway --allow-unconfigured