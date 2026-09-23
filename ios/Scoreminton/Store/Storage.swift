import Foundation

/// JSON files in Application Support. Data stays on device.
enum Storage {
    private static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Scoreminton", isDirectory: true)
        // UI tests start from a clean slate
        if CommandLine.arguments.contains("-uiTestReset") { try? FileManager.default.removeItem(at: url) }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        if let seed = ProcessInfo.processInfo.environment["UITEST_LAST_CONFIG"] {
            try? Data(seed.utf8).write(to: url.appendingPathComponent("lastConfig.json"))
        }
        return url
    }()

    /// Serial queue so large undo stacks are encoded off the main thread, in order.
    private static let queue = DispatchQueue(label: "scoreminton.storage", qos: .utility)

    static func read<T: Decodable>(_ name: String, as: T.Type = T.self) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func write<T: Encodable & Sendable>(_ name: String, _ value: T?) {
        let url = dir.appendingPathComponent(name)
        queue.async {
            guard let value else {
                try? FileManager.default.removeItem(at: url)
                return
            }
            // storage failure (disk full) — app keeps working in memory
            if let data = try? JSONEncoder().encode(value) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    /// Block until pending writes land (tests, app backgrounding).
    static func flush() { queue.sync {} }
}

struct ActiveSnapshot: Codable, Sendable {
    var past: [MatchState]
    var present: MatchState
}
