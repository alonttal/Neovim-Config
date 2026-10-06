#!/usr/bin/env bash
set -euo pipefail

# Install a specific Eclipse snapshot outside the config directory.
# Source: https://download.eclipse.org/jdtls/snapshots/latest.txt
# Java 21+ and Python 3.9+ are needed by the upstream launcher.
archive_name='jdt-language-server-1.62.0-202609282153.tar.gz'
target_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/jdtls"
if [ -e "$target_dir" ]; then
    printf '%s\n' "Already exists: $target_dir (left unchanged)."
    exit 1
fi
stage_dir="$(mktemp -d)"
trap 'rm -rf -- "$stage_dir"' EXIT
curl --fail --location --show-error \
    "https://download.eclipse.org/jdtls/snapshots/$archive_name" \
    --output "$stage_dir/jdtls.tar.gz"
mkdir -p -- "$stage_dir/server"
tar -xzf "$stage_dir/jdtls.tar.gz" -C "$stage_dir/server"
test -x "$stage_dir/server/bin/jdtls"
mkdir -p -- "$(dirname -- "$target_dir")"
mv -- "$stage_dir/server" "$target_dir"
printf '%s\n' "Installed JDT LS to $target_dir"
