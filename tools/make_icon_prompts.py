#!/usr/bin/env python3
"""Yeni ikon seti için görsel üretim komutları (prompt) -> docs/art/ICON_PROMPTS.md

Oyundaki her ikon için dosya adı + İngilizce prompt üretir (görsel üreticiler İngilizce'de daha iyi).
Dosyalar assets/ui/icons_new/<ad>.png (portreler assets/portraits/<ad>.png) olarak konunca oyun otomatik kullanır.
Yeniden üretmek için: python3 tools/make_icon_prompts.py
"""
import json, re, unicodedata

D = "data/common/"
def J(n): return json.load(open(D + n, encoding="utf-8"))

STYLE_ICON = ("Hand-painted icon for a WWII grand strategy game (classic 1930s-40s strategy game style), 1930s-1940s era, "
              "oil-painting look with visible brush strokes, muted bronze, olive, khaki and steel-grey palette with warm gold highlights, "
              "dramatic side lighting, strong readable silhouette centered, slight 3/4 view, subtle dark vignette, "
              "transparent background, no text, no letters, no numbers, no border, no frame, square 1:1, 512x512")
STYLE_SMALL = ("Small UI glyph for a WWII strategy game top bar, embossed brass/bronze metal emblem, "
               "simple bold silhouette readable at 24 px, soft bevel and gold rim light, "
               "transparent background, no text, no letters, no numbers, square 1:1, 256x256")
STYLE_FOCUS = ("National focus emblem for a WWII grand strategy game (classic 1930s-40s strategy game style), "
               "a painted object/scene inside an irregular painted badge shape, 1930s propaganda-poster palette, "
               "muted colors with gold accents, dramatic lighting, centered, transparent background, "
               "no text, no letters, no numbers, square 1:1, 512x512")
STYLE_EVENT = ("Historical event illustration for a WWII grand strategy game, 1930s-1940s, painted in the style of a "
               "sepia-tinted period press photograph turned into an oil painting, cinematic wide composition, muted "
               "desaturated colors, film grain, no text, no captions, no borders, landscape 1024x384 (8:3)")
STYLE_PORTRAIT = ("Head-and-shoulders portrait of {who}, {role}, as he looked around {year}, painted in the style of classic strategy game leader "
                  "portraits: realistic oil painting based on period photographs, period clothing/uniform, neutral dark "
                  "background with soft gradient, subtle film grain, facing slightly left, 4:5 portrait 400x500, "
                  "no text, no border, historically accurate likeness")

