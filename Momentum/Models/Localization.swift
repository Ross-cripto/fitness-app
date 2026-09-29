import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Languages the app is translated into.
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case en, es, pt

    var id: String { rawValue }

    /// The language's own name, so people can always find theirs.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .es: return "Español"
        case .pt: return "Português"
        }
    }

    /// Spanish is neutral Latin American ("tú"); Portuguese is Brazilian.
    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_US")
        case .es: return Locale(identifier: "es_419")
        case .pt: return Locale(identifier: "pt_BR")
        }
    }

    /// The best supported language for a list of preferred language tags (e.g. "pt-PT", "es-MX").
    static func detect(preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        for tag in preferred {
            let code = String(tag.lowercased().prefix(2))
            if let language = AppLanguage(rawValue: code) { return language }
        }
        return .en
    }
}

/// Runtime localization. English text is the key; other languages come from generated tables
/// (`LocalizationData`, `ExerciseTranslations`) and fall back to English when a string is missing.
///
/// Placeholders are `{0}`, `{1}`, ... so translations can reorder them.
enum Loc {
    /// The language the app currently speaks. Set once at launch and whenever the user changes it.
    static var language: AppLanguage = .detect()

    static var locale: Locale { language.locale }

    /// The user's calendar (first weekday, etc.) with month and weekday names in the app language.
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar
    }

    /// Formats a date with a skeleton such as "EEEE" (weekday), "MMMMd" (month and day), "jm" (time), in the app language.
    static func date(_ date: Date, _ template: String) -> String {
        dateFormatter(template).string(from: date)
    }

    /// A date formatter that speaks the app language. Prefer this over `DateFormatter()` and `.formatted()`.
    static func dateFormatter(_ template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    private static let tables: [AppLanguage: [String: String]] = {
        guard let data = LocalizationData.json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        var result: [AppLanguage: [String: String]] = [:]
        for (code, table) in decoded {
            if let language = AppLanguage(rawValue: code) { result[language] = table }
        }
        return result
    }()

    /// Every key that has a translation in `language` (used by tests).
    static func translatedKeys(in language: AppLanguage) -> Set<String> {
        Set(tables[language]?.keys.map { $0 } ?? [])
    }

    static func translate(_ key: String, in language: AppLanguage) -> String {
        if language == .en { return key }
        return tables[language]?[key] ?? key
    }

    static func text(_ key: String, _ args: [String] = []) -> String {
        var result = translate(key, in: language)
        for (index, value) in args.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: value)
        }
        return result
    }

    /// "a", "a and b", "a, b and c" in the current language.
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default:
            let head = items.dropLast().joined(separator: ", ")
            return text("{0} and {1}", [head, items[items.count - 1]])
        }
    }

    /// Formats a number in the current language (12.5 -> "12.5" or "12,5").
    static func number(_ value: Double, maxFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

/// Localized text with `{0}`-style placeholders. The English text is the lookup key.
func L(_ key: String, _ args: CustomStringConvertible...) -> String {
    Loc.text(key, args.map { String(describing: $0) })
}

/// Chooses between a singular and plural key by count. Both receive the count as `{0}`.
func Lp(_ count: Int, one: String, other: String) -> String {
    Loc.text(count == 1 ? one : other, [String(count)])
}

/// Localized exercise names and instructions.
enum ExerciseText {
    struct Entry: Decodable {
        let name: String
        let steps: [String]
    }

    private static let tables: [AppLanguage: [String: Entry]] = {
        guard let data = ExerciseTranslations.json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: [String: Entry]].self, from: data) else { return [:] }
        var result: [AppLanguage: [String: Entry]] = [:]
        for (code, table) in decoded {
            if let language = AppLanguage(rawValue: code) { result[language] = table }
        }
        return result
    }()

    static func entry(id: String, in language: AppLanguage) -> Entry? {
        language == .en ? nil : tables[language]?[id]
    }

    static func name(id: String, english: String) -> String {
        entry(id: id, in: Loc.language)?.name ?? english
    }

    static func steps(id: String, english: [String]) -> [String] {
        guard let entry = entry(id: id, in: Loc.language), entry.steps.count == english.count else { return english }
        return entry.steps
    }

    /// Ids that have a translation in `language` (used by tests).
    static func translatedIDs(in language: AppLanguage) -> Set<String> {
        Set(tables[language]?.keys.map { $0 } ?? [])
    }
}

#if canImport(SwiftUI)
/// Localized `Text` that renders `**bold**` and other inline markdown. Use `Text(L(...))` when markdown is not needed.
func LText(_ key: String, _ args: CustomStringConvertible...) -> Text {
    // Values (a name typed by the user, say) must not be read as markdown.
    let escaped = args.map { arg -> String in
        var text = ""
        for character in String(describing: arg) {
            if "\\`*_[]<>~".contains(character) { text.append("\\") }
            text.append(character)
        }
        return text
    }
    return Text(LocalizedStringKey(Loc.text(key, escaped)))
}
#endif
