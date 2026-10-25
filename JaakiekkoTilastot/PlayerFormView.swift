import SwiftUI

/// Lisää uuden pelaajan (player == nil) tai muokkaa olemassa olevan tietoja.
struct PlayerFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let player: Player?
    let defaultLeague: League

    @State private var name = ""
    @State private var league: League = .nhl
    @State private var team = ""
    @State private var pos = "F"
    @State private var nat = ""
    @State private var born = ""
    @State private var shoots = ""
    @State private var games = ""
    @State private var goals = ""
    @State private var assists = ""
    @State private var pim = ""
    @State private var plusMinus = ""
    @State private var logoURL = ""
    @State private var loaded = false

    private var isEdit: Bool { player != nil }
    private var isCustom: Bool { player?.isCustom ?? true }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text(isEdit ? "Muokkaa tietoja" : "Lisää pelaaja")
                    .font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.text)

                if isCustom {
                    field("Nimi", $name)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionLabel("Sarja")
                            Picker("", selection: $league) {
                                ForEach(League.allCases) { Text($0.label).tag($0) }
                            }.labelsHidden()
                        }
                        field("Joukkue", $team, suggestions: store.teamNames(in: league))
                    }
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel("Pelipaikka")
                        Picker("", selection: $pos) {
                            Text("Hyökkääjä").tag("F"); Text("Puolustaja").tag("D"); Text("Maalivahti").tag("G")
                        }.labelsHidden().pickerStyle(.segmented)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SectionLabel("Kätisyys")
                        Picker("", selection: $shoots) {
                            Text("–").tag(""); Text("V").tag("L"); Text("O").tag("R")
                        }.labelsHidden().pickerStyle(.segmented)
                    }
                }
                HStack(spacing: 10) {
                    field("Kansallisuus", $nat)
                    field("Syntymävuosi", $born)
                }
                HStack(spacing: 10) {
                    field("O", $games); field("M", $goals); field("S", $assists)
                    field("RM", $pim); field("+/-", $plusMinus)
                }
                field("Joukkueen logon URL (valinnainen)", $logoURL)

                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    Button("Peruuta") { dismiss() }.buttonStyle(GhostButtonStyle()).keyboardShortcut(.cancelAction)
                    Button("Tallenna") { save() }.buttonStyle(PrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .disabled(isCustom && (name.trimmingCharacters(in: .whitespaces).isEmpty || team.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
            .padding(24)
        }
        .frame(width: 540, height: isCustom ? 590 : 440)
        .onAppear(perform: load)
    }

    private func field(_ label: String, _ binding: Binding<String>, suggestions: [String] = []) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(label)
            TextField("", text: binding)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        league = defaultLeague
        if let p = player {
            name = p.name; league = p.league; team = p.team
            pos = p.pos ?? "F"; nat = p.nat ?? ""; born = p.born.map(String.init) ?? ""
            shoots = p.shoots ?? ""
            games = p.games.map(String.init) ?? ""; goals = p.goals.map(String.init) ?? ""
            assists = p.assists.map(String.init) ?? ""; pim = p.pim.map(String.init) ?? ""
            plusMinus = p.plusMinus.map(String.init) ?? ""
            logoURL = store.state.logos[p.team] ?? ""
        }
    }

    private func intOrNil(_ s: String) -> Int? { Int(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "+", with: "")) }
    private func strOrNil(_ s: String) -> String? { let t = s.trimmingCharacters(in: .whitespaces); return t.isEmpty ? nil : t }

    private func save() {
        let teamName = player?.team ?? team.trimmingCharacters(in: .whitespaces)
        if !logoURL.isEmpty || store.state.logos[teamName] != nil {
            store.setLogo(team: teamName, urlString: logoURL)
        }
        if let p = player, !p.isCustom {
            store.saveEdit(p.id, PlayerEdit(games: intOrNil(games), goals: intOrNil(goals), assists: intOrNil(assists),
                                            pim: intOrNil(pim), plusMinus: intOrNil(plusMinus),
                                            pos: pos, nat: strOrNil(nat), born: intOrNil(born), shoots: strOrNil(shoots)))
        } else {
            var np = Player(id: player?.id ?? store.newCustomID(),
                            name: name.trimmingCharacters(in: .whitespaces), team: teamName, league: league,
                            flag: store.teamByName[teamName]?.flag ?? String(league.flags.prefix(2)),
                            pos: pos, nat: strOrNil(nat), born: intOrNil(born), shoots: strOrNil(shoots),
                            games: intOrNil(games), goals: intOrNil(goals), assists: intOrNil(assists),
                            pim: intOrNil(pim), plusMinus: intOrNil(plusMinus))
            np.isCustom = true
            if isEdit { store.updateCustom(np) } else { store.addPlayer(np) }
        }
        dismiss()
    }
}
