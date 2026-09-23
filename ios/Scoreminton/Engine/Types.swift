import Foundation

enum Side: String, Codable, CaseIterable, Sendable {
    case A, B
    var other: Side { self == .A ? .B : .A }
}

enum Format: String, Codable, Sendable { case single, double }
enum ScoringSystem: String, Codable, Sendable { case rally, serviceOver }
enum Court: String, Codable, Sendable { case R, L }

/// Index of a player within a team: 0 or 1.
typealias PlayerIndex = Int

/// A value per team, indexable by `Side`.
struct PerSide<T> {
    var A: T
    var B: T

    init(A: T, B: T) {
        self.A = A
        self.B = B
    }

    subscript(side: Side) -> T {
        get { side == .A ? A : B }
        set { if side == .A { A = newValue } else { B = newValue } }
    }
}

extension PerSide: Equatable where T: Equatable {}
extension PerSide: Hashable where T: Hashable {}
extension PerSide: Codable where T: Codable {}
extension PerSide: Sendable where T: Sendable {}

struct TeamInfo: Codable, Equatable, Sendable {
    var name: String
    /// 1 (single) or 2 (double)
    var players: [String]
}

struct MatchConfig: Codable, Equatable, Sendable {
    var format: Format
    var scoring: ScoringSystem
    /// 1 or 3
    var bestOf: Int
    var target: Int
    /// rally: win by 2; serviceOver: "setting" at (target-1)-all, play to cap
    var deuce: Bool
    var cap: Int
    var teams: PerSide<TeamInfo>
    var firstServer: Side
}

struct RallyEvent: Codable, Equatable, Sendable {
    var winner: Side
    var score: PerSide<Int>
    /// server of the rally that was just played
    var servingTeam: Side
    var server: PlayerIndex
    var point: Bool
}

struct GameState: Codable, Equatable, Sendable {
    var score: PerSide<Int>
    var servingTeam: Side
    /// player index of the server within servingTeam
    var server: PlayerIndex
    /// player index standing in the right service court, per team (doubles)
    var rightCourt: PerSide<PlayerIndex>
    /// service-over doubles: 1st or 2nd server of the hand
    var serverNumber: Int
    var intervalDone: Bool
    var rallies: [RallyEvent]
    var winner: Side?
}

enum MatchStatus: String, Codable, Sendable {
    case playing, interval, gameOver, matchOver
}

struct MatchState: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var config: MatchConfig
    var games: [GameState]
    /// team displayed on the left (or top) side of the screen
    var leftTeam: Side
    var status: MatchStatus
    var winner: Side?
    var startedAt: Date
    var endedAt: Date?
}

struct GameSummary: Codable, Equatable, Sendable {
    var score: PerSide<Int>
    var winner: Side?
}

struct MatchRecord: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var config: MatchConfig
    var games: [GameSummary]
    var winner: Side?
    var startedAt: Date
    var endedAt: Date
}
