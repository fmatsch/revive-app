import AppKit
import ServiceManagement

// MARK: - Autostart

struct AutostartService {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    static func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        }
    }

    static func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        }
    }

    static func toggle() -> Bool {
        do {
            if isEnabled { try disable() } else { try enable() }
            return isEnabled
        } catch {
            return isEnabled
        }
    }
}

// MARK: - Anti-Sleep (caffeinate)

class AntiSleepService {
    static let shared = AntiSleepService()
    private var process: Process?

    var isActive: Bool { process?.isRunning == true }

    func enable() {
        guard !isActive else { return }
        let p = Process()
        p.launchPath = "/usr/bin/caffeinate"
        p.arguments  = ["-d", "-i"]  // -d: no display sleep, -i: no idle sleep
        p.standardOutput = Pipe()
        p.standardError  = Pipe()
        try? p.run()
        process = p
    }

    func disable() {
        process?.terminate()
        process = nil
    }

    func toggle() -> Bool {
        isActive ? disable() : enable()
        return isActive
    }
}
