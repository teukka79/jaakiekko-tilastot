import Foundation

// SHL ja HockeyAllsvenskan: pelaajatilastot lasketaan Swehockeyn ottelutapahtumista
// (maalit, syötöt, ylivoimapisteet, +/-, jäähyt). Laukauksia ei saada pelaajakohtaisesti.

struct SweAst: Codable, Hashable {
    var n: Int
    var name: String
}

struct SweGoal: Codable, Hashable {
    var s: String          // "h" = kotijoukkue, "a" = vierasjoukkue
    var type: String       // EQ, PP1, PP2, SH, EN, PS ...
    var n: Int             // maalintekijän numero
    var name: String       // "Sukunimi, Etunimi"
    var ast: [SweAst]
    var pos: [Int]         // kentällä olleet (maalin tehneen joukkueen) numerot
    var neg: [Int]         // kentällä olleet vastustajan numerot
}

struct SwePen: Codable, Hashable {
    var s: String
    var n: Int
    var m: Int
}

struct SweEvents: Codable, Hashable {
    var goals: [SweGoal]
    var pens: [SwePen]
}

struct SwePlayer: Codable, Hashable {
    var name: String
    var team: String
    var number: Int?
    var pos: String?
    var slot: String?
    var nat: String?
    var born: String?
    var goals = 0
    var assists = 0
    var ppPoints = 0
    var plusMinus = 0
    var pim = 0
}

struct SweSnapshot: Codable {
    /// norm(nimi) -> pelaajat (sama nimi voi esiintyä eri joukkueissa)
    var byName: [String: [SwePlayer]]
    var teamGames: [String: Int]
    /// Joukkueen viimeiset 5 ottelua, uusin ensin (pisteet nollilla)
    var teamRecent: [String: [RecentGame]]
    /// "joukkue|norm(nimi)" -> pelaajan pisteottelut joukkueen viimeisten 5 ottelun joukosta
    var recent: [String: [RecentGame]]
    /// "joukkue|norm(nimi)" -> pisteitä jokaisessa joukkueen neljästä viimeisestä ottelusta
    var hot: [String]
    var timestamp: Date
}

struct SweRosterEntry {
    var no: Int
    var name: String
    var pos: String
    var slot: String?
    var nat: String?
    var born: String?
}

private func sweName(_ s: String) -> String {
    let parts = s.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
    return parts.count == 2 ? parts[1] + " " + parts[0] : s.trimmingCharacters(in: .whitespaces)
}

private func swePos(_ raw: String) -> (String, String?) {
    let r = raw.uppercased()
    if r == "GK" || r == "G" { return ("G", nil) }
    if r == "C" || r == "CE" { return ("F", "C") }
    if r == "LW" { return ("F", "L") }
    if r == "RW" { return ("F", "R") }
    if r.hasSuffix("D") { return ("D", "D") }
    return ("F", nil)
}

private func sweDay(_ d: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: d)
}

// MARK: Kokoonpanot

/// {joukkue: [pelaajat]} sarjan Teams/Info/TeamRoster-sivulta
@MainActor
func fetchSweRoster(league: League, teams: [Team]) async -> [String: [SweRosterEntry]]? {
    guard let id = await sweLeagueID(league),
          let page = await sweFetchHTML("\(sweBase)/Teams/Info/TeamRoster/\(id)", timeout: 40) else { return nil }
    let seed = teams.filter { $0.league == league }
    var out: [String: [SweRosterEntry]] = [:]
    var cur: String? = nil
    for row in sweMatches("<tr[^>]*>(.*?)</tr>", in: page) {
        let text = sweText(row[1])
        if text.contains("[Top]") {
            // Otsikkorivillä joukkueen nimi on kahdesti
            let head = text.replacingOccurrences(of: "[Top]", with: "").trimmingCharacters(in: .whitespaces)
            let w = head.split(separator: " ").map(String.init)
            let name = (w.count % 2 == 0 && w.count > 0 && Array(w[0..<(w.count / 2)]) == Array(w[(w.count / 2)...]))
                ? w[0..<(w.count / 2)].joined(separator: " ") : head
            cur = sweResolve(name, seed: seed) ?? sweResolve(head, seed: seed)
            continue
        }
        guard let team = cur else { continue }
        let cells = sweMatches("<td\\b[^>]*?/>|<td\\b[^>]*>.*?</td>", in: row[1]).map { sweText($0[0]) }
        guard cells.count >= 8, let no = Int(cells[0]) else { continue }
        let (pos, slot) = swePos(cells[3])
        let nat = cells[7].split(whereSeparator: { $0 == " " || $0 == "/" }).first.map(String.init)
        out[team, default: []].append(SweRosterEntry(no: no, name: sweName(cells[1]), pos: pos, slot: slot,
                                                      nat: (nat?.isEmpty ?? true) ? nil : nat, born: cells[2].isEmpty ? nil : cells[2]))
    }
    return out.isEmpty ? nil : out
}

// MARK: Ottelutapahtumat

