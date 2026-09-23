import SwiftUI

private let presetTargets = [11, 15, 21, 30]
private let customTag = -1

/// 21→30, 15→21, 11→16 for rally; target+2 for service-over setting.
private func defaultCap(_ scoring: ScoringSystem, _ target: Int) -> Int {
    scoring == .rally ? Int((Double(target) * 30 / 21).rounded()) : target + 2
}

private func initialConfig() -> MatchConfig {
    let p = Preset.rally
    let blank = TeamInfo(name: "", players: ["", ""])
    var cfg = MatchConfig(
        format: .double, scoring: .rally, bestOf: 3,
        target: p.target, deuce: p.deuce, cap: p.cap,
        teams: PerSide(A: blank, B: blank), firstServer: .A
    )
    if let last = MatchStore.lastConfig() {
        cfg = last
        for s in Side.allCases {
            cfg.teams[s].players = Array((last.teams[s].players + ["", ""]).prefix(2))
        }
    }
    return cfg
}

struct SetupView: View {
    var onStart: (MatchConfig) -> Void

    @State private var cfg = initialConfig()
    @State private var customTarget = false
    /// Target/deuce/cap live behind a disclosure so the default path is format, games, names.
    @State private var showAdvanced = false

    private var playersPerTeam: Int { cfg.format == .single ? 1 : 2 }

    @Environment(\.verticalSizeClass) private var vSize
    @Environment(\.horizontalSizeClass) private var hSize
    /// Phone in landscape or iPad: rules and players side by side, slim start bar.
    private var wide: Bool { vSize == .compact || hSize == .regular }

