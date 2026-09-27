# Zombi modu — 06 Teknoloji ve yetenek ağacı

> **Özet.** Bu belge *Gri Kordon* modunun iki ilerleme ağacını tanımlar: araştırma paneli (**I**) için **teknoloji ağacı** ve
> devlet programı ekranı (**F**) için **yetenek ağacı ("Kriz Doktrini")**. Kararlar 01–02'ye, bilim projeleri 05'e uyar.
> - **Teknoloji ağacı: 8 sekme, 70 teknoloji.** 27'si 05_arastirma_merkezleri.md'nin bilim çekirdeği (tıp, biyolojik üretim, gözetim,
>   sivil savunma), **23'ü bu belgenin yenisi** (silah, tahkimat, lojistik, tarım/gıda ve eklemeler), 20'si temel oyundan taşınır;
>   13 temel teknoloji modda silinir. Sekme sayısı temel oyunla aynı kalır (8).
> - **Yetenek ağacı: 1 kök + 6 dal, 51 düğüm.** Kök "Kabine Üslubu" (lider yeteneği, 3 seçenekten biri); dallar Kordon Devleti,
>   Halk Sağlığı Seferberliği, Surlar İçinde, Seyyar Kollar, Ortak Nöbet, Açık Kapı. Her dal 4 kademe ve 2 "birbirini dışlar" çifti içerir.
> - **Doktrin Puanı (DP):** başta 3; 120 günde 1, evre ilerleyişi, tıp kilometre taşları, arındırma, temiz ilan, dayanışma ve kordon
>   dayanıklılığıyla kazanılır. Tipik oyun **32–36 DP**, ağacın tamamı **66 DP** ister: her şey alınamaz, kurgu (build) zorunludur.
> - **Komutan yetenekleri** iki katmanlıdır: bugün mevcut "karargâh kapasitesi" ile ödenen **10 Karargâh Emri**; ROADMAP V3 generalleri
>   gelince 10 **komutan özelliği**. Ayrıca 8 yeni **kabine uzmanı** (danışman).
> - Motor değişikliği küçük ve içerikten bağımsızdır (8 madde, §2.2); her birinin değişiklik yapılmazsa yedek planı yazılıdır.
> - Üç örnek kurgu sayılarla verildi: Türkiye "Laboratuvar Yarışı", Birleşik Krallık "Ada Kordonu", Polonya "Ortak Nöbet".

---

## 1. Kapsam, ilkeler ve öteki belgelerle ilişki

### 1.1 Bu belge neyi kesinleştirir, neyi başka belgeden alır?

| Konu | Bu belge | Kaynak belge |
|---|---|---|
| Sekmeler (kategoriler), yerleşim, bütçe, yapay zekâ önceliği | **Kesinleştirir** | — |
| Tıp, biyolojik üretim, gözetim, sivil savunma projelerinin maliyet/etkileri (27 proje) | Aynen alır, yalnız ad önerir | 05_arastirma_merkezleri.md §3 |
| Silah, tahkimat, lojistik, tarım/gıda teknolojileri ve 4 ek proje | **Kesinleştirir** | — |
| Salgın parametreleri (β, κ, μ, d), önlem birleşimi, tarama düzeyleri | Kullanır | 02_oynanis_dongusu.md, 03_salgin_modeli.md |
| Tür/suş çarpanları, top sesi çekimi, Kösemen, gizli türler | Kullanır | 04_zombi_turleri.md |
| Numune, kaza olasılığı, bilim insanı tavanı, serum/aşı dağıtımı | Kullanır | 05_arastirma_merkezleri.md §5–§8 |
| Yetenek ağacı, doktrin puanı, karargâh emirleri, kabine uzmanları, komutan özellikleri | **Kesinleştirir** | — |

### 1.2 İlkeler

| İlke | Uygulama |
|---|---|
| Oyuncu karar verir (CLAUDE.md kural 1) | DP hiçbir zaman kendiliğinden harcanmaz, doktrin kendiliğinden benimsenmez, emir kendiliğinden verilmez. Yapay zekâ ülkeleri aynı kurallarla otomatik oynar |
| Veri güdümlü (kural 2) | Ağaçlar, puan kuralları, tavanlar, emirler JSON'dadır (§6). Motor "kordon" ya da "serum" sözcüğünü bilmez |
| Yeni sistem değil, yeniden kullanım | Teknoloji = `Research`; yetenek ağacı = devlet programı motoru (`focuses.json`, `focus_panel.gd`); kalıcı etki = ulusal durum (`spirits`); lider yeteneği = kabine ulusal durumu; komutan emri = karar (`decisions`) + mevcut **karargâh kapasitesi** (`Country.command_power`); uzman = danışman |
| Her seçimin bedeli var (01 Sütun 3) | Her kademe-2 ve kademe-4 düğümü bir çifttir; biri ötekini kapatır. Güçlü düğümlerin çoğu bir göstergeden (istikrar, nüfuz, fabrika) bir şey alır |
| Sayılar gerekçeli (docs/OZGUNLUK.md kural 4) | Her etki bir model parametresine (02–05) bağlanır; tarihî dayanak "Dayanak" sütunundadır |
| Ton (01 §6) | Düğüm ve emir adlarında "zombi" sözcüğü, kan, sivile şiddet, gerçek kişi yoktur. Lider yetenekleri **kişiye değil kabineye** bağlıdır (01 §6.5) |

### 1.3 Kimlik eşleme (belgeler arası)

02–04 bazı teknoloji kimliklerini "araştırma belgesinde kesinleşir" diye öneri olarak bırakmıştı. 05 ile bu belge onları kesinleştirir:

| Belge ve yer | Önerilen kimlik | Kesin kimlik | Kesinleştiren |
|---|---|---|---|
| 02 §3.2, §10 (`phases`) | `zm_serum` | `zm_hyperimmune_serum` | 05 §3.2 |
| 02 §4.1, §10 (`victory.cure`) | `zm_vaccine` | `tech_any: [zm_vaccine_live, zm_vaccine_killed]` | 05 §3.4 |
| 03 §8.3, §14 (tarama T1) | `zm_agent_identified` | `zm_agent_isolation` | 05 §3.2 |
| 03 §8.3, §14 (tarama T2) | `zm_incubation_test` | `zm_incubation_test` | **Bu belge** §3.6 |
| 04 T12, §12 (`counters`) | `zm_serum_typed` | `zm_type_specific_serum` | 05 §1.1 |
| 04 T10, §12 | `zm_gauze_masks` | `zm_gauze_masks` | 05 §3.2 |
| 04 §7.4 | `zm_strain_typing` | `zm_strain_typing` | 05 §3.2 |
| 04 T07, §12 (`countered_by_equipment`) | `zm_illumination` (ekipman) | ekipman `zm_illumination`; açan teknoloji `zm_searchlights` | **Bu belge** §3.4 |
| 04 T08 ("İstihkâm taraması") | — | emir `zmo_tunnel_sweep`; açan `zm_tunnel_sealing` | **Bu belge** §3.5, §4.8 |
| 03 §7 ("Köprüleri yık", n = 0,15) | — | emir `zmo_blow_bridges`; açan `zm_bridge_demolition` | **Bu belge** §3.5, §4.8 |
| 02 §9 ("Halk Sağlığı Seferberliği" dalı) | — | yetenek ağacı dal B | **Bu belge** §4.6 |
| 05 §5.2 ("Tıp Fakültesi Seferberliği" programı) | — | düğüm `zmd_medical_faculty` (B5) | **Bu belge** §4.6 |

**Etki anahtarlarının iki yolu.** 03 §7 olay etkileri için süreli anahtarlar önerdi (`transmission`, `suppression`, `detection`,
`report_delay`). 05 §12.4 teknoloji ve ulusal durum modifier'ları için `zm_` önekli anahtarları seçti (`zm_beta_mult`,
`zm_kappa_flat`, `zm_detection`, `zm_report_delay` …). Bu belge 05'in modifier adlarını kullanır. `rules.gd` iki yolu aynı çarpanda
toplar: kalıcı modifier toplamı 03 §7'deki `m = 1 − Π(1 − ö_k)` birleştirmesine **tek bir terim** olarak girer.

## 2. Motor: neyi yeniden kullanıyoruz, ne küçük eklenti istiyor?

### 2.1 Yeniden kullanılanlar (kod okundu)

| Parça | Bugün ne yapıyor | Bu modda ne olur |
|---|---|---|
| `Research` (`game/autoload/research.gd`) | `cat`, `year`, `cost`, `req`, `effects`, `unlock`; yıl başına +%150 erken araştırma cezası; biten teknolojinin `effects`'i `Country.tech_mods`'a eklenir | Aynen. Yıl satırları 1936–1939 kademelerini gösterir |
| `research_panel.gd` | Kategori sekmeleri + yıl şeridi + teknoloji kartı; panel genişliği 720 px | Aynen; 8 sekme sığar (16 sığmaz, §3.1) |
| Devlet programı motoru (`Politics.can_start_focus`) | `prereq` (hepsi), `any_prereq` (en az biri), `exclusive`, `available` (şart listesi), `days`, `effects`, `ai` | Yetenek ağacı. Mod şartları `Game.rules.check_condition` ile zaten çalışır |
| `focus_panel.gd` | x/y ızgarası (hücre 236 × 168, düğüm 212 × 140), önkoşul çizgisi, dışlama için kırmızı kesikli çizgi, dört durum rengi | Aynen (§4.11) |
| Ulusal durum (`spirits`) | `Country.mod()` içinde toplanır, kaydedilir, Hükümet panelinde listelenir | Her doktrin düğümünün kalıcı etkisi bir ulusal durumdur |
| Danışman (`advisors`) | 150 nüfuz, en çok 3, `mods` | 8 yeni kabine uzmanı (§4.9) |
| Karar (`decisions`) | Nüfuzla ödenen süreli `mods` | Karargâh emirleri (§4.8) |
| Karargâh kapasitesi (`Country.command_power`) | Barışta +0,3/gün, savaşta +0,5/gün, en çok 200; üst çubukta gösterilir, kayıtlı; ipucu metni "generaller, doktrinler ve özel emirler için harcanır" ama bugün **hiçbir şey harcamaz** | Karargâh emirlerinin para birimi |
| Kara birikimi (`Country.army_xp`) | Muharebeyle artar (en çok 2/gün, tavan 500); bugün harcanmaz | Sürüm 2'de komutan özellikleri (§4.10) |

### 2.2 Gereken küçük motor eklentileri (içerikten bağımsız)

WWII modu da kullanabilir: ROADMAP V3 "doktrinler … birikim ile açılır" ve "karargâh kapasitesi ile özellik alma" maddelerinin altyapısıdır.

| # | Eklenti | Yer | Yaklaşık iş | Değişiklik yapılmazsa (yedek plan) |
|---|---|---|---|---|
| M1 | Program düğümüne isteğe bağlı `points` alanı; `Country.doctrine_points` (kayda girer); `doctrine_points` etkisi (`apply_effects` + `describe_effects`); başlarken puan düşülür, iptalde iade edilir; düğüm metninde "2 DP · 21 gün"; manifestte isteğe bağlı `focus_title` | `politics.gd`, `country.gd`, `game.gd`, `focus_panel.gd` | ~30 satır + test | DP `rules.gd` durumunda tutulur; maliyet `available: [{"zm_dp_at_least": 2}]` şartı ve bitişte `{"doctrine_points": -2}` etkisiyle yazılır. Çalışır ama ipucu daha az açıktır |
| M2 | Karara isteğe bağlı `currency` (`"pp"` varsayılan, `"command_power"`) ve `available` | `politics.gd`, `politics_panel.gd` | ~12 satır | Emirler nüfuzla ödenir (karargâh kapasitesi boşa kalır) |
| M3 | Danışmana isteğe bağlı `available` | `politics.gd` | ~3 satır | Uzmanlar baştan açık |
| M4 | Kategoriye özgü hız: `c.mod("research_speed_" + cat)` | `research.gd` (`days_needed` ve günlük ilerleme) | ~4 satır | 05'in `research_bonus` (kullanımlık) mekanizması: düğüm `{"research_bonus": "zm_medicine", "value": 0.25, "uses": 2}` verir |
| M5 | Yapay zekânın araştırma sırası manifestten: `ai.research_priority` | `ai.gd` (`RESEARCH_PRIORITY` yerine `GameModes.sub`) | ~3 satır | Yeni kategoriler eşit ağırlıkta seçilir |
| M6 | Program düğümüne isteğe bağlı `ai_mult: [{"if": şart, "x": çarpan}]` | `ai.gd` (`_focus`) | ~8 satır | Bütün yapay zekâ ülkeleri aynı dalları seçer |
| M7 | Ulusal durumda isteğe bağlı `group`; `"doctrine"` grubu Hükümet panelinde tek satırda özetlenir (`PanelLayout.row`) | `politics_panel.gd` | ~10 satır | 20+ doktrin ulusal durumu listeyi doldurur |
| M8 | `ModeRules.describe_mod(key, v)` ve `describe_condition(key, v)` kancaları (boş dönerse varsayılan) | `politics.gd`, `mode_rules.gd` | ~10 satır | Gün ve sayı anahtarları yüzde gibi görünür ("−100%"); mod şartları ipucunda yazmaz |

Yeni görsel stil, gölgelendirici, ışık ya da renk değişikliği **yoktur** (CLAUDE.md kural 5).

## 3. Teknoloji ağacı

### 3.1 Sekmeler: 8 kategori

Araştırma paneli 720 px genişliğindedir; temel oyunun 8 sekmesi sekme başına ~90 px verir. 05 §3.1 temel sekiz kategorinin
kalmasını öngörmüştü; o zaman 8 + 4 + 4 = 16 sekme olurdu ve sekme başına ~45 px kalırdı (okunmaz). **Öneri:** temel teknolojiler
**korunur** (askerî dallar kordon ve arındırma için hâlâ gerekli), yalnız sekmeleri moda özgü kategorilere taşınır. Böylece sekme
sayısı 8'de kalır.

| Sıra | Kimlik | EN / TR | 05'ten | Yeni (06) | Temelden taşınan | Toplam |
|---|---|---|---|---|---|---|
| 1 | `zm_medicine` | Medicine / Tıp | 10 | — | — | 10 |
| 2 | `zm_biologics` | Biologics / Biyolojik Üretim | 3 | — | — | 3 |
| 3 | `zm_surveillance` | Surveillance & Signals / Gözetim ve Haberleşme (05'teki ad "Gözetim"; radyo taşındığı için genişletildi) | 7 | 3 | 2 | 12 |
| 4 | `zm_civil_defence` | Civil Defence / Sivil Savunma | 7 | 1 | — | 8 |
| 5 | `zm_arms` | Arms & Munitions / Silah ve Mühimmat | — | 5 | 9 | 14 |
| 6 | `zm_engineering` | Fortification & Engineering / Tahkimat ve Mühendislik | — | 6 | 1 | 7 |
| 7 | `zm_logistics` | Logistics & Industry / Lojistik ve Sanayi | — | 3 | 8 | 11 |
| 8 | `zm_food` | Agriculture & Food / Tarım ve Gıda | — | 5 | — | 5 |
| | | **Toplam** | **27** | **23** | **20** | **70** |

Sekme sırası = yapay zekânın öncelik sırası (M5) = oyuncunun ilk ay okuma sırası: önce anlamak ve tedavi, sonra kordon.

### 3.2 Yıl kapısı ve maliyet ölçeği

- `cost` = araştırma hızı 1'de gün (motorun ölçeği; temel teknolojiler 100–170). Bu belgenin yeni teknolojileri **50–120** gün arasıdır:
  temel oyunda bir teknoloji bir askerî sınıfın küçük bir iyileştirmesidir (100–170); buradakiler çoğunlukla bir **usul** ya da
  **teşkilat**tır (tel örgü, karakol, kurye hattı) ve dönemin mevcut malzemesiyle kurulur. Bu yüzden ölçeğin alt yarısı seçildi.
- `year` 1936–1938. 1937 teknolojisini 1936'da başlatan oyuncu 2,5 kat maliyet görür ama ilerlemesi silinmez (05 §3.3'teki aşı yolu
  mantığı). Kordon ve mühendislik teknolojilerinin çoğu **1936**'dır: salgın ilk yıl gelir, oyuncu cezasız tepki verebilmelidir.
