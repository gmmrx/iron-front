"""1936 dünyası: Avrupa penceresi dışındaki modern ülkelerin 1936 sahipliği, bölge istisnaları, nüfus ve başkentler.

generate_map.py bu tabloları kendi Avrupa tablolarıyla birleştirir. Kaynak: 1 Ocak 1936 siyasi durumu
(türün klasikleri başlangıcına yakın): sömürge imparatorlukları, dominyonlar ayrı ülke, Mançukuo, Çin savaş ağaları.
"""

# modern ülke kodu (Natural Earth adm0_a3) -> 1936 etiketi
ADM0_OWNER = {
    # Kuzey Amerika
    "USA": "USA", "PRI": "USA", "VIR": "USA", "GUM": "USA", "ASM": "USA", "UMI": "USA", "USG": "USA",
    "CAN": "CAN", "SPM": "FRA", "GRL": "DEN", "BMU": "ENG",
    "MEX": "MEX", "GTM": "GUA", "HND": "HON", "SLV": "ELS", "NIC": "NIC", "CRI": "COS", "PAN": "PAN",
    "BLZ": "ENG", "CUB": "CUB", "HTI": "HAI", "DOM": "DOM", "JAM": "ENG", "BHS": "ENG", "TCA": "ENG",
    "CYM": "ENG", "VGB": "ENG", "AIA": "ENG", "MSR": "ENG", "KNA": "ENG", "ATG": "ENG", "DMA": "ENG",
    "LCA": "ENG", "VCT": "ENG", "GRD": "ENG", "BRB": "ENG", "TTO": "ENG", "BLM": "FRA", "MAF": "FRA",
    "SXM": "HOL", "CUW": "HOL", "ABW": "HOL", "CLP": "FRA",
    # Güney Amerika
    "COL": "COL", "VEN": "VEN", "ECU": "ECU", "PER": "PRU", "BOL": "BOL", "CHL": "CHL", "ARG": "ARG",
    "URY": "URU", "PRY": "PAR", "BRA": "BRA", "GUY": "ENG", "SUR": "HOL", "FLK": "ENG", "SGS": "ENG",
    # Afrika
    "SEN": "FRA", "GIN": "FRA", "CIV": "FRA", "BFA": "FRA", "BEN": "FRA", "TGO": "FRA", "CMR": "FRA",
    "CAF": "FRA", "COG": "FRA", "GAB": "FRA", "MDG": "FRA", "DJI": "FRA", "COM": "FRA",
    "NGA": "ENG", "GHA": "ENG", "SLE": "ENG", "GMB": "ENG", "KEN": "ENG", "UGA": "ENG", "TZA": "ENG",
    "ZMB": "ENG", "MWI": "ENG", "ZWE": "ENG", "BWA": "ENG", "LSO": "ENG", "SWZ": "ENG", "SOL": "ENG",
    "SDS": "ENG", "MUS": "ENG", "SYC": "ENG", "SHN": "ENG",
    "ZAF": "SAF", "NAM": "SAF",
    "AGO": "POR", "MOZ": "POR", "GNB": "POR", "CPV": "POR", "STP": "POR",
    "COD": "BEL", "RWA": "BEL", "BDI": "BEL",
    "ERI": "ITA", "SOM": "ITA", "ETH": "ETH", "LBR": "LIB", "GNQ": "SPR",
    # Asya
    "JPN": "JAP", "KOR": "JAP", "PRK": "JAP", "TWN": "JAP", "MNP": "JAP", "PLW": "JAP", "FSM": "JAP", "MHL": "JAP",
    "CHN": "CHI", "HKG": "ENG", "MAC": "POR", "MNG": "MON",
    "PHL": "PHI", "VNM": "FRA", "LAO": "FRA", "KHM": "FRA", "THA": "SIA",
    "MMR": "RAJ", "BGD": "RAJ", "KAS": "RAJ", "LKA": "ENG", "MDV": "ENG", "IOT": "ENG",
    "NPL": "NEP", "BTN": "BHU",
    "MYS": "ENG", "SGP": "ENG", "BRN": "ENG", "IDN": "HOL", "TLS": "POR", "PGA": "FRA",
    # Okyanusya
    "AUS": "AST", "PNG": "AST", "NFK": "AST", "CSI": "AST", "ATC": "AST", "IOA": "AST", "HMD": "AST", "NRU": "AST",
    "NZL": "NZL", "COK": "NZL", "NIU": "NZL", "WSM": "NZL",
    "FJI": "ENG", "SLB": "ENG", "VUT": "ENG", "TON": "ENG", "TUV": "ENG", "KIR": "ENG", "PCN": "ENG",
    "NCL": "FRA", "PYF": "FRA", "WLF": "FRA", "ATF": "FRA",
}

