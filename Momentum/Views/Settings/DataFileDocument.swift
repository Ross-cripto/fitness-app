import SwiftUI
import UniformTypeIdentifiers

/// A file handed to the system "save to Files" sheet: a JSON backup or a CSV export.
struct DataFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.json, .commaSeparatedText] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
