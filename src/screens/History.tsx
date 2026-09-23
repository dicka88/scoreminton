import { useState } from 'react'
import { other } from '../engine/rules'
import type { MatchRecord } from '../engine/types'
import { formatDate, formatDuration, modeLabel, sideTitle } from '../labels'
import { deleteHistory, loadHistory } from '../store/storage'

export default function History({ onBack }: { onBack: () => void }) {
  const [list, setList] = useState<MatchRecord[]>(loadHistory)
  const [confirmId, setConfirmId] = useState<string>()

  const remove = (id: string) => {
    deleteHistory(id)
    setList(loadHistory())
    setConfirmId(undefined)
  }

  return (
    <main className="page history">
      <header className="topbar">
        <button className="btn btn-ghost btn-sm" onClick={onBack}>
          ← Kembali
        </button>
        <h2>Riwayat</h2>
        <span className="topbar-spacer" />
      </header>

      {list.length === 0 ? (
        <p className="empty">Belum ada pertandingan tersimpan. Hasil muncul di sini setelah match selesai.</p>
      ) : (
        <ul className="history-list">
          {list.map((r) => {
            const w = r.winner
            return (
              <li key={r.id} className="card history-item">
                <div className="hi-meta">
                  <span>{formatDate(r.startedAt)}</span>
                  <span>{formatDuration(r.endedAt - r.startedAt)}</span>
                </div>
                <div className="hi-teams">
                  {(['A', 'B'] as const).map((s) => (
                    <div key={s} className={`hi-team t-${s}${w === s ? ' is-winner' : ''}`}>
                      <span className="hi-name">
                        {w === s && <span className="win-badge">Menang</span>}
                        {sideTitle(r.config, s)}
                      </span>
                      <span className="hi-games num">
                        {r.games.map((g, i) => (
                          <b key={i} className={g.winner === s ? 'won' : ''}>
                            {g.score[s]}
                          </b>
                        ))}
                      </span>
                    </div>
                  ))}
                </div>
                <div className="hi-foot">
                  <span className="muted">{modeLabel(r.config)}</span>
                  {confirmId === r.id ? (
                    <span className="hi-confirm">
                      <button className="btn btn-ghost btn-sm" onClick={() => setConfirmId(undefined)}>
                        Batal
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => remove(r.id)}>
                        Hapus
                      </button>
                    </span>
                  ) : (
                    <button className="btn btn-ghost btn-sm" onClick={() => setConfirmId(r.id)} aria-label={`Hapus match ${sideTitle(r.config, 'A')} vs ${sideTitle(r.config, 'B')}`}>
                      Hapus
                    </button>
                  )}
                </div>
                {w && <span className="sr-only">Pemenang {sideTitle(r.config, w)} atas {sideTitle(r.config, other(w))}</span>}
              </li>
            )
          })}
        </ul>
      )}
    </main>
  )
}
