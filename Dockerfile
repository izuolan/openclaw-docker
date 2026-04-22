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
# RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
#     && apt-get install -y nodejs \
#     && npm install -g npm@latest \
#     && rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION=22.22.2

RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac \
  # use pre-existing gpg directory, see https://github.com/nodejs/docker-node/pull/1895#issuecomment-1550389150
  && export GNUPGHOME="$(mktemp -d)" \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 \
    DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
    CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    A363A499291CBBC940DD62E41F10027AF002F8B0 \
  ; do \
      { gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" && gpg --batch --fingerprint "$key"; } || \
      { gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" && gpg --batch --fingerprint "$key"; } ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && gpgconf --kill all \
  && rm -rf "$GNUPGHOME" \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  # smoke tests
  && node --version \
  && npm --version \
  && rm -rf /tmp/*

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
