import Foundation

@main
struct ChatGPTUsageSmoke {
    static func main() {
        assert(CodexPath.resolve(appRoot: URL(fileURLWithPath: "/tmp/missing")) == nil)
        let executable = URL(fileURLWithPath: "/tmp/ChatGPT.app/Contents/Resources/codex-cli/bin/codex")
        let root = URL(fileURLWithPath: "/tmp/ChatGPT.app")
        try! FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: root) }
        assert(CodexPath.resolve(appRoot: root) == executable)
        print("PASS: ChatGPT resolver")
    }
}
