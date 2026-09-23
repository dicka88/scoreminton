import SwiftUI

private struct Quick: Identifiable {
    var format: Format
    var scoring: ScoringSystem
    var title: String
    var sub: String
    var id: String { "\(format)-\(scoring)" }
}

private let quicks: [Quick] = [
    Quick(format: .double, scoring: .rally, title: "Double", sub: "Rally point · 21"),
    Quick(format: .single, scoring: .rally, title: "Single", sub: "Rally point · 21"),
    Quick(format: .double, scoring: .serviceOver, title: "Double", sub: "Service-over · 30"),
    Quick(format: .single, scoring: .serviceOver, title: "Single", sub: "Service-over · 30"),
]

/// Quick-start config: best of 3, preset points, last used player names.
func quickConfig(_ format: Format, _ scoring: ScoringSystem) -> MatchConfig {
    let last = MatchStore.lastConfig()
    let n = format == .single ? 1 : 2
    func team(_ s: Side) -> TeamInfo {
        TeamInfo(
            name: n == 1 ? "" : (last?.teams[s].name ?? ""),
            players: Array(((last?.teams[s].players ?? []) + ["", ""]).prefix(n))
        )
    }
    let p = Preset.of(scoring)
    return MatchConfig(
        format: format, scoring: scoring, bestOf: 3,
        target: p.target, deuce: p.deuce, cap: p.cap,
        teams: PerSide(A: team(.A), B: team(.B)),
        firstServer: .A
    )
}

struct HomeView: View {
    @Environment(MatchStore.self) private var store
    var onNew: () -> Void
    var onQuickStart: (MatchConfig) -> Void
    var onResume: () -> Void
    var onHistory: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                hero
                if let m = store.present { resumeCard(m) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(quicks) { q in
                        Button { onQuickStart(quickConfig(q.format, q.scoring)) } label: { quickCard(q) }
                            .buttonStyle(.plain)
                    }
                }
                Button("Atur sendiri & isi nama pemain", action: onNew)
                    .buttonStyle(PrimaryButtonStyle())
                Text("Mulai cepat memakai best of 3 dan nama pemain terakhir.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .navigationTitle("Beranda") // back button label on pushed screens
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Logo().frame(width: 30, height: 30)
                Text("Scoreminton").font(.display(22, .heavy)).foregroundStyle(Theme.ink)
            }
            Spacer()
            Button("Riwayat", action: onHistory)
                .font(.display(16, .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Theme.card, in: .capsule)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text("Mau main ") + Text("apa").foregroundColor(Theme.red) + Text(" hari ini?").foregroundColor(Theme.blue))
                .font(.display(34, .heavy))
                .foregroundStyle(Theme.ink)
            Text("Pilih mode, lalu tap sisi tim yang menang rally. Servis, posisi, dan pindah sisi diatur otomatis.")
                .font(.body)
                .foregroundStyle(Theme.muted)
        }
    }

    private func resumeCard(_ m: MatchState) -> some View {
        let g = m.currentGame
        return Button(action: onResume) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle().fill(Theme.red).frame(width: 8, height: 8)
                    Text("Pertandingan belum selesai · Game \(m.games.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                }
                HStack(spacing: 12) {
                    Text(m.config.sideTitle(.A)).foregroundStyle(Theme.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("\(g.score.A)").foregroundStyle(Theme.red).font(.display(40, .heavy))
                    Text("\(g.score.B)").foregroundStyle(Theme.blue).font(.display(40, .heavy))
                    Text(m.config.sideTitle(.B)).foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.display(16, .bold))
                .lineLimit(1)
                .monospacedDigit()
                Text("Lanjutkan →")
                    .font(.display(16, .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .card()
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.sun, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lanjutkan pertandingan, skor \(g.score.A) lawan \(g.score.B)")
    }

    private func quickCard(_ q: Quick) -> some View {
        let n = q.format == .single ? 1 : 2
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<n, id: \.self) { _ in Circle().fill(Theme.red).frame(width: 16, height: 16) }
                Text("vs").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                ForEach(0..<n, id: \.self) { _ in Circle().fill(Theme.blue).frame(width: 16, height: 16) }
            }
            Text(q.title).font(.display(22, .heavy)).foregroundStyle(Theme.ink)
            Text(q.sub).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .contentShape(.rect)
    }
}

// MARK: - Previews

#if DEBUG
/// No active match, so the resume card is absent.
#Preview("Home") {
    NavigationStack {
        HomeView(onNew: {}, onQuickStart: { _ in }, onResume: {}, onHistory: {})
    }
    .environment(MatchStore(persist: false))
    .previewChrome()
}

#Preview("Home · resumable") {
    NavigationStack {
        HomeView(onNew: {}, onQuickStart: { _ in }, onResume: {}, onHistory: {})
    }
    .environment(Sample.board().store)
    .previewChrome()
}
#endif
