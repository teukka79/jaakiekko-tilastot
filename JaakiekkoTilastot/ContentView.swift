import SwiftUI
import UniformTypeIdentifiers

enum SortKey: String, CaseIterable {
    case name, number, nat, slot, team, games, goals, assists, points, ppg, shots, pp, plusMinus, rating, recent
}

enum ViewMode { case table, teams }

enum ActiveSheet: Identifiable {
    case detail(String)
    case add
    case compare
    case settings
    case standings
    case schedule
    case teamResults(String)

    var id: String {
        switch self {
        case .detail(let i): return "detail-\(i)"
        case .add: return "add"
        case .compare: return "compare"
        case .settings: return "settings"
        case .standings: return "standings"
        case .schedule: return "schedule"
        case .teamResults(let t): return "teamResults-\(t)"
        }
    }
}

struct ContentView: View {
    @Environment(AppStore.self) private var store

    @State private var league: League? = .nhl
    @State private var team: String?
    @State private var search = ""
    @State private var sortKey: SortKey = .points
    @State private var ascending = false
    @State private var onlyFavs = false
    @State private var onlyHot = false
    @State private var posFilter: PosFilter = .all
    @State private var hoverID: String?
    @State private var gSort: GoalieSort = .wins
    @State private var gAsc = false
    @State private var mode: ViewMode = .table
    @State private var compareIDs: [String] = []
    @State private var sheet: ActiveSheet?
    @State private var exporting = false
    @State private var importing = false
    @State private var exportDoc = BackupDocument(data: Data())

    // MARK: Suodatus ja lajittelu

    private var visible: [Player] {
        let q = AppStore.norm(search)
        _ = store.recentVersion   // lajittelu päivittyy, kun viimeisten pelien tiedot latautuvat
        var list = store.players.filter { p in
            (league == nil || p.league == league)
            && (team == nil || p.team == team)
            && posFilter.matches(p)
            && (!onlyFavs || store.rating(p.id) == 3)
            && (!onlyHot || store.isHot(p))
            && (q.isEmpty || AppStore.norm(p.name + " " + p.team + " " + (p.nat ?? "")).contains(q))
        }
        func cmp<T: Comparable>(_ a: T?, _ b: T?, _ x: Player, _ y: Player) -> Bool {
            switch (a, b) {
            case (nil, nil): return x.name < y.name
            case (nil, _): return false          // puuttuvat arvot aina loppuun
            case (_, nil): return true
            case let (l?, r?): return l == r ? x.name < y.name : (ascending ? l < r : l > r)
            }
        }
        list.sort { x, y in
            switch sortKey {
            case .name: return ascending ? x.name < y.name : x.name > y.name
            case .number: return cmp(x.number, y.number, x, y)
            case .nat: return x.natLabel == y.natLabel ? x.name < y.name : (ascending ? x.natLabel < y.natLabel : x.natLabel > y.natLabel)
            case .slot: return x.slotLabel == y.slotLabel ? x.name < y.name : (ascending ? x.slotLabel < y.slotLabel : x.slotLabel > y.slotLabel)
            case .team: return x.team == y.team ? x.name < y.name : (ascending ? x.team < y.team : x.team > y.team)
            case .games: return cmp(x.games, y.games, x, y)
            case .goals: return cmp(x.goals, y.goals, x, y)
            case .assists: return cmp(x.assists, y.assists, x, y)
            case .points: return cmp(x.points, y.points, x, y)
            case .ppg: return cmp(x.pointsPerGame, y.pointsPerGame, x, y)
            case .shots: return cmp(x.shots, y.shots, x, y)
            case .pp: return cmp(x.ppPoints, y.ppPoints, x, y)
            case .plusMinus: return cmp(x.plusMinus, y.plusMinus, x, y)
            case .rating:
                let a = store.rating(x.id), b = store.rating(y.id)
                return a == b ? x.name < y.name : (ascending ? a < b : a > b)
            case .recent:
                let m = StripMode(sort: sortKey)
                let a = store.recentSum(x, mode: m), b = store.recentSum(y, mode: m)
                if a == b { return cmp(x.points, y.points, x, y) }
                return cmp(a, b, x, y)
            }
        }
        return list
    }

