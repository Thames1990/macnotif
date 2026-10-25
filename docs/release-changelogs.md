# Release changelog design

Status: curated history and contributor/agent guidance are implemented.
Automatic finalization, publication, and historical release-body updates
remain planned.

MacNotif will use curated `CHANGELOG.md` entries as the source of user-facing
GitHub release notes. Version selection and release timing remain manual.
This follows [Dinky's approach](https://github.com/mikker/Dinky/blob/main/scripts/release.sh):
automate extraction and publication, not writing notes from commit messages.

The current workflow still supports pushed tags, tags `main` without a
changelog commit, and publishes a fixed release description. The changes below
describe the intended replacement, not the currently available procedure.

## Authoring notes

Contributors add an entry under `Unreleased` for each user-facing change.
Entries describe benefits, fixes, and migration requirements for people using
MacNotif, rather than reproducing commit messages. Internal maintenance does
not need an entry.

Use `Added`, `Changed`, `Fixed`, and `Breaking Changes` headings where useful;
omit empty categories. A breaking change must explain what existing users need
to change. Keep an empty `Unreleased` section above released versions, with
newest versions first. Released headings use `VERSION - YYYY-MM-DD`, without
the tag's `v` prefix.

The current [contributor guidance](../CONTRIBUTING.md) documents this convention
for humans and is linked from `AGENTS.md` for coding agents.
There is no per-PR CI requirement to modify the changelog. Starting a release
is the maintainer's approval of the accumulated notes; there is no additional
approval gate.

## Release flow

1. Run the release workflow manually on `main`, selecting patch, minor, or
   major. Keep the existing version calculation from the latest published
   release in `Thames1990/homebrew-tap`. Remove the pushed-tag release trigger.
2. Validate the notes before creating a tag or publishing anything. A release
   must have meaningful `Unreleased` entries or an already-finalized section
   for its selected version. Missing notes stop the run with a clear
   explanation, never a generic fallback. For an intentional maintenance-only
   release, explicitly write "No user-facing changes."
3. For unfinalized notes, move the `Unreleased` entries into a dated version
   section and leave `Unreleased` empty. Commit only `CHANGELOG.md` to `main`,
   then tag that exact commit. An already-finalized section is reused rather
   than duplicated. Do not overwrite concurrent changes, move an existing
   tag, or bypass branch protections; rejected writes stop the run explicitly.
4. Build and smoke-test both native architectures using the tagged source.
   Publish the matching version section as the release body in
   `Thames1990/homebrew-tap`, alongside the existing archives, checksums, and
   source provenance. Continue updating the Homebrew formula and verifying
   installation as today. Do not create duplicate releases in `macnotif`.
5. If building or publishing fails after tagging, retain the changelog commit
   and tag. Rerun the failed workflow jobs rather than selecting another
   release. Retries read notes from the tagged version section, not from
   newer `Unreleased` entries on `main`.

Preserve existing artifact and source-provenance verification when a release
already exists. Retries must not silently replace conflicting artifacts or
publish notes from a different source snapshot. Manually pushed tags no longer
start a release; manual workflow dispatch is the only release entry point.

## Historical backfill

Add curated sections for the two existing releases and replace their generic
GitHub release bodies with the corresponding notes. This is a one-time,
explicit update to release descriptions only: do not change tags or assets.

The dates below are the existing publication dates. Each boundary was checked
against the release's `SOURCE_COMMIT` asset and matching source tag. There is
no earlier version tag for comparison with 1.0.0, so describe its initial
distribution and migration rather than inventing a previous-version diff.

### 1.1.0 - 2026-10-25

#### Added

- Optional TOML configuration for Notice mode and duration defaults, panel
  placement and display selection, and appearance.
- Live configuration reload: valid edits update the running HUD without a
  restart.

Evidence: [configuration change](https://github.com/Thames1990/macnotif/pull/18),
[tagged source](https://github.com/Thames1990/macnotif/commit/d1832a90a0f4dee805cb59aee4b673e6b00fea39),
and [published release](https://github.com/Thames1990/homebrew-tap/releases/tag/v1.1.0).
Exclude the release-workflow and agent-documentation changes from user notes.

### 1.0.0 - 2026-10-15

#### Added

- Homebrew distribution with native Apple Silicon and Intel executables.

#### Breaking Changes

- Renamed `dinky-notify` to `macnotif`. Existing installations do not migrate
  automatically; uninstall the old formula before installing `macnotif`.
- Removed the legacy `mode NAME` and `end` commands and Dinky configuration
  lookup. Use MacNotif's explicit notice arguments and `--clear` instead.

Evidence: [Homebrew distribution](https://github.com/Thames1990/macnotif/pull/9),
[rename and legacy removals](https://github.com/Thames1990/macnotif/pull/11),
[tagged source](https://github.com/Thames1990/macnotif/commit/69d427ab23347f267bc0f6bfe2d7d0d18133203d),
and [published release](https://github.com/Thames1990/homebrew-tap/releases/tag/v1.0.0).

## Implementation boundaries

This design does not introduce automatic version bumps outside the manually
requested release, automatic release scheduling, commit-derived summaries, an
in-app updater, or a changelog requirement for maintenance-only PRs.

Contributor/agent guidance and the canonical changelog are available now.
Update the README release procedure when the workflow replacement is
implemented. Verify section extraction, missing-note failures, finalization,
retry behavior, and removal of pushed-tag publication. Historical
release-body updates remain a separate implementation step; the curated
history does not itself change published releases.
