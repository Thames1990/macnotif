---
title: Overview
nav_order: 1
permalink: /
---

# MacNotif

MacNotif displays short **notices** above other windows in a lightweight macOS
heads-up display (HUD). Give a notice a title and, optionally, supporting detail.
Use it from scripts or your terminal to show a brief update or keep important
context visible.

## Requirements

- macOS Sequoia (15) or later.
- Apple Silicon (`arm64`) or Intel (`x86_64`); Homebrew installs the native
  executable for your Mac.
- Xcode is not needed for the Homebrew installation. Building from source
  requires the Swift compiler from Xcode or its Command Line Tools.

## Two independent notice lifecycles

A **temporary notice** expires automatically. The built-in duration is one
second. A **permanent notice** stays until it is replaced or explicitly cleared.
New notices replace only the existing notice of the same kind.

One of each kind can be visible at the same time, with the permanent notice
above the temporary notice. Clearing a permanent notice does not clear a
temporary one. The HUD runs in the background and hides when neither kind has
an active notice.

## A custom HUD, not Notification Center

MacNotif uses a custom AppKit panel with adaptive macOS HUD material and semantic
system text colors. It is **not a Notification Center banner**: notices have no
Notification Center history, Focus integration, or per-app notification delivery
settings. The familiar macOS appearance does not provide those delivery features.

System accessibility preferences take precedence over visual settings. This
handbook's light/dark control changes only the website, not the HUD.

## Start here

[Install MacNotif]({% link installation.md %}), then
[display your first notice]({% link cli-usage.md %}).

This handbook tracks the current source. Examples here use released CLI
behavior; any future unreleased behavior must be labelled explicitly.
