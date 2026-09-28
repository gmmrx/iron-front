# Zombi modu — 02 Oynanış döngüsü, evreler, kazanma/kaybetme, zorluk

> **Özet.** Bu belge *Gri Kordon* modunun nasıl oynandığını dakika, saat ve oturum ölçeğinde tanımlar. Kararlar 01_vizyon.md'ye dayanır.
> - Oyun **1 Ocak 1936** (çarşamba) duraklatılmış başlar; etken 21 gün önce 25 kişilik bir indeks kümede başlamıştır.
>   İlk tespit tipik olarak **8.–31. gün**, ilk Salgın Bülteni onu izleyen **cuma** gelir.
> - Dünya **altı salgın evresinden** geçer: Sessizlik → Alarm → Yayılma → Çöküş → Karşı Saldırı → Sonuç. Evreler Küresel Salgın
>   Endeksi (KSE) ve ölçülebilir olaylarla değişir; Karşı Saldırı'dan Çöküş'e geri dönüş ("İkinci Dalga") mümkündür.
> - Salgın her eyalette yedi bölmeli günlük bir modelle hesaplanır. Varsayılan zorlukta müdahalesiz bir eyalette R₀ **2,2–4,1**,
>   ikiye katlanma süresi **5–22 gün**, "düşme" süresi **65–270 gün**dür (sayılar aşağıda türetildi).
> - **Kazanma:** Tedavi zaferi, Arındırma zaferi ya da 1 Ocak 1940'a çökmeden ulaşıp puan almak (Dayanma).
>   **Kaybetme:** Çöküş (teslim hesabının karşılığı), Nüfus çöküşü (%20'nin altı) ya da İç Çöküş olayında "hükümeti bırak" seçeneği.
> - Tam kampanya **4–6 saat**, kısa senaryo ~1 saat. Üç hazır zorluk (Tatbikat, Salgın, Kara Yıl) ve özel ayarlar.
> - Oyuncu adına hiçbir önlem kendiliğinden alınmaz; kolaylıklar kapalı başlayan seçeneklerdir.

---

## 1. Zaman ölçekleri ve temel döngü

### 1.1 Saat ve hız
Oyun saati değişmez (`GameClock.HOURS_PER_SECOND = [0, 5, 12, 30, 80, 240]`). Salgın hesabı günlük (`day_passed`) yapılır;
sürü birimlerinin hareketi ve muharebesi mevcut saatlik tick'le yapılır.

| Hız | Oyun saati / sn | 1 oyun günü | 1 gerçek dakika | Ne zaman kullanılır |
|---|---|---|---|---|
| 1 | 5 | 4,8 sn | 12,5 gün | Kordon kırılırken, arındırma harekâtında |
| 2 | 12 | 2,0 sn | 30 gün | Evre 0–2, varsayılan oynanış |
| 3 | 30 | 0,8 sn | 75 gün | Evre 3–4, sakin dönemler |
| 4 | 80 | 0,3 sn | 200 gün | Aşı dağıtımını beklerken |
| 5 | 240 | 0,1 sn | 600 gün | Test ve izleme |

### 1.2 Dakika döngüsü (1–3 gerçek dakika)
Temel ritim: **Uyarı → Duraklat → Oku → Karar → Sürdür.**

```
  ┌──────────────┐   uyarı şeridinde kırmızı kutu    ┌──────────────┐
  │  Oyun akıyor │ ───────────────────────────────▶ │  Duraklat     │
  └──────────────┘                                   └──────┬───────┘
         ▲                                                  │ panel / harita
         │ sürdür                                           ▼
  ┌──────┴───────┐   emir, yasa, olay seçimi         ┌──────────────┐
  │ Kararı ver   │ ◀─────────────────────────────── │ Durumu oku    │
  └──────────────┘                                   └──────────────┘
```

Bir dakikada tipik olarak 1–3 karar verilir. Uyarı şeridine (mevcut `alert_bar.gd`) eklenen **salgın uyarıları**:

| Uyarı (EN / TR) | Tetik | Beklenen yanıt |
|---|---|---|
| New outbreak in your territory / Topraklarında yeni salgın | Kendi eyaletinde bildirilen vaka 0'dan > 0'a | Eyaleti karantinaya al, kordon kur, araştırma merkezine numune |
| Cordon breached / Kordon yarıldı | Sürü birimi kordon ordusunun tuttuğu bölgeden geçti | Yedek tümen gönder, yakın hava desteği |
| Province overrun / Bölge düştü | Kendi bölgenin kontrolü `UND`'a geçti | Arındırma harekâtı ya da geri çekilip hat kısaltma |
| Refugees at the border / Sınırda mülteciler | Komşu eyalet düştü, sınır tutumun açık/denetimli | Olay seçimi: kabul, karantinalı kabul, ret |
| Bulletin / Bülten | Her cuma | Dünya durumunu oku |
| Serum stock empty / Serum stoğu bitti | Dağıtım emri var ama stok 0 | Üretim hattı ya da ithalat |
| Idle research institute / Boş araştırma merkezi | Merkez var, projesi yok | Proje ata |
| Infected division / Enfekte tümen | Ordu içi bulaş > %1 | Tümeni geri çek, karantinaya al |

Mevcut uyarılar (boş araştırma yuvası, boş fabrika, seçilmemiş program, ikmalsiz tümen) aynen kalır.

### 1.3 Saat döngüsü (30–90 gerçek dakika ≈ bir evre)
Her evre oyuncudan farklı bir **ana soru** sorar ve kendine özgü kararlar açar:

| Evre | Ana soru | Tipik kararlar |
|---|---|---|
| 0–1 | Ne kadar erken ve ne kadar sert tepki vereyim? | Gözetim araştırması, liman sağlık denetimi, sınır tutumu, tıbbi heyet |
| 2 | Hattı nerede çizeyim? | Kordon orduları, karantina yasası, fabrikaların sağlık üretimine kaydırılması, mülteci politikası |
| 3 | Neyi feda edip neyi koruyayım? | Hat kısaltma, tahliye, sıkıyönetim, çöken komşunun eyaletleri, serum önceliği |
| 4 | Ne kadar hızlı geri alayım? | Arındırma harekâtları, serum/aşı dağıtımı, ekonomiyi yeniden kurma |
| 5 | Bitişi nasıl kazanayım? | Aşılama kapsamı, temiz ilan, puan için yardım ve kurtarılan nüfus |

### 1.4 Oturum döngüsü (bir kampanya)
Oturum bir **dört perdelik** yapıdadır; her perde bir ya da iki evreye karşılık gelir ve oyuncuya net bir ilerleme duygusu verir:

1. **Perde I — Uyarı (Evre 0–1, ~0–60. gün):** bilgi toplama, hazırlık, ilk sınır kararları.
2. **Perde II — Hat (Evre 2, ~60–200. gün):** kordonlar, karantina, ekonomi dönüşümü.
3. **Perde III — Kuşatma (Evre 3, ~200–600. gün):** kayıplar, zor seçimler, serum yarışı.
4. **Perde IV — Geri dönüş (Evre 4–5, ~600–1.461. gün):** arındırma, aşı, sonuç.

Gün aralıkları, oyuncusuz dünyanın (yalnız yapay zekâ) hedef akışıdır; §8'deki denge testi bunları ölçer.

## 2. Salgın modeli (bu belgenin kullandığı çekirdek)

Modelin ayrıntısı, yeni parametreleri ve yapay zekâsı ayrı belgededir. Oynanış döngüsünü anlamak için gereken çekirdek:

### 2.1 Eyalet bölmeleri
Her eyalet `s` için yedi sayı tutulur (kayda eklenir):

| Bölme | Anlamı | Başlangıç |
|---|---|---|
| S | Sağlam | `states.json` nüfusu |
| E | Kuluçkada | 0 (indeks küme hariç) |
| F | Ateşli | 0 |
| H | Boş | 0 |
| R | İyileşen (bağışık) | 0 |
| V | Aşılı | 0 |
| D | Ölen (salgından) | 0 |

### 2.2 Günlük denklemler
Yaşayan nüfus `L = S + E + F + R + V`, temas havuzu `T = L + H`.

```
yeni_E     = β · d_s · (H + φ·F) · S / T · (1 − önlem_β)
bastırılan = (κ · d_s · L / T + κ_asker_s) · H
çürüyen    = μ · iklim_s · H
E → F      = σ · E
F → H      = γ · F · (1 − p_ölüm)
F → D      = γ · F · p_ölüm
serum      : E, F → R   (dağıtılan doz kadar)
aşı        : S → V      (dağıtılan doz kadar)
```

- **Yoğunluk çarpanı** `d_s = clamp(√(ρ_s / 25), 0,35, 3,0)`; `ρ_s` eyaletin kişi/km² yoğunluğu.
  Gerekçe: temas sayısı yoğunlukla artar ama doğrusal değil, doyuma giden bir eğriyle (Hu ve ark. 2013). Karekök bunun en basit
  yaklaşımıdır. 25 kişi/km² referansı eyalet dağılımımızdan seçildi: `states.json`'da eyalet yoğunluğunun medyanı 10,3, üst çeyrek
  36,5, %90'lık dilim 93,6, %99'luk dilim 302 kişi/km². Böylece medyan eyalet `d = 0,64`, yoğun sanayi eyaleti `d ≈ 1,9`, büyük liman
  şehri `d = 3,0` (tavan) olur.
- **Hem ısırık hem bastırma yoğunlukla ölçeklenir** (ikisi de temas sürecidir). Bu yüzden bir eyaletteki sonucu belirleyen oran,
  yoğunluktan bağımsız **direnç oranıdır**: `α = κ / β`. Yoğunluk sonucu değil **hızı** belirler; seyrek eyaletlerin avantajı Boş ömrünün
  (μ) orada daha etkili olmasıdır. Bu yapı, zombi salgını modellerinin akademik literatüründeki ısırma/öldürme oranı ayrımına dayanır
  (Munz ve ark. 2009; Alemi ve ark. 2015); sayılar bizimdir.
- **Tespit edilemeyecek kadar küçük salgın söner:** bir eyalette `E + F + H < 0,5` olursa üçü de 0'a eşitlenir. Sürekli bir modelde
  yok oluşun (ve "temiz ilan"ın) mümkün olması için gereklidir.

### 2.3 Varsayılan parametreler ve türetilmeleri

| Parametre | Değer (Salgın zorluğu) | Gerekçe |
|---|---|---|
| σ (kuluçka) | 1/3 gün⁻¹ (ort. 3 gün) | Kuduzda kuluçka haftalar–aylar; oyun için çok yavaş. 3 gün, 1936'da bir yolcunun demiryoluyla komşu ülkeye, gemiyle bir iç denizi aşmasına yeter: **ulaşım kontrolü anlamlı olur**, ama salgın oyuncunun tepki süresini aşmaz |
| γ (ateşli evre) | 1/7 gün⁻¹ (ort. 7 gün) | Serumla kurtarma penceresi; bir haftalık pencere "serum dağıtımı lojistiği" kararını gerçek kılar |
| p_ölüm | 0,10 | Ateşli evrede ölen pay. Ensefalit letarjikada akut ölüm yaklaşık üçte birdi; kurgusal etken daha az öldürür, çünkü asıl tehlike dönüşendir |
| φ | 0,15 | Ateşli hasta ısırır ama düzensizdir; aile ve hastane bulaşını temsil eder |
| β | 0,30 gün⁻¹ | Aşağıdaki R₀ hedefinden geri hesaplandı |
| κ (sivil) | 0,08 gün⁻¹ | Silahsız 1930'lar halkı ve polisi; `α = 0,27` → müdahalesiz insanlar kaybeder (literatürdeki "kıyamet dengesi" sonucuyla uyumlu) |
| μ (Boş ömrü) | 1/60 gün⁻¹ | Yalnız suyla hayatta kalma 45–61 gün (açlık grevi kayıtları); Boşlar düzensiz su içer |
| iklim_s | 1,0 ılıman; kış bölgesinde `1 + winter_level` (en çok 2,0); çölde 1,6 | Soğuk ve sıcak çarpması; mevcut `Military.winter_level` yeniden kullanılır |

**R₀ hesabı** (tamamen sağlam nüfusta): `R₀ = φ·β·d/γ + (1 − p_ölüm) · β·d / (κ·d + μ)`

| Eyalet | d | R₀ | İkiye katlanma | %1 yaygınlık | Düşme (H > S+R+V+Vb, 03 §3.7) |
|---|---|---|---|---|---|
| Çok seyrek | 0,35 | 2,2 | 22 gün | 127. gün | 268. gün |
| Medyan | 0,64 | 2,8 | 13 gün | 75. gün | 162. gün |
| Referans | 1,0 | 3,1 | 9,5 gün | 54. gün | 119. gün |
| Sanayi bölgesi | 1,93 | 3,7 | 6,4 gün | 36. gün | 82. gün |
| Büyük liman şehri | 3,0 | 4,1 | 5,1 gün | 28. gün | 65. gün |

(1 milyon nüfuslu eyalet, 200 kişilik çekirdek, hiçbir önlem yok; günlük adımlı sayısal çözüm. Hesap betiği bu belgenin ekidir,
§11.) R₀ aralığı 1918 grip salgını için yapılan 2–3 tahmininin biraz üstündedir: etken aktif olarak "avlar" ve ilk haftalarda tanınmaz.

**Önlemlerin gücü, örnek:** ısırık baskısı %35 azaltılıp (karantina + halk uyarısı) bastırma gücüne 0,10 eklenirse (bir garnizon),
medyan eyalette salgın hemen söner, referans eyalette 600 gün sürünür ama düşmez, **büyük şehir yine 128. günde düşer**. Tasarım
sonucu: kırsalı yasa ve bilgilendirme korur, **şehirleri asker ve serum korur**.

### 2.4 Eyaletler arası yayılma
- **Yolcu akışı (E ve F taşır):** eyalet başına en çok 8 bağlantı (komşu eyaletler, aynı ülkenin başkenti, liman–liman); ağırlık
  çekim modeliyle `w_ij ∝ N_i · N_j / mesafe²` (Viboud ve ark. 2006'daki grip yayılımı çalışmasındaki yaklaşım). Günlük dışarı giden
  pay %0,3: 1930'larda kişi başına yılda yaklaşık bir eyalet dışı yolculuk varsayımı (1/365 ≈ %0,27, yuvarlandı; kendi tahminimiz).
  Ateşli hastalar yarı oranda yolculuk eder; Boşlar yolculuk etmez.
- **Sürü yürüyüşü (H taşır):** günlük `0,01 + 0,09 · (1 − S_i / N⁰_i)` payı, komşu eyaletlere yaşayan yoğunluğuyla orantılı dağılır.
  Gerekçe: bir eyalet ortalama ~280 km genişliğinde (dünya kara alanı / 1.652); Boş günde 10–20 km yürür → bir eyaleti 15–30 günde
  geçer. Yerel av bittikçe göç artar.
- **Sınır tutumu yolcu akışını keser, sürüyü kesmez.** "Kapalı" sınır yolcu akışını %95 azaltır (kalan %5 kaçak ve sızıntıdır;
  tarihte kordonlar hep sızdırdı), ama sürünün yürüyüşünü yalnız o sınırda duran asker durdurur. Oyuncuya ipucunda şu cümle yazılır:
  *"Kâğıt üstündeki sınır yolcuyu durdurur, sürüyü değil."*

### 2.5 Eyalet durum makinesi

```
         yolcu/sürü          bildirilen > 0          yaygınlık ≥ %1          H > S+R+V+Vb ve eyalette tümen yok
 TEMİZ ───────────▶ MARUZ ───────────────▶ BİLDİRİLMİŞ ─────────────▶ SALGIN ───────────────────────────────▶ DÜŞMÜŞ
   ▲   (gizli, oyuncu     (gizli)            (panoda)                   │                                       │
   │    göremez)                                                        │ E+F+H → 0                             │ arındırma harekâtı:
   │                                                                    ▼                                       │ tüm bölgeler geri alındı
   │           42 gün yeni vaka yok          ┌──────────────────┐                                              │ ve H < yaşayan/2
   └──────────────────────────────────────── │ İZLEMEDE         │ ◀────────────────────────────────────────────┘
                                             └──────────────────┘
 DÜŞMÜŞ ─(yaşayan ve H ikisi de ~0)─▶ BOŞALMIŞ (sahipsiz; yeniden yerleşim olayı ile İZLEMEDE'ye geçer)
```

| Durum | Oyuncu görür mü? | Harita | Etkisi |
|---|---|---|---|
| Temiz | — | Normal | — |
| Maruz | Hayır | Normal | Gizli bulaş |
| Bildirilmiş | Evet (gecikmeli) | Eyalet işareti düzey 1 (`mark_tex` 128) | Uyarı; olaylar |
| Salgın | Evet | Eyalet işareti düzey 1 | Fabrika çıktısı × çalışabilir nüfus payı; korku istikrarı düşürür |
| Düşmüş | Evet | Bölgeler `UND` kontrolünde (mevcut işgal çizgisi) + işaret düzey 2 (`mark_tex` 255) | Fabrika, kaynak, insan gücü yok; çöküş ilerlemesine sayılır |
| İzlemede | Evet | Eyalet işareti düzey 1 | 42 günlük sayaç (panelde) |
| Boşalmış | Evet | `UND` kontrolü kalkar, sahibi aynı, nüfus ~0 | Yeniden yerleşim olayı |

**Temiz ilan için 42 gün:** en uzun kuluçka + ateşli süre kuyruğu ~21 gün alınıp iki katı. Dünya Sağlık Örgütü'nün Ebola için
kullandığı "iki kez en uzun kuluçka" kuralıyla aynı mantık; süre bizim etkenimizin evrelerinden türetildi.

## 3. Salgının evreleri

Evre **dünya için** tektir (bülten ve olaylar buna bağlıdır); her ülkenin kendi durumu ayrıca eyalet durumlarından okunur.

### 3.1 Küresel Salgın Endeksi (KSE)
```
KSE = 100 · Σ_s N⁰_s · min(1, (E+F+H)_s / (0,01 · N⁰_s)) / Σ_s N⁰_s
```
Anlamı: dünya nüfusunun, salgın yaygınlığının %1'i aştığı eyaletlerde yaşayan payı (%1'in altında orantılı). 0–100.
Neden bu tanım: oyuncuya "dünyanın ne kadarı yanıyor?" sorusunu tek sayıyla yanıtlar; eyalet büyüklüğünden bağımsızdır; boşalmış
eyaletler etkin salgın olmadığı için endeksi düşürür (yıkım ayrı bir göstergedir: "salgından ölen", üst çubuk ipucunda).
Üst çubukta mevcut **Kriz** hücresinin yerini alır; ipucunda döküm (etkilenen eyalet sayısı, düşmüş eyalet, dünya Boş sayısı tahmini).

### 3.2 Evreler ve geçiş koşulları

| # | Evre (EN / TR) | Girer | Çıkar | Hedef süre* | Açılanlar |
|---|---|---|---|---|---|
| 0 | Silence / **Sessizlik** | Başlangıç | Herhangi bir ülke ilk kez ≥ 50 bildirilen (F+H) vaka tespit eder | 8–31 gün | Normal 1936 yönetimi; hazırlık araştırmaları |
| 1 | Alarm / **Alarm** | İlk tespit | Gerçek enfeksiyon (E+F+H ≥ 100) ≥ 3 ülkede **ya da** KSE ≥ 1 | 20–60 gün | İlk bülten, tıbbi heyet, sınır tutumu, karantina yasası |
| 2 | Spread / **Yayılma** | Alarm biter | KSE ≥ 15 **ya da** 80 ülkeden birinin başkent eyaleti düşer | 90–200 gün | Kordon ordusu olayları, mülteciler, sıkıyönetim yasası |
| 3 | Collapse / **Çöküş** | Yayılma biter | Dünya Boş sayısının 7 günlük ortalaması 60 gün üst üste düşer **ve** en az bir ülke Serum'u bitirmiştir | 200–500 gün | Çöken ülkeler, koruma altına alma, tahliye, İç Çöküş olayı |
| 4 | Counterstroke / **Karşı Saldırı** | Çöküş biter | Bir ülke Aşı'yı bitirir **ve** KSE < 10 | 200–500 gün | Arındırma ödülleri, yeniden yerleşim, aşı diplomasisi |
| 5 | Resolution / **Sonuç** | Karşı Saldırı biter | Oyun sonu (zafer ya da 1 Ocak 1940) | kalan | Tedavi zaferi denetimi, son olaylar |

\* Oyuncusuz dünyanın hedef akışı; §8 denge testi.

**İkinci Dalga (geri dönüş):** Evre 4'te dünya Boş sayısının 7 günlük ortalaması, son 60 günün en düşük değerinin %25 üstüne çıkarsa
evre 3'e döner ve "İkinci Dalga" olayı gelir. Tarihte 1918 salgını birden çok dalgayla geldi; geri dönüş oyuncuyu "erken rahatlama"ya
karşı uyarır. Evre 5'ten geri dönüş yoktur.

### 3.3 Evre durum makinesi
```
[0 Sessizlik] --ilk tespit--> [1 Alarm] --3 ülke / KSE≥1--> [2 Yayılma] --KSE≥15 / başkent düştü--> [3 Çöküş]
                                                                                                    |    ^
                                                          Boşlar 60 gün düşüşte + Serum var         |    | İkinci Dalga
                                                                                                    v    |
                                                                          [4 Karşı Saldırı] ------------+
                                                                                  |
                                                                  Aşı var + KSE<10
                                                                                  v
                                                                             [5 Sonuç] --> oyun sonu
```
Evre atlama mümkündür (ör. KSE bir haftada 1'den 15'e çıkarsa 1 → 2 → 3 aynı gün): her ara evrenin açılış olayı sırayla gelir.

### 3.4 Evre açılış olayları (her biri 2–3 gerçek seçenekli)
Her evreye girişte oyuncuya bir olay gelir. Seçenekler ve etkiler mevcut etki sözlüğüyle yazılır (`Politics.apply_effects`); yeni
etkiler (ör. `border_posture`, `detection`) iki sözlüğe birden eklenir (CLAUDE.md kural 2). Örnek:

**Evre 1 — "Tuhaf Raporlar" / "Strange Reports"**
> *"Uzak bir limanın sağlık müdürlüğü, ateş, konuşma bozukluğu ve açıklanamayan saldırganlıkla seyreden bir hastalık kümesi bildiriyor.
> Hastaların birkaçı bakıcılarını ısırmış. Uluslararası sağlık bülteni ayrıntı istiyor."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Ulusal gözlem ağını seferber et | Tespit oranı +%15, bildirim gecikmesi −2 gün (180 gün) | −50 nüfuz, istikrar −%2 (endişe) |
| Limanlarda sağlık denetimi başlat | Liman eyaletlerinde gelen yolcu akışı −%50 | İthalat konvoy verimi −%15 (90 gün) |
| Bu uzak bir haber | — | — (bilgi yok, bedel yok) |

**Evre 3 — "Hat mı, Halk mı?" / "The Line or the People?"** (kendi topraklarında düşmüş eyalet varsa)
| Seçenek | Etki | Bedel |
|---|---|---|
| Hattı kısalt, düşen eyaletleri bırak | Kordon cephesi kısalır; tahliye edilebilen nüfus komşu eyaletlere | İstikrar −%10, iç cephe −%8 |
| Her karışı savun | Kordon ordularına engel `zm_obstacle` +0,05 (120 gün; savunma artışı sürüye karşı işlemez, 08 §2.2 B5) | Fabrika çıktısı −%10, insan gücü kaybı artar |
| Sıkıyönetim ilan et | Bastırma gücü +0,05 tüm eyaletlerde | İstikrar −%15, uluslararası itibar düşer (diplomasi kabul oranları −%20) |

## 4. Kazanma ve kaybetme

### 4.1 Kazanma koşulları

| Sonuç (EN / TR) | Koşul | Oyun biter mi? |
|---|---|---|
| **Cure Victory / Tedavi Zaferi** | (1) Aşı teknolojisi bitti, (2) kendi yaşayan nüfusunda aşılama kapsamı ≥ `V_c`, (3) anavatan eyaletlerinin hepsi **temiz ilan** (42 gün) | Evet (isteğe bağlı "devam et") |
| **Clearance Victory / Arındırma Zaferi** | Evre ≥ 4, anavatanın bütün eyaletleri 180 gün üst üste E+F+H = 0, hiçbir kendi bölgen `UND` kontrolünde değil, 1936 zafer puanlarının ≥ %90'ı elinde | Evet |
| **Endurance / Dayanma** (kısmi) | 1 Ocak 1940'a çökmeden ulaşmak | Evet; puanla derecelenir |

**Aşılama eşiği** `V_c` sabit değil, oyuncunun kendi durumundan hesaplanır ve Salgın panelinde gösterilir:
```
V_c = clamp( (1 − 1/R_etkin) / 0,9 , 0,40 , 0,90 )
```
`R_etkin`: anavatan eyaletlerinin nüfus ağırlıklı, o günkü önlemlerle hesaplanan üreme sayısı; 0,9: aşının koruyuculuğu. Formül sürü
bağışıklığı eşiğinin standart hâlidir (`1 − 1/R₀`, aşı etkinliğine bölünür). Örnek: önlemsiz referans eyalet R 3,1 → V_c = %75;
karantina ve garnizonla R 2,0 → %56; R 1,5 → %40 (taban). Yani **önlemler aşı hedefini ucuzlatır**; oyuncu ikisini birlikte düşünür.
Tabanın %40 olması, "önlemle R'yi 1'in altına indirip hiç aşılamadan kazanma" kestirmesini kapatır; tavan %90 imkânsız hedefi önler.

**Aşılama hızı gerçekçi mi?** 1947 New York çiçek salgınında 6,35 milyon kişi yaklaşık dört haftada aşılandı (nüfusun büyük kısmı,
en yüksek hızda günde nüfusun ~%3'ü). Mod, iyi örgütlenmiş bir eyalette tavanı **günde nüfusun %1,5'i** alır (aşı merkezi ve doz
stoğuyla sınırlı), yani %60 kapsam en iyi hâlde ~40 gün, tipik olarak 3–6 ay sürer.

**Puan** (her sonuçta hesaplanır; 0–1.000):
```
Puan = 400 · (yaşayan nüfus / 1936 nüfusu)
     + 200 · (elde tutulan 1936 zafer puanı payı)
     + 150 · aşılama kapsamı
     + 100 · (bitirilen tıp araştırması / tüm tıp araştırması)
     + 150 · yardım puanı (0–1: kabul edilen mülteci, gönderilen yardım, paylaşılan araştırma; normalize)
     + erken bitiş: kalan her gün için 0,1 (en çok 150), yalnız zaferlerde
```
Ağırlık gerekçesi: modun sorusu "kimi kurtardın?"dır, bu yüzden en büyük pay yaşayan nüfustadır; toprak ikinci sıradadır; yardım puanı
"kimse tek başına kurtulamaz" sütununu ödüllendirir. Toplam 1.000'i aşarsa 1.000'e kırpılır.

| Puan | Değerlendirme (EN / TR) |
|---|---|
| ≥ 800 | Exemplary / Örnek Yönetim |
| 600–799 | Commendable / Başarılı |
| 400–599 | At Great Cost / Ağır Bedelle |
| < 400 | Ruin / Enkaz |

### 4.2 Kaybetme koşulları

| Sonuç | Koşul | Gerekçe |
|---|---|---|
| **Collapse / Çöküş** | Mevcut teslim ilerlemesi (`surrender_progress`: zafer puanlı şehirlerden düşman—burada `UND`—elindeki pay, sömürgeler ¼, başkent düştüyse +%10) teslim sınırını aşar (mevcut formül: %80, iç cephe %50 altındaysa düşer, en düşük %20) | Temel oyundaki kural aynen; öğrenme maliyeti yok, test edilmiş kod |
| **Population Collapse / Nüfus Çöküşü** | Anavatan eyaletlerindeki yaşayan nüfus (S+E+F+R+V) 1936 nüfusunun **%20'sinin** altına iner | Kara Ölüm (1347–1351) Avrupa'da nüfusun üçte biri ile yarısını öldürdü, 1918'de Batı Samoa %22'sini kaybetti; devletler yine ayakta kaldı. %80 kayıp tarihte örneği olmayan bir eşik: "yönetecek halk kalmadı" |
| **İç Çöküş olayında "Hükümeti bırak"** | İstikrar 60 gün üst üste ≤ %5 → olay (aşağıda) | Kural 4: kriz otomatik kayıp değil, seçenekli olay |

**İç Çöküş / Internal Collapse olayı** (2–3 gerçek seçenek):

| Seçenek | Etki |
|---|---|
| Sıkıyönetim | Devam; fabrika çıktısı −%30 (180 gün), bastırma gücü +0,05, istikrar %20'ye çıkar, iç cephe −%15 |
| Ulusal birlik hükümeti | Devam; bütün danışmanlar görevden alınır, nüfuz −100, istikrar +%25, bir yasa grubu bir basamak yumuşar |
| Hükümeti bırak | Oyun biter (kayıp, puan hesaplanır) |

Yapay zekâ ülkeleri için aynı koşullar "ülkenin çökmesi" demektir (çökmüş ülkeler ayrı belgede).

## 5. Bilim takvimi (kazanmanın saati)

Kazanma koşulları araştırmaya bağlı olduğu için takvim oturum süresini belirler. Teknoloji adları ve maliyetleri araştırma belgesindedir;
buradaki **hedef günler** (tek araştırma merkezi, orta öncelik, numune ile) dengeyi bağlar:

| Kilometre taşı | Hedef en erken | Tipik | Gerekçe |
|---|---|---|---|
| Etkenin tanımlanması | 60. gün | 90–150 | Numune gerektirir (Sütun 4) |
| Serum (Ateşli evre tedavisi) | 180. gün | 240–450 | 1930'larda serum tedavisi yerleşik bir yöntemdi; üretimi zor |
| Aşı | 540. gün (18. ay) | 600–900 | 17D sarı humma aşısı: virüsün yalıtımı 1927, aşı 1937, onay 1938. Mod bunu savaş seferberliği, birden çok merkez ve uluslararası paylaşımla ~5 kat sıkıştırır |
| Aşı dağıtımı %60 kapsama | aşıdan +40 gün | +90–180 gün | §4.1 aşılama hızı |

Bu takvim bitiş tarihini açıklar: aşı tipik olarak 24.–30. ayda gelir, dağıtım için 6–12 ay kalır → **1 Ocak 1940 (1.461. gün)**.

## 6. Oturum süresi

| Bölüm | Oyun günü | Tipik hız | Saf akış süresi | Karar/duraklama | Toplam |
|---|---|---|---|---|---|
| Perde I (Evre 0–1) | ~60 | 2 | 2 dk | ~15 dk | ~17 dk |
| Perde II (Evre 2) | ~150 | 2–3 | 3,5 dk | ~30 dk | ~35 dk |
| Perde III (Evre 3) | ~400 | 3 | 5,5 dk | ~80 dk | ~1,5 sa |
| Perde IV (Evre 4–5) | ~850 | 3–4 | 7 dk | ~60 dk | ~1,1 sa |
| **Tam kampanya** | 1.461 | | ~18 dk | | **~3,5 sa** (hızlı), **4–6 sa** (tipik) |

Karar süreleri, temel oyunun "ilk 30 gün" akışındaki panel başına işlem sayısından kendi tahminimizdir; gerçek oyun testiyle
güncellenecek.

**Kısa senaryolar** (aynı veri, farklı başlangıç ve bitiş; manifestte tanımlanır):

| Senaryo (EN / TR) | Başlangıç | Bitiş | Hedef | Süre |
|---|---|---|---|---|
| Quiet Start / Sessiz Başlangıç | 1 Ocak 1936, Evre 0 | 30 Haziran 1936 | Anavatanda hiç düşmüş eyalet yok ve bildirilen vaka < 1.000 | ~1 sa |
| The Line / Hat | 1 Haziran 1936, Evre 2, komşu ülke salgında | 31 Aralık 1936 | Kordon hiç yarılmadan ya da tek eyalet kaybıyla | ~1,5 sa |
| Last Harbour / Son Liman | 1 Ocak 1937, Evre 3, anavatanın yarısı düşmüş | 1 Ocak 1938 | Çökmeden ve serumu bulup dağıtarak | ~2 sa |

## 7. Zorluk

### 7.1 Hazır zorluklar

| Parametre | Tatbikat / Drill | **Salgın / Outbreak** (varsayılan) | Kara Yıl / Black Year | Gerekçe |
|---|---|---|---|---|
| β (ısırık baskısı) | 0,24 | 0,30 | 0,36 | ±%20 |
| κ (sivil bastırma) | 0,10 | 0,08 | 0,065 | ±%20 civarı |
| Boş ömrü (gün) | 45 | 60 | 80 | Açlıkla hayatta kalma aralığının alt ucu / ortası / üstü (su bulan Boş) |
| R₀ (d = 1) | 2,0 | 3,1 | 4,6 | §2.3 formülü |
| İkiye katlanma (d = 1) | 15 gün | 9,5 gün | 7,3 gün | Sayısal çözüm |
| Referans eyaletin düşmesi (d = 1) | 184. gün | 119. gün | 93. gün | Sayısal çözüm (200 kişilik çekirdek) |
| Büyük şehrin düşmesi (d = 3) | 91. gün | 65. gün | 52. gün | Sayısal çözüm (200 kişilik çekirdek) |
| İndeks küme (21 gün önce) | 15 kişi | 25 kişi | 40 kişi | |
| Tanınmamış hastalıkta tespit oranı | %12 | %8 | %5 | İlk tespit günü |
| Bildirim gecikmesi (taban) | 3 gün | 6 gün | 9 gün | Telgraf + il → bakanlık derlemesi; 6 gün = haftalık derlemenin ortası |
| Başlangıç yeri | Başka bir kıtada | Rastgele (kendi ülken hariç) | Rastgele (kendi ülken ve komşuların dâhil) | |
| Yapay zekâ ülkelerinin yanıtı | Hızlı ve işbirlikçi | Ülkenin kapasitesine göre | Yavaş; yardım ve araştırma paylaşımı nadir | |
| Aşı teknolojisi maliyeti | ×0,8 | ×1,0 | ×1,25 | |

### 7.2 Özel ayarlar
Oyun kurulumunda "Özel" seçilirse her satır ayrı değiştirilebilir; ayrıca:

| Ayar | Seçenekler | Varsayılan |
|---|---|---|
| Başlangıç yeri | Rastgele / kıta seç / eyalet seç / kendi başkentim | Rastgele |
| Bitiş tarihi | 1 Ocak 1938 / **1940** / 1942 | 1940 |
| Demir irade (tek kayıt, geri yükleme yok) | Kapalı / Açık | Kapalı |
| Devletler arası savaş | Kapalı / Yalnız Çöküş evresinde / Serbest | Yalnız Çöküş evresinde |
| Rehber ipuçları (ilk 30 gün) | Açık / Kapalı | Açık (ipucu yalnız bilgi verir, eylem yapmaz) |

### 7.3 Oyuncu adına iş yapılmaz
Aşağıdaki kolaylıkların hepsi **kapalı başlar**, oyuncu açarsa çalışır (CLAUDE.md kural 1):

| Kolaylık | Açıksa ne yapar |
|---|---|
| Otomatik serum dağıtımı | Stoktaki serumu Ateşli vakası en çok olan kendi eyaletlerine dağıtır |
| Otomatik aşı dağıtımı | Aşıyı nüfus yoğunluğu en yüksek temiz eyaletlerden başlayarak dağıtır |
| Kordonu otomatik genişlet | Kordon ordusu, bildirilen yeni enfekte eyaletleri cephesine ekler |
| Otomatik ticaret | Temel oyundaki gibi |

Mevcut `country_check.gd` benzeri bir denetim bu modda da koşar: oyuncu hiçbir şey yapmazsa bu seçeneklerin hiçbiri çalışmamış olmalı.

## 8. Denge testi hedefleri (oyuncusuz dünya, 6 paralel koşu)

Temel oyundaki `balance_parallel.sh` yaklaşımıyla: her kontrol 6 koşunun en az 5'inde tutmalı.

| # | Kontrol | Hedef |
|---|---|---|
| 1 | İlk tespit günü | 8–31 |
| 2 | Evre 2'ye giriş | 60–150. gün |
| 3 | Evre 3'e giriş | 150–400. gün |
| 4 | 540. güne kadar en az bir ülke çöker | evet |
| 5 | Bitişte çökmüş ülke sayısı | 1–25 (80 üzerinden) |
| 6 | Bir ülke serumu bulur | 240–450. gün |
| 7 | Bir ülke aşıyı bulur | 600–900. gün |
| 8 | Bitişte dünyada yaşayan nüfus / 1936 | %35–%75 |
| 9 | Aynı tohumla iki koşu aynı sonuç | evet (belirlenimcilik) |
| 10 | 1.461 günlük koşu süresi (ekransız) | temel oyunun 1.461 günlük süresinin en çok 1,3 katı |

## 9. Oyuncunun ilk 30 günü

Örnek: oyuncu **Türkiye**'yi seçmiş, zorluk *Salgın*, indeks küme başka bir kıtadaki bir liman eyaletinde (gerçek yer adı örneğe
yazılmaz; oyunda da kaynak bir suçlama olarak sunulmaz). Başlangıçta oyuncunun bildiği tek şey 1936'nın olağan dünyasıdır.

| Gün | Tarih | Ne olur (oyun) | Oyuncunun yapabileceği (ipucu önerir, oyun yapmaz) |
|---|---|---|---|
| 1 | Çar 1 Oca 1936 | Oyun duraklatılmış. Salgın paneli (E) açık: "Bilinen vaka yok." İpucu: *"Dünyada bir şey olduğunda ilk bülten cuma gelir."* | Araştırma yuvalarına tıp/gözetim araştırması koy; devlet programından "Halk Sağlığı Seferberliği" dalını seç; 1936 ekonomisini kur (sivil fabrika) |
| 3 | Cum 3 Oca | İlk rutin bülten: "Olağan dışı bildirim yok." (gerçekte indeks eyalette ~250 vaka var) | — |
| 5–14 | | Normal yönetim. Salgın gizlice ikiye katlanıyor (liman şehrinde ~6 günde bir) | Hazırlık: bir eyalete **araştırma merkezi** inşaatı (öneri: Ankara ya da İstanbul; ikisi arasında seçim: İstanbul limandır, numune hızlı gelir ama bulaş riski yüksek) |
| ~15 | | İndeks ülke hastalığı tespit eder (≥ 50 bildirilen). Dünya **Evre 1 — Alarm** | — |
| 17 | Cum 17 Oca | **Bülten** + **"Tuhaf Raporlar"** olayı (3 seçenek, §3.4) | Olay seçimi. En sık seçim: gözetim ağı (−50 nüfuz) |
| 18–24 | | İkinci olay: **"Tıbbi Heyet"** — uluslararası sağlık teşkilatı heyet ve numune için gönüllü ülke arıyor | Seçenekler: heyet gönder (numune gelir, araştırma +%25; heyet dönüşünde %10 olasılıkla bir hekim kuluçkada döner → İstanbul'da ilk vaka), yalnız para yardımı (−30 nüfuz, itibar +), katılma |
| 24 | Cum 24 Oca | Bülten: indeks ülkede 3 eyalet, komşu bir ülkede ilk şüpheli vaka | Sınır tutumu: indeks bölgeden gelen deniz yolları için **denetimli** (limanlarda yolcu akışı −%50, konvoy verimi −%10) ya da **kapalı** (−%95, konvoy verimi −%30, ticaret ortakları memnuniyetsiz) |
| 25–29 | | Yolcu akışıyla uzak bir limana sıçrama (ağ modeli). İpucu: *"Boğazlar ve Ege limanları en olası giriş kapısı."* | Kara Kuvvetleri: 2–3 tümenle **kordon ordusu** kur (mevcut "Ordu kur", cephe = liman eyaletleri). Henüz vaka yok, bu bir yatırım: tümenler başka yerde değil |
| 30–31 | Cum 31 Oca | Bülten: 2 ülke, 7 eyalet enfekte; KSE 0,4. Karantina yasası açılır | **Karantina Politikası** yasası: "Gönüllü Bildirim" → "Zorunlu Karantina" (150 nüfuz; bulaş −%35, fabrika çıktısı −%10, istikrar −%8). İlk 30 günün en büyük kararı: şimdi mi, ilk vaka gelince mi? |

**İlk 30 günün tasarım hedefleri:**
1. Oyuncu ilk 10 günde **hiçbir tehdit görmez** ama hazırlığın değerini ipuçlarından öğrenir. Hazırlık yapmayan oyuncu cezalandırılmaz,
   yalnız 60. günde daha az seçeneği olur.
2. İlk gerçek karar (Tuhaf Raporlar) **tipik olarak 17. günde** gelir: oyuncu panelleri tanıyacak kadar oynamıştır.
3. 30. güne kadar oyuncu altı panelin (beşi mevcut: Hükümet, Araştırma, İnşaat, Ordu, Diplomasi; biri yeni: Salgın) her birinde en az bir karar vermiş olur.
4. İlk vaka oyuncunun ülkesine **tipik olarak 40–90. gün** arasında gelir (başlangıç yeri "kendi ülken hariç"); karar penceresi budur.

## 10. Veri: kurallar dosyası (öneri şema)

Kesin yerleşim 14_teknik_plan.md §2'dedir (mod altyapısı kuruldu: `docs/modlar/README.md`). Bu belgenin kararlarını taşıyan
dosya `data/modes/zombie/own/rules.json`. Motor içerikten bağımsızdır: evre eşikleri, zafer koşulları ve zorluk sayıları kodda değil burada.

```json
{
  "_comment": "Gri Kordon kuralları. Sayıların gerekçesi docs/modlar/zombi/02_oynanis_dongusu.md §2–§7.",
  "start_date": "1936-01-01",
  "end_date": "1940-01-01",
  "hidden_days": 21,
  "index_origin": {"weight": "port_population", "exclude": ["player"]},
  "disease": {
    "sigma": 0.3333, "gamma": 0.1429, "p_death_febrile": 0.10, "phi_febrile_bite": 0.15,
    "density_ref": 25.0, "density_min": 0.35, "density_max": 3.0,
    "extinction_threshold": 0.5,
    "climate": {"winter_max": 2.0, "desert": 1.6}
  },
  "mobility": {"daily_outflow": 0.003, "links_per_state": 8, "febrile_travel": 0.5,
               "horde_walk_base": 0.01, "horde_walk_hunger": 0.09,
               "border": {"open": 1.0, "controlled": 0.5, "closed": 0.05}},
  "horde": {"per_unit": 10000, "max_units": 1200},
  "clean_days": 42,
  "gsi": {"prevalence_saturation": 0.01},
  "phases": [
    {"id": "silence",       "exit": {"first_detection_reported": 50}},
    {"id": "alarm",         "exit": {"any": [{"countries_infected": 3}, {"gsi_at_least": 1}]}},
    {"id": "spread",        "exit": {"any": [{"gsi_at_least": 15}, {"capital_overrun": 1}]}},
    {"id": "collapse",      "exit": {"all": [{"hollow_falling_days": 60}, {"any_country_has_tech": "zm_serum"}]}},
    {"id": "counterstroke", "exit": {"all": [{"any_country_has_tech": "zm_vaccine"}, {"gsi_below": 10}]},
                            "regress_to": "collapse", "regress": {"hollow_rise_over_min": 0.25, "window_days": 60}},
    {"id": "resolution"}
  ],
  "victory": {
    "cure":      {"tech": "zm_vaccine", "coverage_formula": "herd", "coverage_min": 0.40, "coverage_max": 0.90,
                  "vaccine_efficacy": 0.9, "homeland_clean_days": 42},
    "clearance": {"min_phase": "counterstroke", "homeland_clean_days": 180, "vp_share": 0.90},
    "endurance": {"date": "1940-01-01"}
  },
  "defeat": {
    "collapse": {"use": "surrender_progress"},
    "population": {"homeland_living_below": 0.20},
    "internal_collapse_event": {"stability_at_most": 0.05, "days": 60, "event": "zm_internal_collapse"}
  },
  "score": {"living": 400, "vp": 200, "coverage": 150, "medical_research": 100, "solidarity": 150,
            "early_finish_per_day": 0.1, "early_finish_max": 150, "max": 1000},
  "difficulty": {
    "drill":      {"beta": 0.24, "kappa": 0.10,  "hollow_life": 45, "index_size": 15, "detect_unknown": 0.12, "report_delay": 3, "origin": "other_continent", "vaccine_cost": 0.8},
    "outbreak":   {"beta": 0.30, "kappa": 0.08,  "hollow_life": 60, "index_size": 25, "detect_unknown": 0.08, "report_delay": 6, "origin": "random_not_player", "vaccine_cost": 1.0},
    "black_year": {"beta": 0.36, "kappa": 0.065, "hollow_life": 80, "index_size": 40, "detect_unknown": 0.05, "report_delay": 9, "origin": "random_any", "vaccine_cost": 1.25}
  },
  "player_defaults": {"auto_serum": false, "auto_vaccine": false, "auto_cordon": false, "auto_trade": false}
}
```

Kurallar:
- Yeni koşul anahtarları (`countries_infected`, `gsi_at_least`, `capital_overrun`, `hollow_falling_days`, `any_country_has_tech`,
  `gsi_below`) olay `require` şartlarında da kullanılabilmeli; bu yüzden `Politics`'teki koşul denetimine eklenir ve veri testi
  (`tests/test_data.gd`) tanımadığı anahtarı yakalar.
- Teknoloji kimlikleri (`zm_serum`, `zm_vaccine`) araştırma belgesinde kesinleşir; `zm_` öneki mod içeriğini temel oyundan ayırır.
- Bütün oyuncuya görünen adlar (`PHASE_SILENCE` … `VICTORY_CURE`, `SCORE_EXEMPLARY` …) `strings.csv`'ye İngilizce ve Türkçe girer.
- Kayda eklenecekler: eyalet başına 7 bölme, eyalet durumu ve 42/180 gün sayaçları, evre, İkinci Dalga penceresi, sınır tutumları,
  kolaylık seçenekleri, puan bileşenleri (`test_save_load.gd` eksik alanı yakalar).

## 11. Ek: sayıların hesabı

§2.3 ve §7.1'deki tablolar, 1 milyon nüfuslu tek bir eyalette §2.2 denklemlerinin günlük adımla çözülmesiyle üretildi (başlangıç:
200 kişi, %50 kuluçkada, %30 ateşli, %20 Boş; ikiye katlanma 10.–40. günler arasındaki büyümeden). İlk tespit günleri 25 kişilik
kümenin 21 gün önce başlatılmasıyla, "tanınmamış hastalıkta tespit oranı × (F+H) ≥ 50" koşuluyla hesaplandı: d = 1,0 → 31. gün,
d = 1,93 → 15. gün, d = 3,0 → 8. gün. Başlangıç yeri liman nüfusuna göre ağırlıklı seçildiği için tipik indeks eyalet yoğundur;
bu yüzden ilk tespit tipik olarak ~15. gün, ilk bülten 17 Ocak cumasıdır. Aynı betik, salgın modeli uygulandığında
`tests/` altında bir birim testine dönüştürülmelidir (tek eyalet, bilinen parametre → bilinen düşme günü ±1).

## 12. Açık sorular

1. **Çöküş evresine giriş** için "herhangi bir başkentin düşmesi" çok erken tetiklenebilir (küçük bir ülkenin başkenti indeks eyaletse).
   Öneri: yalnız nüfusu 5 milyonun üstündeki ülkelerin başkentleri sayılsın. Denge testiyle karar verilecek.
2. **Arındırma zaferi** ada ülkeleri için kolay mı? (İzlanda, limanlarını kapatıp Evre 4'ü bekleyebilir.) Bedel ekonomik
   (ticaret) — yeterli mi, yoksa "en az bir yardım eylemi" şartı mı eklensin?
3. **Temiz ilan 42 gün** yolcu akışı sürerken hiç gerçekleşmeyebilir; sınırları açık bir ülke için "yalnız yerli vaka" sayılması gerekebilir.
4. **KSE'nin iç cepheye etkisi:** kriz endeksinin %1 başına +%0,4 kuralı ("dayanışma") ile yüksek KSE'de korku/çaresizlik (−) nasıl
   birleşecek? Öneri: KSE ≤ 20'de +%0,3/puan (en çok +%6), üstünde −%0,2/puan. Siyaset belgesinde kesinleşmeli.
5. **Sürü birimi ile eyalet H sayısının** eşlenmesi (birim kaybı → H azalır, H artışı → yeni birim) muharebe belgesinde kesin
   tanımlanmalı; iki yönlü eşlemede sayı kaçağı olmamalı (test: toplam Boş sayısı korunur).
6. **Web sürümü performansı:** 1.200 sürü birimi + 80 ülkenin tümenleri web'de (gl_compatibility) akıcı mı? `sim.gd` ile ölçülmeli.
7. **Rehber ipuçları** için temel oyunda henüz bir sistem yok (ROADMAP P2 "Hedefler / ipucu sistemi"); iki mod ortak kullanmalı.

## 13. Kaynaklar

Epidemiyoloji ve modelleme
- Kermack, W. O., McKendrick, A. G. (1927). A contribution to the mathematical theory of epidemics. — https://jxshix.people.wm.edu/2009-harbin-course/classic/Kermack-McKendrick-1927-I.pdf
- ETH Zürih, SIR modelleri ders notu. — https://tb.ethz.ch/education/learningmaterials/modelingcourse/level-1-modules/SIR.html
- Munz, P. ve ark. (2009). When zombies attack!: Mathematical modelling of an outbreak of zombie infection. — https://www.researchgate.net/publication/228509313_When_zombies_attack_mathematical_modelling_of_an_outbreak_of_zombie_infection
- Alemi, A. A. ve ark. (2015). You can run, you can hide: The epidemiology and statistical mechanics of zombies. *Phys. Rev. E* 92. — https://arxiv.org/abs/1503.01104
- Hu, H., Nigmatulina, K., Eckhoff, P. (2013). The scaling of contact rates with population density for the infectious disease models. — https://pubmed.ncbi.nlm.nih.gov/23665296/
- Çekim modelinin küresel grip yayılımında doğrulanması (Viboud ve ark. 2006, *Science* 312: 447–451 çalışmasını temel alır). — https://pmc.ncbi.nlm.nih.gov/articles/PMC3166731/
- Truscott, J., Ferguson, N. M. (2012). Evaluating the adequacy of gravity models as a description of human mobility for epidemic modelling. *PLoS Comput Biol.* — https://journals.plos.org/ploscompbiol/article?id=10.1371%2Fjournal.pcbi.1002699
- Sürü bağışıklığı eşiği ve aşı etkinliği düzeltmesi. *History of Vaccines.* — https://historyofvaccines.org/vaccines-101/what-do-vaccines-do/how-herd-immunity-works/
- WHO, Ebola salgınının bitiş ilanı ölçütleri (42 gün = iki kez en uzun kuluçka). — https://www.who.int/docs/default-source/inaugural-who-partners-forum/who-recommended-criteria-for-declaring-the-end-of-the-ebola-virus-disease-outbreak.pdf
- WHO, Rabies fact sheet. — https://www.who.int/news-room/fact-sheets/detail/rabies
- Açlıkla hayatta kalma süresi. *Scientific American.* — https://www.scientificamerican.com/article/how-long-can-a-person-survive-without-food/
- Ensefalit letarjika: klinik özellikler ve sonuçlar. — https://academic.oup.com/brain/article/140/8/2246/3970828

Tarih
- 1918 grip salgını: üreme sayısı ve ölüm tahminleri. Taubenberger & Morens (2006). — https://wwwnc.cdc.gov/eid/article/12/1/05-0979_article
- Estimates of the reproduction numbers of Spanish influenza using morbidity data. *Int. J. Epidemiol.* 36(4) (2007). — https://academic.oup.com/ije/article/36/4/881/667165
- Samoa 1918. *NZ History.* — https://nzhistory.govt.nz/culture/1918-influenza-pandemic/samoa
- Amerikan Samoası'nın deniz karantinası. — https://pmc.ncbi.nlm.nih.gov/articles/PMC9152047/
- 1910–11 Mançurya vebası: demiryolu karantinası, maske, yakma. — https://pmc.ncbi.nlm.nih.gov/articles/PMC7110523/
- Rusya kolera ayaklanmaları 1830–31. — https://www.unm.edu/~ybosin/documents/rus_chol.pdf
- 1892 Hamburg kolera salgını ve Altona'nın süzülmüş suyu. — https://blogs.darden.virginia.edu/globalwater/2020/10/27/qa-with-richard-j-evans-on-the-relevance-of-a-past-cholera-epidemic/
- Karantina kavramının tarihi (Ragusa 1377, Venedik). Gensini ve ark. (2004). — https://pmc.ncbi.nlm.nih.gov/articles/PMC7133622/
- Habsburg–Osmanlı sınırında veba kordonu (21/48 gün). — https://www.researchgate.net/publication/319857853_The_Austrian_success_of_controlling_plague_in_the_18th_century_maritime_quarantine_methods_applied_to_continental_circumstances
- Milletler Cemiyeti Sağlık Teşkilatı Singapur Bürosu'nun haftalık telsiz bülteni. — https://www.newmandala.org/singapore-bureau/
- 1947 New York çiçek aşılaması (6,35 milyon kişi). — https://pmc.ncbi.nlm.nih.gov/articles/PMC3323221/
- 17D sarı humma aşısının geliştirilmesi. *Nature.* — https://www.nature.com/articles/d42859-020-00012-9
- Kara Ölüm'ün Avrupa'daki ölüm oranı tahminleri. *Medievalists.net.* — https://www.medievalists.net/2023/11/how-many-people-died-black-death/
- Sülfonamidler, 1935. *Science History Institute.* — https://www.sciencehistory.org/education/scientific-biographies/gerhard-domagk/

Depo içi
- `game/autoload/game_clock.gd` (hızlar), `game/autoload/game.gd` (oyun sonu), `game/autoload/diplomacy.gd` ve `docs/wiki/tr/06_diplomasi.md`
  (teslim), `game/autoload/military.gd` (`winter_level`), `game/map/map_view_3d.gd` (`set_marked_states`), `data/map/states.json`
  (nüfus ve alan), `docs/wiki/tr/01_nasil_oynanir.md` (temel oyunun ilk 30 günü).
