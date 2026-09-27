# Zombi modu — 04 Zombi türleri: Boş tabloları, suşlar ve evrim ağacı

> **Özet.** Bu belge *Gri Kordon* modundaki "zombi türlerini" tanımlar. Kararlar 01_vizyon.md ve 02_oynanis_dongusu.md'ye dayanır.
> - Hastalık tek bir etkendir (EF etkeni). "Tür" iki katmanda ele alınır: **9 tablo** (hastalığın gösterdiği klinik görünüm; sürü
>   birimini belirler) ve **5 suş** (etkenin evrimi; salgın parametrelerini değiştirir). Toplam 14 tür vardır. Ölüler dirilmez ve
>   hayvanlar hastalanmaz.
> - Birim modeli 01'deki melez karara uyar: gerçek sayı eyaletteki H'dir. Sürü, `UND` tarafının `Division`'ıdır ve 10 **bloktan**
>   (1 blok = 1.000 Boş) oluşur. Blok, `units.json`'daki tabur biçimini aynen kullanır; yeni bir birim sınıfı gerekmez.
> - Muharebe değerleri piyade taburu ölçeğinden (30 / 110 / 100) türetildi. Motorun muharebe formülünün Python taklidiyle
>   doğrulandı: siperli bir piyade tümeni 3 Olağan sürüyü (30.000 Boş) tutar, 4 sürüde (52 saatte) çekilir.
> - Boş ömrü enerji harcamasıyla (FAO/WHO/UNU fiziksel etkinlik düzeyi) ve soğukta metabolizmanın yavaşlamasıyla ölçeklenir.
>   Isırık payı, kuduzda bulaşın ısırık yerine bağlı olmasından (Cleaveland ve ark. 2002) yola çıkarak belirlendi.
> - Evrim ağacında **9 özellik** vardır. Her biri gerçek bir evrimsel epidemiyoloji bulgusuna dayanır (Ewald, Read, Gandon, Day, Walther).
>   **Oyuncunun seçimleri** (yarım doz serum, kalabalık hastane, nehir kordonu, sıkı karantina, seri pasaj) belli özellikleri
>   besler. Yeni suşlar bilgi sisinin arkasında doğar ve bülten ya da numuneyle öğrenilir.
> - Görsel ve ses için yalnız liste, özellik ve üretim komutu verilir (dosya üretilmez). JSON şeması §12'dedir.

---

## 1. Kapsam ve ilkeler

| İlke | Uygulama |
|---|---|
| Tek hastalık, biyolojik tutarlılık | Bütün türler aynı etkenin farklı **görünümleri** ya da **evrimleridir**. Her türün gerçek bir tıbbi, fizyolojik ya da evrimsel dayanağı vardır (her kartta "Dayanak" satırı) |
| Tür = veri | Her tür bir `units.json` bloğu, bir `UND` şablonu ve bir kurallar kaydıdır (§12). Motor tür adını bilmez; davranışı JSON'daki anahtarlar seçer |
| Yeni sistem yok, kanca var | Tür davranışları motorda küçük kancalarla yürür: gece çarpanı, uyuşukluk, gizlilik, önder etkisi, nehir kuralı (§2.5). Hepsi mevcut muharebe, hareket ve ikmal koduna ek koşuldur |
| Oyuncu karar verir | Mutasyonlar dünya olaylarıdır; oyuncu adına iş yapmazlar. Oyuncunun seçimleri yalnız mutasyon **olasılıklarını** etkiler ve bu etki seçim anında ipucunda yazar |
| Ton (01 §6) | Kan, uzuv ve çocuk figürü yoktur. Boşlar hastadır, metinler onları aşağılamaz. Hayvan türü yoktur (01 açık soru 6'daki öneriyle uyumlu). Hiçbir tür bir halk, din ya da ülkeyle ilişkilendirilmez; farkı iklim, arazi ve kararlar yaratır |
| Adlar | Türkçe adlar ya tıbbi terimdir ya gündelik Türkçe sözcüktür ("kösemen": sürünün önünden giden koç ya da teke, TDK). İngilizce adlar genel sözcüklerdir. Aday adlar Eylül 2026'da web'de tarandı; başka yapımlarda tür adı olarak kullanılanlar elendi |

## 2. Birim modeli: yoğunluk + sürü (melez)

### 2.1 Katmanlar
```
EYALET (1.652)             BÖLGE (13.414)             SÜRÜ BİRİMİ (en çok 1.200)
H_s = dağınık H + Σ birim  controller = UND ise        UND'ye ait Division
tür payları (belleksiz)    "düşmüş"                    şablon = tür, 10 blok × 1.000 Boş
suş payları (≤ 3 soy)                                  strength × 10.000 = içindeki Boş
```
- **Gerçek sayı** eyaletteki `H_s`'dir (02 §2.1). Salgın denklemleri `H_s`'yi kullanır; birimler bu sayının haritada görünen,
  hareket eden ve savaşan kısmıdır.
- **Korunum:** `H_s = H_dağınık,s + Σ_{s'deki birimler} strength × 10.000`. Birim doğunca dağınık H'den düşülür; birim dağılınca
  kalan Boşlar dağınık H'ye geri eklenir; muharebede ölen Boş D'ye yazılır. Test: bir günlük adım boyunca dünyadaki toplam H'nin
  değişimi, "F → H" girişi eksi "bastırılan + çürüyen + muharebede ölen" çıkışına eşit olmalıdır (tolerans 1 Boş).
- Doğma eşiği, yürüyüş hedefi ve birleşme kuralının kesin biçimi muharebe/kordon belgesinde yazılacak (02 §12 açık soru 5).
  Bu belgenin önerisi şudur: dağınık H ≥ 10.000 olduğunda bir sürü doğar. Doğan sürünün türü §2.3'teki ağırlıklarla seçilir;
  aynı bölgede aynı türden iki sürünün toplam gücü ≤ 1,0 ise birleşirler.

### 2.2 Blok = tabur biçimi
Bir blok, `units.json`'daki tabur kaydıyla aynı anahtarları taşır (`soft`, `hard`, `defense`, `breakthrough`, `hp`, `org`, `width`,
`speed`, `hardness`). `Military.stats()` bir şablonun değerlerini zaten tabur toplamından hesaplar. Bu yüzden `UND`'nin her türü
için 10 bloklu bir şablon yazmak yeterlidir. `manpower` ve `equipment` 0'dır; `UND` takviye almaz.

### 2.3 Tür payları eyalette nasıl tutulur?
- **Tablolar (9 tür):** Eyaletin koşullarından (iklim, arazi, kent/maden, suş) her gün **belleksiz** olarak hesaplanır:
  `pay_t,s = w_t(s) / Σ_t w_t(s)`. Ağırlıklar §4'teki "nadirlik" sütunundadır. Kösemen ve Kaputlu olayla tetiklenir ve yalnız
  birim olarak vardır. Gerekçe: 1.652 eyalet × 9 pay kayda yük getirir, belleksiz hesap bu yükü kaldırır. Eyalet ölçeğinde tür
  dağılımı zaten koşulların bir işlevidir.
- **Eyalet parametresine etki:** `β_etkin,s = β · Σ_t pay_t,s · β×_t`; κ ve μ de aynı yolla karışır.
- **Suşlar (5 tür + 4 ek özellik):** Her eyalette en çok 3 soyun payı **bellekli** tutulur (kayda girer). Nedeni: suşlar yolcu akışıyla
  taşınır ve eyaletler arasında yarışır (§7.3).

