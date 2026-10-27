# Maintainer releases

The [release changelog design](release-changelogs.md) documents the
implemented curated-note release flow. Before dispatching, review the notes
under `Unreleased` in [CHANGELOG.md](../CHANGELOG.md); starting a release
approves those notes. Missing or empty notes stop preparation. For an
intentional maintenance-only release, explicitly record "No user-facing
changes." An already-finalized section for the selected version is reused
without consuming newer Unreleased entries.

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
explicitly; the workflow never force pushes or moves tags. The dedicated release
app can bypass only the PR/check ruleset, as described below.

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

## Source release app and main protection

Source preparation uses a short-lived GitHub App installation token with
**Contents: read and write**, restricted to `Thames1990/macnotif`. Register a
private app under the repository owner's account, disable webhooks, and install
it on this repository only. It needs no Actions, Workflows, Administration, or
tap permissions. Store its client ID in the repository Actions variable
`RELEASE_APP_CLIENT_ID`. Generate a private key and upload the PEM directly as
the `RELEASE_APP_PRIVATE_KEY` secret in the `release-source` environment, not as
a repository-wide secret. Never commit or log the key.

Restrict the `release-source` environment to the `main` branch only (selected
branches and tags, with a branch rule for `main` and no tag rules). The prepare
job also checks the event and branch before requesting a token. The app token
is used by checkout and persisted for Git authentication during preparation,
then revoked by `actions/create-github-app-token` at job completion. It is not
passed to builds, publication, or installation checks. The workflow's
`GITHUB_TOKEN` remains read-only and is used to read public tap release metadata;
the existing tap token remains confined to tap publication.

Unlike pushes authenticated with `GITHUB_TOKEN`, the app's changelog push
triggers normal validation and the path-filtered handbook publication. A pushed
tag still does not start another application release.

After these workflow changes are on `main` and the app is installed, configure
two active branch rulesets targeting `refs/heads/main`:

- **Main integrity:** restrict deletions and block non-fast-forward pushes,
  with no bypass actors, including the release app.
- **Main PR and checks:** require a pull request with zero required approvals
  and successful `arm64 macOS` and `x86_64 macOS` checks from GitHub Actions.
  Give only the release app an always-allowed bypass of this ruleset so it can
  atomically push the finalized changelog and tag. Do not require the
  path-filtered handbook check. No administrator bypass is needed.

The app's bypass is repository-wide for these PR/check rules, not constrained
to a particular file by GitHub; keep its private key limited to the main-only
environment and audit changes to release preparation. The release script still
checks the dispatch identity, concurrent movement, and changelog-only commit.
If another policy rejects a source write, resolve that policy/access issue
through the maintainer process rather than widening the tap token or adding
further bypasses.
