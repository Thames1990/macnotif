---
layout: default
title: Configuration
nav_order: 4
permalink: /configuration/
---

# Configuration

Customize notice defaults, display selection, placement, and appearance with an
optional TOML file. Every setting is optional; start with just what you want to
change.

**Availability:** The configuration and live reload behavior below is available
in MacNotif **1.1.0 and later**. This handbook tracks main; any future
main-only settings will be marked **Unreleased** rather than implied to work in
an installed release.

## On this page

{: .no_toc }

1. TOC
{:toc}

## File location and defaults

MacNotif reads `~/.config/macnotif.toml`. When `XDG_CONFIG_HOME` is set, it reads
`$XDG_CONFIG_HOME/macnotif.toml` **instead**, not in addition to the HOME file.
MacNotif never creates a missing file.

For example, create a partial configuration at the default location:

```sh
mkdir -p ~/.config
```

Save this as `~/.config/macnotif.toml`:

```toml
[notice]
duration = 3.5
```

This keeps temporary notice mode and all built-in appearance and layout
defaults, changing only the duration to 3.5 seconds. If you use
`XDG_CONFIG_HOME`, create and edit the file in that directory instead.

A missing file, empty file, empty table, or omitted setting uses the built-in
default. Configurations are not layered: after a live edit, an omitted setting
reverts to its built-in default, not the value from the previous file.

## Notice defaults and CLI precedence

| Setting | Default | Valid values and effect |
| --- | --- | --- |
| `notice.mode` | `"temporary"` | `"temporary"` or `"permanent"` |
| `notice.duration` | `1` | Finite positive integer or float, in seconds; no fixed upper bound. Only temporary notices expire. |

```toml
[notice]
mode = "temporary"
duration = 1
```

Explicit `--mode` and `--duration` flags override these defaults for that
invocation. For example, even with the partial file above, this temporary notice
expires after one second:

```sh
macnotif --title "Saved" --mode temporary --duration 1
```

Configuration is validated **before** CLI overrides are applied. Overrides
cannot rescue an invalid file, including when running `macnotif --clear`.
Title, supporting detail (`--description`), and clearing (`--clear`) remain CLI
operations; they are not configuration settings. There are no appearance CLI
flags, and the old `--border-color` flag is unsupported.

A permanent notice remains until replaced or cleared; duration has no effect on
it. New notices replace the existing notice of the same kind. Permanent notices
remain above temporary notices when both are visible; `--clear` removes only
the permanent notice. Appearance settings do not change these lifecycles.

## Display selection and positioning

| Setting | Default | Valid values and effect |
| --- | --- | --- |
| `display.id` | Omitted: main display | Integer Core Graphics display ID, `1` through `4294967295` (positive 32-bit ID). |
| `layout.anchor` | `"top-right"` | `"top-left"`, `"top-right"`, `"bottom-left"`, or `"bottom-right"`. |
| `layout.horizontal_inset` | `18` | Finite non-negative integer or float, in points; no fixed upper bound. |
| `layout.vertical_inset` | `18` | Finite non-negative integer or float, in points; no fixed upper bound. |

```toml
[display]
# id = 69733248 # Example Core Graphics ID; replace with your display's ID.

[layout]
anchor = "top-right"
horizontal_inset = 18
vertical_inset = 18
```

The ID is a Core Graphics display identifier, not a display name or list index.
Omit `id` to select the main display. If the configured display is unavailable
(for example, after disconnecting it), the HUD falls back to the main display
and emits a warning through macOS unified logging. It uses the configured
display again when that display becomes available.

The anchor and insets position the **whole notice stack** relative to the
display's usable visible frame (accounting for the menu bar and Dock), not
relative to the full screen bounds. Large insets are accepted, not clamped;
choose values that keep the notices on screen.

## Appearance reference

By default, the HUD uses adaptive macOS material, semantic system text colors,
a system shadow, and **no border**. It follows system light/dark appearance
changes while running; there is no forced-theme setting.

