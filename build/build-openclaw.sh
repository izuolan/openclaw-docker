#!/usr/bin/env bash

# build-openclaw.sh
#
# 构建 OpenClaw 独立 AppImage（内含 Node.js + OpenClaw + uv）
#
# 输出: build/dist/OpenClaw-<version>-<arch>.AppImage
#
# 用法:
#   ./build/build-openclaw.sh [--arch <x86_64|aarch64>] [--node-version <ver>] [--uv-version <ver>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
WORK_DIR="$SCRIPT_DIR/work"

# ── 默认参数 ──────────────────────────────────────────────────────────────

NODE_VERSION="22.14.0"
UV_VERSION="0.10.0"
ARCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)         ARCH="$2";         shift 2 ;;
    --node-version) NODE_VERSION="$2"; shift 2 ;;
    --uv-version)   UV_VERSION="$2";   shift 2 ;;
    *)              echo "Unknown option: $1"; exit 1 ;;
  esac
done

# 自动检测架构
if [[ -z "$ARCH" ]]; then
  case "$(uname -m)" in
    x86_64|amd64)    ARCH="x86_64" ;;
    aarch64|arm64)   ARCH="aarch64" ;;
    *)               echo "Error: cannot detect arch, use --arch"; exit 1 ;;
  esac
fi

case "$ARCH" in
  x86_64)  NODE_ARCH="x64";  UV_TARGET="x86_64-unknown-linux-gnu" ;;
  aarch64) NODE_ARCH="arm64"; UV_TARGET="aarch64-unknown-linux-gnu" ;;
  *)       echo "Error: unsupported arch: $ARCH"; exit 1 ;;
esac

# 读取 openclaw 版本
OPENCLAW_VERSION=$(grep -o '"openclaw": *"[^"]*"' "$SCRIPT_DIR/package.json" | grep -o '[0-9][^"]*')

echo "=========================================="
echo "  OpenClaw AppImage Build"
echo "  Arch:       $ARCH"
echo "  Node.js:    v$NODE_VERSION"
echo "  uv:         v$UV_VERSION"
echo "  OpenClaw:   $OPENCLAW_VERSION"
echo "=========================================="
echo ""

# ── 检查环境 ──────────────────────────────────────────────────────────────

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Warning: AppImage is a Linux format. Building on $(uname -s)."
  echo "         Output should be tested on Linux."
  echo ""
fi

# 需要 npm（不需要 pnpm）
if ! command -v npm &> /dev/null; then
  echo "Error: npm not found. Install Node.js first: https://nodejs.org/"
  exit 1
fi

mkdir -p "$DIST_DIR" "$WORK_DIR"

# ── Step 1: 安装 openclaw ────────────────────────────────────────────────

echo "[1/6] Installing openclaw and dependencies..."
cd "$SCRIPT_DIR"
npm install --omit=dev 2>&1 | tail -5
echo ""

# ── Step 2: 下载 Node.js ─────────────────────────────────────────────────

NODE_DIR="$WORK_DIR/node-v${NODE_VERSION}-linux-${NODE_ARCH}"
NODE_TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}"

if [[ -f "$NODE_DIR/bin/node" ]]; then
  echo "[2/6] Node.js already cached, skipping."
else
  echo "[2/6] Downloading Node.js v${NODE_VERSION} for linux-${NODE_ARCH}..."
  curl -fSL --progress-bar -o "$WORK_DIR/$NODE_TARBALL" "$NODE_URL"
  tar -xJf "$WORK_DIR/$NODE_TARBALL" -C "$WORK_DIR"
  rm -f "$WORK_DIR/$NODE_TARBALL"
fi
echo ""

# ── Step 3: 下载 uv ──────────────────────────────────────────────────────

UV_TARBALL="uv-${UV_TARGET}.tar.gz"
UV_URL="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_TARBALL}"
UV_BIN="$WORK_DIR/uv"

