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

    /// Serial queue so writes happen off the main thread, in order.
    private static let queue = DispatchQueue(label: "scoreminton.storage", qos: .utility)

    static func read<T: Decodable>(_ name: String, as: T.Type = T.self) -> T? {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Write (or delete, for nil) and report whether it landed, so the UI can warn instead of
    /// failing silently. Returns false when the disk is full or the file can't be written.
    @discardableResult
    static func writeNow<T: Encodable>(_ name: String, _ value: T?) -> Bool {
        let url = dir.appendingPathComponent(name)
        guard let value else {
            try? FileManager.default.removeItem(at: url)
            return true
        }
        do {
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Background write; `done` runs on the main queue with the result.
    static func write<T: Encodable & Sendable>(_ name: String, _ value: T?, done: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        queue.async {
            let ok = writeNow(name, value)
            if let done { Task { @MainActor in done(ok) } }
        }
    }

    /// Block until pending writes land (tests, app backgrounding).
    static func flush() { queue.sync {} }
}

/// One user action on the active match. Replaying the ops over `base` rebuilds the present state.
struct Op: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case rally, resume, nextGame, swapSides, swapPositions, firstServer
    }
    var t: Kind
    var side: Side?
    var at: Date?

    static func rally(_ side: Side, at: Date = .now) -> Op { Op(t: .rally, side: side, at: at) }

    /// Modal dismissals ride along with the rally before them, so one undo reverts that rally.
    var rides: Bool { t == .resume || t == .nextGame }
}

/// Persisted active match: the starting state plus the list of actions.
/// Kilobytes for a full match, versus megabytes for a stack of full snapshots.
struct StoredMatch: Codable, Sendable {
    var v = 2
    var base: MatchState
    var ops: [Op]
}

/// v1 format: full-state undo stack. Still read so a match in progress survives the update.
struct LegacySnapshot: Codable, Sendable {
    var past: [MatchState]
    var present: MatchState
}
