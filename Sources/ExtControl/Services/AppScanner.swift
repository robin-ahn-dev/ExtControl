import Foundation
import AppKit
import UniformTypeIdentifiers

/// Findet App-Bundles auf dem System und liest deren `CFBundleDocumentTypes`.
enum AppScanner {

    /// Standard-Suchpfade von LaunchServices.
    static var searchPaths: [URL] {
        var paths = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            "/System/Library/CoreServices/Applications",
            "/Library/Application Support",
            "/Developer/Applications"
        ]
        paths.append(NSHomeDirectory() + "/Applications")
        paths.append(NSHomeDirectory() + "/Developer/Applications")

        let fm = FileManager.default
        return paths
            .filter { fm.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    // MARK: - Bundles finden

    /// Sammelt alle `.app`-Bundles. Steigt nicht in gefundene Bundles hinab.
    static func findAppBundles() -> [URL] {
        let fm = FileManager.default
        var found: [URL] = []
        var seen = Set<String>()

        for root in searchPaths {
            let maxDepth = root.path.hasSuffix("Application Support") ? 3 : 6
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            while let url = enumerator.nextObject() as? URL {
                if enumerator.level > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
                guard url.pathExtension == "app" else { continue }
                enumerator.skipDescendants()

                let resolved = url.resolvingSymlinksInPath()
                if seen.insert(resolved.path).inserted {
                    found.append(resolved)
                }
            }
        }

        // Vom Frontprozess bekannte Apps ergänzen (z. B. auf externen Volumes gestartet).
        for app in NSWorkspace.shared.runningApplications {
            guard let url = app.bundleURL?.resolvingSymlinksInPath(),
                  url.pathExtension == "app" else { continue }
            if seen.insert(url.path).inserted { found.append(url) }
        }

        return found
    }

    // MARK: - Scan

    /// Kompletter Scan im Hintergrund. `progress` liefert (erledigt, gesamt).
    static func scan(progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }) async -> [AppExtensionModel] {
        await Task.detached(priority: .userInitiated) { () -> [AppExtensionModel] in
            let bundles = findAppBundles()
            let total = bundles.count
            progress(0, total)

            var result: [AppExtensionModel] = []
            result.reserveCapacity(total)

            await withTaskGroup(of: AppExtensionModel?.self) { group in
                for url in bundles {
                    group.addTask { model(for: url) }
                }
                var done = 0
                for await model in group {
                    done += 1
                    if done % 25 == 0 { progress(done, total) }
                    if let model { result.append(model) }
                }
                progress(total, total)
            }

            return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }.value
    }

    // MARK: - Info.plist auswerten

    static func model(for url: URL) -> AppExtensionModel? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let info = (try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil)) as? [String: Any]
        else { return nil }

        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = localizedName(for: url)
            ?? info["CFBundleDisplayName"] as? String
            ?? info["CFBundleName"] as? String
            ?? fallbackName

        let bundleID = info["CFBundleIdentifier"] as? String ?? "—"
        let version = info["CFBundleShortVersionString"] as? String
            ?? info["CFBundleVersion"] as? String
            ?? "—"

        let rawTypes = info["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        let documentTypes = rawTypes.compactMap(documentType(from:))

        return AppExtensionModel(
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            url: url,
            documentTypes: documentTypes
        )
    }

    private static func documentType(from dict: [String: Any]) -> DocumentTypeModel? {
        let utis = stringList(dict["LSItemContentTypes"])
        var extensions = stringList(dict["CFBundleTypeExtensions"])

        // Aus UTIs zusätzliche Endungen ableiten.
        for uti in utis {
            guard let type = UTType(uti) else { continue }
            extensions.append(contentsOf: type.tags[.filenameExtension] ?? [])
        }

        let type = DocumentTypeModel(
            name: dict["CFBundleTypeName"] as? String ?? "Ohne Namen",
            role: dict["CFBundleTypeRole"] as? String ?? "—",
            fileExtensions: normalize(extensions),
            contentTypes: utis.sorted(),
            mimeTypes: normalizeKeepCase(stringList(dict["CFBundleTypeMIMETypes"]))
        )
        return type.isEmpty ? nil : type
    }

    /// Wert kann String oder [String] sein.
    private static func stringList(_ value: Any?) -> [String] {
        switch value {
        case let array as [String]: return array
        case let single as String: return [single]
        case let array as [Any]: return array.compactMap { $0 as? String }
        default: return []
        }
    }

    private static func normalize(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty && $0 != "*" }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    private static func normalizeKeepCase(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        return raw
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .sorted()
    }

    /// Lokalisierter Anzeigename aus InfoPlist.strings, sonst nil.
    private static func localizedName(for url: URL) -> String? {
        let name = FileManager.default.displayName(atPath: url.path)
        let trimmed = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension AppScanner {
    /// Dreht die App-Liste um: Endung -> alle Apps, die sie unterstützen.
    static func buildExtensionIndex(from apps: [AppExtensionModel]) -> [FileExtensionModel] {
        var appsByExt: [String: [AppExtensionModel]] = [:]
        var utisByExt: [String: Set<String>] = [:]

        for app in apps {
            for type in app.documentTypes {
                for ext in type.fileExtensions {
                    appsByExt[ext, default: []].append(app)
                    for uti in type.contentTypes {
                        guard let utType = UTType(uti),
                              (utType.tags[.filenameExtension] ?? []).contains(where: { $0.lowercased() == ext })
                        else { continue }
                        utisByExt[ext, default: []].insert(uti)
                    }
                }
            }
        }

        return appsByExt.map { ext, list in
            var utis = utisByExt[ext] ?? []
            var ordered: [String] = []
            if let preferred = UTType(filenameExtension: ext), !preferred.isDynamic {
                ordered.append(preferred.identifier)
                utis.remove(preferred.identifier)
            }
            ordered.append(contentsOf: utis.sorted())

            var seenPaths = Set<String>()
            let unique = list.filter { seenPaths.insert($0.path).inserted }
            return FileExtensionModel(ext: ext, utis: ordered, apps: unique)
        }
        .sorted { $0.ext.localizedStandardCompare($1.ext) == .orderedAscending }
    }
}
