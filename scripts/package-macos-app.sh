#!/usr/bin/env bash
set -euo pipefail
APP="dist/KshonGCS.app"
rm -rf "$APP" dist/KshonGCS-macOS.zip
mkdir -p "$APP/Contents/MacOS"
cp .build/release/KshonGCS "$APP/Contents/MacOS/KshonGCS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KshonGCS</string>
<key>CFBundleIdentifier</key><string>com.kshongcs.app</string>
<key>CFBundleName</key><string>KshonGCS</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/KshonGCS-macOS.zip
