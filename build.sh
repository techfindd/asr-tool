#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building Release..."
swift build -c release

BIN=".build/release/SubtitleStudio"
if [[ ! -f "$BIN" ]]; then
  echo "Error: build artifact not found at $BIN" >&2
  exit 1
fi

APP="ASR Tool.app"
echo "==> Packaging $APP ..."
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
    <key>CFBundleDevelopmentRegion</key><string>en</string>
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

echo "==> Done: $PWD/$APP"
echo "Double-click to run, or drag it into Applications."
