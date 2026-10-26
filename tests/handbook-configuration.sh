#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "${1:-$repo_root/_site}" <<'PY'
import json
import sys
from html.parser import HTMLParser
from pathlib import Path


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.text = []
        self.links = []
        self.feed(source)

    def handle_data(self, data):
        self.text.append(data)

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.links.append(dict(attrs).get("href", ""))


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

print("Configuration production-output checks passed")
PY
