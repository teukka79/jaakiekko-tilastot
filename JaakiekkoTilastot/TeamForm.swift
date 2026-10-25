import SwiftUI

// MARK: Koko sarjan ottelut

struct LeagueGame {
    let date: Date
    let home: String
    let away: String
    let final: Bool
    let hs: Int
    let aw: Int
    var extra: String? = nil   // "JA" tai "RL"
}

@MainActor
func fetchLeagueGames(league: League, teams: [Team]) async -> [LeagueGame]? {
    switch league {
    case .nhl:
        let nhl = teams.filter { $0.league == .nhl }
        let byAbbr = Dictionary(uniqueKeysWithValues: nhl.map { ($0.abbr, $0.name) })
        let lists: [NHLClubSeason?] = await withTaskGroup(of: NHLClubSeason?.self) { group in
            for t in nhl {
                group.addTask {
                    guard let url = URL(string: "https://api-web.nhle.com/v1/club-schedule-season/\(t.abbr)/now") else { return nil }
                    var req = URLRequest(url: url)
                    req.cachePolicy = .reloadIgnoringLocalCacheData
                    req.timeoutInterval = 20
                    guard let (data, resp) = try? await URLSession.shared.data(for: req),
                          (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
                    return try? JSONDecoder().decode(NHLClubSeason.self, from: data)
                }
            }
            var res: [NHLClubSeason?] = []
            for await r in group { res.append(r) }
            return res
        }
        guard lists.contains(where: { $0 != nil }) else { return nil }
        var seen = Set<Int>()
        var out: [LeagueGame] = []
        for l in lists {
            for g in l?.games ?? [] {
                if let id = g.id { if seen.contains(id) { continue }; seen.insert(id) }
                guard let d = resultsISODate(g.startTimeUTC),
                      let h = g.homeTeam?.abbrev.flatMap({ byAbbr[$0] }),
                      let a = g.awayTeam?.abbrev.flatMap({ byAbbr[$0] }) else { continue }
                let state = (g.gameState ?? "").uppercased()
                if (state == "FINAL" || state == "OFF"), let hs = g.homeTeam?.score, let aw = g.awayTeam?.score {
                    let lp = (g.gameOutcome?.lastPeriodType ?? "").uppercased()
                    out.append(LeagueGame(date: d, home: h, away: a, final: true, hs: hs, aw: aw,
                                          extra: lp == "SO" ? "RL" : (lp == "OT" ? "JA" : nil)))
                } else {
                    out.append(LeagueGame(date: d, home: h, away: a, final: false, hs: 0, aw: 0))
                }
            }
        }
        return out

    case .ahl:
        let byCode = Dictionary(uniqueKeysWithValues: teams.filter { $0.league == .ahl }.map { ($0.abbr, $0.name) })
        let season = await fetchAHLSeasonId()
        guard let rows = await ahlFetch("view=schedule&season_id=\(season)") else { return nil }
        var out: [LeagueGame] = []
        for r in rows {
            guard let h = r["home_team_code"].flatMap({ byCode[$0] }),
                  let a = r["visiting_team_code"].flatMap({ byCode[$0] }),
                  let d = resultsISODate(r["GameDateISO8601"]) else { continue }
            if r["final"] == "1", let hs = Int(r["home_goal_count"] ?? ""), let aw = Int(r["visiting_goal_count"] ?? "") {
                var extra: String? = nil
                if r["shootout"] == "1" { extra = "RL" } else if r["overtime"] == "1" { extra = "JA" }
                out.append(LeagueGame(date: d, home: h, away: a, final: true, hs: hs, aw: aw, extra: extra))
            } else {
                out.append(LeagueGame(date: d, home: h, away: a, final: false, hs: 0, aw: 0))
            }
        }
        return out

    case .liiga:
        guard let games = await fetchLiigaGames() else { return nil }
        let seedByKey = Dictionary(uniqueKeysWithValues: teams.filter { $0.league == .liiga }.map { (AppStore.liigaKey($0.name), $0.name) })
        var out: [LeagueGame] = []
        for g in games {
            guard let d = resultsISODate(g.start), let ht = g.homeTeam, let at = g.awayTeam,
                  let h = ht.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }),
                  let a = at.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }) else { continue }
            if g.ended?.value == true {
                let ft = (g.finishedType ?? "").lowercased()
                var extra: String? = nil
                if ft.contains("shootout") { extra = "RL" } else if ft.contains("extended") || ft.contains("overtime") { extra = "JA" }
                out.append(LeagueGame(date: d, home: h, away: a, final: true,
                                      hs: ht.goals ?? (ht.goalEvents ?? []).count,
                                      aw: at.goals ?? (at.goalEvents ?? []).count, extra: extra))
            } else {
                out.append(LeagueGame(date: d, home: h, away: a, final: false, hs: 0, aw: 0))
            }
        }
        return out

    case .mestis:
        guard let games = await fetchMestisSchedule(teams: teams) else { return nil }
        return games.map { g in
            if g.final, let hs = g.homeScore, let aw = g.awayScore {
                return LeagueGame(date: g.date, home: g.home, away: g.away, final: true, hs: hs, aw: aw)
            }
            return LeagueGame(date: g.date, home: g.home, away: g.away, final: false, hs: 0, aw: 0)
        }

    default:
        return nil
    }
}

