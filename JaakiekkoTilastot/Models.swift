import Foundation

// MARK: - Sarjat ja joukkueet

enum League: String, CaseIterable, Identifiable, Codable {
    case nhl = "NHL"
    case ahl = "AHL"
    case liiga = "SM-liiga"
    case mestis = "Mestis"
    case shl = "SHL"
    case allsvenskan = "HockeyAllsvenskan"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nhl: return "NHL"
        case .ahl: return "AHL"
        case .liiga: return "Liiga"
        case .mestis: return "Mestis"
        case .shl: return "SHL"
        case .allsvenskan: return "HockeyAllsvenskan"
        }
    }

    var flags: String {
        switch self {
        case .nhl, .ahl: return "🇺🇸 🇨🇦"
        case .liiga, .mestis: return "🇫🇮"
        case .shl, .allsvenskan: return "🇸🇪"
        }
    }
}

struct Team: Identifiable, Hashable {
    let name: String
    let abbr: String
    let league: League
    let flag: String

    var id: String { name }

    /// NHL:n viralliset logot haetaan joukkuetunnuksella, muille ei ole oletuslogoa (näytetään lyhennemerkki).
    var defaultLogoURL: URL? {
        guard league == .nhl else { return nil }
        return URL(string: "https://assets.nhle.com/logos/nhl/svg/\(abbr)_dark.svg")
    }
}

// MARK: - Pelaaja

struct Player: Identifiable, Hashable {
    var id: String
    var name: String
    var team: String
    var league: League
    var flag: String
    var pos: String?
    var nat: String?
    var born: Int?
    var shoots: String?
    var games: Int?
    var goals: Int?
    var assists: Int?
    var pim: Int?
    var plusMinus: Int?
    var isCustom = false
    var shots: Int? = nil
    /// Tarkka pelipaikka (NHL: C/L/R/D), jos tiedossa.
    var slot: String? = nil
    /// Ylivoimapisteet (maalit + syötöt ylivoimalla), jos tiedossa.
    var ppPoints: Int? = nil
    /// Pelinumero, jos tiedossa.
    var number: Int? = nil

    var points: Int? {
        if goals == nil && assists == nil { return nil }
        return (goals ?? 0) + (assists ?? 0)
    }

    var pointsPerGame: Double? {
        guard let g = games, g > 0, let p = points else { return nil }
        return Double(p) / Double(g)
    }

    var age: Int? {
        guard let born else { return nil }
        return 2026 - born
    }

    var positionLabel: String? {
        switch pos {
        case "F": return "Hyökkääjä"
        case "D": return "Puolustaja"
        case "G": return "Maalivahti"
        default: return nil
        }
    }
}

// MARK: - Tallennettavat rakenteet (yhteensopivia web-version JSON-viennin kanssa)

/// Käyttäjän tekemät muutokset pelaajan tietoihin.
struct PlayerEdit: Codable, Equatable {
    var games: Int?
    var goals: Int?
    var assists: Int?
    var pim: Int?
    var plusMinus: Int?
    var pos: String?
    var nat: String?
    var born: Int?
    var shoots: String?
}

/// Käyttäjän lisäämä pelaaja.
struct StoredPlayer: Codable, Equatable {
    var id: String
    var name: String
    var team: String
    var league: String
    var flag: String?
    var teamLogo: String?
    var pos: String?
    var nat: String?
    var born: Int?
    var shoots: String?
    var games: Int?
    var goals: Int?
    var assists: Int?
    var pim: Int?
    var plusMinus: Int?

    init(_ p: Player) {
        id = p.id; name = p.name; team = p.team; league = p.league.rawValue; flag = p.flag
        teamLogo = nil; pos = p.pos; nat = p.nat; born = p.born; shoots = p.shoots
        games = p.games; goals = p.goals; assists = p.assists; pim = p.pim; plusMinus = p.plusMinus
    }

    func toPlayer() -> Player? {
        guard let lg = League(rawValue: league) else { return nil }
        return Player(id: id, name: name, team: team, league: lg, flag: flag ?? String(lg.flags.prefix(2)),
                      pos: pos, nat: nat, born: born, shoots: shoots,
                      games: games, goals: goals, assists: assists, pim: pim, plusMinus: plusMinus, isCustom: true)
    }
}

