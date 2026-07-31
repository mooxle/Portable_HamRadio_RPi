#!/bin/bash
# Checks for and installs the latest official WSJT-X + GridTracker2 builds.
# Both are installed as regular dpkg packages, but neither comes from an
# apt repository, so plain "apt upgrade" never touches them -- this script
# is the manual replacement for that. Run by hand whenever you want to
# check (no cron/timer -- package installs deserve a look at the output).

set -uo pipefail

WSJTX_ARCH_SUFFIX="linux-aarch64.deb"   # adjust for e.g. linux-x86_64.deb
GT_ARCH="arm64"                         # adjust for e.g. amd64
TMP_DIR="/tmp/radio-app-updates"
mkdir -p "$TMP_DIR"

update_wsjtx() {
    echo "=== WSJT-X ==="
    local installed latest url api_json
    installed=$(dpkg-query -W -f='${Version}' wsjtx 2>/dev/null || echo "none")
    echo "Installed:       $installed"

    api_json=$(curl -sf https://api.github.com/repos/WSJTX/wsjtx/releases/latest) || {
        echo "Could not reach the GitHub API, skipping."
        return
    }

    latest=$(echo "$api_json" | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'].lstrip('v'))" 2>/dev/null)
    url=$(echo "$api_json" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for a in d.get('assets', []):
    if a['name'].endswith('$WSJTX_ARCH_SUFFIX'):
        print(a['browser_download_url'])
        break
" 2>/dev/null)

    echo "Latest (GitHub): ${latest:-unknown}"

    if [ -z "${latest:-}" ] || [ -z "${url:-}" ]; then
        echo "Could not determine the latest version/asset, skipping."
        return
    fi
    if [ "$installed" = "$latest" ]; then
        echo "Already up to date."
        return
    fi

    echo "Downloading $url ..."
    if wget -q "$url" -O "$TMP_DIR/wsjtx-latest.deb"; then
        echo "Installing..."
        sudo apt install -y "$TMP_DIR/wsjtx-latest.deb"
        echo "WSJT-X updated: $installed -> $latest"
    else
        echo "Download failed."
    fi
}

update_gridtracker2() {
    echo
    echo "=== GridTracker2 ==="
    local installed latest url
    installed=$(dpkg-query -W -f='${Version}' gridtracker2 2>/dev/null || echo "none")
    echo "Installed:       $installed"

    # No public release API for GridTracker2 (GitLab project, not tagged
    # via a clean releases feed at time of writing) -- best-effort scrape
    # of the official downloads page for the current ARM64 filename. Falls
    # back gracefully: GridTracker2 has its own built-in update checker
    # (confirmed: "checkForUpdates" in the binary), so this is a
    # convenience, not the only way it stays current.
    latest=$(curl -sf "https://gridtracker.org/index.php/downloads/gridtracker-downloads" \
        | grep -oE "GridTracker2-[0-9]+\.[0-9]+\.[0-9]+-${GT_ARCH}\.deb" | sort -u | head -1 \
        | sed -E "s/GridTracker2-(.*)-${GT_ARCH}\.deb/\1/")

    echo "Latest (site):   ${latest:-unknown}"

    if [ -z "${latest:-}" ]; then
        echo "Could not scrape the current version from the downloads page."
        echo "GridTracker2 has its own built-in updater -- launch it with"
        echo "internet access and watch for an update prompt instead."
        return
    fi
    if [[ "$installed" == "$latest"* ]]; then
        echo "Already up to date."
        return
    fi

    url="https://download2.gridtracker.org/GridTracker2-${latest}-${GT_ARCH}.deb"
    echo "Downloading $url ..."
    if wget -q "$url" -O "$TMP_DIR/gridtracker2-latest.deb"; then
        echo "Installing..."
        sudo apt install -y "$TMP_DIR/gridtracker2-latest.deb"
        echo "GridTracker2 updated: $installed -> $latest"
    else
        echo "Download failed -- GridTracker2's own built-in updater is the fallback."
    fi
}

update_wsjtx
update_gridtracker2

rm -rf "$TMP_DIR"
echo
echo "Done."
