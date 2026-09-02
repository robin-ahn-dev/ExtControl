import Foundation

/// Kuratierte Liste gängiger Dateiendungen für den Filter „Nur gängige“.
enum CommonExtensions {
    static let set: Set<String> = [
        // Text & Dokumente
        "txt", "rtf", "rtfd", "md", "markdown", "pdf", "doc", "docx", "odt", "pages",
        "xls", "xlsx", "ods", "numbers", "csv", "tsv", "ppt", "pptx", "odp", "key",
        "epub", "mobi", "azw3", "djvu", "tex", "log",
        // Bilder
        "jpg", "jpeg", "png", "gif", "bmp", "tif", "tiff", "webp", "heic", "heif",
        "avif", "svg", "ico", "icns", "psd", "ai", "eps", "raw", "cr2", "nef", "arw",
        "dng", "sketch",
        // Audio
        "mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg", "opus", "wma",
        "alac", "mid", "midi", "m4b", "m3u", "m3u8",
        // Video
        "mp4", "m4v", "mov", "avi", "mkv", "webm", "flv", "wmv", "mpg", "mpeg",
        "3gp", "ts", "vob", "srt", "vtt", "ass",
        // Archive & Images
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "dmg", "iso",
        "pkg", "cab",
        // Code & Web
        "html", "htm", "css", "scss", "sass", "less", "js", "mjs", "cjs", "jsx",
        "ts", "tsx", "json", "jsonc", "xml", "yaml", "yml", "toml", "ini", "conf",
        "env", "sql", "graphql",
        "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "cxx", "java", "kt", "kts",
        "py", "rb", "php", "go", "rs", "cs", "dart", "lua", "pl", "r", "scala",
        "sh", "bash", "zsh", "fish", "bat", "ps1", "vim",
        // System & Sonstiges
        "app", "plist", "dylib", "framework", "kext", "command", "webloc", "url",
        "torrent", "vcf", "ics", "eml", "msg", "mbox", "otf", "ttf", "ttc", "woff",
        "woff2", "sqlite", "db", "bak", "tmp", "part", "crdownload",
        "stl", "obj", "fbx", "gltf", "glb", "usdz", "blend",
        "gpx", "kml", "kmz", "geojson", "dwg", "dxf",
        "pem", "crt", "cer", "key", "p12", "pfx", "gpg", "asc", "sig"
    ]

    static func contains(_ ext: String) -> Bool { set.contains(ext.lowercased()) }
}
