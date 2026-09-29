import Foundation

/// Where a new user starts: overall level plus a rung on every bodyweight ladder.
struct Placement: Equatable {
    var level: FitnessLevel
    var rungs: [String: Int]
    /// Plain-language reasons, shown on the plan preview.
    var notes: [String]

    func rung(_ ladder: Ladder) -> Int { rungs[ladder.rawValue] ?? 0 }
}

enum Assessment {
    // MARK: Level

    /// history (0-3) + recent frequency (0-3): 0-2 beginner, 3-4 intermediate, 5-6 advanced.
    /// Advanced additionally needs 2+ years. The optional check then adjusts once.
    static func level(history: TrainingHistory, frequency: RecentFrequency, check: FitnessCheck) -> FitnessLevel {
        let total = history.rawValue + frequency.rawValue
        var level: FitnessLevel = total <= 2 ? .beginner : (total <= 4 ? .intermediate : .advanced)
        if level == .advanced && history != .over2Years { level = .intermediate }

        if level == .beginner && strongMarkers(check) >= 3 {
            level = .intermediate
        } else if level != .beginner, let pushups = check.pushups, let plank = check.plankSeconds,
                  pushups <= 3, plank < 20 {
            level = FitnessLevel.from(rank: level.rank - 1)
        }
        return level
    }

    /// Markers that show clearly above-beginner capability.
    static func strongMarkers(_ check: FitnessCheck) -> Int {
        var count = 0
        if let v = check.pushups, v >= 15 { count += 1 }
        if let v = check.squats, v >= 30 { count += 1 }
        if let v = check.plankSeconds, v >= 60 { count += 1 }
        if let v = check.pullups, v >= 3 { count += 1 }
        return count
    }

    // MARK: Rungs

    /// Defaults by level when the check was skipped: (beginner, intermediate, advanced).
    private static func defaultRung(_ ladder: Ladder, level: FitnessLevel) -> Int {
        let table: [Ladder: [Int]] = [
            .push: [0, 2, 3],
            .verticalPush: [0, 1, 2],
            .pull: [0, 1, 2],
            .squat: [0, 0, 1],
            .lunge: [0, 0, 1],
            .hinge: [0, 1, 1],
            .triceps: [0, 1, 2],
            .coreStability: [0, 1, 2],
            .coreFlexion: [0, 1, 2]
        ]
        return table[ladder]?[level.rank] ?? 0
    }

    static func place(_ profile: UserProfile) -> Placement {
        place(history: profile.history, frequency: profile.frequency, check: profile.check)
    }

    static func place(history: TrainingHistory, frequency: RecentFrequency, check: FitnessCheck) -> Placement {
        let level = self.level(history: history, frequency: frequency, check: check)
        var rungs: [String: Int] = [:]
        for ladder in Ladder.allCases {
            rungs[ladder.rawValue] = defaultRung(ladder, level: level)
        }
        var notes = ["Starting level: \(level.title)."]

        if let p = check.pushups {
            let push = p == 0 ? 0 : (p <= 4 ? 1 : (p < 25 ? 2 : 3))
            rungs[Ladder.push.rawValue] = push
            rungs[Ladder.verticalPush.rawValue] = max(0, push - 1)
            rungs[Ladder.triceps.rawValue] = max(0, push - 1)
            let names = ["wall push-ups", "knee push-ups", "push-ups", "decline push-ups"]
            notes.append("Pushing starts with \(names[push]).")
        }
        if let s = check.squats {
            rungs[Ladder.squat.rawValue] = s >= 40 ? 1 : 0
            rungs[Ladder.lunge.rawValue] = s >= 25 ? 1 : 0
        }
        if let pu = check.pullups {
            rungs[Ladder.pull.rawValue] = pu >= 1 ? 2 : min(defaultRung(.pull, level: level), 1)
            notes.append(pu >= 1 ? "You can pull yourself up, so pulling starts with pull-ups where a bar is available." : "Pulling starts with rows and back work.")
        }
        if let plank = check.plankSeconds {
            let core = plank < 20 ? 0 : (plank < 45 ? 1 : (plank < 90 ? 2 : 3))
            rungs[Ladder.coreStability.rawValue] = core
            let names = ["dead bugs", "planks", "side planks", "hollow holds"]
            notes.append("Core work starts with \(names[core]).")
        }
        return Placement(level: level, rungs: rungs, notes: notes)
    }
}
