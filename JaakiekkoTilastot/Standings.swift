import SwiftUI

// MARK: - Pelipaikan nimi

extension Player {
    /// Pelipaikka suomeksi: NHL:ssä tarkka (keskushyökkääjä, laitahyökkääjä, puolustaja), muualla F/D-tieto.
    var slotLabel: String {
        switch slot {
        case "C": return "Keskushyökkääjä"
        case "L": return "Vasen laita"
        case "R": return "Oikea laita"
        case "D": return "Puolustaja"
        default: break
        }
        switch pos {
        case "F": return "Hyökkääjä"
        case "D": return "Puolustaja"
        case "G": return "Maalivahti"
        default: return "–"
        }
    }
}

// MARK: - Sarjataulukko

struct StandingRow: Identifiable {
    var id: String { team }
    var team: String          // siemendatan joukkuenimi (logoa varten)
    var gp = 0, w = 0, l = 0, otl = 0, pts = 0, gf = 0, ga = 0
    var group = ""            // NHL: divisioona
    var diff: Int { gf - ga }
}

private struct NHLLangName: Decodable { let `default`: String }

private struct NHLStandingsResponse: Decodable {
    struct Row: Decodable {
        let teamAbbrev: NHLLangName
        let gamesPlayed: Int?
        let wins: Int?
        let losses: Int?
        let otLosses: Int?
        let points: Int?
        let goalFor: Int?
        let goalAgainst: Int?
        let divisionName: String?
        let conferenceName: String?
    }
    let standings: [Row]
}

func sortStandings(_ rows: [StandingRow]) -> [StandingRow] {
    rows.sorted {
        if $0.pts != $1.pts { return $0.pts > $1.pts }
        if $0.gp != $1.gp { return $0.gp < $1.gp }
        if $0.diff != $1.diff { return $0.diff > $1.diff }
        return $0.gf > $1.gf
    }
}

func fetchNHLStandings(teams: [Team]) async -> [StandingRow]? {
    guard let url = URL(string: "https://api-web.nhle.com/v1/standings/now") else { return nil }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 15
    guard let (data, resp) = try? await URLSession.shared.data(for: req),
          (resp as? HTTPURLResponse)?.statusCode == 200,
          let r = try? JSONDecoder().decode(NHLStandingsResponse.self, from: data) else { return nil }
    let byAbbr = Dictionary(uniqueKeysWithValues: teams.filter { $0.league == .nhl }.map { ($0.abbr, $0.name) })
    return r.standings.compactMap { s in
        guard let name = byAbbr[s.teamAbbrev.default] else { return nil }
        let conf = s.conferenceName ?? ""
        let div = s.divisionName ?? ""
        return StandingRow(team: name, gp: s.gamesPlayed ?? 0, w: s.wins ?? 0, l: s.losses ?? 0, otl: s.otLosses ?? 0,
                           pts: s.points ?? 0, gf: s.goalFor ?? 0, ga: s.goalAgainst ?? 0, group: "\(conf)|\(div)")
    }
}

/// Liigan sarjataulukko lasketaan ottelutuloksista: voitto 3 p, jatkoaikavoitto 2 p, jatkoaikatappio 1 p.
@MainActor
func fetchLiigaStandings(teams: [Team]) async -> [StandingRow]? {
    guard let games = await fetchLiigaGames() else { return nil }
    let liigaTeams = teams.filter { $0.league == .liiga }
    let seedByKey = Dictionary(uniqueKeysWithValues: liigaTeams.map { (AppStore.liigaKey($0.name), $0.name) })
    var table: [String: StandingRow] = Dictionary(uniqueKeysWithValues: liigaTeams.map { ($0.name, StandingRow(team: $0.name)) })

    for g in games where g.ended?.value == true {
        guard let h = g.homeTeam, let a = g.awayTeam,
              let hn = h.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }),
              let an = a.teamName.flatMap({ seedByKey[AppStore.liigaKey($0)] }) else { continue }
        let hg = h.goals ?? (h.goalEvents ?? []).count
        let ag = a.goals ?? (a.goalEvents ?? []).count
        let ft = (g.finishedType ?? "").lowercased()
        let extra = ft.contains("extended") || ft.contains("overtime") || ft.contains("shootout")

        var hr = table[hn] ?? StandingRow(team: hn)
        var ar = table[an] ?? StandingRow(team: an)
        hr.gp += 1; ar.gp += 1
        hr.gf += hg; hr.ga += ag; ar.gf += ag; ar.ga += hg
        if hg > ag {
            hr.w += 1; hr.pts += extra ? 2 : 3
            if extra { ar.otl += 1; ar.pts += 1 } else { ar.l += 1 }
        } else if ag > hg {
            ar.w += 1; ar.pts += extra ? 2 : 3
            if extra { hr.otl += 1; hr.pts += 1 } else { hr.l += 1 }
        }
        table[hn] = hr; table[an] = ar
    }
    return Array(table.values)
}

