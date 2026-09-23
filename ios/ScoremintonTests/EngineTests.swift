import XCTest
@testable import Scoreminton

private func cfg(
    format: Format = .single,
    scoring: ScoringSystem = .rally,
    target: Int? = nil,
    deuce: Bool? = nil,
    cap: Int? = nil
) -> MatchConfig {
    let p = Preset.of(scoring)
    return MatchConfig(
        format: format,
        scoring: scoring,
        bestOf: 3,
        target: target ?? p.target,
        deuce: deuce ?? p.deuce,
        cap: cap ?? p.cap,
        teams: PerSide(
            A: TeamInfo(name: "A", players: ["a1", "a2"]),
            B: TeamInfo(name: "B", players: ["b1", "b2"])
        ),
        firstServer: .A
    )
}

/// Play rallies, auto-dismissing intervals.
private func play(_ m: MatchState, _ seq: String) -> MatchState {
    var m = m
    for ch in seq {
        m = m.scoringRally(ch == "A" ? .A : .B)
        if m.status == .interval { m = m.resumedFromInterval() }
    }
    return m
}

private func rep(_ s: String, _ n: Int) -> String { String(repeating: s, count: n) }
private func score(_ a: Int, _ b: Int) -> PerSide<Int> { PerSide(A: a, B: b) }

final class RallyPointTests: XCTestCase {
    func testAwardsPointAndPassesServe() {
        let m = play(.create(cfg()), "B")
        XCTAssertEqual(m.currentGame.score, score(0, 1))
        XCTAssertEqual(m.currentGame.servingTeam, .B)
    }

    func testWinsAt21() {
        let m = play(.create(cfg()), rep("A", 21))
        XCTAssertEqual(m.currentGame.winner, .A)
        XCTAssertEqual(m.status, .gameOver)
    }

    func testDeuce20AllNeeds22() {
        var m = play(.create(cfg()), rep("AB", 20))
        XCTAssertEqual(m.currentGame.score, score(20, 20))
        m = play(m, "A")
        XCTAssertNil(m.currentGame.winner)
        m = play(m, "A")
        XCTAssertEqual(m.currentGame.winner, .A)
        XCTAssertEqual(m.currentGame.score, score(22, 20))
    }

    func testCap29AllNextPointWins() {
        var m = play(.create(cfg()), rep("AB", 29))
        XCTAssertNil(m.currentGame.winner)
        m = play(m, "B")
        XCTAssertEqual(m.currentGame.winner, .B)
        XCTAssertEqual(m.currentGame.score, score(29, 30))
    }

    func testDeuceOffFirstToTargetWins() {
        let m = play(.create(cfg(deuce: false)), rep("AB", 20) + "B")
        XCTAssertEqual(m.currentGame.winner, .B)
    }

    func testSinglesServiceCourtByParity() {
        var m = MatchState.create(cfg())
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .R)
        m = play(m, "A")
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .L)
        m = play(m, "B")
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .L) // B has 1
    }
}

final class RallyPointDoublesTests: XCTestCase {
    private func d() -> MatchState { .create(cfg(format: .double)) }

    func testServingSideWinsSameServerSwitchesCourt() {
        var m = d()
        XCTAssertEqual(m.currentGame.server, 0)
        m = play(m, "A")
        XCTAssertEqual(m.currentGame.server, 0)
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .L)
        XCTAssertEqual(m.currentGame.rightCourt.A, 1)
    }

    func testReceivingSideWinsNoPositionChange() {
        let m = play(d(), "B")
        XCTAssertEqual(m.currentGame.servingTeam, .B)
        XCTAssertEqual(m.currentGame.rightCourt.B, 0)
        XCTAssertEqual(m.currentGame.server, 1)
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .L)
        XCTAssertEqual(m.config.receiver(m.currentGame), 1)
    }

    func testSwapPositionsBeforeFirstRally() {
        var m = d().swappingPositions(.A)
        XCTAssertEqual(m.currentGame.server, 1)
        m = play(m, "A")
        XCTAssertEqual(m.swappingPositions(.A), m)
    }
}

final class ServiceOverTests: XCTestCase {
    // classic 15-point game with setting to 17
    private func so(format: Format = .single) -> MatchState {
        .create(cfg(format: format, scoring: .serviceOver, target: 15, cap: 17))
    }

    func testDefaultPreset30SettingTo32() {
        XCTAssertEqual(Preset.serviceOver, Preset(target: 30, deuce: true, cap: 32))
        var m = MatchState.create(cfg(scoring: .serviceOver))
        for _ in 0..<15 { m = m.scoringRally(.A) }
        XCTAssertEqual(m.status, .interval)
        m = play(m.resumedFromInterval(), rep("A", 15))
        XCTAssertEqual(m.currentGame.winner, .A)
        XCTAssertEqual(m.currentGame.score.A, 30)
    }

