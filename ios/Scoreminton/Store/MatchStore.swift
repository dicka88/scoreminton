import Foundation
import Observation

/// Active match with an undo stack, persisted on every change.
@Observable
final class MatchStore {
    private static let activeFile = "active.json"
    private static let lastConfigFile = "lastConfig.json"
    private static let maxHistory = 500

    private(set) var past: [MatchState] = []
    private(set) var present: MatchState?

    var canUndo: Bool { !past.isEmpty }

    init(persist: Bool = true) {
        self.persist = persist
        if persist, let snap = Storage.read(Self.activeFile, as: ActiveSnapshot.self) {
            past = snap.past
            present = snap.present
        }
    }

    private let persist: Bool

    private func save() {
        guard persist else { return }
        Storage.write(Self.activeFile, present.map { ActiveSnapshot(past: past, present: $0) })
    }

    private func push(_ next: MatchState) {
        guard let cur = present, next != cur else { return }
        past.append(cur)
        if past.count > Self.maxHistory { past.removeFirst(past.count - Self.maxHistory) }
        present = next
        save()
    }

    private func replace(_ next: MatchState) {
        guard next != present else { return }
        present = next
        save()
    }

    func new(_ config: MatchConfig) {
        if persist { Storage.write(Self.lastConfigFile, config) }
        past = []
        present = .create(config)
        save()
    }

    func clear() {
        past = []
        present = nil
        save()
    }

    func rally(_ side: Side) { if let m = present { push(m.scoringRally(side)) } }

    func undo() {
        guard let prev = past.popLast() else { return }
        present = prev
        save()
    }

    // Modal dismissals replace the present so one undo reverts the last rally.
    func resume() { if let m = present { replace(m.resumedFromInterval()) } }
    func nextGame() { if let m = present { replace(m.startingNextGame()) } }

    func swapSides() { if let m = present { push(m.swappingSides()) } }
    func swapPositions(_ side: Side) { if let m = present { push(m.swappingPositions(side)) } }
    func setFirstServer(_ side: Side) { if let m = present { push(m.settingFirstServer(side)) } }

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

    private func save() {
        guard persist else { return }
        Storage.write(Self.file, records)
    }

    func add(_ r: MatchRecord) {
        records = [r] + records.filter { $0.id != r.id }
        save()
    }

    func delete(_ id: String) {
        records.removeAll { $0.id == id }
        save()
    }
}
