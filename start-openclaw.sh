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
GATEWAY_PORT=18789

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

# Kill any lingering openclaw gateway processes
kill_existing_gateway() {
    local pids
    pids=$(pgrep -f "openclaw.mjs gateway" 2>/dev/null || true)
    if [[ -n "$pids" ]]; then
        echo "[openclaw] Killing lingering gateway processes: $pids"
        kill $pids 2>/dev/null || true
        sleep 2
        # Force kill if still alive
        kill -9 $pids 2>/dev/null || true
    fi
}

# Wait until the gateway port is free
wait_for_port_free() {
    local max_wait=30
    local waited=0
    while ss -tlnp 2>/dev/null | grep -q ":${GATEWAY_PORT} " || \
          netstat -tlnp 2>/dev/null | grep -q ":${GATEWAY_PORT} "; do
        if (( waited >= max_wait )); then
            echo "[openclaw] Port $GATEWAY_PORT still occupied after ${max_wait}s, force killing..."
            kill_existing_gateway
            sleep 2
            return
        fi
        echo "[openclaw] Waiting for port $GATEWAY_PORT to be released... (${waited}s)"
        sleep 2
        (( waited += 2 ))
    done
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

# ── Main service loop ────────────────────────────────────────────────────
# We run openclaw in a loop so that s6 never sees this script exit.
# When openclaw restarts itself (config change), it spawns a new process
# and exits the old one. We detect this, clean up, and relaunch.
echo "[openclaw] Entering service loop..."

while true; do
    # Ensure no leftover processes and port is free
    kill_existing_gateway
    wait_for_port_free

    echo "[openclaw] Starting OpenClaw gateway..."
    /bin/openclaw gateway --allow-unconfigured &
    GATEWAY_PID=$!
    echo "[openclaw] Gateway started with PID $GATEWAY_PID"

    # Wait for the gateway process to exit
    wait $GATEWAY_PID || true
    EXIT_CODE=$?
    echo "[openclaw] Gateway (PID $GATEWAY_PID) exited with code $EXIT_CODE"

    # Brief pause before restarting
    # Give the self-restarted process time to bind the port,
    # then we'll kill it and do a clean restart in the next iteration.
    sleep 3
done