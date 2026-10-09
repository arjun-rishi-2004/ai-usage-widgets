#!/usr/bin/env bash
set -euo pipefail
for phrase in "ChatGPT only" "Claude only" "Both trackers" "Experimental" "No prompts or conversations" "Uninstall"; do grep -q "$phrase" README.md || exit 1; done
echo PASS
