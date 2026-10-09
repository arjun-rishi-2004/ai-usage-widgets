#!/usr/bin/env bash
set -euo pipefail
target=${1:-}; [[ "$target" =~ ^(chatgpt|claude|both)$ ]] || { echo "usage: $0 <chatgpt|claude|both> [--dry-run]" >&2; exit 2; }
dry=${2:-}; root=$(cd "$(dirname "$0")/.." && pwd); cd "$root"
build() { local name=$1 source=$2; if [[ "$dry" == --dry-run ]]; then echo "dist/$name.app"; return; fi; rm -rf "dist/$name.app"; mkdir -p "dist/$name.app/Contents/MacOS"; swiftc -parse-as-library Shared/UsageModels.swift Shared/Pacing.swift "$source/main.swift" -o "dist/$name.app/Contents/MacOS/$name"; cp "$source/Info.plist" "dist/$name.app/Contents/Info.plist"; }
[[ "$target" == chatgpt || "$target" == both ]] && build 'ChatGPT Usage' ChatGPTUsage
[[ "$target" == claude || "$target" == both ]] && build 'Claude Usage' ClaudeUsage
true
