import Foundation

// MARK: - NHL-ottelun maalit ja kokoonpano (play-by-play + boxscore)

struct NHLPBP: Decodable {
    struct Name: Decodable { let `default`: String? }
    struct Team: Decodable { let id: Int?; let abbrev: String? }
    struct Period: Decodable { let number: Int?; let periodType: String? }
    struct Details: Decodable {
        let eventOwnerTeamId: Int?
        let scoringPlayerId: Int?
        let assist1PlayerId: Int?
        let assist2PlayerId: Int?
        let homeScore: Int?
        let awayScore: Int?
        let committedByPlayerId: Int?
        let descKey: String?
        let duration: Int?
        let highlightClipSharingUrl: String?
        let highlightClip: Int?
    }
    struct Outcome: Decodable { let lastPeriodType: String? }
    struct Play: Decodable {
        let periodDescriptor: Period?
        let timeInPeriod: String?
        let situationCode: String?
        let typeDescKey: String?
        let details: Details?
    }
    struct Roster: Decodable {
        let teamId: Int?
        let playerId: Int?
        let firstName: Name?
        let lastName: Name?
        let sweaterNumber: Int?
        let positionCode: String?
    }
    let homeTeam: Team?
    let awayTeam: Team?
    let venue: Name?
    let plays: [Play]?
    let rosterSpots: [Roster]?
    let gameOutcome: Outcome?
}

private struct NHLLineupBox: Decodable {
    struct BP: Decodable {
        let playerId: Int?
        let sweaterNumber: Int?
        let name: NHLPBP.Name?
        let position: String?
        let toi: String?
    }
    struct TS: Decodable {
        let forwards: [BP]?
        let defense: [BP]?
        let goalies: [BP]?
    }
    struct BG: Decodable { let awayTeam: TS?; let homeTeam: TS? }
    let playerByGameStats: BG?
}

private func nhlGet<T: Decodable>(_ path: String, as type: T.Type) async -> T? {
    guard let url = URL(string: "https://api-web.nhle.com/v1/gamecenter/\(path)") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 20
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}

func fetchNHLPlayByPlay(gameId: Int) async -> NHLPBP? {
    await nhlGet("\(gameId)/play-by-play", as: NHLPBP.self)
}

private func nhlClock(_ t: Int) -> String { String(format: "%d:%02d", t / 60, t % 60) }

private func nhlSeconds(_ s: String?) -> Int {
    let p = (s ?? "").split(separator: ":").compactMap { Int($0) }
    return p.count == 2 ? p[0] * 60 + p[1] : 0
}

private func nhlName(_ r: NHLPBP.Roster?) -> String {
    guard let r else { return "?" }
    return [r.firstName?.default, r.lastName?.default].compactMap { $0 }.joined(separator: " ")
}

