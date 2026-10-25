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

    private static func file(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(hash + ".img")
    }

    static func read(_ url: URL) -> Data? {
        try? Data(contentsOf: file(for: url))
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
    /// Hakee puuttuvat SHL- ja HockeyAllsvenskan-logot TheSportsDB:stä (kerran viikossa per joukkue).
    func fetchMissingLogos() async {
        let key = "logoTried"
        var tried = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        let now = Date().timeIntervalSince1970
        let need = teams.filter {
            ($0.league == .shl || $0.league == .allsvenskan) && logoURL(for: $0.name) == nil && now - (tried[$0.name] ?? 0) > 7 * 86400
        }
        var found = false
        for t in need {
            tried[t.name] = now
            if let q = t.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "https://www.thesportsdb.com/api/v1/json/123/searchteams.php?t=\(q)") {
                var req = URLRequest(url: url)
                req.timeoutInterval = 15
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   (resp as? HTTPURLResponse)?.statusCode == 200,
                   let r = try? JSONDecoder().decode(SportsDBResponse.self, from: data),
                   let list = r.teams {
                    let hit = list.first { $0.strSport == "Ice Hockey" && $0.strCountry == "Sweden" }
                        ?? list.first { $0.strSport == "Ice Hockey" }
                    if let b = hit?.strBadge, !b.isEmpty {
                        var logos = state.autoLogos ?? [:]
                        logos[t.name] = b
                        state.autoLogos = logos
                        found = true
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        UserDefaults.standard.set(tried, forKey: key)
        if found { persist() }
    }
}
