# Zombi modu — 10 Yapay zekâ ve zorluk

> **Özet.** Bu belge *Gri Kordon* modunda kararları kimin, hangi bilgiyle ve ne kadar hesap bütçesiyle verdiğini tanımlar.
> Kararlar 01_vizyon.md ve 02_oynanis_dongusu.md'ye, sayılar 03–09'a dayanır; bu belge dağınık yapay zekâ kurallarını tek yerde toplar.
> - **Dört yapay zekâ vardır:** (1) **sürü yapay zekâsı** (`UND` tarafı: hedef seçimi, göç, birleşme), (2) **devlet yapay zekâsı**
>   (oyuncu dışındaki 79 ülkenin salgın yanıtı), (3) **Konsey yapay zekâsı** (Uluslararası Karantina Konseyi, 09 §6.6), (4) **olay seçimi**
>   (yapay zekâ ülkesine gelen olaylarda `ai` ağırlığı).
> - **Sürüler bir adım ileriyi düşünür.** Her sürü günde en çok bir kez, yalnız **komşu bölgeler** arasından hedef seçer; uzun yol
>   aramaz. Yakında hedef yoksa, günde bir kez eyalet grafiği üzerinde hesaplanan **çekim alanı** (çok kaynaklı en kısa yol, 1.652 düğüm)
>   onu yaşayan nüfusa doğru yürütür. Maliyet: ~3–5 ms/gün.
> - **Devlet yapay zekâsı hile yapmaz:** yalnız **bildirilen** sayıları görür (01 Sütun 2). Kişiliği ideolojiden değil, ölçülebilir
>   kapasiteden (fabrika, coğrafya, istikrar) gelir; rejim önlemi "aklanmaz" (01 §6.5).
> - **Dinamik zorluk yoktur.** Üç hazır zorluk (Tatbikat, Salgın, Kara Yıl) ve "Özel" ayarlar vardır; gerekçe §7.
> - **Belirlenimcilik:** Salgın ve sürü yapay zekâsı yalnız durumsuz sayaç karmasını kullanır (03 §11); devlet yapay zekâsı temel
>   oyundaki gibi global üreteci kullanır. Aynı tohumla iki koşu aynıdır.
> - **Motor değişikliği:** 6 küçük, içerikten bağımsız kanca (Y1–Y6, §9); WWII modunda hepsi etkisizdir. Kalan her şey
>   `game/modes/zombie/rules.gd` ve `data/modes/zombie/own/ai.json` ile yapılır.
> - **Denge testi:** 14 otomatik kontrol (§8), mevcut `balance_parallel.sh` kalıbında: her kontrol 6 koşunun en az 5'inde tutmalı.

---

## 1. Kapsam, ilkeler ve öteki belgelerle ilişki

### 1.1 Bu belge neyi kesinleştirir?

