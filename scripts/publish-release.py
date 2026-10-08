#!/usr/bin/env python3
"""Publish the v0.1.0 GitHub release: draft first, upload verified assets,
then flip the draft to a published prerelease.

Standard library only (no gh CLI, no third-party modules). Designed for the
tag-triggered publish job in .github/workflows/release.yml. Hard-fails, and
removes any draft it created, when a v0.1.0 release already exists, the tag
does not resolve to the checked-out commit, the release notes file is absent,
or any required asset is missing after upload. It never overwrites an
existing release or asset.

Required environment:
  GITHUB_TOKEN        token with contents:write on this repository only
  GITHUB_REPOSITORY   must be anon5376/muse-code-desktop
  GITHUB_REF_NAME     must be v0.1.0
  GITHUB_SHA          commit the workflow checked out (the tagged commit)

Assets uploaded when present in the checkout:
  build/dist/Muse-Code-Desktop-0.1.0-arm64.dmg        (required)
  build/dist/Muse-Code-Desktop-0.1.0-arm64.dmg.sha256 (required)
  docs/media/muse-code-demo.mp4                       (optional, committed by the docs/media task)
Release notes body: docs/releases/v0.1.0.md           (required; authored with real test results)
"""

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

EXPECTED_REPO = "anon5376/muse-code-desktop"
EXPECTED_TAG = "v0.1.0"
TIMEOUT = 120

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NOTES_PATH = os.path.join(ROOT, "docs", "releases", "v0.1.0.md")
ASSETS = [
    (os.path.join(ROOT, "build", "dist", "Muse-Code-Desktop-0.1.0-arm64.dmg"),
     "application/octet-stream", True),
    (os.path.join(ROOT, "build", "dist", "Muse-Code-Desktop-0.1.0-arm64.dmg.sha256"),
     "text/plain", True),
    (os.path.join(ROOT, "docs", "media", "muse-code-demo.mp4"),
     "video/mp4", False),
]


def fail(message):
    print(f"::error::{message}", flush=True)
    sys.exit(1)


def api(method, url, token, body=None, data=None, content_type=None, accept="application/vnd.github+json"):
    request = urllib.request.Request(url, method=method)
    request.add_header("Accept", accept)
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        data = json.dumps(body).encode("utf-8")
        content_type = "application/json"
    if data is not None:
        request.data = data
        if content_type:
            request.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            payload = response.read()
            return response.status, json.loads(payload) if payload else {}
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return 404, {}
        detail = error.read().decode("utf-8", "replace")[:500]
        fail(f"GitHub API {method} {url} failed: HTTP {error.code}: {detail}")
    except urllib.error.URLError as error:
        fail(f"GitHub API {method} {url} failed: {error.reason}")


def tag_commit(api_url, repo, tag, token):
    status, ref = api("GET", f"{api_url}/repos/{repo}/git/ref/tags/{urllib.parse.quote(tag)}", token)
    if status != 200:
        fail(f"Tag {tag} does not resolve on {repo} (HTTP {status}); refusing to publish")
    obj = ref.get("object", {})
    if obj.get("type") == "commit":
        return obj["sha"]
    if obj.get("type") == "tag":  # annotated tag: resolve to the tagged commit
        status, tag_obj = api("GET", obj["url"], token)
        if status == 200 and tag_obj.get("object", {}).get("type") == "commit":
            return tag_obj["object"]["sha"]
    fail(f"Tag {tag} did not resolve to a commit (object type {obj.get('type')})")


def main():
    token = os.environ.get("GITHUB_TOKEN") or fail("GITHUB_TOKEN is not set")
    repo = os.environ.get("GITHUB_REPOSITORY") or fail("GITHUB_REPOSITORY is not set")
    tag = os.environ.get("GITHUB_REF_NAME") or fail("GITHUB_REF_NAME is not set")
    sha = os.environ.get("GITHUB_SHA") or fail("GITHUB_SHA is not set")
    api_url = os.environ.get("GITHUB_API_URL", "https://api.github.com")

    if repo != EXPECTED_REPO:
        fail(f"Refusing to publish: repository is {repo}, expected {EXPECTED_REPO}")
    if tag != EXPECTED_TAG:
        fail(f"Refusing to publish: ref is {tag}, expected tag {EXPECTED_TAG}")

    resolved = tag_commit(api_url, repo, tag, token)
    if resolved != sha:
        fail(f"Tag {tag} resolves to {resolved}, but this run checked out {sha}; refusing to publish")
    print(f"Tag {tag} -> {resolved} verified against checkout")

    status, existing = api("GET", f"{api_url}/repos/{repo}/releases/tags/{urllib.parse.quote(tag)}", token)
    if status == 200:
        fail(f"A release for {tag} already exists ({existing.get('html_url', 'unknown')}); no overwrite")

    if not os.path.isfile(NOTES_PATH):
        fail(f"Release notes {os.path.relpath(NOTES_PATH, ROOT)} are required for publishing and are missing")
    with open(NOTES_PATH, encoding="utf-8") as handle:
        body = handle.read()
    if not body.strip():
        fail(f"Release notes {os.path.relpath(NOTES_PATH, ROOT)} are empty")

    uploads = []
    for path, content_type, required in ASSETS:
        if os.path.isfile(path):
            if os.path.getsize(path) == 0:
                fail(f"Asset {os.path.basename(path)} is empty")
            uploads.append((path, content_type))
        elif required:
            fail(f"Required asset {os.path.relpath(path, ROOT)} is missing; run scripts/package-dmg.sh first")
        else:
            print(f"Optional asset {os.path.relpath(path, ROOT)} not present; skipping")

    release_id = None
    try:
        status, release = api("POST", f"{api_url}/repos/{repo}/releases", token, body={
            "tag_name": tag,
            "target_commitish": sha,
            "name": tag,
            "body": body,
            "draft": True,
            "prerelease": True,
            "generate_release_notes": False,
        })
        if status != 201:
            fail(f"Draft release creation returned HTTP {status}")
        release_id = release["id"]
        upload_base = release["upload_url"].split("{")[0]
        print(f"Draft release {release_id} created")

        expected_names = set()
        for path, content_type in uploads:
            name = os.path.basename(path)
            expected_names.add(name)
            with open(path, "rb") as handle:
                data = handle.read()
            status, asset = api("POST", f"{upload_base}?name={urllib.parse.quote(name)}&label={urllib.parse.quote(name)}",
                                token, data=data, content_type=content_type)
            if status != 201:
                fail(f"Asset upload {name} returned HTTP {status}")
            print(f"Uploaded {name} ({asset.get('size', 0)} bytes)")

        status, listing = api("GET", f"{api_url}/repos/{repo}/releases/{release_id}/assets", token)
        present = {asset["name"] for asset in listing} if status == 200 else set()
        missing = expected_names - present
        if missing:
            fail(f"Release assets incomplete after upload; missing: {sorted(missing)}")

        status, _ = api("PATCH", f"{api_url}/repos/{repo}/releases/{release_id}", token,
                        body={"draft": False, "prerelease": True})
        if status != 200:
            fail(f"Publishing the draft returned HTTP {status}")
        print(f"Published prerelease {tag} with {len(expected_names)} assets")
    except SystemExit:
        if release_id is not None:
            print(f"Removing incomplete draft release {release_id}", flush=True)
            api("DELETE", f"{api_url}/repos/{repo}/releases/{release_id}", token)
        raise


if __name__ == "__main__":
    main()
