import Foundation
import UserNotifications
import Observation
import AppKit

/// Näyttää ilmoitukset myös silloin, kun sovellus on etualalla.
final class NotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Onko Liigassa käynnissä olevia otteluita (kevyt kysely: vain tämän päivän ottelut).
func liigaHasLiveGames() async -> Bool {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(identifier: "Europe/Helsinki")
    df.dateFormat = "yyyy-MM-dd"
    guard let url = URL(string: "https://liiga.fi/api/v2/games?tournament=runkosarja&date=\(df.string(from: Date()))") else { return false }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 10
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let games = try? JSONDecoder().decode([LiigaGame].self, from: data) else { return false }
    return games.contains { $0.started?.value == true && $0.ended?.value != true }
}

/// Hakee yhden NHL-joukkueen pelaajatilastot NHL:n tilastopalvelusta.
func fetchNHLTeam(_ team: Team) async -> (Team, [NHLSkater])? {
    guard let url = URL(string: "https://api-web.nhle.com/v1/club-stats/\(team.abbr)/now") else { return nil }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 15
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let stats = try JSONDecoder().decode(NHLClubStats.self, from: data)
        return (team, stats.skaters)
    } catch {
        return nil
    }
}

/// Hakee yhden NHL-joukkueen kokoonpanon (numerot, syntymämaat).
func fetchNHLRoster(abbr: String) async -> [NHLRosterPlayer] {
    guard let url = URL(string: "https://api-web.nhle.com/v1/roster/\(abbr)/current") else { return [] }
    var req = URLRequest(url: url)
    req.timeoutInterval = 15
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let r = try? JSONDecoder().decode(NHLRoster.self, from: data) else { return [] }
    return r.all
}

/// Onko pelaajalla piste neljässä viimeisessä pelissä (NHL:n ottelulogi).
func nhlHotCheck(key: String, id: Int) async -> (String, Bool)? {
    guard let url = URL(string: "https://api-web.nhle.com/v1/player/\(id)/game-log/now") else { return nil }
    var req = URLRequest(url: url)
    req.timeoutInterval = 15
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let log = try? JSONDecoder().decode(NHLGameLog.self, from: data) else { return nil }
    let last4 = Array((log.gameLog ?? []).prefix(4))
    // Liekki vain, jos pelaaja on tehnyt vähintään yhden pisteen JOKAISESSA neljästä viimeisestä pelistä
    return (key, last4.count == 4 && last4.allSatisfy { ($0.goals ?? 0) + ($0.assists ?? 0) >= 1 })
}

/// Onko NHL:ssä käynnissä olevia otteluita (kevyt kysely).
func nhlHasLiveGames() async -> Bool {
    guard let url = URL(string: "https://api-web.nhle.com/v1/schedule/now") else { return false }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 10
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let week = obj["gameWeek"] as? [[String: Any]] else { return false }
    for day in week {
        for g in (day["games"] as? [[String: Any]]) ?? [] {
            let st = (g["gameState"] as? String ?? "").uppercased()
            if st == "LIVE" || st == "CRIT" { return true }
        }
    }
    return false
}

/// Hakee kaikkien NHL-pelaajien ylivoimapisteet (playerId -> ylivoimapisteet).
func fetchNHLPowerPlay() async -> [Int: Int] {
    guard let url = URL(string: "https://api.nhle.com/stats/rest/en/skater/summary?limit=-1&cayenneExp=seasonId=20262027%20and%20gameTypeId=2") else { return [:] }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 20
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let r = try? JSONDecoder().decode(NHLSummaryResponse.self, from: data) else { return [:] }
    var out: [Int: Int] = [:]
    for row in r.data ?? [] { if let id = row.playerId, let pp = row.ppPoints { out[id] = pp } }
    return out
}

/// Hakee Liigan kauden ottelut (maalit, syöttäjät ja joukkuelogot).
func fetchLiigaGames() async -> [LiigaGame]? {
    guard let url = URL(string: "https://liiga.fi/api/v2/games?tournament=runkosarja&season=2027") else { return nil }
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 30
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try JSONDecoder().decode([LiigaGame].self, from: data)
    } catch {
        return nil
    }
}

/// Liigan viralliset pelaajatilastot (kaikki pelaajat, myös pisteettömät).
struct LiigaStat: Decodable {
    let playerId: Int?
    let teamName: String?
    let role: String?
    let firstName: String?
    let lastName: String?
    let nationality: String?
    let jersey: Int?
    let goalkeeper: Bool?
    let playedGames: Int?
    let goals: Int?
    let assists: Int?
    let penaltyMinutes: Int?
    let plusMinus: Int?
    let shots: Int?
}

func fetchLiigaPlayerStats() async -> [LiigaStat]? {
    guard let url = URL(string: "https://liiga.fi/api/v2/players/stats/summed/2027/2027/runkosarja/true?dataType=basicStats") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 25
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let list = try? JSONDecoder().decode([LiigaStat].self, from: data) else { return nil }
    return list.filter { $0.goalkeeper != true && $0.role != "M" }
}

/// Hakee sarjan pelaajatilastot Elite Prospectsin rajapinnasta (sivutettuna, enintään 5 × 1000 riviä).
/// Palauttaa rivit tai virheselitteen (HTTP-koodi / dekoodausvirhe), jotta tilariville saadaan syy.
func fetchEPLeague(slug: String, key: String, season: String = "2026-2027") async -> (rows: [EPRow]?, error: String?) {
    var all: [EPRow] = []
    for page in 0..<5 {
        var comps = URLComponents(string: "https://api.eliteprospects.com/v1/leagues/\(slug)/player-stats")!
        comps.queryItems = [
            URLQueryItem(name: "season", value: season),
            URLQueryItem(name: "limit", value: "1000"),
            URLQueryItem(name: "offset", value: String(page * 1000)),
            URLQueryItem(name: "fields", value: "player,team,regularStats.GP,regularStats.G,regularStats.A,regularStats.PIM,regularStats.PM"),
            URLQueryItem(name: "apiKey", value: key),
        ]
        guard let url = comps.url else { return (nil, "virheellinen osoite") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return (page == 0 ? nil : all, "ei vastausta") }
            guard http.statusCode == 200 else {
                let body = String(data: data.prefix(160), encoding: .utf8)?.replacingOccurrences(of: "\n", with: " ") ?? ""
                return (page == 0 ? nil : all, "HTTP \(http.statusCode) \(body)")
            }
            let rows = try JSONDecoder().decode(EPResponse.self, from: data).data ?? []
            all += rows
            if rows.count < 1000 { break }
        } catch let e as DecodingError {
            return (page == 0 ? nil : all, "vastauksen luku epäonnistui (\(e.localizedDescription))")
        } catch {
            return (page == 0 ? nil : all, error.localizedDescription)
        }
    }
    return (all, all.isEmpty ? "tyhjä vastaus (ei pelaajia kaudelle 2026-2027)" : nil)
}