| Konu | Bu belge | Kaynak belge |
|---|---|---|
| Sürü hedef puanı, top sesi çekimi, önder etkisi, cephe doğumu | Kullanır; **çekim alanını** ve günlük emir bütçesini ekler | 03 §10, 04 §2.4–§2.5 |
| Kordon, rotasyon, arındırma, hava/deniz kuralları (devlet YZ) | Kullanır, tek tabloda toplar | 08 §15 |
| Yasa, sınır, bağış, koruma kuralları (devlet YZ) | Kullanır | 09 §3.9, §5.4, §6.7 |
| Gıda, mülteci, tayın kuralları (devlet YZ) | Kullanır | 07 §10.7 |
| Araştırma sırası ve doktrin seçimi | Kullanır; **enstitü kurma eşiğini kesinleştirir** (05'in 6. açık sorusu) | 05 §4–§6, 06 §3.12, §4 |
| Zorluk hazır ayarları | Kullanır; yapay zekâya etkisini sayıyla yazar | 02 §7 |
| Denge kontrolleri | 02 §8'dekileri alır, yapay zekâya özgü 4 kontrol ekler | 02 §8, 06 §8, 08 §18, 09 §11 |
| Dinamik zorluk, hile, performans bütçesi, motor kancaları | **Kesinleştirir** | — |

### 1.2 İlkeler

| İlke | Uygulama |
|---|---|
| Oyuncu karar verir (CLAUDE.md kural 1) | Bu belgedeki kuralların **hiçbiri oyuncunun ülkesinde çalışmaz.** Kolaylıklar (otomatik serum, otomatik aşı, kordonu genişlet, otomatik ticaret) kapalı başlar; açılınca da yalnız o işi yapar (02 §7.3). |
| Hile yok | Devlet YZ bildirilen veriyi görür; kaynak, üretim hızı ya da muharebe bonusu almaz (§6). |
| Belirlenimcilik | Salgın ve sürü kararları sayaç karmasıyla (03 §11.2); aynı tohum aynı dünya. |
| Veri güdümlü | Eşikler `own/ai.json`'da; kod yalnız kuralı uygular. |
| Ucuz ve sınırlı | Günlük bütçe §10'da; sürü kararları komşu bölgeyle sınırlı, uzun yol araması yok. |
| Okunabilirlik | Her yapay zekâ kararının oyuncuya görünen bir izi vardır: bülten satırı, diplomasi günlüğü ya da harita işareti. Oyuncu "neden?" diye sorabildiği bir dünyada oynar. |

---

## 2. Mimari: dört yapay zekâ ve çağrı sırası

```
SAAT (hour_passed)                          GÜN (day_passed; World.daily_update)                 AY / HAFTA
 Military._on_hour (mevcut)                  1 Salgın adımı (03 §2, adım 1–7)                     Cuma: bülten (03 §8.2)
  sürüler bir bölge yürür, savaşır           2 Sürü YZ: çekim alanı Φ (günde 1), sürü emirleri    Ay başı: Konsey oturumu (09 §6.6)
                                             3 AI._on_day (mevcut): stratejik (7 günde 1,         14 günde 1: sınır tutumu,
                                               kademeli) + askerî (her gün)                          yasa politikası (09)
                                               └─ Y1/Y2 kancaları: mod katmanı (salgın yanıtı)
                                             4 Game._on_day → rules.on_day (oyun sonu denetimi)
```

- Sürü YZ salgın adımından **sonra** koşar, çünkü doğum/dağılma ve cephe eyaletleri o adımda belirlenir (03 §10).
- Devlet YZ sürü emirlerinden sonra koşar; aynı gün doğan sürüyü görür (bildirildiyse).
- Kod yeri: salgın ve sürü YZ `game/modes/zombie/epidemic.gd` ve `game/modes/zombie/horde_ai.gd` (kural betiğinin yardımcıları);
  devlet YZ'nin mod katmanı `game/modes/zombie/state_ai.gd`. Üçü de `rules.gd`'den çağrılır. Motor tarafı 6 kancadır (§9).

---

## 3. Sürü yapay zekâsı (`UND`)

### 3.1 Neyi taklit ediyoruz?

Boşlar düşünmez; **uyarıya** gider. 04'te tanımlandığı gibi etkenin davranışı kuduza benzer: saldırganlık, ses ve harekete yönelme,
suya isteksizlik. Yapay zekânın görevi "akıllı düşman" değil, **inandırıcı bir akış** üretmektir. Bunun için kalabalık benzetiminin
iki bilinen fikri yeterlidir:

1. **Yerel çekim** (her bireyin yakın çevresine bakması): Reynolds'ın sürü modelinde ve Helbing–Molnár'ın "sosyal kuvvet"
   modelinde yaya, yakındaki hedeflere ve komşularına göre yön seçer.
2. **Küresel alan** (her noktada "hedefe hangi yönden gidilir" bilgisi): Treuille, Cooper ve Popović'in sürekli kalabalık modelinde
   bütün kalabalık tek bir potansiyel alanın eğimini izler. Oyun yapay zekâsında bu fikir "akış alanı" ya da "etki haritası" olarak
   bilinir: yol her birim için değil, **bir kez, bütün harita için** hesaplanır.

Sürü YZ ikisini birleştirir: yakın hedef varsa yerel puan (03 §10), yoksa küresel alan.

### 3.2 Yerel puan (03 §10'daki formül, eklerle)

Sürü `d`, bölge `p`'de. Komşu bölgelerin her biri `q` için:

```
puan(q) = w_q · (L_s(q) / N⁰_s(q))                  yaşayan nüfus çekimi (03 §4 ağırlığı; L = S+E+F+R+V)
        · (1 + 0,5 · ses_q)                          top sesi: son 2 günde q'nun 2 bölge çevresinde topçulu muharebe (04 §2.5)
        · (1 + 0,3 · önder_d)                        Kösemen sürü önderi komşudaysa (04 T04)
        · gece_d                                     Gecegezer gece ×1,5, gündüz ×0,7 (04 T07)
        / (1 + tümen_q)                              içinde tümen olan bölgeden kaçınma (03 §10)
        · nehir_pq                                   nehir geçişi ×0,5 (Sazlıkçı ×1,0) (03 §5.6)
```

- `ses_q` ∈ {0, 1}; Seğirtken ve gece Gecegezer için 2. Gerekçe: 04 §2.5'teki `noise_pull` kancası.
- `tümen_q` bildirilen değil **gerçek** sayıdır: Boşlar "bilgi sisi" yaşamaz, önlerindekini görür (§6.3).
- En yüksek 3 komşu arasından, puanla orantılı olarak ve **karmayla** seçilir: `karma(tohum, gün, akış 7, d.id, 0)`.
  Böylece sürüler tek noktaya yığılmaz (03 §10).

### 3.3 Küresel alan: çekim alanı Φ

**Sorun:** Düşmüş bir iç eyaletteki sürünün bütün komşuları boştur (`L = 0`), yerel puan sıfırdır. Kural olmazsa sürü olduğu yerde
çürür; bu 03'teki "iç eyaletlerde bütün Boşlar dağınıktır" kuralıyla örtüşür, ama cephe eyaletlerindeki birimlerin de düşmüş bölgeye
sıkışıp kalması, yaşayan nüfusa doğru "göç" hissini yok eder.

**Çözüm:** Günde bir kez, **eyalet grafiği** üzerinde çok kaynaklı en kısa yol:

```
kaynaklar = yaşayan nüfusu L_s ≥ 10.000 olan ve DÜŞMÜŞ olmayan eyaletler
başlangıç: Φ(s) = −log10(L_s)                 (büyük nüfus daha "derin" çukur)
kenar maliyeti c(i, j) = uzunluk_ij / 285 km · arazi_ij · nehir_ij     (285 km: medyan eyalet çapı, 03 §5.6)
Φ(i) = min_j [ Φ(j) + c(i, j) ]               (Dijkstra, ikili yığın; mevcut Military._heap_push/_heap_pop kalıbı)
```

- Grafik: 1.652 eyalet, ~7.500 kara kenarı (03 §12.1'deki yürüyüş kenarları). Dijkstra `O(E log V)` ≈ 7.500 × 11 ≈ 80.000 adım.
  03 §12.1'de ölçülen yolcu akışı (aynı kenar sayısı) 4,2 ms/gün sürdüğü için Φ'nin **1–3 ms/gün** tutması beklenir. Ölçülecek (§10).
- Yerel puanın en iyisi `< 0,001` ise sürü, bulunduğu eyaletten **Φ'si en küçük komşu eyalete** giden sınır bölgesine yürür.
  Bölge seçimi yine karmayla, sınır bölgeleri arasından.
- Denizi geçmez; `land_crossing` boğazları geçer (03 §10). Φ bu yüzden kıtalara bölünür; adada kalan sürü yerinde erir.
- **Neden bölge değil eyalet?** Bölge grafiğinde (9.827 düğüm, ~48.000 kenar) aynı hesap 6–7 kat pahalıdır ve gereksizdir: sürü
  zaten yerel puanla bölge düzeyinde adım atar, Φ yalnız "hangi yöne" sorusunu yanıtlar.

### 3.4 Emir bütçesi ve adım

| Kural | Değer | Gerekçe |
|---|---|---|
| Sürü başına en çok emir | Günde 1 | Sürü `Military.order_move(d, q)` ile **yalnız komşu** bölgeye yürür: yol araması 1 adımdır |
| Yeniden hedef | Bölgeye vardığında ya da 3 günde bir (`(gün + d.id) % 3 == 0`) | 1.200 sürüde günde ~400 karar; 04'teki hız (14,4 km/gün) ile bir bölge 1–3 günde geçilir |
| Muharebedeki sürü | Emir almaz | Mevcut muharebe kodu onu tutar (04 §3.3) |
| Kışlayan (T06) | Kışın emir almaz (`torpid`) | 04 T06 |
| Birleşme | Aynı bölgede ≥ 2 birim ve toplam güç ≤ 1,0 ise birleşir | 04 §2.1 korunumu; birim sayısını düşük tutar |
| Dağılma | Bütünlük < %12 → birim kalkar, kalan dağınık H'ye | 04 §2.4 |
| Dünya sınırı | Masaüstü 1.200, web 800 | 03 §12.2 |

**Neden kordonları "delmeye" çalışan bir sürü zekâsı yok?** Çünkü 01'in birinci sütunu "salgın bir cephedir": oyuncu kordonu tutarak
kazanır. Zayıf noktayı arayan bir düşman, oyuncunun her sınır bölgesine eşit tümen koymasını gerektirir ve oyunu mikro yönetime
çevirir. Boşlar en yakın ve en kalabalık yaşama gider; zayıf nokta **nüfusun olduğu yerdir**, oyuncu bunu okuyabilir.

### 3.5 Kalabalığın "hafızası": top sesi ve ceset kokusu

İki kısa ömürlü alan bölge başına tutulur (bayt dizisi, 9.827 bayt):

| Alan | Yazılır | Söner | Etki |
|---|---|---|---|
| `ses_p` | Topçulu tümenin muharebesi (her saat) | 2 gün | Yerel puanda ×1,5 (türe göre ×2) |
| `iz_p` | Bölgede sivil kaybı oldu (salgın adımından) | 5 gün | Yerel puanda ×1,2 — Boşlar kaçan kalabalığın izini sürer |

Bellek 20 KB'ın altında; kayda yazılmaz (yeniden hesaplanır, 03 §11.4'teki kayıp sorunu yok).

### 3.6 Sürü YZ için kontrol listesi

| Davranış | Denetim (test) |
|---|---|
| Sürü yaşayan nüfusa yürür | 30 günde sürünün Φ'si azalır (test §11-1) |
| Sürü tümenli bölgeden kaçınır ama muharebeye girer | Tek komşusu tümenliyse oraya saldırır |
| Sürü denizi geçmez | Ada ülkelerinde birim doğmaz ya da yerinde erir |
| Top sesi çeker | Topçulu muharebe açılan bölgenin 2 halka çevresinde sürü sayısı artar |
| Aynı tohum aynı yol | İki koşuda sürülerin konumları aynı |

---

## 4. Devlet yapay zekâsı: salgın yanıtı katmanı

### 4.1 Temel oyundan ne kalır?

`game/autoload/ai.gd` iki katmanlıdır: **stratejik** (7 günde bir, ülkeler kademeli: inşaat, üretim, araştırma, program, yasa, danışman)
ve **operasyonel** (her gün: tümen üretimi, cephe dağılımı, taarruz, savaş ilanı). Modda bu yapı kalır; üstüne **salgın katmanı**
gelir. Katman kendi kararlarını aynı kademeli takvimle verir (`(gün + c.index) % 7`), böylece günlük maliyet 80 ülkeye yayılır.

| Temel oyun işlevi | Modda |
|---|---|
| `_construction` | Kalır. Mod katmanı önce kendi binalarını ister (§4.5), kalan kapasite temel kurala gider |
| `_production` | Kalır. Serum, aşı ve mühimmat payı mod katmanından (§4.5) |
| `_research` | Kalır; sıra manifestten (Y3; 06 §3.12) |
| `_focus` | Kalır; yetenek ağacında `ai_mult` (06 M6) |
| `_laws` | **Moda devredilir** (Y4): temel oyunun savaş ekonomisi sırası yerine 09 §3.9 ve 07 §10.7 |
| `_advisors` | Kalır; öncelik listesi moddan (kabine uzmanları, 06 §4.9) |
| `_recruit`, `_fronts`, `_assign` | Kalır; `UND` düşman sayılır (Y6). Kordon orduları mod katmanından (§4.4) |
| `_declare` | Mod kuralına bağlanır (Y5): devletler arası savaş ayarına uyar (02 §7.2) |
| `_attack` | Kalır; `UND`'ye karşı eşik 1,5 (08 §15) |

### 4.2 Algı: devlet YZ neyi görür?

| Veri | Oyuncu görür | Devlet YZ görür | Not |
|---|---|---|---|
| Kendi eyaletinde vaka | Bildirilen (gecikmeli, eksik) | **Aynı**: bildirilen | Tespit oranı ve gecikme ülkenin gözetimine bağlı (03 §8) |
| Yabancı ülkede vaka | Bülten (haftalık, şeffaflığa bağlı) | **Aynı**: bülten | 09 §6.1 şeffaflık |
| Sürü birimi | Yalnız görünenler (Durgun, Dehlizci gizli) | **Aynı süzgeç** (08 §15) | `hidden_from(d, tag)` kancası |
| Yeni suş | Keşfedilince | Keşfedilince | 04 §7.4 |
| Gerçek H, gerçek R₀ | Asla | **Asla** | Hile yok |
| Kendi ekonomisi, ordusu | Tam | Tam | Temel oyundaki gibi |

Kısaltmalar (09 ile aynı): `YE_bild` — eyaletin bildirilen yaygınlığı `(F+H)_bild / N⁰`; `düşmüş pay` — ülkenin DÜŞMÜŞ eyaletlerinde
yaşayan 1936 nüfusunun payı; `irade` — halkın dayanma iradesi (`war_support`).

### 4.3 Kişilik: ideoloji değil, kapasite

01 §6.5 ve 07 §10.7 kararı: rejimin sert önlemi "etkili" diye ödüllendirilmez, yumuşak önlemi "zayıf" diye cezalandırılmaz. Bu yüzden
yapay zekânın salgın tutumu **ideolojiden türemez**. Üç ölçülebilir eksenden türer:

| Eksen | Nasıl ölçülür | Etki |
|---|---|---|
| **Kapasite** `k_c` | `min(1, fabrika_c / 40)`; 40 = büyük güçlerin 1936 medyanına yakın | Yüksekse kendi bilimini yürütür (enstitü, numune); düşükse paylaşım ve yardım ister |
| **Coğrafya** `g_c` | Ada (kara komşusu yok) = 1; sınır bölgesi / toplam bölge oranı düşükse 0,5; aksi 0 | Ada: liman karantinası ve deniz devriyesi öncelikli; kara devleti: kordon öncelikli |
| **Kurumsal güven** `t_c` | Başlangıç istikrarı (09 §2.2'deki dayanma iradesi formülünün girdisi) | Düşükse sert yasalara geç ve tek tek geçer (istikrar bedeli ağır); yüksekse erken bildirime ve şeffaflığa yatkın |

Kriz tutumu (09 §4: Önce Sağlık, Önce Düzen, Önce Geçim, Dayanışma) bu üç eksenden seçilir, rastgele değil:

| Koşul (sırayla, ilk uyan) | Tutum |
|---|---|
| `k_c ≥ 0,5` ve `t_c ≥ 0,45` | Önce Sağlık |
| `g_c = 1` (ada) | Önce Düzen (liman ve kıyı ağırlıklı) |
| `k_c < 0,2` | Dayanışma (yardım ve paylaşım) |
| diğer | Önce Geçim |

Beklenen dağılım (1936 verisiyle, 79 yapay zekâ ülkesi): Önce Sağlık ~12, Önce Düzen ~6, Dayanışma ~40, Önce Geçim ~21. Kesin
sayı ilk koşuda `gov_check` benzeri bir dökümle doğrulanır (§8 kontrol 12).

### 4.4 Karar tabloları (tek yerde)

Hepsi yalnız yapay zekâ ülkelerinde, `(gün + c.index) % 7 == 0` günlerinde (sınır ve yasa 14 günde bir; ekonomi ve bilim 7 günde bir).
Eşiklerin gerekçesi kaynak belgededir; burada yalnız toplanır.

**a) Gözetim ve bildirim** (03 §8, 05)

| Koşul | Karar |
|---|---|
| Alarm evresi | Tarama düzeyini T1'e çıkar (başkent ve liman eyaletleri) |
| Kendi eyaletinde bildirilen vaka | O eyalet ve komşularında T2 |
| `t_c < 0,30` ve kendi `YE_bild ≥ 0,02` | Bültene gerçeğin yarısını bildirme olasılığı %50 (şeffaflık düşer; 09 §6.1). İzi: skandal olayı A8 tetiklenebilir |

**b) Sınır tutumu** (09 §6.7): komşu `j`'nin `YE_bild < 0,01` → açık · 0,01–0,10 → denetimli · ≥ 0,10 ya da `j` çökmüş → kapalı.
Kararname Yönetimi olan ülkede eşikler yarıya iner. Ada ülkesi (`g_c = 1`) liman karantinasını (07 §7.2) aynı eşiklerle uygular.

