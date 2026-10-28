import Foundation

/// Where settings and scores persist. Snapshot runs swap in a throwaway suite.
enum Store {
    static var defaults = UserDefaults.standard
}

enum Settings {
    struct GameSpeed {
        let name: String
        let multiplier: Double
        var label: String { "\(name) (\(multiplier.formatted())×)" }
    }

    /// The simulation clock is scaled by `multiplier`, so everything (skier, avalanche, creatures, timers) speeds up together.
    static let speeds = [
        GameSpeed(name: "Chill", multiplier: 0.75),
        GameSpeed(name: "Normal", multiplier: 1.0),
        GameSpeed(name: "Fast", multiplier: 1.25),
        GameSpeed(name: "Turbo", multiplier: 1.5),
    ]

    static var speedIndex: Int {
        get {
            guard Store.defaults.object(forKey: "gameSpeed") != nil else { return 1 }
            return max(0, min(speeds.count - 1, Store.defaults.integer(forKey: "gameSpeed")))
        }
        set { Store.defaults.set(newValue, forKey: "gameSpeed") }
    }

    static var speed: GameSpeed { speeds[speedIndex] }

    static func cycleSpeed() { speedIndex = (speedIndex + 1) % speeds.count }

    static func name(forMultiplier multiplier: Double) -> String {
        speeds.first { $0.multiplier == multiplier }?.name ?? "\(multiplier.formatted())×"
    }
}
