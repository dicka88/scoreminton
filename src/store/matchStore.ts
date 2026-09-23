import { useEffect, useReducer, useSyncExternalStore } from 'react'
import {
  createMatch,
  resumeFromInterval,
  scoreRally,
  setFirstServer,
  startNextGame,
  swapPositions,
  swapSides,
} from '../engine/match'
import type { MatchConfig, MatchState, Side } from '../engine/types'
import { activeSaveStatus, loadActive, saveActive, type Op, type StoredMatch } from './storage'

export interface ActiveMatch {
  base: MatchState
  ops: Op[]
  present: MatchState
}

type State = ActiveMatch | undefined

export type Action =
  | { type: 'new'; config: MatchConfig }
  | { type: 'rally'; side: Side; at?: number }
  | { type: 'undo' }
  | { type: 'resume' }
  | { type: 'nextGame' }
  | { type: 'swapSides' }
  | { type: 'swapPositions'; side: Side }
  | { type: 'firstServer'; side: Side }
  | { type: 'clear' }

export function applyOp(m: MatchState, op: Op): MatchState {
  switch (op.t) {
    case 'rally':
      return scoreRally(m, op.side, op.at)
    case 'resume':
      return resumeFromInterval(m)
    case 'nextGame':
      return startNextGame(m)
    case 'swapSides':
      return swapSides(m)
    case 'swapPositions':
      return swapPositions(m, op.side)
    case 'firstServer':
      return setFirstServer(m, op.side)
  }
}

export const replay = (base: MatchState, ops: Op[]) => ops.reduce(applyOp, base)

/** Modal dismissals ride along with the rally before them, so one undo reverts that rally. */
const rides = (op: Op) => op.t === 'resume' || op.t === 'nextGame'

function toOp(a: Exclude<Action, { type: 'new' | 'clear' | 'undo' }>): Op {
  switch (a.type) {
    case 'rally':
      return { t: 'rally', side: a.side, at: a.at ?? Date.now() }
    case 'swapPositions':
    case 'firstServer':
      return { t: a.type, side: a.side }
    default:
      return { t: a.type }
  }
}

export function reducer(s: State, a: Action): State {
  if (a.type === 'new') {
    const base = createMatch(a.config)
    return { base, ops: [], present: base }
  }
  if (a.type === 'clear') return undefined
  if (!s) return s
  if (a.type === 'undo') {
    const ops = [...s.ops]
    while (ops.length && rides(ops[ops.length - 1])) ops.pop()
    if (!ops.length) return s
    ops.pop()
    return { base: s.base, ops, present: replay(s.base, ops) }
  }
  const op = toOp(a)
  const next = applyOp(s.present, op)
  if (next === s.present) return s
  return { ...s, ops: [...s.ops, op], present: next }
}

export function hydrate(stored: StoredMatch | undefined): State {
  if (!stored) return undefined
  try {
    return { base: stored.base, ops: stored.ops, present: replay(stored.base, stored.ops) }
  } catch {
    return undefined
  }
}

export const dehydrate = (s: State): StoredMatch | undefined =>
  s && { v: 2, base: s.base, ops: s.ops }

export const canUndo = (s: ActiveMatch) => s.ops.some((op) => !rides(op))

export function useMatchStore() {
  const [state, dispatch] = useReducer(reducer, undefined, () => hydrate(loadActive()))
  useEffect(() => {
    saveActive(dehydrate(state))
  }, [state])
  const saved = useSyncExternalStore(activeSaveStatus.subscribe, activeSaveStatus.get)
  return [state, dispatch, saved] as const
}
