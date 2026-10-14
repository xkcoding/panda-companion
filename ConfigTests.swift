import Foundation
@main struct ConfigTests {
    static func main() throws {
        let defaults = DirectConfiguration()
        let roundtrip = try DirectConfiguration.decode(defaults.data)
        assert(roundtrip == defaults)
        let custom = try DirectConfiguration.normalized(domains: "EXAMPLE.COM\n*.example.com\nexample.com", host: "localhost", port: "12345", interval: 30, watch: false)
        assert(custom.domains == ["example.com", "*.example.com"])
        let customRoundtrip = try DirectConfiguration.decode(custom.data)
        assert(customRoundtrip == custom)
        let agent = try PropertyListSerialization.propertyList(from: custom.launchAgent(script: "/tmp/test"), format: nil) as! [String: Any]
        assert(agent["StartInterval"] as? Int == 30 && agent["WatchPaths"] == nil)
        assert(defaults.domains.isEmpty)
        assert(AssistantState(output: "直连规则：尚未添加").phase == .empty)
        assert(AssistantState(output: "直连规则完整").phase == .ready)
        assert(AssistantState(output: "直连规则缺失").phase == .needsRepair)
        for invalid in [ "https://example.com", "example.com/path", "x.com;touch /tmp/evil", "bad-.example.com", "*example.com"] {
            do { _ = try DirectConfiguration.normalized(domains: invalid, host: "127.0.0.1", port: "10080", interval: 10, watch: true); fatalError("Accepted invalid domain") }
            catch is ConfigError {}
        }
        for invalid in ["port=0", "host=10.0.0.1", "interval=1", "version=2"] {
            let key = invalid.split(separator: "=")[0]
            let text = String(decoding: defaults.data, as: UTF8.self).split(separator: "\n").filter { !$0.hasPrefix(key + "=") }.map(String.init).joined(separator: "\n") + "\n" + invalid + "\n"
            do { _ = try DirectConfiguration.decode(Data(text.utf8)); fatalError("Accepted invalid config") }
            catch is ConfigError {}
        }
        assert(AssistantState(output: "自动维护：已开启\nPandaFan：未运行").phase == .notRunning)
        assert(AssistantState(output: "PandaFan：运行中").phase == .waiting)
        let ready = AssistantState(output: "自动维护：已开启\n公司域名例外完整")
        assert(ready.enabled && ready.phase == .ready)
        assert(AssistantState(output: "直连规则完整\n最近记录：\n旧记录：公司域名例外缺失").phase == .ready)
        let missing = AssistantState(output: "自动维护：已暂停\n公司域名例外完整\n公司域名例外缺失")
        assert(!missing.enabled && missing.phase == .needsRepair)
        print("PASS: configuration roundtrip, normalization, input rejection, scheduler generation")
    }
}
