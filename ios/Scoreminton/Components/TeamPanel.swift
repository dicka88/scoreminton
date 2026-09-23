import SwiftUI

private func courtWord(_ c: Court) -> String { c == .R ? "kanan" : "kiri" }

/// Half of the board: one team's score card. Tapping anywhere scores a rally for that team.
struct TeamPanel: View {
    let match: MatchState
    let side: Side
    /// true = left side (landscape) or top (portrait)
    let first: Bool
    let landscape: Bool
    /// UI scale for chrome (names, courts, badges): 1 on phones, up to 1.6 on iPad.
    var k: CGFloat = 1
    var onScore: (Side) -> Void
    var onSwapPositions: (Side) -> Void
    var onSetFirstServer: (Side) -> Void

    @State private var lastHit = Date.distantPast
    @State private var flash: Flash?

    private struct Flash: Equatable {
        var id: Int
        var text: String
    }

    private var cfg: MatchConfig { match.config }
    private var g: GameState { match.currentGame }
    private var serving: Bool { g.servingTeam == side }
    private var court: Court { cfg.serviceCourt(g) }
    private var active: PlayerIndex { serving ? g.server : cfg.receiver(g) }
    private var won: Int { match.gamesWon[side] }
    private var fresh: Bool { g.rallies.isEmpty }
    private var playing: Bool { match.status == .playing }
    private var gamePoint: Bool { playing && cfg.isGamePoint(g.score, side) }
    private var matchPoint: Bool { gamePoint && won == cfg.gamesToWin - 1 }
    private var color: Color { Theme.team(side) }