def slug(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")

out = []
def h(t): out.append("\n## " + t + "\n")
_rows = set()
def row(name, subject, style=STYLE_ICON, folder="assets/ui/icons_new"):
    if name in _rows:
        return
    _rows.add(name)
    subject = subject[0].upper() + subject[1:] if subject else subject
    out.append(f"**`{name}.png`** — {folder}/\n```\n{subject.rstrip('.')}. {style}\n```\n")

# ---------------------------------------------------------------- arayüz
UI = {
 "political_power": "an eagle-topped brass laurel wreath around a government seal, symbol of political power",
 "stability": "a classical brass balance scale perfectly level, symbol of national stability",
 "war_support": "a raised clenched fist holding a rifle in front of a waving banner, symbol of war support",
 "manpower": "a small group of three 1930s soldiers in greatcoats standing shoulder to shoulder, symbol of manpower",
 "factory": "a brick factory with two smoking chimneys and a sawtooth roof, symbol of industry",
 "fuel": "a stack of steel oil drums with a fuel can, symbol of fuel reserves",
 "supply": "a wooden supply crate with a stencil-less lid and a canvas sack, symbol of army supply",
 "convoy_count": "a merchant cargo ship with cargo booms seen from the side, symbol of convoys",
 "command_power": "a field telephone with a coiled cord and a commander's map case, symbol of command power",
 "xp_army": "a single khaki star on a green army shoulder patch, symbol of army experience",
 "xp_navy": "a single star over a ship anchor on a navy-blue patch, symbol of naval experience",
 "xp_air": "a single star between pilot wings on a sky-blue patch, symbol of air experience",
 "world_tension": "a cracked globe with a lit fuse and sparks, symbol of world tension",
 "at_war": "two crossed bayonet rifles over a red background, symbol of being at war",
 "menu_politics": "a government building with columns and a flag on top, menu button for politics",
 "menu_focus": "an unrolled strategic plan with a compass and a quill pen, menu button for national focus",
 "menu_research": "a laboratory flask, a microscope and blueprint rolls, menu button for research",
 "menu_diplomacy": "a fountain pen signing a treaty with a wax seal, menu button for diplomacy",
 "menu_trade": "a ship's cargo hook lifting a pallet of goods over a dock, menu button for trade",
 "menu_construction": "a construction crane lifting a steel beam over scaffolding, menu button for construction",
 "menu_production": "an assembly line with a rifle and an artillery shell, menu button for production",
 "menu_army": "a 1930s infantry helmet with a rifle leaning against it, menu button for the army",
 "menu_navy": "a battleship bow cutting through waves, menu button for the navy",
 "menu_air": "a single-engine propeller fighter plane in flight, menu button for the air force",
 "menu_logistics": "an army supply truck with canvas cover loaded with crates, menu button for logistics",
 "battle": "two crossed sabres with an explosion burst behind them, battle marker",
 "map_capital": "a golden star inside a laurel ring, capital city marker",
 "map_city": "a small cluster of European town houses with a church spire, city marker",
 "map_port": "a ship anchor with a rope, naval port marker",
 "map_airbase": "a propeller plane silhouette over a runway, airbase marker",
}
h("0. Nasıl kullanılır")
out.append("""- Her başlığın altında **dosya adı** ve görsel üreticiye yapıştırılacak **prompt** var (İngilizce; üreticiler İngilizce'de daha tutarlı).
- Çıktıyı **PNG, saydam arka plan** olarak `assets/ui/icons_new/<dosya adı>.png` içine koy. Oyun o adla bir dosya bulursa eskisini **otomatik** bırakır, kod değişikliği gerekmez.
- Olay resimleri geniş (8:3), lider portreleri dikey (4:5) → portreler `assets/portraits/<dosya adı>.png`.
- Tutarlılık için: aynı seti tek oturumda, aynı stil cümlesiyle üret; gerekirse ilk beğendiğin ikonu "style reference" olarak ver.
- Eksik kalan ikonlar eski setten gösterilir; hepsini birden bitirmek zorunda değilsin.
""")
h("1. Arayüz: üst bar, menü düğmeleri, harita işaretleri")
for k, v in UI.items():
    row(k, v, STYLE_SMALL if not k.startswith("menu_") and not k.startswith("map_") else STYLE_ICON)

# ---------------------------------------------------------------- binalar / kaynaklar / ekipman
B = {
 "civilian_factory": "a 1930s civilian consumer-goods factory with red brick walls, big windows and smoking chimneys",
 "military_factory": "a heavy arms factory hall with a tank hull on a gantry crane and sparks from welding",
 "dockyard": "a shipyard slipway with a warship hull under construction and a hammerhead crane",
 "synthetic_refinery": "a synthetic fuel plant with cracking towers, pipes and storage tanks",
 "infrastructure": "a steam locomotive crossing a steel railway bridge next to a paved road",
 "air_base": "an airfield with a hangar, a windsock and a parked propeller fighter",
 "naval_base": "a naval harbor with concrete piers, cranes and a moored destroyer",
 "anti_air": "a 1930s anti-aircraft gun with a long barrel pointing to the sky behind sandbags",
}
h("2. Binalar")
for k, v in B.items(): row("building_" + k, v)
R = {"oil": "an oil derrick pumping crude oil next to a black oil pool", "steel": "a stack of glowing hot steel ingots and I-beams",
     "aluminium": "shiny aluminium ingots and a bundle of aluminium sheets", "tungsten": "dark grey tungsten ore rocks with metallic crystals",
     "chromium": "chromium ore chunks with a polished chrome-plated gear", "rubber": "a rubber tree tapped with a cup and a stack of raw rubber sheets"}
h("3. Kaynaklar")
for k, v in R.items(): row("resource_" + k, v)
E = {
 "infantry_equipment": "a bolt-action rifle, a steel helmet and a cartridge belt", "support_equipment": "a field radio set, a shovel and a first-aid satchel",
 "artillery_equipment": "a 1930s towed field howitzer", "anti_tank_equipment": "a small 37 mm anti-tank gun with a gun shield",
 "anti_air_equipment": "a quad-barrel anti-aircraft autocannon", "motorized_equipment": "a 1930s military truck with a canvas-covered cargo bed",
 "light_tank_equipment": "a small interwar light tank with a riveted turret and a machine gun", "medium_tank_equipment": "a late-1930s medium tank with a short 75 mm gun",
 "fighter_equipment": "a single-engine monoplane fighter with retractable landing gear", "cas_equipment": "a gull-winged dive bomber diving with its siren",
 "tactical_bomber_equipment": "a twin-engine medium bomber in flight", "convoy": "a slow merchant cargo ship in a convoy",
 "destroyer": "a fast 1930s destroyer with two funnels", "submarine": "a surfaced diesel submarine with its deck gun",
 "cruiser": "a heavy cruiser with triple gun turrets", "battleship": "a massive battleship with big-gun turrets firing a broadside",
}
h("4. Ekipman ve birlikler")
for k, v in E.items(): row("equipment_" + k, v)

# ---------------------------------------------------------------- yasalar / danışmanlar / kararlar
L = {
 "disarmed_nation": "a rifle broken over a knee under a dove, disarmed nation", "volunteer_only": "a recruiting poster wall with a single volunteer signing up",
 "limited_conscription": "a queue of young men with papers at a conscription office", "extensive_conscription": "a large parade of new conscripts marching in columns",
 "service_by_requirement": "older men and students receiving rifles from a sergeant", "all_adults_serve": "civilians of all ages drilling with rifles in a town square",
 "scraping_the_barrel": "teenagers and old men in mismatched uniforms holding rifles, last reserves",
 "civilian_economy": "a busy peacetime shop street with consumer goods in windows", "early_mobilization": "a factory switching from tractors to trucks, early mobilization",
 "partial_mobilization": "a factory line half producing rifles half producing tools", "war_economy": "an arms factory working at night under floodlights, war economy",
 "total_mobilization": "women and men in a vast munitions factory producing shells, total mobilization",
 "free_trade": "cargo ships of many nations crowding an open port, free trade", "export_focus": "export crates stamped with a globe loaded onto a ship",
 "limited_exports": "a customs officer checking cargo at a harbor gate", "closed_economy": "a harbor closed with a chain boom and a padlock, closed economy",
}
h("5. Yasalar")
for k, v in L.items(): row("law_" + k, v)
sp = J("spirits.json")
A = {
 "silent_workhorse": "a quiet bureaucrat at a desk buried in paperwork, stamping documents", "captain_of_industry": "a top-hatted industrialist in front of factory chimneys",
 "armaments_organizer": "an engineer with blueprints of a gun and a slide rule", "research_director": "a scientist in a lab coat holding a glowing vacuum tube",
 "army_chief": "a general in a peaked cap studying a map table", "air_chief": "an air marshal in a flight jacket with a squadron flying behind",
 "navy_chief": "an admiral with binoculars on a battleship bridge", "propaganda_minister": "a minister speaking into a radio microphone before a crowd",
}
h("6. Danışmanlar (yüz değil sembolik figür: telif/benzerlik riski yok)")
for k, v in A.items(): row("advisor_" + k, v)
DEC = {"war_bonds": "a war bonds poster with a coin stack and a savings book", "propaganda_campaign": "loudspeakers on a truck and stacks of leaflets",
       "emergency_industry": "workers building a factory overnight under floodlights"}
h("7. Kararlar")
for k, v in DEC.items(): row("decision_" + k, v)

# ---------------------------------------------------------------- milli ruhlar
SPIRIT = {
 "kemalist_reforms": "a Turkish school blackboard with the Latin alphabet and a Republic cockade", "armed_neutrality": "a soldier guarding a border post with a white-red barrier",
 "village_institutes": "village students building their own school in Anatolia", "five_year_plan": "a Soviet-style factory under construction with a plan chart",
 "great_purge": "an empty officers' chair and scattered epaulettes", "rearmament": "rows of new rifles and helmets in an armory",
 "maginot_mentality": "a concrete Maginot Line bunker with a retractable turret", "british_empire": "a globe with shipping lanes and a Royal Navy ensign",
 "fascist_state": "a marble balcony with banners over a massed rally", "war_propaganda": "a wall of war posters and a radio loudspeaker",
 "industrial_drive": "a blast furnace pouring molten steel", "military_modernization": "old cavalry replaced by new trucks and tanks",
 "national_unity": "people of all classes holding one national flag together", "spanish_civil_war": "a shattered Spanish town with volunteers behind barricades",
 "blitzkrieg_doctrine": "tanks and dive bombers advancing together through a breach", "obsolete_army": "WWI-era soldiers with old rifles and horse-drawn guns",
 "italian_army": "Italian Alpini soldiers with feathered hats in the mountains", "expeditionary_doctrine": "troops boarding transports for an overseas expedition",
 "kemalist_officers": "a proud officer corps saluting under a republican banner", "sectarian_woes": "a divided village crowd arguing in front of a mosque and a government office",
 "disorganized_armed_forces": "a disordered army camp with mixed old equipment and confused officers", "widespread_illiteracy": "an old peasant looking at a newspaper he cannot read",
 "first_five_year_plan": "a Turkish textile factory (Sümerbank) being built on the Anatolian plateau", "trotskyite_plot": "a shadowy conspiracy meeting behind a curtain, secret police at the door",
 "purged_army": "a Red Army staff room with empty chairs and removed portraits", "king_george_v": "a royal crown on a velvet cushion with the Union flag",
 "war_to_end_all_wars": "a WWI memorial with poppies and a grieving mother", "disjointed_government": "a parliament chamber in chaos with ministers shouting",
 "victors_of_ww1": "a triumphal arch with a victory parade of 1918 veterans", "inefficient_economy": "an idle factory with workers on strike and rusty machines",
 "full_employment": "crowds of workers entering factory gates at dawn", "victor_emmanuel": "an Italian royal crown beside a fasces symbol",
 "great_depression": "a long breadline in front of a closed bank", "state_shintoism": "a Shinto torii gate with a rising sun behind",
 "chinese_corruption": "an official taking a bribe under a desk in a crowded office", "april_constitution": "a Polish constitutional document with an eagle seal",
 "political_violence": "street fighting between rival militias with overturned carts", "national_strikes": "striking workers with banners blocking a factory gate",
 "carol_lifestyle": "a lavish royal palace ballroom with champagne", "treaty_of_trianon": "a torn map of Hungary with a treaty document",
 "levente": "Hungarian youth paramilitary drilling with wooden rifles", "divided_nation": "a nation split by a crack between two rival flags",
 "croatian_opposition": "a protest crowd with a checkerboard banner", "milli_sef": "a statesman at a podium before Anıtkabir-like classical columns, 'National Chief'",
 "straits_sovereignty": "Turkish coastal guns overlooking the Bosphorus with a warship passing",
}
h("8. Milli ruhlar (national spirits)")
for k, v in SPIRIT.items(): row("spirit_" + k, v)
for k in sp["spirits"]:
    if k not in SPIRIT:
        row("spirit_" + k, sp["spirits"][k]["name"].get("en", k))

# ---------------------------------------------------------------- milli odaklar
KEYS = [("industr", "factories with smoking chimneys"), ("railway", "a steam train on new rails"), ("rail", "a steam train on new rails"),
        ("army", "marching infantry with modern equipment"), ("navy", "warships at sea"), ("naval", "warships at sea"), ("air", "fighter planes in formation"),
        ("research", "scientists with blueprints"), ("construction", "cranes and scaffolding"), ("arms", "an arms factory producing guns"),
        ("doctrine", "officers planning over a map table"), ("equipment", "new rifles and helmets"), ("unity", "a crowd holding one flag"),
        ("propaganda", "posters and a radio loudspeaker"), ("politic", "a parliament building"), ("steel", "a steel mill with molten metal"),
        ("plan", "a five-year plan chart and a factory"), ("fort", "concrete fortifications"), ("guarantee", "a treaty and a shield"),
        ("pact", "diplomats signing a pact"), ("alliance", "diplomats signing an alliance"), ("tank", "tanks in a column"), ("radar", "a radar antenna")]
def focus_subject(tag, f):
    en = f["name"].get("en") or f["name"].get("tr")
    tr = f["name"].get("tr", en)
    desc = (f.get("desc") or {}).get("en") or (f.get("desc") or {}).get("tr") or ""
    hint = next((v for k, v in KEYS if k in (f["id"] + en).lower()), "")
    country = {"TUR": "Turkish", "GER": "German", "SOV": "Soviet", "ENG": "British", "FRA": "French", "ITA": "Italian",
               "JAP": "Japanese", "USA": "American", "CHI": "Chinese", "_generic": ""}[tag]
    s = f"{country} national focus \"{en}\" ({tr})"
    if hint: s += f", showing {hint}"
    if desc: s += f"; theme: {desc}"
    return s
TUR_F = {
 "tur_kemalism": "Anıtkabir-style classical columns with a Turkish flag and the republic's six arrows", "tur_montreux": "Turkish coastal guns over the Dardanelles with a treaty scroll",
 "tur_five_year": "Turkish engineers unrolling an industrial plan in Ankara", "tur_karabuk": "the Karabük iron and steel works blast furnace",
 "tur_sumerbank": "a Sümerbank textile mill with looms", "tur_railways": "a steam locomotive crossing an Anatolian viaduct",
 "tur_second_plan": "a second wave of Turkish factories and power plants", "tur_village": "a village institute with students building a school",
 "tur_nuri": "Nuri Demirağ aircraft factory with a light plane being assembled", "tur_army": "modern Turkish infantry with new helmets on parade",
 "tur_thrace": "bunkers and trenches in Thrace facing the Balkans", "tur_hatay": "the city of Antakya with a Turkish flag raised",
 "tur_balkan": "Balkan Entente flags of Turkey, Greece, Yugoslavia and Romania", "tur_saadabad": "the Saadabad Pact signing in Tehran",
 "tur_neutral": "a Turkish soldier guarding a border with a white-red barrier, armed neutrality", "tur_allies": "Turkish and British officers shaking hands",
 "tur_axis": "Turkish and German officers shaking hands", "tur_mosul": "the oil fields of Mosul under a Turkish flag", "tur_aegean": "Turkish marines landing on an Aegean island",
}
h("9. Milli odaklar (national focus)")
seen_f = set()
for tag, lst in J("focuses.json")["trees"].items():
    items = [f for f in lst if f["id"] not in seen_f]
    if not items:
        continue
    out.append(f"\n### {'Ortak (her ülke)' if tag == '_generic' else tag}\n")
    for f in items:
        seen_f.add(f["id"])
        subj = TUR_F.get(f["id"]) or focus_subject("_generic" if f["id"].startswith("g_") else tag, f)
        row("focus_" + f["id"], subj.strip(), STYLE_FOCUS)

# ---------------------------------------------------------------- teknoloji
h("10. Teknolojiler")
TH = {"infantry": "infantry weapon", "artillery": "artillery piece", "armor": "tank", "air": "aircraft", "naval": "warship",
      "industry": "industrial machinery", "electronics": "electronic device", "doctrine": "military doctrine map and officers"}
for k, t in J("technologies.json")["techs"].items():
    en = t["name"].get("en", k)
    row("tech_" + k, f"technology \"{en}\" ({t['year']}): a {TH.get(t['cat'], '')} typical of {t['year']}, shown as a detailed period object")

# ---------------------------------------------------------------- olaylar
h("11. Olay resimleri (geniş, 8:3)")
for k, e in J("events.json")["events"].items():
    title = e["title"].get("en") or e["title"].get("tr")
    desc = e["desc"].get("en") or e["desc"].get("tr") or ""
    row("event_" + k, f"historical scene: \"{title}\" — {desc[:260].rstrip('.')}", STYLE_EVENT)

# ---------------------------------------------------------------- lider portreleri
h("12. Lider portreleri (dikey 4:5) — assets/portraits/")
out.append("Üst çubukta bayrak yerine, Hükümet ve Diplomasi ekranlarında gösterilir. 1936 liderleri **ülke koduyla** (ör. `TUR.png`), "
           "olaylarla sonradan gelen liderler **adıyla** (ör. `ismet_inonu.png`). Dosya yoksa oyun bayrağı gösterir.\n")
EN = {
 "GER": ("Adolf Hitler", "Führer of Germany"), "ENG": ("Stanley Baldwin", "Prime Minister of the United Kingdom"),
 "FRA": ("Pierre Laval", "Prime Minister of France"), "ITA": ("Benito Mussolini", "Duce of Italy"), "SOV": ("Joseph Stalin", "General Secretary of the Soviet Union"),
 "TUR": ("Mustafa Kemal Atatürk", "President of Turkey"), "SPR": ("Niceto Alcalá-Zamora", "President of the Spanish Republic"),
 "POR": ("António de Oliveira Salazar", "Prime Minister of Portugal"), "POL": ("Ignacy Mościcki", "President of Poland"),
 "ROM": ("Gheorghe Tătărescu", "Prime Minister of Romania"), "HUN": ("Miklós Horthy", "Regent of Hungary, admiral"),
 "CZE": ("Milan Hodža", "Prime Minister of Czechoslovakia"), "AUS": ("Kurt Schuschnigg", "Chancellor of Austria"),
 "YUG": ("Prince Paul of Yugoslavia", "Prince Regent of Yugoslavia"), "GRE": ("King George II of Greece", "King of Greece"),
 "BUL": ("Tsar Boris III", "Tsar of Bulgaria"), "ALB": ("King Zog I", "King of Albania"), "SWE": ("Per Albin Hansson", "Prime Minister of Sweden"),
 "NOR": ("Johan Nygaardsvold", "Prime Minister of Norway"), "DEN": ("Thorvald Stauning", "Prime Minister of Denmark"),
 "FIN": ("Pehr Evind Svinhufvud", "President of Finland"), "EST": ("Konstantin Päts", "State Elder of Estonia"),
 "LAT": ("Kārlis Ulmanis", "Prime Minister of Latvia"), "LIT": ("Antanas Smetona", "President of Lithuania"),
 "HOL": ("Hendrikus Colijn", "Prime Minister of the Netherlands"), "BEL": ("Paul van Zeeland", "Prime Minister of Belgium"),
 "LUX": ("Joseph Bech", "Prime Minister of Luxembourg"), "SWI": ("Albert Meyer", "President of the Swiss Confederation"),
 "IRE": ("Éamon de Valera", "President of the Executive Council of Ireland"), "ICE": ("Hermann Jónasson", "Prime Minister of Iceland"),
 "PER": ("Reza Shah Pahlavi", "Shah of Iran"), "IRQ": ("King Ghazi I", "King of Iraq"), "SAU": ("Ibn Saud (King Abdulaziz)", "King of Saudi Arabia"),
 "OMA": ("Said bin Taimur", "Sultan of Muscat and Oman"), "USA": ("Franklin D. Roosevelt", "President of the United States"),
 "CAN": ("William Lyon Mackenzie King", "Prime Minister of Canada"), "MEX": ("Lázaro Cárdenas", "President of Mexico"),
 "GUA": ("Jorge Ubico", "President of Guatemala, general"), "HON": ("Tiburcio Carías Andino", "President of Honduras"),
 "ELS": ("Maximiliano Hernández Martínez", "President of El Salvador, general"), "NIC": ("Juan Bautista Sacasa", "President of Nicaragua"),
 "COS": ("Ricardo Jiménez Oreamuno", "President of Costa Rica"), "PAN": ("Harmodio Arias Madrid", "President of Panama"),
 "CUB": ("Fulgencio Batista", "Army chief and strongman of Cuba"), "HAI": ("Sténio Vincent", "President of Haiti"),
 "DOM": ("Rafael Trujillo", "President of the Dominican Republic"), "COL": ("Alfonso López Pumarejo", "President of Colombia"),
 "VEN": ("Eleazar López Contreras", "President of Venezuela, general"), "ECU": ("Federico Páez", "Supreme Chief of Ecuador"),
 "PRU": ("Óscar R. Benavides", "President of Peru, general"), "BOL": ("José David Toro", "President of Bolivia, colonel"),
 "CHL": ("Arturo Alessandri", "President of Chile"), "ARG": ("Agustín P. Justo", "President of Argentina, general"),
 "URU": ("Gabriel Terra", "President of Uruguay"), "PAR": ("Rafael Franco", "President of Paraguay, colonel"),
 "BRA": ("Getúlio Vargas", "President of Brazil"), "JAP": ("Keisuke Okada", "Prime Minister of Japan, admiral"),
 "MAN": ("Puyi", "Emperor of Manchukuo"), "CHI": ("Chiang Kai-shek", "Generalissimo of the Republic of China"),
 "PRC": ("Mao Zedong", "Chairman of the Chinese Communist Party, 1936 Yan'an"), "SHX": ("Yan Xishan", "Warlord of Shanxi"),
 "GXC": ("Li Zongren", "Leader of the Guangxi clique, general"), "YUN": ("Long Yun", "Governor of Yunnan"),
 "XSM": ("Ma Bufang", "Warlord of Qinghai"), "SIK": ("Sheng Shicai", "Governor of Xinjiang"),
 "TIB": ("5th Reting Rinpoche", "Regent of Tibet, Buddhist lama"), "MON": ("Peljidiin Genden", "Prime Minister of Mongolia"),
 "TAN": ("Salchak Toka", "Leader of Tannu Tuva"), "SIA": ("Phraya Phahon", "Prime Minister of Siam, colonel"),
 "PHI": ("Manuel L. Quezon", "President of the Philippine Commonwealth"), "AST": ("Joseph Lyons", "Prime Minister of Australia"),
 "NZL": ("Michael Joseph Savage", "Prime Minister of New Zealand"), "SAF": ("J. B. M. Hertzog", "Prime Minister of South Africa"),
 "ETH": ("Haile Selassie", "Emperor of Ethiopia"), "LIB": ("Edwin Barclay", "President of Liberia"),
 "NEP": ("Juddha Shumsher Rana", "Prime Minister of Nepal"), "BHU": ("Jigme Wangchuck", "King of Bhutan"),
 "RAJ": ("Lord Linlithgow", "Viceroy of India"), "AFG": ("Mohammed Zahir Shah", "King of Afghanistan (young)"),
 "YEM": ("Imam Yahya Muhammad Hamid ed-Din", "King of Yemen"),
}
co = J("countries.json")["countries"]
for tag, c in co.items():
    who, role = EN.get(tag, (c["leader"], "leader of " + c["name"].get("en", tag)))
    row(tag, f"{who}", STYLE_PORTRAIT.format(who=who, role=role, year="1936"), "assets/portraits")
for fname, who, role, year in [("ismet_inonu", "İsmet İnönü", "President of Turkey ('National Chief')", "1939"),
                               ("fevzi_cakmak", "Marshal Fevzi Çakmak", "Chief of the General Staff of Turkey", "1939"),
                               ("celal_bayar", "Celâl Bayar", "Prime Minister of Turkey", "1938")]:
    row(fname, who, STYLE_PORTRAIT.format(who=who, role=role, year=year), "assets/portraits")

open("docs/art/ICON_PROMPTS.md", "w", encoding="utf-8").write(
    "# Iron Front — Yeni İkon Seti Prompt Listesi\n\n"
    "Bu dosya `tools/make_icon_prompts.py` ile üretilir (veri değişince yeniden çalıştır).\n" + "".join(out))
n = sum(1 for l in out if l.startswith("**`"))
print("docs/art/ICON_PROMPTS.md", n, "öğe")
