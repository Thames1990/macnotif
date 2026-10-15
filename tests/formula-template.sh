#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output="$(mktemp)"
trap 'rm -f "$test_output"' EXIT

arm64_sha256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
x86_64_sha256=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
bash "$repo_root/scripts/render-formula.sh" 1.2.3 "$arm64_sha256" "$x86_64_sha256" "$test_output"

grep -Fq 'version "1.2.3"' "$test_output"
grep -Fq 'dinky-notify-#{version}-arm64.tar.gz' "$test_output"
grep -Fq "sha256 \"$arm64_sha256\"" "$test_output"
grep -Fq 'dinky-notify-#{version}-x86_64.tar.gz' "$test_output"
grep -Fq "sha256 \"$x86_64_sha256\"" "$test_output"
grep -Fq 'depends_on macos: ">= :sequoia"' "$test_output"
if grep -Fq '@' "$test_output"; then
    echo "Formula output still contains a template marker" >&2
    exit 1
fi

if bash "$repo_root/scripts/render-formula.sh" 1.2 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$x86_64_sha256" "$test_output" 2>/dev/null; then
    echo "Formula renderer accepted an invalid version" >&2
    exit 1
fi
if bash "$repo_root/scripts/render-formula.sh" 1.2.3 invalid "$x86_64_sha256" "$test_output" 2>/dev/null; then
    echo "Formula renderer accepted an invalid checksum" >&2
    exit 1
fi

echo "Formula template test passed"
