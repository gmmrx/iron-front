# Zombi modu — 03 Salgın modeli: bulaşma ve yayılmanın matematiği

> **Özet.** Salgın motoru: bölmeli eyalet modeli, yayılma ağları, iklim, önlemler, gözetim, bağışıklık, sürüler, belirlenimcilik, maliyet
> ve harita verisi. Kararlar 01–02'ye, tür ve suş çarpanları 04_zombi_turleri.md'ye dayanır.
> - **Model:** Eyalet başına 7 bölme + 2 yardımcı sayı; günlük **kırpılmış Euler**, yalnız dört işlem ve karekök (masaüstü = web). 02 §2.3 tablosunu ±1 günle üretir.
> - **Yayılma:** Kara/demiryolu yolcusu, başkent hattı, **çift yönlü** deniz hatları, mülteci ve sürü yürüyüşü. Nehir yürüyüşü yarıya indirir; hava yolu (1938'de ~2,7 milyon yolcu/yıl) ihmal edilir.
> - **Prototip** (gerçek harita, 6 tohum): Müdahalesiz dünyada 1 Ocak 1940'ta %1, güçlü yanıtla %39 yaşıyor. Çift yönlü hatlarla Türkiye'ye ilk vaka 24–87. günde (tek yönlüde 51–361).
> - **Ölçüm** (Godot 4.7.2): Eyalet/günlük 4–8 ms/gün, bölge/saatlik 1.300 ms/gün, temel oyun 115–150 ms/gün → **eyalet + günlük**.
> - **Belirlenimcilik:** Durumsuz sayaç karması; kayıtta base64 ikili biçim (JSON ondalığı kayıplıdır, ölçüldü).
> - **Isı haritası:** Veri hazır. Mevcut işaret dokusu tek düzeylidir (01/02 düzeltmesi); renkli harita gölgelendirici değişikliği ve insan onayı ister.

---

## 1. 02 ile ilişki: netleştirilen kararlar

Bu belge 02 §2'deki çekirdeği kodlanabilir hâle getirir. Prototip ölçümleri ve kod okuması, 01/02'de sekiz yerin netleşmesini
ya da düzeltilmesini gerektirdi:

| # | Konu | 02'de | 03 kararı | Kanıt (§) |
|---|---|---|---|---|
| 1 | Düşme ölçütü | Metin "H > yaşayan" diyor | **H > S + R + V + Vb** ("savunabilir" nüfus) | 02 tablosu bu ölçütle hesaplanmış (±1 gün). "H > yaşayan" ölçütü düşmeyi 8–12 gün geciktirir (§3.7) |
| 2 | İndeks küme | 25 kişi, bileşimi yazılmamış | **25 kişinin hepsi E'de (kuluçkada)**, −21. gün | 02'nin tespit günlerini (31 / 15 / 8) birebir verir (§5.9) |
| 3 | Başlangıç yeri ağırlığı | Liman nüfusu | **Liman nüfusu × d** | İlk tespitin 8–31. günde olma olasılığı %84'ten %95'e çıkar; denge kontrolü 1 için 5/6 = %83 gerekir |
| 4 | Bağlantı sınırı | Eyalet başına en çok 8 | Kara ve başkent bağları için 8. **Deniz hatları çift yönlüdür, sınırsızdır** | Tek yönlü hatlarda liman merkezleri dışarı yayamaz: Türkiye'ye varış 51–361. günden 24–87. güne iner (§5.3, §5.8) |
| 5 | Evre 1 → 2 çıkışı | "≥ 3 ülkede gerçek vaka ≥ 100" ya da KSE ≥ 1 | **KSE ≥ 1** (ya da **bildirilen** sayılarla "3 ülke") | "3 ülke" koşulu 19–57. günde tetikleniyor (hedef 60–150). KSE ≥ 1 ise 46–150. günde (§5.8) |
| 6 | Aşı | S → V anında | **S → Vb → V, 10 gün gecikmeli**, sızdıran etkinlik 0,9 | 17D aşısında bağışıklık 10 gün içinde gelişir (§9) |
| 7 | Harita işareti | "128 enfekte, 255 düşmüş" iki düzey | Gölgelendiricide 0 ile 128 aynı görünür, 255 yeşil nabız atar | `map3d.gdshader` satır 257–263 (§13.1) |
| 8 | Kayıt | Belirtilmemiş | Bölmeler **base64 `PackedFloat64Array`** olarak saklanır | Varsayılan `JSON.stringify` 5 sınama sayısının 5'ini de bozdu (§11.4) |

## 2. Mimari ve günlük hesap sırası

```
SAAT (GameClock.hour_passed)        GÜN (GameClock.day_passed)                       HAFTA (cuma)
 Military._on_hour (mevcut):         1  önlem çarpanlarını topla (yasa, olay, bina)     Salgın Bülteni: yabancı
  sürü birimleri yürür, savaşır      2  eyalet içi adım, 1.652 eyalet (§3)               ülkelerin bildirilen
  muharebede ölen Boş → D            3  akışlar: yolcu, deniz varışı, mülteci,           sayıları, yeni suşlar
                                        sürü yürüyüşü (§5)                              (04 §7.4)
                                     4  küçük sayı rejimi ve sönme (§3.4)
                                     5  tespit ve bildirim halkası (§8)
                                     6  sürü doğumu/dağılması, cephe eyaletleri (§10)
                                     7  eyalet durumu (02 §2.5), bölge kontrolü, KSE, evre
```
- 2. ve 3. adımlar gün başındaki dizilerden okur, sonucu ayrı dizilere yazar (çift tampon). Böylece eyaletlerin işlenme sırası sonucu
  değiştirmez. Akışlar hedef dizide **sabit bağlantı sırasıyla** toplanır. Ondalıklı toplamanın sırası değişirse sonuç da değişebilir.
- Her adım `GameClock.timed("epidemic", t0)` ile ölçülür ve mevcut `sim.gd` profil dökümünde görünür.
- Kod yeri önerisi: şablondaki `mode.json` → `"rules": "res://game/modes/zombie/rules.gd"` alanı. Motor `epidemic.gd`'dir ve
  `data/modes/zombie/epidemic.json`'u okur (§14). Kesin yerleşim `docs/modlar/README.md`'de yazılacak.

## 3. Eyalet içi model

### 3.1 Bölmeler ve yardımcı sayılar

| Sayı | Anlamı | Not |
|---|---|---|
| S | Sağlam | Başlangıç: `states.json` nüfusu (toplam 2.154.592.225) |
| E | Kuluçkada | Belirtisiz, bulaştırmaz (ε = 0; 04'teki "Sessiz taşıyıcılık" ε = 0,10 yapar) |
| F | Ateşli | Belirtili, hafif bulaştırır (φ) |
| H | Boş (dağınık) | Eyalette birim dışındaki Boşlar; `H_top = H + U` |
| U | Birimlerdeki Boşlar | Eyaletteki sürü birimlerinin `strength × 10.000` toplamı (04 §2.1); ayrı tutulmaz, birimlerden okunur |
| R | İyileşen | Serumla (ya da 04'teki Soluk suşta kendiliğinden) iyileşen, bağışık |
| Vb | Aşılandı, bağışıklık gelişiyor | **Yardımcı**: 10 günlük halka; bu sürede S gibi enfekte olur |
| V | Aşılı | Sızdıran koruma: enfeksiyon riski S'nin %10'u |
| D | Salgından ölen | Ateşli evrede ölen + bastırılan + ömrü biten + muharebede ölen Boşlar |

Yaşayan nüfus `L = S + E + F + Vb + R + V`, temas havuzu `T = L + H + U`.

### 3.2 Günlük denklemler (Δt = 1 gün)

```
d_s    = clamp( sqrt(ρ_s / 25), 0.35, 3.0 )                      ρ_s: kişi/km² (02)
c_s    = 1 − 0.25 · kış_s                                         soğukta uyuşukluk (§6)
m_s    = 1 − Π_k (1 − ö_k,s)          m_s ≤ 0.75                  önlemlerin birleşik bulaş azaltması (§7)
λ_s    = β · τβ_s · d_s · c_s · (1 − m_s) · (H + U + φ·F + ε·E) / T
yeni_E = min(λ_s, 0.95) · (S + Vb)  +  min((1 − e_V) · λ_s, 0.95) · V
E → F  = σ · E
F → *  = γ · F   →  H: (1 − p_ölüm − p_iyi),  D: p_ölüm,  R: p_iyi
H → D  = min( κ · τκ_s · d_s · L / T  +  κ_asker,s  +  μ · τμ_s · iklim_s , 0.95 ) · H
birim  : strength ×= 1 − μ · τμ_s · iklim_s                      (04 §2.4; ikmal yerine ömür)
serum  : min(Z_s · e_Z, E + F) kişi → R, E ve F'den paylarıyla    Z_s: o gün dağıtılan doz
aşı    : A_s doz → S ve E'ye paylarıyla; S'ye düşen → Vb(t+10) → V; E'ye düşen boşa gider
```
- `τβ, τκ, τμ` tür ve suş karışımının çarpanlarıdır. Hesabı 04 §2.3'tedir (`β_etkin = β · Σ pay · β×`). Ata suşta hepsi 1'dir.
- `ε` (kuluçkada bulaş) ve `p_iyi` (kendiliğinden iyileşme) ata suşta 0'dır. 04 §6 R₀ formülünü bu iki terimle genişletir.
  Denklem, 04'teki suşları kod değişikliği olmadan çalıştırmak için iki terimi de taşır.
- Aşılanan E'ye giden doz boşa gider. 1936'da kuluçkadaki kişi tanınamaz; doz planlamasında bu fire görünür (panel: "boşa giden doz").
- `κ_asker,s = 0,10 · Σ_tümen (güç × bütünlük oranı) · sqrt(56.500 / A_s)`, üst sınır 0,6. Yalnız o eyalette **muharebede
  olmayan** kendi ya da müttefik tümenleri sayılır. Gerekçe: 02'de "bir garnizon = +0,10" denmişti. Dağınık Boş'u bulmak alan
  taramasıdır, bu yüzden etki alanın karekökü oranında seyrelir. 56.500 km², `states.json`'daki medyan eyalet alanıdır.
  0,6 üst sınırı bir tasarım sınırıdır: bir günde dağınık Boşların en çok %60'ı bulunabilir.

### 3.3 Sayısal şema: kırpılmış Euler

Her çıkış "oran × bölme" biçiminde hesaplanır. Aynı bölmeden çıkışların toplamı 0,95'le kırpılır, böylece hiçbir bölme eksiye düşmez.
Ata suşun varsayılan değerleriyle hiçbir oran 0,95'e ulaşmaz. En büyüğü, d = 3 olan ve Boşların çoğunlukta olduğu eyaletteki
λ ≈ 0,9'dur. Kırpmayı yalnız büyük garnizon (κ_asker) ya da 04'teki hızlı suşlar çalıştırır. Alternatif "üstel çıkış"
`1 − e^(−oran)` kullanır. İki şemanın karşılaştırması: 1 milyonluk eyalet, 200 kişilik çekirdek (%50 E, %30 F, %20 H), önlem yok.

| d | R₀ | İkiye katlanma (Euler / üstel) | %1 yaygınlık günü (E / Ü) | Düşme, H > S (Euler) | Düşme, H > L (Euler / Ü) | 02 tablosu |
|---|---|---|---|---|---|---|
| 0,35 | 2,23 | 22,1 / 22,5 | 128 / 130 | 269 | 278 / 285 | 22 · 127 · 268 |
| 0,64 | 2,75 | 13,0 / 13,3 | 76 / 78 | 163 | 171 / 177 | 13 · 75 · 162 |
| 1,00 | 3,11 | 9,5 / 9,7 | 55 / 57 | 120 | 129 / 134 | 9,5 · 54 · 119 |
| 1,93 | 3,65 | 6,4 / 6,5 | 37 / 37 | 83 | 92 / 96 | 6,4 · 36 · 82 |
| 3,00 | 4,10 | 5,1 / 5,1 | 29 / 29 | 66 | 77 / 80 | 5,1 · 28 · 65 |

**Karar: kırpılmış Euler.** Üç nedeni var:
1. 02'deki sayıları korur. Fark gün saymadan gelen 1 gündür.
2. Yalnız `+ − × ÷` ve `sqrt` kullanır. IEEE 754 bu işlemlerin doğru yuvarlanmasını zorunlu kılar, `exp` için böyle bir zorunluluk
   yoktur. Bu yüzden masaüstü (x86-64) ile web (WASM) aynı bitleri üretmelidir (§11).
3. Tek adım ucuzdur.

### 3.4 Küçük sayılar: melez stokastik rejim

Sürekli bir modelde eyalete 0,001 kişilik "yolcu" gelir ve üstel olarak büyür. Bu, epidemiyolojide 1991'den beri bilinen
**"atto-tilki" sorunudur**: tilki kuduzu modeli km²'de 10⁻¹⁸ kuduz tilkiden yeni bir dalga başlatmıştı. Çözüm, küçük sayıları
tamsayı olarak ve olasılıkla işlemektir:
- Eyalette `E + F + H < 50` ise o gün bölmeler tamsayıya yuvarlanır. Geçişler binom (`E→F ~ Bin(E, σ)` …) ve Poisson
  (`yeni_E ~ Poi(λ·S)`) çekilişleriyle yapılır. 50 ve üstünde deterministik denklem kullanılır. 50'lik eşik, melez modellerde denenen
  50–100 aralığının alt ucudur. 50 enfekteden sönme olasılığı yaklaşık (1/R₀)⁵⁰ ≈ 0'dır, yani eşik üstünde rastgelelik bir şey değiştirmez.
- Yedek kural (02): `E + F + H < 0,5` ise üçü de 0 olur.
- Çekilişler §11'deki sayaç karmasıyla yapılır.

Ölçülen sonuç (prototip, 4.000 deneme). Eyalete **tek bir kuluçkalı yolcu** girerse salgın şu olasılıkla hiç başlamaz:

| d | R₀ | P(söner) | 1/R₀ (dallanma kuramı) | Karantina (β ×0,65) + 1 garnizon (κ +0,10) ile P(söner) |
|---|---|---|---|---|
| 0,35 | 2,23 | 0,47 | 0,45 | 1,00 |
| 0,64 | 2,75 | 0,36 | 0,36 | 1,00 |
| 1,00 | 3,11 | 0,30 | 0,32 | 0,89 |
| 1,93 | 3,65 | 0,20 | 0,27 | 0,53 |
| 3,00 | 4,10 | 0,14 | 0,24 | 0,36 |

Oynanış anlamı: her kaçak yolcu salgın başlatmaz. Önceden hazırlanmış bir kırsal eyalet gelen vakayı neredeyse her zaman söndürür.
Büyük liman şehri ise önlem alınmış olsa bile üç girişin ikisinde salgını başlatır. Bu fark, oyuncunun "hazırlık neye yarar?"
sorusuna verilen sayısal yanıttır.

### 3.5 Parametreler

| Sembol | Değer (Salgın zorluğu) | Gerekçe / kaynak |
|---|---|---|
| β | 0,30 gün⁻¹ | 02 §2.3: R₀ hedefinden geri hesap |
| κ (sivil) | 0,08 gün⁻¹ | 02; α = κ/β = 0,27 |
| μ | 1/60 gün⁻¹ | 02; yalnız suyla hayatta kalma 45–61 gün |
| σ | 1/3 gün⁻¹ | 02 |
| γ | 1/7 gün⁻¹ | 02 |
| p_ölüm | 0,10 | 02 |
| φ | 0,15 | 02 |
| ε, p_iyi | 0, 0 | Ata suş; 04 §6 suşları değiştirir |
| d_ref, d aralığı | 25 kişi/km²; 0,35–3,0 | 02 |
| Önlem tavanı m | 0,75 | §7 |
| e_V (aşı) | 0,9 (sızdıran) | 02 V_c formülü; 04 "Aşı kaçağı" 0,7 |
| Aşı gecikmesi | 10 gün | 17D: aşılananların %95'inden fazlası 10 gün içinde bağışık olur |
| e_Z (serum) | 0,8 (öneri) | Araştırma belgesinde kesinleşir; 04 Dirençli ×0,5 |
| κ_asker | 0,10 / tümen × sqrt(56.500/A) ≤ 0,6 | §3.2 |
| Çıkış kırpması | 0,95 | §3.3 |
| Küçük sayı eşiği | 50 | §3.4 |

### 3.6 R₀, direnç oranı ve "kaç garnizon gerekir?"

`R₀ = ε·β·d/σ + φ·β·d/γ + (1 − p_ölüm − p_iyi) · β·d / (κ·d + κ_asker + μ·iklim)` (02 ve 04 ile aynı).

Tam karışımlı ısırma–öldürme modelinde (dS/dt = −βSZ, dZ/dt = (β − κ)SZ) sonucu α = κ/β belirler. Zombi salgını modellerinin
akademik literatürü (Munz ve ark. 2009; Alemi ve ark. 2015) bu yapıdadır. Bizim modelde iki fark var: Boşlar **ölümlüdür** (μ) ve
Ateşli evre ayrıca bulaştırır (φ). Bu yüzden bir eyalette salgını söndürmek için R < 1 gerekir. Aşağıdaki tablo, R'yi 1'in altına
indirmek için gereken **ek bastırma** κ_asker'i verir (iklim 1):

| β çarpanı (önlem) | d = 0,35 | 0,64 | 1,00 | 1,93 | 3,00 |
|---|---|---|---|---|---|
| ×1,00 (önlem yok) | 0,062 | 0,149 | 0,297 | 1,158 | 14,5 (fiilen imkânsız) |
| ×0,65 (Zorunlu Karantina) | 0,022 | 0,061 | 0,124 | 0,389 | 1,108 |
| ×0,50 (karantina + sıkıyönetim) | 0,005 | 0,028 | 0,064 | 0,203 | 0,511 |

Tümen sayısına çevrildiğinde (§3.2 formülü, tam güçlü tümen = 0,10 × alan çarpanı):
- Medyan eyalette (d ≈ 0,64, ~56.500 km²) karantina varsa **0,6 tümen**, yoksa 1,5 tümen gerekir.
- Sanayi eyaletinde (d ≈ 1,9) karantinayla ~4 tümen gerekir.
- Büyük liman şehrinde (d = 3, ~10.000 km², tümen başına 0,24) karantinayla ~4,7 tümen gerekir. Karantina yoksa κ_asker 0,6
  tavanında kalır ve salgın sönmez.

d = 3'te yalnız Ateşli bulaşı (φ terimi) R'ye 0,95 ekler. Yani **büyük şehirde asıl kaldıraç serumdur**, asker değildir. Bu, 02 §2.3'teki
tasarım sonucunu ("kırsalı yasa korur, şehri asker ve serum korur") sayıyla doğrular.

### 3.7 Düşme ölçütü

Eyalet **DÜŞMÜŞ** olur: `H + U > S + R + V + Vb` ve eyalette kendi ya da müttefik tümeni yoksa (02 §2.5).
- 02'deki düşme günleri bu ölçütle hesaplanmış çıkıyor (±1 gün). "H > yaşayan" ölçütüyle aynı eyaletler 8–12 gün geç düşer.
- E ve F zaten hastadır ve eyaleti savunmaya katkısı yoktur. Metin ile tablo arasındaki çelişki bu tanımla kalkar.

## 4. Yoğunluk: şehir ve kırsal

**Dağılım** (`states.json` ve `data/history/states_1936.json`'dan ölçüldü):
- 1.652 eyaletin 472'si (%28,6) d = 0,35 tabanında, 33'ü d = 3,0 tavanındadır. Medyan yoğunluk 10,2 kişi/km²'dir (d = 0,64).
- 1936 eyalet kategorisi (`category`) yoğunlukla uyumludur:

| Kategori | Eyalet | Medyan kişi/km² | d |
|---|---|---|---|
| pastoral | 158 | 0,7 | 0,35 |
| wasteland | 91 | 2,1 | 0,35 |
| rural | 400 | 2,7 | 0,35 |
| town | 431 | 8,8 | 0,59 |
| large_town | 211 | 17,8 | 0,84 |
| city | 143 | 27,4 | 1,05 |
| large_city | 77 | 59,2 | 1,54 |
| metropolis | 79 | 89,8 | 1,90 |
| megalopolis | 62 | 145,9 | 2,42 |

**Kent payı:** `cities.json`'daki 1.847 şehrin nüfusu 433 milyondur (dünyanın %20'si). Eyalet başına kent payının medyanı %3'tür.
797 eyalette hiç şehir yoktur. 120 eyalette kent payı %50'nin üstündedir.

**Sürüm 1'de eyalet tek yamadır.** Eyaletin içindeki şehir–kırsal farkı üç yolla yansır:
1. **d** zaten eyalet ortalamasıdır; "megalopolis" eyaletleri tavana yakındır.
2. **Deniz varışları liman şehrinin bölgesine iner.** Sürü doğumu ve hedef seçimi bölge ağırlığıyla yapılır:
   `w_p = şehir_nüfusu_p + (N_s − Σ şehir_nüfusu_s) · A_p / A_s`. Şehir bölgesi önce hedef olur, önce düşer.
3. **Bölge kontrolü** sürünün girdiği savunmasız bölgede değişir (mevcut işgal kodu). Eyalet düştüğünde, içinde tümen bulunmayan
   bütün bölgeleri `UND`'ye geçer.

İki yamalı model (şehir + kırsal) açık sorudur (§16-4). Hesap maliyeti iki katına çıkar (ölçülen maliyet doğrusal, §12). Ayrıca şehir
alanı verisi yoktur, uydurulması gerekir.

## 5. Yayılma yolları

### 5.1 Katmanlar

| Yol | Ne taşır | Hız | Veri | 1936 dayanağı |
|---|---|---|---|---|
| Kara yolu + demiryolu (komşu eyaletler) | E, F (½ oranında) | Aynı gün | Bölge komşuluğundan eyalet komşuluğu: 3.763 çift, ortalama 4,56 komşu; 156 eyaletin kara komşusu yok | 1918 Hindistan'ında demiryolu uzak yayılmanın ana aracıydı (Reyes ve ark. 2018) |
| Başkent hattı | E, F | < 1.500 km ise aynı gün, uzaksa gemi süresi | `states.json` → `capitals` | Yönetim ve ticaret trafiği; sömürge–merkez hattı |
| Deniz hatları | E, F; yolda H'ye döner | 533 km/gün (12 knot) | `cities.json` `port`: 528 liman şehri, 295 eyalet | Kolera 1830'da Astrahan'dan Volga boyunca, 1892'de Hazar vapurlarıyla yayıldı |
| Hava | — (ihmal) | — | İsteğe bağlı `air_routes` | 1938'de dünyada ~2,7 milyon hava yolcusu |
| Mülteci | S, E, F, R, V | Aynı gün | Komşuluk | Anvers 1914, Retirada 1939 |
| Sürü yürüyüşü | H (dağınık) | Bir eyalet 15–30 günde geçilir | Komşuluk + nehir | 02 §2.4 |
| Sürü birimi | 10.000 Boş | 0,6 km/sa (04 §3.2) | Bölge komşuluğu | 04 |
| Nehir | Yürüyüşe engel | — | `river_adj`: 1.522 eyalet sınırı (%40) nehirden geçer | Rakun kuduzu: büyük nehirler yerel yayılmayı 7 kat yavaşlattı |

### 5.2 Yolcu katmanı (kara, demiryolu, başkent)

```
o_i      = 0.003 · altyapı_i / 3 · (1 − yasak_i)          günlük dışarı giden pay (altyapı 1–5, states_1936.json)
w_ij     = N_j / max(r_ij, 50 km)²                         en güçlü 5 kara komşusu + başkent (ağırlık ×4)
pay_ij   = w_ij / Σ_k w_ik
x_ij^E   = o_i · pay_ij · b_ij · E_i ;   x_ij^F = ½ · o_i · pay_ij · b_ij · F_i
```
- **Yalnız E ve F taşınır**; bu "gidip gelen yolcu" (commuting) yaklaşımıdır. Sağlam yolcu geri döner ve net akışı sıfırdır.
  Boşlar yolculuk edemez. Eyalet nüfusu yalnız mülteciyle kalıcı olarak değişir.
- **Beklenen sayı 20'nin altındaysa stokastik yuvarlama** uygulanır: `taban(x) + [u < kesir(x)]`. Böylece 0,3 kişilik yolcu
  ortalamada korunur ama tek tek gelir (§3.4).
- `b_ij` sınır ve kordon çarpanıdır (§7).
- **Başkent ağırlığı 4** bir tasarım değeridir: yönetim, demiryolu düğümü ve ticaret merkezi. Denge testiyle ayarlanır.

**Kalibrasyon** (0,3 %/gün, 02'de "yılda bir eyalet dışı yolculuk" diye varsayılmıştı):

| Ölçüt | Hesap | Sonuç | Model (altyapı ağırlıklı) |
|---|---|---|---|
| ABD 1930 | Demiryolu 34 milyar yolcu-mil ÷ 123 M kişi ÷ 365 = 0,76 mil/kişi/gün. ABD eyaletinin ortalama genişliği ~355 km ≈ 220 mil | Demiryoluyla ≤ %0,35/gün (üst sınır; otomobil yolculuğu 175 milyar mil ayrıca vardır) | Altyapı 4,77 → %0,48/gün |
| Britanya Hindistanı 1918 | 459 milyon demiryolu yolcusu ÷ ~387 milyon kişi (modeldeki RAJ nüfusu) | Her tür yolculuk %0,33/gün; eyalet dışına çıkanlar bunun üçte biri ile yarısı → %0,1–0,16/gün | Altyapı 1,97 → %0,20/gün |
| Dünya | Nüfus ağırlıklı ortalama altyapı 2,92 | — | %0,29/gün (02 ile uyumlu) |

Model iki örnekte de ölçülen değerin biraz üstünde ama aynı büyüklük düzeyinde çıkıyor (ABD'de otomobil yolculuğu eklenince fark
kapanır). Biraz yüksek hareketlilik, bilgi sisi altında "sızıntı" hissini güçlendirir; denge testiyle aşağı çekilebilir.

### 5.3 Deniz hatları

**Seçim** (her liman eyaleti için, yükleme sırasında bir kez hesaplanır):
1. 20 günlük seyir içindeki **yabancı** limanlardan `liman_nüfusu_j / deniz_mesafesi` ile en güçlü **2** hat.
2. 30 gün içindeki en büyük yabancı limana **1 uzak hat**.
3. **Her hat çift yönlüdür.** i→j hattı varsa j→i de eklenir.

Mesafe `data/map/sea_lanes.json` ağında en kısa yoldur (prototipte büyük çember × 1,3). Yurt içi limanlar kara ve başkent bağlarıyla
zaten bağlıdır. Prototipte deniz hatlarını yurt içinden de seçmek Japonya'yı kapalı bir ada yaptı: salgın adada kalıp söndü.
Yakın (590) ve uzak (236) hatlar birlikte 826 tek yönlü hattır; çift yönlü yapılınca 1.618 olur. 37 liman eyaletinin 8'den çok bağı
olur, en büyük merkezin 196 bağı vardır.
Toplam bağlantı 8.463'ten 9.491'e çıkar; maliyet doğrusaldır (+%12).

**Yolda ilerleme.** Kuluçkada gemiye binen bir yolcu τ gün sonra şu evrelerde varır (tedavisiz; kapalı biçim
`P_E = e^(−στ)`, `P_F = σ/(γ−σ)·(e^(−στ) − e^(−γτ))`):

| τ (gün) | 1 | 2 | 3 | 5 | 7 | 10 | 14 | 20 |
|---|---|---|---|---|---|---|---|---|
| Hâlâ E | 0,72 | 0,51 | 0,37 | 0,19 | 0,10 | 0,04 | 0,01 | 0,00 |
| F (belirtili) | 0,26 | 0,42 | 0,50 | 0,53 | 0,47 | 0,36 | 0,22 | 0,10 |
| H (Boş) | 0,02 | 0,06 | 0,12 | 0,26 | 0,39 | 0,55 | 0,69 | 0,81 |
| Oyunda (günlük ayrık adım): E / F / H | 0,67 / 0,33 / 0 | 0,44 / 0,51 / 0,04 | 0,30 / 0,58 / 0,11 | 0,13 / 0,58 / 0,26 | 0,06 / 0,49 / 0,40 | 0,02 / 0,34 / 0,57 | 0 / 0,20 / 0,72 | 0 / 0,08 / 0,83 |

Oyunda yolculuk, eyalet içi adımın τ kez yinelenmesiyle hesaplanır (yalnız çarpma ve toplama, §3.3). Ortalama süreler aynıdır
(E 3 gün, F 7 gün); ayrık şemada dağılımın kuyruğu biraz daha kısadır.

- 12 knotta Atlantik ~10 gün sürer. Bu sürede kuluçkadakilerin %96–98'i belirti gösterir. **Uzun seyir kendiliğinden bir karantinadır.**
  Yeter ki limanda denetim olsun. 1926 Uluslararası Sıhhiye Sözleşmesi de bu mantıkla, vebalı limandan gelen gemi yolda altı tam gün
  geçirmediyse inenleri altı günü dolana kadar gözetim altında tutuyordu.
- Varışlar gecikmeli bir halkaya yazılır (`gün + τ`; 32 günlük halka, yalnız 295 liman eyaleti). **H varışı** olursa ve limanda sağlık
  denetimi yoksa Boşlar karaya çıkar. Denetim varsa olay gelir.

> **Olay: "Sarı Bayraklı Gemi" / "The Yellow Flag"** (limana belirtili yolcu ya da Boş taşıyan gemi geldiğinde)
> EN: *"A steamer from an infected port is anchored off the breakwater under the yellow flag. The port physician reports fever
> aboard and two passengers restrained below deck."*
> TR: *"Salgınlı bir limandan gelen vapur, sarı bayrakla mendireğin açığında demirli. Liman hekimi gemide ateşli hastalar olduğunu,
> iki yolcunun ambarda zapt edildiğini bildiriyor."*
> Seçenekler: gemiyi 14 gün karantinada tut (yolcu akışı kesilir, konvoy verimi düşer) · hastaları al, sağlamları bırak
> (F ve H yakalanır, E geçer) · gemiyi geri çevir (diplomasi bedeli; gemi başka limana gider).

### 5.4 Hava yolu

1938'de Japonya'nın hava yolu şirketi yaklaşık 70.000 yolcu taşıdı ve bu dünya yolcu trafiğinin %2,6'sıydı. Buradan dünya toplamı
yılda ~2,7 milyon yolcu çıkar. Yalnız Britanya Hindistanı'nın demiryolu 1918'de 459 milyon yolcu taşımıştı. Hava yolu yolculukların
binde birinden azdır, bu yüzden **ayrı katman yoktur**. Veride boş bir `air_routes` dizisi bulunur; modcu isterse bir hat ekler
(`{"from": 830, "to": 1337, "daily": 40}`). Hat, deniz hattı gibi gecikmeli varış kullanır, τ = 1.

### 5.5 Mülteciler

```
korku_s = clamp( (H_top/T − 0.02) / 0.18 , 0, 1 )          Boş payı %2'de başlar, %20'de doyar
r_s     = 0.03 · korku_s · (1 − tahliye_yasağı_s)          günlük kaçan pay
hedef   ∝ L_j · güven_j · n_ij,   güven_j = clamp(1 − 10 · yaygınlık_j, 0, 1),  n_ij: nehir 0,5
taşınan : S, E, F, R, V (payları kaynaktaki gibi; panik seçici değildir)
```
**Kalibrasyon:** Anvers 10 Ekim 1914'te düşünce iki haftadan kısa sürede 1 milyondan fazla kişi Hollanda'ya geçti. Bu, bir eyalet
nüfusunun günde ~%5–7'si demektir. Retirada'da 28 Ocak–15 Şubat 1939 arasında ~475.000 kişi Katalonya'dan (~2,9 milyon) Fransa'ya
geçti, yani günde ~%0,9. Model bu ikisinin ortasını alır: günde en çok **%3**.

**Sınırda bekleme havuzu.** Hedef başka bir ülkeyse mülteciler sınırda bir havuzda birikir. Oyuncunun ülkesi için 02 §1.2'deki
"Sınırda mülteciler" olayı gelir: kabul, karantinalı kabul (14 gün kamp) ya da ret. Aynı kaynak eyaletten en çok 30 günde bir olay
gelir. Yapay zekâ ülkelerini kendi kuralları yönetir. "Kapalı" sınır havuzun yalnız %5'ini sızdırır. Kamp 04 §7.2'de Kızgın suşun
tetiklerinden biridir.

**Ölçülen etki** (orta yanıt senaryosu, 6 tohum): mülteci katmanı kapatılınca Türkiye'ye varış ve Evre 3 günleri değişmedi. 1940'ta
dünyada yaşayanların payı %7–8'den %6,7–6,8'e indi. Kaçış başladığında (Boş payı ≥ %2) salgın komşuya zaten yolcuyla ulaşmış olur.
Kaçanların çoğu sağlamdır ve hayatta kalır. Bu sonuç 01'deki "Kimse tek başına kurtulamaz" sütununu sayıyla destekler: mülteci kabulü
bir bulaş felaketi değildir. Yerel bedel ise gerçektir: kafileyle kaynak eyaletteki kuluçkalı payı (E/L) kadar kuluçkalı gelir ve bunlar taramada görünmez (§8.3).

### 5.6 Sürü yürüyüşü (dağınık H)

```
y_ij = H_i · (0.01 + 0.09 · (1 − S_i/N⁰_i)) · mevsim_i · L_j·n_ij / Σ_k L_k·n_ik · (1 − g_ij)
mevsim_i = 1 − 0.45·çamur_i − 0.25·kış_i          (Military._speed'deki katsayılar)
n_ij     = 1 (kara), 0.5 (nehir), 0.15 (köprüler yıkılmış), 1 (boğaz, land_crossing)
g_ij     = sınır bölgelerinden tümen tutulanların payı, ≤ 0.9
```
- Temel formül 02 §2.4'tendir. Hız 04 §3.2'deki 14,4 km/gün ile uyumludur: ~285 km'lik eyalet ~20 günde geçilir.
- **Nehir ×0,5.** 04 §2.4 nehir geçişine −0,6 saldırı cezası verir; gerekçe olarak kuduz hastalarının yaklaşık yarısındaki su korkusunu
  gösterir. Rakun kuduzu çalışmasında büyük nehirler yerel yayılmayı 7 kat yavaşlatmıştı. Haritadaki `river_adj` küçük nehirleri de
  içerdiği için varsayılan değer 2 kattır (×0,5). Oyuncu köprüleri yıkarsa sınır 7 kat yavaşlar (×0,15). Bu bir olay ya da karar olur,
  bedeli ticaret ve ikmaldir. 04 §7.2'deki "Suya dayanım" özelliğinin tetiği "nehre dayalı kordon"dur, bu yüzden nehir ucuz ama kalıcı
  olmayan bir çözümdür.
- **Kordon.** `g_ij` iki eyaletin ortak sınırındaki bölgelerden, kendi ya da müttefik tümeni bulunanların payıdır. Ortak sınır bölgeleri
  yüklemede bir kez hesaplanır. Tam tutulan sınır dağınık yürüyüşün %90'ını durdurur. Kalan %10 sızıntıdır ve hedefte κ_asker'e düşer.
  Birim hâlindeki sürüler ise muharebeyle durur (04 §3.3).
- **Karşılaştırma:** Kara Ölüm'ün karadaki cephesi günde ~0,4–1,8 km ilerlemişti. Boş cephesi (10–19 km/gün) bundan on kat hızlıdır,
  ama asıl sıçramayı yolcu katmanı yapar: aynı gün yüzlerce kilometre.

### 5.7 Nehirler: taşıyıcı mı?

Kolera tarihte nehir ticaretiyle yayıldı (Volga). Ama haritada gezilebilir nehir verisi yok; `river_adj` yalnız geçişi gösterir.
Sürüm 1'de nehir yalnız engeldir. Modcu, isterse elle yazılmış nehir hatları ekleyebilir: `river_routes`, eyalet zinciri + günlük yolcu
(ör. Tuna, Volga, Yangzi, Nil). Bunlar deniz hattı gibi işler (§14).

### 5.8 Prototip: gerçek harita üzerinde 6 tohum

Python ve numpy ile yazıldı. Model bu belgedeki denklemleri kullanır ve 1.652 eyaletin hepsini, gerçek komşuluğu, liman ve başkent
verisini ve iklimi içerir. Serum, aşı, sürü muharebesi ve gerçek yapay zekâ **yoktur**. Sayılar, salgın motorunun ham gücünü ve
yapay zekânın ne kadar sert yanıt vermesi gerektiğini gösterir; nihai denge değildir.
- **Orta yanıt:** Ülke ilk tespitinden 6 gün sonra bütün eyaletlerinde β'yı ×0,65 yapar. Vakası binde 1'i aşan eyaletlerde κ'ya +0,05
  eklenir. Dünyadaki ilk tespitten 14 gün sonra uluslararası yolcu ×0,5, mülteci ×0,5 olur.
- **Güçlü yanıt:** β ×0,5, κ +0,15, uluslararası yolcu ×0,05, mülteci ×0,1.

| Ölçüt (6 tohum, aralık) | Yanıt yok | Orta | Güçlü | 02 hedefi |
|---|---|---|---|---|
| İlk tespit (gün) | 7–22 | 7–22 | 7–22 | 8–31 |
| Türkiye'ye ilk vaka (gün) | 24–67 | 24–87 | 24–140 | 40–90 (02 §9) |
| KSE ≥ 1 (gün) | 46–87 | 66–112 | 103–150 | Evre 2: 60–150 |
| KSE ≥ 15 (gün) | 95–134 | 137–181 | 213–289 | Evre 3: 150–400 |
| Yaşayan, 1. yıl sonu | %1–2 | %27–34 | %82–93 | — |
| Yaşayan, 2. yıl sonu | %1 | %10–11 | %44–47 | — |
| Yaşayan, 1 Ocak 1940 | %1 | %7–8 | %39 | %35–75 (kontrol 8) |
| En çok düşmüş eyalet | 1.400–1.438 | 424–438 | 112–119 | — |
| Sürü birimi, tüm H / 10.000 | 18.721–20.912 | 4.867–5.858 | 882–1.060 | ≤ 1.200 |
| Sürü birimi, yalnız cephe, eyalet başına ≤ 3 | 1.032–1.227 | 897–1.018 | 344–370 | ≤ 1.200 |

Deniz hatları tek yönlü olunca (yanıt yok) Türkiye'ye varış 51–361. güne uzar. 1940'ta yaşayan payı %5–6 olur, çünkü merkezler zayıf
bağlanır. Güçlü yanıtta kapalı uluslararası sınırlar Türkiye'ye ilk vakayı medyanda ~46 günden ~85 güne ertelemiş, ama durdurmamıştır.
Bu, grip salgını çalışmalarının bulgusuyla aynıdır: seyahat kısıtları %99'dan etkin değilse yayılmayı ancak 2–3 hafta, %99,9'da bile
en çok ~4 ay geciktirir.

**Sonuçlar:**
1. 02 kontrol 8'e (yaşayan %35–75) ulaşmak için yapay zekâ en az "güçlü" düzeyde yanıt vermeli ve serum/aşı devreye girmelidir. Bu
   sayılar yapay zekâ belgesine hedef olarak verilir.
2. Sürü sınırı ancak **cephe kuralıyla** tutar (§10).
3. Evre 1→2 için KSE ≥ 1 koşulu, yanıt düzeyinden bağımsız olarak hedef aralığa oturuyor.

### 5.9 İlk tespit ve başlangıç yeri

İndeks küme 25 kişidir, hepsi −21. günde E'dedir. Tanınmamış hastalıkta tespit 0,08'dir. Tespit koşulu "0,08 × (F + H) ≥ 50"dir.
Bu ayarla d = 1 / 1,93 / 3 için tespit günü 31 / 15 / 8 çıkar (02 §11 ile aynı). 200 kişilik 50/30/20 karışımı ise 28 / 12 / 5 verir.
295 liman eyaletinde başlangıç ağırlığına göre ilk tespit günü dağılımı:

| Ağırlık | 8–31. günde | < 8 | > 31 | Medyan | %10–%90 |
|---|---|---|---|---|---|
| Liman nüfusu (02) | %84 | %0 | %16 | 14 | 8–40 |
| **Liman nüfusu × d** | **%95** | %0 | %5 | 10 | 8–28 |
| Liman nüfusu, yalnız d ≥ 1 | %100 | %0 | %0 | 11 | 8–25 |
| Liman nüfusu² | %96 | %0 | %4 | 8 | 8–28 |

Karar: **liman nüfusu × d**. Seyrek limanlarda nadir, yavaş başlangıçlar (Avustralya, Uruguay) çeşitlilik olarak kalır.

## 6. Mevsim ve iklim

| Etki | Formül | Gerekçe |
|---|---|---|
| Boş ömrü | `iklim = max(1 + kış, çöl)`, en çok 2,0; kış = `Military.winter_level` (0 / 0,6 / 1,0) | 02. Soğuk stresi evsizlerde ölüm riskini orta soğukta bile 1,84 kat artırır; evsizlerde hipotermi ölümü genel nüfusun 13 katıdır. Boşlar barınmaz |
| Çöl | 1,6; eyaletin ≥ %50 bölgesi `desert` ise (173 eyalet) ve \|enlem\| < 35° ya da yaz ayıysa | Çöl ve tropikte iş sırasında ter kaybı saatte 0,3–1,5 litredir; su bulamayan Boş'un ömrü kısalır. 02'deki 1,6 bu yüzden ılımlı bir değerdir |
| Isırık | β × (1 − 0,25·kış) | Hafif hipotermide (32–35 °C) ataksi ve konuşma bozukluğu, 32 °C altında stupor görülür |
| Yürüyüş | × (1 − 0,45·çamur − 0,25·kış) | Tümen hızındaki katsayıların aynısı; kar ve çamur herkesi yavaşlatır |
| Kışlayan tablosu | Kışta μ × 0,7 | 04 §3.4 (poikilotermi, metabolizmanın yavaşlaması) |

Kışın etkilenen eyaletler: \|enlem\| > 45° olan 480 eyalet (196'sı 55°'nin üstünde, sert kış). Güney yarıkürede 10 eyalet vardır.

**R₀ mevsime göre:**

| d | Ilıman | Sert kış (kış = 1) | Sıcak çöl |
|---|---|---|---|
| 0,35 | 2,23 | 1,24 | 1,84 |
| 0,64 | 2,75 | 1,68 | 2,42 |
| 1,00 | 3,11 | 2,02 | 2,85 |
| 3,00 | 4,10 | 2,93 | 3,98 |

**"Kış müttefiktir ama çare değildir":** sert kışta bile R₀ her yerde 1'in üstünde kalır. Kış salgını yavaşlatır, kordona zaman
kazandırır, ilkbaharda da salgın "uyanır". 04'teki "Bahar Uyanışı" olayı bununla uyumludur. İnsan hareketliliğinin mevsimselliği
(hasat göçü) sürüm 1'de yoktur. Dinî ziyaret gibi hareketler ise bilinçli olarak modellenmez (01 §6.4).

## 7. Karantina, sınır kapatma ve kordon

**Birleştirme kuralı.** Aynı eyalette birden çok önlem varsa bulaş azaltmaları çarpılarak birleşir: `m = 1 − Π(1 − ö_k)`. Toplam
en çok 0,75 olabilir. Gerekçe: 1918'de en başarılı ABD şehirlerinde önlemler bulaşı %30–50 azaltmıştı. Boşlar önlemden bağımsız
saldırır. Tavan, "önlemle R'yi sıfırlama" kestirmesini kapatır ve aşının anlamını korur (02 §4.1).

| Önlem | Model etkisi | Değer | Gerekçe |
|---|---|---|---|
| Zorunlu Karantina (yasa) | β çarpanı | −0,35 | 02; 1918'deki %30–50 aralığının içinde |
| Halkı bilgilendirme (olay/yasa) | β | −0,10 (öneri) | 1918'de önlemi erken ve birden çok alan şehirlerde ölüm tepesi ~%50 daha düşüktü; bilgi, katmanlı önlemin bir parçasıdır |
| Sıkıyönetim (02 olayı) | β, κ | −0,15; κ +0,05 | 02 §3.4 |
| Sivil savunma (yasa) | κ_sivil çarpanı | ×1,5 (öneri) | Silah dağıtmanın bedeli 02 Sütun 3'te |
| Yurt içi seyahat yasağı | o_i | ×0,2 | Kordonlar tarihte hep sızdırdı (02 §2.4) |
| Sınır tutumu | b_ij | açık 1 · denetimli 0,5 · kapalı 0,05 | 02 §2.4; kapalı sınır da %5 sızdırır |
| Liman karantinası (k gün) | Deniz varışında E geçişi | `(1 − σ)^k` | §8.3 |
| Kordon ordusu | Kordonlu eyaletten çıkan yolcu, yürüyüş | `× (1 − 0,9·g)` | §5.6 |
| Köprüleri yık | n_ij | 0,15 | §5.6 |

**Geciktiren ve durduran.** Sınır kapatmak geciktirir, durdurmaz (§5.8). Durduranlar yerel önlemlerdir (β↓, κ↑) ve bilimdir (serum,
aşı). Oyuncu ipucunda bu ayrımı görür: *"Kapalı sınır zaman kazandırır. Zamanı sen kullanırsın."*

**Etki sözlüğüne eklenecek anahtarlar** (CLAUDE.md kural 2; `Politics.apply_effects` ve `describe_effects`'e birlikte):

| Anahtar | Değer | Kapsam | describe (EN / TR) |
|---|---|---|---|
| `transmission` | −0,35 gibi | ülke ya da eyalet, gün | "Transmission %+d%%" / "Bulaş %+d%%" |
| `suppression` | +0,05 gibi | ülke ya da eyalet, gün | "Suppression %+.2f" / "Bastırma %+.2f" |
| `travel` | ×0,2 gibi | ülke, gün | "Internal travel ×%.2f" / "Yurt içi yolculuk ×%.2f" |
| `border_posture` | open / controlled / closed | komşu ülke | "Border with %s: %s" / "%s sınırı: %s" |
| `port_quarantine_days` | 0–40 | ülke | "Port quarantine: %d days" / "Liman karantinası: %d gün" |
| `detection` | +0,15 gibi | ülke, gün | "Detection %+d%%" / "Tespit %+d%%" |
| `report_delay` | −2 gibi | ülke, gün | "Reporting delay %+d days" / "Bildirim gecikmesi %+d gün" |
| `refugee_policy` | accept / camp / refuse | ülke | "Refugees: %s" / "Mülteciler: %s" |

## 8. Test, tarama ve bildirim (gözetim)

### 8.1 Bildirilen vaka

```
belirti_s(t)          = σ · E_s(t)                            (yeni Ateşli = belirti başlangıcı)
bildirilen_s(t + g_s) = yuvarla( p_s · belirti_s(t) )         stokastik yuvarlama, akış 6
```
- **Tespit oranı p_s:**
  - Evre 0'da (etken tanınmamış) `p = tespit_bilinmeyen` (zorluğa göre 0,12 / 0,08 / 0,05; 02 §7.1).
  - Sonra `p = clamp(0,15 + 0,10·(altyapı_ort,c − 1) + Σ ek − 0,10·sömürge, 0,10, 0,95)`. Altyapı ortalaması 1 olan ülkede taban 0,15,
    5 olan ülkede 0,55'tir. Ekler şunlardır: "Tuhaf Raporlar" olayı +0,15 (02 §3.4), gözetim araştırmaları, araştırma merkezi olan
    eyalette +0,05, laboratuvar testi (T1) +0,15.
  - Sömürgedeki −0,10 tarihî gerçekliği yansıtır: sağlık yatırımı azdı (01 §6.4). Olaylar bu açığı kapatma seçeneği sunar.
- **Gecikme g_s:** `clamp(g_taban − iletişim ekleri + 2·[başkente > 1.500 km], 3, 10)`. Taban zorluğa göre 3 / 6 / 9 gündür (02).
- **Düşmüş eyalet bildirim yapmaz** (p = 0). Panelde "Veri yok" yazar. Sessiz kalan eyalet de bir bilgidir.
- Halka: eyalet başına 16 günlük bildirim tamponu (1.652 × 16 sayı).

### 8.2 Yabancı ülkelerin verisi

1926 Sözleşmesi hükümetlere ilk gerçek veba, kolera ya da sarı humma vakasını "hemen" diğer hükümetlere ve Paris'teki
Uluslararası Halk Sağlığı Bürosu'na bildirme yükümlülüğü getiriyordu. Ardından yer, tarih, vaka ve ölüm sayıları gelirdi. Modda:
- Bir ülkenin **ilk** tespiti o hafta cuma bülteninde yer alır.
- Sonrasında her cuma, ülkenin kendi gecikmesiyle bildirdiği sayılar gelir. Bu sayılar ülkenin şeffaflık katsayısıyla çarpılır
  (0,3–1,0). Katsayı yapay zekâ ve diplomasi kurallarından gelir; ayrıntısı o belgelerdedir.
- Oyuncu kendi ülkesinin verisini her gün görür (kendi gecikmesiyle). Yabancı veriyi yalnız haftalık görür.

### 8.3 Tarama noktaları ve test düzeyleri

Tarama, geçen akıştaki hastaları yakalar. Yakalananlar ayırmaya alınır ve yayılmaz (panelde "yakalanan" diye sayılır).

| Düzey | Nasıl açılır | E'yi yakalar | F'yi yakalar | H'yi yakalar | Dayanak |
|---|---|---|---|---|---|
| T0 Klinik muayene | Başlangıç | 0 | 0,6 | 1,0 | Belirtisiz kuluçka dönemi taramayla görülmez |
| T1 Laboratuvar doğrulaması | "Etkenin tanımlanması" (araştırma) | 0 | 0,85 | 1,0 | Mikroskopi ve serum testi yalnız belirtiliyi doğrular |
| T2 Kuluçka testi | Geç araştırma (öneri) | 0,5 | 0,95 | 1,0 | Yarı duyarlı bir kan testi |

Yolcu taramasıyla ilgili modelleme çalışmaları, taramanın kaçırdığı vakaların çoğunun "henüz belirti vermemiş" olduğu için temelde
görünmez olduğunu gösterir. Bu yüzden asıl araç **bekletmedir**:

```
geçen_E = E · (1 − s_E) · (1 − σ)^k        k gün karantina: bekleyen kuluçkalı belirti gösterir ve yakalanır
                                           (sürekli zamanda e^(−σk); oyun ayrık adımı kullanır, §3.3)
geçen_F = F · (1 − s_F)
```

| k (gün) | 0 | 3 | 5 (1926, kolera) | 6 (1926, veba) | 7 | 10 | 14 | 21 |
|---|---|---|---|---|---|---|---|---|
| Belirtisiz kalan E payı | 1,00 | 0,37 | 0,19 | 0,14 | 0,10 | 0,036 | 0,009 | 0,001 |
| Oyunda, `(1 − σ)^k` | 1,00 | 0,30 | 0,13 | 0,088 | 0,059 | 0,017 | 0,003 | 0,0002 |

Tarama noktaları şunlardır: "denetimli" kara sınırı (akış ×0,5 ve T düzeyi), liman sağlık denetimi (T düzeyi ve k günlük karantina),
ordu karantinası (tümen, 04'teki ordu içi bulaş) ve mülteci kampı.

## 9. Bağışıklık ve direnç

| Konu | Karar | Gerekçe |
|---|---|---|
| İyileşen (R) | 4 yıllık oyunda kalıcı bağışık (`recovered_waning` = 0) | Pek çok akut viral enfeksiyon uzun bağışıklık bırakır. Modcu, azalan bağışıklık (SIRS) için değeri > 0 yapabilir |
| Aşı etkinliği | Sızdıran, 0,9: V'nin enfeksiyon riski S'nin %10'u | Sızdıran aşıda kritik kapsam da `(1 − 1/R)/e_V`'dir, yani 02'deki V_c formülü aynen geçerlidir. Ayrıca "aynı kişiyi tekrar aşılayarak %100" açığı kapanır |
| Bağışıklığın gelişmesi | Vb, 10 günlük halka; bu sürede S gibi enfekte olur | 17D'de aşılananların %95'inden fazlası 10 gün içinde bağışık olur. Salgının göbeğinde aşı, sürekli kordon gerektirir |
| Doğal direnç | **Yok.** `innate_immune_share` = 0; > 0 yapılırsa her eyalete **aynı** oranda uygulanır | 01 §6.4: enfeksiyonu etnik köken, din ya da ideolojiyle değiştiren değişken yoktur |
| Serum direnci | 04 T12 Dirençli suş: serum etkinliği ×0,5 | 04 §6 |
| Aşı kaçağı | 04: e_V 0,9 → 0,7 (yalnız Kara Yıl) | 04 §6 |

## 10. Sürüler: oluşum, göç, eşleme

04 §2.1'deki korunum kuralı aynen geçerlidir: `H_s(toplam) = H_dağınık,s + Σ birim strength × 10.000`. Birimler takviye almaz,
μ ile erir, bütünlüğü %12'nin altına inince dağılır ve kalanlar dağınık H'ye döner (04 §2.4). Bu belge doğumun **nerede ve kaç tane**
olacağını belirler.

**Sorun (prototipte ölçüldü):** 04'teki "dağınık H ≥ 10.000 → sürü doğar" kuralı yalnız kalırsa en çok birim sayısı yanıt yokken
18.721–20.912, orta yanıtta 4.867–5.858 olur. 1.200'lük sınır tutmaz.

**Kural: sürüler yalnız cephede doğar.**
1. **Cephe eyaleti:** Dağınık H ≥ 10.000 olan ve kendisi DÜŞMÜŞ olmayan ya da DÜŞMÜŞ olmayan bir kara komşusu bulunan eyalet.
   İç eyaletlerde (her yanı düşmüş) bütün Boşlar dağınıktır: haritada birim yoktur, eyalet düşmüş görünür.
2. **Eyalet başına en çok 3 birim** (web'de 2). Günde en çok 1 doğum olur, doğum `w_p`'si en yüksek bölgede gerçekleşir (§4).
3. **Dünya sınırı 1.200** (01; web önerisi 800, §12). Sınır dolunca sıra şöyledir: (a) oyuncunun ülkesindeki ya da ona komşu eyaletler,
   (b) herhangi bir ordunun komşu olduğu eyaletler, (c) H'si büyük olanlar.
4. Ölçülen sonuç: cephe kuralıyla en çok birim yanıt yokken 1.032–1.227, orta yanıtta 897–1.018, güçlü yanıtta 344–370 olur.
   Eyalet başına 2 birim bu sayıları ~2/3'e indirir.

**Göç (hedef seçimi).** Hedef her gün `UND` yapay zekâsında seçilir. Komşu bölgelerin puanı
`w_p · (L_s / N⁰_s) / (1 + o bölgedeki tümen sayısı)`'dır. En yüksek 3 bölge arasından puanla ağırlıklı ve karmalı (akış 7) seçim
yapılır. Böylece sürüler tek noktaya yığılmaz. 04'teki top sesi çekimi ve Kösemen önder etkisi bu puanın üstüne eklenir. Denizi
geçemezler; `land_crossing` olan boğazları geçerler.

**Kontrol.** Sürü savunmasız bölgeye girince bölge `UND`'ye geçer (mevcut işgal kodu). Bunun için `UND` herkesle kalıcı savaştadır.
Eyalet DÜŞMÜŞ olunca içinde tümen bulunmayan bütün bölgeleri `UND`'ye geçer. Arındırmada bölgeler, tümen girdikçe mevcut kodla
sahibine döner.

**Dağınık ile birim arasındaki iş bölümü.** Dağınık yürüyüş, cepheyi sessizce aşan "sızıntıdır"; karşılığı hedef eyaletteki κ_asker'dir.
Birim ise "dalgadır"; karşılığı muharebedir (04 §3.3: siperli piyade tümeni 3 sürüyü tutar). Oyuncu iki şeyi birden yönetir:
**hattı tutmak** (birimlere karşı) ve **hattın arkasını temiz tutmak** (sızıntıya karşı garnizon).

## 11. Belirlenimcilik ve tohum

### 11.1 Dünya tohumu
- `world_seed` (31 bit) yeni oyunda global `randi()`'den alınır. Böylece mevcut `seed()` tabanlı testler (`test_determinism.gd`)
  onu da kapsar. Özel ayarlarda oyuncu tohumu elle girebilir ("Salgın tohumu"); aynı salgın paylaşılabilir. Tohum kayda yazılır.
- Salgın **global `randf()` kullanmaz.** Mevcut sistemler (yapay zekâ, muharebe) global üreteci kullanıyor ve durumu kayda yazılmıyor.
  Salgın ayrı kalırsa bir salgın parametresini değiştirmek yapay zekânın kararlarını "kelebek etkisiyle" değiştirmez.

### 11.2 Sayaç tabanlı karma (durumsuz üreteç)

Her çekiliş `(tohum, gün, akış, a, b)` beşlisinden hesaplanır. Durum yoktur, kayda bir şey yazılmaz, eyaletlerin işlenme sırası sonucu
değiştirmez. Aşağıdaki kod ölçümde kullanılan sürümdür (Godot 4.7.2):

```gdscript
## FNV-1a benzeri 32 bit karma: 16 bitlik parçalar; çarpım 2^57'yi, son çarpım 2^62'yi aşmaz (int64 taşmaz, platformdan bağımsız)
static func h32(a: int, b: int, c: int, d: int) -> int:
	var h: int = 2166136261
	h = ((h ^ (a & 0xFFFF)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ ((a >> 16) & 0xFFFF)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ (b & 0xFFFF)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ (c & 0xFFFF)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ ((c >> 16) & 0xFFFF)) * 16777619) & 0xFFFFFFFF
	h = ((h ^ (d & 0xFFFF)) * 16777619) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 0x2C1B3C6D) & 0xFFFFFFFF
	h ^= h >> 12
	return h

## [0, 1) aralığında tekdüze sayı. a: tohum ^ gün, b: akış, c: nesne (eyalet/bağlantı), d: alt sıra
static func u01(world_seed: int, day: int, stream: int, obj: int, sub: int) -> float:
	var h: int = h32(world_seed ^ day, stream, obj, sub)
	return float(h) / 4294967296.0
```

| Akış | Kullanım | `obj`, `sub` |
|---|---|---|
| 1 | İndeks eyalet seçimi | 0, 0 |
| 2 | Yolcu yuvarlama | bağlantı no, bölme (E = 0, F = 1) |
| 3 | Deniz varışı | hat no, bölme |
| 4 | Sürü yürüyüşü yuvarlama | yürüyüş kenarı no, 0 |
| 5 | Küçük sayı rejimi (binom/Poisson) | eyalet, geçiş türü |
| 6 | Bildirim yuvarlama | eyalet, 0 |
| 7 | Sürü doğumu ve hedef | eyalet ya da birim, 0 |
| 8 | Mülteci yuvarlama | kenar no, bölme |
| 9 | Suş ortaya çıkışı (04 §7.2) | özellik no, eyalet |
| 10 | Salgın olayları | olay no, 0 |

### 11.3 Platformlar arası aynılık
Günlük adım yalnız `+ − × ÷` ve `sqrt` kullanır (§3.3). Bunlar IEEE 754'te doğru yuvarlanır ve WASM'da da doubledır. Veri JSON'dan
aynı ayrıştırıcıyla okunur. Sabit bağlantı sırası korunursa masaüstü ve web **aynı bitleri** üretmelidir. Bu bir hedeftir, test
edilmelidir (§16-6). Çok oyunculu mod (ROADMAP Faz 10) için ön koşuldur.

### 11.4 Kayıt: ondalık kaybı ölçüldü
Godot 4.7.2'de beş sınama sayısıyla yapılan ölçüm (`0.1+0.2`, `1/3`, `98765432.123…` …):
- Varsayılan `JSON.stringify` (15 anlamlı basamak): **5/5 sayı** yüklemede değişti.
- `JSON.stringify(..., full_precision = true)`: **2/5** yine değişti (ayrıştırma tarafında).
- `Marshalls.raw_to_base64(PackedFloat64Array.to_byte_array())`: **0/5**, birebir aynı.

Bu yüzden salgın bölmeleri kayıtta **base64 ikili** olarak saklanır: 1.652 × 9 sayı × 8 bayt = 119 KB ham, ~159 KB base64. Örnek bir
temel oyun kaydı 576 KB'tır. Halkalar seyrek yazılır (yalnız sıfır olmayan girdiler). Temel oyunun başka ondalık alanları için de aynı
sorun geçerlidir (§16-12).

**Testler:** (1) Aynı tohumla iki koşu bit bit aynı dizileri üretmeli. (2) 200. günde kaydedip yükleyip 400. güne koşmak, kesintisiz
400 günlük koşuyla aynı olmalı. (3) Farklı tohum farklı indeks eyaleti seçmeli.

## 12. Hesap maliyeti ve performans

### 12.1 Ölçüm
Godot 4.7.2, ekransız, tek iş parçacığı, Intel Xeon 2,1 GHz. Ölçülen: yerel denklemler + yolcu akışı (karma yuvarlamayla) + gecikmeli
varış halkası + sürü yürüyüşü. En kötü durumda bütün birimler başlangıçtan etkindir. Bildirim, mülteci ve suş payları ölçüme
katılmadı; bunlar tahminen %30–50 ekler.

| Düzey | Birim | Yolcu + yürüyüş kenarı | Adım/gün | **ms / oyun günü** |
|---|---|---|---|---|
| Eyalet, günlük, karmasız | 1.652 | 7.494 + 7.526 | 1 | **4,2** |
| Eyalet, günlük, karmalı | 1.652 | 7.494 + 7.526 | 1 | **8,2** |
| Eyalet, günlük, başta %10 etkin | 1.652 | aynı | 1 | 3,4 |
| Eyalet, günlük, başta %1 etkin | 1.652 | aynı | 1 | 1,4 |
| Eyalet, saatlik | 1.652 | aynı | 24 | 186 |
| Bölge, günlük (nüfus alanla paylaştırıldı) | 9.827 | 48.320 + 48.320 | 1 | 51 |
| Bölge, saatlik | 9.827 | aynı | 24 | 1.300 |

Bağlantı kurulumu (eyalet) 24 ms, veri yükleme 209–433 ms sürdü.

**Temel oyun (aynı makine, `sim.gd`):**
- 1936 barışı, 120 gün: 13,8 sn, yani **115 ms/gün** (963 tümen).
- 1.000 gün: 149 sn, yani **149 ms/gün** ortalama. Tümen sayısı 1.504'e çıktı, 1 savaş oldu.
- Saatlik askerî iş (hareket + muharebe + toparlanma): 44,6 sn / 24.000 saat = 1,86 ms/saat. Ekonomi 22 ms/gün, yapay zekâ ordu işleri 21 ms/gün.

### 12.2 Tahmini toplam yük

| Kalem | Tahmin | Dayanak |
|---|---|---|
| Salgın adımı (eyalet, günlük) | 6–12 ms/gün | Ölçüm + %30–50 ek |
| 1.200 sürü birimi | +36–60 ms/gün | Tümen sayısı ~%80 artar. Sürüler hep hareket ya da muharebe hâlindedir, bu yüzden tümen başına maliyet ortalamanın üstünde kabul edildi |
| `UND` yapay zekâsı (günlük hedef) | ~5 ms/gün | 1.200 × komşu puanı |
| **Toplam** | **+47–77 ms/gün** | Temel oyuna göre ×1,3–1,5 |

02 kontrol 10'un hedefi en çok ×1,3'tür. Bu yüzden öneriler şunlardır: birim sınırı masaüstünde 1.200'de kalsın ama cephe kuralı
eyalet başına 2 olsun; web'de sınır 800 olsun. Kesin değer `sim.gd` profilinde yeni `epidemic` ve `und` anahtarlarıyla ölçülmelidir.

### 12.3 Neden eyalet + günlük?
- **Bölge düzeyi** eyaletin 7–12 katı (günlük), 160–310 katı (saatlik) pahalıdır. Ayrıca bölge nüfusu verisi yoktur, uydurulması gerekir.
- **Saatlik adım** oynanışa bir şey katmaz: oranlar gün⁻¹'dir, bildirim ve kararlar günlük ya da haftalıktır. Saatlik ölçekte hareket
  eden sürü birimleri zaten saatlik koddadır.
- **Hız 5**'te (10 gün/sn) temel oyun zaten saniyede ~1,5 sn işlemci ister, yani bu hız işlemciyle sınırlıdır. Salgın bunun %4–8'idir.
  Hız 2'de (0,5 gün/sn) salgın saniyede 3–6 ms tutar; hissedilmez.
- **Gün dönümü takılması:** salgın gün dönümünde 4–12 ms ekler. Temel oyunun günlük işleri (ekonomi ~22 ms, yapay zekâ ~21 ms) zaten
  daha büyüktür. Gerekirse **zaman dilimleme** yapılır: eyaletlerin 1/24'ü her saat işlenir, sonuç çift tampona yazılır, gün sonunda
  diziler değiştirilir. Sonuç birebir aynı kalır, saat başına ~0,3–0,5 ms düşer.

### 12.4 Basitleştirmeler (kazanca göre sıralı)
1. Bölge yerine eyalet: ×7–12.
2. Saatlik yerine günlük: ×23–45.
3. Etkin küme: `E + F + H = 0` ve gelen akışı olmayan eyalet atlanır. Oyunun ilk aylarında ×3–6.
4. Karma yalnız beklenen < 20 iken çekilir: ~×2. 20'nin üstünde yuvarlama anlamsızdır.
5. Deniz halkası yalnız 295 liman eyaletinde tutulur: 32 × 295 × 3 sayı.
6. Tür payları belleksizdir (04 §2.3). Suş payları eyalet başına en çok 3'tür.
7. Bağlantılar yüklemede bir kez kurulur (24 ms). İstenirse `tools/` altında önceden hesaplanabilir; modcu hatları da görebilir (§16-2).

**Bellek:** bölmeler ~0,2 MB, deniz halkası ~0,23 MB, bildirim halkası ~0,2 MB, aşı halkası (yalnız aşılanan eyaletler) ≤ 0,13 MB.
Toplam 1 MB'ın altındadır.

**Web:** WASM'daki GDScript'in masaüstünden 1,5–3 kat yavaş olacağı tahmin ediliyor; ölçülmedi (§16-6). Bu tahminle salgın adımı
12–36 ms/gün sürer.

## 13. Harita katmanı (ısı haritası): veri ihtiyacı

### 13.1 Bugün var olan (kod okundu)
- **İşgal çizgisi:** `controller ≠ owner` olan bölge, kontrol edenin palet renginde çapraz çizgilidir (`map3d.gdshader`, `data_tex`
  G kanalı, bayt). Bu **düşmüş bölgeler için hemen çalışır**. `UND`'ye bir ülke dizini (< 256) ve palet rengi verilmesi yeter.
- **İşaret dokusu (`mark_tex`):** Bölge başına bir bayttır (R8, 256 × 53). Gölgelendirici `mk > 0,75` ise bölgeyi **yeşil nabızla**
  boyar, **değilse (0 dahil) %40 karartır**. Yani 128 ile 0 aynı görünür ve dokunun anlamı "inşaata uygun"dur. 01 ve 02'deki
  "128 enfekte, 255 düşmüş" iki düzeyi bu gölgelendiriciyle **oluşmaz**: düşmüş eyalet yeşil yanıp söner. Salgın için kullanılması
  önerilmez (§1, madde 7).

### 13.2 Veri modeli

| Dizi | Boyut | Güncelleme | İçerik |
|---|---|---|---|
| `rep_prev` | 1.652 float | Kendi ülke: günlük (gecikmeli); yabancı: cuma | Bildirilen yaygınlık = son 14 günün bildirilen vakası / N⁰ |
| `rep_trend` | 1.652 float | Aynı | Son 7 gün / önceki 7 gün |
| `data_age` | 1.652 int | Günlük | Son bildirimden bu yana gün; düşmüşte ∞ |
| `status` | 1.652 byte | Günlük | 0 temiz · 1 bildirilmiş · 2 salgın · 3 düşmüş · 4 izlemede · 5 boşalmış (02 §2.5; "maruz" gizlidir) |
| `units` | 1.652 byte | Günlük | Eyaletteki görünür sürü sayısı |
| `epi_bytes` | 13.434 byte | Günlük | Bölge başına kodlanmış değer (gölgelendirici için) |

**Kodlama (öneri):** `0` veri yok ya da temiz. `1–250` bildirilen yaygınlığın log ölçeğidir:
`b = 1 + round(249 · clamp((log10(p) + 5) / 5, 0, 1))`, p ∈ [10⁻⁵, 1]. `251` izlemede, `252` düşmüş, `253` boşalmış.
İsteğe bağlı G kanalı `data_age` (0–255 gün) eski veriyi soluklaştırır. Doku güncellemesi günde 13,6 KB'tır.
Log hesabı yalnız görsel içindir ve belirlenimcilik zincirine girmez.

**Lejant (6 sınıf + 2):** < %0,01 · %0,01–0,1 · %0,1–1 · %1–10 · %10–50 · > %50 · Veri yok · Düşmüş.

### 13.3 Gösterim yolları
- **A (sürüm 1, gölgelendirici değişikliği yok):** Düşmüş bölgeler işgal çizgisiyle görünür. Enfekte eyaletler Salgın panelinde
  (02, kısayol E) `section` + `table` / `table_row` ile listelenir: eyalet, bildirilen, eğilim, veri yaşı, durum; bildirilen yaygınlığa
  göre sıralıdır. `info_cells` ile KSE, bildirilen toplam ve düşmüş eyalet gösterilir. Eyalet ipucuna (`map_tooltip.gd`) üç satır eklenir.
  Bu yol yalnız mevcut yardımcıları kullanır.
- **B (sürüm 2):** `map_mode = 4 (Salgın)` ayrı bir `epi_tex` (R8 ya da RG8) okur ve ardışık bir renk ölçeği uygular. Bu gölgelendirici
  değişikliğidir. **CLAUDE.md kural 5 gereği insan gözüyle doğrulanmalıdır**: Forward+ ve gl_compatibility'de, renk körlüğüne uygun
  bir palet seçilerek. Veri tarafı (bu belge) hazırdır.
- **Bilgi sisi:** Harita ve panel yalnız **bildirilen** veriyi gösterir. Gerçek değerler yalnız test için geliştirici bayrağıyla
  (`--epi-reveal`, `country_check` ve denge betikleri) görülür.

**Metinler (strings.csv, EN / TR):**

| Anahtar | EN | TR |
|---|---|---|
| `EPI_REPORTED_PREV` | Reported prevalence | Bildirilen yaygınlık |
| `EPI_NO_DATA` | No data | Veri yok |
| `EPI_DATA_AGE` | Data %d days old | Veri %d günlük |
| `EPI_TREND_UP` / `_DOWN` | Rising / Falling | Artıyor / Azalıyor |
| `EPI_WATCH` | Under watch (%d/42 days) | İzlemede (%d/42 gün) |
| `EPI_OVERRUN` | Overrun | Düşmüş |
| `EPI_SOURCE_BULLETIN` | Source: Outbreak Bulletin (Friday) | Kaynak: Salgın Bülteni (cuma) |
| `EPI_CAUGHT` | Caught at screening | Taramada yakalanan |
| `EPI_WASTED_DOSES` | Doses given to the incubating | Kuluçkadakilere giden doz |
| `EPI_TIP_BORDER` | A closed border buys time. You decide how to use it. | Kapalı sınır zaman kazandırır. Zamanı sen kullanırsın. |

## 14. Veri: JSON parametreleri ve şema

**Dosya önerisi:** `data/modes/zombie/epidemic.json`. Manifest (`mode.json`) `rules` alanıyla kural betiğini gösterir, betik bu
dosyayı okur. 02 §10'daki `rules.json`'un `disease`, `mobility` ve `horde` blokları **aynı anahtar adlarıyla** buraya taşınabilir ya
da orada kalabilir; karar `docs/modlar/README.md`'nindir. Zorluk tabloları (β, κ, ömür…) 02 §10'daki `difficulty` bloğunda kalır ve
buradaki varsayılanların üstüne yazar. 04'teki tür ve suş dosyaları buradaki anahtarları çarpan ya da değer olarak geçersiz kılar.

```json
{
  "_comment": "Gri Kordon salgın motoru. Gerekçeler: docs/modlar/zombi/03_salgin_modeli.md. Zorluk değerleri 02 §10 'difficulty' bloğundan gelir ve bunların üstüne yazar.",
  "version": 1,
  "step": {"exit_clamp": 0.95, "small_regime_below": 50, "extinction_threshold": 0.5, "round_expected_below": 20, "time_slice_hours": 0},
  "disease": {
    "beta": 0.30, "kappa": 0.08, "hollow_life_days": 60,
    "sigma": 0.3333, "gamma": 0.1429, "p_death_febrile": 0.10, "p_recover_febrile": 0.0,
    "phi_febrile_bite": 0.15, "eps_incubating_bite": 0.0,
    "density_ref": 25.0, "density_min": 0.35, "density_max": 3.0,
    "measures_cap": 0.75, "fall_rule": "hollow_gt_defensible"
  },
  "climate": {"winter_max": 2.0, "desert": 1.6, "desert_min_share": 0.5, "desert_hot_abs_lat": 35.0,
              "winter_bite": 0.25, "walk_winter": 0.25, "walk_mud": 0.45},
  "immunity": {"recovered_waning": 0.0, "vaccine_efficacy": 0.9, "vaccine_delay_days": 10,
               "serum_efficacy": 0.8, "innate_immune_share": 0.0},
  "garrison": {"kappa_per_division": 0.10, "area_ref_km2": 56500, "kappa_cap": 0.6},
  "mobility": {
    "daily_outflow": 0.003, "infra_ref": 3.0, "febrile_travel": 0.5,
    "land_links": 5, "capital_link": true, "capital_weight": 4.0, "colonial_sea_km": 1500, "gravity_min_km": 50,
    "sea": {"ship_km_per_day": 533, "near_ports": 2, "near_max_days": 20, "long_haul": 1, "long_haul_max_days": 30,
            "symmetric": true, "foreign_only": true, "ring_days": 32},
    "air_routes": [],
    "river_routes": [],
    "border": {"open": 1.0, "controlled": 0.5, "closed": 0.05}
  },
  "refugees": {"fear_start": 0.02, "fear_full": 0.20, "max_daily": 0.03, "safety_scale": 10.0,
               "closed_border_leak": 0.05, "event_cooldown_days": 30, "camp_days": 14},
  "horde_walk": {"base": 0.01, "hunger": 0.09, "river": 0.5, "bridges_blown": 0.15, "garrison_block_max": 0.9},
  "horde_units": {"per_unit": 10000, "max_units": 1200, "max_units_web": 800, "per_front_state": 3, "per_front_state_web": 2,
                  "spawn_per_state_day": 1, "priority": ["player_adjacent", "army_adjacent", "hollow"], "target_top_k": 3},
  "surveillance": {
    "detect_unknown": 0.08, "base": 0.15, "per_infra": 0.10, "colony": -0.10, "min": 0.10, "max": 0.95,
    "delay_base": 6, "delay_far_km": 1500, "delay_far_add": 2, "delay_min": 3, "delay_max": 10,
    "report_ring_days": 16, "prevalence_window_days": 14,
    "screening": {"t0": {"E": 0.0, "F": 0.6,  "H": 1.0},
                  "t1": {"E": 0.0, "F": 0.85, "H": 1.0, "tech": "zm_agent_identified"},
                  "t2": {"E": 0.5, "F": 0.95, "H": 1.0, "tech": "zm_incubation_test"}}
  },
  "index": {"size": 25, "compartment": "E", "hidden_days": 21, "weight": "port_pop_x_density", "exclude": ["player"],
            "detect_threshold_reported": 50},
  "rng_streams": {"index": 1, "travel": 2, "sea": 3, "walk": 4, "small": 5, "report": 6, "units": 7, "refugees": 8, "strains": 9, "events": 10},
  "map_layer": {"log_min": -5, "legend_bins": [0.0001, 0.001, 0.01, 0.1, 0.5]}
}
```
Teknoloji kimlikleri (`zm_agent_identified`, `zm_incubation_test`) öneridir; araştırma belgesinde kesinleşir.

**JSON Şeması (kısaltılmış; `tests/test_data.gd`'deki el yazısı denetleyici bunu izler, JSON Şeması destekli editörler de kullanabilir):**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "iron-front/modes/zombie/epidemic.schema.json",
  "type": "object",
  "required": ["version", "disease", "mobility", "horde_walk", "horde_units", "surveillance", "index"],
  "properties": {
    "version": {"const": 1},
    "disease": {
      "type": "object",
      "required": ["beta", "kappa", "hollow_life_days", "sigma", "gamma", "p_death_febrile", "phi_febrile_bite"],
      "properties": {
        "beta":  {"type": "number", "minimum": 0, "maximum": 2},
        "kappa": {"type": "number", "minimum": 0, "maximum": 2},
        "hollow_life_days": {"type": "number", "minimum": 5, "maximum": 400},
        "sigma": {"type": "number", "exclusiveMinimum": 0, "maximum": 0.95},
        "gamma": {"type": "number", "exclusiveMinimum": 0, "maximum": 0.95},
        "p_death_febrile":   {"type": "number", "minimum": 0, "maximum": 1},
        "p_recover_febrile": {"type": "number", "minimum": 0, "maximum": 1},
        "phi_febrile_bite":  {"type": "number", "minimum": 0, "maximum": 1},
        "eps_incubating_bite": {"type": "number", "minimum": 0, "maximum": 1},
        "density_ref": {"type": "number", "exclusiveMinimum": 0},
        "density_min": {"type": "number", "exclusiveMinimum": 0},
        "density_max": {"type": "number"},
        "measures_cap": {"type": "number", "minimum": 0, "maximum": 0.95},
        "fall_rule": {"enum": ["hollow_gt_defensible", "hollow_gt_living"]}
      },
      "additionalProperties": false
    },
    "mobility": {
      "type": "object",
      "properties": {
        "daily_outflow": {"type": "number", "minimum": 0, "maximum": 0.05},
        "border": {"type": "object", "required": ["open", "controlled", "closed"],
                   "additionalProperties": {"type": "number", "minimum": 0, "maximum": 1}},
        "air_routes":   {"type": "array", "items": {"type": "object", "required": ["from", "to", "daily"],
                         "properties": {"from": {"type": "integer"}, "to": {"type": "integer"}, "daily": {"type": "number", "minimum": 0}}}},
        "river_routes": {"type": "array", "items": {"type": "object", "required": ["states", "daily"],
                         "properties": {"states": {"type": "array", "items": {"type": "integer"}, "minItems": 2}, "daily": {"type": "number"}}}}
      }
    },
    "horde_units": {"type": "object", "properties": {"per_unit": {"const": 10000}, "max_units": {"type": "integer", "minimum": 0, "maximum": 3000}}},
    "index": {"type": "object", "properties": {"compartment": {"enum": ["E", "F", "H"]},
              "weight": {"enum": ["port_pop", "port_pop_x_density", "uniform"]}}}
  }
}
```
Veri testi kuralları: şemadaki aralıklar; `p_death_febrile + p_recover_febrile ≤ 1`; `density_min < density_max`; `air_routes` ve
`river_routes`'taki eyalet kimlikleri `states.json`'da olmalı; `exit_clamp < 1`. Tanımadığı anahtar hata verir. Son kural modcunun
yazım hatasını yakalar (`"betta"` gibi).

## 15. Test planı

| Test | Ne ölçer | Beklenen |
|---|---|---|
| `test_epidemic_single` | 1 M nüfus, d = 1, 200 çekirdek (50/30/20), önlem yok | İkiye katlanma 9,5 ± 0,2 gün; %1 yaygınlık 55 ± 1; düşme (H > S+R+V) 120 ± 1 |
| `test_epidemic_detect` | 25 E, −21. gün, tespit 0,08 | d = 1 / 1,93 / 3 → 31 / 15 / 8 (±1) |
| `test_epidemic_extinction` | Tek E, d = 0,35, 1.000 tohum | P(söner) 0,47 ± 0,04 |
| `test_epidemic_conservation` | Yolculuk ve mülteci dahil tek gün | Σ(S+E+F+Vb+R+V+H+U+D) + yoldakiler değişmez (göreli 10⁻⁹); H korunumu (04 §2.1) |
| `test_epidemic_quarantine` | Liman k = 14, T0 | Geçen E ≤ %1 |
| `test_epidemic_determinism` | Aynı tohumla iki koşu; kayıt-yükleme-sürdürme | Bit bit aynı |
| `test_epidemic_data` | `epidemic.json` şeması | Hata yok; yanlış anahtar yakalanır |
| `country_check` (mod) | Oyuncu hiçbir şey yapmaz | Hiçbir önlem, sınır tutumu ya da dağıtım oyuncu adına değişmemiş |
| Denge (02 §8 + ek) | 6 paralel koşu | Mevcut 10 kontrole ek: 11) Türkiye'ye ilk vaka 24–90. gün (oyuncu TUR, 5/6); 12) cephe birimi ≤ sınır |
| `sim.gd` profil | `epidemic`, `und` anahtarları | Salgın ≤ 12 ms/gün; toplam ≤ temel × 1,3 |

## 16. Açık sorular

1. **Düşme ölçütü:** "H > S + R + V + Vb" 02'nin tablosuyla uyumlu. 02 §2.5'teki metin buna göre düzeltilsin mi?
2. **8 bağlantı sınırı:** Çift yönlü deniz hatlarıyla 37 liman eyaleti 8'i aşıyor, en büyük merkez 196 bağa ulaşıyor. Sınır yalnız kara
   ve başkent bağları için mi geçerli olsun? Hatlar yüklemede mi hesaplansın (24 ms), yoksa modcunun görebileceği bir
   `links.json`'a mı yazılsın?
3. **Evre 1→2 koşulu:** KSE ≥ 1 mi, yoksa "3 ülkede **bildirilen** ≥ 100" mü? İkincisi bilgi sisi sütunuyla daha uyumlu ama
   yapay zekânın şeffaflığına bağlı.
4. **İki yamalı eyalet** (şehir + kırsal): 120 eyalette kent payı %50'nin üstünde. Maliyet ×2, şehir alanı verisi yok. Sürüm 2'ye mi kalsın?
5. **Isı haritası gölgelendiricisi** (§13.3 B): kim, ne zaman, hangi paletle yapacak? 01 ve 02'deki "iki düzeyli işaret" ifadesi düzeltilmeli.
6. **Web ölçümü:** WASM'da salgın adımı ve 800 birimle `sim` süresi ölçülmeli. Masaüstü ile web arasında bit aynılığı test edilmeli.
7. **Anahtar adı uyumu:** 04'teki suş tanımları `phi` kullanıyor, 02 ve bu belge `phi_febrile_bite`. Tek ad seçilmeli (öneri:
   `phi_febrile_bite`, `eps_incubating_bite`, `p_recover_febrile`).
8. **Mülteci olay sıklığı:** Kaynak eyalet başına 30 günde bir olay, büyük çöküşte yine çok olay üretebilir. Ülke başına haftalık
   toplu olay mı olsun?
9. **Nehir hatları** (`river_routes`) varsayılan veride olsun mu? Olacaksa hangi nehirler, günde kaç yolcu?
10. **κ_asker ölçeği:** "0,10/tümen × sqrt(alan)" formülü, 04'teki muharebe değerleriyle aynı tümen gücünü mü anlatıyor? Bir tümen
    hem sürüyü tutup hem de dağınık bastırmaya sayılmamalı. Öneri: muharebedeki tümen κ_asker'e katılmaz (§3.2); denge testiyle doğrulanmalı.
11. **Güçlü yanıtın bedeli:** Prototipte yaşayanları %39'a taşıyan yanıt (β ×0,5, uluslararası ×0,05) ekonomiye ne kadara mal oluyor?
    Yapay zekâ bu yanıtı ne zaman seçebilir? Bu, yapay zekâ ve ekonomi belgelerinin konusu.
12. **Temel oyunda kayıt kesinliği:** Varsayılan `JSON.stringify` ondalık sayıları 15 basamağa kırpıyor. Bu, temel oyunda da
    "kaydet-yükle-sürdür" belirlenimciliğini bozabilir; mod dışında ayrıca ele alınmalı.

## 17. Kaynaklar

Salgın modelleme ve zombi salgını modelleri
- Kermack, W. O., McKendrick, A. G. (1927). A contribution to the mathematical theory of epidemics. — https://jxshix.people.wm.edu/2009-harbin-course/classic/Kermack-McKendrick-1927-I.pdf
- Munz, P., Hudea, I., Imad, J., Smith, R. J. (2009). When zombies attack!: Mathematical modelling of an outbreak of zombie infection. — https://www.researchgate.net/publication/228509313_When_zombies_attack_mathematical_modelling_of_an_outbreak_of_zombie_infection
- Alemi, A. A., Bierbaum, M., Myers, C. R., Sethna, J. P. (2015). You can run, you can hide: The epidemiology and statistical mechanics of zombies. *Phys. Rev. E* 92, 052801. — https://link.aps.org/doi/10.1103/PhysRevE.92.052801
- Aynı çalışmanın basın özeti (yoğun bölgeler günler, kırsal bölgeler aylar içinde). — https://phys.org/news/2015-02-zombie-outbreak-statistical-mechanics-reveal.html
- Hu, H., Nigmatulina, K., Eckhoff, P. (2013). The scaling of contact rates with population density for the infectious disease models. *Math. Biosci.* 244(2): 125–134. — https://www.sciencedirect.com/science/article/pii/S0025556413001235
- McCallum, H., Barlow, N., Hone, J. (2001). How should pathogen transmission be modelled? *TREE* 16(6): 295–300. — https://www.cell.com/trends/ecology-evolution/abstract/S0169-5347(01)02144-9
- "Atto-tilki" sorunu: Atto-Foxes and Other Minutiae. *Bull. Math. Biol.* (2021). — https://link.springer.com/article/10.1007/s11538-021-00936-x
- Gillespie, D. T. (2001). Approximate accelerated stochastic simulation of chemically reacting systems (tau-leaping). *J. Chem. Phys.* 115. — https://users.soe.ucsc.edu/~msmangel/Gillespie01.pdf
- Melez stokastik–deterministik bölmeli modeller ve eşik değerleri (Jump-Switch-Flow). — https://arxiv.org/abs/2405.13239
- Balcan, D. ve ark. (2009). Multiscale mobility networks and the spatial spreading of infectious diseases. *PNAS* 106. — https://www.pnas.org/doi/10.1073/pnas.0906910106
- Simini, F. ve ark. (2012). A universal model for mobility and migration patterns. *Nature* 484. — https://www.nature.com/articles/nature10856
- Truscott, J., Ferguson, N. M. (2012). Evaluating the adequacy of gravity models as a description of human mobility for epidemic modelling. — https://journals.plos.org/ploscompbiol/article?id=10.1371%2Fjournal.pcbi.1002699
- Mills, C. E., Robins, J. M., Lipsitch, M. (2004). Transmissibility of 1918 pandemic influenza. *Nature* 432. — https://www.nature.com/articles/nature03063
- Hampson, K. ve ark. (2009). Transmission dynamics and prospects for the elimination of canine rabies. *PLoS Biol.* 7(3). — https://journals.plos.org/plosbiology/article?id=10.1371%2Fjournal.pbio.1000053
- Smith, D. L. ve ark. (2002). Predicting the spatial dynamics of rabies epidemics on heterogeneous landscapes. *PNAS* 99: 3668–3672. — http://www.pnas.org/content/99/6/3668
- Grenfell, B. (2002). Rivers dam waves of rabies. *PNAS* (yorum). — https://www.pnas.org/doi/full/10.1073/pnas.062049599

Önlemler, seyahat ve tarama
- Bootsma, M. C. J., Ferguson, N. M. (2007). The effect of public health measures on the 1918 influenza pandemic in U.S. cities. *PNAS* 104. — https://www.pnas.org/doi/10.1073/pnas.0611071104
- Hatchett, R. J., Mecher, C. E., Lipsitch, M. (2007). Public health interventions and epidemic intensity during the 1918 influenza pandemic. *PNAS* 104. — https://www.pnas.org/doi/full/10.1073/pnas.0610941104
- Cooper, B. S. ve ark. (2006). Delaying the international spread of pandemic influenza. *PLoS Med.* 3(6). — https://journals.plos.org/plosmedicine/article?id=10.1371%2Fjournal.pmed.0030212
- Nonpharmaceutical measures for pandemic influenza — international travel-related measures (derleme). *Emerg. Infect. Dis.* 26(5) (2020). — https://wwwnc.cdc.gov/eid/article/26/5/19-0993_article
- Gostic, K. M., Kucharski, A. J., Lloyd-Smith, J. O. (2015). Effectiveness of traveller screening for emerging pathogens is shaped by epidemiology and natural history of infection. *eLife*. — https://elifesciences.org/articles/05564

Tarih: hareketlilik, salgın yolları, mülteciler, sözleşmeler
- Reyes, O. ve ark. (2018). Spatiotemporal patterns and diffusion of the 1918 influenza pandemic in British India. *Am. J. Epidemiol.* 187(12). — https://academic.oup.com/aje/article/187/12/2550/5106629
- 1918 salgını ve Hindistan demiryolları (Sağlık Komiserliği raporu alıntısı). — https://en.wikipedia.org/wiki/1918_flu_pandemic_in_India
- 1892 Astrahan kolera salgını ve Volga yolu. — https://www.researchgate.net/publication/376686284_The_Demographic_Social_and_Economic_Aftermath_of_the_Cholera_Epidemic_in_Astrakhan_in_1892
- 1892 kolerasının Hazar ötesi demiryolu ve vapurlarla yayılması. — https://www.oeaw.ac.at/sice/sice-blog/a-muslim-cholera-riot-without-muslims
- ABD'de otobüs sanayii ve 1930 yolcu-mil verileri (EH.net). — https://eh.net/encyclopedia/the-bus-industry-in-the-united-states/
- Japan Air Transport (1938'de dünya hava yolcu trafiğinin %2,6'sı). — https://en.wikipedia.org/wiki/Japan_Air_Transport
- La Retirada (1939). — https://en.wikipedia.org/wiki/La_Retirada
- The Retirada or post-war Spanish republican exile. *Musée de l'histoire de l'immigration.* — https://www.histoire-immigration.fr/en/migration-characteristics-by-country-of-origin/the-retirada-or-post-war-spanish-republican-exile
- Belgian refugees in the Netherlands during the First World War. — https://en.wikipedia.org/wiki/Belgian_refugees_in_the_Netherlands_during_the_First_World_War
- Refugees (Belgium), *1914-1918-online*. — https://encyclopedia.1914-1918-online.net/article/refugees-belgium/
- Kara Ölüm'ün yayılma hızı. *National Geographic.* — https://www.nationalgeographic.com/history/history-magazine/article/fast-lethal-black-death-spread-mile-per-day
- 1926 Uluslararası Sıhhiye Sözleşmesi, metin. — https://worldjpn.net/documents/texts/docs/19260621.T1E.html
- 1926 Sözleşmesi, ABD Dışişleri belgeleri. — https://history.state.gov/historicaldocuments/frus1926v01/d116

Fizyoloji ve aşı
- Hypothermia. *StatPearls.* — https://www.ncbi.nlm.nih.gov/books/NBK545239/
- Romaszko, J. ve ark. (2017). Mortality among the homeless: Causes and meteorological relationships. *PLoS One.* — https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0189938
- Physiological responses to exercise in the heat (ter hızı 0,3–1,5 l/saat). *Nutritional Needs in Hot Environments*, National Academies. — https://www.nationalacademies.org/read/2094/chapter/6
- How long can the average person survive without water? *Scientific American.* — https://www.scientificamerican.com/article/how-long-can-the-average/
- 17D sarı humma aşısı: bağışıklığın 10 gün içinde gelişmesi. — https://pmc.ncbi.nlm.nih.gov/articles/PMC4811652/
- Developing the 17D yellow fever vaccine. *Nature.* — https://www.nature.com/articles/d42859-020-00012-9

Depo içi (okunan dosyalar)
- `data/map/states.json`, `provinces.json` (`adj`, `river_adj`, `strait_adj`, `terrain`, `ll`), `cities.json`, `straits.json`,
  `sea_lanes.json`, `data/history/states_1936.json` (`category`, `infrastructure`)
- `game/autoload/military.gd` (`winter_level`, `mud_level`, `_speed`, `river_attack`), `game/autoload/game.gd` (kayıt),
  `game/autoload/game_clock.gd` (`timed`), `game/map/map_view_3d.gd` (`set_marked_states`), `assets/shaders/map3d.gdshader`
  (işaret ve işgal çizgisi), `game/dev/sim.gd`, `tests/test_determinism.gd`, `data/modes/_template/mode.json`
- `docs/modlar/zombi/01_vizyon.md`, `02_oynanis_dongusu.md`, `04_zombi_turleri.md`

---

### Ek A: Prototip ve ölçümler nasıl yapıldı?
- **Tek eyalet** (§3.3, §3.4, §5.9): Python; 02 §2.2 denklemleri günlük adımla çözüldü, küçük sayı rejiminde numpy binom/Poisson çekilişi kullanıldı.
- **Ağ prototipi** (§5.8): Python + numpy; 1.652 eyalet. Bağlantılar bölge komşuluğundan, başkentler `states.json`'dan, limanlar
  `cities.json`'dan kuruldu. İklim enlem ve aydan hesaplandı (`winter_level` ve `mud_level`'in aynı kuralları). Her senaryo 6 tohumla
  koşuldu, oyuncu TUR, 1.461 gün + 21 gün gizli başlangıç. Koşu başına ~3 sn.
- **GDScript ölçümü** (§12): Godot 4.7.2 `--headless -s`. Ayrı bir boş proje, `data/` dosyalarını mutlak yoldan okudu. Temel oyun
  profili, deponun ayrı bir kopyasında `game/dev/sim.gd -- --days=120` ve `--days=1000 --player=TUR` ile alındı.
- Uygulama PR'ında bu betikler `tools/epi_prototype.py` ve `game/dev/epi_bench.gd` olarak depoya eklenmeli. Tek eyalet sayıları
  `tests/` altında birim testine dönüşür (§15).