### 2.4 `UND` kuralları (temel oyundan farklar)
| Kural | Temel oyun | `UND` sürüsü | Gerekçe |
|---|---|---|---|
| Bütünlük %12'nin altına inerse | Geri çekilir | **Dağılır**: birim kalkar, kalan Boşlar dağınık H'ye döner | Boşlar korkmaz ama kalabalığın baskısı çözülür; dağılan kalabalık yok olmaz |
| İkmal | İkmalsizse −%35 muharebe, günde −%1 güç | **İkmal yok, ceza yok.** Bunun yerine her gün `strength ×= 1 − μ·iklim·μ×_t` | Boşun "ikmali" ömrüdür; açlığı μ zaten sayar |
| Kış yıpranması | Günde `−0,0025·winter_level` | Yok (iklim μ'ye dahil) | İki kez sayılmasın |
| Tecrübe | Muharebede artar | Artmaz (`xp` 0,15'te sabit, çarpan 1,0) | Boşlar öğrenmez |
| Arazi saldırı çarpanı | ova 0, orman −0,15, tepe −0,25, dağ −0,5, bataklık −0,4, kent −0,3 | ova 0, orman −0,05, tepe −0,10, dağ −0,30, bataklık −0,40, çöl 0, **kent 0** | Temel oyundaki cezalar, ateş altında örgütlü taarruzun zorluğunu anlatır. Kalabalık ise bina ve ağaç arkasından görünmeden sokulur. Dağ ve bataklık yalnız bedenen yavaşlatır |
| Nehir geçişi | −0,3 | **−0,6** (Sazlıkçı 0) | Kuduz hastalarının yaklaşık yarısında su korkusu (hidrofobi) görülür. Olağan Boş'ta bu tablo, nehri yarı engel yapar |
| Planlama, hava üstünlüğü | Var | Yok | Komuta ve uçak yok |

### 2.5 Motora eklenecek kancalar (tür davranışları)
| Kanca | Nerede | Kullanan türler |
|---|---|---|
| `und_attack_mod(d, pid)`: arazi ve nehir tablosu, gece çarpanı | `Military.attack_mod` / `defend_mod` içinde `d.owner == "UND"` dalı | Hepsi; Gecegezer, Sazlıkçı |
| `torpid(d)`: kışta hız 0, saldırı yok | `_move_all`, `_armies_tick` (yapay zekâ) | Kışlayan |
| `hidden_from(d, tag)`: sayaç gizli | `unit_layer.gd` sayaç çiziminde görünürlük süzgeci | Durgun, Dehlizci, Gecegezer (gece) |
| `aura(d)`: komşu `UND` birimlerine bütünlük çarpanı | `div_stats` önbelleği dışında, muharebe başında | Kösemen |
| `bite(d_hedef, kayıp)`: tümen kaybının bir payı "ordu içi bulaşa" yazılır | `_apply_hits` sonrası | Hepsi (ısırık payı, §3.4) |
| `noise_pull(pid)`: topçulu muharebe, 2 bölge içindeki sürüleri çeker | Günlük `UND` yapay zekâsı | Hepsi (Seğirtken ve gece Gecegezer ×2) |

Kayda eklenecekler (CLAUDE.md kural 9): `Division.infected` (ordu içi bulaş payı). Eyalet başına şunlar da kaydedilir:
Kaputlu havuzu, en çok 3 soyun payı, dünya soy tablosu ve ülke başına keşif bayrakları.

## 3. Muharebe ölçeği ve türetme yöntemi

### 3.1 Mevcut ölçek (depodaki değerler)
| Birim | Personel ateşi | Tanksavar ateşi | Savunma | Şok | Can | Bütünlük | Cephe genişliği | Hız (km/sa) | Zırh oranı |
|---|---|---|---|---|---|---|---|---|---|
| Piyade taburu (1.000 asker) | 30 | 5 | 110 | 15 | 50 | 100 | 4 | 4 | 0 |
| Piyade tümeni (7 piyade + 2 topçu, 8.000 kişi) | 460 | 55 | 870 | 165 | 352 | 100 | 40 | 4 | 0 |
| Garnizon tümeni (5 piyade) | 150 | 25 | 550 | 75 | 250 | 100 | 20 | 4 | 0 |
| Zırhlı tümen (4 hafif tank + 4 motorlu) | 440 | 100 | 520 | 500 | 216 | 58,5 | 32 | 10 | 0,45 |

Muharebe formülü (`military.gd`): saldırı = `(PA·(1−zırh oranı) + TA·zırh oranı) · güç · çarpan`. Saldırının savunma (ya da şok)
değerine kadar olan kısmı 0,1, üstündeki kısmı 0,4 oranında isabet eder. Her isabet 0,0367 bütünlük ve `0,022/can` güç düşürür.
Siper, savunmayı 10 günde %15 artırır.

### 3.2 Olağan Boş bloğu (1.000 Boş): her değerin gerekçesi
| Değer | Piyade taburu | **Boş bloğu** | Gerekçe |
|---|---|---|---|
| Personel ateşi | 30 | **12** | Menzil yoktur; yalnız temas hâlindeki ön sıralar zarar verir. Varsayım (bizim): 10.000 kişilik kalabalığın bir muharebe saatinde yaklaşık %40'ı temastadır. Temas anı bir tüfekçinin ateşi kadar etkilidir → 30 × 0,4 = 12 |
| Tanksavar ateşi | 5 | **0,5** | Silahları yoktur. Yalnız kapağı açık araçlara ve kamyon sürücülerine ulaşabilirler → piyadenin onda biri |
| Savunma | 110 | **15** | Siper, örtü ve karşılık ateşi yoktur; hep açıktadırlar. Bu yüzden piyadenin açıkta ilerlerken karşıladığı değer (şok 15) alındı |
| Şok | 15 | **10** | Ateş ve hareket bilmezler, örtüsüz yürürler → piyadenin 2/3'ü |
| Can | 50 | **25** | Kask, sıhhiye ve örtü yoktur; isabet başına kayıp iki kattır |
| Bütünlük | 100 | **70** | Korku yoktur ama komuta da yoktur. Değer kalabalığın itme gücünü anlatır. Bittiğinde sürü dağılır (§2.4) |
| Cephe genişliği | 4 | **4** | 10.000 kişilik kalabalık 40 birim yer kaplar; bir piyade tümeniyle aynıdır |
| Hız | 4 | **0,6** | 02 §2.4: Boş günde 10–20 km yürür → 0,6 × 24 = 14,4 km/gün |
| Zırh oranı | 0 | **0** | — |

**Olağan sürü (10 blok):** personel ateşi 120, tanksavar 5, savunma 150, şok 100, can 250, bütünlük 70, cephe genişliği 40, hız 0,6.

### 3.3 Motor taklidiyle doğrulama
Motorun `_resolve_battle` ve `_apply_hits` işlevleri Python'da birebir taklit edildi (rastgelelik ortalamada 1,0). Koşullar: ova,
savunan siperli (×1,15), hava desteği yok, arındırmada saldıranın hazırlığı tam (×1,2). Hedefler önce konuldu, değerler bu hedeflere
göre ayarlandı:

| Durum | Hedef | Ölçülen | Tümen bütünlüğü | Sürü kaybı | Tümen kaybı |
|---|---|---|---|---|---|
| 1 sürü → piyade tümeni | Sürü dağılır | 11 saatte dağıldı | %95 | %15 | %0,8 |
| 2 sürü → piyade tümeni | Tutar | 27 saatte dağıldı | %78 | %15 | %3,8 |
| 3 sürü → piyade tümeni | Zorla tutar | 57 saatte dağıldı | %30 | %15 | %11,9 |
| 4 sürü → piyade tümeni | Tümen çekilir | 52 saatte çekildi | %11 | %6 | %15 |
| 2 sürü → garnizon tümeni | Garnizon çekilir | 104 saatte çekildi | %11 | %6 | %21 |
| Arındırma: 1 piyade tümeni → 1 sürü (ova) | 1 günden kısa | 10 saat | %96 | %16 | %0,7 |
| Aynı, kent (saldırana −0,3) | Daha uzun | 14 saat | %94 | %15 | %1,0 |
| Zırhlı tümen → 1 sürü | Kısa | 13 saat | %95 | %15 | %0,8 |

**Sonuç:** 8.000 kişilik silahlı bir tümen 30.000 Boş'u tutar ve 40.000'de kırılır; silahlı-silahsız oranı yaklaşık 1:5'tir.
Bütünlük saatte %2 toparlandığı için dalgalar arasında bir gün dinlenen tümen, üst üste gelen 2 sürülük saldırıları karşılayabilir.
Açık arazideki bir sürü kolay dağıtılır. Zorluk üç yerden gelir: **sayı**, **kentler** ve **ordu içi bulaş**.

### 3.4 Türe göre ölçeklenen üç sayı
**Ömür (μ).** Boş açlık ve susuzlukla ölür (01 §5). Hayatta kalma süresi enerji ve su harcamasıyla ters orantılı alındı:
`ömür_t = 60 gün × FEZ_olağan / FEZ_t`. FEZ, FAO/WHO/UNU 2004 raporundaki fiziksel etkinlik düzeyidir (hareketsiz ve hafif etkin
1,40–1,69; orta etkin 1,70–1,99; çok etkin 2,00–2,40). Günde 14 km yürüyen Olağan Boş'a 1,7 (orta etkin, alt uç) verildi.

| Tür | FEZ | Ömür | μ çarpanı |
|---|---|---|---|
| Olağan | 1,7 | 60 gün | 1,00 |
| Seğirtken | 2,4 (çok etkin, üst sınır) | 42 gün | 1,41 |
| Durgun | 1,3 (dinlenmeye yakın) | 78 gün | 0,77 |

**Soğuk:** Vücut ısısı her 1 °C düştüğünde beyin metabolizması %6–7 azalır. Isı düzenleme merkezi (hipotalamus) hasar görünce
vücut ısısı çevreye uyar (poikilotermi). Kışlayan Boş'un iç ısısı 30 °C'ye (−7 °C) inerse metabolizması 0,935⁷ ≈ 0,62'ye düşer ve
ömrü ~1,6 kat uzar. Donarak ölenler de hesaba katılınca kışta μ ×0,7 alındı. Olağan Boş ise kışta 02'deki iklim çarpanıyla
(×2,0'ye kadar) daha hızlı ölür.

**Isırık payı (ordu içi bulaş).** Tümenin Boşlara karşı verdiği güç kaybının bu payı "enfekte asker" olarak yazılır. Kuduzda
bulaş ısırığın yerine bağlıdır: Tanzanya verisinde baş 0,55, kol 0,22, bacak 0,12, gövde 0,09. Yakın dövüşte kayıpların yaklaşık
%60'ı ısırık yarası olarak alındı (gerisi ezilme, düşme, bitkinlik). EF etkeni sinir dokusuna kuduzdan daha kolay yerleşen kurgusal
bir etkendir; bu yüzden ısırık başına bulaş ~0,6 alındı → **0,35**. El ve yüz ısırıklarını artıran türlerde (sürpriz, dar alan) bu
pay yükselir. Örnek: 3 sürüyü püskürten bir piyade tümeni %11,9 güç kaybeder; bunun 0,35'i, yani 8.000 kişiden ~330'u enfekte olur
(%4,2). Bu, 02 §1.2'deki "Enfekte tümen" uyarısını (%1) açar.

## 4. Tür kataloğu (özet)

Değerler **sürü** (10 blok) içindir. Karşılaştırma için piyade tümeni: 460 / 55 / 870 / 165 / 352 / 100 / 40 / 4 / 0.

| # | TR / EN | Katman | Ortaya çıkış (kısa) | PA | TA | Sav | Şok | Can | Büt. | Hız | Zırh | Ömür | β× | Isırık payı | Nadirlik |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T01 | Olağan Boş / Common Hollow | tablo | her yerde, başlangıçtan | 120 | 5 | 150 | 100 | 250 | 70 | 0,6 | 0 | 60 | 1,0 | 0,35 | ağırlık 100 (%65–77) |
| T02 | Seğirtken / Courser | tablo | her yerde; Kızgın suşla ×2 | 160 | 5 | 100 | 160 | 200 | 50 | 1,5 | 0 | 42 | 1,5 | 0,40 | 10 (%6–8) |
| T03 | Durgun / The Still | tablo (yuva) | kent, orman, tepe; Süreğen suşla ×2 | 80 | 0 | 300 | 0 | 250 | 100 | 0 | 0 | 78 | 0,5 | 0,50 | 12 (H'nin %8–9'u) |
| T04 | Kösemen / Bellwether | önder | H ≥ 50.000 olan eyalette doğan sürünün %4'ü | 120 | 5 | 150 | 120 | 250 | 90 | 0,8 | 0 | 60 | — | 0,35 | dünyada en çok 40 |
| T05 | Kaputlu / Greatcoats | olay | enfekte askerlerden (Kaputlu havuzu ≥ 2.000) | 140 | 5 | 250 | 140 | 300 | 80 | 0,9 | 0,10 | 75 | — | 0,35 | sürülerin %1–3'ü |
| T06 | Kışlayan / Winterers | tablo | "Kışlama" özelliği + kış | 20* | 0 | 50* | 0 | 250 | 100 | 0* | 0 | 86 (kışta) | 0,1* | 0,20* | 40 (kış eyaletinde) |
| T07 | Gecegezer / Night Hollow | tablo | sıcak iklimde ×3 | 120 (gece 168, gündüz 48) | 5 | 150 (gündüz 120) | 100 (gece 130) | 250 | 70 | 0,6 (gece 0,9) | 0 | 60 (çölde 50) | 1,1 | 0,40 | 8 (%5–16) |
| T08 | Dehlizci / Sump Hollow | tablo (gizli) | kentli ya da madenli eyalet; kışta ×2 | 140 | 5 | 300 | 80 | 250 | 80 | 0,4 | 0 | 67 | 0,8 | 0,45 | 25 (kentli eyalette %16) |
| T09 | Sazlıkçı / Waders | tablo | "Suya dayanım" özelliği + bataklık, nehir, kıyı | 120 | 5 | 150 | 120 | 250 | 70 | 0,6 | 0 | 75 | 0,9 | 0,35 | 15 |
| T10 | Hırıltılı suş / Rasping strain | suş | kış + yoğun eyalet | — | — | — | — | — | — | — | — | — | φ 0,15→0,45 | +0,15 | koşuların ~2/3'ü |
| T11 | Kızgın suş / Fervid strain | suş | hasta kalabalığı | ×1,15 | | | | | ×0,9 | | | 45 | 1,2 | 0,35 | ~1/2 |
| T12 | Dirençli suş / Refractory strain | suş | yarım doz / eksik serum | | | | | | | | | 60 | 1,0 | 0,35 | seçime bağlı |
| T13 | Soluk suş / Pale strain | suş | seri pasaj + laboratuvar kazası | ×0,7 | | | | ×0,8 | | | | 30 | 0,7 | 0,25 | seçime bağlı |
| T14 | Süreğen suş / Chronic strain | suş | konak azlığı (S/N⁰ < 0,5) | ×0,9 | | | | | ×1,1 | | | 150 | 0,8 | 0,35 | ~1/2 |

\* Kışlayan: yıldızlı değerler uyuşukluk (kış) içindir. Kış dışında Olağan Boş değerlerini alır.
Nadirlik yüzdeleri §2.3'teki ağırlıklardan hesaplandı: ılıman ve kentli bir eyalette Olağan %64,5, Dehlizci %16,1, Durgun %7,7,
Seğirtken %6,5, Gecegezer %5,2; sıcak bir eyalette Gecegezer %16,4; kırsal bir eyalette Olağan %76,9.

**Motor taklidiyle ölçülen güç** (ova, siperli piyade tümeni; aynı yöntem, §3.3):

| Tür | Tümeni kıran sürü sayısı | Bir eksiğinde tümen bütünlüğü | Arındırma süresi (1 piyade tümeni) | Garnizonu kıran |
|---|---|---|---|---|
| Olağan | 4 (52 sa) | %30 | 10 sa (kent 14) | 2 (104 sa) |
| Seğirtken | 3 (53 sa) | %70 | 7 sa | 2 (78 sa) |
| Durgun | saldırmaz | — | 18 sa (kent 29), sürü kaybı %22 | — |
| Kösemen | 3 Kösemen (73 sa); 1 Kösemen + 3 Olağan (52 sa) | 1 K + 2 O'da %16 | 13 sa | 2 |
| Kaputlu | 3 (59 sa) | %55 | 15 sa | 2 (88 sa) |
| Kışlayan (uyuşuk) | saldırmaz | — | 12 sa, tümen bütünlüğü %99 | — |
| Gecegezer | gece 3 (50 sa), gündüz 5 (105 sa) | gece %63 | 9–10 sa | gece 2 (73 sa) |
| Dehlizci | 4 (45 sa) | %22 | 15 sa (kent 24) | 2 (88 sa) |
| Sazlıkçı | 4 (52 sa); asıl farkı nehir | %12 | 10 sa | 2 |

## 5. Tablolar (sürü türleri)

Her kartta aynı satırlar vardır: dayanak, ortaya çıkış, değer gerekçesi, bulaştırma, davranış, karşı koyma, görsel, ses ve nadirlik.
Görsel ve ses dosyalarının üretim komutları §10–§11'dedir.

### T01 — Olağan Boş / Common Hollow
| | |
|---|---|
| Dayanak | Kuduzun "öfkeli" tablosu (hastaların ~%80'i): taşkınlık ve saldırganlık nöbetleri, arada durgun dönemler |
| Ortaya çıkış | Her eyalette, başlangıçtan. Temel ağırlık 100 |
| Değerler | §3.2'de türetildi |
| Bulaştırma | β ×1,0; ısırık payı 0,35 |
| Davranış | Yaşayan yoğunluğu en yüksek komşuya yürür (02 §2.4). Nehirden kaçınır (saldırı −0,6). Top sesine yönelir: topçulu bir muharebe 2 bölge içindeki sürüleri günde 0,3 olasılıkla çeker. Bu kuralın bedeli şudur: topçu çok öldürür ama daha çok sürüyü üstüne çeker |
| Karşı koyma | Siperli piyade ve topçu, nehir hattı, sayı üstünlüğü; arındırmada planlama. Kentte asker ve serum (02 §2.3) |
| Görsel | Yavaş, sürüyen adımlar; omuzlar düşük, baş öne eğik; 1930'ların yıpranmış sivil giysileri (kömür grisi, arduvaz, soluk lacivert, yulaf rengi) |
| Ses | Kalabalık nefesi, sürüme adımları, uzak mırıltı; çığlık yok |
| Nadirlik | Dünyadaki sürülerin %65–77'si |

### T02 — Seğirtken / Courser
| | |
|---|---|
| Dayanak | 1917–1928 uyku hastalığı (ensefalit letarjika) salgınında tanımlanan üç klinik biçimden biri olan **hiperkinetik** biçim: aşırı hareket ve motor taşkınlık |
| Ortaya çıkış | Temel ağırlık 10. Kızgın suş eyaletinde ×2, kışta ×0,5 (enerji harcayan tür soğukta önce ölür) |
| Değerler | PA 16/blok: temas payı 0,4 → 0,55 (mesafeyi hızla kapatır). Şok 16: ateş bölgesinde kısa süre kalır (hız 2,5 kat, şok 1,6 kat; hedef seçimi düzensiz). Savunma 10: siper arkasına bile saklanmaz. Can 20: zayıf, tükenmiş beden. Bütünlük 50: düzensiz, kalabalık tutmaz. Hız 1,5 km/sa (36 km/gün) |
| Bulaştırma | β ×1,5. Kinetik gaz modeline göre temas hızla orantılıdır ve hız 2,5 kattır; ama temasların yarısı boşa gider. Isırık payı 0,40 |
| Davranış | Kısa, hızlı dalgalar. Top sesi çekimi ×2 (günde 0,6). 42 gün ömür: kendi kendine tükenir |
| Karşı koyma | Derin savunma ve bekleme (ömrü kısadır), siper, kış. Arındırma kolaydır (7 saat); tehlikesi kordonu yarması ve sürprizdir |
| Görsel | Gömlek kollu, zayıf figürler; öne eğik koşu; adım boyu Olağan'ın 2 katı |
| Ses | Hızlı adım yağmuru, soluk soluğa nefes (1,5–2,5 Hz genlik kıpırtısı) |
| Nadirlik | %6–8; Kızgın suş bölgesinde %12–15 |

### T03 — Durgun / The Still
| | |
|---|---|
| Dayanak | Ensefalit letarjikanın **akinetik-katılık** biçimi (parkinsonizm benzeri katılık ve hareketsizlik) ve kuduzun sessiz, felçli tablosu (~%20). Bu etken "öfke" ensefaliti olduğu için pay yarıya indirildi: %10 |
| Ortaya çıkış | Temel ağırlık 12. Kent, orman ve tepe bölgelerinde ×1,5; Süreğen suşla ×2. Yürüyen sürü oluşturmaz. Eyaletteki Durgun payı × H ≥ 10.000 olursa bir **yuva** birimi doğar (hız 0) |
| Değerler | PA 8: yalnız yaklaşana ulaşır. Savunma 30: bina içinde, her köşe bir pusu. Şok 0: saldırmaz. Bütünlük 100: yerinden kıpırdamayan kalabalık çözülmez. Ömür 78 gün (FEZ 1,3) |
| Bulaştırma | β ×0,5 (hareket etmez), κ ×0,5 (bulunması zordur). Isırık payı 0,50: yakın sürpriz, el ve yüz ısırıkları |
| Davranış | **Gizli:** sayaç yalnız komşu bölgede tümen olduğunda ya da o eyalette gözetim ≥ 0,6 olduğunda görünür. Temizlendi sanılan eyalette 42 günlük "temiz ilan" sayacını sıfırlayan asıl tür budur |
| Karşı koyma | Yavaş ve planlı arındırma (hazırlık tam olmadan girilmez), sahra sağlık taraması, deri eldiven ve tozluk (ısırık payı −0,10; öneri ekipman). Kaba kuvvet işe yaramaz, sabır işe yarar |
| Görsel | Karanlık bir kapı eşiğinde ya da ağaç altında hareketsiz duran tek tük figür; yakın zoom'da yalnız siluet |
| Ses | Neredeyse sessizlik: oda gürültüsü, 6–12 saniyede bir tahta gıcırtısı, tek uzun nefes |
| Nadirlik | H'nin %8–9'u. Yuva birimi olarak kentli eyaletlerde yaygın |

### T04 — Kösemen / Bellwether (sürü önderi)
| | |
|---|---|
| Dayanak | Hayvan gruplarında toplu hareket (Couzin ve ark. 2005): grubun küçük, bilgili bir azınlığı büyük grubu yönlendirebilir; grup büyüdükçe gereken pay küçülür. Kurgu: ön beyni kısmen korunmuş bazı hastalar yön seçer, diğerleri onları izler |
| Ortaya çıkış | Dağınık H'si ≥ 50.000 olan eyalette doğan her sürü 0,04 olasılıkla Kösemen olur (yaklaşık 25 sürüde 1). Dünyada en çok 40 Kösemen olabilir; iki Kösemen arasında en az 3 eyalet bulunur |
| Değerler | Olağan bloğu ile aynıdır; yalnız şok 12, bütünlük 90 ve net hız 0,8 farklıdır. Yürüme hızı aynıdır ama yön tutarlılığı artınca net ilerleme artar (0,6 → 0,8) |
| Bulaştırma | Eyalet düzeyine etkisi yoktur; ısırık payı 0,35 |
| Davranış | **Önder etkisi:** aynı ve komşu bölgedeki `UND` birimlerinin bütünlüğü ×1,2 olur; hepsi Kösemen'in hedefine yürür ve aynı saatte saldırır. Hedef, en zayıf savunulan komşu yaşayan eyalettir: `L / (1 + savunma gücü)` en büyük olan. **Kösemen dağılırsa** bağlı birimler anında %50 bütünlük kaybeder |
| Karşı koyma | Keşif (hava keşfi ya da komşu tümen Kösemen'i tanır), topçu ve yakın hava desteğiyle yoğun saldırı. Önder düşerse çevresindekiler dağılır |
| Görsel | Kalabalığın önünde başı dik, biraz daha uzun bir figür. Sayaçta önder rozeti |
| Ses | Boğuk, yinelenen tek çağrı; ardından gecikmeli, daha kısık yanıtlar ("çağrı-yankı"). Oyuncu onu sesinden tanır |
| Nadirlik | Sürülerin ~%2'si; üst sınır 40 |

### T05 — Kaputlu / Greatcoats
| | |
|---|---|
| Dayanak | Ordu içi bulaş (02 §1.2). Genç, düzenli beslenen erkeklerin yedek yağ ve kas rezervi sivil ortalamanın üstündedir. Bu belgede %25 fazla varsayıldı. Tatbikat alışkanlığı da yürüyüş düzeninde iz bırakır |
| Ortaya çıkış | **Oyuncunun ve yapay zekânın kararıyla.** Karantinaya alınmayan tümendeki enfekte askerler E→F→H yolunu izler ve eyaletin **Kaputlu havuzuna** geçer. Kuşatılıp yok edilen enfekte tümenin enfekte askerleri de havuza eklenir. Havuz ≥ 2.000 olunca bir Kaputlu sürüsü doğar (gücü havuz/10.000, en az 0,2) |
| Değerler | PA 14 (genç ve güçlü), savunma 25 (kask, kalın kaput, teçhizat kemeri), şok 14, can 30, bütünlük 80 (yürüyüş düzeni), zırh oranı 0,10 (kask ve yün ateşin bir kısmını boşa çıkarır). Hız 0,9; yolda altyapı bonusu ×2 (kol hâlinde yürür). Ömür 75 gün |
| Bulaştırma | Isırık payı 0,35 |
| Davranış | Yol ve demiryolu boyunca yürür. Kösemen'le birlikteyken en tehlikeli ikilidir (§8) |
| Karşı koyma | Önleme: ordu içi tarama, enfekte tümeni geri çekme, askere serum önceliği. Zırhlı birlik (zırh oranı 0,45, Boş saldırısını yaklaşık yarıya indirir) |
| Görsel | Uzun yün kaputlar ve eski kasklar; **rozetsiz, bayraksız, ülke işaretsiz** genel bir haki-gri. Adımları uyumsuz ama sıralı kol düzeni |
| Ses | Tutarsız bir tempoda (dakikada ~100 adım, ±%15) ağır bot sürtünmesi, metal şıngırtısı (kask, matara), yün hışırtısı |
| Nadirlik | Sürülerin %1–3'ü; ordusunu enfekte hâlde hatta tutan ülkelerin yakınında daha çok |

### T06 — Kışlayan / Winterers
| | |
|---|---|
| Dayanak | Hipotalamus hasarında ısı düzenleme kaybı (poikilotermi): vücut ısısı çevreye uyar. Soğukta metabolizma 1 °C başına %6–7 yavaşlar (§3.4) |
| Ortaya çıkış | Soyunda "Kışlama" özelliği (§7) olan eyalette, `winter_level ≥ 0,6` iken. Ağırlık 40 |
| Değerler | **Uyuşukluk (kış):** hız 0, PA 20 (yalnız dokunanı ısırır), savunma 50, şok 0, bütünlük 100; β ×0,1. Kışta ömür 86 gün (μ ×0,7). Kış dışında Olağan gibi davranır |
| Bulaştırma | Kışta ısırık payı 0,20 (uyuşuk ama tutulunca ısırır); baharda 0,35 |
| Davranış | **Bahar Uyanışı:** `winter_level` 0'a düşünce o eyaletteki uyuşuk Boşlar 7 gün içinde uyanır ve aynı hafta içinde çok sayıda sürü doğar. Oyuncuya uyanıştan 14 gün önce olay gelir (§9.3) |
| Karşı koyma | Kış taraması: arındırma uyuşuk sürüyü 12 saatte dağıtır. Bedeli şudur: tümen kış yıpranmasına (günde −0,25%·kış) ve kış saldırı cezasına (−%15) uğrar. Seçenek ya kışın sert koşulda taramak ya da baharda uyanış dalgasını karşılamaktır |
| Görsel | Kar yığınları ve çit dibinde kıvrılmış, kırağılı figürler; kıpırtısız |
| Ses | Rüzgâr, buz çatırtısı; uyanışta damlama ve yükselen alçak uğultu |
| Nadirlik | Kışlama özelliği yoksa 0. Varsa kış eyaletlerindeki H'nin %20–30'u |

### T07 — Gecegezer / Night Hollow
| | |
|---|---|
| Dayanak | Ensefalit letarjikada **uyku döngüsünün tersine dönmesi**; bunama hastalarında akşamüstü ve akşam artan huzursuzluk ("gün batımı sendromu"). Sıcakta gündüz yürümek su kaybını çok artırır: ağır işte ter kaybı saatte 0,3–1,5 L'dir, susuz hayatta kalma ise 3–5 gündür |
| Ortaya çıkış | Temel ağırlık 8. Sıcak eyalette ×3 (çöl arazisi ya da enlem 23,5°'den küçük) |
| Değerler | Yerel saat `(GameClock.hour + round(boylam/15)) mod 24`. **Gece (19–06):** PA ×1,4, şok ×1,3, hız ×1,5. **Gündüz:** PA ×0,4, savunma ×0,8, hız ×0,3. Çölde iklim çarpanı 1,6 yerine 1,2 (sıcaktan kaçar) |
| Bulaştırma | β ×1,1 (gece baskını), κ ×0,8. Isırık payı 0,40 (karanlıkta yakın temas) |
| Davranış | Geceleri saldırır, gündüz dağınık bekler. Gece sayacı gizlidir; yalnız muharebe ya da komşuluk onu gösterir |
| Karşı koyma | Aydınlatma (ışıldak ve işaret fişeği; öneri ekipman) gece çarpanını o bölgede kaldırır. Gündüz taarruzu. Gece için siper |
| Görsel | Ay ışığında tarlayı geçen siluetler, ışıldak huzmesinde irkilen kalabalık |
| Ses | Gece böcekleri, **yaklaşınca ansızın kesilen** böcek sesi (sessizlik uyarıdır), toprakta çıplak ayak |
| Nadirlik | Ilıman bölgede %5; sıcak bölgede %16 |

### T08 — Dehlizci / Sump Hollow
| | |
|---|---|
| Dayanak | Işıktan kaçma ve karanlık arama. Toprak sıcaklığı ~10 m derinlikten sonra yıl boyu yaklaşık sabittir ve yıllık ortalama hava sıcaklığına eşittir. 1936'da kanalizasyon, maden ve metro vardı: Tokyo 1927, Moskova 1935 |
| Ortaya çıkış | Kentli (en az bir `urban` bölgesi olan) ya da madenli (çelik, tungsten, krom, alüminyum kaynağı olan) eyalette ağırlık 25; kışta ×2 (soğuktan yeraltına sığınır). Başka yerde 0. **Kazmaz**, var olan dehlizleri kullanır |
| Değerler | PA 14 (dar alanda yakın dövüş), savunma 30 (tünelde savunan üstündür), şok 8, bütünlük 80, hız 0,4. Kış iklim çarpanı yoktur. Su bulur: μ ×0,9 (67 gün) |
| Bulaştırma | β ×0,8, κ ×0,5. Isırık payı 0,45 (dar alan) |
| Davranış | **Yeraltı geçişi:** aynı eyaletteki kent ya da maden bölgeleri arasında, arada kimin kontrolü olursa olsun 1 günde geçer. Kordonu **eyalet içinde** delebilir, eyalet sınırını delemez. Gizlidir |
| Karşı koyma | İstihkâm taraması (tünelleri kapatma, su basma; öneri: eyalet altyapısı −1 bedelli karar), aydınlatma, kentte planlı arındırma (24 saat) |
| Görsel | Yuvarlak bir kanalizasyon ağzı, karanlık suda belli belirsiz şekiller, tek fener |
| Ses | Tünel yankısı (2,5 sn sönüm), su damlaları, uzaktan sürtünme |
| Nadirlik | Kentli eyaletlerde %16; dünyada ~%5 |

### T09 — Sazlıkçı / Waders
| | |
|---|---|
| Dayanak | Kuduzdaki su korkusunun (hastaların ~yarısı) bu soyda görülmemesi. Susuzluk Boş'un ölüm saatidir; suyu bulan Boş daha uzun yaşar. Tarih: gemiyle gelen salgın (1720 Marsilya, *Grand Saint-Antoine*; 1918 Batı Samoa, *Talune*) |
| Ortaya çıkış | Soyunda "Suya dayanım" özelliği (§7) olan eyalette: bataklık arazisinde, nehir kıyısında (`river_adjacent`) ya da kıyıda. Ağırlık 15 |
| Değerler | Olağan bloğu ile aynıdır; şok 12'dir (nehir ve bataklık aşar). Nehir saldırı cezası 0, bataklıkta hız ×1,0 ve saldırı 0. Ömür 75 gün (su sınırlayıcı değil; boğulma payı dahil μ ×0,8) |
| Bulaştırma | β ×0,9 (vaktinin bir kısmı suda, konaktan uzakta geçer). Liman bağlantılarında H akışı ×3: yanaşmış mavnaya ve tekneye binen Boş, 02 §2.4'teki liman-liman ağıyla taşınır |
| Davranış | Nehir hatlarını ve dar boğazları aşar; limanlardan sıçrar |
| Karşı koyma | Nehri tek başına kordon sanmamak. Nehir devriyesi (küçük donanma), liman sağlık denetimi (02 §3.4), kıyı gözetimi |
| Görsel | Sisli bir deltada beline kadar sazlık içinde yürüyen figürler |
| Ses | Su şapırtısı, saz hışırtısı |
| Nadirlik | Özellik yoksa 0; varsa uygun eyaletlerde %10 |

## 6. Suşlar (etkenin evrimi)

Suş, sürünün değil **soyun** özelliğidir. Eyaletin salgın parametrelerini değiştirir, ayrıca o eyalette doğan sürülerin
değerlerine çarpan uygular. R₀ değerleri 02 §2.3 formülüyle hesaplandı. Formül, kuluçkada bulaş (ε) ve kendiliğinden iyileşme
(p_iyi) terimleriyle genişletildi: `R₀ = ε·β·d/σ + φ·β·d/γ + (1 − p_ölüm − p_iyi)·β·d/(κ·d + μ)`.

| Soy | Değişen parametreler | R₀ (d = 0,35 / 0,64 / 1 / 1,93 / 3) | Kısa anlam |
|---|---|---|---|
| Ata suş EF-0 | — | 2,23 / 2,75 / 3,11 / 3,65 / 4,10 | 02'deki çekirdek |
| **Hırıltılı** | φ 0,15 → 0,45 | 2,45 / 3,15 / 3,74 / 4,87 / 5,99 | Ateşli hasta öksürür; yoğun şehirde en büyük sıçrama |
| **Kızgın** | σ 1/3 → 1/1,5; γ 1/7 → 1/4; β ×1,2; μ ×1,33; p_ölüm 0,15 | 2,21 / 2,81 / 3,21 / 3,76 / 4,15 | R₀ aynı kalır ama kuşak süresi 15 günden 10 güne iner: ikiye katlanma 9,3 → 6,2 gün; serum penceresi 7 → 4 gün |
| **Dirençli** | serum etkinliği ×0,5 | ata suşla aynı | Serum dozu yarı yarıya az kurtarır |
| **Soluk** | β ×0,7; φ 0,5; γ 1/10; p_iyi 0,80; p_ölüm 0,03; ömür 30 gün | 0,57 / 0,94 / 1,36 / 2,39 / 3,54 | Hafif seyirli, çoğu kendiliğinden iyileşir ve bağışık olur; ağırlıkla şehirlerde yayılır |
| **Süreğen** | μ ×0,4 (150 gün); β ×0,8 | 2,27 / 2,55 / 2,74 / 3,07 / 3,38 | Seyrek yerde ata suş kadar yayılır, uzun yaşar; beklemek işe yaramaz |
| (ek) Sessiz taşıyıcılık | ε = 0,10; σ 1/3 → 1/5 | 2,28 / 2,84 / 3,26 / 3,94 / 4,55 | Kuluçkadaki kişi de bulaştırır; yalnız hastayı ayırmak yetmez |
| (ek) Kışlama | T06 tablosunu açar | — | Kış öldürmez, uyutur |
| (ek) Suya dayanım | T09 tablosunu açar | — | Nehir engel olmaktan çıkar |
| (ek) Aşı kaçağı | aşı etkinliği 0,9 → 0,7 | — | Yalnız "Kara Yıl" zorluğunda ve özel ayarda |

### T10 — Hırıltılı suş / Rasping strain
- **Dayanak:** 1910–11 Mançurya vebası, kışın kalabalık ve kapalı mekânlarda damlacıkla yayılan akciğer vebasıydı; gazlı bez
  maske o salgında yaygınlaştı. Solunum yolu virüslerinin kışın daha iyi yayıldığı, mutlak nemin düşüşüyle açıklanır (Shaman ve Kohn 2009).
- **Çıkış ve seçilim:** kış (`winter_level ≥ 0,6`) ve yoğunluk çarpanı `d ≥ 1,5`. Kışta seçilim avantajı +0,05/gün, yazın −0,03/gün.
- **Muharebe:** ısırık payına +0,15 (yakın dövüşte damlacık). Sürü değerleri değişmez.
- **Karşı koyma:** gazlı bez maske (öneri ucuz üretim kalemi; takılıysa +0,15'in yarısı kalkar), toplu kış barınaklarını dağıtmak,
  aralıklı yataklı ayırma hastanesi.

### T11 — Kızgın suş / Fervid strain
- **Dayanak:** Ewald'ın hipotezi: 1918 grip salgınında Batı Cephesi'ndeki siperler ve kalabalık sahra hastaneleri, hareket edemeyen
  hastadan bile bulaşabilen, daha öldürücü soyları seçti. Öldürücülük ile bulaş süresi arasındaki ödünleşim (Alizon ve ark. 2009).
- **Çıkış:** hasta kalabalığı. Eyalette Ateşli sayısı hastane kapasitesinin 2 katını aşarsa, eyalette mülteci kampı varsa ya da
  ordu içi bulaşı %3'ün üstünde olan bir tümen bulunuyorsa tetiklenir. Seçilim avantajı kalabalık sürdükçe +0,04/gün, sona erince −0,01/gün.
- **Sürü:** PA ×1,15, bütünlük ×0,9; Seğirtken ağırlığı ×2.
- **Karşı koyma:** hastane kapasitesi ve hastaları dağıtma, hızlı serum lojistiği (pencere 4 gün), sıkı kordon. Kısa ömürlü olduğu
  için kordonla kendi kendine söner.

### T12 — Dirençli suş / Refractory strain
- **Dayanak:** Tam koruma sağlamayan ("sızdıran") aşılar ve tedaviler, konağı yaşatıp bulaşı sürdürdüğünde daha ağır soyların
  ayakta kalmasına yol açabilir (Gandon ve ark. 2001; Read ve ark. 2015, Marek hastalığı). Direncin çoğunlukla bir büyüme bedeli
  vardır (Andersson ve Hughes 2010).
- **Çıkış:** "Yarım doz serum" kararı ya da Ateşli hastaların %20–60'ının 60 günden uzun süre eksik dozla tedavi edilmesi.
  Yarım doz hastayı kurtarmaz; Ateşli evreyi uzatır (γ ×0,7) ve bulaş sürer. Seçilim avantajı `+0,08 × eksik serum kapsamı`,
  serum kullanılmayan yerde −0,005/gün (direncin bedeli).
- **Karşı koyma:** tam doz ve tipe özgü serum ("Serum II", öneri kimlik). 1930'larda pnömoni tedavisinde tipe özgü serumlar
  kullanılıyordu; bu, direnç karşısında gerçekçi bir yanıttır.

### T13 — Soluk suş / Pale strain
- **Dayanak:** Canlı zayıflatılmış aşıların tarihi: Pasteur 1885'te kuduz etkenini kurutulmuş tavşan omuriliğinde zayıflattı;
  17D sarı humma aşısı 1930'larda fare ve tavuk dokusunda 176 seri pasajla elde edildi. Hafif hastalıkla bağışıklık kazandırma
  pratiği (variolasyon) 1717'de İstanbul'da gözlemlenip Avrupa'ya taşındı. Variolasyon yapılanların %1–2'si ölürken doğal çiçekte
  ölüm oranı ~%30'du.
- **Çıkış:** yalnız oyuncunun (ya da yapay zekânın) seçimiyle. "Seri pasaj" araştırma yöntemi seçilmişse, o araştırma merkezinde
  çıkan laboratuvar kazasında sızan soyun Soluk olma olasılığı %50'dir. Kaza olasılığı araştırma belgesinde yazılacak.
- **Etki:** Soluk suşla enfekte olanların %80'i kendiliğinden iyileşir (R, bütün soylara bağışık), %3'ü ölür, %17'si kısa ömürlü
  zayıf Boş olur. Sürü: PA ×0,7, can ×0,8. Yoğun şehirde yayılır (R₀ 2,4–3,5), kırsalda söner (R₀ < 1).
- **Karar:** §9.2'deki olay. Soluk suş "iyi haber" değildir, bedelli bir fırsattır.

### T14 — Süreğen suş / Chronic strain
- **Dayanak:** Konak bulmak zorlaştığında seçilim, bulaş süresi uzun soyları kayırır. Buna "otur ve bekle" hipotezi (Walther ve
  Ewald 2004) ve öldürücülük-süre ödünleşimi (Alizon ve ark. 2009) denir.
- **Çıkış:** evre ≥ Çöküş olmalı ve eyalette `S/N⁰ < 0,5` olmalı (çok kayıp, çok aşı ya da uzun süre sıkı kordonla yalıtılmış Boşlar).
  Seçilim avantajı `0,03 × (1 − S/N⁰) − 0,01` gün⁻¹; S payı %67'nin altına inince pozitife döner.
- **Sürü:** PA ×0,9, bütünlük ×1,1; Durgun ağırlığı ×2. Ömür 150 gün.
- **Karşı koyma:** etkin arındırma (beklemek işe yaramaz), aşı (Süreğen de S'ye muhtaçtır). Arındırma Zaferi'nin 180 günlük koşulunu
  en çok zorlayan soydur.

## 7. Evrim ağacı

### 7.1 Yapı
```
                                      ┌─ Hırıltılı ────── (+ Sessiz taşıyıcılık)
                 bulaş yolu ──────────┤
                                      └─ Sessiz taşıyıcılık
                                      ┌─ Kızgın  ─┐
 [Ata suş EF-0] ─ öldürücülük ekseni ─┼─ Süreğen ─┼─ (birbirini dışlar: bir soyda en çok biri)
                                      └─ Soluk   ─┘  (yalnız laboratuvardan)
                 tedaviye yanıt ──────┬─ Dirençli
                                      └─ Aşı kaçağı (Kara Yıl)
                 çevreye uyum ────────┬─ Kışlama     → T06 Kışlayan
                                      └─ Suya dayanım → T09 Sazlıkçı
```
- Bir soy en çok **3 özellik** taşır. Dünyada aynı anda en çok **6 soy**, bir eyalette en çok **3 soy** bulunur.
  Gerekçe: 1.652 × 3 pay kayda ve hesaba küçük bir yük getirir; 6 soy panelde tek tabloya sığar.
- Yeni özellik, kaynak eyaletteki **baskın soya** eklenir. Yeni soy o eyalete %1 payla girer.
- Örnek soy adı: "EF-2 (Hırıltılı, Kışlama)". Sıra numarası doğuş sırasıdır. Oyunda ad `STRAIN_NAME` biçim anahtarıyla kurulur.

### 7.2 Ortaya çıkış formülü
Mutasyonun tek tek genetik hesabı yapılmaz. RNA virüslerinde mutasyon hızı hücre enfeksiyonu başına nükleotit başına 10⁻⁶–10⁻⁴'tür
(Sanjuán ve ark. 2010). Yani her enfeksiyon değişik kopyalar üretir; seyrek olan, **işe yarayan** ve **tutunan** değişikliktir.
Bu yüzden ortaya çıkış tek bir sabitle, enfeksiyon sayısına orantılı bir olasılık olarak modellenir:

```
λ_X(t) = k_X · Σ_s c_X(s,t) · yeniE_s(t) / 1.000        (gün⁻¹)
P(X bugün çıkar) = 1 − exp(−λ_X(t))                   (tohumlu RNG → belirlenimci; 02 §8 kontrol 9)
```
`c_X` tetik yoğunluğudur (0–1). `k_X` şu hedeften geri hesaplandı: "tipik tetik yoğunluğunda (I, bin yeni enfeksiyon/gün)
ortalama bekleme T gün" → `k = 1/(I·T)`. Ölçek için tek eyalet çözümü: 1 milyonluk bir eyalette günlük yeni enfeksiyon d = 0,64'te
~19 bin, d = 3'te ~48 bin ile tepe yapar (02 §2.2 denklemleri, önlemsiz).

| Özellik | Tetik `c_X(s)` (oyuncu seçimi kalın) | I (bin/gün) | T (gün) | k_X | 90 günde | 180 günde | Denge hedefi (6 koşu) |
|---|---|---|---|---|---|---|---|
| Hırıltılı | kış ≥ 0,6 ve d ≥ 1,5; **toplu kış barınağı** varsa ×2 | 100 | 180 | 5,6·10⁻⁵ | %39 | %63 | 3–5 |
| Kışlama | kış ≥ 0,6 | 150 | 90 | 7,4·10⁻⁵ | %63 | %86 | 4–6 |
| Kızgın | **hastane taşması**, **mülteci kampı**, **enfekte tümeni hatta tutmak** | 50 | 120 | 1,7·10⁻⁴ | %53 | %78 | 2–4 |
| Dirençli | **yarım doz serum** (1,0) ya da eksik kapsam (0,5); serum yoksa 0 | 20 | 60 | 8,3·10⁻⁴ | %78 | %95 | 0–3 |
| Süreğen | evre ≥ 3 ve S/N⁰ < 0,5; **uzun sıkı kordon** ×1,5 | 30 | 150 | 2,2·10⁻⁴ | %45 | %70 | 2–4 |
| Sessiz taşıyıcılık | **zorunlu karantina** ve tespit ≥ 0,5 (yalnız hastayı ayırma) | 40 | 200 | 1,3·10⁻⁴ | %36 | %59 | 1–3 |
| Suya dayanım | cephesi nehir olan kordon payı (**nehre dayalı kordon**) | 20 | 150 | 3,3·10⁻⁴ | %45 | %70 | 1–3 |
| Soluk | olasılık yok; **seri pasaj** + kaza olayı | — | — | — | — | — | 0–1 |
| Aşı kaçağı | V/N⁰ ≥ 0,5, 120 gün; yalnız Kara Yıl | 50 | 300 | 6,7·10⁻⁵ | %26 | %45 | 0 (varsayılan kapalı) |

**Sessiz taşıyıcılık için dayanak:** Evrimsel epidemiyoloji, yalnız belirti gösterenleri ayıran önlemlerin belirti öncesi dönemi
uzun soyları kayırabileceğini öngörür (Day ve ark. 2020). Karantina kötü bir seçim değildir; kısa vadede R'yi düşürür. Yalnız
uzun vadede "temaslı takibi" gibi ikinci bir önlem ister.

### 7.3 Eyaletler arası yarış
Her eyalette soy payları, popülasyon genetiğinin iki tipli seçilim denklemiyle değişir. Bu denklem evrimsel epidemiyolojide
kullanılır (Day ve Gandon 2007):
```
Δp_i = p_i · (s_i(koşul) − s̄) · Δt          s̄ = Σ p_j · s_j
```
Payların toplamı 1'de tutulur. Yolcu akışı ve sürü yürüyüşü, taşıdıkları enfekte kişi sayısıyla orantılı olarak soy payı da
taşır. Payı 0,005'in altına düşen soy o eyaletten silinir.

**Zaman ölçeği:** %1'den %50'ye çıkış süresi `ln(99)/s`'dir: s = 0,03 → 153 gün, s = 0,05 → 92 gün, s = 0,08 → 57 gün.
Yani bir özellik bir mevsim içinde baskın olur. Mevsim dönünce (ör. Hırıltılı'da yaz −0,03) geriler. Böylece "suş mevsimi"
gerçekçi biçimde gelir gider.

### 7.4 Keşif (bilgi sisi, 01 Sütun 2)
| Yol | Koşul | Gecikme |
|---|---|---|
| Uluslararası bülten | Soyun payı ≥ 0,25 olan en az 3 eyalet ve o eyaletlerde tespit ≥ %30 | 14 gün sonra cuma bülteninde |
| Kendi numunen | Araştırma merkezi, payı ≥ 0,10 olan eyaletten numune işler ("suş tipleme", öneri kimlik) | Numune işleme süresi |
| Muharebe | Tablo türleri, ilk muharebede ya da komşu tümenin keşfiyle tanınır; o zamana kadar sayaç "Tanımlanmamış sürü"dür | Anında |

Keşfedilmemiş soyun etkisi yine vardır, ama panel bunu "beklenmeyen hız" diye gösterir: bildirilen artış ile model tahmini
ayrışır. Oyuncu sebebini bilmez.

### 7.5 Seçim → sonuç tablosu (ipucunda yazar)
| Oyuncu seçimi | Kazanç | Beslediği özellik | Gerçek alternatif |
|---|---|---|---|
| Yarım doz serum | Anında 2 kat kapsam | Dirençli | Tam doz + üretim artışı (fabrika bedeli) |
| Kalabalık sahra hastanesi / mülteci kampı | Kısa vadeli kapasite | Kızgın | Hastaları dağıtmak (tahliye bedeli) |
| Enfekte tümeni hatta tutmak | Cephe tutulur | Kızgın, Kaputlu | Geri çekip karantinaya almak (cephe açığı) |
| Zorunlu karantina (yalnız hasta) | Bulaş −%35 | Sessiz taşıyıcılık | Temaslı takibi eklemek (nüfuz, gözetim yatırımı) |
| Nehre dayalı kordon | Ucuz kordon (Boş nehirde −0,6) | Suya dayanım | Asker yoğun kara kordonu |
| Seri pasaj araştırması | Aşı maliyeti −%20 (öneri) | Soluk (kazada) | Klasik yöntem (daha yavaş, kaza bedelsiz) |
| Toplu kış barınakları | Kışta sivil ölümü azalır | Hırıltılı | Dağınık barınma (yakıt ve inşaat bedeli) |
| Uzun sıkı kordon, arındırmasız bekleme | Az asker kaybı | Süreğen | Etkin arındırma (ordu içi bulaş riski) |

## 8. Tür etkileşimleri

| Birlikte | Sonuç | Karşı koyma |
|---|---|---|
| Kösemen + Olağan | Bütünlük ×1,2, eşzamanlı saldırı: 1 Kösemen + 3 Olağan siperli tümeni 52 saatte kırar | Önce Kösemen'i vur |
| Kösemen + Kaputlu | Yol boyunca kol hâlinde, hızlı ve sıkı yürüyüş: 1 K + 2 Kaputlu tümeni 63 saatte kırar. En tehlikeli ikili | Yol kavşaklarında zırhlı yedek |
| Kösemen + Seğirtken | Hızlı baskın dalgası; Seğirtken ömrü kısa olduğu için 2–3 haftalık bir tehdit | Zaman kazan, derin savunma |
| Kızgın suş + Seğirtken | Seğirtken payı ×2, kuşak 10 gün: yazın patlayan kent salgını | Hastane kapasitesi, serum hızı |
| Hırıltılı + Durgun | Görünmeyen yuvalar çevresinde damlacıkla bulaş; "temiz" eyalet tekrar tutuşur | Maske + planlı tarama |
| Hırıltılı + Kızgın | En kötü soy (Kara Yıl'da beklenir): R₀ yüksek, kuşak kısa | Maske + kapasite + kordon birlikte |
| Kışlayan + Dehlizci | Yeraltında kış uykusu: kış hiçbirini öldürmez | Kış taraması yeraltına işlemez; istihkâm taraması gerekir |
| Gecegezer + Dehlizci | Gündüz yeraltında, gece yüzeyde: hiç görülmeyen sürü | Aydınlatma + gözetim ≥ 0,6 |
| Sazlıkçı + liman | Liman-liman sıçrama ×3; ada ülkesinin kalkanı delinir | Liman sağlık denetimi, donanma devriyesi |
| Sazlıkçı + nehir kordonu | Nehir kordonu işe yaramaz; zaten bu seçim Sazlıkçı'yı doğurur | Kara kordonuna geçiş |
| Soluk ↔ öteki soylar | Soluk ile iyileşen (R) bütün soylara bağışıktır; öteki soylar için S'yi azaltır | Soluk'u tutmak ya da kullanmak (§9.2) |
| Süreğen + Durgun | Durgun ×2 ve 150 gün ömür: uzun süren "ölü bölgeler" | Etkin arındırma + aşı |
| Dirençli ↔ serum | Dirençli yalnız serum kullanılan yerde üstün, başka yerde bedel öder | Tam doz, Serum II, serumu doğru yere vermek |
| Kızgın ↔ Süreğen | Aynı soyda birlikte olamaz; aynı eyalette yarışır. Kalabalık Kızgın'ı, konak azlığı Süreğen'i kayırır | Koşulu değiştirmek soyu değiştirir |
| Seğirtken ↔ kış | Seğirtken ağırlığı ×0,5, ömrü de kısalır | Kış müttefiktir |
| Top sesi ↔ bütün sürüler | Topçulu muharebe 2 bölge içindeki sürüleri çeker (Seğirtken ×2) | Topçuyu hat gerisinde tut, kısa ateş |

## 9. Oyun içi metin önerileri (EN / TR)

### 9.1 Adlar ve ipuçları
| Anahtar | EN | TR |
|---|---|---|
| `ZM_TYPE_COMMON` | Common Hollow — slow, tireless, shuns water. | Olağan Boş — yavaş, yorulmaz, sudan kaçar. |
| `ZM_TYPE_COURSER` | Courser — fast and restless; burns out within weeks. | Seğirtken — hızlı ve huzursuz; birkaç haftada tükenir. |
| `ZM_TYPE_STILL` | The Still — motionless in dark rooms; strikes whoever comes close. | Durgun — karanlık odalarda kıpırtısız; yaklaşanı ısırır. |
| `ZM_TYPE_BELLWETHER` | Bellwether — the others follow it. Break it and the crowd scatters. | Kösemen — ötekiler onu izler. Onu dağıtırsan kalabalık çözülür. |
| `ZM_TYPE_GREATCOATS` | Greatcoats — once soldiers. Steady on the road, hard to stop. | Kaputlu — bir zamanlar askerdiler. Yolda düzenli, durdurması güç. |
| `ZM_TYPE_WINTERERS` | Winterers — asleep under the snow until the thaw. | Kışlayan — bahar gelene kadar kar altında uyur. |
| `ZM_TYPE_NIGHT` | Night Hollow — still by day, moving by night. | Gecegezer — gündüz durgun, gece yolda. |
| `ZM_TYPE_SUMP` | Sump Hollow — in sewers, mines and tunnels. | Dehlizci — lağımda, madende, tünelde. |
| `ZM_TYPE_WADERS` | Waders — rivers do not stop them. | Sazlıkçı — nehir onları durdurmaz. |
| `ZM_TYPE_UNKNOWN` | Unidentified horde | Tanımlanmamış sürü |
| `ZM_STRAIN_RASPING` | Rasping strain — the fevered cough; spreads in crowded winter rooms. | Hırıltılı suş — ateşli hasta öksürür; kalabalık kış odalarında yayılır. |
| `ZM_STRAIN_FERVID` | Fervid strain — faster from bite to fever; the serum window is four days. | Kızgın suş — ısırıktan ateşe daha hızlı; serum penceresi dört gün. |
| `ZM_STRAIN_REFRACTORY` | Refractory strain — half-doses no longer work. | Dirençli suş — yarım doz artık işe yaramıyor. |
| `ZM_STRAIN_PALE` | Pale strain — mild; most recover and are immune. | Soluk suş — hafif seyirli; çoğu iyileşir ve bağışık olur. |
| `ZM_STRAIN_CHRONIC` | Chronic strain — the Hollow live for months. Waiting will not end it. | Süreğen suş — Boşlar aylarca yaşıyor. Beklemek bitirmez. |
| `ZM_TIP_CHOICE_FEEDS` | This choice favours the %s. | Bu seçim %s özelliğini kayırır. |

### 9.2 Olay: "Soluk Suş" / "The Pale Strain"
> EN: *"The institute reports that a weakened culture used for serial passage has escaped the laboratory. Staff who fell ill are
> recovering; none has turned. The director asks for instructions."*
> TR: *"Enstitü, seri pasajda kullanılan zayıflatılmış bir kültürün laboratuvardan sızdığını bildiriyor. Hastalanan personel
> iyileşiyor; hiçbiri Boş'a dönmedi. Müdür talimat bekliyor."*

| Seçenek (EN / TR) | Etki | Bedel |
|---|---|---|
| Seal the district / Semti kapat | Soluk soy o eyalette ×0,1 seçilim (60 gün); söner | Araştırma merkezi 60 gün kapalı; istikrar −%2 |
| Observe and report / Gözle ve bildir | Doğal yayılım; bülten bütün dünyaya bildirir (uluslararası itibar +) | Kırsalda söner, şehirde yayılır; ölümler %3, zayıf Boşlar %17 |
| Voluntary inoculation programme / Gönüllü aşılama programı | Seçilen eyaletlerde gönüllü S'nin günde %0,3'ü Soluk'la aşılanır (%80 bağışık) | Gönüllülerin %3'ü ölür, %17'si zayıf Boş olur; istikrar −%5; nüfuz −100. Seçenek yalnız etken tanımlandıktan sonra açılır |

### 9.3 Olay: "Bahar Uyanışı" / "The Thaw"
> EN: *"Field reports from the northern provinces: under the snow, the sick are not dead. Surgeons expect them to wake when the
> ground softens."* TR: *"Kuzey illerinden rapor: kar altındaki hastalar ölmemiş. Hekimler toprak yumuşayınca uyanacaklarını bekliyor."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Winter sweep / Kış taraması | Uyuşuk sürülere karşı saldırı +%50 (30 gün) | Kış yıpranması ×1,5; ordu içi bulaş riski |
| Evacuate the thaw zone / Uyanış bölgesini boşalt | Uyanış bölgesindeki S'nin %30'u komşu eyaletlere taşınır | Fabrika çıktısı −%10 o eyaletlerde (90 gün); istikrar −%3 |
| Hold the line for spring / Bahara kadar hattı tut | — | Uyanış dalgası tam güçle gelir |

### 9.4 Olay: "Kaputlular" / "Men in Greatcoats" (ilk Kaputlu sürüsü kendi askerinden doğunca)
| Seçenek | Etki | Bedel |
|---|---|---|
| Screen every unit / Her birliği tara | Bütün tümenlerde ordu içi bulaş sıfırlanır | Tümenlerin bütünlüğü −%10 (14 gün); nüfuz −50 |
| Pull infected divisions back / Enfekte tümenleri geri çek | Ordu içi bulaşı %1'in üstündeki tümenler karantinaya çekilir | Cephede açık; iç cephe −%3 |
| Keep it quiet / Sessiz kal | Bedel yok | Kaputlu havuzu büyümeye devam eder; haber 60 gün içinde sızarsa iç cephe −%10 |

### 9.5 Bülten satırları (ilk keşifte)
| Özellik | EN | TR |
|---|---|---|
| Hırıltılı | Reports from crowded winter quarters describe patients who cough before they turn. | Kalabalık kış barınaklarından gelen raporlar, dönüşmeden önce öksüren hastalardan söz ediyor. |
| Kızgın | Clinicians in overcrowded wards report fever within a day of the bite. | Taşmış koğuşlardaki hekimler ısırıktan bir gün sonra ateş bildiriyor. |
| Dirençli | Several institutes report that reduced serum doses no longer halt the fever. | Birkaç enstitü, azaltılmış serum dozunun ateşi artık durdurmadığını bildiriyor. |
| Süreğen | Hollow seen in spring have been observed again in autumn in the same villages. | İlkbaharda görülen Boşlar sonbaharda aynı köylerde yeniden görüldü. |
| Kışlama | Patrols report motionless sick under snow, alive and cold to the touch. | Devriyeler kar altında kıpırtısız, soğuk ama canlı hastalar bildiriyor. |
| Suya dayanım | River pickets report the sick wading across at night. | Nehir karakolları hastaların gece sudan yürüyerek geçtiğini bildiriyor. |
| Sessiz taşıyıcılık | Contacts without fever are falling ill after release from quarantine. | Karantinadan ateşsiz çıkan temaslılar sonradan hastalanıyor. |

Yeni etkiler (`strain_fitness`, `serum_dose_policy`, `inranks_screen`, `pale_inoculation`, `torpid_attack_bonus`),
`Politics.apply_effects` ve `describe_effects` sözlüklerine birlikte eklenir (CLAUDE.md kural 2).

## 10. Görsel varlıklar (liste ve üretim komutları)

CLAUDE.md kural 5 ve 6 gereği: dosya üretilmez ve render/shader/ışık değiştirilmez. Aşağıdaki liste kullanıcının üreteceği
dosyalar içindir. Model ve animasyon parametreleri insan gözüyle masaüstünde (Forward+) ve web'de (gl_compatibility) doğrulanır.

### 10.1 3D figürler (`assets/models/hollow_units.glb`, mesh adları `hol_*`)
Mevcut figür sistemi (`unit_models.gd`: MultiMesh, rol öneki ölçeği, kodla yürütülen adım) yeniden kullanılır. Yapılacak ek:
`ROLE_SCALE`'e `"hol": 2.6` ve tür başına yürüyüş parametreleri.

| Mesh | Üçgen bütçesi | Varyant | Yürüyüş (adım boyu / en yüksek hız / sallanma) | Tarif |
|---|---|---|---|---|
| `hol_common_a/b/c` | ≤ 1.200 | 3 (erkek, kadın, yaşlı; **çocuk yok**) | 0,7 / 2,0 / belirgin | Yıpranmış 1930'lar sivil giysisi, eğik baş, sarkık kollar |
| `hol_courser_a/b` | ≤ 1.200 | 2 | 1,4 / 8,0 / az | Gömlek kollu, öne eğik koşu duruşu |
| `hol_still_a/b` | ≤ 900 | 2 | 0 / 0 / yok | Ayakta hareketsiz, kollar yanda; biri duvara yaslı |
| `hol_bellwether` | ≤ 1.400 | 1 | 0,8 / 2,4 / az | Başı dik, biraz uzun; paltolu |
| `hol_greatcoat_a/b` | ≤ 1.400 | 2 | 0,8 / 2,6 / düzenli | Rozetsiz uzun kaput, eski kask; hiçbir ülke işareti yok |
| `hol_winter` | ≤ 900 | 1 | 0 / 0 (kış) | Kıvrılmış, kırağılı |
| `hol_wader` | ≤ 1.200 | 1 | 0,6 / 1,8 / belirgin | Belden aşağısı ıslak (koyu doku), sazlık lekesi |

Ortak kurallar: tek malzeme, köşe rengi. Ten tonları çeşitlidir ve **hepsinin üstüne aynı gri solgunluk katmanı** uygulanır:
"gri hastalık" bir belirti olarak gösterilir, hiçbir ten rengiyle ilişkilendirilmez. Kan, yara ve uzuv kaybı yoktur. Dehlizci ve
Gecegezer ayrı model istemez; Olağan modeli koyu ton ve gece kullanımıyla yeterlidir (bütçe: ~10 model, 01 §3a ile uyumlu).

### 10.2 İkonlar (`assets/ui/icons_new/`)
Ortak stil cümlesi (tools/make_icon_prompts.py'deki yapıya uyar):
```
STYLE_ZM_ICON = "Hand-painted icon for a 1930s alternate-history epidemic grand strategy game, in the manner of a 1930s
public-health poster and a field-manual engraving, muted slate-grey, ash, faded ochre and dull teal palette with one warm
accent, strong readable silhouette centered, figures faceless or turned away, no blood, no gore, no wounds, no children,
no religious symbols, no national insignia, transparent background, no text, no letters, no numbers, no border, square 1:1, 512x512"
STYLE_ZM_STRAIN = "Scientific plate illustration in the manner of a 1930s bacteriology textbook, glassware on a plain
laboratory bench, sepia ink lines with muted watercolour wash, centered, transparent background, no text, no letters,
no numbers, no border, square 1:1, 512x512"
```
| Dosya | Konu (prompt'un başı; sonuna stil cümlesi eklenir) |
|---|---|
| `zm_type_common.png` | a loose crowd of five gaunt adults in worn 1930s civilian coats shuffling forward with heads bowed, seen from a distance in grey fog |
| `zm_type_courser.png` | two lean figures in shirtsleeves running forward, motion blur, across a muddy field |
| `zm_type_still.png` | a single silhouette standing motionless in the dark doorway of a tenement |
| `zm_type_bellwether.png` | a crowd of silhouettes following one taller figure at the front whose head is raised, like a flock behind its leader |
| `zm_type_greatcoats.png` | a column of figures in long plain wool greatcoats and battered helmets walking out of step along a country road |
| `zm_type_winterers.png` | figures curled motionless under snowdrifts beside a frozen fence, frost on their coats |
| `zm_type_night.png` | silhouettes crossing a moonlit field caught in a single searchlight beam |
| `zm_type_sump.png` | the round mouth of a brick sewer tunnel, dim shapes in dark water, one hanging lantern |
| `zm_type_waders.png` | figures wading waist-deep through tall reeds in a misty river delta |
| `zm_type_unknown.png` | a blurred crowd silhouette behind a question-shaped wisp of fog (no letters) |
| `zm_strain_rasping.png` | a gauze face mask beside a petri dish with a faint spreading mist pattern (STYLE_ZM_STRAIN) |
| `zm_strain_fervid.png` | a clinical thermometer in the red zone over a petri dish with a dense, fast-growing colony (STYLE_ZM_STRAIN) |
| `zm_strain_refractory.png` | a cracked serum ampoule beside an untouched colony (STYLE_ZM_STRAIN) |
| `zm_strain_pale.png` | a nearly clear petri dish with a pale, faded colony and a small flask (STYLE_ZM_STRAIN) |
| `zm_strain_chronic.png` | a brass hourglass beside a slow, ring-shaped colony (STYLE_ZM_STRAIN) |
| `zm_strain_silent.png` | a railway ticket and a thermometer showing normal temperature beside a microscope slide (STYLE_ZM_STRAIN) |
| `zm_strain_winter.png` | a petri dish rimmed with frost crystals (STYLE_ZM_STRAIN) |
| `zm_strain_wader.png` | a petri dish resting on a river chart with blue waterways (STYLE_ZM_STRAIN) |
| `zm_strain_escape.png` | a vaccine vial with a hairline crack (STYLE_ZM_STRAIN) |
| `zm_badge_leader.png` | a small brass shepherd's bell, symbol of a leader (STYLE_SMALL) |

Sayaçta tür rozeti mevcut ikon mekanizmasıyla gösterilir; yeni sayaç stili yoktur.

### 10.3 Olay resimleri (8:3, `STYLE_EVENT` yapısında; mod tonu için ek: "no gore, no children, figures at a distance")
| Dosya | Konu |
|---|---|
| `event_zm_pale_strain.png` | a 1930s laboratory corridor at night, an open door, a nurse in a gauze mask reading a report under a desk lamp |
| `event_zm_thaw.png` | a northern village in early spring, melting snow on fields, dark still shapes in the snow at the edge of a birch wood |
| `event_zm_greatcoats.png` | a rainy crossroads, a column of figures in plain greatcoats seen from far behind a checkpoint barrier |
| `event_zm_coughing_wards.png` | a crowded winter hall of camp beds, stoves, gauze masks hanging on a line, soft window light |

## 11. Ses varlıkları (liste, prosedürel tarif, üretim komutu)

`tools/make_audio.py` telifli örnek kullanmaz; sesleri numpy ile sentezler (`noise`, `band`, `env`, `tone`). Aşağıdaki tarifler
aynı yaklaşıma uyar (Farnell'in prosedürel ses yöntemi ve Roads'un granüler sentezi). Hiçbirinde çığlık, çiğneme ya da yırtılma
sesi yoktur; korku ritimden ve sessizlikten gelir (01 §6.1). Dosya yolu `assets/audio/zm_*.wav`, mono, 44,1 kHz.

| Dosya | Süre | Prosedürel tarif | Üretim komutu (EN, ses üreticisi için) |
|---|---|---|---|
| `zm_horde_common_loop` | 8 sn döngü | (1) Nefes: pembe gürültü, 180–700 Hz bant, 12 ses, her biri 0,25–0,4 Hz rastgele fazlı genlik zarfı, 300 ve 900 Hz'de hafif formant; (2) sürüme: 40 ms gürültü taneleri, 300–2.500 Hz, saniyede 6–10, ±6 dB; (3) 80–160 Hz sinüs kümesi, 0,5–2 Hz vuruşlu | "distant slow crowd of tired people shuffling on gravel, heavy breathing, low murmur, no screams, no words, eerie calm, loopable" |
| `zm_courser_loop` | 4 sn | Tane hızı saniyede 18–25; 400–1.500 Hz nefes, 1,5–2,5 Hz genlik kıpırtısı; ara ara keskin soluk (80 ms, 2 kHz) | "fast uneven running footsteps on dirt, panting, no voices, loopable" |
| `zm_still_amb` | 12 sn | Oda gürültüsü (−40 dB), 6–12 sn'de bir tahta gıcırtısı (rezonans 450 Hz, 300 ms), tek uzun nefes | "silent dark room tone, an old floorboard creaks once, a single slow exhale" |
| `zm_bellwether_call` | 1,2 sn + yanıtlar | 60–80 Hz darbe dizisi (boğuk ses), 500/1.500 Hz formant süzgeci; 0,3–1,0 sn gecikmeli, −10 dB, alçak geçiren 3–5 kopya | "a single hoarse low call from a crowd, answered by fainter echoing calls, no words" |
| `zm_greatcoat_loop` | 6 sn | Dakikada ~100 adım ±%15, ağır bot sürtünmesi (150–1.200 Hz); 2,1 / 3,7 / 5,3 kHz uyumsuz kısmi tonlu metal şıngırtısı (80 ms sönüm); yün hışırtısı (4–8 kHz) | "out-of-step marching boots on a wet road, loose helmets and tin canteens clinking, no voices" |
| `zm_winter_amb` / `zm_thaw_sting` | 10 sn / 3 sn | Rüzgâr (400 Hz alçak geçiren, yavaş genlik); buz çatırtısı (geniş bantlı tık + 1,2 kHz rezonans kuyruğu). Uyanış: damlalar (1,5–3 kHz sinüs, 60 ms, saniyede 3), yükselen 55→80 Hz uğultu | "winter wind over snow, ice cracking" / "melting snow dripping, a low swelling drone" |
| `zm_night_amb` | 10 sn | Gece böcekleri (4–5 kHz, 15–30 Hz darbe); tetiklenince 0,3 sn'de sus; çıplak ayak (alçak geçiren tane) | "night crickets that suddenly fall silent, soft bare footsteps on earth" |
| `zm_sump_amb` | 10 sn | Yapay dürtü yanıtıyla evrişim (üstel 2,5 sn sönüm, 200–3.000 Hz); damlalar; uzak sürtünme (200→600 Hz bant süpürme) | "echoing brick sewer tunnel, dripping water, faint distant scraping" |
| `zm_wader_amb` | 8 sn | Su şapırtısı (200–900 Hz gürültü, 0,8–1,2 Hz genlik); saz hışırtısı (2–6 kHz tane) | "wading through shallow water and reeds, slow splashes, no voices" |
| `zm_strain_sting` | 3 sn | Telgraf tıkırtısı (1 kHz sinüs; 60 ms kısa, 180 ms uzun darbe) + testere dişi 110 Hz, 800 Hz alçak geçiren, yavaş titreşim | "telegraph key clicking over a low sustained cello-like tone, ominous, short" |
| `zm_rasp_sting` | 0,8 sn | 1–3 kHz gürültü, 12–18 Hz genlik kıpırtısı; 0,15 sn kısa öksürük darbesi | "a dry raspy cough in a large hall, single, restrained" |
| `zm_breach_alert` | 1,5 sn | Mevcut `alert` motifinin alçak, iki notalı çeşitlemesi + kısa davul | "short low two-note alarm with a muffled drum" |

## 12. Veri: JSON şema örneği

Öneri dosyalar: `data/modes/zombie/hollow_types.json` ve `data/modes/zombie/strains.json`. Kesin yerleşim, mod altyapısı belgesinde
(`docs/modlar/README.md`) yazılacak. Kimlikler (`zm_gauze_masks`, `zm_strain_typing` vb.) öneridir; araştırma belgesinde kesinleşir.

```json
{
  "_comment": "Boş tabloları. Blok = 1.000 Boş, units.json tabur biçimi; sürü = 10 blok. Gerekçeler: docs/modlar/zombi/04_zombi_turleri.md §3-§5. Değerler motor taklidiyle doğrulandı (§3.3).",
  "block_size": 1000,
  "blocks_per_horde": 10,
  "und_rules": {
    "disperse_below_org": 0.12,
    "gain_xp": false,
    "needs_supply": false,
    "terrain_attack": {"plains": 0.0, "forest": -0.05, "hills": -0.10, "mountain": -0.30, "marsh": -0.40, "desert": 0.0, "urban": 0.0},
    "river_attack": -0.6,
    "noise_pull": {"radius": 2, "daily_chance": 0.3},
    "night_hours": [19, 6]
  },
  "blocks": {
    "hollow_common": {"name": {"en": "Hollow (1,000)", "tr": "Boş (1.000)"}, "category": "hollow",
      "soft": 12, "hard": 0.5, "defense": 15, "breakthrough": 10, "hp": 25, "org": 70, "width": 4,
      "speed": 0.6, "hardness": 0.0, "armor": 0, "piercing": 0, "manpower": 0, "equipment": {}},
    "hollow_courser": {"name": {"en": "Coursers (1,000)", "tr": "Seğirtken (1.000)"}, "category": "hollow",
      "soft": 16, "hard": 0.5, "defense": 10, "breakthrough": 16, "hp": 20, "org": 50, "width": 4,
      "speed": 1.5, "hardness": 0.0, "armor": 0, "piercing": 0, "manpower": 0, "equipment": {}},
    "hollow_greatcoat": {"name": {"en": "Greatcoats (1,000)", "tr": "Kaputlu (1.000)"}, "category": "hollow",
      "soft": 14, "hard": 0.5, "defense": 25, "breakthrough": 14, "hp": 30, "org": 80, "width": 4,
      "speed": 0.9, "hardness": 0.10, "armor": 0, "piercing": 0, "manpower": 0, "equipment": {}}
  },
  "types": {
    "common": {
      "name": {"en": "Common Hollow", "tr": "Olağan Boş"},
      "kind": "presentation",
      "block": "hollow_common",
      "spawn": {"weight": 100},
      "disease": {"beta_mult": 1.0, "kappa_mult": 1.0, "life_days": 60},
      "combat": {"bite_share": 0.35},
      "icon": "zm_type_common", "model": "hol_common", "audio": "zm_horde_common_loop"
    },
    "courser": {
      "name": {"en": "Courser", "tr": "Seğirtken"},
      "kind": "presentation",
      "block": "hollow_courser",
      "spawn": {"weight": 10, "mult": [
        {"if": {"state_has_trait": "fervid"}, "x": 2.0},
        {"if": {"winter_at_least": 0.6}, "x": 0.5}]},
      "disease": {"beta_mult": 1.5, "kappa_mult": 1.0, "life_days": 42},
      "combat": {"bite_share": 0.40},
      "behaviour": {"noise_pull_mult": 2.0},
      "icon": "zm_type_courser", "model": "hol_courser", "audio": "zm_courser_loop"
    },
    "bellwether": {
      "name": {"en": "Bellwether", "tr": "Kösemen"},
      "kind": "leader",
      "block": "hollow_common",
      "block_overrides": {"breakthrough": 12, "org": 90, "speed": 0.8},
      "spawn": {"chance_per_spawn": 0.04, "min_state_hollow": 50000, "world_cap": 40, "min_state_gap": 3},
      "combat": {"bite_share": 0.35},
      "behaviour": {"aura": {"radius": 1, "org_mult": 1.2, "sync_attack": true},
                    "on_disperse": {"aura_org_loss": 0.5},
                    "target": "weakest_living_neighbour"},
      "icon": "zm_type_bellwether", "badge": "zm_badge_leader", "model": "hol_bellwether", "audio": "zm_bellwether_call"
    },
    "greatcoats": {
      "name": {"en": "Greatcoats", "tr": "Kaputlu"},
      "kind": "event",
      "block": "hollow_greatcoat",
      "spawn": {"from_pool": "inranks", "pool_min": 2000, "min_strength": 0.2},
      "disease": {"life_days": 75},
      "combat": {"bite_share": 0.35},
      "behaviour": {"road_speed_mult": 2.0},
      "icon": "zm_type_greatcoats", "model": "hol_greatcoat", "audio": "zm_greatcoat_loop"
    },
    "night": {
      "name": {"en": "Night Hollow", "tr": "Gecegezer"},
      "kind": "presentation",
      "block": "hollow_common",
      "spawn": {"weight": 8, "mult": [{"if": {"any": [{"terrain": "desert"}, {"abs_lat_below": 23.5}]}, "x": 3.0}]},
      "disease": {"beta_mult": 1.1, "kappa_mult": 0.8, "life_days": 60, "climate": {"desert": 1.2}},
      "combat": {"bite_share": 0.40},
      "behaviour": {"night": {"soft": 1.4, "breakthrough": 1.3, "speed": 1.5, "hidden": true},
                    "day": {"soft": 0.4, "defense": 0.8, "speed": 0.3},
                    "countered_by_equipment": "zm_illumination"},
      "icon": "zm_type_night", "model": "hol_common", "audio": "zm_night_amb"
    }
  }
}
```

```json
{
  "_comment": "Soylar ve evrim ağacı. k = 1/(I*T): tipik tetik yoğunluğunda (I bin yeni enfeksiyon/gün) ortalama T günde çıkış. Gerekçeler: 04_zombi_turleri.md §6-§7.",
  "ancestral": "ef0",
  "max_traits": 3,
  "max_lineages_world": 6,
  "max_lineages_state": 3,
  "seed_share": 0.01,
  "drop_share": 0.005,
  "exclusive": [["fervid", "chronic", "pale"]],
  "traits": {
    "rasping": {
      "name": {"en": "Rasping strain", "tr": "Hırıltılı suş"},
      "disease": {"phi": 0.45},
      "horde": {"bite_share_add": 0.15},
      "emerge": {"k": 5.6e-5, "where": {"all": [{"winter_at_least": 0.6}, {"density_mult_at_least": 1.5}]},
                 "boost": [{"if": {"policy": "mass_winter_shelters"}, "x": 2.0}]},
      "fitness": [{"if": {"winter_at_least": 0.6}, "s": 0.05}, {"else": true, "s": -0.03}],
      "discover": {"bulletin_share": 0.25, "bulletin_states": 3, "bulletin_delay_days": 14, "sample_share": 0.10},
      "counters": ["zm_gauze_masks"],
      "icon": "zm_strain_rasping"
    },
    "fervid": {
      "name": {"en": "Fervid strain", "tr": "Kızgın suş"},
      "disease": {"sigma": 0.6667, "gamma": 0.25, "beta_mult": 1.2, "mu_mult": 1.33, "p_death_febrile": 0.15},
      "horde": {"soft_mult": 1.15, "org_mult": 0.9, "type_weight_mult": {"courser": 2.0}},
      "emerge": {"k": 1.7e-4, "where": {"any": [{"hospital_overload_at_least": 2.0}, {"refugee_camp": true}, {"infected_division_share_at_least": 0.03}]}},
      "fitness": [{"if": {"crowding": true}, "s": 0.04}, {"else": true, "s": -0.01}],
      "discover": {"bulletin_share": 0.25, "bulletin_states": 3, "bulletin_delay_days": 14, "sample_share": 0.10},
      "icon": "zm_strain_fervid"
    },
    "refractory": {
      "name": {"en": "Refractory strain", "tr": "Dirençli suş"},
      "disease": {"serum_efficacy_mult": 0.5},
      "emerge": {"k": 8.3e-4, "requires_tech_anywhere": "zm_serum",
                 "where": {"any": [{"policy": "serum_half_dose", "c": 1.0}, {"serum_coverage_between": [0.2, 0.6], "days": 60, "c": 0.5}]}},
      "fitness": [{"expr": "0.08 * partial_serum_coverage"}, {"if": {"serum_coverage": 0}, "s": -0.005}],
      "counters": ["zm_serum_typed"],
      "icon": "zm_strain_refractory"
    }
  }
}
```

**Veri testleri** (`tests/test_data.gd` yaklaşımıyla):
1. Her blok `units.json` tabur anahtarlarının hepsini taşır; tanımsız koşul anahtarı (`winter_at_least`, `state_has_trait` …) hata verir.
2. `exclusive` kümesindeki iki özellik aynı soya eklenemez; bir soy en çok `max_traits` özellik taşır.
3. **Korunum:** tek günlük adımda dünyadaki H değişimi = giriş − çıkış (§2.1), tolerans 1.
4. **Belirlenimcilik:** aynı tohumla 540 günlük iki koşuda soy tablosu (özellik, doğuş günü, kaynak eyalet) aynı çıkar.
5. **Motor taklidi testi:** siperli piyade tümeni + 3 Olağan sürü → sürüler dağılır; + 4 → tümen çekilir (§3.3; ±6 saat).
6. `country_check.gd` yaklaşımı: oyuncu hiçbir şey yapmazsa hiçbir "oyuncu seçimi" tetiği (`policy: ...`) oyuncu ülkesi için doğmamış olmalı.

**Arayüz:** Salgın panelinde (02, kısayol E) "Suşlar" bölümü yalnız `panel_layout.gd` yardımcılarıyla kurulur: `section` başlığı,
`table` / `table_row` (soy adı, özellikler, kendi eyaletlerindeki payı, keşif günü), `info_cells` (bilinen soy sayısı, baskın soy),
`empty` ("Tipleme için numune gerekli"). Yeni görsel stil yoktur.

## 13. Açık sorular

1. **Durgun yuvaları birim olsun mu?** Yuvalar görünmez birim olarak 1.200'lük sürü sınırını yer. Alternatif: yalnız eyalet düzeyinde
   bir "gizli H" payı tutmak ve arındırmada ek bir bedel yazmak. Karar `sim.gd` performans ölçümüyle verilmeli.
2. **Gönüllü aşılama (Soluk suş) seçeneği kalsın mı?** Tarihî dayanağı güçlü (1717 İstanbul) ve seçenek gönüllüdür, ama %3 ölüm
   ve %17 dönüşüm bedeli taşır. İçerik incelemesinde (01 §6) ayrıca değerlendirilmeli.
3. **Tür payları belleksiz** hesaplanıyor. Bir sürü başka eyalete yürüdüğünde türü korunur, ama o eyaletin dağınık H'si yerel
   koşula göre yeniden paylanır. Bu basitleştirme oyuncuya "tutarsız" görünür mü?
4. **Gece görünürlüğü:** Harita ışığı gündüz ve geceye göre değişmiyor. Gecegezer'in gece gücünü oyuncu nasıl fark edecek? Öneri:
   sayaçta ay rozeti ve ipucunda yerel saat. Işık değişikliği CLAUDE.md kural 5 gereği yapılmaz.
5. **Kaputlu figürü:** Rozetsiz genel bir kaput bile belli bir orduyu çağrıştırabilir. Seçenek: sivil palto + kask karışımı.
6. **Yapay zekânın seçim olasılıkları** (yarım doz serum %30, seri pasaj %20 öneri) yapay zekâ belgesinde kesinleşmeli. Aksi hâlde
   Dirençli ve Soluk soylar oyuncusuz dünyada hiç görülmeyebilir.
7. **Aşı kaçağı** yalnız Kara Yıl'da açık. Tedavi Zaferi'ni (02 §4.1) imkânsız kılmaması için "güncellenmiş aşı" araştırmasının
   maliyeti denge testiyle belirlenmeli.
8. **Zırhlı birliklerin üstünlüğü:** Boşların tanksavar ateşi 0,5. Zırh oranı 0,45 olan tümen Boş saldırısını yaklaşık yarıya indiriyor.
   Yakıt kısıtı bunu dengeliyor mu? `balance_parallel` benzeri koşuda ölçülmeli.
9. **Top sesi çekimi** (günde 0,3) oyuncuyu topçudan vazgeçirecek kadar güçlü mü? Hedef, topçunun hâlâ en iyi seçenek olması ama
   bedelinin görünür olması.
10. **Isırık payı 0,35** ile her büyük savunma %4 civarı enfekte asker üretir. Serumdan önceki aylarda bu oran oyuncuyu kordonu
    bırakmaya itebilir. Tatbikat zorluğunda 0,25 önerilir.

## 14. Kaynaklar

Tıp, fizyoloji, davranış
- Kuduz: öfkeli (~%80) ve felçli (~%20) tablo, su korkusu (~%50). *MedLink Neurology.* — https://www.medlink.com/articles/rabies
- Kuduz klinik tablosu. *Communicable Diseases Agency, Singapur.* — https://www.cda.gov.sg/professionals/diseases/rabies/
- Cleaveland, S., Fèvre, E. M., Kaare, M., Coleman, P. G. (2002). Estimating human rabies mortality in the United Republic of Tanzania
  from dog bite injuries. *Bull. WHO* 80(4). — https://www.scielosp.org/article/bwho/2002.v80n4/304-310/
- Von Economo ensefaliti (ensefalit letarjika): somnolent-oftalmoplejik, hiperkinetik, akinetik biçimler. *StatPearls.* — https://www.ncbi.nlm.nih.gov/books/NBK567791/
- Encephalitis lethargica: 100 years after the epidemic. *Brain* 140(8) (2017). — https://academic.oup.com/brain/article/140/8/2246/3970828
- Gün batımı sendromu. *Mayo Clinic.* — https://www.mayoclinic.org/diseases-conditions/alzheimers-disease/expert-answers/sundowning/faq-20058511
- Poikilotermi patofizyolojisi. *PubMed 1365216.* — https://pubmed.ncbi.nlm.nih.gov/1365216/
- Hedefli sıcaklık yönetimi (1 °C başına beyin metabolizması −%6–7). *StatPearls.* — https://www.ncbi.nlm.nih.gov/books/NBK556124/
- Therapeutic hypothermia for acute neurological injuries. *Neurotherapeutics* (2012). — https://link.springer.com/article/10.1007/s13311-011-0092-7
- Derinlikle toprak sıcaklığı. *British Geological Survey.* — https://shop.bgs.ac.uk/resources/shop/doc/example/product/modules/C012.pdf
- FAO/WHO/UNU (2004). Human energy requirements (fiziksel etkinlik düzeyi). — https://www.fao.org/4/y5686e/y5686e07.htm
- Sıcakta ter kaybı ve sıvı gereksinimi. *NCBI Bookshelf NBK231132.* — https://www.ncbi.nlm.nih.gov/books/NBK231132/
- Susuz hayatta kalma süresi. *Scientific American.* — https://www.scientificamerican.com/article/how-long-can-the-average/
- Parkinson tipi sürüme yürüyüşü. *ScienceDirect Topics.* — https://www.sciencedirect.com/topics/medicine-and-dentistry/shuffling-gait
- Couzin, I. D., Krause, J., Franks, N. R., Levin, S. A. (2005). Effective leadership and decision-making in animal groups on the move.
  *Nature* 433. — https://www.nature.com/articles/nature03236

Evrimsel epidemiyoloji
- Alizon, S., Hurford, A., Mideo, N., Van Baalen, M. (2009). Virulence evolution and the trade-off hypothesis. *J. Evol. Biol.* 22. — https://academic.oup.com/jeb/article/22/2/245/7324136
- Walther, B. A., Ewald, P. W. (2004). Pathogen survival in the external environment and the evolution of virulence. *Biol. Rev.* 79. — https://pubmed.ncbi.nlm.nih.gov/15682873/
- Ewald'ın 1918 hipotezi (siper ve sahra hastanesi). *Evolution, Medicine, and Public Health* (2018). — https://academic.oup.com/emph/article/2018/1/219/5088155
- Gandon, S., Mackinnon, M. J., Nee, S., Read, A. F. (2001). Imperfect vaccines and the evolution of pathogen virulence. *Nature* 414. — https://www.nature.com/articles/414751a
- Read, A. F. ve ark. (2015). Imperfect vaccination can enhance the transmission of highly virulent pathogens. *PLoS Biol.* — https://journals.plos.org/plosbiology/article?id=10.1371%2Fjournal.pbio.1002198
- Day, T., Gandon, S., Lion, S., Otto, S. P. (2020). On the evolutionary epidemiology of SARS-CoV-2. *Curr. Biol.* 30. — https://www.cell.com/current-biology/fulltext/S0960-9822(20)30847-2
- Day, T., Gandon, S. (2007). Applying population-genetic models in theoretical evolutionary epidemiology. *Ecol. Lett.* 10. — https://onlinelibrary.wiley.com/doi/10.1111/j.1461-0248.2007.01091.x
- Sanjuán, R. ve ark. (2010). Viral mutation rates. *J. Virol.* 84. — https://journals.asm.org/doi/10.1128/jvi.00694-10
- Andersson, D. I., Hughes, D. (2010). Antibiotic resistance and its cost. *Nat. Rev. Microbiol.* 8. — https://www.nature.com/articles/nrmicro2319
- Shaman, J., Kohn, M. (2009). Absolute humidity modulates influenza survival, transmission, and seasonality. *PNAS* 106. — https://www.pnas.org/doi/10.1073/pnas.0806852106
- Munz, P. ve ark. (2009) ve Alemi, A. A. ve ark. (2015): bkz. 01_vizyon.md Kaynaklar.

Tarih
- The Manchurian pandemic of pneumonic plague (1910–1911). *PubMed 36148171.* — https://pubmed.ncbi.nlm.nih.gov/36148171/
- Mançurya vebası ve gazlı bez maskenin tarihi. *HKU, Making Modernity in East Asia.* — https://mmea.hku.hk/a-tale-of-two-covers/
- History of the plague of 1720–1722 in Marseille. *ScienceDirect.* — https://www.sciencedirect.com/science/article/pii/S0755498222000318
- 1918 Samoa (*Talune*). *NZ History.* — https://nzhistory.govt.nz/culture/1918-influenza-pandemic/samoa
- 1885, the first rabies vaccination in humans. *PNAS.* — https://www.pnas.org/doi/10.1073/pnas.1414226111
- The first live attenuated vaccines. *Nature Milestones.* — https://www.nature.com/articles/d42859-020-00008-5
- 17D aşı suşunun seri pasajla zayıflatılması. *PLOS Pathogens.* — https://journals.plos.org/plospathogens/article?id=10.1371%2Fjournal.ppat.1013373
- Variolasyon ve Lady Mary Wortley Montagu (İstanbul, 1717). *U.S. National Library of Medicine.* — https://www.nlm.nih.gov/exhibition/smallpox/sp_variolation.html
- Lady Mary Wortley Montagu and smallpox. *Hektoen International.* — https://hekint.org/2020/07/13/lady-mary-wortley-montagu-and-smallpox/
- 1930'larda tipe özgü pnömokok serumları. *Clinical Microbiology and Infection* (2014). — https://www.clinicalmicrobiologyandinfection.org/article/S1198-743X(14)61357-4/fulltext
- Yarım ve kısmi doz: 2016 sarı humma kampanyası (karşılaştırma için). *NEJM.* — https://www.nejm.org/doi/full/10.1056/NEJMoa1710430
- Tokyo Ginza hattı (1927). — https://en.wikipedia.org/wiki/Tokyo_Metro_Ginza_Line
- Moskova metrosu (1935). — https://en.wikipedia.org/wiki/Moscow_Metro

Dil
- "Kösemen" maddesi. *TDK Güncel Türkçe Sözlük.* — https://sozluk.gov.tr/
- "Bellwether" maddesi. *Merriam-Webster.* — https://www.merriam-webster.com/dictionary/bellwether

Ses ve görsel tasarım
- Farnell, A. (2010). *Designing Sound.* MIT Press. — https://mitpress.mit.edu/9780262014410/designing-sound/
- Roads, C. (2001). *Microsound.* MIT Press. — https://mitpress.mit.edu/9780262681544/microsound/
- WPA afişleri 1936–1943 (halk sağlığı afişleri; dönem görsel dili). *Library of Congress.* — https://www.loc.gov/collections/works-progress-administration-posters/about-this-collection

Depo içi
- `game/autoload/military.gd` (`stats`, `_resolve_battle`, `_apply_hits`, `attack_mod`, `winter_level`, `_on_day`), `game/core/division.gd`,
  `data/common/units.json`, `game/map/unit_models.gd`, `game/map/unit_layer.gd`, `tools/make_audio.py`, `tools/make_icon_prompts.py`,
  `game/ui/panel_layout.gd`, 01_vizyon.md, 02_oynanis_dongusu.md.
- Motor taklidi ve tek eyalet çözümü için kullanılan hesap betikleri bu belgenin ekidir. Uygulamada `tests/` altında birim testine
  dönüştürülmelidir (§12, test 5).