func parseSweEvents(_ html: String) -> SweEvents {
    struct GoalRow { var hs: Int; var aw: Int; var type: String; var ab: String; var detail: String }
    var goalRows: [GoalRow] = []
    var pens: [(ab: String, n: Int, m: Int)] = []
    var gk: [String] = []
    var seen = Set<String>()

    for chunk in html.components(separatedBy: "<tr").dropFirst() {
        var c = chunk
        if let r = c.range(of: "</tr>") { c = String(c[..<r.lowerBound]) }
        if let g = c.firstIndex(of: ">") { c = String(c[c.index(after: g)...]) }
        let t = sweText(c)
        if t.isEmpty { continue }
        if let m = sweMatches("^([0-9]+):([0-9]+) ([0-9]+)-([0-9]+) \\(([A-Z]+[0-9]?)\\) (\\S+) (.*)$", in: t).first, m.count > 7 {
            if seen.insert(t).inserted {
                goalRows.append(GoalRow(hs: Int(m[3]) ?? 0, aw: Int(m[4]) ?? 0, type: m[5], ab: m[6], detail: m[7]))
            }
            continue
        }
        if let m = sweMatches("^([0-9]+):([0-9]+) ([0-9]+(?:\\+[0-9]+)*) min (\\S+) ([0-9]+)\\.", in: t).first, m.count > 5 {
            let mins = m[3].split(separator: "+").compactMap { Int($0) }.reduce(0, +)
            pens.append((m[4], Int(m[5]) ?? 0, mins))
            continue
        }
        if let m = sweMatches("^(\\S{2,5}) [0-9]+\\. .+ [0-9]+,[0-9]+% \\([0-9]+/[0-9]+\\)$", in: t).first, m.count > 1 {
            if !gk.contains(m[1]) { gk.append(m[1]) }
        }
    }

    goalRows.sort { ($0.hs + $0.aw) < ($1.hs + $1.aw) }
    var side: [String: String] = [:]
    var ph = 0
    var goals: [SweGoal] = []
    for g in goalRows {
        let s = g.hs > ph ? "h" : "a"
        ph = g.hs
        side[g.ab] = s
        let detail = g.detail
        let main = (detail.range(of: "Pos. Part.").map { String(detail[..<$0.lowerBound]) } ?? detail).trimmingCharacters(in: .whitespaces)
        guard let sm = sweMatches("^([0-9]+)\\.\\s+(.+?)\\s+\\(([0-9]+)\\)\\s*(.*)$", in: main).first, sm.count > 4 else { continue }
        var ast: [SweAst] = []
        for x in sweMatches("([0-9]+)\\.\\s+([^0-9]+?)\\s*(?=[0-9]+\\.\\s|$)", in: sm[4]) where x.count > 2 {
            ast.append(SweAst(n: Int(x[1]) ?? 0, name: x[2].trimmingCharacters(in: .whitespaces)))
        }
        func nums(_ pattern: String) -> [Int] {
            guard let mm = sweMatches(pattern, in: detail).first, mm.count > 1 else { return [] }
            return mm[1].split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        goals.append(SweGoal(s: s, type: g.type, n: Int(sm[1]) ?? 0, name: sm[2].trimmingCharacters(in: .whitespaces), ast: ast,
                             pos: nums("Pos\\. Part\\.:\\s*([0-9\\s,]*?)\\s*(?:Neg\\. Part\\.|$)"),
                             neg: nums("Neg\\. Part\\.:\\s*([0-9\\s,]*)$")))
    }
    if gk.count >= 2 {
        if side[gk[0]] == nil, !side.values.contains("h") { side[gk[0]] = "h" }
        if side[gk[1]] == nil, !side.values.contains("a") { side[gk[1]] = "a" }
    }
    var pl: [SwePen] = []
    for p in pens {
        let s = side[p.ab] ?? (gk.first == p.ab ? "h" : (gk.count > 1 && gk[1] == p.ab ? "a" : nil))
        if let s { pl.append(SwePen(s: s, n: p.n, m: p.m)) }
    }
    return SweEvents(goals: goals, pens: pl)
}

private func sweEventTask(_ gid: String, _ total: Int) async -> (String, SweEvents?) {
    guard let html = await sweFetchHTML("\(sweBase)/Game/Events/\(gid)", timeout: 30) else { return (gid, nil) }
    let ev = parseSweEvents(html)
    return (gid, (ev.goals.isEmpty && total > 0) ? nil : ev)
}

/// Hakee ottelutapahtumat enintään 6 rinnakkaisella pyynnöllä. items: (ottelun tunnus, lopputuloksen maalisumma)
func fetchSweEventsBatch(_ items: [(String, Int)]) async -> [String: SweEvents] {
    var result: [String: SweEvents] = [:]
    var it = items.makeIterator()
    await withTaskGroup(of: (String, SweEvents?).self) { group in
        for _ in 0..<6 {
            if let item = it.next() { group.addTask { await sweEventTask(item.0, item.1) } }
        }
        while let done = await group.next() {
            if let ev = done.1 { result[done.0] = ev }
            if let item = it.next() { group.addTask { await sweEventTask(item.0, item.1) } }
        }
    }
    return result
}

// MARK: Yhdistäminen

@MainActor
func aggregateSwe(league: League, teams: [Team], games: [SweGame], cache: [String: SweEvents],
                  roster: [String: [SweRosterEntry]]) -> SweSnapshot {
    struct TL { var gid: String; var date: String; var opp: String; var home: Bool; var at: Date }
    struct PG { var goals = 0; var assists = 0; var pp = 0 }
    func key(_ team: String, _ name: String) -> String { team + "|" + AppStore.norm(name) }

    var numMap: [String: [Int: String]] = [:]
    var ents: [String: SwePlayer] = [:]
    var perGame: [String: [String: PG]] = [:]
    var teamGames: [String: Int] = [:]
    var teamList: [String: [TL]] = [:]

    for (team, list) in roster {
        numMap[team] = [:]
        for r in list {
            numMap[team]?[r.no] = r.name
            ents[key(team, r.name)] = SwePlayer(name: r.name, team: team, number: r.no, pos: r.pos, slot: r.slot, nat: r.nat, born: r.born)
        }
    }
    func ensure(_ team: String, _ name: String, _ no: Int?) {
        let k = key(team, name)
        if ents[k] == nil { ents[k] = SwePlayer(name: name, team: team, number: no) }
    }
    func bump(_ gid: String, _ team: String, _ name: String, _ f: (inout PG) -> Void) {
        let k = key(team, name)
        var pg = perGame[k] ?? [:]
        var r = pg[gid] ?? PG()
        f(&r)
        pg[gid] = r
        perGame[k] = pg
    }

    let fin = games.filter { $0.final && $0.gid != nil && cache[$0.gid!] != nil }.sorted { $0.date < $1.date }
    for g in fin {
        guard let gid = g.gid, let ev = cache[gid] else { continue }
        let day = sweDay(g.date)
        for t in [g.home, g.away] {
            teamGames[t, default: 0] += 1
            teamList[t, default: []].append(TL(gid: gid, date: day, opp: t == g.home ? g.away : g.home, home: t == g.home, at: g.date))
        }
        for gl in ev.goals {
            let team = gl.s == "h" ? g.home : g.away
            let opp = gl.s == "h" ? g.away : g.home
            let pp = gl.type.hasPrefix("PP")
            let sn = sweName(gl.name)
            ensure(team, sn, gl.n)
            ents[key(team, sn)]?.goals += 1
            bump(gid, team, sn) { $0.goals += 1; if pp { $0.pp += 1 } }
            if pp { ents[key(team, sn)]?.ppPoints += 1 }
            for a in gl.ast {
                let an = sweName(a.name)
                ensure(team, an, a.n)
                ents[key(team, an)]?.assists += 1
                bump(gid, team, an) { $0.assists += 1; if pp { $0.pp += 1 } }
                if pp { ents[key(team, an)]?.ppPoints += 1 }
            }
            if !pp && gl.type != "PS" {
                for n in gl.pos {
                    if let nm = numMap[team]?[n], var e = ents[key(team, nm)], e.pos != "G" { e.plusMinus += 1; ents[key(team, nm)] = e }
                }
                for n in gl.neg {
                    if let nm = numMap[opp]?[n], var e = ents[key(opp, nm)], e.pos != "G" { e.plusMinus -= 1; ents[key(opp, nm)] = e }
                }
            }
        }
        for p in ev.pens {
            let team = p.s == "h" ? g.home : g.away
            if let nm = numMap[team]?[p.n], ents[key(team, nm)] != nil { ents[key(team, nm)]?.pim += p.m }
        }
    }

    var byName: [String: [SwePlayer]] = [:]
    for e in ents.values { byName[AppStore.norm(e.name), default: []].append(e) }

    var teamRecent: [String: [RecentGame]] = [:]
    var lastN: [String: [TL]] = [:]
    for (t, l) in teamList {
        let sorted = l.sorted { $0.at > $1.at }
        lastN[t] = Array(sorted.prefix(5))
        teamRecent[t] = sorted.prefix(5).map { RecentGame(date: $0.date, opponent: $0.opp, home: $0.home, goals: 0, assists: 0, pp: 0) }
    }
    var recent: [String: [RecentGame]] = [:]
    var hot: [String] = []
    for (k, pg) in perGame {
        let team = String(k[..<(k.firstIndex(of: "|") ?? k.endIndex)])
        let tr = lastN[team] ?? []
        let mine = tr.compactMap { g -> RecentGame? in
            guard let r = pg[g.gid] else { return nil }
            return RecentGame(date: g.date, opponent: g.opp, home: g.home, goals: r.goals, assists: r.assists, pp: r.pp)
        }
        if !mine.isEmpty { recent[k] = mine }
        let last4 = (teamList[team] ?? []).sorted { $0.at > $1.at }.prefix(4)
        if last4.count == 4, last4.allSatisfy({ (pg[$0.gid]?.goals ?? 0) + (pg[$0.gid]?.assists ?? 0) > 0 }) { hot.append(k) }
    }
    return SweSnapshot(byName: byName, teamGames: teamGames, teamRecent: teamRecent, recent: recent, hot: hot, timestamp: Date())
}
