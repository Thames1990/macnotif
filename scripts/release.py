#!/usr/bin/env python3
"""Prepare immutable release sources and publish their curated notes."""

import argparse
import datetime
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


TAP = "Thames1990/homebrew-tap"
VERSION = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"


def command(*args, env=None, strip_output=True):
    output = subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE, env=env).stdout
    return output.strip() if strip_output else output


def git(*args, **kwargs):
    return command("git", *args, **kwargs)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def changelog_at(source):
    return subprocess.run(
        ["git", "show", f"{source}:CHANGELOG.md"], check=True,
        stdout=subprocess.PIPE,
    ).stdout.decode("utf-8")


def sections(text):
    result = []
    offset = 0
    fence = None
    for line in text.splitlines(keepends=True):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if marker:
            value = marker[1]
            if fence is None:
                fence = value
            elif value[0] == fence[0] and len(value) >= len(fence):
                fence = None
        if fence is None and line.startswith("## "):
            result.append((line[3:].strip(), offset, offset + len(line)))
        offset += len(line)
    return [
        (title, start, body, result[i + 1][1] if i + 1 < len(result) else len(text))
        for i, (title, start, body) in enumerate(result)
    ]


def meaningful(notes):
    text = re.sub(r"<!--.*?-->", "", notes, flags=re.S)
    text = re.sub(r"^#{1,6}\s.*$", "", text, flags=re.M)
    return bool(re.search(r"[^\W_]", text))


