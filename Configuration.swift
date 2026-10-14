import Foundation

struct DirectConfiguration: Equatable {
    var domains: [String] = []
    var host = "127.0.0.1"
    var port = 10080
    var interval = 10
    var watchChanges = true
    static let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CompanyDirect/config.conf")

    static func normalized(domains: String, host: String, port: String, interval: Int, watch: Bool) throws -> DirectConfiguration {
        let entries = domains.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        var unique: [String] = []
        let pattern = #"^(\*\.)?([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?$"#
        for entry in entries {
            guard entry.count <= 253, entry.range(of: pattern, options: .regularExpression) != nil,
                  entry.split(separator: ".").allSatisfy({ $0.count <= 63 }) else {
                throw ConfigError.message("域名格式不正确：\(entry.prefix(50))。请填写域名，不要包含 https://、路径或空格。")
            }
            if !unique.contains(entry) { unique.append(entry) }
        }
        guard unique.count <= 200 else { throw ConfigError.message("最多可添加 200 条直连规则。") }
        guard ["127.0.0.1", "localhost", "::1"].contains(host) else { throw ConfigError.message("代理地址仅支持本机地址。") }
        guard let number = Int(port), (1...65535).contains(number) else { throw ConfigError.message("端口应为 1–65535 的整数。") }
        guard (5...300).contains(interval) else { throw ConfigError.message("检查间隔应在 5–300 秒之间。") }
        return DirectConfiguration(domains: unique, host: host, port: number, interval: interval, watchChanges: watch)
    }

    var data: Data {
        Data((["version=1", "host=\(host)", "port=\(port)", "interval=\(interval)", "watch=\(watchChanges ? 1 : 0)"] + domains.map { "domain=\($0)" }).joined(separator: "\n").appending("\n").utf8)
    }
    static func decode(_ data: Data) throws -> DirectConfiguration {
        guard let text = String(data: data, encoding: .utf8), data.count <= 65536 else { throw ConfigError.message("配置文件无法读取。") }
        var values: [String: String] = [:]
        var domains: [String] = []
        for line in text.components(separatedBy: .newlines) where !line.isEmpty {
            let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { throw ConfigError.message("配置文件格式不正确。") }
            let key = String(pair[0]), value = String(pair[1])
            if key == "domain" { domains.append(value); continue }
            guard ["version", "host", "port", "interval", "watch"].contains(key), values[key] == nil else { throw ConfigError.message("配置文件包含未知或重复字段。") }
            values[key] = value
        }
        guard values["version"] == "1", let host = values["host"], let port = values["port"],
              let intervalString = values["interval"], let interval = Int(intervalString),
              let watch = values["watch"], ["0", "1"].contains(watch) else { throw ConfigError.message("配置文件版本或字段不正确。") }
        return try normalized(domains: domains.joined(separator: "\n"), host: host, port: port, interval: interval, watch: watch == "1")
    }
    static func load() throws -> DirectConfiguration {
        if !FileManager.default.fileExists(atPath: file.path) { return DirectConfiguration() }
        return try decode(Data(contentsOf: file))
    }
    func launchAgent(script: String) throws -> Data {
        var plist: [String: Any] = [
            "Label": "local.company-direct.guard", "ProgramArguments": ["/bin/zsh", script, "check"],
            "RunAtLoad": true, "StartInterval": interval, "ThrottleInterval": 2,
            "ProcessType": "Background", "LowPriorityIO": true, "LimitLoadToSessionType": "Aqua"
        ]
        if watchChanges { plist["WatchPaths"] = ["/Library/Preferences/SystemConfiguration/preferences.plist"] }
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }
}

enum ConfigError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(message) = self { return message }; return nil }
}

struct CommandResult { let code: Int32; let output: String }
enum LocalCommand {
    static func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: deadline)
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit(); deadline.cancel()
        return CommandResult(code: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}

enum ConfigurationStore {
    static func save(_ configuration: DirectConfiguration) throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let file = DirectConfiguration.file
        let agent = home.appendingPathComponent("Library/LaunchAgents/local.company-direct.guard.plist")
        let script = home.appendingPathComponent("Library/Application Support/CompanyDirect/panda-companion").path
        let target = "gui/\(getuid())/local.company-direct.guard"
        let active = try LocalCommand.run("/bin/launchctl", ["print", target]).code == 0
        let oldConfig = try? Data(contentsOf: file)
        let oldAgent = try Data(contentsOf: agent)
        let newAgent = try configuration.launchAgent(script: script)
        if active {
            guard try LocalCommand.run("/bin/launchctl", ["bootout", target]).code == 0 else { throw ConfigError.message("暂时无法暂停后台检查，请稍后保存。") }
        }
        do {
            try configuration.data.write(to: file, options: .atomic)
            try newAgent.write(to: agent, options: .atomic)
            if active {
                let result = try LocalCommand.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", agent.path])
                guard result.code == 0 else { throw ConfigError.message("后台任务重载失败。") }
            }
        } catch {
            // Restore both files and previous running state if applying the new configuration fails.
            do {
                if let oldConfig { try oldConfig.write(to: file, options: .atomic) }
                else if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
                try oldAgent.write(to: agent, options: .atomic)
                if active {
                    let result = try LocalCommand.run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", agent.path])
                    guard result.code == 0 else { throw ConfigError.message("后台任务恢复失败。") }
                }
            } catch { throw ConfigError.message("保存失败，且自动恢复未完成。请检查自动维护状态。") }
            throw ConfigError.message("保存失败，已恢复原配置。")
        }
    }
}
