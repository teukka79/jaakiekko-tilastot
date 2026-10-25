import SwiftUI

struct CompareView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let ids: [String]
    var onClear: () -> Void

    private var players: [Player] { ids.compactMap { store.player($0) } }

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
                    Text("Pelaajavertailu").font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
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
                }

                VStack(spacing: 0) {
                    ForEach(metrics) { m in
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
