import type { MatchConfig, MatchRecord, Side } from './engine/types'

export const teamName = (cfg: MatchConfig, s: Side) =>
  cfg.teams[s].name.trim() || `Tim ${s}`

export const playerName = (cfg: MatchConfig, s: Side, i: number) =>
  cfg.teams[s].players[i]?.trim() || (cfg.format === 'single' ? teamName(cfg, s) : `Pemain ${s}${i + 1}`)

export const playersLine = (cfg: MatchConfig, s: Side) =>
  cfg.format === 'single'
    ? playerName(cfg, s, 0)
    : `${playerName(cfg, s, 0)} / ${playerName(cfg, s, 1)}`

/** Headline for a side: players for doubles if no custom team name. */
export const sideTitle = (cfg: MatchConfig, s: Side) =>
  cfg.teams[s].name.trim() || playersLine(cfg, s)

export const modeLabel = (cfg: MatchConfig) =>
  `${cfg.format === 'single' ? 'Single' : 'Double'} · ${cfg.scoring === 'rally' ? 'Rally point' : 'Service-over'} · ${cfg.target} poin${cfg.bestOf === 3 ? ' · Best of 3' : ''}`

export const recordSummary = (r: MatchRecord) =>
  r.games.map((g) => `${g.score.A}–${g.score.B}`).join(', ')

export const formatDate = (ts: number) =>
  new Date(ts).toLocaleString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })

export const formatDuration = (ms: number) => {
  const m = Math.max(1, Math.round(ms / 60000))
  return m < 60 ? `${m} mnt` : `${Math.floor(m / 60)} j ${m % 60} mnt`
}

/**
 * Short headline for tight spots (scoreboard header, resume card). The court tiles already
 * show each player, so doubles without typed names read "Tim A" rather than "Pemain A1 / Pemain A2".
 */
export const headTitle = (cfg: MatchConfig, s: Side) => {
  const name = cfg.teams[s].name.trim()
  if (name) return name
  if (cfg.format === 'single') return playerName(cfg, s, 0)
  if (!cfg.teams[s].players.some((p) => p?.trim())) return teamName(cfg, s)
  return `${shortName(cfg, s, 0)} & ${shortName(cfg, s, 1)}`
}

/** Up to two initials for an avatar, e.g. "Budi Santoso" → "BS". */
export const initials = (name: string) =>
  name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('') || '?'

/** Avatar text: initials of a typed name, otherwise the slot code (A1, B2, …). */
export const avatarText = (cfg: MatchConfig, s: Side, i: number) => {
  const typed = cfg.teams[s].players[i]?.trim()
  if (typed) return initials(typed)
  return cfg.format === 'single' ? s : `${s}${i + 1}`
}

/** Compact name for tight spots (court tiles): first word of a typed name. */
export const shortName = (cfg: MatchConfig, s: Side, i: number) => {
  const typed = cfg.teams[s].players[i]?.trim()
  if (!typed) return playerName(cfg, s, i)
  const first = typed.split(/\s+/)[0]
  return first.length >= 3 ? first : typed
}