/// Maalit (tekijä, syöttäjät, ylivoima, tilanne) ottelun play-by-playsta.
func nhlGameDetail(_ p: NHLPBP) -> LiigaGameDetail {
    var d = LiigaGameDetail()
    var roster: [Int: NHLPBP.Roster] = [:]
    for r in p.rosterSpots ?? [] { if let id = r.playerId { roster[id] = r } }
    let isSO = (p.gameOutcome?.lastPeriodType ?? "").uppercased() == "SO"
    var finalH = 0, finalA = 0
    for play in p.plays ?? [] where play.typeDescKey == "goal" {
        if (play.periodDescriptor?.periodType ?? "").uppercased() == "SO" { continue }
        finalH = max(finalH, play.details?.homeScore ?? 0)
        finalA = max(finalA, play.details?.awayScore ?? 0)
    }
    for play in p.plays ?? [] where play.typeDescKey == "goal" {
        guard let det = play.details else { continue }
        if (play.periodDescriptor?.periodType ?? "").uppercased() == "SO" { continue }
        let n = play.periodDescriptor?.number ?? 1
        let secs = (n - 1) * 1200 + nhlSeconds(play.timeInPeriod)
        let home = det.eventOwnerTeamId == p.homeTeam?.id
        // situationCode: [vieras MV][vieras kenttäpelaajat][koti kenttäpelaajat][koti MV]
        // MV = 0 tarkoittaa tyhjää maalia: ylimääräinen hyökkääjä lasketaan pois ennen ylivoiman vertailua.
        let digits = Array(play.situationCode ?? "").compactMap { Int(String($0)) }
        var tags: [String] = []
        if digits.count == 4 {
            let aG = digits[0], hG = digits[3]
            let aS = digits[1] - (aG == 0 ? 1 : 0)
            let hS = digits[2] - (hG == 0 ? 1 : 0)
            let mine = home ? hS : aS
            let theirs = home ? aS : hS
            if (home ? aG : hG) == 0 { tags.append("TM") }
            if mine > theirs { tags.append("YV") } else if mine < theirs { tags.append("AV") }
        }
        if !isSO, finalH != finalA, let hs = det.homeScore, let aws = det.awayScore {
            let homeWon = finalH > finalA
            if home == homeWon, (home ? hs : aws) == (homeWon ? finalA : finalH) + 1 { tags.append("VM") }
        }
        let assists = [det.assist1PlayerId, det.assist2PlayerId].compactMap { $0 }.map { nhlName(roster[$0]) }
        var line = LiigaGoalLine(seconds: secs, period: n, home: home,
                                 scorer: det.scoringPlayerId.map { nhlName(roster[$0]) } ?? "?",
                                 assists: assists, homeScore: det.homeScore, awayScore: det.awayScore,
                                 powerPlay: tags.contains("YV"))
        line.tags = tags
        if let clip = det.highlightClip {
            line.video = URL(string: "https://players.brightcove.net/6415718365001/default_default/index.html?videoId=\(clip)&autoplay=true&muted=false&applicationId=nhl")
        } else {
            line.video = det.highlightClipSharingUrl.flatMap { URL(string: $0) }
        }
        d.goals.append(line)
    }
    d.rink = p.venue?.default
    return d
}

func fetchNHLGameDetail(gameId: Int) async -> LiigaGameDetail? {
    guard let p = await fetchNHLPlayByPlay(gameId: gameId) else { return nil }
    return nhlGameDetail(p)
}

// MARK: - Lisätiedot: erätilastot, jäähyt, tilastovertailu, tähdet, rankkarit

struct NHLPenaltyLine: Identifiable {
    let id = UUID()
    let period: Int
    let seconds: Int
    let home: Bool
    let player: String
    let reason: String
    let minutes: Int
}

struct NHLPeriodLine: Identifiable {
    var id: String { label }
    let label: String
    let order: Int
    var hGoals: Int?
    var aGoals: Int?
    var hShots: Int?
    var aShots: Int?
}

struct NHLStatLine: Identifiable {
    var id: String { label }
    let label: String
    let home: String
    let away: String
    let hv: Double
    let av: Double
}

struct NHLStarLine: Identifiable {
    var id: Int { star }
    let star: Int
    let name: String
    let home: Bool?
    let detail: String
}

struct NHLShootoutLine: Identifiable {
    let id: Int
    let home: Bool
    let name: String
    let scored: Bool
}

struct NHLGoalieLine: Identifiable {
    let id = UUID()
    let home: Bool
    let name: String
    let line: String
}

struct NHLExtras {
    var outcome: String?
    var penalties: [NHLPenaltyLine] = []
    var periods: [NHLPeriodLine] = []
    var totalGoals: (h: Int, a: Int)?
    var stats: [NHLStatLine] = []
    var stars: [NHLStarLine] = []
    var shootout: [NHLShootoutLine] = []
}

private let nhlPenaltyFi: [String: String] = [
    "hooking": "koukkaus", "holding": "kiinnipito", "tripping": "kampitus", "slashing": "mailalyönti",
    "high-sticking": "korkea maila", "interference": "estäminen", "cross-checking": "ristiintaklaus",
    "roughing": "karkea peli", "boarding": "laitaan ajo", "elbowing": "kyynärpää",
    "delaying-game": "pelin viivytys", "too-many-men-on-the-ice": "liikaa pelaajia", "fighting": "tappelu",
    "unsportsmanlike-conduct": "epäurheilijamainen käytös", "charging": "taklaus hyökkäämällä",
    "closing-hand-on-puck": "kiekon peittäminen", "holding-the-stick": "mailan pitely",
    "illegal-check-to-head": "kielletty taklaus päähän", "kneeing": "polvitaklaus",
    "hi-stick": "korkea maila", "embellishment": "näyttelu", "goalie-leaves-crease": "maalivahti pois alueeltaan",
    "puck-over-glass-delay-of-game": "kiekko katsomoon", "delay-of-game": "pelin viivytys",
    "misconduct": "pelirangaistus", "game-misconduct": "ottelurangaistus", "spearing": "keihästys",
    "clipping": "polviin taklaus", "illegal-equipment": "kielletty varuste", "bench": "vaihtopenkki",
    "face-off-violation": "aloitusrike", "playing-without-a-helmet": "ei kypärää"
]

