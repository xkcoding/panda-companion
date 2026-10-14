import AppKit

final class SettingsController: NSObject {
    let window: NSWindow
    weak var parent: NSWindow?
    let onSaved: (DirectConfiguration) -> Void
    let onClosed: () -> Void
    let domains = NSTextView()
    let host = NSPopUpButton()
    let port = NSTextField(string: "10080")
    let interval = NSTextField(string: "10")
    let watch = NSButton(checkboxWithTitle: "网络设置变化时立即检查", target: nil, action: nil)
    let errorLabel = label("", DesignToken.Font.caption, .regular, DesignToken.Color.error)
    var tabs: DesignTabs!
    var domainPage: NSView!
    var advancedPage: NSView!
    var saveButton: NSButton!
    var cancelButton: NSButton!
    var defaultsButton: NSButton!
    let compatibility = CompatibilityPane()
    var saving = false
    init(parent: NSWindow, onSaved: @escaping (DirectConfiguration) -> Void, onClosed: @escaping () -> Void) {
        self.parent = parent; self.onSaved = onSaved; self.onClosed = onClosed
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: DesignToken.settingsWidth, height: 632), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "熊猫伴行设置"; window.isReleasedWhenClosed = false
        window.contentView = DesignComponent.background()
        super.init()
        tabs = DesignTabs(labels: ["直连规则", "运行设置", "网络兼容性"], target: self, action: #selector(changeTab))
        tabs.selectedSegment = 0
        tabs.widthAnchor.constraint(equalToConstant: DesignToken.settingsContentWidth).isActive = true
        domains.isRichText = false; domains.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        domains.isAutomaticQuoteSubstitutionEnabled = false; domains.isAutomaticDashSubstitutionEnabled = false
        domains.isAutomaticSpellingCorrectionEnabled = false
        domains.textContainerInset = NSSize(width: 10, height: 10)
        domains.autoresizingMask = [.width]; domains.isVerticallyResizable = true; domains.isHorizontallyResizable = false
        domains.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView(); scroll.documentView = domains; scroll.hasVerticalScroller = true; scroll.borderType = .noBorder; scroll.wantsLayer = true; scroll.layer?.cornerRadius = DesignToken.fieldRadius; scroll.layer?.borderWidth = 1; scroll.layer?.borderColor = DesignToken.Color.border.cgColor
        scroll.heightAnchor.constraint(equalToConstant: 180).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: DesignToken.settingsInnerWidth).isActive = true
        domainPage = DesignComponent.card(stack([
            DesignComponent.section("直连规则", subtitle: "让指定域名通过系统代理例外直接连接。"), scroll,
            label("每行一条，例如 example.com 或 *.example.com。\n留空时不维护；删除条目后，系统已有例外会保留。", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
        ], spacing: DesignToken.Space.md), width: DesignToken.settingsContentWidth, height: 302)
        host.addItems(withTitles: ["127.0.0.1", "localhost", "::1"])
        port.widthAnchor.constraint(equalToConstant: 80).isActive = true; interval.widthAnchor.constraint(equalToConstant: 65).isActive = true
        port.setAccessibilityLabel("PandaFan 代理端口"); interval.setAccessibilityLabel("兜底检查间隔")
        let proxyCard = DesignComponent.card(stack([
            DesignComponent.section("本机代理", subtitle: "匹配 PandaFan 正在使用的地址与端口。"),
            stack([host, label(":"), port], vertical: false),
            label("仅在 PandaFan 运行且系统代理匹配时维护规则。这里不会修改 PandaFan 的端口。", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
        ], spacing: DesignToken.Space.md), width: DesignToken.settingsContentWidth, height: 136)
        let scheduleCard = DesignComponent.card(stack([
            DesignComponent.section("自动检查", subtitle: "网络设置变化时检查，定时检查作为补充。"),
            stack([label("检查间隔"), interval, label("秒（5–300）", DesignToken.Font.caption, .regular, DesignToken.Color.muted)], vertical: false),
            watch,
            label("建议保持 10 秒。休眠期间不运行，唤醒后由系统恢复。", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
        ], spacing: DesignToken.Space.md), width: DesignToken.settingsContentWidth, height: 160)
        advancedPage = stack([proxyCard, scheduleCard], spacing: DesignToken.Space.lg)
        let pages = NSView(); pages.heightAnchor.constraint(equalToConstant: 380).isActive = true; pages.widthAnchor.constraint(equalToConstant: DesignToken.settingsContentWidth).isActive = true
        for page in [domainPage!, advancedPage!, compatibility.view] {
            page.translatesAutoresizingMaskIntoConstraints = false; pages.addSubview(page)
            NSLayoutConstraint.activate([page.leadingAnchor.constraint(equalTo: pages.leadingAnchor), page.trailingAnchor.constraint(equalTo: pages.trailingAnchor), page.topAnchor.constraint(equalTo: pages.topAnchor)])
        }
        advancedPage.isHidden = true; compatibility.view.isHidden = true
        saveButton = button("保存", target: self, action: #selector(save)); saveButton.keyEquivalent = "\r"; DesignComponent.primary(saveButton)
        cancelButton = button("取消", target: self, action: #selector(cancel)); cancelButton.keyEquivalent = "\u{1b}"
        defaultsButton = button("恢复默认", target: self, action: #selector(defaults))
        let actions = stack([defaultsButton, NSView(), cancelButton, saveButton], vertical: false)
        actions.widthAnchor.constraint(equalToConstant: DesignToken.settingsContentWidth).isActive = true
        errorLabel.widthAnchor.constraint(equalToConstant: DesignToken.settingsContentWidth).isActive = true
        errorLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 28).isActive = true
        let body = stack([DesignComponent.header("设置", subtitle: "熊猫伴行 · 规则与连接偏好"), tabs, pages, errorLabel, actions], spacing: DesignToken.Space.lg)
        body.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(body)
        NSLayoutConstraint.activate([body.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: DesignToken.Space.lg), body.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: DesignToken.Space.page), body.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -DesignToken.Space.page)])
        compatibility.onBusy = { [weak self] value in
            self?.saving = value; self?.cancelButton.isEnabled = !value; self?.tabs.isEnabled = !value
        }
        do { fill(try DirectConfiguration.load()) } catch { fill(DirectConfiguration()); errorLabel.stringValue = error.localizedDescription }
    }
    func fill(_ config: DirectConfiguration) {
        domains.string = config.domains.joined(separator: "\n")
        host.selectItem(withTitle: config.host); port.stringValue = String(config.port); interval.stringValue = String(config.interval); watch.state = config.watchChanges ? .on : .off
    }
    func show(tab: Int = 0) { tabs.selectedSegment = tab; changeTab(); parent?.beginSheet(window) }
    @objc func changeTab() {
        domainPage.isHidden = tabs.selectedSegment != 0; advancedPage.isHidden = tabs.selectedSegment != 1
        compatibility.view.isHidden = tabs.selectedSegment != 2
        saveButton.isHidden = tabs.selectedSegment == 2; defaultsButton.isHidden = tabs.selectedSegment == 2
        cancelButton.title = tabs.selectedSegment == 2 ? "完成" : "取消"
        errorLabel.isHidden = tabs.selectedSegment == 2
        if tabs.selectedSegment == 2 { compatibility.check() }
    }
    @objc func defaults() { fill(DirectConfiguration()); errorLabel.stringValue = "默认值已填入，保存后生效。" }
    func finish() { parent?.endSheet(window); window.orderOut(nil); onClosed() }
    @objc func cancel() { guard !saving else { return }; finish() }
    func setSaving(_ value: Bool) {
        saving = value; saveButton.isEnabled = !value; cancelButton.isEnabled = !value; defaultsButton.isEnabled = !value
        domains.isEditable = !value; port.isEnabled = !value; interval.isEnabled = !value; host.isEnabled = !value; watch.isEnabled = !value; tabs.isEnabled = !value
        saveButton.title = value ? "保存中…" : "保存"
    }
    @objc func save() {
        do {
            let config = try DirectConfiguration.normalized(domains: domains.string, host: host.titleOfSelectedItem ?? "", port: port.stringValue, interval: Int(interval.stringValue) ?? -1, watch: watch.state == .on)
            setSaving(true); errorLabel.stringValue = ""
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let result = Result { try ConfigurationStore.save(config) }
                DispatchQueue.main.async {
                    guard let self else { return }; self.setSaving(false)
                    switch result {
                    case .success: self.onSaved(config); self.finish()
                    case .failure(let error): self.errorLabel.stringValue = error.localizedDescription
                    }
                }
            }
        } catch { errorLabel.stringValue = error.localizedDescription }
    }
}
