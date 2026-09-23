import { describe, expect, it } from 'vitest'
import {
  createMatch,
  currentGame,
  resumeFromInterval,
  scoreRally,
  startNextGame,
  swapPositions,
} from './match'
import { PRESETS, isGamePoint, receiver, serviceCourt } from './rules'
import type { MatchConfig, MatchState, Side } from './types'

function cfg(over: Partial<MatchConfig> = {}): MatchConfig {
  const scoring = over.scoring ?? 'rally'
  return {
    format: 'single',
    scoring,
    bestOf: 3,
    ...PRESETS[scoring],
    teams: { A: { name: 'A', players: ['a1', 'a2'] }, B: { name: 'B', players: ['b1', 'b2'] } },
    firstServer: 'A',
    ...over,
  }
}

/** Play rallies, auto-dismissing intervals. */
function play(m: MatchState, seq: string): MatchState {
  for (const ch of seq) {
    m = scoreRally(m, ch as Side)
    if (m.status === 'interval') m = resumeFromInterval(m)
  }
  return m
}

const g = (m: MatchState) => currentGame(m)

describe('rally point', () => {
  it('awards point to rally winner and passes serve', () => {
    let m = createMatch(cfg())
    m = play(m, 'B')
    expect(g(m).score).toEqual({ A: 0, B: 1 })
    expect(g(m).servingTeam).toBe('B')
  })

  it('wins at 21 with 2-point lead', () => {
    const m = play(createMatch(cfg()), 'A'.repeat(21))
    expect(g(m).winner).toBe('A')
    expect(m.status).toBe('gameOver')
  })

  it('deuce: 20-20 needs 22', () => {
    let m = play(createMatch(cfg()), 'AB'.repeat(20))
    expect(g(m).score).toEqual({ A: 20, B: 20 })
    m = play(m, 'A')
    expect(g(m).winner).toBeUndefined()
    m = play(m, 'A')
    expect(g(m).winner).toBe('A')
    expect(g(m).score).toEqual({ A: 22, B: 20 })
  })

  it('cap: 29-29 next point wins at 30', () => {
    let m = play(createMatch(cfg()), 'AB'.repeat(29))
    expect(g(m).winner).toBeUndefined()
    m = play(m, 'B')
    expect(g(m).winner).toBe('B')
    expect(g(m).score).toEqual({ A: 29, B: 30 })
  })

  it('deuce off: first to target wins', () => {
    const m = play(createMatch(cfg({ deuce: false })), 'AB'.repeat(20) + 'B')
    expect(g(m).winner).toBe('B')
  })

  it('singles service court by parity', () => {
    let m = createMatch(cfg())
    expect(serviceCourt(m.config, g(m))).toBe('R')
    m = play(m, 'A')
    expect(serviceCourt(m.config, g(m))).toBe('L')
    m = play(m, 'B')
    expect(serviceCourt(m.config, g(m))).toBe('L') // B has 1
  })
})

describe('rally point doubles', () => {
  const d = () => createMatch(cfg({ format: 'double' }))

  it('serving side wins: same server switches court', () => {
    let m = d()
    expect(g(m).server).toBe(0)
    m = play(m, 'A')
    expect(g(m).server).toBe(0)
    expect(serviceCourt(m.config, g(m))).toBe('L')
    expect(g(m).rightCourt.A).toBe(1)
  })

  it('receiving side wins: no position change, server by parity', () => {
    let m = d()
    m = play(m, 'B') // B 1 -> serve from left: player in left = b2 (index 1)
    expect(g(m).servingTeam).toBe('B')
    expect(g(m).rightCourt.B).toBe(0)
    expect(g(m).server).toBe(1)
    expect(serviceCourt(m.config, g(m))).toBe('L')
    expect(receiver(m.config, g(m))).toBe(1) // A left court = a2
  })

  it('swapPositions before first rally changes server', () => {
    let m = swapPositions(d(), 'A')
    expect(g(m).server).toBe(1)
    m = play(m, 'A')
    expect(swapPositions(m, 'A')).toBe(m)
  })
})