@MainActor
@Observable
final class AppStore {
    // Staattinen data
    let teams: [Team]
    let teamByName: [String: Team]
    let teamByAbbr: [String: Team]
    private let seedPlayers: [Player]

    // Yhdistetty näkymä (siemen + live + omat muokkaukset)
    private(set) var players: [Player] = []

    // Tallennettu tila
    var state = AppState()

    // UI-tila
    var nhlStatus = "NHL: ei haettu"
    var liigaStatus = "Liiga: ei haettu"
    var ahlStatus = "AHL: ei haettu"
    var mestisStatus = "Mestis: ei haettu"
    var epStatus = "SHL/HA: ei haettu"
    var hasEPKey = Keychain.get("eliteprospects") != nil
    private var lastEPFetch: Date?
    /// SHL/HA näkyy yläpalkissa vain onnistuneen haun jälkeen; virheet näkyvät Asetukset-ikkunassa.
    var epOK: Bool { epStatus.contains("päivitetty") || epStatus.contains("tallennettu") }
    var liveStatus: String { nhlStatus + " · " + liigaStatus + " · " + ahlStatus + " · " + mestisStatus + (hasEPKey && epOK ? " · " + epStatus : "") }
    var isRefreshing = false
    var toast: String?

    init() {
        let parsed = AppStore.parseSeed()
        teams = parsed.teams
        seedPlayers = parsed.players
        teamByName = Dictionary(uniqueKeysWithValues: parsed.teams.map { ($0.name, $0) })
        teamByAbbr = Dictionary(uniqueKeysWithValues: parsed.teams.filter { $0.league == .nhl }.map { ($0.abbr, $0) })
        loadState()
        UNUserNotificationCenter.current().delegate = notifDelegate
        if notifyEnabled { requestNotificationAuth() }
        if let ts = state.liveEP?.values.map(\.timestamp).max() {
            epStatus = "SHL/HA tallennettu " + AppStore.timeString(ts)
            lastEPFetch = ts
        }
        if let ts = state.liveMestis?.timestamp {
            mestisStatus = "Mestis tallennettu " + AppStore.timeString(ts)
        }
        if let ts = state.liveAHL?.timestamp {
            ahlStatus = "AHL tallennettu " + AppStore.timeString(ts)
        }
        if let ts = state.liveLiiga?.timestamp {
            liigaStatus = "Liiga tallennettu " + AppStore.timeString(ts)
        }
        if let ts = state.live?.timestamp {
            nhlStatus = "NHL tallennettu " + AppStore.timeString(ts)
        }
        rebuild()
    }

    // MARK: Siemendata

    private static func parseSeed() -> (teams: [Team], players: [Player]) {
        var teams: [Team] = []
        for line in SeedData.teamsRaw.split(separator: "\n") {
            let c = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard c.count >= 3, let lg = League(rawValue: c[0]) else { continue }
            let flag: String
            switch lg {
            case .nhl: flag = (c.count > 3 && c[3] == "CA") ? "🇨🇦" : "🇺🇸"
            case .liiga, .mestis: flag = "🇫🇮"
            case .shl, .allsvenskan: flag = "🇸🇪"
            case .ahl: flag = (c.count > 3 && c[3] == "CA") ? "🇨🇦" : "🇺🇸"
            }
            teams.append(Team(name: c[1], abbr: c[2], league: lg, flag: flag))
        }
        let byName = Dictionary(uniqueKeysWithValues: teams.map { ($0.name, $0) })

        var players: [Player] = []
        for (i, line) in SeedData.rosterRaw.split(separator: "\n").enumerated() {
            let c = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard c.count >= 2, let team = byName[c[0]] else { continue }
            func field(_ idx: Int) -> String? { idx < c.count && !c[idx].isEmpty ? c[idx] : nil }
            let id = field(7) ?? "t-\(i)"
            var p = Player(id: id, name: c[1], team: team.name, league: team.league, flag: team.flag,
                           pos: field(2), nat: field(3), born: nil, shoots: nil,
                           games: field(4).flatMap { Int($0) }, goals: field(5).flatMap { Int($0) },
                           assists: field(6).flatMap { Int($0) }, pim: nil, plusMinus: nil)
            if let m = SeedData.meta[id] {
                if let nat = m.nat { p.nat = nat }
                p.born = m.born
                p.shoots = m.shoots
            }
            players.append(p)
        }
        return (teams, players)
    }

    // MARK: Tallennus

