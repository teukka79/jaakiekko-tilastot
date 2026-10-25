import SwiftUI

/// Yhden joukkueen päättynyt ottelu joukkueen näkökulmasta.
struct TeamResultGame: Identifiable {
    let id: String
    let date: Date
    let opponent: String
    let home: Bool
    let gf: Int
    let ga: Int
    var extra: String? = nil   // "JA" tai "RL"
    var game: ScheduleGame? = nil   // ottelun tiedot, jos saatavilla
    var win: Bool { gf > ga }
}

struct TeamResultsData {
    var games: [TeamResultGame] = []
    var note: String? = nil
}

struct NHLClubSeason: Decodable {
    struct Ref: Decodable { let abbrev: String?; let score: Int? }
    struct Outcome: Decodable { let lastPeriodType: String? }
    struct Game: Decodable {
        let id: Int?
        let startTimeUTC: String?
        let gameState: String?
        let homeTeam: Ref?
        let awayTeam: Ref?
        let gameOutcome: Outcome?
    }
    let games: [Game]?
}

func resultsISODate(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: s) { return d }
    let f2 = ISO8601DateFormatter()
    f2.formatOptions = [.withInternetDateTime]
    return f2.date(from: s)
}

private func lastFive(_ games: [TeamResultGame]) -> [TeamResultGame] {
    Array(games.sorted { $0.date > $1.date }.prefix(5))
}

/// Hakee joukkueen 5 viimeisintä päättynyttä ottelua. Palauttaa nil, jos haku epäonnistuu.
@MainActor
func fetchTeamResults(team: Team, allTeams: [Team]) async -> TeamResultsData? {
    switch team.league {
    case .nhl:
        let byAbbr = Dictionary(uniqueKeysWithValues: allTeams.filter { $0.league == .nhl }.map { ($0.abbr, $0.name) })
        guard let url = URL(string: "https://api-web.nhle.com/v1/club-schedule-season/\(team.abbr)/now") else { return nil }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 20
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let r = try? JSONDecoder().decode(NHLClubSeason.self, from: data) else { return nil }
        var out: [TeamResultGame] = []
        for g in r.games ?? [] {
            let state = (g.gameState ?? "").uppercased()
            guard state == "FINAL" || state == "OFF",
                  let d = resultsISODate(g.startTimeUTC),
                  let hs = g.homeTeam?.score, let aw = g.awayTeam?.score else { continue }
            let isHome = g.homeTeam?.abbrev == team.abbr
            let oppAbbr = (isHome ? g.awayTeam?.abbrev : g.homeTeam?.abbrev) ?? "?"
            let lp = (g.gameOutcome?.lastPeriodType ?? "").uppercased()
            out.append(TeamResultGame(id: "nhl-\(g.id ?? out.count)", date: d, opponent: byAbbr[oppAbbr] ?? oppAbbr,
                                      home: isHome, gf: isHome ? hs : aw, ga: isHome ? aw : hs,
                                      extra: lp == "SO" ? "RL" : (lp == "OT" ? "JA" : nil),
                                      game: ScheduleGame(id: "nhl-\(g.id ?? out.count)", date: d,
                                                         home: isHome ? team.name : (byAbbr[oppAbbr] ?? oppAbbr),
                                                         away: isHome ? (byAbbr[oppAbbr] ?? oppAbbr) : team.name,
                                                         gameId: g.id, final: true,
                                                         homeScore: isHome ? hs : aw, awayScore: isHome ? aw : hs)))
        }
        return TeamResultsData(games: lastFive(out))

    case .ahl:
        let byCode = Dictionary(uniqueKeysWithValues: allTeams.filter { $0.league == .ahl }.map { ($0.abbr, $0.name) })
        let season = await fetchAHLSeasonId()
        guard let rows = await ahlFetch("view=schedule&season_id=\(season)") else { return nil }
        var out: [TeamResultGame] = []
        for r in rows where r["final"] == "1" {
            guard let hc = r["home_team_code"], let vc = r["visiting_team_code"],
                  hc == team.abbr || vc == team.abbr,
                  let d = resultsISODate(r["GameDateISO8601"]),
                  let hs = Int(r["home_goal_count"] ?? ""), let aw = Int(r["visiting_goal_count"] ?? "") else { continue }
            let isHome = hc == team.abbr
            let oppCode = isHome ? vc : hc
            var extra: String? = nil
            if r["shootout"] == "1" { extra = "RL" } else if r["overtime"] == "1" { extra = "JA" }
            out.append(TeamResultGame(id: "ahl-\(r["game_id"] ?? "\(out.count)")", date: d, opponent: byCode[oppCode] ?? oppCode,
                                      home: isHome, gf: isHome ? hs : aw, ga: isHome ? aw : hs, extra: extra))
        }
        return TeamResultsData(games: lastFive(out))

    case .liiga:
        guard let games = await fetchLiigaGames() else { return nil }
        let liigaTeams = allTeams.filter { $0.league == .liiga }
        let seedByKey = Dictionary(uniqueKeysWithValues: liigaTeams.map { (AppStore.liigaKey($0.name), $0.name) })
        var out: [TeamResultGame] = []
        for (i, g) in games.enumerated() where g.ended?.value == true {
            guard let d = resultsISODate(g.start), let ht = g.homeTeam, let at = g.awayTeam,
                  let h = ht.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }),
                  let a = at.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }),
                  h == team.name || a == team.name else { continue }
            let hs = ht.goals ?? (ht.goalEvents ?? []).count
            let aw = at.goals ?? (at.goalEvents ?? []).count
            let isHome = h == team.name
            let ft = (g.finishedType ?? "").lowercased()
            var extra: String? = nil
            if ft.contains("shootout") { extra = "RL" } else if ft.contains("extended") || ft.contains("overtime") { extra = "JA" }
            out.append(TeamResultGame(id: "liiga-\(g.id?.value ?? i)", date: d, opponent: isHome ? a : h,
                                      home: isHome, gf: isHome ? hs : aw, ga: isHome ? aw : hs, extra: extra,
                                      game: {
                                          var sg = ScheduleGame(id: "liiga-\(g.id?.value ?? i)", date: d, home: h, away: a)
                                          sg.final = true; sg.homeScore = hs; sg.awayScore = aw
                                          sg.liiga = makeLiigaDetail(g)
                                          return sg
                                      }()))
        }
        return TeamResultsData(games: lastFive(out))

    case .mestis:
        guard let games = await fetchMestisSchedule(teams: allTeams) else { return nil }
        let out: [TeamResultGame] = games.compactMap { g in
            guard g.final, let hs = g.homeScore, let aw = g.awayScore,
                  g.home == team.name || g.away == team.name else { return nil }
            let isHome = g.home == team.name
            return TeamResultGame(id: g.id, date: g.date, opponent: isHome ? g.away : g.home,
                                  home: isHome, gf: isHome ? hs : aw, ga: isHome ? aw : hs)
        }
        return TeamResultsData(games: lastFive(out), note: "Jatkoaika- ja rankkaritietoa ei ole saatavilla tälle sarjalle.")

    default:
        return TeamResultsData(games: [], note: "Ottelutuloksia ei ole saatavilla tälle sarjalle.")
    }
}

