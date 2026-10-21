import Cocoa
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let watcher = SelectionWatcher()

    private var enabled = true {
        didSet { watcher.enabled = enabled }
    }
    private var pending: DispatchWorkItem?
    private var generation = 0              // bumped on every selection change; cancels stale requests
    private var isClicking = false

    private var marker: MarkerWindow?
    private var markerToken = 0
    private var calibration: CalibrationController?

    private var toggleItem: NSMenuItem!
    private var hideCursorItem: NSMenuItem!
    private var loginItem: NSMenuItem!

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If Finder is busy, don't let Accessibility calls hang for long.
        _ = AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "ColumnFit")
            image?.isTemplate = true
            button.image = image
        }
        statusItem.menu = buildMenu()

        requestAccessibility()

        watcher.onChange = { [weak self] in
            DispatchQueue.main.async { self?.schedule() }
        }
        watcher.start()
    }

    // MARK: Menu

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        return it
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        toggleItem = item(L10n.t(.autoOn), #selector(toggleEnabled))
        menu.addItem(toggleItem)
        menu.addItem(item(L10n.t(.resizeNow), #selector(applyNow)))
        hideCursorItem = item(L10n.t(.hideCursor), #selector(toggleHideCursor))
        menu.addItem(hideCursorItem)

        menu.addItem(.separator())
        menu.addItem(item(L10n.t(.calibrate), #selector(openCalibration)))
        menu.addItem(item(L10n.t(.diagnostics), #selector(showDiagnostics)))
        menu.addItem(item(L10n.t(.forceColumnView), #selector(forceColumnView)))

        menu.addItem(.separator())
        loginItem = item(L10n.t(.launchAtLogin), #selector(toggleLogin))
        menu.addItem(loginItem)
        menu.addItem(item(L10n.t(.openAccessibility), #selector(openAccessibilityPrefs)))

        let languageItem = NSMenuItem(title: L10n.t(.language), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for lang in Lang.allCases {
            let it = NSMenuItem(title: lang.nativeName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = lang.rawValue
            it.state = (lang == L10n.current) ? .on : .off
            languageMenu.addItem(it)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(.separator())
        menu.addItem(item(L10n.t(.about), #selector(showAbout)))
        let quit = NSMenuItem(title: L10n.t(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.title = enabled ? L10n.t(.autoOn) : L10n.t(.autoOff)
        toggleItem.state = enabled ? .on : .off
        hideCursorItem.state = Prefs.hideCursor ? .on : .off
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    // MARK: Menu actions

    @objc private func toggleEnabled() { enabled.toggle() }

    @objc private func toggleHideCursor() { Prefs.hideCursor.toggle() }

    @objc private func applyNow() { rightSizeLastColumn() }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let lang = Lang(rawValue: raw) else { return }
        Prefs.language = lang
        calibration?.close()
        calibration = nil
        statusItem.menu = buildMenu()
    }

    @objc private func openCalibration() {
        if calibration == nil {
            calibration = CalibrationController(
                showMarker: { [weak self] in self?.showMarker() ?? false },
                columnHeight: { FinderInspector.divider()?.height },
                test: { [weak self] in self?.rightSizeLastColumn() })
        }
        calibration?.show()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("ColumnFit: login item error: \(error)")
        }
    }

    @objc private func openAccessibilityPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func forceColumnView() {
        let alert = NSAlert()
        alert.messageText = L10n.t(.switchTitle)
        alert.informativeText = L10n.t(.switchInfo)
        alert.addButton(withTitle: L10n.t(.switchOK))
        alert.addButton(withTitle: L10n.t(.cancel))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        func run(_ path: String, _ args: [String]) {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: path)
            p.arguments = args
            try? p.run()
            p.waitUntilExit()
        }
        run("/usr/bin/defaults", ["write", "com.apple.finder", "FXPreferredViewStyle", "-string", "Clmv"])
        run("/usr/bin/killall", ["Finder"])
    }

    /// Technical read-out for bug reports (intentionally English only).
    @objc private func showDiagnostics() {
        var out: [String] = []
        out.append("Accessibility permission: \(AXIsProcessTrusted() ? "granted" : "MISSING")")

        if let window = FinderInspector.focusedWindow() {
            out.append("Window title: \(axAttr(window, "AXTitle") as? String ?? "-")")
            out.append("AXDocument: \(axAttr(window, "AXDocument") as? String ?? "-")")
            if let browser = findBrowser(in: window) {
                let columns = columnElements(of: browser)
                out.append("AXBrowser: found, \(columns.count) column(s)")
                for (i, c) in columns.enumerated() {
                    out.append("  column \(i): \(axFrame(c).map { NSStringFromRect($0) } ?? "no frame")")
                }
                out.append("Fingerprint: \(selectionSignature(window: window, browser: browser))")
            } else {
                out.append("AXBrowser: NOT FOUND (is the window in Column View?)")
            }
        } else {
            out.append("No Finder window could be read.")
        }

        if let d = FinderInspector.divider() {
            let p = d.point
            out.append("Divider: x=\(Int(d.x)) top=\(Int(d.top)) bottom=\(Int(d.bottom)) height=\(Int(d.height))")
            out.append("Click point: \(Int(p.x)), \(Int(p.y))")
        }
        out.append("Hide pointer: \(Prefs.hideCursor)")
        out.append("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")

        let alert = NSAlert()
        alert.messageText = "ColumnFit diagnostics"
        alert.informativeText = out.joined(separator: "\n")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Marker overlay (calibration)

    private func showMarker() -> Bool {
        guard let divider = FinderInspector.divider() else { return false }
        let point = divider.point

        if let m = marker {
            m.update(point: point, top: divider.top, bottom: divider.bottom)
        } else {
            marker = MarkerWindow(point: point, top: divider.top, bottom: divider.bottom)
        }
        marker?.orderFrontRegardless()

        markerToken += 1
        let token = markerToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.markerToken == token else { return }
            self.marker?.orderOut(nil)
            self.marker = nil
        }
        return true
    }

    // MARK: Resizing

    /// Selection changed: wait briefly (rapid key presses are coalesced), then resize.
    private func schedule() {
        generation += 1
        let gen = generation
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rightSizeLastColumn(gen: gen) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Prefs.settleDelay, execute: work)
    }

    /// `gen == nil` for manual calls (menu / calibration test).
    private func rightSizeLastColumn(gen: Int? = nil) {
        guard AXIsProcessTrusted() else { return }
        let gen = gen ?? generation

        // Finder not in front (e.g. "Test" in the calibration panel): bring it forward first.
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != FinderInspector.bundleID {
            FinderInspector.runningApp?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.performRightSize(attempt: 0, gen: gen)
            }
            return
        }
        performRightSize(attempt: 0, gen: gen)
    }

    private func performRightSize(attempt: Int, gen: Int) {
        guard gen == generation else { return }          // a newer selection superseded this request

        // Never interfere with a mouse button the user is holding, or with a running click.
        if isClicking || NSEvent.pressedMouseButtons != 0 {
            schedule()
            return
        }

        guard let divider = FinderInspector.divider() else {
            // While Finder scrolls to a newly opened column its edge can be off-screen for a moment.
            if attempt < 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.performRightSize(attempt: attempt + 1, gen: gen)
                }
            }
            return
        }

        isClicking = true
        ClickEngine.doubleClick(at: divider.point,
                                gap: Prefs.clickGap,
                                hidePointer: Prefs.hideCursor) { [weak self] in
            self?.isClicking = false
        }
    }
}