- Oyun 1 Ocak 1940'ta biter; 1939 ve sonrası temel teknolojiler yalnız yıl cezasıyla alınabilir (bilinçli).

### 3.3 Bilim çekirdeği (05'ten, 27 proje)

Maliyet, önkoşul ve etki 05 §3.2'deki gibidir; burada yalnız **oyuncuya görünen ad önerisi** ve dönem dayanağı eklenir. 05 bir ad
verirse onunki geçerlidir.

| # | Kimlik | Kat. | Yıl | Cost | Ad önerisi (EN / TR) | Dönem dayanağı |
|---|---|---|---|---|---|---|
| 1 | `zm_case_definition` | gözetim | 1936 | 30 | Case Definition / Vaka Tanımı | Bildirimin ön koşulu: ne sayılacağını tanımlamak |
| 2 | `zm_notifiable_disease` | gözetim | 1936 | 60 | Compulsory Notification / Zorunlu Bildirim | İngiltere 1889 Bildirim Yasası: hekim ve aile bildirmezse ceza |
| 3 | `zm_radio_bulletin` | gözetim | 1936 | 80 | Wireless Bulletin / Telsiz Bülteni | 1925 Singapur bürosunun haftalık telsiz bülteni (01) |
| 4 | `zm_railway_health_posts` | gözetim | 1936 | 90 | Railway Health Posts / Demiryolu Sağlık Noktaları | 1911 Mançurya: yük vagonlarında gözlem, 5–10 gün |
| 5 | `zm_port_quarantine_station` | gözetim | 1936 | 110 | Port Quarantine Station / Liman Karantina İstasyonu | 1926 Uluslararası Sıhhiye Sözleşmesi (01) |
| 6 | `zm_contact_tracing` | gözetim | 1936 | 150 | Contact Tracing / Temaslı Takibi | Parran 1937: vaka bulma ve temaslı takibi ilkeleri |
| 7 | `zm_strain_typing` | gözetim | 1936 | 150 | Strain Typing / Suş Tipleme | 1930'larda pnömokok tiplemesi (Neufeld testi, 1933) |
| 8 | `zm_agent_isolation` | tıp | 1936 | 120 | Isolation of the Agent / Etkenin Yalıtılması (05) | 17D öncesi: sarı humma etkeni 1927 |
| 9 | `zm_serotherapy` | tıp | 1936 | 70 | Principles of Serotherapy / Serum Tedavisi İlkeleri | 1890'lar difteri antitoksini |
| 10 | `zm_hyperimmune_serum` | tıp | 1936 | 150 | Hyperimmune Serum / Hiperimmün Serum (05) | At bağışıklamasıyla serum üretimi |
| 11 | `zm_serum_standardisation` | tıp | 1936 | 130 | Serum Standardisation / Serum Standardı | 1939 pepsinle arıtılmış antitoksin; Milletler Cemiyeti biyolojik standartları (05) |
| 12 | `zm_type_specific_serum` | tıp | 1936 | 200 | Type-Specific Serum (Serum II) / Tipe Özgü Serum | 1920–30'larda tipe özgü pnömoni serumu (ölüm %22 → %13) |
| 13 | `zm_attenuation_passage` | tıp | 1937 | 260 | Attenuation by Serial Passage / Seri Pasajla Zayıflatma | 17D (04 T13) |
| 14 | `zm_attenuation_inactivated` | tıp | 1937 | 340 | Inactivated Agent / Öldürülmüş Etken | Ramon 1923 formol; Semple 1911 fenolle öldürülmüş kuduz aşısı |
| 15 | `zm_vaccine_live` | tıp | 1937 | 320 | Live Attenuated Vaccine / Canlı Zayıflatılmış Aşı (05) | 17D 1937 |
| 16 | `zm_vaccine_killed` | tıp | 1937 | 380 | Killed Vaccine / Öldürülmüş Aşı | Semple tipi aşılar |
| 17 | `zm_vaccine_potency` | tıp | 1936 | 160 | Potency Testing / Aşı Güç Denetimi | 1930 Lübeck kirli BCG partisi → parti denetimi (05 §7.4) |
| 18 | `zm_egg_culture` | biyo. | 1936 | 150 | Egg Culture / Kuluçka Yumurtasında Üretim | Woodruff ve Goodpasture 1931 |
| 19 | `zm_cold_chain` | biyo. | 1936 | 170 | Cold Chain / Soğuk Zincir | Canlı aşının soğukta taşınması |
| 20 | `zm_filling_line` | biyo. | 1936 | 140 | Filling Line / Dolum Hattı | Seri dolum ve ambalaj |
| 21 | `zm_gauze_masks` | siv. sav. | 1936 | 50 | Gauze Masks / Gazlı Bez Maske | 1911 Mançurya (Wu Lien-teh) |
| 22 | `zm_disinfection_protocol` | siv. sav. | 1936 | 80 | Disinfection Protocol / Dezenfeksiyon Usulü | Rus Polonyası'nda savaş yıllarının önleyici bit ayıklama istasyonları; 1920–23 Milletler Cemiyeti Salgın Komisyonu |
| 23 | `zm_isolation_wards` | siv. sav. | 1936 | 120 | Isolation Wards / Ayırma Koğuşları | Ateşli hasta ayırma hastaneleri |
| 24 | `zm_bite_wound_protocol` | siv. sav. | 1936 | 90 | Bite-Wound Protocol / Isırık Yarası Usulü | Kuduzda yara yıkama ve serum (04) |
| 25 | `zm_civil_guard_drill` | siv. sav. | 1936 | 110 | Civil Guard Drill / Sivil Muhafız Talimi | 1937 İngiliz hava saldırısı bekçileri |
| 26 | `zm_lab_discipline` | siv. sav. | 1936 | 100 | Laboratory Discipline / Laboratuvar Disiplini (05) | Pike derlemesi (05 §7.1) |
| 27 | `zm_evacuation_plans` | siv. sav. | 1936 | 130 | Evacuation Plans / Tahliye Planları | İngiltere'nin 1 Ocak 1938 yasası: her belediye bekçi, ambulans ve kurtarma ekiplerini kendisi örgütler |

Not: 05 §3.2'deki `zm_evacuation_plans` etkisi ("tahliye hızı +%50") bu belgenin `zm_evacuation_mult` anahtarıyla yazılır (§3.10).

### 3.4 Silah ve Mühimmat (`zm_arms`, 14)

| Kimlik | EN / TR | Yıl | Cost | Önkoşul | Etki | Gerekçe ve dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|---|---|
| `zm_gauntlets` | Gauntlets and Puttees / Eldiven ve Dolak | 1936 | 50 | — | `zm_inranks_mult −0,25` | 04 §3.4: ısırıkların kol payı 0,22, bacak payı 0,12 (Tanzanya verisi); deri eldiven ve dolak bu 0,34'ün ~3/4'ünü kapatır → ısırık kaynaklı bulaş ~−%25 | leather gauntlets and wound puttees on a wooden bench |
| `zm_searchlights` | Searchlights and Flares / Işıldak ve İşaret Fişeği | 1936 | 60 | `radio` | Ekipman `zm_illumination` açılır | 04 T07 Gecegezer'in karşılığı; ışıldak ve fişek siper savaşının gece aracıydı | a searchlight beam over a dark field and a falling flare |
| `zm_fire_discipline` | Short-Burst Fire Discipline / Kısa Atış Disiplini | 1936 | 70 | `artillery_1` | `zm_noise_mult −0,40`; `artillery_soft −0,05` | 04: topçulu muharebe 2 bölgedeki sürüleri günde 0,3 olasılıkla çeker → 0,18. Bedel: az atış, az hasar | a field gun crew with ear covers waiting beside a stopwatch |
| `zm_final_protective_fire` | Final Protective Fire / Son Savunma Ateşi | 1937 | 100 | `artillery_1`, `infantry_weapons_1` | `defense +0,08` | Önceden nişanlanmış savunma barajı. 04 §3.3: siperli tümen 3 sürüde %30 bütünlükle zor tutar; +%8 savunma bu payı büyütür (motor taklidiyle yeniden ölçülmeli, §10) | a map board with pre-registered target lines and a field telephone |
| `zm_marksman_teams` | Marksman Teams / Nişancı Takımları | 1937 | 90 | `infantry_weapons_1` | `zm_leader_damage +0,50` | 04 T04: Kösemen dağılınca bağlı birimler %50 bütünlük kaybeder; önderi hedeflemek en ucuz arındırmadır | a pair of binoculars and a rifle resting on a sandbag at dawn |
| 9 temel teknoloji | `infantry_weapons_1`, `infantry_weapons_2`, `support_weapons`, `artillery_1`, `light_tank_2`, `medium_tank_1`, `fighter_1`, `cas_1`, `bomber_1` | — | — | Değişmez | Değişmez | Kilit açan (`unlock`) teknolojiler silinirse ekipman herkese serbest kalır (`Research.is_unlocked`), bu yüzden taşınır | Mevcut ikonlar |

**`zm_illumination` ekipmanı:** 1 birim = bir tümenin ışıldak takımı (iki ışıldak, jeneratör, fişek tabancası). Maliyet **15 fabrika-saat**,
çelik 1. Gerekçe: destek ekipmanı 21 fabrika-saattir; ışıldak takımı ondan hafif ama motorlu jeneratör içerir → ~%70. Tümen başına
4 birim stokta varsa Gecegezer'in gece çarpanları o tümenin muharebesinde uygulanmaz (04 §12 `countered_by_equipment`); eksikse
oranla uygulanır.

### 3.5 Tahkimat ve Mühendislik (`zm_engineering`, 7)

| Kimlik | EN / TR | Yıl | Cost | Önkoşul | Etki | Gerekçe ve dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|---|---|
| `zm_wire_obstacles` | Barbed-Wire Obstacles / Dikenli Tel Engelleri | 1936 | 50 | — | `entrenchment +0,15`; `defense +0,03` | Silahsız kalabalığı tel durdurur, kesmez. 04 §3.1: siper savunmayı 10 günde %15 artırır; tel bu süreyi kısaltır | coils of barbed wire on wooden stakes across a muddy field |
| `zm_cordon_posts` | Cordon Watch-Posts / Kordon Gözetleme Karakolları | 1936 | 70 | `zm_wire_obstacles` | `zm_leak_mult −0,15` | Habsburg askerî sınırı: birbirini gören gözetleme kuleleri zinciri ve kontumaz istasyonları; yolcular 2–3 hafta tutulurdu | a wooden watchtower on stilts beside a striped barrier |
| `zm_bridge_demolition` | Bridge Demolition Teams / Köprü Yıkım Takımları | 1936 | 60 | — | Emir `zmo_blow_bridges` açılır | 03 §7: yıkılmış köprüde sürü yürüyüşü ×0,15 | a stone bridge with a demolition charge box on its pier |
| `zm_tunnel_sealing` | Tunnel Sealing and Flooding / Tünel Kapatma ve Su Basma | 1937 | 90 | `zm_bridge_demolition` | Emir `zmo_tunnel_sweep` açılır | 04 T08 Dehlizci kanalizasyon, maden ve metroyu kullanır; karşılığı istihkâm taraması (altyapı −1 bedelli) | a brick sewer mouth being bricked up, a water hose beside it |
| `zm_urban_clearance` | Urban Clearance Method / Kent Arındırma Usulü | 1937 | 100 | `zm_wire_obstacles` | `zm_urban_attack +0,10` | 04 §2.4: kentte saldırana −0,3, Boşlara 0. Usul cezayı −0,2'ye indirir; 04 §3.3'teki 14 saatlik kent arındırması ~12 saate iner | a street map with blocks crossed out in pencil and a whistle |
| `zm_blockhouse_chain` | Blockhouse Chain / Karakol Zinciri | 1938 | 120 | `zm_cordon_posts` | `zm_garrison_kappa_mult +0,20`; `zm_leak_mult −0,10` | Habsburg kordonu Lika'dan Karpatlar'a kesintisiz karakol zinciriydi; garnizonun etkisi alan taramasıyla artar (03 §3.2) | a line of small log blockhouses along a ridge in snow |
| `construction_1` (temel) | Prefabricated Structures / Prefabrik Yapılar | 1936 | 110 | — | Değişmez | Hastane ve karakol inşasını hızlandırır | Mevcut |

### 3.6 Lojistik ve Sanayi (`zm_logistics`, 11) ve Gözetim eklemeleri (`zm_surveillance`, +5)

| Kimlik | Kat. | EN / TR | Yıl | Cost | Önkoşul | Etki | Gerekçe ve dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|---|---|---|
| `zm_medical_couriers` | lojistik | Medical Couriers / Tıbbi Kurye Hattı | 1936 | 70 | — | `zm_sample_days −2` | 05 §6.3: taşıma 300 km başına 1 gün (en çok 12). Buzlu vagon ve öncelikli kurye 2 gün kazandırır; numune 10 günde bozulur | a padlocked courier satchel on a railway mail cart with ice blocks |
| `zm_hospital_trains` | lojistik | Hospital Trains / Hastane Trenleri | 1936 | 70 | — | `zm_evacuation_mult +0,25`; `zm_distribution_mult +0,10` | Birinci Dünya Savaşı'nda İngiliz demiryolları 1918'e kadar 51 hastane treni yaptı; tren başına ~500 hasta | a hospital train carriage with stretchers and a white-painted roof, no emblem |
| `zm_field_quarantine_stations` | lojistik | Field Quarantine Stations / Sahra Karantina İstasyonları | 1937 | 80 | — | `zm_inranks_mult −0,15` | Cepheden dönen birliklerin gözlemden geçirilmesi; Birinci Dünya Savaşı'nda Rus Polonyası'nda kurulan önleyici bit ayıklama istasyonları kordonu (1920'de dağıldı) | a row of canvas tents behind a rope line with a disinfection boiler |
| 8 temel teknoloji | lojistik | `motorization`, `industry_1`, `industry_2`, `synthetic_oil`, `destroyer_1`, `cruiser_1`, `submarine_1`, `battleship_1` | — | — | — | Değişmez | Sentetik kauçuk serum/aşı dozunun kauçuk ihtiyacı yüzünden önemlidir (05 §8.1) | Mevcut |
| `zm_incubation_test` | gözetim | Incubation Blood Test / Kuluçka Kan Testi | 1937 | 100 | `zm_agent_isolation`, `zm_strain_typing` | Tarama T2 (E 0,5, F 0,95; 03 §8.3); `zm_detection +0,05` | Dönemin serolojisi (komplement bağlama, aglütinasyon) belirti vermemiş taşıyıcının bir kısmını yakalayabilirdi; 0,5 duyarlılık kurgusal ama ılımlıdır | a rack of small test tubes with a faint cloudy band in half of them |
| `zm_epidemic_mapping` | gözetim | Epidemic Mapping / Salgın Haritacılığı | 1936 | 70 | `zm_case_definition` | `zm_detection +0,03`; Salgın panelinde "model tahmini" sütunu | Kermack–McKendrick 1927 ve Reed–Frost 1928 modelleri dönemin bilgisidir. Sütun, bildirilen ile beklenen artışı karşılaştırır; 04 §7.4'teki "beklenmeyen hız" uyarısının kaynağı olur | a wall map with pins and thread, a slide rule on the desk |
| `zm_aerial_survey` | gözetim | Aerial Survey / Hava Keşif Fotoğrafçılığı | 1937 | 80 | `radio` | `zm_reveal_radius +1` | 04: Durgun ve Gecegezer gizlidir; hava fotoğrafı kalabalığı sayar. Yeraltındaki Dehlizci'yi göstermez | a large aerial camera beside a stack of photographic plates |
| 2 temel teknoloji | gözetim | `radio`, `computing_1` | — | — | — | Değişmez | Radyo bülten ve sinyal; tablolayıcı hız verir | Mevcut |

### 3.7 Sivil Savunma eklemesi (`zm_civil_defence`, +1)

| Kimlik | EN / TR | Yıl | Cost | Önkoşul | Etki | Gerekçe ve dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|---|---|
| `zm_door_to_door` | Door-to-Door Vaccination / Kapı Kapı Aşılama | 1937 | 70 | `zm_civil_guard_drill` | `zm_distribution_mult +0,20` | 05 §8.3 dağıtım formülüne çarpan; **%1,5 tavanı değişmez**. 1938'de Brezilya'da 17D ile 1,06 milyon kişi aşılandı; 1947 New York'ta 6,35 milyon kişi ~4 haftada (02) | a nurse's bag and a vial case on a doorstep, a numbered door |

### 3.8 Tarım ve Gıda (`zm_food`, 5)

Gıda **ayrı bir kaynak değildir** (yeni sistem yok). Etkiler istikrar, iç cephe, tüketim malı, insan gücü ve Boş ömrü üzerinden gelir.
Gerekçe: salgında gıdanın oyuna etkisi zaten bu kanallardan geçer (açlık → huzursuzluk, tarım işçisi → asker), ayrı bir stok ve
ticaret katmanı yalnız yük getirirdi.

| Kimlik | EN / TR | Yıl | Cost | Önkoşul | Etki | Gerekçe ve dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|---|---|
| `zm_ration_cards` | Ration Cards / Karne Düzeni | 1936 | 60 | — | `stability +0,02`; `consumer_goods_mod −0,03` | Kıtlıkta adil pay istikrarı korur; tüketim malına giden sivil fabrika payı düşer | a stack of printed ration coupons tied with string, blank fields |
| `zm_grain_reserves` | State Grain Reserves / Devlet Tahıl Stokları | 1936 | 70 | `zm_ration_cards` | `stability +0,03`; `war_support +0,02` | Toprak Mahsulleri Ofisi (1938): hububat stok ve fiyat politikası | a grain silo with sacks stacked at its base |
| `zm_food_denial` | Granary and Well Denial / Ambar ve Kuyu Boşaltma | 1937 | 80 | `zm_ration_cards` | `zm_hollow_life_mult −0,15` (kendi ve düşmüş komşu eyaletlerde); `stability −0,02` | 01 §5: Boş ömrü su ve besine bağlı (yalnız suyla 45–61 gün). Ambarı boşaltmak ve kuyuyu kapatmak ömrü kısaltır; zehirleme yoktur (ton) | an empty granary with open doors and a capped stone well |
| `zm_fortified_farms` | Fortified Farm Villages / Korunaklı Çiftlik Köyleri | 1937 | 90 | `zm_grain_reserves` | `zm_civil_kappa_mult +0,10`; `stability +0,01` | Kırda nüfus dağınıktır; toplu köy savunması sivil bastırmayı artırır (03 §3.2: κ_sivil · d · L/T) | a farm courtyard with a closed gate and a watch bell |
| `zm_farm_mechanisation` | Farm Mechanisation / Tarım Makineleşmesi | 1938 | 110 | `zm_grain_reserves`, `motorization` | `recruitable_population_factor +0,05` | ABD'de 1930'da 920 bin traktör vardı; tarım 1939'da 1930'dakinden ~500 bin daha az kişi çalıştırıyordu. Açılan iş gücü orduya ve fabrikaya gider | a small tractor pulling a plough past a horse team |

### 3.9 Temel oyundan silinenler (13)

`technologies.patch.json`'da `null` ile silinir. Hiçbiri ekipman kilidi açmaz (koddan ve verilerden tarandı: başka bir dosya bu
kimliklere başvurmuyor), bu yüzden silinmeleri hiçbir birimi serbest bırakmaz.

