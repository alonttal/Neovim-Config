#!/usr/bin/env bash
set -euo pipefail

# Only the protocol client is a Neovim plugin. Java's debug adapter extends JDT LS.
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
plugin_dir="$data_dir/pack/ide/opt/nvim-dap"
adapter_dir="$data_dir/java-debug"
if [ -e "$plugin_dir" ] || [ -e "$adapter_dir" ]; then
    printf '%s\n' 'Debug files already exist; left unchanged.' >&2
    exit 1
fi
stage_dir="$(mktemp -d)"
trap 'rm -rf -- "$stage_dir"' EXIT
curl --fail --location --show-error \
    https://github.com/mfussenegger/nvim-dap/archive/refs/tags/0.10.0.tar.gz \
    --output "$stage_dir/dap.tar.gz"
curl --fail --location --show-error \
    https://open-vsx.org/api/vscjava/vscode-java-debug/0.59.0/file/vscjava.vscode-java-debug-0.59.0.vsix \
    --output "$stage_dir/debug.vsix"
mkdir -p "$stage_dir/dap" "$stage_dir/adapter"
tar -xzf "$stage_dir/dap.tar.gz" --strip-components=1 -C "$stage_dir/dap"
test -f "$stage_dir/dap/lua/dap.lua"
# VSIX is a ZIP archive. Extract just server JARs, not the VS Code UI.
python3 - "$stage_dir/debug.vsix" "$stage_dir/adapter" <<'PY'
from pathlib import Path
import sys
import zipfile

target = Path(sys.argv[2])
with zipfile.ZipFile(sys.argv[1]) as archive:
    names = [n for n in archive.namelist()
             if n.startswith('extension/server/') and n.endswith('.jar')]
    if not any(Path(n).name.startswith('com.microsoft.java.debug.plugin-') for n in names):
        raise SystemExit('Java debug extension contains no adapter bundle')
    for name in names:
        (target / Path(name).name).write_bytes(archive.read(name))
PY
mkdir -p "$(dirname "$plugin_dir")" "$data_dir"
mv "$stage_dir/dap" "$plugin_dir"
mv "$stage_dir/adapter" "$adapter_dir"
printf '%s\n' 'Installed nvim-dap 0.10.0 and Java debug extension 0.59.0. Restart Neovim.'
