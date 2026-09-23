import XCTest
@testable import Scoreminton

/// Mirrors `src/store/matchStore.test.ts` on the web.
final class MatchStoreTests: XCTestCase {
    private func config(scoring: ScoringSystem = .rally, bestOf: Int = 3) -> MatchConfig {
        let p = Preset.of(scoring)
        return MatchConfig(
            format: .double, scoring: scoring, bestOf: bestOf,
            target: p.target, deuce: p.deuce, cap: p.cap,
            teams: PerSide(A: TeamInfo(name: "", players: ["", ""]), B: TeamInfo(name: "", players: ["", ""])),
            firstServer: .A
        )
    }

    private func start(_ c: MatchConfig? = nil) -> MatchStore {
        let s = MatchStore(persist: false)
        s.new(c ?? config())
        return s
    }

    private func play(_ s: MatchStore, _ seq: String) {
        for ch in seq { s.rally(ch == "A" ? .A : .B) }
    }

    private func score(_ s: MatchStore) -> String {
        let g = s.present!.currentGame
        return "\(g.score.A)-\(g.score.B)"
    }

    func testUndoRevertsOneRally() {
        let s = start()
        play(s, "AAB")
        XCTAssertEqual(score(s), "2-1")
        s.undo()
        XCTAssertEqual(score(s), "2-0")
        XCTAssertEqual(s.present!.currentGame.servingTeam, .A)
    }

    func testOneUndoFromIntervalGoesBeforeTheIntervalRally() {
        let s = start()
        play(s, String(repeating: "A", count: 11))
        XCTAssertEqual(s.present!.status, .interval)
        s.resume()
        play(s, "B")
        s.undo()
        XCTAssertEqual(s.present!.status, .playing)
        XCTAssertEqual(score(s), "11-0")
        s.undo()
        XCTAssertEqual(score(s), "10-0")
        XCTAssertEqual(s.present!.status, .playing)
    }

    func testUndoAfterNextGameReturnsToGameWinningRally() {
        let s = start()
        play(s, String(repeating: "A", count: 11))
        s.resume()
        play(s, String(repeating: "A", count: 10))
        XCTAssertEqual(s.present!.status, .gameOver)
        s.nextGame()
        XCTAssertEqual(s.present!.games.count, 2)
        s.undo()
        XCTAssertEqual(s.present!.games.count, 1)
        XCTAssertEqual(score(s), "20-0")
    }

    func testReplayAfterReloadGivesSameStateIncludingEndTime() throws {
        let s = start(config(bestOf: 1))
        play(s, String(repeating: "A", count: 11))
        s.resume()
        play(s, String(repeating: "A", count: 10))
        XCTAssertEqual(s.present!.status, .matchOver)
        let stored = StoredMatch(base: s.base!, ops: s.ops)
        let data = try JSONEncoder().encode(stored)
        let back = try JSONDecoder().decode(StoredMatch.self, from: data)
        XCTAssertEqual(MatchStore.replay(back.base, back.ops), s.present)
        XCTAssertTrue(s.canUndo)
    }

    func testLongServiceOverMatchStaysSmall() throws {
        let s = start(config(scoring: .serviceOver))
        var i = 0
        while s.present!.status != .matchOver && i < 2000 {
            switch s.present!.status {
            case .interval: s.resume()
            case .gameOver: s.nextGame()
            default: s.rally(i % 3 == 0 ? .B : .A)
            }
            i += 1
        }
        let size = try JSONEncoder().encode(StoredMatch(base: s.base!, ops: s.ops)).count
        XCTAssertGreaterThan(s.ops.count, 150)
        XCTAssertLessThan(size, 60_000)
    }

    func testLegacySnapshotIsNotReadAsNewFormat() throws {
        let m = MatchState.create(config())
        let data = try JSONEncoder().encode(LegacySnapshot(past: [m], present: m))
        XCTAssertNil(try? JSONDecoder().decode(StoredMatch.self, from: data))
        XCTAssertEqual(try JSONDecoder().decode(LegacySnapshot.self, from: data).present, m)
    }
}