/// NHL-live-tilasto yhdelle pelaajalle (yhdessä joukkueessa).
struct LiveEntry: Codable, Equatable {
    var abbr: String
    var pos: String
    var games: Int
    var goals: Int
    var assists: Int
    var pim: Int?
    var plusMinus: Int?
    var playerId: Int? = nil
    var shots: Int? = nil
    /// Pelaajan koko nimi (tarvitaan, kun pelaaja ei ole siemendatassa).
    var name: String? = nil
    /// Ylivoimapisteet (NHL: tilastopalvelu, Liiga: ylivoimamaalien tekijät ja syöttäjät).
    var ppPoints: Int? = nil
    /// Mestis: pelaajasivun polku (ottelu-ottelulta -lokia varten).
    var link: String? = nil
}

/// Yhden pelin tulos pelaajalle (viimeisimmät pelit -lista).
struct RecentGame: Codable, Identifiable, Hashable {
    var date: String        // YYYY-MM-DD
    var opponent: String
    var home: Bool?
    var goals: Int
    var assists: Int
    var shots: Int? = nil
    /// Ylivoimapisteet pelissä, jos tiedossa.
    var pp: Int? = nil
    var id: String { date + opponent }
    var points: Int { goals + assists }
}

struct LiveSnapshot: Codable {
    var byName: [String: [LiveEntry]]
    var timestamp: Date
    /// Joukkueen pelaamat ottelut (käytössä Liigassa, jonka rajapinta ei kerro pelaajakohtaisia otteluita).
    var teamGames: [String: Int]? = nil
    /// Liigan viimeisimmät pisteottelut pelaajittain (norm(nimi) -> uusin ensin).
    var recent: [String: [RecentGame]]? = nil
    /// Pelaajat (norm(nimi)), jotka ovat tehneet pisteen neljästä viimeisestä pelistään.
    var hot: [String]? = nil
    /// Joukkueen viimeisimmät (enintään 5) pelatut ottelut, uusin ensin (Liiga).
    var teamRecent: [String: [RecentGame]]? = nil
    /// Pelaajakohtaiset lisätiedot (norm(nimi) -> numero, kansalaisuus).
    var info: [String: PlayerInfo]? = nil
}

struct PlayerInfo: Codable, Equatable {
    var number: Int?
    var nat: String?
}

/// Sovelluksen tallennettu tila (Application Support/JaakiekkoTilastot/state.json).
struct AppState: Codable {
    var ratings: [String: Int] = [:]
    var notes: [String: String] = [:]
    var edits: [String: PlayerEdit] = [:]
    var logos: [String: String] = [:]
    var customPlayers: [StoredPlayer] = []
    var live: LiveSnapshot?
    var liveLiiga: LiveSnapshot?
    var liveAHL: LiveSnapshot?
    var liveMestis: LiveSnapshot?
    /// Rajapinnoista haetut joukkuelogot (joukkueen nimi -> URL).
    var autoLogos: [String: String]?
    /// Elite Prospects -rajapinnasta haetut tilastot sarjoittain (SHL, HockeyAllsvenskan).
    var liveEP: [String: LiveSnapshot]?
}

/// JSON-varmuuskopio. Kentät ovat samat kuin web-version viennissä, joten tiedostot kelpaavat molempiin suuntiin.
struct BackupFile: Codable {
    var app: String?
    var version: Int?
    var season: String?
    var exportedAt: String?
    var ratings: [String: Int]?
    var notes: [String: String]?
    var edits: [String: PlayerEdit]?
    var logos: [String: String]?
    var customPlayers: [StoredPlayer]?
}

// MARK: - NHL API

struct NHLClubStats: Decodable {
    let skaters: [NHLSkater]
}

struct NHLSkater: Decodable {
    struct Name: Decodable {
        let `default`: String
    }
    let firstName: Name
    let lastName: Name
    let positionCode: String
    let playerId: Int?
    let shots: Int?
    let gamesPlayed: Int
    let goals: Int
    let assists: Int
    let plusMinus: Int?
    let penaltyMinutes: Int?
}


