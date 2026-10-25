import Foundation

// MARK: - Mestis (mestis.fi, HTML-sivujen jäsentäminen)

enum MestisSite {
    static let base = "https://mestis.fi"

    /// Joukkueiden logot (seuran nimi siemendatassa -> kuva).
    static let logos: [String: String] = [
        "Hermes": base + "/media/team-logos/hermes.png.150x150_q85.png",
        "IPK": base + "/media/team-logos/ipk.png.150x150_q85.png",
        "JoKP": base + "/media/team-logos/kiekkopojat.png.150x150_q85.png",
        "Ketterä": base + "/media/team-logos/kettera.png.150x150_q85.png",
        "KeuPa HT": base + "/media/team-logos/keupa_elAJWhB.png.150x150_q85.png",
        "K-Vantaa": base + "/media/team-logos/kiekko-vantaa.png.150x150_q85.png",
        "Pyry": base + "/media/team-logos/Pyry_Hockey_Logo.png.150x150_q85.png",
        "RoKi": base + "/media/team-logos/roki_new.png.150x150_q85.png",
        "TUTO Hockey": base + "/media/team-logos/tuto.png.150x150_q85.png",
    ]

    /// Vertailuavain: pienet kirjaimet, ei diakriitteja, vain kirjaimet ja numerot.
    static func key(_ s: String) -> String {
        let f = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return String(f.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }

    /// Sivuston nimi -> siemendatan joukkuenimi.
    static func resolve(_ name: String, teams: [Team]) -> String? {
        let seed = teams.filter { $0.league == .mestis }
        let k = key(name)
        if let t = seed.first(where: { key($0.name) == k }) { return t.name }
        let alias = ["kiekkopojat": "jokp", "kiekkovantaa": "kvantaa", "tuto": "tutohockey", "keupa": "keupaht"]
        if let a = alias[k], let t = seed.first(where: { key($0.name) == a }) { return t.name }
        return nil
    }
}

private struct MestisRow {
    var tag: String
    var cells: [String]
    var raw: [String]
}

func fetchMestisHTML(_ path: String) async -> String? {
    guard let url = URL(string: MestisSite.base + path) else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 25
    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let html = String(data: data, encoding: .utf8) else { return nil }
    return html
}

private func mestisClean(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    let ents = ["&nbsp;": " ", "&amp;": "&", "&mdash;": "—", "&ndash;": "–", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&lt;": "<", "&gt;": ">"]
    for (k, v) in ents { t = t.replacingOccurrences(of: k, with: v) }
    return t.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
}

/// Poimii taulukon (id) rungon rivit ja solut.
private func mestisRows(_ html: String, tableId: String) -> [MestisRow] {
    guard let start = html.range(of: "id=\"\(tableId)\"") else { return [] }
    var body = String(html[start.upperBound...])
    if let end = body.range(of: "</table>") { body = String(body[..<end.lowerBound]) }
    if let tb = body.range(of: "<tbody") { body = String(body[tb.lowerBound...]) }
    guard let rowRe = try? NSRegularExpression(pattern: "(<tr[^>]*>)(.*?)</tr>", options: [.dotMatchesLineSeparators]),
          let cellRe = try? NSRegularExpression(pattern: "<td[^>]*>(.*?)</td>", options: [.dotMatchesLineSeparators]) else { return [] }
    let ns = body as NSString
    var out: [MestisRow] = []
    for m in rowRe.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
        let tag = ns.substring(with: m.range(at: 1))
        let inner = ns.substring(with: m.range(at: 2)) as NSString
        var cells: [String] = [], raws: [String] = []
        for c in cellRe.matches(in: inner as String, range: NSRange(location: 0, length: inner.length)) {
            let raw = inner.substring(with: c.range(at: 1))
            raws.append(raw)
            cells.append(mestisClean(raw))
        }
        if !cells.isEmpty { out.append(MestisRow(tag: tag, cells: cells, raw: raws)) }
    }
    return out
}

private func mestisInt(_ s: String?) -> Int? {
    guard let s else { return nil }
    return Int(s.replacingOccurrences(of: "+", with: "").trimmingCharacters(in: .whitespaces))
}

// MARK: Pelaajat

struct MestisSkater {
    var id: Int?
    var name: String
    var team: String
    var pos: String
    var games: Int, goals: Int, assists: Int
    var pim: Int?, plusMinus: Int?, shots: Int?
    var link: String?
}

func fetchMestisSkaters() async -> [MestisSkater]? {
    guard let html = await fetchMestisHTML("/fi/tilastot/pelaajat/") else { return nil }
    let rows = mestisRows(html, tableId: "stats")
    var out: [MestisSkater] = []
    for r in rows where r.cells.count >= 16 {
        let pos = r.cells[3]
        if pos == "MV" { continue }   // maalivahdit jätetään pois
        var name = r.cells[1]
        if let comma = name.range(of: ", ") {
            name = String(name[comma.upperBound...]) + " " + String(name[..<comma.lowerBound])
        }
        var id: Int?
        var link: String?
        if let m = r.raw[1].range(of: "/pelaajat/[0-9]+", options: .regularExpression) {
            id = Int(r.raw[1][m].replacingOccurrences(of: "/pelaajat/", with: ""))
        }
        if let m = r.raw[1].range(of: "href=\"/fi/pelaajat/[^\"]+\"", options: .regularExpression) {
            link = String(r.raw[1][m]).replacingOccurrences(of: "href=\"", with: "").replacingOccurrences(of: "\"", with: "")
            if link?.hasSuffix("/") == true { link?.removeLast() }
        }
        out.append(MestisSkater(id: id, name: name, team: r.cells[2], pos: pos,
                                games: mestisInt(r.cells[4]) ?? 0, goals: mestisInt(r.cells[5]) ?? 0,
                                assists: mestisInt(r.cells[6]) ?? 0, pim: mestisInt(r.cells[8]),
                                plusMinus: mestisInt(r.cells[11]), shots: mestisInt(r.cells[15]), link: link))
    }
    return out.isEmpty ? nil : out
}

// MARK: Sarjataulukko

func fetchMestisStandings(teams: [Team]) async -> [StandingRow]? {
    guard let html = await fetchMestisHTML("/fi/tilastot/joukkueet/") else { return nil }
    var out: [StandingRow] = []
    for r in mestisRows(html, tableId: "stats") where r.cells.count >= 9 {
        guard let team = MestisSite.resolve(r.cells[1], teams: teams) else { continue }
        let v = mestisInt(r.cells[3]) ?? 0, jav = mestisInt(r.cells[4]) ?? 0
        out.append(StandingRow(team: team, gp: mestisInt(r.cells[2]) ?? 0, w: v + jav, l: mestisInt(r.cells[6]) ?? 0,
                               otl: mestisInt(r.cells[5]) ?? 0, pts: mestisInt(r.cells[9]) ?? 0,
                               gf: mestisInt(r.cells[7]) ?? 0, ga: mestisInt(r.cells[8]) ?? 0))
    }
    return out.isEmpty ? nil : out
}

// MARK: Otteluohjelma

func fetchMestisSchedule(teams: [Team]) async -> [ScheduleGame]? {
    guard let html = await fetchMestisHTML("/fi/ottelut/") else { return nil }
    let rows = mestisRows(html, tableId: "games")
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(identifier: "Europe/Helsinki")
    df.dateFormat = "yyyyMMdd HH:mm"
    var out: [ScheduleGame] = []
    for r in rows where r.cells.count >= 6 {
        guard let tm = r.tag.range(of: "data-time=\"[0-9]{8}\"", options: .regularExpression) else { continue }
        let day = r.tag[tm].replacingOccurrences(of: "data-time=\"", with: "").replacingOccurrences(of: "\"", with: "")
        guard let date = df.date(from: day + " " + r.cells[2]) else { continue }
        let parts = r.cells[3].components(separatedBy: " - ")
        guard parts.count == 2,
              let h = MestisSite.resolve(parts[0], teams: teams),
              let a = MestisSite.resolve(parts[1], teams: teams) else { continue }
        var hs: Int?, aw: Int?
        let score = r.cells[5]
        if let m = score.range(of: "[0-9]+ ?[—–-] ?[0-9]+", options: .regularExpression) {
            let nums = score[m].components(separatedBy: CharacterSet(charactersIn: "—–- ")).compactMap { Int($0) }
            if nums.count == 2 { hs = nums[0]; aw = nums[1] }
        }
        var gid = ""
        if let m = r.raw[3].range(of: "/runkosarja/[0-9]+", options: .regularExpression) {
            gid = r.raw[3][m].replacingOccurrences(of: "/runkosarja/", with: "")
        }
        // Sivusto ei kerro ottelun tilaa: tulos näkyy ja ottelu alkoi alle 2,5 tuntia sitten -> käynnissä
        let recent = Date().timeIntervalSince(date) < 2.5 * 3600
        out.append(ScheduleGame(id: "mestis-\(gid.isEmpty ? "\(out.count)" : gid)", date: date, home: h, away: a,
                                live: hs != nil && recent, final: hs != nil && !recent, homeScore: hs, awayScore: aw))
    }
    return out.isEmpty ? nil : out
}

// MARK: Pelaajakohtaiset tiedot

private func mestisAllRows(_ html: String) -> [[String]] {
    guard let rowRe = try? NSRegularExpression(pattern: "<tr[^>]*>(.*?)</tr>", options: [.dotMatchesLineSeparators]),
          let cellRe = try? NSRegularExpression(pattern: "<td[^>]*>(.*?)</td>", options: [.dotMatchesLineSeparators]) else { return [] }
    let ns = html as NSString
    var out: [[String]] = []
    for m in rowRe.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
        let inner = ns.substring(with: m.range(at: 1)) as NSString
        let cells = cellRe.matches(in: inner as String, range: NSRange(location: 0, length: inner.length))
            .map { mestisClean(inner.substring(with: $0.range(at: 1))) }
        if !cells.isEmpty { out.append(cells) }
    }
    return out
}

