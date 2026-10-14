import Foundation

struct PandaConfig {
    static let defaultRange = "198.18.0.1/16"
    static let compatibleRange = "198.19.0.1/16"
    static func object(_ data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ConfigError.message("PandaFan 配置格式不正确，未修改。") }
        return root
    }
    static func dns(_ root: [String: Any]) throws -> [String: Any] {
        guard let raw = root["clash_default_config"] else { return [:] }
        guard let defaults = raw as? [String: Any] else { throw ConfigError.message("PandaFan 默认配置字段不兼容，未修改。") }
        guard let rawDNS = defaults["dns"] else { return [:] }
        guard let dns = rawDNS as? [String: Any] else { throw ConfigError.message("PandaFan DNS 字段不兼容，未修改。") }
        return dns
    }
    static func range(_ data: Data) throws -> String {
        let value = try dns(object(data))["fake-ip-range"]
        guard let value else { return defaultRange }
        guard let range = value as? String else { throw ConfigError.message("PandaFan 虚拟网段格式不正确。") }
        return range
    }
    static func changing(_ data: Data, value: Any?, removeEmptyDefaults: Bool = false, removeEmptyDNS: Bool = false) throws -> Data {
        var root = try object(data)
        var dns = try self.dns(root)
        var defaults = root["clash_default_config"] as? [String: Any] ?? [:]
        dns["fake-ip-range"] = value
        if removeEmptyDNS && dns.isEmpty { defaults.removeValue(forKey: "dns") } else { defaults["dns"] = dns }
        if removeEmptyDefaults && defaults.isEmpty { root.removeValue(forKey: "clash_default_config") } else { root["clash_default_config"] = defaults }
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}

struct PandaRoute {
    let destination: String
    let mask: String
    let interface: String
    init(_ text: String) {
        func field(_ key: String) -> String {
            text.components(separatedBy: .newlines).first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix(key + ":") })?.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        }
        destination = field("destination"); mask = field("mask"); interface = field("interface")
    }
    var reservesCandidate: Bool { destination.hasPrefix("198.19.") || destination == "198.19" }
}
struct PandaInspection {
    let running: Bool
    let range: String
    let current: PandaRoute
    let candidate: PandaRoute
    let pandaInterfaces: Set<String>
    var conflict: Bool { running && !pandaInterfaces.isEmpty && !current.interface.isEmpty && !pandaInterfaces.contains(current.interface) }
    var candidateConflict: Bool { (candidate.reservesCandidate || candidate.interface.hasPrefix("utun")) && !pandaInterfaces.contains(candidate.interface) }
    var summary: String {
        if conflict { return "发现路由冲突：虚拟地址走 \(current.interface)，PandaFan 使用 \(pandaInterfaces.sorted().joined(separator: "/"))。" }
        if !running { return "PandaFan 已退出，可以备份并应用配置。" }
        if pandaInterfaces.isEmpty { return "未识别到 PandaFan 虚拟接口，无法确认增强模式路由。" }
        return "采样虚拟地址经 \(current.interface)，未发现此前的接口冲突。"
    }
}

enum PandaCompatibility {
    static let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/PandaFan/config.json")
    static func running() throws -> Bool {
        let r = try LocalCommand.run("/usr/bin/pgrep", ["-u", String(getuid()), "-x", "PandaFan"])
        guard r.code == 0 || r.code == 1 else { throw ConfigError.message("无法确认 PandaFan 是否退出，已停止修改。") }
        return r.code == 0
    }
    static func inspect() throws -> PandaInspection {
        let active = try running(), range = try PandaConfig.range(Data(contentsOf: file))
        guard [PandaConfig.defaultRange, PandaConfig.compatibleRange].contains(range) else { throw ConfigError.message("当前使用自定义网段 \(range)，请保留现有设置并人工检查。") }
        let interfaces = try LocalCommand.run("/sbin/ifconfig", [])
        guard interfaces.code == 0 else { throw ConfigError.message("无法读取虚拟网卡。") }
        var currentInterface = "", found = Set<String>()
        for line in interfaces.output.components(separatedBy: .newlines) {
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") { currentInterface = String(line.prefix(while: { $0 != ":" })) }
            if line.contains("inet 198.18.0.1 ") || line.contains("inet 198.19.0.1 ") { found.insert(currentInterface) }
        }
        func route(_ ip: String) throws -> PandaRoute {
            let r = try LocalCommand.run("/sbin/route", ["-n", "get", ip])
            guard r.code == 0 else { throw ConfigError.message("无法读取路由，请联网后重新检查。") }
            return PandaRoute(r.output)
        }
        return try PandaInspection(running: active, range: range, current: route(range == PandaConfig.defaultRange ? "198.18.0.9" : "198.19.0.9"), candidate: route("198.19.0.9"), pandaInterfaces: found)
    }
    static func apply() throws -> URL {
        let inspection = try inspect()
        guard !inspection.running else { throw ConfigError.message("请先退出 PandaFan，再点击应用。关闭窗口不等于退出客户端。") }
        guard !inspection.candidateConflict else { throw ConfigError.message("198.19 网段也被其他接口占用，未修改。") }
        return try PandaFileStore.apply(file: file, isRunning: running)
    }
    static func restore() throws { try PandaFileStore.restore(file: file, isRunning: running) }
}