| Silinen | Neden |
|---|---|
| `doctrine_1`–`doctrine_4` | Kara doktrinleri yetenek ağacına (§4) geçti; aynı işi iki yerde yapmamak |
| `infantry_weapons_3`, `artillery_3`, `medium_tank_2`, `fighter_2`, `industry_3` | Yıl 1940–1942; oyun 1940'ta bitiyor, 2,5–5 kat yıl cezasıyla ölü satır |
| `artillery_2`, `construction_2`, `radar_1`, `anti_tank_1` | 70 teknoloji sınırı. Tanksavar Boşlara karşı işe yaramaz (Boş sertliği 0; 04 §3.2); radar hava/deniz gücü verir, salgın sorusuna yanıt değildir |

### 3.10 Yeni modifier anahtarları ve tavanlar

Anahtarlar `effects`/`mods` içinde toplanır (`Country.mod`). `rules.gd` okur, tavanı uygular ve 03–05'teki formüllere yerleştirir.
"Göreli" = `taban × (1 + toplam)`. Tavan, doktrin + teknoloji + danışman + emir **toplamına** uygulanır.

| Anahtar | Anlamı | Tür | Taban (nerede) | Tavan | MOD_ metni (EN / TR) |
|---|---|---|---|---|---|
| `zm_detection` | Tespit oranı | mutlak | 03 §8.1 | 0,95 (03) | Detection / Tespit |
| `zm_report_delay` | Bildirim gecikmesi | gün | 03 §8.1 | en az 3 gün (03) | Reporting delay (days) / Bildirim gecikmesi (gün) |
| `zm_beta_mult` | Kalıcı bulaş azaltması | pay | 03 §7 | toplam `m ≤ 0,75` (03) | Transmission / Bulaş |
| `zm_kappa_flat` | Bastırma gücü (κ) eki | mutlak | 03 §3.5 | +0,05 | Suppression / Bastırma |
| `zm_inranks_mult` | Ordu içi bulaş | göreli | 04 §3.4 (0,35) | −0,60 | In-ranks infection / Ordu içi bulaş |
| `zm_accident_mult`, `zm_release_mult`, `zm_distribution_mult`, `zm_sample_days` | 05 §12.4'teki anlamlarıyla | 05 | 05 | 05 (dağıtım tavanı %1,5) | 05 |
| `zm_civil_kappa_mult` | Sivil bastırma (κ_sivil) | göreli | 03 (0,08; sivil savunma yasası ×1,5) | +1,00 | Civil suppression / Sivil bastırma |
| `zm_garrison_kappa_mult` | Garnizon bastırması (κ_asker) | göreli | 03 §3.2 (0,10/tümen) | +0,75; 03'ün 0,6 tavanı ayrıca geçerli | Garrison suppression / Garnizon bastırması |
| `zm_leak_mult` | Kordon, sınır ve bildirilmiş eyalet çıkışındaki kaçak akış | göreli | 02 §2.4, 03 §7 | −0,60 ("kordonlar hep sızdırdı") | Cordon leakage / Kordon kaçağı |
| `zm_quarantine_cost_mult` | Liman karantinası ve kapalı sınırın ticaret/konvoy bedeli | göreli | 02 §9, 05 #5 | −0,60 … +0,50 | Quarantine trade cost / Karantinanın ticaret bedeli |
| `zm_noise_mult` | Top sesi çekimi | göreli | 04 (0,3/gün) | −0,80 | Gunfire attraction / Top sesi çekimi |
| `zm_urban_attack` | Kentte saldırı çarpanına ek | mutlak | temel −0,3 (04 §2.4) | +0,25 (ceza −0,05'e kadar) | Urban assault / Kent taarruzu |
| `zm_leader_damage` | Kösemen'e verilen hasar | göreli | 04 T04 | +1,50 | Damage to leaders / Önderlere hasar |
| `zm_reveal_radius` | Gizli sürülerin görünür olduğu bölge yarıçapı | bölge | 04 (komşu bölge) | +3 | Reveal radius / Görüş yarıçapı |
| `zm_hollow_life_mult` | Boş ömrü (kendi ve düşmüş komşu eyaletlerde) | göreli | 02/03 (60 gün) | −0,30 | Hollow lifespan / Boş ömrü |
| `zm_evacuation_mult` | Tahliye hızı | göreli | 05 #27 ve mülteci modeli (03 §5.5) | +1,50 | Evacuation rate / Tahliye hızı |
| `zm_bridges_blown`, `zm_tunnels_sealed` | Emir bayrakları (0/1) | bayrak | 03 §7, 04 T08 | — | Bridges blown / Köprüler yıkık · Tunnels sealed / Tüneller kapalı |
| `research_speed_<kategori>` | Kategoriye özgü araştırma hızı (M4) | göreli | 1 + `research_speed` | **+0,10** (doktrin + danışman) | Research speed: %s / Araştırma hızı: %s |

**Neden +0,10 kategori tavanı?** 05 §3.4'te tıp yolunun en erken aşı günü 521'dir (G3 numunesi + yıl cezası + birikim). Aşı
yolunun darboğazı 1937 yıl kapısıdır: zayıflatma en erken 366. günde biter, canlı aşı (320) ondan sonra başlar. §5.1'deki hızla
(genel hız 1,32) hesap: tavan +0,20 olsaydı canlı aşı **G2 ile ~516, G3 ile ~492**; +0,10'da **G2 ile ~529, G3 ile ~504** olur.
Böylece 02'nin "en erken 540" hedefinden sapma tipik numuneyle %2'de kalır; uç kurgu yalnız bedelli G3 yoluyla birkaç hafta daha
kazanır. Tarihî yorum: bir noktadan sonra bilim para değil zaman ister (sarı hummada etken 1927, aşı 1937).

### 3.11 Bütçe ve yuva rekabeti

| Kalem | Araştırma günü |
|---|---|
| 05 bilim çekirdeği (27) | 3.880 |
| Bu belgenin yenileri (23) | 1.810 (silah 370, tahkimat 490, lojistik 220, gözetim 250, sivil savunma 70, gıda 410) |
| Taşınan temel teknolojiler (20) | 2.470 (başlangıç teknolojisi alan ülkede 2.050) |
| **Toplam** | **8.160** (aşı yolunun iki kolundan yalnız biri gerekir: ~7.440) |

05 §3.2'nin üretim hesabıyla: iki yuva ve 1,15 hız ≈ 3.360 gün → ağacın **%41–45'i**; üç yuva ve 1,30 hız ≈ 5.700 gün →
**%70–77'si**. Tasarım sonucu: küçük ülke bilim ile kordon arasında seçer; büyük güç ikisini de yapar ama gıda ve sanayiden vazgeçer.
Yetenek ağacının B7 düğümü (+1 yuva) ve 05'in BKP yuvaları bu dengeyi kasıtlı olarak kaydırır.

### 3.12 Yapay zekânın araştırma sırası (M5)

Manifest: `"ai": {"research_priority": ["zm_medicine", "zm_surveillance", "zm_biologics", "zm_civil_defence", "zm_engineering",
"zm_arms", "zm_logistics", "zm_food"]}`. Motorun mevcut puanı `gün × (1 + sıra × 0,12)` aynen kalır; yani yapay zekâ ucuz kordon
teknolojisini pahalı bir tıp projesine yine tercih edebilir, ama eşitlikte tıbbı seçer. Denge hedefi (02 §8 kontrol 6–7) değişmez.

## 4. Yetenek ağacı: Kriz Doktrini

### 4.1 Neden devlet programı motoru?

Kullanıcının istediği "yetenek ağacı"nın bütün parçaları motorda zaten var: dal ve kademe (x/y ızgarası), önkoşul (`prereq`,
`any_prereq`), birbirini dışlayan seçim (`exclusive` ve kırmızı kesikli çizgi), şartlı açılma (`available`), kalıcı etki (ulusal
durum), yapay zekâ ağırlığı (`ai`). Eksik olan tek şey **puan**dı; M1 onu ekler. Ekran (F) aynen kullanılır; başlığı manifestten
"Kriz Doktrini / Crisis Doctrine" olur. Mod WWII'nin ülkeye özgü program ağaçlarını yüklemez (01 §3a); bütün ülkeler `_generic`
ağacını, yani Kriz Doktrini'ni kullanır.

### 4.2 Üç katman

| Katman | Kimin yeteneği | Nasıl ödenir | Nerede | Kaç tane |
|---|---|---|---|---|
| **Kabine Üslubu** (kök) | Liderin — kişiye değil **kabineye** bağlı (01 §6.5) | 0 DP, 7 gün; üçten biri | F ekranı, en üst satır | 3 |
| **Doktrin dalları** | Devletin | DP + benimseme süresi | F ekranı | 6 dal × 8 düğüm |
| **Karargâh emirleri** | Komutanlığın | Karargâh kapasitesi (mevcut) | Hükümet paneli, Kararlar bölümü | 10 |
| **Kabine uzmanları** | Kabinenin | 150 nüfuz (mevcut danışman kuralı) | Hükümet paneli, Danışmanlar | 8 yeni |
| **Komutan özellikleri** (sürüm 2) | Generallerin | Kara birikimi | ROADMAP V3 Genelkurmay ekranı | 10 |

### 4.3 Doktrin Puanı (DP): kazanma yolları

Puan kaynakları beş tasarım sütununun her birini ödüllendirir; böylece hangi oyun tarzını seçerse seçsin oyuncu puan kazanır, ama
"bütün sütunlarda iyi" oynayan en çok kazanır.

| Kaynak | DP | Sınır | Sütun | Kural (kötüye kullanım önlemi) |
|---|---|---|---|---|
| Başlangıç | 3 | — | — | Kök + iki kademe-1 düğümü ya da bir kademe-2 düğümü ilk günden alınabilsin |
| Kabine değerlendirmesi (her 120 günde) | 1 | 12 | — | Pasif taban: hiçbir şey başaramayan da ilerler |
| Dünya evresi ilerledi (Alarm, Yayılma, Çöküş, Karşı Saldırı, Sonuç) | 1 | 5 | Sütun 2 | İkinci Dalga'dan (02 §3.2) sonra aynı evreye yeniden giriş sayılmaz |
| Tıp kilometre taşı (kendi araştırman): `zm_agent_isolation`, `zm_hyperimmune_serum`, aşı (`tech_any`) | 2 | 6 | Sütun 4 | Paylaşımla hızlanmış olsa da sayılır; araştırmayı sen bitirmelisin |
| Anavatan eyaleti arındırıldı (DÜŞMÜŞ → İZLEMEDE) | 1 | 6 | Sütun 1 | Eyalet en az 30 gün düşmüş kalmış olmalı (bırak-al döngüsü kapanır) |
| Anavatan eyaleti temiz ilan edildi (42 gün) | 1 | 6 | Sütun 2 | Eyalette en az 100 bildirilen vaka olmuş olmalı |
| Dayanışma eylemi (bulgu paylaşımı, tıbbi heyet, ortak enstitü, doz yardımı — 05 §9; mülteci olayında kabul) | 1 | 5 | Sütun 5 | 60 günde en çok 1 |
| Kordon dayanıklılığı: bir kordon ordusu 90 gün yarılmadan tuttu ve en az 1 sürü muharebesi kazandı | 1 | 3 | Sütun 1 | Aynı ordu bir kez |

**Beklenen birikim** (Salgın zorluğu; evre günleri 02 §3.2, tıp günleri 05 §3.4 "tipik"):

| Gün | Pasif oyuncu (yalnız başlangıç + dönemsel + evre) | Tipik oyuncu | İyi oyuncu | Harcanabilecek (bkz. §4.4) |
|---|---|---|---|---|
| 90 | 4 | 4–5 | 6 | Kök + dal başlangıcı |
| 180 | 6 | 8–9 | 11 | Bir dalın kapanışına (8 DP) yakın |
| 365 | 9 | 14–16 | 19 | Bir tam dal (11) + birkaç temel |
| 730 | 13 | 21–24 | 29 | İki tam dal |
| 1.461 | 20 | **32–36** | 42–48 | Üç tam dal ya da iki dal + dağınık seçim |

Ağacın tamamı (kök hariç) 6 × 11 = **66 DP** ister; iyi bir oyuncu bile ancak ~%70'ine ulaşır. 1. yılın sonunda tipik oyuncu tek bir
dalı bitirebilir: **ilk yılın doktrini, oyunun kimliğidir.**

### 4.4 Kademeler

| Kademe | EN / TR | DP | Benimseme | Açılma şartı | Dal başına | Neden |
|---|---|---|---|---|---|---|
| T0 | Cabinet / Kabine | 0 | 7 gün | — | 3 kök (biri) | İlk hafta yön seçimi; bedava ama kalıcı |
| T1 | Foundation / Temel | 1 | 14 gün | — | 2 (ikisi de alınabilir) | İki cuma bülteni: ilk ayda tepki verilebilsin |
| T2 | Direction / Yön | 2 | 21 gün | T1'den biri (`any_prereq`) | 2, **birbirini dışlar** | Dalın karakteri burada seçilir |
| T3 | Expertise / Uzmanlık | 2 | 28 gün | T2'den biri; evre ≥ Alarm | 2 (ikisi de alınabilir) | Salgın tanınmadan uzmanlaşma yok (Sütun 2) |
| T4 | Doctrine / Doktrin | 3 | 42 gün | T3'ten biri; evre ≥ Yayılma | 2, **birbirini dışlar** | 42 gün = temiz ilan süresi; kapanış bir yatırım olsun |

- Bir dalın en kısa kapanış yolu: T1 + T2 + T3 + T4 = **8 DP, 105 gün**. Dalın tamamı: 6 düğüm, **11 DP, 147 gün**.
- Motor bir anda tek programa izin verir; bu korunur: benimseme süresince DP birikir, oyuncu sırayı planlar.
- Süreler temel oyunun 6–12 haftalık programlarından kısadır, çünkü asıl kapı puandır; süre yalnız "aynı anda her şey" kestirmesini kapatır.

### 4.5 Kök: Kabine Üslubu (lider yetenekleri)

| Kimlik | EN / TR | Etki (ulusal durum `group: cabinet`) | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|
| `zmd_cabinet_experts` | Cabinet of Experts / Uzmanlar Kabinesi | `research_speed +0,05`; `zm_detection +0,03`; `political_power_gain −0,10` | Teknokrat bakanlar bilgiyi hızlandırır, siyasi sermayeleri azdır | a round cabinet table with a microscope, ledgers and a telephone |
| `zmd_cabinet_emergency` | Emergency Cabinet / Olağanüstü Hal Kabinesi | `political_power_gain +0,15`; `zm_kappa_flat +0,01`; `stability −0,05` | Kararname hızlıdır; zor önlem güveni aşındırır (1830–31 kolera ayaklanmaları, 01 Sütun 3) | a desk with a stamped decree, a pen and a heavy seal |
| `zmd_cabinet_accord` | National Accord Cabinet / Ulusal Uzlaşma Kabinesi | `stability +0,05`; `war_support +0,05`; `political_power_gain −0,05` | Geniş tabanlı hükümet: uyum yüksek, karar yavaş (01 §6.5) | many hands resting on one long table around a shared inkwell |

02 §4.2'deki İç Çöküş olayının "Ulusal birlik hükümeti" seçeneği kökü `zmd_cabinet_accord`'a çevirir (eski kök ulusal durumu kalkar).
Bu, kökün oyun içinde değişebildiği tek yoldur (§9 açık soru 3).

### 4.6 Dallar (6 × 8 düğüm)

Tablolarda **K** = kademe; "⟂" = birbirini dışlar. Her düğümün etkisi, düğümle aynı kimlikte bir ulusal durumdur (`group: doctrine`);
"(etki)" yazanlar bir kerelik program etkisidir. Önkoşullar §4.4'teki kalıptadır ve tabloda tekrar edilmez.

#### A — Kordon Devleti / The Cordon State (Sütun 3: her önlemin bedeli)

| Kimlik | EN / TR | K | Etki | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|
| `zmd_sanitary_gates` | Sanitary Gates / Sıhhiye Kapıları | T1 | `zm_leak_mult −0,10`; `zm_quarantine_cost_mult −0,20` | Habsburg kontumazları geçişi kesmeden süzdü | a striped barrier pole beside a small whitewashed inspection hut |
| `zmd_quarantine_inspectorate` | Quarantine Inspectorate / Karantina Müfettişliği | T1 | `zm_detection +0,03`; uzman "Karantina Başmüfettişi" açılır | 1926 Sözleşmesi liman ve sınır sağlık denetimi (01) | an inspector's peaked cap on a ledger beside a magnifying glass |
| `zmd_closed_frontier` | Closed-Frontier Principle / Kapalı Sınır İlkesi | T2 ⟂ | `zm_leak_mult −0,25`; `zm_quarantine_cost_mult +0,25`; `stability −0,02` | Kapalı sınır geciktirir, ticareti keser (03 §7) | a wooden border gate chained shut, an empty road beyond |
| `zmd_filtered_passage` | Filtered Passage / Süzgeçli Geçiş | T2 ⟂ | `zm_leak_mult −0,10`; `zm_quarantine_cost_mult −0,30`; `zm_detection +0,03` | 1911 Mançurya: 5–10 gün gözlem, ardından mühürlü bilezikle salıverme | a railway freight car fitted as an observation ward |
| `zmd_quarantine_statute` | State Quarantine Statute / Eyalet Karantina Tüzüğü | T3 | `zm_beta_mult −0,04`; `stability +0,02` | Kural yazılı ve cezalı olunca uyum artar (1889 bildirim yasası) | a bound statute book with a ribbon marker and a stamp |
| `zmd_cordon_gendarmerie` | Cordon Gendarmerie / Kordon Jandarması | T3 | `zm_garrison_kappa_mult +0,20` | Askerî sınırda kordonu asker tuttu; κ_asker (03 §3.2) | a mounted gendarme silhouette beside a wooden watchtower |
| `zmd_iron_cordon` | The Iron Cordon / Demir Kordon | T4 ⟂ | `zm_leak_mult −0,30`; `zm_kappa_flat +0,02`; `stability −0,05`; `political_power_gain −0,10` | Sert kordonun bedeli güvendir: 1830–31 ve 1892 kolera ayaklanmaları | a long line of iron posts and wire across a snowy plain |
| `zmd_consent_quarantine` | Quarantine by Consent / Rızaya Dayalı Karantina | T4 ⟂ | `zm_beta_mult −0,06`; `zm_leak_mult −0,10`; `stability +0,03` | 1918: erken ve katmanlı önlem alan ABD şehirlerinde tepe ölüm oranı ~%50 düşüktü (Hatchett ve ark. 2007) | a family closing its own front door, a notice pinned beside it |

#### B — Halk Sağlığı Seferberliği / Public Health Mobilisation (Sütun 4: bilim zamanla yarışır)

| Kimlik | EN / TR | K | Etki | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|
| `zmd_hygiene_institute` | National Hygiene Institute / Ulusal Hıfzıssıhha Enstitüsü | T1 | `research_speed_zm_medicine +0,05`; `zm_scientists +1` (etki) | Merkez Hıfzıssıhha Enstitüsü (1928) 1932'de serum ithalatını durdurdu; Statens Serum Institut (1902) difteri serumu için kuruldu | a stone institute facade with tall windows, a flask on the steps |
| `zmd_hospital_mobilisation` | Hospital Mobilisation / Hastane Seferberliği | T1 | `zm_distribution_mult +0,15`; `factory_output −0,02` | Hastane dağıtım kapasitesinin girdisidir (05 §8.3) | iron hospital beds being unloaded from a lorry |
| `zmd_sampling_expeditions` | Sampling Expeditions / Numune Seferleri | T2 ⟂ | `zm_sample_days −2`; `zm_accident_mult +0,25` | Numune askerî iştir (05 §6); hız riskle gelir | a padlocked sample case carried by gloved hands through mud |
| `zmd_sealed_laboratory` | Sealed-Laboratory Discipline / Kapalı Laboratuvar Düzeni | T2 ⟂ | `zm_accident_mult −0,30`; `research_speed_zm_medicine −0,03` | Laboratuvar enfeksiyonlarının çoğu bilinen bir kazaya bağlanamaz → günlük disiplin (05 §7.1) | a laboratory door with a double lock and a logbook |
| `zmd_medical_faculty` | Medical Faculty Mobilisation / Tıp Fakültesi Seferberliği | T3 | `zm_scientists +3` (etki); `stability −0,01` | 05 §5.2: kadro darlığı modun asıl kısıtıdır | students in white coats leaving a lecture hall for a train |
| `zmd_science_board` | Science Board Authority / Bilim Kurulu Yetkisi | T3 | `research_speed +0,05`; `political_power_gain −0,05` | Bilime bütçe önceliği | a council table with one large microscope at its centre |
| `zmd_serum_race` | The Serum Race / Serum Yarışı | T4 ⟂ | `research_slot +1` (etki); `research_speed_zm_medicine +0,05`; `factory_output −0,03` | Bilimi hızlandıran yuva ve bütçedir; kategori tavanı +0,10 (§3.10) | a rack of glass ampoules before a ticking wall clock |
| `zmd_physician_to_the_people` | Physician to the People / Halkın Hekimi | T4 ⟂ | `zm_distribution_mult +0,25`; `zm_release_mult +0,15`; `stability +0,02` | 1938 Brezilya'daki 1,06 milyon aşılama, üretimin değil örgütlenmenin ölçeğidir (05 §8.1) | a country doctor's bag open on a kitchen table |

#### C — Surlar İçinde / Within the Walls (şehri asker ve serum korur, 02 §2.3)

| Kimlik | EN / TR | K | Etki | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|
| `zmd_street_barricades` | Street Barricades / Sokak Barikatları | T1 | `zm_civil_kappa_mult +0,10` | Sivil bastırma yoğunlukla ölçeklenir (03 §3.2: κ · d · L/T); en çok kentte işe yarar | a barricade of carts and furniture across a cobbled street |
| `zmd_urban_garrison_manual` | Urban Garrison Manual / Kent Garnizon Talimnamesi | T1 | `zm_urban_attack +0,05`; `zm_garrison_kappa_mult +0,10` | 04 §2.4: kentte saldırana −0,3 | a field manual open on a map of city blocks |
| `zmd_gated_quarters` | Gated Quarters / Kapılı Mahalleler | T2 ⟂ | `zm_beta_mult −0,04`; `construction_speed −0,05` | Karantinanın mekânı: Ragusa 1377, Venedik lazaretleri (01) | a street gate with iron doors and lanterns at night |
| `zmd_open_city_evacuation` | Open-City Evacuation / Açık Şehir Tahliyesi | T2 ⟂ | `zm_evacuation_mult +0,40`; `stability −0,02` | Büyük şehir (d = 3) önlemsiz 65. günde düşer (02 §2.3): boşaltmak gerçek bir seçenektir | a crowded platform with suitcases, faces turned away |
| `zmd_underground_sweeps` | Underground Sweeps / Yeraltı Taramaları | T3 | `zm_urban_attack +0,10`; `zm_reveal_radius +1` (yalnız kentli eyaletlerde) | 04 T03 Durgun ve T08 Dehlizci gizlidir | a sewer entrance lit by a hand lamp, a chalk mark on brick |
| `zmd_city_depots` | City Ration Depots / Şehir Erzak Depoları | T3 | `stability +0,03`; `war_support +0,03` | Kuşatılmış kentin dayanma iradesi erzakla ölçülür | stacked sacks and crates in a vaulted warehouse |
| `zmd_city_states` | City-States / Kent Devletleri | T4 ⟂ | `surrender_limit +0,10`; `zm_garrison_kappa_mult +0,25`; `political_power_gain −0,05` | Çöküş, zafer puanlı şehirlerle ölçülür (02 §4.2): teslim sınırı %80 → %90 (motor tavanı %95) | a walled hill town with lit windows amid dark fields |
| `zmd_islands_of_people` | Islands of People / İnsan Adaları | T4 ⟂ | `zm_evacuation_mult +0,50`; `zm_hollow_life_mult −0,10`; `factory_output −0,05` | Boşaltılan kırda av yoktur; Boş ömrü kısalır (01 §5) | a few lit towns like islands in a dark countryside, from above |

#### D — Seyyar Kollar / Flying Columns (Sütun 1: salgın bir cephedir)

| Kimlik | EN / TR | K | Etki | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|
| `zmd_motor_columns` | Motor Columns / Motorlu Kollar | T1 | `infantry_speed +0,08`; `breakthrough +0,03` | Seğirtken günde 36 km yürür (04 T02); kovalamak hız ister | a column of canvas-covered lorries on a dusty road |
| `zmd_cavalry_screens` | Cavalry Screens / Süvari Perdesi | T1 | `zm_reveal_radius +1`; `org +0,03` | 1930'ların ordularında süvari keşfi hâlâ yaygındı; gizli türler (04) | two horsemen with binoculars on a hill at dawn |
| `zmd_fire_and_movement` | Fire and Movement / Ateş ve Hareket | T2 ⟂ | `artillery_soft +0,10`; `zm_noise_mult +0,25` | Topçu çok öldürür, ama sürüleri çeker (04 T01) | a field gun firing, smoke drifting over a field |
| `zmd_silent_approach` | Silent Approach / Sessiz Yaklaşma | T2 ⟂ | `zm_noise_mult −0,40`; `artillery_soft −0,05` | Top sesi çekimi 0,3/gün (04) | infantry moving quietly through tall grass, rifles slung |
| `zmd_air_ground` | Air–Ground Cooperation / Hava–Kara İşbirliği | T3 | `air_power +0,10` | Yakın hava desteği sürüye karşı (01 §3e) | a biplane dropping a message canister to waving troops |
| `zmd_field_screening` | Field Screening Teams / Sahra Tarama Takımları | T3 | `zm_inranks_mult −0,15`; `zm_detection +0,02` | 1914'ten itibaren cephe gerisinde seyyar bakteriyoloji laboratuvarları (Rowland) | a motor laboratory van with a folding bench beside a tent |
| `zmd_sweep_doctrine` | Sweep Doctrine / Tarama Doktrini | T4 ⟂ | `breakthrough +0,10`; `zm_urban_attack +0,10`; `org −0,05` | Karşı Saldırı evresinin aracı; Süreğen suşa karşı "beklemek işe yaramaz" (04 T14) | a line of soldiers advancing at arm's length across a field |
| `zmd_strike_the_leader` | Strike the Leader / Önderi Vur | T4 ⟂ | `zm_leader_damage +0,75`; `zm_reveal_radius +1` | 04 T04: Kösemen dağılınca bağlı birimler %50 bütünlük kaybeder | a small brass shepherd's bell lying on a trampled field |

#### E — Ortak Nöbet / Common Watch (topluluğun direnişi)

| Kimlik | EN / TR | K | Etki | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|
| `zmd_street_watch` | Street Watch / Sokak Nöbeti | T1 | `zm_civil_kappa_mult +0,10`; `zm_detection +0,02` | İngiliz hava saldırısı bekçileri (Nisan 1937): 1938 ortasında ~200 bin, Eylül'de 700 binden çok gönüllü | a warden's armband and a hand whistle on a doorstep |
| `zmd_health_posters` | Public Health Posters / Halk Sağlığı Afişleri | T1 | `zm_beta_mult −0,03`; `stability +0,01` | 1918'de katmanlı önlemin bir parçası bilgilendirmeydi (Hatchett 2007) | a paste bucket and a blank poster on a brick wall |
| `zmd_local_guard` | Local Guard Companies / Yerel Muhafız Bölükleri | T2 ⟂ | `zm_civil_kappa_mult +0,25`; `stability −0,03` | Silah dağıtmanın bedeli (01 Sütun 3; 03 §7 sivil savunma yasası ×1,5) | old rifles in a village hall rack under a lantern |
| `zmd_unarmed_defence` | Unarmed Civil Defence / Silahsız Sivil Savunma | T2 ⟂ | `zm_civil_kappa_mult +0,10`; `zm_evacuation_mult +0,20`; `stability +0,02` | Örgütlü sivil: sedye, tahliye, ilk yardım (ARP modeli) | a folded stretcher, a helmet and a hand bell by a doorway |
| `zmd_door_survey` | Door-to-Door Survey / Kapı Kapı Tarama | T3 | `zm_detection +0,05`; `zm_report_delay −1` | Parran 1937: vaka bulma | a clipboard and pencil on a doorstep beside a numbered door |
| `zmd_volunteer_vaccinators` | Volunteer Vaccinators / Gönüllü Aşıcılar | T3 | `zm_distribution_mult +0,15` | 1947 New York aşılaması (02 §4.1) | a school-hall table with vials and a queue, faces turned away |
| `zmd_every_house_a_post` | Every House a Post / Her Ev Bir Karakol | T4 ⟂ | `zm_civil_kappa_mult +0,35`; `war_support +0,05`; `factory_output −0,03` | Topluluğun silahlı nöbeti; iş gücü nöbete gider | a lit window with half-closed shutters and a lantern on the sill |
| `zmd_mutual_aid` | Mutual-Aid Network / Yardımlaşma Ağı | T4 ⟂ | `stability +0,05`; `zm_beta_mult −0,03`; `zm_distribution_mult +0,10` | Evde bakım ağı hastayı sağlamdan ayırır | a basket of bread and a medicine bottle passed between doorways |

#### F — Açık Kapı / Open Door (Sütun 5: kimse tek başına kurtulamaz)

| Kimlik | EN / TR | K | Etki | Dayanak | İkon konusu (EN) |
|---|---|---|---|---|---|
| `zmd_intelligence_sharing` | Epidemic Intelligence Sharing / Salgın Bilgisi Paylaşımı | T1 | `zm_report_delay −1`; `political_power_gain +0,03` | 1925 Singapur bürosunun haftalık telsiz bülteni | a wireless set with headphones and telegram forms |
| `zmd_medical_missions` | Medical Mission Corps / Tıbbi Heyet Teşkilatı | T1 | `zm_scientists +1` (etki); `zm_sample_days −1` | Tıbbi heyet G2 numune getirir (05 §9) | travellers with medical bags boarding a steamer, seen from behind |
| `zmd_reception_camps` | Reception Camps / Kabul Kampları | T2 ⟂ | `recruitable_population_factor +0,03`; `stability −0,02` | Mülteci iş gücü kazandırır; ama kamp Kızgın suşun tetiğidir (04 §7.2) | rows of canvas tents behind a simple fence, a registration table |
| `zmd_aid_at_border` | Aid at the Border / Sınırda Yardım | T2 ⟂ | `stability +0,02`; `political_power_gain −0,05` | Kabul etmeden yardım: bulaş riski düşük, bedel siyasi | supply crates handed across a border barrier |
| `zmd_research_exchange` | Research Exchange / Araştırma Mübadelesi | T3 | `research_speed_zm_medicine +0,05` | 05 §9 paylaşım; Milletler Cemiyeti biyolojik standartları | two scientists exchanging a sealed envelope over a bench |
| `zmd_dose_diplomacy` | Dose Diplomacy / Doz Diplomasisi | T3 | `political_power_gain +0,08`; `zm_release_mult +0,10` | 05 §9 aşı diplomasisi yardım puanı getirir | a crate of vials with a shipping tag on a gangway |
| `zmd_joint_cordon_pact` | Joint Cordon Pact / Ortak Kordon Paktı | T4 ⟂ | `zm_leak_mult −0,15`; `zm_garrison_kappa_mult +0,10` | 1911 ortak demiryolu karantinası; 1920–23 Milletler Cemiyeti Salgın Komisyonu (Polonya kordonu) | two different border posts sharing one barrier across a railway |
| `zmd_guardian_state` | Guardian State / Koruyucu Devlet | T4 ⟂ | `surrender_limit +0,05`; `stability +0,03`; `political_power_gain +0,05` | Çöken komşuyu korumak (01 Sütun 5, "koruma altına alma") | an open gate with a lantern on a dark road |

### 4.7 Birbirini dışlayan seçimlerin özeti

| Dal | T2 sorusu | T4 sorusu |
|---|---|---|
| A Kordon Devleti | Sınırı kapat mı, süz mü? (sızıntı ↔ ticaret) | Zorla mı, rızayla mı? (kaçak ↔ istikrar) |
| B Halk Sağlığı | Hızlı numune mi, güvenli laboratuvar mı? (hız ↔ kaza) | Bulmak mı, ulaştırmak mı? (yuva ↔ dağıtım) |
| C Surlar İçinde | Şehri kapat mı, boşalt mı? (bulaş ↔ tahliye) | Şehri tut mu, kırı aç mı? (çöküş sınırı ↔ Boş ömrü) |
| D Seyyar Kollar | Topla mı, sessizce mi? (hasar ↔ çekim) | Toplu tarama mı, önder avı mı? (arındırma ↔ Kösemen) |
| E Ortak Nöbet | Silahlı mı, silahsız mı? (bastırma ↔ istikrar) | Nöbet mi, bakım mı? (bastırma ↔ bulaş/istikrar) |
| F Açık Kapı | Kamp mı, sınırda yardım mı? (iş gücü ↔ Kızgın suş) | Ortak kordon mu, koruyucu devlet mi? (kaçak ↔ çöküş sınırı) |

Kök (3'ten biri) + 12 dışlama çifti → farklı tam kurgu sayısı 3 × 2¹² = **12.288**; puan bütçesiyle gerçekte oynanan kurgu 2–3 dal seçimidir.

### 4.8 Karargâh emirleri (komutan yetenekleri, M2)

Para birimi mevcut **karargâh kapasitesi**dir (üst çubukta). Temel tahakkuk barışta +0,3/gün; mod kuralı ülkenin en az bir eyaleti
SALGIN durumundayken **+0,2/gün** ekler ("kriz karargâhı"), tavan 200 aynı kalır. Böylece salgındaki bir ülke ~0,5/gün, yılda ~180
kazanır. Emir bedeli 20–50 = 40–100 günlük birikim → tipik olarak **iki ayda bir emir**; tavan 200 en çok ~5 emrin stoklanmasına izin verir.
Emirler ülke geneline uygulanır (sürüm 1). Aynı emir süresi bitmeden yeniden verilemez (mevcut karar kuralı).

| Kimlik | EN / TR | Bedel | Süre | Etki | Açan | Dayanak |
|---|---|---|---|---|---|---|
| `zmo_night_watch` | Night Watch Rota / Gece Nöbeti Düzeni | 25 | 30 g | `defense +0,08`; `org −0,03` | `zm_searchlights` | 04 T07 Gecegezer gece saldırır |
| `zmo_silent_line` | Silent Line / Sessiz Hat | 20 | 30 g | `zm_noise_mult −0,50`; `artillery_soft −0,10` | — | 04 top sesi çekimi |
| `zmo_blow_bridges` | Blow the Bridges / Köprüleri At | 40 | 90 g | `zm_bridges_blown 1` (kordon cephesindeki eyalet sınırlarında yürüyüş ×0,15); `infantry_speed −0,10` | `zm_bridge_demolition` | 03 §7 |
| `zmo_tunnel_sweep` | Engineer Tunnel Sweep / İstihkâm Taraması | 35 | 60 g | `zm_tunnels_sealed 1` (Dehlizci yeraltı geçişi kapalı); kordon eyaletlerinde altyapı −1 (bir kez) | `zm_tunnel_sealing` | 04 T08 |
| `zmo_army_quarantine` | Army Quarantine Rotation / Ordu Karantina Nöbeti | 30 | 45 g | `zm_inranks_mult −0,30`; `org −0,05` | — | 04 T05 Kaputlu havuzunu kurutmak; 02 §1.2 "Enfekte tümen" uyarısı |
| `zmo_general_sweep` | General Sweep / Genel Tarama | 50 | 20 g | `breakthrough +0,15`; `zm_urban_attack +0,10` | evre ≥ Çöküş | Arındırma harekâtının kısa hamlesi |
| `zmo_evacuation_trains` | Evacuation Trains / Tahliye Trenleri | 40 | 30 g | `zm_evacuation_mult +0,50`; `infantry_speed −0,05` (demiryolu meşgul) | — | Birinci Dünya Savaşı hastane trenleri |
| `zmo_close_guard` | Close Guard / Sıkı Nöbet | 35 | 60 g | `zm_garrison_kappa_mult +0,25` | — | 03 §3.6: "kaç garnizon gerekir?" |
| `zmo_recon_sorties` | Reconnaissance Sorties / Keşif Uçuşları | 25 | 30 g | `zm_reveal_radius +2` | `fighter_1` ya da `zm_aerial_survey` | 04 §7.4 keşif |
| `zmo_leader_hunt` | Leader Hunt / Önder Avı | 40 | 30 g | `zm_leader_damage +1,0` | `zm_marksman_teams` ya da `zmd_strike_the_leader` | 04 T04 |

### 4.9 Kabine uzmanları (yeni danışmanlar, M3)

Mevcut kural: 150 nüfuz, en çok 3 danışman. Temel oyunun 8 danışmanı kalır (bilim kurulu başkanı `research_speed +0,07` 05'in
hesabındadır); 8 yeni uzman eklenir. Adlar makamdır, kişi değildir (01 §6.5).

| Kimlik | EN / TR | Etki | Şart (`available`) |
|---|---|---|---|
| `zm_epidemic_commissioner` | Epidemic Commissioner / Salgın Komiseri | `zm_beta_mult −0,03`; `zm_report_delay −1` | `zm_phase_at_least: alarm` |
| `zm_chief_quarantine_inspector` | Chief Quarantine Inspector / Karantina Başmüfettişi | `zm_leak_mult −0,15` | `has_focus: zmd_quarantine_inspectorate` |
| `zm_hygiene_director` | Director of the Hygiene Institute / Hıfzıssıhha Enstitüsü Müdürü | `research_speed_zm_medicine +0,05` | `zm_has_building: zm_research_institute` (05) |
| `zm_civil_defence_director` | Director-General of Civil Defence / Sivil Savunma Genel Müdürü | `zm_civil_kappa_mult +0,15` | — |
| `zm_cordon_chief_of_staff` | Chief of Staff, Cordon Armies / Kordon Orduları Kurmay Başkanı | `zm_garrison_kappa_mult +0,15`; `defense +0,03` | — |
| `zm_medical_transport` | Medical Transport Coordinator / Sıhhî Nakliyat Koordinatörü | `zm_distribution_mult +0,15`; `zm_evacuation_mult +0,15` | `zm_tech_any: [zm_hyperimmune_serum]` (05) |
| `zm_provisions_undersecretary` | Under-Secretary for Provisions / İaşe Müsteşarı | `stability +0,03`; `consumer_goods_mod −0,03` | — |
| `zm_relief_envoy` | Envoy for International Relief / Uluslararası Yardım Temsilcisi | `political_power_gain +0,08`; `zm_sample_days −1` | — |

### 4.10 Komutan özellikleri (sürüm 2; ROADMAP V3 generallerine bağlı)

Bugün motorda general yoktur (ROADMAP V3: "Generaller ve mareşaller … karargâh kapasitesi ile özellik alma"). V3 gelince bu mod
aşağıdaki özellikleri ekler. Bedel mevcut kara birikimidir (`army_xp`, tavan 500); etkiler ordunun (cephesinin) eyaletlerinde geçerlidir.

| Özellik | EN / TR | Kara birikimi | Etki (o ordu) | Karşı olduğu tehdit |
|---|---|---|---|---|
| `zmt_cordon_keeper` | Cordon Keeper / Kordon Ustası | 75 | `zm_leak_mult −0,10` | Dağınık sızıntı (03 §10) |
| `zmt_night_warden` | Night Warden / Gece Nöbetçisi | 50 | Gece savunması +%10 | Gecegezer |
| `zmt_street_fighter` | Street Fighter / Sokak Muharibi | 75 | `zm_urban_attack +0,10` | Durgun, Dehlizci |
| `zmt_surgeons_friend` | Surgeon's Friend / Hekim Dostu | 50 | `zm_inranks_mult −0,20` | Kaputlu havuzu |
| `zmt_quiet_gunner` | Quiet Gunner / Sessiz Topçu | 50 | `zm_noise_mult −0,30` | Top sesi çekimi |
| `zmt_river_keeper` | River Keeper / Nehir Bekçisi | 50 | Nehir arkasında savunma +%10 | Sazlıkçı |
| `zmt_winter_hunter` | Winter Hunter / Kış Avcısı | 75 | Kış saldırı cezası yarıya | Kışlayan (kış taraması, 04 T06) |
| `zmt_crossroads_guard` | Crossroads Guard / Kavşak Muhafızı | 75 | Yol kavşağı bölgelerinde savunma +%10 | Kösemen + Kaputlu ikilisi (04 §8) |
| `zmt_evacuator` | Evacuator / Tahliyeci | 50 | Ordunun eyaletlerinde `zm_evacuation_mult +0,25` | Düşen eyaletten kaçış |
| `zmt_leader_hunter` | Leader Hunter / Önder Avcısı | 100 | `zm_leader_damage +0,50` | Kösemen |

### 4.11 Görsel düzen (mevcut F ekranı)

Hücre 236 × 168 px, düğüm 212 × 140 px (`focus_panel.gd`). Altı dal iki banda yerleşir; dallar arası önkoşul çizgisi olmadığı için
bantlar karışmaz. Kök düğümler hiçbir dalın önkoşulu değildir.

```
x →        0            1            2            3            4            5
y=0                  [R1 Uzmanlar]  [R2 Olağanüstü]  [R3 Uzlaşma]            (x = 1,5 / 2,5 / 3,5; üçü ⟂)
y=1      [A1 Kapılar] [A2 Müfettiş] [B1 Hıfzıss.] [B2 Hastane]  [C1 Barikat] [C2 Talimname]   T1 · 1 DP · 14 g
y=2      [A3 Kapalı]╌╌[A4 Süzgeç]   [B3 Numune]╌╌[B4 Kapalı L.] [C3 Mahalle]╌╌[C4 Tahliye]    T2 · 2 DP · 21 g
y=3      [A5 Tüzük]   [A6 Jandarma] [B5 Fakülte]  [B6 Kurul]    [C5 Yeraltı]  [C6 Depolar]    T3 · 2 DP · 28 g · ≥ Alarm
y=4      [A7 Demir]╌╌╌[A8 Rıza]     [B7 Serum Y.]╌[B8 Hekim]    [C7 Kent D.]╌╌[C8 Adalar]     T4 · 3 DP · 42 g · ≥ Yayılma
y=5,25   [D1 Motorlu] [D2 Süvari]   [E1 Sokak N.] [E2 Afişler]  [F1 Bilgi]    [F2 Heyet]
y=6,25   [D3 Ateş]╌╌╌╌[D4 Sessiz]   [E3 Muhafız]╌╌[E4 Silahsız] [F3 Kamp]╌╌╌╌[F4 Sınırda]
y=7,25   [D5 Hava]    [D6 Tarama T.] [E5 Kapı K.] [E6 Aşıcılar] [F5 Mübadele] [F6 Doz D.]
y=8,25   [D7 Tarama]╌╌[D8 Önder]    [E7 Her Ev]╌╌[E8 Yardım]    [F7 Pakt]╌╌╌╌[F8 Koruyucu]
         ╌╌ = birbirini dışlar (mevcut kırmızı kesikli çizgi); dikey önkoşul çizgileri mevcut kodla çizilir
```

- Tuval: ~1.450 × 1.590 px (son düğüm x = 5 → 5 × 236 + 20 + 212 + 40 kenar). 1.600 px ve üstü ekranda (kullanılabilir 1.520 px)
  yatay kaydırma yok; dikey kaydırma mevcut `ScrollContainer` ile.
- Düğüm metni: "Ad\n2 DP · 21 gün" (M1). Durum renkleri mevcut dört stildir (bitti, sürüyor, alınabilir, kilitli); yeni stil yok.
- Başlık satırı (mevcut `_status` etiketi): "Doktrin puanı: 5 · Benimseniyor: Kordon Jandarması (12 gün)".
- İpucu: açıklama + etkiler (mevcut `describe_effects`) + "Bedel: 2 DP" + mod şartları (M8: "Dünya salgın evresi en az Yayılma
  (şu an: Alarm)") + "Birbirini dışlar: Demir Kordon".
- Hükümet paneli: doktrin ulusal durumları tek `row` satırında özetlenir: "Benimsenen doktrinler: 9 (F)" (M7); kabine üslubu
  ayrı satırda ve ikonuyla görünür.
- Uyarı şeridi: mevcut "seçilmemiş program" uyarısı yalnız **alınabilir bir düğüm varken** yanar (DP yetmiyorsa oyuncuyu dürtmez).

## 5. Üç örnek oyun kurgusu

Varsayımlar: Salgın zorluğu, evre günleri 02 §3.2, tıp takvimi 05 §3.4 "tipik" profili, numune zamanlaması 05'teki gibi.

### 5.1 Türkiye — "Laboratuvar Yarışı" (Uzmanlar Kabinesi + B + F)

**Fikir:** 14 fabrikalı, 16 milyonluk bir ülke kordonu uzun süre tutamaz; aşıyı herkesten önce bulup komşularına dağıtarak kazanır.

| Gün | DP geliri | Harcama | Bakiye | Neden |
|---|---|---|---|---|
| 1 | 3 (başlangıç) | Uzmanlar Kabinesi (0) → Hıfzıssıhha (1) | 2 | Kadro +1 ve tıp hızı; ilk proje `zm_case_definition` |
| ~22 | +1 (Alarm) | Hastane Seferberliği (1) | 2 | Dağıtım kapasitesini baştan kurmak |
| 36 | — | Numune Seferleri (2) ⟂ Kapalı Laboratuvar | 0 | G2 numunesi 2 gün erken; kaza riski muhafaza kanadıyla dengelenir |
| ~95–120 | +2 (etken), +1 (Yayılma), +1 (120. gün) | Tıp Fakültesi (2) | 2 | Bilim insanı tavanı 8 → 12: enstitü (6) + muhafaza kanadı (3) + saha lab. (2) = 11 |
| ~150 | — | Bilim Kurulu (2) | 0 | Genel hız +0,05 |
| ~230–240 | +2 (serum), +1 (240. gün) | Serum Yarışı (3) ⟂ Halkın Hekimi | 0 | +1 yuva: seri pasaj ve öldürülmüş etken paralel yürüyebilir (05 §10.4 üçüncü seçenek) |
| 300–480 | +1 (Çöküş), +1 (360), +1 (480), +1 (tıbbi heyet) | Salgın Bilgisi (1), Tıbbi Heyet (1), Sınırda Yardım (2) | 0 | Dayanışma DP'si ve numune |
| 540–730 | +2 (aşı), +1 (600), +1 (720), +1 (doz yardımı) | Doz Diplomasisi (2), Araştırma Mübadelesi (2) | 1 | Aşıyı dağıtıp yardım puanı toplamak (02 §4.1: 150 puan) |

**Takvim (tıp hızı):** Genel hız 1 + 0,03 (radyo) + 0,05 (kabine) + 0,06 → 0,12 (05 BKP kademesi) + 0,07 (bilim kurulu danışmanı) +
0,05 (Bilim Kurulu düğümü, ~178. günden) ≈ 1,21 → 1,32. Kategori eki +0,10'da tavana takılır: Hıfzıssıhha düğümü +0,05 ve enstitü
bitince (~126. gün, 05 §4.1) Hıfzıssıhha Müdürü danışmanı +0,05. **Sonuç:** Serum Yarışı'nın tıp eki bu kurguda boşa gider; asıl
kazancı +1 yuvadır (seri pasaj ile öldürülmüş etken paralel yürür). İpucu bunu "tavan dolu" diye gösterir.

| Kilometre taşı | 05 tipik | Bu kurgu (G2) | Bu kurgu (G3) | Hesap (G2) |
|---|---|---|---|---|
| Etkenin yalıtılması | 112 | **~95** | ~84 | 25 + 120 / (1,21 × 1,05 × 1,35) = 25 + 70 |
| Serum I | 274 | **~224** | ~201 | + 70 / 1,40 + 150 / (1,40 × 1,35) = + 50 + 79 |
| Seri pasaj (yıl kapısı) | 442 | **366** | 366 | 224. günden 366. güne 1,89/gün × 142 = 268 ≥ 260 → yılbaşı |
| Canlı aşı | 648 | **~529** | ~504 | 366 + 320 / (1,32 × 1,10 × 1,35) = 366 + 163 |

**Güçlü yanı:** aşı 02'nin "en erken 540" hedefine G2 ile ~11 gün yaklaşır; tıp araştırması puanının tamamı (100) mümkündür.
**Zayıf yanı:** kordon yok denecek kadar incedir (A, C, D dalı yok); Edirne ve İstanbul kıyısı düşerse Çöküş hesabı hızla ilerler.
**Risk:** kaza. 05 §7.2 formülüyle taban: `0,12 × M3 0,35 × disiplin 0,6 × Numune Seferleri 1,25 = 0,032/yıl` → 4 yılda 0,126.
Ekler: seri pasaj çalışırken (142 gün) ×2,5 → +0,018; G3 60 gün elde tutulursa ×4 → +0,016. Kampanya boyunca beklenen kaza
**~0,16** (en az bir kaza olasılığı ~%15). Kazaların %10'u sızıntıdır; seri pasaj sürerken sızan soyun yarısı Soluk'tur (05 §7.3, 04 T13).
**Karşı hamle:** Kapalı Laboratuvar (B4) seçilirse taban risk ×0,56 olur (0,7 / 1,25) ama numune 2 gün geç gelir; aşı ~10 gün kayar.

### 5.2 Birleşik Krallık — "Ada Kordonu" (Olağanüstü Hal Kabinesi + A + C)

**Fikir:** Ada ülkesinde salgın gemiyle gelir (1918 Amerikan Samoası'nın deniz karantinası, 01 Sütun 5). Kıyı sızıntısını en aza
indir, büyük şehirleri tut, aşıyı beklemek yerine Arındırma Zaferi'ni kolla.

| Gün | Alınan (sıra) | Toplam DP |
|---|---|---|
| 1–35 | Olağanüstü Hal (0) → Sıhhiye Kapıları (1) → Karantina Müfettişliği (1) | 2 |
| ~40–60 | Kapalı Sınır İlkesi (2) ⟂ Süzgeçli Geçiş | 4 |
| ~100–200 | Eyalet Karantina Tüzüğü (2), Kordon Jandarması (2) | 8 |
| ~240–280 | **Demir Kordon** (3) ⟂ Rızaya Dayalı | 11 |
| 300–730 | Sokak Barikatları (1), Kent Garnizon Talimnamesi (1), Kapılı Mahalleler (2), Yeraltı Taramaları (2), Şehir Erzak Depoları (2), **Kent Devletleri** (3) | 22 |
| 730+ | Motorlu Kollar (1), Süvari Perdesi (1), Sessiz Yaklaşma (2): Karşı Saldırı için | 26 |

**Sayılar — deniz yoluyla yerleşen salgın:** Kapalı sınırın kaçağı 0,05'tir (02 §2.4). `zm_leak_mult` toplamı: Sıhhiye Kapıları
−0,10, Kapalı Sınır −0,25, Demir Kordon −0,30, Karantina Başmüfettişi −0,15, Kordon Karakolları −0,15 = −0,95 → tavan **−0,60**
→ kaçak **0,02**. Hazırlıklı ılıman bir eyalete (d = 1, karantina + 1 garnizon) giren tek kuluçkalı yolcunun salgın başlatmama olasılığı
0,89'dur (03 §3.4). Yerleşen salgın başına gereken enfekte yolcu:

| Durum | Geçen pay × yerleşme olasılığı | Yerleşen salgın başına enfekte yolcu |
|---|---|---|
| Açık sınır, hazırlıksız | 1,0 × 0,70 | ~1,4 |
| Kapalı sınır, hazırlıksız | 0,05 × 0,70 = 0,035 | ~29 |
| **Bu kurgu** | 0,02 × 0,11 = 0,0022 | **~455** |

**Bedeller:** istikrar −0,05 (kabine) −0,02 (Kapalı Sınır) −0,05 (Demir Kordon) −0,08 (Zorunlu Karantina yasası, 02) = **−0,20**;
nüfuz kazancı +0,15 −0,10 = +0,05. `zm_quarantine_cost_mult` −0,20 +0,25 = +0,05: ithalata bağımlı ekonomi (kauçuk → serum dozu,
05 §8.1) sıkışır. Kent Devletleri teslim sınırını %80'den %90'a çıkarır: Londra düşse bile hükümet ayakta kalır.
**Suş riski:** 04 §7.2'ye göre uzun sıkı kordon Süreğen suşu ×1,5 besler; zorunlu karantina + yüksek tespit Sessiz taşıyıcılığı besler.
Karşılık: `zm_contact_tracing` (05, seçilim −%60) ve Karşı Saldırı'da D dalıyla etkin arındırma.
**Zayıf yanı:** bilim yavaştır (kabine araştırma vermez); Tedavi Zaferi geç gelir. 02 açık soru 2'deki "ada ülkesi için kolay Arındırma
Zaferi" sorusu bu kurguyla test edilmelidir (§8 kontrol 7).

### 5.3 Polonya — "Ortak Nöbet" (Ulusal Uzlaşma Kabinesi + E + D + F)

**Fikir:** 15 fabrikalı, 31 milyonluk, uzun kara sınırlı bir ülke. Ordu her kasabaya yetmez, bilim kadrosu 9 kişidir (05 §5.1).
Toplumu örgütleyerek kırsalı sivillere, şehri az sayıda garnizona bırakır; bilimi paylaşımla alır.

| Gün | Alınan (sıra) | Toplam DP |
|---|---|---|
| 1–35 | Ulusal Uzlaşma (0) → Sokak Nöbeti (1) → Halk Sağlığı Afişleri (1) | 2 |
| ~40–60 | Yerel Muhafız Bölükleri (2) ⟂ Silahsız | 4 |
| ~100–200 | Kapı Kapı Tarama (2), Motorlu Kollar (1) | 7 |
| ~240–300 | **Her Ev Bir Karakol** (3) ⟂ Yardımlaşma | 10 |
| 300–600 | Gönüllü Aşıcılar (2), Salgın Bilgisi Paylaşımı (1), Sınırda Yardım (2) ⟂ Kamp, Süvari Perdesi (1), Sessiz Yaklaşma (2) | 18 |

Kamp yerine Sınırda Yardım seçildi: uzun doğu ve batı sınırlarında mülteci kampı Kızgın suşun tetiğidir (04 §7.2).

**Sayılar — sivil bastırma ve eyalet R₀'ı** (02 §2.3 formülü, ata suş, ılıman iklim, tam sağlam nüfus):
- κ_sivil = 0,08 × 1,5 (Sivil savunma yasası, 03 §7) × (1 + 0,10 Sokak Nöbeti + 0,25 Yerel Muhafız + 0,35 Her Ev + 0,15 Sivil Savunma
  Genel Müdürü + 0,10 Korunaklı Çiftlik) = 0,08 × 1,5 × 1,95 = **0,234** (tavan +1,0 içinde).
- Bulaş: Zorunlu Karantina −0,35 × 1,10 (`zm_contact_tracing`, 05) = −0,385; kalıcı terim: maske −0,08, dezenfeksiyon −0,07,
  afiş −0,03 = −0,18 → `m = 1 − (1 − 0,385)(1 − 0,18) = 0,496` → β_etkin = 0,30 × 0,504 = **0,151**.

| d (eyalet) | 03 tablosu: karantinayla R < 1 için gereken κ_asker | Bu kurguda R₀ (garnizonsuz) | Bu kurguda 1 garnizonla |
|---|---|---|---|
| 0,64 (medyan) | 0,061 (~0,6 tümen) | **0,62** | — |
| 1,00 (referans) | 0,124 | **0,70** | — |
| 1,93 (sanayi) | 0,389 (~4 tümen) | **0,87** | — |
| 3,00 (büyük şehir) | 1,108 (~4,7 tümen) | 1,04 | **0,90** (κ_asker 0,24) |

Hesap (d = 3): `φβd/γ = 0,15 × 0,151 × 3 / 0,1429 = 0,476`; `0,9 × 0,151 × 3 / (0,234 × 3 + 0,24 + 0,0167) = 0,426` → 0,90.
**Sonuç:** kırsal ve orta eyaletlerde salgın asker olmadan söner; büyük şehir için 4–5 tümen yerine 1 tümen yeter. Ama R₀'ın yarısı
Ateşli bulaşından (φ) gelir: **şehirde asıl kaldıraç yine serumdur** (03 §3.6 ile aynı sonuç).
**Bedeller:** istikrar +0,05 (kabine) +0,01 (afiş) −0,03 (muhafız) + Zorunlu Karantina −0,08 = −0,05; fabrika −0,03 (Her Ev).
**Zayıf yanı:** aşı geç (kadro 9 → tek enstitü); 05 §9'daki "Bulgu iste" ve Standart Birim Komisyonu'na, dolayısıyla komşuların
iyi niyetine bağlıdır. Kösemen önderliğinde gelen sürü dalgası (04 §8) garnizonu az olan hattı yarar.

### 5.4 Tehdit → karşılık tablosu (04 türleri)

| Tehdit (04) | Teknoloji | Doktrin | Emir |
|---|---|---|---|
| T01 Olağan + top sesi | `zm_fire_discipline` | D4 Sessiz Yaklaşma | Sessiz Hat |
| T02 Seğirtken | `zm_wire_obstacles`, `zm_final_protective_fire` | D1 Motorlu Kollar | — |
| T03 Durgun | `zm_urban_clearance` | C5 Yeraltı Taramaları | Genel Tarama |
| T04 Kösemen | `zm_marksman_teams`, `zm_aerial_survey` | D8 Önderi Vur, D2 | Önder Avı, Keşif Uçuşları |
| T05 Kaputlu | `zm_gauntlets`, `zm_field_quarantine_stations`, `zm_bite_wound_protocol` (05) | D6 Sahra Tarama | Ordu Karantina Nöbeti |
| T07 Gecegezer | `zm_searchlights` | D2 Süvari Perdesi | Gece Nöbeti Düzeni |
| T08 Dehlizci | `zm_tunnel_sealing` | C5 | İstihkâm Taraması |
| T09 Sazlıkçı | `zm_port_quarantine_station` (05) | A3 / A4 | — |
| T10 Hırıltılı | `zm_gauze_masks` (05) | E8 Yardımlaşma | — |
| T11 Kızgın | `zm_isolation_wards` (05) | B2, F4 (kampsız) | — |
| T12 Dirençli | `zm_type_specific_serum` (05) | B8 Halkın Hekimi (tam doz dağıtımı) | — |
| T14 Süreğen | — | D7 Tarama Doktrini; A8 (uzun sıkı kordon yerine) | Genel Tarama |
| Sessiz taşıyıcılık | `zm_contact_tracing` (05), `zm_incubation_test` | E5 Kapı Kapı Tarama | — |

## 6. Veri: JSON şema örnekleri

Dosyalar mod altyapısının yama düzenindedir (`docs/modlar/README.md`: tam dosya ya da `.patch.json`):
`data/modes/zombie/common/technologies.patch.json`, `equipment.patch.json`, `focuses.json` (**tam dosya**: WWII ağaçları yüklenmez),
`spirits.patch.json` ve modun kural dosyası `data/modes/zombie/doctrine.json`.

### 6.1 Teknoloji yaması (06'nın kısmı; 05 §12.2 ile aynı dosya)

```json
{
  "_comment": "Gri Kordon teknoloji ağacı. Temel kategoriler silinir, temel teknolojiler yeni sekmelere taşınır, 13 teknoloji silinir. Gerekçe: docs/modlar/zombi/06_teknoloji_ve_yetenek_agaci.md §3.",
  "categories": {
    "infantry": null, "artillery": null, "armor": null, "air": null,
    "naval": null, "industry": null, "electronics": null, "doctrine": null,
    "zm_medicine":      {"en": "Medicine", "tr": "Tıp"},
    "zm_biologics":     {"en": "Biologics", "tr": "Biyolojik Üretim"},
    "zm_surveillance":  {"en": "Surveillance & Signals", "tr": "Gözetim ve Haberleşme"},
    "zm_civil_defence": {"en": "Civil Defence", "tr": "Sivil Savunma"},
    "zm_arms":          {"en": "Arms & Munitions", "tr": "Silah ve Mühimmat"},
    "zm_engineering":   {"en": "Fortification & Engineering", "tr": "Tahkimat ve Mühendislik"},
    "zm_logistics":     {"en": "Logistics & Industry", "tr": "Lojistik ve Sanayi"},
    "zm_food":          {"en": "Agriculture & Food", "tr": "Tarım ve Gıda"}
  },
  "techs": {
    "infantry_weapons_1": {"cat": "zm_arms"},
    "radio":              {"cat": "zm_surveillance"},
    "battleship_1":       {"cat": "zm_logistics"},
    "doctrine_1": null, "anti_tank_1": null, "radar_1": null,
    "zm_searchlights": {
      "cat": "zm_arms", "year": 1936, "cost": 60, "req": ["radio"],
      "name": {"en": "Searchlights and Flares", "tr": "Işıldak ve İşaret Fişeği"},
      "effects": {}, "unlock": ["zm_illumination"],
      "icon_subject": "a searchlight beam over a dark field and a falling flare"
    },
    "zm_cordon_posts": {
      "cat": "zm_engineering", "year": 1936, "cost": 70, "req": ["zm_wire_obstacles"],
      "name": {"en": "Cordon Watch-Posts", "tr": "Kordon Gözetleme Karakolları"},
      "effects": {"zm_leak_mult": -0.15},
      "icon_subject": "a wooden watchtower on stilts beside a striped barrier"
    },
    "zm_food_denial": {
      "cat": "zm_food", "year": 1937, "cost": 80, "req": ["zm_ration_cards"],
      "name": {"en": "Granary and Well Denial", "tr": "Ambar ve Kuyu Boşaltma"},
      "effects": {"zm_hollow_life_mult": -0.15, "stability": -0.02},
      "icon_subject": "an empty granary with open doors and a capped stone well"
    }
  }
}
```
`equipment.patch.json`: `"zm_illumination": {"cost": 15, "resources": {"steel": 1}, "category": "land", "name": {"en": "Illumination Kit",
"tr": "Aydınlatma Takımı"}}`. `icon_subject` motorca okunmaz; `tools/make_icon_prompts.py` modun dosyalarını da tararsa ikon listesini
bundan üretir (§7).

### 6.2 Kriz Doktrini ağacı (`focuses.json`, kesit)

```json
{
  "_comment": "Kriz Doktrini (yetenek ağacı). Devlet programı motoru; points = doktrin puanı (M1). Kademe kuralları ve gerekçe: 06 §4.",
  "trees": {
    "_generic": [
      {"id": "zmd_cabinet_experts", "branch": "root", "tier": 0,
       "name": {"en": "Cabinet of Experts", "tr": "Uzmanlar Kabinesi"},
       "desc": {"en": "Technical ministers speed up knowledge, but hold little political capital.",
                "tr": "Teknik bakanlar bilgiyi hızlandırır ama siyasi sermayeleri azdır."},
       "x": 1.5, "y": 0, "days": 7, "points": 0,
       "prereq": [], "any_prereq": [], "exclusive": ["zmd_cabinet_emergency", "zmd_cabinet_accord"],
       "available": [], "effects": [{"spirit": "zmd_cabinet_experts"}],
       "ai": 30, "ai_mult": [{"if": {"zm_scientists_at_least": 12}, "x": 1.5}],
       "icon_subject": "a round cabinet table with a microscope, ledgers and a telephone"},
      {"id": "zmd_sanitary_gates", "branch": "cordon", "tier": 1,
       "name": {"en": "Sanitary Gates", "tr": "Sıhhiye Kapıları"},
       "desc": {"en": "Inspect, hold and release at the frontier instead of closing it.",
                "tr": "Sınırı kapatmak yerine denetle, beklet, bırak."},
       "x": 0, "y": 1, "days": 14, "points": 1,
       "prereq": [], "any_prereq": [], "exclusive": [], "available": [],
       "effects": [{"spirit": "zmd_sanitary_gates"}],
       "ai": 20, "ai_mult": [{"if": {"has_focus": "zmd_cabinet_emergency"}, "x": 2.0}, {"if": {"zm_has_port": true}, "x": 1.3}],
       "icon_subject": "a striped barrier pole beside a small whitewashed inspection hut"},
      {"id": "zmd_closed_frontier", "branch": "cordon", "tier": 2,
       "name": {"en": "Closed-Frontier Principle", "tr": "Kapalı Sınır İlkesi"},
       "desc": {"en": "A closed border buys time. You decide how to use it.",
                "tr": "Kapalı sınır zaman kazandırır. Zamanı sen kullanırsın."},
       "x": 0, "y": 2, "days": 21, "points": 2,
       "prereq": [], "any_prereq": ["zmd_sanitary_gates", "zmd_quarantine_inspectorate"],
       "exclusive": ["zmd_filtered_passage"], "available": [],
       "effects": [{"spirit": "zmd_closed_frontier"}], "ai": 15,
       "icon_subject": "a wooden border gate chained shut, an empty road beyond"},
      {"id": "zmd_iron_cordon", "branch": "cordon", "tier": 4,
       "name": {"en": "The Iron Cordon", "tr": "Demir Kordon"},
       "desc": {"en": "Nothing passes. Not goods, not news, not patience.",
                "tr": "Hiçbir şey geçmez: ne mal, ne haber, ne sabır."},
       "x": 0, "y": 4, "days": 42, "points": 3,
       "prereq": [], "any_prereq": ["zmd_quarantine_statute", "zmd_cordon_gendarmerie"],
       "exclusive": ["zmd_consent_quarantine"], "available": [{"zm_phase_at_least": "spread"}],
       "effects": [{"spirit": "zmd_iron_cordon"}], "ai": 25,
       "icon_subject": "a long line of iron posts and wire across a snowy plain"}
    ]
  }
}
```

### 6.3 Ulusal durum, uzman ve emir (`spirits.patch.json`, kesit)

```json
{
  "spirits": {
    "zmd_cabinet_experts": {"name": {"en": "Cabinet of Experts", "tr": "Uzmanlar Kabinesi"}, "group": "cabinet",
                            "mods": {"research_speed": 0.05, "zm_detection": 0.03, "political_power_gain": -0.10}},
    "zmd_sanitary_gates":  {"name": {"en": "Sanitary Gates", "tr": "Sıhhiye Kapıları"}, "group": "doctrine",
                            "mods": {"zm_leak_mult": -0.10, "zm_quarantine_cost_mult": -0.20}},
    "zmd_iron_cordon":     {"name": {"en": "The Iron Cordon", "tr": "Demir Kordon"}, "group": "doctrine",
                            "mods": {"zm_leak_mult": -0.30, "zm_kappa_flat": 0.02, "stability": -0.05, "political_power_gain": -0.10}}
  },
  "advisors": {
    "zm_chief_quarantine_inspector": {"name": {"en": "Chief Quarantine Inspector", "tr": "Karantina Başmüfettişi"},
                                      "mods": {"zm_leak_mult": -0.15},
                                      "available": [{"has_focus": "zmd_quarantine_inspectorate"}]}
  },
  "decisions": {
    "zmo_blow_bridges": {"name": {"en": "Blow the Bridges", "tr": "Köprüleri At"},
                         "currency": "command_power", "cost": 40, "days": 90,
                         "available": [{"zm_tech_any": ["zm_bridge_demolition"]}],
                         "mods": {"zm_bridges_blown": 1.0, "infantry_speed": -0.10}}
  }
}
```

### 6.4 Doktrin kural dosyası (`data/modes/zombie/doctrine.json`)

```json
{
  "_comment": "Doktrin puanı (DP), kademeler, tavanlar, karargâh eki. Gerekçe: docs/modlar/zombi/06_teknoloji_ve_yetenek_agaci.md §3.10, §4.3-§4.4, §4.8.",
  "points": {
    "start": 3,
    "periodic": {"every_days": 120, "points": 1},
    "phase_advance": {"points": 1, "max": 5, "count_regress": false},
    "milestones": [
      {"tech_any": ["zm_agent_isolation"], "points": 2},
      {"tech_any": ["zm_hyperimmune_serum"], "points": 2},
      {"tech_any": ["zm_vaccine_live", "zm_vaccine_killed"], "points": 2}
    ],
    "state_cleared": {"points": 1, "max": 6, "min_overrun_days": 30},
    "state_clean":   {"points": 1, "max": 6, "min_reported": 100},
    "solidarity":    {"points": 1, "max": 5, "cooldown_days": 60,
                      "actions": ["share_findings", "medical_mission", "joint_institute", "dose_aid", "refugees_accept"]},
    "cordon_held":   {"points": 1, "max": 3, "days": 90, "min_battles_won": 1}
  },
  "tiers": [
    {"tier": 0, "points": 0, "days": 7},
    {"tier": 1, "points": 1, "days": 14},
    {"tier": 2, "points": 2, "days": 21},
    {"tier": 3, "points": 2, "days": 28, "phase_min": "alarm"},
    {"tier": 4, "points": 3, "days": 42, "phase_min": "spread"}
  ],
  "caps": {
    "zm_leak_mult": [-0.6, 0.5], "zm_civil_kappa_mult": [0.0, 1.0], "zm_garrison_kappa_mult": [0.0, 0.75],
    "zm_inranks_mult": [-0.6, 0.5], "zm_noise_mult": [-0.8, 0.5], "zm_urban_attack": [0.0, 0.25],
    "zm_leader_damage": [0.0, 1.5], "zm_reveal_radius": [0, 3], "zm_hollow_life_mult": [-0.3, 0.0],
    "zm_quarantine_cost_mult": [-0.6, 0.5], "zm_evacuation_mult": [0.0, 1.5], "zm_kappa_flat": [0.0, 0.05],
    "research_speed_category": [-0.10, 0.10]
  },
  "command_power": {"crisis_bonus_per_day": 0.2, "crisis_if_own_state_status": "outbreak"},
  "ai_research_priority": ["zm_medicine", "zm_surveillance", "zm_biologics", "zm_civil_defence",
                           "zm_engineering", "zm_arms", "zm_logistics", "zm_food"]
}
```

**Yeni şart ve etki anahtarları** (`rules.gd` → `condition_keys`/`check_condition`, `effect_keys`/`apply_effect`/`describe_effect`;
CLAUDE.md kural 2 gereği iki sözlüğe birden):

| Tür | Anahtar | Anlamı |
|---|---|---|
| Şart | `zm_phase_at_least` | Dünya salgın evresi en az (`alarm`, `spread`, `collapse`, `counterstroke`, `resolution`) |
| Şart | `zm_has_port` | Ülkenin en az bir liman eyaleti var |
| Şart | `zm_scientists_at_least` | Bilim insanı tavanı ≥ N (05 §5.1) |
| Şart | `zm_dp_at_least` | Yalnız M1 yapılmazsa: DP ≥ N |
| Etki | `doctrine_points` | DP ± N (M1 ile motorda; yapılmazsa `rules.gd`'de) |
| Etki | `zm_scientists` | 05 §12.4'teki etki (Tıp Fakültesi, Hıfzıssıhha, Tıbbi Heyet düğümleri) |

### 6.5 Doktrin düğümü JSON Şeması (kısaltılmış)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "iron-front/modes/zombie/doctrine_node.schema.json",
  "type": "object",
  "required": ["id", "name", "x", "y", "days", "points", "prereq", "any_prereq", "exclusive", "available", "effects", "ai"],
  "properties": {
    "id": {"type": "string", "pattern": "^zmd_[a-z0-9_]{2,40}$"},
    "branch": {"enum": ["root", "cordon", "health", "walls", "columns", "watch", "door"]},
    "tier": {"type": "integer", "minimum": 0, "maximum": 4},
    "name": {"$ref": "#/$defs/loc"},
    "desc": {"$ref": "#/$defs/loc"},
    "x": {"type": "number", "minimum": 0, "maximum": 5.5},
    "y": {"type": "number", "minimum": 0, "maximum": 9},
    "days": {"enum": [7, 14, 21, 28, 42]},
    "points": {"type": "integer", "minimum": 0, "maximum": 3},
    "prereq": {"type": "array", "items": {"type": "string"}},
    "any_prereq": {"type": "array", "items": {"type": "string"}},
    "exclusive": {"type": "array", "items": {"type": "string"}},
    "available": {"type": "array", "items": {"type": "object"}},
    "effects": {"type": "array", "minItems": 1, "items": {"type": "object"}},
    "ai": {"type": "number", "minimum": 0, "maximum": 100},
    "ai_mult": {"type": "array", "items": {"type": "object", "required": ["if", "x"],
                "properties": {"if": {"type": "object"}, "x": {"type": "number", "minimum": 0, "maximum": 5}}}},
    "icon_subject": {"type": "string", "maxLength": 160}
  },
  "additionalProperties": false,
  "$defs": {"loc": {"type": "object", "required": ["en", "tr"],
                    "properties": {"en": {"type": "string"}, "tr": {"type": "string"}}}}
}
```

**Veri testi kuralları** (`tests/test_data.gd` yaklaşımı): (1) her `prereq`/`any_prereq`/`exclusive` kimliği var; `exclusive`
simetrik; (2) `tier` ile `points`/`days` `doctrine.json → tiers` ile tutarlı; (3) aynı (x, y) iki düğüm yok; (4) her dalın en çok
maliyeti 11 DP, toplam 66; (5) her `spirit` etkisi `spirits`'te var ve `group` alanı dolu; (6) her modifier anahtarının `MOD_<anahtar>`
çevirisi var ya da `describe_mod` onu tanıyor; (7) `technologies` içindeki her `cat` tanımlı, hiçbir `req` silinmiş bir teknolojiye
bakmıyor; (8) tanımsız şart anahtarı hata verir (yazım hatası `"zm_phase_atleast"` yakalanır).

## 7. Metinler, görseller ve sesler

### 7.1 Arayüz metinleri (`strings.csv`, EN / TR)

| Anahtar | EN | TR |
|---|---|---|
| `DOCTRINE_TITLE` | Crisis Doctrine | Kriz Doktrini |
| `DOCTRINE_POINTS` | Doctrine points: %d | Doktrin puanı: %d |
| `FOCUS_COST_DP` | %d DP · %d days | %d DP · %d gün |
| `EFF_DOCTRINE_POINTS` | Doctrine points %+d | Doktrin puanı %+d |
| `DP_GAIN_PERIODIC` | Cabinet review: +1 doctrine point | Kabine değerlendirmesi: +1 doktrin puanı |
| `DP_GAIN_PHASE` | The world enters %s: +1 doctrine point | Dünya %s evresine girdi: +1 doktrin puanı |
| `DP_GAIN_MILESTONE` | %s completed: +2 doctrine points | %s tamamlandı: +2 doktrin puanı |
| `DP_GAIN_CLEARED` / `_CLEAN` / `_SOLIDARITY` / `_CORDON` | %s retaken / %s declared clean / An act of solidarity / The cordon held: +1 | %s geri alındı / %s temiz ilan edildi / Bir dayanışma eylemi / Kordon dayandı: +1 |
| `TIER_0` … `TIER_4` | Cabinet · Foundation · Direction · Expertise · Doctrine | Kabine · Temel · Yön · Uzmanlık · Doktrin |
| `COND_ZM_PHASE_AT_LEAST` | World outbreak phase: %s or later (now: %s) | Dünya salgın evresi: en az %s (şu an: %s) |
| `POL_DOCTRINES_ROW` | Adopted doctrines: %d (F) | Benimsenen doktrinler: %d (F) |
| `ORDER_ISSUE` | Issue (%d staff capacity) | Emret (%d karargâh kapasitesi) |
| `MOD_zm_leak_mult` … | bkz. §3.10 tablosu (her anahtar için EN / TR) | |

Düğüm, emir ve uzman adları JSON'da `{"en", "tr"}` olarak durur (tablolar §4.5–§4.9).

### 7.2 Görsel varlıklar (liste ve üretim komutları; dosya üretilmez, CLAUDE.md kural 6)

| Grup | Dosya adı kalıbı | Adet | Stil |
|---|---|---|---|
| Doktrin düğümleri | `assets/ui/icons_new/focus_zmd_*.png` | 51 | `STYLE_ZM_DOCTRINE` (aşağıda) |
| Yeni teknolojiler | `tech_zm_*.png` | 23 | Tıbbi olanlar 04'ün `STYLE_ZM_STRAIN`'i, diğerleri `STYLE_ZM_ICON` |
| Karargâh emirleri | `decision_zmo_*.png` | 10 | `STYLE_ZM_ICON` |
| Kabine uzmanları | `advisor_zm_*.png` | 8 | `STYLE_ZM_ICON` — makam nesnesi (şapka, masa, evrak), **portre değil** |
| Ekipman | `equipment_zm_illumination.png` | 1 | `STYLE_SMALL` |
| Doktrin puanı glifi | `doctrine_points.png` | 1 | `STYLE_SMALL`: "a brass medallion stamped with a laurel sprig" |
| **Toplam** | | **94** | |

01 §3a yeni iş olarak ~40 ikon öngörmüştü; bu belge tek başına 94 ister. **Öncelik önerisi:** P1 = 3 kök + 6 kapanış çifti (12) +
10 emir = 25 ikon; kalanlar gelene kadar düğüm ikonsuz görünür (`UiTheme.icon` dosya yoksa `null` döner, düğme ikonsuz çizilir;
kod değişikliği gerekmez).

```
STYLE_ZM_DOCTRINE = "Crisis doctrine emblem for a 1930s alternate-history epidemic grand strategy game, a single painted object
or small scene on a round enamel medallion with a thin brass rim, muted public-health poster palette of off-white, slate grey,
faded teal and ochre with one warm accent, dramatic side lighting, centered, figures faceless or turned away, no blood, no gore,
no children, no religious symbols, no national insignia, no red cross or red crescent emblem, transparent background, no text,
no letters, no numbers, square 1:1, 512x512"
```
Kızıl haç ve kızılay amblemleri Cenevre Sözleşmeleri'yle korunur ve yalnız sağlık hizmetini göstermek için izinli kullanılabilir;
bu yüzden sağlık temalı ikonlarda **hiçbir haç ya da hilal amblemi yoktur** (05 §14 ile aynı). Konu cümleleri (EN) §3.4–§3.8 ve
§4.5–§4.6 tablolarının "İkon konusu" sütunundadır; tam komut = konu + ". " + stil. Emir ve uzman konuları:

| Dosya | Konu (EN) |
|---|---|
| `decision_zmo_night_watch` | a hooded searchlight on a sandbagged post under a moonless sky |
| `decision_zmo_silent_line` | a field gun with its muzzle capped under a camouflage net |
| `decision_zmo_blow_bridges` | a broken stone bridge over a river, rubble in the water |
| `decision_zmo_tunnel_sweep` | engineers' lamps and a water pump at a bricked-up tunnel mouth |
| `decision_zmo_army_quarantine` | a row of army tents behind a rope, boots lined up outside |
| `decision_zmo_general_sweep` | a line of whistles and a folded map on an ammunition box |
| `decision_zmo_evacuation_trains` | a long passenger train leaving a station at dusk, empty platform |
| `decision_zmo_close_guard` | a sentry box with a lantern at a crossroads in rain |
| `decision_zmo_recon_sorties` | a biplane over a patchwork of fields, a camera hatch open |
| `decision_zmo_leader_hunt` | a brass shepherd's bell hanging from a broken fence post |
| `advisor_zm_epidemic_commissioner` | a commissioner's desk with a wall chart of rising curves |
| `advisor_zm_chief_quarantine_inspector` | an inspector's peaked cap and a brass stamp |
| `advisor_zm_hygiene_director` | a director's white coat on a hook beside an institute key |
| `advisor_zm_civil_defence_director` | a steel helmet and a hand-cranked siren on a desk |
| `advisor_zm_cordon_chief_of_staff` | a staff map with a chalk ring around a region, compasses |
| `advisor_zm_medical_transport` | a railway timetable and a crate of vials with tags |
| `advisor_zm_provisions_undersecretary` | a ledger of grain accounts beside a sack of flour |
| `advisor_zm_relief_envoy` | a travelling case with shipping labels and a folded letter |

### 7.3 Sesler (`tools/make_audio.py` yaklaşımı; telifli örnek yok)

Doktrin benimsenince mevcut `focus_done` (kauçuk damga), teknoloji bitince mevcut `research_done` çalar; yeni ses yalnız üç tane:

| Dosya | Süre | Prosedürel tarif (mevcut yardımcılarla) | Üretim komutu (EN) |
|---|---|---|---|
| `zm_doctrine_capstone` | 2,2 sn | `focus_done` damgası + 0,4 sn sonra `tone(196, 1,4, harm=(1, 0,5, 0,25))` alçak org akoru, `reverb(0,6, 0,35)` | "a rubber stamp on paper followed by a low, solemn organ chord in a large hall" |
| `zm_order_issued` | 1,4 sn | Tarla telefonu manyetosu: `band(noise(0,5), 300, 1.200)` × 18 Hz genlik kıpırtısı, ardından iki kısa `tone(1.100, 0,12)` zil | "a hand-cranked field telephone ringing twice, short" |
| `zm_dp_gain` | 0,6 sn | Tek telgraf tıkırtısı (mevcut `alert` motifinin ilk notası) + `tone(1.319, 0,4)` yumuşak zil, düşük seviye (−18 dB) | "a single soft telegraph click and a small bell, understated" |

## 8. Test ve denge hedefleri

### 8.1 Birim testleri (`tests/test_zm_doctrine.gd`)

| # | Test | Beklenen |
|---|---|---|
| 1 | DP defteri, oyuncusuz 365 gün (evre günleri sabitlenmiş) | Başlangıç 3 + dönemsel 3 + evre ≥ 2; İkinci Dalga sonrası aynı evreye dönüş puan vermez |
| 2 | M1: DP < `points` iken `can_start_focus` | `false`; başlatınca DP düşer, iptalde tam iade |
| 3 | Dışlama | A3 alınınca A4 alınamaz ve tersi (mevcut motor davranışı) |
| 4 | Kademe kapısı | T3 evre < Alarm iken kapalı; T4 evre < Yayılma iken kapalı |
| 5 | Tavanlar | `zm_leak_mult` toplamı −0,95 olsa da etkin değer −0,60; `research_speed_zm_medicine` +0,20 olsa da +0,10 |
| 6 | Emir para birimi (M2) | Karargâh kapasitesi 30 iken 40'lık emir verilemez; verilince kapasite düşer, nüfuz değişmez |
| 7 | Kayıt/yükleme | `doctrine_points`, program ilerlemesi, DP sayaçları (sınır ve bekleme günleri) aynen döner (`test_save_load.gd` kalıbı) |
| 8 | `country_check` (mod) | Oyuncu hiçbir şey yapmazsa DP birikir ama **hiçbir düğüm benimsenmez, hiçbir emir verilmez** (kural 1) |
| 9 | Veri testi | §6.5'teki sekiz kural |
| 10 | Belirlenimcilik | Aynı tohumla iki koşuda yapay zekâ kök ve kapanış seçimleri aynı |

### 8.2 Denge hedefleri (oyuncusuz dünya, 6 koşu; her kontrol ≥ 5/6)

| # | Kontrol | Hedef |
|---|---|---|
| 1 | Yapay zekâ ülkelerinin 730. günde ortalama kazandığı DP | 12–24 |
| 2 | 1.000. güne kadar en az bir kapanış (T4) benimseyen yapay zekâ ülkesi payı | ≥ %60 |
| 3 | Dal çeşitliliği: tüm yapay zekâ kapanışları içinde tek bir dalın payı | %5–35 |
| 4 | Kök dağılımı (yapay zekâ) | Her kök %20–50 |
| 5 | Dünyada ilk aşı | ≥ 500. gün (doktrin 02/05 takvimini delmesin) |
| 6 | Dünyada ilk serum ve aşı (02 kontrol 6–7) | 240–450 ve 600–900 (değişmemeli) |
| 7 | "Ada Kordonu" benzeri ada ülkelerinde Arındırma Zaferi oranı | ≤ %40 (02 açık soru 2) |
| 8 | Bitişte yapay zekâ ülkelerinin bitirdiği teknoloji payı (medyan) | %35–55 (70 üzerinden) |
| 9 | Doktrin defteri ve tavan hesabının maliyeti (`sim.gd`) | < 0,5 ms/gün |

## 9. Açık sorular

1. **Sekmeleri birleştirme:** 05 §3.1 temel sekiz kategorinin kalmasını öngörür; bu belge teknolojileri koruyup sekmeleri taşımayı
   önerir (16 sekme 720 px'e sığmaz). Hangisi? Alternatif: araştırma paneline ikinci bir sekme satırı (arayüz işi, insan gözü gerekir).
2. **DP ve zaman:** Motor bir anda tek program yürütür. Doktrinler paralel benimsenebilsin mi (ör. dal başına bir)? Öneri: hayır;
   tek sıra planlamayı anlamlı kılıyor. Oyun testi karar versin.
3. **Yeniden seçim (respec):** Kök yalnız İç Çöküş olayında değişiyor (§4.5). Seçimle iktidar değişince de değişsin mi?
   Öneri: evet, mevcut seçim olayına "kabine üslubunu koru / değiştir" seçeneği eklenir; doktrin düğümleri geri alınmaz.
4. **Kategori hız tavanı (+0,10):** uç kurgu aşıyı ~504. güne çekiyor (05'in 521'inden 17 gün erken); tipik numuneyle ~529
   (02'nin 540 hedefinden %2 erken). Tavan +0,05'e mi insin? Denge kontrolü 5 karar versin.
5. **Emirlerin hedefi:** Sürüm 1'de emirler ülke genelidir. Ordu ya da eyalet seçerek verilen emir daha doğal olur ama ordu
   paneline yeni bir düğme ister (yalnız `small_button`, stil yok). Ne zaman?
6. **Komutan özellikleri** ROADMAP V3 generallerine bağlı; V3 bu moddan önce gelmezse §4.10 ertelenir.
7. **Gıda kaynağı yok:** Tarım/gıda yalnız istikrar, insan gücü ve Boş ömrü üzerinden etki ediyor. Kıtlık olayları (01 Sütun 3)
   için bu yeterli mi, yoksa eyalet düzeyinde bir "hasat kaybı" çarpanı mı gerekir? Öneri: sürüm 1'de yeterli.
8. **Temel teknolojilerin silinmesi** (13) yalnız bu modda geçerli; WWII'ye etkisi yok. Ama 1939 teknolojileri (orta tank, hafif
   makineli) 1939'da da yıl cezasız alınabiliyor; oyunun son yılında askerî sıçrama isteniyor mu?
9. **İkon bütçesi:** 94 ikon, 01'in ~40'lık tahmininin iki katından fazla. P1 listesi (25) ile başlamak kabul mü?
10. **Dağıtım tavanı:** 02 aşılamada günde %1,5 tavan koyar, 05 aynı tavanı dağıtıma uygular. Bu belgedeki dağıtım çarpanları tavanı
    aşmaz, yalnız tavana daha çok eyalette ulaşılır. 1947 New York'un zirve hızı (~%3/gün) doktrinle tavanın %2'ye çıkmasını haklı
    kılar mı?
11. **Yapay zekâ kişilikleri:** `ai_mult` yalnız köke ve coğrafyaya bakıyor (ideolojiye bakmıyor; 01 §6.5'teki "rejim önlemi aklanmaz"
    ilkesi yüzünden). Çeşitlilik yeterli olmazsa ek ölçüt ne olmalı (bilim kadrosu, sınır uzunluğu)?

## 10. Kaynaklar

Salgın yönetimi ve kurumlar (tarih)
- Hatchett, R. J., Mecher, C. E., Lipsitch, M. (2007). Public health interventions and epidemic intensity during the 1918 influenza
  pandemic. *PNAS* 104(18): 7582–7587. — https://www.pnas.org/content/104/18/7582
- Horbec, I. At the Gates of Christian Europe: The Quarantines on the Habsburg–Ottoman Border (18th–19th Century). —
  https://www.researchgate.net/publication/274962221_At_the_Gates_of_Christian_Europe_The_Quarantines_on_the_Habsburg-Ottoman_Border_18th-19th_Century
- Askerî sınırda veba, kontumaz ve karantina (18.–19. yüzyıl). *Hrčak.* — https://hrcak.srce.hr/clanak/376728
- 1911 Mançurya vebası: demiryolu karantinası, yük vagonunda gözlem, maske. — https://pmc.ncbi.nlm.nih.gov/articles/PMC7110523/
- Polonya tifüs salgını 1916–1923 ve Milletler Cemiyeti Salgın Komisyonu. *Epidemiologia* 5(4). — https://pmc.ncbi.nlm.nih.gov/articles/PMC11675154/
- Infectious Disease (Notification) Act 1889. — https://www.legislation.gov.uk/ukpga/Vict/52-53/72/contents/enacted
- Parran, T. (1937). *Shadow on the Land: Syphilis* (Milbank Quarterly incelemesi). —
  https://www.milbank.org/quarterly/articles/review-shadow-on-the-land-syphilis-by-thomas-parran/
- İngiltere'de hava saldırısı önlemleri ve bekçi teşkilatı (1937–1939). *Imperial War Museums.* —
  https://www.iwm.org.uk/history/how-britain-prepared-for-air-raids-in-the-second-world-war
- Air Raid Precautions (gönüllü sayıları 1938). — https://en.wikipedia.org/wiki/Air_Raid_Precautions
- Birinci Dünya Savaşı hastane trenleri. *National Railway Museum.* —
  https://www.railwaymuseum.org.uk/objects-and-stories/ambulance-trains-bringing-first-world-war-home
- İngiliz ordusunda bakteriyoloji ve seyyar laboratuvarlar 1850–1918. — https://pubmed.ncbi.nlm.nih.gov/20919615/
- Sydney Domville Rowland ve 1 No'lu Seyyar Laboratuvar (1914). — https://en.wikipedia.org/wiki/Sydney_Domville_Rowland
- Toprak Mahsulleri Ofisi (1938). — https://tr.wikipedia.org/wiki/Toprak_Mahsulleri_Ofisi
- Refik Saydam Hıfzıssıhha Enstitüsü (1928). *Atatürk Ansiklopedisi.* —
  https://ataturkansiklopedisi.gov.tr/detay/187/Refik-Saydam-H%C4%B1fz%C4%B1ss%C4%B1hha-Enstit%C3%BCs%C3%BC
- Statens Serum Institut'un yüzüncü yılı. *Eurosurveillance.* — https://www.eurosurveillance.org/content/10.2807/esm.07.10.00364-en
- Economic History of Tractors in the United States. *EH.net.* — https://eh.net/encyclopedia/economic-history-of-tractors-in-the-united-states/
- Mechanization and the Use of Labor on Farms (USDA). — https://ageconsearch.umn.edu/record/341158

Bilim ve tıp tarihi
- Reed–Frost zincir binom modeli (1928) ve salgın modellemesinin tarihi. — https://pmc.ncbi.nlm.nih.gov/articles/PMC3710332/
- 17D suşunun Brezilya'da erken kullanımı (1938'de 1.058.328 aşılama). *Memórias do Instituto Oswaldo Cruz.* —
  https://memorias.ioc.fiocruz.br/article/2565/the-early-use-of-yellow-fever-virus-strain-17d-for-vaccine-production-in-brazil-_-a-review
- Developing the 17D yellow fever vaccine. *Nature.* — https://www.nature.com/articles/d42859-020-00012-9
- Woodruff, A. M., Goodpasture, E. W. (1931). The cultivation of vaccinia and other viruses in the chorio-allantoic membrane of chick
  embryos. *Science* 74. — https://www.science.org/doi/10.1126/science.74.1919.371
- Ramon ve formolle zararsızlaştırılmış difteri anatoksini (1923). *Institut Pasteur.* —
  https://www.pasteur.fr/en/research-journal/news/diphtheria-hundred-years-ago-first-toxoid-vaccine
- Kuduz aşılarının gelişimi (Semple 1911, fenolle öldürülmüş). *Vaccines* 11(4). — https://pmc.ncbi.nlm.nih.gov/articles/PMC10147034/
- 1930 Lübeck BCG olayı. *European Respiratory Review.* — https://pmc.ncbi.nlm.nih.gov/articles/PMC9488810/
- Treatment of Diphtheria with Refined Antitoxin (1939). *BMJ.* — https://pmc.ncbi.nlm.nih.gov/articles/PMC2209030/
- The Changing Fate of Pneumonia as a Public Health Concern in 20th-Century America (tipe özgü serum). *AJPH* 95(12). —
  https://ajph.aphapublications.org/doi/full/10.2105/AJPH.2004.048397
- Cleaveland, S. ve ark. (2002). Estimating human rabies mortality in the United Republic of Tanzania from dog bite injuries
  (ısırık yeri dağılımı). *Bull. WHO* 80(4). — https://www.scielosp.org/article/bwho/2002.v80n4/304-310/

Hukuk (ikon içeriği)
- Cenevre Sözleşmesi I (1949), madde 44: amblemin kullanım kısıtları. *ICRC.* —
  https://ihl-databases.icrc.org/en/ihl-treaties/gci-1949/article-44

Depo içi
- `game/autoload/research.gd`, `game/autoload/politics.gd`, `game/autoload/ai.gd`, `game/autoload/military.gd` (karargâh ve birikim
  tahakkuku), `game/core/country.gd`, `game/core/game_modes.gd`, `game/core/mode_rules.gd`, `game/ui/focus_panel.gd`,
  `game/ui/research_panel.gd`, `game/ui/ui_theme.gd`, `data/common/technologies.json`, `data/common/focuses.json`,
  `data/common/spirits.json`, `data/common/equipment.json`, `docs/modlar/README.md`, `docs/OZGUNLUK.md`, `ROADMAP.md` (V3),
  `tools/make_icon_prompts.py`, `tools/make_audio.py`, `docs/modlar/zombi/01`–`05`.
