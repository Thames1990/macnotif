---
title: CLI Usage
nav_order: 3
permalink: /cli-usage/
---

# CLI Usage

After [installation]({% link installation.md %}), display a temporary notice:

```sh
macnotif --title "Layout changed: Tiles" --mode temporary --duration 1
```

The explicit mode and duration make this example independent of your configured
notice defaults. Quote text containing spaces so your shell passes it as one
argument.

## Options

```text
macnotif --title TEXT [--description TEXT] [--mode temporary|permanent] [--duration SECONDS]
macnotif --clear
```

| Option | Behavior |
| --- | --- |
| `--title TEXT` | Required for a new notice; must contain non-whitespace text. |
| `--description TEXT` | Optional supporting detail below the title. |
| `--mode MODE` | `temporary` or `permanent`. Built-in default: `temporary`. |
| `--duration SECONDS` | A finite positive number of seconds, including decimals. Built-in default: `1`. Only temporary notices expire. |
| `--clear` | Used alone, clears the permanent notice. |

The optional TOML configuration can change mode and duration defaults; explicit
`--mode` and `--duration` values take precedence for that invocation. Duration
does not affect a permanent notice, although a supplied value must still be
valid.

## Temporary notices

```sh
macnotif --title "Build complete" --description "All checks passed" --mode temporary --duration 3.5
```

A temporary notice disappears when its duration expires. A new temporary
notice replaces the previous temporary notice, without replacing a permanent
notice.

## Permanent notices and replacement

```sh
macnotif --title "Working" --description "Deployment in progress" --mode permanent
macnotif --title "Ready" --description "Deployment complete" --mode permanent
```

The second command replaces the first permanent notice. New notices always
replace only the existing notice of the **same kind**. A permanent notice
stays above any temporary notice until replaced or cleared.

## Clearing

```sh
macnotif --clear
```

Clearing removes the permanent notice if present; it **does not clear a temporary
notice**, which must expire on its own or be replaced by another temporary
notice. Clearing when no permanent notice exists is harmless.

Do not combine `--clear` with other arguments. There is no clear-all command.
The HUD hides when neither kind has an active notice.

## Errors and background behavior

Invalid modes, missing values, empty titles, invalid durations, and unsupported
options produce a diagnostic on stderr and a nonzero exit status. Configuration
is read before every CLI operation: an invalid or unreadable configuration also
stops `--clear`, even when CLI overrides are supplied.

`--border-color` is no longer supported. Appearance is configured through TOML,
not CLI flags. The old `mode NAME` and `end` commands are not aliases.

Running the executable with no arguments starts the background HUD rather than
printing help; there is no `--help` flag. New notices start the HUD as needed.
Notice state is stored in `~/Library/Application Support/MacNotif/`.
