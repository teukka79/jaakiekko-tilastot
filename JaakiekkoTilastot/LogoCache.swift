import SwiftUI
import CryptoKit

/// SHL-logot (TheSportsDB). Puuttuvat haetaan ajon aikana (AppStore.fetchMissingLogos).
enum ExtraLogos {
    static let urls: [String: String] = [
        "Brynäs IF": "https://r2.thesportsdb.com/images/media/team/badge/n7ngcn1700826181.png",
        "Djurgårdens IF": "https://r2.thesportsdb.com/images/media/team/badge/eoxtmh1644937914.png",
        "Färjestad BK": "https://r2.thesportsdb.com/images/media/team/badge/svvxxu1421610693.png",
        "Frölunda HC": "https://r2.thesportsdb.com/images/media/team/badge/1zbgup1656774483.png",
        "HV71": "https://r2.thesportsdb.com/images/media/team/badge/k10ji41663411948.png",
        "IF Björklöven": "https://r2.thesportsdb.com/images/media/team/badge/0yuhv71700826189.png",
        "Linköping HC": "https://r2.thesportsdb.com/images/media/team/badge/330nt41783580950.png",
        "Luleå HF": "https://r2.thesportsdb.com/images/media/team/badge/5l7gw41644937943.png",
        "Malmö Redhawks": "https://r2.thesportsdb.com/images/media/team/badge/j8gnby1644937928.png",
        "Örebro HK": "https://r2.thesportsdb.com/images/media/team/badge/wqtspp1422389481.png",
    ]
}

/// Pysyvä logovälimuisti levyllä (Application Support/JaakiekkoTilastot/logos).
enum LogoDisk {
    static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JaakiekkoTilastot", isDirectory: true)
            .appendingPathComponent("logos", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private static func hash(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func file(for url: URL) -> URL {
        dir.appendingPathComponent(hash(for: url) + ".img")
    }

    /// Sovellukseen paketoitu logo (LogoSeed-kansio), jos levyvälimuistissa ei vielä ole.
    private static func bundled(_ url: URL) -> Data? {
        let h = hash(for: url)
        let u = Bundle.main.url(forResource: h, withExtension: "img")
            ?? Bundle.main.url(forResource: h, withExtension: "img", subdirectory: "LogoSeed")
        return u.flatMap { try? Data(contentsOf: $0) }
    }

    static func read(_ url: URL) -> Data? {
        if let d = try? Data(contentsOf: file(for: url)) { return d }
        return bundled(url)
    }

    static func write(_ data: Data, for url: URL) {
        try? data.write(to: file(for: url), options: .atomic)
    }
}

private struct SportsDBResponse: Decodable {
    struct Team: Decodable {
        let strSport: String?
        let strCountry: String?
        let strBadge: String?
    }
    let teams: [Team]?
}

extension AppStore {
    /// Sovellukseen paketoitu joukkue -> logo-osoite -taulukko (LogoMap.json): logot näkyvät heti myös uudella koneella.
    func seedBundledLogoMap() {
        let u = Bundle.main.url(forResource: "LogoMap", withExtension: "json")
            ?? Bundle.main.url(forResource: "LogoMap", withExtension: "json", subdirectory: "LogoSeed")
        guard let u, let data = try? Data(contentsOf: u),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        var logos = state.autoLogos ?? [:]
        var changed = false
        for (name, url) in map where logoURL(for: name) == nil && teamByName[name] != nil {
            logos[name] = url
            changed = true
        }
        if changed { state.autoLogos = logos; persist() }
    }

    /// Hakee puuttuvat SHL- ja HockeyAllsvenskan-logot TheSportsDB:stä (kerran viikossa per joukkue).
    func fetchMissingLogos() async {
        seedBundledLogoMap()
        let key = "logoTried"
        var tried = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        let now = Date().timeIntervalSince1970
        func tkey(_ t: Team) -> String { t.league == .nl ? t.name + "#3" : t.name }
        let need = teams.filter {
            ($0.league == .shl || $0.league == .allsvenskan || $0.league == .nl) && logoURL(for: $0.name) == nil && now - (tried[tkey($0)] ?? 0) > 7 * 86400
        }
        var found = false
        // Varmat TheSportsDB-logot National League -joukkueille, joita nimihaku ei löydä
        let nlBadges: [String: String] = [
            "Genève-Servette HC": "https://r2.thesportsdb.com/images/media/team/badge/9zq0sa1647290526.png",
            "EHC Biel-Bienne": "https://r2.thesportsdb.com/images/media/team/badge/oy3z7j1647290451.png",
            "EHC Kloten": "https://r2.thesportsdb.com/images/media/team/badge/f37tvd1626190829.png",
            "HC Lugano": "https://r2.thesportsdb.com/images/media/team/badge/l7m2vl1647290511.png",
        ]
        for (n, u) in nlBadges where logoURL(for: n) == nil && teams.contains(where: { $0.name == n }) {
            var logos = state.autoLogos ?? [:]
            logos[n] = u
            state.autoLogos = logos
            found = true
        }
        let pending = need.filter { logoURL(for: $0.name) == nil }
        for t in pending {
            tried[tkey(t)] = now
            let plain = t.name.folding(options: .diacriticInsensitive, locale: nil)
            var queries = [t.name]
            if t.league == .nl, plain != t.name { queries.append(plain) }
            if t.league == .nl {
                var short = plain
                for pre in ["HC ", "EHC ", "SC ", "EV "] where short.hasPrefix(pre) { short = String(short.dropFirst(pre.count)) }
                if short.hasSuffix(" HC") { short = String(short.dropLast(3)) }
                for q in [short, short.replacingOccurrences(of: "-", with: " ")] where !queries.contains(q) { queries.append(q) }
            }
            let country = t.league == .nl ? "Switzerland" : "Sweden"
            for qs in queries {
                guard let q = qs.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "https://www.thesportsdb.com/api/v1/json/123/searchteams.php?t=\(q)") else { continue }
                var req = URLRequest(url: url)
                req.timeoutInterval = 15
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   (resp as? HTTPURLResponse)?.statusCode == 200,
                   let r = try? JSONDecoder().decode(SportsDBResponse.self, from: data),
                   let list = r.teams {
                    let hit = list.first { $0.strSport == "Ice Hockey" && $0.strCountry == country }
                        ?? (t.league == .nl ? nil : list.first { $0.strSport == "Ice Hockey" })
                    if let b = hit?.strBadge, !b.isEmpty {
                        var logos = state.autoLogos ?? [:]
                        logos[t.name] = b
                        state.autoLogos = logos
                        found = true
                        break
                    }
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        UserDefaults.standard.set(tried, forKey: key)
        if found { persist() }
    }
}
