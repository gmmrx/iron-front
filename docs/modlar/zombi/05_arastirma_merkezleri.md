# Zombi modu — 05 Araştırma merkezleri, bilim yolu ve tedavi

> **Özet.** Bu belge *Gri Kordon* modunda bilimin nasıl işlediğini tanımlar: binalar, personel, numune, araştırma ağacı,
> serum ve aşı üretimi, laboratuvar kazaları ve uluslararası işbirliği. Kararlar 01_vizyon.md ve 02_oynanis_dongusu.md'ye uyar.
> - **Dört aşama:** *anlamak* → *yavaşlatmak* → *tedavi etmek* → *önlemek*. 27 teknoloji, dört yeni araştırma kategorisi
>   (`zm_medicine`, `zm_surveillance`, `zm_civil_defence`, `zm_biologics`). Maliyetler 02 §5'teki kilometre taşlarına göre geri
>   hesaplandı: etken tipik **112. gün** (en erken ~65), serum tipik **274. gün** (en erken ~191), aşı tipik **648. gün** (en erken ~521).
> - **Sekiz bina:** saha laboratuvarı, araştırma enstitüsü, muhafaza kanadı, numune deposu, karantina hastanesi,
>   üniversite hastanesi, serum ahırı, aşı üretim tesisi. Maliyetler mevcut bina maliyetlerinden (fabrika-gün) türetildi.
> - **Personel:** "bilim insanı" tavanı fabrika sayısı ve nüfustan hesaplanır (ülke başına 2–29; medyan 5). Kadro darlığı
>   modun asıl kısıtıdır; küçük ülke bilimi tek başına yürütemez (01 Sütun 5).
> - **Numune** askerî iş ister: klinik (G1), saha (G2), sürü (G3) ve suş (G4). Motorun mevcut `research_bonus` mekanizması
>   kullanılır; G3 hem en güçlü hem en riskli yoldur.
> - **Laboratuvar kazası** olasılığı gerçek verilerden ölçeklendi (modern BSL-3 için 0,2%/laboratuvar-yılı → 1936 için 0,12).
>   Üç muhafaza düzeyi gerçek BSL tanımlarına bağlanır; 1936'da güvenlik kabini yoktur, bu yüzden dördüncü düzey de yoktur.
> - **Serum ve aşı** mevcut üretim hattı motorunda üretilir (fabrika-saat); binalar **serbest bırakma** ve **dağıtım**
>   kapasitesini belirler. Oyuncu adına dağıtım yapılmaz (`auto_serum`, `auto_vaccine`, `auto_staff` kapalı başlar).
> - Motorda gereken değişiklik yalnız ikidir (§1.3); geri kalan her şey JSON ve `rules.gd` kancalarıyla yürür.

---

## 1. Kapsam, ilkeler ve motorla ilişki

### 1.1 Bu belgenin kapsamı
Bu belge şunları kesinleştirir: bina türleri ve maliyetleri, personel, numune toplama, araştırma projeleri ve süreleri,
serum/aşı yolu, kaza ve etik olayları, uluslararası bilgi paylaşımı, arayüz ve harita görünümü, JSON şeması, test hedefleri.
Salgın denklemleri 02_oynanis_dongusu.md ve 03_salgin_modeli.md'de, tür ve suş tabloları 04_zombi_turleri.md'dedir;
buradaki her sayı onlarla tutarlıdır (serum etkinliği için 03'ün bıraktığı boşluk §8.4'te doldurulur).
04'ün "araştırma belgesinde kesinleşir" dediği kimlikler burada kesinleşti: `zm_strain_typing`, `zm_gauze_masks`,
Serum II = `zm_type_specific_serum`, laboratuvar kazası olasılığı §7.2.

### 1.2 İlkeler
| İlke | Uygulama |
|---|---|
| Oyuncu karar verir (CLAUDE.md kural 1) | Kadro atama, numune emri, serum/aşı dağıtımı, paylaşım teklifi hep oyuncunun eylemidir. Kolaylıklar (`auto_staff`, `auto_serum`, `auto_vaccine`) **kapalı** başlar; yapay zekâ ülkeleri kendi bilimini otomatik yürütür |
| Veri güdümlü (kural 2) | Bina, teknoloji, ekipman, olay ve sayıların tamamı `data/modes/zombie/**` içinde. Motor "aşı" sözcüğünü bilmez; anahtarları bilir |
| Yeni sistem değil, var olanın yeniden kullanımı | Bina = `Economy` inşaat kuyruğu; teknoloji = `Research`; numune bonusu = `Country.research_bonus`; kaza = `Politics.fire_event`; enstitü hızı = ulusal durum (spirit) kademeleri; üretim = `ProductionLine` |
| Bilim işe yarar | Aşı ve serum olumlu araçlardır (01 §6.3). Söylenti ve korku olayları vardır ama oyun gerçeği belirsiz bırakmaz |
| Etik bedeli olan seçim, avantaj değil | Rızasız deney, gizlenen kaza, kirli parti sevkiyatı **hız kazandırmaz**; yalnız bedel doğurur (§10) |
| Gerçek dayanak | Her bina, süre ve risk sayısının altında tarihî ya da bilimsel bir dayanak satırı vardır (§16) |

### 1.3 Motorda gereken değişiklikler (yalnız iki tane)
1. **Bina şartları (içerikten bağımsız, küçük):** `Economy.can_build` şu isteğe bağlı anahtarları tanısın:
   `requires_tech`, `requires_building`, `min_population`, `category_min`. Bugün `coastal`, `shared_slots`, `max` tanınıyor;
   dördü de aynı kalıptadır ve WWII modu da kullanabilir. **Yedek plan (değişiklik yapılmazsa):** şartlar kaldırılır, denge
   yalnız maliyet ve slotla kurulur; oyuncu teoride teknolojisi yokken aşı tesisi kurabilir (boş durur).
2. **Yeni binaların haritada görünmesi (görsel — insan gözü gerekir, CLAUDE.md kural 5):** `MapIconLayer` kalıbıyla iki boyutlu
   ikon (zoom aralıklı `Sprite3D`) eklenmesi yeterlidir; `CityLayer3D._build_industry` listesine dokunmak gerekmez.
   Doğrulanana kadar merkezler **yalnız** eyalet panelinde, salgın panelinde ve eyalet işaretinde görünür (§11.4).

Değişiklik gerektirmeyenler: yeni araştırma kategorisi ve teknoloji (`technologies.patch.json`), yeni bina
(`buildings.patch.json`; eyalet paneli `Economy.defs`'i tarayıp kendiliğinden gösterir), yeni ekipman
(`equipment.patch.json`; üretim paneli kategoriye bakmadan listeler), yeni etki ve şart anahtarları
(`rules.gd` → `effect_keys`/`apply_effect`/`describe_effect`/`condition_keys`/`check_condition`).

## 2. Bilim yolu: dört aşama

```
  ANLAMAK                YAVAŞLATMAK              TEDAVİ ETMEK              ÖNLEMEK
  vaka tanımı            maske, dezenfeksiyon     serum tedavisi            zayıflatma (seri pasaj
  bildirim zorunluluğu   izolasyon koğuşu         hiperimmün serum            ya da öldürülmüş etken)
  etkenin yalıtılması    temaslı takibi           serum standardı           kuluçka yumurtasında üretim
  suş tipleme            ısırık protokolü         tipe özgü serum           aşı · etkinlik denetimi
       │                      │                        │                         │
       ▼                      ▼                        ▼                         ▼
  bilgi sisi açılır      R düşer, süre kazanılır   Ateşli kurtulur (F→R)     Sağlam korunur (S→V)
  numune işlenebilir     mutasyon riski düşer      ölü ve Boş azalır         Tedavi Zaferi mümkün
```

**Sıra neden böyle?** Kullanıcının istediği dört aşamanın son ikisi yer değiştirdi: modda **serum aşıdan önce** gelir.
Gerekçe tarihîdir: serum tedavisi (pasif bağışıklık) 1890'larda difteri ve tetanosta yerleşti ve 1930'larda pnömonide tipe
özgü serumlar kullanılıyordu; canlı zayıflatılmış bir aşı ise aynı hastalık için yıllar sonra gelebildi (sarı humma:
etken 1927'de yalıtıldı, 17D aşısı 1937'de elde edildi). Oyunda da serum "zaman kazandıran", aşı "bitiren" araçtır.

| Aşama | Ne verir | Oyuncunun sorusu | Kilometre taşı (02 §5) |
|---|---|---|---|
| Anlamak | Tespit oranı, bildirim hızı, numune işleme, suş keşfi | "Neye bakıyorum?" | Etkenin tanımlanması |
| Yavaşlatmak | β düşüşü, κ artışı, ordu içi bulaş düşüşü, mutasyon riski düşüşü | "Kaç gün kazanırım?" | — (sürekli kazanç) |
| Tedavi etmek | F → R (kurtarılan hasta), ölümün azalması | "Kimi kurtarırım?" | Serum |
| Önlemek | S → V, Tedavi Zaferi koşulu | "Bitirebilir miyim?" | Aşı + kapsam |

## 3. Araştırma ağacı: 27 proje

### 3.1 Kategoriler
`technologies.patch.json` dört kategori ekler. Mevcut sekiz kategori (piyade, topçu, zırh, hava, deniz, sanayi, elektronik,
kara doktrini) kalır; zombi modunda askerî dallar arındırma harekâtı ve kordon için hâlâ gereklidir.

| Kimlik | EN / TR | Yuva rekabeti | Not |
|---|---|---|---|
| `zm_medicine` | Medicine / Tıp | Yüksek | Kritik yol; numune bonusu buraya yazılır |
| `zm_surveillance` | Surveillance / Gözetim | Orta | Bilgi sisini açar (01 Sütun 2) |
| `zm_civil_defence` | Civil Defence / Sivil Savunma | Düşük | β ve κ; hep işe yarar, hiç kazandırmaz |
| `zm_biologics` | Biologics / Biyolojik Üretim | Orta | Üretim ve dağıtım tavanları |

### 3.2 Proje tablosu
`cost` = araştırma hızı 1'de gün; `year` = bu yıldan önce araştırılırsa yıl başına **+%150** süre (motorun mevcut
`AHEAD_PENALTY` kuralı). Aşı dalı dışında bütün `zm_*` projeleri `year: 1936`'dır; gerekçe §3.3'te.

