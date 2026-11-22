#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> 编译 Release 版本..."
swift build -c release

BIN=".build/release/SubtitleStudio"
if [[ ! -f "$BIN" ]]; then
  echo "错误：找不到构建产物 $BIN" >&2
  exit 1
fi

APP="SubtitleStudio.app"
echo "==> 打包 $APP ..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SubtitleStudio"
if [[ -f "Assets/AppIcon.icns" ]]; then
  cp "Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleExecutable</key><string>SubtitleStudio</string>
    <key>CFBundleIdentifier</key><string>com.local.asrtool</string>
    <key>CFBundleName</key><string>ASR Tool</string>
    <key>CFBundleDisplayName</key><string>ASR Tool</string>
    <key>CFBundleIconFile</key><string>AppIcon.icns</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

echo "==> 完成：$PWD/$APP"
echo "双击即可运行，也可将其拖入「应用程序」文件夹。"
