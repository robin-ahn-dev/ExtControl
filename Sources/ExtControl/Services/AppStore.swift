import Foundation
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Hält gescannte Apps, den Endungs-Index und die aktuellen Standard-Apps.
@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var apps: [AppExtensionModel] = []
    @Published private(set) var extensions: [FileExtensionModel] = []
    @Published private(set) var handlers: [String: HandlerInfo] = [:]   // ext -> Standard-App
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var scannedCount = 0
    @Published private(set) var totalCount = 0
    @Published var lastError: String?

    private var task: Task<Void, Never>?
    private var appsByPath: [String: AppExtensionModel] = [:]

    var totalExtensionCount: Int { extensions.count }

    func app(path: String) -> AppExtensionModel? { appsByPath[path] }

    func handler(for ext: String) -> HandlerInfo? { handlers[ext] }

    // MARK: - Laden

    func load() {
        guard !isLoading else { return }
        task?.cancel()
        isLoading = true
        progress = 0
        scannedCount = 0
        totalCount = 0

        task = Task { [self] in
            let result = await AppScanner.scan { done, total in
                Task { @MainActor in
                    self.updateProgress(done: done, total: total)
                }
            }
            guard !Task.isCancelled else { return }
            apps = result
            appsByPath = Dictionary(uniqueKeysWithValues: result.map { ($0.path, $0) })
            extensions = AppScanner.buildExtensionIndex(from: result)
            totalCount = result.count
            scannedCount = result.count
            progress = 1
            isLoading = false
            refreshHandlers()
        }
    }

    /// Standard-Apps für alle Endungen neu bei LaunchServices abfragen.
    func refreshHandlers() {
        let exts = extensions.map(\.ext)
        Task { @MainActor in
            var map: [String: HandlerInfo] = [:]
            for (index, ext) in exts.enumerated() {
                if let info = DefaultAppService.handler(forExtension: ext) {
                    map[ext] = info
                }
                if index % 200 == 0 { await Task.yield() }
            }
            handlers = map
        }
    }

    /// Standard-App für eine oder mehrere Endungen setzen.
    func setDefault(app url: URL, for exts: [String]) {
        Task { @MainActor in
            var failures: [String] = []
            for ext in exts {
                if let error = await DefaultAppService.setDefault(app: url, forExtension: ext) {
                    failures.append(".\(ext): \(error)")
                } else {
                    handlers[ext] = DefaultAppService.handler(forExtension: ext)
                        ?? DefaultAppService.info(for: url)
                }
            }
            lastError = failures.isEmpty ? nil : failures.joined(separator: "\n")
        }
    }

    private func updateProgress(done: Int, total: Int) {
        scannedCount = done
        totalCount = total
        progress = total > 0 ? Double(done) / Double(total) : 0
    }
}

/// Icons werden erst beim Zeichnen der Zeile geladen und gecacht.
@MainActor
final class IconCache {
    static let shared = IconCache()
    private var cache: [String: NSImage] = [:]

    func icon(for path: String, size: CGFloat = 24) -> NSImage {
        let key = "\(path)#\(Int(size))"
        if let cached = cache[key] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: size, height: size)
        cache[key] = image
        return image
    }

    func icon(forExtension ext: String, size: CGFloat = 24) -> NSImage {
        let key = ".\(ext)#\(Int(size))"
        if let cached = cache[key] { return cached }
        let type = DefaultAppService.utType(for: ext) ?? .data
        let image = NSWorkspace.shared.icon(for: type)
        image.size = NSSize(width: size, height: size)
        cache[key] = image
        return image
    }
}
