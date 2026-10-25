#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$(mktemp -d)"
trap 'rm -rf "$test_directory"' EXIT
mkdir -p "$test_directory/bin"
export PATH="$test_directory/bin:$PATH"
export LATEST_TAG=v1.2.3
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

cat > "$test_directory/bin/gh" <<'SH'
#!/bin/bash
set -euo pipefail
if [[ "$*" == "api repos/Thames1990/homebrew-tap/releases/latest --jq .tag_name" ]]; then
    if [[ "${GH_FAIL:-0}" == 1 ]]; then
        echo "GitHub unavailable" >&2
        exit 1
    fi
    if [[ -n "${MOVE_REMOTE:-}" ]]; then
        git --git-dir="$MOVE_REMOTE" update-ref refs/heads/main "$MOVE_COMMIT"
    fi
    printf '%s\n' "$LATEST_TAG"
elif [[ "$*" == "api repos/Thames1990/homebrew-tap/releases --paginate --jq .[].tag_name" ]]; then
    if [[ "${GH_FAIL:-0}" == 1 ]]; then echo "GitHub unavailable" >&2; exit 1; fi
    if [[ -f "$PUBLISHED/tag" ]]; then cat "$PUBLISHED/tag"; fi
elif [[ "$1 $2" == "release create" ]]; then
    if [[ "${GH_CREATE_FAIL:-0}" == 1 ]]; then echo "Publication rejected" >&2; exit 1; fi
    tag="$3"
    shift 3
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) test "$2" = Thames1990/homebrew-tap; shift 2 ;;
            --title) test "$2" = "MacNotif ${tag#v}"; shift 2 ;;
            --notes-file) cp "$2" "$PUBLISHED/notes"; shift 2 ;;
            --*) echo "Unexpected publication flag $1" >&2; exit 1 ;;
            *) cp "$1" "$PUBLISHED/"; shift ;;
        esac
    done
    printf '%s\n' "$tag" > "$PUBLISHED/tag"
    echo created >> "$PUBLISHED/writes"
elif [[ "$1 $2" == "release view" ]]; then
    if [[ "${GH_VIEW_FAIL:-0}" == 1 ]]; then echo "Release lookup denied" >&2; exit 1; fi
    test "$*" = "release view $(cat "$PUBLISHED/tag") --repo Thames1990/homebrew-tap --json body --jq .body"
    cat "$PUBLISHED/notes"
elif [[ "$1 $2" == "release download" ]]; then
    if [[ "${GH_DOWNLOAD_FAIL:-0}" == 1 ]]; then echo "Asset download denied" >&2; exit 1; fi
    shift 3
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo) test "$2" = Thames1990/homebrew-tap; shift 2 ;;
            --pattern) shift 2 ;;
            --dir) destination="$2"; shift 2 ;;
            *) echo "Unexpected download flag $1" >&2; exit 1 ;;
        esac
    done
    cp "$PUBLISHED/"*.tar.gz "$PUBLISHED/SHA256SUMS" "$PUBLISHED/SOURCE_COMMIT" "$destination/"
else
    echo "Unexpected GitHub operation: $*" >&2; exit 1
fi
SH
chmod +x "$test_directory/bin/gh"

