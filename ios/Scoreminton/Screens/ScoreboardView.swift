import SwiftUI
import UIKit

private enum SheetKind: String, Identifiable {
    case log
    var id: String { rawValue }
}

struct ScoreboardView: View {
    @Environment(MatchStore.self) private var store
    let match: MatchState
    var onExit: () -> Void
    var onFinish: () -> Void
    var onAbandon: () -> Void
    /// Storage problem to show over the board (never blocks scoring).
    var notice: String? = nil

    @State private var sheet: SheetKind?
    /// Menu is a card over the board (a sheet goes full screen in phone landscape).
    @State private var showMenu = false
    @State private var confirmAbandon = false
    /// Ignore taps that land while the board is still appearing (finger from the previous screen).
    @State private var readyAt = Date().addingTimeInterval(0.4)

    private var cfg: MatchConfig { match.config }
    private var g: GameState { match.currentGame }
    private var left: Side { match.leftTeam }
    private var right: Side { match.leftTeam.other }

    var body: some View {
        GeometryReader { geo in
            let inset = geo.safeAreaInsets
            let landscape = geo.size.width > geo.size.height
            let layout = landscape ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 10))
            // phone-sized cards keep 1×; iPad cards grow the chrome so it reads from the court
            let k = min(max((landscape ? geo.size.height : geo.size.width) / 400, 1), 1.6)
            layout {
                panel(left, first: true, landscape: landscape, k: k)
                spine(landscape: landscape, k: k)
                panel(right, first: false, landscape: landscape, k: k)
            }
            // Landscape: the side insets are symmetric but the sensor housing only sits mid-edge,
            // where the cards show nothing but background — reclaim part of that width.
            .padding(.leading, landscape ? max(10, inset.leading - 26) : inset.leading + 10)
            .padding(.trailing, landscape ? max(10, inset.trailing - 26) : inset.trailing + 10)
            .padding(.top, inset.top + 10)
            .padding(.bottom, landscape ? max(8, inset.bottom - 8) : inset.bottom + 10)
        }
        .ignoresSafeArea()
        .background(Theme.paper.ignoresSafeArea())
        .overlay { modal }
        .overlay(alignment: .top) { if let notice { NoticeBanner(text: notice) } }
        .overlay { if showMenu { menuCard } }
        .animation(.easeOut(duration: 0.15), value: showMenu)
        .background { keyboardShortcuts }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .sheet(item: $sheet) { kind in
            switch kind {
            case .log: logSheet
            }
        }
        .alert("Akhiri tanpa menyimpan?", isPresented: $confirmAbandon) {
            Button("Kembali", role: .cancel) {}
            Button("Ya, akhiri", role: .destructive, action: onAbandon)
        } message: {
            Text("Skor \(g.score[left])–\(g.score[right]) di game \(match.games.count) dibuang dan tidak masuk riwayat.")
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: match.status) { _, s in
            if s == .matchOver { Haptics.success() }
        }
        .onChange(of: announcement) { _, text in
            // VoiceOver hears every score change, including undo
            if !text.isEmpty { AccessibilityNotification.Announcement(text).post() }
        }
    }

    private var announcement: String {
        guard match.status == .playing else { return "" }
        let server = cfg.playerName(g.servingTeam, g.server)
        let court = cfg.serviceCourt(g) == .R ? "kanan" : "kiri"
        return "\(cfg.sideTitle(left)) \(g.score[left]), \(cfg.sideTitle(right)) \(g.score[right]). \(server) servis dari kotak \(court)."
    }

    // MARK: - Actions

    private func score(_ s: Side) {
        guard match.status == .playing, sheet == nil, !showMenu, !confirmAbandon, Date() >= readyAt else { return }
        Haptics.tap()
        store.rally(s)
    }

    private func undo() {
        guard store.canUndo else { return }
        Haptics.light()
        withAnimation(.snappy) { store.undo() }
    }

    // MARK: - Layout

    private func panel(_ s: Side, first: Bool, landscape: Bool, k: CGFloat) -> some View {
        TeamPanel(
            match: match,
            side: s,
            first: first,
            landscape: landscape,
            k: k,
            onScore: score,
            onSwapPositions: { store.swapPositions($0) },
            onSetFirstServer: { store.setFirstServer($0) }
        )
    }

    /// Net strip between the two panels holding the controls.
    private func spine(landscape: Bool, k: CGFloat) -> some View {
        let won = match.gamesWon
        let layout = landscape ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            VStack(spacing: 2) {
                Text("Game \(match.games.count)")
                    .font(.display(12 * k, .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.muted)
                if cfg.bestOf > 1 {
                    HStack(spacing: 3) {
                        Text("\(won[left])").foregroundStyle(Theme.team(left))
                        Text("–").foregroundStyle(Theme.muted)
                        Text("\(won[right])").foregroundStyle(Theme.team(right))
                    }
                    .font(.display(20 * k, .heavy))
                    .monospacedDigit()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Game dimenangkan \(won[left]) lawan \(won[right])")
                }
                if extended {
                    Text(cfg.scoring == .rally ? "Deuce" : "Setting \(cfg.cap)")
                        .font(.display(11 * k, .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Theme.sun, in: .capsule)
                        .fixedSize()
                        .padding(.top, 2)
                }
            }
            .frame(minWidth: 56)
            if landscape { Spacer(minLength: 0) }
            iconButton("Undo", "arrow.uturn.backward", k: k, disabled: !store.canUndo, action: undo)
            HoldButton(title: "Sisi", symbol: landscape ? "arrow.left.arrow.right" : "arrow.up.arrow.down", k: k) {
                withAnimation(.snappy) { store.swapSides() }
            }
            iconButton("Log", "list.bullet", k: k) { sheet = .log }
            iconButton("Menu", "line.3.horizontal", k: k) { showMenu = true }
            if landscape { Spacer(minLength: 0) }
        }
        .padding(landscape ? .vertical : .horizontal, 8)
        .frame(width: landscape ? 76 * k : nil, height: landscape ? nil : 64 * k)
        .frame(maxWidth: landscape ? nil : .infinity, maxHeight: landscape ? .infinity : nil)
        .background(
            // net pattern
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Theme.ink.opacity(0.06), radius: 8, y: 4)
        )
    }

    private func iconButton(_ title: String, _ symbol: String, k: CGFloat, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 20 * k, weight: .semibold))
                Text(title).font(.display(11 * k, .bold))
            }
            .frame(width: 56 * k, height: 50 * k)
            .foregroundStyle(Theme.ink)
            .background(Theme.field, in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .accessibilityLabel(title == "Sisi" ? "Tukar sisi" : title)
    }

    /// Deuce (rally) or setting (service-over) is on once both sides reach target − 1.
    private var extended: Bool {
        cfg.deuce && match.status == .playing && min(g.score.A, g.score.B) >= cfg.target - 1
    }

    // MARK: - Modals

    @ViewBuilder private var modal: some View {
        switch match.status {
        case .playing:
            EmptyView()
        case .interval:
            ModalCard {
                Text("Interval game \(match.games.count)").font(.display(24, .heavy)).foregroundStyle(Theme.ink)
                scoreLine(g.score[left], g.score[right], left, right)
                if cfg.isDecidingGame(match.games.count - 1) { Callout("Pindah sisi lapangan") }
                Text("Istirahat maksimal 60 detik. Minum dulu!").foregroundStyle(Theme.muted)
                actions(primary: "Lanjut main") { store.resume() }
            }
        case .gameOver:
            let w = g.winner ?? .A
            ModalCard {
                (Text(cfg.headTitle(w)).foregroundColor(Theme.team(w)) + Text(" menang game \(match.games.count)"))
                    .font(.display(28, .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                scoreLine(g.score[w], g.score[w.other], w, w.other)
                Callout("Pindah sisi · \(cfg.headTitle(w)) servis duluan")
                actions(primary: "Mulai game \(match.games.count + 1)") {
                    withAnimation(.snappy) { store.nextGame() }
                }
            }
        case .matchOver:
            let w = match.winner ?? .A
            ZStack {
                ModalCard {
                    Trophy()
                    (Text(cfg.headTitle(w)).foregroundColor(Theme.team(w)) + Text(" menang!"))
                        .font(.display(30, .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 14) {
                        ForEach(Array(match.games.enumerated()), id: \.offset) { _, x in
                            Text("\(x.score[w])–\(x.score[w.other])")
                                .foregroundStyle(Theme.team(x.winner ?? w))
                        }
                    }
                    .font(.display(22, .heavy))
                    .monospacedDigit()
                    Text("\(cfg.modeLabel) · \(formatDuration((match.endedAt ?? match.startedAt).timeIntervalSince(match.startedAt)))")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    actions(primary: "Simpan hasil", action: onFinish)
                }
                Confetti()
            }
        }
    }

    private func scoreLine(_ a: Int, _ b: Int, _ sa: Side, _ sb: Side) -> some View {
        HStack(spacing: 6) {
            Text("\(a)").foregroundStyle(Theme.team(sa))
            Text("–").foregroundStyle(Theme.muted)
            Text("\(b)").foregroundStyle(Theme.team(sb))
        }
        .font(.display(52, .heavy))
        .monospacedDigit()
    }

    private func actions(primary: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button("Undo", action: undo).buttonStyle(GhostButtonStyle())
            Button(primary, action: action).buttonStyle(PrimaryButtonStyle())
        }
        .padding(.top, 6)
    }

    // MARK: - Sheets

    private var logSheet: some View {
        NavigationStack {
            Group {
                if g.rallies.isEmpty {
                    ContentUnavailableView("Belum ada rally", systemImage: "list.bullet")
                } else {
                    List {
                        ForEach(Array(g.rallies.enumerated().reversed()), id: \.offset) { i, r in
                            HStack(spacing: 12) {
                                Text("\(i + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.muted)
                                    .frame(width: 28, alignment: .trailing)
                                Text("\(r.score[left])–\(r.score[right])")
                                    .font(.display(18, .heavy))
                                    .foregroundStyle(Theme.team(r.winner))
                                    .frame(width: 64)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.point ? "Poin \(cfg.headTitle(r.winner))" : "Pindah servis → \(cfg.headTitle(r.winner))")
                                        .font(.subheadline.weight(.semibold))
                                    Text("servis: \(cfg.playerName(r.servingTeam, r.server))")
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .monospacedDigit()
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Log rally · Game \(match.games.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Tutup") { sheet = nil } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var menuCard: some View {
        ModalCard(onDismiss: { showMenu = false }) {
            Text("Menu").font(.display(22, .heavy)).foregroundStyle(Theme.ink)
            Text(cfg.modeLabel)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button("Ke beranda (match tetap tersimpan)") {
                showMenu = false
                onExit()
            }
            .buttonStyle(GhostButtonStyle())
            Button("Akhiri tanpa menyimpan") {
                showMenu = false
                confirmAbandon = true
            }
            .buttonStyle(GhostButtonStyle(tint: Theme.danger))
            Button("Tutup") { showMenu = false }
                .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - Hardware keyboard (iPad)

    /// `←` / `→` score left/right side, `⌫` / `Z` undo.
    private var keyboardShortcuts: some View {
        ZStack {
            Button("") { score(left) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { score(right) }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("") { undo() }.keyboardShortcut(.delete, modifiers: [])
            Button("") { undo() }.keyboardShortcut("z", modifiers: [])
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

// MARK: - Controls

/// Acts only after a deliberate press-and-hold, so a stray tap mid-rally does nothing.
/// A short tap says "Tahan" instead of silently ignoring the touch.
private struct HoldButton: View {
    let title: String
    let symbol: String
    var k: CGFloat = 1
    var duration: Double = 0.6
    let onHold: () -> Void

    @State private var progress: CGFloat = 0
    @State private var fired = false
    @State private var nudge = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 20 * k, weight: .semibold))
            Text(nudge ? "Tahan" : title).font(.display(11 * k, .bold))
        }
        .frame(width: 56 * k, height: 50 * k)
        .foregroundStyle(Theme.ink)
        .background(alignment: .bottom) {
            // fill rises while held; full = swap
            GeometryReader { geo in
                Theme.blueMid.frame(height: geo.size.height * progress).frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Theme.field)
        .clipShape(.rect(cornerRadius: 16, style: .continuous))
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 20) {
            fired = true
            Haptics.tap()
            onHold()
        } onPressingChanged: { pressing in
            if pressing {
                fired = false
                nudge = false
                withAnimation(.linear(duration: duration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.15)) { progress = 0 }
            }
        }
        // released too early: say how it works instead of silently ignoring the tap
        .simultaneousGesture(TapGesture().onEnded { if !fired { nudge = true } })
        .task(id: nudge) {
            guard nudge else { return }
            try? await Task.sleep(for: .seconds(1.4))
            if !Task.isCancelled { nudge = false }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tukar sisi layar")
        .accessibilityHint("Tekan dan tahan")
        .accessibilityAddTraits(.isButton)
        // VoiceOver and Switch Control users act on purpose; no hold needed
        .accessibilityAction { onHold() }
    }
}

/// Storage problem banner: stays visible, never intercepts taps.
struct NoticeBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.display(14, .bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Theme.danger, in: .rect(cornerRadius: 16, style: .continuous))
            .shadow(color: Theme.ink.opacity(0.25), radius: 12, y: 6)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(maxWidth: 560)
            .allowsHitTesting(false)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Modal pieces

private struct ModalCard<Content: View>: View {
    /// Set to let a tap on the backdrop close the card.
    var onDismiss: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss?() }
            ScrollView {
                VStack(spacing: 12) { content }
                    .padding(24)
                    .frame(maxWidth: 420)
                    .background(Theme.card, in: .rect(cornerRadius: 28, style: .continuous))
                    .shadow(color: Theme.ink.opacity(0.22), radius: 32, y: 16)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
        .transition(.opacity)
    }
}

private struct Callout: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.display(15, .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.sun.opacity(0.35), in: .capsule)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Board · doubles") {
    let s = Sample.board()
    ScoreboardView(match: s.match, onExit: {}, onFinish: {}, onAbandon: {})
        .environment(s.store)
        .previewChrome()
}

#Preview("Board · singles") {
    let s = Sample.board(format: .single, ralliesA: 6, ralliesB: 9)
    ScoreboardView(match: s.match, onExit: {}, onFinish: {}, onAbandon: {})
        .environment(s.store)
        .previewChrome()
}

/// Ends on the 11th point, which is where the engine raises the interval.
#Preview("Interval") {
    let s = Sample.board(ralliesA: 11, ralliesB: 8)
    ScoreboardView(match: s.match, onExit: {}, onFinish: {}, onAbandon: {})
        .environment(s.store)
        .previewChrome()
}
#endif