enum StandingsMode { case table, form, overUnder }

struct StandingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var league: League = .nhl
    @State private var byDivision = true
    @State private var rows: [StandingRow] = []
    @State private var loading = false
    @State private var failed = false
    @State private var mode: StandingsMode = .table
    @State private var side: FormSide = .all
    @State private var window = 5
    @State private var line = 4.5
    @State private var games: [LeagueGame]?
    @State private var gamesLoading = false
    @State private var gamesLeague: League?

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Sarjataulukko").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                ForEach([League.nhl, League.ahl, League.liiga, League.mestis, League.shl, League.allsvenskan]) { l in
                    Button(l.label) { league = l }.buttonStyle(GhostButtonStyle(active: league == l))
                }
                Spacer()
                if league == .nhl || league == .ahl {
                    Button("Divisioonat") { byDivision = true }.buttonStyle(GhostButtonStyle(active: byDivision))
                    Button("Koko sarja") { byDivision = false }.buttonStyle(GhostButtonStyle(active: !byDivision))
                }
            }

            HStack(spacing: 8) {
                Button("Sarjataulukko") { mode = .table }.buttonStyle(GhostButtonStyle(active: mode == .table))
                Button("Kunto") { mode = .form }.buttonStyle(GhostButtonStyle(active: mode == .form))
                Button("Yli/Alle") { mode = .overUnder }.buttonStyle(GhostButtonStyle(active: mode == .overUnder))
                Spacer()
            }
            if mode != .table {
                HStack(spacing: 8) {
                    ForEach(FormSide.allCases, id: \.self) { sd in
                        Button(sd.rawValue) { side = sd }.buttonStyle(GhostButtonStyle(active: side == sd))
                    }
                    Spacer().frame(width: 10)
                    if mode == .form {
                        ForEach([5, 10], id: \.self) { n in
                            Button("\(n)") { window = n }.buttonStyle(GhostButtonStyle(active: window == n))
                        }
                    } else {
                        ForEach([0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5], id: \.self) { v in
                            Button(String(format: "%.1f", v)) { line = v }.buttonStyle(GhostButtonStyle(active: line == v))
                        }
                    }
                    Spacer()
                }
            }

            if mode != .table {
                if gamesLoading || (games != nil && gamesLeague != league) {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let g = games, gamesLeague == league {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            TeamFormTables(league: league,
                                           teamNames: store.teams.filter { $0.league == league }.map { $0.name },
                                           groups: Dictionary(rows.map { ($0.team, $0.group) }, uniquingKeysWith: { a, _ in a }),
                                           byDivision: byDivision, games: g, isForm: mode == .form,
                                           side: side, window: window, line: line)
                            Text(mode == .form
                                 ? "OTT = ottelut, JA-V/JA-H = jatkoaika- tai rankkarivoitot/-tappiot, M = maalit, PIS = pisteet valitulta ajalta. Merkit uusimmasta vanhimpaan; ? = seuraava ottelu (vie hiiri päälle). Oranssi kulma = ratkesi jatkoajalla tai rankkareilla."
                                 : "O = yli \(String(format: "%.1f", line)) maalia (ottelun kaikki maalit), U = alle, M = maalit tehty:päästetty, M/O = maaleja per ottelu. Koko kausi, merkit = viimeiset 5 ottelua.")
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                            if league == .mestis {
                                Text("Mestiksestä ei saa jatkoaikatietoa.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                } else {
                    Text("Otteluiden haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.")
                        .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                Text("Sarjataulukon haku epäonnistui. Tarkista verkkoyhteys ja avaa uudelleen.")
                    .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        if (league == .nhl || league == .ahl) && byDivision {
                            ForEach(divisionKeys, id: \.self) { key in
                                section(title: divisionTitle(key), rows: sortStandings(rows.filter { $0.group == key }))
                            }
                        } else {
                            section(title: nil, rows: sortStandings(rows))
                        }
                        Text("O = ottelut, V = voitot, H = tappiot, JH = jatkoaika-/rankkaritappiot, P = pisteet.")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        if league == .shl || league == .allsvenskan {
                            Text("Taulukko on laskettu ottelutuloksista (voitto 3 p, jatkoaikavoitto 2 p, jatkoaikatappio 1 p). Lähde: swehockey.se.")
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                        if league == .liiga {
                            Text("Liigan taulukko on laskettu ottelutuloksista (voitto 3 p, jatkoaikavoitto 2 p, jatkoaikatappio 1 p).")
                                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 900, height: 760)
        .background(AppBackground())
        .task(id: league) { await load() }
        .task(id: "\(league.rawValue)-\(mode == .table)") { await loadGames() }
    }

    private var divisionKeys: [String] {
        Array(Set(rows.map { $0.group })).sorted()
    }

    private func divisionTitle(_ key: String) -> String {
        let parts = key.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        return parts.count == 2 ? "\(parts[1]) (\(parts[0]))" : key
    }

    private func loadGames() async {
        guard mode != .table, !(games != nil && gamesLeague == league) else { return }
        gamesLoading = true
        let lg = league
        let g = await fetchLeagueGames(league: lg, teams: store.teams)
        if lg == league { games = g; gamesLeague = lg }
        gamesLoading = false
    }

    private func load() async {
        loading = true; failed = false; rows = []
        let r: [StandingRow]?
        switch league {
        case .nhl: r = await fetchNHLStandings(teams: store.teams)
        case .mestis: r = await fetchMestisStandings(teams: store.teams)
        case .ahl: r = await fetchAHLStandings(teams: store.teams, season: await fetchAHLSeasonId())
        case .shl, .allsvenskan: r = await fetchSweStandings(league: league, teams: store.teams)
        default: r = await fetchLiigaStandings(teams: store.teams)
        }
        if let r { rows = r } else { failed = true }
        loading = false
    }

    private func section(title: String?, rows: [StandingRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                SectionLabel(title).padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            }
            headerRow
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, r in
                HStack(spacing: 8) {
                    Text("\(idx + 1)").frame(width: 24, alignment: .trailing).foregroundStyle(Theme.muted)
                    TeamLogoView(team: r.team, size: 30).frame(width: 30, height: 26)
                    Text(r.team).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    num(r.gp, 34); num(r.w, 34); num(r.l, 34); num(r.otl, 34)
                    Text("\(r.pts)").font(.system(size: 13, weight: .bold).monospacedDigit()).foregroundStyle(Theme.cyan)
                        .frame(width: 40, alignment: .trailing)
                    Text("\(r.gf)–\(r.ga)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted)
                        .frame(width: 64, alignment: .trailing)
                    Text(r.diff > 0 ? "+\(r.diff)" : "\(r.diff)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(r.diff > 0 ? Theme.green : r.diff < 0 ? Theme.red : Theme.muted)
                        .frame(width: 40, alignment: .trailing)
                }
                .font(.system(size: 12).monospacedDigit())
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(idx % 2 == 1 ? Color.white.opacity(0.025) : .clear)
            }
        }
        .padding(.bottom, 6)
        .glassCard(radius: 12)
    }

    private func num(_ v: Int, _ w: CGFloat) -> some View {
        Text("\(v)").foregroundStyle(Theme.text).frame(width: w, alignment: .trailing)
    }

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("#").frame(width: 24, alignment: .trailing)
            Text("Joukkue").padding(.leading, 38)
            Spacer(minLength: 0)
            Text("O").frame(width: 34, alignment: .trailing)
            Text("V").frame(width: 34, alignment: .trailing)
            Text("H").frame(width: 34, alignment: .trailing)
            Text("JH").frame(width: 34, alignment: .trailing)
            Text("P").frame(width: 40, alignment: .trailing)
            Text("Maalit").frame(width: 64, alignment: .trailing)
            Text("Ero").frame(width: 40, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
        .padding(.horizontal, 12).padding(.vertical, 6)
    }
}