**c) Yasalar** (09 §3.9 ve 07 §10.7): karantina, olağanüstü yönetim, sivil savunma, basın, zorunlu hizmet ve gıda politikası grupları;
eşikler kaynak tablolardadır. Bir yasa değişikliği için nüfuz ≥ bedel + 30 (temel oyundaki `_laws` koşulu).

**d) Askerî** (08 §15): kordon ordusu, %70 üst pay, şablonlar, 25 günde rotasyon, arındırma eşiği 1,5, Kordon Hattı binası, hava yakın
desteği tanıma ≥ 0,5, boğaz nöbeti, askere serum önceliği açık.

**e) Bilim ve üretim** (05, 06; bu belge **enstitü eşiğini** kesinleştirir)

| Karar | Kural | Gerekçe |
|---|---|---|
| Saha laboratuvarı | Alarm evresinde, fabrikası ≥ 5 ise 1 tane | 05'teki en ucuz bina; ilk bilgi (etkeni anlama) herkes için yararlı |
| **Araştırma enstitüsü** | `k_c ≥ 0,35` **ve** (kendi bildirilen vakası var **ya da** evre ≥ Yayılma) → 1; `k_c ≥ 0,7` ve evre ≥ Yayılma → 2 | 05'in 6. açık sorusu. Yalnız fabrika eşiği olursa küçük ülkeler hiç kurmaz (doğru: 01 Sütun 5), ama büyük ülkeler salgın gelmeden kurarsa bilim takvimi (02 §5) 60–90 gün öne kayar. Vaka/evre şartı takvimi korur. Beklenen: Yayılma'da 12–18 ülke |
| Numune | G1 her enstitülü ülke; G2 kordonu olan; G3 yalnız `k_c ≥ 0,7` ve muhafaza kanadı varsa | 05: G3 en riskli yol, yalnız donanımlı ülke |
| Serum hattı | Serum bitince fabrikanın %10'u; kendi `YE_bild ≥ 0,05` ise %20 | 05 §8 |
| Aşı hattı | Aşı bitince %15; nüfusun %30'u aşılanana dek | 05 §8, 02 §4.1 tedavi zaferi eşiği |
| Mühimmat | Kordonu olan ülkede askerî üretimin %10–25'i | 08 §18 kontrol 1 |
| Gıda | Gıda oranı < 1,0 ise ticaret ve tayın (07 §10.7) | 07 |

