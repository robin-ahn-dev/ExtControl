<p align="center">
  <img src="docs/icon.png" alt="ExtControl" width="128">
</p>

<h1 align="center">ExtControl</h1>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-black">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-orange">
  <img alt="UI" src="https://img.shields.io/badge/UI-SwiftUI-blue">
</p>

Standard-Apps für Dateiendungen auf macOS verwalten — in einer Liste statt einzeln über
den Finder-Infodialog.

macOS bietet keine zentrale Stelle, an der man sieht, welche App welche Dateiendung
öffnet. ExtControl scannt alle installierten Apps, dreht deren `CFBundleDocumentTypes`
um und zeigt pro Endung die aktuell zuständige App — änderbar per Klick, auch für
viele Endungen gleichzeitig.

<p align="center">
  <img src="docs/screenshot.png" alt="ExtControl – Endungs-Ansicht mit Detailbereich" width="900">
</p>

## Features

- **Endungs-Ansicht** — Tabelle aller gefundenen Dateiendungen mit aktueller Standard-App
- **Standard-App per Menü setzen** — direkt in der Tabellenzeile oder im Detailbereich
- **Mehrfachauswahl** — mehrere Endungen markieren, per Rechtsklick eine App für alle setzen
- **Filter „Nur gängige"** — kuratierte Liste (~230 Endungen) an/aus schalten
- **App-Ansicht** — umgekehrter Blick: eine App als Standard für *all* ihre Endungen setzen
- **Suche & Sortierung** — Live-Suche über Endung, UTI und App-Name; alle Spalten sortierbar
- **Beliebige App wählen** — Datei-Dialog für Apps, die die Endung nicht deklarieren

## Installation

Fertiges Bundle bauen:

```bash
git clone https://github.com/<user>/ExtControl.git
cd ExtControl
./build_app.sh
open dist/ExtControl.app
```

Oder direkt starten:

```bash
swift run -c release
```

Voraussetzungen: macOS 13+, Xcode Command Line Tools (Swift 5.9).

## Bedienung

| Aktion | Weg |
|---|---|
| Standard-App ändern | Klick auf App-Namen in Spalte **Standard-App** -> App wählen |
| Andere App wählen | Menü -> „Andere App wählen …" (Datei-Dialog) |
| Mehrere Endungen | Zeilen mit ⌘/⇧ markieren -> Rechtsklick -> „Standard-App für n Endung(en)" |
| Alle Endungen einer App | Ansicht **Nach App** -> Rechtsklick auf App |
| Filter umschalten | Toolbar-Button **Nur gängige** |
| Neu scannen | ⌘R |

## Wie es funktioniert

- **Scan:** parallele Suche (`TaskGroup`) nach `.app`-Bundles in `/Applications`,
  `/System/Applications`, `~/Applications`, `/System/Library/CoreServices` u. a.,
  plus laufende Apps über `NSWorkspace`
- **Endungen:** aus `CFBundleTypeExtensions` **und** aus `LSItemContentTypes`
  (UTI -> `UTType.tags[.filenameExtension]`)
- **Lesen:** `NSWorkspace.urlForApplication(toOpen:)` / `urlsForApplications(toOpen:)`
- **Schreiben:** `NSWorkspace.setDefaultApplication(at:toOpen:)` (macOS 15+),
  sonst `LSSetDefaultRoleHandlerForContentType`

## Wichtig zu wissen

macOS speichert Standard-Apps **pro Dateityp (UTI), nicht pro Endung**. Teilen sich
mehrere Endungen einen UTI (`.jpg` und `.jpeg` -> `public.jpeg`), gilt eine Änderung
für alle. Der Detailbereich weist auf betroffene Endungen hin.

Endungen ohne registrierten UTI bekommen von macOS einen dynamischen UTI
(`dyn.ah62d…`). Dort kann LaunchServices die Zuordnung ablehnen — Fehler erscheinen
als Dialog.

`LSDatabaseQuery` (vollständiger LaunchServices-Dump) ist private API und wird nicht
genutzt; ExtControl arbeitet mit Verzeichnis-Scan und öffentlichen APIs.

## Projektstruktur

| Datei | Zweck |
|---|---|
| `Model/AppExtensionModel.swift` | App + `CFBundleDocumentTypes` |
| `Model/FileExtensionModel.swift` | Endung -> UTIs + unterstützende Apps |
| `Model/CommonExtensions.swift` | Kuratierte Liste gängiger Endungen |
| `Services/AppScanner.swift` | Bundle-Scan, Info.plist-Parsing, `buildExtensionIndex` |
| `Services/DefaultAppService.swift` | LaunchServices: Handler lesen/setzen |
| `Services/AppStore.swift` | Ladezustand, Endungs-Index, Handler-Cache, Icon-Cache |
| `Views/ContentView.swift` | Modus-Umschalter + App-Tabelle |
| `Views/ExtensionListView.swift` | Endungs-Tabelle mit Inline-Menü |
| `Views/ExtensionDetailView.swift` | Detail: Kandidaten-Apps, Standard setzen |
| `Views/AppDetailView.swift` | Detail der App-Ansicht |
| `tools/MakeIcon.swift` | Rendert das App-Icon (`Resources/AppIcon.iconset`) |
| `docs/` | Icon und Screenshot für die README |

## Icon neu bauen

```bash
swift tools/MakeIcon.swift Resources/AppIcon.iconset
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
./build_app.sh
```

## Lizenz

MIT © 2026 Robin Ahn
