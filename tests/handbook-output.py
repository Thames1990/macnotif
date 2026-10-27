#!/usr/bin/env python3
"""Check the built public handbook, not theme templates or source layout."""

import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

ORIGIN = "https://macnotif.mohrworks.com"


class Document(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.text = ""
        self.ids = set()
        self.links = []
        self.resources = []
        self.navigation = []
        self.buttons = []
        self.in_nav = False
        self.feed(path.read_text())
        self.text = " ".join(self.text.split())

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "nav":
            self.in_nav = True
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
            if self.in_nav:
                self.navigation.append(attrs["href"])
        if tag in ("script", "img", "source") and "src" in attrs:
            self.resources.append(attrs["src"])
        if tag == "link" and attrs.get("rel") == "stylesheet":
            self.resources.append(attrs["href"])
        if tag == "button":
            self.buttons.append(attrs)

    def handle_endtag(self, tag):
        if tag == "nav":
            self.in_nav = False

    def handle_data(self, data):
        self.text += data


def require(condition, message):
    if not condition:
        raise SystemExit(message)


site = Path(sys.argv[1])
overview = site / "index.html"
require(overview.is_file(), "Overview must be published at the domain root")
html = Document(overview).text
for text in ("Overview", "macOS Sequoia", "arm64", "x86_64", "Notification Center"):
    require(text in html, f"Overview is missing {text!r}")

installation = site / "installation" / "index.html"
require(installation.is_file(), "Installation guide must be published")
for text in (
    "brew install Thames1990/tap/macnotif",
    "brew upgrade macnotif",
    "brew uninstall macnotif",
    "./scripts/build.sh",
    "unsigned",
    "Gatekeeper",
    "command -v macnotif",
):
    require(text in Document(installation).text, f"Installation is missing {text!r}")

cli = site / "cli-usage" / "index.html"
require(cli.is_file(), "CLI Usage must be published")
cli_text = Document(cli).text
for text in (
    "--title",
    "--description",
    "--mode temporary|permanent",
    "--duration",
    "finite positive",
    "macnotif --clear",
    "does not clear a temporary notice",
    "same kind",
    "stderr",
    "--border-color",
):
    require(text in cli_text, f"CLI Usage is missing {text!r}")

documents = {path: Document(path) for path in site.rglob("*.html")}
allowed_pages = {
    "index.html",
    "installation/index.html",
    "cli-usage/index.html",
    "configuration/index.html",
    "changelog/index.html",
}
for path in site.rglob("*"):
    if not path.is_file():
        continue
    relative = path.relative_to(site).as_posix()
    require(
        relative in allowed_pages or relative.startswith("assets/"),
        f"Unintended published file: {relative}",
    )
    require(
        path.suffix in (".html", ".css", ".js", ".json", ".map", ".svg", ".ico", ".png"),
        f"Unintended published file type: {relative}",
    )
    for private_text in (
        "HOMEBREW_TAP_TOKEN",
        "Issue tracker: GitHub",
        "Agent skills",
        "Keep a custom panel rather than Notification Center banners",
    ):
        require(
            private_text not in path.read_text(errors="replace"),
            f"Internal material leaked into {relative}: {private_text}",
        )


def resolve_local(reference, page_url):
    url = urlsplit(urljoin(ORIGIN + page_url, reference))
    if url.scheme not in ("http", "https") or url.netloc != urlsplit(ORIGIN).netloc:
        return None
    path = site / unquote(url.path).lstrip("/")
    if url.path.endswith("/"):
        path /= "index.html"
    require(path.resolve().is_relative_to(site.resolve()), f"URL escapes site: {reference}")
    require(path.is_file(), f"Broken public URL from {page_url}: {reference}")
    if url.fragment and path.suffix == ".html":
        require(
            unquote(url.fragment) in documents[path].ids,
            f"Broken fragment from {page_url}: {reference}",
        )
    return path


for path, document in documents.items():
    page_url = "/" + path.relative_to(site).as_posix().removesuffix("index.html")
    for target in ("/", "/installation/", "/cli-usage/"):
        require(target in document.navigation, f"{page_url} navigation is missing {target}")
    for reference in document.links:
        resolve_local(reference, page_url)
    for resource in document.resources:
        require(
            resource.startswith("/") and not resource.startswith("//"),
            f"Resource must be local to the custom-domain root: {resource}",
        )
        resolve_local(resource, page_url)
    require(
        any(button.get("aria-label") == "Toggle dark mode" for button in document.buttons),
        f"{page_url} needs an accessible light/dark control",
    )

search = json.loads((site / "assets/js/search-data.json").read_text())
records = list(search.values())
for title in ("Overview", "Installation", "CLI Usage"):
    require(any(record["doc"] == title for record in records), f"Search is missing {title}")
for term in ("--clear", "Gatekeeper", "Notification Center"):
    require(any(term in record["content"] for record in records), f"Search is missing {term}")
for record in records:
    require(resolve_local(record["url"], "/") is not None, f"Nonlocal search URL: {record['url']}")

for stylesheet in site.rglob("*.css"):
    page_url = "/" + stylesheet.relative_to(site).as_posix()
    for reference in re.findall(r"url\(\s*['\"]?([^)'\"\s]+)", stylesheet.read_text()):
        if not reference.startswith("data:"):
            require(resolve_local(reference, page_url) is not None, f"External CSS asset: {reference}")
print("Handbook output checks passed")
