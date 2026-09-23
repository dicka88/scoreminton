import { useCallback, useEffect, useState } from 'react'

/** Keep the screen awake while `active`. Re-acquires after tab becomes visible again. */
export function useWakeLock(active: boolean) {
  useEffect(() => {
    if (!active || !('wakeLock' in navigator)) return
    let lock: WakeLockSentinel | undefined
    let cancelled = false
    const acquire = async () => {
      try {
        lock = await navigator.wakeLock.request('screen')
        if (cancelled) lock.release()
      } catch {
        // denied (battery saver, not visible) — ignore
      }
    }
    const onVisible = () => document.visibilityState === 'visible' && acquire()
    acquire()
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      cancelled = true
      document.removeEventListener('visibilitychange', onVisible)
      lock?.release().catch(() => {})
    }
  }, [active])
}

export function useFullscreen() {
  const [isFull, setFull] = useState(() => !!document.fullscreenElement)
  useEffect(() => {
    const on = () => setFull(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', on)
    return () => document.removeEventListener('fullscreenchange', on)
  }, [])
  const supported = !!document.documentElement.requestFullscreen
  const toggle = useCallback(async () => {
    try {
      if (document.fullscreenElement) await document.exitFullscreen()
      else {
        await document.documentElement.requestFullscreen({ navigationUI: 'hide' })
        // best effort; only works in fullscreen on Android Chrome
        const o = screen.orientation as ScreenOrientation & { lock?: (o: string) => Promise<void> }
        await o.lock?.('landscape').catch(() => {})
      }
    } catch {
      // ignore
    }
  }, [])
  return { isFull, toggle, supported }
}

export function vibrate(ms = 25) {
  try {
    navigator.vibrate?.(ms)
  } catch {
    // unsupported
  }
}