**f) Diplomasi** (09 §6.7): bağış, ortak kordon önerisi, koruma ve tanıma, protesto, savaş. Konsey oyu §5'te.

**g) Mülteciler** (07 §10.7): gıda oranı ≥ 1,0 ve sınır eyaleti SALGIN değilse kabul; 0,85–1,0 kamp; aksi ret.

**h) Doktrin (yetenek ağacı)** (06 §4, M6): kök, tutuma göre (Önce Sağlık → bilim kökü; Önce Düzen → düzen kökü; öteki ikisi → üçüncü
kök); dallar `ai_mult` ile coğrafyaya göre (ada → Surlar İçinde; kara → Kordon Devleti; `k_c < 0,2` → Ortak Nöbet).

### 4.5 Çatışan istekler: tek bütçe

Mod katmanı ile temel katman aynı kaynakları ister (inşaat kapasitesi, fabrika, nüfuz). Sıra şöyledir: **(1)** kendi `YE_bild ≥ 0,05`
iken kordon ve sağlık, **(2)** gıda açığı varsa gıda, **(3)** bilim, **(4)** temel oyunun inşaat/üretim kuralı. Nüfuz harcaması aynı
yedek kuralıyla sınırlıdır (bedel + 30). Böylece yapay zekâ salgın yokken 1936'daki gibi davranır, salgın gelince önceliği kayar.