# (modern ülke, bölge adı) -> 1936 etiketi
REGION_OWNER = {
    ("CHN", "Heilongjiang"): "MAN", ("CHN", "Jilin"): "MAN", ("CHN", "Liaoning"): "MAN",
    ("CHN", "Xinjiang"): "SIK", ("CHN", "Xizang"): "TIB",
    ("CHN", "Qinghai"): "XSM", ("CHN", "Ningxia"): "XSM", ("CHN", "Gansu"): "XSM",
    ("CHN", "Shanxi"): "SHX", ("CHN", "Guangxi"): "GXC", ("CHN", "Yunnan"): "YUN",
    ("CHN", "Shaanxi"): "PRC",
    ("RUS", "Tuva"): "TAN",
    ("YEM", "`Adan"): "ENG", ("YEM", "Lahij"): "ENG", ("YEM", "Abyan"): "ENG", ("YEM", "Shabwah"): "ENG",
    ("YEM", "Hadramawt"): "ENG", ("YEM", "Al Mahrah"): "ENG", ("YEM", "Al Dali'"): "ENG",
}

# 1936 nüfusu (milyon), modern ülke alanına göre (tüm ülke)
POP1936 = {
    "USA": 128.0, "PRI": 1.7, "VIR": 0.02, "GUM": 0.02, "ASM": 0.01, "UMI": 0.001, "USG": 0.001,
    "CAN": 11.0, "SPM": 0.004, "GRL": 0.02, "BMU": 0.03, "MEX": 18.5, "GTM": 2.1, "HND": 1.0, "SLV": 1.6,
    "NIC": 0.8, "CRI": 0.6, "PAN": 0.55, "BLZ": 0.06, "CUB": 4.2, "HTI": 2.8, "DOM": 1.5, "JAM": 1.1,
    "BHS": 0.07, "TCA": 0.005, "CYM": 0.006, "VGB": 0.006, "AIA": 0.005, "MSR": 0.012, "KNA": 0.04,
    "ATG": 0.03, "DMA": 0.05, "LCA": 0.06, "VCT": 0.05, "GRD": 0.08, "BRB": 0.19, "TTO": 0.45,
    "BLM": 0.002, "MAF": 0.005, "SXM": 0.003, "CUW": 0.08, "ABW": 0.03, "CLP": 0.0,
    "COL": 8.7, "VEN": 3.4, "ECU": 2.6, "PER": 6.8, "BOL": 3.0, "CHL": 4.6, "ARG": 12.8, "URY": 2.0,
    "PRY": 1.0, "BRA": 38.0, "GUY": 0.33, "SUR": 0.16, "FLK": 0.002, "SGS": 0.0,
    "SEN": 1.8, "GIN": 2.1, "CIV": 4.0, "BFA": 3.2, "BEN": 1.2, "TGO": 0.8, "CMR": 2.6, "CAF": 1.0,
    "COG": 0.6, "GAB": 0.4, "MDG": 3.8, "DJI": 0.05, "COM": 0.13, "NGA": 20.0, "GHA": 3.7, "SLE": 1.8,
    "GMB": 0.2, "KEN": 3.3, "UGA": 3.6, "TZA": 5.2, "ZMB": 1.4, "MWI": 1.7, "ZWE": 1.3, "BWA": 0.27,
    "LSO": 0.56, "SWZ": 0.16, "SOL": 0.35, "SDS": 1.5, "MUS": 0.4, "SYC": 0.03, "SHN": 0.004,
    "ZAF": 9.6, "NAM": 0.35, "AGO": 3.3, "MOZ": 4.5, "GNB": 0.4, "CPV": 0.17, "STP": 0.06,
    "COD": 10.5, "RWA": 1.8, "BDI": 1.8, "ERI": 0.6, "SOM": 1.0, "ETH": 10.0, "LBR": 1.5, "GNQ": 0.15,
    "JPN": 69.0, "KOR": 13.0, "PRK": 9.0, "TWN": 5.3, "MNP": 0.04, "PLW": 0.03, "FSM": 0.03, "MHL": 0.01,
    "CHN": 500.0, "HKG": 1.0, "MAC": 0.2, "MNG": 0.75, "PHL": 15.0, "VNM": 19.0, "LAO": 1.0, "KHM": 3.0,
    "THA": 14.0, "MMR": 15.0, "BGD": 42.0, "KAS": 0.0, "LKA": 5.8, "MDV": 0.08, "IOT": 0.001, "NPL": 6.0,
    "BTN": 0.3, "MYS": 4.5, "SGP": 0.6, "BRN": 0.03, "IDN": 67.0, "TLS": 0.45, "PGA": 0.0,
    "AUS": 6.8, "PNG": 1.2, "NFK": 0.001, "CSI": 0.0, "ATC": 0.0, "IOA": 0.002, "HMD": 0.0, "NRU": 0.003,
    "NZL": 1.6, "COK": 0.015, "NIU": 0.004, "WSM": 0.06, "FJI": 0.2, "SLB": 0.09, "VUT": 0.05, "TON": 0.03,
    "TUV": 0.004, "KIR": 0.03, "PCN": 0.0001, "NCL": 0.05, "PYF": 0.04, "WLF": 0.006, "ATF": 0.0,
    # Avrupa penceresinde kısmen görünen ülkelerin tam 1936 nüfusları (dünya haritasında tamamı var)
    "RUS": 105.0, "KAZ": 6.1, "UZB": 6.0, "TKM": 1.25, "KGZ": 1.45, "TJK": 1.5, "IND": 300.0, "PAK": 30.0,
    "AFG": 7.0, "YEM": 3.5, "OMN": 0.5, "SDN": 6.0, "MLI": 3.4, "NER": 2.0, "TCD": 1.4, "MRT": 0.4,
}

