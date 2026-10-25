import SwiftUI

/// Mitä lukua viimeisten pelien ruudut näyttävät (seuraa taulukon lajittelua).
enum StripMode {
    case points, goals, assists, pp, shots

    init(sort: SortKey) {
        switch sort {
        case .goals: self = .goals
        case .assists: self = .assists
        case .pp: self = .pp
        case .shots: self = .shots
        default: self = .points
        }
    }

    var label: String {
        switch self {
        case .points: return "pisteet"
        case .goals: return "maalit"
        case .assists: return "syötöt"
        case .pp: return "ylivoima"
        case .shots: return "laukaukset"
        }
    }

    func value(_ g: RecentGame) -> Int? {
        switch self {
        case .points: return g.goals + g.assists
        case .goals: return g.goals
        case .assists: return g.assists
        case .pp: return g.pp
        case .shots: return g.shots
        }
    }

    var thresholds: [Int] { self == .shots ? [1, 3, 5] : [1, 2, 3] }
}

/// Pelaajan viimeiset (enintään 5) pelit pieninä ruutuina, uusin vasemmalla.
struct RecentStrip: View {
    @Environment(AppStore.self) private var store
    let player: Player
    let mode: StripMode
    @State private var games: [RecentGame]?
    @State private var loaded = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        HStack(spacing: 2) {
            if !loaded {
                Text("…").font(.system(size: 11)).foregroundStyle(Theme.muted)
            } else if let g = games, !g.isEmpty {
                ForEach(Array(g.prefix(5).enumerated()), id: \.offset) { _, game in
                    box(game)
                }
            } else {
                Text("–").foregroundStyle(Theme.muted)
            }
        }
        .task(id: player.id) {
            let r = await store.recentGames(for: player)
            games = r.games
            loaded = true
        }
    }

    /// YYYY-MM-DD -> pp.kk.vvvv
    private static func display(_ iso: String) -> String {
        let p = iso.split(separator: "-")
        return p.count == 3 ? "\(p[2]).\(p[1]).\(p[0])" : iso
    }

    private func box(_ g: RecentGame) -> some View {
        let v = mode.value(g)
        let t = mode.thresholds
        let (bg, fg): (Color, Color) = {
            guard let v else { return (Color.white.opacity(0.06), Theme.muted) }
            if v >= t[2] { return (Color.orange.opacity(0.38), Color(red: 0.99, green: 0.83, blue: 0.30)) }
            if v >= t[1] { return (Theme.green.opacity(0.28), Color(red: 0.53, green: 0.94, blue: 0.67)) }
            if v >= t[0] { return (Theme.cyan.opacity(0.18), Color(red: 0.40, green: 0.91, blue: 0.98)) }
            return (Color.white.opacity(0.06), Theme.muted)
        }()
        var tip = "\(Self.display(g.date)) \(g.home == true ? "vs" : g.home == false ? "@" : "–") \(g.opponent) · M \(g.goals), S \(g.assists)"
        if let pp = g.pp { tip += ", YV \(pp)" }
        if let s = g.shots { tip += ", L \(s)" }
        return Text(v.map(String.init) ?? "–")
            .font(.system(size: 12, weight: .bold).monospacedDigit())
            .foregroundStyle(fg)
            .frame(width: 24, height: 22)
            .background(RoundedRectangle(cornerRadius: 5).fill(bg))
            .help(tip)
    }
}
