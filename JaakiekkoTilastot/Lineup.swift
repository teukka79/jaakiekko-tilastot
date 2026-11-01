import SwiftUI

// MARK: - Liigan kokoonpanot (ketjut)

struct LineupPlayer: Identifiable {
    let id: Int
    let name: String
    let jersey: Int?
    let role: String      // KH, VL, OL, VP, OP, MV, "13. H", "7. P", H, P
    let line: Int?
    let captain: Bool
    let alt: Bool
    var first: String = ""
    var born: String? = nil
    var birthplace: String? = nil
    var height: Int? = nil
    var weight: Int? = nil
    var hand: String? = nil
    var goals: [GoalNote] = []
    var assists: [GoalNote] = []
    var team: String = ""
}

/// Yksi maali (tekijälle tai syöttäjälle) otteluajalla.
struct GoalNote: Identifiable {
    let id = UUID()
    let time: String
    let period: Int
    let score: String
}

struct LiigaLineup {
    var home: [LineupPlayer] = []
    var away: [LineupPlayer] = []
    var note: String? = nil
    /// Kokoonpano on julkaistu, kun jollakin pelaajalla on ketjunumero.
    var published: Bool { (home + away).contains { $0.line != nil } }
}

private struct LiigaLineupDTO: Decodable {
    struct P: Decodable {
        let id: Int?
        let firstName: String?
        let lastName: String?
        let roleCode: String?
        let line: Int?
        let jersey: Int?
        let captain: Bool?
        let alternateCaptain: Bool?
        let dateOfBirth: String?
        let placeOfBirth: String?
        let height: Int?
        let weight: Int?
        let handedness: String?
    }
    struct Goal: Decodable {
        let scorerPlayerId: Int?
        let assistantPlayerIds: [Int]?
        let gameTime: Int?
        let period: Int?
        let homeTeamScore: Int?
        let awayTeamScore: Int?
    }
    struct Team: Decodable { let goalEvents: [Goal]? }
    struct Game: Decodable { let homeTeam: Team?; let awayTeam: Team? }
    let game: Game?
    let homeTeamPlayers: [P]?
    let awayTeamPlayers: [P]?
}

func fetchLiigaLineup(gameID: String) async -> LiigaLineup? {
    guard let url = URL(string: "https://liiga.fi/api/v2/games/2027/\(gameID)") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 20
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let dto = try? JSONDecoder().decode(LiigaLineupDTO.self, from: data) else { return nil }
    let events = (dto.game?.homeTeam?.goalEvents ?? []) + (dto.game?.awayTeam?.goalEvents ?? [])
    func clock(_ t: Int) -> String { String(format: "%d:%02d", t / 60, t % 60) }
    func conv(_ l: [LiigaLineupDTO.P]?) -> [LineupPlayer] {
        (l ?? []).enumerated().map { i, p in
            var lp = LineupPlayer(id: p.id ?? i, name: p.lastName ?? "?", jersey: p.jersey, role: p.roleCode ?? "",
                         line: p.line, captain: p.captain == true, alt: p.alternateCaptain == true)
            lp.first = p.firstName ?? ""
            lp.born = p.dateOfBirth
            lp.birthplace = p.placeOfBirth
            lp.height = p.height
            lp.weight = p.weight
            lp.hand = p.handedness
            if let pid = p.id {
                for e in events {
                    let note = GoalNote(time: clock(e.gameTime ?? 0), period: e.period ?? 0,
                                        score: "\(e.homeTeamScore ?? 0)–\(e.awayTeamScore ?? 0)")
                    if e.scorerPlayerId == pid { lp.goals.append(note) }
                    if (e.assistantPlayerIds ?? []).contains(pid) { lp.assists.append(note) }
                }
            }
            return lp
        }
    }
    var res = LiigaLineup(home: conv(dto.homeTeamPlayers), away: conv(dto.awayTeamPlayers))
    for i in res.home.indices { res.home[i].team = "home" }
    for i in res.away.indices { res.away[i].team = "away" }
    return res
}

/// Kaukalonäkymä: vieras vasemmalla, koti oikealla, valitun ketjun hyökkääjät ja puolustajapari sekä maalivahti.
struct LineupView: View {
    let game: ScheduleGame
    /// NHL-ottelun tunnus: kokoonpano haetaan NHL:n rajapinnasta Liigan sijaan.
    var nhlGameId: Int? = nil
    @State private var loading = true
    @State private var failed = false
    @State private var lineup = LiigaLineup()
    @State private var line = 1
    @State private var selected: LineupPlayer? = nil