    private static var stateURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JaakiekkoTilastot", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("state.json")
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: AppStore.stateURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let s = try? decoder.decode(AppState.self, from: data) { state = s }
    }

    func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) {
            try? data.write(to: AppStore.stateURL, options: .atomic)
        }
    }

    // MARK: Yhdistäminen

    static func norm(_ s: String) -> String {
        let folded = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        let letters = folded.map { $0.isLetter ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }

    private func liveFor(_ p: Player) -> (entry: LiveEntry, team: Team?)? {
        guard p.league == .nhl, let list = state.live?.byName[AppStore.norm(p.name)] else { return nil }
        let abbr = teamByName[p.team]?.abbr
        let cand = list.filter { e in
            guard let pos = p.pos else { return true }
            return (pos == "D") == (e.pos == "D")
        }
        let match = cand.first(where: { $0.abbr == abbr }) ?? (cand.count == 1 ? cand[0] : nil)
        guard let entry = match else { return nil }
        let moved = entry.abbr != abbr ? teamByAbbr[entry.abbr] : nil
        return (entry, moved)
    }

    func rebuild() {
        let custom = state.customPlayers.compactMap { $0.toPlayer() }
        var out: [Player] = []
        out.reserveCapacity(seedPlayers.count + custom.count)
        for base in seedPlayers + custom {
            var p = base
            if p.league == .liiga, let snap = state.liveLiiga, let tg = snap.teamGames, !tg.isEmpty {
                // Liigan rajapinta antaa maalit ja syötöt, ei pelaajakohtaisia otteluita: ottelut = joukkueen pelaamat ottelut.
                let e = snap.byName[AppStore.norm(p.name)]?.first
                p.goals = e?.goals ?? 0
                p.ppPoints = e?.ppPoints ?? 0
                p.assists = e?.assists ?? 0
                if let e, !e.pos.isEmpty {
                    p.games = e.games; p.pim = e.pim; p.plusMinus = e.plusMinus; p.shots = e.shots
                } else {
                    p.games = tg[p.team] ?? 0
                    p.pim = nil; p.plusMinus = nil
                }
            }
            if (p.league == .shl || p.league == .allsvenskan),
               let e = state.liveEP?[p.league.rawValue]?.byName[AppStore.norm(p.name)]?.first {
                p.games = e.games; p.goals = e.goals; p.assists = e.assists
                p.pim = e.pim; p.plusMinus = e.plusMinus
            }
            if let lv = liveFor(p) {
                p.games = lv.entry.games; p.goals = lv.entry.goals; p.assists = lv.entry.assists
                p.pim = lv.entry.pim; p.plusMinus = lv.entry.plusMinus
                p.shots = lv.entry.shots
                p.slot = lv.entry.pos
                p.ppPoints = lv.entry.ppPoints
                if let t = lv.team { p.team = t.name; p.flag = t.flag }
            }
            if p.league == .nhl, let i = state.live?.info?[AppStore.norm(p.name)] {
                p.number = i.number
                if p.nat == nil { p.nat = i.nat }
            } else if p.league == .liiga, let i = state.liveLiiga?.info?[AppStore.norm(p.name)] {
                p.number = i.number
                if p.nat == nil { p.nat = i.nat }
            }
            if let e = state.edits[p.id] {
                p.games = e.games; p.goals = e.goals; p.assists = e.assists
                p.pim = e.pim; p.plusMinus = e.plusMinus
                if let v = e.pos { p.pos = v }
                if let v = e.nat { p.nat = v }
                if let v = e.born { p.born = v }
                if let v = e.shoots { p.shoots = v }
            }
            out.append(p)
        }

        // Lisätään taulukkoon kaikki NHL- ja Liiga-pelaajat, joilla on pisteitä, vaikka heitä ei olisi siemendatassa.
        var have = Set(out.map { "\($0.league.rawValue)|\(AppStore.norm($0.name))" })
        if let snap = state.live {
            for (key, list) in snap.byName {
                for e in list {
                    let tag = "\(League.nhl.rawValue)|\(key)"
                    guard !have.contains(tag), let name = e.name, let team = teamByAbbr[e.abbr] else { continue }
                    have.insert(tag)
                    var p = Player(id: "nhl-\(e.playerId.map(String.init) ?? key)", name: name, team: team.name,
                                   league: .nhl, flag: team.flag, pos: e.pos == "D" ? "D" : "F", nat: nil, born: nil, shoots: nil,
                                   games: e.games, goals: e.goals, assists: e.assists, pim: e.pim, plusMinus: e.plusMinus)
                    p.shots = e.shots
                    p.slot = e.pos
                    p.ppPoints = e.ppPoints
                    p.number = snap.info?[key]?.number
                    p.nat = snap.info?[key]?.nat
                    out.append(p)
                }
            }
        }
        if let snap = state.liveLiiga {
            for (key, list) in snap.byName {
                for e in list where e.goals + e.assists > 0 || !e.pos.isEmpty {
                    let tag = "\(League.liiga.rawValue)|\(key)"
                    guard !have.contains(tag), let name = e.name, let team = teamByName[e.abbr] else { continue }
                    have.insert(tag)
                    let official = !e.pos.isEmpty
                    var lp = Player(id: "liiga-\(key)", name: name, team: team.name, league: .liiga, flag: team.flag,
                                    pos: official ? e.pos : nil, nat: snap.info?[key]?.nat, born: nil, shoots: nil,
                                    games: official ? e.games : (snap.teamGames?[team.name] ?? 0), goals: e.goals, assists: e.assists,
                                    pim: official ? e.pim : nil, plusMinus: official ? e.plusMinus : nil)
                    if official { lp.shots = e.shots }
                    lp.number = snap.info?[key]?.number
                    lp.ppPoints = e.ppPoints
                    out.append(lp)
                }
            }
        }
        if let snap = state.liveAHL {
            for (key, list) in snap.byName {
                for e in list where e.goals + e.assists > 0 {
                    let tag = "\(League.ahl.rawValue)|\(key)"
                    guard !have.contains(tag), let name = e.name, let team = teamByName[e.abbr] else { continue }
                    have.insert(tag)
                    var ap = Player(id: "ahl-\(e.playerId.map(String.init) ?? key)", name: name, team: team.name, league: .ahl, flag: team.flag,
                                    pos: e.pos == "D" ? "D" : "F", nat: nil, born: nil, shoots: nil,
                                    games: e.games, goals: e.goals, assists: e.assists, pim: e.pim, plusMinus: e.plusMinus)
                    ap.shots = e.shots
                    ap.slot = e.pos
                    ap.ppPoints = e.ppPoints
                    ap.number = snap.info?[key]?.number
                    out.append(ap)
                }
            }
        }
        if let snap = state.liveMestis {
            for (key, list) in snap.byName {
                for e in list {
                    let tag = "\(League.mestis.rawValue)|\(key)"
                    guard !have.contains(tag), let name = e.name, let team = teamByName[e.abbr] else { continue }
                    have.insert(tag)
                    var mp = Player(id: "mestis-\(e.playerId.map(String.init) ?? key)", name: name, team: team.name, league: .mestis, flag: team.flag,
                                    pos: e.pos, nat: nil, born: nil, shoots: nil,
                                    games: e.games, goals: e.goals, assists: e.assists, pim: e.pim, plusMinus: e.plusMinus)
                    mp.shots = e.shots
                    mp.number = snap.info?[key]?.number
                    mp.nat = snap.info?[key]?.nat
                    out.append(mp)
                }
            }
        }
        players = out
    }

    // MARK: Haut

    func player(_ id: String) -> Player? { players.first { $0.id == id } }

    func rating(_ id: String) -> Int { state.ratings[id] ?? 0 }

    func note(_ id: String) -> String { state.notes[id] ?? "" }

    func logoURL(for teamName: String) -> URL? {
        if let s = state.logos[teamName], let u = URL(string: s) { return u }
        if let s = state.autoLogos?[teamName], let u = URL(string: s) { return u }
        if let s = StaticLogos.urls[teamName], let u = URL(string: s) { return u }
        return teamByName[teamName]?.defaultLogoURL
    }

    func abbr(for teamName: String) -> String {
        if let a = teamByName[teamName]?.abbr { return a }
        return String(teamName.split(separator: " ").compactMap { $0.first }.prefix(3)).uppercased()
    }

    /// Joukkueet valitulle sarjalle (omat joukkueet mukaan lukien).
    func teamNames(in league: League?) -> [String] {
        var names = teams.filter { league == nil || $0.league == league }.map { $0.name }
        for p in players where (league == nil || p.league == league) && teamByName[p.team] == nil && !names.contains(p.team) {
            names.append(p.team)
        }
        return names
    }

    var ratedCount: Int { players.filter { rating($0.id) > 0 }.count }
    var notesCount: Int { players.filter { !note($0.id).isEmpty }.count }

    // MARK: Muutokset

    func setRating(_ id: String, _ value: Int) {
        let current = rating(id)
        if current == value { state.ratings[id] = nil } else { state.ratings[id] = value }
        persist()
        if let p = player(id) {
            let r = rating(id)
            flash(r > 0 ? "\(p.name): \(String(repeating: "⭐", count: r))" : "\(p.name): arvostelu poistettu")
        }
    }

    func resetRatings(in list: [Player]) {
        for p in list { state.ratings[p.id] = nil }
        persist()
        flash("Tähdet nollattu")
    }

    func setNote(_ id: String, _ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { state.notes[id] = nil } else { state.notes[id] = text }
        persist()
    }

    func saveEdit(_ id: String, _ edit: PlayerEdit) {
        state.edits[id] = edit
        persist(); rebuild()
        flash("Tiedot päivitetty")
    }

    func resetEdit(_ id: String) {
        state.edits[id] = nil
        persist(); rebuild()
        flash("Alkuperäiset tiedot palautettu")
    }

    func setLogo(team: String, urlString: String) {
        let t = urlString.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { state.logos[team] = nil } else { state.logos[team] = t }
        persist()
    }

    func addPlayer(_ p: Player) {
        state.customPlayers.append(StoredPlayer(p))
        persist(); rebuild()
        flash("\(p.name) lisätty")
    }

    func updateCustom(_ p: Player) {
        guard let i = state.customPlayers.firstIndex(where: { $0.id == p.id }) else { return }
        state.customPlayers[i] = StoredPlayer(p)
        persist(); rebuild()
        flash("Tiedot päivitetty")
    }

    func deleteCustom(_ id: String) {
        state.customPlayers.removeAll { $0.id == id }
        state.ratings[id] = nil; state.notes[id] = nil; state.edits[id] = nil
        persist(); rebuild()
        flash("Pelaaja poistettu")
    }

    func newCustomID() -> String { "custom-" + UUID().uuidString.prefix(8).lowercased() }

    // MARK: Vienti ja tuonti

    func exportData() -> Data? {
        let backup = BackupFile(app: "jaakiekko-pistepörssi", version: 2, season: "2026/2027",
                                exportedAt: ISO8601DateFormatter().string(from: Date()),
                                ratings: state.ratings, notes: state.notes, edits: state.edits,
                                logos: state.logos, customPlayers: state.customPlayers)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(backup)
    }

    @discardableResult
    func importData(_ data: Data) -> Bool {
        guard let b = try? JSONDecoder().decode(BackupFile.self, from: data) else {
            flash("Virheellinen JSON-tiedosto")
            return false
        }
        var r = 0, n = 0, c = 0
        for (k, v) in b.ratings ?? [:] where (1...3).contains(v) { state.ratings[k] = v; r += 1 }
        for (k, v) in b.notes ?? [:] where !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { state.notes[k] = v; n += 1 }
        for (k, v) in b.edits ?? [:] { state.edits[k] = v }
        for (k, v) in b.logos ?? [:] where v.lowercased().hasPrefix("http") { state.logos[k] = v }
        for sp in b.customPlayers ?? [] where sp.id.hasPrefix("custom-") && League(rawValue: sp.league) != nil {
            if let i = state.customPlayers.firstIndex(where: { $0.id == sp.id }) { state.customPlayers[i] = sp }
            else { state.customPlayers.append(sp) }
            c += 1
        }
        persist(); rebuild()
        flash("Tuotu: \(r) arvostelua, \(n) muistiinpanoa, \(c) pelaajaa")
        return true
    }

    // MARK: NHL live

    /// `force` ohittaa Elite Prospectsin kutsukiintiön säästön (muuten haetaan korkeintaan kahden tunnin välein).
    func refreshLive(force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        lastFullRefresh = Date()
        await refreshNHL()
        await refreshLiiga()
        await refreshAHL()
        await refreshMestis()
        notifyArmed = true
        if hasEPKey, force || lastEPFetch == nil || Date().timeIntervalSince(lastEPFetch ?? .distantPast) > 7200 {
            await refreshEP()
        }
    }

    @ObservationIgnored private var lastFullRefresh = Date.distantPast
    @ObservationIgnored private var lastFastRefresh = Date.distantPast
    var liveGamesOn = false

    // MARK: Ilmoitukset (maali / syöttö)

    var notifyEnabled: Bool = (UserDefaults.standard.object(forKey: "notifyEnabled") as? Bool) ?? true
    var appIconChoice: AppIconChoice = AppIconChoice.saved
    func setAppIcon(_ c: AppIconChoice) {
        appIconChoice = c
        UserDefaults.standard.set(c.rawValue, forKey: "appIconChoice")
        c.apply()
    }
    var notifyMinStars: Int = (UserDefaults.standard.object(forKey: "notifyMinStars") as? Int) ?? 3
    @ObservationIgnored private let notifDelegate = NotifDelegate()
    @ObservationIgnored private var goalSound: NSSound?
    var notifySound: Bool = (UserDefaults.standard.object(forKey: "notifySound") as? Bool) ?? true
    var customSoundName: String? = UserDefaults.standard.string(forKey: "customSoundName")

    private var soundsDir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("JaakiekkoTilastot", isDirectory: true)
    }

    private var customSoundURL: URL? {
        guard let n = UserDefaults.standard.string(forKey: "customSoundFile") else { return nil }
        let u = soundsDir.appendingPathComponent(n)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }

    func setNotifySound(_ on: Bool) {
        notifySound = on
        UserDefaults.standard.set(on, forKey: "notifySound")
    }

    /// Kopioi käyttäjän valitseman äänitiedoston sovelluksen omaan tallennustilaan.
    func setCustomSound(from url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        let file = "goal-sound." + (url.pathExtension.isEmpty ? "aiff" : url.pathExtension.lowercased())
        let dest = soundsDir.appendingPathComponent(file)
        try? FileManager.default.removeItem(at: dest)
        do { try FileManager.default.copyItem(at: url, to: dest) } catch { return false }
        guard NSSound(contentsOf: dest, byReference: false) != nil else {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
        UserDefaults.standard.set(file, forKey: "customSoundFile")
        UserDefaults.standard.set(url.lastPathComponent, forKey: "customSoundName")
        customSoundName = url.lastPathComponent
        return true
    }

    func clearCustomSound() {
        if let u = customSoundURL { try? FileManager.default.removeItem(at: u) }
        UserDefaults.standard.removeObject(forKey: "customSoundFile")
        UserDefaults.standard.removeObject(forKey: "customSoundName")
        customSoundName = nil
    }

    /// Soittaa ilmoitusäänen (oma ääni, jos valittu; muuten järjestelmän oletusääni).
    func playNotificationSound() {
        if let u = customSoundURL, let s = NSSound(contentsOf: u, byReference: false) {
            goalSound?.stop()
            goalSound = s
            s.play()
        } else {
            NSSound.beep()
        }
    }
    @ObservationIgnored private var scoreBaseline: [String: (g: Int, a: Int)] = [:]
    @ObservationIgnored private var notifyArmed = false

    func setNotifyEnabled(_ on: Bool) {
        notifyEnabled = on
        UserDefaults.standard.set(on, forKey: "notifyEnabled")
        if on { requestNotificationAuth() }
    }

    func setNotifyMinStars(_ n: Int) {
        notifyMinStars = n
        UserDefaults.standard.set(n, forKey: "notifyMinStars")
    }

    func requestNotificationAuth() {
        let c = UNUserNotificationCenter.current()
        c.delegate = notifDelegate
        c.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Vertaa pelaajien maaleja ja syöttöjä edelliseen päivitykseen ja ilmoittaa suosikkien (tähtiluokitus) uusista pisteistä.
    private func checkScoringNotifications() {
        var snap: [String: (g: Int, a: Int)] = [:]
        var fired: [(Player, Int, Int)] = []
        for p in players {
            let g = p.goals ?? 0, a = p.assists ?? 0
            snap[p.id] = (g, a)
            guard notifyArmed, notifyEnabled, let old = scoreBaseline[p.id], rating(p.id) >= notifyMinStars,
                  g > old.g || a > old.a else { continue }
            fired.append((p, max(0, g - old.g), max(0, a - old.a)))
        }
        scoreBaseline = snap
        if !fired.isEmpty && notifySound { playNotificationSound() }
        for (p, dg, da) in fired {
            let content = UNMutableNotificationContent()
            let what = dg > 0 && da > 0 ? "Maali ja syöttö" : dg > 0 ? (dg > 1 ? "\(dg) maalia" : "Maali") : (da > 1 ? "\(da) syöttöä" : "Syöttö")
            content.title = "\(what): \(p.name)"
            content.body = "\(p.team) · \(p.points ?? 0) p (\(p.goals ?? 0)+\(p.assists ?? 0))"
            content.sound = nil   // ääni soitetaan itse (oma ääni tai järjestelmän piippaus)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    /// Kutsutaan puolen minuutin välein: normaali päivitys 10 min välein, käynnissä olevien NHL-, AHL- ja Liiga-pelien aikana minuutin välein.
    func autoRefreshTick() async {
        if isRefreshing { return }
        if Date().timeIntervalSince(lastFullRefresh) >= 600 {
            await refreshLive(); return
        }
        let nhlLive = await nhlHasLiveGames()
        let ahlLive = await ahlHasLiveGames()
        let liigaLive = await liigaHasLiveGames()
        liveGamesOn = nhlLive || ahlLive || liigaLive
        guard liveGamesOn, Date().timeIntervalSince(lastFastRefresh) >= 55 else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        lastFastRefresh = Date()
        if nhlLive { await refreshNHL(fast: true) }
        if ahlLive { await refreshAHL() }
        if liigaLive { await refreshLiiga() }
    }

    func setEPKey(_ key: String) {
        let t = key.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.set(t, for: "eliteprospects")
        hasEPKey = !t.isEmpty
        if !hasEPKey { epStatus = "SHL/HA: ei avainta" }
    }

    // MARK: Elite Prospects (SHL, HockeyAllsvenskan)

    private func refreshEP() async {
        guard let key = Keychain.get("eliteprospects") else { return }
        epStatus = "Päivitetään SHL/HA…"
        var snapshots = state.liveEP ?? [:]
        var failures: [String] = []
        var fetched = 0
        for (league, slug) in [(League.shl, "shl"), (League.allsvenskan, "hockeyallsvenskan")] {
            let result = await fetchEPLeague(slug: slug, key: key)
            guard let rows = result.rows, !rows.isEmpty else {
                failures.append("\(league.label): \(result.error ?? "tuntematon virhe")")
                continue
            }
            var byName: [String: LiveEntry] = [:]
            for r in rows {
                guard let name = r.player?.fullName, !name.isEmpty, let st = r.regularStats else { continue }
                let k = AppStore.norm(name)
                var e = byName[k] ?? LiveEntry(abbr: r.team?.name ?? "", pos: "", games: 0, goals: 0, assists: 0, pim: nil, plusMinus: nil)
                e.games += st.GP ?? 0; e.goals += st.G ?? 0; e.assists += st.A ?? 0
                if let p = st.PIM { e.pim = (e.pim ?? 0) + p }
                if let p = st.PM { e.plusMinus = (e.plusMinus ?? 0) + p }
                byName[k] = e
            }
            guard !byName.isEmpty else { failures.append("\(league.label): ei tilastorivejä"); continue }
            var snap: [String: [LiveEntry]] = [:]
            for (k, v) in byName { snap[k] = [v] }
            snapshots[league.rawValue] = LiveSnapshot(byName: snap, timestamp: Date())
            fetched += 1
        }
        lastEPFetch = Date()
        if fetched > 0 {
            state.liveEP = snapshots
            persist(); rebuild()
        }
        let now = AppStore.timeString(Date())
        if failures.isEmpty { epStatus = "SHL/HA päivitetty " + now }
        else { epStatus = "SHL/HA: " + failures.joined(separator: "; ") }
    }

    private func refreshNHL(fast: Bool = false) async {
        nhlStatus = "Päivitetään NHL…"


        let nhlTeams = teams.filter { $0.league == .nhl }
        let results = await withTaskGroup(of: (Team, [NHLSkater])?.self, returning: [(Team, [NHLSkater])].self) { group in
            for t in nhlTeams { group.addTask { await fetchNHLTeam(t) } }
            var out: [(Team, [NHLSkater])] = []
            for await r in group { if let r { out.append(r) } }
            return out
        }

        guard !results.isEmpty else {
            if let ts = state.live?.timestamp {
                nhlStatus = "NHL: ei yhteyttä, tallennettu " + AppStore.timeString(ts)
            } else {
                nhlStatus = "NHL: ei yhteyttä"
            }
            return
        }

        let ppMap = await fetchNHLPowerPlay()
        var byName: [String: [LiveEntry]] = [:]
        for (team, skaters) in results {
            for s in skaters {
                let full = s.firstName.default + " " + s.lastName.default
                let key = AppStore.norm(full)
                byName[key, default: []].append(
                    LiveEntry(abbr: team.abbr, pos: s.positionCode, games: s.gamesPlayed, goals: s.goals,
                              assists: s.assists, pim: s.penaltyMinutes, plusMinus: s.plusMinus,
                              playerId: s.playerId, shots: s.shots, name: full,
                              ppPoints: s.playerId.flatMap { ppMap[$0] }))
            }
        }
        let now = Date()
        state.live = LiveSnapshot(byName: byName, timestamp: now, hot: state.live?.hot, info: state.live?.info)
        persist(); rebuild()
        nhlStatus = "NHL päivitetty " + AppStore.timeString(now)
        checkScoringNotifications()
        // Liekkitarkistus vain pelaajille, joilla on pisteitä (pisteetön pelaaja ei voi olla liekissä)
        let ids: [(key: String, id: Int)] = byName.compactMap { k, list in
            guard list.contains(where: { $0.goals + $0.assists > 0 }),
                  let id = list.compactMap({ $0.playerId }).first else { return nil }
            return (key: k, id: id)
        }
        if !fast { Task { await self.refreshNHLHot(ids); await self.refreshNHLRosters() } }
    }

    // MARK: Liiga live

    /// Liigan joukkuenimien erot siemendataan nähden.
    static func liigaKey(_ name: String) -> String {
        let n = norm(name)
        return n == "k espoo" ? "kiekko espoo" : n
    }

    private func refreshLiiga() async {
        liigaStatus = "Päivitetään Liiga…"
        guard let games = await fetchLiigaGames() else {
            if let ts = state.liveLiiga?.timestamp {
                liigaStatus = "Liiga: ei yhteyttä, tallennettu " + AppStore.timeString(ts)
            } else {
                liigaStatus = "Liiga: ei yhteyttä"
            }
            return
        }

        var byName: [String: LiveEntry] = [:]
        var teamGames: [String: Int] = [:]
        var logos: [String: String] = state.autoLogos ?? [:]
        let liigaTeams = teams.filter { $0.league == .liiga }
        let seedByKey = Dictionary(uniqueKeysWithValues: liigaTeams.map { (AppStore.liigaKey($0.name), $0.name) })

        func bump(_ person: LiigaPerson?, team: String, goal: Bool, pp: Bool = false) {
            guard let person, !person.fullName.isEmpty else { return }
            let key = AppStore.norm(person.fullName)
            if let j = person.jersey { infoAcc[key] = PlayerInfo(number: j, nat: nil) }
            var e = byName[key] ?? LiveEntry(abbr: team, pos: "", games: 0, goals: 0, assists: 0, pim: nil, plusMinus: nil, name: person.fullName)
            if goal { e.goals += 1 } else { e.assists += 1 }
            if pp { e.ppPoints = (e.ppPoints ?? 0) + 1 }
            byName[key] = e
        }

        var recentAcc: [String: [RecentGame]] = [:]
        var teamStarts: [String: [String]] = [:]
        var infoAcc: [String: PlayerInfo] = [:]
        var teamRecentAcc: [String: [RecentGame]] = [:]
        var pointGames: [(key: String, team: String, start: String)] = []
        for g in games {
            for (side, t) in [g.homeTeam, g.awayTeam].enumerated() {
                guard let t, let name = t.teamName, let seedName = seedByKey[AppStore.liigaKey(name)] else { continue }
                if let url = t.logos?.darkBg ?? t.logos?.lightBg, url.lowercased().hasPrefix("http") { logos[seedName] = url }
                guard g.ended?.value == true else { continue }
                teamGames[seedName, default: 0] += 1
                teamStarts[seedName, default: []].append(g.start ?? "")
                for ev in t.goalEvents ?? [] {
                    let isPP = (ev.goalTypes ?? []).contains { $0.uppercased().hasPrefix("YV") }
                    bump(ev.scorerPlayer, team: seedName, goal: true, pp: isPP)
                    for a in ev.assistantPlayers ?? [] { bump(a, team: seedName, goal: false, pp: isPP) }
                }
                // Pelikohtaiset pisteet viimeisimmät pelit -listaa varten
                var local: [String: (g: Int, a: Int, pp: Int)] = [:]
                for ev in t.goalEvents ?? [] {
                    let isPP = (ev.goalTypes ?? []).contains { $0.uppercased().hasPrefix("YV") }
                    if let sp = ev.scorerPlayer, !sp.fullName.isEmpty {
                        local[AppStore.norm(sp.fullName), default: (0, 0, 0)].g += 1
                        if isPP { local[AppStore.norm(sp.fullName), default: (0, 0, 0)].pp += 1 }
                    }
                    for a in ev.assistantPlayers ?? [] where !a.fullName.isEmpty {
                        local[AppStore.norm(a.fullName), default: (0, 0, 0)].a += 1
                        if isPP { local[AppStore.norm(a.fullName), default: (0, 0, 0)].pp += 1 }
                    }
                }
                let other = side == 0 ? g.awayTeam?.teamName : g.homeTeam?.teamName
                teamRecentAcc[seedName, default: []].append(RecentGame(date: String((g.start ?? "").prefix(10)), opponent: other ?? "?", home: side == 0, goals: 0, assists: 0, pp: 0))
                for (k, _) in local { pointGames.append((key: k, team: seedName, start: g.start ?? "")) }
                for (k, v) in local {
                    recentAcc[k, default: []].append(RecentGame(date: String((g.start ?? "").prefix(10)), opponent: other ?? "?",
                                                                home: side == 0, goals: v.g, assists: v.a, pp: v.pp))
                }
            }
        }

        let now = Date()
        var snapshot: [String: [LiveEntry]] = [:]
        for (k, v) in byName { snapshot[k] = [v] }
        // Viralliset pelaajatilastot: kaikki pelaajat (myös pisteettömät), oikeat ottelumäärät, numerot ja kansalaisuudet
        if let stats = await fetchLiigaPlayerStats() {
            for s in stats {
                guard let tn = s.teamName, let seedName = seedByKey[AppStore.liigaKey(tn)],
                      let f = s.firstName, let l = s.lastName else { continue }
                let full = f + " " + l
                let key = AppStore.norm(full)
                snapshot[key] = [LiveEntry(abbr: seedName, pos: s.role == "P" ? "D" : "F", games: s.playedGames ?? 0,
                                           goals: s.goals ?? 0, assists: s.assists ?? 0, pim: s.penaltyMinutes,
                                           plusMinus: s.plusMinus, playerId: s.playerId, shots: s.shots, name: full,
                                           ppPoints: byName[key]?.ppPoints)]
                infoAcc[key] = PlayerInfo(number: s.jersey, nat: s.nationality)
            }
        }
        var recent: [String: [RecentGame]] = [:]
        for (k, list) in recentAcc { recent[k] = Array(list.sorted { $0.date > $1.date }.prefix(5)) }
        var lastStarts: [String: Set<String>] = [:]
        for (t, starts) in teamStarts { lastStarts[t] = Set(starts.sorted().suffix(4)) }
        var hitStarts: [String: Set<String>] = [:]
        for pg in pointGames where lastStarts[pg.team]?.contains(pg.start) == true {
            hitStarts[pg.key, default: []].insert(pg.start)
        }
        // Liekki vain, jos pelaaja on tehnyt pisteen joukkueen jokaisessa neljässä viimeisessä pelissä
        let hotSet = Set(hitStarts.filter { $0.value.count == 4 }.map { $0.key })
        state.liveLiiga = LiveSnapshot(byName: snapshot, timestamp: now, teamGames: teamGames, recent: recent, hot: Array(hotSet),
                                    teamRecent: teamRecentAcc.mapValues { Array($0.sorted { $0.date > $1.date }.prefix(5)) },
                                    info: infoAcc)
        state.autoLogos = logos
        persist(); rebuild()
        liigaStatus = "Liiga päivitetty " + AppStore.timeString(now)
        checkScoringNotifications()
    }

    private func refreshAHL() async {
        ahlStatus = "Päivitetään AHL…"
        let season = await fetchAHLSeasonId()
        let ahlFeedTeams = await fetchAHLTeams(season: season)
        guard let skaters = await fetchAHLSkaters(season: season, teamIDs: ahlFeedTeams.map(\.id)) else {
            if let ts = state.liveAHL?.timestamp { ahlStatus = "AHL: ei yhteyttä, tallennettu " + AppStore.timeString(ts) }
            else { ahlStatus = "AHL: ei yhteyttä" }
            return
        }
        let ahlTeams = teams.filter { $0.league == .ahl }
        let byCode = Dictionary(uniqueKeysWithValues: ahlTeams.map { ($0.abbr, $0.name) })
        var byName: [String: [LiveEntry]] = [:]
        var info: [String: PlayerInfo] = [:]
        for s in skaters.sorted(by: { $0.games > $1.games }) {
            guard let teamName = teamByName[s.team]?.name ?? byCode[s.code] else { continue }
            let pos: String
            switch s.pos {
            case "LW", "L": pos = "L"
            case "RW", "R": pos = "R"
            case "D": pos = "D"
            default: pos = "C"
            }
            let key = AppStore.norm(s.name)
            byName[key, default: []].append(LiveEntry(abbr: teamName, pos: pos, games: s.games, goals: s.goals, assists: s.assists,
                                                      pim: s.pim, plusMinus: s.plusMinus, playerId: s.id, shots: s.shots, name: s.name, ppPoints: s.ppPoints))
            if info[key] == nil { info[key] = PlayerInfo(number: s.number, nat: nil) }
        }
        let now = Date()
        state.liveAHL = LiveSnapshot(byName: byName, timestamp: now, info: info)
        var logos = state.autoLogos ?? [:]
        for t in ahlFeedTeams where teamByName[t.name]?.league == .ahl { if let u = t.logo, !u.isEmpty { logos[t.name] = u } }
        state.autoLogos = logos
        persist(); rebuild()
        ahlStatus = "AHL päivitetty " + AppStore.timeString(now)
        checkScoringNotifications()
    }

    private func refreshMestis() async {
        mestisStatus = "Päivitetään Mestis…"
        guard let skaters = await fetchMestisSkaters() else {
            if let ts = state.liveMestis?.timestamp { mestisStatus = "Mestis: ei yhteyttä, tallennettu " + AppStore.timeString(ts) }
            else { mestisStatus = "Mestis: ei yhteyttä" }
            return
        }
        var byName: [String: [LiveEntry]] = [:]
        for s in skaters.sorted(by: { $0.games > $1.games }) {
            guard let teamName = MestisSite.resolve(s.team, teams: teams) else { continue }
            let key = AppStore.norm(s.name)
            byName[key, default: []].append(LiveEntry(abbr: teamName, pos: s.pos == "P" ? "D" : "F", games: s.games, goals: s.goals,
                                                      assists: s.assists, pim: s.pim, plusMinus: s.plusMinus, playerId: s.id,
                                                      shots: s.shots, name: s.name, link: s.link))
        }
        let now = Date()
        state.liveMestis = LiveSnapshot(byName: byName, timestamp: now, info: state.liveMestis?.info)
        var logos = state.autoLogos ?? [:]
        for (n, u) in MestisSite.logos { logos[n] = u }
        state.autoLogos = logos
        persist(); rebuild()
        mestisStatus = "Mestis päivitetty " + AppStore.timeString(now)
        checkScoringNotifications()
        Task { await self.refreshMestisInfo() }
    }

    /// Hakee Mestis-pelaajien numerot ja kansalaisuudet pelaajasivuilta (vain puuttuvat, 8 rinnakkain).
    private func refreshMestisInfo() async {
        guard let snap = state.liveMestis else { return }
        var info = snap.info ?? [:]
        let todo: [(String, String)] = snap.byName.compactMap { k, list in
            guard info[k] == nil, let l = list.first?.link else { return nil }
            return (k, l)
        }
        guard !todo.isEmpty else { return }
        await withTaskGroup(of: (String, PlayerInfo?).self) { group in
            var idx = 0
            while idx < min(8, todo.count) {
                let t = todo[idx]; idx += 1
                group.addTask { (t.0, await fetchMestisPlayerInfo(link: t.1)) }
            }
            for await r in group {
                if let i = r.1 { info[r.0] = i }
                if idx < todo.count {
                    let t = todo[idx]; idx += 1
                    group.addTask { (t.0, await fetchMestisPlayerInfo(link: t.1)) }
                }
            }
        }
        if var s = state.liveMestis {
            s.info = info
            state.liveMestis = s
            persist(); rebuild()
        }
    }

    // MARK: Liekki (pisteitä neljässä viimeisessä pelissä)

    func isHot(_ p: Player) -> Bool {
        let k = AppStore.norm(p.name)
        switch p.league {
        case .nhl: return state.live?.hot?.contains(k) ?? false
        case .liiga: return state.liveLiiga?.hot?.contains(k) ?? false
        default: return false
        }
    }

    /// Hakee NHL-joukkueiden kokoonpanot: pelinumerot ja syntymämaat.
    private func refreshNHLRosters() async {
        let nhlTeams = teams.filter { $0.league == .nhl }
        let rosters = await withTaskGroup(of: [NHLRosterPlayer].self, returning: [[NHLRosterPlayer]].self) { group in
            for t in nhlTeams { group.addTask { await fetchNHLRoster(abbr: t.abbr) } }
            var out: [[NHLRosterPlayer]] = []
            for await r in group { out.append(r) }
            return out
        }
        var info: [String: PlayerInfo] = [:]
        for p in rosters.flatMap({ $0 }) {
            guard let f = p.firstName?.default, let l = p.lastName?.default else { continue }
            info[AppStore.norm(f + " " + l)] = PlayerInfo(number: p.sweaterNumber, nat: p.birthCountry)
        }
        guard !info.isEmpty, var snap = state.live else { return }
        snap.info = info
        state.live = snap
        persist(); rebuild()
    }

    /// Hakee NHL-pelaajien ottelulogit (8 rinnakkain) ja merkitsee ne, joilla on piste 4 viimeisessä pelissä.
    private func refreshNHLHot(_ players: [(key: String, id: Int)]) async {
        var hot: [String] = []
        await withTaskGroup(of: (String, Bool)?.self) { group in
            var idx = 0
            while idx < min(8, players.count) {
                let p = players[idx]; idx += 1
                group.addTask { await nhlHotCheck(key: p.key, id: p.id) }
            }
            for await r in group {
                if let r, r.1 { hot.append(r.0) }
                if idx < players.count {
                    let p = players[idx]; idx += 1
                    group.addTask { await nhlHotCheck(key: p.key, id: p.id) }
                }
            }
        }
        if var snap = state.live {
            snap.hot = hot
            state.live = snap
            persist()
        }
    }

    // MARK: Viimeisimmät pelit

    struct RecentResult {
        var games: [RecentGame] = []
        var note: String?
    }

    @ObservationIgnored private var recentCache: [String: (Date, RecentResult)] = [:]

    /// Pelaajan viimeisimmät (enintään 5) pelit. NHL: ottelulogi rajapinnasta; Liiga: ottelut, joissa pelaaja teki pisteen.
    func recentGames(for p: Player) async -> RecentResult {
        if let c = recentCache[p.id], Date().timeIntervalSince(c.0) < 600 { return c.1 }
        var result = RecentResult()
        switch p.league {
        case .nhl:
            guard let id = liveFor(p)?.entry.playerId else {
                result.note = "Pelaajan NHL-tunnusta ei ole vielä haettu. Paina Päivitä ja avaa pelaaja uudelleen."
                return result
            }
            guard let url = URL(string: "https://api-web.nhle.com/v1/player/\(id)/game-log/now") else { return result }
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { result.note = "Ottelulokin haku epäonnistui."; return result }
                let log = try JSONDecoder().decode(NHLGameLog.self, from: data)
                result.games = (log.gameLog ?? []).prefix(5).map {
                    RecentGame(date: $0.gameDate ?? "", opponent: $0.opponentAbbrev ?? "?",
                               home: $0.homeRoadFlag.map { $0 == "H" }, goals: $0.goals ?? 0, assists: $0.assists ?? 0, shots: $0.shots, pp: $0.powerPlayPoints)
                }
                if result.games.isEmpty { result.note = "Ei pelattuja otteluja tällä kaudella." }
            } catch {
                result.note = "Ottelulokin haku epäonnistui."
                return result
            }
        case .liiga:
            let mine = state.liveLiiga?.recent?[AppStore.norm(p.name)] ?? []
            if let teamList = state.liveLiiga?.teamRecent?[p.team], !teamList.isEmpty {
                // Joukkueen 5 viimeistä ottelua; pelaajan pisteet yhdistetään niihin, muut ottelut näytetään 0 pisteellä.
                result.games = teamList.map { tg in mine.first(where: { $0.id == tg.id }) ?? tg }
                result.note = "Liiga: joukkueen viimeiset 5 ottelua. Rajapinta ei kerro, pelasiko pelaaja kaikissa, joten pisteetön ottelu voi olla myös poissaolo."
            } else {
                result.games = mine
                result.note = mine.isEmpty
                    ? "Ei pisteotteluja tällä kaudella (tai Liigaa ei ole vielä päivitetty)."
                    : "Paina Päivitä nähdäksesi myös pisteettömät ottelut."
            }
        case .mestis:
            if let link = state.liveMestis?.byName[AppStore.norm(p.name)]?.first?.link {
                if let g = await fetchMestisGameLog(link: link, team: p.team) {
                    result.games = g
                    if g.isEmpty { result.note = "Ei pelattuja otteluja tällä kaudella." }
                } else {
                    result.note = "Ottelulokin haku epäonnistui."
                }
            } else {
                result.note = "Pelaajan sivua ei ole vielä haettu. Paina Päivitä ja avaa pelaaja uudelleen."
            }
        case .ahl, .shl, .allsvenskan:
            result.note = "Pelikohtaisia tietoja ei ole saatavilla tälle sarjalle."
        }
        if result.note == nil || !result.games.isEmpty { recentCache[p.id] = (Date(), result) }
        return result
    }

    // MARK: Apurit

    static func timeString(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    func flash(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }
}