### 4.6 Devletler arası savaş

02 §7.2 ayarı (Kapalı / Yalnız Çöküş evresinde / Serbest) Y5 kancasıyla `_declare`'e bağlanır. Varsayılan "Yalnız Çöküş": yapay zekâ
yalnız hedef **çökmüşse** ve kendi `YE_bild < 0,05` ise, koruma altına alma (09 §5.4) yerine savaşı seçebilir; olasılık ayda %10.
Temel oyunun tarihî savaş takvimi (`ai.rearm_year`, `cautious_until`) modda kapalıdır: manifestte `"ai": {"rearm_year": 0,
"cautious_until": "", "phoney_war_days": 0, "major_hold_fire_days": 0}` (mod altyapısının mevcut alanları).

---

## 5. Konsey yapay zekâsı ve olay seçimi

**Konsey** (09 §6.6): Cenevre'de, ayda bir oturum; dokuz tasarıdan biri gündeme gelir. Her yapay zekâ üyesinin "evet" olasılığı 09'daki
tabloda yazılıdır; oyuncu kendi oyunu verir (oyuncu adına oy kullanılmaz). Oy sayımı karmayla değil **olasılık × 100 ≥ karma(…) × 100**
biçiminde belirlenimcidir. Konsey'in kendisi karar vermez; yalnız gündem sırasını uygular (09 §6'daki öncelik sütunu).

**Olay seçimi:** Yapay zekâ ülkesine gelen olayda motor seçenekleri `ai` ağırlığıyla seçer (mevcut `Politics`). Mod olaylarında ağırlık
koşula bağlanabilir: `"ai": 0.6, "ai_mult": [{"if": {"zm_reported_prevalence": 0.1}, "x": 2.0}]` (06 M6'daki alanın olaylara
genişletilmesi; Y2 ile aynı değerlendirici). Oyuncuya gelen olayda seçenek **asla** kendiliğinden seçilmez: olay, oyuncu seçene dek
mevcut `Politics.pending_events` kuyruğunda bekler (motorda süre sınırı yoktur). Bekletmenin bir bedeli olsun mu, açık sorudur (§14-7):
bedel olmazsa oyuncu kötü seçenekleri sonsuza dek erteleyebilir; bedel olursa bu, oyuncu adına verilmiş bir karar gibi okunmamalı.

---

## 6. Hile yapmamak

### 6.1 Neden önemli?

Oyuncu yapay zekânın aynı kurallarla oynadığına inanmazsa kaybı "haksızlık" olarak okur. Salgın modunda bu risk daha büyüktür, çünkü
oyun zaten **eksik bilgiyle** oynanır (01 Sütun 2): yapay zekâ gerçek sayıyı görseydi, onun erken ve doğru önlemleri oyuncuya
"sezgi" değil "hile" gibi görünürdü.

### 6.2 Kurallar

| Alan | Kural |
|---|---|
| Bilgi | §4.2 tablosu: bildirilen veri, bülten, görünür sürüler |
| Kaynak | Yapay zekâya zorluk düzeyine göre üretim, araştırma ya da insan gücü bonusu **verilmez** |
| Zaman | Yapay zekâ kararları 7/14 günde bir; oyuncu her an karar verebilir. Bu, oyuncunun lehinedir ve bilerek öyledir |
| Salgın | Salgın modeli ülke ayırt etmez; oyuncunun ülkesinde β, κ, μ aynıdır. Zorluk bütün dünyaya birden uygulanır |
| Başlangıç yeri | Zorluk ayarı dışında oyuncuya özel bir yere konmaz (02 §7.1) |

### 6.3 İstisnalar (bilinçli)

| Aktör | Gerçek veriyi görür mü? | Neden |
|---|---|---|
| Sürü YZ | Evet: bölgedeki tümen sayısını ve yaşayan nüfusu | Boşların "bilgisi" duyularıdır; bu bir oyuncu değil, doğa kuralıdır |
| Salgın modeli | Evet | Modelin kendisi |
| Konsey | Hayır: bülten verisiyle oylar | Bir kurum da ülkeler kadar kördür |

---

## 7. Zorluk

### 7.1 Hazır zorlukların yapay zekâya etkisi

02 §7.1 salgın parametrelerini verir. Yapay zekâ satırı orada sözle yazılıdır ("hızlı ve işbirlikçi / kapasiteye göre / yavaş");
burada sayıya çevrilir. Yapay zekâ ülkelerine **bonus verilmez**; yalnız tepki hızı ve işbirliği eğilimi değişir.

| Parametre | Tatbikat | **Salgın** | Kara Yıl | Gerekçe |
|---|---|---|---|---|
| Karar aralığı (stratejik) | 5 gün | 7 gün | 10 gün | Temel oyunun 7 günü ortada; yavaş karar = daha çok yayılma |
| Eşik çarpanı (yasa, sınır) | ×0,7 | ×1,0 | ×1,4 | Düşük eşik = erken önlem |
| Bülten şeffaflığı tabanı | +0,15 | 0 | −0,15 | 09 §6.1 |
| Bağış olasılığı | ×1,5 | ×1,0 | ×0,5 | 02: "yardım nadir" |
| Paylaşım teklifine "evet" | ×1,3 | ×1,0 | ×0,6 | 05 §9 ve 09 §6.3 kabul formülü |
| Enstitü eşiği `k_c` | 0,25 | 0,35 | 0,50 | Kara Yıl'da dünyada daha az laboratuvar |
| Oyuncuya karşı savaş | Kapalı | Yalnız Çöküş | Yalnız Çöküş | Kara Yıl zaten zor; savaşı oyuncu "Serbest"e alabilir |

Bu satırlar `own/ai.json`'daki `difficulty` bölümündedir (§12). Denge testleri üç zorlukta ayrı koşar (§8).

### 7.2 Dinamik zorluk: yok

