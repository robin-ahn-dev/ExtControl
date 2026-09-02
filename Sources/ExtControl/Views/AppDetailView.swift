import SwiftUI
import AppKit

struct AppDetailView: View {
    let app: AppExtensionModel?

    var body: some View {
        if let app {
            detail(for: app)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
                Text("App auswählen")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func detail(for app: AppExtensionModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(for: app)
                Divider()

                if app.documentTypes.isEmpty {
                    Text("Keine Document Types in der Info.plist.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(app.documentTypes) { type in
                        typeSection(type)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func header(for app: AppExtensionModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: IconCache.shared.icon(for: app.path, size: 64))
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name).font(.title2).bold()
                    Text(app.bundleIdentifier)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Version \(app.version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(app.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)

            HStack {
                Button("Im Finder zeigen") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.url])
                }
                Button("Öffnen") {
                    NSWorkspace.shared.open(app.url)
                }
            }
            .controlSize(.small)

            if !app.fileExtensions.isEmpty {
                FlowTags(items: app.fileExtensions.map { ".\($0)" })
            }
        }
    }

    private func typeSection(_ type: DocumentTypeModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(type.name).font(.headline)
                Spacer()
                Text(type.role)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            row("Endungen", type.fileExtensions.map { ".\($0)" })
            row("UTIs", type.contentTypes)
            row("MIME", type.mimeTypes)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func row(_ label: String, _ values: [String]) -> some View {
        if !values.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 66, alignment: .leading)
                Text(values.joined(separator: ", "))
                    .font(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Simple umbrechende Tag-Liste.
struct FlowTags: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 4)], alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 5))
                    .lineLimit(1)
            }
        }
    }
}
