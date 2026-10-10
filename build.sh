#!/usr/bin/env bash
# Builds DinkyNotify and installs it to ~/Applications/DinkyNotify.app.
set -euo pipefail

cd "$(dirname "$0")"
APP="$HOME/Applications/DinkyNotify.app"
ICON_SRC="/Applications/dinky.app/Contents/Resources/Dinky.icns"

mkdir -p build
swiftc -O -swift-version 5 main.swift -o build/DinkyNotify

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/DinkyNotify "$APP/Contents/MacOS/DinkyNotify"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$APP/Contents/Resources/Dinky.icns"
else
  echo "warning: $ICON_SRC not found; keeping existing icon" >&2
fi

codesign --force --sign - "$APP"
echo "Installed $APP"
