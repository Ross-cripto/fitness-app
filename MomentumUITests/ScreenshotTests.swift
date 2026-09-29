import XCTest

/// Launches the real app with demo data in each language and saves a screenshot of every main screen.
/// It doubles as a smoke test: if the app crashes on launch or a screen cannot be reached, it fails.
/// CI publishes the screenshots (see .github/workflows/screenshots.yml).
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(language: String, demo: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uiTesting", "-demoLanguage", language, "-AppleLanguages", "(\(language))"]
        arguments += ["-AppleLocale", ["en": "en_US", "es": "es_419", "pt": "pt_BR"][language] ?? "en_US"]
        if demo { arguments.append("-demoData") }
        arguments += extra
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func shot(_ app: XCUIApplication, _ language: String, _ name: String) {
        // Let animations settle so the picture is stable.
        Thread.sleep(forTimeInterval: 1.0)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapTab(_ app: XCUIApplication, _ index: Int) {
        let tab = app.tabBars.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "tab \(index)")
        tab.tap()
    }

    private func walkThrough(_ language: String) {
        var app = launch(language: language)

        // Workouts (home)
        XCTAssertTrue(app.buttons["mainWorkoutCard"].waitForExistence(timeout: 15), "home workout card")
        shot(app, language, "1-workouts")

        // Progress, history, settings
        tapTab(app, 0)
        Thread.sleep(forTimeInterval: 1.0)
        shot(app, language, "4-progress")
        let all = app.buttons["allWorkouts"]
        XCTAssertTrue(all.waitForExistence(timeout: 5), "all workouts link")
        all.tap()
        shot(app, language, "5-history")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let settings = app.buttons["openSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "settings button")
        settings.tap()
        shot(app, language, "6-settings")

        // Workout detail and the player (fresh launch: no sheet to dismiss)
        app.terminate()
        app = launch(language: language)
        let card = app.buttons["mainWorkoutCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "home workout card")
        card.tap()
        let start = app.buttons["startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "start button")
        shot(app, language, "2-workout-detail")
        start.tap()
        Thread.sleep(forTimeInterval: 1.5)
        shot(app, language, "3-active-workout")
    }

    func testEnglish() { walkThrough("en") }
    func testSpanish() { walkThrough("es") }
    func testPortuguese() { walkThrough("pt") }

    func testExploreAndOnboarding() {
        let explore = launch(language: "es")
        tapTab(explore, 2)
        shot(explore, "es", "7-explore")
        explore.terminate()

        // A fresh install starts with onboarding.
        let fresh = launch(language: "pt", demo: false)
        XCTAssertTrue(fresh.staticTexts.firstMatch.waitForExistence(timeout: 10))
        shot(fresh, "pt", "8-onboarding")
    }

    /// Every onboarding step, then the home screen of the person just created.
    func testOnboardingSteps() {
        let app = launch(language: "es", demo: false)
        let next = app.buttons["onboardingNext"]
        for step in 0..<8 {
            XCTAssertTrue(next.waitForExistence(timeout: 10), "onboarding step \(step)")
            shot(app, "es", "onboarding-\(step + 1)")
            next.tap()
        }
        XCTAssertTrue(app.buttons["mainWorkoutCard"].waitForExistence(timeout: 15), "home after onboarding")
        shot(app, "es", "onboarded-home")
    }

    /// The biggest accessibility text size: layouts must still work.
    func testLargestTextSize() {
        let app = launch(language: "pt", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.buttons["mainWorkoutCard"].waitForExistence(timeout: 15), "home workout card")
        shot(app, "pt", "xxxl-1-workouts")
        app.buttons["mainWorkoutCard"].tap()
        XCTAssertTrue(app.buttons["startWorkout"].waitForExistence(timeout: 10), "start button")
        shot(app, "pt", "xxxl-2-workout-detail")
    }
}
