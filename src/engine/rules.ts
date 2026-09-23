import type { Court, GameState, MatchConfig, PlayerIndex, Side } from './types'

export const other = (s: Side): Side => (s === 'A' ? 'B' : 'A')
export const partner = (p: PlayerIndex): PlayerIndex => (p === 0 ? 1 : 0)
export const parityCourt = (score: number): Court => (score % 2 === 0 ? 'R' : 'L')

export const PRESETS = {
  rally: { target: 21, deuce: true, cap: 30 },
  serviceOver: { target: 30, deuce: true, cap: 32 },
} as const

/** Winner of the game given the score, or undefined if still in progress. */
export function gameWinner(cfg: MatchConfig, score: Record<Side, number>): Side | undefined {
  for (const s of ['A', 'B'] as const) {
    const me = score[s]
    const opp = score[other(s)]
    if (me < cfg.target) continue
    if (!cfg.deuce) return s
    if (me >= cfg.cap) return s
    if (cfg.scoring === 'rally') {
      if (me - opp >= 2) return s
    } else {
      // setting triggered once both reached target-1; then first to cap wins
      if (opp < cfg.target - 1) return s
    }
  }
  return undefined
}

export const intervalPoint = (cfg: MatchConfig) => Math.ceil(cfg.target / 2)

export const gamesToWin = (cfg: MatchConfig) => Math.ceil(cfg.bestOf / 2)

export const isDecidingGame = (cfg: MatchConfig, gameIndex: number) =>
  gameIndex === cfg.bestOf - 1

/** Court the given player of a team stands in (doubles). */
export function playerCourt(g: GameState, side: Side, p: PlayerIndex): Court {
  return g.rightCourt[side] === p ? 'R' : 'L'
}

export function playerInCourt(g: GameState, side: Side, c: Court): PlayerIndex {
  return c === 'R' ? g.rightCourt[side] : partner(g.rightCourt[side])
}

/** Court the current server serves from. */
export function serviceCourt(cfg: MatchConfig, g: GameState): Court {
  if (cfg.format === 'single') return parityCourt(g.score[g.servingTeam])
  return playerCourt(g, g.servingTeam, g.server)
}

/** Receiver stands diagonally, i.e. in the same-named court. */
export function receiver(cfg: MatchConfig, g: GameState): PlayerIndex {
  if (cfg.format === 'single') return 0
  return playerInCourt(g, other(g.servingTeam), serviceCourt(cfg, g))
}

/** True if `side` would win the game by scoring the next point. */
export function isGamePoint(cfg: MatchConfig, score: Record<Side, number>, side: Side): boolean {
  if (gameWinner(cfg, score)) return false
  return gameWinner(cfg, { ...score, [side]: score[side] + 1 }) === side
}
