import Foundation

/// User-adjustable settings, persisted in UserDefaults.
enum Prefs {
    private static let d = UserDefaults.standard

    private static func double(_ key: String, _ fallback: Double) -> Double {
        d.object(forKey: key) as? Double ?? fallback
    }

    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) as? Bool ?? fallback
    }

    /// Horizontal shift of the click point relative to the column's right edge (px). Negative = left.
    static var offsetX: Double {
        get { double("offsetX", -4) }
        set { d.set(newValue, forKey: "offsetX") }
    }

    /// Vertical click position along the divider line, in px measured from the bottom edge
    /// (or from the top edge when `yFromTop` is true). The calibration panel decides which one
    /// to use, so any point from the very bottom to the very top of the line can be chosen.
    static var yOffset: Double {
        get { double("yOffset", double("offsetBottom", 8)) }
        set { d.set(newValue, forKey: "yOffset") }
    }

    static var yFromTop: Bool {
        get { bool("yFromTop", false) }
        set { d.set(newValue, forKey: "yFromTop") }
    }

    /// Time between the two clicks of the double-click (seconds).
    static var clickGap: Double {
        get { double("clickGap", 0.08) }
        set { d.set(newValue, forKey: "clickGap") }
    }

    /// Delay between a selection change and the resize (seconds).
    static var settleDelay: Double {
        get { double("settleDelay2", 0.25) }
        set { d.set(newValue, forKey: "settleDelay2") }
    }

    /// Hide the mouse pointer while the synthetic double-click is performed.
    static var hideCursor: Bool {
        get { bool("hideCursor", true) }
        set { d.set(newValue, forKey: "hideCursor") }
    }

    /// UI language. English is the default.
    static var language: Lang {
        get { Lang(rawValue: d.string(forKey: "language") ?? "") ?? .en }
        set { d.set(newValue.rawValue, forKey: "language") }
    }
}
