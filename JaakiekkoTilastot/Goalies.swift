import Foundation

/// Maalivahdin kausitilasto (NHL, AHL, Liiga; SHL/HockeyAllsvenskan myöhemmin).
struct Goalie: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var team: String
    var league: League
    var flag: String
    var nat: String? = nil
    var number: Int? = nil
    var games: Int = 0
    var wins: Int? = nil
    var shotsAgainst: Int? = nil
    var saves: Int? = nil
    var goalsAgainst: Int? = nil
    var shutouts: Int? = nil
    /// Päästetyt maalit ottelua kohti (suoraan rajapinnasta, jos tarjolla).
    var gaaValue: Double? = nil

    /// Torjuntaprosentti 0–100.
    var savePct: Double? {
        guard let sv = saves, let sa = shotsAgainst, sa > 0 else { return nil }
        return Double(sv) / Double(sa) * 100
    }
    var gaa: Double? {
        if let g = gaaValue { return g }
        guard let ga = goalsAgainst, games > 0 else { return nil }
        return Double(ga) / Double(games)
    }
    var natLabel: String { Countries.label(for: nat) }
}

enum GoalieSort: String {
    case name, number, nat, team, games, wins, savePct, gaa, shutouts, saves, shots, rating
}

// MARK: - Haku

private struct NHLGoalieResponse: Decodable {
    struct Row: Decodable {
        let playerId: Int?
        let goalieFullName: String?
        let teamAbbrevs: String?
        let gamesPlayed: Int?
        let wins: Int?
        let shotsAgainst: Int?
        let saves: Int?
        let goalsAgainst: Int?
        let shutouts: Int?
        let goalsAgainstAverage: Double?
    }
    let data: [Row]?
}

func fetchNHLGoalies(teamByAbbr: [String: Team]) async -> [Goalie]? {
    guard let url = URL(string: "https://api.nhle.com/stats/rest/en/goalie/summary?limit=-1&cayenneExp=seasonId=20262027%20and%20gameTypeId=2") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 20
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let r = try? JSONDecoder().decode(NHLGoalieResponse.self, from: data) else { return nil }
    var out: [Goalie] = []
    for row in r.data ?? [] {
        guard let id = row.playerId, let name = row.goalieFullName,
              let abbr = row.teamAbbrevs?.split(separator: ",").last.map({ String($0).trimmingCharacters(in: .whitespaces) }),
              let team = teamByAbbr[abbr] else { continue }
        out.append(Goalie(id: "g-nhl-\(id)", name: name, team: team.name, league: .nhl, flag: team.flag,
                          games: row.gamesPlayed ?? 0, wins: row.wins, shotsAgainst: row.shotsAgainst, saves: row.saves,
                          goalsAgainst: row.goalsAgainst, shutouts: row.shutouts, gaaValue: row.goalsAgainstAverage))
    }
    return out
}

private func goalieKey(_ s: String) -> String {
    let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    let n = String(folded.map { $0.isLetter ? $0 : " " }).split(separator: " ").joined(separator: " ")
    return n == "k espoo" ? "kiekko espoo" : n
}

private struct LiigaGoalie: Decodable {
    let playerId: Int?
    let teamName: String?
    let role: String?
    let firstName: String?
    let lastName: String?
    let nationality: String?
    let jersey: Int?
    let goalkeeper: Bool?
    let playedGames: Int?
    let gkWins: Int?
    let goalsAgainst: Int?
    let blockedOrSavedShots: Int?
    let shutOut: Int?
    let goalsAgainstAvg: Double?
}