    var body: some View {
        VStack(spacing: 12) {
            GradientSegmented(selection: $line, items: (1...4).map { ($0, "Ketju \($0)", String?.none) })
                .frame(width: 360)

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                Text("Kokoonpanon haku epäonnistui.").foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !lineup.published {
                VStack(spacing: 8) {
                    Image(systemName: "person.3").font(.system(size: 28)).foregroundStyle(Theme.muted)
                    Text("Kokoonpanoa ei ole vielä julkaistu.").foregroundStyle(Theme.text)
                    Text("Joukkueet ilmoittavat kokoonpanonsa ennen ottelua. Näkymä päivittyy, kun avaat ikkunan uudelleen.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                rink
                HStack {
                    Label(game.away, systemImage: "circle.fill").foregroundStyle(Theme.indigo)
                    Spacer()
                    Label(game.home, systemImage: "circle.fill").foregroundStyle(Theme.cyan)
                }
                .font(.system(size: 12, weight: .semibold)).labelStyle(.titleAndIcon)
                if let n = lineup.note { Text(n).font(.system(size: 11)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading) }
                if let p = selected { playerCard(p) } else { extras }
                Spacer(minLength: 0)
            }
        }
        .task {
            if let gid = nhlGameId {
                if let l = await fetchNHLLineup(gameId: gid) { lineup = l } else { failed = true }
            } else {
                let id = game.id.replacingOccurrences(of: "liiga-", with: "")
                if let l = await fetchLiigaLineup(gameID: id) { lineup = l } else { failed = true }
            }
            loading = false
        }
    }

    private func slot(_ list: [LineupPlayer], _ role: String, line n: Int) -> LineupPlayer? {
        list.first { $0.role == role && $0.line == n }
    }

    private func goalie(_ list: [LineupPlayer]) -> LineupPlayer? {
        list.filter { $0.role == "MV" && $0.line != nil }.min { ($0.line ?? 9) < ($1.line ?? 9) }
    }

    private var rink: some View {
        let w: CGFloat = 620, h: CGFloat = 300
        let dLine = min(line, 3)
        func place(_ p: LineupPlayer?, _ x: CGFloat, _ y: CGFloat, _ color: Color) -> some View {
            marker(p, color).position(x: x, y: y)
        }
        return ZStack {
            rinkShape(w: w, h: h)
            // Vieras (vasemmalla): hyökkäys oikealle, vasen laita ylhäällä
            Group {
                place(goalie(lineup.away), 50, h / 2, Theme.indigo)
                place(slot(lineup.away, "VP", line: dLine), 160, 95, Theme.indigo)
                place(slot(lineup.away, "OP", line: dLine), 160, 205, Theme.indigo)
                place(slot(lineup.away, "VL", line: line), 265, 55, Theme.indigo)
                place(slot(lineup.away, "KH", line: line), 265, h / 2, Theme.indigo)
                place(slot(lineup.away, "OL", line: line), 265, 245, Theme.indigo)
            }
            // Koti (oikealla): peilattu
            Group {
                place(goalie(lineup.home), w - 50, h / 2, Theme.cyan)
                place(slot(lineup.home, "VP", line: dLine), w - 160, 205, Theme.cyan)
                place(slot(lineup.home, "OP", line: dLine), w - 160, 95, Theme.cyan)
                place(slot(lineup.home, "VL", line: line), w - 265, 245, Theme.cyan)
                place(slot(lineup.home, "KH", line: line), w - 265, h / 2, Theme.cyan)
                place(slot(lineup.home, "OL", line: line), w - 265, 55, Theme.cyan)
            }
        }
        .frame(width: w, height: h)
    }

    private func rinkShape(w: CGFloat, h: CGFloat) -> some View {
        let stroke = Color.white.opacity(0.16)
        return ZStack {
            RoundedRectangle(cornerRadius: 70, style: .continuous).fill(Color.white.opacity(0.03))
            RoundedRectangle(cornerRadius: 70, style: .continuous).strokeBorder(stroke, lineWidth: 2)
            Rectangle().fill(stroke).frame(width: 2, height: h)
            Rectangle().fill(stroke).frame(width: 2, height: h).offset(x: -w * 0.18)
            Rectangle().fill(stroke).frame(width: 2, height: h).offset(x: w * 0.18)
            Circle().strokeBorder(stroke, lineWidth: 2).frame(width: 70, height: 70)
            Circle().fill(stroke).frame(width: 8, height: 8)
            ForEach([-1.0, 1.0], id: \.self) { sx in
                ForEach([-1.0, 1.0], id: \.self) { sy in
                    Circle().strokeBorder(stroke, lineWidth: 2).frame(width: 60, height: 60)
                        .offset(x: sx * w * 0.30, y: sy * h * 0.30)
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func marker(_ p: LineupPlayer?, _ color: Color) -> some View {
        VStack(spacing: 2) {
            ZStack {
                if let g = glowColor(p) {
                    Image(systemName: "tshirt.fill").font(.system(size: 42)).foregroundStyle(g).blur(radius: 6)
                }
                Image(systemName: "tshirt.fill").font(.system(size: 38)).foregroundStyle(color.opacity(p == nil ? 0.25 : 0.9))
                if let g = glowColor(p) {
                    Image(systemName: "tshirt").font(.system(size: 38, weight: .bold)).foregroundStyle(g)
                }
                Text(p?.jersey.map(String.init) ?? "–")
                    .font(.system(size: 12, weight: .heavy).monospacedDigit()).foregroundStyle(Color.black.opacity(0.85)).offset(y: 3)
                if let p, p.captain || p.alt {
                    Text(p.captain ? "C" : "A").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                        .padding(3).background(Circle().fill(Theme.amber.opacity(0.95))).offset(x: 18, y: -14)
                }

            }
            Text(p.map { ($0.jersey.map { "\($0) " } ?? "") + $0.name } ?? "–").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
                .lineLimit(1).padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color.black.opacity(0.35), in: Capsule())
            pointChip(p).frame(height: 16)
        }
        .frame(width: 100)
        .contentShape(Rectangle())
        .onTapGesture { if let p { selected = (selected?.id == p.id) ? nil : p } }
    }

    private static let goalGlow = Color(red: 0.98, green: 0.75, blue: 0.14)
    private static let assistGlow = Color(red: 0.20, green: 0.83, blue: 0.60)

    /// Hehku paidan ympärille: kulta = maali, vihreä = pelkkä syöttö.
    private func glowColor(_ p: LineupPlayer?) -> Color? {
        guard let p else { return nil }
        if !p.goals.isEmpty { return Self.goalGlow }
        if !p.assists.isEmpty { return Self.assistGlow }
        return nil
    }

    /// Pistemerkki nimen alla: "maalit + syötöt".
    @ViewBuilder
    private func pointChip(_ p: LineupPlayer?) -> some View {
        if let p, !(p.goals.isEmpty && p.assists.isEmpty) {
            let fill: AnyShapeStyle = !p.goals.isEmpty && !p.assists.isEmpty
                ? AnyShapeStyle(LinearGradient(stops: [.init(color: Self.goalGlow, location: 0.5), .init(color: Self.assistGlow, location: 0.5)],
                                               startPoint: .leading, endPoint: .trailing))
                : AnyShapeStyle(p.goals.isEmpty ? Self.assistGlow : Self.goalGlow)
            Text("\(p.goals.count) + \(p.assists.count)")
                .font(.system(size: 11, weight: .heavy).monospacedDigit()).foregroundStyle(Color.black)
                .padding(.horizontal, 9).padding(.vertical, 1)
                .background(Capsule().fill(fill))
        } else {
            Color.clear
        }
    }

    private func periodName(_ p: Int) -> String {
        p >= 1 && p <= 3 ? "\(p). erä" : p == 4 ? "Jatkoaika" : p > 4 ? "Rankkarit" : ""
    }

    private func playerCard(_ p: LineupPlayer) -> some View {
        let teamName = p.team == "home" ? game.home : game.away
        var facts: [String] = []
        if let h = p.height, h > 0 { facts.append("\(h) cm") }
        if let w = p.weight, w > 0 { facts.append("\(w) kg") }
        if let hd = p.hand { facts.append(hd == "LEFT" ? "Vasenkätinen" : hd == "RIGHT" ? "Oikeakätinen" : hd) }
        var born = ""
        if let b = p.born, b.count >= 10 {
            let parts = b.prefix(10).split(separator: "-")
            if parts.count == 3 { born = "\(Int(parts[2]) ?? 0).\(Int(parts[1]) ?? 0).\(parts[0])" }
        }
        if let pl = p.birthplace, !pl.isEmpty { born += born.isEmpty ? pl : ", \(pl)" }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(p.jersey.map { "\($0) " } ?? "")\(p.first) \(p.name)")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                Text(teamName).font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Button("Sulje") { selected = nil }.buttonStyle(GhostButtonStyle())
            }
            if !facts.isEmpty { Text(facts.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(Theme.muted) }
            if !born.isEmpty { Text("Syntynyt \(born)").font(.system(size: 12)).foregroundStyle(Theme.muted) }
            if p.goals.isEmpty && p.assists.isEmpty {
                Text("Ei maaleja tai syöttöjä tässä ottelussa.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            ForEach(p.goals) { g in
                Text("Maali \(g.time) (\(periodName(g.period)), \(g.score))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
            }
            ForEach(p.assists) { g in
                Text("Syöttö \(g.time) (\(periodName(g.period)), \(g.score))").font(.system(size: 12)).foregroundStyle(Theme.green)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var extras: some View {
        func names(_ list: [LineupPlayer]) -> String {
            let ex = list.filter { ($0.role.hasSuffix(". H") || $0.role.hasSuffix(". P")) && $0.line != nil }
            let bk = list.filter { $0.role == "MV" && ($0.line ?? 0) >= 2 }
            return (bk.map { "MV \($0.name)" } + ex.map { "\($0.name)" }).joined(separator: ", ")
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Varamaalivahti ja lisäpelaajat").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted)
            Text("\(game.away): \(names(lineup.away).isEmpty ? "–" : names(lineup.away))").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text("\(game.home): \(names(lineup.home).isEmpty ? "–" : names(lineup.home))").font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
