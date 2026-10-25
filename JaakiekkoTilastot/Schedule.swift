import SwiftUI

// MARK: - Otteluohjelma

struct ScheduleGame: Identifiable {
    let id: String
    let date: Date
    let home: String      // siemendatan joukkuenimi
    let away: String
    var live = false
    var gameId: Int? = nil
    var final = false
    var homeScore: Int? = nil
    var awayScore: Int? = nil
    var liiga: LiigaGameDetail? = nil
}

struct LiigaGoalLine {
    let seconds: Int
    let period: Int
    let home: Bool
    let scorer: String
    let assists: [String]
    let homeScore: Int?
    let awayScore: Int?
    let powerPlay: Bool
}

struct LiigaGameDetail {
    var goals: [LiigaGoalLine] = []
    var rink: String?
    var spectators: Int?
    var homePP: String?
    var awayPP: String?
    var resultNote: String?
}

private struct NHLScheduleResponse: Decodable {
    struct TeamRef: Decodable { let abbrev: String?; let score: Int? }
    struct Game: Decodable {
        let id: Int?
        let startTimeUTC: String?
        let gameState: String?
        let awayTeam: TeamRef?
        let homeTeam: TeamRef?
    }
    struct Day: Decodable {
        let date: String?
        let games: [Game]?
    }
    let nextStartDate: String?
    let gameWeek: [Day]?
}

/// AHL:n otteluohjelma ja tulokset (HockeyTech-rajapinta, koko liigan ottelut kerralla).
func fetchAHLSchedule(teams: [Team]) async -> [ScheduleGame]? {
    let byCode = Dictionary(uniqueKeysWithValues: teams.filter { $0.league == .ahl }.map { ($0.abbr, $0.name) })
    let season = await fetchAHLSeasonId()
    guard let rows = await ahlFetch("view=schedule&season_id=\(season)") else { return nil }
    var out: [ScheduleGame] = []
    for r in rows {
        guard let h = r["home_team_code"].flatMap({ byCode[$0] }),
              let a = r["visiting_team_code"].flatMap({ byCode[$0] }),
              let d = parseISODate(r["GameDateISO8601"]) else { continue }
        let final = r["final"] == "1"
        let started = r["started"] == "1"
        out.append(ScheduleGame(id: "ahl-\(r["game_id"] ?? "\(out.count)")", date: d, home: h, away: a,
                                live: started && !final, final: final,
                                homeScore: Int(r["home_goal_count"] ?? ""), awayScore: Int(r["visiting_goal_count"] ?? "")))
    }
    return out
}

private func parseISODate(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: s) { return d }
    let f2 = ISO8601DateFormatter()
    f2.formatOptions = [.withInternetDateTime]
    return f2.date(from: s)
}

/// Hakee NHL:n tulevat ottelut (kolme viikkoa eteenpäin).
func fetchNHLSchedule(teams: [Team]) async -> [ScheduleGame]? {
    let byAbbr = Dictionary(uniqueKeysWithValues: teams.filter { $0.league == .nhl }.map { ($0.abbr, $0.name) })
    var out: [ScheduleGame] = []
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "America/New_York")
    // Alkaen kahden päivän takaa, jotta uusimmat päättyneet ottelut tulevat mukaan
    var path = df.string(from: Date().addingTimeInterval(-2 * 86400))
    var gotAny = false
    for _ in 0..<3 {
        guard let url = URL(string: "https://api-web.nhle.com/v1/schedule/\(path)") else { break }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let r = try? JSONDecoder().decode(NHLScheduleResponse.self, from: data) else { break }
        gotAny = true
        for day in r.gameWeek ?? [] {
            for g in day.games ?? [] {
                let state = (g.gameState ?? "").uppercased()
                let isFinal = state == "FINAL" || state == "OFF"
                guard let d = parseISODate(g.startTimeUTC),
                      let h = g.homeTeam?.abbrev.flatMap({ byAbbr[$0] }),
                      let a = g.awayTeam?.abbrev.flatMap({ byAbbr[$0] }) else { continue }
                out.append(ScheduleGame(id: "nhl-\(g.id ?? out.count)", date: d, home: h, away: a,
                                        live: state == "LIVE" || state == "CRIT", gameId: g.id, final: isFinal,
                                        homeScore: g.homeTeam?.score, awayScore: g.awayTeam?.score))
            }
        }
        guard let next = r.nextStartDate else { break }
        path = next
    }
    return gotAny ? out : nil
}

