import SwiftUI
import AppKit

enum BrowseMode: String, CaseIterable, Identifiable {
    case extensions = "Nach Endung"
    case apps = "Nach App"
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var store = AppStore()

    @State private var mode: BrowseMode = .extensions
    @State private var searchText = ""
    @State private var extSelection: Set<String> = []
    @State private var onlyCommon = true
    @State private var appSelection: AppExtensionModel.ID?

    private var selectedExtension: FileExtensionModel? {
        guard extSelection.count == 1, let id = extSelection.first else { return nil }
        return store.extensions.first { $0.id == id }
    }

    private var selectedApp: AppExtensionModel? {
        guard let appSelection else { return nil }
        return store.app(path: appSelection)
    }

    var body: some View {
        NavigationSplitView {
            Group {
                switch mode {
                case .extensions:
                    ExtensionListView(store: store,
                                      searchText: $searchText,
                                      selection: $extSelection,
                                      onlyCommon: $onlyCommon)
                case .apps:
                    AppListView(store: store,
                                searchText: $searchText,
                                selection: $appSelection)
                }
            }
            .navigationSplitViewColumnWidth(min: 620, ideal: 860)
        } detail: {
            Group {
                switch mode {
                case .extensions:
                    ExtensionDetailView(store: store, item: selectedExtension)
                case .apps:
                    AppDetailView(app: selectedApp)
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 360)
        }
        .navigationTitle("")
        .searchable(text: $searchText, placement: .toolbar,
                    prompt: mode == .extensions ? "pdf, public.image, Preview …"
                                                : "App, Bundle-ID, .pdf …")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("Ansicht", selection: $mode) {
                    ForEach(BrowseMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if mode == .extensions {
                    Toggle(isOn: $onlyCommon) {
                        Label("Nur gängige", systemImage: onlyCommon
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                    }
                    .toggleStyle(.button)
                    .help("An: nur gängige Dateiendungen. Aus: alle gefundenen Endungen.")
                }

                Button {
                    store.refreshHandlers()
                } label: {
                    Label("Standard-Apps aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(store.isLoading)

                Button {
                    store.load()
                } label: {
                    Label("Neu scannen", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
                .keyboardShortcut("r")
            }
        }
        .alert("Standard-App konnte nicht gesetzt werden",
               isPresented: Binding(get: { store.lastError != nil },
                                    set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
        .task { store.load() }
    }
}

/// Alte App-zentrierte Tabelle als zweite Ansicht.
struct AppListView: View {
    @ObservedObject var store: AppStore
    @Binding var searchText: String
    @Binding var selection: AppExtensionModel.ID?

    @State private var onlyWithTypes = true
    @State private var sortOrder = [KeyPathComparator(\AppExtensionModel.name, order: .forward)]

    private var filteredApps: [AppExtensionModel] {
        store.apps
            .filter { !onlyWithTypes || !$0.fileExtensions.isEmpty }
            .filter { $0.matches(query: searchText) }
            .sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            Table(filteredApps, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("") { app in
                    Image(nsImage: IconCache.shared.icon(for: app.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .width(28)

                TableColumn("App", value: \.name, comparator: .localizedStandard) { app in
                    Text(app.name).fontWeight(.medium)
                }
                .width(min: 140, ideal: 190)

                TableColumn("Bundle-ID", value: \.bundleIdentifier, comparator: .localizedStandard) { app in
                    Text(app.bundleIdentifier)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .width(min: 160, ideal: 230)

                TableColumn("Typen", value: \.extensionCount) { app in
                    Text("\(app.extensionCount)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(46)

                TableColumn("Dateiendungen", value: \.extensionsJoined, comparator: .localizedStandard) { app in
                    Text(app.extensionsJoined)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(app.extensionsJoined)
                }
                .width(min: 200, ideal: 380)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: AppExtensionModel.ID.self) { ids in
                if let id = ids.first, let app = store.app(path: id) {
                    Button("Für alle Endungen dieser App zum Standard machen") {
                        store.setDefault(app: app.url, for: app.fileExtensions)
                    }
                    Button("Im Finder zeigen") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.url])
                    }
                    Button("Bundle-ID kopieren") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.bundleIdentifier, forType: .string)
                    }
                }
            }
            .overlay {
                if store.isLoading && store.apps.isEmpty {
                    ProgressView("Scanne Apps …", value: store.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                } else if !store.isLoading && filteredApps.isEmpty {
                    ContentUnavailableMessage(text: "Kein Treffer.")
                }
            }

            Divider()
            HStack(spacing: 12) {
                Toggle("Nur mit Dateitypen", isOn: $onlyWithTypes)
                    .toggleStyle(.checkbox)
                Text("\(filteredApps.count) von \(store.apps.count) Apps")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct ContentUnavailableMessage: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
    }
}