| Seçenek | Artı | Eksi |
|---|---|---|
| Dinamik zorluk (oyuncu iyiyse salgını hızlandır, kötüyse yavaşlat) | Daha çok oyuncu "akış" durumunda kalır; kısa oyunlarda yararı ölçülmüştür | Strateji oyununda **planlama cezalandırılır**: iyi kordon kuran oyuncuya daha hızlı salgın gelir. "Her önlemin bir bedeli vardır" sütunu (01 Sütun 3) anlamını yitirir. Oyuncular ayarlamayı fark edip sömürür (bilerek kötü oynayıp rahatlatmak). Belirlenimciliği ve denge testini karmaşıklaştırır. Oyunun sonunda "başardım" mı "oyun beni taşıdı" mı sorusu doğar |
| **Sabit hazır zorluk + Özel ayar** | Sonuçlar oyuncunun kararlarından gelir; tohumla paylaşılabilir; denge testi zorluk başına bir kez yapılır | İlk oyunda doğru zorluğu seçmek zor olabilir |

**Karar: dinamik zorluk yok.** İlk oyun için iki yumuşak yardım var, ikisi de zorluğu değiştirmez:
1. **Rehber ipuçları** (02 §7.2): ilk 30 gün, yalnız bilgi.
2. **Oyun sonu önerisi:** Oyuncu 180. günden önce çökerse oyun sonu ekranında "Tatbikat'ı dene" satırı; oyuncu 1940'a KSE < 5 ile
   ulaşırsa "Kara Yıl'ı dene". Öneri yalnız metindir.

### 7.3 Puan ve zorluk

Dayanma zaferinin puanına (02 §4.1) zorluk çarpanı uygulanır: Tatbikat ×0,6, Salgın ×1,0, Kara Yıl ×1,5; Özel ayarda çarpan, R₀'nun
varsayılana oranıdır (`R₀ / 3,1`), 0,5–2,0 arasında kırpılır. Gerekçe: puan, "ne kadar zor bir dünyada ne kadar kurtardın?" sorusunu
yanıtlamalı; ayarı düşürüp puan toplamak anlamsız olmalı.

---

## 8. Denge testi: otomatik kontroller

### 8.1 Araç

Temel oyundaki `tools/balance_parallel.sh` + `game/dev/balance.gd` kalıbı. Mod için ayrı betik: `game/dev/zm_balance.gd` (oyuncusuz
dünya, 1.461 gün, tohum argümanı) ve `tools/balance_parallel.sh`'ye `--game_mode=zombie` geçişi (betik bugün `balance.gd`'yi koşar;
`balance.gd` ww2 dışındaki modda çıkış 2 verir, bu yüzden mod betiği ayrı yazılır). 6 paralel koşu, her kontrol en az 5/6.
Tahmini süre: temel oyun 1936–1942 (6 yıl) ~15 dk; mod 4 yıl ama ×1,3–1,5 maliyet → ~13–15 dk.

### 8.2 Kontroller (varsayılan zorluk)

| # | Kontrol | Hedef | Kaynak |
|---|---|---|---|
| 1 | İlk tespit günü | 8–31 | 02 §8 |
| 2 | Evre 2'ye giriş | 60–150. gün | 02 §8 |
| 3 | Evre 3'e giriş | 150–400. gün | 02 §8 |
| 4 | 540. güne kadar en az bir ülke çöker | evet | 02 §8 |
| 5 | Bitişte çökmüş ülke sayısı | 1–25 | 02 §8 |
| 6 | Bir ülke serumu bulur | 240–450. gün | 02 §8, 05 |
| 7 | Bir ülke aşıyı bulur | 600–900. gün | 02 §8, 05 |
| 8 | Bitişte yaşayan nüfus / 1936 | %35–%75 | 02 §8 |
| 9 | Aynı tohumla iki koşu aynı | evet | 02 §8, §11 |
| 10 | 1.461 günlük koşu süresi | temel oyunun en çok ×1,3'ü | 02 §8, §10 |
| 11 | **Orta ülke dayanıklılığı:** 1936 fabrikası 10–40 olan yapay zekâ ülkelerinin 365. günde çökmemiş payı | ≥ %70 | Bu belge. "Orta zorlukta orta ülke bir yıl ayakta kalır" |
| 12 | **Tutum çeşitliliği:** dört kriz tutumunun her biri en az 3 ülkede | evet | §4.3 |
| 13 | **Kordon kurma:** Evre 2'de kendi bildirilen vakası olan yapay zekâ ülkelerinin kordon ordusu kurmuş payı | ≥ %60 | 08 §15 |
| 14 | **Sürü sınırı:** herhangi bir günde birim sayısı | ≤ 1.200 (web yapısında ≤ 800) | 03 §10 |

