#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: build-release.sh <arm64|x86_64> <output-path>" >&2
    exit 2
fi

architecture=$1
output=$2
case "$architecture" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported architecture: $architecture" >&2
        exit 2
        ;;
esac

if [[ "$(uname -m)" != "$architecture" ]]; then
    echo "Expected a native $architecture runner; found $(uname -m)" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
if [[ "$output" != /* ]]; then
    output="$repo_root/$output"
fi
mkdir -p "$(dirname "$output")"
swiftc -O -swift-version 5 -target "${architecture}-apple-macosx15.0" main.swift -o "$output"
