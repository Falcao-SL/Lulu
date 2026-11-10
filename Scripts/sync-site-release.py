#!/usr/bin/env python3
"""Write the Lulu product page release.json from the GitHub Releases API."""

import json
import os
import sys
import urllib.request

API = "https://api.github.com/repos/Falcao-SL/Lulu/releases"


def fetch(tag):
    url = f"{API}/tags/{tag}" if tag else f"{API}/latest"
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "lulu-site-release",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def pick(assets, stable, suffix):
    by_name = {asset["name"]: asset["browser_download_url"] for asset in assets}
    url = by_name.get(stable)
    if url is None:
        matches = [link for name, link in by_name.items() if name.endswith(suffix)]
        if len(matches) != 1:
            raise SystemExit(f"expected one {suffix} asset, found {len(matches)}")
        url = matches[0]
    prefix = "https://github.com/Falcao-SL/Lulu/releases/download/"
    if not url.startswith(prefix):
        raise SystemExit(f"refusing unexpected download URL: {url}")
    return url


def document(release):
    assets = release.get("assets") or []
    return {
        "tag": release["tag_name"],
        "arm64": pick(assets, "Lulu-macos-arm64.dmg", "-macos-arm64.dmg"),
        "intel": pick(assets, "Lulu-macos-x86_64.dmg", "-macos-x86_64.dmg"),
        "page": release["html_url"],
    }


def main():
    tag = None
    output = None
    args = sys.argv[1:]
    index = 0
    while index < len(args):
        if args[index] == "--tag":
            tag = args[index + 1]
            index += 2
        elif args[index] == "--output":
            output = args[index + 1]
            index += 2
        else:
            raise SystemExit(f"unknown argument: {args[index]}")
    text = json.dumps(document(fetch(tag)), indent=2) + "\n"
    if output:
        with open(output, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
