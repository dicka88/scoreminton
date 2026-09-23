import Foundation

func partner(_ p: PlayerIndex) -> PlayerIndex { p == 0 ? 1 : 0 }
func parityCourt(_ score: Int) -> Court { score % 2 == 0 ? .R : .L }

struct Preset: Equatable {
    var target: Int
    var deuce: Bool
    var cap: Int

    static let rally = Preset(target: 21, deuce: true, cap: 30)
    static let serviceOver = Preset(target: 30, deuce: true, cap: 32)

    static func of(_ scoring: ScoringSystem) -> Preset {
        scoring == .rally ? .rally : .serviceOver
    }
}

extension MatchConfig {
    /// Winner of the game given the score, or nil if still in progress.
    func gameWinner(_ score: PerSide<Int>) -> Side? {
        for s in Side.allCases {
            let me = score[s]
            let opp = score[s.other]
            if me < target { continue }
            if !deuce { return s }
            if me >= cap { return s }
            if scoring == .rally {
                if me - opp >= 2 { return s }
            } else {
                // setting triggered once both reached target-1; then first to cap wins
                if opp < target - 1 { return s }
            }
        }
        return nil
    }

    var intervalPoint: Int { (target + 1) / 2 }
    var gamesToWin: Int { (bestOf + 1) / 2 }
    func isDecidingGame(_ gameIndex: Int) -> Bool { gameIndex == bestOf - 1 }

    /// Court the current server serves from.
    func serviceCourt(_ g: GameState) -> Court {
        if format == .single { return parityCourt(g.score[g.servingTeam]) }
        return g.playerCourt(g.servingTeam, g.server)
    }

    /// Receiver stands diagonally, i.e. in the same-named court.
    func receiver(_ g: GameState) -> PlayerIndex {
        if format == .single { return 0 }
        return g.playerInCourt(g.servingTeam.other, serviceCourt(g))
    }

    /// True if `side` would win the game by scoring the next point.
    func isGamePoint(_ score: PerSide<Int>, _ side: Side) -> Bool {
        if gameWinner(score) != nil { return false }
        var next = score
        next[side] += 1
        return gameWinner(next) == side
    }
}

extension GameState {
    /// Court the given player of a team stands in (doubles).
    func playerCourt(_ side: Side, _ p: PlayerIndex) -> Court {
        rightCourt[side] == p ? .R : .L
    }

    func playerInCourt(_ side: Side, _ c: Court) -> PlayerIndex {
        c == .R ? rightCourt[side] : partner(rightCourt[side])
    }
}