/// Hakee Liigan ottelut: tulevat, käynnissä olevat ja kahden viime päivän päättyneet.
@MainActor
func fetchLiigaSchedule(teams: [Team]) async -> [ScheduleGame]? {
    guard let games = await fetchLiigaGames() else { return nil }
    let liigaTeams = teams.filter { $0.league == .liiga }
    let seedByKey = Dictionary(uniqueKeysWithValues: liigaTeams.map { (AppStore.liigaKey($0.name), $0.name) })
    let now = Date()
    var out: [ScheduleGame] = []
    for (i, g) in games.enumerated() {
        guard let d = parseISODate(g.start),
              let ht = g.homeTeam, let at = g.awayTeam,
              let h = ht.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }),
              let a = at.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }) else { continue }
        let ended = g.ended?.value == true
        let started = g.started?.value == true
        if ended && d < now.addingTimeInterval(-48 * 3600) { continue }
        var game = ScheduleGame(id: "liiga-\(g.id?.value ?? i)", date: d, home: h, away: a)
        if ended || started {
            game.final = ended
            game.live = !ended
            game.homeScore = ht.goals ?? (ht.goalEvents ?? []).count
            game.awayScore = at.goals ?? (at.goalEvents ?? []).count
            game.liiga = makeLiigaDetail(g)
        }
        out.append(game)
    }
    return out
}

func makeLiigaDetail(_ g: LiigaGame) -> LiigaGameDetail {
    var d = LiigaGameDetail()
    for (isHome, team) in [(true, g.homeTeam), (false, g.awayTeam)] {
        for ev in team?.goalEvents ?? [] {
            d.goals.append(LiigaGoalLine(
                seconds: ev.gameTime?.value ?? 0,
                period: ev.period?.value ?? 0,
                home: isHome,
                scorer: ev.scorerPlayer?.fullName ?? "?",
                assists: (ev.assistantPlayers ?? []).map { $0.fullName }.filter { !$0.isEmpty },
                homeScore: ev.homeTeamScore?.value,
                awayScore: ev.awayTeamScore?.value,
                powerPlay: (ev.goalTypes ?? []).contains { $0.uppercased().hasPrefix("YV") }))
        }
    }
    d.goals.sort { $0.seconds < $1.seconds }
    d.rink = g.iceRink?.name
    d.spectators = g.spectators?.value
    func pp(_ t: LiigaTeam?) -> String? {
        guard let inst = t?.powerplayInstances?.value else { return nil }
        return "\(t?.powerplayGoals?.value ?? 0)/\(inst)"
    }
    d.homePP = pp(g.homeTeam)
    d.awayPP = pp(g.awayTeam)
    let ft = (g.finishedType ?? "").lowercased()
    if ft.contains("shootout") { d.resultNote = "Ratkesi rankkarikisassa" }
    else if ft.contains("extended") || ft.contains("overtime") { d.resultNote = "Ratkesi jatkoajalla" }
    return d
}

