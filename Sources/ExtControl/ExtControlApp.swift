import SwiftUI
import AppKit

/// Erzwingt eine normale GUI-App (Dock-Icon + Fenster im Vordergrund).
/// Nötig, wenn das Binary ohne vollwertiges .app-Bundle läuft.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

/// Eigenes About-Fenster mit Autor und Kurzbeschreibung.
@MainActor
private func showAbout() {
    let text = "ExtControl – Standard-Apps für Dateiendungen verwalten.\n\n"
        + "Zeigt alle Dateiendungen des Systems mit der aktuell zuständigen App "
        + "und setzt die Standard-App per LaunchServices – einzeln oder für "
        + "mehrere Endungen gleichzeitig.\n\n"
        + "Entwickelt von Robin Ahn."

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let credits = NSAttributedString(string: text, attributes: [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: style
    ])

    let info = Bundle.main.infoDictionary
    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "ExtControl",
        .applicationVersion: info?["CFBundleShortVersionString"] as? String ?? "1.0",
        .version: info?["CFBundleVersion"] as? String ?? "1",
        .credits: credits,
        NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Robin Ahn"
    ])
    NSApp.activate(ignoringOtherApps: true)
}

@main
struct ExtControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 520)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("Über ExtControl") { showAbout() }
            }
        }
    }
}
