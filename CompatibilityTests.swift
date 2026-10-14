import Foundation
@main struct CompatibilityTests {
    static func main() throws {
        let initial = Data(#"{"user":{"token":"fixture-only"},"runTimeState":{"tun_mode":true},"clash_default_config":{"dns":{"nameserver":["system"]}}}"#.utf8)
        assert(tryRange(initial) == PandaConfig.defaultRange)
        let changed = try PandaConfig.changing(initial, value: PandaConfig.compatibleRange)
        var expected = try PandaConfig.object(initial)
        var defaults = expected["clash_default_config"] as! [String: Any]
        var dns = defaults["dns"] as! [String: Any]; dns["fake-ip-range"] = PandaConfig.compatibleRange; defaults["dns"] = dns; expected["clash_default_config"] = defaults
        assert(NSDictionary(dictionary: try! PandaConfig.object(changed)).isEqual(to: expected))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("company-direct-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("config.json"); try initial.write(to: file)
        func rejects(_ work: () throws -> Void) { do { try work(); fatalError("Expected rejection") } catch {} }
        rejects { _ = try PandaFileStore.apply(file: file, isRunning: { true }) }
        assert(try! Data(contentsOf: file) == initial)
        let backup = try PandaFileStore.apply(file: file, isRunning: { false })
        assert(try! Data(contentsOf: backup) == initial)
        assert(tryRange(try! Data(contentsOf: file)) == PandaConfig.compatibleRange)
        let attributes = try FileManager.default.attributesOfItem(atPath: backup.path)
        assert((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        rejects { _ = try PandaFileStore.apply(file: file, isRunning: { false }) }
        assert(try! Data(contentsOf: PandaFileStore.backupURL(file)) == initial)
        // Simulate another valid preference change after applying; restoring must retain it.
        var newer = try PandaConfig.object(Data(contentsOf: file)); newer["laterPreference"] = 123
        try JSONSerialization.data(withJSONObject: newer).write(to: file)
        try PandaFileStore.restore(file: file, isRunning: { false })
        let restored = try PandaConfig.object(Data(contentsOf: file))
        assert(restored["laterPreference"] as? Int == 123)
        assert(tryRange(try! Data(contentsOf: file)) == PandaConfig.defaultRange)
        assert(try! PandaConfig.dns(restored)["fake-ip-range"] == nil)
        // Guard against PandaFan reopening between backup and replacement.
        try initial.write(to: file); var calls = 0
        rejects { _ = try PandaFileStore.apply(file: file, isRunning: { calls += 1; return calls >= 2 }) }
        assert(try! Data(contentsOf: file) == initial)
        let foreign = PandaRoute("destination: 198.18.0.0\nmask: 255.255.0.0\ninterface: utun1")
        let good = PandaRoute("destination: 128.0.0.0\nmask: 128.0.0.0\ninterface: utun6")
        let state = PandaInspection(running: true, range: PandaConfig.defaultRange, current: foreign, candidate: good, pandaInterfaces: ["utun6"])
        assert(state.conflict && !state.candidateConflict)
        let occupied = PandaInspection(running: false, range: PandaConfig.defaultRange, current: foreign, candidate: PandaRoute("destination: 198.19.0.0\ninterface: utun1"), pandaInterfaces: [])
        assert(occupied.candidateConflict)
        print("PASS: field-only edit/restore, private backup, running/reopening guards, idempotence, route conflict classification")
    }
    static func tryRange(_ data: Data) -> String { try! PandaConfig.range(data) }
}
