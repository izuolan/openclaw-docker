# OpenClaw AppImage Builder

将 OpenClaw 打包为独立的 Linux AppImage，内含 Node.js + OpenClaw + uv，无需任何外部依赖。

与 ClawX 项目完全无关，可独立使用。

## 构建

```bash
# 在 Linux 上（推荐）
./build-openclaw.sh

# 指定架构（交叉编译）
./build-openclaw.sh --arch aarch64

# 指定版本
./build-openclaw.sh --node-version 22.14.0 --uv-version 0.10.0
```

构建产物: `dist/OpenClaw-<version>-linux-<arch>.AppImage`

## 使用

```bash
# 启动 Gateway 服务（默认 HTTP/WS，端口 9090）
./OpenClaw-*.AppImage

# CLI 模式
./OpenClaw-*.AppImage --version
./OpenClaw-*.AppImage chat
```

## 文件结构

```
build/
├── build-openclaw.sh    # 构建脚本
├── package.json         # 仅 openclaw 依赖
├── AppRun               # AppImage 入口
├── openclaw.desktop     # .desktop 文件
└── README.md
```

## 要求

- Linux（或 macOS 构建后在 Linux 上测试）
- npm
- curl
- 网络连接（下载 Node.js、uv、appimagetool）

## 更新 OpenClaw 版本

修改 `package.json` 中的 `openclaw` 版本号，重新运行构建脚本即可。