def version_notes(text, tag):
    matches = [s for s in sections(text) if s[0].startswith(f"{tag[1:]} - ")]
    require(len(matches) == 1, f"Expected exactly one finalized section for {tag}.")
    title, _, body, end = matches[0]
    date = title.removeprefix(f"{tag[1:]} - ")
    require(bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", date)), "Invalid release date.")
    datetime.date.fromisoformat(date)
    notes = text[body:end].strip("\r\n") + "\n"
    require(meaningful(notes), f"Missing or empty notes for {tag}.")
    return notes


def finalize(text, tag):
    unreleased = [s for s in sections(text) if s[0] == "Unreleased"]
    require(len(unreleased) == 1, "Expected exactly one Unreleased section.")
    if any(s[0].startswith(f"{tag[1:]} - ") for s in sections(text)):
        version_notes(text, tag)
        return text
    _, _, body, end = unreleased[0]
    notes = text[body:end].strip("\r\n")
    require(meaningful(notes), "Missing or empty Unreleased notes; explicitly record No user-facing changes if intended.")
    date = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
    return text[:body] + f"\n## {tag[1:]} - {date}\n\n{notes}\n\n" + text[end:]


def validate_identity(tag, source):
    require(bool(re.fullmatch("v" + VERSION, tag)), "Invalid release tag.")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", source)), "Invalid source commit.")
    require(git("rev-parse", f"{tag}^{{commit}}") == source,
            "Release tag does not match the prepared source commit.")
    return version_notes(changelog_at(source), tag)


def write_identity(args, tag, source):
    with Path(args.output).open("a") as output:
        output.write(f"tag_name={tag}\nsource_commit={source}\n")


def prepare(args):
    require(args.event == "workflow_dispatch" and args.ref == "refs/heads/main",
            "Run manual releases from main.")
    require(args.bump in ("patch", "minor", "major"), "Version increment must be patch, minor, or major.")
    require(bool(re.fullmatch(r"[0-9a-f]{40}", args.source)), "Invalid source commit.")
    require(bool(re.fullmatch(r"[1-9][0-9]*", args.run_id)), "Invalid workflow run identity.")
    require(bool(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repository)), "Invalid repository.")
    git("fetch", "--no-tags", "origin", "refs/heads/main:refs/remotes/origin/main")
    remote_tags = git("ls-remote", "--tags", "--refs", "origin")
    git("fetch", "--no-tags", "origin", "refs/tags/*:refs/tags/*")
    marker = f"MacNotif release {args.repository} run {args.run_id}"
    message = f"{marker}\nDispatch source: {args.source}\nIncrement: {args.bump}"
    retries = []
    for line in remote_tags.splitlines():
        ref = line.split()[1]
        if git("cat-file", "-t", ref) != "tag":
            continue
        annotation = git("cat-file", "-p", ref).partition("\n\n")[2]
        if annotation.splitlines()[:1] == [marker]:
            require(annotation == message, "Retry dispatch identity conflicts with the original release.")
            retries.append(ref.removeprefix("refs/tags/"))
    require(len(retries) <= 1, "Multiple tags claim this release run.")
    if retries:
        tag = retries[0]
        source = git("rev-parse", f"{tag}^{{commit}}")
        validate_identity(tag, source)
        if source != args.source:
            require(git("rev-list", "--parents", "-n", "1", source).split() == [source, args.source],
                    "Retry tag has an unexpected source parent.")
            require(git("diff-tree", "--no-commit-id", "--name-only", "-r", source) == "CHANGELOG.md",
                    "Retry source changes more than CHANGELOG.md.")
        git("merge-base", "--is-ancestor", source, "origin/main")
        write_identity(args, tag, source)
        return
    require(git("rev-parse", "origin/main") == args.source,
            "Concurrent main movement: dispatch source no longer matches main.")
    require(git("rev-parse", "HEAD") == args.source, "Checkout does not match dispatch source.")
    try:
        latest = command("gh", "api", f"repos/{TAP}/releases/latest", "--jq", ".tag_name")
    except subprocess.CalledProcessError as error:
        raise ValueError("Cannot read the latest published tap release; refusing to allocate a version.") from error
    require(bool(re.fullmatch("v" + VERSION, latest)), f"Latest published release has an invalid version: {latest}")
    major, minor, patch = map(int, latest[1:].split("."))
    if args.bump == "major":
        major, minor, patch = major + 1, 0, 0
    elif args.bump == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    tag = f"v{major}.{minor}.{patch}"
    require(not git("ls-remote", "origin", f"refs/tags/{tag}"), f"Conflicting tag {tag}; refusing to move it.")
    require(not git("tag", "--list", tag), f"Conflicting local tag {tag}; refusing to move it.")
    original = changelog_at(args.source)
    require(Path("CHANGELOG.md").read_bytes() == original.encode()
            and not git("diff", "--cached", args.source, "--", "CHANGELOG.md"),
            "CHANGELOG.md has local edits.")
    updated = finalize(original, tag)
    source = args.source
    if updated != original:
        with tempfile.TemporaryDirectory() as directory:
            index_env = {**os.environ, "GIT_INDEX_FILE": str(Path(directory) / "index")}
            git("read-tree", args.source, env=index_env)
            blob = subprocess.run(
                ["git", "hash-object", "-w", "--stdin"], input=updated, text=True,
                stdout=subprocess.PIPE, check=True,
            ).stdout.strip()
            git("update-index", "--add", "--cacheinfo", f"100644,{blob},CHANGELOG.md", env=index_env)
            tree = git("write-tree", env=index_env)
            bot_env = {
                **os.environ,
                "GIT_AUTHOR_NAME": "github-actions[bot]",
                "GIT_AUTHOR_EMAIL": "41898282+github-actions[bot]@users.noreply.github.com",
                "GIT_COMMITTER_NAME": "github-actions[bot]",
                "GIT_COMMITTER_EMAIL": "41898282+github-actions[bot]@users.noreply.github.com",
            }
            source = git("commit-tree", tree, "-p", args.source, "-m", f"Release {tag}", env=bot_env)
    git("-c", "user.name=github-actions[bot]",
        "-c", "user.email=41898282+github-actions[bot]@users.noreply.github.com",
        "tag", "-a", tag, source, "-m",
        message)
    try:
        git("push", "--atomic", "origin", f"{source}:refs/heads/main", f"refs/tags/{tag}:refs/tags/{tag}")
    except subprocess.CalledProcessError as error:
        raise ValueError("Source write rejected (branch protection, concurrent main movement, or tag conflict); no force push attempted.") from error
    if source != args.source:
        git("update-ref", "HEAD", source, args.source)
        Path("CHANGELOG.md").write_bytes(updated.encode())
        git("update-index", "--cacheinfo", f"100644,{blob},CHANGELOG.md")
    write_identity(args, tag, source)


