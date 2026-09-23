import { useState } from 'react'
import { PRESETS } from '../engine/rules'
import type { Format, MatchConfig, ScoringSystem, Side } from '../engine/types'
import { avatarText, modeLabel } from '../labels'
import { loadLastConfig } from '../store/storage'

interface Props {
  onStart: (c: MatchConfig) => void
  onBack: () => void
}

const DEFAULT: MatchConfig = {
  format: 'double',
  scoring: 'rally',
  bestOf: 3,
  ...PRESETS.rally,
  teams: { A: { name: '', players: ['', ''] }, B: { name: '', players: ['', ''] } },
  firstServer: 'A',
}

/** 21→30, 15→21, 11→16 for rally; target+2 for service-over setting. */
const defaultCap = (scoring: ScoringSystem, target: number) =>
  scoring === 'rally' ? Math.round((target * 30) / 21) : target + 2

function Segmented<T extends string | number>({
  value,
  options,
  onChange,
  label,
}: {
  value: T
  options: { value: T; label: string; hint?: string }[]
  onChange: (v: T) => void
  label: string
}) {
  return (
    <div className="seg" role="radiogroup" aria-label={label}>
      {options.map((o) => (
        <button
          key={String(o.value)}
          type="button"
          role="radio"
          aria-checked={o.value === value}
          className={o.value === value ? 'on' : ''}
          onClick={() => onChange(o.value)}
        >
          <span>{o.label}</span>
          {o.hint && <small>{o.hint}</small>}
        </button>
      ))}
    </div>
  )
}

