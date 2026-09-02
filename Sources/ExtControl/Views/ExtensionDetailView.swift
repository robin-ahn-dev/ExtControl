import SwiftUI
import AppKit

struct ExtensionDetailView: View {
    @ObservedObject var store: AppStore
    let item: FileExtensionModel?

    @State private var candidates: [HandlerInfo] = []
    @State private var shared: [String] = []

    var body: some View {
        if let item {
            detail(for: item)
                .task(id: item.ext) { reload(item) }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.badge.gearshape")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("Endung auswählen").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func reload(_ item: FileExtensionModel) {
        var seen = Set<String>()
        var list: [HandlerInfo] = []
        for path in item.appPaths {
            guard let app = store.app(path: path), seen.insert(path).inserted else { continue }
            list.append(HandlerInfo(url: app.url, name: app.name, bundleID: app.bundleIdentifier))
        }
        for info in DefaultAppService.candidates(forExtension: item.ext)
        where seen.insert(info.url.path).inserted {
            list.append(info)
        }
        candidates = list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        shared = DefaultAppService.sharedExtensions(for: item.ext)
    }

    @ViewBuilder
    private func detail(for item: FileExtensionModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: item)
                Divider()

                Text("Öffnen mit")
                    .font(.headline)

                if candidates.isEmpty {
                    Text("Keine App gefunden, die \(item.dotted) unterstützt.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 4) {
                        ForEach(candidates) { app in
                            candidateRow(app, ext: item.ext)
                        }
                    }
                }

                Button("Andere App wählen …") { chooseApp(for: item.ext) }
                    .controlSize(.small)

                if !shared.isEmpty {
                    Label("Der Dateityp gilt auch für \(shared.map { ".\($0)" }.joined(separator: ", ")). macOS setzt die Standard-App pro Dateityp, nicht pro Endung.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func header(for item: FileExtensionModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(nsImage: IconCache.shared.icon(forExtension: item.ext, size: 56))
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.dotted).font(.title2.monospaced()).bold()
                    Text(item.utiJoined)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(3)
                }
            }
            if let current = store.handler(for: item.ext) {
                HStack(spacing: 6) {
                    Text("Standard:").font(.caption).foregroundStyle(.secondary)
                    Image(nsImage: IconCache.shared.icon(for: current.url.path, size: 16))
                        .resizable().frame(width: 16, height: 16)
                    Text(current.name).font(.caption).bold()
                }
            }
        }
    }

    private func candidateRow(_ app: HandlerInfo, ext: String) -> some View {
        let isCurrent = store.handler(for: ext)?.url.path == app.url.path
        return HStack(spacing: 8) {
            Image(nsImage: IconCache.shared.icon(for: app.url.path, size: 22))
                .resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).lineLimit(1)
                Text(app.bundleID).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            } else {
                Button("Standard") { store.setDefault(app: app.url, for: [ext]) }
                    .controlSize(.small)
            }
        }
        .padding(6)
        .background(isCurrent ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            Button("Im Finder zeigen") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
        }
    }

    private func chooseApp(for ext: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Als Standard setzen"
        if panel.runModal() == .OK, let url = panel.url {
            store.setDefault(app: url, for: [ext])
        }
    }
}
