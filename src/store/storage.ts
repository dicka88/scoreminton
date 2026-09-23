import type { MatchRecord, MatchState, Side } from '../engine/types'

const ACTIVE_KEY = 'scoreminton.active'
const HISTORY_KEY = 'scoreminton.history'
const LAST_CONFIG_KEY = 'scoreminton.lastConfig'

function read<T>(key: string): T | undefined {
  try {
    const raw = localStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : undefined
  } catch {
    return undefined
  }
}

/** Returns false when storage is unavailable (private mode) or full, so the UI can say so. */
function write(key: string, value: unknown): boolean {
  try {
    if (value === undefined) localStorage.removeItem(key)
    else localStorage.setItem(key, JSON.stringify(value))
    return true
  } catch {
    return false
  }
}

/** One user action on the active match. Replaying the ops over `base` rebuilds the present state. */
export type Op =
  | { t: 'rally'; side: Side; at: number }
  | { t: 'resume' }
  | { t: 'nextGame' }
  | { t: 'swapSides' }
  | { t: 'swapPositions'; side: Side }
  | { t: 'firstServer'; side: Side }

/**
 * Persisted active match: the starting state plus the list of actions.
 * Kilobytes for a full match, versus megabytes for a stack of full snapshots.
 */
export interface StoredMatch {
  v: 2
  base: MatchState
  ops: Op[]
}

/** v1 format: full-state undo stack. Still read so a match in progress survives the update. */
interface LegacySnapshot {
  past: MatchState[]
  present: MatchState
}

export function loadActive(): StoredMatch | undefined {
  const raw = read<StoredMatch | LegacySnapshot>(ACTIVE_KEY)
  if (!raw) return undefined
  if ('v' in raw && raw.v === 2) return raw
  if ('present' in raw && raw.present) return { v: 2, base: raw.present, ops: [] }
  return undefined
}

/** Whether the last save of the active match worked; subscribable so the UI can warn. */
let activeSaved = true
const listeners = new Set<() => void>()
export const activeSaveStatus = {
  subscribe(l: () => void) {
    listeners.add(l)
    return () => {
      listeners.delete(l)
    }
  },
  get: () => activeSaved,
}

export function saveActive(s: StoredMatch | undefined) {
  const ok = write(ACTIVE_KEY, s)
  if (ok !== activeSaved) {
    activeSaved = ok
    listeners.forEach((l) => l())
  }
  return ok
}

export const loadHistory = () => read<MatchRecord[]>(HISTORY_KEY) ?? []
export function addHistory(r: MatchRecord) {
  const list = loadHistory().filter((x) => x.id !== r.id)
  return write(HISTORY_KEY, [r, ...list])
}
export function deleteHistory(id: string) {
  return write(HISTORY_KEY, loadHistory().filter((x) => x.id !== id))
}

export const loadLastConfig = <T>() => read<T>(LAST_CONFIG_KEY)
export const saveLastConfig = (c: unknown) => write(LAST_CONFIG_KEY, c)
