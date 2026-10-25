# Jääkiekon Pistepörssi 2026/2027 (macOS, SwiftUI)

Avaa `JaakiekkoTilastot.xcodeproj` Xcodella (16 tai uudempi) ja paina Run (⌘R).

Ensimmäisellä kerralla: valitse projektin Signing & Capabilities -välilehdeltä oma Team ja halutessasi vaihda Bundle Identifier.

- macOS 14+, SwiftUI + Observation
- NHL: tilastot päivittyvät automaattisesti NHL:n rajapinnasta (käynnistyessä ja 10 min välein)
- Liiga: maalit ja syötöt lasketaan liiga.fi:n ottelutiedoista, ottelumäärä on joukkueen pelaamat ottelut; logot haetaan samasta lähteestä
- SHL ja HockeyAllsvenskan: ei julkista tilastorajapintaa, tilastot ovat pohjadataa + omat muokkaukset; HockeyAllsvenskanin logot on haettu liigan sivustolta
- Liiga / SHL / HockeyAllsvenskan: pohjadata + omat muokkaukset
- Tila tallentuu kansioon Application Support/JaakiekkoTilastot/state.json
- JSON-vienti ja -tuonti ovat yhteensopivia web-version kanssa
