---
title: Installation
nav_order: 2
permalink: /installation/
---

# Installation

MacNotif requires **macOS Sequoia (15) or later**, on Apple Silicon (`arm64`) or
Intel (`x86_64`).

## Install with Homebrew

```sh
brew install Thames1990/tap/macnotif
```

Homebrew downloads the native release archive, verifies its SHA-256 checksum,
and links `macnotif` into its standard `bin` directory. You do not need Xcode
or Command Line Tools for this installation.

Make sure `$(brew --prefix)/bin` is on your `PATH`; the formula does not change
your shell profile. Confirm which installation your shell will run:

```sh
command -v macnotif
```

To update:

```sh
brew update
brew upgrade macnotif
```

To remove the Homebrew-managed installation:

```sh
brew uninstall macnotif
```

The formula lives in
[Thames1990/homebrew-tap](https://github.com/Thames1990/homebrew-tap).

## Manual build and installation

With a local checkout of MacNotif's source, run from the repository root:

```sh
./build.sh
```

Building requires the Swift compiler supplied by Xcode or its Command Line
Tools. The first build downloads the pinned TOMLKit dependency through Swift
Package Manager. The installed executable needs neither SwiftPM nor a separate
TOML parser.

The installer builds for your Mac's architecture, installs
`~/Applications/MacNotif.app`, signs the app ad-hoc, and creates a
`~/.local/bin/macnotif` symlink to its executable. Ensure `~/.local/bin` is on
`PATH`. It refuses to overwrite an unrelated file or symlink at that command
path.

If both the manual installation and Homebrew are present, `PATH` order decides
which runs. Homebrew does not remove or change the manual symlink; check
`command -v macnotif` before troubleshooting the wrong installation.

## Unsigned executables and Gatekeeper

The Homebrew distribution is one **unsigned executable**, not an app bundle or
shell launcher. A checksum verifies the archive's integrity; it is not an Apple
signature or notarization. The manual installer uses an ad-hoc signature, not
a Developer ID signature.

macOS Gatekeeper may block downloaded unsigned software. Use only a source you
trust. If macOS blocks it, review the specific warning and Apple's
[guidance for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).
Do not disable Gatekeeper system-wide or remove quarantine from files you have
not verified.

## Existing installations

Existing installations do not migrate automatically. Remove any previous
Homebrew formula before installing `macnotif`. The manual installer leaves
previous app bundles, commands, and saved state untouched; remove them yourself
if no longer needed. MacNotif provides no previous-name aliases.