if [[ -f "$UV_BIN" ]]; then
  echo "[3/6] uv already cached, skipping."
else
  echo "[3/6] Downloading uv v${UV_VERSION}..."
  curl -fSL --progress-bar -o "$WORK_DIR/$UV_TARBALL" "$UV_URL"
  tar -xzf "$WORK_DIR/$UV_TARBALL" -C "$WORK_DIR" --strip-components=1 "$(basename "$UV_TARBALL" .tar.gz)/uv"
  chmod +x "$UV_BIN"
  rm -f "$WORK_DIR/$UV_TARBALL"
fi
echo ""

# ── Step 4: 组装 AppDir ──────────────────────────────────────────────────

echo "[4/6] Assembling AppDir..."

APPDIR="$WORK_DIR/OpenClaw.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/lib/node"
mkdir -p "$APPDIR/usr/lib/bin"

# Node.js 二进制（只需要 bin/node）
cp "$NODE_DIR/bin/node" "$APPDIR/usr/lib/node/node"
chmod +x "$APPDIR/usr/lib/node/node"

# 保持 npm 平铺结构：node_modules/ 包含 openclaw 和所有依赖
# ESM 从 openclaw/dist/ 向上查找 → openclaw/ → node_modules/（父目录）→ 找到 chalk 等
cp -r "$SCRIPT_DIR/node_modules" "$APPDIR/usr/lib/node_modules"

# uv 二进制
cp "$UV_BIN" "$APPDIR/usr/lib/bin/uv"
chmod +x "$APPDIR/usr/lib/bin/uv"

# AppRun + .desktop + icon
cp "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"
cp "$SCRIPT_DIR/openclaw.desktop" "$APPDIR/openclaw.desktop"

# icon — 生成最小有效 PNG（1x1 透明像素）
if [[ -f "$SCRIPT_DIR/openclaw.png" ]]; then
  cp "$SCRIPT_DIR/openclaw.png" "$APPDIR/openclaw.png"
else
  # 最小有效 1x1 PNG
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > "$APPDIR/openclaw.png"
fi

echo ""

# ── Step 5: 清理瘦身 ─────────────────────────────────────────────────────

echo "[5/6] Cleaning up bundle..."

NM="$APPDIR/usr/lib/node_modules"

# # 删除运行时不需要的整个包（对齐 ClawX 的 SKIP_PACKAGES / SKIP_SCOPES）
# echo "  Removing unnecessary packages..."
# rm -rf "$NM/typescript" 2>/dev/null || true
# rm -rf "$NM/@playwright" 2>/dev/null || true
# rm -rf "$NM/@types" 2>/dev/null || true
# rm -rf "$NM/@cloudflare" 2>/dev/null || true

# # 删除已知的大型无用子目录（对齐 ClawX 的 LARGE_REMOVALS）
# echo "  Removing large unused subdirectories..."
# rm -rf "$NM/pdfjs-dist/legacy" 2>/dev/null || true
# rm -rf "$NM/pdfjs-dist/types" 2>/dev/null || true
# rm -rf "$NM/node-llama-cpp/llama" 2>/dev/null || true
# rm -rf "$NM/koffi/src" 2>/dev/null || true
# rm -rf "$NM/koffi/vendor" 2>/dev/null || true
# rm -rf "$NM/koffi/doc" 2>/dev/null || true

# # 删除开发产物（目录）
# echo "  Removing dev artifacts..."
# # 注意：不删除 doc/docs 目录，某些包（如 yaml）的 doc/ 是运行时代码
# find "$NM" -type d \( -name test -o -name tests -o -name __tests__ -o -name .github -o -name examples -o -name example \) -exec rm -rf {} + 2>/dev/null || true