private func nhlPenaltyReason(_ key: String?) -> String {
    guard let key, !key.isEmpty else { return "jäähy" }
    if let fi = nhlPenaltyFi[key] { return fi }
    return key.replacingOccurrences(of: "-", with: " ")
}

func nhlPenalties(_ p: NHLPBP) -> [NHLPenaltyLine] {
    var roster: [Int: NHLPBP.Roster] = [:]
    for r in p.rosterSpots ?? [] { if let id = r.playerId { roster[id] = r } }
    var out: [NHLPenaltyLine] = []
    for play in p.plays ?? [] where play.typeDescKey == "penalty" {
        guard let det = play.details else { continue }
        let n = play.periodDescriptor?.number ?? 1
        let home = det.eventOwnerTeamId == p.homeTeam?.id
        let who = det.committedByPlayerId.map { nhlName(roster[$0]) } ?? "Joukkue"
        out.append(NHLPenaltyLine(period: n, seconds: (n - 1) * 1200 + nhlSeconds(play.timeInPeriod), home: home,
                                  player: who, reason: nhlPenaltyReason(det.descKey), minutes: det.duration ?? 2))
    }
    return out
}

private func nhlRawData(_ path: String) async -> Data? {
    guard let url = URL(string: "https://api-web.nhle.com/v1/gamecenter/\(path)") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 20
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
    return data
}

private func jNum(_ a: Any?) -> Double? {
    if let n = a as? NSNumber { return n.doubleValue }
    if let s = a as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
    return nil
}

private func jStr(_ a: Any?) -> String? {
    if let s = a as? String { return s }
    if let d = a as? [String: Any] { return d["default"] as? String }
    return nil
}

private func jFind(_ srcs: [[String: Any]?], _ key: String) -> Any? {
    for s in srcs { if let v = s?[key], !(v is NSNull) { return v } }
    return nil
}

private func nhlPeriodLabel(_ n: Int, _ t: String) -> (String, Int) {
    if t == "SO" { return ("RL", 100) }
    if t == "OT" { return (n > 4 ? "JA\(n - 3)" : "JA", n) }
    return ("\(n).", n)
}

private func nhlPeriodKey(_ d: Any?) -> (String, Int)? {
    guard let pd = d as? [String: Any], let n = jNum(pd["number"]) else { return nil }
    return nhlPeriodLabel(Int(n), (pd["periodType"] as? String ?? "REG").uppercased())
}

