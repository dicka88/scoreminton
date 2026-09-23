import SwiftUI

@main
struct ScoremintonApp: App {
    @State private var store = MatchStore()
    @State private var history = HistoryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(history)
                .preferredColorScheme(.light)
                .tint(Theme.ink)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Storage.flush() }
        }
    }
}

enum Route: Hashable {
    case setup, history
}

struct RootView: View {
    @Environment(MatchStore.self) private var store
    @Environment(HistoryStore.self) private var history
    @State private var path: [Route] = []
    @State private var scoring = false
    /// New match waiting for the user to confirm it may replace the one in progress.
    @State private var pending: MatchConfig?
    @State private var historyFailed = false

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onNew: { path.append(.setup) },
                onQuickStart: start,
                onResume: { scoring = true },
                onHistory: { path.append(.history) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .setup: SetupView(onStart: start)
                case .history: HistoryView()
                }
            }
        }
        .overlay(alignment: .top) { if !scoring, let notice { NoticeBanner(text: notice) } }
        .alert(
            "Ganti pertandingan yang sedang jalan?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { config in
            // cancel role: keeps the match and stops iOS adding its own English "Cancel"
            Button("Lanjutkan", role: .cancel) {
                pending = nil
                path = []
                scoring = true
            }
            Button("Mulai baru", role: .destructive) { begin(config) }
        } message: { _ in
            Text(replaceMessage)
        }
        .fullScreenCover(isPresented: $scoring) {
            if let match = store.present {
                ScoreboardView(
                    match: match,
                    onExit: { scoring = false },
                    onFinish: finish,
                    onAbandon: abandon,
                    notice: notice
                )
            }
        }
    }

    private var notice: String? {
        if historyFailed {
            return "Hasil gagal disimpan ke riwayat karena penyimpanan penuh. Kosongkan ruang di iPhone, lalu tap Simpan hasil lagi."
        }
        if !store.saved && store.present != nil {
            return "Skor tidak bisa disimpan di perangkat ini (penyimpanan penuh). Jangan tutup app sampai pertandingan selesai."
        }
        return nil
    }

    private var replaceMessage: String {
        guard let m = store.present else { return "" }
        if m.status == .matchOver, let w = m.winner {
            return "Hasil \(m.config.headTitle(w)) menang belum disimpan ke riwayat dan akan hilang."
        }
        let g = m.currentGame
        return "Skor \(m.config.headTitle(.A)) \(g.score.A)–\(g.score.B) \(m.config.headTitle(.B)) di game \(m.games.count) akan hilang."
    }

    private func start(_ config: MatchConfig) {
        if store.present != nil { pending = config } else { begin(config) }
    }

    private func begin(_ config: MatchConfig) {
        pending = nil
        historyFailed = false
        store.new(config)
        path = []
        scoring = true
    }

    private func finish() {
        if let m = store.present, m.status == .matchOver, !history.add(m.toRecord()) {
            // keep the match so the result is not lost; the notice explains what to do
            historyFailed = true
            return
        }
        historyFailed = false
        store.clear()
        scoring = false
        path = [.history]
    }

    private func abandon() {
        store.clear()
        scoring = false
    }
}
