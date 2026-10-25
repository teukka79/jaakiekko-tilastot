import Foundation

/// API-avaimen tallennus sovelluksen omaan (sandbox-)tallennustilaan.
/// Nimi on säilytetty yhteensopivuuden vuoksi. Aiemmin avain oli macOS:n Keychainissa, mutta Xcode-käännökset
/// allekirjoitetaan joka kerralla uudelleen, minkä vuoksi macOS kysyi salasanaa jokaisella käynnistyksellä.
enum Keychain {
    private static func key(_ account: String) -> String { "secret.\(account)" }

    static func get(_ account: String) -> String? {
        let v = UserDefaults.standard.string(forKey: key(account))
        return (v?.isEmpty == false) ? v : nil
    }

    @discardableResult
    static func set(_ value: String?, for account: String) -> Bool {
        if let value, !value.isEmpty {
            UserDefaults.standard.set(value, forKey: key(account))
        } else {
            UserDefaults.standard.removeObject(forKey: key(account))
        }
        return true
    }
}
