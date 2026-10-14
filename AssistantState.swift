import Foundation

enum AssistantPhase { case empty, notRunning, waiting, ready, needsRepair }
struct AssistantState {
    let enabled: Bool
    let phase: AssistantPhase
    init(output: String) {
        let output = output.components(separatedBy: "最近记录：")[0]
        enabled = output.contains("自动维护：已开启")
        if output.contains("直连规则：尚未添加") { phase = .empty }
        else if output.contains("PandaFan：未运行") { phase = .notRunning }
        else if output.contains("直连规则缺失") || output.contains("公司域名例外缺失") { phase = .needsRepair }
        else if output.contains("直连规则完整") || output.contains("公司域名例外完整") { phase = .ready }
        else { phase = .waiting }
    }
    var title: String {
        switch phase {
        case .empty: return "添加第一条直连规则"
        case .notRunning: return "先打开 PandaFan"
        case .waiting: return "等待 PandaFan 系统代理"
        case .ready: return "直连规则已就绪"
        case .needsRepair: return "直连规则待补齐"
        }
    }
    var detail: String {
        switch phase {
        case .empty: return "把需要直接访问的域名添加到规则中。"
        case .notRunning: return "连接 PandaFan 后，助手会按规则维护直连。"
        case .waiting: return "请在 PandaFan 开启系统代理；已开启时检查端口匹配。"
        case .ready: return "已补齐系统代理例外，可按需添加更多规则。"
        case .needsRepair: return enabled ? "自动维护已开启，也可以立即手动修复。" : "自动维护已暂停，可手动修复或重新开启。"
        }
    }
    var action: String {
        switch phase {
        case .empty: return "添加规则"
        case .notRunning: return "打开 PandaFan"
        case .waiting: return "前往 PandaFan 连接"
        case .ready: return "检查直连规则"
        case .needsRepair: return "补齐直连规则"
        }
    }
}
