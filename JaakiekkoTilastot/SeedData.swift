import Foundation

/// Joukkueet ja pelaajat (Elite Prospects 2.10.2026 + NHL-joukkuelistat).
/// Tyhjä tilasto = ei vielä haettu. NHL-tilastot päivittyvät sovelluksessa automaattisesti.
enum SeedData {
    // Sarja|Joukkue|Lyhenne|(NHL: maa)
    static let teamsRaw = """
NHL|Anaheim Ducks|ANA|US
NHL|Boston Bruins|BOS|US
NHL|Buffalo Sabres|BUF|US
NHL|Calgary Flames|CGY|CA
NHL|Carolina Hurricanes|CAR|US
NHL|Chicago Blackhawks|CHI|US
NHL|Colorado Avalanche|COL|US
NHL|Columbus Blue Jackets|CBJ|US
NHL|Dallas Stars|DAL|US
NHL|Detroit Red Wings|DET|US
NHL|Edmonton Oilers|EDM|CA
NHL|Florida Panthers|FLA|US
NHL|Los Angeles Kings|LAK|US
NHL|Minnesota Wild|MIN|US
NHL|Montréal Canadiens|MTL|CA
NHL|Nashville Predators|NSH|US
NHL|New Jersey Devils|NJD|US
NHL|New York Islanders|NYI|US
NHL|New York Rangers|NYR|US
NHL|Ottawa Senators|OTT|CA
NHL|Philadelphia Flyers|PHI|US
NHL|Pittsburgh Penguins|PIT|US
NHL|San Jose Sharks|SJS|US
NHL|Seattle Kraken|SEA|US
NHL|St. Louis Blues|STL|US
NHL|Tampa Bay Lightning|TBL|US
NHL|Toronto Maple Leafs|TOR|CA
NHL|Utah Mammoth|UTA|US
NHL|Vancouver Canucks|VAN|CA
NHL|Vegas Golden Knights|VGK|US
NHL|Washington Capitals|WSH|US
NHL|Winnipeg Jets|WPG|CA
SM-liiga|Ilves|ILV
SM-liiga|Jukurit|JUK
SM-liiga|JYP|JYP
SM-liiga|SaiPa|SAI
SM-liiga|Kiekko-Espoo|KES
SM-liiga|Ässät|ÄSS
SM-liiga|Lukko|LUK
SM-liiga|Kärpät|KÄR
SM-liiga|Tappara|TAP
SM-liiga|TPS|TPS
SM-liiga|Pelicans|PEL
SM-liiga|KalPa|KAL
SM-liiga|Sport|SPO
SM-liiga|HPK|HPK
SM-liiga|HIFK|HIF
SM-liiga|Jokerit|JOK
SM-liiga|KooKoo|KOO
SHL|Växjö Lakers HC|VÄX
SHL|Skellefteå AIK|SKE
SHL|Frölunda HC|FRÖ
SHL|Färjestad BK|FÄR
SHL|Örebro HK|ÖRE
SHL|Malmö Redhawks|MAL
SHL|Luleå HF|LUL
SHL|HV71|HV7
SHL|Brynäs IF|BRY
SHL|IF Björklöven|BJÖ
SHL|Rögle BK|RÖG
SHL|Djurgårdens IF|DIF
SHL|Linköping HC|LHC
SHL|Timrå IK|TIM
HockeyAllsvenskan|IK Oskarshamn|OSK
HockeyAllsvenskan|Östersunds IK|ÖST
HockeyAllsvenskan|Södertälje SK|SÖD
HockeyAllsvenskan|Almtuna IS|ALM
HockeyAllsvenskan|Leksands IF|LEK
HockeyAllsvenskan|Visby/Roma|VIS
HockeyAllsvenskan|Kalmar HC|KAL
HockeyAllsvenskan|BIK Karlskoga|KAR
HockeyAllsvenskan|MoDo Hockey|MOD
HockeyAllsvenskan|Vimmerby HC|VIM
HockeyAllsvenskan|Västerås IK|VÄS
HockeyAllsvenskan|AIK|AIK
HockeyAllsvenskan|Mora IK|MOR
HockeyAllsvenskan|Nybro Vikings|NYB
AHL|Abbotsford Canucks|ABB|CA
AHL|Bakersfield Condors|BAK|US
AHL|Belleville Senators|BEL|CA
AHL|Calgary Wranglers|CGY|CA
AHL|Charlotte Checkers|CLT|US
AHL|Chicago Wolves|CHI|US
AHL|Cleveland Monsters|CLE|US
AHL|Coachella Valley Firebirds|CV|US
AHL|Colorado Eagles|COL|US
AHL|Grand Rapids Griffins|GR|US
AHL|Hamilton Hammers|HAM|CA
AHL|Hartford Wolf Pack|HFD|US
AHL|Henderson Silver Knights|HSK|US
AHL|Hershey Bears|HER|US
AHL|Iowa Wild|IA|US
AHL|Laval Rocket|LAV|CA
AHL|Lehigh Valley Phantoms|LV|US
AHL|Manitoba Moose|MB|CA
AHL|Milwaukee Admirals|MIL|US
AHL|Ontario Reign|ONT|US
AHL|Providence Bruins|PRO|US
AHL|Rochester Americans|ROC|US
AHL|Rockford IceHogs|RFD|US
AHL|San Diego Gulls|SD|US
AHL|San Jose Barracuda|SJ|US
AHL|Springfield Thunderbirds|SPR|US
AHL|Syracuse Crunch|SYR|US
AHL|Texas Stars|TEX|US
AHL|Toronto Marlies|TOR|CA
AHL|Tucson Roadrunners|TUC|US
AHL|Utica Comets|UTC|US
AHL|Wilkes-Barre/Scranton Penguins|WBS|US
Mestis|Hermes|HER
Mestis|IPK|IPK
Mestis|JoKP|JOK
Mestis|Ketterä|KET
Mestis|KeuPa HT|KEU
Mestis|K-Vantaa|KVA
Mestis|Pyry|PYR
Mestis|RoKi|ROK
Mestis|TUTO Hockey|TUT
"""

