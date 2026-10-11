#!/usr/bin/env bash
# Builds DinkyModeHUD and installs it to ~/Applications/DinkyModeHUD.app.
set -euo pipefail

cd "$(dirname "$0")"
APP="$HOME/Applications/DinkyModeHUD.app"

mkdir -p build
swiftc -O -swift-version 5 main.swift -o build/DinkyModeHUD

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/DinkyModeHUD "$APP/Contents/MacOS/DinkyModeHUD"
cp dinky-notify "$APP/Contents/MacOS/dinky-notify"
chmod +x "$APP/Contents/MacOS/dinky-notify"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"
echo "Installed $APP"