// MARK: Laskenta

struct FormResult: Identifiable {
    let id = UUID()
    let game: LeagueGame
    let home: Bool
    let gf: Int
    let ga: Int
    let opp: String
    var win: Bool { gf > ga }
    var total: Int { gf + ga }
}

struct TeamFormStats: Identifiable {
    var id: String { team }
    let team: String
    var gp = 0, w = 0, otw = 0, otl = 0, l = 0, gf = 0, ga = 0, pts = 0
    var allGp = 0, allGf = 0, allGa = 0, over = 0, under = 0, totalGoals = 0
    var recent: [FormResult] = []   // vanhimmasta uusimpaan (kunto-ikkuna)
    var last5: [FormResult] = []
    var next: LeagueGame? = nil
    var avgGoals: Double { allGp > 0 ? Double(totalGoals) / Double(allGp) : 0 }
}

enum FormSide: String, CaseIterable { case all = "Yhteensä", home = "Kotona", away = "Vieraissa" }

func computeTeamForm(games: [LeagueGame], teamNames: [String], league: League, side: FormSide, window: Int, line: Double) -> [TeamFormStats] {
    let twoWay = league == .nhl || league == .ahl
    return teamNames.map { name in
        let mine = games.filter { g in
            switch side {
            case .all: return g.home == name || g.away == name
            case .home: return g.home == name
            case .away: return g.away == name
            }
        }.sorted { $0.date < $1.date }
        let all: [FormResult] = mine.filter { $0.final }.map { g in
            let home = g.home == name
            return FormResult(game: g, home: home, gf: home ? g.hs : g.aw, ga: home ? g.aw : g.hs, opp: home ? g.away : g.home)
        }
        var s = TeamFormStats(team: name)
        let win = Array(all.suffix(window))
        for x in win {
            s.gf += x.gf; s.ga += x.ga
            let ex = x.game.extra != nil
            if x.win {
                if ex { s.otw += 1 } else { s.w += 1 }
                s.pts += twoWay ? 2 : (ex ? 2 : 3)
            } else if ex { s.otl += 1; s.pts += 1 } else { s.l += 1 }
        }
        s.gp = win.count
        for x in all {
            s.totalGoals += x.total
            if Double(x.total) > line { s.over += 1 } else { s.under += 1 }
            s.allGf += x.gf; s.allGa += x.ga
        }
        s.allGp = all.count
        s.recent = win
        s.last5 = Array(all.suffix(5))
        s.next = mine.first { !$0.final }
        return s
    }
}

// MARK: Näkymä

private let formDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "fi_FI")
    f.dateFormat = "d.M."
    return f
}()

private let formFullDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "fi_FI")
    f.dateFormat = "d.M.yyyy"
    return f
}()

