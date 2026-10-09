#!/usr/bin/env bash
set -euo pipefail
! Scripts/build.sh invalid >/dev/null 2>&1
! Scripts/install.sh invalid >/dev/null 2>&1
Scripts/build.sh chatgpt --dry-run | grep -q 'ChatGPT Usage.app'
! Scripts/build.sh chatgpt --dry-run | grep -q 'Claude Usage.app'
! Scripts/uninstall.sh chatgpt x --dry-run | grep -q '/Applications/ChatGPT.app'
echo PASS
