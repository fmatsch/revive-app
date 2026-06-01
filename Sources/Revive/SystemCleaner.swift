import AppKit

enum CleanAction {
    case restartFinder
    case restartDock
    case flushDNS
    case purgeRAM
    case clearUserCaches
    case restartWindowManager

    var label: String {
        switch self {
        case .restartFinder:        return "Finder neu starten"
        case .restartDock:          return "Dock neu starten"
        case .flushDNS:             return "DNS-Cache leeren"
        case .purgeRAM:             return "RAM freigeben (sudo)"
        case .clearUserCaches:      return "User-Caches leeren"
        case .restartWindowManager: return "WindowServer neu starten (Vorsicht!)"
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
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            var freed = 0
            let fm = FileManager.default
            if let items = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
                for item in items {
                    if let size = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        freed += size
                    }
                    try? fm.removeItem(at: item)
                }
            }
            let mb = freed / 1_048_576
            completion("✓ User-Caches geleert (~\(mb) MB)")

        case .restartWindowManager:
            // This logs the user out visually — warn before using
            run("killall -KILL WindowServer")
            completion("WindowServer neugestartet")
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
}
