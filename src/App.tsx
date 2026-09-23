import { useState } from 'react'
import { Modal } from './components/Dialog'
import { currentGame, toRecord } from './engine/match'
import type { MatchConfig } from './engine/types'
import { headTitle, sideTitle } from './labels'
import History from './screens/History'
import Home from './screens/Home'
import Scoreboard from './screens/Scoreboard'
import Setup from './screens/Setup'
import { canUndo, useMatchStore } from './store/matchStore'
import { addHistory, saveLastConfig } from './store/storage'

type Screen = 'home' | 'setup' | 'score' | 'history'

export default function App() {
  const [store, dispatch, saved] = useMatchStore()
  const [screen, setScreen] = useState<Screen>('home')
  /** New match waiting for the user to confirm it may replace the one in progress. */
  const [pending, setPending] = useState<MatchConfig>()
  const [historyFailed, setHistoryFailed] = useState(false)

  const begin = (config: MatchConfig) => {
    saveLastConfig(config)
    dispatch({ type: 'new', config })
    setPending(undefined)
    setHistoryFailed(false)
    setScreen('score')
  }
  const start = (config: MatchConfig) => (store ? setPending(config) : begin(config))

  const finish = () => {
    if (store?.present.status === 'matchOver' && !addHistory(toRecord(store.present))) {
      // keep the match so the result is not lost; the notice explains what to do
      setHistoryFailed(true)
      return
    }
    setHistoryFailed(false)
    dispatch({ type: 'clear' })
    setScreen('history')
  }

  const abandon = () => {
    dispatch({ type: 'clear' })
    setScreen('home')
  }

  const notice = historyFailed
    ? 'Hasil gagal disimpan ke riwayat karena penyimpanan penuh. Hapus beberapa riwayat lama, lalu tap Simpan hasil lagi.'
    : !saved && store
      ? 'Skor tidak bisa disimpan di perangkat ini (mode privat atau penyimpanan penuh). Jangan tutup halaman sampai pertandingan selesai.'
      : undefined

  if (screen === 'score' && store)
    return (
      <Scoreboard
        match={store.present}
        canUndo={canUndo(store)}
        dispatch={dispatch}
        onExit={() => setScreen('home')}
        onFinish={finish}
        onAbandon={abandon}
        notice={notice}
      />
    )

  const active = store?.present
  const g = active && currentGame(active)
  const confirm = pending && active && g && (
    <Modal label="Ganti pertandingan yang sedang jalan?" onEscape={() => setPending(undefined)}>
      <h2>Ganti pertandingan yang sedang jalan?</h2>
      <p className="muted">
        {active.status === 'matchOver'
          ? `Hasil ${sideTitle(active.config, active.winner!)} menang belum disimpan ke riwayat dan akan hilang.`
          : `Skor ${headTitle(active.config, 'A')} ${g.score.A}–${g.score.B} ${headTitle(active.config, 'B')} di game ${active.games.length} akan hilang.`}
      </p>
      <div className="modal-actions">
        <button
          className="btn btn-ghost"
          autoFocus
          onClick={() => {
            setPending(undefined)
            setScreen('score')
          }}
        >
          Lanjutkan
        </button>
        <button className="btn btn-danger" onClick={() => begin(pending)}>
          Mulai baru
        </button>
      </div>
    </Modal>
  )

  let page
  if (screen === 'setup') page = <Setup onStart={start} onBack={() => setScreen('home')} />
  else if (screen === 'history') page = <History onBack={() => setScreen('home')} />
  else
    page = (
      <Home
        active={active}
        onNew={() => setScreen('setup')}
        onQuickStart={start}
        onResume={() => setScreen('score')}
        onHistory={() => setScreen('history')}
      />
    )

  return (
    <>
      {page}
      {notice && (
        <p className="notice" role="alert">
          {notice}
        </p>
      )}
      {confirm}
    </>
  )
}
