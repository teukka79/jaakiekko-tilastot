import SwiftUI

struct PlayerDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let playerID: String

    @State private var noteText = ""
    @State private var editing = false
    @State private var showTeamResults = false
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var recent: AppStore.RecentResult?
    @State private var recentLoading = true

    var body: some View {
        ZStack {
            AppBackground()
            if let p = store.player(playerID) {
                content(p)
            } else {
                Text("Pelaajaa ei löytynyt").foregroundStyle(Theme.muted)
            }
        }
        .frame(width: 560, height: 780)
        .onAppear {
            if !loaded { noteText = store.note(playerID); loaded = true }
        }
        .sheet(isPresented: $editing) {
            if let p = store.player(playerID) {
                PlayerFormView(player: p, defaultLeague: p.league)
            }
        }
        .confirmationDialog("Poistetaanko pelaaja?", isPresented: $confirmDelete) {
            Button("Poista", role: .destructive) { store.deleteCustom(playerID); dismiss() }
            Button("Peruuta", role: .cancel) {}
        }
    }

    private func content(_ p: Player) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                TeamLogoView(team: p.team, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
                    HStack(spacing: 4) {
                        Text(p.flag).font(.system(size: 12))
                        Button { showTeamResults = true } label: {
                            Text(p.team).font(.system(size: 12)).underline(true, pattern: .dot)
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.muted)
                        .help("Näytä joukkueen 5 viimeisintä ottelua")
                        Text("· \(p.league.label)").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    .sheet(isPresented: $showTeamResults) { TeamResultsView(teamName: p.team) }
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 18)) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                StarsView(value: store.rating(p.id), size: 22) { store.setRating(p.id, $0) }
                Spacer()
                if let pos = p.positionLabel { Chip(text: pos) }
                if let nat = p.nat { Chip(text: nat) }
                if let age = p.age { Chip(text: "\(age) v") }
                if let s = p.shoots { Chip(text: s == "L" ? "Vasenkätinen" : s == "R" ? "Oikeakätinen" : s) }
            }

            HStack(spacing: 10) {
                stat("O", num(p.games)); stat("M", num(p.goals)); stat("S", num(p.assists))
                stat("P", num(p.points), highlight: true); stat("P/O", ppgString(p.pointsPerGame)); stat("L", num(p.shots))
                stat("YV", num(p.ppPoints)); stat("RM", num(p.pim)); stat("+/-", signed(p.plusMinus))
            }

            recentSection(p)

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Muistiinpanot")
                TextEditor(text: $noteText)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
                    .onChange(of: noteText) { _, new in store.setNote(p.id, new) }
                    .frame(minHeight: 90)
            }

            HStack {
                Button { editing = true } label: { Label("Muokkaa tietoja", systemImage: "pencil") }
                    .buttonStyle(GhostButtonStyle())
                if store.state.edits[p.id] != nil {
                    Button { store.resetEdit(p.id) } label: { Label("Palauta alkuperäiset", systemImage: "arrow.uturn.backward") }
                        .buttonStyle(GhostButtonStyle())
                }
                Spacer()
                if p.isCustom {
                    Button { confirmDelete = true } label: { Label("Poista", systemImage: "trash") }
                        .buttonStyle(GhostButtonStyle())
                        .foregroundStyle(Theme.red)
                }
            }
        }
        .padding(24)
    }

    private func shortDate(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3, let m = Int(parts[1]), let d = Int(parts[2]) else { return iso }
        return "\(d).\(m)."
    }

    @ViewBuilder
    private func recentSection(_ p: Player) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Viimeiset 5 peliä")
                Spacer()
                if let r = recent, !r.games.isEmpty {
                    let g = r.games.reduce(0) { $0 + $1.goals }
                    let a = r.games.reduce(0) { $0 + $1.assists }
                    Chip(text: "\(g + a) p (\(g)+\(a))")
                }
            }
            if recentLoading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Haetaan…").font(.system(size: 12)).foregroundStyle(Theme.muted) }
            } else if let r = recent {
                if !r.games.isEmpty {
                    let showShots = r.games.contains { $0.shots != nil }
                    let showPP = r.games.contains { $0.pp != nil }
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Text("Päivä").frame(width: 46, alignment: .leading)
                            Text("Koti/Vieras").frame(width: 62, alignment: .leading)
                            Text("Vastustaja")
                            Spacer()
                            if showShots { Text("Laukaus").frame(width: 56, alignment: .trailing) }
                            Text("Maali").frame(width: 46, alignment: .trailing)
                            Text("Syöttö").frame(width: 50, alignment: .trailing)
                            Text("Pisteet").frame(width: 50, alignment: .trailing)
                            if showPP { Text("Ylivoima").frame(width: 58, alignment: .trailing) }
                        }
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        ForEach(r.games) { g in
                            HStack(spacing: 8) {
                                Text(shortDate(g.date)).font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted).frame(width: 46, alignment: .leading)
                                Text(g.home == true ? "Koti" : g.home == false ? "Vieras" : "–")
                                    .font(.system(size: 12)).foregroundStyle(Theme.muted).frame(width: 62, alignment: .leading)
                                Text(g.opponent).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.text)
                                Spacer()
                                if showShots {
                                    Text(g.shots.map(String.init) ?? "–").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.muted).frame(width: 56, alignment: .trailing)
                                }
                                Text("\(g.goals)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.text).frame(width: 46, alignment: .trailing)
                                Text("\(g.assists)").font(.system(size: 12).monospacedDigit()).foregroundStyle(Theme.text).frame(width: 50, alignment: .trailing)
                                Text("\(g.points)").font(.system(size: 12, weight: .bold).monospacedDigit())
                                    .foregroundStyle(g.points > 0 ? Theme.cyan : Theme.muted).frame(width: 50, alignment: .trailing)
                                if showPP {
                                    Text(g.pp.map(String.init) ?? "–").font(.system(size: 12).monospacedDigit())
                                        .foregroundStyle((g.pp ?? 0) > 0 ? Theme.amber : Theme.muted).frame(width: 58, alignment: .trailing)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(g.points > 0 ? Theme.cyan.opacity(0.07) : .clear)
                        }
                    }
                    .glassCard(radius: 12)
                }
                if let note = r.note {
                    Text(note).font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
        }
        .task(id: p.id) {
            recentLoading = true
            recent = await store.recentGames(for: p)
            recentLoading = false
        }
    }

    private func stat(_ label: String, _ value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 18, weight: .bold).monospacedDigit())
                .foregroundStyle(highlight ? Theme.cyan : Theme.text)
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .glassCard(radius: 12)
    }
}