Tatbikat ve Kara Yıl için 4, 5, 6, 7, 8 ve 11. kontrollerin hedefleri kaydırılır (ör. Kara Yıl'da 8: %20–%55, 11: ≥ %45). Kaydırılmış
tablo ilk ölçümden sonra yazılır; önceden uydurulmaz (açık soru 3).

### 8.3 "Oyuncu adına iş yok" denetimi

`game/dev/country_check.gd -- --game_mode=zombie` (mod altyapısında var): oyuncu hiçbir şey yapmazsa 60 günde oyuncunun ülkesinde
hiçbir yasa, sınır tutumu, bina, üretim hattı, ordu, doktrin, bağış, oy değişmemiş olmalı; otomatik serum/aşı/kordon/ticaret seçenekleri
kapalı kalmalı. 08 §15'in listesi bu denetime eklenir.

---

## 9. Motor kancaları (içerikten bağımsız)

Mod altyapısındaki `ModeRules` sınıfına (`game/core/mode_rules.gd`) eklenecek kancalar. Her biri WWII'de boş döner, yani WWII davranışı
değişmez (mod altyapısının "birebir aynı" testi bunu denetler).

| # | Kanca | Yer | Boyut | Yapılmazsa |
|---|---|---|---|---|
| Y1 | `ai_strategic(c)`: stratejik katmanın sonunda çağrılır | `AI._strategic` son satırı | ~2 satır | Mod katmanı `on_day`'de ayrı döngüyle çalışır; kademeli takvimi kendisi tutar (+~0,2 ms/gün) |
| Y2 | `ai_military(c) -> bool`: `true` dönerse temel `_military` atlanır | `AI._military` başı | ~3 satır | Kordon orduları temel `_assign` ile çakışır; tümenler kordondan cepheye çekilir |
| Y3 | Araştırma önceliği manifestten: `ai.research_priority` | `AI._research` (`RESEARCH_PRIORITY` yerine) | ~3 satır | Yeni kategoriler temel sıranın sonuna düşer (06 M5 ile aynı kanca) |
| Y4 | `ai.laws = "rules"` ise `_laws` atlanır; mod kendi yasa politikasını uygular | `AI._laws` başı | ~2 satır | Temel oyunun "savaş ekonomisi" sırası salgın yasalarıyla yarışır |
| Y5 | `can_declare(a, b) -> bool` | `AI._declare` ve `Diplomacy.declare_war` başı | ~4 satır | 02 §7.2 ayarı uygulanamaz |
| Y6 | Düşman tanımı: `Diplomacy.are_enemies(tag, "UND")` her zaman `true`, `at_war` salgını saymaz (09 S1 ile aynı iş) | `Diplomacy` | 09 S1 | 08 B2'deki yan etkiler (seçim ertelenmesi, savaş yasaları) |

Y1–Y5 bu belgeye, Y6 09'daki S1'e aittir. Hepsi 14_teknik_plan.md'deki kanca listesinde toplanır.

---

## 10. Performans bütçesi

### 10.1 Günlük bütçe (masaüstü, ekransız; 03 §12.1'deki makine)

| Kalem | Tahmin (ms/gün) | Dayanak | Ölçüm anahtarı |
|---|---|---|---|
| Temel oyun (1936 barışı → savaşsız dünya) | 115–150 | 03 §12.1 ölçümü | mevcut |
| Salgın adımı | 6–12 | 03 §12.2 | `epidemic` |
| Çekim alanı Φ | 1–3 | §3.3 tahmini | `und_field` |
| Sürü emirleri (~400 karar, komşu puanı) | 2–4 | 400 × 6 komşu × birkaç çarpım | `und_ai` |
| 1.200 sürünün saatlik hareketi ve muharebesi | 36–60 | 03 §12.2 | mevcut `military` |
| Devlet YZ salgın katmanı | 0,5–1,5 | 80 ülke / 7 gün × ~50 eşik denetimi | `ai_zm` |
| **Toplam ek** | **~46–80** | | |

Temel oyuna göre ×1,3–1,5. 02 §8'in hedefi ×1,3 olduğu için sürü sınırı ve eyalet başına 2 birim kuralı (03 §12.2) ilk ayardır.

### 10.2 Web

WASM'da GDScript masaüstünden tahminen 1,5–3 kat yavaştır (03 §16-6; ölçülmedi). Web yapısında: sürü sınırı 800, eyalet başına 2 birim,
Φ iki günde bir (sürülerin 3 günlük yeniden hedef döngüsü zaten daha yavaştır; fark oynanışta görünmez). Yapı türü `OS.has_feature("web")`
ile okunur, sayılar `own/ai.json` → `web` bölümündedir.

### 10.3 Zaman dilimleme

Gün dönümündeki takılma (03 §12.3) sürü YZ için de geçerlidir. Gerekirse sürü emirleri 24 saate bölünür: `d.id % 24 == saat` olan sürüler
o saat karar verir. Sonuç, kararların gün başındaki Φ ile verilmesi sayesinde birebir aynı kalır.

---

## 11. Belirlenimcilik

| Bileşen | Rastgelelik kaynağı | Kayda yazılır mı? |
|---|---|---|
| Salgın modeli | Sayaç karması (03 §11.2), akış 1–6 | Yalnız `world_seed` |
| Sürü YZ | Sayaç karması, akış 7 (hedef), akış 8 (birleşme sırası) | Hayır; yeniden hesaplanır |
| Konsey | Sayaç karması, akış 9 | Hayır |
| Devlet YZ | Global `randf()` (temel oyundaki gibi) | Hayır (temel oyunla aynı sınır) |

Sonuç: aynı tohumla yeni oyun iki kez koşulursa aynı dünya çıkar (mevcut `test_determinism.gd` kalıbı). Kayıttan devam edilen oyun,
temel oyunda olduğu gibi global üreteç kayda yazılmadığı için devlet YZ kararlarında ayrışabilir; salgın ve sürüler ayrışmaz. Bu sınır
temel oyundan gelir ve modda genişlemez.

**Çift tampon:** Sürü emirleri gün başındaki Φ ve bölge durumuyla verilir, uygulanması sonraki saatlerdedir. Sürülerin işlenme sırası
sonucu değiştirmez.

---

## 12. Veri: `data/modes/zombie/own/ai.json` (şema örneği)

Modun kendi verisi `own/` klasöründedir (mod altyapısı: `GameModes.load_own("ai.json")`). Temel oyunda karşılığı olmadığı için yama
değil, modun kendi dosyasıdır.

```json
{
 "_comment": "Zombi modu yapay zekâ eşikleri. Gerekçeler: docs/modlar/zombi/10_yapay_zeka_ve_zorluk.md",
 "horde": {
  "retarget_days": 3,
  "top_k": 3,
  "noise_mult": 0.5, "noise_days": 2, "noise_rings": 2,
  "trail_mult": 0.2, "trail_days": 5,
  "leader_mult": 0.3,
  "river_mult": 0.5,
  "local_min": 0.001,
  "field_min_living": 10000,
  "field_median_km": 285,
  "cap": {"desktop": 1200, "web": 800},
  "per_state": {"desktop": 3, "web": 2},
  "field_every_days": {"desktop": 1, "web": 2}
 },
 "state": {
  "strategic_days": 7,
  "law_days": 14,
  "capacity_factories": 40,
  "stance_rules": [
   {"if": {"capacity_min": 0.5, "trust_min": 0.45}, "stance": "health_first"},
   {"if": {"island": true}, "stance": "order_first"},
   {"if": {"capacity_max": 0.2}, "stance": "solidarity"},
   {"stance": "livelihood_first"}
  ],
  "institute": {"capacity_min": 0.35, "second_capacity_min": 0.7},
  "serum_share": [0.10, 0.20], "vaccine_share": 0.15, "vaccine_target_coverage": 0.30,
  "clearance_power_ratio": 1.5, "cordon_max_share": 0.70, "rotation_days": 25
 },
 "difficulty": {
  "drill":    {"strategic_days": 5,  "threshold_mult": 0.7, "transparency": 0.15,  "donate_mult": 1.5, "share_yes_mult": 1.3, "institute_capacity_min": 0.25},
  "outbreak": {"strategic_days": 7,  "threshold_mult": 1.0, "transparency": 0.0,   "donate_mult": 1.0, "share_yes_mult": 1.0, "institute_capacity_min": 0.35},
  "black_year": {"strategic_days": 10, "threshold_mult": 1.4, "transparency": -0.15, "donate_mult": 0.5, "share_yes_mult": 0.6, "institute_capacity_min": 0.50}
 },
 "score_mult": {"drill": 0.6, "outbreak": 1.0, "black_year": 1.5, "custom_min": 0.5, "custom_max": 2.0}
}
```

Manifestte (`data/modes/zombie/mode.json`) yapay zekâya ilişkin alanlar, mod altyapısının bugünkü alanlarıyla:
`"ai": {"rearm_year": 0, "cautious_until": "", "phoney_war_days": 0, "major_hold_fire_days": 0}` ve `"combat": {"phoney_war_days": 0}`.
Y3 kancası gelince `ai.research_priority` alanı eklenir (mod altyapısının `SUB_DEFAULTS["ai"]` listesine).

---

## 13. Test planı

| # | Test (`tests/test_zm_ai.gd`) | Ne denetler |
|---|---|---|
| 1 | Φ doğru yönde | Tek kaynaklı küçük grafikte Φ kaynağa doğru azalır; sürü 30 günde kaynağa yaklaşır |
| 2 | Yerel puan tümenden kaçınır | İki eşit komşudan tümensiz olan seçilir |
| 3 | Top sesi çeker | Topçulu muharebe açılınca 2 halka içindeki sürülerin hedefi oraya döner |
| 4 | Deniz geçilmez | Ada eyaletine sürü yürüyemez |
| 5 | Emir bütçesi | Bir günde verilen emir sayısı ≤ sürü sayısı / 3 + varanlar |
| 6 | Hile yok | Devlet YZ'nin okuduğu değerler `*_reported` alanlarıdır (gerçek alanlara erişen çağrı sayısı 0; sarmalayıcıyla sayılır) |
| 7 | Tutum seçimi | Kapasite/coğrafya/güven girdileriyle §4.3 tablosu birebir |
| 8 | Oyuncuya dokunmaz | Oyuncu ülkesinde 60 günde hiçbir mod kararı yok (country_check ile aynı) |
| 9 | Belirlenimcilik | Aynı tohum: sürü konumları, Konsey oyları, tutumlar aynı |
| 10 | WWII etkisiz | Y1–Y5 WWII'de boş; mod altyapısının birebir aynılık testi yeşil |

---

## 14. Açık sorular

1. **Φ'nin gerçek maliyeti** web yapısında ölçülmeli (§10.2). 3 ms'yi aşarsa iki günde bir hesap masaüstünde de varsayılan olabilir.
2. **Sürüler kordonu "sezmeli" mi?** Bu belge hayır diyor (§3.4). Oyun testinde kordonlar fazla kolay tutulursa, yalnız Kösemen önderli
   sürülere "zayıf komşuyu seç" eğilimi (tümen sayısı en düşük sınır bölgesi) eklenebilir.
3. **Tatbikat ve Kara Yıl kontrol hedefleri** ilk ölçümden sonra yazılacak (§8.2).
4. **Devlet YZ'nin global üreteci** kayda yazılsın mı? Temel oyunda da yazılmıyor; ikisi birlikte çözülmeli (mod altyapısının
   `ModeRules.to_save` notu: büyük tamsayılar metin olarak).