// MARK: - Liigan rajapinta (liiga.fi/api/v2/games)

/// Rajapinnan kentät luetaan sallivasti: puuttuva tai erimuotoinen kenttä ei kaada koko vastausta.
/// Sallivasti luettu kokonaisluku: ei kaada koko vastausta, vaikka kentän tyyppi olisi odottamaton.
struct LiigaFlexInt: Decodable {
    let value: Int?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = Int(d) }
        else if let s = try? c.decode(String.self) { value = Int(s) }
        else { value = nil }
    }
}

/// Kenttä voi olla joko merkkijono tai olio, jolla on nimi.
struct LiigaRink: Decodable {
    let name: String?
    enum CodingKeys: String, CodingKey { case name }
    init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer(), let s = try? c.decode(String.self) {
            name = s
        } else if let k = try? decoder.container(keyedBy: CodingKeys.self) {
            name = (try? k.decodeIfPresent(String.self, forKey: .name)) ?? nil
        } else {
            name = nil
        }
    }
}

struct LiigaGame: Decodable {
    let id: LiigaFlexInt?
    let started: LiigaFlex?
    let spectators: LiigaFlexInt?
    let iceRink: LiigaRink?
    let start: String?
    let ended: LiigaFlex?
    let homeTeam: LiigaTeam?
    let awayTeam: LiigaTeam?
    let finishedType: String?
}

struct LiigaTeam: Decodable {
    let teamName: String?
    let goalEvents: [LiigaGoal]?
    let goals: Int?
    let powerplayInstances: LiigaFlexInt?
    let powerplayGoals: LiigaFlexInt?
    let logos: LiigaLogos?
}

struct LiigaGoal: Decodable {
    /// Maalityypit; "YV" = ylivoimamaali.
    let goalTypes: [String]?
    let gameTime: LiigaFlexInt?
    let period: LiigaFlexInt?
    let homeTeamScore: LiigaFlexInt?
    let awayTeamScore: LiigaFlexInt?
    let scorerPlayer: LiigaPerson?
    let assistantPlayers: [LiigaPerson]?
}

struct LiigaPerson: Decodable {
    let firstName: String?
    let lastName: String?
    /// Pelinumero, jos rajapinta kertoo sen (kentän nimeä kokeillaan useilla vaihtoehdoilla).
    let jersey: Int?

    enum CodingKeys: String, CodingKey { case firstName, lastName, jersey, jerseyNumber, number, shirtNumber }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        firstName = (try? c.decodeIfPresent(String.self, forKey: .firstName)) ?? nil
        lastName = (try? c.decodeIfPresent(String.self, forKey: .lastName)) ?? nil
        func intValue(_ k: CodingKeys) -> Int? {
            if let i = try? c.decodeIfPresent(Int.self, forKey: k) { return i }
            if let s = try? c.decodeIfPresent(String.self, forKey: k) { return Int(s) }
            return nil
        }
        jersey = intValue(.jersey) ?? intValue(.jerseyNumber) ?? intValue(.number) ?? intValue(.shirtNumber)
    }

    var fullName: String { [firstName, lastName].compactMap { $0 }.joined(separator: " ") }
}

struct LiigaLogos: Decodable {
    let darkBg: String?
    let lightBg: String?
}

/// `ended` voi olla totuusarvo tai aikaleima.
struct LiigaFlex: Decodable {
    let value: Bool
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { value = b }
        else if let s = try? c.decode(String.self) { value = !s.isEmpty }
        else if (try? c.decode(Int.self)) != nil { value = true }
        else { value = false }
    }
}


// MARK: - Elite Prospects API (api.eliteprospects.com/v1)

struct EPResponse: Decodable {
    let data: [EPRow]?
}

