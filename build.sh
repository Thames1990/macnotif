#!/usr/bin/env bash
# Builds DinkyModeHUD and installs it to ~/Applications/DinkyModeHUD.app.
set -euo pipefail

cd "$(dirname "$0")"
APP="$HOME/Applications/DinkyModeHUD.app"
BIN="$HOME/.local/bin"
CLI="$BIN/dinky-notify"
APP_CLI="$APP/Contents/MacOS/dinky-notify"

if [ -L "$CLI" ]; then
    if [ "$(readlink "$CLI")" != "$APP_CLI" ]; then
        echo "Cannot install dinky-notify: $CLI already exists and is not the app command link." >&2
        exit 1
    fi
elif [ -e "$CLI" ]; then
    echo "Cannot install dinky-notify: $CLI already exists and is not the app command link." >&2
    exit 1
fi

mkdir -p build
swiftc -O -swift-version 5 main.swift -o build/DinkyModeHUD

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/DinkyModeHUD "$APP/Contents/MacOS/DinkyModeHUD"
cp dinky-notify "$APP/Contents/MacOS/dinky-notify"
chmod +x "$APP/Contents/MacOS/dinky-notify"
cp Resources/Info.plist "$APP/Contents/Info.plist"

codesign --force --deep --sign - "$APP"

mkdir -p "$BIN"
if [ ! -L "$CLI" ]; then
    ln -s "$APP_CLI" "$CLI"
fi

echo "Installed $APP"
echo "Installed command $CLI"
case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "Add $BIN to PATH to run dinky-notify by name." ;;
esac
