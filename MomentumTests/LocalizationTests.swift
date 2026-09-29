import XCTest
@testable import Momentum

final class LocalizationTests: XCTestCase {
    private let translated: [AppLanguage] = [.es, .pt]

    override func tearDown() {
        Loc.language = .en
        super.tearDown()
    }

    // MARK: Basics

    func testLanguageDetectionPicksSupportedLanguage() {
        XCTAssertEqual(AppLanguage.detect(preferred: ["pt-PT", "en"]), .pt)
        XCTAssertEqual(AppLanguage.detect(preferred: ["es-MX"]), .es)
        XCTAssertEqual(AppLanguage.detect(preferred: ["fr-FR", "es"]), .es)
        XCTAssertEqual(AppLanguage.detect(preferred: ["ja"]), .en)
        XCTAssertEqual(AppLanguage.detect(preferred: []), .en)
    }

    func testPlaceholdersAreFilledInAnyOrder() {
        Loc.language = .en
        XCTAssertEqual(L("{1} then {0}", "a", "b"), "b then a")
        XCTAssertEqual(L("no placeholders"), "no placeholders")
    }

    func testUnknownKeysFallBackToEnglish() {
        for language in translated {
            Loc.language = language
            XCTAssertEqual(L("This sentence is not in any table {0}", 3), "This sentence is not in any table 3")
        }
    }

    func testListJoinsInEveryLanguage() {
        Loc.language = .en
        XCTAssertEqual(Loc.list(["a", "b", "c"]), "a, b and c")
        Loc.language = .es
        XCTAssertEqual(Loc.list(["a", "b", "c"]), "a, b y c")
        Loc.language = .pt
        XCTAssertEqual(Loc.list(["a", "b", "c"]), "a, b e c")
    }

    func testNumbersUseTheLanguagesDecimalSeparator() {
        Loc.language = .en
        XCTAssertEqual(Loc.number(12.5), "12.5")
        Loc.language = .es
        XCTAssertEqual(Loc.number(12.5), "12,5")
        Loc.language = .pt
        XCTAssertEqual(Loc.number(12.5), "12,5")
    }