    var body: some View {
        Group {
            if wide {
                HStack(spacing: 0) {
                    Form { rulesSections }
                    Form {
                        teamSection(.A)
                        teamSection(.B)
                    }
                }
            } else {
                Form {
                    rulesSections
                    teamSection(.A)
                    teamSection(.B)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Pertandingan baru")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .onAppear {
            customTarget = !presetTargets.contains(cfg.target)
            // Open the section when the restored config isn't the plain preset, so custom rules stay visible.
            showAdvanced = Preset(target: cfg.target, deuce: cfg.deuce, cap: cfg.cap) != Preset.of(cfg.scoring)
        }
    }

    @ViewBuilder private var rulesSections: some View {
        Section("Aturan main") {
            Picker("Format", selection: $cfg.format) {
                Text("Single").tag(Format.single)
                Text("Double").tag(Format.double)
            }
            .pickerStyle(.segmented)

            Picker("Sistem poin", selection: Binding(
                get: { cfg.scoring },
                set: { setScoring($0) }
            )) {
                Text("Rally point").tag(ScoringSystem.rally)
                Text("Service-over").tag(ScoringSystem.serviceOver)
            }
            .pickerStyle(.segmented)

            Text(cfg.scoring == .rally
                 ? "Setiap rally menghasilkan poin untuk pemenangnya (BWF sekarang)."
                 : "Sistem lama: poin hanya untuk tim yang servis. Kalau penerima menang rally, servis pindah tanpa poin.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }

        Section("Poin & game") {
            Picker("Jumlah game", selection: $cfg.bestOf) {
                Text("1 game").tag(1)
                Text("Best of 3").tag(3)
            }
            .pickerStyle(.segmented)

            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target poin").font(.subheadline).foregroundStyle(Theme.muted)
                    Picker("Target poin", selection: targetTag) {
                        ForEach(presetTargets, id: \.self) { Text("\($0)").tag($0) }
                        Text("Lain").tag(customTag)
                    }
                    .pickerStyle(.segmented)
                }
                if customTarget {
                    Stepper("Target: \(cfg.target)", value: Binding(
                        get: { cfg.target },
                        set: { setTarget($0) }
                    ), in: 1...98)
                }

                Toggle(cfg.scoring == .rally
                       ? "Deuce, menang selisih 2"
                       : "Setting di \(cfg.target - 1)–\(cfg.target - 1)",
                       isOn: $cfg.deuce)
                if cfg.deuce {
                    Stepper(
                        "\(cfg.scoring == .rally ? "Maksimal" : "Main sampai") \(cfg.cap)",
                        value: $cfg.cap,
                        in: (cfg.target + 1)...99
                    )
                }
            } label: {
                HStack {
                    Text("Aturan lanjutan")
                    Spacer()
                    Text(advancedSummary)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    /// Keeps the numbers readable while the disclosure is closed.
    private var advancedSummary: String {
        guard cfg.deuce else { return "\(cfg.target) poin · tanpa deuce" }
        let tail = cfg.scoring == .rally ? "maks \(cfg.cap)" : "setting \(cfg.cap)"
        return "\(cfg.target) poin · \(tail)"
    }

    private var targetTag: Binding<Int> {
        Binding(
            get: { customTarget ? customTag : cfg.target },
            set: { v in
                if v == customTag {
                    customTarget = true
                    setTarget(cfg.target + 1)
                } else {
                    customTarget = false
                    setTarget(v)
                }
            }
        )
    }

    private func setTarget(_ t: Int) {
        cfg.target = min(max(t, 1), 98)
        cfg.cap = max(defaultCap(cfg.scoring, cfg.target), cfg.target + 1)
    }

    private func setScoring(_ s: ScoringSystem) {
        let p = Preset.of(s)
        cfg.scoring = s
        cfg.target = p.target
        cfg.deuce = p.deuce
        cfg.cap = p.cap
        customTarget = false
    }

    private func teamSection(_ s: Side) -> some View {
        Section {
            if cfg.format == .double {
                TextField("Nama tim (opsional)", text: $cfg.teams[s].name)
                    .textInputAutocapitalization(.words)
            }
            ForEach(0..<playersPerTeam, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(cfg.avatarText(s, i))
                        .font(.display(13, .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Theme.team(s), in: .circle)
                    TextField(placeholder(i), text: $cfg.teams[s].players[i])
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }
            Toggle("Servis duluan", isOn: Binding(
                get: { cfg.firstServer == s },
                set: { cfg.firstServer = $0 ? s : s.other }
            ))
        } header: {
            HStack(spacing: 8) {
                Text(s.rawValue)
                    .font(.display(13, .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Theme.team(s), in: .circle)
                Text("Tim \(s.rawValue)").foregroundStyle(Theme.team(s))
            }
        } footer: {
            if s == .B { Text("Nama boleh dikosongkan.") }
        }
    }

    private func placeholder(_ i: Int) -> String {
        if cfg.format == .single { return "Nama pemain" }
        return i == 0 ? "Pemain 1 · mulai di kanan" : "Pemain 2 · mulai di kiri"
    }

    private var actionBar: some View {
        let layout = wide ? AnyLayout(HStackLayout(spacing: 16)) : AnyLayout(VStackLayout(spacing: 8))
        return layout {
            Text(cfg.modeLabel)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: wide ? .infinity : nil, alignment: .leading)
            Button("Mulai pertandingan", action: submit)
                .buttonStyle(PrimaryButtonStyle(height: wide ? 44 : 52))
                .frame(maxWidth: wide ? 300 : .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, wide ? 6 : 12)
        .background(.bar)
    }

    private func submit() {
        var c = cfg
        let n = playersPerTeam
        for s in Side.allCases {
            c.teams[s].players = Array(c.teams[s].players.prefix(n))
            if n == 1 { c.teams[s].name = "" }
        }
        if !c.deuce { c.cap = max(c.cap, c.target + 1) }
        onStart(c)
    }
}

// MARK: - Previews

#if DEBUG
/// `initialConfig()` reads the last-used config from disk, so whether "Aturan lanjutan"
/// starts expanded here depends on the simulator's saved state.
#Preview("Setup") {
    NavigationStack {
        SetupView(onStart: { _ in })
    }
    .previewChrome()
}
#endif
