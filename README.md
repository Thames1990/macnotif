# MacNotif

MacNotif is a lightweight macOS HUD for temporary and permanent notices. It
displays messages above other windows using macOS's adaptive HUD material.
This is a custom panel, not a Notification Center banner: Notices do not appear
in Notification Center history, integrate with Focus, or follow per-app
notification delivery settings.

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

This installer builds the Swift package, installs `~/Applications/MacNotif.app`
and a `macnotif` command in `~/.local/bin`, and signs the app ad-hoc. It
requires macOS Sequoia (15) or later and the Swift compiler supplied by Xcode
or its Command Line Tools. The first build downloads the pinned TOMLKit
dependency using Swift Package Manager; the installed executable does not
require SwiftPM or a separate TOML parser. Ensure `~/.local/bin` is on PATH if
you want to use this installation by name.

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
`--mode temporary|permanent` (built-in default: temporary) and `--duration` in
positive seconds (built-in default: 1, temporary notices only).
`--border-color` is no longer supported.

Temporary notices disappear after their duration. Permanent notices remain
until replaced or cleared with `macnotif --clear`; clearing a permanent notice
does not clear a temporary one. New notices replace the existing notice of
the same kind.

Notice state is stored in `~/Library/Application Support/MacNotif/`. The HUD
runs in the background and hides when neither bar has an active notice. Running
the app executable without arguments starts the HUD rather than displaying CLI
help.

## Configuration

MacNotif reads an optional TOML file from `~/.config/macnotif.toml`. When
`XDG_CONFIG_HOME` is set, it reads `$XDG_CONFIG_HOME/macnotif.toml` instead;
it does not also read the HOME config. MacNotif never creates a missing
config file.

```toml
[notice]
mode = "temporary" # "temporary" or "permanent"
duration = 1       # finite positive number of seconds; integers or floats

[display]
# id = 69733248 # optional Core Graphics display ID; omitted uses the main display

[layout]
anchor = "top-right" # top-left, top-right, bottom-left, or bottom-right
horizontal_inset = 18 # points
vertical_inset = 18   # points
```

The file is partial: an empty file, an empty `[notice]` table, or omitted
settings inherit the built-in defaults. For example, setting only
`duration = 3.5` under `[notice]` keeps Temporary notice mode with a 3.5-second
duration. Duration has no effect on Permanent notices.

`[display].id` optionally selects a display by its Core Graphics display ID;
omit it to use the main display. If that display is disconnected, the HUD uses
the main display and emits a warning through macOS unified logging.
`[layout].anchor` selects a corner, with top-right as the default.
`horizontal_inset` and `vertical_inset` set the distance from that corner in
points; both default to 18.

Explicit `--mode` and `--duration` values override notice defaults for that
invocation. Title, description, and clearing remain CLI operations, not
configuration settings. Each invocation reads the file at startup. Invalid
TOML, unknown settings or sections, invalid types, and unreadable files stop
startup with a diagnostic on stderr, even if CLI overrides were supplied or
the invocation is `--clear`. Syntax errors identify the file, line, and
column; setting errors identify the file and setting.

The running HUD rereads its configuration on its 150 ms refresh cycle. Valid
edits replace the entire active configuration together, updating appearance,
placement, and display selection without a restart. Omitted settings revert
to built-in defaults rather than inheriting an earlier edit. Invalid live
edits (including unreadable files) apply nothing: the HUD keeps its last
known-good settings and reports the file/setting diagnostic through macOS
unified logging. Repeated identical diagnostics are suppressed until the error
changes or a valid configuration is loaded again. Deleting the file restores
built-in defaults; recreating it resumes live configuration.

Notice defaults apply to new CLI invocations, with explicit flags still taking
precedence. Reloading never changes existing Notice content or expiration,
replaces a Notice, or clears one. The HUD keeps the config path selected by
its startup environment; changing `XDG_CONFIG_HOME` for a later CLI invocation
does not redirect an already-running HUD.

### Panel appearance

The built-in design uses adaptive macOS material, semantic system text colors,
a subtle system shadow, and **no border**. It follows system light/dark
appearance changes while the HUD is running; there is no forced-theme setting.
Permanent notices remain above Temporary notices when both are visible.
Appearance settings never change Notice content, replacement, expiration, or
clearing behavior.

All visual tokens live in TOML, not CLI flags. This example shows the built-in
values; every field is optional:

```toml
[appearance]
width = 360
min_height = 54
padding = 14
icon_spacing = 12
text_spacing = 2
stack_spacing = 8
title_size = 14
detail_size = 13
symbol_size = 16
corner_radius = 14
shadow = true
permanent_symbol = "pin.fill"
temporary_symbol = "bell.fill"
animation_duration = 0.15
border_width = 0
```

Dimensions, font sizes, and spacing are in points; animation duration is in
seconds. `min_height` is a minimum, not a fixed height: bars grow to fit their
text and vertical padding. Width also grows if necessary to accommodate
padding, the symbol, icon spacing, and at least 96 points of text. Titles and
details retain their single-line truncation behavior.

| Token | Accepted values |
| --- | --- |
| `width` | 160-1200 |
| `min_height` | 32-400 |
| `padding`, `icon_spacing`, `stack_spacing` | 0-80 |
| `text_spacing` | 0-40 |
| `title_size`, `detail_size`, `symbol_size` | 8-96 |
| `corner_radius` | 0-100 |
| `border_width` | 0-10; zero disables the border |
| `animation_duration` | 0-2; zero disables the brief Notice fade-in |
| `shadow` | Boolean |
| `permanent_symbol`, `temporary_symbol` | Valid SF Symbol names available on the running macOS version |

Numeric tokens accept finite integers or floats. Invalid tokens are rejected
with a file/setting diagnostic rather than silently ignored.

#### Light and dark color overrides

Omitted colors keep semantic system defaults. Override only the colors you
want in each appearance; one appearance's overrides never leak into the other.
For example, this deliberately replaces the material's default background
and enables an optional border:

```toml
[appearance]
border_width = 1

[appearance.light]
background = "#F5F5F5EE"
title = "#202020"
detail = "#404040"
symbol = "#404040"
border = "#808080"

[appearance.dark]
background = "#242424EE"
title = "#FFFFFF"
detail = "#DDDDDD"
symbol = "#DDDDDD"
border = "#909090"
```

Each color accepts `"#RRGGBB"` or `"#RRGGBBAA"` (sRGB, optional alpha). Without a
custom border color, an enabled border uses the system separator color. A
border color alone does not enable the border. Explicit colors may diverge
from the native palette; choose legible foreground/background pairs.

**Accessibility preferences are authoritative**, including changes while
running. Reduce Motion disables Notice animations, including an animation
already in progress. Increase Contrast replaces custom colors with opaque
system background and primary text colors and enforces at least a one-point
system-color outline. Reduce Transparency replaces custom/translucent
backgrounds with the opaque system background. Text never shrinks below
AppKit's preferred headline/body sizes, even when smaller sizes are configured;
larger preferred text increases the bar height instead of clipping it.
