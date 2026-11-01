import SwiftUI

/// Vihjeehdokas: pelaaja + kohdetyyppi, perusteena viimeisten pelien osumat.
struct Tip: Identifiable {
    enum Kind: String, CaseIterable {
        case points = "Piste", assists = "Syöttö", goals = "Maali", pp = "Ylivoimapiste"
        case points2 = "2+ pistettä", assists2 = "2+ syöttöä", goals2 = "2+ maalia"
        /// Odds API -markkinan avain (+ "@" + raja) tai nil, jos kerrointa ei haeta.
        var market: String? {
            switch self {
            case .points: return "player_points@0.5"
            case .assists: return "player_assists@0.5"
            case .goals: return "player_goal_scorer_anytime"
            case .pp: return nil
            case .points2: return "player_points@1.5"
            case .assists2: return "player_assists@1.5"
            case .goals2: return "player_goals@1.5"
            }
        }
    }
    let player: Player
    let kind: Kind
    let hits: Int
    let games: Int
    let hot: Bool
    let fav: Bool
    var offers: [OddsOffer] = []
    var id: String { player.id + "|" + kind.rawValue }
    var rate: Double { games > 0 ? Double(hits) / Double(games) : 0 }
    var best: OddsOffer? { offers.max { $0.price < $1.price } }
}

/// Ottelun "Vihjeet"-välilehti: ehdotukset suosikeista ja vedossa olevista pelaajista sekä kuponkilaskuri.
struct TipsView: View {
    @Environment(AppStore.self) private var store
    let game: ScheduleGame
    /// true = Kupongit-sivu (valmiit kupongit), false = Vihjeet-lista ja oma kuponki.
    var coupons = false
    var onEdit: () -> Void = {}

    @State private var loading = true
    @State private var tips: [Tip] = []
    @State private var selected: [String] = []
    @State private var manual: [String: String] = [:]
    @State private var h2hLine = ""
    @State private var note = ""
    @State private var slipSize = 2
    @State private var favOnly = true
    @State private var kinds: Set<Tip.Kind> = Set(Tip.Kind.allCases)

    private var league: League { store.teamByName[game.home]?.league ?? .nhl }