fixture() {
    case_directory="$test_directory/$1"
    git init --quiet --bare "$case_directory/remote.git"
    git init --quiet -b main "$case_directory/source"
    cd "$case_directory/source"
    git config user.name Tester
    git config user.email tester@example.invalid
    cat > CHANGELOG.md <<'MD'
# Changelog

## Unreleased

### Fixed

- Keep **Markdown**, `code`, and [links](https://example.org).

## 1.2.3 - 2026-01-01

- Older notes.
MD
    echo original > unrelated
    git add .
    git commit --quiet -m Initial
    git remote add origin "$case_directory/remote.git"
    git push --quiet origin main
    source_commit="$(git rev-parse HEAD)"
}

prepare() {
    python3 "$repo_root/scripts/release.py" prepare \
        --event workflow_dispatch --ref refs/heads/main --bump patch \
        --source "$source_commit" --run-id 42 --repository Thames1990/macnotif \
        --output "$case_directory/identity" "$@"
}

save_notes() {
    git add CHANGELOG.md
    git commit --quiet -m Notes
    git push --quiet origin main
    source_commit="$(git rev-parse HEAD)"
}

reject() {
    if prepare "$@" > "$case_directory/log" 2>&1; then
        echo "Preparation unexpectedly succeeded: $case_directory" >&2
        exit 1
    fi
    test ! -e "$case_directory/identity"
    test -z "$(git ls-remote --tags origin)"
}

fixture finalize
echo staged > unrelated
git add unrelated
echo untracked > untracked
prepare
tag_commit="$(git rev-parse 'v1.2.4^{commit}')"
test "$tag_commit" != "$source_commit"
test "$(git rev-parse origin/main)" = "$tag_commit"
test "$(git diff-tree --no-commit-id --name-only -r "$tag_commit")" = CHANGELOG.md
test "$(git show HEAD:unrelated)" = original
test "$(git diff --cached --name-only)" = unrelated
test "$(cat unrelated)" = staged
test "$(cat untracked)" = untracked
grep -Fxq 'tag_name=v1.2.4' "$case_directory/identity"
grep -Fxq "source_commit=$tag_commit" "$case_directory/identity"
python3 - <<'PY'
import datetime
from pathlib import Path
expected = f"""# Changelog

## Unreleased

## 1.2.4 - {datetime.datetime.now(datetime.timezone.utc).date().isoformat()}

### Fixed

- Keep **Markdown**, `code`, and [links](https://example.org).

## 1.2.3 - 2026-01-01

- Older notes.
"""
assert Path("CHANGELOG.md").read_text() == expected
PY

python3 "$repo_root/scripts/release.py" notes --tag v1.2.4 \
    --source "$tag_commit" --output "$case_directory/notes"
cat > "$case_directory/expected-notes" <<'MD'
### Fixed

- Keep **Markdown**, `code`, and [links](https://example.org).
MD
cmp "$case_directory/notes" "$case_directory/expected-notes"

# A rerun keeps the allocated version even after publication and new main work.
git restore --staged unrelated
git add unrelated untracked
git commit --quiet -m "Later work"
sed -i.bak '/## Unreleased/a\
\
- New future notes.
' CHANGELOG.md
rm CHANGELOG.md.bak
git add CHANGELOG.md
git commit --quiet -m "Future notes"
git push --quiet origin main
later_main="$(git rev-parse HEAD)"
export LATEST_TAG=v1.2.4
rm "$case_directory/identity"
prepare
grep -Fxq 'tag_name=v1.2.4' "$case_directory/identity"
grep -Fxq "source_commit=$tag_commit" "$case_directory/identity"
test "$(git rev-parse origin/main)" = "$later_main"
test "$(git rev-parse 'v1.2.4^{commit}')" = "$tag_commit"
python3 "$repo_root/scripts/release.py" notes --tag v1.2.4 \
    --source "$tag_commit" --output "$case_directory/retry-notes"
cmp "$case_directory/retry-notes" "$case_directory/expected-notes"
git clone --quiet --branch main "$case_directory/remote.git" "$case_directory/retry"
cd "$case_directory/retry"
git checkout --quiet --detach "$source_commit"
rm "$case_directory/identity"
export GH_FAIL=1
prepare
unset GH_FAIL
grep -Fxq "source_commit=$tag_commit" "$case_directory/identity"
grep -Fxq 'tag_name=v1.2.4' "$case_directory/identity"
rm "$case_directory/identity"
if prepare --source "$later_main" > "$case_directory/log" 2>&1; then
    echo "Rerun accepted a different dispatch identity" >&2; exit 1
fi
grep -Fq 'Retry dispatch identity conflicts' "$case_directory/log"
test ! -e "$case_directory/identity"
export LATEST_TAG=v1.2.3

for bump in minor major; do
    fixture "$bump"
    prepare --bump "$bump"
    if [[ "$bump" == minor ]]; then expected=v1.3.0; else expected=v2.0.0; fi
    grep -Fxq "tag_name=$expected" "$case_directory/identity"
done

fixture reuse
cat > CHANGELOG.md <<'MD'
# Changelog

## Unreleased

- Future feature must stay unreleased.

## 1.2.4 - 2026-10-20

### Added

- Curated **release**.

```markdown
## Not a section boundary inside a fence
```

## 1.2.3 - 2026-01-01

- Must not leak.
MD
save_notes
cp CHANGELOG.md "$case_directory/original"
prepare
test "$(git rev-parse 'v1.2.4^{commit}')" = "$source_commit"
cmp CHANGELOG.md "$case_directory/original"
python3 "$repo_root/scripts/release.py" notes --tag v1.2.4 \
    --source "$source_commit" --output "$case_directory/notes"
cat > "$case_directory/expected" <<'MD'
### Added

- Curated **release**.

```markdown
## Not a section boundary inside a fence
```
MD
cmp "$case_directory/notes" "$case_directory/expected"

for invalid in missing empty headings comments empty-finalized; do
    fixture "$invalid"
    case "$invalid" in
        missing) printf '# Changelog\n' > CHANGELOG.md ;;
        empty) printf '# Changelog\n\n## Unreleased\n' > CHANGELOG.md ;;
        headings) printf '# Changelog\n\n## Unreleased\n\n### Added\n\n- \n' > CHANGELOG.md ;;
        comments) printf '# Changelog\n\n## Unreleased\n\n<!-- Add notes here -->\n' > CHANGELOG.md ;;
        empty-finalized) printf '# Changelog\n\n## Unreleased\n\n- Valid future notes.\n\n## 1.2.4 - 2026-10-20\n\n### Fixed\n' > CHANGELOG.md ;;
    esac
    save_notes
    reject
    grep -Eq 'notes|Unreleased' "$case_directory/log"
    test "$(git rev-parse origin/main)" = "$source_commit"
