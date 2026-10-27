#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
site_directory="${1:-$repo_root/docs/handbook/_site}"
python3 tests/handbook-output.py "$site_directory"
bash tests/handbook-configuration.sh "$site_directory"
bash tests/handbook-changelog.sh "$site_directory"
