import Foundation

/// Varalogot, jotka toimivat ennen ensimmäistä rajapintahakua tai jos haku epäonnistuu.
/// Liigan logot päivittyvät rajapinnasta; HockeyAllsvenskanin logot ovat liigan omalta sivustolta.
/// SHL:lle ei ole varmistettua logolähdettä, joten niille näytetään lyhennemerkki (oman logon voi asettaa pelaajan muokkauslomakkeessa).
enum StaticLogos {
    private static let b = "https://cdn.builder.io/api/v1/image/assets%2Ff11503eeae084753968caac3899a5d78%2F"
    private static let ha = "https://ha-media.hadigital.se/ha-league/"

    static let urls: [String: String] = [
        // Liiga
        "Jukurit": b + "5fa94d44327f46b7b4e30ae58a3be7ca",
        "HPK": b + "6020edd6d9bc45b68a50bd191b826deb",
        "Kiekko-Espoo": b + "bf4ab47ce42640ebad139fd11a6a7861",
        "KalPa": b + "1183427f2aed401184bc2f96bb1a3303",
        "Kärpät": b + "57b5b1a6c04f43368910ee73822513d8",
        "Ässät": b + "e4c7031958a043cdb8ca80c3c353f0c6",
        "Lukko": b + "c7acfb63cfe7436b9778f1e684cd0c57",
        "Ilves": b + "079e0e0bde4f43b8b8afa667d3285ebc",
        "SaiPa": b + "5640db8b21854732baf6afc56fc013b5",
        "Tappara": b + "8bb664ba2392481ebc1091a33ee75513",
        "TPS": b + "e07109c96edf4561b8b5021e7fc44526",
        "KooKoo": b + "7d933387f498496094d7ef1928e9fa7b",
        "Sport": b + "77efd6df129843699ae9a4c2e94efcb2",
        "Jokerit": b + "aaa8acd74adb43f4bfd3de3e9af484b0",
        "Pelicans": b + "269341129a1449ccb0a64345337c3273",
        // HockeyAllsvenskan
        "AIK": ha + "AIK_logo_aeaee9d0d7/AIK_logo_aeaee9d0d7.webp",
        "Kalmar HC": ha + "KHC_logo_c216f7d7ef/KHC_logo_c216f7d7ef.webp",
        "MoDo Hockey": ha + "MODO_logowebp_7958fa798d/MODO_logowebp_7958fa798d.webp",
        "IK Oskarshamn": ha + "IKO_logo_0a5ec7f1c3/IKO_logo_0a5ec7f1c3.webp",
        "Almtuna IS": ha + "AIS_logo_1630847fab/AIS_logo_1630847fab.webp",
        "BIK Karlskoga": ha + "BIK_logo_87df9b9f59/BIK_logo_87df9b9f59.webp",
        "Södertälje SK": ha + "SSK_Logotyp_Krans_9e983a8dff/SSK_Logotyp_Krans_9e983a8dff.webp",
        "Östersunds IK": ha + "Oe_IK_Logotyp_07abdb2a3f/Oe_IK_Logotyp_07abdb2a3f.webp",
        "Västerås IK": ha + "VIK_logo_dca4566eac/VIK_logo_dca4566eac.webp",
        "Nybro Vikings": ha + "NYB_logo_9177238de1/NYB_logo_9177238de1.webp",
        "Vimmerby HC": ha + "VHC_logo_b2656683bb/VHC_logo_b2656683bb.webp",
        "Mora IK": ha + "MIK_logo_c9f61b7bb4/MIK_logo_c9f61b7bb4.webp",
        "Visby/Roma": ha + "Visby_Logotyp_f3c19bb9ba/Visby_Logotyp_f3c19bb9ba.webp",
    ]
}
