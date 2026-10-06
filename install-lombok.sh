#!/usr/bin/env bash
set -euo pipefail

# Editor-side Java agent; project Maven dependencies remain managed by pom.xml.
# Pin the current release instead of silently changing it on each installation.
# Source: https://projectlombok.org/download and /changelog
lombok_version='1.18.48'
target_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/jdtls"
if [ ! -x "$target_dir/bin/jdtls" ]; then
    printf '%s\n' 'Install JDT LS with bash ./install-jdtls.sh first.' >&2
    exit 1
fi

# Download beside the destination so the validated file can be renamed into
# place. A failed download does not replace an existing working agent.
download_file="$(mktemp "$target_dir/.lombok-download.XXXXXX")"
trap 'rm -- "$download_file" 2>/dev/null || true' EXIT
curl --fail --location --show-error \
    "https://projectlombok.org/downloads/lombok-$lombok_version.jar" \
    --output "$download_file"

# Reject HTML/error pages and incomplete archives before installing.
python3 - "$download_file" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as jar:
    if jar.testzip() is not None:
        raise SystemExit('Lombok archive is corrupt')
    manifest = jar.read('META-INF/MANIFEST.MF').decode('utf-8')
    if 'Premain-Class: lombok.launch.Agent' not in manifest:
        raise SystemExit('Downloaded file is not a Lombok Java agent')
PY
chmod 644 "$download_file"
mv -- "$download_file" "$target_dir/lombok.jar"
printf '%s\n' "Installed Lombok $lombok_version for JDT LS. Restart Neovim."