describe('service-over', () => {
  // classic 15-point game with setting to 17
  const so = (over: Partial<MatchConfig> = {}) =>
    createMatch(cfg({ scoring: 'serviceOver', target: 15, cap: 17, ...over }))

  it('default preset: 30 points, setting at 29-all to 32, interval at 15', () => {
    expect(PRESETS.serviceOver).toEqual({ target: 30, deuce: true, cap: 32 })
    let m = createMatch(cfg({ scoring: 'serviceOver' }))
    for (let i = 0; i < 15; i++) m = scoreRally(m, 'A')
    expect(m.status).toBe('interval')
    m = play(resumeFromInterval(m), 'A'.repeat(15))
    expect(g(m).winner).toBe('A')
    expect(g(m).score.A).toBe(30)
  })

  it('receiver winning only gains serve, no point', () => {
    let m = so()
    m = play(m, 'B')
    expect(g(m).score).toEqual({ A: 0, B: 0 })
    expect(g(m).servingTeam).toBe('B')
    m = play(m, 'B')
    expect(g(m).score).toEqual({ A: 0, B: 1 })
  })

  it('wins at 15', () => {
    const m = play(so(), 'A'.repeat(15))
    expect(g(m).winner).toBe('A')
  })

  it('setting at 14-14 plays to 17', () => {
    // A to 14, B takes serve and scores 14
    let m = play(so(), 'A'.repeat(14) + 'B' + 'B'.repeat(14))
    expect(g(m).score).toEqual({ A: 14, B: 14 })
    m = play(m, 'B')
    expect(g(m).winner).toBeUndefined()
    m = play(m, 'BB')
    expect(g(m).winner).toBe('B')
    expect(g(m).score).toEqual({ A: 14, B: 17 })
  })

  it('14-13 serving to 15 wins without setting', () => {
    const m = play(so(), 'A'.repeat(13) + 'B' + 'B'.repeat(14) + 'A' + 'A')
    expect(g(m).score).toEqual({ A: 14, B: 14 })
    const m2 = play(so(), 'A'.repeat(14) + 'B' + 'B'.repeat(13) + 'A' + 'A')
    expect(g(m2).score).toEqual({ A: 15, B: 13 })
    expect(g(m2).winner).toBe('A')
  })

  it('doubles: one hand down at game start, then two servers', () => {
    let m = so({ format: 'double' })
    expect(g(m).serverNumber).toBe(2)
    m = play(m, 'B') // service over immediately
    expect(g(m).servingTeam).toBe('B')
    expect(g(m).serverNumber).toBe(1)
    expect(g(m).server).toBe(0)
    m = play(m, 'B') // B scores, server switches court
    expect(g(m).score.B).toBe(1)
    expect(serviceCourt(m.config, g(m))).toBe('L')
    m = play(m, 'A') // second server
    expect(g(m).servingTeam).toBe('B')
    expect(g(m).serverNumber).toBe(2)
    expect(g(m).server).toBe(1)
    expect(serviceCourt(m.config, g(m))).toBe('R') // b2 now in right court
    m = play(m, 'A') // service over
    expect(g(m).servingTeam).toBe('A')
    expect(g(m).serverNumber).toBe(1)
    expect(g(m).server).toBe(g(m).rightCourt.A)
    expect(g(m).score).toEqual({ A: 0, B: 1 })
  })
})

describe('match flow', () => {
  it('interval at 11 and deciding game switches ends', () => {
    let m = createMatch(cfg())
    for (let i = 0; i < 11; i++) m = scoreRally(m, 'A')
    expect(m.status).toBe('interval')
    expect(m.leftTeam).toBe('A') // not deciding game
    m = resumeFromInterval(m)
    m = play(m, 'A'.repeat(10))
    m = startNextGame(m)
    expect(m.leftTeam).toBe('B')
    m = play(m, 'B'.repeat(21))
    m = startNextGame(m)
    expect(m.games.length).toBe(3)
    expect(g(m).servingTeam).toBe('B')
    const before = m.leftTeam
    for (let i = 0; i < 11; i++) m = scoreRally(m, 'A')
    expect(m.status).toBe('interval')
    expect(m.leftTeam).not.toBe(before)
  })

  it('best of 3 ends at 2 games', () => {
    let m = play(createMatch(cfg()), 'A'.repeat(21))
    m = startNextGame(m)
    m = play(m, 'A'.repeat(21))
    expect(m.status).toBe('matchOver')
    expect(m.winner).toBe('A')
  })

  it('winner of game serves first next game', () => {
    let m = play(createMatch(cfg()), 'B'.repeat(21))
    m = startNextGame(m)
    expect(g(m).servingTeam).toBe('B')
  })

  it('does not mutate input (undo safety)', () => {
    const m = createMatch(cfg({ format: 'double' }))
    const snap = JSON.stringify(m)
    play(m, 'ABBA')
    expect(JSON.stringify(m)).toBe(snap)
  })
})

describe('game point', () => {
  it('detects game point incl. deuce', () => {
    const c = cfg()
    expect(isGamePoint(c, { A: 20, B: 10 }, 'A')).toBe(true)
    expect(isGamePoint(c, { A: 20, B: 20 }, 'A')).toBe(false)
    expect(isGamePoint(c, { A: 21, B: 20 }, 'A')).toBe(true)
    expect(isGamePoint(c, { A: 29, B: 29 }, 'B')).toBe(true)
    const so = cfg({ scoring: 'serviceOver', target: 15, cap: 17 })
    expect(isGamePoint(so, { A: 14, B: 14 }, 'A')).toBe(false)
    expect(isGamePoint(so, { A: 16, B: 14 }, 'A')).toBe(true)
  })
})
