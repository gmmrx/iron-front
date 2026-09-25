#!/usr/bin/env python3
"""1936 hükümet kurulumu (tarihî 1936 başlangıcına göre): ideoloji, lider, iktidar partisi, seçimler, parti
popülerliği, başlangıç milli ruhları, yasalar, hedef istikrar/savaş desteği.

Hedef istikrar/savaş desteği oyundaki *etkin* değerdir (taban + ruhlar + iktidar partisi popülerlik bonusu);
betik tabanı buna göre geri hesaplar. Çalıştır: python3 tools/setup_1936_government.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
C = ROOT / "data/common"
countries_doc = json.load(open(C / "countries.json"))
countries = countries_doc.get("countries", countries_doc)
spirits_doc = json.load(open(C / "spirits.json"))
laws_doc = json.load(open(C / "laws.json"))

POP_BONUS = 0.15   # iktidar ideolojisinin popülerliği istikrara 0..+%15 (Politics.stability ile aynı)

# ------------------------------------------------------------------ ideoloji (1936)
IDEOLOGY = {
    "GER": "fascism", "ITA": "fascism", "JAP": "neutrality", "SOV": "communism", "FRA": "democratic", "ENG": "democratic",
    "USA": "democratic", "AFG": "neutrality", "ALB": "neutrality", "ARG": "neutrality", "AST": "democratic", "AUS": "neutrality",
    "BEL": "democratic", "BHU": "neutrality", "BOL": "democratic", "BRA": "democratic", "RAJ": "neutrality", "BUL": "neutrality",
    "CAN": "democratic", "CHL": "democratic", "CHI": "neutrality", "PRC": "communism", "COL": "democratic", "COS": "democratic",
    "CUB": "democratic", "CZE": "democratic", "DEN": "democratic", "DOM": "fascism", "ECU": "democratic", "ELS": "fascism",
    "EST": "neutrality", "ETH": "neutrality", "FIN": "neutrality", "GRE": "neutrality", "GXC": "neutrality", "GUA": "neutrality",
    "HAI": "democratic", "HON": "democratic", "HUN": "neutrality", "ICE": "democratic", "PER": "neutrality", "IRQ": "neutrality",
    "IRE": "democratic", "LAT": "neutrality", "LIB": "democratic", "LIT": "neutrality", "LUX": "democratic", "MAN": "fascism",
    "MEX": "neutrality", "MON": "communism", "OMA": "neutrality", "NEP": "neutrality", "HOL": "democratic", "NZL": "democratic",
    "NIC": "neutrality", "NOR": "democratic", "PAN": "democratic", "PAR": "democratic", "PRU": "fascism", "PHI": "democratic",
    "POL": "neutrality", "POR": "neutrality", "XSM": "neutrality", "ROM": "democratic", "SAU": "neutrality", "SHX": "neutrality",
    "SIA": "neutrality", "SIK": "communism", "SAF": "democratic", "SPR": "democratic", "SWE": "democratic", "SWI": "democratic",
    "TAN": "communism", "TIB": "neutrality", "TUR": "neutrality", "URU": "democratic", "VEN": "fascism", "YEM": "neutrality",
    "YUG": "neutrality", "YUN": "neutrality",
}

# ------------------------------------------------------------------ lider, parti, popülerlik, hedefler (wiki ülke sayfaları)
# pop: (demokrasi, komünizm, faşizm, bağlantısız) yüzde
GOV = {
    "TUR": dict(leader="Mustafa Kemal Atatürk", party=("Republican People's Party (CHP)", "Cumhuriyet Halk Partisi (CHP)"),
                pop=(6, 0, 0, 94), stab=0.50, ws=0.20),
    "GER": dict(leader="Adolf Hitler", party=("NSDAP", "NSDAP"), pop=(35, 10, 40, 15), stab=0.81, ws=0.35),
    "ENG": dict(leader="Stanley Baldwin", party=("Conservative Party", "Muhafazakâr Parti"), pop=(97, 1, 2, 0), stab=0.89, ws=0.15,
                elections=(48, "1939-11-01")),
    "FRA": dict(leader="Pierre Laval", party=("Radical Party", "Radikal Parti"), pop=(64, 20, 1, 15), stab=0.50, ws=0.10,
                elections=(48, "1936-05-03")),
    "ITA": dict(leader="Benito Mussolini", party=("National Fascist Party", "Ulusal Faşist Parti"), pop=(20, 2, 73, 5), stab=0.42, ws=0.55),
    "SOV": dict(leader="Iosif Stalin", party=("VKP(b)", "VKP(b)"), pop=(10, 88, 2, 0), stab=0.30, ws=0.40),
    "USA": dict(leader="Franklin D. Roosevelt", party=("Democratic Party", "Demokrat Parti"), pop=(99, 1, 0, 0), stab=0.90, ws=0.05,
                elections=(48, "1936-11-03")),
    "JAP": dict(leader="Keisuke Okada", party=("Kyokoku Itchi Naikaku", "Kyokoku Itchi Naikaku"), pop=(23, 2, 35, 40), stab=0.70, ws=0.20),
    "POL": dict(leader="Ignacy Mościcki", party=("Sanacja", "Sanacja"), pop=(18, 2, 15, 65), stab=0.45, ws=0.30),
    "CHI": dict(leader="Chiang Kai-shek", party=("Kuomintang", "Kuomintang"), pop=(20, 5, 10, 65), stab=0.35, ws=0.50),
    "SPR": dict(leader="Niceto Alcalá-Zamora", party=("PSOE", "PSOE"), pop=(41, 7, 37, 15), stab=0.20, ws=0.30,
                elections=(48, "1936-02-16")),
    "ROM": dict(leader="Gheorghe Tătărescu", party=("National Liberal Party", "Ulusal Liberal Parti"), pop=(60, 2, 18, 20), stab=0.50, ws=0.20,
                elections=(48, "1937-12-20")),
    "HUN": dict(leader="Miklós Horthy", party=("Party of National Unity", "Ulusal Birlik Partisi"), pop=(20, 2, 34, 44), stab=0.50, ws=0.08),
    "CZE": dict(leader="Milan Hodža", party=("Broad Coalition", "Geniş Koalisyon"), pop=(71, 12, 3, 14), stab=0.50, ws=0.30,
                elections=(60, "1940-05-01")),
    "YUG": dict(leader="Prince Paul", party=("Regency Council", "Naiplik Konseyi"), pop=(15, 15, 10, 60), stab=0.35, ws=0.20),
}
DEFAULT_POP = {"democratic": (70, 10, 10, 10), "communism": (5, 85, 5, 5), "fascism": (10, 5, 70, 15), "neutrality": (20, 10, 10, 60)}
DEM_ELECTIONS = 48    # varsayılan: demokrasiler 4 yılda bir, ilk seçim 1937-06

# ------------------------------------------------------------------ yeni başlangıç ruhları (etkiler bizim modifier dilimizde)
NEW_SPIRITS = {
    "kemalist_officers": ("Kemalist Officers", "Kemalist Subaylar", {"stability": 0.05}),
    "sectarian_woes": ("Sectarian Woes", "Mezhepsel Sıkıntılar", {"stability": -0.15, "war_support": -0.15}),
    "disorganized_armed_forces": ("Disorganized Armed Forces", "Dağınık Silahlı Kuvvetler", {"org": -0.08, "speed": -0.10, "war_support": -0.15}),
    "widespread_illiteracy": ("Widespread Illiteracy", "Yaygın Okuma Yazma Bilmezlik", {"political_power_gain": -0.05, "stability": -0.05, "research_speed": -0.05}),
    "first_five_year_plan": ("First Five-Year Industrial Plan", "Birinci Beş Yıllık Sanayi Planı", {"construction_speed": 0.05}),
    "trotskyite_plot": ("Trotskyite Plot?", "Troçkist Komplo?", {"political_power_gain": -0.15, "stability": -0.20}),
    "purged_army": ("Purged Officer Corps", "Tasfiye Edilmiş Subay Kadrosu", {"org": -0.10}),
    "king_george_v": ("King George V", "Kral V. George", {"stability": 0.15}),
    "war_to_end_all_wars": ("The War to End All Wars", "Bütün Savaşları Bitirecek Savaş", {"recruitable_population_factor": -0.30}),
    "disjointed_government": ("Disjointed Government", "Dağınık Hükümet", {"stability": -0.10, "political_power_flat": -0.8, "surrender_limit": -0.30}),
    "victors_of_ww1": ("Victors of the Great War", "Büyük Savaşın Galipleri", {"war_support": -0.05}),
    "inefficient_economy": ("Inefficient Economy", "Verimsiz Ekonomi", {"factory_output": -0.20}),
    "full_employment": ("Full Employment", "Tam İstihdam", {"recruitable_population_factor": -0.25}),
    "victor_emmanuel": ("Victor Emmanuel III", "III. Vittorio Emanuele", {"stability": 0.05}),
    "great_depression": ("The Great Depression", "Büyük Buhran", {"political_power_flat": -0.5, "consumer_goods_mod": 0.15, "recruitable_population_factor": -0.5}),
    "state_shintoism": ("State Shintoism", "Devlet Şintoizmi", {"war_support": 0.20, "surrender_limit": 0.10}),
    "chinese_corruption": ("Corruption in the Armed Forces", "Silahlı Kuvvetlerde Yolsuzluk", {"recruitable_population_factor": -0.40, "defense": -0.15, "consumer_goods_mod": 0.10}),
    "april_constitution": ("The April Constitution", "Nisan Anayasası", {"political_power_gain": -0.15}),
    "political_violence": ("Political Violence", "Siyasi Şiddet", {"stability": -0.15}),
    "national_strikes": ("National Strikes", "Genel Grevler", {"stability": -0.10, "factory_output": -0.10, "construction_speed": -0.10}),
    "carol_lifestyle": ("King Carol II's Lifestyle", "Kral II. Carol'ün Yaşam Tarzı", {"stability": -0.05}),
    "treaty_of_trianon": ("Treaty of Trianon", "Trianon Antlaşması", {"recruitable_population_factor": -0.30}),
    "levente": ("Levente Associations", "Levente Dernekleri", {"recruitable_population_factor": 0.10}),
    "divided_nation": ("Divided Nation", "Bölünmüş Ulus", {"stability": -0.20}),
    "croatian_opposition": ("Croatian Opposition", "Hırvat Muhalefeti", {"stability": -0.20}),
    "milli_sef": ("National Chief", "Millî Şef", {"stability": 0.05, "political_power_gain": 0.10}),
    "straits_sovereignty": ("Sovereignty over the Straits", "Boğazlarda Egemenlik", {"defense": 0.05, "stability": 0.03}),
}
START_ADD = {
    "TUR": ["kemalist_officers", "sectarian_woes", "disorganized_armed_forces", "widespread_illiteracy", "first_five_year_plan"],
    "SOV": ["trotskyite_plot"], "ENG": ["king_george_v", "war_to_end_all_wars"],
    "FRA": ["disjointed_government", "victors_of_ww1", "inefficient_economy", "full_employment"],
    "ITA": ["victor_emmanuel"], "USA": ["great_depression"], "JAP": ["state_shintoism"], "CHI": ["chinese_corruption"],
    "POL": ["april_constitution"], "SPR": ["political_violence", "national_strikes"], "ROM": ["carol_lifestyle"],
    "HUN": ["treaty_of_trianon", "levente"], "CZE": ["divided_nation"], "YUG": ["croatian_opposition"],
}
# Türkiye: başlangıçta Atatürk'ün reform ruhu yok; silahlı tarafsızlık odakla gelir
START_REMOVE = {"TUR": ["kemalist_reforms", "armed_neutrality"]}

# ------------------------------------------------------------------ başlangıç yasaları
LAWS = {
    "GER": ("limited_conscription", "partial_mobilization", "limited_exports"),
    "ENG": ("limited_conscription", "civilian_economy", "free_trade"),
    "FRA": ("limited_conscription", "civilian_economy", "free_trade"),
    "ITA": ("volunteer_only", "early_mobilization", "export_focus"),
    "SOV": ("limited_conscription", "civilian_economy", "closed_economy"),
    "USA": ("volunteer_only", "civilian_economy", "free_trade"),
    "JAP": ("limited_conscription", "partial_mobilization", "limited_exports"),
    "TUR": ("volunteer_only", "civilian_economy", "export_focus"),
    "POL": ("limited_conscription", "civilian_economy", "export_focus"),
    "CHI": ("limited_conscription", "civilian_economy", "export_focus"),
}


def mods_sum(spirit_ids, key):
    total = 0.0
    for sid in spirit_ids:
        total += float(spirits_doc["spirits"].get(sid, {}).get("mods", {}).get(key, 0.0))
    return total


for sid, (en, tr, mods) in NEW_SPIRITS.items():
    spirits_doc["spirits"][sid] = {"name": {"en": en, "tr": tr}, "mods": mods}

start = spirits_doc["start"]
for tag, add in START_ADD.items():
    lst = start.setdefault(tag, [])
    for s in add:
        if s not in lst:
            lst.append(s)
for tag, rem in START_REMOVE.items():
    start[tag] = [s for s in start.get(tag, []) if s not in rem]

pop = spirits_doc["popularity"]
for tag, c in countries.items():
    ideo = IDEOLOGY.get(tag, c["ideology"])
    c["ideology"] = ideo
    g = GOV.get(tag, {})
    if "leader" in g:
        c["leader"] = g["leader"]
    if "party" in g:
        c["party"] = {"en": g["party"][0], "tr": g["party"][1]}
    p = g.get("pop") or DEFAULT_POP[ideo]
    pd = {"democratic": p[0] / 100, "communism": p[1] / 100, "fascism": p[2] / 100, "neutrality": p[3] / 100}
    pop[tag] = pd
    if "elections" in g:
        c["elections"] = {"months": g["elections"][0], "next": g["elections"][1]}
    elif ideo == "democratic":
        c["elections"] = {"months": DEM_ELECTIONS, "next": "1937-06-01"}
    else:
        c.pop("elections", None)
    sp = start.get(tag, [])
    bonus = POP_BONUS * pd[ideo]
    if "stab" in g:
        c["stability"] = round(min(max(g["stab"] - mods_sum(sp, "stability") - bonus, 0.0), 1.0), 3)
    else:
        # hedef belirtilmemiş: önceki etkin değer (target_stability) korunur; popülerlik bonusu tabandan düşülür
        target = float(c.setdefault("target_stability", float(c["stability"])))
        c["stability"] = round(min(max(target - mods_sum(sp, "stability") - bonus, 0.05), 1.0), 3)
    if "ws" in g:
        c["war_support"] = round(min(max(g["ws"] - mods_sum(sp, "war_support"), 0.0), 1.0), 3)

for tag, (cs, ec, tr_) in LAWS.items():
    laws_doc["start"][tag] = {"conscription": cs, "economy": ec, "trade": tr_}

json.dump(countries_doc, open(C / "countries.json", "w"), ensure_ascii=False, indent=1)
json.dump(spirits_doc, open(C / "spirits.json", "w"), ensure_ascii=False, indent=1)
json.dump(laws_doc, open(C / "laws.json", "w"), ensure_ascii=False, indent=1)
print("countries:", len(countries), "spirits:", len(spirits_doc["spirits"]))
for t in ["TUR", "GER", "ENG", "FRA", "SOV", "USA"]:
    c = countries[t]
    print(t, c["ideology"], c["leader"], c.get("party", {}).get("tr"), "base stab", c["stability"], "base ws", c["war_support"], start.get(t), c.get("elections"))
