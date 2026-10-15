# MacNotif

MacNotif is a lightweight macOS HUD for temporary and permanent notices. It
displays messages above other windows using macOS's adaptive HUD material.

## Homebrew installation

Requires macOS Sequoia (15) or later. Install the native executable for your
Mac with:

```sh
brew install Thames1990/tap/macnotif
```

Homebrew verifies the downloaded release archive against its SHA-256 checksum
and links `macnotif` into Homebrew's standard `bin` directory. Installation
does not require Xcode or Command Line Tools and does not change PATH or shell
profiles. Before invoking `macnotif` by name, make sure Homebrew's `bin`
directory (`$(brew --prefix)/bin`) is on PATH.

Update to a newly published release with:

```sh
brew update
brew upgrade macnotif
```

Uninstall the Homebrew-managed version with:

```sh
brew uninstall macnotif
```

The formula installs one unsigned executable, not an app bundle or shell
launcher. It requires macOS Sequoia (15) or later.

The Homebrew formula is published to `Thames1990/homebrew-tap` on the next
tagged release. Existing installations of the previous `dinky-notify` formula
do not migrate automatically; uninstall that formula before installing
`macnotif`.

## Maintainer releases

Push a `vMAJOR.MINOR.PATCH` tag to build and smoke-test native arm64 and x86_64
executables, publish both archives and their `SHA256SUMS` file as a public
release in `Thames1990/homebrew-tap`, update its formula, and verify Homebrew
installation on both architectures. Pull requests and branch pushes run
validation only; they do not publish releases.

Before the first release, configure a fine-grained personal access token
restricted to `Thames1990/homebrew-tap` with **Contents: read and write**
permission. Store it as the `HOMEBREW_TAP_TOKEN` Actions secret in the
`Thames1990/macnotif` repository. The workflow uses it only to publish the
public release and update the formula; the token value must not be committed
or logged.

## Manual build and install

```sh
./build.sh
```

This installer compiles `main.swift`, installs `~/Applications/MacNotif.app`
and a `macnotif` command in `~/.local/bin`, and signs the app ad-hoc. It
requires macOS Sequoia (15) or later and the Swift compiler supplied by Xcode
or its Command Line Tools. Ensure `~/.local/bin` is on PATH if you want to use
this installation by name.

The installer leaves any previous `DinkyModeHUD.app`, `dinky-notify` command,
and their saved state untouched. Remove those old files manually if you no
longer need them; MacNotif does not migrate their state or provide old-name
aliases. An existing `~/.local/bin/macnotif` symlink is left untouched by
Homebrew installation and uninstallation. If both that directory and
Homebrew's `bin` are on PATH, command precedence depends on their order;
inspect it with `command -v macnotif`.

## Usage

```sh
macnotif --title "Layout changed: Tiles" --duration 1
macnotif --title "Working" --description "Persistent notice" --mode permanent
macnotif --clear
```

Notices require `--title`. Optional flags are `--description`,
`--mode temporary|permanent` (default: temporary), `--duration` in positive
seconds (default: 1, temporary notices only), and `--border-color` as a six-
or eight-digit RGB/RGBA hex color, optionally prefixed with `#`. Without a
color override, the HUD uses the macOS accent color.

Temporary notices disappear after their duration. Permanent notices remain
until replaced or cleared with `macnotif --clear`; clearing a permanent notice
does not clear a temporary one. New notices replace the existing notice of
the same kind.

Notice state is stored in `~/Library/Application Support/MacNotif/`. The HUD
runs in the background and hides when neither bar has an active notice. Running
the app executable without arguments starts the HUD rather than displaying CLI
help.
