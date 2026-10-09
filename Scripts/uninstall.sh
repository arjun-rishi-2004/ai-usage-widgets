#!/usr/bin/env bash
set -euo pipefail
target=${1:-}; purge=${2:-}; [[ "$target" =~ ^(chatgpt|claude|both)$ ]] || { echo "usage: $0 <chatgpt|claude|both> [--purge-data]" >&2; exit 2; }
dry=${3:-}; remove() { [[ "$dry" == --dry-run ]] && echo "$1" || rm -rf "$1"; }
[[ "$target" == chatgpt || "$target" == both ]] && remove "$HOME/Applications/ChatGPT Usage.app"
[[ "$target" == claude || "$target" == both ]] && remove "$HOME/Applications/Claude Usage.app"
[[ "$purge" == --purge-data ]] && remove "$HOME/Library/Application Support/AI Usage Widgets"
