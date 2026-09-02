import Foundation
import AppKit
import UniformTypeIdentifiers
import CoreServices

/// Eine App als möglicher oder aktiver Handler.
struct HandlerInfo: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let url: URL
    let name: String
    let bundleID: String
}

/// Lesen und Setzen der Standard-App über LaunchServices.
enum DefaultAppService {

    static func utType(for ext: String) -> UTType? {
        UTType(filenameExtension: ext)
    }

    static func info(for url: URL) -> HandlerInfo {
        let raw = FileManager.default.displayName(atPath: url.path)
        let name = raw.hasSuffix(".app") ? String(raw.dropLast(4)) : raw
        return HandlerInfo(url: url,
                           name: name,
                           bundleID: Bundle(url: url)?.bundleIdentifier ?? "—")
    }

    /// Aktuelle Standard-App für eine Endung.
    static func handler(forExtension ext: String) -> HandlerInfo? {
        guard let type = utType(for: ext),
              let url = NSWorkspace.shared.urlForApplication(toOpen: type)
        else { return nil }
        return info(for: url)
    }

    /// Alle bei LaunchServices registrierten Kandidaten.
    static func candidates(forExtension ext: String) -> [HandlerInfo] {
        guard let type = utType(for: ext) else { return [] }
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: type)
            .filter { seen.insert($0.resolvingSymlinksInPath().path).inserted }
            .map(info(for:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Setzt die Standard-App. Rückgabe: Fehlertext oder nil bei Erfolg.
    static func setDefault(app: URL, forExtension ext: String) async -> String? {
        guard let type = utType(for: ext) else {
            return "Kein Dateityp (UTI) für .\(ext) ermittelbar."
        }
        if #available(macOS 15.0, *) {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: app, toOpen: type)
                return nil
            } catch {
                return error.localizedDescription
            }
        }
        guard let bundleID = Bundle(url: app)?.bundleIdentifier else {
            return "App hat keine Bundle-ID."
        }
        let status = LSSetDefaultRoleHandlerForContentType(
            type.identifier as CFString, .all, bundleID as CFString)
        return status == noErr ? nil : "LaunchServices-Fehler \(status)"
    }

    /// Warnung, wenn der UTI von mehreren Endungen geteilt wird.
    static func sharedExtensions(for ext: String) -> [String] {
        guard let type = utType(for: ext) else { return [] }
        let all = (type.tags[.filenameExtension] ?? []).map { $0.lowercased() }
        return all.filter { $0 != ext }.sorted()
    }
}
