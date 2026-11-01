import Foundation

// MARK: - Sveitsin National League (SIHF:n tilastorajapinta data.sihf.ch)

enum NLSite {
    static let table = "https://data.sihf.ch/Statistic/api/cms/table"
    /// Kausi 2026/27.
    static let season = "2027"
    static let seasonRange = "01.07.2026-30.06.2027"
}

private struct NLTable {
    var index: [String: Int] = [:]
    var rows: [[Any]] = []

    func cell(_ r: [Any], _ alias: String) -> Any? {
        guard let i = index[alias], i < r.count else { return nil }
        return r[i]
    }
    func str(_ r: [Any], _ alias: String) -> String? { cell(r, alias) as? String }
    func int(_ r: [Any], _ alias: String) -> Int? {
        str(r, alias).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    func dbl(_ r: [Any], _ alias: String) -> Double? {
        str(r, alias).flatMap { Double($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
    }
    func dict(_ r: [Any], _ alias: String) -> [String: Any]? { cell(r, alias) as? [String: Any] }
}

@MainActor
private func nlFetch(_ query: String) async -> NLTable? {
    guard let url = URL(string: NLSite.table + "?" + query) else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 30
    req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36", forHTTPHeaderField: "User-Agent")
    req.setValue("https://www.nationalleague.ch/", forHTTPHeaderField: "Referer")
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rows = obj["data"] as? [[Any]],
          let header = obj["header"] as? [[String: Any]] else { return nil }
    var t = NLTable()
    for (i, h) in header.enumerated() {
        if let a = h["alias"] as? String { t.index[a] = i }
    }
    t.rows = rows
    return t
}

/// Rajapinnan joukkue-objekti -> siemendatan joukkue.
private func nlTeam(_ obj: [String: Any]?, _ teams: [Team]) -> Team? {
    guard let obj else { return nil }
    let name = obj["name"] as? String ?? ""
    let acr = obj["acronym"] as? String ?? ""
    let list = teams.filter { $0.league == .nl }
    return list.first { $0.name == name } ?? list.first { $0.abbr == acr }
}

/// "Sukunimi Etunimi" -> "Etunimi Sukunimi".
func nlDisplayName(_ s: String) -> String {
    let parts = s.split(separator: " ").map(String.init)
    guard parts.count >= 2, let first = parts.last else { return s }
    return first + " " + parts.dropLast().joined(separator: " ")
}

private func nlBaseQuery(_ alias: String) -> String {
    "alias=\(alias)&searchQuery=1//1&filterBy=Season&filterQuery=\(NLSite.season)&language=en"
}

/// Kenttäpelaajat: avain norm(nimi).
@MainActor
func fetchNLSkaters(teams: [Team]) async -> [String: [LiveEntry]]? {
    guard let t = await nlFetch(nlBaseQuery("player") + "&orderBy=points&orderByDescending=true&take=500&skip=0") else { return nil }
    var out: [String: [LiveEntry]] = [:]
    for r in t.rows {
        guard let raw = t.str(r, "player"), let team = nlTeam(t.dict(r, "team"), teams) else { continue }
        let name = nlDisplayName(raw)
        let pos = (t.str(r, "position") ?? "").hasPrefix("Verteid") ? "D" : "F"
        out[AppStore.norm(name), default: []].append(
            LiveEntry(abbr: team.name, pos: pos, games: t.int(r, "gamesPlayed") ?? 0, goals: t.int(r, "goals") ?? 0,
                      assists: t.int(r, "assists") ?? 0, pim: t.int(r, "pimTotal"), plusMinus: t.int(r, "plusMinus"), name: name))
    }
    return out.isEmpty ? nil : out
}

@MainActor
func fetchNLGoalies(teams: [Team]) async -> [Goalie]? {
    guard let t = await nlFetch(nlBaseQuery("goalkeeper") + "&take=100&skip=0") else { return nil }
    var out: [Goalie] = []
    for r in t.rows {
        guard let raw = t.str(r, "player"), let team = nlTeam(t.dict(r, "team"), teams) else { continue }
        let name = nlDisplayName(raw)
        out.append(Goalie(id: "g-nl-\(AppStore.norm(name))-\(team.abbr)", name: name, team: team.name, league: .nl, flag: team.flag,
                          games: t.int(r, "gamesPlayed") ?? 0, wins: nil, shotsAgainst: t.int(r, "shotsAgainst"),
                          saves: t.int(r, "saves"), goalsAgainst: t.int(r, "goalsAgainst"), shutouts: nil,
                          gaaValue: t.dbl(r, "goalsAgainstAverage")))
    }
    return out
}

@MainActor
func fetchNLStandings(teams: [Team]) async -> [StandingRow]? {
    guard let t = await nlFetch(nlBaseQuery("standing")) else { return nil }
    var out: [StandingRow] = []
    for r in t.rows {
        guard let team = nlTeam(t.dict(r, "team"), teams) else { continue }
        let w = (t.int(r, "gamesWonInTime") ?? 0) + (t.int(r, "gamesWonExtraTime") ?? 0) + (t.int(r, "gamesWonPenalty") ?? 0)
        out.append(StandingRow(team: team.name, gp: t.int(r, "gamesPlayed") ?? 0, w: w, l: t.int(r, "gamesLostInTime") ?? 0,
                               otl: (t.int(r, "gamesLostExtraTime") ?? 0) + (t.int(r, "gamesLostPenalty") ?? 0),
                               pts: t.int(r, "points") ?? 0, gf: t.int(r, "goalsFor") ?? 0, ga: t.int(r, "goalsAgainst") ?? 0))
    }
    return out.isEmpty ? nil : out
}

struct NLGame {
    let id: String
    let date: Date
    let home: String
    let away: String
    let final: Bool
    let live: Bool
    let hs: Int
    let aw: Int
    let extra: String?
}

@MainActor
func fetchNLGames(teams: [Team]) async -> [NLGame]? {
    guard let t = await nlFetch("alias=results&searchQuery=1//1&language=en&filterBy=Date&filterQuery=\(NLSite.seasonRange)") else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    let fallback = DateFormatter()
    fallback.locale = Locale(identifier: "en_US_POSIX")
    fallback.timeZone = TimeZone(identifier: "Europe/Zurich")
    fallback.dateFormat = "dd.MM.yyyy HH:mm"
    var out: [NLGame] = []
    for (i, r) in t.rows.enumerated() {
        guard let h = nlTeam(t.dict(r, "homeTeam"), teams), let a = nlTeam(t.dict(r, "awayTeam"), teams) else { continue }
        let status = t.dict(r, "status")
        var date = (status?["startDateTime"] as? String).flatMap { iso.date(from: $0) }
        if date == nil, let d = t.str(r, "date"), let tm = t.str(r, "time") { date = fallback.date(from: "\(d) \(tm)") }
        guard let date else { continue }
        let percent = (status?["percent"] as? Int) ?? Int(status?["percent"] as? Double ?? 0)
        let score = t.dict(r, "score")
        let hs = (score?["homeTeam"] as? String).flatMap { Int($0) }
        let aw = (score?["awayTeam"] as? String).flatMap { Int($0) }
        let finished = percent >= 100 && hs != nil && aw != nil
        let dec = (t.str(r, "decision") ?? "").uppercased()
        let extra: String? = !finished ? nil : (dec == "OT" ? "JA" : (dec == "SO" || dec == "PS" || dec == "GWS" ? "RL" : nil))
        let gid = (t.dict(r, "details")?["gameId"] as? String) ?? "\(i)"
        out.append(NLGame(id: "nl-\(gid)", date: date, home: h.name, away: a.name, final: finished,
                          live: !finished && percent > 0 && percent < 100, hs: hs ?? 0, aw: aw ?? 0, extra: extra))
    }
    return out.isEmpty ? nil : out
}

@MainActor
func fetchNLSchedule(teams: [Team]) async -> [ScheduleGame]? {
    guard let games = await fetchNLGames(teams: teams) else { return nil }
    return games.map { g in
        var s = ScheduleGame(id: g.id, date: g.date, home: g.home, away: g.away)
        s.live = g.live
        if g.final { s.final = true; s.homeScore = g.hs; s.awayScore = g.aw }
        return s
    }
}

// MARK: Pelikohtaiset tiedot (viimeiset pelit, liekki, numerot, laukaukset, ylivoima)

/// Kaudelta kertyneet summat; jo käsitellyt ottelut muistetaan, jotta vain uudet haetaan.
struct NLAgg: Codable {
    var processed: [String] = []
    var num: [String: Int] = [:]
    var sog: [String: Int] = [:]
    var pp: [String: Int] = [:]
}

private struct NLGameScoring {
    var goals: [String: Int] = [:]    // norm(nimi) -> maalit
    var assists: [String: Int] = [:]
    var pp: [String: Int] = [:]       // ylivoimapisteet
    var sog: [String: Int] = [:]      // laukaukset
    var num: [String: Int] = [:]      // pelinumero
}

private func nlInt(_ v: Any?) -> Int? {
    if let i = v as? Int { return i }
    if let d = v as? Double { return Int(d) }
    if let s = v as? String { return Int(s.trimmingCharacters(in: .whitespaces)) }
    return nil
}

/// Varasuunnitelma: maalitapahtuman tekstistä ("**EQ** / **0:1** - **Meier Gian (1)**\nMäenalanen Saku (6), Björninen Hannes (8)").
@MainActor
private func nlParseGoalText(_ text: String?) -> (scorer: String?, assists: [String]) {
    guard let text else { return (nil, []) }
    func clean(_ s: String) -> String {
        var x = s.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
        if let r = x.range(of: " (", options: .backwards) { x = String(x[..<r.lowerBound]) }
        return x.trimmingCharacters(in: .whitespaces)
    }
    let lines = text.components(separatedBy: "\n")
    var scorer: String? = nil
    if let first = lines.first, let r = first.range(of: " - ", options: .backwards) {
        let n = clean(String(first[r.upperBound...]))
        if !n.isEmpty { scorer = AppStore.norm(nlDisplayName(n)) }
    }
    var assists: [String] = []
    if lines.count > 1 {
        for part in lines[1].components(separatedBy: "), ") {
            let n = clean(part.hasSuffix(")") ? part : part + ")")
            if !n.isEmpty { assists.append(AppStore.norm(nlDisplayName(n))) }
        }
    }
    return (scorer, assists)
}

@MainActor private var nlScoringCache: [String: NLGameScoring] = [:]

/// Hakee yhden ottelun maalit, syötöt, ylivoimapisteet, laukaukset ja numerot (SIHF gameoverview).
@MainActor
private func fetchNLGameScoring(gameId: String) async -> NLGameScoring? {
    if let c = nlScoringCache[gameId] { return c }
    guard let url = URL(string: "https://data.sihf.ch/Statistic/api/cms/gameoverview?alias=gameDetail&searchQuery=\(gameId)&language=en") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 30
    req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36", forHTTPHeaderField: "User-Agent")
    req.setValue("https://www.nationalleague.ch/", forHTTPHeaderField: "Referer")
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let summary = obj["summary"] as? [String: Any],
          let periods = summary["periods"] as? [[String: Any]] else { return nil }
    let players = (obj["players"] as? [[String: Any]]) ?? []
    var names: [Int: String] = [:]
    var out = NLGameScoring()
    for p in players {
        if let id = nlInt(p["id"]), let n = p["fullName"] as? String {
            let k = AppStore.norm(nlDisplayName(n))
            names[id] = k
            if let jn = nlInt(p["jerseyNumber"]) { out.num[k] = jn }
        }
    }
    for period in periods {
        for g in (period["goals"] as? [[String: Any]]) ?? [] {
            if (g["isShootout"] as? Bool) == true { continue }
            let code = ((g["situation"] as? [String: Any])?["code"] as? String) ?? ""
            let isPP = code.hasPrefix("PP")
            let parsed = nlParseGoalText(g["text"] as? String)
            if let n = nlInt(g["scorerLicenceNr"]).flatMap({ names[$0] }) ?? parsed.scorer {
                out.goals[n, default: 0] += 1
                if isPP { out.pp[n, default: 0] += 1 }
            }
            for (i, k) in ["assist1LicenceNr", "assist2LicenceNr"].enumerated() {
                let a = nlInt(g[k])
                if let a, a <= 0 { continue }
                if let n = a.flatMap({ names[$0] }) ?? (i < parsed.assists.count ? parsed.assists[i] : nil) {
                    out.assists[n, default: 0] += 1
                    if isPP { out.pp[n, default: 0] += 1 }
                }
            }
        }
    }
    for tbl in (obj["stats"] as? [[String: Any]]) ?? [] {
        guard let header = tbl["header"] as? [[String: Any]], let rows = tbl["data"] as? [[Any]] else { continue }
        let aliases = header.map { ($0["alias"] as? String) ?? "" }
        guard let ni = aliases.firstIndex(of: "player"), let si = aliases.firstIndex(of: "shotsOnGoal") else { continue }
        for r in rows where ni < r.count && si < r.count {
            if let nm = r[ni] as? String, let sv = r[si] as? String, let sh = Int(sv.trimmingCharacters(in: .whitespaces)) {
                out.sog[AppStore.norm(nlDisplayName(nm)), default: 0] += sh
            }
        }
    }
    nlScoringCache[gameId] = out
    return out
}

extension AppStore {
    /// Liittää kertyneet laukaukset, ylivoimapisteet ja pelinumerot pelaajiin.
    private func applyNLAgg(_ snap: inout LiveSnapshot) {
        guard let agg = state.nlAgg, !agg.processed.isEmpty else { return }
        var info = snap.info ?? [:]
        for (key, list) in snap.byName {
            var l = list
            for i in l.indices { l[i].shots = agg.sog[key] ?? 0; l[i].ppPoints = agg.pp[key] ?? 0 }
            snap.byName[key] = l
            if let n = agg.num[key] { info[key] = PlayerInfo(number: n, nat: nil) }
        }
        snap.info = info
    }

    /// Päivittää National League -pelaajat, maalivahdit sekä viimeisten pelien, liekin, numeroiden, laukausten ja ylivoiman tiedot.
    func refreshNL() async {
        if let byName = await fetchNLSkaters(teams: teams) {
            var s = LiveSnapshot(byName: byName, timestamp: Date(), info: state.liveNL?.info)
            s.teamRecent = state.liveNL?.teamRecent
            s.recent = state.liveNL?.recent
            s.hot = state.liveNL?.hot
            applyNLAgg(&s)
            state.liveNL = s
        }
        if let g = await fetchNLGoalies(teams: teams), !g.isEmpty {
            var merged = state.goalies ?? []
            merged.removeAll { $0.league == .nl }
            merged += g
            state.goalies = merged
        }
        persist()
        rebuild()

        guard var snap = state.liveNL else { nlStatus = "NL: pelaajatietoja ei haettu"; return }
        guard let games = await fetchNLGames(teams: teams) else { nlStatus = "NL: ottelulistan haku epäonnistui"; return }
        let finished = games.filter { $0.final }.sorted { $0.date > $1.date }
        func gid(_ g: NLGame) -> String { g.id.replacingOccurrences(of: "nl-", with: "") }
        var perTeam: [String: [NLGame]] = [:]
        for g in finished {
            for t in [g.home, g.away] where perTeam[t, default: []].count < 5 { perTeam[t, default: []].append(g) }
        }
        nlStatus = "NL: haetaan pelitietoja…"
        var agg = state.nlAgg ?? NLAgg()
        let done = Set(agg.processed)
        let unprocessed = finished.map(gid).filter { !done.contains($0) }
        let recentIds = perTeam.values.flatMap { $0 }.map(gid)
        let ids = Array(Set(unprocessed + recentIds)).filter { nlScoringCache[$0] == nil }
        var idx = 0
        while idx < ids.count {
            let chunk = Array(ids[idx..<min(idx + 6, ids.count)])
            idx += 6
            await withTaskGroup(of: Void.self) { group in
                for id in chunk { group.addTask { @MainActor in _ = await fetchNLGameScoring(gameId: id) } }
            }
        }
        // Uudelleenyritys hakematta jääneille otteluille (muuten joukkueen viimeiset pelit näkyvät nollina)
        for _ in 0..<2 {
            let missing = Array(Set(unprocessed + recentIds)).filter { nlScoringCache[$0] == nil }
            if missing.isEmpty { break }
            for id in missing { _ = await fetchNLGameScoring(gameId: id) }
        }
        for id in unprocessed {
            guard let s = nlScoringCache[id] else { continue }
            for (k, v) in s.num { agg.num[k] = v }
            for (k, v) in s.sog { agg.sog[k, default: 0] += v }
            for (k, v) in s.pp { agg.pp[k, default: 0] += v }
            agg.processed.append(id)
        }
        state.nlAgg = agg
        let recentUnique = Set(recentIds)
        let okRecent = recentUnique.filter { nlScoringCache[$0] != nil }.count
        nlStatus = "NL: viimeiset pelit \(okRecent)/\(recentUnique.count) ottelua, kausi \(agg.processed.count)/\(finished.count)"

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "Europe/Zurich")
        df.dateFormat = "yyyy-MM-dd"
        var teamRecent: [String: [RecentGame]] = [:]
        var recent: [String: [RecentGame]] = [:]
        var hot: [String] = []
        for (team, list) in perTeam {
            let rows: [RecentGame] = list.map { g in
                let home = g.home == team
                return RecentGame(date: df.string(from: g.date), opponent: home ? g.away : g.home, home: home, goals: 0, assists: 0)
            }
            teamRecent[team] = rows
            let scorings = list.map { nlScoringCache[gid($0)] }
            var keys = Set<String>()
            for s in scorings { if let s { keys.formUnion(s.goals.keys); keys.formUnion(s.assists.keys) } }
            for key in keys {
                // Vastustajan pelaajat ohitetaan: avain kuuluu vain oman joukkueensa peleihin
                guard snap.byName[key]?.contains(where: { $0.abbr == team }) == true else { continue }
                var perGame: [RecentGame] = []
                for (i, s) in scorings.enumerated() {
                    guard let s else { continue }
                    let g = s.goals[key] ?? 0, a = s.assists[key] ?? 0
                    if g + a > 0 {
                        var r = rows[i]; r.goals = g; r.assists = a
                        r.pp = s.pp[key]; r.shots = s.sog[key]
                        perGame.append(r)
                    }
                }
                if !perGame.isEmpty { recent[key, default: []] = perGame }
                // Liekki: piste jokaisessa joukkueen neljässä viimeisessä pelissä
                let last4 = scorings.prefix(4)
                if last4.count == 4, last4.allSatisfy({ ($0?.goals[key] ?? 0) + ($0?.assists[key] ?? 0) > 0 }) { hot.append(key) }
            }
        }
        snap.teamRecent = teamRecent
        snap.recent = recent
        snap.hot = hot
        applyNLAgg(&snap)
        state.liveNL = snap
        persist()
        rebuild()
        clearRecentCache()
    }
}
