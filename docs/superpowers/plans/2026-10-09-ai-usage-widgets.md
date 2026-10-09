# AI Usage Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish a source-only macOS repository containing independently installable ChatGPT Usage and Claude Usage trackers that can also share local usage snapshots for pacing advice.

**Architecture:** Split the existing local trackers into a shared Swift module for snapshots and pacing, plus one app target per provider. The repository includes shell build/install tools that select a single provider or both and no generated user data. ChatGPT retains its supported app-server adapter; Claude remains isolated as an experimental adapter with explicit credential-handling documentation.

**Tech Stack:** Swift 5.9+, Cocoa, SwiftUI, UserNotifications, macOS 13+, shell scripts, GitHub Markdown.

**Spec:** `docs/superpowers/specs/2026-10-09-open-source-release-design.md`

## Global Constraints

- Support macOS 13 and newer.
- Publish source only; never commit compiled `.app` bundles, snapshots, launch agents, credentials, or personal information.
- The installer accepts exactly `chatgpt`, `claude`, or `both`.
- Claude support is marked experimental and must not log or persist access tokens.
- Startup registration is opt-in, and uninstall removes only project-owned app and launch-agent identifiers.
- Both apps work separately; switch advice needs fresh local snapshots from both running apps.

## Review Focus

- Missing ChatGPT or Claude Code dependency: installation fails with a useful next action and no partial app install.
- A selected single-provider install: no other tracker is compiled, installed, launched, or registered.
- A stale or missing peer snapshot: pacing never recommends switching services.
- A Claude Keychain read failure or non-200 usage response: error state contains no credential material.
- An uninstall request: it never removes unrelated `~/Applications` apps, launch agents, or stored snapshots unless `--purge-data` is passed.

---

### Task 1: Create the clean repository shell and contributor safeguards

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`
- Create: `SECURITY.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`
- Test: `Scripts/test-repository-safety.sh`

**Interfaces:**
- Produces: a repository policy that later installer and source tasks follow.
- Produces: `Scripts/test-repository-safety.sh`, exit code 0 only when no prohibited artifact appears in the tracked tree.

- [ ] **Step 1: Write the failing repository-safety test**

```bash
#!/usr/bin/env bash
set -euo pipefail
blocked='(\.app/|\.dSYM/|status\.json$|pace-history\.json$|\.plist$|\.icns$|\.DS_Store$)'
if git ls-files | grep -E "$blocked"; then
  echo "tracked generated or local data found" >&2
  exit 1
