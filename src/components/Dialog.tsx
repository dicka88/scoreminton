import { useEffect, useRef, type ReactNode, type RefObject } from 'react'

const FOCUSABLE = 'button:not(:disabled), input:not(:disabled), [href], [tabindex]:not([tabindex="-1"])'

/** Keep keyboard focus inside the dialog, close on Escape, and hand focus back when it closes. */
function useDialog(ref: RefObject<HTMLDivElement | null>, onEscape?: () => void) {
  const escape = useRef(onEscape)
  // Read during the first render, before an autoFocus child takes focus.
  const opener = useRef(document.activeElement instanceof HTMLElement ? document.activeElement : null)
  useEffect(() => {
    escape.current = onEscape
  })

  useEffect(() => {
    const el = ref.current
    if (!el) return
    const back = opener.current
    if (!el.contains(document.activeElement)) el.focus()

    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && escape.current) {
        e.preventDefault()
        escape.current()
        return
      }
      if (e.key !== 'Tab') return
      const items = [...el.querySelectorAll<HTMLElement>(FOCUSABLE)]
      if (!items.length) return
      const first = items[0]
      const last = items[items.length - 1]
      const inside = el.contains(document.activeElement)
      if (!inside || (e.shiftKey && document.activeElement === first)) {
        e.preventDefault()
        ;(e.shiftKey ? last : first).focus()
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault()
        first.focus()
      }
    }
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      // StrictMode re-runs effects without removing the node; only a real close hands focus back.
      queueMicrotask(() => {
        if (!el.isConnected && back?.isConnected) back.focus()
      })
    }
  }, [ref])
}

export function Modal({ label, onEscape, children }: { label: string; onEscape?: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  useDialog(ref, onEscape)
  return (
    <div className="overlay">
      <div ref={ref} className="modal" role="dialog" aria-modal="true" aria-label={label} tabIndex={-1}>
        {children}
      </div>
    </div>
  )
}

export function Sheet({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  useDialog(ref, onClose)
  return (
    <div className="overlay" onClick={onClose}>
      <div
        ref={ref}
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-label={title}
        tabIndex={-1}
        onClick={(e) => e.stopPropagation()}
      >
        <header className="sheet-head">
          <h3>{title}</h3>
          <button className="btn btn-ghost btn-sm" onClick={onClose}>
            Tutup
          </button>
        </header>
        <div className="sheet-body">{children}</div>
      </div>
    </div>
  )
}