def checksums(directory, names):
    return {name: hashlib.sha256((directory / name).read_bytes()).hexdigest() for name in names}


def publish(args):
    notes = validate_identity(args.tag, args.source)
    require(git("rev-parse", "HEAD") == args.source, "Publication checkout does not match the prepared source.")
    version = args.tag[1:]
    names = [f"macnotif-{version}-{arch}.tar.gz" for arch in ("arm64", "x86_64")]
    dist = Path(args.dist)
    require(all((dist / name).is_file() for name in names), "Missing architecture archives.")
    # A failed lookup is not evidence that a release is absent.
    tags = command("gh", "api", f"repos/{TAP}/releases", "--paginate", "--jq", ".[].tag_name").splitlines()
    with tempfile.TemporaryDirectory() as directory:
        existing = Path(directory)
        notes_file = existing / "notes.md"
        notes_file.write_text(notes, encoding="utf-8")
        if args.tag in tags:
            body = command("gh", "release", "view", args.tag, "--repo", TAP, "--json", "body", "--jq", ".body",
                           strip_output=False)
            require(body.rstrip("\r\n") == notes.rstrip("\r\n"),
                    "Published notes conflict with the prepared source; refusing to replace them.")
            command("gh", "release", "download", args.tag, "--repo", TAP,
                    "--pattern", names[0], "--pattern", names[1],
                    "--pattern", "SHA256SUMS", "--pattern", "SOURCE_COMMIT", "--dir", directory)
            require((existing / "SOURCE_COMMIT").read_text().strip() == args.source,
                    "Release belongs to a different source commit; refusing to replace it.")
            manifest = (existing / "SHA256SUMS").read_text().splitlines()
            require(len(manifest) == 2, "Published release has an invalid checksum manifest.")
            expected = checksums(existing, names)
            require(set(manifest) == {f"{sha}  {name}" for name, sha in expected.items()},
                    "Published archive checksum or manifest conflict; refusing to replace assets.")
            for name in [*names, "SHA256SUMS", "SOURCE_COMMIT"]:
                shutil.copyfile(existing / name, dist / name)
        else:
            expected = checksums(dist, names)
            (dist / "SHA256SUMS").write_text("".join(f"{sha}  {name}\n" for name, sha in expected.items()))
            (dist / "SOURCE_COMMIT").write_text(args.source + "\n")
            command("gh", "release", "create", args.tag,
                    *(str(dist / name) for name in [*names, "SHA256SUMS", "SOURCE_COMMIT"]),
                    "--repo", TAP, "--title", f"MacNotif {version}", "--notes-file", str(notes_file))
    with Path(args.output).open("a") as output:
        for arch, name in zip(("arm64", "x86_64"), names):
            output.write(f"{arch}_sha256={expected[name]}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="operation", required=True)
    preparation = subparsers.add_parser("prepare")
    for name in ("event", "ref", "bump", "source", "run-id", "repository", "output"):
        preparation.add_argument(f"--{name}", required=True)
    notes = subparsers.add_parser("notes")
    for name in ("tag", "source", "output"):
        notes.add_argument(f"--{name}", required=True)
    publication = subparsers.add_parser("publish")
    for name in ("tag", "source", "dist", "output"):
        publication.add_argument(f"--{name}", required=True)
    args = parser.parse_args()
    try:
        if args.operation == "prepare":
            prepare(args)
        elif args.operation == "publish":
            publish(args)
        else:
            Path(args.output).write_text(validate_identity(args.tag, args.source), encoding="utf-8")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Release failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