done

fixture maintenance
printf '# Changelog\n\n## Unreleased\n\nNo user-facing changes.\n' > CHANGELOG.md
save_notes
prepare
grep -Fq 'No user-facing changes.' CHANGELOG.md

fixture indentation
printf '# Changelog\n\n## Unreleased\n\n    macnotif --clear\n' > CHANGELOG.md
save_notes
prepare
python3 "$repo_root/scripts/release.py" notes --tag v1.2.4 \
    --source "$(git rev-parse HEAD)" --output "$case_directory/notes"
printf '    macnotif --clear\n' > "$case_directory/expected"
cmp "$case_directory/notes" "$case_directory/expected"

for invalid in bad-event bad-ref bad-bump bad-source latest-failure latest-invalid; do
    fixture "$invalid"
    case "$invalid" in
        bad-event) reject --event push ;;
        bad-ref) reject --ref refs/heads/feature ;;
        bad-bump) reject --bump huge ;;
        bad-source) reject --source not-a-sha ;;
        latest-failure)
            export GH_FAIL=1
            reject
            grep -Fq 'Cannot read the latest published tap release' "$case_directory/log"
            grep -Fq 'GitHub unavailable' "$case_directory/log"
            unset GH_FAIL
            ;;
        latest-invalid)
            for latest in v01.2.3 v1.2 v1.2.3-rc1 null; do
                export LATEST_TAG="$latest"
                reject
                grep -Fq 'invalid version' "$case_directory/log"
            done
            export LATEST_TAG=v1.2.3
            ;;
    esac
done

fixture protected
cat > "$case_directory/remote.git/hooks/pre-receive" <<'SH'
#!/bin/sh
echo "Protected branch write rejected" >&2
exit 1
SH
chmod +x "$case_directory/remote.git/hooks/pre-receive"
reject
grep -Fq 'Source write rejected' "$case_directory/log"
grep -Fq 'Protected branch write rejected' "$case_directory/log"
test "$(git ls-remote origin refs/heads/main | cut -f1)" = "$source_commit"

