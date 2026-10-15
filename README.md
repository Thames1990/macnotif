# dinky-notify

Small macOS HUD for Dinky mode indicators and temporary notifications. A
persistent mode bar stays above a separate temporary notice bar, using macOS's
adaptive HUD material and Dinky's active border color.

## Homebrew installation

Requires macOS Sequoia (15) or later. Install the native executable for your
Mac with:

```sh
brew install Thames1990/tap/dinky-notify
```

Homebrew verifies the downloaded release archive against its SHA-256 checksum
and links `dinky-notify` into Homebrew's standard `bin` directory. Installation
does not require Xcode or Command Line Tools and does not change PATH or shell
profiles. Before invoking `dinky-notify` by name, make sure Homebrew's `bin`
directory (`$(brew --prefix)/bin`) is on PATH.

Update to a newly published release with:

```sh
brew update
brew upgrade dinky-notify
```

Uninstall the Homebrew-managed version with:

```sh
brew uninstall dinky-notify
```

The formula installs one unsigned executable, not an app bundle or shell
launcher. It requires macOS Sequoia (15) or later.

An existing `~/.local/bin/dinky-notify` manual-install symlink is left
untouched by both Homebrew installation and uninstallation. If both that
directory and Homebrew's `bin` are on PATH, command precedence depends on their
order; inspect it with `command -v dinky-notify`. To remove the old manual
symlink when you choose to migrate:

```sh
rm ~/.local/bin/dinky-notify
```

## Maintainer releases

Push a `vMAJOR.MINOR.PATCH` tag to build and smoke-test native arm64 and x86_64
executables, publish both archives and their `SHA256SUMS` file as a public
release in `Thames1990/homebrew-tap`, update its formula, and verify Homebrew
installation on both architectures. Pull requests and branch pushes run
validation only; they do not publish releases.

Before the first release, configure a fine-grained personal access token
restricted to `Thames1990/homebrew-tap` with **Contents: read and write**
permission. Store it as the `HOMEBREW_TAP_TOKEN` Actions secret in the private
`Thames1990/dinky-notify` repository. The workflow uses it only to publish the
public release and update the formula; the token value must not be committed
or logged.

## Manual build and install

```sh
./build.sh
```

This legacy installer compiles `main.swift`, installs
`~/Applications/DinkyModeHUD.app` and a `dinky-notify` command in
`~/.local/bin`, and signs the app ad-hoc. It requires macOS Sequoia (15) or
later and the Swift compiler supplied by Xcode or its Command Line Tools.
Ensure `~/.local/bin` is on PATH if you want to use this installation by name.

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
