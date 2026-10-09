import Foundation

@main
struct PacingTests {
    static let now = 1_000_000.0

    static func snapshot(_ used: Double, _ weekly: Double, age: Double = 0, reset: Double? = nil) -> UsageSnapshot {
        UsageSnapshot(updated: now - age, primaryUsed: used, secondaryUsed: weekly, primaryReset: reset ?? now + 7_200, secondaryReset: now + 3 * 86_400, primaryMinutes: 300, secondaryMinutes: 10_080)
    }

    static func advice(_ current: UsageSnapshot, peer: UsageSnapshot? = nil, history: [UsageSnapshot] = []) -> PaceAdvice {
        Pacing.advice(current: current, peer: peer, peerName: "Claude", history: history, now: now)
    }

    static func main() {
        assert(advice(snapshot(86, 30), peer: snapshot(20, 10)).title == "Switch to Claude")
        assert(advice(snapshot(86, 30), peer: snapshot(20, 10, age: 601)).title == "Slow down")
        assert(advice(snapshot(20, 30, age: 601)).title == "Waiting for fresh usage")
        assert(advice(snapshot(20, 95)).warning)
        assert(advice(snapshot(20, 30, reset: now - 1)).title == "Waiting for fresh usage")
        assert(advice(snapshot(20, 30)).title == "On pace")
        assert(advice(snapshot(50, 30), history: [snapshot(10, 30, age: 1_200)]).warning)
        assert(advice(snapshot(20, 30)).budget == "Weekly budget: 20.0 points/day")
        assert(advice(snapshot(20, 30), history: [snapshot(10, 30, age: 1_200, reset: now + 1)]).forecast.hasPrefix("Learning"))
        let unused = UsageSnapshot(updated: now, primaryUsed: 0, secondaryUsed: 10, primaryReset: nil, secondaryReset: now + 3 * 86_400, primaryMinutes: 300, secondaryMinutes: 10_080)
        assert(advice(unused).title == "On pace")
        assert(advice(snapshot(86, 30), peer: unused).title == "Switch to Claude")
        print("PASS: 11 pacing checks")
    }
}