    // Joukkue|Pelaaja|Pelipaikka|Kansallisuus|O|M|S|(web-version id)
    static let rosterRaw = """
Anaheim Ducks|Leo Carlsson|F|Ruotsi
Anaheim Ducks|Troy Terry|F|USA
Anaheim Ducks|Cutter Gauthier|F|USA
Boston Bruins|David Pastrňák|F|Tšekki
Boston Bruins|Charlie McAvoy|D|USA
Boston Bruins|Morgan Geekie|F|Kanada
Buffalo Sabres|Tage Thompson|F|USA
Buffalo Sabres|Rasmus Dahlin|D|Ruotsi
Buffalo Sabres|Josh Norris|F|USA
Calgary Flames|Jonathan Huberdeau|F|Kanada
Calgary Flames|Yegor Sharangovich|F|Valko-Venäjä
Calgary Flames|Mikael Backlund|F|Ruotsi
Carolina Hurricanes|Sebastian Aho|F|Suomi
Carolina Hurricanes|Seth Jarvis|F|Kanada
Carolina Hurricanes|Andrei Svechnikov|F|Venäjä
Chicago Blackhawks|Connor Bedard|F|Kanada
Chicago Blackhawks|Patrick Kane|F|USA
Chicago Blackhawks|Frank Nazar|F|USA
Colorado Avalanche|Nathan MacKinnon|F|Kanada
Colorado Avalanche|Cale Makar|D|Kanada
Colorado Avalanche|Nazem Kadri|F|Kanada
Colorado Avalanche|Brock Nelson|F|USA|1|1|2
Columbus Blue Jackets|Zach Werenski|D|USA
Columbus Blue Jackets|Adam Fantilli|F|Kanada
Columbus Blue Jackets|Conor Garland|F|USA
Dallas Stars|Jason Robertson|F|USA
Dallas Stars|Mikko Rantanen|F|Suomi
Dallas Stars|Miro Heiskanen|D|Suomi
Detroit Red Wings|Dylan Larkin|F|USA
Detroit Red Wings|Lucas Raymond|F|Ruotsi
Detroit Red Wings|Alex DeBrincat|F|USA
Edmonton Oilers|Evan Bouchard|D|Kanada|2|4|4|nhl-1
Edmonton Oilers|Connor McDavid|F|Kanada|2|1|6|nhl-2
Edmonton Oilers|Leon Draisaitl|F|Saksa|2|2|2|nhl-8
Edmonton Oilers|Vasili Podkolzin|F|Venäjä|2|3|1
Florida Panthers|Aleksander Barkov|F|Suomi
Florida Panthers|Sam Reinhart|F|Kanada
Florida Panthers|Matthew Tkachuk|F|USA
Florida Panthers|Brady Tkachuk|F|USA
Los Angeles Kings|Adrian Kempe|F|Ruotsi
Los Angeles Kings|Kevin Fiala|F|Sveitsi
Los Angeles Kings|Quinton Byfield|F|Kanada
Minnesota Wild|Kirill Kaprizov|F|Venäjä
Minnesota Wild|Quinn Hughes|D|USA
Minnesota Wild|Matt Boldy|F|USA
Montréal Canadiens|Nick Suzuki|F|Kanada
Montréal Canadiens|Cole Caufield|F|USA
Montréal Canadiens|Lane Hutson|D|USA
Nashville Predators|Filip Forsberg|F|Ruotsi
Nashville Predators|Steven Stamkos|F|Kanada
Nashville Predators|Ryan O'Reilly|F|Kanada
New Jersey Devils|Jack Hughes|F|USA
New Jersey Devils|Nico Hischier|F|Sveitsi
New Jersey Devils|Jesper Bratt|F|Ruotsi
New York Islanders|Mathew Barzal|F|Kanada
New York Islanders|Bo Horvat|F|Kanada
New York Islanders|Matthew Schaefer|D|Kanada
New York Rangers|J.T. Miller|F|USA
New York Rangers|Alexis Lafrenière|F|Kanada
New York Rangers|Will Cuylle|F|Kanada
Ottawa Senators|Tim Stützle|F|Saksa
Ottawa Senators|Jake Sanderson|D|USA
Ottawa Senators|Thomas Chabot|D|Kanada
Philadelphia Flyers|Travis Konecny|F|Kanada
Philadelphia Flyers|Trevor Zegras|F|USA
Philadelphia Flyers|Matvei Michkov|F|Venäjä
Pittsburgh Penguins|Sidney Crosby|F|Kanada
Pittsburgh Penguins|Yevgeni Malkin|F|Venäjä
Pittsburgh Penguins|Erik Karlsson|D|Ruotsi
San Jose Sharks|Macklin Celebrini|F|Kanada
San Jose Sharks|Tyler Toffoli|F|Kanada
San Jose Sharks|William Smith|F|USA|1|2|1
Seattle Kraken|Jared McCann|F|Kanada
Seattle Kraken|Vince Dunn|D|Kanada|1|1|2
Seattle Kraken|Shane Wright|F|Kanada
St. Louis Blues|Robert Thomas|F|Kanada
St. Louis Blues|Jimmy Snuggerud|F|USA
St. Louis Blues|Dylan Holloway|F|Kanada
Tampa Bay Lightning|Nikita Kucherov|F|Venäjä
Tampa Bay Lightning|Brayden Point|F|Kanada
Tampa Bay Lightning|Jake Guentzel|F|USA
Toronto Maple Leafs|William Nylander|F|Ruotsi|1|2|0|nhl-4
Toronto Maple Leafs|Auston Matthews|F|USA
Toronto Maple Leafs|John Tavares|F|Kanada
Utah Mammoth|Clayton Keller|F|USA
Utah Mammoth|Logan Cooley|F|USA
Utah Mammoth|Dylan Guenther|F|Kanada
Vancouver Canucks|Elias Pettersson|F|Ruotsi|2|2|2|nhl-7
Vancouver Canucks|Paul Cotter|F|USA|2|3|1|nhl-6
Vancouver Canucks|Marco Rossi|F|Itävalta|2|3|1
Vancouver Canucks|Filip Hronek|D|Tšekki|2|0|4
Vegas Golden Knights|Jack Eichel|F|USA|1|1|2|nhl-3
Vegas Golden Knights|Ivan Barbashev|F|Venäjä|1|0|2|nhl-5
Vegas Golden Knights|Mitch Marner|F|Kanada
Washington Capitals|Alex Ovechkin|F|Venäjä
Washington Capitals|Jordan Kyrou|F|Kanada
Washington Capitals|Alex Tuch|F|USA
Washington Capitals|Tom Wilson|F|Kanada
Winnipeg Jets|Kyle Connor|F|USA
Winnipeg Jets|Mark Scheifele|F|Kanada
Winnipeg Jets|Josh Morrissey|D|Kanada
Ilves|Luke Henman|||7|3|6|liiga-3
Ilves|Aleks Haatanen|F||7|2|4
Ilves|Benjamin Korhonen|F||6|3|1
Jukurit|Andrej Šustr|D||9|0|13|liiga-1
Jukurit|Jacob Hayhurst|||9|4|8|liiga-2
Jukurit|Elias Koponen|||9|2|6
JYP|Santeri Huovila|F||6|1|7
JYP|Valtteri Ojantakanen|F||6|3|4
JYP|Reece Newkirk|F||6|3|4
SaiPa|Aarne Intonen|F||7|1|5
SaiPa|Patrik Siikanen|F||7|5|0
SaiPa|Petrus Palmu|F||7|2|3
Kiekko-Espoo|Jere Väisänen|F||8|3|4
Kiekko-Espoo|Lukas Svejkovsky|F||8|4|2
Kiekko-Espoo|Jere Sallinen|F||8|3|1
Ässät|Alexandre Doucet|||8|3|5
Ässät|Johan Olofsson|F||8|2|3
Ässät|Cameron Hillis|F||8|2|3
Lukko|Alex Beaucage|||8|4|4
Lukko|Jakob Stenqvist|D||8|0|6
Lukko|Antti Saarela|F||8|1|4
Kärpät|Roni Hirvonen|F||7|2|3
Kärpät|Wiktor Nilsson|F||7|2|2
Kärpät|Henrik Törnqvist|F||7|2|2
Tappara|Henrik Haapala|F||7|2|5
Tappara|Joachim Blichfeld|F||7|3|3
Tappara|Kasper Simontaival|F||7|1|5
TPS|Lukas Wernblom|||8|4|7|liiga-4
TPS|Lukas Haudum|||8|1|8|liiga-5
TPS|Lars Bryggman|F||7|4|3
Pelicans|Roni Karvinen|F||8|3|3
Pelicans|Oleksii Myklukha|F||8|2|3
Pelicans|Liam Hawel|F||8|0|5
KalPa|Aleksi Klemetti|F||7|3|2
KalPa|Juuso Mäenpää|F||7|2|3
KalPa|Jaakko Rissanen|F||7|1|4
Sport|Lari Heikkinen|F||9|4|1
Sport|George Diaco|F||9|3|1
HPK|Sami Päivärinta|||7|4|5|liiga-6
HPK|Brendan Ranford|F||7|0|6
HPK|Chad Nychuk|D||7|2|2
HIFK|Daniel Mäkiaho|||8|4|4
HIFK|Vincent Marleau|F||8|3|3
HIFK|Kasper Puutio|D||8|0|5
Jokerit|Emil Kuusla|F||6|1|5
Jokerit|Maxime Fortier|F||7|1|4
Jokerit|Patrick Curry|F||8|0|5
KooKoo|Manu Mäkelä|F||8|2|2
Växjö Lakers HC|Lucas Elvenes|||5|2|9
Växjö Lakers HC|Joel Persson|||5|2|6
Växjö Lakers HC|Olivier Nadeau|||5|5|2
Skellefteå AIK|Oscar Lindberg|||5|3|6
Skellefteå AIK|Mikkel Aagaard|||5|4|3
Skellefteå AIK|Rickard Hugg|F||5|2|4
Skellefteå AIK|Jonathan Pudas|D||5|1|4|shl-3
Skellefteå AIK|Marcus Sörensen|F|||||shl-1
Frölunda HC|Graeme Clarke|||5|4|3
Frölunda HC|Henrik Tömmernes|D||5|2|3
Frölunda HC|Patrik Puistola|F||5|2|2
Färjestad BK|Viktor Lodin|||5|3|4
Färjestad BK|Axel Bergkvist|D||5|1|5
Färjestad BK|Radim Zohorna|F||5|3|2
Örebro HK|Kalle Kossila|||5|0|7
Örebro HK|Patrik Karlkvist|F||5|2|3
Örebro HK|Milton Oscarson|F||5|2|1
Malmö Redhawks|Oliwer Kaski|||4|4|2
Malmö Redhawks|Lauri Pajuniemi|F||4|2|2
Malmö Redhawks|William von Barnekow|F||4|1|2
Luleå HF|Joona Koppanen|||5|4|2
Luleå HF|Anton Levtchi|F||5|2|3
Luleå HF|Markus Nurmi|F||5|1|3
Luleå HF|Linus Omark|F|||||shl-4
HV71|Lukas Rousek|F||5|2|4
HV71|Pavol Regenda|F||4|3|2
HV71|Nikola Pasic|F||5|3|2
Brynäs IF|Jakob Silfverberg|F||5|1|5
Brynäs IF|Johan Larsson|F||5|3|2
Brynäs IF|Kieffer Bellows|F||5|3|1
IF Björklöven|Lucas Ekeståhl Jonsson|D||5|1|4
IF Björklöven|Robin Kovács|F||5|4|0
IF Björklöven|Oscar Tellström|F||5|2|2
Rögle BK|Fredrik Olofsson|F||5|1|4
Rögle BK|Lubos Horky|F||5|3|0
Rögle BK|Karson Kuhlman|F||5|2|1
Djurgårdens IF|Charles Hudon|F||5|2|2
Djurgårdens IF|Oliver Wahlstrom|F||3|2|1
Djurgårdens IF|Joe Snively|F||5|0|3
Linköping HC|Christoffer Ehn|F||4|2|0
Linköping HC|Mikko Kokkonen|D||4|1|1
Linköping HC|Roby Järventie|F|||||shl-2
Timrå IK|Reid Gardiner|F||5|2|0
Timrå IK|Anton Heikkinen|F||5|1|1
IK Oskarshamn|Calle Karlsson|||6|6|5|ha-1
IK Oskarshamn|Joel Svensson|||6|6|5|ha-2
IK Oskarshamn|Filiph Engsund|||6|3|7|ha-4
Östersunds IK|Daniel Öhrn|||6|3|8|ha-3
Östersunds IK|Olle Norberg|||6|1|7
Östersunds IK|Anton Klint|F||6|6|0
Södertälje SK|Nolan Stevens|||6|2|7
Södertälje SK|Carter Souch|||6|5|3
Södertälje SK|Tarun Fizer|||6|1|7
Almtuna IS|Karl Sterner|||6|5|3
Almtuna IS|Lukas Vesterlund|F||6|2|3
Almtuna IS|Bruno Osmanis|F||6|2|2
Leksands IF|Tyler Kelleher|||6|4|4
Leksands IF|Åke Stakkestad|F||6|5|1
Leksands IF|Josh Passolt|F||6|3|3
Visby/Roma|Juho Liuksiala|F||6|3|4
Visby/Roma|Giorgio Estephan|F||6|2|5
Visby/Roma|John Dahlström|F||4|3|0
Kalmar HC|Christian Felton|D||6|3|4
Kalmar HC|Reece Vitelli|F||6|3|3
Kalmar HC|Tommy Bergsland|D||6|2|4
BIK Karlskoga|Henrik Björklund|F||6|3|3
BIK Karlskoga|Gustaf Franzén|F||6|3|3
BIK Karlskoga|Carson Golder|F||6|2|3
MoDo Hockey|Elton Hermansson|F||6|3|3
MoDo Hockey|Carl Mattsson|F||6|5|0
MoDo Hockey|August Berg|D||6|2|1
Vimmerby HC|Max Karlsson|F||6|4|1
Vimmerby HC|Hampus Karlsson|F||6|2|3
Vimmerby HC|Hugo Lejon|F||6|2|3
Västerås IK|Sebastian Falk|F||6|3|2
Västerås IK|Carl Jakobsson|F||6|2|3
Västerås IK|Lukas Zetterberg|F||6|2|2
AIK|Oliver Johansson|F||6|3|2
AIK|Daniel Ljungman|F||6|2|3
AIK|Scott Pooley|F||6|1|4
Mora IK|Oliver Tärnström|F||6|2|2
Mora IK|Karl Umegård|F||6|3|0
Mora IK|Hampus Larsson|F||6|2|1
Nybro Vikings|Joachim Rohdin|F||6|3|2
Nybro Vikings|Oscar Nordin|F||5|1|3
Nybro Vikings|Melvin Wersäll|F||6|0|4
"""

    /// Vanhojen pelaajien lisätiedot (id -> kansallisuus, syntymävuosi, kätisyys)
    static let meta: [String: (nat: String?, born: Int?, shoots: String?)] = [
        "nhl-1": (nil, 1999, "R"), "nhl-2": (nil, 1997, "L"), "nhl-3": (nil, 1996, "R"),
        "nhl-4": (nil, 1996, "R"), "nhl-5": (nil, 1995, "L"), "nhl-6": (nil, 1999, "L"),
        "nhl-7": (nil, 1998, "L"), "nhl-8": (nil, 1995, "L"),
        "liiga-1": ("Tšekki", 1991, "L"), "liiga-6": ("Suomi", nil, nil),
        "shl-4": ("Ruotsi", 1987, "L"), "shl-2": ("Suomi", nil, nil)
    ]
}
