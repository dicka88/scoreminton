export type Side = 'A' | 'B'
export type Format = 'single' | 'double'
export type ScoringSystem = 'rally' | 'serviceOver'
export type Court = 'R' | 'L'
export type PlayerIndex = 0 | 1

export interface TeamInfo {
  name: string
  players: string[] // 1 (single) or 2 (double)
}

export interface MatchConfig {
  format: Format
  scoring: ScoringSystem
  bestOf: 1 | 3
  target: number
  /** rally: win by 2; serviceOver: "setting" at (target-1)-all, play to cap */
  deuce: boolean
  cap: number
  teams: Record<Side, TeamInfo>
  firstServer: Side
}

export interface RallyEvent {
  winner: Side
  score: Record<Side, number>
  /** server of the rally that was just played */
  servingTeam: Side
  server: PlayerIndex
  point: boolean
}

export interface GameState {
  score: Record<Side, number>
  servingTeam: Side
  /** player index of the server within servingTeam */
  server: PlayerIndex
  /** player index standing in the right service court, per team (doubles) */
  rightCourt: Record<Side, PlayerIndex>
  /** service-over doubles: 1st or 2nd server of the hand */
  serverNumber: 1 | 2
  intervalDone: boolean
  rallies: RallyEvent[]
  winner?: Side
}

export type MatchStatus = 'playing' | 'interval' | 'gameOver' | 'matchOver'

export interface MatchState {
  id: string
  config: MatchConfig
  games: GameState[]
  /** team displayed on the left side of the screen */
  leftTeam: Side
  status: MatchStatus
  winner?: Side
  startedAt: number
  endedAt?: number
}

export interface MatchRecord {
  id: string
  config: MatchConfig
  games: { score: Record<Side, number>; winner?: Side }[]
  winner?: Side
  startedAt: number
  endedAt: number
}
