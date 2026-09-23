import { describe, expect, it, vi } from 'vitest'
import { createMatch } from '../engine/match'
import { PRESETS } from '../engine/rules'
import type { MatchConfig, MatchState, Side } from '../engine/types'
import { canUndo, dehydrate, hydrate, reducer, type ActiveMatch } from './matchStore'
import { loadActive } from './storage'

const cfg = (over: Partial<MatchConfig> = {}): MatchConfig => ({
  format: 'double',
  scoring: 'rally',
  bestOf: 3,
  ...PRESETS.rally,
  teams: { A: { name: '', players: ['', ''] }, B: { name: '', players: ['', ''] } },
  firstServer: 'A',
  ...over,
})

const start = (c = cfg()) => reducer(undefined, { type: 'new', config: c })!
const rally = (s: ActiveMatch, side: Side, at = 1) => reducer(s, { type: 'rally', side, at })!
const rallies = (s: ActiveMatch, seq: string) => [...seq].reduce((x, ch) => rally(x, ch as Side), s)
const score = (s: ActiveMatch) => {
  const g = s.present.games[s.present.games.length - 1]
  return `${g.score.A}-${g.score.B}`
}

describe('match store', () => {
  it('undo reverts one rally at a time', () => {
    let s = rallies(start(), 'AAB')
    expect(score(s)).toBe('2-1')
    s = reducer(s, { type: 'undo' })!
    expect(score(s)).toBe('2-0')
    expect(s.present.games[0].servingTeam).toBe('A')
  })

  it('one undo from the interval screen goes back before the interval rally', () => {
    let s = rallies(start(), 'A'.repeat(11))
    expect(s.present.status).toBe('interval')
    s = reducer(s, { type: 'resume' })!
    s = rally(s, 'B')
    s = reducer(s, { type: 'undo' })!
    expect(s.present.status).toBe('playing')
    expect(score(s)).toBe('11-0')
    s = reducer(s, { type: 'undo' })!
    expect(score(s)).toBe('10-0')
    expect(s.present.status).toBe('playing')
  })

  it('undo after starting the next game returns to the game-winning rally', () => {
    let s = rallies(start(), 'A'.repeat(11))
    s = reducer(s, { type: 'resume' })!
    s = rallies(s, 'A'.repeat(10))
    expect(s.present.status).toBe('gameOver')
    s = reducer(s, { type: 'nextGame' })!
    expect(s.present.games).toHaveLength(2)
    s = reducer(s, { type: 'undo' })!
    expect(s.present.games).toHaveLength(1)
    expect(score(s)).toBe('20-0')
  })

  it('replay after reload gives the same state, including end time', () => {
    let s = rallies(start(cfg({ bestOf: 1 })), 'A'.repeat(11))
    s = reducer(s, { type: 'resume' })!
    s = rallies(s, 'A'.repeat(10))
    expect(s.present.status).toBe('matchOver')
    const again = hydrate(JSON.parse(JSON.stringify(dehydrate(s))))!
    expect(again.present).toEqual(s.present)
    expect(canUndo(again)).toBe(true)
  })

  it('a long service-over match stays small in storage', () => {
    let s = start(cfg({ scoring: 'serviceOver', ...PRESETS.serviceOver }))
    // alternate so every other rally is a service over: ~300 rallies over three games
    for (let i = 0; i < 2000 && s.present.status !== 'matchOver'; i++) {
      if (s.present.status === 'interval') s = reducer(s, { type: 'resume' })!
      else if (s.present.status === 'gameOver') s = reducer(s, { type: 'nextGame' })!
      else s = rally(s, i % 3 === 0 ? 'B' : 'A', i)
    }
    const size = JSON.stringify(dehydrate(s)).length
    expect(s.ops.length).toBeGreaterThan(150)
    expect(size).toBeLessThan(40_000)
  })

  it('reads a v1 snapshot as a match without undo history', () => {
    const present: MatchState = createMatch(cfg())
    const store = new Map([['scoreminton.active', JSON.stringify({ past: [present], present })]])
    vi.stubGlobal('localStorage', { getItem: (k: string) => store.get(k) ?? null })
    const s = hydrate(loadActive())!
    vi.unstubAllGlobals()
    expect(s.present).toEqual(present)
    expect(canUndo(s)).toBe(false)
  })
})
