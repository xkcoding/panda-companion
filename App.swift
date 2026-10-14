import AppKit
import SystemConfiguration

func label(_ text: String, _ size: CGFloat = DesignToken.Font.body, _ weight: NSFont.Weight = .regular, _ color: NSColor = DesignToken.Color.text) -> NSTextField {
    let view = NSTextField(wrappingLabelWithString: text)
    view.font = .systemFont(ofSize: size, weight: weight); view.textColor = color
    return view
}
func stack(_ views: [NSView], vertical: Bool = true, spacing: CGFloat = DesignToken.Space.md) -> NSStackView {
    let view = NSStackView(views: views)
    view.orientation = vertical ? .vertical : .horizontal
    view.alignment = vertical ? .leading : .centerY; view.spacing = spacing
    return view
}
func pin(_ child: NSView, to parent: NSView, inset: CGFloat = 0) {
    child.translatesAutoresizingMaskIntoConstraints = false; parent.addSubview(child)
    NSLayoutConstraint.activate([child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset), child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset), child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset), child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)])
}
func button(_ title: String, target: AnyObject, action: Selector) -> NSButton {
    let view = NSButton(title: title, target: target, action: action); view.bezelStyle = .rounded; view.font = .systemFont(ofSize: DesignToken.Font.body)
    return view
}
final class DirectWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
final class MainPanel {
    let window: NSPanel
    let status = label("正在检查…", DesignToken.Font.heading, .semibold)
    let detail = label("", DesignToken.Font.body, .regular, DesignToken.Color.muted)
    let rules = label("", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
    let light = NSImageView()
    let maintenance = NSSwitch()
    let maintenanceDetail = label("", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
    let primary: NSButton
    let checked = label("", DesignToken.Font.micro, .regular, DesignToken.Color.subtle)
    let progress = NSProgressIndicator()
    init(owner: AppDelegate) {
        window = DirectWindow(contentRect: NSRect(x: 0, y: 0, width: DesignToken.mainWidth, height: 530), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "熊猫伴行"; window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true; window.titleVisibility = .hidden; window.level = .floating
        let background = DesignComponent.background()
        window.contentView = background
        let header = DesignComponent.header("熊猫伴行", subtitle: "PandaFan 的轻量配套助手")
        light.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "规则状态")
        light.widthAnchor.constraint(equalToConstant: 8).isActive = true
        light.heightAnchor.constraint(equalToConstant: 8).isActive = true
        primary = button("正在检查…", target: owner, action: #selector(AppDelegate.primaryAction))
        DesignComponent.primary(primary); primary.keyEquivalent = "\r"
        primary.widthAnchor.constraint(equalToConstant: DesignToken.mainContentWidth - DesignToken.Space.lg * 2).isActive = true
        let ruleHeading = stack([label("直连规则", DesignToken.Font.caption, .medium, DesignToken.Color.muted), NSView(), rules], vertical: false)
        ruleHeading.widthAnchor.constraint(equalToConstant: DesignToken.mainContentWidth - DesignToken.Space.lg * 2).isActive = true
        detail.widthAnchor.constraint(equalToConstant: DesignToken.mainContentWidth - DesignToken.Space.lg * 2).isActive = true
        let cardBody = stack([ruleHeading, stack([light, status], vertical: false, spacing: DesignToken.Space.sm), detail, primary], spacing: DesignToken.Space.md)
        let card = DesignComponent.card(cardBody, width: DesignToken.mainContentWidth, height: 154)
        maintenance.setAccessibilityLabel("自动维护"); maintenance.target = owner; maintenance.action = #selector(AppDelegate.toggleMaintenance)
        let autoText = stack([label("自动维护", DesignToken.Font.body, .medium), maintenanceDetail], spacing: DesignToken.Space.xs)
        let autoRow = stack([autoText, NSView(), maintenance], vertical: false)
        autoRow.widthAnchor.constraint(equalToConstant: DesignToken.mainContentWidth).isActive = true
        let compatibility = button("检查兼容性", target: owner, action: #selector(AppDelegate.showCompatibility))
        let networkIcon = NSImageView(image: NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: nil)!)
        networkIcon.contentTintColor = DesignToken.Color.accent
        networkIcon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        let compatHeading = stack([networkIcon, label("网络兼容性", DesignToken.Font.section, .semibold), NSView()], vertical: false, spacing: DesignToken.Space.sm)
        let compatText = label("增强模式连接异常？检查 Fake-IP 网段是否与其他 VPN 冲突。", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
        compatText.widthAnchor.constraint(equalToConstant: DesignToken.mainContentWidth - DesignToken.Space.lg * 2).isActive = true
        let compatibilityCard = DesignComponent.card(stack([compatHeading, compatText, compatibility], spacing: DesignToken.Space.sm), width: DesignToken.mainContentWidth, height: 121)
        let panda = button("打开 PandaFan ↗", target: owner, action: #selector(AppDelegate.openPanda)); panda.bezelStyle = .inline; panda.font = .systemFont(ofSize: 11)
        let settings = NSButton(image: NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "设置")!, target: owner, action: #selector(AppDelegate.showSettings))
        settings.bezelStyle = .inline; settings.toolTip = "直连规则与运行设置"
        let more = NSButton(image: NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "更多")!, target: owner, action: #selector(AppDelegate.showMore(_:)))
        more.bezelStyle = .inline
        progress.style = .spinning; progress.controlSize = .small; progress.isDisplayedWhenStopped = false
        let footer = stack([panda, NSView(), progress, settings, more], vertical: false, spacing: DesignToken.Space.md)
        footer.widthAnchor.constraint(equalToConstant: DesignToken.mainContentWidth).isActive = true
        let body = stack([header, card, autoRow, compatibilityCard, footer, checked], spacing: DesignToken.Space.lg)
        body.translatesAutoresizingMaskIntoConstraints = false; background.addSubview(body)
        NSLayoutConstraint.activate([body.topAnchor.constraint(equalTo: background.topAnchor, constant: DesignToken.Space.lg), body.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: DesignToken.Space.page), body.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -DesignToken.Space.page)])
    }
    func render(_ state: AssistantState, config: DirectConfiguration, error: String?, busy: Bool, checkedAt: String) {
        status.stringValue = error == nil ? state.title : "检查未完成"
        detail.stringValue = error ?? state.detail
        light.contentTintColor = error != nil || state.phase == .needsRepair ? DesignToken.Color.warning : state.phase == .ready ? DesignToken.Color.success : DesignToken.Color.muted
        rules.stringValue = "\(config.domains.count) 条"
        maintenance.state = state.enabled ? .on : .off; maintenance.isEnabled = !busy
        maintenanceDetail.stringValue = state.enabled ? "连接后自动补齐缺失的规则" : "已暂停 · 可随时手动检查"
        primary.title = busy ? "正在检查…" : error == nil ? state.action : "重新检查"
        primary.isEnabled = !busy
        checked.stringValue = busy ? "读取本机状态" : checkedAt.isEmpty ? "" : "上次检查 \(checkedAt)"
        if busy { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let pandaID = "com.beexio.pandafan.client"
    var item: NSStatusItem!
    var panel: MainPanel!
    var settings: SettingsController?
    var state = AssistantState(output: "")
    var configuration = DirectConfiguration()
    var busy = false
    var refreshPending = false
    var lastError: String?
    var checkedAt = ""
    var store: SCDynamicStore?
    let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CompanyDirect")
    static func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            for x: CGFloat in [2, 11] { NSBezierPath(ovalIn: NSRect(x: x, y: 12, width: 5, height: 5)).fill() }
            let outline = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 15, height: 13), xRadius: 6, yRadius: 6)
            outline.lineWidth = 1.5; NSColor.black.setStroke(); outline.stroke()
            let route = NSBezierPath(); route.move(to: NSPoint(x: 9, y: 4)); route.line(to: NSPoint(x: 9, y: 7)); route.line(to: NSPoint(x: 5.5, y: 10.5))
            route.move(to: NSPoint(x: 9, y: 7)); route.line(to: NSPoint(x: 12.5, y: 10.5)); route.lineWidth = 1.7; route.lineCapStyle = .round; route.stroke()
            return true
        }
        image.isTemplate = true; image.accessibilityDescription = "熊猫伴行"; return image
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Self.menuIcon()
        item.button?.target = self; item.button?.action = #selector(togglePanel)
        item.button?.toolTip = "熊猫伴行 · PandaFan 配套助手"
        panel = MainPanel(owner: self)
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(pandaChanged(_:)), name: name, object: nil)
        }
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        store = SCDynamicStoreCreate(nil, "CompanyDirectUI" as CFString, { _, _, info in
            guard let info else { return }
            let owner = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            if owner.panel.window.isVisible { owner.refresh() }
        }, &context)
        if let store {
            SCDynamicStoreSetNotificationKeys(store, ["State:/Network/Global/Proxies"] as CFArray, nil)
            SCDynamicStoreSetDispatchQueue(store, DispatchQueue.main)
        }
        if !CommandLine.arguments.contains("--background") { showPanel() }
    }
    @objc func pandaChanged(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.bundleIdentifier == Self.pandaID, panel.window.isVisible else { return }
        refresh()
    }
    func render() { panel.render(state, config: configuration, error: lastError, busy: busy, checkedAt: checkedAt) }
    func refresh(_ action: String = "status") {
        guard !busy else { refreshPending = true; return }
        do { configuration = try DirectConfiguration.load() } catch { lastError = error.localizedDescription; render(); return }
        busy = true; lastError = nil; render()
        let script = base.appendingPathComponent("company-direct").path
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result: Result<CommandResult, Error> = Result {
                let result = try LocalCommand.run("/bin/zsh", [script, action])
                if result.code == 0 && action == "pause" { return try LocalCommand.run("/bin/zsh", [script, "status"]) }
                return result
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                switch result {
                case .success(let output):
                    if output.code == 0 { self.state = AssistantState(output: output.output) }
                    else { self.lastError = output.output.trimmingCharacters(in: .whitespacesAndNewlines) }
                case .failure(let error): self.lastError = error.localizedDescription
                }
                let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss"; self.checkedAt = formatter.string(from: Date())
                self.render()
                if self.refreshPending { self.refreshPending = false; self.refresh() }
            }
        }
    }
    func showPanel() {
        if !panel.window.isVisible { panel.window.center() }
        panel.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); refresh()
    }
    @objc func togglePanel() { if panel.window.isVisible { panel.window.orderOut(nil) } else { showPanel() } }
    @objc func toggleMaintenance() { refresh(panel.maintenance.state == .on ? "enable" : "pause") }
    @objc func primaryAction() {
        if lastError != nil { refresh() }
        else if state.phase == .empty { showSettings() }
        else if state.phase == .notRunning || state.phase == .waiting { openPanda() }
        else { refresh("repair") }
    }
    @objc func openPanda() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.pandaID) else { lastError = "未找到 PandaFan，请先安装。"; render(); return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            if let error { DispatchQueue.main.async { self?.lastError = error.localizedDescription; self?.render() } }
        }
    }
    @objc func showSettings() { openSettings(tab: 0) }
    @objc func showCompatibility() { openSettings(tab: 2) }
    func openSettings(tab: Int) {
        guard !busy, settings == nil else { return }
        settings = SettingsController(parent: panel.window, onSaved: { [weak self] in self?.configuration = $0; self?.refresh() }, onClosed: { [weak self] in self?.settings = nil })
        settings?.show(tab: tab)
    }
    @objc func showMore(_ sender: NSButton) {
        let menu = NSMenu()
        for (title, action) in [("设置…", #selector(showSettings)), ("查看维护日志", #selector(openLog)), ("使用说明", #selector(openHelp))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出菜单栏（自动维护继续）", action: #selector(quitApp), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
    }
    @objc func openLog() { NSWorkspace.shared.open(base.appendingPathComponent("changes.log")) }
    @objc func openHelp() { NSWorkspace.shared.open(base.appendingPathComponent("README.md")) }
    @objc func quitApp() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPanel(); return true }
}
@main struct CompanyDirect {
    static func main() {
        if let other = NSRunningApplication.runningApplications(withBundleIdentifier: "local.company-direct.app").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            other.activate(options: [.activateAllWindows]); return
        }
        let app = NSApplication.shared; let delegate = AppDelegate()
        app.setActivationPolicy(.accessory); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
