import Cocoa
import ApplicationServices

/// Detects selection changes in a Finder column-view window (keyboard, mouse, anything)
/// by polling a cheap Accessibility "fingerprint" while Finder is the frontmost app.
/// No keyboard/mouse event monitoring – and therefore no Input Monitoring permission – is needed.
final class SelectionWatcher {
    /// Called on an arbitrary thread when the selection changed.
    var onChange: () -> Void = {}

    private let lock = NSLock()
    private var _enabled = true
    private var _finderFrontmost = false

    var enabled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _enabled }
        set { lock.lock(); _enabled = newValue; lock.unlock() }
    }

    private var finderFrontmost: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _finderFrontmost }
        set { lock.lock(); _finderFrontmost = newValue; lock.unlock() }
    }

    // Only touched on `queue`.
    private let queue = DispatchQueue(label: "columnfit.selection-watcher", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var pid: pid_t?
    private var cachedWindow: AXUIElement?
    private var cachedBrowser: AXUIElement?
    private var last: String?

    private var observer: NSObjectProtocol?

    init() {
        finderFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == FinderInspector.bundleID
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.finderFrontmost = (app?.bundleIdentifier == FinderInspector.bundleID)
        }
    }

    deinit {
        timer?.cancel()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    func start() {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.5, repeating: 0.15, leeway: .milliseconds(30))
        t.setEventHandler { [weak self] in self?.poll() }
        t.resume()
        timer = t
    }

    private func finderPID() -> pid_t? {
        if let pid, let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated { return pid }
        pid = FinderInspector.runningApp?.processIdentifier
        return pid
    }

    private func poll() {
        guard enabled, finderFrontmost, AXIsProcessTrusted(), let pid = finderPID() else {
            last = nil          // when Finder comes back, the first reading is only a baseline
            return
        }

        let app = AXUIElementCreateApplication(pid)
        guard let ref = axAttr(app, "AXFocusedWindow") else { last = nil; return }
        let window = ref as! AXUIElement

        if let cached = cachedWindow {
            if CFEqual(cached, window) == false {          // another window → new baseline
                cachedWindow = window
                cachedBrowser = nil
                last = nil
            }
        } else {
            cachedWindow = window
        }

        // Searching the AX tree is comparatively expensive: cache the browser, re-find if it went stale.
        if let b = cachedBrowser, axRole(b) != "AXBrowser" { cachedBrowser = nil }
        if cachedBrowser == nil { cachedBrowser = findBrowser(in: window) }
        guard let browser = cachedBrowser else { last = nil; return }      // not in Column View

        let signature = selectionSignature(window: window, browser: browser)
        if let previous = last, previous != signature { onChange() }
        last = signature
    }
}