fi
```

- [ ] **Step 2: Run the test to verify it fails while the repository safeguards are absent**

Run: `bash Scripts/test-repository-safety.sh`

Expected: FAIL because `Scripts/test-repository-safety.sh` does not exist.

- [ ] **Step 3: Add the minimal safeguards**

Create `.gitignore` entries for Swift build products, `.app` bundles, `.DS_Store`, `Library/`, runtime JSON snapshots, and user-specific launch-agent output. Add the MIT license. Document contributor rules: no credentials, no telemetry, no generated binaries, and no personal snapshots. Document a private security-report channel placeholder as a GitHub Security Advisory route, not an email address.

- [ ] **Step 4: Run the safety test**

Run: `bash Scripts/test-repository-safety.sh`

Expected: PASS with no output.

- [ ] **Step 5: Commit**

```bash
git add .gitignore LICENSE CONTRIBUTING.md SECURITY.md .github Scripts/test-repository-safety.sh
git commit -m "chore: add open-source repository safeguards"
```

### Task 2: Extract provider-neutral Swift code

**Files:**
- Create: `Shared/UsageModels.swift`
- Create: `Shared/Pacing.swift`
- Create: `Tests/PacingTests.swift`
- Remove after migration: `widget-shared/Pacing.swift`
- Test: `Tests/PacingTests.swift`

**Interfaces:**
- Produces: `UsageSnapshot`, `PaceAdvice`, and `Pacing.advice(current:peer:peerName:history:now:) -> PaceAdvice`.
- Produces: `SnapshotStore.read(_:)`, `SnapshotStore.history(_:)`, and `SnapshotStore.save(_:at:)`.
- Consumed by: both provider apps.

- [ ] **Step 1: Write failing Swift tests for fresh peer and stale peer decisions**

```swift
assert(advice(current: snapshot(86, 30), peer: snapshot(20, 10)).title == "Switch to Claude")
assert(advice(current: snapshot(86, 30), peer: snapshot(20, 10, age: 601)).title == "Slow down")
assert(advice(current: snapshot(20, 30, age: 601)).title == "Waiting for fresh usage")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swiftc Shared/UsageModels.swift Shared/Pacing.swift Tests/PacingTests.swift -o .build/pacing-tests && .build/pacing-tests`

Expected: FAIL because the shared files do not yet exist.

- [ ] **Step 3: Move the existing model and pacing behavior into focused files**

Keep all persisted fields limited to timestamps, percentages, window length, and reset timestamps. Keep the 15% session and 10% weekly reserves. Reject a peer snapshot older than ten minutes from switch advice. Keep an unused 0% session valid even when a provider omits the reset time.

- [ ] **Step 4: Run the complete pacing test suite**

Run: `mkdir -p .build && swiftc Shared/UsageModels.swift Shared/Pacing.swift Tests/PacingTests.swift -o .build/pacing-tests && .build/pacing-tests`

Expected: PASS with tests for switch, stale peer, stale current data, expired reset, weekly reserve, unused session, and rate forecast.

- [ ] **Step 5: Commit**

```bash
git add Shared Tests
git commit -m "refactor: extract shared usage pacing"
```

### Task 3: Package ChatGPT Usage as a standalone app

**Files:**
- Create: `ChatGPTUsage/main.swift`
- Create: `ChatGPTUsage/Info.plist`
- Create: `ChatGPTUsage/README.md`
- Test: `Tests/ChatGPTUsageSmoke.swift`

**Interfaces:**
- Consumes: `UsageSnapshot`, `SnapshotStore`, and `Pacing` from `Shared`.
- Produces: `ChatGPT Usage.app`, bundle ID `io.github.aiusagewidgets.chatgptusage`.
- Reads: ChatGPT’s bundled Codex executable through a resolver returning `URL?`.

- [ ] **Step 1: Write a failing resolver test for current and absent ChatGPT app layouts**

```swift
assert(CodexPath.resolve(appRoot: URL(fileURLWithPath: "/tmp/missing")) == nil)
let expected = URL(fileURLWithPath: "/tmp/ChatGPT.app/Contents/Resources/codex-cli/bin/codex")
assert(CodexPath.resolve(appRoot: expected.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()) == expected)
```

- [ ] **Step 2: Run the resolver test to verify it fails**

Run: `swiftc Shared/UsageModels.swift Shared/Pacing.swift ChatGPTUsage/main.swift Tests/ChatGPTUsageSmoke.swift -o .build/chatgpt-smoke && .build/chatgpt-smoke`

Expected: FAIL because `CodexPath.resolve` does not exist.

- [ ] **Step 3: Move the ChatGPT app code and add the resolver**

Search only under `/Applications/ChatGPT.app/Contents/Resources` for the current bundled `codex-cli/bin/codex`, then start `app-server` and request `account/rateLimits/read`. If no executable exists, show `ChatGPT app or Codex component not found` with no retry loop that launches a shell. Preserve notification controls, Add Widget, Remove Widget, snapshot saving, and pacing UI.

- [ ] **Step 4: Build and run the non-network smoke checks**

Run: `swiftc Shared/UsageModels.swift Shared/Pacing.swift ChatGPTUsage/main.swift Tests/ChatGPTUsageSmoke.swift -o .build/chatgpt-smoke && .build/chatgpt-smoke`

Expected: PASS. Then run `Scripts/build.sh chatgpt` and confirm `dist/ChatGPT Usage.app` exists.

- [ ] **Step 5: Commit**

```bash
git add ChatGPTUsage Tests/ChatGPTUsageSmoke.swift
git commit -m "feat: package ChatGPT usage tracker"
```

### Task 4: Package Claude Usage as an experimental standalone app

**Files:**
- Create: `ClaudeUsage/main.swift`
- Create: `ClaudeUsage/Info.plist`
- Create: `ClaudeUsage/README.md`
- Test: `Tests/ClaudeUsageSmoke.swift`

**Interfaces:**
- Consumes: `UsageSnapshot`, `SnapshotStore`, and `Pacing` from `Shared`.
- Produces: `Claude Usage.app`, bundle ID `io.github.aiusagewidgets.claudeusage`.
- Reads: the existing `Claude Code-credentials` Keychain item in memory only.

- [ ] **Step 1: Write failing parser tests for a valid payload and a missing session window**

```swift
let payload = #"{"five_hour":{"utilization":15,"resets_at":"2026-10-10T00:00:00.000000+00:00"},"seven_day":{"utilization":6,"resets_at":"2026-10-15T00:00:00.000000+00:00"}}"#.data(using: .utf8)!
let limits = try ClaudeUsageParser.parse(payload)
assert(limits.primary?.usedPercent == 15)
assert(limits.secondary?.usedPercent == 6)
```

- [ ] **Step 2: Run the parser test to verify it fails**

Run: `swiftc Shared/UsageModels.swift Shared/Pacing.swift ClaudeUsage/main.swift Tests/ClaudeUsageSmoke.swift -o .build/claude-smoke && .build/claude-smoke`

Expected: FAIL because `ClaudeUsageParser.parse` does not exist.

- [ ] **Step 3: Move the Claude app code behind a narrow adapter**

Use `security find-generic-password -s Claude Code-credentials -w` only to read the current user’s credential into memory. Parse only `claudeAiOauth.accessToken`; never write it to a file, `UserDefaults`, UI, notification, error string, or log. Make one HTTPS request to Claude’s usage endpoint and turn response errors into generic user-safe states. Mark the app and documentation as experimental.

- [ ] **Step 4: Build and run the parser smoke checks**

Run: `swiftc Shared/UsageModels.swift Shared/Pacing.swift ClaudeUsage/main.swift Tests/ClaudeUsageSmoke.swift -o .build/claude-smoke && .build/claude-smoke`

Expected: PASS. Confirm malformed JSON and missing Keychain values return a generic error with no token text.

- [ ] **Step 5: Commit**

```bash
git add ClaudeUsage Tests/ClaudeUsageSmoke.swift
git commit -m "feat: package experimental Claude usage tracker"
```

### Task 5: Add reproducible build, install, startup, and uninstall commands

**Files:**
- Create: `Scripts/build.sh`
- Create: `Scripts/install.sh`
- Create: `Scripts/uninstall.sh`
- Create: `Tests/InstallerContractTests.sh`
- Modify: `.gitignore`

**Interfaces:**
- `Scripts/build.sh <chatgpt|claude|both>` creates selected `.app` bundles under `dist/`.
- `Scripts/install.sh <chatgpt|claude|both> [--login-item]` installs only the selected bundle(s) under `~/Applications`.
- `Scripts/uninstall.sh <chatgpt|claude|both> [--purge-data]` removes only `io.github.aiusagewidgets.*` app and launch-agent paths.

- [ ] **Step 1: Write failing shell tests for targets and safe uninstall paths**

```bash
assert_fails Scripts/build.sh invalid
assert_fails Scripts/install.sh invalid
assert_output_contains "ChatGPT Usage.app" Scripts/build.sh chatgpt --dry-run
assert_output_excludes "Claude Usage.app" Scripts/build.sh chatgpt --dry-run
assert_output_excludes "/Applications/ChatGPT.app" Scripts/uninstall.sh chatgpt --dry-run
```

- [ ] **Step 2: Run the contract tests to verify they fail**

Run: `bash Tests/InstallerContractTests.sh`

Expected: FAIL because build/install/uninstall scripts do not exist.

- [ ] **Step 3: Implement the selected-target scripts**

Use `set -euo pipefail`, explicit case matching, quoted paths, and `mkdir -p`. Build with `swiftc` and package `Info.plist` plus official app icon references only as copied public build inputs. Require `--login-item` before writing a launch agent. For uninstall, remove only exact `~/Applications/ChatGPT Usage.app`, `~/Applications/Claude Usage.app`, and `~/Library/LaunchAgents/io.github.aiusagewidgets.*.plist` paths; retain snapshots unless `--purge-data` is passed.

- [ ] **Step 4: Run contracts and all build targets**

Run: `bash Tests/InstallerContractTests.sh && Scripts/build.sh chatgpt && Scripts/build.sh claude && Scripts/build.sh both`

Expected: PASS. Confirm `dist/` contains exactly the selected apps for each individual invocation.

- [ ] **Step 5: Commit**

```bash
git add Scripts Tests/InstallerContractTests.sh .gitignore
git commit -m "feat: add targeted build and install scripts"
```

### Task 6: Write the public release documentation

**Files:**
- Create: `README.md`
- Create: `docs/PRIVACY.md`
- Create: `docs/TROUBLESHOOTING.md`
- Create: `docs/SCREENSHOTS.md`
- Modify: `ChatGPTUsage/README.md`
- Modify: `ClaudeUsage/README.md`

**Interfaces:**
- Produces: copy-paste commands for `chatgpt`, `claude`, and `both` installation paths.
- Produces: a clear disclosure that Claude support uses an undocumented, experimental endpoint.

- [ ] **Step 1: Write a documentation contract check**

```bash
for phrase in "ChatGPT only" "Claude only" "Both trackers" "Experimental" "No prompts or conversations" "Uninstall"; do
  grep -q "$phrase" README.md || exit 1