| # | Kimlik | Kat. | Yıl | Cost | Şart (`req`) | Etki (özet) |
|---|---|---|---|---|---|---|
| 1 | `zm_case_definition` | gözetim | 1936 | 30 | — | Tespit +0,10; bildirim gecikmesi −1 gün |
| 2 | `zm_notifiable_disease` | gözetim | 1936 | 60 | 1 | Tespit +0,10; gecikme −1; karantina yasası açılır |
| 3 | `zm_radio_bulletin` | gözetim | 1936 | 80 | 1 | Gecikme −2; bültende eyalet ayrıntısı |
| 4 | `zm_railway_health_posts` | gözetim | 1936 | 90 | 2 | Enfekte eyaletten çıkan yolcu akışı −%25 |
| 5 | `zm_port_quarantine_station` | gözetim | 1936 | 110 | 2 | Liman yolcu akışı −%40; konvoy cezası yarıya iner |
| 6 | `zm_contact_tracing` | gözetim | 1936 | 150 | 2 | Karantina etkisi +%10; Sessiz taşıyıcılık seçilimi −%60 (04 §7.2) |
| 7 | `zm_strain_typing` | gözetim | 1936 | 150 | 8 | Numuneyle suş keşfi (04 §7.4); G4 numune açılır |
| 8 | **`zm_agent_isolation`** | tıp | 1936 | 120 | 1 | **Etkenin tanımlanması.** G2/G3 numune, Soluk aşılama seçeneği, tıp dalı açılır |
| 9 | `zm_serotherapy` | tıp | 1936 | 70 | 8 | Serum ahırı binası açılır; ısırık protokolü şartı |
| 10 | **`zm_hyperimmune_serum`** | tıp | 1936 | 150 | 9 | **Serum I.** `zm_serum_dose` üretilebilir; etkinlik 0,60 |
| 11 | `zm_serum_standardisation` | tıp | 1936 | 130 | 10 | Etkinlik 0,75; serbest bırakma ×1,5; Dirençli seçilimi yarıya iner |
| 12 | `zm_type_specific_serum` | tıp | 1936 | 200 | 11, 7 | **Serum II.** Etkinlik 0,85; Dirençli suşta etkinlik cezası kalkar (04 T12) |
| 13 | `zm_attenuation_passage` | tıp | **1937** | 260 | 10 | Seri pasajla zayıflatma; kaza çarpanı ×2,5; Soluk suş riski (04 T13) |
| 14 | `zm_attenuation_inactivated` | tıp | **1937** | 340 | 10 | Öldürülmüş etken; kaza çarpanı ×1,0; Soluk riski yok |
| 15 | **`zm_vaccine_live`** | tıp | **1937** | 320 | 13, 18 | **Aşı (canlı).** Etkinlik 0,90 |
| 16 | **`zm_vaccine_killed`** | tıp | **1937** | 380 | 14 | **Aşı (öldürülmüş).** Etkinlik 0,75; iki doz (dağıtım ×0,6) |
| 17 | `zm_vaccine_potency` | tıp | 1936 | 160 | 11 | Etkinlik +0,05; Aşı kaçağı seçilimi −%50; kirli parti olayı olasılığı −%70 |
| 18 | `zm_egg_culture` | biyo. | 1936 | 150 | — | Aşı doz maliyeti ×0,6; aşı tesisi binası açılır |
| 19 | `zm_cold_chain` | biyo. | 1936 | 170 | 18 | Eyalet dağıtım kapasitesi +%50; doz bozulması −%80 |
| 20 | `zm_filling_line` | biyo. | 1936 | 140 | 18 | Üretim verimlilik tavanı +%10; serbest bırakma ×1,25 |
| 21 | `zm_gauze_masks` | siv. sav. | 1936 | 50 | — | β −%8 |
| 22 | `zm_disinfection_protocol` | siv. sav. | 1936 | 80 | 21 | β −%7; düşmüş eyaletten komşuya bulaş −%20 |
| 23 | `zm_isolation_wards` | siv. sav. | 1936 | 120 | 21 | Hastane taşması (Kızgın) tetiği −%60; serum tedavi verimi +%20 |
| 24 | `zm_bite_wound_protocol` | siv. sav. | 1936 | 90 | 9 | Ordu içi bulaş −%40 |
| 25 | `zm_civil_guard_drill` | siv. sav. | 1936 | 110 | — | Kendi eyaletlerinde κ +0,02 |
| 26 | `zm_lab_discipline` | siv. sav. | 1936 | 100 | 8 | Kaza çarpanı ×0,6 |
| 27 | `zm_evacuation_plans` | siv. sav. | 1936 | 130 | — | Tahliye hızı +%50; mülteci kaynaklı bulaş −%25 |

**Toplam bütçe:** 3.880 araştırma puanı (gözetim 670, tıp 2.130, biyolojik 460, sivil savunma 680).
Bir kampanyada (1.461 gün) iki yuva ve 1,15 hızla üretilen puan ≈ 3.360. Yani **her şey araştırılamaz**: bu kasıtlıdır.
Üç yuva ve 1,30 hızla (büyük güç + danışman + enstitüler) ≈ 5.700 puan üretilir ve ağaç bitirilebilir; küçük ülke
paylaşıma (§9) ya da seçime mecburdur.