func fetchLiigaGoalies(teams: [Team]) async -> [Goalie]? {
    guard let url = URL(string: "https://liiga.fi/api/v2/players/stats/summed/2027/2027/runkosarja/true") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 30
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let list = try? JSONDecoder().decode([LiigaGoalie].self, from: data) else { return nil }
    let byKey = Dictionary(teams.filter { $0.league == .liiga }.map { (goalieKey($0.name), $0) }, uniquingKeysWith: { a, _ in a })
    var out: [Goalie] = []
    for g in list where g.goalkeeper == true || g.role == "MV" {
        guard let id = g.playerId, let tn = g.teamName, let team = byKey[goalieKey(tn)],
              (g.playedGames ?? 0) > 0 else { continue }
        let sv = g.blockedOrSavedShots
        let ga = g.goalsAgainst
        out.append(Goalie(id: "g-liiga-\(id)", name: "\(g.firstName ?? "") \(g.lastName ?? "")".trimmingCharacters(in: .whitespaces),
                          team: team.name, league: .liiga, flag: team.flag, nat: g.nationality, number: g.jersey,
                          games: g.playedGames ?? 0, wins: g.gkWins,
                          shotsAgainst: (sv != nil && ga != nil) ? sv! + ga! : nil, saves: sv, goalsAgainst: ga,
                          shutouts: g.shutOut, gaaValue: g.goalsAgainstAvg))
    }
    return out
}

func fetchAHLGoalies(teams: [Team], season: String, teamIDs: [String]) async -> [Goalie]? {
    let byName = Dictionary(teams.filter { $0.league == .ahl }.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
    let byCode = Dictionary(teams.filter { $0.league == .ahl }.map { ($0.abbr, $0) }, uniquingKeysWith: { a, _ in a })
    var all: [Goalie] = []
    var anyOK = false
    await withTaskGroup(of: [Goalie]?.self) { group in
        for id in teamIDs {
            group.addTask {
                guard let rows = await ahlFetch("view=statviewtype&type=goalies&season_id=\(season)&team_id=\(id)&limit=20&first=0&sort=wins") else { return nil }
                return rows.compactMap { r -> Goalie? in
                    guard let pid = r["player_id"], let name = r["name"] ?? r["shortname"],
                          let team = r["team_name"].flatMap({ byName[$0] }) ?? r["team_code"].flatMap({ byCode[$0] }) else { return nil }
                    let gp = Int(r["games_played"] ?? "") ?? 0
                    guard gp > 0 else { return nil }
                    return Goalie(id: "g-ahl-\(pid)", name: name, team: team.name, league: .ahl, flag: team.flag,
                                  number: Int(r["jersey_number"] ?? ""), games: gp, wins: Int(r["wins"] ?? ""),
                                  shotsAgainst: Int(r["shots"] ?? ""), saves: Int(r["saves"] ?? ""),
                                  goalsAgainst: Int(r["goals_against"] ?? ""), shutouts: Int(r["shutouts"] ?? ""),
                                  gaaValue: Double(r["goals_against_average"] ?? ""))
                }
            }
        }
        for await r in group { if let r { anyOK = true; all += r } }
    }
    return anyOK ? all : nil
}

// MARK: - Store

extension AppStore {
    /// Hakee maalivahtitilastot ja tallentaa ne (sarja kerrallaan; epäonnistunut haku säilyttää vanhat tiedot).
    func refreshGoalies() async {
        var merged = state.goalies ?? []
        func replace(_ lg: League, _ new: [Goalie]?) {
            guard let new, !new.isEmpty else { return }
            merged.removeAll { $0.league == lg }
            merged += new
        }
        async let nhl = fetchNHLGoalies(teamByAbbr: teamByAbbr)
        async let liiga = fetchLiigaGoalies(teams: teams)
        let season = await fetchAHLSeasonId()
        let ids = await fetchAHLTeams(season: season).map(\.id)
        let ahl = await fetchAHLGoalies(teams: teams, season: season, teamIDs: ids)
        replace(.nhl, await nhl)
        replace(.liiga, await liiga)
        replace(.ahl, ahl)
        state.goalies = merged
        persist()
    }

    var goalies: [Goalie] { state.goalies ?? [] }
}
