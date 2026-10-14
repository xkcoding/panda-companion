import AppKit

/// Shared appearance contract for every surface. Sizes are macOS points.
/// Keep layout policy here; features should use components rather than copy styles.
enum DesignToken {
    enum Color {
        static let accent = NSColor.systemTeal
        static let surface = NSColor.controlBackgroundColor
        static let text = NSColor.labelColor
        static let muted = NSColor.secondaryLabelColor
        static let subtle = NSColor.tertiaryLabelColor
        static let warning = NSColor.systemOrange
        static let success = NSColor.systemGreen
        static let error = NSColor.systemRed
        static let border = NSColor.separatorColor
    }
    enum Font {
        static let title: CGFloat = 22
        static let heading: CGFloat = 16
        static let section: CGFloat = 13
        static let body: CGFloat = 12
        static let caption: CGFloat = 11
        static let micro: CGFloat = 10
    }
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let page: CGFloat = 24
    }
    static let cardRadius: CGFloat = 14
    static let fieldRadius: CGFloat = 8
    static let controlHeight: CGFloat = 30
    static let mainWidth: CGFloat = 392
    static let settingsWidth: CGFloat = 552
    static let mainContentWidth = mainWidth - Space.page * 2
    static let settingsContentWidth = settingsWidth - Space.page * 2
    static let settingsInnerWidth = settingsContentWidth - Space.lg * 2
}

enum DesignComponent {
    static func background() -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover; view.blendingMode = .behindWindow; view.state = .active
        return view
    }
    static func card(_ content: NSView, width: CGFloat, height: CGFloat? = nil) -> NSBox {
        let card = NSBox(); card.boxType = .custom; card.borderWidth = 0
        card.fillColor = DesignToken.Color.surface; card.cornerRadius = DesignToken.cardRadius
        card.contentViewMargins = .zero
        pin(content, to: card.contentView!, inset: DesignToken.Space.lg)
        card.widthAnchor.constraint(equalToConstant: width).isActive = true
        if let height { card.heightAnchor.constraint(equalToConstant: height).isActive = true }
        return card
    }
    static func header(_ title: String, subtitle: String) -> NSView {
        let icon = NSImageView(image: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return stack([icon, stack([label(title, DesignToken.Font.title, .semibold), label(subtitle, DesignToken.Font.caption, .regular, DesignToken.Color.muted)], spacing: DesignToken.Space.xs)], vertical: false, spacing: DesignToken.Space.md)
    }
    static func primary(_ button: NSButton) {
        button.bezelColor = DesignToken.Color.accent
        button.heightAnchor.constraint(equalToConstant: DesignToken.controlHeight).isActive = true
    }
    static func section(_ title: String, subtitle: String) -> NSView {
        stack([label(title, DesignToken.Font.section, .semibold), label(subtitle, DesignToken.Font.caption, .regular, DesignToken.Color.muted)], spacing: DesignToken.Space.xs)
    }
}

/// Uses the same native button and accent treatment as the primary actions.
final class DesignTabs: NSStackView {
    var selectedSegment = 0 { didSet { render() } }
    var isEnabled = true { didSet { buttons.forEach { $0.isEnabled = isEnabled } } }
    private var buttons: [NSButton] = []
    private weak var actionTarget: AnyObject?
    private let actionSelector: Selector
    init(labels: [String], target: AnyObject, action: Selector) {
        actionTarget = target; actionSelector = action
        super.init(frame: .zero)
        orientation = .horizontal; distribution = .fillEqually; spacing = DesignToken.Space.sm
        for (index, title) in labels.enumerated() {
            let control = button(title, target: self, action: #selector(selectTab(_:)))
            control.tag = index; control.setAccessibilityLabel(title)
            control.heightAnchor.constraint(equalToConstant: DesignToken.controlHeight).isActive = true
            buttons.append(control); addArrangedSubview(control)
        }
        render()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func render() {
        for (index, control) in buttons.enumerated() {
            control.bezelColor = index == selectedSegment ? DesignToken.Color.accent : nil
            control.font = .systemFont(ofSize: DesignToken.Font.body, weight: index == selectedSegment ? .semibold : .regular)
            control.setAccessibilityValue(index == selectedSegment ? "已选择" : "未选择")
        }
    }
    @objc private func selectTab(_ sender: NSButton) {
        selectedSegment = sender.tag
        NSApp.sendAction(actionSelector, to: actionTarget, from: self)
    }
}