done
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash Tests/DocumentationContractTests.sh`

Expected: FAIL because public documentation does not exist.

- [ ] **Step 3: Write the release documentation**

Explain prerequisites, build tools, exact installation commands, first-run permission behavior, startup option, Add Widget/Remove Widget, pacing estimates, notification behavior, privacy boundaries, known ChatGPT app update breakage, Claude experimental limitations, safe uninstall, and how to report a security issue. Screenshots must be generic and contain no account percentages, personal app names, or system-menu details.

- [ ] **Step 4: Run documentation and repository safety checks**

Run: `bash Tests/DocumentationContractTests.sh && bash Scripts/test-repository-safety.sh && git ls-files | grep -Ei '(status\.json|pace-history|credential|token)' && exit 1 || true`

Expected: Documentation and safety checks PASS; the final scan emits no source file containing stored credentials or tokens.

- [ ] **Step 5: Commit**

```bash
git add README.md docs ChatGPTUsage/README.md ClaudeUsage/README.md Tests/DocumentationContractTests.sh
git commit -m "docs: prepare public release guide"
```

### Task 7: Validate the release candidate and prepare GitHub metadata

**Files:**
- Create: `.github/pull_request_template.md`
- Create: `.github/workflows/build.yml`
- Create: `CHANGELOG.md`
- Modify: `README.md`

**Interfaces:**
- Produces: CI that builds and runs tests for both provider targets on macOS.
- Produces: a `v0.1.0` changelog entry with ChatGPT stable and Claude experimental labels.

- [ ] **Step 1: Write a failing CI configuration check**

```bash
grep -q 'macos-14' .github/workflows/build.yml
grep -q 'Scripts/build.sh both' .github/workflows/build.yml
grep -q 'Tests/InstallerContractTests.sh' .github/workflows/build.yml
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash Tests/CiContractTests.sh`

Expected: FAIL because the GitHub workflow does not exist.

- [ ] **Step 3: Add the release metadata**

Use a macOS GitHub Actions workflow that runs shared pacing tests, installer contract tests, documentation contract tests, and the `both` build. Add a PR template asking contributors to state whether they changed credential or persistence behavior. Add `v0.1.0` changelog notes and link the README to both tracker folders.

- [ ] **Step 4: Run the full local release check**

Run: `bash Scripts/test-repository-safety.sh && bash Tests/InstallerContractTests.sh && bash Tests/DocumentationContractTests.sh && bash Tests/CiContractTests.sh && Scripts/build.sh both`

Expected: PASS. Inspect `git status --short` to confirm no `dist/`, `.build/`, snapshot, or `.app` files are tracked.

- [ ] **Step 5: Commit**

```bash
git add .github CHANGELOG.md README.md Tests/CiContractTests.sh
git commit -m "ci: add macOS release validation"
```

## Final pre-publish checklist

- [ ] Run `git log --oneline --decorate -10` and confirm the history contains only project files.
- [ ] Run `git grep -nEi 'accessToken|Bearer |arjun|gmail\.com|/Users/'` and resolve any result that can expose a person or credential.
- [ ] Run `git status --short`; it must be empty.
- [ ] Review the README installation instructions from a fresh macOS account or state the exact unverified assumption.
- [ ] Create the GitHub repository and push only after the user explicitly authorizes the selected owner, repository name, visibility, and remote destination.
