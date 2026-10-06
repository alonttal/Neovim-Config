#!/usr/bin/env bash
set -euo pipefail

# Run after closing all Neovim instances. Only Neovim's four directories
# from this machine's stdpath() are removed; system runtimes stay installed.
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test -f "$repo_dir/init.lua"

rm -rf -- \
    /home/alontalmor/.config/nvim \
    /home/alontalmor/.local/share/nvim \
    /home/alontalmor/.cache/nvim \
    /home/alontalmor/.local/state/nvim

mkdir -p -- /home/alontalmor/.config/nvim
cp -- "$repo_dir/init.lua" /home/alontalmor/.config/nvim/init.lua
printf '%s\n' 'Fresh Neovim configuration installed.'