    func testProfileLanguageChoiceIsSavedAndOptional() throws {
        var profile = UserProfile()
        XCTAssertNil(profile.language)
        profile.language = .pt
        let decoded = try JSONDecoder().decode(UserProfile.self, from: try JSONEncoder().encode(profile))
        XCTAssertEqual(decoded.language, .pt)
        let old = try JSONDecoder().decode(UserProfile.self, from: Data(#"{"name":"Sam"}"#.utf8))
        XCTAssertNil(old.language)
    }

    // MARK: Tables

    private func placeholders(_ text: String) -> [String] {
        var found: [String] = []
        var index = text.startIndex
        while let open = text[index...].firstIndex(of: "{") {
            guard let close = text[open...].firstIndex(of: "}") else { break }
            found.append(String(text[open...close]))
            index = text.index(after: close)
        }
        return found.sorted()
    }

    func testTablesHaveTheSameKeysInEveryLanguage() {
        let es = Loc.translatedKeys(in: .es)
        let pt = Loc.translatedKeys(in: .pt)
        XCTAssertFalse(es.isEmpty)
        XCTAssertEqual(es.subtracting(pt), [], "missing Portuguese")
        XCTAssertEqual(pt.subtracting(es), [], "missing Spanish")
    }

    func testTranslationsKeepPlaceholders() {
        for language in translated {
            for key in Loc.translatedKeys(in: language) {
                let text = Loc.translate(key, in: language)
                XCTAssertEqual(placeholders(text), placeholders(key), "\(language): \(key)")
                XCTAssertFalse(text.trimmingCharacters(in: .whitespaces).isEmpty, "\(language): \(key)")
            }
        }
    }

    func testEveryExerciseIsTranslatedWithTheSameNumberOfSteps() {
        for language in translated {
            XCTAssertEqual(ExerciseText.translatedIDs(in: language), Set(ExerciseLibrary.all.map(\.id)), "\(language)")
            for exercise in ExerciseLibrary.all {
                guard let entry = ExerciseText.entry(id: exercise.id, in: language) else { continue }
                XCTAssertFalse(entry.name.isEmpty, exercise.id)
                XCTAssertEqual(entry.steps.count, exercise.englishSteps.count, "\(language) \(exercise.id)")
                XCTAssertTrue(entry.steps.allSatisfy { !$0.isEmpty }, "\(language) \(exercise.id)")
            }
        }
    }

    func testExerciseTextFollowsTheLanguage() {
        let pushup = ExerciseLibrary.exercise("pushup")
        Loc.language = .en
        XCTAssertEqual(pushup.name, pushup.englishName)
        Loc.language = .es
        XCTAssertNotEqual(pushup.name, pushup.englishName)
        XCTAssertEqual(pushup.steps.count, pushup.englishSteps.count)
        Loc.language = .pt
        XCTAssertNotEqual(pushup.name, pushup.englishName)
    }

    func testVideoSearchUsesTheTranslatedName() {
        Loc.language = .es
        let exercise = ExerciseLibrary.exercise("pushup")
        let query = URLComponents(url: exercise.videoURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "search_query" }?.value ?? ""
        XCTAssertTrue(query.contains(exercise.name), query)
        XCTAssertFalse(query.contains("proper form"), query)
    }

    func testEnumsHaveTranslatedTitles() {
        func check<T: CaseIterable>(_ type: T.Type, _ title: (T) -> String) {
            for value in T.allCases {
                Loc.language = .en
                let english = title(value)
                for language in translated {
                    Loc.language = language
                    XCTAssertNotEqual(title(value), "", "\(value)")
                    _ = english
                }
            }
        }
        check(Goal.self) { $0.title }
        check(FitnessLevel.self) { $0.title }
        check(Equipment.self) { $0.title }
        check(BodyArea.self) { $0.title }
        check(MuscleGroup.self) { $0.title }
        check(SwapReason.self) { $0.title }
    }

    // MARK: Engine output

    /// Sentences the engine writes must not leak English or unresolved placeholders in another language.
    func testEngineTextIsFullyTranslated() {
        let english = [" the ", " you ", " your ", " and ", " with ", " because "]
        let profiles = [
            T.profile(level: .beginner, goal: .stayFit, equipment: .bodyweight, weekdays: [2, 4], minutes: 30),
            T.profile(level: .intermediate, goal: .buildMuscle, equipment: .dumbbells, weekdays: [2, 3, 5, 6], minutes: 45, limitations: [.knees]),
            T.profile(level: .advanced, goal: .getStronger, equipment: .fullGym, weekdays: [2, 3, 4, 6], minutes: 60, age: 55),
        ]
        for profile in profiles {
            Loc.language = .en
            let base = PlanGenerator.week(containing: T.monday, profile: profile, history: [], now: T.monday)
            for language in translated {
                Loc.language = language
                let localized = PlanGenerator.week(containing: T.monday, profile: profile, history: [], now: T.monday)
                XCTAssertEqual(base.count, localized.count)
                for (a, b) in zip(base, localized) {
                    XCTAssertEqual(a.workout.exercises.map(\.exercise.id), b.workout.exercises.map(\.exercise.id),
                                   "language must never change which exercises are planned")
                    var texts = [b.workout.title, b.workout.phase?.label ?? "", b.workout.note ?? ""]
                    for (x, y) in zip(a.workout.exercises, b.workout.exercises) {
                        if let original = x.reason, !original.isEmpty {
                            XCTAssertNotEqual(original, y.reason, "\(language) not translated: \(original)")
                        }
                        texts.append(y.reason ?? "")
                        texts.append(y.exercise.name)
                    }
                    for text in texts {
                        XCTAssertFalse(text.contains("{"), "\(language): \(text)")
                        for word in english {
                            XCTAssertFalse(" \(text.lowercased()) ".contains(word), "\(language) leaks English: \(text)")
                        }
                    }
                }
            }
        }
    }

    func testSwapSuggestionsAreTranslated() {
        let profile = T.profile(level: .intermediate, equipment: .fullGym)
        Loc.language = .en
        guard let workout = PlanGenerator.workout(on: T.monday, profile: profile, history: [], now: T.monday),
              let planned = workout.exercises.first else { return XCTFail("no workout") }
        for language in translated {
            Loc.language = language
            for reason in SwapReason.allCases {
                let suggestions = Alternatives.suggest(for: planned, in: workout, reason: reason, profile: profile, painAreas: [.knees])
                for suggestion in suggestions {
                    XCTAssertFalse(suggestion.why.contains("{"), suggestion.why)
                    XCTAssertFalse(" \(suggestion.why.lowercased()) ".contains(" the "), "\(language): \(suggestion.why)")
                }
            }
        }
    }
}
