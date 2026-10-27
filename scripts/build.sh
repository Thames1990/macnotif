#!/usr/bin/env bash
# Builds MacNotif and installs it to ~/Applications/MacNotif.app.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="$HOME/Applications/MacNotif.app"
BIN="$HOME/.local/bin"
CLI="$BIN/macnotif"
APP_CLI="$APP/Contents/MacOS/macnotif"

if [ -L "$CLI" ]; then
    if [ "$(readlink "$CLI")" != "$APP_CLI" ]; then
        echo "Cannot install macnotif: $CLI already exists and is not the app command link." >&2
        exit 1
    fi
elif [ -e "$CLI" ]; then
    echo "Cannot install macnotif: $CLI already exists and is not the app command link." >&2
    exit 1
fi

mkdir -p build
architecture="$(uname -m)"
case "$architecture" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        exit 1
        ;;
esac
bash scripts/build-release.sh "$architecture" build/macnotif

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/macnotif "$APP_CLI"
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
    *) echo "Add $BIN to PATH to run macnotif by name." ;;
esac