All dimensions, font sizes, and spacing below are in **points**, not pixels.
Numeric settings accept finite integers or floats, and ranges are inclusive.
System accessibility preferences can override these tokens as described
[below](#system-accessibility-precedence).

| Setting | Default | Valid values and effect |
| --- | --- | --- |
| `appearance.width` | `360` | `160`-`1200`; preferred width of each notice. |
| `appearance.min_height` | `54` | `32`-`400`; minimum height of each notice, not a fixed height. |
| `appearance.padding` | `14` | `0`-`80`; internal padding around content. |
| `appearance.icon_spacing` | `12` | `0`-`80`; gap between symbol and text. |
| `appearance.text_spacing` | `2` | `0`-`40`; gap between title and supporting detail. |
| `appearance.stack_spacing` | `8` | `0`-`80`; gap between permanent and temporary notices. |
| `appearance.title_size` | `14` | `8`-`96`; title font size, subject to the system preferred size minimum. |
| `appearance.detail_size` | `13` | `8`-`96`; supporting detail font size, subject to the system preferred size minimum. |
| `appearance.symbol_size` | `16` | `8`-`96`; SF Symbol size. |
| `appearance.corner_radius` | `14` | `0`-`100`; corner radius. |
| `appearance.shadow` | `true` | Boolean `true` or `false`; panel shadow. |
| `appearance.permanent_symbol` | `"pin.fill"` | Nonempty valid SF Symbol name available on the running macOS version. |
| `appearance.temporary_symbol` | `"bell.fill"` | Nonempty valid SF Symbol name available on the running macOS version. |
| `appearance.animation_duration` | `0.15` | `0`-`2` **seconds**; new-notice fade-in. `0` disables it. |
| `appearance.border_width` | `0` | `0`-`10`; `0` disables the optional border unless Increase Contrast requires one. |

This complete appearance example lists built-in values. Copy only the settings
you want to change into your own `[appearance]` table:

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

Notice bars grow to fit text height, the symbol, and vertical padding. Width
grows when needed to fit two padding widths, the symbol, icon spacing, and at
least 96 points of text. Titles and supporting detail remain single-line and
truncate at the end rather than wrapping. Larger fonts can increase height,
but do not remove horizontal truncation.

### Light and dark color overrides

Each of `[appearance.light]` and `[appearance.dark]` supports all five color
settings below. An omitted color keeps its system default. Overrides in one
appearance never carry over to the other.

| Setting (under either table) | Default | Effect |
| --- | --- | --- |
| `background` | Adaptive HUD material | Custom background over the material. |
| `title` | System label color | Title foreground. |
| `detail` | System secondary label color | Supporting detail foreground. |
| `symbol` | System secondary label color | SF Symbol tint. |
| `border` | System separator color | Border color, visible only when a border is enabled. |

Every color is a quoted sRGB hex string: `"#RRGGBB"` or `"#RRGGBBAA"`.
The optional final alpha byte runs from `00` (transparent) to `FF` (opaque).
Hex digits are case-insensitive; named colors, shorthand hex, and unquoted
values are not accepted. Use full setting names such as
`appearance.light.background` or `appearance.dark.border` when searching.

For a custom palette and optional border:

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

Merge this with any existing `[appearance]` table; do not declare the same
table twice. Setting a border color alone does **not** enable a border.
With a positive `border_width` and no custom border color, the system
separator color is used. Explicit colors can diverge from the native palette;
choose legible foreground/background pairs in both appearances.

### System accessibility precedence

System accessibility preferences are authoritative, including changes made
while the HUD is running:

| System preference | Effect on configuration |
| --- | --- |
| Reduce Motion | Disables notice animations, including a fade-in already in progress. |
| Increase Contrast | Replaces custom colors with an opaque system background and primary system text/symbol colors. Enforces a system-color outline at least one point wide, even with `border_width = 0`. |
| Reduce Transparency | Replaces custom or translucent backgrounds with the opaque system background. Foreground overrides remain unless Increase Contrast also applies. |
| Preferred text sizes | Title and detail never shrink below AppKit's preferred headline/body sizes, even when smaller sizes are configured. Larger preferred text grows the bar height instead of clipping vertically. |

These settings customize a custom AppKit HUD, not Notification Center banners.
They do not add notification history, Focus integration, or per-app delivery
settings.

## Validation and diagnostics

Each invocation reads and validates the whole file at startup. Invalid TOML,
unknown sections or settings, invalid types or values, and unreadable files
stop startup with a diagnostic on **stderr** and a nonzero exit status. A
missing file is the exception: it uses defaults.

TOML syntax diagnostics identify the file, line, and column. Setting
diagnostics identify the file and setting. For example, an invalid duration
at the default location produces a message of this form (the HOME path varies):

```text
macnotif: /Users/you/.config/macnotif.toml: notice.duration must be a finite positive number of seconds
```

Common corrections:

| Problem | Correction |
| --- | --- |
| `duration = 0`, negative values, `inf`, or `nan` | Use a finite positive duration. |
| `shadow = "false"` | Use the Boolean `shadow = false`, not a string. |
| `display.id = 1.5` | Use an integer display ID, not a float. |
| A misspelled key or unsupported section | Use only the keys in this reference, in their documented tables. |
| Invalid symbol name | Choose an SF Symbol available on the Mac running MacNotif. |
| Invalid color | Quote a full `"#RRGGBB"` or `"#RRGGBBAA"` string. |
| File cannot be read | Check its location, permissions, and UTF-8 encoding. |

Do not assume a setting was ignored because the HUD still looks unchanged:
check startup stderr or live reload logs. To inspect live reload errors and
unavailable-display warnings, open Console and filter for subsystem
`com.mohrworks.macnotif`, category `HUD`, or stream them in Terminal:

```sh
log stream --style compact --predicate 'subsystem == "com.mohrworks.macnotif" AND category == "HUD"'
```

## Live reload and last known-good configuration

The running HUD rereads the file on its **150 ms refresh cycle**. A valid edit
replaces the entire active configuration together, updating appearance,
placement, and display selection without restarting the HUD.

An invalid live edit, including an unreadable file, applies **nothing**.
The HUD keeps its **last known-good configuration** and reports the diagnostic
through macOS unified logging, not the later CLI invocation's stderr. Repeated
identical errors are suppressed until the error changes or a valid
configuration loads again.

Deleting the file restores built-in defaults; recreating it resumes live
configuration. Removing a setting in a valid file also restores that setting's
built-in default rather than retaining the last configured value.

Notice defaults affect **new CLI invocations**, with explicit flags still
taking precedence. Reloading never changes existing notice content or
expiration, replaces a notice, or clears one. An invalid file can therefore
leave the existing HUD working while preventing new CLI invocations.

The HUD retains the configuration location selected by its own startup
environment. Changing `XDG_CONFIG_HOME` for a later CLI invocation does not
redirect an already-running HUD; use a consistent environment for the HUD and
commands.
