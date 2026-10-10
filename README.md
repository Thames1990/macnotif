# dinky-notify

Tiny macOS helper that posts a notification with the Dinky icon. Used by a
Dinky `mode-changed` hook to show the active mode.

## Build and install

```sh
./build.sh
```

Compiles `main.swift`, installs `~/Applications/DinkyNotify.app`, copies the
icon from `/Applications/dinky.app`, and signs the app ad-hoc. Keep the bundle
ID (`local.thomas.dinky-notify`) unchanged so the notification permission
persists.

## Usage

```sh
DinkyNotify "<title>" "<body>"
```

In `~/.config/dinky/dinky.toml`:

```toml
mode-changed = ['exec-and-forget ~/Applications/DinkyNotify.app/Contents/MacOS/DinkyNotify "dinky mode: $DINKY_MODE" "$DINKY_PREV_MODE → $DINKY_MODE"']
```