CAPITALS = {  # (boylam, enlem)
    "USA": (-77.04, 38.90), "CAN": (-75.70, 45.42), "MEX": (-99.13, 19.43), "GUA": (-90.51, 14.63),
    "HON": (-87.21, 14.07), "ELS": (-89.19, 13.69), "NIC": (-86.25, 12.13), "COS": (-84.09, 9.93),
    "PAN": (-79.52, 8.98), "CUB": (-82.37, 23.11), "HAI": (-72.34, 18.54), "DOM": (-69.93, 18.49),
    "COL": (-74.07, 4.71), "VEN": (-66.90, 10.49), "ECU": (-78.47, -0.18), "PRU": (-77.04, -12.05),
    "BOL": (-68.15, -16.50), "CHL": (-70.67, -33.45), "ARG": (-58.38, -34.60), "URU": (-56.16, -34.90),
    "PAR": (-57.58, -25.26), "BRA": (-43.17, -22.91), "JAP": (139.69, 35.69), "MAN": (125.32, 43.82),
    "CHI": (118.80, 32.06), "PRC": (109.49, 36.59), "SHX": (112.55, 37.87), "GXC": (108.37, 22.82),
    "YUN": (102.71, 25.04), "XSM": (101.78, 36.62), "SIK": (87.62, 43.83), "TIB": (91.13, 29.65),
    "MON": (106.92, 47.92), "TAN": (94.45, 51.72), "SIA": (100.50, 13.75), "PHI": (120.98, 14.60),
    "AST": (149.13, -35.28), "NZL": (174.78, -41.29), "SAF": (28.19, -25.75), "ETH": (38.74, 9.03),
    "LIB": (-10.80, 6.30), "NEP": (85.32, 27.72), "BHU": (89.64, 27.47), "RAJ": (77.21, 28.61),
    "AFG": (69.17, 34.53), "YEM": (44.21, 15.35),
}