    func testReceiverWinningOnlyGainsServe() {
        var m = play(so(), "B")
        XCTAssertEqual(m.currentGame.score, score(0, 0))
        XCTAssertEqual(m.currentGame.servingTeam, .B)
        m = play(m, "B")
        XCTAssertEqual(m.currentGame.score, score(0, 1))
    }

    func testWinsAt15() {
        XCTAssertEqual(play(so(), rep("A", 15)).currentGame.winner, .A)
    }

    func testSetting14AllPlaysTo17() {
        var m = play(so(), rep("A", 14) + "B" + rep("B", 14))
        XCTAssertEqual(m.currentGame.score, score(14, 14))
        m = play(m, "B")
        XCTAssertNil(m.currentGame.winner)
        m = play(m, "BB")
        XCTAssertEqual(m.currentGame.winner, .B)
        XCTAssertEqual(m.currentGame.score, score(14, 17))
    }

    func testNoSettingWhenOpponentBelow() {
        let m = play(so(), rep("A", 13) + "B" + rep("B", 14) + "A" + "A")
        XCTAssertEqual(m.currentGame.score, score(14, 14))
        let m2 = play(so(), rep("A", 14) + "B" + rep("B", 13) + "A" + "A")
        XCTAssertEqual(m2.currentGame.score, score(15, 13))
        XCTAssertEqual(m2.currentGame.winner, .A)
    }

    func testDoublesOneHandDownThenTwoServers() {
        var m = so(format: .double)
        XCTAssertEqual(m.currentGame.serverNumber, 2)
        m = play(m, "B") // service over immediately
        XCTAssertEqual(m.currentGame.servingTeam, .B)
        XCTAssertEqual(m.currentGame.serverNumber, 1)
        XCTAssertEqual(m.currentGame.server, 0)
        m = play(m, "B") // B scores, server switches court
        XCTAssertEqual(m.currentGame.score.B, 1)
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .L)
        m = play(m, "A") // second server
        XCTAssertEqual(m.currentGame.servingTeam, .B)
        XCTAssertEqual(m.currentGame.serverNumber, 2)
        XCTAssertEqual(m.currentGame.server, 1)
        XCTAssertEqual(m.config.serviceCourt(m.currentGame), .R) // b2 now in right court
        m = play(m, "A") // service over
        XCTAssertEqual(m.currentGame.servingTeam, .A)
        XCTAssertEqual(m.currentGame.serverNumber, 1)
        XCTAssertEqual(m.currentGame.server, m.currentGame.rightCourt.A)
        XCTAssertEqual(m.currentGame.score, score(0, 1))
    }
}

final class MatchFlowTests: XCTestCase {
    func testIntervalAndDecidingGameSwitchesEnds() {
        var m = MatchState.create(cfg())
        for _ in 0..<11 { m = m.scoringRally(.A) }
        XCTAssertEqual(m.status, .interval)
        XCTAssertEqual(m.leftTeam, .A) // not deciding game
        m = m.resumedFromInterval()
        m = play(m, rep("A", 10))
        m = m.startingNextGame()
        XCTAssertEqual(m.leftTeam, .B)
        m = play(m, rep("B", 21))
        m = m.startingNextGame()
        XCTAssertEqual(m.games.count, 3)
        XCTAssertEqual(m.currentGame.servingTeam, .B)
        let before = m.leftTeam
        for _ in 0..<11 { m = m.scoringRally(.A) }
        XCTAssertEqual(m.status, .interval)
        XCTAssertNotEqual(m.leftTeam, before)
    }

    func testBestOf3EndsAtTwoGames() {
        var m = play(.create(cfg()), rep("A", 21))
        m = m.startingNextGame()
        m = play(m, rep("A", 21))
        XCTAssertEqual(m.status, .matchOver)
        XCTAssertEqual(m.winner, .A)
    }

    func testGameWinnerServesFirstNextGame() {
        let m = play(.create(cfg()), rep("B", 21)).startingNextGame()
        XCTAssertEqual(m.currentGame.servingTeam, .B)
    }

    func testRoundTripsThroughJSON() throws {
        let m = play(.create(cfg(format: .double)), "ABBA")
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(MatchState.self, from: data), m)
    }
}

final class GamePointTests: XCTestCase {
    func testDetectsGamePointIncludingDeuce() {
        let c = cfg()
        XCTAssertTrue(c.isGamePoint(score(20, 10), .A))
        XCTAssertFalse(c.isGamePoint(score(20, 20), .A))
        XCTAssertTrue(c.isGamePoint(score(21, 20), .A))
        XCTAssertTrue(c.isGamePoint(score(29, 29), .B))
        let so = cfg(scoring: .serviceOver, target: 15, cap: 17)
        XCTAssertFalse(so.isGamePoint(score(14, 14), .A))
        XCTAssertTrue(so.isGamePoint(score(16, 14), .A))
    }
}