fixture concurrent
other_commit="$(git commit-tree 'HEAD^{tree}' -p HEAD -m Concurrent)"
git push --quiet origin "$other_commit:refs/heads/concurrent"
export MOVE_REMOTE="$case_directory/remote.git" MOVE_COMMIT="$other_commit"
reject
unset MOVE_REMOTE MOVE_COMMIT
grep -Fq 'Source write rejected' "$case_directory/log"
test "$(git ls-remote origin refs/heads/main | cut -f1)" = "$other_commit"

fixture stale-dispatch
old_source="$source_commit"
echo changed >> unrelated
git add unrelated
git commit --quiet -m Concurrent
git push --quiet origin main
source_commit="$old_source"
reject
grep -Fq 'Concurrent main movement' "$case_directory/log"

fixture staged-changelog
printf '\n- A staged note that must not be lost.\n' >> CHANGELOG.md
git add CHANGELOG.md
git show HEAD:CHANGELOG.md > CHANGELOG.md
staged_blob="$(git rev-parse :CHANGELOG.md)"
reject
grep -Fq 'CHANGELOG.md has local edits' "$case_directory/log"
test "$(git rev-parse :CHANGELOG.md)" = "$staged_blob"

fixture conflict
git tag v1.2.4
git push --quiet origin v1.2.4
if prepare > "$case_directory/log" 2>&1; then
    echo "Conflicting tag was accepted" >&2
    exit 1
fi
grep -Fq 'Conflicting tag' "$case_directory/log"
test "$(git rev-parse v1.2.4)" = "$source_commit"
test "$(git ls-remote origin refs/tags/v1.2.4 | cut -f1)" = "$source_commit"
test ! -e "$case_directory/identity"

fixture publication
prepare
prepared_source="$(git rev-parse 'v1.2.4^{commit}')"
export PUBLISHED="$case_directory/published"
mkdir -p "$PUBLISHED" dist
printf 'arm64 archive bytes\n' > dist/macnotif-1.2.4-arm64.tar.gz
printf 'x86 archive bytes\n' > dist/macnotif-1.2.4-x86_64.tar.gz
publish() {
    python3 "$repo_root/scripts/release.py" publish --tag v1.2.4 \
        --source "$prepared_source" --dist dist --output "$case_directory/checksums" "$@"
}
publish
test "$(cat "$PUBLISHED/tag")" = v1.2.4
test "$(cat "$PUBLISHED/SOURCE_COMMIT")" = "$prepared_source"
cat > "$case_directory/expected" <<'MD'
### Fixed

- Keep **Markdown**, `code`, and [links](https://example.org).
MD
cmp "$PUBLISHED/notes" "$case_directory/expected"
test "$(wc -l < "$PUBLISHED/SHA256SUMS" | tr -d ' ')" = 2
grep -Eq '^arm64_sha256=[0-9a-f]{64}$' "$case_directory/checksums"
grep -Eq '^x86_64_sha256=[0-9a-f]{64}$' "$case_directory/checksums"

# Rebuilt archives may differ; a retry uses verified, previously published bytes.
echo rebuilt > dist/macnotif-1.2.4-arm64.tar.gz
publish
cmp dist/macnotif-1.2.4-arm64.tar.gz "$PUBLISHED/macnotif-1.2.4-arm64.tar.gz"
test "$(cat "$PUBLISHED/writes")" = created

for conflict in provenance checksum manifest archive notes unavailable view-failure download-failure source; do
    cp "$PUBLISHED/SOURCE_COMMIT" "$case_directory/source-backup"
    cp "$PUBLISHED/SHA256SUMS" "$case_directory/sums-backup"
    cp "$PUBLISHED/notes" "$case_directory/notes-backup"
    cp "$PUBLISHED/macnotif-1.2.4-arm64.tar.gz" "$case_directory/archive-backup"
    case "$conflict" in
        provenance) printf '%040d\n' 0 > "$PUBLISHED/SOURCE_COMMIT" ;;
        checksum) echo corrupt >> "$PUBLISHED/SHA256SUMS" ;;
        manifest) sed 's/macnotif-1.2.4-arm64.tar.gz/other-file/' "$case_directory/sums-backup" > "$PUBLISHED/SHA256SUMS" ;;
        archive) echo corruption >> "$PUBLISHED/macnotif-1.2.4-arm64.tar.gz" ;;
        notes) echo 'Notes from another snapshot' > "$PUBLISHED/notes" ;;
        unavailable) export GH_FAIL=1 ;;
        view-failure) export GH_VIEW_FAIL=1 ;;
        download-failure) export GH_DOWNLOAD_FAIL=1 ;;
        source)
            if publish --source "$source_commit" > "$case_directory/log" 2>&1; then
                echo "Publication accepted another source" >&2; exit 1
            fi
            grep -Fq 'Release tag does not match' "$case_directory/log"
            continue
            ;;
    esac
    if publish > "$case_directory/log" 2>&1; then
        echo "Publication accepted $conflict" >&2; exit 1
    fi
    test "$(cat "$PUBLISHED/writes")" = created
    cp "$case_directory/source-backup" "$PUBLISHED/SOURCE_COMMIT"
    cp "$case_directory/sums-backup" "$PUBLISHED/SHA256SUMS"
    cp "$case_directory/notes-backup" "$PUBLISHED/notes"
    cp "$case_directory/archive-backup" "$PUBLISHED/macnotif-1.2.4-arm64.tar.gz"
    unset GH_FAIL GH_VIEW_FAIL GH_DOWNLOAD_FAIL
