#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: render-formula.sh <version> <arm64-sha256> <x86_64-sha256> <output-path>" >&2
    exit 2
fi

version=$1
arm64_sha256=$2
x86_64_sha256=$3
output=$4

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid release version: $version" >&2
    exit 2
fi
if [[ ! "$arm64_sha256" =~ ^[[:xdigit:]]{64}$ || ! "$x86_64_sha256" =~ ^[[:xdigit:]]{64}$ ]]; then
    echo "SHA-256 values must contain exactly 64 hexadecimal characters" >&2
    exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
template="$repo_root/templates/macnotif.rb.in"
if [[ "$output" != /* ]]; then
    output="$repo_root/$output"
fi
mkdir -p "$(dirname "$output")"
sed \
    -e "s/@VERSION@/$version/g" \
    -e "s/@ARM64_SHA256@/$arm64_sha256/g" \
    -e "s/@X86_64_SHA256@/$x86_64_sha256/g" \
    "$template" > "$output"
