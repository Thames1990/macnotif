# Changelog

## Unreleased

## 1.1.0 - 2026-10-25

### Added

- Optional TOML configuration for Notice mode and duration defaults, panel
  placement and display selection, and appearance.
- Live configuration reload: valid edits update the running HUD without a
  restart.

## 1.0.0 - 2026-10-15

### Added

- Homebrew distribution with native Apple Silicon and Intel executables.

### Breaking Changes

- Renamed `dinky-notify` to `macnotif`. Existing installations do not migrate
  automatically; uninstall the old formula before installing `macnotif`.
- Removed the legacy `mode NAME` and `end` commands and Dinky configuration
  lookup. Use MacNotif's explicit notice arguments and `--clear` instead.
