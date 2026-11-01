import SwiftUI

// MARK: - NHL-ottelun pelaajalista (boxscore)

private struct NHLBoxscore: Decodable {
    struct TeamInfo: Decodable {
        let abbrev: String?
        let score: Int?
        let sog: Int?
    }
    struct Name: Decodable { let `default`: String? }
    struct BoxPlayer: Decodable {
        let playerId: Int?
        let sweaterNumber: Int?
        let name: Name?
        let position: String?
        let goals: Int?
        let assists: Int?
        let points: Int?
        let plusMinus: Int?
        let sog: Int?
        let toi: String?
        let saveShotsAgainst: String?
    }
    struct TeamStats: Decodable {
        let forwards: [BoxPlayer]?
        let defense: [BoxPlayer]?
        let goalies: [BoxPlayer]?
        var isEmpty: Bool { (forwards ?? []).isEmpty && (defense ?? []).isEmpty && (goalies ?? []).isEmpty }
    }
    struct ByGame: Decodable {
        let awayTeam: TeamStats?
        let homeTeam: TeamStats?
    }
    let gameState: String?
    let awayTeam: TeamInfo?
    let homeTeam: TeamInfo?
    let playerByGameStats: ByGame?
}

struct GameDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var game: ScheduleGame

    init(game: ScheduleGame) { _game = State(initialValue: game) }

    @State private var loading = true
    @State private var failed = false
    @State private var box: NHLBoxscore?
    @State private var nhl: NHLExtras?
    @State private var videoItem: VideoItem?
    @State private var tab = 0
    private var isLiigaGame: Bool { game.id.hasPrefix("liiga-") }
    private var isNHLGame: Bool { game.gameId != nil }
    private var nhlStarted: Bool { isNHLGame && (game.final || game.live) }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Ottelu").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
            }

            HStack(spacing: 12) {
                Text(game.home).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                TeamLogoView(team: game.home, size: 40).frame(width: 40, height: 34)
                ScorePill(home: box?.homeTeam?.score ?? game.homeScore, away: box?.awayTeam?.score ?? game.awayScore, size: .large, amber: true)
                TeamLogoView(team: game.away, size: 40).frame(width: 40, height: 34)
                Text(game.away).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(statusText).font(.system(size: 12)).foregroundStyle(Theme.muted)

            if !game.final || isLiigaGame || nhlStarted {
                let tabCount = 1 + (game.final ? 0 : 2) + ((isLiigaGame || nhlStarted) ? 1 : 0) + (nhlStarted ? 1 : 0)
                GradientSegmented(selection: $tab, items: tabItems)
                    .frame(width: CGFloat(tabCount) * 110)
            }

            if tab == 3 && (isLiigaGame || nhlStarted) {
                LineupView(game: game, nhlGameId: nhlStarted ? game.gameId : nil)
            } else if tab >= 1 && tab <= 2 && !game.final {
                TipsView(game: game, coupons: tab == 2, onEdit: { tab = 1 })
            } else if tab == 0 && !game.final && !game.live {
                MatchPreviewView(game: game)
            } else if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                Text("Ottelun tietojen haku epäonnistui.").foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = game.liiga, !(nhlStarted && tab == 4) {
                liigaBody(d)
            } else if let s = box?.playerByGameStats, let a = s.awayTeam, let h = s.homeTeam, !(a.isEmpty && h.isEmpty) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        teamCard(game.away, stats: a)
                        teamCard(game.home, stats: h)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.3").font(.system(size: 28)).foregroundStyle(Theme.muted)
                    Text("Kokoonpanoja ei ole vielä julkaistu.").foregroundStyle(Theme.text)
                    Text("NHL:n rajapinta antaa pelaajalistan vasta, kun ottelu on alkanut. Kentällisiä (ketjuja) se ei kerro lainkaan.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(width: 660, height: 780)
        .background(AppBackground())
        .sheet(item: $videoItem) { VideoSheet(url: $0.url) }
        .task {
            if game.liiga == nil, let gid = game.sweGid {
                if let d = await fetchSweGameDetail(gid: gid, extra: game.sweExtra) { game.liiga = d } else { failed = true }
                loading = false
            } else if game.liiga == nil { await load() } else { loading = false }
            // Käynnissä olevan ottelun tiedot päivittyvät 20 s välein
            while !Task.isCancelled && (game.live || (!game.final && game.date.timeIntervalSinceNow < 600)) {
                try? await Task.sleep(for: .seconds(20))
                if Task.isCancelled { break }
                if game.gameId != nil {
                    await load(silent: true)
                } else if game.liiga != nil || game.id.hasPrefix("liiga") {
                    if let list = await fetchLiigaSchedule(teams: store.teams), let g = list.first(where: { $0.id == game.id }) { game = g }
                }
            }
        }
    }

    private var tabItems: [(Int, String, String?)] {
        var out: [(Int, String, String?)] = [(0, "Ottelu", nil)]
        if !game.final {
            out.append((1, "Vihjeet", nil))
            out.append((2, "Kupongit", nil))
        }
        if isLiigaGame || nhlStarted { out.append((3, "Kokoonpano", nil)) }
        if nhlStarted { out.append((4, "Pelaajat", nil)) }
        return out
    }

    private var goalieLines: [NHLGoalieLine] {
        guard let s = box?.playerByGameStats else { return [] }
        var out: [NHLGoalieLine] = []
        let sides: [(Bool, NHLBoxscore.TeamStats?)] = [(true, s.homeTeam), (false, s.awayTeam)]
        for (isHome, ts) in sides {
            for g in ts?.goalies ?? [] where (g.toi ?? "00:00") != "00:00" {
                guard let sv = g.saveShotsAgainst else { continue }
                let parts = sv.split(separator: "/").compactMap { Double($0) }
                var pct = ""
                if parts.count == 2, parts[1] > 0 {
                    pct = String(format: " · %.1f %%", parts[0] / parts[1] * 100).replacingOccurrences(of: ".", with: ",")
                }
                out.append(NHLGoalieLine(home: isHome, name: g.name?.default ?? "?", line: sv + pct))
            }
        }
        return out
    }

    private func periodTitle(_ p: Int) -> String {
        switch p {
        case 1, 2, 3: return "\(p). erä"
        case 4: return "Jatkoaika"
        default: return p > 4 ? "Rankkarit" : "Maalit"
        }
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func liigaBody(_ d: LiigaGameDetail) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    if let rink = d.rink { Text(rink).font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    if let sp = d.spectators { Text("Katsojia: \(sp)").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                    if let a = d.awayPP, let h = d.homePP {
                        Text("Ylivoimamaalit / ylivoimat: \(game.away) \(a) · \(game.home) \(h)")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    if let n = d.resultNote { Text(n).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.amber) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let ex = nhl, !ex.periods.isEmpty {
                    NHLPeriodCard(home: game.home, away: game.away, ex: ex)
                }

                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Maalit").padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
                    if d.goals.isEmpty {
                        Text("Ei maaleja.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    ForEach(Array(d.goals.enumerated()), id: \.offset) { idx, g in
                        VStack(alignment: .leading, spacing: 0) {
                            if idx == 0 || d.goals[idx - 1].period != g.period {
                                Text(periodTitle(g.period)).font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.text).padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
                            }
                            HStack(spacing: 10) {
                                Text(clock(g.seconds - (g.period - 1) * 1200)).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted)
                                    .frame(width: 44, alignment: .leading)
                                TeamLogoView(team: g.home ? game.home : game.away, size: 34).frame(width: 36, height: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(g.scorer).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                                        ForEach(g.tags.isEmpty && g.powerPlay ? ["YV"] : g.tags, id: \.self) { t in
                                            let c: Color = t == "YV" ? Theme.amber : (t == "AV" ? Theme.red : (t == "TM" ? Theme.green : Theme.cyan))
                                            Text(t).font(.system(size: 9, weight: .bold)).foregroundStyle(c)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Capsule().fill(c.opacity(0.16)))
                                                .overlay(Capsule().stroke(c.opacity(0.5), lineWidth: 0.5))
                                        }
                                    }
                                    if !g.assists.isEmpty {
                                        Text(g.assists.joined(separator: ", ")).font(.system(size: 11)).foregroundStyle(Theme.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                                Group {
                                    if let v = g.video {
                                        Button { videoItem = VideoItem(url: v) } label: {
                                            ZStack {
                                                Circle().fill(Theme.amber.opacity(0.16))
                                                Circle().stroke(Theme.amber.opacity(0.5), lineWidth: 1)
                                                Image(systemName: "play.fill").font(.system(size: 9)).offset(x: 0.5)
                                            }
                                            .frame(width: 24, height: 24)
                                        }
                                        .buttonStyle(.plain).foregroundStyle(Theme.amber).help("Katso maalin video")
                                    } else {
                                        Color.clear
                                    }
                                }
                                .frame(width: 24, height: 24)
                                if let hs = g.homeScore, let aws = g.awayScore {
                                    HStack(spacing: 0) {
                                        Text("\(hs)").padding(.horizontal, 10).padding(.vertical, 4)
                                            .foregroundStyle(g.home ? goalAccent : Theme.muted)
                                            .background(g.home ? goalAccent.opacity(0.2) : Color.clear)
                                        Text("\(aws)").padding(.horizontal, 10).padding(.vertical, 4)
                                            .foregroundStyle(g.home ? Theme.muted : awayText)
                                            .background(g.home ? Color.clear : awayAccent.opacity(0.3))
                                    }
                                    .font(.system(size: 16, weight: .heavy).monospacedDigit())
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                }
                            }
                            .padding(.leading, 34).padding(.trailing, 12).padding(.vertical, 6)
                            .frame(minHeight: 44)
                            .overlay(alignment: .leading) {
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 2).padding(.leading, 17)
                                    Circle().fill(g.home ? Theme.amber : Color.clear)
                                        .overlay(Circle().stroke(Theme.amber, lineWidth: 2))
                                        .frame(width: 10, height: 10).padding(.leading, 13)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 6)
                .glassCard(radius: 12)

                if let ex = nhl {
                    if !ex.shootout.isEmpty { NHLShootoutCard(home: game.home, away: game.away, list: ex.shootout) }
                    if !ex.stats.isEmpty { NHLStatsCard(home: game.home, away: game.away, stats: ex.stats) }
                    if !ex.penalties.isEmpty { NHLPenaltyCard(home: game.home, away: game.away, penalties: ex.penalties) }
                    if !ex.stars.isEmpty || !goalieLines.isEmpty {
                        NHLStarsCard(home: game.home, away: game.away, stars: ex.stars, goalies: goalieLines)
                    }
                }

                if game.id.hasPrefix("liiga-") {
                    Text("Liigan rajapinta ei kerro kokoonpanoja tai kentällisiä.")
                        .font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var statusText: String {
        if game.final {
            if let o = nhl?.outcome { return "Päättynyt · \(o)" }
            return "Päättynyt"
        }
        if game.live { return "Käynnissä" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "fi_FI")
        f.dateFormat = "EEEE d.M. 'klo' HH:mm"
        return f.string(from: game.date)
    }

    /// Kotijoukkue vasemmalla: nimi, logo, maalit – maalit, logo, nimi (vierasjoukkue oikealla).
    private func headerTeam(_ name: String, score: Int?, homeSide: Bool) -> some View {
        let scoreText = Group {
            if let score { Text("\(score)").font(.system(size: 22, weight: .bold).monospacedDigit()).foregroundStyle(Theme.cyan) }
        }
        let nameText = Text(name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text).lineLimit(1)
        let logo = TeamLogoView(team: name, size: 40).frame(width: 40, height: 34)
        return HStack(spacing: 10) {
            if homeSide {
                nameText.frame(maxWidth: .infinity, alignment: .trailing)
                logo
                scoreText
            } else {
                scoreText
                logo
                nameText.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func teamCard(_ team: String, stats: NHLBoxscore.TeamStats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(team).padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)
            group("Hyökkääjät", stats.forwards ?? [], goalie: false)
            group("Puolustajat", stats.defense ?? [], goalie: false)
            group("Maalivahdit", stats.goalies ?? [], goalie: true)
        }
        .padding(.bottom, 6)
        .glassCard(radius: 12)
    }

    @ViewBuilder
    private func group(_ title: String, _ players: [NHLBoxscore.BoxPlayer], goalie: Bool) -> some View {
        if !players.isEmpty {
            HStack(spacing: 6) {
                Text("#").frame(width: 28, alignment: .trailing)
                Text(title).padding(.leading, 4)
                Spacer()
                if goalie {
                    Text("Torjunnat").frame(width: 70, alignment: .trailing)
                } else {
                    Text("M").frame(width: 28, alignment: .trailing)
                    Text("S").frame(width: 28, alignment: .trailing)
                    Text("P").frame(width: 28, alignment: .trailing)
                    Text("+/-").frame(width: 34, alignment: .trailing)
                    Text("L").frame(width: 28, alignment: .trailing)
                }
                Text("Aika").frame(width: 48, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 5)
            ForEach(Array(players.enumerated()), id: \.offset) { idx, p in
                HStack(spacing: 6) {
                    Text(p.sweaterNumber.map(String.init) ?? "–").foregroundStyle(Theme.muted).frame(width: 28, alignment: .trailing)
                    Text(p.name?.default ?? "?").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.text)
                        .padding(.leading, 4).lineLimit(1)
                    if let pos = p.position { Text(pos).font(.system(size: 10)).foregroundStyle(Theme.muted) }
                    Spacer(minLength: 0)
                    if goalie {
                        Text(p.saveShotsAgainst ?? "–").frame(width: 70, alignment: .trailing)
                    } else {
                        Text(p.goals.map(String.init) ?? "–").frame(width: 28, alignment: .trailing)
                        Text(p.assists.map(String.init) ?? "–").frame(width: 28, alignment: .trailing)
                        Text(p.points.map(String.init) ?? "–").foregroundStyle((p.points ?? 0) > 0 ? Theme.cyan : Theme.muted)
                            .frame(width: 28, alignment: .trailing)
                        Text(p.plusMinus.map { $0 > 0 ? "+\($0)" : "\($0)" } ?? "–").frame(width: 34, alignment: .trailing)
                        Text(p.sog.map(String.init) ?? "–").frame(width: 28, alignment: .trailing)
                    }
                    Text(p.toi ?? "–").foregroundStyle(Theme.muted).frame(width: 48, alignment: .trailing)
                }
                .font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.text)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(idx % 2 == 1 ? Color.white.opacity(0.025) : .clear)
            }
        }
    }

    private func load(silent: Bool = false) async {
        if !silent { loading = true; failed = false }
        guard let id = game.gameId, let url = URL(string: "https://api-web.nhle.com/v1/gamecenter/\(id)/boxscore") else {
            failed = true; loading = false; return
        }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = 15
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           (resp as? HTTPURLResponse)?.statusCode == 200,
           let b = try? JSONDecoder().decode(NHLBoxscore.self, from: data) {
            box = b
        } else if !silent {
            failed = true
        }
        // Maalit, syöttäjät ja ylivoimat play-by-playsta (Ottelu-välilehti)
        if let b = await fetchNHLGameBundle(gameId: id) {
            game.liiga = b.detail
            nhl = b.extras
        }
        loading = false
    }
}
