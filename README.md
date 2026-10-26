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
builds, updates, migration from `dinky-notify`, and Gatekeeper guidance.

## Documentation

- [Overview and limitations](https://macnotif.mohrworks.com/)
- [Installation](https://macnotif.mohrworks.com/installation/)
- [CLI usage and notice lifecycles](https://macnotif.mohrworks.com/cli-usage/)
- [Configuration, appearance, and live reload](https://macnotif.mohrworks.com/configuration/)
- [Changelog](https://macnotif.mohrworks.com/changelog/)

The handbook tracks current `main`; behavior not yet released is labelled
**Unreleased**. Release history is maintained only in
[CHANGELOG.md](CHANGELOG.md) and rendered into the handbook.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the curated changelog policy and
[handbook maintenance](docs/handbook.md) for local preview and publication
instructions.

## Maintainer releases

The [release changelog design](docs/release-changelogs.md) documents the
implemented curated-note release flow. Before dispatching, review the notes
under `Unreleased` in `CHANGELOG.md`; starting a release approves those notes.
Missing or empty notes stop preparation. For an intentional maintenance-only
release, explicitly record "No user-facing changes." An already-finalized
section for the selected version is reused without consuming newer Unreleased
entries.

To release from GitHub, open **Actions > Release Homebrew formula > Run
workflow**, select **main**, choose **patch**, **minor**, or **major** (default:
**patch**), and run the workflow. The next version is calculated from the
latest published release in `Thames1990/homebrew-tap`: from `1.2.3`, patch
produces `1.2.4`, minor produces `1.3.0`, and major produces `2.0.0`.
The run stops if the latest release cannot be read or has an invalid version,
or if `main` has moved since dispatch. Preparation moves the notes into a
`VERSION - YYYY-MM-DD` section dated in UTC and leaves `Unreleased` empty.
It commits only `CHANGELOG.md`, then atomically pushes that commit to `main`
and an annotated `vVERSION` tag pointing to it. If the selected section was
already finalized, no changelog commit is needed. Conflicting tags,
concurrent source updates, and branch-protection/write rejections fail
explicitly; the workflow never force pushes, moves tags, or bypasses protections.

Only manual dispatch publishes; pushing a tag does not start a release.
Both native arm64 and x86_64 executables are built and smoke-tested from
the prepared commit. The workflow publishes only that version's curated notes,
both archives, `SHA256SUMS`, and `SOURCE_COMMIT` in `Thames1990/homebrew-tap`,
updates its formula, and verifies Homebrew installation on both architectures.
It does not create a release in the source repository. Pull requests and
branch pushes run validation only, including isolated release tests; no
per-PR changelog edit is required.

If building or publishing fails after preparation, leave the commit and tag
intact and **rerun the failed jobs in the original workflow run**, rather than
dispatching another release. The original outputs retain the version and
source. If preparation itself must be rerun after a successful push, its tag's
repository/run ID, original dispatch commit, and increment recover that same
identity without recalculating from a newer tap release. Later Unreleased
entries cannot leak into a retry. Existing published archives are reused only
after checking their manifest, checksums, source provenance, and matching
notes; conflicts or GitHub lookup/download failures stop publication instead
of replacing assets or release bodies.

Before the first release, configure a fine-grained personal access token
restricted to `Thames1990/homebrew-tap` with **Contents: read and write**
permission. Store it as the `HOMEBREW_TAP_TOKEN` Actions secret in the
`Thames1990/macnotif` repository. The workflow uses it only to publish the
public release and update the formula; the token value must not be committed
or logged.

Source preparation separately uses the workflow's `GITHUB_TOKEN` with
`contents: write` in the prepare job only. The tap token is not a source-write
credential. If repository policy rejects the source commit/tag push, resolve
that policy/access issue through the normal maintainer process; do not widen
the tap token or bypass branch protections to make a release succeed.
