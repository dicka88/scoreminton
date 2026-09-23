import { useEffect, useRef, useState, type Dispatch, type ReactNode } from 'react'
import { Modal, Sheet } from '../components/Dialog'
import TeamPanel from '../components/TeamPanel'
import { currentGame, gamesWon } from '../engine/match'
import { isDecidingGame, other, serviceCourt } from '../engine/rules'
import type { MatchState, Side } from '../engine/types'
import { useFullscreen, useWakeLock, vibrate } from '../hooks/device'
import { formatDuration, headTitle, modeLabel, playerName, sideTitle } from '../labels'
import type { Action } from '../store/matchStore'

interface Props {
  match: MatchState
  canUndo: boolean
  dispatch: Dispatch<Action>
  onExit: () => void
  onFinish: () => void
  onAbandon: () => void
  notice?: ReactNode
}

export default function Scoreboard({ match, canUndo, dispatch, onExit, onFinish, onAbandon, notice }: Props) {
  const [sheet, setSheet] = useState<'none' | 'log' | 'menu' | 'confirmAbandon'>('none')
  const fs = useFullscreen()
  useWakeLock(true)

  const cfg = match.config
  const g = currentGame(match)
  const left = match.leftTeam
  const right = other(left)

  // Ignore taps that land while the board is still appearing (finger from the previous screen).
  const [readyAt] = useState(() => performance.now() + 400)

  const score = (s: Side) => {
    if (match.status !== 'playing' || sheet !== 'none') return
    if (performance.now() < readyAt) return
    vibrate()
    dispatch({ type: 'rally', side: s, at: Date.now() })
  }
  const undo = () => {
    vibrate(12)
    dispatch({ type: 'undo' })
  }

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.target instanceof HTMLInputElement) return
      if (e.key === 'ArrowLeft') score(left)
      else if (e.key === 'ArrowRight') score(right)
      else if (e.key === 'Backspace' || e.key.toLowerCase() === 'z') undo()
      else if (e.key === 'Escape') setSheet('none')
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  const panel = (s: Side, pos: 'left' | 'right') => (
    <TeamPanel
      match={match}
      side={s}
      pos={pos}
      onScore={score}
      onSwapPositions={(side) => dispatch({ type: 'swapPositions', side })}
      onSetFirstServer={(side) => dispatch({ type: 'firstServer', side })}
    />
  )

  const won = gamesWon(match)
  const [a, b] = [g.score[left], g.score[right]]
  // Deuce (rally) or setting (service-over) is on once both sides reach target − 1.
  const extended = cfg.deuce && match.status === 'playing' && Math.min(g.score.A, g.score.B) >= cfg.target - 1
  const serverName = playerName(cfg, g.servingTeam, g.server)
  const court = serviceCourt(cfg, g) === 'R' ? 'kanan' : 'kiri'
  const announcement =
    match.status === 'playing'
      ? `${sideTitle(cfg, left)} ${a}, ${sideTitle(cfg, right)} ${b}. ${serverName} servis dari kotak ${court}.`
      : ''

  return (
    <main className="board">
      {panel(left, 'left')}

      <nav className="spine" aria-label="Kontrol">
        <div className="spine-meta">
          <span className="game-no">Game {match.games.length}</span>
          {cfg.bestOf > 1 && (
            <span className="set-score num" aria-label={`Game dimenangkan ${won[left]} lawan ${won[right]}`}>
              <span className={`t-${left}`}>{won[left]}</span>
              <span className="dash">–</span>
              <span className={`t-${right}`}>{won[right]}</span>
            </span>
          )}
          {extended && <span className="deuce-tag">{cfg.scoring === 'rally' ? 'Deuce' : `Setting ${cfg.cap}`}</span>}
        </div>
        <button className="icon-btn undo" onClick={undo} disabled={!canUndo} aria-label="Undo">
          <Icon d="M9 14 4 9l5-5M4 9h11a5 5 0 0 1 0 10h-3" />
          <span>Undo</span>
        </button>
        <HoldButton label="Tukar sisi layar (tekan dan tahan)" text="Sisi" onHold={() => dispatch({ type: 'swapSides' })}>
          <Icon d="M7 4 3 8l4 4M3 8h14M17 20l4-4-4-4M21 16H7" />
        </HoldButton>
        <button className="icon-btn" onClick={() => setSheet('log')} aria-label="Log rally">
          <Icon d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01" />
          <span>Log</span>
        </button>
        {fs.supported && (
          <button className="icon-btn hide-short" onClick={fs.toggle} aria-label="Layar penuh">
            <Icon d={fs.isFull ? 'M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5' : 'M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5'} />
            <span>Penuh</span>
          </button>
        )}
        <button className="icon-btn" onClick={() => setSheet('menu')} aria-label="Menu">
          <Icon d="M4 6h16M4 12h16M4 18h16" />
          <span>Menu</span>
        </button>
      </nav>

      {panel(right, 'right')}

      <p className="sr-only" aria-live="polite">
        {announcement}
      </p>
      {notice && (
        <p className="notice" role="alert">
          {notice}
        </p>
      )}

      {match.status === 'interval' && (
        <Modal label={`Interval game ${match.games.length}`}>
          <h2>Interval game {match.games.length}</h2>
          <p className="modal-score num">
            <span className={`t-${left}`}>{a}</span>–<span className={`t-${right}`}>{b}</span>
          </p>
          {isDecidingGame(cfg, match.games.length - 1) && <p className="callout">Pindah sisi lapangan</p>}
          <p className="muted">Istirahat maksimal 60 detik. Minum dulu!</p>
          <div className="modal-actions">
            <button className="btn btn-ghost" onClick={undo}>
              Undo
            </button>
            <button className="btn btn-primary" onClick={() => dispatch({ type: 'resume' })} autoFocus>
              Lanjut main
            </button>
          </div>
        </Modal>
      )}

      {match.status === 'gameOver' && (
        <Modal label={`Game ${match.games.length} selesai`}>
          <h2 className="winner">
            <span className={`t-${g.winner}`}>{headTitle(cfg, g.winner!)}</span> menang game {match.games.length}
          </h2>
          <p className="modal-score num">
            {g.score[g.winner!]}–{g.score[other(g.winner!)]}
          </p>
          <p className="callout">Pindah sisi · {headTitle(cfg, g.winner!)} servis duluan</p>
          <div className="modal-actions">
            <button className="btn btn-ghost" onClick={undo}>
              Undo
            </button>
            <button className="btn btn-primary" onClick={() => dispatch({ type: 'nextGame' })} autoFocus>
              Mulai game {match.games.length + 1}
            </button>
          </div>
        </Modal>
      )}

      {match.status === 'matchOver' && (
        <Modal label="Pertandingan selesai">
          <Confetti />
          <Trophy />
          <h2 className="winner">
            <span className={`t-${match.winner}`}>{headTitle(cfg, match.winner!)}</span> menang!
          </h2>
          <div className="final-games num">
            {match.games.map((x, i) => (
              <span key={i} className={`t-${x.winner}`}>
                {x.score[match.winner!]}–{x.score[other(match.winner!)]}
              </span>
            ))}
          </div>
          <p className="muted">
            {modeLabel(cfg)} · {formatDuration((match.endedAt ?? match.startedAt) - match.startedAt)}
          </p>
          <div className="modal-actions">
            <button className="btn btn-ghost" onClick={undo}>
              Undo
            </button>
            <button className="btn btn-primary" onClick={onFinish} autoFocus>
              Simpan hasil
            </button>
          </div>
        </Modal>
      )}

      {sheet === 'log' && (
        <Sheet title={`Log rally · Game ${match.games.length}`} onClose={() => setSheet('none')}>
          {g.rallies.length === 0 ? (
            <p className="muted">Belum ada rally.</p>
          ) : (
            <ol className="rally-log">
              {[...g.rallies].reverse().map((r, i) => (
                <li key={g.rallies.length - i} className={`t-${r.winner}`}>
                  <span className="rl-no num">{g.rallies.length - i}</span>
                  <span className="rl-score num">
                    {r.score[left]}–{r.score[right]}
                  </span>
                  <span className="rl-desc">
                    {r.point ? `Poin ${headTitle(cfg, r.winner)}` : `Pindah servis → ${headTitle(cfg, r.winner)}`}
                    <small>servis: {playerName(cfg, r.servingTeam, r.server)}</small>
                  </span>
                </li>
              ))}
            </ol>
          )}
        </Sheet>
      )}

      {sheet === 'menu' && (
        <Sheet title="Menu" onClose={() => setSheet('none')}>
          <p className="muted">{modeLabel(cfg)}</p>
          <div className="menu-list">
            <button className="btn btn-ghost btn-lg" onClick={onExit}>
              Ke beranda (match tetap tersimpan)
            </button>
            <button className="btn btn-danger btn-lg" onClick={() => setSheet('confirmAbandon')}>
              Akhiri tanpa menyimpan
            </button>
          </div>
        </Sheet>
      )}

      {sheet === 'confirmAbandon' && (
        <Modal label="Akhiri tanpa menyimpan?" onEscape={() => setSheet('none')}>
          <h2>Akhiri tanpa menyimpan?</h2>
          <p className="muted">
            Skor {a}–{b} di game {match.games.length} dibuang dan tidak masuk riwayat.
          </p>
          <div className="modal-actions">
            <button className="btn btn-ghost" onClick={() => setSheet('none')} autoFocus>
              Kembali
            </button>
            <button className="btn btn-danger" onClick={onAbandon}>
              Ya, akhiri
            </button>
          </div>
        </Modal>
      )}

    </main>
  )
}

