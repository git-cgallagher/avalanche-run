import Foundation

struct ScoreEntry: Codable, Equatable {
    var name: String
    var score: Int
    var meters: Int
    var date: Date
    /// Slowest game-speed multiplier used during the run (nil for runs before speeds existed).
    var speed: Double?
}

/// Local top-10 table, stored as JSON in UserDefaults.
enum Leaderboard {
    static let size = 10
    private static var store: UserDefaults { Store.defaults }

    static var entries: [ScoreEntry] {
        guard let data = store.data(forKey: "leaderboard"),
              let list = try? JSONDecoder().decode([ScoreEntry].self, from: data) else { return [] }
        return list
    }

    static var best: Int { entries.first?.score ?? 0 }

    static var lastName: String {
        get { store.string(forKey: "lastName") ?? "" }
        set { store.set(newValue, forKey: "lastName") }
    }

    static func qualifies(_ score: Int) -> Bool {
        let list = entries
        guard score > 0 else { return false }
        return list.count < size || score > (list.last?.score ?? 0)
    }

    /// Where `score` would land (0-based). Ties go below existing entries.
    static func rank(for score: Int) -> Int {
        entries.firstIndex { score > $0.score } ?? entries.count
    }

    @discardableResult
    static func record(_ entry: ScoreEntry) -> Int {
        var list = entries
        let rank = rank(for: entry.score)
        list.insert(entry, at: rank)
        if let data = try? JSONEncoder().encode(Array(list.prefix(size))) { store.set(data, forKey: "leaderboard") }
        return rank
    }
}
