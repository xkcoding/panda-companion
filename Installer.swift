import Foundation

// Persistent IDs are intentionally stable so upgrades reuse existing preferences.
let bundleID = "local.company-direct.app"
let guardID = "local.company-direct.guard"
let menuID = "local.company-direct.menu"
let fm = FileManager.default
func command(_ args: [String]) throws -> Int32 {
    let p = Process(); p.executableURL = URL(fileURLWithPath: args[0]); p.arguments = Array(args.dropFirst())
    p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
    try p.run(); p.waitUntilExit(); return p.terminationStatus
}
func fail(_ message: String) -> NSError { NSError(domain: "PandaCompanionInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
func plist(_ url: URL) throws -> [String: Any] {
    guard let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any] else { throw fail("Invalid property list") }
    return value
}
func writePlist(_ data: [String: Any], _ url: URL) throws {
    try PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0).write(to: url, options: .atomic)
    try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}
do {
    let args = CommandLine.arguments
    guard args.count == 2 || (args.count == 4 && args[2] == "--home") else { throw fail("Usage: Install APP [--home DESTINATION]") }
    let source = URL(fileURLWithPath: args[1]).standardizedFileURL
    let home = args.count == 4 ? URL(fileURLWithPath: args[3]).standardizedFileURL : fm.homeDirectoryForCurrentUser
    let live = home.resolvingSymlinksInPath() == fm.homeDirectoryForCurrentUser.resolvingSymlinksInPath()
    let destination = home.appendingPathComponent("Applications/熊猫伴行.app")
    let base = home.appendingPathComponent("Library/Application Support/CompanyDirect")
    let agents = home.appendingPathComponent("Library/LaunchAgents")
    let resource = source.appendingPathComponent("Contents/Resources")
    guard try plist(source.appendingPathComponent("Contents/Info.plist"))["CFBundleIdentifier"] as? String == bundleID else { throw fail("Unexpected application bundle") }
    if fm.fileExists(atPath: destination.path) {
        guard try plist(destination.appendingPathComponent("Contents/Info.plist"))["CFBundleIdentifier"] as? String == bundleID else { throw fail("Refusing to replace an unrelated application") }
    }
    if live {
        for name in ["PandaCompanion", "CompanyDirect"] {
            let code = try command(["/usr/bin/pgrep", "-u", String(getuid()), "-x", name])
            guard code == 1 else { throw fail("请先退出熊猫伴行，再运行安装器。") }
        }
    }
    for name in ["panda-companion", "config.conf", "README.md", "DESIGN.md", "PERFORMANCE.md"] {
        guard fm.fileExists(atPath: resource.appendingPathComponent(name).path) else { throw fail("Incomplete application resources: \(name)") }
    }
    try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try fm.createDirectory(at: agents, withIntermediateDirectories: true)
    // Prepare the replacement first, retaining the existing app until the copy succeeds.
    let staged = destination.deletingLastPathComponent().appendingPathComponent(".panda-install-\(UUID().uuidString).app")
    try fm.copyItem(at: source, to: staged)
    defer { try? fm.removeItem(at: staged) }
    let previous = base.appendingPathComponent("PreviousVersions/\(UUID().uuidString).app")
    if fm.fileExists(atPath: destination.path) {
        try fm.createDirectory(at: previous.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: destination, to: previous)
    }
    do { try fm.moveItem(at: staged, to: destination) }
    catch { if fm.fileExists(atPath: previous.path) { try? fm.moveItem(at: previous, to: destination) }; throw error }
    for name in ["panda-companion", "README.md", "DESIGN.md", "PERFORMANCE.md"] {
        try Data(contentsOf: resource.appendingPathComponent(name)).write(to: base.appendingPathComponent(name), options: .atomic)
    }
    try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: base.appendingPathComponent("panda-companion").path)
    let config = base.appendingPathComponent("config.conf")
    if !fm.fileExists(atPath: config.path) {
        try fm.copyItem(at: resource.appendingPathComponent("config.conf"), to: config)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
    }
    // Old scheduled jobs continue using this compatibility entry point until reconfigured.
    let alias = base.appendingPathComponent("company-direct")
    if fm.fileExists(atPath: alias.path) {
        try Data("#!/bin/zsh\nexec /bin/zsh \"${0:A:h}/panda-companion\" \"$@\"\n".utf8).write(to: alias, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: alias.path)
    }
    let guardFile = agents.appendingPathComponent(guardID + ".plist")
    if !fm.fileExists(atPath: guardFile.path) {
        try writePlist(["Label": guardID, "ProgramArguments": ["/bin/zsh", base.appendingPathComponent("panda-companion").path, "check"], "RunAtLoad": true, "StartInterval": 10, "ThrottleInterval": 2, "WatchPaths": ["/Library/Preferences/SystemConfiguration/preferences.plist"], "ProcessType": "Background", "LowPriorityIO": true, "LimitLoadToSessionType": "Aqua"], guardFile)
    }
    try writePlist(["Label": menuID, "ProgramArguments": [destination.appendingPathComponent("Contents/MacOS/PandaCompanion").path, "--background"], "RunAtLoad": true, "LimitLoadToSessionType": "Aqua"], agents.appendingPathComponent(menuID + ".plist"))
    print("安装完成：\(destination.path)\n个人规则与自动维护状态已保留。请打开熊猫伴行。")
} catch {
    fputs("安装失败：\(error.localizedDescription)\n", stderr); exit(1)
}
