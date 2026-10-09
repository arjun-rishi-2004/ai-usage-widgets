import Foundation

public struct UsageSnapshot: Codable, Equatable {
    public let updated: Double
    public let primaryUsed: Double?
    public let secondaryUsed: Double?
    public let primaryReset: Double?
    public let secondaryReset: Double?
    public let primaryMinutes: Int?
    public let secondaryMinutes: Int?

    public init(updated: Double, primaryUsed: Double?, secondaryUsed: Double?, primaryReset: Double?, secondaryReset: Double?, primaryMinutes: Int?, secondaryMinutes: Int?) {
        self.updated = updated
        self.primaryUsed = primaryUsed
        self.secondaryUsed = secondaryUsed
        self.primaryReset = primaryReset
        self.secondaryReset = secondaryReset
        self.primaryMinutes = primaryMinutes
        self.secondaryMinutes = secondaryMinutes
    }
}

public struct PaceAdvice: Equatable {
    public let title: String
    public let reason: String
    public let budget: String
    public let forecast: String
    public let warning: Bool

    public init(title: String, reason: String, budget: String, forecast: String, warning: Bool) {
        self.title = title
        self.reason = reason
        self.budget = budget
        self.forecast = forecast
        self.warning = warning
    }
}

public enum SnapshotStore {
    public static func read(_ url: URL) -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    public static func history(_ url: URL) -> [UsageSnapshot] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([UsageSnapshot].self, from: data)) ?? []
    }

    public static func save(_ snapshot: UsageSnapshot, at url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }

        let historyURL = directory.appendingPathComponent("pace-history.json")
        var snapshots = history(historyURL).filter {
            $0.updated >= snapshot.updated - 3_600 && $0.primaryReset == snapshot.primaryReset
        }
        if let last = snapshots.last, (snapshot.primaryUsed ?? 0) < (last.primaryUsed ?? 0) { snapshots = [] }
        snapshots.append(snapshot)
        if let data = try? JSONEncoder().encode(Array(snapshots.suffix(120))) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }
}