    private func price(_ t: Tip) -> Double? {
        if let m = manual[t.id]?.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces), let v = Double(m), v > 1 { return v }
        return t.best?.price
    }

    private func score(_ t: Tip) -> Double { t.rate + (t.fav ? 0.15 : 0) + (t.hot ? 0.1 : 0) }

    /// Valmiit kuponkiehdotukset: parhaat yhdistelmät (eri pelaajat), joiden viimeisten pelien osumatiheyksien tulo on suurin.
    private var suggestions: [[Tip]] {
        let pool = Array(tips.filter { (!favOnly || $0.fav) && kinds.contains($0.kind) }.sorted { score($0) > score($1) }.prefix(9))
        guard pool.count >= slipSize else { return [] }
        var out: [([Tip], Double)] = []
        func rec(_ start: Int, _ cur: [Tip]) {
            if cur.count == slipSize { out.append((cur, cur.reduce(1.0) { $0 * $1.rate })); return }
            guard start < pool.count else { return }
            for i in start..<pool.count {
                if cur.contains(where: { $0.player.id == pool[i].player.id }) { continue }
                rec(i + 1, cur + [pool[i]])
            }
        }
        rec(0, [])
        return out.sorted { $0.1 > $1.1 }.prefix(6).map { $0.0 }
    }

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Kohteita kupongilla").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                GradientSegmented(selection: $slipSize, items: (2...5).map { ($0, "\($0)", String?.none) })
                    .frame(width: 200)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Kohdetyypit").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 6) {
                    ForEach(Tip.Kind.allCases, id: \.self) { k in
                        Toggle(k.rawValue, isOn: Binding(get: { kinds.contains(k) }, set: { on in
                            if on { kinds.insert(k) } else if kinds.count > 1 { kinds.remove(k) }
                        })).toggleStyle(.checkbox).font(.system(size: 12))
                    }
                }
            }
            Toggle("Vain suosikit", isOn: $favOnly).toggleStyle(.checkbox).font(.system(size: 12))
            let list = suggestions
            if list.isEmpty {
                Text(favOnly ? "Suosikkipelaajia ei ole tarpeeksi tälle kuponkikoolle ja valituille kohdetyypeille. Poista \"Vain suosikit\" tai merkitse lisää suosikkeja (3 tähteä)." : "Ei tarpeeksi kohteita tälle kuponkikoolle.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(list.enumerated()), id: \.offset) { _, combo in suggestionCard(combo) }
                }
            }
        }
    }

    private func suggestionCard(_ combo: [Tip]) -> some View {
        let ps = combo.map(price)
        let odds: Double? = ps.contains(where: { $0 == nil }) ? nil : ps.compactMap { $0 }.reduce(1, *)
        let rate = combo.reduce(1.0) { $0 * $1.rate }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(combo) { t in
                    Text("\(t.player.name) · \(t.kind.rawValue) (\(t.hits)/\(t.games))").font(.system(size: 12)).foregroundStyle(Theme.text)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(odds.map { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "–")
                    .font(.system(size: 16, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.cyan)
                Text("osumatiheys ~\(Int((rate * 100).rounded())) %").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Button("Muokkaa") { selected = combo.map(\.id); onEdit() }.buttonStyle(GhostButtonStyle()).fixedSize()
        }
        .padding(10)
        .glassCard(radius: 12)
    }

    private var slip: [Tip] { selected.compactMap { id in tips.first { $0.id == id } } }
    private var combinedOdds: Double? {
        let ps = slip.map(price)
        guard slip.count >= 2, !ps.contains(where: { $0 == nil }) else { return nil }
        return ps.compactMap { $0 }.reduce(1, *)
    }
    private var combinedRate: Double { slip.reduce(1) { $0 * $1.rate } }

    var body: some View {
        VStack(spacing: 10) {
            if !h2hLine.isEmpty {
                Text(h2hLine).font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            if loading {
                ProgressView("Haetaan vihjeitä…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tips.isEmpty {
                Text(note.isEmpty ? "Ei vihjeitä: joukkueiden pelaajilta ei löytynyt tarpeeksi viimeisten pelien tietoja." : note)
                    .font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if coupons {
                suggestionsView
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(tips) { t in tipRow(t) }
                    }
                }
                .glassCard()
                if !note.isEmpty {
                    Text(note).font(.system(size: 11)).foregroundStyle(Theme.amber).multilineTextAlignment(.center)
                }
                slipBar
            }
            Text("Vihjeet perustuvat vain viimeisten pelien tilastoihin eivätkä ole todennäköisyyksiä. Pelaa vastuullisesti.")
                .font(.system(size: 10)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .task { await load() }
    }

    private func tipRow(_ t: Tip) -> some View {
        let on = selected.contains(t.id)
        return HStack(spacing: 10) {
            Button {
                if on { selected.removeAll { $0 == t.id } }
                else if selected.count < 5 { selected.append(t.id) }
                else { store.flash("Kuponkiin voi valita enintään 5 kohdetta") }
            } label: {
                Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? Theme.cyan : Theme.muted)
            }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(t.player.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    if t.fav { Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Theme.amber) }
                    if t.hot { Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(Theme.flame) }
                }
                Text("\(t.kind.rawValue) · \(t.hits)/\(t.games) viimeisessä pelissä · \(t.player.team)")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if let b = t.best {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.2f", b.price).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 14, weight: .bold).monospacedDigit()).foregroundStyle(Theme.cyan)
                    Text(b.book).font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            } else {
                TextField("kerroin", text: Binding(get: { manual[t.id] ?? "" }, set: { manual[t.id] = $0 }))
                    .textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 60)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(on ? Theme.cyan.opacity(0.10) : .clear)
    }

    private var slipBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kuponki \(slip.count)/5").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.text)
                Text(slip.count < 2 ? "Valitse 2–5 kohdetta."
                     : "Karkea osumatiheys \(Int((combinedRate * 100).rounded())) % (oletus: kohteet toisistaan riippumattomia)")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if let c = combinedOdds {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.2f", c).replacingOccurrences(of: ".", with: ","))
                        .font(.system(size: 18, weight: .heavy).monospacedDigit()).foregroundStyle(Theme.cyan)
                    Text("yhdistelmäkerroin").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            } else if slip.count >= 2 {
                Text("syötä puuttuvat kertoimet").font(.system(size: 11)).foregroundStyle(Theme.amber)
            }
            if !slip.isEmpty { Button("Tyhjennä") { selected.removeAll() }.buttonStyle(GhostButtonStyle()) }
        }
        .padding(12)
        .glassCard()
    }

    // MARK: Lataus

    private func load() async {
        loading = true
        let names = Set([game.home, game.away])
        let favs = store.players.filter { names.contains($0.team) && $0.pos != "G" && ($0.games ?? 0) > 0 }
        // Ehdokkaat: suosikit ja eniten pisteitä tehneet (pelaajamäärä rajattu hakujen vuoksi)
        var cands: [Player] = []
        for t in names {
            let mine = favs.filter { $0.team == t }.sorted {
                let a = store.rating($0.id) == 3 ? 1 : 0, b = store.rating($1.id) == 3 ? 1 : 0
                return a != b ? a > b : ($0.points ?? 0) > ($1.points ?? 0)
            }
            cands += mine.prefix(12)
        }
        var recents: [String: [RecentGame]] = [:]
        await withTaskGroup(of: (String, [RecentGame]).self) { group in
            for p in cands { group.addTask { (p.id, await store.recentGames(for: p).games) } }
            for await (id, g) in group { recents[id] = g }
        }
        var built: [Tip] = []
        for p in cands {
            let g = recents[p.id] ?? []
            guard g.count >= 3 else { continue }
            let fav = store.rating(p.id) == 3, hot = store.isHot(p)
            func add(_ k: Tip.Kind, _ hits: Int, min: Int) {
                if hits >= min || fav && hits >= 2 { built.append(Tip(player: p, kind: k, hits: hits, games: g.count, hot: hot, fav: fav)) }
            }
            add(.points, g.filter { $0.points >= 1 }.count, min: 3)
            add(.assists, g.filter { $0.assists >= 1 }.count, min: 3)
            add(.goals, g.filter { $0.goals >= 1 }.count, min: 2)
            if g.contains(where: { $0.pp != nil }) { add(.pp, g.filter { ($0.pp ?? 0) >= 1 }.count, min: 2) }
            add(.points2, g.filter { $0.points >= 2 }.count, min: 2)
            add(.assists2, g.filter { $0.assists >= 2 }.count, min: 2)
            add(.goals2, g.filter { $0.goals >= 2 }.count, min: 2)
        }
        built.sort {
            let a = $0.rate + ($0.fav ? 0.15 : 0) + ($0.hot ? 0.1 : 0), b = $1.rate + ($1.fav ? 0.15 : 0) + ($1.hot ? 0.1 : 0)
            return a != b ? a > b : $0.player.name < $1.player.name
        }
        tips = Array(built.prefix(30))

        // Kertoimet Odds API:sta
        if !store.hasOddsKey {
            note = "Lisää Odds API -avain Asetuksissa, niin ehdotuksiin haetaan kertoimet. Voit syöttää kertoimet myös käsin."
        } else if let ev = await OddsService.events(OddsService.sportKey(league)), let ref = OddsService.match(game, in: ev) {
            if let h = await OddsService.h2h(OddsService.sportKey(league)), let eo = h[ref.id] {
                let parts = [ref.away, ref.home].map { team -> String in
                    let best = eo.h2h[team]?.sorted { $0.price > $1.price }.prefix(2).map { "\($0.book) \(String(format: "%.2f", $0.price).replacingOccurrences(of: ".", with: ","))" }.joined(separator: ", ") ?? "–"
                    return "\(team): \(best)"
                }
                h2hLine = "Voittaja (parhaat): " + parts.joined(separator: " · ")
            }
            if OddsService.hasPlayerProps(league) {
                if let props = await OddsService.props(OddsService.sportKey(league), eventId: ref.id) {
                    for i in tips.indices {
                        guard let m = tips[i].kind.market, let byPlayer = props[m] else { continue }
                        tips[i].offers = byPlayer[AppStore.norm(tips[i].player.name)] ?? []
                    }
                    if props.isEmpty { note = "Tälle ottelulle ei ole vielä pelaajakohtaisia kertoimia." }
                } else { note = "Pelaajakohtaisten kertoimien haku epäonnistui." }
            } else {
                note = "Tälle sarjalle Odds API ei tarjoa pelaajakohtaisia kertoimia. Syötä kertoimet käsin."
            }
            if let r = OddsService.lastRemaining { note += (note.isEmpty ? "" : " ") + "Odds API -kyselyjä jäljellä: \(r)." }
        } else {
            note = "Ottelua ei löytynyt Odds API:sta (kertoimia ei ole vielä julkaistu). Syötä kertoimet käsin."
        }
        loading = false
    }
}
