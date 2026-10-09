import Cocoa
import Foundation

struct ClaudeWindow: Decodable {
    let utilization: Double?
    let resetsAt: String?
    enum CodingKeys: String, CodingKey { case utilization; case resetsAt = "resets_at" }
    func limit(minutes: Int) -> UsageSnapshot? {
        guard let utilization else { return nil }
        let reset = resetsAt.flatMap { ISO8601DateFormatter().date(from: $0)?.timeIntervalSince1970 }
        return UsageSnapshot(updated: Date().timeIntervalSince1970, primaryUsed: utilization, secondaryUsed: nil, primaryReset: reset, secondaryReset: nil, primaryMinutes: minutes, secondaryMinutes: nil)
    }
}
struct ClaudePayload: Decodable { let fiveHour: ClaudeWindow?; let sevenDay: ClaudeWindow?; enum CodingKeys: String, CodingKey { case fiveHour = "five_hour"; case sevenDay = "seven_day" } }
struct ClaudeLimits { let primary: UsageSnapshot?; let secondary: UsageSnapshot? }

enum ClaudeUsageParser {
    static func parse(_ data: Data) throws -> ClaudeLimits {
        let payload = try JSONDecoder().decode(ClaudePayload.self, from: data)
        return ClaudeLimits(primary: payload.fiveHour?.limit(minutes: 300), secondary: payload.sevenDay?.limit(minutes: 10_080))
    }
}

final class ClaudeMonitor: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: 54)
    private let snapshotURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AI Usage Widgets/claude-status.json")
    override init() {
        super.init(); item.button?.title = "–%"; item.button?.toolTip = "Claude Usage (experimental)"
        let menu = NSMenu(); menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r"); menu.addItem(.separator()); menu.addItem(withTitle: "Quit Claude Usage", action: #selector(quit), keyEquivalent: "q"); item.menu = menu
        refresh(); Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }
    @objc private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let token = self.keychainToken() else { self.safeError(); return }
            var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!); request.timeoutInterval = 25
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization"); request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
            URLSession.shared.dataTask(with: request) { data, response, _ in
                guard let data, (response as? HTTPURLResponse)?.statusCode == 200, let limits = try? ClaudeUsageParser.parse(data) else { self.safeError(); return }
                DispatchQueue.main.async { self.show(limits) }
            }.resume()
        }
    }
    private func keychainToken() -> String? {
        let process = Process(), output = Pipe(); process.executableURL = URL(fileURLWithPath: "/usr/bin/security"); process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }; let data = output.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        guard process.terminationStatus == 0, let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let oauth = value["claudeAiOauth"] as? [String: Any] else { return nil }
        return oauth["accessToken"] as? String
    }
    private func show(_ limits: ClaudeLimits) {
        item.button?.title = "\(Int(limits.primary?.primaryUsed ?? 0))%"
        let primary = limits.primary; let secondary = limits.secondary
        SnapshotStore.save(UsageSnapshot(updated: Date().timeIntervalSince1970, primaryUsed: primary?.primaryUsed, secondaryUsed: secondary?.primaryUsed, primaryReset: primary?.primaryReset, secondaryReset: secondary?.primaryReset, primaryMinutes: 300, secondaryMinutes: 10_080), at: snapshotURL)
    }
    private func safeError() { DispatchQueue.main.async { self.item.button?.title = "?%"; self.item.button?.toolTip = "Claude usage unavailable — sign in to Claude Code" } }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

#if !TESTING
@main
struct ClaudeUsageApp { static func main() { let app = NSApplication.shared; _ = ClaudeMonitor(); app.setActivationPolicy(.accessory); app.run() } }
#endif
