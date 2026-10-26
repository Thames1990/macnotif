#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "${1:-$repo_root/_site}" <<'PY'
import json
import sys
import tomllib
from html.parser import HTMLParser
from pathlib import Path


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.text = []
        self.links = []
        self.rows = []
        self.examples = []
        self.row = None
        self.example = None
        self.feed(source)

    def handle_data(self, data):
        self.text.append(data)
        if self.row is not None:
            self.row.append(data)
        if self.example is not None:
            self.example.append(data)

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.links.append(dict(attrs).get("href", ""))
        if tag == "tr":
            self.row = []
        if tag in ("td", "th") and self.row is not None:
            self.row.append(" ")
        if tag == "pre":
            self.example = []

    def handle_endtag(self, tag):
        if tag == "tr" and self.row is not None:
            self.rows.append(" ".join("".join(self.row).split()))
            self.row = None
        if tag == "pre" and self.example is not None:
            self.examples.append("".join(self.example))
            self.example = None


site = Path(sys.argv[1])
configuration = site / "configuration/index.html"
assert configuration.is_file(), "Production output is missing the Configuration reference"
page = Page(configuration.read_text())
overview = Page((site / "index.html").read_text())
assert any(link.rstrip("/").endswith("/configuration") for link in overview.links), (
    "Configuration must be reachable from handbook navigation"
)
search = json.loads((site / "assets/js/search-data.json").read_text())
entries = search.values() if isinstance(search, dict) else search
configuration_entries = [
    entry for entry in entries if "/configuration" in entry.get("url", "")
]
assert configuration_entries, "Configuration is missing from local search data"
search_text = " ".join(entry.get("content", "") for entry in configuration_entries)
for term in ("XDG_CONFIG_HOME", "horizontal_inset", "animation_duration", "last known-good"):
    assert term in search_text, f"Configuration search data is missing {term}"

expected_settings = {
    "notice.mode": ('"temporary"', '"permanent"'),
    "notice.duration": ("1", "positive", "seconds"),
    "display.id": ("Omitted", "4294967295"),
    "layout.anchor": ('"top-right"', '"top-left"', '"bottom-left"', '"bottom-right"'),
    "layout.horizontal_inset": ("18", "non-negative", "points"),
    "layout.vertical_inset": ("18", "non-negative", "points"),
    "appearance.width": ("360", "160", "1200"),
    "appearance.min_height": ("54", "32", "400"),
    "appearance.padding": ("14", "0", "80"),
    "appearance.icon_spacing": ("12", "0", "80"),
    "appearance.text_spacing": ("2", "0", "40"),
    "appearance.stack_spacing": ("8", "0", "80"),
    "appearance.title_size": ("14", "8", "96"),
    "appearance.detail_size": ("13", "8", "96"),
    "appearance.symbol_size": ("16", "8", "96"),
    "appearance.corner_radius": ("14", "0", "100"),
    "appearance.shadow": ("true", "false"),
    "appearance.permanent_symbol": ('"pin.fill"', "SF Symbol"),
    "appearance.temporary_symbol": ('"bell.fill"', "SF Symbol"),
    "appearance.animation_duration": ("0.15", "0", "2", "seconds"),
    "appearance.border_width": ("0", "10"),
}
for key, values in expected_settings.items():
    rows = [row for row in page.rows if row.startswith(key + " ")]
    assert any(all(value in row for value in values) for row in rows), (
        f"Reference needs a settings row for {key} with default and limits {values}"
    )
    assert key in search_text, f"Configuration search data is missing {key}"

text = " ".join("".join(page.text).split())
for concept in (
    "1.1.0", "Unreleased", "before CLI overrides", "stderr", "line, and column",
    "150 ms", "last known-good", "Deleting the file", "Reduce Motion",
    "Increase Contrast", "Reduce Transparency", "preferred headline/body",
    "appearance.light", "appearance.dark", "#RRGGBBAA",
):
    assert concept in text, f"Reference is missing guidance about {concept}"

toml_examples = [example for example in page.examples if example.lstrip().startswith("[")]
assert toml_examples, "Reference must provide copyable TOML examples"
for example in toml_examples:
    tomllib.loads(example)
palette = next(
    tomllib.loads(example)["appearance"]
    for example in toml_examples if "[appearance.light]" in example
)
assert palette["border_width"] == 1, "Palette example must enable its optional border"
for scheme in ("light", "dark"):
    assert set(palette[scheme]) == {"background", "title", "detail", "symbol", "border"}

print("Configuration production-output checks passed")
PY
