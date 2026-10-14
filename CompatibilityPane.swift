import AppKit

final class CompatibilityPane: NSObject {
    let view = NSView()
    let status = label("点击检查，读取 PandaFan 配置与路由。", DesignToken.Font.body, .medium)
    let range = label("", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
    let message = label("", DesignToken.Font.caption, .regular, DesignToken.Color.muted)
    var checkButton: NSButton!
    var applyButton: NSButton!
    var restoreButton: NSButton!
    var openButton: NSButton!
    var busy = false
    var onBusy: ((Bool) -> Void)?
    var onChanged: (() -> Void)?
    override init() {
        super.init()
        checkButton = button("检查兼容性", target: self, action: #selector(check))
        applyButton = button("备份并应用 198.19 网段", target: self, action: #selector(apply))
        restoreButton = button("恢复修改前网段", target: self, action: #selector(restore))
        openButton = button("打开 PandaFan", target: self, action: #selector(openPanda))
        DesignComponent.primary(checkButton)
        let stateCard = DesignComponent.card(stack([
            DesignComponent.section("网络兼容性", subtitle: "检查增强模式与其他 VPN 的路由冲突。"), status, range,
            stack([checkButton, openButton], vertical: false)
        ], spacing: DesignToken.Space.md), width: DesignToken.settingsContentWidth, height: 174)
        let actionCard = DesignComponent.card(stack([
            label("网段调整", DesignToken.Font.section, .semibold),
            label("退出 PandaFan → 备份并应用 → 重新连接并复测", DesignToken.Font.caption, .medium),
            label("仅调整 Fake-IP 网段。其他 VPN 路由保持原样。", DesignToken.Font.caption, .regular, DesignToken.Color.muted),
            stack([applyButton, restoreButton], vertical: false), message
        ], spacing: DesignToken.Space.sm), width: DesignToken.settingsContentWidth, height: 182)
        let body = stack([stateCard, actionCard], spacing: DesignToken.Space.lg)
        pin(body, to: view)
        applyButton.isEnabled = false; restoreButton.isEnabled = false
    }
    func setBusy(_ value: Bool) {
        busy = value; checkButton.isEnabled = !value; openButton.isEnabled = !value
        applyButton.isEnabled = false; restoreButton.isEnabled = false; onBusy?(value)
    }
    func render(_ inspection: PandaInspection) {
        status.stringValue = inspection.summary
        status.textColor = inspection.conflict || inspection.candidateConflict ? DesignToken.Color.warning : .labelColor
        range.stringValue = "当前配置：\(inspection.range) · 目标：\(PandaConfig.compatibleRange)"
        applyButton.isEnabled = !inspection.running && !inspection.candidateConflict && inspection.range == PandaConfig.defaultRange
        restoreButton.isEnabled = !inspection.running && inspection.range == PandaConfig.compatibleRange && FileManager.default.fileExists(atPath: PandaFileStore.backupURL(PandaCompatibility.file).path)
        if inspection.candidateConflict { message.stringValue = "目标网段也指向其他虚拟接口，已禁止应用。" }
        else if inspection.running {
            message.stringValue = inspection.range == PandaConfig.compatibleRange
                ? "已配置兼容网段，可重试此前连接失败的应用。恢复原网段前需退出 PandaFan。"
                : "应用前请在 PandaFan 中退出客户端，再点“检查兼容性”。"
        }
    }
    func perform(_ operation: @escaping () throws -> String) {
        guard !busy else { return }; setBusy(true); message.stringValue = "正在读取本机配置…"
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Result { () -> (String, Result<PandaInspection, Error>) in
                let message = try operation(); return (message, Result { try PandaCompatibility.inspect() })
            }
            DispatchQueue.main.async {
                guard let self else { return }; self.setBusy(false)
                switch result {
                case .success(let (message, inspection)):
                    self.message.stringValue = message
                    switch inspection {
                    case .success(let value): self.render(value)
                    case .failure(let error):
                        self.status.stringValue = "路由状态未能验证"; self.status.textColor = DesignToken.Color.warning
                        self.message.stringValue = message + "\n" + error.localizedDescription
                    }
                    self.onChanged?()
                case .failure(let error): self.status.stringValue = "未完成操作"; self.status.textColor = DesignToken.Color.warning; self.message.stringValue = error.localizedDescription
                }
            }
        }
    }
    @objc func check() { perform { "只检查本机路由；配置生效仍需重新连接并复测应用。" } }
    @objc func apply() {
        perform {
            _ = try PandaCompatibility.apply()
            return "已备份并写入配置。请打开 PandaFan 连接，再点“检查兼容性”并复测之前失败的应用。"
        }
    }
    @objc func restore() {
        perform { try PandaCompatibility.restore(); return "已恢复此前网段字段，其他设置保留。请重新打开 PandaFan。" }
    }
    @objc func openPanda() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppDelegate.pandaID) else { message.stringValue = "未找到 PandaFan。"; return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error { self?.message.stringValue = error.localizedDescription }
                else { self?.message.stringValue = "已打开 PandaFan。连接后点击检查兼容性，确认实际路由。" }
            }
        }
    }
}
