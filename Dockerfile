FROM linuxserver/webtop:ubuntu-xfce

# ============================================
# OpenClaw + VNC Desktop + Chromium
# ============================================

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    unzip \
    xz-utils \
    ca-certificates \
    gnupg \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm and openclaw
ENV PNPM_HOME=/root/.pnpm_global
ENV PATH="/root/.pnpm_global:$PATH"
RUN npm install -g pnpm # && pnpm -g install openclaw

# Install Playwright chromium for browser MCP
ENV PLAYWRIGHT_BROWSERS_PATH=/usr/lib/playwright
RUN npx playwright install-deps chromium \
    && mkdir -p /usr/share/applications \
    && cat > /usr/share/applications/chromium.desktop <<'EOF'
[Desktop Entry]
Name=Chromium
Exec=/usr/bin/chromium --no-sandbox --user-data-dir=/config/.chromium-desktop %U
Icon=web-browser
Type=Application
Categories=Network;WebBrowser;
EOF

ENV HOME=/config
WORKDIR /config

# Copy startup script
COPY start-openclaw.sh /custom-services.d/openclaw
RUN chmod +x /custom-services.d/openclaw

# Ports: 3001 = VNC web desktop, 18789 = OpenClaw gateway
EXPOSE 3001 18789

# Volumes for persistence
VOLUME ["/config", "/home/node/.openclaw", "/home/node/workspace"]