# Yeni ülkeler: ad (en/tr), renk, ideoloji, lider, başkent şehri ipucu, istikrar, savaş desteği, bayrak
COUNTRIES = {
    "USA": [("United States", "Amerika Birleşik Devletleri"), "#3b5f9e", "democratic", "Franklin D. Roosevelt", "Washington", 0.8, 0.1,
            {"dir": "h", "colors": ["#b22234", "#f5f5f5"] * 6 + ["#b22234"], "emblem": {"type": "canton_stars", "bg": "#3c3b6e", "color": "#ffffff"}}],
    "CAN": [("Canada", "Kanada"), "#b2413f", "democratic", "W. L. Mackenzie King", "Ottawa", 0.8, 0.2,
            {"dir": "h", "colors": ["#c8102e"], "emblem": {"type": "canton_union"}}],
    "MEX": [("Mexico", "Meksika"), "#7c9c4a", "neutrality", "Lázaro Cárdenas", "Mexico City", 0.6, 0.2,
            {"dir": "v", "colors": ["#006847", "#f5f5f5", "#ce1126"]}],
    "GUA": [("Guatemala", "Guatemala"), "#6fa0c4", "neutrality", "Jorge Ubico", "Guatemala", 0.6, 0.1, {"dir": "v", "colors": ["#4997d0", "#f5f5f5", "#4997d0"]}],
    "HON": [("Honduras", "Honduras"), "#5486b8", "neutrality", "Tiburcio Carías Andino", "Tegucigalpa", 0.5, 0.1, {"dir": "h", "colors": ["#0073cf", "#f5f5f5", "#0073cf"]}],
    "ELS": [("El Salvador", "El Salvador"), "#4f6fb5", "neutrality", "Maximiliano H. Martínez", "San Salvador", 0.5, 0.1, {"dir": "h", "colors": ["#0f47af", "#f5f5f5", "#0f47af"]}],
    "NIC": [("Nicaragua", "Nikaragua"), "#6a8fcf", "neutrality", "Juan Bautista Sacasa", "Managua", 0.4, 0.1, {"dir": "h", "colors": ["#0067c6", "#f5f5f5", "#0067c6"]}],
    "COS": [("Costa Rica", "Kosta Rika"), "#8a6fbf", "democratic", "Ricardo Jiménez Oreamuno", "San José", 0.7, 0.05, {"dir": "h", "colors": ["#002b7f", "#f5f5f5", "#ce1126", "#ce1126", "#f5f5f5", "#002b7f"]}],
    "PAN": [("Panama", "Panama"), "#c46a6a", "democratic", "Harmodio Arias Madrid", "Panama City", 0.6, 0.05, {"dir": "v", "colors": ["#f5f5f5", "#da121a"]}],
    "CUB": [("Cuba", "Küba"), "#5c7fd0", "neutrality", "Fulgencio Batista", "Havana", 0.5, 0.1, {"dir": "h", "colors": ["#002a8f", "#f5f5f5", "#002a8f", "#f5f5f5", "#002a8f"], "emblem": {"type": "triangle", "color": "#cf142b"}}],
    "HAI": [("Haiti", "Haiti"), "#4f5fa8", "neutrality", "Sténio Vincent", "Port-au-Prince", 0.4, 0.05, {"dir": "h", "colors": ["#00209f", "#d21034"]}],
    "DOM": [("Dominican Republic", "Dominik Cumhuriyeti"), "#b04a5a", "neutrality", "Rafael Trujillo", "Santo Domingo", 0.5, 0.1, {"dir": "h", "colors": ["#002d62", "#ce1126"], "emblem": {"type": "swiss", "color": "#ffffff"}}],
    "COL": [("Colombia", "Kolombiya"), "#d6b945", "democratic", "Alfonso López Pumarejo", "Bogotá", 0.6, 0.1, {"dir": "h", "colors": ["#fcd116", "#fcd116", "#003893", "#ce1126"]}],
    "VEN": [("Venezuela", "Venezuela"), "#c9a64a", "neutrality", "Eleazar López Contreras", "Caracas", 0.5, 0.1, {"dir": "h", "colors": ["#ffcc00", "#00247d", "#cf142b"]}],
    "ECU": [("Ecuador", "Ekvador"), "#b8aa5a", "neutrality", "Federico Páez", "Quito", 0.4, 0.1, {"dir": "h", "colors": ["#ffd100", "#ffd100", "#0072ce", "#ef3340"]}],
    "PRU": [("Peru", "Peru"), "#c05050", "neutrality", "Óscar R. Benavides", "Lima", 0.5, 0.1, {"dir": "v", "colors": ["#d91023", "#f5f5f5", "#d91023"]}],
    "BOL": [("Bolivia", "Bolivya"), "#9aa04a", "neutrality", "José David Toro", "La Paz", 0.4, 0.2, {"dir": "h", "colors": ["#d52b1e", "#f9e300", "#007934"]}],
    "CHL": [("Chile", "Şili"), "#b85d5d", "democratic", "Arturo Alessandri", "Santiago", 0.6, 0.1, {"dir": "h", "colors": ["#f5f5f5", "#d52b1e"], "emblem": {"type": "canton_star", "color": "#ffffff", "bg": "#0039a6"}}],
    "ARG": [("Argentina", "Arjantin"), "#86b1d9", "neutrality", "Agustín P. Justo", "Buenos Aires", 0.6, 0.1, {"dir": "h", "colors": ["#74acdf", "#f5f5f5", "#74acdf"], "emblem": {"type": "center_disc", "color": "#f6b40e"}}],
    "URU": [("Uruguay", "Uruguay"), "#7fa8d8", "democratic", "Gabriel Terra", "Montevideo", 0.6, 0.05, {"dir": "h", "colors": ["#f5f5f5", "#0038a8"] * 4 + ["#f5f5f5"]}],
    "PAR": [("Paraguay", "Paraguay"), "#8c6fb0", "neutrality", "Rafael Franco", "Asunción", 0.4, 0.3, {"dir": "h", "colors": ["#d52b1e", "#f5f5f5", "#0038a8"]}],
    "BRA": [("Brazil", "Brezilya"), "#4c9a55", "neutrality", "Getúlio Vargas", "Rio de Janeiro", 0.6, 0.1, {"dir": "h", "colors": ["#009c3b"], "emblem": {"type": "center_disc", "color": "#002776"}}],
    "JAP": [("Japan", "Japonya"), "#d9d9c9", "neutrality", "Hirohito (Keisuke Okada)", "Tokyo", 0.7, 0.4, {"dir": "h", "colors": ["#f5f5f5"], "emblem": {"type": "center_disc", "color": "#bc002d"}}],
    "MAN": [("Manchukuo", "Mançukuo"), "#b0a060", "fascism", "Puyi", "Changchun", 0.4, 0.2, {"dir": "h", "colors": ["#fcd116"], "emblem": {"type": "canton_bars", "colors": ["#da251d", "#0000ff", "#f5f5f5", "#000000"]}}],
    "CHI": [("China", "Çin"), "#5d8a6a", "neutrality", "Chiang Kai-shek", "Nanjing", 0.4, 0.4, {"dir": "h", "colors": ["#fe0000"], "emblem": {"type": "canton_sun", "bg": "#000095", "color": "#ffffff"}}],
    "PRC": [("Communist China", "Komünist Çin"), "#c43b3b", "communism", "Mao Zedong", "Yan'an", 0.6, 0.6, {"dir": "h", "colors": ["#c8102e"], "emblem": {"type": "canton_star", "color": "#ffd700"}}],
    "SHX": [("Shanxi", "Şanşi"), "#9a7a5a", "neutrality", "Yan Xishan", "Taiyuan", 0.5, 0.3, {"dir": "h", "colors": ["#fe0000", "#fcd116", "#0000ff", "#f5f5f5", "#000000"]}],
    "GXC": [("Guangxi Clique", "Guangxi Klikası"), "#7a9a5a", "neutrality", "Li Zongren", "Nanning", 0.5, 0.3, {"dir": "h", "colors": ["#fe0000"], "emblem": {"type": "canton_sun", "bg": "#000095", "color": "#ffffff"}}],
    "YUN": [("Yunnan", "Yunnan"), "#a0885a", "neutrality", "Long Yun", "Kunming", 0.5, 0.2, {"dir": "h", "colors": ["#fe0000"], "emblem": {"type": "canton_sun", "bg": "#000095", "color": "#ffffff"}}],
    "XSM": [("Xibei San Ma", "Xibei San Ma"), "#7a6a9a", "neutrality", "Ma Bufang", "Xining", 0.5, 0.3, {"dir": "h", "colors": ["#fe0000"], "emblem": {"type": "canton_sun", "bg": "#000095", "color": "#ffffff"}}],
    "SIK": [("Sinkiang", "Sincan"), "#8aa0b5", "communism", "Sheng Shicai", "Ürümqi", 0.4, 0.2, {"dir": "h", "colors": ["#c8102e"], "emblem": {"type": "canton_star", "color": "#ffd700"}}],
    "TIB": [("Tibet", "Tibet"), "#c9a36b", "neutrality", "Reting Rinpoche", "Lhasa", 0.6, 0.1, {"dir": "h", "colors": ["#c8102e", "#0033a0", "#c8102e", "#0033a0"], "emblem": {"type": "center_disc", "color": "#fcd116"}}],
    "MON": [("Mongolia", "Moğolistan"), "#c07a5a", "communism", "Peljidiin Genden", "Ulaanbaatar", 0.5, 0.3, {"dir": "v", "colors": ["#c4272f", "#015197", "#c4272f"]}],
    "TAN": [("Tannu Tuva", "Tannu Tuva"), "#b58a6a", "communism", "Salchak Toka", "Kyzyl", 0.5, 0.2, {"dir": "h", "colors": ["#0033a0", "#f5f5f5", "#fcd116", "#f5f5f5", "#c8102e"]}],
    "SIA": [("Siam", "Siyam"), "#6a8ac4", "neutrality", "Phraya Phahon", "Bangkok", 0.6, 0.2, {"dir": "h", "colors": ["#a51931", "#f4f5f8", "#2d2a4a", "#2d2a4a", "#f4f5f8", "#a51931"]}],
    "PHI": [("Philippines", "Filipinler"), "#6f8fc7", "democratic", "Manuel L. Quezon", "Manila", 0.6, 0.1, {"dir": "h", "colors": ["#0038a8", "#ce1126"], "emblem": {"type": "triangle", "color": "#f5f5f5"}}],
    "AST": [("Australia", "Avustralya"), "#6aa0c8", "democratic", "Joseph Lyons", "Canberra", 0.8, 0.2, {"dir": "h", "colors": ["#012169"], "emblem": {"type": "canton_union", "stars": True}}],
    "NZL": [("New Zealand", "Yeni Zelanda"), "#5a8ab8", "democratic", "Michael Joseph Savage", "Wellington", 0.8, 0.2, {"dir": "h", "colors": ["#012169"], "emblem": {"type": "canton_union", "stars": True}}],
    "SAF": [("South Africa", "Güney Afrika"), "#c78a3a", "democratic", "J. B. M. Hertzog", "Pretoria", 0.7, 0.2, {"dir": "h", "colors": ["#ff8000", "#f5f5f5", "#002395"]}],
    "ETH": [("Ethiopia", "Etiyopya"), "#8ab05a", "neutrality", "Haile Selassie", "Addis Ababa", 0.4, 0.6, {"dir": "h", "colors": ["#078930", "#fcdd09", "#da121a"]}],
    "LIB": [("Liberia", "Liberya"), "#b86a6a", "neutrality", "Edwin Barclay", "Monrovia", 0.5, 0.05, {"dir": "h", "colors": ["#bf0a30", "#f5f5f5"] * 5 + ["#bf0a30"], "emblem": {"type": "canton_star", "bg": "#002868", "color": "#ffffff"}}],
    "NEP": [("Nepal", "Nepal"), "#c05a6a", "neutrality", "Juddha Shumsher", "Kathmandu", 0.6, 0.1, {"dir": "h", "colors": ["#dc143c"], "emblem": {"type": "center_disc", "color": "#003893"}}],
    "BHU": [("Bhutan", "Butan"), "#d4a04a", "neutrality", "Jigme Wangchuck", "Thimphu", 0.6, 0.05, {"dir": "h", "colors": ["#ffd520", "#ff4e12"]}],
    "RAJ": [("British Raj", "Britanya Hindistanı"), "#d98a6a", "democratic", "Lord Linlithgow", "New Delhi", 0.5, 0.1, {"dir": "h", "colors": ["#c8102e"], "emblem": {"type": "canton_union"}}],
    "AFG": [("Afghanistan", "Afganistan"), "#7a8a5a", "neutrality", "Mohammed Zahir Shah", "Kabul", 0.5, 0.2, {"dir": "v", "colors": ["#000000", "#d32011", "#007a36"]}],
    "YEM": [("Yemen", "Yemen"), "#a07a5a", "neutrality", "Yahya Muhammad Hamid ed-Din", "Sanaa", 0.5, 0.2, {"dir": "h", "colors": ["#ce1126"], "emblem": {"type": "center_disc", "color": "#f5f5f5"}}],
}

