#!/usr/bin/env bash
set -euo pipefail
target=${1:-}; login=${2:-}; [[ "$target" =~ ^(chatgpt|claude|both)$ ]] || { echo "usage: $0 <chatgpt|claude|both> [--login-item]" >&2; exit 2; }; [[ -z "$login" || "$login" == --login-item ]] || exit 2
"$(dirname "$0")/build.sh" "$target"; mkdir -p "$HOME/Applications"
[[ "$target" == chatgpt || "$target" == both ]] && cp -R 'dist/ChatGPT Usage.app' "$HOME/Applications/"
[[ "$target" == claude || "$target" == both ]] && cp -R 'dist/Claude Usage.app' "$HOME/Applications/"
echo "Installed $target"
