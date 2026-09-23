import { useRef, useState } from 'react'
import { currentGame, gamesWon } from '../engine/match'
import { gamesToWin, isGamePoint, receiver, serviceCourt } from '../engine/rules'
import type { Court, MatchState, Side } from '../engine/types'
import { avatarText, headTitle, playerName, shortName, sideTitle } from '../labels'

export type ScreenPos = 'left' | 'right'

interface Props {
  match: MatchState
  side: Side
  pos: ScreenPos
  onScore: (s: Side) => void
  onSwapPositions: (s: Side) => void
  onSetFirstServer: (s: Side) => void
}

const courtWord = (c: Court) => (c === 'R' ? 'kanan' : 'kiri')

/** Finger travel (px) that turns a tap into a drag. */
const SLOP = 12

export default function TeamPanel({ match, side, pos, onScore, onSwapPositions, onSetFirstServer }: Props) {
  const cfg = match.config
  const g = currentGame(match)
  const serving = g.servingTeam === side
  const court = serviceCourt(cfg, g)
  const active = serving ? g.server : receiver(cfg, g)
  const won = gamesWon(match)[side]
  const need = gamesToWin(cfg)
  const fresh = g.rallies.length === 0
  const playing = match.status === 'playing'
  const lock = useRef(0)

  // Show a short "+1" / "Pindah servis" badge only when a rally was added (not on undo).
  const len = g.rallies.length
  const [seen, setSeen] = useState(len)
  const [flash, setFlash] = useState<{ id: number; text: string }>()
  if (len !== seen) {
    setSeen(len)
    const last = g.rallies[len - 1]
    setFlash(len > seen && last?.winner === side ? { id: len, text: last.point ? '+1' : 'Pindah servis' } : undefined)
  }

  // Service-over: only the serving side can score on the next rally.
  const canScoreNext = cfg.scoring === 'rally' || serving
  const gamePoint = playing && canScoreNext && isGamePoint(cfg, g.score, side)
  const matchPoint = gamePoint && won === need - 1
  const showTapHint = playing && fresh && match.games.length === 1

  const hit = () => {
    const now = performance.now()
    // guard against accidental double taps
    if (now - lock.current < 280) return
    lock.current = now
    onScore(side)
  }

  // Score on release, not on touch: a grip, a palm or a drag across the panel never counts.
  const press = useRef<{ id: number; x: number; y: number } | null>(null)
  const pointer = {
    onPointerDown: (e: React.PointerEvent<HTMLButtonElement>) => {
      if (e.button !== 0) return
      if (press.current) {
        // a second finger means the phone is being held, not tapped
        press.current = null
        return
      }
      e.currentTarget.setPointerCapture(e.pointerId)
      press.current = { id: e.pointerId, x: e.clientX, y: e.clientY }
    },
    onPointerMove: (e: React.PointerEvent) => {
      const p = press.current
      if (p?.id === e.pointerId && Math.hypot(e.clientX - p.x, e.clientY - p.y) > SLOP) press.current = null
    },
    onPointerUp: (e: React.PointerEvent) => {
      const p = press.current
      press.current = null
      if (p?.id === e.pointerId) hit()
    },
    onPointerCancel: () => {
      press.current = null
    },
    // keyboard activation (Enter / Space) arrives as a click with no pointer detail
    onClick: (e: React.MouseEvent) => {
      if (e.detail === 0) hit()
    },
  }

  const who = playerName(cfg, side, active)
  /** Player index standing in court `c`, or undefined for the empty singles box. */
  const occupant = (c: Court) => {
    if (cfg.format === 'single') return c === court ? 0 : undefined
    return c === 'R' ? g.rightCourt[side] : g.rightCourt[side] === 0 ? 1 : 0
  }

  const duty = serving ? `${who} servis dari kotak ${courtWord(court)}` : `${who} menerima`

  return (
    <section className={`panel team-${side} pos-${pos}${serving ? ' serving' : ''}`} aria-label={sideTitle(cfg, side)}>
      <button
        type="button"
        className="panel-hit"
        aria-label={`Poin untuk ${sideTitle(cfg, side)}. Skor ${g.score[side]}. ${duty}.`}
        aria-disabled={!playing}
        {...pointer}
      />
      <div className="back">
        <header className="panel-head">
          <span className="team-tag">{side}</span>
          <span className="team-name">{headTitle(cfg, side)}</span>
          {gamePoint && <span className="point-badge in-head">{matchPoint ? 'Match point' : 'Game point'}</span>}
          {serving && (
            <span className="serve-pill">
              <Shuttlecock /> <span className="serve-pill-text">Servis</span>
            </span>
          )}
          {cfg.bestOf > 1 && (
            <span className="game-dots" aria-label={`${won} game dimenangkan`}>
              {Array.from({ length: need }, (_, i) => (
                <i key={i} className={i < won ? 'on' : ''} />
              ))}
            </span>
          )}
        </header>

        <div className="score-wrap">
          {gamePoint && <span className="point-badge">{matchPoint ? 'Match point' : 'Game point'}</span>}
          <div className="score num" key={`${match.games.length}-${g.score[side]}`}>
            {g.score[side]}
          </div>
          {showTapHint && <span className="tap-hint">Tap di sini kalau menang rally</span>}
          {flash && (
            <span className="float" key={flash.id}>
              {flash.text}
            </span>
          )}
        </div>

        <footer className="panel-foot">
          <span className="status">
            {serving ? (
              <>
                <b>{who}</b> servis dari kotak {courtWord(court)}
                {cfg.format === 'double' && cfg.scoring === 'serviceOver' && (
                  <em className="server-no">{g.serverNumber === 1 ? 'Server 1' : 'Server 2 · terakhir'}</em>
                )}
              </>
            ) : (
              <>
                Menerima: <b>{who}</b>
              </>
            )}
          </span>
          {fresh && playing && (
            <span className="prestart">
              {!serving && match.games.length === 1 && (
                <button type="button" className="chip" onClick={() => onSetFirstServer(side)}>
                  Servis duluan
                </button>
              )}
              {cfg.format === 'double' && (
                <button type="button" className="chip" onClick={() => onSwapPositions(side)}>
                  Tukar posisi
                </button>
              )}
            </span>
          )}
        </footer>
      </div>

      <div className="svc" data-pos={pos} aria-hidden="true">
        {(['R', 'L'] as const).map((c) => {
          const isActive = c === court
          const role = isActive ? (serving ? 'serve' : 'recv') : ''
          const p = occupant(c)
          return (
            <div key={c} className={`box box-${c} ${role}`}>
              <span className="box-label">{c === 'R' ? 'Kanan' : 'Kiri'}</span>
              {p !== undefined ? (
                <>
                  <span className="avatar">
                    {avatarText(cfg, side, p)}
                    {role === 'serve' && (
                      <span className="avatar-shuttle">
                        <Shuttlecock />
                      </span>
                    )}
                  </span>
                  <span className="box-name">{shortName(cfg, side, p)}</span>
                </>
              ) : (
                <span className="box-empty" />
              )}
              {role && <span className="box-role">{role === 'serve' ? 'Servis' : 'Terima'}</span>}
            </div>
          )
        })}
      </div>
    </section>
  )
}

function Shuttlecock() {
  return (
    <svg className="shuttle-ico" viewBox="0 0 24 24" width="16" height="16" aria-hidden="true">
      <path d="M7 3h10l-2 11H9z" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" />
      <path d="M8.5 14h7v2.5a3.5 3.5 0 0 1-7 0z" fill="currentColor" />
    </svg>
  )
}
