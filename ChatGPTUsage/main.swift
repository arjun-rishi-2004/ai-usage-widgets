import Cocoa
import Foundation

enum CodexPath {
    static func resolve(appRoot: URL = URL(fileURLWithPath: "/Applications/ChatGPT.app")) -> URL? {
        let executable = appRoot.appendingPathComponent("Contents/Resources/codex-cli/bin/codex")
        return FileManager.default.fileExists(atPath: executable.path) ? executable : nil
    }
}

struct WindowLimit: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Double?
    var used: Int { Int(usedPercent.rounded()) }
}
struct CodexLimits: Decodable { let primary: WindowLimit?; let secondary: WindowLimit? }
struct RateResponse: Decodable { let rateLimits: CodexLimits?; let rateLimitsByLimitId: [String: CodexLimits]? }
struct ServerResponse: Decodable { let result: RateResponse? }

final class ChatGPTMonitor: NSObject {
    private var process: Process?
    private var input: Pipe?
    private var buffer = Data()
    private let statusItem = NSStatusBar.system.statusItem(withLength: 54)
    private let snapshotURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AI Usage Widgets/chatgpt-status.json")

    override init() {
        super.init()
        statusItem.button?.title = "–%"
        statusItem.button?.toolTip = "ChatGPT Usage"
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh", action: #selector(refresh), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ChatGPT Usage", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
        connect()
        Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
    }

    private func connect() {
        guard process == nil else { return }
        guard let executable = CodexPath.resolve() else { statusItem.button?.title = "?%"; statusItem.button?.toolTip = "ChatGPT app or Codex component not found"; return }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            DispatchQueue.main.async { self?.receive(data) }
        }
        process.terminationHandler = { [weak self] _ in DispatchQueue.main.async { self?.process = nil; self?.statusItem.button?.title = "?%" } }
        self.process = process; self.input = input
        do { try process.run(); send(["id": 0, "method": "initialize", "params": ["clientInfo": ["name": "ai-usage-widgets", "version": "0.1"]]]) }
        catch { self.process = nil; statusItem.button?.title = "?%" }
    }

    private func send(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        try? input?.fileHandleForWriting.write(contentsOf: data + Data([10]))
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 10) {
            let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
            guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if json["id"] as? Int == 0 { send(["method": "initialized"]); refresh(); continue }
            guard let response = try? JSONDecoder().decode(ServerResponse.self, from: line), let result = response.result,
                  let limits = result.rateLimitsByLimitId?["codex"] ?? result.rateLimits else { continue }
            show(limits)
        }
    }

    private func show(_ limits: CodexLimits) {
        statusItem.button?.title = "\(limits.primary?.used ?? 0)%"
        let snapshot = UsageSnapshot(updated: Date().timeIntervalSince1970, primaryUsed: limits.primary?.usedPercent, secondaryUsed: limits.secondary?.usedPercent, primaryReset: limits.primary?.resetsAt, secondaryReset: limits.secondary?.resetsAt, primaryMinutes: limits.primary?.windowDurationMins, secondaryMinutes: limits.secondary?.windowDurationMins)
        SnapshotStore.save(snapshot, at: snapshotURL)
    }

    @objc private func refresh() { if process == nil { connect() } else { send(["id": 1, "method": "account/rateLimits/read"]) } }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

#if !TESTING
@main
struct ChatGPTUsageApp {
    static func main() {
        let app = NSApplication.shared
        _ = ChatGPTMonitor()
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
#endif
