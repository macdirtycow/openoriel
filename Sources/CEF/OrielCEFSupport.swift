import Foundation

/// Chromium Native (Blink) availability — filesystem + compile-flag checks.
enum OrielCEFSupport {
    static var frameworkURL: URL? {
        #if os(macOS)
        let fm = FileManager.default
        if let privateFrameworks = Bundle.main.privateFrameworksURL {
            let bundled = privateFrameworks.appendingPathComponent("Chromium Embedded Framework.framework")
            if fm.fileExists(atPath: bundled.path) { return bundled }
        }
        let beside = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Frameworks/Chromium Embedded Framework.framework")
        if fm.fileExists(atPath: beside.path) { return beside }
        if let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            let candidate = support
                .appendingPathComponent("Oriel", isDirectory: true)
                .appendingPathComponent("CEF", isDirectory: true)
                .appendingPathComponent("Chromium Embedded Framework.framework", isDirectory: true)
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
        #else
        return nil
        #endif
    }

    static var isFrameworkOnDisk: Bool { frameworkURL != nil }

    static var isEmbeddedHostingCompiled: Bool {
        #if ORIEL_HAS_CEF
        #if os(macOS)
        true
        #else
        false
        #endif
        #else
        false
        #endif
    }

    static var isReady: Bool {
        isFrameworkOnDisk && isEmbeddedHostingCompiled
    }

    static var statusSummary: String {
        #if os(iOS)
        return "CEF / Blink Native is Mac-only. iPhone and iPad stay on WebKit."
        #else
        if !isFrameworkOnDisk {
            return "CEF framework not installed. Run Scripts/fetch-cef-macos.sh."
        }
        if !isEmbeddedHostingCompiled {
            return "CEF framework on disk, but this binary was not built with ORIEL_HAS_CEF. Run Scripts/enable-cef-macos.sh and rebuild the Mac target."
        }
        return "Embedded CEF ready — Chromium Native paints Blink inside Oriel tabs."
        #endif
    }
}
