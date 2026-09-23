import SwiftUI

struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @State private var pendingDelete: MatchRecord?

    var body: some View {
        Group {
            if history.records.isEmpty {
                ContentUnavailableView(
                    "Belum ada pertandingan",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Hasil muncul di sini setelah match selesai.")
                )
            } else {
                List {
                    ForEach(history.records) { r in
                        row(r)
                            .swipeActions {
                                Button("Hapus", role: .destructive) { pendingDelete = r }
                            }
                            .contextMenu {
                                Button("Hapus", systemImage: "trash", role: .destructive) { pendingDelete = r }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Theme.paper)
        .navigationTitle("Riwayat")
        .confirmationDialog(
            "Hapus match ini?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { r in
            Button("Hapus", role: .destructive) { history.delete(r.id) }
            Button("Batal", role: .cancel) {}
        } message: { r in
            Text("\(r.config.sideTitle(.A)) vs \(r.config.sideTitle(.B))")
        }
    }

    private func row(_ r: MatchRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(formatDate(r.startedAt))
                Spacer()
                Text(formatDuration(r.endedAt.timeIntervalSince(r.startedAt)))
            }
            .font(.caption)
            .foregroundStyle(Theme.muted)

            ForEach(Side.allCases, id: \.self) { s in
                HStack(spacing: 8) {
                    Text(r.config.sideTitle(s))
                        .font(.display(17, r.winner == s ? .heavy : .semibold))
                        .foregroundStyle(Theme.team(s))
                        .lineLimit(1)
                    if r.winner == s {
                        Text("Menang")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.sun, in: .capsule)
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    ForEach(Array(r.games.enumerated()), id: \.offset) { _, g in
                        Text("\(g.score[s])")
                            .font(.display(18, g.winner == s ? .heavy : .regular))
                            .foregroundStyle(g.winner == s ? Theme.ink : Theme.muted)
                            .frame(minWidth: 28)
                    }
                }
                .monospacedDigit()
            }

            Text(r.config.modeLabel).font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("History") {
    NavigationStack {
        HistoryView()
    }
    .environment(Sample.history())
    .previewChrome()
}

#Preview("History · empty") {
    NavigationStack {
        HistoryView()
    }
    .environment(HistoryStore(persist: false))
    .previewChrome()
}
#endif
