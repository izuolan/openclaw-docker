#!/usr/bin/env bash
set -euo pipefail

# Wait for the desktop environment to be ready
sleep 5

# Set up environment
export OPENCLAW_HOME="${OPENCLAW_HOME:-/config}"
export NODE_ENV="${NODE_ENV:-production}"
export DISPLAY=:1
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-/usr/lib/playwright}"

SKILLHUB_BIN="$HOME/.local/bin/skillhub"
SKILLHUB_DIR="$HOME/.skillhub"

CONFIG_DIR="$OPENCLAW_HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

# Create directories if not exists
mkdir -p "$OPENCLAW_HOME"
mkdir -p "$CONFIG_DIR"

# First-run setup
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[openclaw] First run detected, config not found: $CONFIG_FILE"
    echo "[openclaw] Running initial setup..."
    /bin/openclaw setup

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "[openclaw] Error: setup finished but config file was not created"
        exit 1
    fi
fi
# skillhub 安装目标路径
# RUN skillhub install gog \
#     && skillhub install summarize \
#     && skillhub install nano-pdf \
#     && skillhub install agent-browser \
#     && skillhub install home-assistant \
#     && skillhub install mission-control \
#     && skillhub install weather \
#     && skillhub install edge-tts \
#     && skillhub install youtube-ultimate \
#     && skillhub install file-organization
install_skillhub_if_needed() {
  # 如果已经有可执行的 skillhub，就跳过安装
  if command -v skillhub >/dev/null 2>&1; then
    return
  fi

  echo "[openclaw] skillhub not found, installing to $HOME ..."
  mkdir -p "$HOME/.local/bin"

  # 运行官方安装脚本，注意：此时 HOME=/config
  curl -fsSL https://skillhub-1388575217.cos.ap-guangzhou.myqcloud.com/install/install.sh \
    | bash -s -- --no-skills

  # 确保 PATH 能找到 skillhub
  if [ -x "$SKILLHUB_BIN" ]; then
    export PATH="$HOME/.local/bin:$PATH"
    echo "[openclaw] skillhub installed to $SKILLHUB_BIN"
  else
    echo "[openclaw] skillhub install script ran but binary not found at $SKILLHUB_BIN" >&2
  fi
}

install_skillhub_if_needed

# Start OpenClaw gateway
echo "[openclaw] Starting OpenClaw gateway..."
exec /bin/openclaw gateway --allow-unconfigured