/// Pelaajan viimeisimmät pelatut ottelut (ottelu-ottelulta-sivu).
func fetchMestisGameLog(link: String, team: String) async -> [RecentGame]? {
    guard let html = await fetchMestisHTML(link + "/ottelu-ottelulta") else { return nil }
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(identifier: "Europe/Helsinki")
    df.dateFormat = "d.M.yyyy"
    let iso = DateFormatter()
    iso.locale = Locale(identifier: "en_US_POSIX")
    iso.timeZone = TimeZone(identifier: "Europe/Helsinki")
    iso.dateFormat = "yyyy-MM-dd"
    var games: [(Date, RecentGame)] = []
    for c in mestisAllRows(html) where c.count >= 13 {
        guard c[0].range(of: "^[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{4}$", options: .regularExpression) != nil,
              let d = df.date(from: c[0]), d <= Date() else { continue }
        let parts = c[1].components(separatedBy: " - ")
        guard parts.count == 2 else { continue }
        let isHome = MestisSite.key(parts[0]) == MestisSite.key(team)
        let opp = isHome ? parts[1] : parts[0]
        games.append((d, RecentGame(date: iso.string(from: d), opponent: opp, home: isHome,
                                    goals: mestisInt(c[2]) ?? 0, assists: mestisInt(c[3]) ?? 0, shots: mestisInt(c[12]))))
    }
    return games.sorted { $0.0 > $1.0 }.prefix(5).map { $0.1 }
}

/// Pelinumero ja kansalaisuus pelaajasivulta.
func fetchMestisPlayerInfo(link: String) async -> PlayerInfo? {
    guard let html = await fetchMestisHTML(link) else { return nil }
    var number: Int?
    if let t = html.range(of: "<title>[^<]*</title>", options: .regularExpression) {
        let title = String(html[t])
        if let m = title.range(of: "#[0-9]+", options: .regularExpression) { number = Int(title[m].dropFirst()) }
    }
    var nat: String?
    if let m = html.range(of: "Kansalaisuus\\s*</th>\\s*<td[^>]*>\\s*[A-Za-z]{3}", options: [.regularExpression]) {
        nat = String(html[m].suffix(3)).uppercased()
    }
    return PlayerInfo(number: number, nat: nat)
}
