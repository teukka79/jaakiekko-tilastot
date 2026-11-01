import SwiftUI

// MARK: - Alkamattoman ottelun esittely (kunto, kovimmat pelaajat, keskinäiset ottelut, erikoistilanteet, kertoimet, maalivahdit)

private struct FormRow: Identifiable {
    let id = UUID()
    let game: LeagueGame
    let home: Bool
    let gf: Int
    let ga: Int
    let opponent: String
    var win: Bool { gf > ga }
}

private struct SpecialTeams {
    var pp: Double?
    var pk: Double?
}

struct MatchPreviewView: View {
    @Environment(AppStore.self) private var store
    let game: ScheduleGame

    @State private var loading = true
    @State private var failed = false
    @State private var games: [LeagueGame] = []
    @State private var table: [StandingRow] = []
    @State private var special: [String: SpecialTeams] = [:]
    @State private var odds: EventOdds?
    @State private var oddsRef: OddsService.OddsEventRef?

    private var league: League? { store.teamByName[game.home]?.league }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "d.M."
        return f
    }()

    // MARK: Laskenta

    private func lastGames(_ team: String, _ n: Int) -> [FormRow] {
        let mine = games.filter { $0.final && ($0.home == team || $0.away == team) }.sorted { $0.date > $1.date }
        return mine.prefix(n).map { g in
            let isHome = g.home == team
            return FormRow(game: g, home: isHome, gf: isHome ? g.hs : g.aw, ga: isHome ? g.aw : g.hs,
                           opponent: isHome ? g.away : g.home)
        }
    }

    private func headToHead() -> [LeagueGame] {
        games.filter { $0.final && (($0.home == game.home && $0.away == game.away) || ($0.home == game.away && $0.away == game.home)) }
            .sorted { $0.date > $1.date }
    }

    private func standing(_ team: String) -> String? {
        guard let i = table.firstIndex(where: { $0.team == team }) else { return nil }
        return "\(i + 1). sija · \(table[i].pts) p"
    }

    private func topPlayers(_ team: String) -> [Player] {
        store.players
            .filter { $0.team == team && $0.league == league }
            .sorted {
                let a = $0.points ?? -1, b = $1.points ?? -1
                return a == b ? ($0.goals ?? 0) > ($1.goals ?? 0) : a > b
            }
            .prefix(3).map { $0 }
    }

    private func goalie(_ team: String) -> Goalie? {
        store.goalies.filter { $0.team == team }.max { $0.games < $1.games }
    }

    // MARK: Näkymä

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed && games.isEmpty {
                Text("Tietojen haku epäonnistui. Tarkista verkkoyhteys ja avaa ikkuna uudelleen.")
                    .foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        formCard
                        playersCard
                        h2hCard
                        if special[game.home] != nil || special[game.away] != nil { specialCard }
                        if odds != nil || goalie(game.home) != nil || goalie(game.away) != nil { oddsGoalieCard }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .task { await load() }
    }

    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(Theme.muted)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: Kunto

    private var formCard: some View {
        card("Kunto · viimeiset 5 ottelua") {
            HStack(alignment: .top, spacing: 16) {
                formColumn(game.away)
                formColumn(game.home)
            }
            Text("V = voitto, H = tappio, T = tappio jatkoajalla tai rankkareilla. (k) = kotipeli, (v) = vieraspeli.")
                .font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
    }

    private func formColumn(_ team: String) -> some View {
        let rows = lastGames(team, 5)
        let w = rows.filter { $0.win }.count
        let gf = rows.reduce(0) { $0 + $1.gf }
        let ga = rows.reduce(0) { $0 + $1.ga }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(team).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                if let s = standing(team) { Text(s).font(.system(size: 11)).foregroundStyle(Theme.muted) }
            }
            if rows.isEmpty {
                Text("Ei pelattuja otteluita.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            } else {
                HStack(spacing: 4) {
                    ForEach(rows) { r in dot(r) }
                }
                Text("\(w) V · \(rows.count - w) H · maalit \(gf)–\(ga)")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
                ForEach(rows.prefix(3)) { r in
                    HStack {
                        Text("\(Self.dayFmt.string(from: r.game.date)) \(r.opponent) (\(r.home ? "k" : "v"))")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(r.gf)–\(r.ga)\(r.game.extra.map { " \($0)" } ?? "")")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(r.win ? Theme.green : (r.game.extra != nil ? Theme.amber : Theme.red))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dot(_ r: FormRow) -> some View {
        let color: Color = r.win ? Theme.green : (r.game.extra != nil ? Theme.amber : Theme.red)
        let letter = r.win ? "V" : (r.game.extra != nil ? "T" : "H")
        return Text(letter).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color.black)
            .frame(width: 22, height: 22).background(Circle().fill(color))
    }

    // MARK: Kovimmat pelaajat

    private var playersCard: some View {
        card("Kovimmat pelaajat") {
            HStack(alignment: .top, spacing: 16) {
                playerColumn(game.away)
                playerColumn(game.home)
            }
            Text("🔥 = piste jokaisessa neljässä viime pelissä · ★ = suosikkisi")
                .font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
    }

    private func playerColumn(_ team: String) -> some View {
        let list = topPlayers(team)
        return VStack(alignment: .leading, spacing: 5) {
            if list.isEmpty {
                Text("Ei pelaajatietoja.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, p in
                HStack(spacing: 5) {
                    Text("\(i + 1)").font(.system(size: 11)).foregroundStyle(Theme.muted).frame(width: 12, alignment: .leading)
                    Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    if store.isHot(p) { Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(Theme.flame) }
                    if store.rating(p.id) == 3 { Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.amber) }
                    Spacer(minLength: 2)
                    Text("\(p.points ?? 0) p").font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.text)
                    Text("(\(p.goals ?? 0)+\(p.assists ?? 0))").font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Keskinäiset ottelut

    private var h2hCard: some View {
        let list = headToHead()
        return card("Keskinäiset ottelut (kausi)") {
            if list.isEmpty {
                Text("Joukkueet eivät ole vielä kohdanneet tällä kaudella.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            } else {
                ForEach(Array(list.prefix(4).enumerated()), id: \.offset) { _, g in
                    HStack {
                        Text("\(Self.dayFmt.string(from: g.date)) \(g.home) – \(g.away)").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text("\(g.hs)–\(g.aw)\(g.extra.map { " \($0)" } ?? "")").font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(Theme.text)
                    }
                }
                let homeWins = list.filter { ($0.home == game.home && $0.hs > $0.aw) || ($0.away == game.home && $0.aw > $0.hs) }.count
                let awayWins = list.count - homeWins
                Text("\(game.home) \(homeWins) voittoa · \(game.away) \(awayWins) voittoa")
                    .font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Erikoistilanteet (Liiga)

    private func pct(_ v: Double?) -> String { v.map { String(format: "%.0f %%", $0) } ?? "–" }

    private func compareBar(_ title: String, _ a: Double?, _ h: Double?) -> some View {
        let av = max(a ?? 0, 0.1), hv = max(h ?? 0, 0.1)
        return VStack(spacing: 4) {
            HStack {
                Text("\(title) \(game.away) \(pct(a))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
                Text("\(game.home) \(pct(h))").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
            }
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(Theme.indigo).frame(width: geo.size.width * av / (av + hv))
                    Rectangle().fill(Theme.cyan)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)
        }
    }

    private var specialCard: some View {
        card("Erikoistilanteet") {
            compareBar("Ylivoima", special[game.away]?.pp, special[game.home]?.pp)
            compareBar("Alivoima", special[game.away]?.pk, special[game.home]?.pk)
        }
    }

    // MARK: Kertoimet ja maalivahdit

    private func best(_ name: String) -> OddsOffer? { odds?.h2h[name]?.max { $0.price < $1.price } }

    private var oddsGoalieCard: some View {
        card("Kertoimet ja maalivahdit") {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Voittajakertoimet").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    if let ref = oddsRef, odds != nil {
                        oddsRow(game.away, best(ref.away), Theme.indigo)
                        if let d = best("Draw") { oddsRow("Tasapeli", d, Theme.text) }
                        oddsRow(game.home, best(ref.home), Theme.cyan)
                    } else {
                        Text(store.hasOddsKey ? "Ei kertoimia tälle ottelulle." : "Lisää Odds API -avain asetuksissa.")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Maalivahdit (eniten pelannut)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
                    goalieRow(game.away)
                    goalieRow(game.home)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func oddsRow(_ name: String, _ o: OddsOffer?, _ color: Color) -> some View {
        HStack {
            Text(name).font(.system(size: 12)).foregroundStyle(Theme.text).lineLimit(1)
            Spacer(minLength: 4)
            if let o {
                Text(String(format: "%.2f", o.price)).font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(color)
                Text(o.book).font(.system(size: 10)).foregroundStyle(Theme.muted)
            } else {
                Text("–").foregroundStyle(Theme.muted)
            }
        }
    }

    private func goalieRow(_ team: String) -> some View {
        HStack {
            if let g = goalie(team) {
                Text(g.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                Spacer(minLength: 4)
                Text("\(g.savePct.map { String(format: "%.1f %%", $0) } ?? "–") · \(g.gaa.map { String(format: "%.2f", $0) } ?? "–")")
                    .font(.system(size: 11).monospacedDigit()).foregroundStyle(Theme.muted)
            } else {
                Text("\(team): ei tietoa").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
    }

    // MARK: Haku

    private func loadTable(_ l: League) async -> [StandingRow]? {
        switch l {
        case .nhl: return await fetchNHLStandings(teams: store.teams)
        case .mestis: return await fetchMestisStandings(teams: store.teams)
        case .ahl: return await fetchAHLStandings(teams: store.teams, season: await fetchAHLSeasonId())
        case .shl, .allsvenskan: return await fetchSweStandings(league: l, teams: store.teams)
        case .nl: return await fetchNLStandings(teams: store.teams)
        default: return await fetchLiigaStandings(teams: store.teams)
        }
    }

    private func loadSpecial() async -> [String: SpecialTeams] {
        guard let all = await fetchLiigaGames() else { return [:] }
        let seedByKey = Dictionary(uniqueKeysWithValues: store.teams.filter { $0.league == .liiga }.map { (AppStore.liigaKey($0.name), $0.name) })
        var ppG: [String: Int] = [:], ppI: [String: Int] = [:], pkG: [String: Int] = [:], pkI: [String: Int] = [:]
        for g in all where g.ended?.value == true {
            guard let ht = g.homeTeam, let at = g.awayTeam,
                  let h = ht.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }),
                  let a = at.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }) else { continue }
            let hi = ht.powerplayInstances?.value ?? 0, hg = ht.powerplayGoals?.value ?? 0
            let ai = at.powerplayInstances?.value ?? 0, ag = at.powerplayGoals?.value ?? 0
            ppI[h, default: 0] += hi; ppG[h, default: 0] += hg; pkI[h, default: 0] += ai; pkG[h, default: 0] += ag
            ppI[a, default: 0] += ai; ppG[a, default: 0] += ag; pkI[a, default: 0] += hi; pkG[a, default: 0] += hg
        }
        var out: [String: SpecialTeams] = [:]
        for t in Set(ppI.keys).union(pkI.keys) {
            var s = SpecialTeams()
            if let i = ppI[t], i > 0 { s.pp = Double(ppG[t] ?? 0) / Double(i) * 100 }
            if let i = pkI[t], i > 0 { s.pk = (1 - Double(pkG[t] ?? 0) / Double(i)) * 100 }
            out[t] = s
        }
        return out
    }

    private func load() async {
        guard let l = league else { loading = false; failed = true; return }
        async let g = fetchLeagueGames(league: l, teams: store.teams)
        async let t = loadTable(l)
        let gl = await g
        failed = gl == nil
        games = gl ?? []
        table = sortStandings(await t ?? [])
        if l == .liiga { special = await loadSpecial() }
        loading = false
        // Kertoimet haetaan erikseen, jotta muu näkymä ei odota niitä
        if store.hasOddsKey {
            let sport = OddsService.sportKey(l)
            if let evs = await OddsService.events(sport), let ref = OddsService.match(game, in: evs),
               let all = await OddsService.h2h(sport), let eo = all[ref.id] {
                oddsRef = ref
                odds = eo
            }
        }
    }
}