**Puanlamayla bağ:** 02 §4.1'deki "bitirilen tıp araştırması / tüm tıp araştırması" (100 puan) oranı, `zm_medicine` ve
`zm_biologics` kategorilerindeki **13 proje** üzerinden hesaplanır (13'ünü de bitiren 100 puanın tamamını alır).

### 3.3 Yıl kapısı: aşı 1936'da neden zorlanır?
Aşı dalının üç projesi (13–16) `year: 1937`dir. Motor her gün maliyeti yeniden hesaplar:
`cost × (1 + 1,5 × (yıl − o günün yılı))`. Sonuç iki katmanlı ve tarihe uygun bir karar doğurur:
- 1936'da başlarsan hedef **2,5 kat** büyür; ama biriken ilerleme silinmez. 1 Ocak 1937'de hedef düşer ve biriken ilerleme
  eşiği aşıyorsa proje **o gün** tamamlanır. "Acele eden" oyuncu bunu bilerek yapar: kış boyunca çalışır, yılbaşında hasat eder.
- Bekleyen oyuncu yuvasını serum ve gözetimle doldurur, aşıya 1937'de temiz başlar.

Bu, 17D aşısının hikâyesiyle örtüşür: etken 1927'de yalıtıldı, aşı 1937'de elde edildi, 1938'de yaklaşık 1,06 milyon kişi
aşılandı. Modun sıkıştırma oranı yaklaşık 5 kattır (02 §5).

### 3.4 Sürelerin türetilmesi
`Research` her gün yuva başına `hız × (1 + numune bonusu)` puan yazar; `hız = 1 + mod("research_speed")`.
Üç profil kullanıldı:

| Profil | Yuva | Hız | Numune bonusu | Kim |
|---|---|---|---|---|
| **Tipik** | 2 | 1,06 → 1,15 (enstitüler kurulunca) | 0,35 (G2) | Orta ülke, dengeli oynayan |
| **En erken** | 2–3 | 1,25 → 1,30 | 0,60 (G3) | Bilime her şeyi veren oyuncu; 30 günlük boş yuva birikimi (`research_stored`) dâhil |
| **Geç** | 2 | 1,00 | 0 (numune yok) | Hiç merkez kurmayan; kritik yolda ~1,7 kat yavaş |

Kritik yol ve sonuçlar (gün, oyun başından):

| Kilometre taşı | Hesap (tipik) | Tipik | En erken | 02 §5 hedefi | Uyum |
|---|---|---|---|---|---|
| Vaka tanımı (1) | 30 / 1,06 = 28 | **28** | 24 | — | — |
| Etkenin tanımlanması (8) | 120 / (1,06 × 1,35) = 84 | **112** | 65 | tipik 90–150, en erken 60 | ✔ |
| Serum tedavisi ilkeleri (9) | 70 / 1,12 = 63 | **175** | 119 | — | — |
| **Serum I** (10) | 150 / (1,12 × 1,35) = 99 | **274** | 191 | tipik 240–450, en erken 180 | ✔ |
| Zayıflatma (13, yıl kapısı) | 1 Ocak 1937'ye kadar 144 puan birikir, kalan 116 / 1,55 = 75 gün | **442** | 367 | — | Yıl kapısı §3.3 |
| **Aşı** (15) | 320 / (1,15 × 1,35) = 206 | **648** | 521 | tipik 600–900, en erken 540 | ✔ (en erken ~%3 erken) |
| Öldürülmüş aşı yolu (14→16) | 340 (yıl kapısı) → 380 / 1,55 = 245 | **738** | 550 | — | Yavaş ama kazasız |

"En erken 521" 02'deki 540'ın %3,5 altındadır; iki belge arasında düzeltme gerekmez, çünkü 521 ancak şu üçü birlikte
yapılırsa çıkar: G3 sürü numunesi (§6), 1936'da yıl cezası ödeyerek çalışma (§3.3) ve 30 günlük yuva birikimini saklama.
Üçü de bedelli seçimlerdir.

**02 §10 şemasında bir düzeltme:** `victory.cure.tech: "zm_vaccine"` alanı **`tech_any: ["zm_vaccine_live", "zm_vaccine_killed"]`**
olmalıdır; motorun `req` listesi "VE" bağlacıdır, bu yüzden iki aşı yolu iki ayrı teknolojidir ve zafer koşulu ikisinden
birini kabul eder. `rules.gd` bunu kendi `check_end`'inde denetler; motor değişmez.

## 4. Araştırma merkezleri: bina kataloğu

### 4.1 Maliyet türetme yöntemi
Ölçek zaten depoda: `data/common/buildings.json` maliyetleri **fabrika-gün** cinsindendir (bir sivil fabrikanın bir günlük işi).
Çıpalar: sivil fabrika 2.160, sentetik rafineri 3.000, askerî fabrika 1.440, tersane 1.280, altyapı 1.100, deniz üssü 450,
uçaksavar 400, hava üssü 300. Sağlık binaları bu çıpalara **inşaat işi** olarak oranlandı (makine ağırlığı değil, yapı ağırlığı):

| Bina | Maliyet | Nasıl türetildi |
|---|---|---|
| Saha laboratuvarı | **240** | Hava üssü (300) bir tesviye + hangar işidir; saha laboratuvarı bir okul/hastane kanadının dönüştürülmesi + tezgâh ve otoklav = 0,8 × 300 |
| Numune deposu | **300** | Uçaksavar bataryası (400) ölçeğinin altı: buz mahzeni/soğutucu, kilitli kasa, kayıt odası |
| Karantina hastanesi | **520** | Deniz üssü (450) + %15: pavyon bloklar, su ve kanalizasyon, çamaşırhane, yakma fırını |
| Serum ahırı ve dolum atölyesi | **640** | Deniz üssü × 1,4: ahır, padok, soğutmalı dolum odası, sterilizasyon |
| Üniversite hastanesi | **1.100** | Altyapı (1.100) ile aynı: dönemin en büyük kamu yapı kalemi; klinik + fakülte + laboratuvar |
| Araştırma enstitüsü | **1.450** | Askerî fabrika (1.440) mertebesi: laboratuvar binası, hayvan barınağı, kazan ve otoklav hattı, kütüphane, atölye |
| Muhafaza kanadı | **700** | Enstitünün ~%48'i: ayrı blok, tek yönlü koridor, geçiş odaları, baca çekişli havalandırma, yakma fırını |
| Aşı üretim tesisi | **1.900** | Sivil fabrikanın %88'i: kuluçka salonları, soğuk oda, dolum hattı, cam şişe atölyesi. Sıradan fabrikadan metrekare başına pahalı, toplamda küçük |

Bir eyalette 12 fabrikanın çalıştığı bir şantiyede (`max_factories_per_project: 12`) enstitü ≈ 121 gün, saha laboratuvarı
≈ 20 gün, aşı tesisi ≈ 158 gün sürer (altyapı ve istikrar çarpanları hariç). Bu, oyunun ritmine uyar: **saha laboratuvarı
ilk ayın, enstitü ilk çeyreğin, aşı tesisi ikinci yılın işidir.**

### 4.2 Katalog
`shared` = fabrika/tersaneyle aynı eyalet slotunu kullanır (gerçek bir fırsat maliyeti). BKP = bilim kapasitesi puanı (§4.3).
Kadro = çalışması için gereken bilim insanı (§5). Yük = sağlık yükü puanı (§4.5).

| Bina (`kimlik`) | EN / TR | Maliyet | Slot | Max/eyalet | Şart | BKP | Kadro | Yük | Ne yapar |
|---|---|---|---|---|---|---|---|---|---|
| `zm_field_lab` | Field Laboratory / Saha Laboratuvarı | 240 | serbest | 2 | — | 1 | 2 | 1 | Eyalette tespit oranı +0,10, bildirim gecikmesi −1 (03_salgin_modeli.md §8'deki tespit ve tarama modeline girer); G1 numune işler; suş payını görünür kılar (pay ≥ 0,25) |
| `zm_specimen_store` | Specimen Store / Numune Deposu | 300 | serbest | 1 | saha lab. ya da enstitü | 1 | 1 | 1 | Numune ömrü 10 → 60 gün; aynı anda 3 numune; kaza çarpanı ×0,7 (dağınık saklama yok) |
| `zm_quarantine_hospital` | Quarantine Hospital / Karantina Hastanesi | 520 | serbest | 2 | `zm_notifiable_disease` | 1 | 3 | 2 | Eyalette β −%10; serum dağıtım kapasitesi +; Kızgın tetiği (hastane taşması) −%40; G1 numune |
| `zm_serum_stables` | Serum Stables / Serum Ahırı | 640 | serbest | 1 | `zm_serotherapy` | 1 | 2 | 2 | Ülke serum serbest bırakma kapasitesi +15.000 doz/gün |
| `zm_teaching_hospital` | Teaching Hospital / Üniversite Hastanesi | 1.100 | **shared** | 1 | nüfus ≥ 400.000, kategori ≥ `city` | 3 | 3 | 3 | Bilim insanı tavanı **+6**; eyalette β −%6; G1 numune; kaza sonrası iyileşme hızlı |
| `zm_research_institute` | Research Institute / Araştırma Enstitüsü | 1.450 | **shared** | 1 | nüfus ≥ 250.000 | 4 | 6 | 3 | Araştırma hızı kademesi (§4.3); G2 numune işler; suş tipleme; proje başına numune bonusu uygular |
| `zm_containment_wing` | Containment Wing / Muhafaza Kanadı | 700 | serbest | 1 | aynı eyalette enstitü | 2 | 3 | 2 | Muhafaza düzeyi M2 → M3 (§7.1); **G3 (sürü) numunesi ancak burada tutulur**; kaza çarpanı ×0,35 |
| `zm_vaccine_works` | Vaccine Works / Aşı Üretim Tesisi | 1.900 | **shared** | 2 | `zm_egg_culture` | 1 | 5 | 4 | Aşı serbest bırakma kapasitesi +40.000 doz/gün; eyalette dağıtım kapasitesi ×1,5 |

**Neden "shared" olanlar tam da bunlar?** Enstitü, üniversite hastanesi ve aşı tesisi bir sanayi eyaletinin kıt slotunu
yer; yani **bilim, fabrikadan çalınan yerdir**. Saha laboratuvarı, karantina hastanesi ve numune deposu kıtlık yaratmadan
her yere kurulabilir: 1936 devleti bunları kışlaya, okula, hastane kanadına sığdırırdı.

### 4.3 Araştırma hızı: BKP kademeleri
Toplam BKP, ülkenin **sahibi ve denetleyicisi kendisi olan, düşmüş olmayan** eyaletlerindeki binalardan ve **kadrosu tam**
olanlardan sayılır (kadro eksikse o binanın BKP'si yarıya iner). Kademeler ulusal durum (spirit) olarak verilir:
`rules.gd` her gün doğru kademeyi hesaplar, değiştiyse eskisini kaldırıp yenisini ekler (`spirit` / `remove_spirit`
etkileri motorda var). Böylece bonus **Hükümet panelinde görünür**, kayda kendiliğinden girer, motor değişmez.

| Kademe (`zm_science_base_*`) | BKP | `research_speed` | Tipik sahibi |
|---|---|---|---|
| — | 0–2 | +0,00 | Hiç yatırım yapmamış ülke |
| 1 | 3–6 | +0,06 | 1 enstitü + 1 saha laboratuvarı |
| 2 | 7–12 | +0,12 | 2 enstitü + destek, ya da 1 enstitü + muhafaza + hastane |
| 3 | 13–20 | +0,20 | Orta büyük ülkenin olgun ağı |
| 4 | 21–34 | +0,28 | Büyük güç |
| 5 | 35+ | +0,34 | Bilime kilitlenmiş büyük güç |

Azalan getiri kasıtlıdır: ikinci enstitü birinciyi çoğaltır, katlamaz; 1930'larda ilerlemeyi bina değil, birkaç kişi ve
birkaç yöntem belirliyordu. Tavan +0,34, danışman (+0,07), yasa (+0,01…+0,07) ve teknolojiyle birlikte hız ~1,50'ye kadar çıkar.

**Araştırma yuvası:** BKP ≥ 10'da +1, BKP ≥ 25'te +1 daha (en çok +2; `research_slot` etkisi). Bir kez verilir;
`rules.gd` verildi bayrağını kayda yazar (BKP düşse de yuva geri alınmaz — kurulan kurum kolay dağılmaz).

### 4.4 Numune ve proje işleme
Bir numunenin araştırma bonusuna dönüşmesi için **numuneyi işleyebilen bir bina** gerekir (§6.2). Enstitüsü olmayan ülke
G1'i saha laboratuvarında işler ve yalnız 0,15 bonus alır; G3'ü hiç işleyemez. Bu, "önce kurum, sonra bilim" sırasını
veri düzeyinde zorlar.

### 4.5 Bakım: sağlık yükü
Temel oyunda binaların bakım gideri yoktur; yeni bir gider sistemi icat etmiyoruz. Bunun yerine sağlık aygıtının
sivil üretimi yemesi mevcut **tüketim malı** kanalıyla verilir: `rules.gd` yük oranını hesaplar
`r = Σ yük / (sivil + askerî fabrika + tersane)` ve kademeli bir ulusal durum ekler.

| Kademe (`zm_health_burden_*`) | r | `consumer_goods_mod` | Örnek |
|---|---|---|---|
| — | < 0,10 | +0,00 | 20 fabrikalı ülkede 1 enstitü + 1 laboratuvar (yük 4) |
| 1 | 0,10–0,20 | +0,01 | 20 fabrika, yük 3–4 |
| 2 | 0,20–0,35 | +0,02 | 14 fabrikalı Türkiye, yük 4 (enstitü + laboratuvar) |
| 3 | 0,35–0,55 | +0,035 | Küçük ülkenin geniş sağlık ağı |
| 4 | ≥ 0,55 | +0,05 | Fabrikasız ülkenin bilim hevesi |

Gerekçe: %1 tüketim malı, 20 fabrikalı bir ülkede 0,2 fabrikaya denktir; kademe 2'de (+%2) bilim ağı yaklaşık yarım
fabrikaya mal olur. Bu, bir binanın inşaat maliyetinin yanında küçük ama ihmal edilemez bir kalemdir ve "her önlemin
bedeli vardır" sütununu bina düzeyinde de geçerli kılar.

### 4.6 Merkezler düşerse, tahliye edilirse
| Durum | Sonuç |
|---|---|
| Eyalet **SALGIN** (02 §2.5) | Bina çalışır; kaza çarpanı ×1,3; kadro kaybı riski (günde %0,2 personel) |
| Eyalet **DÜŞMÜŞ** (controller = `UND`) | BKP 0; kadro **kaybedilir** (tahliye edilmemişse); numune deposu varsa "sızıntı" olayı olasılığı %25 |
| **Tahliye** kararı (`zm_evacuate_institute`, 60 nüfuz, 21 gün) | Kadronun %80'i ve suş verisi korunur; numuneler yok edilir; bina kaybı sayılmaz (yeniden inşa gerekir) |
| Eyalet geri alınırsa | Bina hasarlı döner: 60 gün BKP yarım ("onarım"), kadro yeniden atanmalı |
| Aşı tesisi düşerse | Serbest bırakma kapasitesi hemen düşer; stoktaki doz kalır (dağıtım kapasitesi sınırlar) |

## 5. Personel: bilim insanı

### 5.1 Havuz nereden gelir?
Yeni bir nüfus sistemi kurulmaz; havuz mevcut verilerden **türetilir** ve bir tavandır (zaman serisi değil):

```
bilim_insanı_tavanı = floor( 2 + 0,30 × (sivil + askerî fabrika + tersane) + 0,6 × √(nüfus / 1.000.000) )
                      + 6 × üniversite hastanesi + olay/program katkıları
```

Gerekçe: 1936'da bir devletin laboratuvar kadrosu iki şeye bağlıydı — teknik sanayi tabanı (cam, optik, kimya, tezgâh;
depoda fabrika sayısıyla temsil edilir) ve hekim/öğretmen havuzunun büyüklüğü (nüfusla artar ama doğrusal değil, bu yüzden
karekök). Sabit 2, en küçük devletin bile bir sağlık müdürlüğü ve bir hastane laboratuvarı olduğunu söyler.
Katsayılar `data/history/states_1936.json` ve `data/map/states.json` üzerinde ölçüldü; sonuç aşağıdaki dağılımı verir
(dünya toplamı 550, medyan 5).

| Ülke | Fabrika | Nüfus | Tavan | Ne kurabilir (kadro sınırıyla) |
|---|---|---|---|---|
| ABD | 68 | 129,7 M | **29** | 3 enstitü + muhafaza + hastane + tesis |
| Sovyetler | 57 | 161,0 M | **26** | 3 enstitü + destek |
| Birleşik Krallık | 49 | 133,6 M | **23** | 2 enstitü + muhafaza + 2 hastane |
| Japonya | 50 | 96,4 M | **22** | 2 enstitü + tesis + destek |
| Almanya | 52 | 67,6 M | **22** | 2 enstitü + muhafaza + hastane |
| Fransa | 47 | 112,2 M | **22** | 2 enstitü + destek |
| İtalya | 36 | 45,8 M | **16** | 2 enstitü, muhafazasız |
| Polonya | 15 | 31,5 M | **9** | 1 enstitü + laboratuvar + depo |
| Romanya | 14 | 19,6 M | **8** | 1 enstitü + laboratuvar |
| **Türkiye** | 14 | 16,0 M | **8** | 1 enstitü (6) + 1 saha laboratuvarı (2) — sonrası üniversite hastanesine bağlı |
| İsveç | 15 | 6,2 M | **8** | 1 enstitü + laboratuvar |
| İsviçre | 9 | 4,1 M | **5** | 1 saha lab. + karantina hastanesi; enstitü için hastane şart |
| Etiyopya | 2 | 10,0 M | **4** | 2 saha laboratuvarı; enstitü kadrosu yok |
| Afganistan | 1 | 7,0 M | **3** | 1 saha lab. + depo |

**Tasarım sonucu:** enstitü 6 kadro ister; bu, 80 ülkenin yarısının **tek başına enstitü kuramaması** demektir.
Çıkış yolları: üniversite hastanesi (+6 tavan), "Bilim İnsanı Mültecileri" olayı (§10.7), ortak enstitü ve tıbbi heyet (§9).
01 Sütun 5 ("kimse tek başına kurtulamaz") burada bir tabloya dönüşür.

**Sömürgeler:** Havuz tavanı ülke düzeyindedir ve sömürge nüfusu da sayılır; ayrıca ceza yoktur. Tarihî eşitsizlik
(sömürgede kurum azlığı) **binaların başlangıç dağılımıyla** temsil edilir: 1936 senaryosunda hiçbir ülkenin sağlık binası
yoktur, yani herkes sıfırdan başlar; fakat anavatan dışı eyaletlerde `category` çoğunlukla `rural`/`town` olduğu için
üniversite hastanesi ve enstitü şartları (nüfus, kategori) daha az yerde sağlanır. Bu bir ceza değil, coğrafyanın sonucudur
ve oyuncu altyapı yatırımıyla düzeltebilir (01 §6.4).

### 5.2 Kadro atama kuralları
| Kural | Ayrıntı |
|---|---|
| Atama oyuncunun eylemidir | Yeni bina bitince "Kadrosuz" başlar; salgın panelinde **Kadro ata** düğmesi vardır. `auto_staff` kapalı başlar; açıksa inşa sırasına göre atanır (CLAUDE.md kural 1) |
| Kadrosuz bina | BKP yarım, numune işlemez, kaza çarpanı ×2 (denetimsiz laboratuvar) |
| Kadro kaybı | Kaza (1–4 kişi), düşmüş eyalet (tamamı), olaylar. Kayıp tavanı düşürmez, **atanmış kadroyu** boşaltır; yeniden atama için havuzda yer açılmalı |
| Kadro kazancı | Üniversite hastanesi (+6 tavan), olaylar, paylaşım anlaşmaları (§9), "Tıp Fakültesi Seferberliği" programı |
| Uyarı | Uyarı şeridinde "Kadrosuz araştırma merkezi" (mevcut `alert_bar.gd` kalıbı) |

## 6. Numune: bilimin askerî yüzü

### 6.1 Neden askerî iş?
Etken canlı dokuda incelenir; doku enfekte insandan ya da Boş'tan gelir. Bu yüzden numune, 01 Sütun 4'ün ("bilim zamanla
yarışır") haritaya bağlandığı yerdir: **numune almak için bir yere gitmek, bir riski kabul etmek gerekir.**
Dayanak: 1910–11 Mançurya vebasında Wu Lien-teh'in tanıyı doğrulaması için otopsi ve saha laboratuvarı kurması;
sarı humma çalışmalarında araştırmacıların numune ve deney hayvanıyla sahada çalışması.

### 6.2 Numune sınıfları
| Sınıf | EN / TR | Nereden | Şart | Süre | Bonus (`research_bonus.value`) | Risk |
|---|---|---|---|---|---|---|
| G1 | Clinical sample / Klinik numune | Kendi eyaletindeki hastaneden (F > 0) | Karantina ya da üniversite hastanesi; işlemek için saha lab. | 3 gün | 0,15 | Yok |
| G2 | Field sample / Saha numunesi | Enfekte eyalet (kordon hattı, `SALGIN` ya da `BİLDİRİLMİŞ`) | O eyalette **en az 1 tümen**; işlemek için enstitü | 7 gün | 0,35 | Ekip kaybı %4; o tümende ordu içi bulaş +0,5 puan (%2) |
| G3 | Horde sample / Sürü numunesi | `UND` denetimindeki bölgeden canlı Boş | O bölgede kazanılmış muharebe ya da "baskın" emri (≥ 3 tümenli ordu); **muhafaza kanadı** zorunlu | 14 gün | 0,60 | Ekip kaybı %12; ordu içi bulaş +1,5 puan; 60 gün kaza çarpanı ×4 |
| G4 | Strain sample / Suş numunesi | Bir soyun payı ≥ 0,10 olan eyalet | `zm_strain_typing` + enstitü | 10 gün | — (yerine **suş keşfi**, 04 §7.4) | G2 ile aynı |

Değerlerin gerekçesi: motorun `research_bonus` alanı maliyeti `1 + value`'ya böler. 0,15 → −%13, 0,35 → −%26, 0,60 → −%37.
Aralık bilinçli olarak dar tutuldu: numune **hızlandırır**, atlatmaz. Motor bir projede yalnız **ilk uyan bonusu** kullanır
(`Research.start`), yani numuneler üst üste binmez; oyuncu "hangi projeye hangi numuneyi" sorusunu yanıtlar.

### 6.3 Akış (durum makinesi)
```
 [Hedef seç]  panelde uygun eyalet listesi (G1/G2/G3/G4 ayrı sekmeler)
      │ nüfuz: 20 (G1) / 40 (G2) / 70 (G3) / 40 (G4)
      ▼
 [Ekip yolda]  süre = sınıf süresi + taşıma (demiryolu/gemi: 300 km başına 1 gün, en çok 12)
      │  başarısızlık: ekip kaybı zarı; başarısızsa "Ekip Dönmedi" olayı
      ▼
 [Numune elde]  ömür: buzda 10 gün · numune deposunda 60 gün
      │  bekleyen numune sayısı: depo yoksa 1, deposu varsa 3
      ▼
 [İşleme]  bina şartı sağlanırsa: research_bonus eklenir (uses = 1) → ilk başlatılan projede kullanılır
      │  G4: suş keşfi + dünya soy tablosuna kayıt
      ▼
 [Tükendi]  panelde "kullanıldı" olarak 30 gün görünür (oyuncu neyi neye harcadığını görsün)
```

Uyarı şeridi: "Numune bozuluyor (3 gün)", "Boş araştırma merkezi", "İşlenmemiş numune".

### 6.4 Ordu içi bulaşla bağ
04 §2.5'teki `Division.infected` alanı numune operasyonlarında artar. Sonuç: G3'ü ucuz sanan oyuncu kordon ordusunu
hastalandırır ve 04 T05 (Kaputlu) havuzunu besler. İpucu metni: *"Sürüden numune almak, sürüyü birliğinize davet etmektir."*

## 7. Muhafaza düzeyleri ve laboratuvar kazaları

### 7.1 1936'nın muhafazası: üç düzey
Biyogüvenlik düzeyleri (BSL-1…4) bir **1984 sonrası** çerçevedir (ABD'de BMBL'nin ilk baskısı 1984); sınıf III eldivenli
kabin 1943'te, kısmi korumalı sınıf I kabin 1950'lerin ortasında çıktı. Yani **1936'da BSL yoktur ve dördüncü düzeyin
karşılığı da yoktur.** Mod, dönemin gerçek pratiğinden üç düzey tanımlar ve bugünün tanımlarına yalnız *karşılaştırma*
olarak bağlar:

| Düzey | 1936'da ne demek | Bugünün ölçütüyle kabaca | Kaza çarpanı | Nerede |
|---|---|---|---|---|
| **M1 — Saha düzeyi** | Tezgâhta çalışma, alev sterilizasyonu, karbolik asit, gazlı bez maske, ağızla pipetleme | BSL-1/2 arası pratik | ×1,0 | Saha laboratuvarı, hastaneler |
| **M2 — Enstitü düzeyi** | Ayrı hayvan barınağı, otoklav, kilitli giriş, kayıtlı numune, personelin aşılanması | BSL-2 | ×0,5 | Araştırma enstitüsü |
| **M3 — Muhafaza kanadı** | Ayrı blok, tek yönlü koridor, kimyasal geçiş odası, baca çekişli tek yönlü havalandırma, otoklavlı geçiş, yakma fırını, laboratuvarda yeme-içme yasağı | BSL-3'ün 1936'da yapılabilen kadarı | ×0,35 | Muhafaza kanadı (G3 numune için zorunlu) |

`zm_lab_discipline` araştırması (pipetleme yasağı, kayıt disiplini, personelin serumla korunması) ayrıca ×0,6 verir.
Dayanak: Pike'ın 3.921 laboratuvar kaynaklı enfeksiyon derlemesinde vakaların yalnız **%18'i bilinen bir kazaya**
bağlanabilmişti; yani ekipmandan çok **günlük disiplin** belirleyicidir.

### 7.2 Kaza olasılığı
```
P_yıl(enstitü) = 0,12 × düzey × Π(çarpanlar)          (en çok 0,90)
p_gün          = 1 − (1 − P_yıl)^(1/365) ≈ P_yıl / 365
```
**Taban 0,12 nasıl bulundu?** Modern yüksek muhafazalı laboratuvar için literatürdeki tahmin ~**0,002 enfeksiyon /
laboratuvar-yılı**'dır (BSL-3 verisinden). 1936'da kabin, HEPA süzgeç ve tek kullanımlık malzeme yoktur ve mod
laboratuvarları hem araştırma hem üretim ölçeğinde çalışır. Tarihî büyüklük mertebesi bunu doğrular: 1898 Viyana'da bir
veba laboratuvarı kazası bir laboratuvar görevlisi, onu tedavi eden hekim ve bir hemşirenin ölümüyle sonuçlandı;
1927–28'de sarı humma araştırmacıları arasında ölümler oldu; 1931'de tek bir laboratuvarda yedi laboratuvar kaynaklı sarı
humma vakası bildirildi (hepsi iyileşti); Sulkin ve Pike'ın 1951 taraması yaklaşık 5.000 laboratuvarda 1.342 vaka ve
39 ölüm saydı. Modern ölçütün **60 katı** (0,12) bu tabloya uyar ve oyun için ölçülebilir bir sıklık verir.

| Çarpan | Değer | Gerekçe |
|---|---|---|
| Muhafaza düzeyi M1 / M2 / M3 | 1,0 / 0,5 / 0,35 | §7.1 |
| `zm_lab_discipline` | ×0,6 | Pike: kazaların %18'i "bilinen kaza" |
| Personeli serum/aşı ile koruma (stokta ayrılmış doz) | ×0,5 | Dönemin pratiği: tifüs aşısı geliştiren laboratuvarda personel önce aşılanıyordu |
| Kadro eksik | ×2,0 | Denetimsiz iş |
| Numune deposu yok | ×1,5 | Dağınık, kayıtsız saklama |
| Elde **G3 (canlı Boş) numunesi** var | ×4,0 | Canlı, saldırgan konak |
| **Seri pasaj** projesi çalışıyor (13) | ×2,5 | Yüksek titreli canlı kültürle sürekli çalışma |
| Eyalet salgın hâlinde | ×1,3 | Dışarıdan gelen vaka baskısı, yorgun kadro |

**Üç profil (4 yıllık kampanya, kaza *beklenen sayısı*):**

| Profil | Çarpanlar | P_yıl | 1 enstitü / 4 yıl | 3 enstitü / 4 yıl |
|---|---|---|---|---|
| İhtiyatlı | M3 × disiplin × korunmuş kadro (0,35 × 0,6 × 0,5) | 0,0126 | **0,05** | 0,15 |
| Dengeli | M2 × disiplin (0,5 × 0,6) | 0,036 | **0,14** | 0,43 |
| Acele (seri pasaj + G3, kanatsız, kadrosuz) | 1,0 × 4 × 2,5 × 2 × 1,5 → tavan | 0,90 | **3,6** | 10,8 |

Yani: **doğru yapan oyuncu kampanya boyunca büyük olasılıkla hiç kaza görmez.** Kaza bir vergi değil, risk almanın bedelidir.
"Acele" profili yalnız G3 numunesi elde tutulduğu sürece geçerlidir; numune işlenir işlenmez çarpan düşer.

### 7.3 Kaza çıkarsa ne olur?
Bir kaza tetiklendiğinde şiddet zarı atılır (tohumlu RNG, kayda yazılır — belirlenimcilik):

| Şiddet | Olasılık | Sonuç |
|---|---|---|
| **Maruz kalma** | %60 | 1–2 kadro karantinaya (14 gün çalışamaz); proje ilerlemesi 10 gün durur; "Kaza" olayı (§10.5) |
| **Enstitü içi salgın** | %30 | 2–4 kadro kaybı (biri Boş'a döner, olay metninde soyut anlatılır); bina 30–60 gün kapalı; eyalette bildirilen vaka +; istikrar −%3 |
| **Sızıntı** | %10 | Eyalete 8–40 kişilik gizli E tohumlanır (02 §2.1); bulaş normal yoluna girer. Seri pasaj çalışıyorsa sızan soyun **Soluk** olma olasılığı %50 (04 T13); değilse baskın soy sızar |

Yapay zekâ ülkelerinde aynı kurallar işler; sızıntı bülten satırıyla dünyaya duyurulabilir (saklamak da mümkündür, §10.5).

### 7.4 Aşı güvenliği: kirli parti
Üretim kazası ayrı bir koldur. Dayanak: 1930 Lübeck'te ağızdan verilen BCG partisinin virülan basille kirlenmesi sonucu
251 bebekten 77'si öldü (67'si tüberkülozdan); soruşturma laboratuvar disiplininin bozukluğunu buldu.
Modda: `zm_vaccine_works` üretimi varsa her 100.000 dozda bir "parti denetimi" zarı atılır; temel kirlenme olasılığı
**%1,5**, `zm_vaccine_potency` ile **%0,45**, muhafaza kanadı olan ülkede ×0,7. Olay §10.2'dir. Kirli parti dağıtılırsa
dağıtılan doz kadar V yerine F üretilir ve istikrar −%12, aşı güveni (dağıtım hızı) 180 gün −%40 olur.

## 8. Tedavi ve aşı: üretimden kola

### 8.1 Ekipman (üretim hattı)
Serum ve aşı mevcut üretim motorunda üretilir: `cost` = birim başına **fabrika-saat**; bir askerî fabrika günde
24 fabrika-saat çalışır; verimlilik %15'ten başlar, %50 (+teknoloji) tavanına yaklaşır.

| Ekipman | 1 birim | Cost (fabrika-saat) | Kaynak | Açan | Gerekçe |
|---|---|---|---|---|---|
| `zm_serum_dose` | 10.000 doz | 12 | kauçuk 1 | `zm_hyperimmune_serum` | Topçu (19) ve kamyon (13) ölçeğinde bir sanayi kalemi; cam şişe ve kauçuk tıpa |
| `zm_vaccine_dose` | 10.000 doz | 20 → **12** (`zm_egg_culture` ile ×0,6) | kauçuk 1, alüminyum 1 | `zm_vaccine_live` / `zm_vaccine_killed` | Kuluçka yumurtasında üretim (1931 yöntemi) ölçeği ucuzlatır |
| `zm_medical_supplies` | 10.000 set | 6 | çelik 1 | `zm_gauze_masks` | Maske, bez, dezenfektan; dağıtıldığı eyalette β −%5 (üstü ekilmez) |

12 askerî fabrikalı bir hat, %50 verimlilikte günde 144 fabrika-saat üretir → **12 birim = 120.000 doz/gün**.
16 milyonluk bir ülkede %60 kapsam 9,6 milyon doz ister: üretim yalnız 40 gün sürer. Yani **üretim darboğaz değildir**;
darboğaz serbest bırakma ve dağıtımdır (aşağıda). Bu kasıtlıdır: 1938'de 17D aşısıyla yaklaşık 1,06 milyon kişinin
aşılanması, üretimin değil örgütlenmenin ölçeğini gösterir.

### 8.2 Serbest bırakma kapasitesi (ülke)
Üretilen doz doğrudan kullanılamaz; denetlenmesi, dolumu ve ambalajlanması gerekir. Bu, binaların anlamıdır:

```
serum_serbest/gün = (5.000 + 15.000 × serum ahırı) × (1,5 if zm_serum_standardisation) × (1,25 if zm_filling_line)
aşı_serbest/gün   = (10.000 + 40.000 × aşı tesisi) × (1,25 if zm_filling_line)
```
Fazlası stokta "denetim bekleyen doz" olarak durur ve panelde ayrı gösterilir (tarihî dayanak: Milletler Cemiyeti Sağlık
Teşkilatı'nın 1923–24'te kurduğu Biyolojik Standartlar Daimî Komisyonu ve serum birimlerinin uluslararası standardı).

### 8.3 Dağıtım kapasitesi (eyalet)
```
D_s (doz/gün) = N_s × ( 0,002 + 0,003 × (karantina hast. + üniversite hast.) + 0,001 × altyapı seviyesi )
                × (1,5 if zm_cold_chain) × (1,5 if aşı tesisi aynı eyalette)
en çok 0,015 × N_s        (02 §4.1: günde nüfusun %1,5'i)
```
| Örnek eyalet (1 M nüfus) | Bina/altyapı | D_s | Nüfusun payı |
|---|---|---|---|
| Kırsal, altyapı 0 | — | 2.000 | %0,2 |
| Kasaba, altyapı 2 | karantina hastanesi | 7.000 | %0,7 |
| Şehir, altyapı 3 | karantina + üniversite hastanesi + soğuk zincir | 16.500 → tavan **15.000** | %1,5 |

Dağıtım oyuncunun emridir: panelde eyalet seçilir, "serum gönder" / "aşı gönder" denir; `auto_serum` ve `auto_vaccine`
kapalı başlar (02 §7.3). Öldürülmüş aşı iki doz ister → o yolda etkin dağıtım ×0,6.

### 8.4 Serumun ve aşının etkisi
| Ürün | Etki | Etkinlik | Notlar |
|---|---|---|---|
| Serum | E ve F → R (bağışık) | 0,60 → 0,75 (`zm_serum_standardisation`) → 0,85 (`zm_type_specific_serum`) | Dirençli suşta ×0,5; Serum II bunu geri alır (04 T12). `zm_isolation_wards` ile uygulanan doz başına verim +%20 |
| Aşı | S → Vb → V (10 gün gecikmeli) | Canlı 0,90 (+0,05 `zm_vaccine_potency`) · öldürülmüş 0,75 | 02'deki `V_c = clamp((1 − 1/R_etkin)/etkinlik; 0,40; 0,90)` formülünde "0,9" yerine **seçilen aşının etkinliği** kullanılır |
| Soluk suşla gönüllü aşılama | S → R (%80), ölüm %3, zayıf Boş %17 | — | 04 §9.2'deki olay; yalnız etken tanımlandıktan sonra |

**03_salgin_modeli.md ile uyum.** Salgın modeli belgesi serum etkinliğini geçici olarak `e_Z = 0,8` alıp "araştırma
belgesinde kesinleşir" demiştir; burada kesinleşen üç basamaklı merdiven (0,60 / 0,75 / 0,85) o değeri ortadan kuşatır.
Uygulamada `e_Z` sabit değil, ülkenin araştırma durumundan okunan bir değerdir; 03 §3.2'deki `serum` terimi bu değeri
kullanır. Aşı tarafında 03'ün `S → Vb → V` (10 günlük bağışıklık gecikmesi) ve "E'ye giden doz boşa gider" kuralları
aynen geçerlidir: bu yüzden **dağıtılan doz ile kapsam birbirine eşit değildir** ve panelde "boşa giden doz" ayrı görünür.

**Öldürülmüş aşıyı seçmenin bedeli sayıyla:** R_etkin = 2,0'da V_c canlı aşıyla %56, öldürülmüş aşıyla %67; üstüne iki doz
ve ×0,6 dağıtım → aynı kapsama ulaşmak yaklaşık **2 kat** uzun sürer. Karşılığı: Soluk suş riski yok, kaza çarpanı düşük,
araştırma yolu kazasız. Tablo oyuncuya olay ekranında gösterilir.

### 8.5 Kapsam takvimi (örnek)
16 milyonluk bir ülke, aşı 648. günde, 2 aşı tesisi (90.000 doz/gün serbest), üç büyük eyalette toplam 45.000 doz/gün dağıtım:

| Gün | Olan | Kapsam |
|---|---|---|
| 648 | Aşı bitti; üretim hattı kurulur (12 fabrika) | %0 |
| 663 | İlk 1,2 M doz serbest; başkent ve iki liman eyaletinde dağıtım | %4 |
| 743 | Günlük 45.000 doz sürüyor | %26 |
| 863 | Soğuk zincir bitti, dağıtım 67.500/gün | %60 → **V_c (R 2,0'da %56) aşıldı** |
| 933 | Temiz ilan sayaçları dolar (42 gün) | Tedavi Zaferi denetimi |

02 §5'in "aşıdan +90–180 gün" bandıyla uyumludur (burada +215 gün, çünkü örnek ülke yalnız 3 eyalette dağıtıyor;
daha çok hastane ve altyapıyla bant içine iner). Oyuncuya ipucu: *"Aşıyı bulmak altı ay; halka ulaştırmak bir yıl."*

## 9. Uluslararası işbirliği ve bilgi paylaşımı

Uluslararası sağlık kurumu yapay zekânın yürüttüğü bir aktördür (01 §3b): bülten yayımlar, paylaşıma aracılık eder.
Bütün eylemler mevcut diplomasi ve olay motoruyla yürür; her biri hem kazanç hem sızıntı riski taşır.

| Eylem (EN / TR) | Bedel | Kazanç | Risk / bedel |
|---|---|---|---|
| Share findings / Bulguları paylaş | 60 nüfuz | Karşı tarafa `research_bonus` 0,40 (bir proje); karşılıklılık sayacı +1 | Rakip önce bitirebilir; "kim bulduysa aşıyı o dağıtır" |
| Request findings / Bulgu iste | 40 nüfuz + karşılıklılık | Sende olmayan tamamlanmış bir projeye 0,40 bonus | Reddedilirse itibar; kabul için karşılıklılık ≥ 1 gerekir |
| Medical mission / Tıbbi heyet gönder | 3 kadro + 60 nüfuz, 90 gün | G2 numune + yardım puanı (+0,1) + hedef ülkede β −%5 | Heyet üyesinin %10 olasılıkla kuluçkada dönmesi (02 §9) |
| Joint institute / Ortak enstitü | Her iki taraf 700 fabrika-gün + 3 kadro | İkisi de BKP +4 sayar; biri çökse diğeri korur | Saldırmazlık/ittifak şartı; ortak çökerse 90 gün BKP yarım |
| Standards commission / Standart Birim Komisyonu | 80 nüfuz + serum verisi | Üye olan **herkeste** serum etkinliği +0,15; üyelerin serum/aşı durumu görünür | Üyelik dışında kalan avantaj sağlamaz; veri paylaşmak rakibe de yarar |
| Surveillance pool / Gözetim havuzu | 40 nüfuz/yıl | Cuma bülteni bütün üyeler için +%20 doğruluk (tespit ve gecikme) | Tipik bir kamu malı sorunu: katkısız üye de yararlanır; 3 yıl katkı yapmayan düşer |
| Vaccine diplomacy / Aşı diplomasisi | Doz | Yardım puanı (02 puanının 150 puanlık kalemi), itibar, koruma altına alma kolaylığı | Kendi kapsamın gecikir |

**Yapay zekânın kabul formülü** (mevcut diplomasi tutumu üzerinden):
```
kabul_şansı = clamp( 0,15 + 0,004 × tutum + 0,25 × karşılıklılık + 0,010 × KSE
                     − 0,30 × (rakip mi) − 0,20 × (aynı zaferin peşinde mi) , 0,02 , 0,95 )
```
Yani **salgın büyüdükçe dünya işbirliğine daha açık olur** (KSE terimi): KSE 40'ta +0,40. Dayanak: 1910–11 Mançurya
vebasında Çinli, Rus ve Japon demiryolu yönetimlerinin ortak karantinası ve 1926 Uluslararası Sıhhiye Sözleşmesi'nin
bildirim yükümlülüğü.

**Kurumsal dayanak notu (yardım ekranında):** Milletler Cemiyeti Sağlık Teşkilatı'nın Singapur bürosu 1925'ten itibaren
salgın bültenini haftalık telsizle yayımlıyordu; Biyolojik Standartlar Daimî Komisyonu 1923–24'te serum birimlerini
standartlaştırdı; Pasteur enstitüleri ağı ve Rockefeller Vakfı Uluslararası Sağlık Bölümü 1930'larda saha laboratuvarları
işletiyordu. Modun "komisyon" ve "havuz" mekanikleri bu kurumsal biçime dayanır; adlar bizimdir.

## 10. Olaylar: kazalar ve etik ikilemler

Hepsi 2–3 **gerçek** seçeneklidir; etkiler mevcut etki sözlüğü ve modun yeni anahtarlarıyla yazılır (§12.4).
Ton: 1930'ların resmî dili; kan ve vahşet yok (01 §6).

### 10.1 "Gönüllüler" / "The Volunteers"
> EN: *"The institute has a serum but no proof. The director proposes a trial: twenty volunteers, a written contract in two
> languages, a physician at each bedside, and payment to the families whatever the outcome."*
> TR: *"Enstitünün serumu var, kanıtı yok. Müdür bir deneme öneriyor: yirmi gönüllü, iki dilde yazılı sözleşme, her başucunda
> bir hekim ve sonuç ne olursa olsun ailelere ödeme."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Yazılı rızayla, ödemeli deneme | Serum etkinliği +0,05 kalıcı; `zm_serum_standardisation` maliyeti −%20 | 40 nüfuz; gönüllülerin %10'u ölür → istikrar −%2; basında tartışma |
| Hastalarda, rızayı sorma | **Hiçbir hız kazancı yok**; sonuçlar güvenilmez (etkinlik +0) | İstikrar −%8; uluslararası itibar −; 180 gün paylaşım tekliflerinde kabul şansı −0,25 |
| Denemeyi erteleme | — | Serum etkinliği 0,60'ta kalır; standart araştırması normal maliyet |

Dayanak: 1900'de sarı humma çalışmasında gönüllülere İngilizce ve İspanyolca yazılı sözleşme verilmesi ve ödeme yapılması,
yazılı bilgilendirilmiş onamın ilk örneklerinden sayılır. Modda **rıza yolu ödüllendirilir, rızasız yol ödüllendirilmez**.

### 10.2 "Kirlenen Parti" / "The Tainted Batch"
> EN: *"A control sample from the new vaccine batch has grown something it should not have. Two hundred thousand doses are
> crated and waiting at the railhead."* TR: *"Yeni aşı partisinden alınan denetim örneğinde olmaması gereken bir şey üredi.
> İki yüz bin doz sandıklanmış, istasyonda bekliyor."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Partiyi yak, hattı temizle | Risk sıfır; parti denetim olasılığı 120 gün −%50 | 200.000 doz kaybı; üretim 14 gün durur |
| 21 gün bekletip yeniden denetle | %85 temiz çıkar ve dağıtılır | 21 gün gecikme; bu sürede aşı dağıtımı durur |
| Sevk et | Doz hemen dağıtılır | %30 gerçekten kirli: dağıtılan doz kadar S → F; istikrar −%12; aşı güveni 180 gün −%40; soruşturma olayı |

Dayanak: 1930 Lübeck olayı (§7.4).

### 10.3 "Numune mi, Hat mı" / "Sample or Line"
> TR: *"Enstitü canlı bir örnek istiyor. Elinizdeki tek yedek tümen kordonun zayıf omzunu tutuyor."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Tümeni baskına ayır | G3 numunesi (bonus 0,60) | Kordonda 14 gün açık; kırılma olasılığı +; ordu içi bulaş +1,5 puan |
| Klinik numuneyle yetin | G1 numunesi (0,15) | Araştırma yavaş kalır |
| Komşudan numune iste | Karşılıklılık harcanır, G2 gelir | 40 nüfuz; komşu reddedebilir (§9 formülü) |

### 10.4 "Seri Pasaj" / "Serial Passage"
> TR: *"Müdür aşıya giden kısa yolu anlatıyor: etkeni yüzlerce kez tavuk embriyosundan geçirmek. Daha hızlı, daha zayıf ve
> laboratuvarda daha canlı bir kültürle çalışmak demek."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Seri pasaj | `zm_attenuation_passage` yolu açılır (aşı yolu toplam −%20 maliyet, 04 §7.5 ile uyumlu) | Kaza çarpanı ×2,5; kazada Soluk suş olasılığı %50 (04 T13) |
| Öldürülmüş etken | `zm_attenuation_inactivated`; kaza çarpanı ×1,0 | Toplam +%20 maliyet; aşı etkinliği 0,75; iki doz |
| İkisini paralel yürüt | İki proje iki yuvayı tutar; hangisi önce biterse o kullanılır | Yuva maliyeti; kaza çarpanı yine ×2,5 |

### 10.5 "Kaza" / "The Accident"
> EN: *"At two in the morning a flask broke in the animal house. Three attendants were in the room. The wing has been locked
> from the inside."* TR: *"Sabah ikide hayvan barınağında bir cam kırıldı. Odada üç görevli vardı. Kanat içeriden kilitlendi."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Kanadı kapat ve bildir | Sızıntı olasılığı −%70; uluslararası itibar +; komisyon üyeliği güçlenir | Enstitü 21 gün kapalı; 10 gün proje durur |
| Sessizce karantinaya al | Bina çalışmaya devam eder | Sızıntı olasılığı tam; haber 60 gün içinde %30 olasılıkla sızar → istikrar −%10, itibar −−, paylaşım kabulü −0,25 |
| Semti boşalt | Sızıntı olasılığı −%95 | O eyalette fabrika çıktısı 90 gün −%10; istikrar −%4; mülteci hareketi |

### 10.6 "Enstitünün Tahliyesi" / "Evacuating the Institute"
Cephe iki eyalet yakınına geldiğinde gelir.

| Seçenek | Etki | Bedel |
|---|---|---|
| Kadroyu ve defterleri taşı | Kadronun %80'i ve suş verisi korunur | 60 gün BKP 0 (yeni yerde kurulum); numuneler yok edilir |
| Son güne kadar çalış | Kesinti yok | Eyalet düşerse kadro tamamen kaybedilir; numune deposu sızıntı riski %25 |
| Her şeyi yak ve çekil | Sızıntı riski 0; kadronun %95'i kurtulur | Bina ve bütün numune/veri kaybı; `zm_strain_typing` keşifleri korunur |

### 10.7 "Bilim İnsanı Mültecileri" / "Refugee Scientists"
> TR: *"Çöken komşudan bir hekim ve bakteriyolog heyeti sınıra ulaştı. Yanlarında bir kültür sandığı ve üç yıllık kayıt var."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Kabul et ve enstitüye ver | Bilim insanı tavanı +4; bir tamamlanmış projeye 0,30 bonus | İstikrar −%2; kültür sandığı karantinaya alınmazsa kaza çarpanı 30 gün ×1,5 |
| Kabul et, karantinada tut | Tavan +4, 30 gün gecikmeli | 20 nüfuz |
| Geri çevir | — | Uluslararası itibar −; yardım puanı −0,05; (oyun bu seçeneği hiçbir sayıyla ödüllendirmez) |

### 10.8 "Söylenti" / "The Rumour"
> TR: *"Üç ilde aynı söylenti: hekimler kuyulara zehir atıyor. Bir aşı ekibi taşlanmış."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Açık bülten ve halk toplantıları | Dağıtım hızı 60 gün içinde eski düzeyine döner; istikrar +%2 | 30 nüfuz; bültende gerçek sayılar rakiplere de görünür |
| Ekipleri jandarmayla gönder | Dağıtım sürer | İstikrar −%6; kordon bölgelerinde direniş olayı olasılığı + |
| Programı o illerde durdur | İstikrar −%1 | 90 gün o eyaletlerde dağıtım yok |

Dayanak: 1830–31 kolera ayaklanmaları, hekimlerin halkı bilerek zehirlediği söylentileriyle başlamıştı (01 §6.3: oyun
gerçeği belirsiz bırakmaz; söylenti yanlıştır, çaresi şeffaflıktır).

## 11. Arayüz ve harita görünümü

### 11.1 Salgın panelinin "Bilim" sekmesi (kısayol **E**, sekme 3)
Yalnız mevcut yardımcılar (`game/ui/panel_layout.gd`): `frame`, `tabs`, `info_cells`, `section`, `table`, `table_row`,
`row`, `row_action`, `small_button`, `progress`, `empty`, `stat`. Yeni görsel stil yok.

```
┌ SALGIN ─────────────────────────────────── [Durum][Eyaletler][BİLİM][Dağıtım] ┐
│ info_cells:  Etken: Tanımlandı ·  Serum: Var (0,75) ·  Aşı: 62%  ·  Bilim insanı: 6/8│
│              Numune: 2 (1 bozuluyor) ·  Kaza riski: Düşük (0,03/yıl)                 │
│ section "Araştırma merkezleri"                                                        │
│ table [Eyalet | Bina | Kadro | BKP | Muhafaza | Risk | ]                              │
│   İstanbul   Enstitü        6/6   4   M3   ×0,21   [Numune ata][Tahliye]             │
│   İstanbul   Muhafaza kanadı 3/3   2   —    —      [—]                                │
│   Ankara     Saha lab.      0/2   0,5 M1   ×2,0    [Kadro ata]                        │
│ section "Numuneler"                                                                   │
│ table [Sınıf | Kaynak | Kalan ömür | Bonus | ]                                        │
│   G2 Saha     Edirne        41 gün   0,35   [İşle → Serum I]                           │
│ section "Projeler"  (Araştırma panelinden okunur; buradan yalnız numune bağlanır)      │
│ row  Serum I — 68/150 · progress · "Numune bağlı: G2 (+%26)"                           │
│ section "Emirler"   row_action: [Numune al…] [Serum gönder…] [Aşı gönder…]             │
│ Kolaylıklar (kapalı başlar): [ ] Otomatik kadro  [ ] Otomatik serum  [ ] Otomatik aşı  │
└───────────────────────────────────────────────────────────────────────────────────────┘
```

### 11.2 Diğer paneller
| Panel | Ek |
|---|---|
| Eyalet paneli (`state_panel.gd`) | Yeni binalar **kendiliğinden** listelenir ve inşa döşemesi olarak çıkar (panel `Economy.defs`'i tarar). Gereken: `BDESC_zm_*` çevirileri ve `building_zm_*` ikonları |
| Araştırma paneli | Dört yeni kategori sekmesi kendiliğinden gelir; teknoloji ipucunda "numune bonusu" ve "yıl cezası" dökümü |
| Üretim paneli | `zm_serum_dose`, `zm_vaccine_dose`, `zm_medical_supplies` hatları; ipucunda "serbest bırakma kapasitesi" satırı |
| İnşaat paneli | Sağlık binaları ayrı bölümde (mevcut `section` ile), maliyet ve slot etkisi görünür |
| Uyarı şeridi (`alert_bar.gd`) | "Kadrosuz araştırma merkezi", "İşlenmemiş numune", "Numune bozuluyor", "Denetim bekleyen doz", "Boş aşı tesisi", "Yüksek kaza riski" |
| Oyun sonu | Puan dökümünde "tıp araştırması" kalemi 13 proje üzerinden |

### 11.3 İpuçlarda şeffaflık
Her sayı dökümüyle gösterilir: `hız 1,15 = 1 + 0,12 (enstitüler) + 0,07 (danışman) + 0,03 (teknoloji)`;
`kaza ×0,21 = M3 0,35 × disiplin 0,6`; `dağıtım 7.000 = 1 M × (0,002 + 0,003 + 0,002)`. Bu, temel oyunun ipucu
geleneğini sürdürür ve tasarım kararını oyuncuya açık eder.

### 11.4 Haritada görünüm
| Yakınlık | Ne görünür |
|---|---|
| Uzak (kamera > 2.300) | Hiçbir şey (harita okunabilir kalır) |
| Orta (640–2.300) | `map_institute`, `map_hospital`, `map_vaccine_works` ikonları (`MapIconLayer` kalıbı, `Sprite3D`, sabit boyut); enstitü ikonunun yanında küçük kadro/risk rozeti yok — ayrıntı panelde |
| Yakın (< 640) | Şehir dioraması aynı kalır. 3D bina modeli **eklenmez** (kural 5: insan gözü gerekir; açık soru §15.2) |
| Eyalet işareti | Enfekte/düşmüş işaretleri 02'deki gibi; merkez ikonu düşmüş eyalette **gri** çizilir (aynı doku, ayrı ikon dosyası) |

## 12. Veri: JSON şemaları

Dosyalar (mod altyapısının yama düzeni; kesin yerleşim 14_teknik_plan.md §2):
`data/modes/zombie/common/buildings.patch.json`, `technologies.patch.json`, `equipment.patch.json`, `spirits.patch.json`,
`events.patch.json` ve modun kendi dosyası `data/modes/zombie/own/science.json`.

### 12.1 Binalar
```json
{
  "_comment": "Sağlık ve bilim binaları. cost: fabrika-gün (gerekçe: docs/modlar/zombi/05_arastirma_merkezleri.md §4.1). requires_* anahtarları motor eklentisi ister (§1.3); yoksa yok sayılır.",
  "buildings": {
    "zm_field_lab":           {"cost": 240,  "shared_slots": false, "max": 2, "name": {"en": "Field Laboratory", "tr": "Saha Laboratuvarı"}},
    "zm_specimen_store":      {"cost": 300,  "shared_slots": false, "max": 1, "requires_building": ["zm_field_lab", "zm_research_institute"], "name": {"en": "Specimen Store", "tr": "Numune Deposu"}},
    "zm_quarantine_hospital": {"cost": 520,  "shared_slots": false, "max": 2, "requires_tech": "zm_notifiable_disease", "name": {"en": "Quarantine Hospital", "tr": "Karantina Hastanesi"}},
    "zm_serum_stables":       {"cost": 640,  "shared_slots": false, "max": 1, "requires_tech": "zm_serotherapy", "name": {"en": "Serum Stables", "tr": "Serum Ahırı"}},
    "zm_teaching_hospital":   {"cost": 1100, "shared_slots": true,  "max": 1, "min_population": 400000, "category_min": "city", "name": {"en": "Teaching Hospital", "tr": "Üniversite Hastanesi"}},
    "zm_research_institute":  {"cost": 1450, "shared_slots": true,  "max": 1, "min_population": 250000, "name": {"en": "Research Institute", "tr": "Araştırma Enstitüsü"}},
    "zm_containment_wing":    {"cost": 700,  "shared_slots": false, "max": 1, "requires_building": ["zm_research_institute"], "name": {"en": "Containment Wing", "tr": "Muhafaza Kanadı"}},
    "zm_vaccine_works":       {"cost": 1900, "shared_slots": true,  "max": 2, "requires_tech": "zm_egg_culture", "name": {"en": "Vaccine Works", "tr": "Aşı Üretim Tesisi"}}
  }
}
```

### 12.2 Teknolojiler (kesit)
```json
{
  "categories": {
    "zm_medicine":      {"en": "Medicine", "tr": "Tıp"},
    "zm_surveillance":  {"en": "Surveillance", "tr": "Gözetim"},
    "zm_civil_defence": {"en": "Civil Defence", "tr": "Sivil Savunma"},
    "zm_biologics":     {"en": "Biologics", "tr": "Biyolojik Üretim"}
  },
  "techs": {
    "zm_agent_isolation": {"cat": "zm_medicine", "year": 1936, "cost": 120, "req": ["zm_case_definition"],
      "name": {"en": "Isolation of the Agent", "tr": "Etkenin Yalıtılması"}, "effects": {"zm_detection": 0.05}},
    "zm_hyperimmune_serum": {"cat": "zm_medicine", "year": 1936, "cost": 150, "req": ["zm_serotherapy"],
      "name": {"en": "Hyperimmune Serum", "tr": "Hiperimmün Serum"}, "unlock": ["zm_serum_dose"],
      "effects": {"zm_serum_efficacy": 0.60}},
    "zm_vaccine_live": {"cat": "zm_medicine", "year": 1937, "cost": 320, "req": ["zm_attenuation_passage", "zm_egg_culture"],
      "name": {"en": "Live Attenuated Vaccine", "tr": "Canlı Zayıflatılmış Aşı"}, "unlock": ["zm_vaccine_dose"],
      "effects": {"zm_vaccine_efficacy": 0.90}},
    "zm_lab_discipline": {"cat": "zm_civil_defence", "year": 1936, "cost": 100, "req": ["zm_agent_isolation"],
      "name": {"en": "Laboratory Discipline", "tr": "Laboratuvar Disiplini"}, "effects": {"zm_accident_mult": -0.40}}
  }
}
```
Not: `effects` değerleri motorun `tech_mods` toplamına girer; mod bunları `rules.gd` içinde okur (`c.mod("zm_serum_efficacy")`).
Etkinlik gibi "toplam değil, en büyük" olması gereken değerler `rules.gd`'de `maxf` ile yorumlanır ve bu, teknolojinin
`_comment`'ında yazılır.

### 12.3 Modun bilim dosyası
```json
{
  "_comment": "Bilim, merkezler, numune, kaza. Gerekçeler: docs/modlar/zombi/05_arastirma_merkezleri.md",
  "scientists": {"base": 2, "per_factory": 0.30, "per_sqrt_million": 0.6, "per_teaching_hospital": 6},
  "staff_required": {"zm_field_lab": 2, "zm_specimen_store": 1, "zm_quarantine_hospital": 3, "zm_serum_stables": 2,
                     "zm_teaching_hospital": 3, "zm_research_institute": 6, "zm_containment_wing": 3, "zm_vaccine_works": 5},
  "science_points": {"zm_field_lab": 1, "zm_specimen_store": 1, "zm_quarantine_hospital": 1, "zm_serum_stables": 1,
                     "zm_teaching_hospital": 3, "zm_research_institute": 4, "zm_containment_wing": 2, "zm_vaccine_works": 1},
  "science_tiers": [{"min": 3, "spirit": "zm_science_base_1", "research_speed": 0.06},
                    {"min": 7, "spirit": "zm_science_base_2", "research_speed": 0.12},
                    {"min": 13, "spirit": "zm_science_base_3", "research_speed": 0.20},
                    {"min": 21, "spirit": "zm_science_base_4", "research_speed": 0.28},
                    {"min": 35, "spirit": "zm_science_base_5", "research_speed": 0.34}],
  "research_slot_at": [10, 25],
  "burden": {"points": {"zm_field_lab": 1, "zm_specimen_store": 1, "zm_quarantine_hospital": 2, "zm_serum_stables": 2,
                        "zm_teaching_hospital": 3, "zm_research_institute": 3, "zm_containment_wing": 2, "zm_vaccine_works": 4},
             "tiers": [{"ratio": 0.10, "spirit": "zm_health_burden_1", "consumer_goods_mod": 0.01},
                       {"ratio": 0.20, "spirit": "zm_health_burden_2", "consumer_goods_mod": 0.02},
                       {"ratio": 0.35, "spirit": "zm_health_burden_3", "consumer_goods_mod": 0.035},
                       {"ratio": 0.55, "spirit": "zm_health_burden_4", "consumer_goods_mod": 0.05}]},
  "samples": {
    "g1": {"bonus": 0.15, "days": 3,  "pp": 20, "needs": ["zm_field_lab"], "risk": {}},
    "g2": {"bonus": 0.35, "days": 7,  "pp": 40, "needs": ["zm_research_institute"], "requires_division": true,
           "risk": {"team_loss": 0.04, "inranks": 0.005}},
    "g3": {"bonus": 0.60, "days": 14, "pp": 70, "needs": ["zm_containment_wing"], "requires_battle_won": true,
           "risk": {"team_loss": 0.12, "inranks": 0.015, "accident_mult": 4.0, "accident_days": 60}},
    "g4": {"discovers_strain": true, "days": 10, "pp": 40, "needs": ["zm_research_institute", "zm_strain_typing"],
           "min_strain_share": 0.10, "risk": {"team_loss": 0.04, "inranks": 0.005}},
    "life_days": 10, "life_days_with_store": 60, "slots": 1, "slots_with_store": 3,
    "transport_days_per_km": 0.00333, "transport_days_max": 12
  },
  "accident": {
    "base_per_year": 0.12, "cap_per_year": 0.90,
    "level_mult": {"m1": 1.0, "m2": 0.5, "m3": 0.35},
    "mult": {"lab_discipline": 0.6, "staff_protected": 0.5, "understaffed": 2.0, "no_store": 1.5,
             "holding_g3": 4.0, "serial_passage": 2.5, "state_outbreak": 1.3},
    "severity": {"exposure": 0.60, "inhouse": 0.30, "escape": 0.10},
    "escape_seed": [8, 40], "pale_chance_on_passage": 0.50
  },
  "release": {"serum_base": 5000, "serum_per_stables": 15000, "vaccine_base": 10000, "vaccine_per_works": 40000,
              "standardisation_mult": 1.5, "filling_line_mult": 1.25},
  "distribution": {"base": 0.002, "per_hospital": 0.003, "per_infrastructure": 0.001,
                   "cold_chain_mult": 1.5, "works_in_state_mult": 1.5, "cap": 0.015, "killed_vaccine_mult": 0.6},
  "batch_check": {"per_doses": 100000, "contaminated": 0.015, "with_potency": 0.0045, "with_containment": 0.7},
  "cooperation": {"share_pp": 60, "request_pp": 40, "mission_staff": 3, "joint_cost": 700,
                  "commission_pp": 80, "commission_serum_bonus": 0.15, "pool_pp_per_year": 40,
                  "accept": {"base": 0.15, "per_opinion": 0.004, "per_reciprocity": 0.25, "per_gsi": 0.010,
                             "rival": -0.30, "same_victory_race": -0.20, "min": 0.02, "max": 0.95}},
  "player_defaults": {"auto_staff": false, "auto_serum": false, "auto_vaccine": false}
}
```

### 12.4 Yeni etki ve şart anahtarları
İki ayrı yol vardır ve karıştırılmamalıdır:
- **Teknoloji `effects`** herhangi bir anahtar olabilir; motor bunları `Country.tech_mods` içinde toplar ve `rules.gd`
  `c.mod("zm_...")` ile okur. Kayıt gerekmez. Modun kullandığı anahtarlar: `zm_detection`, `zm_report_delay`,
  `zm_beta_mult`, `zm_kappa_flat`, `zm_inranks_mult`, `zm_serum_efficacy`, `zm_vaccine_efficacy`, `zm_accident_mult`,
  `zm_release_mult`, `zm_distribution_mult`, `zm_sample_days`.
- **Olay ve program etkileri** motorun sözlüğünde yoksa `rules.gd` → `effect_keys`/`apply_effect` **ve**
  `describe_effect` ikisine birden eklenir (CLAUDE.md kural 2):

| Etki anahtarı | Anlamı |
|---|---|
| `zm_scientists` | Bilim insanı tavanı ± N |
| `zm_sample` | Verilen sınıfta numune ver (`{"zm_sample": "g2"}`) |
| `zm_research_bonus_cat` | Kategoriye bonus (motorun `research_bonus`'una yazar) |
| `zm_accident_mult` | Geçici kaza çarpanı (`{"value": 1.5, "days": 30}`) |
| `zm_institute_closed` | Belirtilen eyalette merkez N gün kapalı |
| `zm_serum_efficacy`, `zm_vaccine_efficacy` | Etkinlik (en büyük geçerli) |
| `zm_release_mult`, `zm_distribution_mult` | Serbest bırakma / dağıtım çarpanı (süreli) |
| `zm_vaccine_trust` | Dağıtım hızına güven çarpanı (süreli) |
| `zm_batch_destroy` | Stoktan doz sil |
| `zm_reciprocity` | Bir ülkeyle karşılıklılık sayacı ± |

| Şart anahtarı | Anlamı |
|---|---|
| `zm_has_building` | `{"zm_has_building": "zm_research_institute"}` — en az bir tane |
| `zm_staffed_institutes` | En az N kadrolu enstitü |
| `zm_has_sample` | Elde belirtilen sınıfta numune |
| `zm_science_points` | BKP ≥ N |
| `zm_tech_any` | Listeden herhangi biri tamamlanmış |
| `zm_serum_stock`, `zm_vaccine_stock` | Stok ≥ N doz |

### 12.5 Kayda eklenecekler
`Game` kaydına (mod durumu `rules.gd.to_save`): bilim insanı tavanı ve atanmış kadro (bina başına), numune listesi
(sınıf, kaynak eyalet, kalan ömür, hedef proje), kaza çarpanı sayaçları ve RNG durumu, verilmiş araştırma yuvası
bayrakları, etkin kademe ulusal durumları, denetim bekleyen doz, eyalet başına dağıtılan doz, karşılıklılık sayaçları,
komisyon/havuz üyelikleri, kolaylık seçenekleri. Binalar ve teknolojiler motorun kaydında zaten var
(`data["states"][id]["buildings"]`, `research_done`). `tests/test_save_load.gd` kalıbı eksik alanı yakalar.

## 13. Test ve denge hedefleri

### 13.1 Birim testleri (`tests/test_zm_science.gd`)
| # | Test | Beklenen |
|---|---|---|
| 1 | Sabit hız 1,0, numune yok: 1 → 8 zinciri | 150 gün ±2 |
| 2 | G2 numunesi bağlanmış 8. proje | maliyet 120 → etkin 89 gün ±1 (bonus bir kez) |
| 3 | İki numune aynı projeye | Yalnız biri kullanılır (motor davranışı), diğeri stokta kalır |
| 4 | Yıl kapısı | 13. proje 1936'da 650 puan, 1 Ocak 1937'de 260 puan; biriken ilerleme silinmez |
| 5 | Kadro muhasebesi | Atanan toplam ≤ tavan; bina yıkılınca/düşünce kadro serbest kalır; negatif olmaz |
| 6 | Doz muhasebesi | Üretilen = serbest bırakılan + denetim bekleyen; dağıtılan = V artışı / etkinlik (tolerans 1 doz) |
| 7 | Kaza belirlenimciliği | Aynı tohum → aynı gün, aynı şiddet; kayıt/yükleme sonrası da aynı |
| 8 | Sızıntı | E tohumu 8–40 aralığında ve o eyaletin S'sinden düşülür (nüfus korunumu) |
| 9 | Kolaylıklar kapalı | Oyuncu hiçbir şey yapmazsa kadro atanmaz, doz dağıtılmaz (`country_check` kalıbı) |
| 10 | Yama bütünlüğü | `technologies.patch.json`'daki her `req` ve `cat` tanımlı; her bina adının `BDESC_*` çevirisi var |

### 13.2 Denge hedefleri (oyuncusuz dünya, 6 koşu; her kontrol ≥ 5/6)
| # | Kontrol | Hedef |
|---|---|---|
| 1 | İlk saha laboratuvarını kuran ülke | 20.–70. gün |
| 2 | İlk enstitüyü bitiren ülke | 90.–200. gün |
| 3 | En az bir ülke etkeni tanımlar | 90.–180. gün |
| 4 | Serum (02 kontrol 6 ile aynı) | 240.–450. gün |
| 5 | Aşı (02 kontrol 7 ile aynı) | 600.–900. gün |
| 6 | Bitişte enstitüsü olan ülke sayısı | 15–45 (80 üzerinden) |
| 7 | Dünyada kampanya boyunca kaza sayısı | 3–20; bunların 0–3'ü sızıntı |
| 8 | Soluk suş ortaya çıkışı | 0–1 (04 §7.2 hedefiyle aynı) |
| 9 | Bitişte en yüksek aşılama kapsamı | ≥ %40 olan en az 1 ülke |
| 10 | Paylaşım anlaşması sayısı | 5–40; KSE 30'un üstünde arttığı görülmeli |
| 11 | Ek çalışma süresi | Bilim katmanı 1.461 günlük koşuyu %5'ten çok yavaşlatmamalı |

## 14. Görsel ve ses varlıkları (liste ve üretim komutları)

Dosya üretilmez (CLAUDE.md kural 6). Stil cümleleri 04 §10.2'deki `STYLE_ZM_ICON` ve `STYLE_ZM_STRAIN` ile aynıdır.

| Dosya | Konu (prompt'un başı; sonuna stil cümlesi eklenir) |
|---|---|
| `building_zm_field_lab.png` | a folding field table under canvas with a microscope, spirit lamp and glass slides |
| `building_zm_specimen_store.png` | a locked steel cabinet with numbered drawers beside a block of ice in sawdust |
| `building_zm_quarantine_hospital.png` | a long low pavilion ward with shuttered windows and a laundry chimney |
| `building_zm_serum_stables.png` | a clean stable with two calm draught horses and a rack of sealed flasks |
| `building_zm_teaching_hospital.png` | a stone clinic facade with an arched entrance and a lecture-theatre skylight |
| `building_zm_research_institute.png` | a brick institute block with tall laboratory windows and a boiler chimney |
| `building_zm_containment_wing.png` | a separate windowless annex with a double door, ventilation stack and incinerator |
| `building_zm_vaccine_works.png` | rows of incubator cabinets and a filling bench with small glass vials |
| `tech_zm_agent_isolation.png` | a microscope beside a sealed culture flask on a laboratory bench (STYLE_ZM_STRAIN) |
| `tech_zm_hyperimmune_serum.png` | a graduated flask and a row of sealed ampoules on a wooden rack (STYLE_ZM_STRAIN) |
| `tech_zm_vaccine_live.png` | an egg in a candling lamp beside a syringe and a stoppered vial (STYLE_ZM_STRAIN) |
| `tech_zm_cold_chain.png` | an insulated shipping box packed with ice and straw, railway label blank (STYLE_ZM_STRAIN) |
| `tech_zm_gauze_masks.png` | a folded gauze mask with tapes, laid flat (STYLE_ZM_STRAIN) |
| `tech_zm_lab_discipline.png` | a rubber pipette bulb, a logbook and an autoclave dial (STYLE_ZM_STRAIN) |
| `equipment_zm_serum_dose.png` | a wooden crate of sealed glass ampoules packed in straw (STYLE_SMALL) |
| `equipment_zm_vaccine_dose.png` | a small crate of stoppered vials with an ice pack (STYLE_SMALL) |
| `map_institute.png` / `map_hospital.png` / `map_vaccine_works.png` | a small brick institute block / a pavilion ward with a red-free plain cross-free health emblem / an incubator hall roof (STYLE_ICON, harita ikonu) |
| `event_zm_volunteers.png` | a 1930s ward, a clerk holding two typed contracts, a physician at a bedside, faces turned away |
| `event_zm_tainted_batch.png` | crates of small vials stacked on a railway platform at dusk, one crate open |
| `event_zm_accident.png` | a locked laboratory door at night seen from the corridor, a single desk lamp, broken glass swept into a pan |
| `event_zm_refugee_scientists.png` | three figures with suitcases and a wooden culture case at a rainy border post |

Sesler (`tools/make_audio.py` yaklaşımı, mono 44,1 kHz, telifli örnek yok):

| Dosya | Süre | Prosedürel tarif | Üretim komutu (EN) |
|---|---|---|---|
| `zm_lab_amb` | 12 sn döngü | Oda gürültüsü −42 dB; 0,4 Hz kaynama fokurtusu (120–400 Hz bant); 7–11 sn'de bir cam tıkırtısı (2,5 kHz, 40 ms, kısa kuyruk); uzak kazan uğultusu 90 Hz | "quiet 1930s laboratory room tone, faint boiling flask, occasional glass clink, distant boiler hum, loopable" |
| `zm_breakthrough_sting` | 2,5 sn | Telgraf tıkırtısı (1 kHz) + yükselen üçlü akor (220/277/330 Hz), 300 ms sönüm, hafif oda yankısı | "short hopeful telegraph flourish resolving into a warm three-note chord" |
| `zm_accident_sting` | 1,8 sn | Tek cam kırılması (geniş bant tık + 3 kHz kuyruk), ardından 60 Hz alçak uğultu ve ani sessizlik | "a single flask breaking in a large room, then a low hum and sudden silence" |
| `zm_convoy_doses` | 4 sn | Tren freni (400–1.200 Hz süpürme), sandık tokmağı (200 Hz tık ×3), kısa ıslık | "wooden crates being loaded onto a train, brakes, a guard's whistle" |

## 15. Açık sorular

1. **Bina şartları için motor eklentisi** (§1.3 madde 1) yapılacak mı, yoksa şartlar tamamen maliyete mi bindirilecek?
   Öneri: eklenti yapılsın (WWII modu da kullanır: ör. sentetik rafineri için teknoloji şartı).
2. **Merkezlerin 3D görünümü** (§11.4): yakın zoom'da bina modeli eklemek `CityLayer3D`'ye dokunmak demektir; kural 5
   gereği insan gözüyle iki hedefte (Forward+ ve gl_compatibility) doğrulanmalı. Kim ve ne zaman? O zamana kadar yalnız ikon.
3. **Bilim insanı tavanı formülü** fabrika sayısına dayanıyor; fabrika kaybı (düşmüş eyalet) tavanı da düşürmeli mi?
   Öneri: hayır (kurum insanı kalır), yalnız atanmış kadro kaybedilir. Denge testiyle bakılmalı.
4. **Serum ve aşı dozunun kaynağı** kauçuk: kauçuk ithal eden bir ülkede abluka, serum üretimini durdurur. İstenen bir
   bağ mı, fazla mı sert? Öneri: kalsın, ama `zm_filling_line` kauçuk ihtiyacını yarıya indirsin.
5. **Öldürülmüş aşı yolu** iki dozla ve 0,75 etkinlikle Tedavi Zaferi'ni ada ülkeleri için bile zorlaştırıyor;
   02 açık soru 2 (ada ülkelerinin kolay Arındırma Zaferi) ile birlikte dengelenmeli.
6. ~~**Yapay zekânın bilim önceliği:**~~ — **Çözüldü:** enstitü eşiği kapasite + vaka/evre şartına bağlandı (10 §4.4e).
7. **Kaza olaylarının sıklığı** ihtiyatlı oyuncu için çok seyrek (kampanyada ~%5). Kaza dışında bir "etik ikilem" kaynağı
   gerekir mi (ör. kadro yorgunluğu, denetim baskısı)? Öneri: §10.1, §10.2, §10.8 zaten kazadan bağımsız tetikleniyor.
8. ~~**Komisyon ve havuz üyeliğinin**~~ — **Çözüldü:** Uluslararası Karantina Konseyi yapay zekâsı 09 §6.6 ve 10 §5'te.
9. **Numune taşıma süresi** deniz yolu kesilirse ne olur (ada ülkesi, abluka)? Öneri: konvoy/deniz yolu yoksa numune
   G2/G3 için gelmez; bu, donanmayı bilime bağlar.

## 16. Kaynaklar

Biyogüvenlik ve laboratuvar kaynaklı enfeksiyonlar
- CDC/NIH. *Biosafety in Microbiological and Biomedical Laboratories* (BMBL), ilk baskı 1984, 6. baskı 2020; BSL-1…4 tanımları. — https://www.cdc.gov/labs/bmbl/index.html
- Biyogüvenlik düzeyleri ve muhafaza tarihçesi (sınıf III kabin 1943, sınıf I kabin 1950'ler). — https://en.wikipedia.org/wiki/Biosafety_level
- Biyolojik güvenlik kabinlerinin gelişimi (Wedum, Camp Detrick). *Lab Manager.* — https://www.labmanager.com/evolution-of-biological-safety-cabinets-18557
- Amerikan Biyogüvenlik Derneği, ilk biyogüvenlik konferansları (1955–1965). — https://absa.org/about/hist01/
- Pike, R. M. (1976). Laboratory-associated infections: summary and analysis of 3921 cases. *Health Lab Science.* — https://pubmed.ncbi.nlm.nih.gov/946794/
- Sulkin, S. E., Pike, R. M. (1951). Survey of laboratory-acquired infections. *Am. J. Public Health* 41: 769–781. — https://www.scirp.org/reference/referencespapers?referenceid=3360967
- Mesleki hastalıkların kısa tarihi: laboratuvar kaynaklı enfeksiyonlar (1898 Viyana veba kazası dâhil). — https://pmc.ncbi.nlm.nih.gov/articles/PMC7907906/
- Avusturya Veba Komisyonu ve 1898 Viyana'daki son ölümcül veba vakaları. *Wien. Med. Wochenschr.* — https://link.springer.com/article/10.1007/s10354-018-0653-z
- Henkel, R. D., Miller, T., Weyant, R. S. (2012). Monitoring select agent theft, loss and release reports in the United States, 2004–2010. — https://journals.sagepub.com/doi/10.1177/153567601201700402
- Klotz, L. ve ark. tartışması; Lipsitch & Inglesby'nin laboratuvar-yılı başına ~0,2% enfeksiyon tahmini. *mBio / PMC.* — https://pmc.ncbi.nlm.nih.gov/articles/PMC4271556/
- 2000–2021 arası laboratuvar kaynaklı enfeksiyonlar ve patojen kaçakları: kapsam taraması. *The Lancet Microbe.* — https://www.thelancet.com/journals/lanmic/article/PIIS2666-5247(23)00319-1/fulltext

Aşı ve serum tarihi
- Theiler & Smith'in 17D suşu: 176 pasaj, 1937; Brezilya'da 1938'de yaklaşık 1,06 milyon kişinin aşılanması. — https://memorias.ioc.fiocruz.br/article/2565/the-early-use-of-yellow-fever-virus-strain-17d-for-vaccine-production-in-brazil-_-a-review
- Sarı humma aşısının tarihi (Asibi suşu 1927, 1951 Nobel Ödülü). — https://brewminate.com/a-history-of-the-yellow-fever-vaccine/
- Laboratuvarda kazayla edinilen sarı humma vakaları (Berry & Kitchen, 1931). *Am. J. Trop. Med. Hyg.* — http://www.ajtmh.org/content/journals/10.4269/ajtmh.1931.s1-11.365
- Goodpasture & Woodruff (1931): virüslerin tavuk embriyosu koryoallantoik zarında üretimi. *Science* 74: 371. — https://www.science.org/doi/10.1126/science.74.1919.371
- Behring ve Kitasato (1890), serum tedavisinin kuruluşu. *NobelPrize.org.* — https://www.nobelprize.org/prizes/medicine/1901/behring/article/
- Roux ve arkadaşlarının 1894'te difteri antitoksiniyle klinik sonuçları. *PMC.* — https://pmc.ncbi.nlm.nih.gov/articles/PMC2405444/
- Pasteur'ün 1885 kuduz aşısı: kurutulmuş tavşan omuriliği, 14 günlük dizi. *PNAS.* — https://www.pnas.org/doi/10.1073/pnas.1414226111
- Weigl'in tifüs aşısı: personelin önce aşılanması, 1936–43'te Asya'daki ilk geniş kullanım. — https://en.wikipedia.org/wiki/Rudolf_Weigl
- 1930 Lübeck olayı: kirlenmiş BCG partisi, 251 bebek, 77 ölüm. *European Respiratory Review.* — https://publications.ersnet.org/content/errev/31/164/220046
- Yenidoğanlarda tüberküloz: "Lübeck faciası"nın dersleri (1929–1933). *PLOS Pathogens.* — https://journals.plos.org/plospathogens/article?id=10.1371%2Fjournal.ppat.1005271

Kurumlar, etik ve halk sağlığı örgütlenmesi
- Milletler Cemiyeti Sağlık Teşkilatı'nın Singapur bürosu ve haftalık telsiz bülteni (1925). — https://www.newmandala.org/singapore-bureau/
- Biyolojik standartlaştırmanın tarihi: Daimî Komisyon (1923–24), Madsen, Dale, Statens Serum Institut. *J. Pharm. Sci.* — https://www.sciencedirect.com/science/article/abs/pii/S0022354924006142
- Milletler Cemiyeti'nin sağlık çalışması (dönemin kendi anlatımı). *Milbank Quarterly* 13(1). — https://www.milbank.org/wp-content/uploads/mq/volume-13/issue-01/13-1-Health-Work-of-the-League-of-Nations.pdf
- 1926 Uluslararası Sıhhiye Sözleşmesi. BM Cenevre Arşivi. — https://archives.ungeneva.org/international-sanitary-convention-1926
- Wu Lien-teh ve Kuzey Mançurya Veba Önleme İdaresi (1912): hastane ve bakteriyoloji laboratuvarı ağı. — https://biblioasia.nlb.gov.sg/vol-16/issue-2/jul-sep-2020/plague/
- 1910–11 Mançurya vebası: ortak demiryolu karantinası, maske, yakma. — https://link.springer.com/article/10.1007/s11684-018-0613-4
- Rockefeller Vakfı Uluslararası Sağlık Bölümü: 1934 bütçesi ve saha/laboratuvar kadroları. *1934 Yıllık Raporu.* — https://www.rockefellerfoundation.org/wp-content/uploads/Annual-Report-1934-1.pdf
- Rockefeller Vakfı'nın 20. yüzyıldaki hastalık mücadelesi (IHD, 1927 yeniden örgütlenme). — https://resource.rockarch.org/story/the-rockefeller-foundations-20th-century-global-fight-against-disease/
- Denizaşırı Pasteur enstitüleri ağı ve bilginin yayılması (1887–1975). *Stud. Hist. Phil. Biol. Biomed. Sci.* — https://www.sciencedirect.com/science/article/pii/S0923250807002100
- 1900 sarı humma çalışmasında iki dilde yazılı onam ve ödeme. *Military Medicine* 181(1). — https://academic.oup.com/milmed/article-abstract/181/1/90/4158283
- Yüzyıllık dönüm: Sarı Humma Komisyonu ve tıbbi araştırmada bilgilendirilmiş onam. *Salud Pública de México.* — https://www.scielo.org.mx/scielo.php?script=sci_arttext&pid=S0036-36342002000200009

Depo içi
- `data/common/buildings.json` (fabrika-gün ölçeği), `data/common/equipment.json` (fabrika-saat, verimlilik),
  `data/common/technologies.json` (cost/year/req/effects kalıbı), `data/common/spirits.json` (ulusal durum ve danışman kalıbı)
- `game/autoload/research.gd` (`AHEAD_PENALTY`, `research_bonus`, `research_stored`), `game/autoload/economy.gd`
  (`can_build`, `_assign`, üretim), `game/autoload/politics.gd` (`apply_effects`, `check`), `game/core/mode_rules.gd`
  (mod kancaları), `game/core/game_modes.gd` (yama düzeni), `game/ui/panel_layout.gd`, `game/ui/state_panel.gd`,
  `game/map/map_icon_layer.gd`
- `data/map/states.json`, `data/history/states_1936.json` (bilim insanı formülünün ölçüldüğü veri)
- `docs/modlar/zombi/01_vizyon.md`, `02_oynanis_dongusu.md`, `04_zombi_turleri.md`, `docs/OZGUNLUK.md`
