import Cocoa
import ApplicationServices

// MARK: - Low-level Accessibility helpers

func axAttr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
}

func axChildren(_ el: AXUIElement) -> [AXUIElement] {
    (axAttr(el, "AXChildren") as? [AXUIElement]) ?? []
}

func axRole(_ el: AXUIElement) -> String? {
    axAttr(el, "AXRole") as? String
}

func axFrame(_ el: AXUIElement) -> CGRect? {
    guard let v = axAttr(el, "AXFrame"), CFGetTypeID(v) == AXValueGetTypeID() else { return nil }
    var rect = CGRect.zero
    return AXValueGetValue(v as! AXValue, .cgRect, &rect) ? rect : nil
}

/// Depth-first search for the column-view container (`AXBrowser`).
func findBrowser(in el: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if axRole(el) == "AXBrowser" { return el }
    if depth > 10 { return nil }
    for child in axChildren(el) {
        if let found = findBrowser(in: child, depth: depth + 1) { return found }
    }
    return nil
}

func columnElements(of browser: AXUIElement) -> [AXUIElement] {
    let columns = (axAttr(browser, "AXColumns") as? [AXUIElement]) ?? []
    if !columns.isEmpty { return columns }
    return axChildren(browser).filter { axRole($0) == "AXScrollArea" }
}

func firstList(in el: AXUIElement, depth: Int = 0) -> AXUIElement? {
    if let role = axRole(el), role == "AXList" || role == "AXOutline" { return el }
    if depth > 3 { return nil }
    for child in axChildren(el) {
        if let found = firstList(in: child, depth: depth + 1) { return found }
    }
    return nil
}

/// A small "fingerprint" of the current selection: window title (name of the selected folder),
/// document path, and the position of the selected row in every column.
/// Column *widths* are deliberately not part of it, so our own resizing never re-triggers.
func selectionSignature(window: AXUIElement, browser: AXUIElement) -> String {
    let title = axAttr(window, "AXTitle") as? String ?? ""
    let doc = axAttr(window, "AXDocument") as? String ?? ""
    var parts: [String] = []
    for column in columnElements(of: browser) {
        var ys: [String] = []
        if let list = firstList(in: column),
           let rows = axAttr(list, "AXSelectedRows") as? [AXUIElement] {
            for row in rows {
                if let f = axFrame(row) { ys.append(String(Int(f.minY))) }
            }
        }
        parts.append(ys.joined(separator: ","))
    }
    return "\(title)|\(doc)|\(parts.joined(separator: ";"))"
}

// MARK: - Finder geometry

enum FinderInspector {
    static let bundleID = "com.apple.finder"

    static var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    static func focusedWindow() -> AXUIElement? {
        guard let app = runningApp else { return nil }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        guard let w = axAttr(ax, "AXFocusedWindow") ?? axAttr(ax, "AXMainWindow") else { return nil }
        return (w as! AXUIElement)
    }

    /// The vertical divider line at the right edge of the right-most column.
    /// Coordinates are global screen points with the origin at the top-left (same as CGEvent).
    struct Divider {
        let x: CGFloat
        let top: CGFloat
        let bottom: CGFloat

        var height: CGFloat { bottom - top }

        /// The click point chosen in the calibration panel, anywhere along the line.
        var point: CGPoint {
            let offset = CGFloat(Prefs.yOffset)
            var y = Prefs.yFromTop ? top + offset : bottom - offset
            y = min(max(y, top + 1), bottom - 1)
            return CGPoint(x: x, y: y)
        }
    }

    static func divider() -> Divider? {
        guard AXIsProcessTrusted(),
              let window = focusedWindow(),
              let browser = findBrowser(in: window) else { return nil }

        let frames = columnElements(of: browser).compactMap { axFrame($0) }
        guard let last = frames.max(by: { $0.maxX < $1.maxX }) else { return nil }

        // While Finder is still scrolling, the column's edge can be outside the visible area.
        if let bf = axFrame(browser), last.maxX > bf.maxX + 2 { return nil }

        return Divider(x: last.maxX + CGFloat(Prefs.offsetX), top: last.minY, bottom: last.maxY)
    }
}
