import Foundation

extension MatchConfig {
    func teamName(_ s: Side) -> String {
        let n = teams[s].name.trimmed
        return n.isEmpty ? "Tim \(s.rawValue)" : n
    }

    private func typed(_ s: Side, _ i: Int) -> String {
        i < teams[s].players.count ? teams[s].players[i].trimmed : ""
    }

    func playerName(_ s: Side, _ i: Int) -> String {
        let t = typed(s, i)
        if !t.isEmpty { return t }
        return format == .single ? teamName(s) : "Pemain \(s.rawValue)\(i + 1)"
    }

    func playersLine(_ s: Side) -> String {
        format == .single ? playerName(s, 0) : "\(playerName(s, 0)) / \(playerName(s, 1))"
    }

    /// Headline for a side: players for doubles if no custom team name.
    func sideTitle(_ s: Side) -> String {
        let n = teams[s].name.trimmed
        return n.isEmpty ? playersLine(s) : n
    }

    var modeLabel: String {
        var parts = [
            format == .single ? "Single" : "Double",
            scoring == .rally ? "Rally point" : "Service-over",
            "\(target) poin",
        ]
        if bestOf == 3 { parts.append("Best of 3") }
        return parts.joined(separator: " · ")
    }

    /// Avatar text: initials of a typed name, otherwise the slot code (A1, B2, …).
    func avatarText(_ s: Side, _ i: Int) -> String {
        let t = typed(s, i)
        if !t.isEmpty { return initials(t) }
        return format == .single ? s.rawValue : "\(s.rawValue)\(i + 1)"
    }

    /// Compact name for tight spots (court tiles): first word of a typed name.
    func shortName(_ s: Side, _ i: Int) -> String {
        let t = typed(s, i)
        if t.isEmpty { return playerName(s, i) }
        let first = t.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? t
        return first.count >= 3 ? first : t
    }
}

/// Up to two initials for an avatar, e.g. "Budi Santoso" → "BS".
func initials(_ name: String) -> String {
    let s = name.split(whereSeparator: \.isWhitespace).prefix(2).compactMap { $0.first?.uppercased() }.joined()
    return s.isEmpty ? "?" : s
}

func formatDate(_ d: Date) -> String {
    d.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "id_ID")))
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let m = max(1, Int((seconds / 60).rounded()))
    return m < 60 ? "\(m) mnt" : "\(m / 60) j \(m % 60) mnt"
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
