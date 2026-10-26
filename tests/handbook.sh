#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
python3 tests/handbook-output.py "${1:-_site}"
bash tests/handbook-configuration.sh "${1:-_site}"
bash tests/handbook-changelog.sh "${1:-_site}"
