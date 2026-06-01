import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private var statsMenuItem: NSMenuItem!
    private var swapMenuItem: NSMenuItem!
    private var lastResultMenuItem: NSMenuItem!
    private var timer: Timer?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        setupButton()
        buildMenu()
        startStatsTimer()
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }
        button.image = ReviveIcon.menuBarImage()
        button.toolTip = "Revive – System auffrischen"
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Header: App name
        let titleItem = NSMenuItem(title: "⚡ Revive", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor
        ]
        titleItem.attributedTitle = NSAttributedString(string: "⚡ Revive", attributes: titleAttrs)
        menu.addItem(titleItem)

        menu.addItem(.separator())

        // Live memory stats
        statsMenuItem = NSMenuItem(title: "RAM: …", action: nil, keyEquivalent: "")
        statsMenuItem.isEnabled = false
        menu.addItem(statsMenuItem)

        swapMenuItem = NSMenuItem(title: "Swap: …", action: nil, keyEquivalent: "")
        swapMenuItem.isEnabled = false
        menu.addItem(swapMenuItem)

        menu.addItem(.separator())

        // Main actions
        menu.addItem(makeItem("⚡ Quick Refresh", #selector(quickRefresh), "r"))
        menu.addItem(makeItem("🧹 Deep Clean  (sudo)", #selector(deepClean), "d"))

        menu.addItem(.separator())

        // Individual actions submenu
        let sub = NSMenu()
        sub.addItem(makeItem("Finder neu starten",    #selector(restartFinder),   ""))
        sub.addItem(makeItem("Dock neu starten",       #selector(restartDock),     ""))
        sub.addItem(makeItem("DNS-Cache leeren",       #selector(flushDNS),        ""))
        sub.addItem(makeItem("RAM-Purge (sudo)",       #selector(purgeRAM),        ""))
        sub.addItem(makeItem("User-Caches leeren",     #selector(clearCaches),     ""))

        let subParent = NSMenuItem(title: "Einzelaktionen", action: nil, keyEquivalent: "")
        menu.addItem(subParent)
        menu.setSubmenu(sub, for: subParent)

        menu.addItem(.separator())

        // Last result feedback
        lastResultMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        lastResultMenuItem.isEnabled = false
        lastResultMenuItem.isHidden = true
        menu.addItem(lastResultMenuItem)

        menu.addItem(.separator())
        menu.addItem(makeItem("Beenden", #selector(quitApp), "q"))

        statusItem.menu = menu
        updateStats()
    }

    // MARK: - Stats

    private func startStatsTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    private func updateStats() {
        let s = MemoryStats.current()
        statsMenuItem.title = String(
            format: "%@ RAM: %.1f / %.0f GB  (%d%%)",
            s.pressureEmoji, s.usedGB, s.totalGB, s.pressurePercent
        )
        let swapIcon = s.swapUsedGB > 1.0 ? "🔴" : "🟢"
        swapMenuItem.title = String(
            format: "%@ Swap: %.1f GB genutzt",
            swapIcon, s.swapUsedGB
        )
    }

    // MARK: - Actions

    @objc private func quickRefresh() {
        setButtonSpinning(true)
        SystemCleaner.quickRefresh { [weak self] result in
            self?.setButtonSpinning(false)
            self?.showResult(result)
            self?.updateStats()
        }
    }

    @objc private func deepClean() {
        setButtonSpinning(true)
        SystemCleaner.deepClean { [weak self] result in
            self?.setButtonSpinning(false)
            self?.showResult(result)
            self?.updateStats()
        }
    }

    @objc private func restartFinder() {
        SystemCleaner.perform(.restartFinder) { [weak self] r in self?.showResult(r) }
    }

    @objc private func restartDock() {
        SystemCleaner.perform(.restartDock) { [weak self] r in self?.showResult(r) }
    }

    @objc private func flushDNS() {
        SystemCleaner.perform(.flushDNS) { [weak self] r in self?.showResult(r) }
    }

    @objc private func purgeRAM() {
        setButtonSpinning(true)
        SystemCleaner.perform(.purgeRAM) { [weak self] r in
            self?.setButtonSpinning(false)
            self?.showResult(r)
            self?.updateStats()
        }
    }

    @objc private func clearCaches() {
        SystemCleaner.perform(.clearUserCaches) { [weak self] r in self?.showResult(r) }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - UI Helpers

    private func makeItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func showResult(_ text: String) {
        lastResultMenuItem.title = text
        lastResultMenuItem.isHidden = false

        // Auto-hide after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.lastResultMenuItem.isHidden = true
        }
    }

    private func setButtonSpinning(_ on: Bool) {
        guard let button = statusItem.button else { return }
        if on {
            let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            let img = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: nil)!
                .withSymbolConfiguration(cfg)!
            img.isTemplate = true
            button.image = img
        } else {
            button.image = ReviveIcon.menuBarImage()
        }
    }
}
