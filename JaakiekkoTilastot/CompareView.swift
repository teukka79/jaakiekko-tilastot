import SwiftUI

struct CompareView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ids: [String]
    var onClear: () -> Void

    private var isGoalie: Bool { ids.first?.hasPrefix("g-") == true }
    private var players: [Player] { isGoalie ? [] : ids.compactMap { store.player($0) } }
    private var goalies: [Goalie] { isGoalie ? ids.compactMap { id in store.goalies.first { $0.id == id } } : [] }

    private struct GMetric: Identifiable {
        let id: String
        let title: String
        let value: (Goalie) -> Double?
        let text: (Goalie) -> String
    }

    private func f1(_ v: Double?, _ d: Int) -> String { v.map { String(format: "%.\(d)f", $0).replacingOccurrences(of: ".", with: ",") } ?? "–" }

    private var gMetrics: [GMetric] {
        [
            GMetric(id: "o", title: "Ottelut", value: { Double($0.games) }, text: { String($0.games) }),
            GMetric(id: "w", title: "Voitot", value: { $0.wins.map(Double.init) }, text: { num($0.wins) }),
            GMetric(id: "sv", title: "Torjunta-%", value: { $0.savePct }, text: { f1($0.savePct, 1) }),
            GMetric(id: "gaa", title: "Päästetyt / ottelu", value: { $0.gaa.map { -$0 } }, text: { f1($0.gaa, 2) }),
            GMetric(id: "so", title: "Nollapelit", value: { $0.shutouts.map(Double.init) }, text: { num($0.shutouts) }),
            GMetric(id: "sa", title: "Torjunnat", value: { $0.saves.map(Double.init) }, text: { num($0.saves) }),
            GMetric(id: "sh", title: "Laukaukset", value: { $0.shotsAgainst.map(Double.init) }, text: { num($0.shotsAgainst) }),
        ]
    }

    private struct Metric: Identifiable {
        let id: String
        let title: String
        let value: (Player) -> Double?
        let text: (Player) -> String
    }

    private var metrics: [Metric] {
        [
            Metric(id: "o", title: "Ottelut", value: { $0.games.map(Double.init) }, text: { num($0.games) }),
            Metric(id: "m", title: "Maalit", value: { $0.goals.map(Double.init) }, text: { num($0.goals) }),
            Metric(id: "s", title: "Syötöt", value: { $0.assists.map(Double.init) }, text: { num($0.assists) }),
            Metric(id: "p", title: "Pisteet", value: { $0.points.map(Double.init) }, text: { num($0.points) }),
            Metric(id: "ppg", title: "Pisteet / ottelu", value: { $0.pointsPerGame }, text: { ppgString($0.pointsPerGame) }),
            Metric(id: "pim", title: "Rangaistusminuutit", value: { $0.pim.map { -Double($0) } }, text: { num($0.pim) }),
            Metric(id: "pm", title: "+/-", value: { $0.plusMinus.map(Double.init) }, text: { signed($0.plusMinus) }),
        ]
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(isGoalie ? "Maalivahtivertailu" : "Pelaajavertailu").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
                    Spacer()
                    Button("Tyhjennä valinnat") { onClear(); dismiss() }.buttonStyle(GhostButtonStyle())
                    Button("Sulje") { dismiss() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.cancelAction)
                }

                HStack(alignment: .top, spacing: 12) {
                    Color.clear.frame(width: 150, height: 1)
                    ForEach(players) { p in
                        VStack(spacing: 6) {
                            TeamLogoView(team: p.team, size: 44)
                            Text(p.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                            Text(p.team).font(.system(size: 11)).foregroundStyle(Theme.muted)
                            StarsView(value: store.rating(p.id), size: 12)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    ForEach(goalies) { g in
                        VStack(spacing: 6) {
                            TeamLogoView(team: g.team, size: 44)
                            Text(g.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                            Text(g.team).font(.system(size: 11)).foregroundStyle(Theme.muted)
                            StarsView(value: store.rating(g.id), size: 12)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(gMetrics) { m in
                        let values = goalies.compactMap(m.value)
                        let best = values.max()
                        HStack(spacing: 12) {
                            Text(m.title).font(.system(size: 12)).foregroundStyle(Theme.muted)
                                .frame(width: 150, alignment: .leading)
                            ForEach(goalies) { g in
                                let v = m.value(g)
                                let isBest = v != nil && v == best && values.filter { $0 == best }.count < goalies.count
                                Text(m.text(g))
                                    .font(.system(size: 15, weight: isBest ? .heavy : .regular).monospacedDigit())
                                    .foregroundStyle(isBest ? Theme.green : Theme.text)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        Divider().overlay(Theme.hairline)
                    }
                    ForEach(isGoalie ? [] : metrics) { m in
                        let values = players.compactMap(m.value)
                        let best = values.max()
                        HStack(spacing: 12) {
                            Text(m.title).font(.system(size: 12)).foregroundStyle(Theme.muted)
                                .frame(width: 150, alignment: .leading)
                            ForEach(players) { p in
                                let v = m.value(p)
                                let isBest = v != nil && v == best && values.filter { $0 == best }.count < players.count
                                Text(m.text(p))
                                    .font(.system(size: 15, weight: isBest ? .heavy : .regular).monospacedDigit())
                                    .foregroundStyle(isBest ? Theme.green : Theme.text)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 10).padding(.horizontal, 14)
                        Divider().overlay(Theme.hairline)
                    }
                }
                .glassCard()
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(width: 720, height: 560)
    }
}