/// Erätilastot, tilastovertailu, tähdet ja rankkarit right-railista ja landingista (kenttiä luetaan joustavasti).
private func nhlParseSummary(rr: Data?, ln: Data?, homeAbbrev: String?, awayAbbrev: String?) -> NHLExtras {
    var ex = NHLExtras()
    let rrObj = rr.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let lnObj = ln.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let srcs: [[String: Any]?] = [rrObj, lnObj?["summary"] as? [String: Any], lnObj]

    // Erätilanne ja laukaukset
    var periods: [String: NHLPeriodLine] = [:]
    if let ls = jFind(srcs, "linescore") as? [String: Any] {
        for e in ls["byPeriod"] as? [[String: Any]] ?? [] {
            guard let (label, order) = nhlPeriodKey(e["periodDescriptor"]) else { continue }
            var l = periods[label] ?? NHLPeriodLine(label: label, order: order)
            l.hGoals = jNum(e["home"]).map { Int($0) }
            l.aGoals = jNum(e["away"]).map { Int($0) }
            periods[label] = l
        }
        if let t = ls["totals"] as? [String: Any], let h = jNum(t["home"]), let a = jNum(t["away"]) {
            ex.totalGoals = (Int(h), Int(a))
        }
    }
    for e in jFind(srcs, "shotsByPeriod") as? [[String: Any]] ?? [] {
        guard let (label, order) = nhlPeriodKey(e["periodDescriptor"]) else { continue }
        var l = periods[label] ?? NHLPeriodLine(label: label, order: order)
        l.hShots = jNum(e["home"]).map { Int($0) }
        l.aShots = jNum(e["away"]).map { Int($0) }
        periods[label] = l
    }
    ex.periods = periods.values.sorted { $0.order < $1.order }

    // Tilastovertailu
    let cats: [(String, String)] = [
        ("sog", "Laukaukset"), ("powerPlay", "Ylivoimat"), ("pim", "Jäähyminuutit"), ("hits", "Taklaukset"),
        ("blockedShots", "Blokatut laukaukset"), ("faceoffWinningPctg", "Aloitusvoitot"),
        ("giveaways", "Menetetyt kiekot"), ("takeaways", "Riistot")]
    func shown(_ cat: String, _ v: Any?) -> (String, Double)? {
        if let s = v as? String {
            let first = s.split(separator: "/").first.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if let d = Double(s.replacingOccurrences(of: ",", with: ".")), cat == "faceoffWinningPctg" {
                let pct = d <= 1 ? d * 100 : d
                return (String(format: "%.0f %%", pct), pct)
            }
            return (s, first ?? Double(s) ?? 0)
        }
        guard let d = jNum(v) else { return nil }
        if cat == "faceoffWinningPctg" {
            let pct = d <= 1 ? d * 100 : d
            return (String(format: "%.0f %%", pct), pct)
        }
        return (String(Int(d)), d)
    }
    let rows = jFind(srcs, "teamGameStats") as? [[String: Any]] ?? []
    for (key, label) in cats {
        guard let r = rows.first(where: { ($0["category"] as? String) == key }),
              let h = shown(key, r["homeValue"]), let a = shown(key, r["awayValue"]) else { continue }
        ex.stats.append(NHLStatLine(label: label, home: h.0, away: a.0, hv: h.1, av: a.1))
    }

    // Kolme tähteä
    for e in jFind(srcs, "threeStars") as? [[String: Any]] ?? [] {
        let name = jStr(e["name"]) ?? [jStr(e["firstName"]), jStr(e["lastName"])].compactMap { $0 }.joined(separator: " ")
        guard !name.isEmpty else { continue }
        let abbr = jStr(e["teamAbbrev"])
        let home: Bool? = abbr == nil ? nil : (abbr == homeAbbrev ? true : (abbr == awayAbbrev ? false : nil))
        var detail = ""
        if (e["position"] as? String) == "G" {
            if let sp = jNum(e["savePctg"]) { detail = "torjunta-% " + String(format: "%.3f", sp).replacingOccurrences(of: "0.", with: ".") }
        } else {
            let g = jNum(e["goals"]).map { Int($0) } ?? 0
            let a = jNum(e["assists"]).map { Int($0) } ?? 0
            detail = "\(g) + \(a)"
        }
        ex.stars.append(NHLStarLine(star: Int(jNum(e["star"]) ?? Double(ex.stars.count + 1)), name: name, home: home, detail: detail))
    }
    ex.stars.sort { $0.star < $1.star }

    // Rankkarit
    var i = 0
    for e in jFind(srcs, "shootout") as? [[String: Any]] ?? [] {
        let name = [jStr(e["firstName"]), jStr(e["lastName"])].compactMap { $0 }.joined(separator: " ")
        guard !name.isEmpty else { continue }
        let abbr = jStr(e["teamAbbrev"])
        i += 1
        ex.shootout.append(NHLShootoutLine(id: i, home: abbr == homeAbbrev, name: name,
                                           scored: (e["result"] as? String ?? "") == "goal"))
    }
    return ex
}

/// Maalit + lisätiedot yhdellä kertaa.
func fetchNHLGameBundle(gameId: Int) async -> (detail: LiigaGameDetail, extras: NHLExtras)? {
    async let pbpT = fetchNHLPlayByPlay(gameId: gameId)
    async let rrT = nhlRawData("\(gameId)/right-rail")
    async let lnT = nhlRawData("\(gameId)/landing")
    guard let p = await pbpT else { return nil }
    let rr = await rrT
    let ln = await lnT
    var ex = nhlParseSummary(rr: rr, ln: ln, homeAbbrev: p.homeTeam?.abbrev, awayAbbrev: p.awayTeam?.abbrev)
    ex.penalties = nhlPenalties(p)
    switch (p.gameOutcome?.lastPeriodType ?? "").uppercased() {
    case "REG": ex.outcome = "normaaliajalla"
    case "OT": ex.outcome = "jatkoajalla"
    case "SO": ex.outcome = "rankkareilla"
    default: break
    }
    return (nhlGameDetail(p), ex)
}