const CONFETTI_COLORS = ['var(--red)', 'var(--blue)', 'var(--sun)', 'var(--red-mid)', 'var(--blue-mid)']

function Confetti() {
  return (
    <div className="confetti" aria-hidden="true">
      {Array.from({ length: 28 }, (_, i) => (
        <i
          key={i}
          style={{
            left: `${(i * 37) % 100}%`,
            background: CONFETTI_COLORS[i % CONFETTI_COLORS.length],
            animationDelay: `${(i % 7) * 0.12}s`,
            animationDuration: `${1.8 + (i % 5) * 0.25}s`,
          }}
        />
      ))}
    </div>
  )
}

function Trophy() {
  return (
    <svg className="trophy" viewBox="0 0 64 64" width="56" height="56" aria-hidden="true">
      <path d="M20 8h24v14a12 12 0 0 1-24 0z" fill="var(--sun)" />
      <path d="M20 12H10v4a10 10 0 0 0 10 10M44 12h10v4a10 10 0 0 1-10 10" fill="none" stroke="var(--sun-deep)" strokeWidth="4" strokeLinecap="round" />
      <path d="M28 34h8v10h-8z" fill="var(--sun-deep)" />
      <rect x="20" y="44" width="24" height="8" rx="3" fill="var(--ink)" />
    </svg>
  )
}

