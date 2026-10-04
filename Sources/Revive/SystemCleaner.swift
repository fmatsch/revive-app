import AppKit

enum CleanAction {
    case restartFinder
    case restartDock
    case flushDNS
    case purgeRAM
    case clearUserCaches
    case clearAppCaches
    case restartWindowManager
    case cleanRestart

    var label: String {
        switch self {
        case .restartFinder:        return "Finder neu starten"
        case .restartDock:          return "Dock neu starten"
        case .flushDNS:             return "DNS-Cache leeren"
        case .purgeRAM:             return "RAM freigeben (sudo)"
        case .clearUserCaches:      return "User-Caches leeren"
        case .clearAppCaches:       return "App-Caches leeren"
        case .restartWindowManager: return "WindowServer neu starten (Vorsicht!)"
        case .cleanRestart:         return "Sauber neustarten"
        }
    }
}

struct SystemCleaner {

    static func quickRefresh(completion: @escaping (String) -> Void) {
        var log: [String] = []
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global().async {
            run("killall Finder") ? log.append("✓ Finder neugestartet") : log.append("⚠ Finder konnte nicht neugestartet werden")
            group.leave()
        }

        group.enter()
        DispatchQueue.global().async {
            run("dscacheutil -flushcache")
            run("killall -HUP mDNSResponder")
            log.append("✓ DNS-Cache geleert")
            group.leave()
        }

        group.notify(queue: .main) {
            completion(log.joined(separator: "\n"))
        }
    }

    static func deepClean(completion: @escaping (String) -> Void) {
        var log: [String] = []

        // Sync actions first (no sudo)
        run("killall Finder")  ? log.append("✓ Finder neugestartet")   : ()
        run("killall Dock")    ? log.append("✓ Dock neugestartet")      : ()
        run("dscacheutil -flushcache") ; run("killall -HUP mDNSResponder")
        log.append("✓ DNS-Cache geleert")

        // purge needs admin rights — show macOS password dialog via AppleScript
        DispatchQueue.global().async {
            let src = "do shell script \"purge\" with administrator privileges"
            var error: NSDictionary?
            NSAppleScript(source: src)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                if error == nil {
                    log.append("✓ RAM-Purge abgeschlossen")
                } else {
                    log.append("⚠ Purge abgebrochen oder fehlgeschlagen")
                }
                completion(log.joined(separator: "\n"))
            }
        }
    }

    static func perform(_ action: CleanAction, completion: @escaping (String) -> Void) {
        switch action {
        case .restartFinder:
            run("killall Finder")
            completion("✓ Finder neugestartet")

        case .restartDock:
            run("killall Dock")
            completion("✓ Dock neugestartet")

        case .flushDNS:
            run("dscacheutil -flushcache")
            run("killall -HUP mDNSResponder")
            completion("✓ DNS-Cache geleert")

        case .purgeRAM:
            DispatchQueue.global().async {
                var error: NSDictionary?
                NSAppleScript(source: "do shell script \"purge\" with administrator privileges")?
                    .executeAndReturnError(&error)
                DispatchQueue.main.async {
                    completion(error == nil ? "✓ RAM-Purge abgeschlossen" : "⚠ Purge fehlgeschlagen")
                }
            }

        case .clearUserCaches:
            let freed = clearDirectory(
                FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!,
                skip: []
            )
            completion("✓ User-Caches geleert (\(formatBytes(freed)))")

        case .clearAppCaches:
            DispatchQueue.global().async {
                let fm = FileManager.default
                let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!

                // Only clear contents of per-app cache folders, not the folders themselves
                let skipBundles: Set<String> = [
                    "com.apple.bird",          // iCloud daemon
                    "com.apple.MediaAnalysis", // Photos ML
                    "com.apple.containermanagerd"
                ]

                var totalFreed: Int64 = 0
                var appCount = 0

                if let appDirs = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.isDirectoryKey]) {
                    for appDir in appDirs {
                        let name = appDir.lastPathComponent
                        guard skipBundles.contains(name) == false else { continue }
                        guard (try? appDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

                        // Clear contents but keep the folder itself
                        if let contents = try? fm.contentsOfDirectory(at: appDir, includingPropertiesForKeys: [.fileSizeKey, .totalFileSizeKey]) {
                            for item in contents {
                                let size = Int64((try? fm.allocatedSizeOf(item)) ?? 0)
                                if (try? fm.removeItem(at: item)) != nil {
                                    totalFreed += size
                                }
                            }
                            appCount += 1
                        }
                    }
                }

                DispatchQueue.main.async {
                    completion("✓ App-Caches geleert – \(appCount) Apps, \(formatBytes(Int(totalFreed))) freigegeben")
                }
            }

        case .restartWindowManager:
            // This logs the user out visually — warn before using
            run("killall -KILL WindowServer")
            completion("WindowServer neugestartet")

        case .cleanRestart:
            // Disable window restore, then restart via AppleScript (shows macOS restart dialog)
            DispatchQueue.global().async {
                // Temporarily turn off "Reopen windows when logging back in"
                run("defaults write com.apple.loginwindow TALLogoutSavesState -bool false")
                run("defaults write com.apple.loginwindow LoginwindowLaunchesRelaunchApps -bool false")
                var error: NSDictionary?
                let script = """
                    tell application "System Events"
                        restart
                    end tell
                    """
                NSAppleScript(source: script)?.executeAndReturnError(&error)
                if error != nil {
                    // Restore defaults if restart was cancelled
                    run("defaults delete com.apple.loginwindow TALLogoutSavesState")
                    run("defaults delete com.apple.loginwindow LoginwindowLaunchesRelaunchApps")
                    DispatchQueue.main.async { completion("⚠ Neustart abgebrochen") }
                }
            }
        }
    }

    @discardableResult
    private static func run(_ command: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments  = ["-c", command]
        task.standardOutput = Pipe()
        task.standardError  = Pipe()
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    // Deletes all items inside `dir`, optionally skipping entries by lastPathComponent.
    // Returns total bytes freed (best-effort).
    private static func clearDirectory(_ dir: URL, skip: Set<String>) -> Int {
        let fm = FileManager.default
        var freed = 0
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        for item in items {
            guard !skip.contains(item.lastPathComponent) else { continue }
            freed += (try? fm.allocatedSizeOf(item)) ?? 0
            try? fm.removeItem(at: item)
        }
        return freed
    }
}

private func formatBytes(_ bytes: Int) -> String {
    if bytes >= 1_073_741_824 { return String(format: "%.1f GB", Double(bytes) / 1_073_741_824) }
    if bytes >= 1_048_576     { return String(format: "%.0f MB", Double(bytes) / 1_048_576) }
    return "\(bytes / 1024) KB"
}

extension FileManager {
    func allocatedSizeOf(_ url: URL) throws -> Int {
        var total: Int64 = 0
        if let enumerator = enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) {
            for case let fileURL as URL in enumerator {
                let vals = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
                total += Int64(vals.totalFileAllocatedSize ?? vals.fileAllocatedSize ?? 0)
            }
        }
        return Int(total)
    }
}
