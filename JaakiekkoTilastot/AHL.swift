import Foundation

// MARK: - AHL (HockeyTech-rajapinta)

/// Arvo voi olla merkkijono tai luku; muut tyypit tulkitaan puuttuvaksi.
struct AHLValue: Decodable {
    let s: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { s = v }
        else if let v = try? c.decode(Int.self) { s = String(v) }
        else if let v = try? c.decode(Double.self) { s = String(v) }
        else { s = nil }
    }
}

private struct AHLResponse: Decodable {
    struct Inner: Decodable {
        let rows: [[String: AHLValue]]
        enum CodingKeys: String, CodingKey { case statviewtype = "Statviewtype", seasons = "Seasons", teams = "Teamsbyseason", schedule = "Schedule" }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let r = try? c.decode([[String: AHLValue]].self, forKey: .statviewtype) { rows = r }
            else if let r = try? c.decode([[String: AHLValue]].self, forKey: .seasons) { rows = r }
            else if let r = try? c.decode([[String: AHLValue]].self, forKey: .teams) { rows = r }
            else if let r = try? c.decode([[String: AHLValue]].self, forKey: .schedule) { rows = r }
            else { rows = [] }
        }
    }
    let siteKit: Inner
    enum CodingKeys: String, CodingKey { case siteKit = "SiteKit" }
}

func ahlFetch(_ query: String) async -> [[String: String]]? {
    let base = "https://lscluster.hockeytech.com/feed/index.php?feed=modulekit&key=ccb91f29d6744675&fmt=json&client_code=ahl&lang=en&"
    guard let url = URL(string: base + query) else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 20
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let r = try? JSONDecoder().decode(AHLResponse.self, from: data) else { return nil }
    return r.siteKit.rows.map { row in row.compactMapValues { $0.s } }
}

/// Uusin runkosarjakausi (season_id); oletus 94 = 2026–27.
func fetchAHLSeasonId() async -> String {
    guard let rows = await ahlFetch("view=seasons") else { return "94" }
    let reg = rows.filter { $0["career"] == "1" && $0["playoff"] == "0" }
    let named = reg.filter { ($0["season_name"] ?? "").contains("Regular") }
    let list = named.isEmpty ? reg : named
    let best = list.compactMap { r -> (Int, String)? in
        guard let id = r["season_id"], let n = Int(id) else { return nil }
        return (n, id)
    }.max { $0.0 < $1.0 }
    return best?.1 ?? "94"
}

struct AHLSkater {
    var id: Int?
    var name: String
    var team: String
    var code: String
    var pos: String
    var number: Int?
    var games: Int, goals: Int, assists: Int
    var pim: Int?, plusMinus: Int?, shots: Int?
    var ppPoints: Int?
}

/// Joukkueet kaudella: (id, nimi, lyhenne, logo).
func fetchAHLTeams(season: String) async -> [(id: String, name: String, code: String, logo: String?)] {
    guard let rows = await ahlFetch("view=teamsbyseason&season_id=\(season)") else { return [] }
    return rows.compactMap { r in
        guard let id = r["id"], let n = r["name"] else { return nil }
        return (id, n, r["code"] ?? "", r["team_logo_url"])
    }
}

/// Rajapinta palauttaa oletuksena vain yhden joukkueen pelaajat, joten haetaan joukkue kerrallaan.
func fetchAHLSkaters(season: String, teamIDs: [String]) async -> [AHLSkater]? {
    var all: [AHLSkater] = []
    var anyOK = false
    await withTaskGroup(of: [AHLSkater]?.self) { group in
        for id in teamIDs {
            group.addTask {
                guard let rows = await ahlFetch("view=statviewtype&type=skaters&season_id=\(season)&team_id=\(id)&limit=100&first=0&sort=points") else { return nil }
                return rows.compactMap { r -> AHLSkater? in
                    guard let name = r["name"] ?? r["shortname"], let team = r["team_name"] else { return nil }
                    let g = Int(r["goals"] ?? "") ?? 0
                    let a = Int(r["assists"] ?? "") ?? 0
                    return AHLSkater(id: Int(r["player_id"] ?? ""), name: name, team: team, code: r["team_code"] ?? "",
                                     pos: (r["position"] ?? "").uppercased(), number: Int(r["jersey_number"] ?? ""),
                                     games: Int(r["games_played"] ?? "") ?? 0, goals: g, assists: a,
                                     pim: Int(r["penalty_minutes"] ?? ""), plusMinus: Int(r["plus_minus"] ?? ""),
                                     shots: Int(r["shots"] ?? ""), ppPoints: Int(r["power_play_points"] ?? ""))
                }
            }
        }
        for await r in group {
            if let r { anyOK = true; all += r }
        }
    }
    return anyOK ? all : nil
}

@MainActor
func fetchAHLStandings(teams: [Team], season: String) async -> [StandingRow]? {
    guard let rows = await ahlFetch("view=statviewtype&type=standings&stat=overall&season_id=\(season)&groupTeamsBy=division") else { return nil }
    let seed = teams.filter { $0.league == .ahl }
    let byName = Dictionary(uniqueKeysWithValues: seed.map { (AppStore.norm($0.name), $0.name) })
    let byAbbr = Dictionary(uniqueKeysWithValues: seed.map { ($0.abbr, $0.name) })
    var result: [StandingRow] = []
    for r in rows {
        guard r["team_id"] != nil else { continue }
        let name = r["name"].flatMap { byName[AppStore.norm($0)] } ?? r["team_code"].flatMap { byAbbr[$0] }
        guard let team = name else { continue }
        let gp = Int(r["games_played"] ?? "") ?? 0
        let w = Int(r["wins"] ?? "") ?? 0
        let otl = (Int(r["ot_losses"] ?? "") ?? 0) + (Int(r["shootout_losses"] ?? "") ?? 0)
        let l = max(0, gp - w - otl)
        let conf = r["conference_name"] ?? ""
        let div = r["division_name"] ?? r["divisname"] ?? ""
        result.append(StandingRow(team: team, gp: gp, w: w, l: l, otl: otl, pts: Int(r["points"] ?? "") ?? 0,
                                  gf: Int(r["goals_for"] ?? "") ?? 0, ga: Int(r["goals_against"] ?? "") ?? 0,
                                  group: "\(conf)|\(div)"))
    }
    return result.isEmpty ? nil : result
}

/// Onko AHL:ssä käynnissä olevia otteluita (kevyt kysely).
func ahlHasLiveGames() async -> Bool {
    guard let rows = await ahlFetch("view=schedule&season_id=94") else { return false }
    return rows.contains { $0["started"] == "1" && $0["final"] != "1" }
}
