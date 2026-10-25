import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var soundError: String?

    private func pickSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Valitse ilmoitusääni (esim. mp3, wav, aiff, m4a)"
        if panel.runModal() == .OK, let url = panel.url {
            soundError = store.setCustomSound(from: url) ? nil : "Äänitiedoston avaaminen epäonnistui. Kokeile toista tiedostoa."
        }
    }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 14) {
                Text("Asetukset").font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.text)
                SectionLabel("Ilmoitukset")
                Toggle("Ilmoita, kun pelaaja tekee maalin tai syöttää", isOn: Binding(get: { store.notifyEnabled }, set: { store.setNotifyEnabled($0) }))
                    .toggleStyle(.switch).foregroundStyle(Theme.text)
                HStack(spacing: 8) {
                    Text("Pelaajat, joilla tähtiä vähintään").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    ForEach([1, 2, 3], id: \.self) { n in
                        Button("\(n)") { store.setNotifyMinStars(n) }.buttonStyle(GhostButtonStyle(active: store.notifyMinStars == n))
                    }
                    Spacer()
                }
                Toggle("Äänimerkki ilmoituksen yhteydessä", isOn: Binding(get: { store.notifySound }, set: { store.setNotifySound($0) }))
                    .toggleStyle(.switch).foregroundStyle(Theme.text)
                HStack(spacing: 8) {
                    Text("Ääni: " + (store.customSoundName ?? "järjestelmän oletus"))
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                    Spacer()
                    Button("Valitse äänitiedosto…") { pickSound() }.buttonStyle(GhostButtonStyle())
                    if store.customSoundName != nil {
                        Button("Palauta oletus") { store.clearCustomSound() }.buttonStyle(GhostButtonStyle())
                    }
                    Button("Testaa") { store.playNotificationSound() }.buttonStyle(GhostButtonStyle())
                }
                if let soundError {
                    Text(soundError).font(.system(size: 11)).foregroundStyle(Theme.red)
                }
                Text("Ilmoitukset tulevat käynnissä olevista peleistä NHL:ssä, AHL:ssä ja Liigassa noin minuutin viiveellä. Jos ilmoitukset eivät näy, salli ne Järjestelmäasetukset > Ilmoitukset.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
                SectionLabel("Sovelluksen kuvake")
                HStack(spacing: 14) {
                    ForEach(AppIconChoice.allCases) { c in
                        Button { store.setAppIcon(c) } label: {
                            VStack(spacing: 5) {
                                Group {
                                    if let img = c.image { Image(nsImage: img).resizable().interpolation(.high) } else { Color.clear }
                                }
                                .frame(width: 64, height: 64)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(store.appIconChoice == c ? Theme.cyan : Color.clear, lineWidth: 2).padding(-3))
                                Text(c.title).font(.system(size: 11, weight: store.appIconChoice == c ? .bold : .regular))
                                    .foregroundStyle(store.appIconChoice == c ? Theme.text : Theme.muted)
                            }
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                }
                SectionLabel("Elite Prospects API -avain (SHL ja HockeyAllsvenskan)")
                SecureField(store.hasEPKey ? "Avain tallennettu – liitä uusi korvataksesi" : "Liitä avain tähän", text: $key)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))
                Text("Avain tallennetaan vain tämän sovelluksen omaan tallennustilaan tälle koneelle. Ilmainen taso sallii 1 000 kutsua kuukaudessa, joten SHL/HA haetaan korkeintaan kahden tunnin välein tai Päivitä-napista.")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
                if store.hasEPKey {
                    Text("Tila: " + store.epStatus)
                        .font(.system(size: 11)).foregroundStyle(store.epOK ? Theme.green : Theme.amber)
                        .lineLimit(4).textSelection(.enabled)
                }
                Spacer(minLength: 0)
                HStack {
                    if store.hasEPKey {
                        Button("Poista avain") { store.setEPKey(""); key = "" }.buttonStyle(GhostButtonStyle())
                    }
                    Spacer()
                    Button("Sulje") { dismiss() }.buttonStyle(GhostButtonStyle()).keyboardShortcut(.cancelAction)
                    Button("Tallenna ja hae") {
                        store.setEPKey(key)
                        dismiss()
                        Task { await store.refreshLive(force: true) }
                    }
                    .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
        }
        .frame(width: 540, height: 680)
    }
}
