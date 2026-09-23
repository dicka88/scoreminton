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
        .fullScreenCover(isPresented: $scoring) {
            if let match = store.present {
                ScoreboardView(
                    match: match,
                    onExit: { scoring = false },
                    onFinish: finish,
                    onAbandon: abandon
                )
            }
        }
    }

    private func start(_ config: MatchConfig) {
        store.new(config)
        path = []
        scoring = true
    }

    private func finish() {
        if let m = store.present, m.status == .matchOver { history.add(m.toRecord()) }
        store.clear()
        scoring = false
        path = [.history]
    }

    private func abandon() {
        store.clear()
        scoring = false
    }
}