    private var visibleGoalies: [Goalie] {
        let q = AppStore.norm(search)
        var list = store.goalies.filter { g in
            (league == nil || g.league == league)
            && (team == nil || g.team == team)
            && (!onlyFavs || store.rating(g.id) == 3)
            && (q.isEmpty || AppStore.norm(g.name + " " + g.team + " " + (g.nat ?? "")).contains(q))
        }
        func cmp<T: Comparable>(_ a: T?, _ b: T?, _ x: Goalie, _ y: Goalie, lowerIsBetter: Bool = false) -> Bool {
            switch (a, b) {
            case (nil, nil): return x.name < y.name
            case (nil, _): return false
            case (_, nil): return true
            case let (l?, r?): return l == r ? x.name < y.name : (gAsc ? l < r : l > r)
            }
        }
        list.sort { x, y in
            switch gSort {
            case .name: return gAsc ? x.name < y.name : x.name > y.name
            case .number: return cmp(x.number, y.number, x, y)
            case .nat: return x.natLabel == y.natLabel ? x.name < y.name : (gAsc ? x.natLabel < y.natLabel : x.natLabel > y.natLabel)
            case .team: return x.team == y.team ? x.name < y.name : (gAsc ? x.team < y.team : x.team > y.team)
            case .games: return cmp(x.games, y.games, x, y)
            case .wins: return cmp(x.wins, y.wins, x, y)
            case .savePct: return cmp(x.savePct, y.savePct, x, y)
            case .gaa: return cmp(x.gaa, y.gaa, x, y)
            case .shutouts: return cmp(x.shutouts, y.shutouts, x, y)
            case .saves: return cmp(x.saves, y.saves, x, y)
            case .shots: return cmp(x.shotsAgainst, y.shotsAgainst, x, y)
            case .rating:
                let a = store.rating(x.id), b = store.rating(y.id)
                return a == b ? x.name < y.name : (gAsc ? a < b : a > b)
            }
        }
        return list
    }