    var body: some View {
        // service courts sit against the net
        let svcFirst = !first
        let layout = landscape ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        GeometryReader { geo in
            // courts take a share of the card so small phones keep room for the score
            let svc = landscape
                ? min(max(geo.size.width * 0.3, 84), 124 * k)
                : min(max(geo.size.height * 0.3, 88), 120 * k)
            // small phones in landscape (iPhone SE): trim header chrome so nothing overflows
            let compact = landscape && geo.size.width - svc < 200 * k
            layout {
                if svcFirst { serviceBoxes(svc) }
                back(compact: compact)
                if !svcFirst { serviceBoxes(svc) }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [color, Theme.teamDeep(side)], startPoint: .top, endPoint: .bottom))
        )
        .overlay {
            if serving {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Theme.sun, lineWidth: 5)
            }
        }
        .shadow(color: color.opacity(serving ? 0.35 : 0.15), radius: serving ? 14 : 6, y: 8)
        .contentShape(.rect)
        .onTapGesture(perform: hit)
        .onChange(of: g.rallies.count) { old, new in
            let last = g.rallies.last
            if new > old, let last, last.winner == side {
                flash = Flash(id: new, text: last.point ? "+1" : "Pindah servis")
            } else {
                flash = nil
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func hit() {
        // guard against accidental double taps
        let now = Date()
        guard now.timeIntervalSince(lastHit) > 0.28 else { return }
        lastHit = now
        onScore(side)
    }

    // MARK: - Score card

    private func back(compact: Bool) -> some View {
        VStack(spacing: 0) {
            header(compact: compact)
                .fixedSize(horizontal: false, vertical: true)
            ZStack {
                VStack(spacing: 4) {
                    if gamePoint {
                        Text(matchPoint ? "Match point" : "Game point")
                            .font(.display(15 * k, .heavy))
                            .textCase(.uppercase)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Theme.sun, in: .capsule)
                            .foregroundStyle(Theme.ink)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text("\(g.score[side])")
                        .font(.system(size: 400, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.05)
                        .lineLimit(1)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(g.score[side])))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .shadow(color: .black.opacity(0.15), radius: 0, y: 4)
                    if playing && fresh && match.games.count == 1 {
                        Text("Tap di sini kalau menang rally")
                            .font(.display(14 * k, .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                }
                .animation(.snappy(duration: 0.25), value: g.score[side])
                .animation(.snappy, value: gamePoint)

                if let flash {
                    FloatText(text: flash.text).id(flash.id)
                }
            }
            .frame(maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(cfg.sideTitle(side)), skor \(g.score[side])")
            .accessibilityHint("Ketuk dua kali untuk poin tim ini")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { hit() }

            footer
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Landscape cards are narrow, so the name gets its own line below the badges.
    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(side.rawValue)
                    .font(.display(15 * k, .heavy))
                    .foregroundStyle(color)
                    .frame(width: 28 * k, height: 28 * k)
                    .background(.white, in: .circle)
                if landscape { Spacer(minLength: 0) } else { teamName(compact: false) }
                if serving {
                    HStack(spacing: 4) {
                        Shuttlecock(color: Theme.ink).frame(width: 16 * k, height: 16 * k)
                        if !compact { Text("Servis").font(.display(13 * k, .heavy)) }
                    }
                    .padding(.horizontal, compact ? 7 : 10).padding(.vertical, 5)
                    .background(Theme.sun, in: .capsule)
                    .foregroundStyle(Theme.ink)
                    .fixedSize()
                }
                if cfg.bestOf > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<cfg.gamesToWin, id: \.self) { i in
                            Circle()
                                .strokeBorder(.white, lineWidth: 2.5)
                                .background(Circle().fill(i < won ? .white : .clear))
                                .frame(width: 14 * k, height: 14 * k)
                        }
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(won) game dimenangkan")
                }
            }
            if landscape { teamName(compact: compact) }
        }
    }

    private func teamName(compact: Bool) -> some View {
        Text(cfg.sideTitle(side))
            .font(.display((compact ? 16 : 18) * k, .heavy))
            .foregroundStyle(.white)
            .lineLimit(landscape ? 2 : 1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if fresh && playing { prestartChips }
            status
                .font(.system(size: 15 * k, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Before the first rally: pick who serves / swap doubles positions. Stacks when the card is narrow.
    @ViewBuilder private var prestartChips: some View {
        let showServe = !serving && match.games.count == 1
        let showSwap = cfg.format == .double
        if showServe || showSwap {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    if showServe { chip("Servis duluan") { onSetFirstServer(side) } }
                    if showSwap { chip("Tukar posisi") { onSwapPositions(side) } }
                }
                VStack(alignment: .leading, spacing: 6) {
                    if showServe { chip("Servis duluan") { onSetFirstServer(side) } }
                    if showSwap { chip("Tukar posisi") { onSwapPositions(side) } }
                }
            }
        }
    }

    @ViewBuilder private var status: some View {
        let who = cfg.playerName(side, active)
        if serving {
            VStack(alignment: .leading, spacing: 2) {
                (Text(who).fontWeight(.heavy).foregroundColor(.white) + Text(" servis dari kotak \(courtWord(court))"))
                if cfg.format == .double && cfg.scoring == .serviceOver {
                    Text(g.serverNumber == 1 ? "Server 1" : "Server 2 · terakhir").italic()
                }
            }
        } else {
            Text("Menerima: ") + Text(who).fontWeight(.heavy).foregroundColor(.white)
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.display(13 * k, .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .frame(minHeight: 36 * k)
                .background(.white, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Service courts

    /// Box order as seen from the player facing the net:
    /// landscape left team faces right → its right court is at the bottom, etc.
    private var courtOrder: [Court] { first == landscape ? [.L, .R] : [.R, .L] }

    /// `size` is the column width (landscape) or row height (portrait).
    private func serviceBoxes(_ size: CGFloat) -> some View {
        let layout = landscape ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            ForEach(courtOrder, id: \.self) { c in box(c) }
        }
        .padding(6)
        .background(.white.opacity(0.16), in: .rect(cornerRadius: 22, style: .continuous))
        .frame(width: landscape ? size : nil, height: landscape ? nil : size)
        .padding(8)
        .accessibilityHidden(true)
    }

    /// Player index standing in court `c`, or nil for the empty singles box.
    private func occupant(_ c: Court) -> PlayerIndex? {
        if cfg.format == .single { return c == court ? 0 : nil }
        return g.playerInCourt(side, c)
    }

    private func box(_ c: Court) -> some View {
        let isActive = c == court
        let serve = isActive && serving
        let recv = isActive && !serving
        let p = occupant(c)
        let fg: Color = serve ? Theme.ink : recv ? color : .white
        let bg: Color = serve ? Theme.sun : recv ? .white : .white.opacity(0.1)

        return VStack(spacing: 4) {
            Text(c == .R ? "Kanan" : "Kiri")
                .font(.display(11 * k, .bold))
                .textCase(.uppercase)
                .opacity(0.75)
            if let p {
                ZStack(alignment: .bottomTrailing) {
                    Text(cfg.avatarText(side, p))
                        .font(.display(15 * k, .heavy))
                        .foregroundStyle(serve || recv ? .white : color)
                        .frame(width: 40 * k, height: 40 * k)
                        .background(serve || recv ? AnyShapeStyle(color) : AnyShapeStyle(.white), in: .circle)
                    if serve {
                        Shuttlecock(color: Theme.ink)
                            .padding(2)
                            .frame(width: 20 * k, height: 20 * k)
                            .background(.white, in: .circle)
                            .offset(x: 5, y: 3)
                    }
                }
                Text(cfg.shortName(side, p))
                    .font(.display(13 * k, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Circle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: 40 * k, height: 40 * k)
                    .opacity(0.4)
            }
            if isActive {
                Text(serve ? "Servis" : "Terima")
                    .font(.display(11 * k, .heavy))
                    .textCase(.uppercase)
            }
        }
        .foregroundStyle(fg)
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg, in: .rect(cornerRadius: 16, style: .continuous))
    }
}

/// "+1" / "Pindah servis" badge that floats up and fades.
private struct FloatText: View {
    let text: String
    @State private var go = false

    var body: some View {
        Text(text)
            .font(.display(28, .heavy))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(Theme.sun, in: .capsule)
            .offset(y: go ? -90 : -20)
            .opacity(go ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { go = true }
            }
    }
}