struct TeamResultsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let teamName: String

    @State private var data: TeamResultsData?
    @State private var loading = true
    @State private var failed = false
    @State private var selected: ScheduleGame?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "d.M."
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                TeamLogoView(team: teamName, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(teamName).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.text)
                    Text("5 viimeisintä ottelua").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed || data == nil {
                Text("Tulosten haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.")
                    .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = data {
                if d.games.isEmpty {
                    Text(d.note ?? "Päättyneitä otteluita ei löytynyt.")
                        .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    summary(d.games)
                    VStack(spacing: 0) {
                        ForEach(Array(d.games.enumerated()), id: \.element.id) { idx, g in
                            if let sg = g.game {
                                Button { selected = sg } label: { row(g, odd: idx % 2 == 1) }.buttonStyle(.plain)
                            } else {
                                row(g, odd: idx % 2 == 1)
                            }
                        }
                    }
                    .glassCard(radius: 12)
                    if let n = d.note {
                        Text(n).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    Text("Klikkaa ottelua nähdäksesi sen tiedot. Tulos näytetään joukkueen näkökulmasta (oma maalimäärä ensin). JA = jatkoaika, RL = rankkarit.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 470)
        .task { await load() }
        .sheet(item: $selected) { GameDetailView(game: $0) }
    }

    private func summary(_ games: [TeamResultGame]) -> some View {
        let wins = games.filter { $0.win }.count
        let gf = games.reduce(0) { $0 + $1.gf }
        let ga = games.reduce(0) { $0 + $1.ga }
        return HStack(spacing: 10) {
            SectionLabel("Muoto")
            ForEach(games) { g in
                Text(g.win ? "V" : "H")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(g.win ? Theme.green : Theme.red)
            }
            Spacer()
            Text("\(wins) V – \(games.count - wins) H").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.text)
            Text("maalit \(gf)–\(ga)").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
        }
    }

    private func row(_ g: TeamResultGame, odd: Bool) -> some View {
        HStack(spacing: 10) {
            Text(TeamResultsView.dateFormatter.string(from: g.date))
                .font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.muted).frame(width: 52, alignment: .leading).lineLimit(1)
            Text(g.home ? "Koti" : "Vieras")
                .font(.system(size: 12)).foregroundStyle(Theme.muted).frame(width: 50, alignment: .leading)
            TeamLogoView(team: g.opponent, size: 24)
            Text(g.opponent).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer()
            Text("\(g.gf) – \(g.ga)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Theme.text)
            Text(g.extra ?? "").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted).frame(width: 18, alignment: .leading)
            Text(g.win ? "V" : "H").font(.system(size: 13, weight: .bold))
                .foregroundStyle(g.win ? Theme.green : Theme.red).frame(width: 16)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(odd ? Color.white.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
    }

    private func load() async {
        guard let team = store.teamByName[teamName] else { failed = true; loading = false; return }
        let r = await fetchTeamResults(team: team, allTeams: Array(store.teamByName.values))
        data = r
        failed = (r == nil)
        loading = false
    }
}