    // MARK: Runko

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 14) {
                header
                toolbar
                if mode == .table { (posFilter == .goalie ? AnyView(goalieTable) : AnyView(table)) } else {
                    TeamsGridView(league: league) { name in
                        team = name
                        if let l = store.teamByName[name]?.league { league = l }
                        mode = .table
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 18)

            if let toast = store.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Theme.hairline))
                        .padding(.bottom, 26)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toast)
        .task {
            await store.refreshLive()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await store.autoRefreshTick()
            }
        }
        .onChange(of: league) { _, new in
            if let t = team, let tl = store.teamByName[t]?.league, new != nil, tl != new { team = nil }
        }
        .sheet(item: $sheet) { s in
            switch s {
            case .detail(let id): PlayerDetailView(playerID: id)
            case .add: PlayerFormView(player: nil, defaultLeague: league ?? .nhl)
            case .compare: CompareView(ids: compareIDs) { compareIDs.removeAll() }
            case .settings: SettingsView()
            case .standings: StandingsView()
            case .schedule: ScheduleView(initial: league ?? .nhl)
            case .teamResults(let t): TeamResultsView(teamName: t)
            }
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: "jaakiekko-pistepörssi-2026-2027") { result in
            if case .success = result { store.flash("Vienti valmis") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { store.importData(data) }
        }
    }

    // MARK: Otsikko

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Jääkiekko Tilastot")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(Theme.accentGradient)
                Text("Kausi 2026/2027 · \(posFilter == .goalie ? visibleGoalies.count : visible.count) \(posFilter == .goalie ? "maalivahtia" : "pelaajaa") · \(store.ratedCount) arvosteltu · \(store.notesCount) muistiinpanoa")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            HStack(spacing: 8) {
                if store.isRefreshing { ProgressView().controlSize(.small) }
                Text(store.liveStatus).font(.system(size: 11)).foregroundStyle(Theme.muted)
                    .lineLimit(2).multilineTextAlignment(.trailing).frame(maxWidth: 420, alignment: .trailing)
                Button {
                    Task { await store.refreshLive(force: true) }
                } label: { Label("Päivitä", systemImage: "arrow.clockwise") }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(store.isRefreshing)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Työkalurivi

    private var toolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                leagueButton(nil, label: "Kaikki")
                ForEach(League.allCases) { l in leagueButton(l, label: l.label) }
                Spacer()
                GradientSegmented(selection: $mode, items: [
                    (ViewMode.table, "Taulukko", "tablecells"),
                    (ViewMode.teams, "Joukkueet", "square.grid.2x2")
                ])
                .frame(width: 220)
            }
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("Hae pelaajaa, joukkuetta tai kansallisuutta", text: $search)
                        .textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
                .frame(maxWidth: 360)

                Picker("Pelipaikka", selection: $posFilter) {
                    ForEach(PosFilter.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 190)

                Picker("Joukkue", selection: Binding<String?>(
                    get: { team.flatMap { store.teamNames(in: league).contains($0) ? $0 : nil } },
                    set: { team = $0 })) {
                    Text("Kaikki joukkueet").tag(String?.none)
                    ForEach(store.teamNames(in: league), id: \.self) { Text($0).tag(String?.some($0)) }
                }
                .frame(width: 210)

                Button { onlyFavs.toggle() } label: {
                    Label("Suosikit", systemImage: onlyFavs ? "star.fill" : "star")
                }
                .buttonStyle(GhostButtonStyle(active: onlyFavs))

                Button { onlyHot.toggle() } label: {
                    Label("Liekissä", systemImage: onlyHot ? "flame.fill" : "flame")
                }
                .buttonStyle(GhostButtonStyle(active: onlyHot))
                .help("Vähintään yksi piste jokaisessa neljässä viimeisessä pelissä. Valitse sarja ylhäältä tai Kaikki.")

                Spacer()

                Button {
                    sheet = .compare
                } label: { Label("Vertaa (\(compareIDs.count))", systemImage: "rectangle.split.3x1") }
                    .buttonStyle(GhostButtonStyle(active: compareIDs.count >= 2))
                    .disabled(compareIDs.count < 2)

                Button { sheet = .standings } label: { Label("Sarjataulukko", systemImage: "list.number") }
                    .buttonStyle(GhostButtonStyle())
                Button { sheet = .schedule } label: { Label("Otteluohjelma", systemImage: "calendar") }
                    .buttonStyle(GhostButtonStyle())
                if let t = team {
                    Button { sheet = .teamResults(t) } label: { Label("Joukkueen tulokset", systemImage: "chart.bar") }
                        .buttonStyle(GhostButtonStyle())
                }
                Menu {
                    Button("Vie JSON…") {
                        if let d = store.exportData() { exportDoc = BackupDocument(data: d); exporting = true }
                    }
                    Button("Tuo JSON…") { importing = true }
                    Button("Sarjataulukko") { sheet = .standings }
                    Button("Otteluohjelma") { sheet = .schedule }
                    Button("Asetukset…") { sheet = .settings }
                    Divider()
                    Button("Nollaa näkyvien tähdet") { store.resetRatings(in: visible) }
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).frame(width: 34)
            }
        }
    }

    private func leagueButton(_ l: League?, label: String) -> some View {
        Button {
            league = l
        } label: {
            HStack(spacing: 5) {
                if let l { Text(l.flags) }
                Text(label)
            }
        }
        .buttonStyle(GhostButtonStyle(active: league == l))
    }

    // MARK: Taulukko

    private struct Col: Identifiable {
        let key: SortKey
        let title: String
        let width: CGFloat?
        var id: SortKey { key }
    }

    private let cols: [Col] = [
        Col(key: .name, title: "Pelaaja", width: nil),
        Col(key: .number, title: "Nro", width: 40),
        Col(key: .nat, title: "Kansalaisuus", width: 100),
        Col(key: .slot, title: "Pelipaikka", width: 100),
        Col(key: .games, title: "Ottelut", width: 58),
        Col(key: .goals, title: "Maalit", width: 54),
        Col(key: .assists, title: "Syötöt", width: 54),
        Col(key: .points, title: "Pisteet", width: 56),
        Col(key: .ppg, title: "Pist./ott.", width: 70),
        Col(key: .shots, title: "Laukaukset", width: 78),
        Col(key: .pp, title: "Ylivoima", width: 62),
        Col(key: .plusMinus, title: "+/-", width: 46),
        Col(key: .rating, title: "Tähdet", width: 84),
    ]

    private func toggleSort(_ k: SortKey) {
        if sortKey == k { ascending.toggle() } else {
            sortKey = k
            ascending = (k == .name || k == .team || k == .slot || k == .nat)
        }
        if sortKey == .recent { store.prefetchRecent(visible) }
    }

    private var table: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 22, height: 1)
                ForEach(cols) { c in
                    if c.key == .rating {
                        Button { toggleSort(.recent) } label: {
                            HStack(spacing: 3) {
                                Text("Viim. 5: \(StripMode(sort: sortKey).label)").lineLimit(1)
                                if sortKey == .recent {
                                    Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                                    if store.recentLoading { ProgressView().controlSize(.mini) }
                                }
                            }
                            .frame(width: 156)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(sortKey == .recent ? Theme.cyan : Theme.muted)
                        .help("Lajittele viiden viimeisen pelin summan mukaan. Luku seuraa lajittelua: maalit, syötöt, ylivoima tai laukaukset; muuten pisteet. Tiedot haetaan listan pelaajille ensimmäisellä kerralla.")
                    }
                    Button { toggleSort(c.key) } label: {
                        HStack(spacing: 3) {
                            Text(c.title).lineLimit(1).fixedSize()
                            if sortKey == c.key { Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.system(size: 8)) }
                        }
                        .frame(maxWidth: c.width == nil ? .infinity : c.width, alignment: c.width == nil ? .leading : .center)
                        .frame(width: c.width)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(sortKey == c.key ? Theme.cyan : Theme.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Theme.hairline)

            if visible.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundStyle(Theme.muted)
                    Text("Ei hakua vastaavia pelaajia").foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { idx, p in
                            row(p, odd: idx % 2 == 1)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: Maalivahtitaulukko

    private struct GCol: Identifiable {
        let key: GoalieSort
        let title: String
        let width: CGFloat?
        var id: GoalieSort { key }
    }

    private let gcols: [GCol] = [
        GCol(key: .name, title: "Maalivahti", width: nil),
        GCol(key: .number, title: "Nro", width: 40),
        GCol(key: .nat, title: "Kansalaisuus", width: 100),
        GCol(key: .games, title: "Ottelut", width: 58),
        GCol(key: .wins, title: "Voitot", width: 54),
        GCol(key: .savePct, title: "Torjunta-%", width: 80),
        GCol(key: .gaa, title: "Päästetyt/ott.", width: 96),
        GCol(key: .shutouts, title: "Nollapelit", width: 74),
        GCol(key: .saves, title: "Torjunnat", width: 70),
        GCol(key: .shots, title: "Laukaukset", width: 78),
        GCol(key: .rating, title: "Tähdet", width: 84),
    ]

    private func toggleGSort(_ k: GoalieSort) {
        if gSort == k { gAsc.toggle() } else {
            gSort = k
            gAsc = (k == .name || k == .team || k == .nat || k == .gaa)
        }
    }

    private var goalieTable: some View {
        let list = visibleGoalies
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 22, height: 1)
                ForEach(gcols) { c in
                    Button { toggleGSort(c.key) } label: {
                        HStack(spacing: 3) {
                            Text(c.title).lineLimit(1).fixedSize()
                            if gSort == c.key { Image(systemName: gAsc ? "chevron.up" : "chevron.down").font(.system(size: 8)) }
                        }
                        .frame(maxWidth: c.width == nil ? .infinity : c.width, alignment: c.width == nil ? .leading : .center)
                        .frame(width: c.width)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(gSort == c.key ? Theme.cyan : Theme.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Theme.hairline)

            if list.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "hockey.puck").font(.system(size: 28)).foregroundStyle(Theme.muted)
                    Text(store.goalies.isEmpty || league == .shl || league == .allsvenskan || league == .mestis
                         ? "Maalivahtitilastoja ei ole vielä saatavilla tälle sarjalle"
                         : "Ei hakua vastaavia maalivahteja")
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { idx, g in
                            goalieRow(g, odd: idx % 2 == 1)
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    private func goalieRow(_ g: Goalie, odd: Bool) -> some View {
        let selected = compareIDs.contains(g.id)
        return HStack(spacing: 8) {
            Button {
                if compareIDs.first?.hasPrefix("g-") == false { compareIDs.removeAll() }
                if selected { compareIDs.removeAll { $0 == g.id } }
                else if compareIDs.count < 3 { compareIDs.append(g.id) }
                else { store.flash("Vertailuun voi valita enintään 3 maalivahtia") }
            } label: {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Theme.cyan : Theme.muted)
            }
            .buttonStyle(.plain).frame(width: 22)
            .accessibilityLabel("Valitse vertailuun")
            HStack(spacing: 10) {
                TeamLogoView(team: g.team, size: 44).frame(width: 44, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(g.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                    Text("\(g.flag) \(g.team)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            Text(g.number.map { "#\($0)" } ?? "–").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted).frame(width: 40)
            Text(g.natLabel).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1).frame(width: 100)
            cell(String(g.games), 58)
            cell(num(g.wins), 54)
            cell(g.savePct.map { String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ",") } ?? "–", 80, bold: true, color: Theme.cyan)
            cell(g.gaa.map { String(format: "%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "–", 96)
            cell(num(g.shutouts), 74)
            cell(num(g.saves), 70)
            cell(num(g.shotsAgainst), 78)
            StarsView(value: store.rating(g.id)) { store.setRating(g.id, $0) }
                .frame(width: 84)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(selected ? Theme.cyan.opacity(0.10) : hoverID == g.id ? Theme.cyan.opacity(0.09) : (odd ? Color.white.opacity(0.025) : .clear))
        .onHover { h in
            if h { hoverID = g.id } else if hoverID == g.id { hoverID = nil }
        }
    }

    private func row(_ p: Player, odd: Bool) -> some View {
        let selected = compareIDs.contains(p.id)
        return HStack(spacing: 8) {
            Button {
                if compareIDs.first?.hasPrefix("g-") == true { compareIDs.removeAll() }
                if compareIDs.contains(p.id) { compareIDs.removeAll { $0 == p.id } }
                else if compareIDs.count < 3 { compareIDs.append(p.id) }
                else { store.flash("Vertailuun voi valita enintään 3 pelaajaa") }
            } label: {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? Theme.cyan : Theme.muted)
            }
            .buttonStyle(.plain).frame(width: 22)
            .accessibilityLabel("Valitse vertailuun")

            Button { sheet = .detail(p.id) } label: {
                HStack(spacing: 10) {
                    TeamLogoView(team: p.team, size: 44)
                        .frame(width: 44, height: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(p.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                            if store.isHot(p) { Image(systemName: "flame.fill").font(.system(size: 12)).foregroundStyle(Theme.flame).help("Vähintään yksi piste jokaisessa neljässä viimeisessä pelissä") }
                            if !store.note(p.id).isEmpty { Image(systemName: "note.text").font(.system(size: 10)).foregroundStyle(Theme.cyan) }
                        }
                        Text("\(p.flag) \(p.team)").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(p.number.map { "#\($0)" } ?? "–").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted).frame(width: 40)
            Text(p.natLabel).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1).frame(width: 100)
            Text(p.slotLabel).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1).frame(width: 100)
            cell(num(p.games), 58, bold: sortKey == .games, color: sortKey == .games ? Theme.amber : Theme.text)
            cell(num(p.goals), 54, bold: sortKey == .goals, color: sortKey == .goals ? Theme.amber : Theme.text)
            cell(num(p.assists), 54, bold: sortKey == .assists, color: sortKey == .assists ? Theme.amber : Theme.text)
            cell(num(p.points), 56, bold: sortKey == .points, color: sortKey == .points ? Theme.amber : Theme.text)
            cell(ppgString(p.pointsPerGame), 70, bold: sortKey == .ppg, color: sortKey == .ppg ? Theme.amber : Theme.text)
            cell(num(p.shots), 78, bold: sortKey == .shots, color: sortKey == .shots ? Theme.amber : Theme.text)
            cell(num(p.ppPoints), 62, bold: sortKey == .pp, color: sortKey == .pp ? Theme.amber : Theme.text)
            cell(signed(p.plusMinus), 46, color: (p.plusMinus ?? 0) > 0 ? Theme.green : (p.plusMinus ?? 0) < 0 ? Theme.red : Theme.text)
            RecentStrip(player: p, mode: StripMode(sort: sortKey)).frame(width: 156)
            StarsView(value: store.rating(p.id)) { store.setRating(p.id, $0) }
                .frame(width: 84)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(selected ? Theme.cyan.opacity(0.10) : (hoverID == p.id ? Theme.cyan.opacity(0.09) : (odd ? Color.white.opacity(0.025) : .clear)))
        .onHover { h in
            if h { hoverID = p.id } else if hoverID == p.id { hoverID = nil }
        }
    }

    private func cell(_ s: String, _ w: CGFloat, bold: Bool = false, color: Color = Theme.text) -> some View {
        Text(s)
            .font(.system(size: 13, weight: bold ? .bold : .regular).monospacedDigit())
            .foregroundStyle(color)
            .frame(width: w)
    }
}


/// Pelipaikkasuodatin pelaajataulukkoon.
enum PosFilter: String, CaseIterable, Identifiable {
    case all, forward, center, left, right, defense, goalie
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "Kaikki pelipaikat"
        case .forward: return "Hyökkääjät"
        case .center: return "Keskushyökkääjät"
        case .left: return "Vasemmat laidat"
        case .right: return "Oikeat laidat"
        case .defense: return "Puolustajat"
        case .goalie: return "Maalivahdit"
        }
    }
    func matches(_ p: Player) -> Bool {
        switch self {
        case .all: return true
        case .forward: return p.pos == "F" || ["C", "L", "R"].contains(p.slot ?? "")
        case .center: return p.slot == "C"
        case .left: return p.slot == "L"
        case .right: return p.slot == "R"
        case .defense: return p.pos == "D" || p.slot == "D"
        case .goalie: return p.pos == "G"
        }
    }
}
