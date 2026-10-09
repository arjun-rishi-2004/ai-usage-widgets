# AI Usage Widgets

Native macOS menu-bar trackers for ChatGPT/Codex and Claude Code usage.

## Install

ChatGPT only: `Scripts/install.sh chatgpt`

Claude only: `Scripts/install.sh claude`

Both trackers: `Scripts/install.sh both`

Claude Usage is **Experimental** because it depends on an undocumented Claude
usage endpoint. The trackers keep local percentage/reset snapshots only. **No
prompts or conversations** are read or stored.

Each app shows the current-session percentage, refreshes regularly, and saves
non-sensitive snapshots so pacing guidance can recommend the other service only
when both trackers have fresh data. It retains a 15% session reserve and 10%
weekly reserve.

## Uninstall

`Scripts/uninstall.sh chatgpt`, `Scripts/uninstall.sh claude`, or
`Scripts/uninstall.sh both`. Add `--purge-data` to remove local snapshots.