struct FormBadge: View {
    enum Kind { case win, loss, unknown }
    let text: String
    let kind: Kind
    var overtime = false
    let tip: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
            .overlay(alignment: .bottomTrailing) {
                if overtime {
                    Path { p in
                        p.move(to: CGPoint(x: 7, y: 0)); p.addLine(to: CGPoint(x: 7, y: 7)); p.addLine(to: CGPoint(x: 0, y: 7)); p.closeSubpath()
                    }
                    .fill(Color(red: 0.96, green: 0.62, blue: 0.04))
                    .frame(width: 7, height: 7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .help(tip)
    }

    private var color: Color {
        switch kind {
        case .win: return Color(red: 0.09, green: 0.64, blue: 0.29)
        case .loss: return Color(red: 0.86, green: 0.15, blue: 0.15)
        case .unknown: return Color(red: 0.32, green: 0.32, blue: 0.36)
        }
    }
}

struct TeamFormTables: View {
    let league: League
    let teamNames: [String]
    let groups: [String: String]
    let byDivision: Bool
    let games: [LeagueGame]
    let isForm: Bool
    let side: FormSide
    let window: Int
    let line: Double

    var body: some View {
        let stats = computeTeamForm(games: games, teamNames: teamNames, league: league, side: side, window: window, line: line)
        VStack(spacing: 14) {
            ForEach(sections(stats), id: \.title) { sec in
                VStack(alignment: .leading, spacing: 0) {
                    if !sec.title.isEmpty {
                        SectionLabel(divisionTitle(sec.title)).padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                    }
                    header
                    ForEach(Array(sorted(sec.rows).enumerated()), id: \.element.id) { idx, s in
                        row(idx, s)
                    }
                }
                .padding(.bottom, 6)
                .glassCard(radius: 12)
            }
        }
    }

    private struct FormSection { let title: String; let rows: [TeamFormStats] }

    private func sections(_ stats: [TeamFormStats]) -> [FormSection] {
        if (league == .nhl || league == .ahl) && byDivision && !groups.isEmpty {
            let keys = Array(Set(stats.map { groups[$0.team] ?? "" })).sorted()
            return keys.map { k in FormSection(title: k, rows: stats.filter { (groups[$0.team] ?? "") == k }) }
        }
        return [FormSection(title: "", rows: stats)]
    }

    private func divisionTitle(_ key: String) -> String {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        return parts.count == 2 ? "\(parts[1]) (\(parts[0]))" : key
    }

    private func sorted(_ rows: [TeamFormStats]) -> [TeamFormStats] {
        if isForm {
            return rows.sorted { a, b in
                if a.pts != b.pts { return a.pts > b.pts }
                if (a.gf - a.ga) != (b.gf - b.ga) { return (a.gf - a.ga) > (b.gf - b.ga) }
                return a.gf > b.gf
            }
        }
        return rows.sorted { a, b in
            if a.over != b.over { return a.over > b.over }
            return a.avgGoals > b.avgGoals
        }
    }

    private func nextTip(_ s: TeamFormStats) -> String {
        guard let n = s.next else { return "Ei tulevia otteluita" }
        return "Seuraava ottelu:\n\(n.home) · \(n.away)\n\(formFullDateFormatter.string(from: n.date))"
    }

    private func resTip(_ x: FormResult) -> String {
        "\(x.home ? "Koti" : "Vieras") · \(x.opp) \(x.gf)–\(x.ga)\(x.game.extra.map { " " + $0 } ?? "") · \(formDateFormatter.string(from: x.game.date))"
    }

    private func cell(_ t: String, _ w: CGFloat, bold: Bool = false, color: Color = Theme.text) -> some View {
        Text(t).font(.system(size: 12, weight: bold ? .bold : .regular).monospacedDigit())
            .foregroundStyle(color).frame(width: w, alignment: .trailing)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("#").frame(width: 24, alignment: .trailing)
            Text("Joukkue").padding(.leading, 38)
            Spacer(minLength: 0)
            if isForm {
                Text("OTT").frame(width: 34, alignment: .trailing)
                Text("V").frame(width: 28, alignment: .trailing)
                Text("JA-V").frame(width: 36, alignment: .trailing)
                Text("JA-H").frame(width: 36, alignment: .trailing)
                Text("H").frame(width: 28, alignment: .trailing)
                Text("M").frame(width: 52, alignment: .trailing)
                Text("PIS").frame(width: 34, alignment: .trailing)
                Text("KUNTO").frame(width: CGFloat(window + 1) * 25, alignment: .center)
            } else {
                Text("OTT").frame(width: 34, alignment: .trailing)
                Text("O").frame(width: 28, alignment: .trailing)
                Text("U").frame(width: 28, alignment: .trailing)
                Text("M").frame(width: 56, alignment: .trailing)
                Text("M/O").frame(width: 38, alignment: .trailing)
                Text("VIIMEISET 5").frame(width: 6 * 25, alignment: .center)
            }
        }
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private func row(_ idx: Int, _ s: TeamFormStats) -> some View {
        HStack(spacing: 6) {
            Text("\(idx + 1)").frame(width: 24, alignment: .trailing).foregroundStyle(Theme.muted)
            TeamLogoView(team: s.team, size: 26).frame(width: 30, height: 26)
            Text(s.team).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer(minLength: 0)
            if isForm {
                cell("\(s.gp)", 34); cell("\(s.w)", 28); cell("\(s.otw)", 36); cell("\(s.otl)", 36); cell("\(s.l)", 28)
                cell("\(s.gf):\(s.ga)", 52, color: Theme.muted)
                cell("\(s.pts)", 34, bold: true, color: Theme.cyan)
                HStack(spacing: 3) {
                    FormBadge(text: "?", kind: .unknown, tip: nextTip(s))
                    ForEach(s.recent) { x in
                        FormBadge(text: x.win ? "V" : "H", kind: x.win ? .win : .loss, overtime: x.game.extra != nil, tip: resTip(x))
                    }
                }
                .frame(width: CGFloat(window + 1) * 25, alignment: .leading)
            } else {
                cell("\(s.allGp)", 34); cell("\(s.over)", 28); cell("\(s.under)", 28)
                cell("\(s.allGf):\(s.allGa)", 56, color: Theme.muted)
                cell(s.allGp > 0 ? String(format: "%.1f", s.avgGoals) : "–", 38, bold: true, color: Theme.cyan)
                HStack(spacing: 3) {
                    FormBadge(text: "?", kind: .unknown, tip: nextTip(s))
                    ForEach(s.last5) { x in
                        let over = Double(x.total) > line
                        FormBadge(text: over ? "+" : "−", kind: over ? .win : .loss, tip: resTip(x) + " · maaleja \(x.total)")
                    }
                }
                .frame(width: 6 * 25, alignment: .leading)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .background(idx % 2 == 1 ? Color.white.opacity(0.025) : .clear)
    }
}
