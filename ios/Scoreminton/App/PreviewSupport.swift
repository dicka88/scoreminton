#if DEBUG
import SwiftUI

/// Sample data for `#Preview` blocks. Debug-only, so none of it reaches a release build.
enum Sample {
    /// Fixed instant so previews render identical dates and durations on every run.
    static let startedAt = Date(timeIntervalSince1970: 1_758_600_000)

    private static let namesA = ["Budi Santoso", "Adi Nugroho"]
    private static let namesB = ["Citra Lestari", "Dewi Anggraini"]

    static func config(
        format: Format = .double,
        scoring: ScoringSystem = .rally,
        bestOf: Int = 3
    ) -> MatchConfig {
        let p = Preset.of(scoring)
        let n = format == .single ? 1 : 2
        return MatchConfig(
            format: format,
            scoring: scoring,
            bestOf: bestOf,
            target: p.target,
            deuce: p.deuce,
            cap: p.cap,
            teams: PerSide(
                A: TeamInfo(name: "", players: Array(namesA.prefix(n))),
                B: TeamInfo(name: "", players: Array(namesB.prefix(n)))
            ),
            firstServer: .A
        )
    }

    /// A store seeded by replaying rallies through the real engine, plus its resulting match.
    ///
    /// Replaying (rather than hand-building a `MatchState`) keeps `store.present` and the
    /// returned match in agreement, so Undo and the rally log behave as they do in the app.
    /// `ralliesA`/`ralliesB` count rallies *won*, which equals points only under rally scoring.
    static func board(
        format: Format = .double,
        scoring: ScoringSystem = .rally,
        bestOf: Int = 3,
        ralliesA: Int = 9,
        ralliesB: Int = 6
    ) -> (store: MatchStore, match: MatchState) {
        let cfg = config(format: format, scoring: scoring, bestOf: bestOf)
        let store = MatchStore(persist: false)
        store.new(cfg)
        for side in interleaved(ralliesA, ralliesB) {
            // The engine drops rallies unless the status is `.playing`, so step past the
            // interval and game-over pauses to keep the replay moving. Ending the sequence
            // exactly on a pause leaves the match in that state, which is what the
            // interval preview below relies on.
            switch store.present?.status {
            case .interval: store.resume()
            case .gameOver: store.nextGame()
            default: break
            }
            store.rally(side)
        }
        return (store, store.present ?? .create(cfg, now: startedAt))
    }

    /// Alternating winners, so the service pattern and log read plausibly instead of
    /// showing one team scoring every point in a row.
    private static func interleaved(_ a: Int, _ b: Int) -> [Side] {
        var out: [Side] = []
        for i in 0..<max(a, b) {
            if i < a { out.append(.A) }
            if i < b { out.append(.B) }
        }
        return out
    }

    static func history() -> HistoryStore {
        let store = HistoryStore(persist: false)
        for r in records().reversed() { store.add(r) }
        return store
    }

    static func records() -> [MatchRecord] {
        [
            MatchRecord(
                id: "sample-doubles",
                config: config(),
                games: [
                    GameSummary(score: PerSide(A: 21, B: 18), winner: .A),
                    GameSummary(score: PerSide(A: 19, B: 21), winner: .B),
                    GameSummary(score: PerSide(A: 21, B: 15), winner: .A),
                ],
                winner: .A,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(52 * 60)
            ),
            MatchRecord(
                id: "sample-singles",
                config: config(format: .single),
                games: [
                    GameSummary(score: PerSide(A: 15, B: 21), winner: .B),
                    GameSummary(score: PerSide(A: 12, B: 21), winner: .B),
                ],
                winner: .B,
                startedAt: startedAt.addingTimeInterval(-2 * 24 * 60 * 60),
                endedAt: startedAt.addingTimeInterval(-2 * 24 * 60 * 60 + 31 * 60)
            ),
        ]
    }
}

extension View {
    /// The chrome `ScoremintonApp` applies to `RootView`, so previews aren't misleading
    /// about color scheme or tint.
    func previewChrome() -> some View {
        preferredColorScheme(.light).tint(Theme.ink)
    }
}
#endif