# # 删除开发产物（文件）
# find "$NM" -type f \( \
#   -name "*.d.ts" -o -name "*.d.ts.map" -o -name "*.d.mts" -o \
#   -name "*.js.map" -o -name "*.ts.map" -o -name "*.mjs.map" -o \
#   -name "*.ts" ! -name "*.d.ts" -o \
#   -name ".DS_Store" -o -name "README.md" -o -name "CHANGELOG.md" -o \
#   -name "LICENSE" -o -name "LICENSE.md" -o -name "LICENSE.txt" -o \
#   -name "tsconfig.json" -o -name "tsconfig.*.json" -o \
#   -name ".npmignore" -o -name ".eslintrc" -o -name ".eslintrc.json" -o \
#   -name ".prettierrc" -o -name ".prettierrc.json" -o \
#   -name "Makefile" -o -name "Gruntfile.js" -o -name "Gulpfile.js" -o \
#   -name "binding.gyp" -o -name ".travis.yml" -o -name "appveyor.yml" \
# \) -delete 2>/dev/null || true

# 清理非目标平台的 native 模块
PLATFORM="linux"
cleanup_native_scopes() {
  local nm="$1"
  # koffi: 只保留 linux_$NODE_ARCH
  local koffi_dir="$nm/koffi/build/koffi"
  if [[ -d "$koffi_dir" ]]; then
    for entry in "$koffi_dir"/*/; do
      local name=$(basename "$entry")
      if [[ "$name" != "${PLATFORM}_${NODE_ARCH}" ]]; then
        rm -rf "$entry"
      fi
    done
  fi
  # @img/sharp*, @napi-rs/canvas*, @mariozechner/clipboard*
  for scope_dir in "$nm/@img" "$nm/@napi-rs" "$nm/@mariozechner"; do
    [[ -d "$scope_dir" ]] || continue
    for pkg in "$scope_dir"/*/; do
      local pkg_name=$(basename "$pkg")
      # 如果包名包含平台标识但不匹配当前平台，删除
      if echo "$pkg_name" | grep -qE '(darwin|win32|linux)-(x64|arm64)'; then
        if ! echo "$pkg_name" | grep -q "${PLATFORM}-${NODE_ARCH}"; then
          rm -rf "$pkg"
        fi
      fi
    done
  done
}

cleanup_native_scopes "$NM"

# 删除空目录
find "$NM" -type d -empty -delete 2>/dev/null || true

SIZE=$(du -sh "$APPDIR" | cut -f1)
echo "  AppDir size: $SIZE"
echo ""

# ── Step 6: 生成 AppImage ────────────────────────────────────────────────

echo "[6/6] Generating AppImage..."

APPIMAGETOOL="$WORK_DIR/appimagetool-${ARCH}.AppImage"
if [[ ! -f "$APPIMAGETOOL" ]]; then
  echo "  Downloading appimagetool..."
  TOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  curl -fSL --progress-bar -o "$APPIMAGETOOL" "$TOOL_URL"
  chmod +x "$APPIMAGETOOL"
fi

OUTPUT_NAME="OpenClaw-${OPENCLAW_VERSION}-linux-${ARCH}.AppImage"
OUTPUT_PATH="$DIST_DIR/$OUTPUT_NAME"

export ARCH="$ARCH"

"$APPIMAGETOOL" --no-appstream "$APPDIR" "$OUTPUT_PATH" 2>&1 || {
  echo "  Retrying with --appimage-extract-and-run..."
  "$APPIMAGETOOL" --appimage-extract-and-run --no-appstream "$APPDIR" "$OUTPUT_PATH" 2>&1
}

chmod +x "$OUTPUT_PATH"

FILESIZE=$(du -h "$OUTPUT_PATH" | cut -f1)

echo ""
echo "=========================================="
echo "  Build complete!"
echo "  Output: $OUTPUT_PATH"
echo "  Size:   $FILESIZE"
echo "=========================================="
echo ""
echo "  chmod +x $OUTPUT_NAME"
echo "  ./$OUTPUT_NAME              # 启动 Gateway"
echo "  ./$OUTPUT_NAME --version    # CLI 模式"