5. **Yapay zekâ kişiliği** yalnız üç eksenle mi kalmalı? 06'nın 11. açık sorusuyla birlikte: liderin kişisel özellikleri (ROADMAP V3
   generaller) gelince dördüncü eksen olabilir.
6. **Konsey'de oyuncunun ağırlığı:** Oyuncunun oyu yapay zekâ üyeleriyle eşit mi, itibara göre ağırlıklı mı? (09 ile birlikte.)
7. **Bekleyen olayın bedeli:** Salgın olayları (ör. liman kapatma) yanıtsız kalırsa dünya yine de ilerler. Öneri: olay seçilmeden
   geçen her hafta, olayın tanımındaki `pending_cost` etkisi (ör. istikrar −%1) uygulanır ve olay penceresinde bu satır görünür.
   Seçenek kendiliğinden seçilmez. Motor değişikliği küçük (bekleyen olay listesinde gün sayacı); 09 ile birlikte karar verilmeli.

## 15. Kaynaklar

- Reynolds, C. W. (1987). *Flocks, herds and schools: A distributed behavioral model.* SIGGRAPH '87. https://doi.org/10.1145/37402.37406
  · özet ve açıklama: https://www.red3d.com/cwr/boids/
- Helbing, D., Molnár, P. (1995). *Social force model for pedestrian dynamics.* Physical Review E 51, 4282–4286.
  https://pubmed.ncbi.nlm.nih.gov/9963139/
- Treuille, A., Cooper, S., Popović, Z. (2006). *Continuum crowds.* ACM Transactions on Graphics 25(3), 1160–1168.
  https://doi.org/10.1145/1141911.1142008
- Hunicke, R. (2005). *The case for dynamic difficulty adjustment in games.* ACE '05, 429–433. https://doi.org/10.1145/1178477.1178573
- Dijkstra, E. W. (1959). *A note on two problems in connexion with graphs.* Numerische Mathematik 1, 269–271.
  https://doi.org/10.1007/BF01386390
- Kermack, W. O., McKendrick, A. G. (1927). *A contribution to the mathematical theory of epidemics.* Proc. R. Soc. A 115, 700–721.
  https://doi.org/10.1098/rspa.1927.0118
- Depodaki kod: `game/autoload/ai.gd` (stratejik ve operasyonel katman), `game/autoload/military.gd` (`order_move`, `find_path`,
  ikili yığın), `game/core/mode_rules.gd`, `game/core/game_modes.gd` (`load_own`), `tools/balance_parallel.sh`, `game/dev/country_check.gd`.
- Bu klasör: 01, 02, 03 §10–§12, 04 §2.4–§2.5, 05 §10–§11, 06 §3.12 ve §4, 07 §10.7, 08 §15, 09 §3.9, §4, §6.
