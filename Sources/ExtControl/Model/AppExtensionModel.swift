import Foundation

/// Ein einzelner Eintrag aus `CFBundleDocumentTypes`.
struct DocumentTypeModel: Identifiable, Hashable, Sendable {
    let id = UUID()
    let name: String
    let role: String
    let fileExtensions: [String]
    let contentTypes: [String]
    let mimeTypes: [String]

    var isEmpty: Bool {
        fileExtensions.isEmpty && contentTypes.isEmpty && mimeTypes.isEmpty
    }
}

/// Eine installierte App inklusive aller unterstützten Dateiendungen.
struct AppExtensionModel: Identifiable, Hashable, Sendable {
    let id: String              // Pfad zum Bundle (eindeutig)
    let name: String
    let bundleIdentifier: String
    let version: String
    let path: String
    let url: URL
    let documentTypes: [DocumentTypeModel]

    /// Alle Endungen aller Document Types, dedupliziert + sortiert.
    let fileExtensions: [String]

    /// Vorberechnet für schnelle Suche.
    let searchBlob: String

    var extensionsJoined: String {
        fileExtensions.isEmpty ? "—" : fileExtensions.map { ".\($0)" }.joined(separator: ", ")
    }

    var extensionCount: Int { fileExtensions.count }

    init(name: String,
         bundleIdentifier: String,
         version: String,
         url: URL,
         documentTypes: [DocumentTypeModel]) {
        self.id = url.path
        self.path = url.path
        self.url = url
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.documentTypes = documentTypes

        var seen = Set<String>()
        var ordered: [String] = []
        for type in documentTypes {
            for ext in type.fileExtensions where seen.insert(ext).inserted {
                ordered.append(ext)
            }
        }
        self.fileExtensions = ordered.sorted()

        var blob = "\(name)\n\(bundleIdentifier)\n\(url.path)\n"
        blob += self.fileExtensions.map { ".\($0)" }.joined(separator: " ")
        blob += "\n" + documentTypes.flatMap(\.contentTypes).joined(separator: " ")
        blob += "\n" + documentTypes.flatMap(\.mimeTypes).joined(separator: " ")
        self.searchBlob = blob.lowercased()
    }

    /// Live-Filter: matcht App-Name, Bundle-ID, Endung (mit oder ohne Punkt), UTI, MIME.
    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return needle
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .allSatisfy { searchBlob.contains($0) }
    }
}
