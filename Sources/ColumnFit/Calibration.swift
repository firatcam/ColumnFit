import Cocoa

// MARK: - Marker overlay (divider line + click point)

final class MarkerView: NSView {
    var pointY: CGFloat = 0     // view coordinates (origin bottom-left)
    var lineFrom: CGFloat = 0
    var lineTo: CGFloat = 0

    override func draw(_ dirtyRect: NSRect) {
        let cx = bounds.midX

        // The divider line over its full height.
        NSColor.systemRed.withAlphaComponent(0.55).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: cx, y: lineFrom))
        line.line(to: NSPoint(x: cx, y: lineTo))
        line.lineWidth = 1.5
        line.stroke()

        // The chosen click point on that line.
        NSColor.systemRed.setStroke()
        NSColor.systemRed.setFill()

        let ring = NSBezierPath(ovalIn: NSRect(x: cx - 8, y: pointY - 8, width: 16, height: 16))
        ring.lineWidth = 2
        ring.stroke()

        let ticks = NSBezierPath()
        ticks.move(to: NSPoint(x: cx - 18, y: pointY)); ticks.line(to: NSPoint(x: cx + 18, y: pointY))
        ticks.lineWidth = 1
        ticks.stroke()

        NSBezierPath(ovalIn: NSRect(x: cx - 1.5, y: pointY - 1.5, width: 3, height: 3)).fill()
    }
}

final class MarkerWindow: NSWindow {
    private let pad: CGFloat = 20
    private let markerView: MarkerView

    init(point: CGPoint, top: CGFloat, bottom: CGFloat) {
        markerView = MarkerView(frame: .zero)
        super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = markerView
        update(point: point, top: top, bottom: bottom)
    }

    /// `point`, `top`, `bottom` are global screen coordinates with a top-left origin (as used by Accessibility).
    func update(point: CGPoint, top: CGFloat, bottom: CGFloat) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let lineLength = bottom - top
        let frame = NSRect(x: point.x - pad,
                           y: primaryHeight - bottom - pad,          // top-left → bottom-left origin
                           width: pad * 2,
                           height: lineLength + pad * 2)
        setFrame(frame, display: false)
        markerView.frame = NSRect(origin: .zero, size: frame.size)
        markerView.lineFrom = pad
        markerView.lineTo = pad + lineLength
        markerView.pointY = (bottom - point.y) + pad
        markerView.needsDisplay = true
    }
}

// MARK: - Calibration panel

final class SliderRow: NSStackView {
    let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    let valueLabel = NSTextField(labelWithString: "0")
    let stepper = NSStepper()

    init(title: String) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 4

        let label = NSTextField(labelWithString: title)

        slider.isContinuous = true
        slider.widthAnchor.constraint(equalToConstant: 260).isActive = true

        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        stepper.increment = 1
        stepper.minValue = 0

        let controls = NSStackView(views: [slider, valueLabel, stepper])
        controls.orientation = .horizontal
        controls.spacing = 8

        addArrangedSubview(label)
        addArrangedSubview(controls)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class StepperRow: NSStackView {
    private let valueLabel = NSTextField(labelWithString: "")
    private let stepper = NSStepper()
    private let onChange: (Double) -> Void

    init(title: String, min: Double, max: Double, step: Double, value: Double,
         onChange: @escaping (Double) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 8

        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 250).isActive = true

        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = step
        stepper.doubleValue = value
        stepper.target = self
        stepper.action = #selector(changed)

        valueLabel.alignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        valueLabel.stringValue = String(Int(value))

        addArrangedSubview(label)
        addArrangedSubview(valueLabel)
        addArrangedSubview(stepper)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func changed() {
        valueLabel.stringValue = String(Int(stepper.doubleValue))
        onChange(stepper.doubleValue)
    }
}

final class CalibrationController: NSObject {
    private let panel: NSPanel
    private let status = NSTextField(wrappingLabelWithString: "")
    private let yRow = SliderRow(title: L10n.t(.calY))

    private let showMarker: () -> Bool
    private let columnHeight: () -> CGFloat?
    private let test: () -> Void

    /// Height (px) of the divider line = the range of the vertical position slider.
    private var height: Double = 400

    init(showMarker: @escaping () -> Bool,
         columnHeight: @escaping () -> CGFloat?,
         test: @escaping () -> Void) {
        self.showMarker = showMarker
        self.columnHeight = columnHeight
        self.test = test
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                        styleMask: [.titled, .closable, .utilityWindow],
                        backing: .buffered, defer: false)
        super.init()

        panel.title = L10n.t(.calTitle)
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        let help = NSTextField(wrappingLabelWithString: L10n.t(.calHelp))
        help.font = .systemFont(ofSize: 11)
        help.preferredMaxLayoutWidth = 388

        let xRow = StepperRow(title: L10n.t(.calX), min: -40, max: 40, step: 1,
                              value: Prefs.offsetX) { [weak self] v in
            Prefs.offsetX = v
            self?.updateMarker()
        }

        yRow.slider.target = self
        yRow.slider.action = #selector(ySliderChanged)
        yRow.stepper.target = self
        yRow.stepper.action = #selector(yStepperChanged)

        let gapRow = StepperRow(title: L10n.t(.calGap), min: 30, max: 300, step: 10,
                                value: Prefs.clickGap * 1000) { v in
            Prefs.clickGap = v / 1000
        }
        let settleRow = StepperRow(title: L10n.t(.calSettle), min: 100, max: 1000, step: 50,
                                   value: Prefs.settleDelay * 1000) { v in
            Prefs.settleDelay = v / 1000
        }

        let showButton = NSButton(title: L10n.t(.calShow), target: self, action: #selector(showTapped))
        let testButton = NSButton(title: L10n.t(.calTest), target: self, action: #selector(testTapped))
        let buttons = NSStackView(views: [showButton, testButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10

        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.preferredMaxLayoutWidth = 388

        let stack = NSStackView(views: [help, xRow, yRow, gapRow, settleRow, buttons, status])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        panel.contentView = stack
        panel.setContentSize(stack.fittingSize)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        refresh()
    }

    func close() {
        panel.close()
    }

    // MARK: Vertical position (full line height)

    private var fromBottom: Double {
        Prefs.yFromTop ? height - Prefs.yOffset : Prefs.yOffset
    }

    /// Positions in the lower half are stored relative to the bottom edge, positions in the upper half
    /// relative to the top edge – so the point keeps its place when the Finder window is resized.
    private func store(_ value: Double) {
        let v = min(max(value.rounded(), 0), height)
        if v > height / 2 {
            Prefs.yFromTop = true
            Prefs.yOffset = height - v
        } else {
            Prefs.yFromTop = false
            Prefs.yOffset = v
        }
    }

    private func syncYControls() {
        let v = min(max(fromBottom, 0), height)
        yRow.slider.maxValue = height
        yRow.stepper.maxValue = height
        yRow.slider.doubleValue = v
        yRow.stepper.doubleValue = v
        yRow.valueLabel.stringValue = String(Int(v))
    }

    @objc private func ySliderChanged() {
        store(yRow.slider.doubleValue)
        syncYControls()
        updateMarker()
    }

    @objc private func yStepperChanged() {
        store(yRow.stepper.doubleValue)
        syncYControls()
        updateMarker()
    }

    // MARK: Actions

    private func refresh() {
        if let h = columnHeight() { height = max(Double(h), 2) }
        syncYControls()
        updateMarker()
    }

    private func updateMarker() {
        status.stringValue = showMarker() ? "" : L10n.t(.calNotFound)
    }

    @objc private func showTapped() { refresh() }
    @objc private func testTapped() { test() }
}
