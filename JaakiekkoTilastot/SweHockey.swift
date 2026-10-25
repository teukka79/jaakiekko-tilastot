import Foundation

/// SHL ja HockeyAllsvenskan: ottelut luetaan stats.swehockey.se -sivustolta.
struct SweGame {
    let id: String
    let gid: String?
    let date: Date
    let home: String
    let away: String
    let final: Bool
    let hs: Int
    let aw: Int
    let extra: String?   // "JA" tai "RL"
}

let sweBase = "https://stats.swehockey.se"

@MainActor private var sweCache: [League: (Date, [SweGame])] = [:]

func sweFetchHTML(_ url: String, timeout: TimeInterval = 30) async -> String? {
    guard let u = URL(string: url) else { return nil }
    var req = URLRequest(url: u)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = timeout
    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return String(data: data, encoding: .utf8)
}

func sweText(_ html: String) -> String {
    var s = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    s = s.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&nbsp;", with: " ")
    return s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
}

@MainActor
private func sweKey(_ s: String) -> String {
    AppStore.norm(s).replacingOccurrences(of: " ", with: "")
}

@MainActor
func sweResolve(_ name: String, seed: [Team]) -> String? {
    let k = sweKey(name)
    if let t = seed.first(where: { sweKey($0.name) == k }) { return t.name }
    return seed.first(where: {
        let a = sweKey($0.name)
        let (s, l) = a.count < k.count ? (a, k) : (k, a)
        return s.count >= 6 && l.contains(s)
    })?.name
}

func sweMatches(_ pattern: String, in s: String) -> [[String]] {
    guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
    let ns = s as NSString
    return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
        (0..<m.numberOfRanges).map { i in m.range(at: i).location == NSNotFound ? "" : ns.substring(with: m.range(at: i)) }
    }
}

@MainActor private var sweIdCache: [League: (Date, String)] = [:]

/// Sarjan tunnus löytyy etusivun linkistä, joten se ei vanhene kauden vaihtuessa
@MainActor
func sweLeagueID(_ league: League) async -> String? {
    if let c = sweIdCache[league], Date().timeIntervalSince(c.0) < 3600 { return c.1 }
    let label = league == .shl ? "SHL" : "HockeyAllsvenskan"
    guard let home = await sweFetchHTML(sweBase + "/") else { return nil }
    let links = sweMatches("<a[^>]+href=\"/ScheduleAndResults/(?:Overview|Schedule|Live)/([0-9]+)\"[^>]*>\\s*([^<]*?)\\s*</a>", in: home)
    guard let id = links.first(where: { $0.count > 2 && $0[2] == label })?[1] else { return nil }
    sweIdCache[league] = (Date(), id)
    return id
}

@MainActor
func fetchSweGames(league: League, teams: [Team]) async -> [SweGame]? {
    if let c = sweCache[league], Date().timeIntervalSince(c.0) < 300 { return c.1 }
    guard let id = await sweLeagueID(league),
          let page = await sweFetchHTML("\(sweBase)/ScheduleAndResults/Schedule/\(id)", timeout: 40) else { return nil }

    let seed = teams.filter { $0.league == league }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
    var out: [SweGame] = []
    var day: (Int, Int, Int)? = nil

    for row in sweMatches("<tr[^>]*>(.*?)</tr>", in: page) {
        let cells = sweMatches("<td\\b[^>]*?/>|<td\\b[^>]*>.*?</td>", in: row[1]).map { $0[0] }
        guard cells.count >= 8 else { continue }
        let c0 = sweText(cells[0])
        if let m = sweMatches("^([0-9]{4})-([0-9]{2})-([0-9]{2})$", in: c0).first, m.count > 3 {
            day = (Int(m[1]) ?? 0, Int(m[2]) ?? 0, Int(m[3]) ?? 0)
        }
        guard let d = day,
              let tm = sweMatches("([0-9]{1,2}):([0-9]{2})", in: sweText(cells[2])).first, tm.count > 2 else { continue }
        let parts = sweText(cells[3]).components(separatedBy: " - ")
        guard parts.count == 2,
              let h = sweResolve(parts[0], seed: seed), let a = sweResolve(parts[1], seed: seed),
              let date = cal.date(from: DateComponents(year: d.0, month: d.1, day: d.2, hour: Int(tm[1]), minute: Int(tm[2])))
        else { continue }
        let result = sweMatches("([0-9]+)\\s*-\\s*([0-9]+)", in: sweText(cells[4])).first
        let periods = sweMatches("[0-9]+-[0-9]+", in: sweText(cells[5])).count
        let gid = sweMatches("/Game/Events/([0-9]+)", in: cells[4]).first?[1]
        if let r = result, r.count > 2, let hs = Int(r[1]), let aw = Int(r[2]) {
            out.append(SweGame(id: "swe-\(gid ?? "\(out.count)")", gid: gid, date: date, home: h, away: a, final: true, hs: hs, aw: aw,
                               extra: periods >= 5 ? "RL" : (periods == 4 ? "JA" : nil)))
        } else {
            out.append(SweGame(id: "swe-\(out.count)", gid: nil, date: date, home: h, away: a, final: false, hs: 0, aw: 0, extra: nil))
        }
    }
    if out.isEmpty { return nil }
    sweCache[league] = (Date(), out)
    return out
}

@MainActor
func fetchSweSchedule(league: League, teams: [Team]) async -> [ScheduleGame]? {
    guard let games = await fetchSweGames(league: league, teams: teams) else { return nil }
    return games.map { g in
        var s = ScheduleGame(id: g.id, date: g.date, home: g.home, away: g.away)
        if g.final { s.final = true; s.homeScore = g.hs; s.awayScore = g.aw }
        return s
    }
}

@MainActor
func fetchSweStandings(league: League, teams: [Team]) async -> [StandingRow]? {
    guard let games = await fetchSweGames(league: league, teams: teams) else { return nil }
    var table: [String: StandingRow] = Dictionary(uniqueKeysWithValues: teams.filter { $0.league == league }.map { ($0.name, StandingRow(team: $0.name)) })
    for g in games where g.final {
        guard var hr = table[g.home], var ar = table[g.away] else { continue }
        hr.gp += 1; ar.gp += 1
        hr.gf += g.hs; hr.ga += g.aw; ar.gf += g.aw; ar.ga += g.hs
        let ex = g.extra != nil
        if g.hs > g.aw {
            hr.w += 1; hr.pts += ex ? 2 : 3
            if ex { ar.otl += 1; ar.pts += 1 } else { ar.l += 1 }
        } else if g.aw > g.hs {
            ar.w += 1; ar.pts += ex ? 2 : 3
            if ex { hr.otl += 1; hr.pts += 1 } else { hr.l += 1 }
        }
        table[g.home] = hr; table[g.away] = ar
    }
    return Array(table.values)
}
