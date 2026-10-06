#!/usr/bin/env bash
# Install from any working directory; system packages stay under your control.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install_java=false
install_debug=false
for argument in "$@"; do
    case "$argument" in
        --java) install_java=true ;;
        --debug) install_java=true; install_debug=true ;;
        -h|--help)
            printf '%s\n' 'Usage: bash install.sh [--java] [--debug]' \
                'Default: install init.lua, backing up the existing config directory.' \
                '--java: also install JDT LS and Lombok.' \
                '--debug: also install Java support and nvim-dap / Java debug adapter.' \
                'Requires Neovim 0.11+. Java tools require Java 21+, Python 3.9+, curl and tar.'
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 1 ;;
    esac
done
command -v nvim >/dev/null || { echo 'Install Neovim 0.11+ first.' >&2; exit 1; }
nvim --headless -u NONE -i NONE '+lua if vim.fn.has("nvim-0.11") == 0 then vim.cmd("cquit 1") end' '+qa' \
    || { echo 'Neovim 0.11+ is required.' >&2; exit 1; }
if [[ "$install_java" == true ]]; then
    for tool in java python3 curl tar; do
        command -v "$tool" >/dev/null || { printf 'Install %s first.\n' "$tool" >&2; exit 1; }
    done
    python3 -c 'import sys; assert sys.version_info >= (3, 9), "Python 3.9+ is required"'
    java_version=$(java -version 2>&1)
    if [[ "$java_version" =~ version\ \"([0-9]+) ]] && (( ${BASH_REMATCH[1]} >= 21 )); then
        :
    else
        echo 'Set java on PATH to Java 21+ before installing Java support.' >&2
        exit 1
    fi
fi
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
# Do not move the clone itself if someone cloned into their config directory.
if [[ -d "$config_dir" && "$(cd -- "$config_dir" && pwd -P)" == "$(cd -- "$source_root" && pwd -P)" ]]; then
    echo "The clone is already the active configuration: $config_dir"
else
    mkdir -p -- "$(dirname -- "$config_dir")"
    if [[ -e "$config_dir" || -L "$config_dir" ]]; then
        backup_dir="${config_dir}.backup-$(date +%Y%m%d-%H%M%S)-$$"
        mv -- "$config_dir" "$backup_dir"
        printf 'Previous configuration backed up to: %s\n' "$backup_dir"
    fi
    mkdir -p -- "$config_dir"
    cp -- "$source_root/init.lua" "$config_dir/init.lua"
    printf 'Installed configuration: %s/init.lua\n' "$config_dir"
fi
if [[ "$install_java" == true ]]; then
    if [[ ! -x "$data_dir/jdtls/bin/jdtls" ]]; then
        bash "$source_root/install-jdtls.sh"
    fi
    if [[ ! -f "$data_dir/jdtls/lombok.jar" ]]; then
        bash "$source_root/install-lombok.sh"
    fi
fi
if [[ "$install_debug" == true ]]; then
    if [[ ! -e "$data_dir/pack/ide/opt/nvim-dap" && ! -e "$data_dir/java-debug" ]]; then
        bash "$source_root/install-debug.sh"
    elif [[ ! -f "$data_dir/pack/ide/opt/nvim-dap/lua/dap.lua" || ! -d "$data_dir/java-debug" ]]; then
        echo 'Debug installation is incomplete; inspect the existing debug directories before retrying.' >&2
        exit 1
    fi
fi
printf '%s\n' 'Installation complete. Restart Neovim.' \
    'Project settings and application servers are configured separately with :ProjectSettings.'
for tool in rg svn mvn; do
    command -v "$tool" >/dev/null || printf 'Optional tool missing: %s (search / SVN / Maven workflows).\n' "$tool"
done
