# Release changelog design

Status: curated history, contributor/agent guidance, manual finalization,
source-bound release-note publication, and historical release-body
synchronization are implemented.

MacNotif uses curated `CHANGELOG.md` entries as the source of user-facing
GitHub release notes. Version selection and release timing remain manual.
This follows [Dinky's approach](https://github.com/mikker/Dinky/blob/main/scripts/release.sh):
automate extraction and publication, not writing notes from commit messages.

The manual workflow is the only publication entry point. It prepares an
immutable source identity before either native build, and publishes the
matching curated version section rather than a fixed release description.

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
   release in `Thames1990/homebrew-tap`. Pushed tags do not trigger publication.
2. Validate the notes before creating a tag or publishing anything. A release
   must have meaningful `Unreleased` entries or an already-finalized section
   for its selected version. Missing notes stop the run with a clear
   explanation, never a generic fallback. For an intentional maintenance-only
   release, explicitly write "No user-facing changes."
3. For unfinalized notes, move the `Unreleased` entries into a dated version
   section and leave `Unreleased` empty. Commit only `CHANGELOG.md` to `main`,
   then tag that exact commit. The commit and annotated tag are pushed
   atomically with ordinary fast-forward/ref-creation checks. An already-finalized
   section is reused rather than duplicated. Do not overwrite concurrent changes, move an existing
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

`scripts/release.py` is the black-box release interface: `prepare` selects
the version, finalizes notes, and writes `tag_name`/`source_commit` outputs;
`notes` extracts the selected section from that commit after checking the
tag identity; `publish` checks the same identity and publishes or verifies
the tap release. `tests/release-preparation.sh` exercises it with temporary
Git repositories, rejected/concurrent pushes, and controlled `gh` responses,
including workflow wiring. Ordinary validation runs these tests alongside
the existing formula and native checks, without a per-PR changelog gate.

Preparation requires `main` to still match the dispatch commit. Its source
write uses only the source workflow token, with no branch-protection bypass.
The existing tap-only token remains confined to tap publication. The annotated
tag records the repository, workflow run ID, dispatch source, and increment;
if preparation is retried after the atomic push, it recovers this original
identity before consulting the latest tap release. A different run cannot
reuse that tag. Rejected writes do not publish either remote ref, while
failed builds/publication do not roll back an already-prepared commit/tag.

Preserve existing artifact and source-provenance verification when a release
already exists. Retries must not silently replace conflicting artifacts or
publish notes from a different source snapshot. Manually pushed tags no longer
start a release; manual workflow dispatch is the only release entry point.
Existing release bodies must match the selected section, and both archives
must match the two-entry checksum manifest and `SOURCE_COMMIT`. These verified
published bytes remain authoritative if a rebuild produces different archive
bytes; retries never upload replacements. GitHub failures are not interpreted
as absence of a release.

## Historical backfill

Curated sections for the two existing releases are in `CHANGELOG.md`.
Their GitHub release bodies were updated to match those sections without
changing tags or assets. This was a one-time, explicit update to release
descriptions only; future workflow runs do not rewrite historical releases.

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

Contributor/agent guidance, the canonical changelog, the README procedure,
the workflow, and both historical release bodies now match the implemented
behavior. Focused tests cover section extraction, missing-note failures,
finalization, retry identity, publication conflicts, and dispatch-only wiring.
Future dispatches publish only their selected release and do not rewrite
historical release bodies.
