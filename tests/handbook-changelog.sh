#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_directory="$repo_root/.build/handbook-changelog-test-$$"
if [[ -e "$test_directory" ]]; then
    echo "Refusing to overwrite existing test directory: $test_directory" >&2
    exit 1
fi
mkdir -p "$test_directory"
trap 'rm -rf "$test_directory"' EXIT
source_directory="$test_directory/source"
mkdir -p "$source_directory"

# Exercise a disposable source tree so failures cannot leave edited release notes.
cd "$repo_root"
git ls-files -z --cached --others --exclude-standard |
    tar -cf - --null -T - |
    tar -xf - -C "$source_directory"

build() {
    (
        # Keep the installed bundle's local configuration outside the disposable tree.
        cd "$repo_root/docs/handbook"
        BUNDLE_GEMFILE="$repo_root/docs/handbook/Gemfile" JEKYLL_ENV=production \
            bundle exec jekyll build \
                --config "$source_directory/docs/handbook/_config.yml" \
                --source "$source_directory/docs/handbook/site" \
                --destination "$test_directory/site"
    )
}

if [[ $# -gt 0 ]]; then
    output_directory="$(cd "$1" && pwd)"
else
    build
    output_directory="$test_directory/site"
fi
python3 - "$source_directory/CHANGELOG.md" "$output_directory" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path


class Page(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.headings = []
        self.links = []
        self.text = []
        self.heading = None
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("h1", "h2"):
            self.heading = []
        if tag == "a":
            self.links.append(attrs.get("href", ""))

    def handle_data(self, data):
        self.text.append(data)
        if self.heading is not None:
            self.heading.append(data)

    def handle_endtag(self, tag):
        if tag in ("h1", "h2") and self.heading is not None:
            self.headings.append("".join(self.heading).strip())
            self.heading = None


canonical = Path(sys.argv[1]).read_text()
site = Path(sys.argv[2])
changelog = site / "changelog/index.html"
assert changelog.is_file(), "The handbook must publish /changelog/"
page = Page(changelog.read_text())
assert "Changelog" in page.headings, "The changelog needs a page heading"
assert "Unreleased" not in page.headings, "Unreleased changes must not be published"
for line in canonical.splitlines():
    if line.startswith("## "):
        if line[3:] != "Unreleased":
            assert line[3:] in page.headings, f"Missing release heading: {line[3:]}"
assert "/changelog/" in Page((site / "index.html").read_text()).links, \
    "Readers must be able to navigate to Changelog from the overview"
assert "Homebrew distribution with native Apple Silicon and Intel executables." in \
    " ".join(" ".join(page.text).split()), "Existing curated release content is missing"
PY

python3 - "$source_directory/CHANGELOG.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
content = path.read_text()
assert content.count("## Unreleased\n") == 1
path.write_text(content.replace(
    "## Unreleased\n",
    "## Unreleased\n\n### Fixed\n\n"
    "- Unreleased handbook probe must not be published.\n",
    1,
).replace(
    "## 1.1.0 - 2026-10-25\n",
    "## 1.1.0 - 2026-10-25\n\n### Canonical Probe Anchor\n\n"
    "- Canonical changelog probe **formatted** with `--clear` and "
    "[released changes](#canonical-probe-anchor).\n",
    1,
))
PY

build
python3 - "$test_directory/site/changelog/index.html" <<'PY'
import sys
from html.parser import HTMLParser
from pathlib import Path


class Probe(HTMLParser):
    def __init__(self, html):
        super().__init__()
        self.stack = []
        self.formatted = False
        self.code = False
        self.link = False
        self.probe_anchor = False
        self.text = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.stack.append((tag, attrs))
        if attrs.get("id") == "canonical-probe-anchor":
            self.probe_anchor = True

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                break

    def handle_data(self, data):
        self.text.append(data)
        if not self.stack:
            return
        tag, attrs = self.stack[-1]
        self.formatted |= tag == "strong" and data == "formatted"
        self.code |= tag == "code" and data == "--clear"
        self.link |= tag == "a" and attrs.get("href") == "#canonical-probe-anchor" \
            and data == "released changes"


page = Probe(Path(sys.argv[1]).read_text())
assert "Canonical changelog probe" in "".join(page.text), \
    "Editing only the canonical changelog must update generated output"
assert page.formatted and page.code, "Curated Markdown formatting must render"
assert page.link and page.probe_anchor, "Changelog fragment links must resolve"
assert "Unreleased handbook probe" not in "".join(page.text), \
    "Unreleased changelog content must not be published"
PY

echo "Handbook canonical changelog checks passed"
