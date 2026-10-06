#!/usr/bin/env bash
# Publish the prepared snapshot without replacing an existing remote history.
# This helper is needed when the editing session cannot access GitHub or .git.
set -euo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bundle="$source_root/Neovim-Config.bundle"
repo_url=${NVIM_PUBLISH_REMOTE:-git@github.com:alonttal/Neovim-Config.git}
if [[ ! -f "$bundle" ]]; then
    echo "Missing prepared snapshot: $bundle" >&2
    exit 1
fi
publish_dir=$(mktemp -d "${TMPDIR:-/tmp}/neovim-config-publish.XXXXXX")
checkout="$publish_dir/repo"
trap 'echo "Publishing stopped. Checkout retained at: $checkout" >&2' ERR
git clone "$repo_url" "$checkout"
git -C "$checkout" fetch "$bundle" main:refs/remotes/prepared/main
if git -C "$checkout" rev-parse --verify HEAD >/dev/null 2>&1; then
    branch=$(git -C "$checkout" branch --show-current)
    if [[ -z "$branch" ]]; then
        echo "Remote checkout has no active branch; inspect $checkout" >&2
        exit 1
    fi
    # Replace only files in our prepared snapshot; leave other remote files alone.
    # NUL-delimited paths support filenames containing whitespace.
    git -C "$checkout" ls-tree -r --name-only -z refs/remotes/prepared/main > "$publish_dir/paths"
    git -C "$checkout" restore --source=refs/remotes/prepared/main --staged --worktree \
        --pathspec-from-file="$publish_dir/paths" --pathspec-file-nul
    if ! git -C "$checkout" diff --cached --quiet; then
        git -C "$checkout" commit -m "Build native-first Neovim IDE with Java and SVN support"
    fi
else
    branch=main
    git -C "$checkout" switch -C "$branch" refs/remotes/prepared/main
fi
# No force push: concurrent remote changes are rejected rather than overwritten.
git -C "$checkout" push origin "HEAD:refs/heads/$branch"
echo "Published to $repo_url ($branch)."
echo "Normal Git checkout retained at: $checkout"