/// Kokoonpano boxscoresta. NHL ei julkaise ketjuja, joten ne arvioidaan peliajan perusteella.
func fetchNHLLineup(gameId: Int) async -> LiigaLineup? {
    async let pbpTask = fetchNHLPlayByPlay(gameId: gameId)
    async let boxTask = nhlGet("\(gameId)/boxscore", as: NHLLineupBox.self)
    guard let box = await boxTask, let stats = box.playerByGameStats else { return nil }
    let pbp = await pbpTask
    var roster: [Int: NHLPBP.Roster] = [:]
    for r in pbp?.rosterSpots ?? [] { if let id = r.playerId { roster[id] = r } }

    // Maalit ja syötöt pelaajittain
    var goals: [Int: [GoalNote]] = [:]
    var assists: [Int: [GoalNote]] = [:]
    for play in pbp?.plays ?? [] where play.typeDescKey == "goal" {
        guard let det = play.details, (play.periodDescriptor?.periodType ?? "").uppercased() != "SO" else { continue }
        let n = play.periodDescriptor?.number ?? 1
        let note = GoalNote(time: nhlClock((n - 1) * 1200 + nhlSeconds(play.timeInPeriod)), period: n,
                            score: "\(det.homeScore ?? 0)–\(det.awayScore ?? 0)")
        if let s = det.scoringPlayerId { goals[s, default: []].append(note) }
        for a in [det.assist1PlayerId, det.assist2PlayerId].compactMap({ $0 }) { assists[a, default: []].append(note) }
    }

    func build(_ ts: NHLLineupBox.TS?, team: String) -> [LineupPlayer] {
        guard let ts else { return [] }
        var out: [LineupPlayer] = []
        func make(_ b: NHLLineupBox.BP, role: String, line: Int) -> LineupPlayer {
            let r = b.playerId.flatMap { roster[$0] }
            let last = r?.lastName?.default ?? (b.name?.default.map { $0.components(separatedBy: ". ").last ?? $0 } ?? "?")
            var lp = LineupPlayer(id: b.playerId ?? Int.random(in: 1...Int.max), name: last,
                                  jersey: b.sweaterNumber ?? r?.sweaterNumber, role: role, line: line, captain: false, alt: false)
            lp.first = r?.firstName?.default ?? ""
            lp.team = team
            if let id = b.playerId { lp.goals = goals[id] ?? []; lp.assists = assists[id] ?? [] }
            return lp
        }
        let fw = (ts.forwards ?? []).sorted { nhlSeconds($0.toi) > nhlSeconds($1.toi) }
        for g in 0..<4 {
            guard g * 3 < fw.count else { break }
            var rest = Array(fw[(g * 3)..<min(g * 3 + 3, fw.count)])
            func take(_ pos: String) -> NHLLineupBox.BP? {
                if let i = rest.firstIndex(where: { $0.position == pos }) { return rest.remove(at: i) }
                return rest.isEmpty ? nil : rest.removeFirst()
            }
            if let c = take("C") { out.append(make(c, role: "KH", line: g + 1)) }
            if let l = take("L") { out.append(make(l, role: "VL", line: g + 1)) }
            if let r = take("R") { out.append(make(r, role: "OL", line: g + 1)) }
        }
        if fw.count > 12 {
            for (i, b) in fw.enumerated() where i >= 12 { out.append(make(b, role: "\(i + 1). H", line: 5)) }
        }
        let d = (ts.defense ?? []).sorted { nhlSeconds($0.toi) > nhlSeconds($1.toi) }
        for (i, b) in d.enumerated() {
            if i < 6 { out.append(make(b, role: i % 2 == 0 ? "VP" : "OP", line: i / 2 + 1)) }
            else { out.append(make(b, role: "\(i + 1). P", line: 4)) }
        }
        let gk = (ts.goalies ?? []).sorted { nhlSeconds($0.toi) > nhlSeconds($1.toi) }
        for (i, b) in gk.enumerated() { out.append(make(b, role: "MV", line: i + 1)) }
        return out
    }
    var res = LiigaLineup(home: build(stats.homeTeam, team: "home"), away: build(stats.awayTeam, team: "away"))
    res.note = "NHL ei julkaise ketjuja: ketjut ja puolustusparit on arvioitu pelaajien peliajan perusteella."
    return res
}
