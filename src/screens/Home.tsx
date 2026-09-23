import { currentGame, gamesWon } from '../engine/match'
import { PRESETS } from '../engine/rules'
import type { Format, MatchConfig, MatchState, ScoringSystem } from '../engine/types'
import { headTitle, modeLabel } from '../labels'
import { loadLastConfig } from '../store/storage'

interface Props {
  active?: MatchState
  onNew: () => void
  onQuickStart: (c: MatchConfig) => void
  onResume: () => void
  onHistory: () => void
}

const SYSTEMS: { scoring: ScoringSystem; title: string; sub: string }[] = [
  { scoring: 'rally', title: 'Rally point', sub: '21 poin · best of 3' },
  { scoring: 'serviceOver', title: 'Service-over', sub: '30 poin · best of 3' },
]
const FORMATS: { format: Format; title: string }[] = [
  { format: 'single', title: 'Single' },
  { format: 'double', title: 'Double' },
]

function quickConfig(format: Format, scoring: ScoringSystem): MatchConfig {
  const last = loadLastConfig<MatchConfig>()
  const n = format === 'single' ? 1 : 2
  const team = (s: 'A' | 'B') => ({
    name: n === 1 ? '' : (last?.teams[s].name ?? ''),
    players: [...(last?.teams[s].players ?? []), '', ''].slice(0, n),
  })
  return {
    format,
    scoring,
    bestOf: 3,
    ...PRESETS[scoring],
    teams: { A: team('A'), B: team('B') },
    firstServer: 'A',
  }
}

export default function Home({ active, onNew, onQuickStart, onResume, onHistory }: Props) {
  const g = active && currentGame(active)
  const won = active && gamesWon(active)
  const last = active ? undefined : loadLastConfig<MatchConfig>()
  return (
    <main className="page home">
      <header className="home-top">
        <span className="brand">
          <Logo />
          Scoreminton
        </span>
        <button className="btn btn-ghost btn-sm" onClick={onHistory}>
          Riwayat
        </button>
      </header>

      <section className="home-hero">
        <h1>
          Mau main <span className="t-A">apa</span> <span className="t-B">hari ini?</span>
        </h1>
        <p className="lede">Pilih mode, lalu tap sisi tim yang menang rally. Servis, posisi, dan pindah sisi diatur otomatis.</p>
      </section>

      <section className="home-actions">
        {active && g && won && (
          <button className="resume-card" onClick={onResume}>
            <span className="rc-top">
              <span className="live-dot" aria-hidden="true" />
              Pertandingan belum selesai · Game {active.games.length}
            </span>
            <span className="resume-score">
              <span className="rs-name t-A">{headTitle(active.config, 'A')}</span>
              <b className="num t-A">{g.score.A}</b>
              <b className="num t-B">{g.score.B}</b>
              <span className="rs-name t-B">{headTitle(active.config, 'B')}</span>
            </span>
            <span className="rc-cta">Lanjutkan →</span>
          </button>
        )}

        {last && (
          <button className="again-card" onClick={() => onQuickStart(last)}>
            <span className="ag-title">Main lagi</span>
            <span className="ag-players">
              <span className="ag-A">{headTitle(last, 'A')}</span> vs <span className="ag-B">{headTitle(last, 'B')}</span>
            </span>
            <span className="ag-sub">{modeLabel(last)}</span>
          </button>
        )}

        {SYSTEMS.map((sys) => (
          <div key={sys.scoring} className="quick-row" role="group" aria-label={`${sys.title}, ${sys.sub}`}>
            <p className="qr-label">
              <b>{sys.title}</b>
              <span>{sys.sub}</span>
            </p>
            <div className="quick-grid">
              {FORMATS.map((f) => (
                <button
                  key={f.format}
                  className={`quick-card q-${f.format}`}
                  aria-label={`${f.title}, ${sys.title} ${sys.sub}`}
                  onClick={() => onQuickStart(quickConfig(f.format, sys.scoring))}
                >
                  <span className="qc-icon" aria-hidden="true">
                    <span className="qi-a">{f.format === 'single' ? <i /> : <><i /><i /></>}</span>
                    <span className="qc-vs">vs</span>
                    <span className="qi-b">{f.format === 'single' ? <i /> : <><i /><i /></>}</span>
                  </span>
                  <span className="qc-title">{f.title}</span>
                </button>
              ))}
            </div>
          </div>
        ))}

        <button className="btn btn-ghost btn-lg" onClick={onNew}>
          Atur sendiri &amp; isi nama pemain
        </button>
        <p className="home-note">Mulai cepat memakai nama pemain terakhir.</p>
      </section>
    </main>
  )
}

function Logo() {
  return (
    <svg viewBox="0 0 32 32" width="30" height="30" aria-hidden="true">
      <circle cx="16" cy="16" r="16" fill="var(--red)" />
      <path d="M16 0a16 16 0 0 1 0 32z" fill="var(--blue)" />
      <path d="M11 8h10l-2 11h-6z" fill="none" stroke="#fff" strokeWidth="2" strokeLinejoin="round" />
      <path d="M12.5 19h7v2a3.5 3.5 0 0 1-7 0z" fill="#fff" />
    </svg>
  )
}
