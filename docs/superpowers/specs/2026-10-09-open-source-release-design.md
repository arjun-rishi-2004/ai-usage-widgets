# AI Usage Widgets: Open-source release design

## Purpose

Publish two independent native macOS menu-bar and desktop usage trackers:

- **ChatGPT Usage** tracks Codex limits available through the installed ChatGPT app.
- **Claude Usage** tracks Claude Code subscription limits.

A person can build and install either tracker alone or install both. When both run, their local snapshots allow each tracker to recommend switching services when the other has more available allowance.

## Repository scope

The repository contains source code, source assets, tests, documentation, and local build/install scripts only. It contains no compiled apps, account snapshots, Keychain data, credentials, user names, email addresses, or launch-agent files generated on a user’s Mac.

The project is source-only for its first public release. Releases and GitHub publishing remain separate user-authorized steps.

## Layout

```text
ai-usage-widgets/
  ChatGPTUsage/
  ClaudeUsage/
  Shared/
  Scripts/
  Tests/
  docs/
  README.md
  SECURITY.md
  CONTRIBUTING.md
  LICENSE
  .gitignore
```

`Shared` owns the data model, rolling pacing calculation, and tests. Each tracker owns its account adapter and visual theme. `Scripts` provides explicit commands for building/installing ChatGPT, Claude, or both; startup registration is opt-in.

## Data flow and privacy

ChatGPT Usage starts the bundled Codex app server from the installed ChatGPT app and asks it for rate-limit data. Claude Usage reads the existing Claude Code credential from the macOS Keychain into memory and calls Claude’s usage endpoint. It must never log, serialize, or transmit the credential anywhere except that request.

Both trackers persist only local snapshots containing timestamps, used percentages, window lengths, and reset times under `~/Library/Application Support`. The other tracker can read this non-sensitive snapshot when both are installed. Neither tracker reads prompts, responses, chats, source files, or browser history.

Claude support is marked **experimental** because its usage endpoint is not a documented public API and may change. ChatGPT support checks current bundled CLI locations and reports an actionable error if ChatGPT updates its layout.

## User experience

Each app shows a logo, current-session and weekly meters, reset times, a compact pacing recommendation, and a refresh action. The menu-bar entry shows logo plus current-session percentage. Add Widget and Remove Widget control the floating desktop card. Notification settings allow usage-change, threshold, reset, and pre-reset reminders.

The pacing guidance reserves 15% of the current window and 10% of the weekly allowance. It computes a daily weekly target and, after ten minutes of history, a recent consumption estimate. Switching advice requires fresh snapshots from both locally running trackers.

## Install and lifecycle

The installer accepts exactly one target: `chatgpt`, `claude`, or `both`. It compiles the selected tracker(s), installs them to `~/Applications`, and can optionally add a per-user launch agent. The uninstaller removes only files bearing the project’s explicit app and launch-agent identifiers, leaving stored snapshots unless the user selects the data-removal option.

## Validation

Automated tests cover pacing and snapshot behavior. Build checks compile both targets separately. A manual smoke test confirms each tracker starts, reads an authenticated account, shows usage, and can add/remove the desktop card. Documentation states expected macOS, ChatGPT, and Claude Code prerequisites and known limitations.

## License and contribution policy

The initial release uses the MIT License. Contributions must avoid adding credential logging, telemetry, or background networking beyond the account usage request described above. Security reports use the repository’s private reporting guidance rather than public issue disclosure.
