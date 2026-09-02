import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExtensionListView: View {
    @ObservedObject var store: AppStore
    @Binding var searchText: String
    @Binding var selection: Set<String>
    @Binding var onlyCommon: Bool

    @State private var sortOrder = [KeyPathComparator(\ExtensionRow.id, comparator: .localizedStandard, order: .forward)]

    var items: [ExtensionRow] {
        store.extensions
            .filter { !onlyCommon || CommonExtensions.contains($0.ext) }
            .filter { $0.matches(query: searchText) }
            .map { ExtensionRow(model: $0, handler: store.handler(for: $0.ext)) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            Table(items, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { (item: ExtensionRow) in
                    Image(nsImage: IconCache.shared.icon(forExtension: item.ext, size: 20))
                        .resizable()
                        .frame(width: 18, height: 18)
                }
                .width(26)

                TableColumn("Endung", value: \.id, comparator: .localizedStandard) { (item: ExtensionRow) in
                    Text(item.dotted)
                        .font(.body.monospaced())
                        .fontWeight(.medium)
                }
                .width(min: 80, ideal: 110)

                TableColumn("Standard-App", value: \.handlerSortKey, comparator: .localizedStandard) { (item: ExtensionRow) in
                    DefaultAppCell(store: store, item: item.model)
                }
                .width(min: 180, ideal: 230)

                TableColumn("Apps", value: \.appCount) { (item: ExtensionRow) in
                    Text("\(item.appCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(46)

                TableColumn("Unterstützt von", value: \.appsJoined, comparator: .localizedStandard) { (item: ExtensionRow) in
                    Text(item.appsJoined)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.secondary)
                        .help(item.appsJoined)
                }
                .width(min: 160, ideal: 300)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: String.self) { ids in
                contextMenu(for: ids)
            }
            .overlay { overlay }

            Divider()
            statusBar
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<String>) -> some View {
        let targets = ids.isEmpty ? selection : ids
        if !targets.isEmpty {
            let apps = candidateApps(for: targets)
            Menu("Standard-App für \(targets.count) Endung(en)") {
                ForEach(apps) { app in
                    Button(app.name) { store.setDefault(app: app.url, for: Array(targets)) }
                }
                if apps.isEmpty { Text("Keine bekannten Apps") }
                Divider()
                Button("Andere App wählen …") { chooseApp(for: Array(targets)) }
            }
            Button("Endungen kopieren") {
                copy(targets.sorted().map { ".\($0)" }.joined(separator: " "))
            }
        }
    }

    /// Apps, die alle gewählten Endungen unterstützen; sonst alle beteiligten Apps.
    private func candidateApps(for exts: Set<String>) -> [HandlerInfo] {
        let models = store.extensions.filter { exts.contains($0.ext) }
        guard let first = models.first else { return [] }
        var common = Set(first.appPaths)
        for model in models.dropFirst() { common.formIntersection(model.appPaths) }
        let paths = common.isEmpty ? Set(models.flatMap(\.appPaths)) : common
        return paths
            .compactMap { store.app(path: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { HandlerInfo(url: $0.url, name: $0.name, bundleID: $0.bundleIdentifier) }
    }

    private func chooseApp(for exts: [String]) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Als Standard setzen"
        if panel.runModal() == .OK, let url = panel.url {
            store.setDefault(app: url, for: exts)
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if store.isLoading && store.extensions.isEmpty {
            ProgressView("Scanne Apps …", value: store.progress)
                .progressViewStyle(.linear)
                .frame(width: 240)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        } else if !store.isLoading && items.isEmpty {
            ContentUnavailableMessage(text: searchText.isEmpty
                ? (onlyCommon ? "Keine gängigen Endungen gefunden." : "Keine Endungen gefunden.")
                : "Kein Treffer für „\(searchText)“.")
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if store.isLoading {
                ProgressView().controlSize(.small)
                Text("\(store.scannedCount)/\(store.totalCount)").monospacedDigit()
            }
            Text("\(items.count) von \(store.extensions.count) Endungen")
            if onlyCommon {
                Text("·")
                Text("Filter: nur gängige")
            }
            Text("·")
            Text("\(store.apps.count) Apps")
            if selection.count > 1 {
                Text("·")
                Text("\(selection.count) ausgewählt")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

/// Tabellenzeile: Endung + aktuell gesetzte Standard-App (für Sortierung).
struct ExtensionRow: Identifiable, Hashable {
    let model: FileExtensionModel
    let handler: HandlerInfo?

    var id: String { model.id }
    var ext: String { model.ext }
    var dotted: String { model.dotted }
    var appCount: Int { model.appCount }
    var appsJoined: String { model.appsJoined }
    var utiJoined: String { model.utiJoined }

    /// Endungen ohne Standard-App sortieren ans Ende.
    var handlerSortKey: String { handler.map { "0\($0.name)" } ?? "1" }
}

/// Zelle mit aktueller Standard-App + Menü zum Umstellen.
struct DefaultAppCell: View {
    @ObservedObject var store: AppStore
    let item: FileExtensionModel

    private var current: HandlerInfo? { store.handler(for: item.ext) }

    var body: some View {
        Menu {
            ForEach(item.appPaths, id: \.self) { path in
                if let app = store.app(path: path) {
                    Button {
                        store.setDefault(app: app.url, for: [item.ext])
                    } label: {
                        if app.path == current?.url.path {
                            Label(app.name, systemImage: "checkmark")
                        } else {
                            Text(app.name)
                        }
                    }
                }
            }
            Divider()
            Button("Andere App wählen …") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.application]
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                panel.prompt = "Als Standard setzen"
                if panel.runModal() == .OK, let url = panel.url {
                    store.setDefault(app: url, for: [item.ext])
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let current {
                    Image(nsImage: IconCache.shared.icon(for: current.url.path, size: 16))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(current.name).lineLimit(1)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
