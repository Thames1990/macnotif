# dinky-notify

Small macOS HUD for Dinky mode indicators and temporary notifications. A
persistent mode bar stays above a separate temporary notice bar, using macOS's
adaptive HUD material and Dinky's active border color.

## Build and install

```sh
./build.sh
```

Compiles `main.swift`, installs `~/Applications/DinkyModeHUD.app` and a
`dinky-notify` command in `~/.local/bin`, and signs the app ad-hoc. Requires
macOS and the Swift compiler supplied by Xcode or its Command Line Tools.
Ensure `~/.local/bin` is on `PATH`; for zsh, add
`export PATH="$HOME/.local/bin:$PATH"` to `~/.zprofile` if needed.

This replaces the repository's older `DinkyNotify.app` notification helper.
Update hooks referencing that helper to the HUD path below. The HUD uses
`local.thomas.dinky-mode-hud` and does not require notification permission.
The old app is not removed by the build script.

## Usage

```sh
dinky-notify mode resize
dinky-notify mode main
dinky-notify --title "Layout changed: Tiles" --duration 1
dinky-notify --title "Working" --description "Persistent notice" --mode permanent
dinky-notify end
```

`mode <name>` displays **MODE: <name>** permanently for any non-main mode.
`mode main` clears the permanent bar. `end` also clears the permanent bar,
without clearing a temporary notice.

General notices require `--title`. Optional flags are `--description`,
`--mode temporary|permanent` (default: temporary), `--duration` in positive
seconds (default: 1, temporary notices only), and `--border-color` as a six-
or eight-digit RGB/RGBA hex color, optionally prefixed with `#`.
Without a color override, the HUD reads `[borders].active-color` from
`~/.config/dinky/dinky.toml`, falling back to the macOS accent color.

New notices replace the existing notice of the same kind. State is stored in
`~/Library/Application Support/DinkyModeHUD/`. The HUD runs in the background
and hides when neither bar has an active notice. Running the app executable
without arguments starts the HUD rather than displaying CLI help.

## Dinky integration

In `~/.config/dinky/dinky.toml`, add the command to the global `[hooks]` table:

```toml
[hooks]
mode-changed = ['exec-and-forget dinky-notify mode "$DINKY_MODE"']
```

This covers every mode change, including entering or leaving `resize`, and
hides the mode bar when returning to `main`. Keep your existing resize mode
and bindings; no duplicate per-mode notification is needed. Replace the old
mode-change notification command, preserving any unrelated hook commands.

For a temporary layout notice, add this after the layout command in its
existing binding:

```toml
'exec-and-forget dinky-notify --title "Layout changed: Tiles" --duration 1'
```

Run `dinky reload-config` and `dinky doctor`, then enter resize mode to see
`MODE: resize` and return to main to hide it.
