import Foundation

@main
struct ClaudeUsageSmoke {
    static func main() throws {
        let payload = #"{"five_hour":{"utilization":15,"resets_at":"2026-10-10T00:00:00.000000+00:00"},"seven_day":{"utilization":6,"resets_at":"2026-10-15T00:00:00.000000+00:00"}}"#.data(using: .utf8)!
        let limits = try ClaudeUsageParser.parse(payload)
        assert(limits.primary?.primaryUsed == 15)
        assert(limits.secondary?.primaryUsed == 6)
        assert((try? ClaudeUsageParser.parse(Data("{}".utf8)))?.primary == nil)
        print("PASS: Claude parser")
    }
}
