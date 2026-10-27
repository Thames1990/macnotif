# MacNotif

MacNotif is a lightweight macOS HUD for temporary and permanent notices. It
displays messages above other windows using macOS's adaptive HUD material.
This is a custom panel, not a Notification Center banner: notices do not appear
in Notification Center history, integrate with Focus, or follow per-app
notification delivery settings.

**[Read the MacNotif handbook](https://macnotif.mohrworks.com/)** for the complete
installation, CLI usage, configuration, and release-history guides.

## Quick start

Requires **macOS Sequoia (15) or later**, on Apple Silicon (`arm64`) or
Intel (`x86_64`). Install with Homebrew:

```sh
brew install Thames1990/tap/macnotif
```

Make sure Homebrew's `bin` directory (`$(brew --prefix)/bin`) is on your `PATH`.
Then display a temporary notice, a permanent notice, or clear the permanent
notice:

```sh
macnotif --title "Layout changed: Tiles" --duration 1
macnotif --title "Working" --description "Persistent notice" --mode permanent
macnotif --clear
```

The Homebrew distribution is an unsigned executable. See the
[installation guide](https://macnotif.mohrworks.com/installation/) for manual
builds, updates, migrating existing installations, and Gatekeeper guidance.

## Documentation

- [Overview and limitations](https://macnotif.mohrworks.com/)
- [Installation](https://macnotif.mohrworks.com/installation/)
- [CLI usage and notice lifecycles](https://macnotif.mohrworks.com/cli-usage/)
- [Configuration, appearance, and live reload](https://macnotif.mohrworks.com/configuration/)
- [Changelog](https://macnotif.mohrworks.com/changelog/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the curated changelog policy and
[handbook maintenance](docs/handbook.md) for local preview and publication
instructions.

## Maintainer releases

See the [maintainer release procedure](docs/maintainer-releases.md) for
workflow dispatch, release retries, and required credentials.
