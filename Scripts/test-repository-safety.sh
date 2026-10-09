#!/usr/bin/env bash
set -euo pipefail

blocked='(\.app/|\.dSYM/|status\.json$|pace-history\.json$|\.plist$|\.icns$|\.DS_Store$)'
if git ls-files | grep -E "$blocked"; then
  echo "tracked generated or local data found" >&2
  exit 1
fi