export default function Setup({ onStart, onBack }: Props) {
  const [cfg, setCfg] = useState<MatchConfig>(() => {
    const last = loadLastConfig<MatchConfig>()
    if (!last) return DEFAULT
    const pad = (s: Side) => ({ ...last.teams[s], players: [...last.teams[s].players, '', ''].slice(0, 2) })
    return { ...DEFAULT, ...last, teams: { A: pad('A'), B: pad('B') } }
  })
  const set = (p: Partial<MatchConfig>) => setCfg((c) => ({ ...c, ...p }))

  const setScoring = (scoring: ScoringSystem) => set({ scoring, ...PRESETS[scoring] })

  const setPlayer = (s: Side, i: number, v: string) =>
    setCfg((c) => {
      const players = [...c.teams[s].players]
      players[i] = v
      return { ...c, teams: { ...c.teams, [s]: { ...c.teams[s], players } } }
    })
  const setTeamName = (s: Side, name: string) =>
    setCfg((c) => ({ ...c, teams: { ...c.teams, [s]: { ...c.teams[s], name } } }))

  const presetTargets = [11, 15, 21, 30]
  const customTarget = !presetTargets.includes(cfg.target)
  const capInvalid = cfg.deuce && cfg.cap <= cfg.target
  const targetInvalid = !(cfg.target >= 1 && cfg.target <= 99)

  const submit = (e: React.FormEvent) => {
    e.preventDefault()
    if (capInvalid || targetInvalid) return
    const n = cfg.format === 'single' ? 1 : 2
    onStart({
      ...cfg,
      teams: {
        A: { name: n === 1 ? '' : cfg.teams.A.name, players: cfg.teams.A.players.slice(0, n) },
        B: { name: n === 1 ? '' : cfg.teams.B.name, players: cfg.teams.B.players.slice(0, n) },
      },
    })
  }

  const numberInput = (value: number, onChange: (n: number) => void, label: string) => (
    <input
      className="num-input"
      type="number"
      inputMode="numeric"
      min={1}
      max={99}
      aria-label={label}
      value={Number.isFinite(value) ? value : ''}
      onChange={(e) => onChange(parseInt(e.target.value, 10))}
    />
  )

  const teamCard = (s: Side) => (
    <section className={`team-card team-${s}`} aria-label={`Tim ${s}`}>
      <div className="team-card-head">
        <span className="team-tag">{s}</span>
        <button
          type="button"
          className={`serve-toggle${cfg.firstServer === s ? ' on' : ''}`}
          aria-pressed={cfg.firstServer === s}
          onClick={() => set({ firstServer: s })}
        >
          {cfg.firstServer === s ? '✓ Servis duluan' : 'Servis duluan?'}
        </button>
      </div>
      {cfg.format === 'double' && (
        <input
          className="text-input team-name-input"
          placeholder="Nama tim (opsional)"
          value={cfg.teams[s].name}
          onChange={(e) => setTeamName(s, e.target.value)}
          maxLength={24}
          enterKeyHint="next"
        />
      )}
      {Array.from({ length: cfg.format === 'single' ? 1 : 2 }, (_, i) => (
        <label key={i} className="player-field">
          <span className="avatar sm">{avatarText(cfg, s, i)}</span>
          <input
            className="text-input"
            placeholder={cfg.format === 'single' ? 'Nama pemain' : `Pemain ${i + 1}`}
            value={cfg.teams[s].players[i] ?? ''}
            onChange={(e) => setPlayer(s, i, e.target.value)}
            maxLength={20}
            autoComplete="off"
            enterKeyHint="next"
          />
          {cfg.format === 'double' && <span className="pf-court">mulai {i === 0 ? 'kanan' : 'kiri'}</span>}
        </label>
      ))}
    </section>
  )

  return (
    <form className="page setup" onSubmit={submit}>
      <header className="topbar">
        <button type="button" className="btn btn-ghost btn-sm" onClick={onBack}>
          ← Kembali
        </button>
        <h2>Pertandingan baru</h2>
        <span className="topbar-spacer" />
      </header>

      <h3 className="section-label">1 · Aturan main</h3>
      <div className="setup-grid">
        <section className="card">
          <span className="field-label">Format</span>
          <Segmented<Format>
            label="Format"
            value={cfg.format}
            onChange={(format) => set({ format })}
            options={[
              { value: 'single', label: 'Single', hint: '1 lawan 1' },
              { value: 'double', label: 'Double', hint: '2 lawan 2' },
            ]}
          />
          <span className="field-label">Sistem poin</span>
          <Segmented<ScoringSystem>
            label="Sistem poin"
            value={cfg.scoring}
            onChange={setScoring}
            options={[
              { value: 'rally', label: 'Rally point', hint: 'BWF sekarang' },
              { value: 'serviceOver', label: 'Service-over', hint: 'Sistem lama' },
            ]}
          />
          <p className="hint">
            {cfg.scoring === 'rally'
              ? 'Setiap rally menghasilkan poin untuk pemenangnya.'
              : 'Poin hanya untuk tim yang servis. Kalau penerima menang rally, servis pindah tanpa poin.'}
          </p>
        </section>

        <section className="card">
          <span className="field-label">Jumlah game</span>
          <Segmented<1 | 3>
            label="Jumlah game"
            value={cfg.bestOf}
            onChange={(bestOf) => set({ bestOf })}
            options={[
              { value: 1, label: '1 game' },
              { value: 3, label: 'Best of 3', hint: 'menang 2 game' },
            ]}
          />
          <span className="field-label">Target poin</span>
          <div className="row">
            <Segmented<number>
              label="Target poin"
              value={customTarget ? -1 : cfg.target}
              onChange={(v) => {
                const target = v === -1 ? cfg.target + 1 : v
                set({ target, cap: defaultCap(cfg.scoring, target) })
              }}
              options={[...presetTargets.map((t) => ({ value: t, label: String(t) })), { value: -1, label: 'Lain' }]}
            />
            {customTarget && numberInput(cfg.target, (target) => set({ target, cap: defaultCap(cfg.scoring, target) }), 'Target poin custom')}
          </div>
          <div className="row deuce-row">
            <label className="toggle">
              <input type="checkbox" checked={cfg.deuce} onChange={(e) => set({ deuce: e.target.checked })} />
              <span className="toggle-track" aria-hidden="true" />
              <span>{cfg.scoring === 'rally' ? 'Deuce, menang selisih 2' : `Setting di ${cfg.target - 1}–${cfg.target - 1}`}</span>
            </label>
            {cfg.deuce && (
              <span className="cap-row">
                <span>{cfg.scoring === 'rally' ? 'maks' : 'sampai'}</span>
                {numberInput(cfg.cap, (cap) => set({ cap }), cfg.scoring === 'rally' ? 'Batas maksimal' : 'Main sampai')}
              </span>
            )}
          </div>
          {capInvalid && <p className="error">Batas maksimal harus lebih besar dari target.</p>}
          {targetInvalid && <p className="error">Isi target antara 1 dan 99.</p>}
        </section>
      </div>

      <h3 className="section-label">2 · Siapa yang main? <span className="optional">(boleh dikosongkan)</span></h3>
      <div className="versus">
        {teamCard('A')}
        <span className="vs" aria-hidden="true">vs</span>
        {teamCard('B')}
      </div>

      <div className="action-bar">
        <span className="ab-summary">{modeLabel(cfg)}</span>
        <button type="submit" className="btn btn-primary" disabled={capInvalid || targetInvalid}>
          Mulai pertandingan
        </button>
      </div>
    </form>
  )
}