# Başlangıç tümen sayıları (varsayılanın üstüne yazılır)
START_DIVISIONS = {
    "USA": 12, "JAP": 40, "CHI": 60, "PRC": 12, "MAN": 14, "SHX": 12, "GXC": 14, "YUN": 10, "XSM": 10, "SIK": 8,
    "RAJ": 20, "AST": 6, "CAN": 6, "SAF": 5, "NZL": 3, "BRA": 12, "ARG": 10, "MEX": 10, "SIA": 8, "ETH": 12,
    "MON": 6, "TIB": 3, "PHI": 4, "CHL": 6, "PRU": 6, "COL": 5, "VEN": 4, "BOL": 5, "PAR": 5,
}

# Başlangıç donanmaları
START_FLEETS = {
    "USA": {"destroyer": 90, "cruiser": 30, "battleship": 15, "submarine": 60, "convoy": 400},
    "JAP": {"destroyer": 80, "cruiser": 35, "battleship": 10, "submarine": 50, "convoy": 250},
    "AST": {"destroyer": 5, "cruiser": 4, "convoy": 30}, "CAN": {"destroyer": 4, "convoy": 40},
    "ARG": {"destroyer": 12, "cruiser": 3, "battleship": 2, "submarine": 3, "convoy": 25},
    "BRA": {"destroyer": 8, "cruiser": 2, "battleship": 2, "submarine": 4, "convoy": 25},
    "CHL": {"destroyer": 8, "cruiser": 2, "battleship": 1, "submarine": 6, "convoy": 15},
    "CHI": {"destroyer": 4, "cruiser": 4, "convoy": 10}, "SIA": {"destroyer": 4, "submarine": 4, "convoy": 8},
}
FLEET_BASES = {"USA": ["Norfolk", "San Diego", "Honolulu"], "JAP": ["Yokosuka", "Kure", "Sasebo"]}
