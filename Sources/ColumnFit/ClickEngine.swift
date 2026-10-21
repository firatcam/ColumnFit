import Cocoa
import CoreGraphics

/// Hides / shows the system pointer even though ColumnFit is a background (accessory) app.
///
/// Background apps are normally not allowed to hide the cursor. The widely used
/// "SetsCursorInBackground" connection property lifts that restriction. It is looked up
/// dynamically, so if a future macOS removes it the app still works – the pointer is simply
/// not hidden.
enum CursorHider {
    private static var prepared = false
    private static var hidden = false

    private static func allowBackgroundControl() {
        guard !prepared else { return }
        prepared = true

        typealias MainConnectionFn = @convention(c) () -> Int32
        typealias SetPropertyFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

        let path = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)          // RTLD_DEFAULT
        let handle = dlopen(path, RTLD_LAZY) ?? rtldDefault
        guard let mainSym = dlsym(handle, "CGSMainConnectionID"),
              let setSym = dlsym(handle, "CGSSetConnectionProperty") else { return }

        let connection = unsafeBitCast(mainSym, to: MainConnectionFn.self)()
        _ = unsafeBitCast(setSym, to: SetPropertyFn.self)(connection, connection,
                                                          "SetsCursorInBackground" as CFString,
                                                          kCFBooleanTrue)
    }

    static func hide() {
        guard !hidden else { return }
        allowBackgroundControl()
        _ = CGDisplayHideCursor(CGMainDisplayID())
        hidden = true
    }

    static func show() {
        guard hidden else { return }
        _ = CGDisplayShowCursor(CGMainDisplayID())
        hidden = false
    }
}

/// Performs the synthetic double-click on the column divider.
///
/// Finder has no command (and no Accessibility action) for "Right Size This Column"; the only
/// way to trigger it is a double-click on the column's resize handle. To keep that invisible:
///   1. the pointer is hidden,
///   2. the physical mouse is detached from the cursor, so hand movements cannot interfere,
///   3. the cursor jumps to the handle, double-clicks, and jumps back,
///   4. the mouse is re-attached and the pointer is shown again.
/// The whole sequence takes roughly 150–200 ms.
enum ClickEngine {
    private static let queue = DispatchQueue(label: "columnfit.click", qos: .userInteractive)

    static func doubleClick(at target: CGPoint,
                            gap: TimeInterval,
                            hidePointer: Bool,
                            completion: @escaping () -> Void) {
        queue.async {
            let source = CGEventSource(stateID: .hidSystemState)
            source?.localEventsSuppressionInterval = 0          // no input freeze after warping
            let saved = CGEvent(source: nil)?.location ?? target

            func post(_ type: CGEventType, at point: CGPoint, click: Int64 = 0) {
                guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                          mouseCursorPosition: point, mouseButton: .left) else { return }
                event.flags = []                                 // ignore held modifier keys (⌥ would resize ALL columns)
                if click > 0 { event.setIntegerValueField(.mouseEventClickState, value: click) }
                event.post(tap: .cghidEventTap)
            }
            func pause(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }

            if hidePointer { CursorHider.hide() }
            _ = CGAssociateMouseAndMouseCursorPosition(0)

            // Move onto the handle and let Finder register the hover.
            _ = CGWarpMouseCursorPosition(target)
            post(.mouseMoved, at: target)
            pause(0.040)

            // Double-click.
            post(.leftMouseDown, at: target, click: 1)
            pause(0.020)
            post(.leftMouseUp, at: target, click: 1)
            pause(gap)
            post(.leftMouseDown, at: target, click: 2)
            pause(0.020)
            post(.leftMouseUp, at: target, click: 2)
            pause(0.030)

            // Jump back where the user's pointer was.
            _ = CGWarpMouseCursorPosition(saved)
            post(.mouseMoved, at: saved)

            _ = CGAssociateMouseAndMouseCursorPosition(1)
            if hidePointer { CursorHider.show() }

            DispatchQueue.main.async(execute: completion)
        }
    }
}
