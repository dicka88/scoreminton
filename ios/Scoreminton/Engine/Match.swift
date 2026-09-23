import Foundation

extension GameState {
    static func new(servingTeam: Side) -> GameState {
        GameState(
            score: PerSide(A: 0, B: 0),
            servingTeam: servingTeam,
            server: 0,
            rightCourt: PerSide(A: 0, B: 0),
            // service-over doubles: the side serving first in a game gets only one hand
            serverNumber: 2,
            intervalDone: false,
            rallies: [],
            winner: nil
        )
    }
}

extension MatchState {
    static func create(_ config: MatchConfig, now: Date = .now) -> MatchState {
        MatchState(
            id: UUID().uuidString,
            config: config,
            games: [.new(servingTeam: config.firstServer)],
            leftTeam: .A,
            status: .playing,
            winner: nil,
            startedAt: now,
            endedAt: nil
        )
    }

    var currentGame: GameState { games[games.count - 1] }

    var gamesWon: PerSide<Int> {
        var w = PerSide(A: 0, B: 0)
        for g in games { if let win = g.winner { w[win] += 1 } }
        return w
    }

    /// Resolve a rally won by `winner`. Returns a new state; `self` is not mutated.
    /// `now` stamps the match end, so replaying a saved action log gives the same state.
    func scoringRally(_ winner: Side, now: Date = .now) -> MatchState {
        guard status == .playing else { return self }
        let cfg = config
        let gi = games.count - 1
        var g = applyRally(cfg, games[gi], winner)
        var next = self

        if let gw = g.winner {
            next.games[gi] = g
            if next.gamesWon[gw] >= cfg.gamesToWin {
                next.status = .matchOver
                next.winner = gw
                next.endedAt = now
            } else {
                next.status = .gameOver
            }
            return next
        }

        let lead = max(g.score.A, g.score.B)
        if !g.intervalDone && lead >= cfg.intervalPoint && lead < cfg.target {
            g.intervalDone = true
            next.status = .interval
            if cfg.isDecidingGame(gi) { next.leftTeam = leftTeam.other }
        }
        next.games[gi] = g
        return next
    }

    func resumedFromInterval() -> MatchState {
        guard status == .interval else { return self }
        var m = self
        m.status = .playing
        return m
    }

    func startingNextGame() -> MatchState {
        guard status == .gameOver, let w = currentGame.winner else { return self }
        var m = self
        m.games.append(.new(servingTeam: w))
        m.leftTeam = leftTeam.other
        m.status = .playing
        return m
    }

    func swappingSides() -> MatchState {
        var m = self
        m.leftTeam = leftTeam.other
        return m
    }

    /// Swap player positions of a team (doubles). Only before the first rally of a game.
    func swappingPositions(_ side: Side) -> MatchState {
        var g = currentGame
        guard config.format == .double, g.rallies.isEmpty else { return self }
        g.rightCourt[side] = partner(g.rightCourt[side])
        if side == g.servingTeam { g.server = g.rightCourt[side] }
        var m = self
        m.games[games.count - 1] = g
        return m
    }

    /// Change which team serves first. Only before the first rally of the first game.
    func settingFirstServer(_ side: Side) -> MatchState {
        guard games.count == 1, currentGame.rallies.isEmpty else { return self }
        var g = GameState.new(servingTeam: side)
        g.rightCourt = currentGame.rightCourt
        g.server = g.rightCourt[side]
        var m = self
        m.config.firstServer = side
        m.games = [g]
        return m
    }

    func toRecord() -> MatchRecord {
        MatchRecord(
            id: id,
            config: config,
            games: games.map { GameSummary(score: $0.score, winner: $0.winner) },
            winner: winner,
            startedAt: startedAt,
            endedAt: endedAt ?? .now
        )
    }
}

private func applyRally(_ cfg: MatchConfig, _ g: GameState, _ winner: Side) -> GameState {
    let serving = g.servingTeam
    var next = g
    var point = false

    if winner == serving {
        // Serving side wins: point in both systems, same server switches court.
        next.score[winner] += 1
        point = true
        if cfg.format == .double { next.rightCourt[winner] = partner(g.rightCourt[winner]) }
    } else if cfg.scoring == .rally {
        next.score[winner] += 1
        point = true
        next.servingTeam = winner
        next.server = cfg.format == .double
            ? next.playerInCourt(winner, parityCourt(next.score[winner]))
            : 0
    } else if cfg.format == .double && g.serverNumber == 1 {
        // service-over doubles: partner becomes second server
        next.serverNumber = 2
        next.server = partner(g.server)
    } else {
        // service over
        next.servingTeam = winner
        next.serverNumber = 1
        next.server = cfg.format == .double ? next.rightCourt[winner] : 0
    }

    next.rallies.append(RallyEvent(
        winner: winner, score: next.score, servingTeam: serving, server: g.server, point: point
    ))
    next.winner = cfg.gameWinner(next.score)
    return next
}