enum PandaFileStore {
    static func backupURL(_ file: URL) -> URL { file.deletingLastPathComponent().appendingPathComponent("CompanyDirect-Backups/last-before-fakeip.json") }
    static func checkedRead(_ file: URL) throws -> Data {
        guard try file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ConfigError.message("配置文件是符号链接，未修改。") }
        return try Data(contentsOf: file)
    }
    static func ensureStopped(_ isRunning: () throws -> Bool) throws {
        guard try !isRunning() else { throw ConfigError.message("PandaFan 仍在运行，未修改。请退出客户端后重试。") }
    }
    static func write(_ data: Data, file: URL, original: Data, isRunning: () throws -> Bool) throws {
        try ensureStopped(isRunning)
        guard try checkedRead(file) == original else { throw ConfigError.message("PandaFan 配置刚刚发生变化，未覆盖，请重新检查。") }
        let temp = file.deletingLastPathComponent().appendingPathComponent(".company-direct-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: temp) }
        guard FileManager.default.createFile(atPath: temp.path, contents: data, attributes: [.posixPermissions: 0o600]) else { throw ConfigError.message("无法写入配置。") }
        try ensureStopped(isRunning)
        guard try checkedRead(file) == original else { throw ConfigError.message("配置已变化，未覆盖。") }
        guard rename(temp.path, file.path) == 0 else { throw ConfigError.message("无法替换配置，原文件保留。") }
    }
    static func apply(file: URL, isRunning: () throws -> Bool) throws -> URL {
        try ensureStopped(isRunning)
        let original = try checkedRead(file), range = try PandaConfig.range(original)
        guard range == PandaConfig.defaultRange else { throw ConfigError.message(range == PandaConfig.compatibleRange ? "已配置兼容网段，无需重复修改。" : "当前为自定义网段，未修改。") }
        let newData = try PandaConfig.changing(original, value: PandaConfig.compatibleRange)
        let backup = backupURL(file)
        try FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: backup.deletingLastPathComponent().path)
        // Keep each full backup private; only the last one is offered by the UI for field-level restore.
        let archive = backup.deletingLastPathComponent().appendingPathComponent("before-\(UUID().uuidString).json")
        for target in [archive, backup] {
            guard FileManager.default.createFile(atPath: target.path, contents: original, attributes: [.posixPermissions: 0o600]) else { throw ConfigError.message("备份失败，未修改 PandaFan。") }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        }
        try write(newData, file: file, original: original, isRunning: isRunning)
        return archive
    }
    static func restore(file: URL, isRunning: () throws -> Bool) throws {
        try ensureStopped(isRunning)
        let original = try checkedRead(file)
        guard try PandaConfig.range(original) == PandaConfig.compatibleRange else { throw ConfigError.message("当前网段已变化，停止恢复以保留你的设置。") }
        let before = try checkedRead(backupURL(file)), oldRoot = try PandaConfig.object(before), oldDNS = try PandaConfig.dns(oldRoot)
        let oldDefaults = oldRoot["clash_default_config"] as? [String: Any]
        let restored = try PandaConfig.changing(original, value: oldDNS["fake-ip-range"], removeEmptyDefaults: oldDefaults == nil, removeEmptyDNS: oldDefaults?["dns"] == nil)
        try write(restored, file: file, original: original, isRunning: isRunning)
    }
}
