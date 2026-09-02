import Foundation

/// Eine Dateiendung mit allen Apps, die sie laut Info.plist unterstützen.
struct FileExtensionModel: Identifiable, Hashable, Sendable {
    let id: String              // Endung ohne Punkt, lowercase
    let utis: [String]
    let appPaths: [String]
    let appNames: [String]
    let searchBlob: String

    var ext: String { id }
    var dotted: String { ".\(id)" }
    var appCount: Int { appPaths.count }
    var utiJoined: String { utis.isEmpty ? "—" : utis.joined(separator: ", ") }
    var appsJoined: String { appNames.isEmpty ? "—" : appNames.joined(separator: ", ") }

    init(ext: String, utis: [String], apps: [AppExtensionModel]) {
        self.id = ext
        self.utis = utis
        let sorted = apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.appPaths = sorted.map(\.path)
        self.appNames = sorted.map(\.name)
        self.searchBlob = ".\(ext) \(utis.joined(separator: " ")) \(self.appNames.joined(separator: " "))".lowercased()
    }

    func matches(query: String) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }
        return needle
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .allSatisfy { searchBlob.contains($0) }
    }
}
