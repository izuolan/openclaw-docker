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
        echo "[openclaw] Ensuring gateway is in remote/lan mode;"

        tmpfile="$(mktemp)"
        # "hot" = apply config changes in-process (e.g. model switch) without replacing the gateway process,
        # so Docker/s6 still see one PID and logs stay attached. Avoids default "hybrid" falling back to
        # full restart (port fights with s6). If a future change truly needs a process restart, restart the container.
        jq '.gateway.port = 18789
            | .gateway.mode = "remote"
            | .gateway.bind = "lan"
            | .gateway.remote.url = "ws://127.0.0.1:18789"
            | .gateway.reload = (.gateway.reload // {})
            | .gateway.reload.mode = "hybrid"
            | .gateway.http.endpoints.chatCompletions.enabled = true
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

GATEWAY_PORT=18789

is_port_in_use() {
    if command -v ss >/dev/null 2>&1; then
        ss -tln 2>/dev/null | grep -q ":${GATEWAY_PORT} "
    else
        (echo >/dev/tcp/127.0.0.1/${GATEWAY_PORT}) 2>/dev/null
    fi
}

get_openclaw_pid() {
    pgrep -f "openclaw gateway" 2>/dev/null | head -1
}

wait_for_existing_gateway() {
    local pid

    trap cleanup_and_exit SIGTERM SIGINT SIGHUP

    while true; do
        pid=$(get_openclaw_pid)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "[openclaw] Existing gateway detected (PID=$pid). Monitoring instead of starting a new instance."
            while kill -0 "$pid" 2>/dev/null; do
                sleep 2
            done

            echo "[openclaw] Gateway process $pid exited. Checking whether restart spawned a replacement..."
            sleep 2
            continue
        fi

        if is_port_in_use; then
            echo "[openclaw] Port $GATEWAY_PORT still busy. Waiting for release before deciding whether to start."
            sleep 2
            continue
        fi

        break
    done
}

cleanup_and_exit() {
    local pid
    pid=$(get_openclaw_pid)
    if [[ -n "$pid" ]]; then
        echo "[openclaw] Forwarding signal to openclaw (PID=$pid)"
        kill "$pid" 2>/dev/null || true
    fi
    exit 0
}

if is_port_in_use; then
    EXISTING_PID=$(get_openclaw_pid)
    if [[ -n "$EXISTING_PID" ]] && kill -0 "$EXISTING_PID" 2>/dev/null; then
        echo "[openclaw] Self-restart detected: process $EXISTING_PID already on port $GATEWAY_PORT."
        wait_for_existing_gateway
    else
        echo "[openclaw] Port $GATEWAY_PORT in use but no openclaw process found yet."
        wait_for_existing_gateway
    fi
fi

echo "[openclaw] Starting OpenClaw gateway (foreground). Config updates use hot reload where supported."
exec /bin/openclaw gateway --allow-unconfigured