function Icon({ d }: { d: string }) {
  return (
    <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={d} />
    </svg>
  )
}

const HOLD_MS = 600

/** A control that acts only after a deliberate press-and-hold, so a stray tap mid-rally does nothing. */
function HoldButton({ label, text, onHold, children }: { label: string; text: string; onHold: () => void; children: ReactNode }) {
  const [holding, setHolding] = useState(false)
  const [nudge, setNudge] = useState(false)
  const timer = useRef<number>(undefined)
  const nudgeTimer = useRef<number>(undefined)
  useEffect(
    () => () => {
      window.clearTimeout(timer.current)
      window.clearTimeout(nudgeTimer.current)
    },
    [],
  )

  const start = (e: React.PointerEvent) => {
    if (e.button !== 0) return
    setHolding(true)
    setNudge(false)
    timer.current = window.setTimeout(() => {
      setHolding(false)
      vibrate(30)
      onHold()
    }, HOLD_MS)
  }
  const stop = (released: boolean) => {
    if (!holding) return
    window.clearTimeout(timer.current)
    setHolding(false)
    if (!released) return
    // released too early: say how it works instead of silently ignoring the tap
    setNudge(true)
    window.clearTimeout(nudgeTimer.current)
    nudgeTimer.current = window.setTimeout(() => setNudge(false), 1400)
  }

  return (
    <button
      className={`icon-btn hold${holding ? ' holding' : ''}${nudge ? ' nudge' : ''}`}
      aria-label={label}
      style={{ '--hold': `${HOLD_MS}ms` } as React.CSSProperties}
      onPointerDown={start}
      onPointerUp={() => stop(true)}
      onPointerLeave={() => stop(false)}
      onPointerCancel={() => stop(false)}
      onContextMenu={(e) => e.preventDefault()}
      // keyboard users act on purpose; no hold needed
      onClick={(e) => e.detail === 0 && onHold()}
    >
      {children}
      <span>{nudge ? 'Tahan' : text}</span>
    </button>
  )
}
