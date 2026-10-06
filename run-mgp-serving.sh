#!/usr/bin/env bash
set -euo pipefail
# Compatibility shim for old settings; all server behavior is in run-catalina.sh.
runner_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export NVIM_PROJECT_ROOT="${NVIM_PROJECT_ROOT:-${MGP_PROJECT_ROOT:-$PWD}}"
export NVIM_SERVER_HOME="${NVIM_SERVER_HOME:-${MGP_TOMEE_HOME:?Set your server installation path}}"
export NVIM_WAR_FILE="${NVIM_WAR_FILE:-target/ROOT.war}"
export NVIM_CONTEXT_PATH="${NVIM_CONTEXT_PATH:-/}"
export NVIM_HTTP_PORT="${NVIM_HTTP_PORT:-${MGP_HTTP_PORT:-8081}}"
export NVIM_DEBUG_PORT="${NVIM_DEBUG_PORT:-${MGP_DEBUG_PORT:-5005}}"
if [ -n "${MGP_TOMEE_BASE:-}" ] && [ -z "${NVIM_SERVER_BASE:-}" ]; then
    export NVIM_SERVER_BASE="$MGP_TOMEE_BASE"
fi
exec bash "$runner_dir/run-catalina.sh" "$@"