struct ScheduleView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var league: League = .nhl
    @State private var games: [ScheduleGame] = []
    @State private var loading = false
    @State private var failed = false
    @State private var selected: ScheduleGame?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "EEEE d.M."
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Seuraavat 14 päivää (käynnissä olevat ottelut mukaan lukien).
    private var upcoming: [ScheduleGame] {
        let now = Date()
        let to = now.addingTimeInterval(14 * 24 * 3600)
        return games.filter {
            (($0.final && $0.date >= now.addingTimeInterval(-48 * 3600)) || $0.date >= now.addingTimeInterval(-3 * 3600)) && $0.date <= to
        }.sorted { $0.date < $1.date }
    }

    private var days: [(day: Date, games: [ScheduleGame])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: upcoming) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Otteluohjelma").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                ForEach([League.nhl, League.ahl, League.liiga, League.mestis]) { l in
                    Button(l.label) { league = l }.buttonStyle(GhostButtonStyle(active: league == l))
                }
                Spacer()
                Text("Vieras – Koti · ajat omassa aikavyöhykkeessäsi").font(.system(size: 11)).foregroundStyle(Theme.muted)
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                Text("Otteluohjelman haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.")
                    .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if days.isEmpty {
                Text("Ei tulevia otteluita seuraavan 14 päivän aikana.")
                    .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(days, id: \.day) { entry in
                            VStack(alignment: .leading, spacing: 0) {
                                SectionLabel(ScheduleView.dayFormatter.string(from: entry.day))
                                    .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                                ForEach(Array(entry.games.enumerated()), id: \.element.id) { idx, g in
                                    gameRow(g, odd: idx % 2 == 1)
                                }
                            }
                            .padding(.bottom, 6)
                            .glassCard(radius: 12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 640, height: 760)
        .background(AppBackground())
        .task(id: league) {
            await load()
            // Päivitetään tulokset 20 s välein, kun ottelu on käynnissä tai alkamassa
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                if Task.isCancelled { break }
                let now = Date()
                if games.contains(where: { $0.live || (!$0.final && $0.date < now.addingTimeInterval(600) && $0.date > now.addingTimeInterval(-4 * 3600)) }) {
                    await load(silent: true)
                }
            }
        }
        .sheet(item: $selected) { GameDetailView(game: $0) }
    }

    @ViewBuilder
    private func gameRow(_ g: ScheduleGame, odd: Bool) -> some View {
        if g.gameId != nil || g.liiga != nil {
            Button { selected = g } label: { rowContent(g, odd: odd) }.buttonStyle(.plain)
        } else {
            rowContent(g, odd: odd)
        }
    }

    private func rowContent(_ g: ScheduleGame, odd: Bool) -> some View {
        HStack(spacing: 10) {
            Text(g.final ? "Päättynyt" : g.live ? "Käynnissä" : ScheduleView.timeFormatter.string(from: g.date))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(g.live ? Theme.green : Theme.muted)
                .frame(width: 74, alignment: .leading)
            Text(g.away).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
            TeamLogoView(team: g.away, size: 30).frame(width: 30, height: 26)
            if g.final || g.live, let a = g.awayScore, let h = g.homeScore {
                Text("\(a) – \(h)").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Theme.cyan)
                    .frame(width: 56)
            } else {
                Text("–").foregroundStyle(Theme.muted).frame(width: 56)
            }
            TeamLogoView(team: g.home, size: 30).frame(width: 30, height: 26)
            Text(g.home).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(odd ? Color.white.opacity(0.025) : .clear)
        .contentShape(Rectangle())
    }

    private func teamCell(_ name: String, logoAfterName: Bool = false) -> some View {
        HStack(spacing: 8) {
            if !logoAfterName { TeamLogoView(team: name, size: 30).frame(width: 30, height: 26) }
            Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer(minLength: 0)
            if logoAfterName { TeamLogoView(team: name, size: 30).frame(width: 30, height: 26) }
        }
        .frame(maxWidth: .infinity)
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true; failed = false; games = [] }
        let r: [ScheduleGame]?
        switch league {
        case .nhl: r = await fetchNHLSchedule(teams: store.teams)
        case .mestis: r = await fetchMestisSchedule(teams: store.teams)
        case .ahl: r = await fetchAHLSchedule(teams: store.teams)
        default: r = await fetchLiigaSchedule(teams: store.teams)
        }
        if let r { games = r } else if !silent { failed = true }
        if !silent { loading = false }
    }
}
