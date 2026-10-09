import Foundation

public enum Pacing {
    public static func advice(current snapshot: UsageSnapshot, peer: UsageSnapshot?, peerName: String, history: [UsageSnapshot], now: Double) -> PaceAdvice {
        let unavailable = PaceAdvice(title: "Waiting for fresh usage", reason: "Refresh to get a pacing recommendation.", budget: "Daily target unavailable", forecast: "Estimates · keeps 15% session / 10% weekly spare", warning: false)
        guard now - snapshot.updated <= 600, now >= snapshot.updated - 60,
              let used = snapshot.primaryUsed, let weekly = snapshot.secondaryUsed,
              let weeklyReset = snapshot.secondaryReset,
              (snapshot.primaryReset.map { $0 > now } ?? (used == 0)), weeklyReset > now else { return unavailable }

        let sessionReset = snapshot.primaryReset ?? .infinity
        let days = (weeklyReset - now) / 86_400
        let budget = String(format: "Weekly budget: %.1f points/day", max(0, 90 - weekly) / max(1, days))
        let duration = Double(snapshot.secondaryMinutes ?? 10_080) * 60
        let elapsed = max(0, min(1, 1 - (weeklyReset - now) / duration))
        let ahead = weekly > 90 * elapsed + 5
        let eligible = history.filter {
            $0.primaryReset == sessionReset && $0.updated <= snapshot.updated - 600 && $0.updated >= now - 3_600 && ($0.primaryUsed ?? 101) <= used
        }

        var forecast = snapshot.primaryReset == nil ? "Session unused · reset time not yet available" : "Learning your pace · needs 10 minutes"
        var runningFast = false
        if let first = eligible.min(by: { $0.updated < $1.updated }), let old = first.primaryUsed {
            let rate = (used - old) / ((snapshot.updated - first.updated) / 3_600)
            if rate > 0 {
                let hours = max(0, 85 - used) / rate
                forecast = String(format: "Recent pace: %.1f points/h · reserve in %.0fm", rate, hours * 60)
                runningFast = hours * 3_600 < sessionReset - now
            } else { forecast = "No recent increase · reserve intact" }
        }

        var title = "On pace"
        var reason = "Keep a little allowance for unexpected tasks."
        var warning = false
        if used >= 85 || weekly >= 90 || runningFast || ahead {
            warning = true
            title = "Slow down"
            reason = weekly >= 90 ? "Weekly reserve reached; save it until reset." : used >= 85 ? "Session reserve reached; save it until reset." : ahead ? "Weekly usage is ahead of an even daily pace." : "At this pace, you’ll reach your reserve before reset."
            if let peer, now - peer.updated <= 600, now >= peer.updated - 60,
               let peerUsed = peer.primaryUsed, let peerWeekly = peer.secondaryUsed,
               let peerWeeklyReset = peer.secondaryReset,
               peerUsed < 75, peerWeekly < 80,
               (peer.primaryReset.map { $0 > now } ?? (peerUsed == 0)), peerWeeklyReset > now,
               ((peerUsed < used && (used >= 85 || runningFast)) || (peerWeekly < weekly && (weekly >= 90 || ahead))) {
                title = "Switch to \(peerName)"
                reason += " \(peerName) has more headroom."
            }
        } else if sessionReset - now < 1_800 && used < 70 {
            title = "Room for a small task"
            reason = "Reset is close; stay within your weekly budget."
        }
        return PaceAdvice(title: title, reason: reason, budget: budget, forecast: forecast, warning: warning)
    }
}
