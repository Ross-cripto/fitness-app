import Foundation

/// Everything the app stores about a person. This is also the shape of the app's own save file.
struct PersonalData: Codable {
    var profile: UserProfile
    var sessions: [WorkoutSession]
    var weights: [WeightEntry]
}

/// A file the person can save anywhere and restore later (another phone, after a reinstall).
/// Plain JSON, readable and diffable, so the data is never locked in.
struct BackupFile: Codable {
    static let format = "momentum-backup"
    /// Bump when a change would stop older apps from reading the file.
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var profile: UserProfile
    var sessions: [WorkoutSession]
    var weights: [WeightEntry]
}

enum BackupError: Error, Equatable {
    /// Not JSON, or not a Momentum backup.
    case notABackup
    /// Written by a newer version of the app.
    case newerVersion(Int)
}

enum Backup {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func export(_ data: PersonalData, now: Date = Date()) throws -> Data {
        let file = BackupFile(
            format: BackupFile.format,
            version: BackupFile.currentVersion,
            exportedAt: now,
            profile: data.profile,
            sessions: data.sessions.sorted { $0.date < $1.date },
            weights: data.weights.sorted { $0.date < $1.date }
        )
        return try encoder.encode(file)
    }

    /// Reads and checks a backup. Never returns partial data: it either works or throws.
    static func read(_ data: Data) throws -> PersonalData {
        // Look at the header first so a newer file gives a helpful error instead of a decoding failure.
        struct Header: Decodable { var format: String?; var version: Int? }
        guard let header = try? decoder.decode(Header.self, from: data), header.format == BackupFile.format else {
            throw BackupError.notABackup
        }
        if let version = header.version, version > BackupFile.currentVersion {
            throw BackupError.newerVersion(version)
        }
        guard let file = try? decoder.decode(BackupFile.self, from: data) else { throw BackupError.notABackup }
        return PersonalData(
            profile: file.profile,
            sessions: file.sessions.sorted { $0.date < $1.date },
            weights: file.weights.filter { $0.kg.isFinite && $0.kg > 0 }.sorted { $0.date < $1.date }
        )
    }

    // MARK: CSV

    /// One row per logged set, in English with stable exercise ids, for spreadsheets and other tools.
    static func csv(sessions: [WorkoutSession]) -> String {
        var lines = ["date,workout,exercise_id,exercise,set,reps,weight_kg,seconds,effort"]
        let formatter = ISO8601DateFormatter()
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            for log in session.logs {
                let name = ExerciseLibrary.byID[log.exerciseID]?.englishName ?? log.exerciseID
                for (index, set) in log.sets.enumerated() {
                    let fields = [
                        formatter.string(from: session.date),
                        session.title,
                        log.exerciseID,
                        name,
                        String(index + 1),
                        String(set.reps),
                        trimmed(set.weightKg),
                        String(set.seconds),
                        log.effort?.rawValue ?? "",
                    ]
                    lines.append(fields.map(escape).joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func trimmed(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// Quotes a CSV field when needed. Also defuses spreadsheet formulas ("=", "+", "-", "@") in text fields.
    private static func escape(_ field: String) -> String {
        var text = field
        if let first = text.first, "=+-@".contains(first) { text = "'" + text }
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
