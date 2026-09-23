import {
  gameWinner,
  gamesToWin,
  intervalPoint,
  isDecidingGame,
  other,
  parityCourt,
  partner,
  playerInCourt,
} from './rules'
import type { GameState, MatchConfig, MatchRecord, MatchState, PlayerIndex, RallyEvent, Side } from './types'

const newId = () =>
  typeof crypto !== 'undefined' && 'randomUUID' in crypto
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`

export function newGame(servingTeam: Side): GameState {
  return {
    score: { A: 0, B: 0 },
    servingTeam,
    server: 0,
    rightCourt: { A: 0, B: 0 },
    // service-over doubles: the side serving first in a game gets only one hand
    serverNumber: 2,
    intervalDone: false,
    rallies: [],
  }
}

export function createMatch(config: MatchConfig): MatchState {
  return {
    id: newId(),
    config,
    games: [newGame(config.firstServer)],
    leftTeam: 'A',
    status: 'playing',
    startedAt: Date.now(),
  }
}

export const currentGame = (m: MatchState) => m.games[m.games.length - 1]

export function gamesWon(m: MatchState): Record<Side, number> {
  const w = { A: 0, B: 0 }
  for (const g of m.games) if (g.winner) w[g.winner]++
  return w
}

function applyRally(cfg: MatchConfig, g: GameState, winner: Side): GameState {
  const serving = g.servingTeam
  const next: GameState = {
    ...g,
    score: { ...g.score },
    rightCourt: { ...g.rightCourt },
  }
  let point = false

  if (winner === serving) {
    // Serving side wins: point in both systems, same server switches court.
    next.score[winner]++
    point = true
    if (cfg.format === 'double') next.rightCourt[winner] = partner(g.rightCourt[winner])
  } else if (cfg.scoring === 'rally') {
    next.score[winner]++
    point = true
    next.servingTeam = winner
    next.server =
      cfg.format === 'double' ? playerInCourt(next, winner, parityCourt(next.score[winner])) : 0
  } else if (cfg.format === 'double' && g.serverNumber === 1) {
    // service-over doubles: partner becomes second server
    next.serverNumber = 2
    next.server = partner(g.server)
  } else {
    // service over
    next.servingTeam = winner
    next.serverNumber = 1
    next.server = cfg.format === 'double' ? next.rightCourt[winner] : 0
  }

  const ev: RallyEvent = { winner, score: next.score, servingTeam: serving, server: g.server, point }
  next.rallies = [...g.rallies, ev]
  next.winner = gameWinner(cfg, next.score)
  return next
}

/** Resolve a rally won by `winner`. Returns a new state; input is not mutated. */
export function scoreRally(m: MatchState, winner: Side, now = Date.now()): MatchState {
  if (m.status !== 'playing') return m
  const cfg = m.config
  const gi = m.games.length - 1
  const g = applyRally(cfg, m.games[gi], winner)
  const games = [...m.games.slice(0, gi), g]
  const next: MatchState = { ...m, games }

  if (g.winner) {
    const won = gamesWon(next)
    if (won[g.winner] >= gamesToWin(cfg)) {
      next.status = 'matchOver'
      next.winner = g.winner
      next.endedAt = now
    } else {
      next.status = 'gameOver'
    }
    return next
  }

  const lead = Math.max(g.score.A, g.score.B)
  if (!g.intervalDone && lead >= intervalPoint(cfg) && lead < cfg.target) {
    games[gi] = { ...g, intervalDone: true }
    next.status = 'interval'
    if (isDecidingGame(cfg, gi)) next.leftTeam = other(m.leftTeam)
  }
  return next
}

export function resumeFromInterval(m: MatchState): MatchState {
  return m.status === 'interval' ? { ...m, status: 'playing' } : m
}

export function startNextGame(m: MatchState): MatchState {
  if (m.status !== 'gameOver') return m
  const last = currentGame(m)
  return {
    ...m,
    games: [...m.games, newGame(last.winner!)],
    leftTeam: other(m.leftTeam),
    status: 'playing',
  }
}

export function swapSides(m: MatchState): MatchState {
  return { ...m, leftTeam: other(m.leftTeam) }
}

/** Swap player positions of a team (doubles). Only before the first rally of a game. */
export function swapPositions(m: MatchState, side: Side): MatchState {
  const g = currentGame(m)
  if (m.config.format !== 'double' || g.rallies.length > 0) return m
  const rightCourt = { ...g.rightCourt, [side]: partner(g.rightCourt[side]) }
  const server: PlayerIndex = side === g.servingTeam ? rightCourt[side] : g.server
  return { ...m, games: [...m.games.slice(0, -1), { ...g, rightCourt, server }] }
}

/** Change which team serves first. Only before the first rally of the first game. */
export function setFirstServer(m: MatchState, side: Side): MatchState {
  if (m.games.length !== 1 || currentGame(m).rallies.length > 0) return m
  const g = newGame(side)
  g.rightCourt = currentGame(m).rightCourt
  g.server = g.rightCourt[side]
  return { ...m, config: { ...m.config, firstServer: side }, games: [g] }
}

export function toRecord(m: MatchState): MatchRecord {
  return {
    id: m.id,
    config: m.config,
    games: m.games.map((g) => ({ score: g.score, winner: g.winner })),
    winner: m.winner,
    startedAt: m.startedAt,
    endedAt: m.endedAt ?? Date.now(),
  }
}
