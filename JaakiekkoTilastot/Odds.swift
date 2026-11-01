import Foundation

/// Yhden vedonlyöntiyhtiön tarjoama kerroin.
struct OddsOffer: Hashable {
    let book: String
    let price: Double
}

private struct OddsEventDTO: Decodable {
    let id: String
    let home_team: String
    let away_team: String
    let commence_time: String
    let bookmakers: [Book]?
    struct Book: Decodable {
        let key: String
        let title: String?
        let markets: [Market]?
    }
    struct Market: Decodable {
        let key: String
        let outcomes: [Outcome]?
    }
    struct Outcome: Decodable {
        let name: String
        let description: String?
        let price: Double
        let point: Double?
    }
}

/// Tapahtuman haetut kertoimet: pelaajakohtaiset (markkina -> pelaaja -> tarjoukset) ja ottelun voittaja (joukkue -> tarjoukset).
struct EventOdds {
    var props: [String: [String: [OddsOffer]]] = [:]
    var h2h: [String: [OddsOffer]] = [:]
}

/// Odds API -haut. Vastaukset välimuistissa, jotta kuukausikiintiö ei kulu turhaan.
@MainActor
enum OddsService {
    static var key: String? { Keychain.get("odds") }

    private static var eventsCache: [String: (Date, [OddsEventRef])] = [:]
    private static var propsCache: [String: (Date, [String: [String: [OddsOffer]]])] = [:]
    private static var h2hCache: [String: (Date, [String: EventOdds])] = [:]
    static var lastRemaining: String?

    struct OddsEventRef { let id: String; let home: String; let away: String; let start: Date }

    static func sportKey(_ l: League) -> String {
        switch l {
        case .nhl: return "icehockey_nhl"
        case .ahl: return "icehockey_ahl"
        case .liiga: return "icehockey_liiga"
        case .mestis: return "icehockey_mestis"
        case .shl: return "icehockey_sweden_hockey_league"
        case .nl: return "icehockey_switzerland_nla"
        case .allsvenskan: return "icehockey_sweden_allsvenskan"
        }
    }

    /// Pelaajakohtaisia kertoimia on Odds API:ssa vain NHL:lle (Coolbet, Pinnacle).
    static func hasPlayerProps(_ l: League) -> Bool { l == .nhl }

    static let propMarkets = "player_points,player_assists,player_goals,player_goal_scorer_anytime"
    static let h2hBooks = "veikkaus_fi,unibet_fi,nordicbet,coolbet,pinnacle"
    static let propBooks = "coolbet,pinnacle"

    private static func get(_ path: String, _ query: [String: String]) async -> Data? {
        guard let k = key else { return nil }
        var c = URLComponents(string: "https://api.the-odds-api.com/v4" + path)!
        c.queryItems = ([("apiKey", k)] + query.map { ($0.key, $0.value) }).map { URLQueryItem(name: $0.0, value: $0.1) }
        guard let url = c.url else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else { return nil }
        if let r = http.value(forHTTPHeaderField: "x-requests-remaining") { lastRemaining = r }
        return http.statusCode == 200 ? data : nil
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()

    static func events(_ sport: String) async -> [OddsEventRef]? {
        if let c = eventsCache[sport], Date().timeIntervalSince(c.0) < 1800 { return c.1 }
        guard let data = await get("/sports/\(sport)/events", [:]),
              let list = try? JSONDecoder().decode([OddsEventDTO].self, from: data) else { return nil }
        let refs = list.map { OddsEventRef(id: $0.id, home: $0.home_team, away: $0.away_team, start: iso.date(from: $0.commence_time) ?? .distantPast) }
        eventsCache[sport] = (Date(), refs)
        return refs
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        let x = AppStore.norm(a), y = AppStore.norm(b)
        return x == y || x.contains(y) || y.contains(x)
    }

    static func match(_ game: ScheduleGame, in list: [OddsEventRef]) -> OddsEventRef? {
        list.first { same($0.home, game.home) && same($0.away, game.away) && abs($0.start.timeIntervalSince(game.date)) < 86400 }
    }

    /// Ottelun voittajakertoimet kaikille sarjan otteluille (1 kysely).
    static func h2h(_ sport: String) async -> [String: EventOdds]? {
        if let c = h2hCache[sport], Date().timeIntervalSince(c.0) < 900 { return c.1 }
        guard let data = await get("/sports/\(sport)/odds", ["regions": "fi,eu", "markets": "h2h", "bookmakers": h2hBooks]),
              let list = try? JSONDecoder().decode([OddsEventDTO].self, from: data) else { return nil }
        var out: [String: EventOdds] = [:]
        for e in list {
            var eo = EventOdds()
            for b in e.bookmakers ?? [] {
                let label = bookLabel(b.key, b.title)
                for m in b.markets ?? [] where m.key == "h2h" {
                    for o in m.outcomes ?? [] { eo.h2h[o.name, default: []].append(OddsOffer(book: label, price: o.price)) }
                }
            }
            out[e.id] = eo
        }
        h2hCache[sport] = (Date(), out)
        return out
    }

    /// Yhden ottelun pelaajakohtaiset kertoimet (kustannus: markkinoiden määrä).
    static func props(_ sport: String, eventId: String) async -> [String: [String: [OddsOffer]]]? {
        let ck = sport + eventId
        if let c = propsCache[ck], Date().timeIntervalSince(c.0) < 1800 { return c.1 }
        guard let data = await get("/sports/\(sport)/events/\(eventId)/odds", ["regions": "eu", "markets": propMarkets, "bookmakers": propBooks]),
              let e = try? JSONDecoder().decode(OddsEventDTO.self, from: data) else { return nil }
        var out: [String: [String: [OddsOffer]]] = [:]
        for b in e.bookmakers ?? [] {
            let label = bookLabel(b.key, b.title)
            for m in b.markets ?? [] {
                for o in m.outcomes ?? [] {
                    let anytime = m.key == "player_goal_scorer_anytime"
                    var mk = m.key
                    if anytime {
                        guard o.name != "No" else { continue }
                    } else {
                        let pt = o.point ?? 0.5
                        guard o.name == "Over", pt == 0.5 || pt == 1.5 else { continue }
                        mk = m.key + "@" + (pt == 1.5 ? "1.5" : "0.5")
                    }
                    let who = (o.description?.isEmpty == false) ? o.description! : o.name
                    out[mk, default: [:]][AppStore.norm(who), default: []].append(OddsOffer(book: label, price: o.price))
                }
            }
        }
        propsCache[ck] = (Date(), out)
        return out
    }

    static func bookLabel(_ key: String, _ title: String?) -> String {
        switch key {
        case "veikkaus_fi": return "Veikkaus"
        case "unibet_fi": return "Unibet"
        case "nordicbet": return "NordicBet"
        case "coolbet": return "Coolbet"
        case "pinnacle": return "Pinnacle"
        default: return title ?? key
        }
    }
}

extension AppStore {
    var hasOddsKey: Bool { _ = oddsKeyVersion; return Keychain.get("odds") != nil }
    func setOddsKey(_ k: String) {
        Keychain.set(k.trimmingCharacters(in: .whitespacesAndNewlines), for: "odds")
        oddsKeyVersion += 1
    }
}