done

rm "$PUBLISHED/tag"
export GH_CREATE_FAIL=1
if publish > "$case_directory/log" 2>&1; then echo "Publication failure was hidden" >&2; exit 1; fi
grep -Fq 'Publication rejected' "$case_directory/log"
unset GH_CREATE_FAIL
test "$(git rev-parse 'v1.2.4^{commit}')" = "$prepared_source"
test "$(git ls-remote origin refs/heads/main | cut -f1)" = "$prepared_source"

python3 - "$repo_root" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
workflow = (root / ".github/workflows/release.yml").read_text()
triggers = workflow.split("\npermissions:", 1)[0]
assert "  workflow_dispatch:" in triggers
assert not re.search(r"^  (push|release|workflow_run|schedule):", triggers, re.M)
assert "group: homebrew-tap-release\n  cancel-in-progress: false" in workflow
prepare = workflow.split("\n  prepare:", 1)[1].split("\n  build:", 1)[0]
assert "contents: write" in prepare
assert "GH_TOKEN: ${{ github.token }}" in prepare
assert "HOMEBREW_TAP_TOKEN" not in prepare
assert "RUN_ID: ${{ github.run_id }}" in prepare
assert "SOURCE_COMMIT: ${{ github.sha }}" in prepare
assert "python3 scripts/release.py prepare" in prepare
assert '--output "$GITHUB_OUTPUT"' in prepare
assert "source_commit: ${{ steps.release.outputs.source_commit }}" in prepare
for job, following in (("build", "publish"), ("publish", "verify-install"), ("verify-install", None)):
    block = workflow.split(f"\n  {job}:", 1)[1]
    if following:
        block = block.split(f"\n  {following}:", 1)[0]
    assert "ref: ${{ needs.prepare.outputs.source_commit }}" in block
build = workflow.split("\n  build:", 1)[1].split("\n  publish:", 1)[0]
assert "python3 scripts/release.py notes" in build
assert "bash tests/release-smoke.sh build/macnotif" in build
assert "architecture: arm64" in build and "architecture: x86_64" in build
publish = workflow.split("\n  publish:", 1)[1].split("\n  verify-install:", 1)[0]
assert "GH_TOKEN: ${{ secrets.HOMEBREW_TAP_TOKEN }}" in publish
assert "python3 scripts/release.py publish" in publish
assert '--source "$SOURCE_COMMIT"' in publish
assert "bash scripts/render-formula.sh" in publish
assert "brew test Thames1990/tap/macnotif" in workflow
assert "bash tests/release-preparation.sh" in (root / ".github/workflows/validate.yml").read_text()
PY

echo "Release preparation tests passed"
