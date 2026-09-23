import Foundation
import Observation

/// Active match as a starting state plus an action log, persisted on every change.
/// Undo drops the last action and replays the rest.
@Observable
final class MatchStore {
    private static let activeFile = "active.json"
    private static let lastConfigFile = "lastConfig.json"

    private(set) var base: MatchState?
    private(set) var ops: [Op] = []
    private(set) var present: MatchState?
    /// False after a save failed (disk full); the UI shows a warning while it stays false.
    private(set) var saved = true

    var canUndo: Bool { ops.contains { !$0.rides } }

    init(persist: Bool = true) {
        self.persist = persist
        guard persist else { return }
        if let stored = Storage.read(Self.activeFile, as: StoredMatch.self) {
            base = stored.base
            ops = stored.ops
            present = Self.replay(stored.base, stored.ops)
        } else if let legacy = Storage.read(Self.activeFile, as: LegacySnapshot.self) {
            base = legacy.present
            present = legacy.present
        }
    }

    private let persist: Bool

    private func save() {
        guard persist else { return }
        let value = base.map { StoredMatch(base: $0, ops: ops) }
        Storage.write(Self.activeFile, value) { [weak self] ok in self?.saved = ok }
    }

    static func apply(_ m: MatchState, _ op: Op) -> MatchState {
        switch op.t {
        case .rally: m.scoringRally(op.side ?? .A, now: op.at ?? .now)
        case .resume: m.resumedFromInterval()
        case .nextGame: m.startingNextGame()
        case .swapSides: m.swappingSides()
        case .swapPositions: m.swappingPositions(op.side ?? .A)
        case .firstServer: m.settingFirstServer(op.side ?? .A)
        }
    }

    static func replay(_ base: MatchState, _ ops: [Op]) -> MatchState {
        ops.reduce(base, apply)
    }

    private func record(_ op: Op) {
        guard let cur = present else { return }
        let next = Self.apply(cur, op)
        guard next != cur else { return }
        ops.append(op)
        present = next
        save()
    }

    func new(_ config: MatchConfig) {
        if persist { Storage.write(Self.lastConfigFile, config) }
        let m = MatchState.create(config)
        base = m
        ops = []
        present = m
        save()
    }

    func clear() {
        base = nil
        ops = []
        present = nil
        save()
    }

    func rally(_ side: Side) { record(.rally(side)) }

    func undo() {
        guard let base else { return }
        var rest = ops
        while let last = rest.last, last.rides { rest.removeLast() }
        guard !rest.isEmpty else { return }
        rest.removeLast()
        ops = rest
        present = Self.replay(base, rest)
        save()
    }

    func resume() { record(Op(t: .resume)) }
    func nextGame() { record(Op(t: .nextGame)) }
    func swapSides() { record(Op(t: .swapSides)) }
    func swapPositions(_ side: Side) { record(Op(t: .swapPositions, side: side)) }
    func setFirstServer(_ side: Side) { record(Op(t: .firstServer, side: side)) }

    static func lastConfig() -> MatchConfig? { Storage.read(lastConfigFile) }
}

/// Finished matches, newest first.
@Observable
final class HistoryStore {
    private static let file = "history.json"
    private(set) var records: [MatchRecord]

    private let persist: Bool

    init(persist: Bool = true) {
        self.persist = persist
        records = persist ? (Storage.read(Self.file) ?? []) : []
    }

    /// Saved synchronously so the caller knows whether the result is safe before clearing the match.
    @discardableResult
    private func save(_ next: [MatchRecord]) -> Bool {
        guard persist else { records = next; return true }
        guard Storage.writeNow(Self.file, next) else { return false }
        records = next
        return true
    }

    /// Returns false when the result could not be written (disk full).
    @discardableResult
    func add(_ r: MatchRecord) -> Bool {
        save([r] + records.filter { $0.id != r.id })
    }

    func delete(_ id: String) {
        save(records.filter { $0.id != id })
    }
}
