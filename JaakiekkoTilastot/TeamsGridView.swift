import SwiftUI

/// Joukkuenäkymä: kaikki joukkueet ruudukkona. Klikkaus avaa joukkueen pelaajat taulukossa.
struct TeamsGridView: View {
    @Environment(AppStore.self) private var store
    let league: League?
    var onSelect: (String) -> Void
    @State private var resultsTeam: String?

    private let columns = [GridItem(.adaptive(minimum: 230, maximum: 320), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(store.teamNames(in: league), id: \.self) { name in
                    card(name)
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: Binding(get: { resultsTeam != nil }, set: { if !$0 { resultsTeam = nil } })) {
            if let t = resultsTeam { TeamResultsView(teamName: t) }
        }
    }

    private func card(_ name: String) -> some View {
        let roster = store.players.filter { $0.team == name }
        let top = roster.max { ($0.points ?? -1) < ($1.points ?? -1) }
        let lg = store.teamByName[name]?.league
        return Button { onSelect(name) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    TeamLogoView(team: name, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text).lineLimit(2)
                        Text(lg?.label ?? "Oma joukkue").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                Divider().overlay(Theme.hairline)
                HStack {
                    Text("\(roster.count) pelaajaa").font(.system(size: 11)).foregroundStyle(Theme.muted)
                    Spacer()
                    if let top, let pts = top.points {
                        Text("\(top.name.split(separator: " ").last.map(String.init) ?? top.name) \(pts) p")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.cyan).lineLimit(1)
                    }
                }
            }
            .padding(14)
            .glassCard()
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button { resultsTeam = name } label: {
                Image(systemName: "chart.bar").font(.system(size: 12))
                    .padding(7).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Theme.cyan)
            .help("Joukkueen 5 viimeisintä ottelua")
            .padding(6)
        }
    }
}
