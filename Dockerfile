FROM linuxserver/webtop:ubuntu-xfce

# ============================================
# OpenClaw + VNC Desktop + Chromium
# ============================================

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget \
    git jq vim \
    procps ripgrep fd-find less tree unzip xz-utils \
    ca-certificates gnupg build-essential \
    fonts-noto-cjk fonts-noto-color-emoji \
    python3 python3-pip python3-venv \
    iproute2 iputils-ping dnsutils traceroute \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g axios fs-extra dayjs lodash cheerio pdf-lib sharp puppeteer
RUN pip install requests beautifulsoup4 lxml pdfplumber PyPDF2 python-docx openpyxl pandas Pillow pyyaml python-dotenv

# Install Playwright system deps + symlink webtop's Chromium into Playwright's expected path
# ENV PLAYWRIGHT_BROWSERS_PATH=/usr/lib/playwright
# RUN npx playwright install-deps chromium \
#     && CHROMIUM_REVISION=$(npx playwright install chromium --dry-run 2>&1 | grep -oP 'chromium-\K\d+' || echo "1155") \
#     && mkdir -p /usr/lib/playwright/chromium-${CHROMIUM_REVISION}/chrome-linux \
#     && ln -s /usr/bin/chromium /usr/lib/playwright/chromium-${CHROMIUM_REVISION}/chrome-linux/chrome \
#     && mkdir -p /usr/share/applications \
#     && cat > /usr/share/applications/chromium.desktop <<'EOF'
# [Desktop Entry]
# Name=Chromium
# Exec=/usr/bin/chromium --no-sandbox --user-data-dir=/config/.chromium-desktop %U
# Icon=web-browser
# Type=Application
# Categories=Network;WebBrowser;
# EOF

ENV HOME=/config
WORKDIR /config

# Copy startup script
COPY start-openclaw.sh /custom-services.d/start-openclaw.sh
COPY openclaw /bin/openclaw
RUN chmod a+x /custom-services.d/start-openclaw.sh \
    && chmod a+x /bin/openclaw

# Ports: 3001 = VNC web desktop, 18789 = OpenClaw gateway
EXPOSE 3001 18789
