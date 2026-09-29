import Foundation

/// Launch arguments used by UI tests and screenshot runs. They never touch the real data file.
///
///     -uiTesting                  use a throwaway data file
///     -demoData                   start with six weeks of engine-generated history
///     -demoLanguage en|es|pt      language to use
extension AppStore {
    @MainActor
    static func forLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppStore {
        guard arguments.contains("-uiTesting") else { return AppStore() }

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("momentum-uitest-\(UUID().uuidString).json")
        let store = AppStore(fileURL: file)
        var language: AppLanguage?
        if let index = arguments.firstIndex(of: "-demoLanguage"), index + 1 < arguments.count {
            language = AppLanguage(rawValue: arguments[index + 1])
        }
        if arguments.contains("-demoData") {
            store.seed(DemoData.make(language: language))
        } else if let language {
            store.profile.language = language
        }
        return store
    }
}