struct EPRow: Decodable {
    struct Player: Decodable {
        let name: String?
        let firstName: String?
        let lastName: String?
        var fullName: String {
            if let name, !name.isEmpty { return name }
            return [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        }
    }
    struct Team: Decodable { let name: String? }
    struct Stats: Decodable {
        let GP: Int?
        let G: Int?
        let A: Int?
        let PIM: Int?
        let PM: Int?
    }
    let player: Player?
    let team: Team?
    let regularStats: Stats?
}


// MARK: - NHL ottelulogi (api-web.nhle.com/v1/player/{id}/game-log/now)

struct NHLGameLog: Decodable {
    let gameLog: [NHLGameLogEntry]?
}

struct NHLGameLogEntry: Decodable {
    let powerPlayPoints: Int?
    let gameDate: String?
    let opponentAbbrev: String?
    let homeRoadFlag: String?
    let goals: Int?
    let assists: Int?
    let shots: Int?
}


// MARK: - NHL-kokoonpano (numero ja syntymämaa)

struct NHLNameDefault: Decodable { let `default`: String }

struct NHLRosterPlayer: Decodable {
    let id: Int?
    let firstName: NHLNameDefault?
    let lastName: NHLNameDefault?
    let sweaterNumber: Int?
    let birthCountry: String?
}

struct NHLRoster: Decodable {
    let forwards: [NHLRosterPlayer]?
    let defensemen: [NHLRosterPlayer]?
    let goalies: [NHLRosterPlayer]?
    var all: [NHLRosterPlayer] { (forwards ?? []) + (defensemen ?? []) + (goalies ?? []) }
}

// MARK: - Kansalaisuuden näyttö

enum Countries {
    /// NHL:n kolmikirjaiminen maakoodi -> (lippu, suomenkielinen nimi)
    static let byCode: [String: (String, String)] = [
        "SWE": ("🇸🇪", "Ruotsi"), "FIN": ("🇫🇮", "Suomi"), "USA": ("🇺🇸", "USA"), "CAN": ("🇨🇦", "Kanada"),
        "RUS": ("🇷🇺", "Venäjä"), "CZE": ("🇨🇿", "Tsekki"), "SVK": ("🇸🇰", "Slovakia"), "CHE": ("🇨🇭", "Sveitsi"),
        "DEU": ("🇩🇪", "Saksa"), "DNK": ("🇩🇰", "Tanska"), "NOR": ("🇳🇴", "Norja"), "LVA": ("🇱🇻", "Latvia"),
        "AUT": ("🇦🇹", "Itävalta"), "BLR": ("🇧🇾", "Valko-Venäjä"), "UKR": ("🇺🇦", "Ukraina"), "FRA": ("🇫🇷", "Ranska"),
        "GBR": ("🇬🇧", "Britannia"), "SVN": ("🇸🇮", "Slovenia"), "AUS": ("🇦🇺", "Australia"), "JPN": ("🇯🇵", "Japani"),
        "KAZ": ("🇰🇿", "Kazakstan"), "LTU": ("🇱🇹", "Liettua"), "POL": ("🇵🇱", "Puola"), "NLD": ("🇳🇱", "Hollanti"),
        "ITA": ("🇮🇹", "Italia"), "HUN": ("🇭🇺", "Unkari"), "EST": ("🇪🇪", "Viro"), "BHS": ("🇧🇸", "Bahama"),
        "JAM": ("🇯🇲", "Jamaika"), "NGA": ("🇳🇬", "Nigeria"), "BRA": ("🇧🇷", "Brasilia"), "KOR": ("🇰🇷", "Etelä-Korea"),
        "HRV": ("🇭🇷", "Kroatia"), "ROU": ("🇷🇴", "Romania"), "ISL": ("🇮🇸", "Islanti"), "DEN": ("🇩🇰", "Tanska"),
    ]

    static func label(for nat: String?) -> String {
        guard let nat, !nat.isEmpty else { return "–" }
        if let c = byCode[nat.uppercased()] { return "\(c.0) \(c.1)" }
        if let c = byCode.values.first(where: { $0.1.lowercased() == nat.lowercased() }) { return "\(c.0) \(c.1)" }
        return nat
    }
}

extension Player {
    var natLabel: String { Countries.label(for: nat) }
}


// MARK: - NHL ylivoimapisteet (tilastopalvelu)

struct NHLSummaryResponse: Decodable {
    struct Row: Decodable {
        let playerId: Int?
        let ppPoints: Int?
    }
    let data: [Row]?
}
