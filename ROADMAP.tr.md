[English](ROADMAP.md) · **Türkçe**

# Yol Haritası — "Iron Front" (çalışma adı)

Godot 4.7 ile yapılan, 2. Dünya Savaşı konulu büyük strateji oyunu.
Başlangıç: **1 Ocak 1936**. Harita: tüm dünya (Avrupa, Kuzey Afrika, Orta Doğu ve Batı SSCB ile başladı).

İlke: **veri güdümlü mimari** — içerik `data/` altında JSON/CSV; motor kodu içerikten bağımsız.
Hedef: **en yakın zoom'da bile AAA görüntü, 60 FPS**, derin ve kendine özgü oynanış.
Dil: oyun ve belgeler **önce İngilizce**; Türkçe eksiksiz, Ayarlar → Dil'den seçilir.

Durum: ✔ bitti · ◐ temel hâli var, derinleşecek · ☐ yapılmadı
Son güncelleme: **27 Eylül 2026**

> ### ⚠ ÖNCE OKU — ÖZGÜNLÜK VE FİKRÎ MÜLKİYET (tüm ajanlar için)
> Oyunun ilk sürümleri türün en bilinen ticari oyunu örnek alınarak yapıldı; adlar, sayı tabloları, terimler ve ekran
> düzeni büyük ölçüde oradan geliyordu. Dava riskini kaldırmak için **oynanış kalır, ifade bizim olur**. Kurallar ve plan:
> [docs/OZGUNLUK.md](docs/OZGUNLUK.md) (BÖLÜM Ö). Özetle:
> - Başka bir oyunun dosyası, wikisi, ekran görüntüsü ya da rehber videosu kaynak olarak kullanılmaz (temiz oda).
> - Adlar tarihî gerçek adlardır ya da bizimdir; sayılar kendi formülümüzden ve tarihî veriden türetilir, gerekçesi yazılır.
> - Kod, yorum, belge ve commit'te başka bir oyun ne adıyla ne "türün klasiği" gibi örtmeceyle anılır; "parite" hedefi yok.
> - Oyun **açık kaynaklı, ücretsiz bir tarayıcı oyunu** (mağaza yok). Ücretsiz olmak telif riskini kaldırmaz: gerçekçi tehlike
>   GitHub'a telif bildirimi ve deponun kapatılması. Depodaki her varlığın lisansı yeniden dağıtıma izin vermeli.
> - **"Iron Front" çalışma adıdır**: aynı adlı, 2. Dünya Savaşı konulu ticari bir oyun yayında. Ad değişikliği önerilir;
>   oyun modlanabilir olacağından (2. Dünya Savaşı, alternatif tarih, zombi...) yeni ad 2. Dünya Savaşı'na bağlı olmayan
>   genel bir ad olmalı. Yeni ad marka araştırması yapılmadan kullanılmaz.

### Şu an nerede? (özet)
- Tüm dünya haritası, **80 oynanabilir ülke**, 1936 ekonomisi ve tarihî akış (Polonya → Fransa → Barbarossa → Pasifik) çalışıyor;
  denge testi 6 koşunun 6'sında 12 kontrolün hepsini geçiyor.
- **Hükümet modeli**: lider, iktidar partisi, ideoloji popülerliği (istikrara +%15'e kadar), seçimler,
  kriz endeksi ve savaş durumuna bağlı iç cephe, istikrarın fabrika/nüfuz/tüketim malı etkileri, iç cepheye bağlı teslim sınırı,
  şartlı yasalar, tarihli ve süreli ulusal durumlar, 1936 değerleri tarihî başlangıca göre (`game/dev/gov_check.gd`).
- **Arayüz**: metal doku seti, üst çubuk + ayrı komuta gücü/birikim kutusu, ekranın sol kenarında kısayol harfli dikey menü;
  tüm yan paneller aynı çerçevede, büyük ekranlar tam ekran ve sürükleyerek kaydırmalı (açıkken harita kıpırdamaz);
  araştırma tek sayfa zaman çizelgesi; renkli ipuçları (iyi yeşil, kötü kırmızı).
- **Karar oyuncuda**: oyuncunun ticareti elle (otomatik ticaret isteğe bağlı), hava kanatları elle, tümenler "son askere kadar"
  (emir olmadan geri çekilmez), kendiliğinden komutan atanmaz, tarihî baskılar seçenekli olay (Türkiye: Mayıs 1936 Sovyet baskısı, 1938 halef, 1939 Moskova).
- Harita: daha koyu ve doygun; hareket okları yeşil/kırmızı, akan işaretli; uzak zoom'da sayı yerine ülke bayrakları, daha uzakta
  birlik işareti yok.
- **Tarih**: oyuncunun ülkesi dışındaki her ülke gerçek zaman çizelgesini tam gününde izler (`data/common/history.json`:
  Rheinland, Anschluss, Münih, Polonya, Kış Savaşı, Batı, Barbarossa, Pearl Harbor...); oyuncunun ülkesi hiçbir adımı
  kendiliğinden atmaz; koşulu artık tutmayan adım atlanır (oyuncu tarihi değiştirmiştir); 2 Eylül 1945'e kadar yapay zekâ
  kendi başına savaş açmaz ve saldırı savaşına çağrıyla katılmaz.
- **Komuta zinciri**: ordular grubu (mareşal) → ordu (general) → tümen; 80 ülkenin hepsine komutan kadrosu (57 ülkede
  dönemin gerçek komutanları, kalanlarda yöresel isimler), beceri 1–5 muharebe katkısı, muharebede tecrübe ve beceri artışı,
  komuta gücüyle mareşalliğe terfi ve yeni general; Ordu ekranı (U) ağaç + ayrıntı + kadro; seçim panelinde mikro yönetim
  (bileşim, böl, orduya kat/çıkar, doğrudan emir). Oyuncunun ordusuna kendiliğinden komutan atanmaz.
- **Harita kartları**: Ctrl basılıyken ülke kartı (portre, ilişki, göstergeler, savaşlar), Ctrl + tık o ülkenin siyaset
  ekranı (salt okunur); deniz bölgelerinde ülkelere göre deniz hâkimiyeti.
- **Harita bir kurmay masası (iğne tasarımı)**: 3D arazi kalır; şehirler, tümenler, filolar ve hava kanatları haritaya
  saplanmış iğnelerdir (şehir iğnesinin başı şehri elinde tutan ülkenin renginde; sayaç iğnenin bayrağı); uzakta her
  zamanki harita ikonları, yaklaşınca iğneler. Her eyaletin yapıları tek iğnede resim ve seviye olarak, süren inşaat
  turuncu "+n". Tek model uçaklardır (küçük tek uçak). Eyalet sınırları ve daha küçük province sınırları (farenin
  vurguladığı birim) her zoom'da net çizgidir.
- **Ayarlar** ana menüde ve oyun içinde: ses düzeyleri, müzik seçimi, dil (English / Türkçe), tam ekran.
- Arayüzü olup oyuna henüz etkisi olmayan özellikler (kara/deniz/hava birikimi) soluk ve yasak imleçli görünür, nedenini söyler.
- Oyun wikisi: [docs/wiki/tr](docs/wiki/tr/README.md) (İngilizcesi [docs/wiki](docs/wiki/README.md)). Yeni ikon seti oyunda;
  ikon ve portre prompt listesi: [docs/art/ICON_PROMPTS.md](docs/art/ICON_PROMPTS.md) (yeni dosyaları oyun otomatik kullanır).

### Sıradaki işler (öncelik sırasıyla)
0. ◐ **Özgünlük (BÖLÜM Ö)**: ✔ terimler, yasalar, danışmanlar, ulusal durumlar, teknoloji/program adları, inşaat/üretim/muharebe
   sayıları kendi ifademizle, kopya izleri temizlendi; ☐ kalan sayılar (docs/OZGUNLUK.md), arayüz kimliği, yeni genel oyun adı
   ve marka araştırması
1. ✔ **Gemiler karaya çıkmıyor**: deniz yolları tam çözünürlükte doğrulanıp onarıldı (kara teması 236 → 0 rota, eksik liman–deniz
   12 → 0), düğüm köşe kavisleri suda kalan yarıçapla, karaya düşen filo grubu en yakın suya; `tests/test_sea_lanes.gd`,
   `tests/test_fleet_motion.gd` bunu sayıyla denetler
2. ◐ **Yeni ikon seti ve portreler** (kullanıcı üretiyor): ✔ ikon seti oyunda; portreler geliyor → geldikçe görsel kontrol
3. ◐ **Açık uçlu oyun (BÖLÜM AÇIK)**: ✔ bitiş tarihi yok — oyun, oyuncu bütün dünyayı ele geçirene ya da yok olana
   kadar sürer; ✔ bitmeyen araştırma (iyileştirme seviyeleri); ✔ dünyada olanları izlemek ve cevap vermek için solda
   bir dünya olayları menüsü (BÖLÜM OL)
3b. **Türkiye ile uçtan uca oyun**: dünyayı fethetme / yenilme yolu görsel olarak doğrulanır
4. **İçerik**: ◐ 1936 seçenekli olayları eklendi: Japonya (26 Şubat), İtalya (Cemiyet yaptırımları), İngiltere (Savunma Beyaz
   Kitabı), Fransa (Halk Cephesi), Almanya (Berlin Olimpiyatları), Polonya (Rambouillet kredisi), SSCB (1936 Anayasası),
   Çin (Xi'an). Kalan: orta ve küçük ülkeler, 1937–1945 olay zincirleri (İspanya İç Savaşı, Kış Savaşı, Balkanlar)
5. **Eksik mekanikler** (BÖLÜM M): ◐ generaller (komuta zinciri ✔; özellikler, portreler, tarihî giriş/çıkış sırada), doktrinler
   (birikim hücreleri onlarla açılır), savaş planları, barış konferansı, kuklalar, istihbarat, ikmal merkezleri
6. ✔ Küçük ülkeler de inşaat yapabilir (1 fabrikalık kamu inşaat tabanı, ithalat ödemesi de bunu yiyemez); ✔ duraklatma menüsü, oyun sonu, tümen paneli yeni tasarımda
7. ☐ **Mod desteği** (BÖLÜM MOD): oyun modlanabilir bir platform olur; 2. Dünya Savaşı ilk senaryodur

---

## BÖLÜM Ö — ÖZGÜNLÜK VE FİKRÎ MÜLKİYET ◐ ← HER İŞTEN ÖNCE
Ayrıntı ve kurallar: [docs/OZGUNLUK.md](docs/OZGUNLUK.md). Her PR bu sayfadaki inceleme listesinden geçer.
- [◐] Katman 1 — İfade: ✔ terim sözlüğü, yasalar, danışmanlar, ulusal durumlar, teknoloji ve ortak program adları, inşaat
      (fabrika-gün), üretim (fabrika-saat), muharebe değerleri, komutanlar; ☐ nüfuz ölçeği, ticaret/konvoy oranları, kriz endeksi eşikleri,
      istikrar etkileri, tabur insan gücü/ekipman, 1936 başlangıç değerleri (liste: docs/OZGUNLUK.md)
- [ ] Katman 2 — Arayüz kimliği: kendi yerleşim, kısayol ve renk dili; harita sayaçları için açık sembol standardı
      (insan gözü gerekir)
- [ ] Katman 3 — İmza mekanikler: seçenekli kriz pazarlıkları, tarafsız ülke denge diplomasisi, hava/mevsim ve cephe sistemi
- [◐] Katman 4 — Süreç: ✔ "türün klasiği" ifadeleri ve parite/rehber videosu bölümleri temizlendi; ◐ üçüncü taraf atıfları
      (bayrak lisansları tek tek doğrulanacak); ☐ isteğe bağlı: geçmişi olmayan yeni bir depodan yayın
- [ ] **Oyun adı** (önerilir, acil değil; açık kaynak ücretsiz oyunda marka riski düşük): "Iron Front" çalışma adı. Aynı adı taşıyan, 2. Dünya Savaşı konulu ticari bir bilgisayar oyunu (2012) ve bir
      mobil oyun yayında; ad ayrıca 1930'ların gerçek bir siyasi örgütünün adı. Oyun modlanabilir olacağından yeni ad genel
      olmalı (2. Dünya Savaşı'na bağlı değil). Aday adlar TÜRKPATENT, EUIPO, USPTO, WIPO
      (Nice 9, 28, 41), mağazalar ve alan adlarında aranır; seçilen ad tek bir çeviri anahtarından okunur

---

## BÖLÜM A — TAMAMLANAN TEMEL (Faz 0–9)

| Faz | Konu | Durum |
|---|---|---|
| 0 | Proje, harita üretim hattı, kamera, saat, temel arayüz | ✔ |
| 1 | 3D harita, kabartma, nehir/göl/boğaz, şehirler, ülke adları | ✔ (tüm dünya ✔, bkz. W) |
| 2 | Ekonomi: fabrikalar, inşaat, kaynaklar, ticaret, üretim hatları, yasalar | ✔ |
| 3 | Siyaset: devlet programı ağaçları, olaylar, ulusal durumlar, danışmanlar, kararlar | ◐ |
| 4 | Araştırma: 33 teknoloji, slotlar, yıl cezası | ◐ |
| 5 | Kara savaşı: tümenler, A*, muharebe, kuşatma, basit ikmal, ordular/cepheler (C1), komuta zinciri | ◐ |
| 6 | Hava (gerçek kanatlar, ★4) & deniz (gerçek filolar, deniz yolları, ★3) | ◐ |
| 7 | Diplomasi: gerekçe, savaş, ittifak, garanti, teslim, barış | ◐ |
| 8 | Yapay zekâ: ekonomi + cephe + tarihî akış | ◐ |
| 9 | Kaydet/yükle (ordular ve komutanlar dâhil), menüler, ayarlar (ses, müzik, dil), temel sesler | ✔ |
| 10 | Çok oyunculu | ☐ |

---

## BÖLÜM W — TÜM DÜNYA ✔ (Faz 11c)
- [x] Miller silindirik projeksiyon, 16384 px; dikiş Bering Boğazı'nda, komşuluk dikişten sarmalanır
- [x] Değişken bölge yoğunluğu: Avrupa ayrıntılı; Doğu Asya/Hindistan 2–2,5x, Sibirya/Afrika/okyanus 5x
      → 13.414 bölge (8.812 kara, 1.901 ada, 2.134 deniz, 567 göl), 1.652 eyalet, 1.847 şehir
- [x] Dünya yükseltisi (Terrarium z5 + Avrupa z6), enleme göre kar çizgisi, güney yarıküre biyomları
- [x] 1936 siyasi durumu: 80 ülke, bütün sömürge imparatorlukları, dominyonlar, Mançukuo, Çin savaş ağaları
- [x] Dünya ekonomisi (ABD, Japonya, Çin, Hindistan...), gerçek yataklar (Malaya kauçuğu, Teksas petrolü...)
- [x] Coğrafi mesafe (büyük daire) ile hareket, yol bulma, deniz bölgeleri, hava menzili
- [x] Bellek bütçesi (~750 MB): 16 bit bölge dokusu, yarım çözünürlük SDF/arazi, 128 parçalı harita ağı
- [x] Kamera: görüş alanı hiçbir zoom'da haritadan taşmaz (kenar boşluğu yok); en uzak zoom tüm dünya; bulut yok
- [x] Asya odakları: Japonya (Marco Polo 1937, Üçlü Pakt, Güneye Saldırı 1941), ABD, Çin
- [x] Sömürge nüfusu insan gücüne %15 katılır
- [x] Almanya Balkan/Barbarossa ve İtalya Yunanistan odakları Fransa savaşı bitmeden açılmaz
- [x] Dünya denge testi 12 kontrol ≥5/6: Polonya 1940-02, Fransa 1940 Tem–Eyl, Barbarossa 1941-09,
      Japonya–Çin 1937-08, Pasifik Savaşı 1941-12, Çin/İngiltere/SSCB ayakta
- [x] Doğu–batı kesintisiz kaydırma: dikişte harita kopyası, kamera sarmalanır, dikiş çizgisi/karartma yok
- [x] Messina / Küçük Belt / Panama kanalları (harita yeniden üretimi; 11 boğaz, Manş karadan geçilmez)
- [ ] Diğer büyük güçler için ayrıntılı devlet programı ağaçları (ABD, Japonya, Çin genişletilecek)

## BÖLÜM ★ — GÖRÜNÜR SAVAŞ (Faz 11) ◐ ← EN ÖNCELİKLİ
Oyuncu savaşı **görmeli**: asker, tank, gemi, denizaltı, uçak haritada gerçek, hareket eden 3D modeller.

### ★1. 3D model kütüphanesi ✔
- [x] Kara: Muster WWII (MIT) modelleri → sadeleştirilmiş + renk aktarılmış GLB (`tools/muster/`):
      piyade ve makineli tüfekçi (GER/SOV/UK/USA), top (PaK 40, ZiS-3, 25-pdr, M2A1, Flak 36)
- [x] Zırhlı: Panzer IV, T-34-85, Cromwell, Sherman, M13/40, Chi-Ha, Tiger, KV-1, Churchill; Opel Blitz, ZiS-5
- [x] Hava: Bf 109, Spitfire, P-51, Il-2 (Muster); bombardıman uçağı (Blender)
- [x] Deniz: muhrip, kruvazör, zırhlı, denizaltı, yük gemisi (Blender)
- [x] Ülkeye özgü teçhizat; diğer ülkelerde dönem üniforma rengi
- [ ] Uçak gemisi, nakliye uçağı, motosiklet, zırhlı araç

### ★2. Kara birliklerinin görünümü ◐
- [x] Yakın zoom: tümen başına 3–5 figür (şablona göre piyade/MG/top/kamyon/tank), kamera uzaklığına göre ölçek
- [x] Yürüme animasyonu; tümen bölgeler arasında ilerleme oranına göre yürür
- [x] **Akıcı hareket**: saat içi ara değer + Catmull-Rom rota (saatlik zıplama ve keskin köşe yok)
- [x] **Figür başına yönlendirme**: her asker/araç kendi yuvasına döner, hızlanır; tümenin hızını taşır (geride kalmaz)
- [x] Adım fazı gerçek yer hızına bağlı (kayma / "moonwalk" yok); yürüyüşte gövde sekmesi ve salınımı
- [x] Yürüyüşte iki sıralı kol, beklerken savunma hattı, muharebede yayılmış hat; araçlar araziye göre eğilir
- [x] Sayaçlar birliklerin akıcı konumunu izler ve figürlerin üstünde durur
- [x] Muharebede figürler düşmana döner; namlu alevi, patlama, duman
- [ ] Geri çekilme, kuşatılınca teslim olma/yok olma animasyonu
- [ ] Eğitimdeki tümenler kışlada talim yapar

### ★3. Donanma birimleri (sistem + görünüm) ◐
- [x] Filo birimi (`Navy` + `Fleet`): gemiler stok yerine filolarda; liman ya da deniz bölgesinde; yedek filo
- [x] Görevler: limanda, deniz üstünlüğü, konvoy baskını (denizaltı), konvoy koruma; görev bölgesi (≈420 km)
- [x] Deniz muharebesi: saatlik ateş/hasar, denizaltı tespiti, bütünlük, geri çekilme, batan gemiler
- [x] Deniz hâkimiyeti: nakliyedeki tümenler düşman hâkimiyetinde kayıp verir; rota düşman denizinden geçmez
- [x] Konvoylar: baskınla batar, açık ithalatı düşürür; AI konvoy üretir
- [x] Donanma paneli (N), haritada filo seçimi, sağ tıkla bölge/üs emri, filo ipucu
- [x] Görünüm: limanda demirli gemiler, seyir + iz dalgası, dalıştaki denizaltı, top alevi + su sütunları,
      batan gemi animasyonu
- [x] **Düzgün seyir**: filo tek parça, derli toplu seyir düzeni (ortada ağır gemi + 4 eskort), sınırlı hızla
      döner, dönüşte hafif yatış, yana kayma yok; hıza göre kısa iz dalgası; limanda kıyıya paralel sıralar
- [x] Sakin filo hareketi: seyir hızları (zırhlı 24, muhrip 30 km/sa), bölgede mevzi tutma, birkaç günde bir
      ağır devriye kayması, AI bölge seçiminde eşik salınımı yok
- [ ] Çıkarma planı (oyuncu), liman baskını, mayınlar, uçak gemisi ve deniz hava gücü
- [x] Deniz yolu ağı (tools/build_sea_lanes.py): her deniz bölgesinde açık deniz düğümü, komşular ve limanlar
      arasında yalnız sudan geçen, kıyıdan uzak rotalar (Süveyş, boğazlar, dar kanallar tam çözünürlükte)
- [x] Filolar ve nakliyeler bu yolları izler; düğümlerde Bézier kavis; zoom'la konum değişmez (sabit ölçek)
- [x] Rota kıyıdan en az ~12 px uzak; yol bulma ve hız gerçek rota uzunluğuyla; seyir hızları 13–23 km/sa;
      sıkı üçgen düzen, pruva rota teğetini izler, kıyıya yaklaşınca düzen yumuşakça sıkışır
- [x] Kamera arazi yüksekliğini izlemez (sabit yükseklik, inip çıkma yok)
- [x] Deniz yolu üreticisi son aşamada her rotayı tam çözünürlükte doğrular/onarır (kara teması 0), uzak denize açılan
      limanlar şehrin rıhtımından çıkar, düğüm başına köşe yarıçapı (kavis suda kalır); FleetLayer düzeni (fit_formation)
      ekransız test edilir, karaya düşen grup konumu en yakın suya alınır
- [x] Aynı yerdeki filolar/tümenler tek temsilci grup (en çok 3 gemi / 1 tümen düzeni), sayı sayaçta
- [x] Konvoy / ticaret rotalarının haritada görünmesi (Yollar modu)
- [x] Deniz bölgesi kartı: ülkelere göre deniz hâkimiyeti (pay çubuğu), bizim tarafın payı, nakliye güvenli mi, oradaki filolar

### ★4. Hava kuvvetleri (sistem + görünüm) ◐
- [x] Hava kanadı birimi (`Air` + `AirWing`): avcı / yakın destek / bombardıman kanatları hava üslerinde (100 uçak)
- [x] Görevler bölge başına (≈350 km, menzil kontrollü): hava üstünlüğü, yakın hava desteği, liman baskını
- [x] Günlük it dalaşı + uçaksavar kayıpları; bölgesel hava üstünlüğü ve yakın destek kara muharebesine bonus
- [x] AI: en sıcak cepheye üs değiştirir ve görev verir; oyuncu kanatları "Otomatik" ile AI'a bırakılabilir
- [x] Hava paneli (H): kanat kur (stoktan, seçilen üsse), görev, bölge seçimi, otomatik mod, takviye, dağıt
- [x] Karar oyuncuda: oyuncunun ürettiği uçaklar stokta bekler, elle kanat olarak konuşlandırılır
- [x] Görünüm: üslerde park etmiş uçaklar, görev bölgesi üstünde V düzeninde tur atan filolar,
      it dalaşı (iz mermisi), düşen uçak, yakın destek bombaları + yer patlamaları
- [x] Deniz aşırı harekette tümen nakliye gemisi olarak görünür
- [ ] Stratejik bombardıman (fabrika hasarı), üs kapasitesi cezası, şehir üstünde uçaksavar ateşi

### ★6. Haritada şehirler ve binalar ◐
- [x] **İğne tasarımı** (`game/map/pin_layer.gd`, 27 Eyl 2026): harita bir kurmay masası — 3D arazi, üstünde modeller
      yerine iğneler. Şehir: kontrol eden ülkenin renginde başlı iğne (büyük şehirde büyük), adı başın üstünde. Tümen,
      filo, hava kanadı: sayaç iğnenin bayrağı. İğneler her zoom'da ekranda aynı boyda; uzakta her zamanki harita ikonları,
      yaklaşınca her ikon yerden yükselen bir iğneye dönüşür
- [x] İğne olarak yapılar: eyalet başına bir iğne, ucunda yapıları yan yana resim (sivil/askerî fabrika, tersane,
      rafineri, uçaksavar, deniz üssü) ve seviyesi; süren inşaat turuncu çerçeveli resim ve "+n"; hava üssünün kendi iğnesi
- [x] Yapı rozetleri geç gelir (28 Eyl 2026): orta uzaklıkta haritanın üstünde ikon olarak durur, iğne ancak çok
      yakında yükselir. Farenin rozetin üstüne gelmesiyle rozet büyür, yapının sesi çalar (`map_<yapı>.wav`; dosya
      gelene kadar yakın bir eylem sesi) ve kart yapıyı anlatır (seviye / en çok, inşaat, ülke toplamı, konuşlu kanatlar);
      tıklamak eyaletini açar
- [x] Oyuncunun ordusu yakında ana sayacının üstünde komutanının portresini taşır (resim yoksa baş harfleri)
- [x] Muharebe durum okları: durumu az önce düzelen tarafta küçük yeşil ▲, zemin kaybedende kırmızı ▼; yükselip söner
      (`game/map/battle_ticker.gd`)
- [x] Uçaklar: ülke renginde tek küçük uçak modeli, üste park etmiş ya da görevinde uçarken
- [x] Eyalet sınırları her zoom'da net çizgi (yakında daha kalın), province sınırları (farenin vurguladığı birim) eyaletlerin
      içinde daha ince ve açık çizgi
- [x] Hiçbir şey üst üste binmez: tümenler şehrin, yapıların ve hava üssünün yanında durur; hava üssü başka bir şehrin
      dibine kurulmaz
- [ ] Başka şeyler için de iğne: ikmal merkezleri, tahkimat, radar, stratejik kaynaklar (petrol, çelik...) eyaletinde
- [ ] İşgal edilen şehir: iğne başı işgalcinin renginde, ince bir halka sahibinin renginde; bombardımanla yıkılmış şehir
- [ ] 3D model kütüphanesi kapalı olarak duruyor (`city_layer_3d.gd`, `industry_layer.gd`, `unit_models.gd` içinde
      `SHOW_MODELS`); model hattı (`tools/blender/build_cities.py`, `build_industry.py`) ileride kullanılmak üzere kalır.
      Ayrıntılı şehir dioramaları, rig'li sanayi (vinçler, uçaksavar topları, rafineri meşalesi) ve modelli kara birlikleri
      bunun içinde

### ★5. Muharebe efektleri ve sesleri ◐
- [x] Parçacıklar: namlu alevi, patlama, duman; denizde su sütunları
- [x] Prosedürel efekt gölgelendiricisi (vfx.gdshader): gürültülü ateş topu (beyaz çekirdek → turuncu → is),
      kabaran düzensiz duman, fırlayan toprak, iki yana açılan namlu alevi; figür boyuna göre ölçek
- [x] Ateş eden figürlerin namlu ucunda anlık alevler (piyade sık/küçük, top/tank seyrek/büyük)
- [x] Uzak zoom'da muharebe plakası (çapraz kılıç + iki tarafın denge çubuğu; oyuncu saldırıda yeşil, savunmada kırmızı)
- [x] Uçaklar sabit ölçek, gölgesiz; aynı bölge/üs+sahip+tür tek temsilci grup (en çok 3 uçak) + sayı sayacı
- [x] Yakın destek gerçek saldırı turu: hedef düşman tümen, dalış, 2 bomba (bombardıman 4'lü dizi), isabet patlaması;
      avcılar burundan kısa atış dizileri (ekranı kaplayan rastgele iz mermisi bulutu kaldırıldı)
- [x] Piyade/makineli iz mermileri düşmana doğru; namlu alevleri
- [x] Yön değiştiren tümen geri dönmez (gittiği bölgeden devam eder)
- [x] Tek bilgi kartı (bozuk tooltip gecikme ayarı düzeltildi); alttaki düğmelerin (harita modları) kartı düğmenin üstünde açılır
- [x] Üst görev çubuğu kare simge düğmeleri + kare uyarı şeridi (olay, boş araştırma, devlet programı, boş fabrika/tersane,
      boş inşaat, ikmalsiz tümen, konvoy açığı, stokta uçak, insan gücü, teslim tehlikesi)
- [x] Donanma: büyük güçler 6 filoya kadar, 12+ gemilik yedek filoya dönüşür; oyuncu her zaman çıkarma yapabilir
      (düşman hâkimiyetindeki denizden geçemez)
- [ ] Zoom'a göre muharebe sesleri (tüfek, makineli, top, tank, uçak motoru, deniz topları)
- [ ] Performans: havuzlama (pooling)

---

## BÖLÜM P — OYNANABİLİRLİK (Faz 11b) ◐ ← ★ ile birlikte en öncelikli
Oyun "izlenebilir" olmaktan çıkıp **oynanabilir** olmalı: dengeli tarih akışı, anlaşılır geri bildirim, az mikro yönetim.

### P1. Savaş dengesi (kritik)
- [x] AI konuşlanma rotası düşman toprağından geçmez; her cephe bölgesine garnizon; Manş yürünemez
- [x] Gemi ve uçak tipleri araştırma olmadan üretilemez (başlangıçta eldeki tiplerin teknolojisi verilir)
- [x] Otomatik denge testi (paralel, ~15–20 dk): `tools/balance_parallel.sh 6`
- [x] AI ana taarruz noktası (Schwerpunkt): cephe başına 2 bölgede yığınak → Fransa 1940 Mart–Nisan'da düşer
- [x] AI performansı: dost toprak bileşenleriyle konuşlanma (ai_military 130 sn → 16 sn / 1700 gün)
- [x] Doğu cephesi dengesi: ikmal menzili (işgal edilen toprakta kaynaktan en fazla 9 bölge) + yurt savunması
      (+%15) → "kazanan her şeyi siler" dinamiği bitti; Almanya ve SSCB 1942 ortasına kadar ayakta (6/6)
- [x] Denge testi 9 kontrolün tamamı 6/6: Polonya 1940-02, Fransa 1940 Nisan–Haziran, Barbarossa 1941-09
- [x] Dünya haritasında denge testi (12 kontrol, 6 paralel koşu): hepsi ≥5/6 — Fransa 1940 Tem–Eyl,
      Japonya–Çin 1937-08, Pasifik savaşı 1941-12, Çin/İngiltere/SSCB ayakta
- [x] Yeni dünya haritasında (kanallar) denge bozuldu → teşhis: yok olan tümenlerin neredeyse hepsi
      "çekilecek yer yok" (derine tek başına sızan birlikler); Almanya ordusu Fransa'dayken anavatan boşalıp
      teslim oluyor. Düzeltmeler: AI cephe bütünlüğü (yalnız dost bölgeye de değen boş bölgeye ilerler),
      deniz güçleri küçük ordu (İngiltere ×0,5, ABD ×0,6), demokrasilere ilk 270 gün saldırı cezası (−%25)
      → Almanya ayakta 0/6 → 2/6, Fransa düşer 1/6 → 3/6
- [x] 1939–41 akışı (25 Eyl 2026, 6 koşu): 12 kontrolün hepsi ≥5/6 — Polonya Eyl–Ara 1939 düşer, Almanya/İngiltere/SSCB/İtalya
      ayakta, Barbarossa 1941-07. Düzeltmeler: AI ordusu tek düşmanı hedefler (müttefik cephesine yayılmaz), ordu başına
      tavan, her cephe bölgesine garnizon, büyük güçler arası ilk 240 gün taarruz yok, demokrasiler sağlam büyük güce
      saldırmaz ("garip savaş"), tümenler dolmadan yenisi kurulmaz, doktrin durumları (Blitzkrieg +%25 saldırı, Maginot −%30,
      Büyük Terör −%30, hazırlıksız ordu), Alman program tarihleri tarihî (Danzig 1 Eyl 1939, Batı Mayıs 1940)
- [x] Komutanlarla (27 Eyl 2026, 6 koşu): 12 kontrolün hepsi ≥5/6; bir koşuda Almanya/İtalya erken, bir koşuda Fransa geç
      düştü — izlenecek
- [x] Fransa Haziran–Temmuz 1940'ta düşer (6/6 koşu, 28 Eyl 2026): tarih çizelgesi (Sarı Plan, 10 Mayıs 1940) ve
      Mayıs–Ekim 1940 "Cephenin Çöküşü" durumu
- [x] Teslim olan ülke tutarlı devredilir: işgal edilen eyaletleri işgalcilere geçer, bütün savaşlardan ve (lideri
      değilse) ittifakından çıkar, verdiği garantiler düşer, iki yıl savaş ilan edemez (`Diplomacy.TRUCE_DAYS`); eski
      müttefiklerinin savaşlarına yeniden çekilmez
- [ ] Barış konferansı (basit): kazanan taraf eyaletleri paylaşır

### P2. Oyuncuya geri bildirim
- [ ] Muharebe ayrıntı penceresi (iki taraf, güç, kayıplar, arazi/nehir cezaları)
- [x] Yol önizlemesi ve varış süresi: tümen seçiliyken farenin altındaki bölgeye aynı stilde soluk bir ok çizilir (ilk
      üç tümenin yolu) ve kartı tahmini varışı gösterir (en yavaşı, muharebesiz; `Military.eta`, yürüyüşle aynı hız)
- [x] Filolar için varış süresi (filo seçiliyken fare altındaki kart; `Navy.eta_hours`); filo yol önizlemesi henüz yok
- [◐] "Neden?" ipuçları: istikrar ve iç cephe dökümü, teslim sınırı, yasa şartları, kapalı diplomasi eylemlerinin nedeni,
      kaynak açığı satırları, deniz bölgesine göre deniz hâkimiyeti ✔; kalan: ikmal açığı
- [x] Ctrl ile ülke kartı (lider, ilişki, bizimkine göre renkli göstergeler), başka ülkelerin siyaseti salt okunur
- [ ] Hedefler / ipucu sistemi (ilk 30 dakika için rehber)

### P3. Mikro yönetimi azaltma — ve iyileştirme
- [x] Ordu → cephe atama (C1) — temel hâli bitti; savaş planı okları (C2) sırada
- [x] Komuta zinciri ve seçim paneli: böl, ordu kur, orduya kat/çıkar, doğrudan emir (C3)
- [ ] Takviye/konuşlandırma kuyruğu (oyuncu açarsa), şablon kopyala

### P4. Karar oyuncuda (otomatiklik denetimi) ✔
- [x] Oyuncunun ticareti elle: satıcı seç, +8/−8, iptal; "Otomatik ticaret" yalnız oyuncu açarsa; ödenemeyecek ithalat engellenir (nedeni ipucunda)
- [x] Oyuncunun hava kanatları "Otomatik" kapalı başlar (başlangıçtakiler ve yeni konuşlandırılanlar)
- [x] Tümenler "Son askere kadar" açık başlar: kendiliğinden geri çekilmez; bütünlük bitince yarı güçle savaşır (tümen panelinden kapatılabilir)
- [x] Tarihî baskılar seçenekli olay; seçeneklere şart (`require`), şartsız seçenek kilitli görünür, AI da seçmez
- [x] Her ülke testi (`game/dev/country_check.gd`): oyuncu eylemleri oyunu etkiliyor, oyuncu adına otomatik iş yok
- [x] Otomatik test paketi ve CI: `tests/` (veri bütünlüğü: olay/program/teknoloji/yasa/şablon başvuruları, etki sözlüğü,
      çeviri tablosu), `tools/run_tests.sh`, GitHub Actions; dev betikleri sorun bulunca 1 ile çıkar
- [x] Sistem senaryo testleri (95 test): ekonomi, ticaret, siyaset, diplomasi, kara savaşı, deniz/hava, komutanlar, kayıt/yükleme
      (200 gün, alan alan), belirlenimcilik; bulunan hatalar düzeltildi (oyuncunun düşmanla ticareti, üyenin beyaz barışı,
      yüklemede tercihlerin/bekleyen olayların/siperin kaybı, yüklemede 1936 ticareti, yeni oyunda eski önbellek)
- [x] Oyuncunun ordularına kendiliğinden komutan atanmaz; oyuncunun boş ordusu silinmez; haritadan emir verilen tümeni ordu
      planı geri çekmez
- [x] Arayüzü olup etkisi olmayan özellikler görünür biçimde kilitli (soluk, yasak imleci, nedeni ipucunda): kara/deniz/hava birikimi
- [ ] Yapay zekânın otomatik ticareti savaştığı ülkeden de alıyor (1940 ortasında Almanya ~57, İtalya ~53 kaynak/gün,
      çoğu İngiliz/Fransız sömürgelerinden). Kesmek (abluka) gerçekçi ama Almanya'yı kaynaksız bırakıp denge testinde
      "Fransa 1940–41'de düşer" kontrolünü 4/6'ya indiriyor — abluka + telafi (ör. Sovyet/İsveç/Romanya ticareti) birlikte
      ele alınmalı
- [ ] Yapay zekânın "fırsat kollayıp sonra katılma" kuralı (`Diplomacy.ai_answers_call`) yazılmış ama bağlanmamış
      (ittifak çağrısında İtalya'nın Haziran 1940'ı beklemesi); bağlamak dengeyi değiştirir — karar bekliyor
- [ ] Oyuncu ordusu karadan ayrı cephe parçalarına (ör. Doğu Prusya) kendiliğinden deniz aşırı tümen göndermez
- [x] Hareket ve animasyon mantığı testleri: deniz yolları, filo köşe/liman çıkışı/düzen, tümen yolu sürekliliği, hareket
      okları, hava durumu (belirlenimci; önbellek hatası düzeltildi), zoom kiplerinde sayaç/bayrak/gizli

## BÖLÜM V — OYUN DERİNLİĞİ ◐ ← P ile birlikte sıradaki ana iş
Kendi tasarım hedeflerimiz; kaynak tarih ve kendi denge testimiz (BÖLÜM Ö kuralları). Her madde oyunda nasıl karşılık
bulacağıyla yazıldı.

### V1. Savaş hissi ve muharebe matematiği ◐
- [x] Tümen tecrübesi: Acemi −%25 · Talimli · Pişkin +%25 · Sınanmış +%50 · Seçme +%75; muharebe ile artar,
      kayıpla (yeni asker) düşer; sayaçta yıldız, panelde çubuk
- [x] Hazırlık bonusu: düşmana komşu, bekleyen tümen 15 günde en çok +%20 hazırlık biriktirir; saldırdıkça erir
      (plan çizip beklemek → ilk darbe güçlü; tek tük saldırı zayıf)
- [x] Hava ve mevsim: kış (Ara–Şub, 45°K üstü) saldırı −%9…−%15, kış donanımı yoksa yıpranma; sonbahar çamuru (Eki–Kas,
      Doğu Avrupa) hız −%45; çölde sıcak yıpranması; haritada kış örtüsü (her modda, yamalı)
- [x] Yakıt: taban gelir (sanayi) + petrol → yakıt deposu; zırhlı/motorlu hareket ve muharebe, uçak görevleri, denizdeki
      gemiler tüketir; yakıt yoksa zırhlı/motorlu güç −%35, hız −%50; üst barda yakıt, uyarı
- [x] Araştırma birikimi: boş yuva 30 güne kadar araştırma biriktirir (fazlası kaybolur), yeni araştırmaya aktarılır
- [ ] Kuşatma cezası: çembere alınan birim −%30 (ikmalsizliğe ek); general yakalama (ileride)
- [ ] Muharebe ayrıntı penceresi (P2 ile): iki taraf, genişlik, arazi/nehir/hava/hazırlık/tecrübe/yakıt çarpanları

### V2. Lojistik (B ile birleşir) ☐
- [ ] Trenler ekipman olarak üretilir; demiryolu ağı tren ister (üst barda ihtiyaç/stok)
- [ ] İkmal merkezleri ve demiryolu seviyeleri; kamyonlar merkezden cepheye; ikmal açığı → yıpranma, org düşüşü
- [ ] Tümen ikmal tüketimi şablona göre (lojistik bölüğü −%); ağır tank en çok tüketir
- [ ] Konvoy: deniz aşırı ticaret, ikmal ve asker taşıma konvoy tüketir; üst barda konvoy

### V3. Ordu yapısı ve komuta ◐
- [ ] Tümen şablonları: tabur + destek bölükleri (mühendis, keşif, askerî inzibat, bakım, hastane, lojistik, sinyal,
      topçu, uçaksavar, tanksavar); muharebe genişliği hedefi (düzlük 70 → 35/70 bölen şablonlar)
- [ ] Özel kuvvetler: deniz piyadesi (çıkarma/nehir), dağcı, paraşütçü, ormancı; arazi bonusları
- [x] Generaller ve mareşaller (temel): ülke kadroları (dönemin komutanları + yöresel isimler), beceri 1–5, ordu/grup ataması,
      muharebe katkısı (general beceri × %4, 24 tümene kadar tam; mareşal × %2 bütün gruba), muharebede tecrübe → beceri,
      komuta gücüyle mareşalliğe terfi (30) ve yeni general (15); kayıt/yükleme; `tests/test_commanders.gd`
- [ ] Generallerin **özellikleri**: hücum, savunma, lojistik, planlama değerleri ayrı; tecrübeyle özellik kazanma
      (ör. kuşatma ustası, savunma uzmanı, zırhlı birlik komutanı, kış savaşçısı, dağ harbi); karargâh kapasitesiyle özellik alma
- [ ] Komutan **portreleri** (kullanıcı üretir; prompt listesine eklenecek) ve komutan ayrıntı kartı
- [ ] Tarihî giriş/çıkış: komutanların yıllara göre kadroya girmesi, 1937 Sovyet tasfiyesi (Tukhachevsky, Blyukher, Yegorov),
      emeklilik, muharebede yaralanma/yakalanma/ölüm, kuşatılan ordunun generali esir düşer
- [ ] Komutan başına tümen sınırı ve karargâh (ordu/ordular grubu karargâh sayacı haritada), ordu adı değiştirme
- [ ] Doktrinler: kara, deniz, hava; yapı ve adlar bizim, dönemin gerçek kavramlarından (hareket savaşı, derin harekât,
      metodik muharebe, sızma taktikleri); kara/deniz/hava birikimi ile açılır (üst çubuktaki birikim hücrelerinin kilidi o zaman açılır)
- [ ] Taarruz tavrı: temkinli / dengeli / "ne olursa olsun" (plan saldırganlığı)

### V4. Ekonomi ve siyaset ayrıntıları ◐
- [x] Sivil/askerî fabrika, inşaat, altyapının inşaat hızı bonusu, ticaret yasası (ihracat payı), üretim verimliliği
- [ ] Altyapı eyaletin kaynak çıktısını artırır (seviye başına +%10), eyalet başına bina yuvası teknolojiyle artar
- [ ] Tüketim malları (consumer goods): seferberlik yasası + istikrar → sivil fabrikaların bir kısmı halka gider
- [ ] Kaynak açığında üretim hattı sırası: öndeki hat az, arkadakiler çok ceza
- [ ] Nüfuz birikip boşa gitmesin uyarısı; ülkeye özgü tarihî danışmanlar ve tasarım büroları (tank/uçak/gemi)
- [ ] İstikrar ve iç cephe etkileri: iç cephe zayıflayınca askere alım yavaşlar
- [ ] Barış konferansı: ilhak / kukla / kaynak ve fabrika talebi; kukla haraç öder
- [ ] İşgal yönetimi: direniş ve uyum; işgal yasası (sivil gözetim … askerî yönetim), garnizon ister

### V5. Hava ve deniz derinliği ◐
- [x] Hava üstünlüğü, yakın destek, liman baskını; görsel saldırı turu, bomba
- [ ] Deniz bombardıman uçağı (denizdeki filoya), stratejik bombardıman (fabrika hasarı + onarım), lojistik baskını
- [ ] Hava üssü kapasitesi (seviye başına 200 uçak); fazlası ceza; uçaksavar binası üsse gelen saldırıyı azaltır
- [ ] Filo yapısı: perde gemileri (muhrip/hafif kruvazör) önde, ağır gemiler ve uçak gemileri arkada; perde yetersizse
      ağır gemiler vurulur; hafif atak perdeye, ağır atak büyük gemilere; uçak gemisi sayısı filo başına en çok 4–6
- [ ] Mayınlama; çıkarma teknolojisi (aynı anda çıkarma sayısı); deniz piyadesi bonusu

### V6. Daha sonra
- [ ] İstihbarat ve ajanlar, şifre çözme; atom bombası (teslim sınırını düşürür); füze saldırıları
- [ ] Tank/uçak tasarımcısı (modüller, güvenilirlik, maliyet)

## BÖLÜM B — ULAŞIM VE LOJİSTİK (Faz 12) ◐
Ekonominin ve savaşın omurgası: ikmal, hareket hızı, sanayi ve kaynak taşıma buna bağlı.

### B0. Yollar harita modu (F4) ✔
- [x] Soluk siyasi zemin üstünde: deniz yolu ağı, ticaret yolları (kaynak renginde, ithalatçıya akan dalga;
      sınır komşuları karadan, diğerleri başkent → liman → deniz yolu → liman → başkent), oyuncunun filo
      rotaları (kesikli, kalan km ve varış günü), hava görev hatları
- [x] Üzerine gelince bilgi kartı (mal, mesafe, konvoy karşılaması, düşman deniz bölgesi riski), tıkla-seç vurgusu
- [ ] Kara yolları ve demiryolları aynı moda eklenecek (B1–B2), tren/kamyon ikmal akışı (B3)

### B1. Karayolu ağı
- [ ] Şehir kapılarını (`City.gates`, hazır) birbirine bağlayan yol grafı
- [ ] Yol sınıfları: toprak → şose → asfalt (altyapı seviyesiyle yükselir)
- [ ] Araziye oturan yol çizimi (eğim, nehir, dağ geçidi; köprüler kafes modülüyle)
- [ ] Etki: tümen hızı, kamyon ikmal verimi, inşaat hızı

### B2. Demiryolu ağı
- [ ] 1936 tarihî ana hatlar (Berlin–Varşova–Moskova, Bağdat Demiryolu, Paris–Marsilya…)
- [ ] Demiryolu seviyeleri 1–5; oyuncu İnşaat ekranında çizerek yapar
- [ ] Görsel: ray + travers, istasyonlar, yakın zoom'da **hareket eden trenler**
- [ ] Kapasite → ikmal akışı; bombalama/işgalle hasar ve onarım; zırhlı tren

### B3. İkmal sistemi (modern ikmal modeli: merkez + demiryolu + kamyon)
- [ ] İkmal merkezleri (inşa edilebilir, demiryoluna bağlı)
- [ ] Başkent/limanlar → demiryolu → ikmal merkezi → kamyonlarla cephe
- [ ] Kamyon tüketimi, atlı ikmal
- [ ] Bölge ikmal kapasitesi vs. tüketim → açık: bütünlük/saldırı/yıpranma cezası
- [ ] İkmal harita modu (akış, darboğazlar)
- [ ] Deniz ikmali: konvoylar; denizaltılar konvoy batırır

### B4. Ekonomiye etkisi
- [ ] Kaynaklar demiryoluyla taşınır; bağlantısız kaynak kullanılamaz
- [ ] Fabrika çıktısı ve inşaat hızı ulaşım ağına bağlı
- [ ] Ticaret rotaları (konvoy ihtiyacı), ambargo, abluka

---

## BÖLÜM C — SAVAŞ EKRANI VE KOMUTA (Faz 13) ◐

### C1. Cephe hatları ◐
- [x] Ordular (oyuncu): seçili tümenlerden "Ordu kur", cephe = seçilen ülkeyle sınır (savaştan önce de), Savun / Taarruz,
      orduyu seç, dağıt; tümen panelinde ordu satırı; kayıt/yükleme
- [x] Orduya cephe atama: tümenler cephe boyunca düşman yoğunluğuna göre kendiliğinden dağılır (gereksiz yer değiştirme yok)
- [x] Taarruz: cephedeki tümenler, hattı bozmadan (yan güvenliği), güçlü oldukları komşu düşman bölgelerine ilerler
- [x] Temas hattının çizimi: sınırın tam üstünde, ordu renginde çizgi + düşmana bakan dişler (taarruzda uzun)
- [x] AI büyük güçleri savaşta cephe orduları kullanır: düşman başına ordu, haftalık plan (cephe uzunluğu + düşman gücü
      oranında tümen), başkent garnizonu, cephede %25 güçlüyse taarruz
- [x] Uzak zoom'da sayaç birleştirme: aynı ülkenin yakın sayaçları haritada sabit ızgarayla tek sayaç (toplam tümen),
      yalnız 3 zoom eşiğinde değişir, en büyük yığının yerinde durur (kayma/animasyon yok); tıklayınca grubun tamamı seçilir
- [x] Aynı yerdeki filolar tek sayaç (toplam gemi), zoom'la kayan yan yana sayaç yok
- [x] AI: çakışan cepheler (müttefik düşmanlar) tek orduda; taarruzda yığınak (en zayıf 2 noktaya 3 kat tümen);
      ordu kodu performansı (hedef ülke tamsayı kümesi, karadan ulaşılabilir cephe, günlük emir sınırı): 285 sn → 41 sn
- [x] General atama (V3): Ordu ekranında ve komutan kadrosunda; seçili tümen panelinde ordunun komutanı
- [ ] Ordu sayacı / ordu kartı, harita üzerinde tıklayarak cephe seçme
- [ ] Kuşatma cepleri görsel olarak işaretli

### C2. Savaş planları (oklar) ◐
- [ ] Taarruz oku çizme (sürükleyerek, kıvrımlı), mızrak ucu birlikleri
- [ ] Hazırlık bonusu, planı yürüt/durdur
- [ ] Savunma hattı, tahkimat hattı, deniz çıkarma planı, hava indirme
- [x] Hareket oku: birimin bulunduğu yerden başlar, kesintisiz eğri gövde, kuyrukta incelir,
      çentikli geniş uç, gölge, degrade + kontur + akan parlaklık, kalınlık zoom'a göre; aynı hedefte tek uç
- [ ] İlerleme göstergesi

### C3. Komuta yapısı
- [x] Ordular → Ordu Grupları → Mareşal; generaller (beceri, deneyim); özellikler V3'te
- [x] Ordu paneli: komuta zinciri ağacı, ordu/grup ayrıntısı (komutan, cephe, duruş, grup), tümen listesi (bütünlük, güç,
      durum, konum), tümen aktarma, bağlanmamış tümenler, komutan kadrosu; ☐ ekipman doluluğu
- [x] Mikro yönetim (seçim paneli): sayı ve şablon bileşimi (tıkla: yalnız o tür), yarıya böl, seçilenlerle yeni ordu,
      orduya kat / ordudan çık, **doğrudan emir** (haritadan emir verilen ordu tümeni ordu planının dışında kalır,
      "Ordu planına döndür" ile geri verilir), tümen satırına tıkla = yalnız onu seç
- [x] Tümen deneyimi / veteranlık (V1'de yapıldı)

### C4. Muharebe derinleştirme
- [ ] Muharebe ekranı (iki taraf, genişlik, zarlar, taktikler)
- [ ] Muharebe taktikleri
- [x] Hava durumu ve mevsimler (kış, çamur, çöl sıcağı — V1)
- [ ] Tahkimatlar (Maginot, Metaxas, kıyı tahkimatları)

---

## BÖLÜM D — ATMOSFER VE ARAYÜZ ANİMASYONLARI (Faz 14) ◐

### D1. Savaş izleri
- [ ] Kuşatılan şehirlerde yangın, yıkık bina varyantları, cephe hattında siperler ve krater izleri

### D4. Harita atmosferi
- [x] Kış kar örtüsü (mevsime ve enleme göre, yamalı)
- [ ] Gün/gece döngüsü (şehir ışıkları), mevsim renkleri
- [x] Yağmur/kar parçacıkları (bölgesel, mevsime bağlı, yakın zoom'da; FPS dostu)
- [ ] Sis; liman/fabrika dumanı; trenler

### D5. Arayüz animasyonları
- [x] Yan panel kayma, haber animasyonu
- [ ] Düğme hover/basma animasyonları
- [ ] Olay pencerelerinde dönem illüstrasyonları
- [ ] Savaş ilanı / teslim için sinematik manşet

---

## BÖLÜM E — SES (Faz 14) ✔
- [x] Prosedürel sentez motoru (`tools/audio_synth.py`): dalga tablolu yaylı/bakır/üflemeli, piyano, vurmalılar, salon yankısı, mastering
- [x] Dinamik müzik (`tools/make_music.py`, 7 parça ~16 dk, OGG): menü teması, barış (2), gerginlik, uzak savaş, oyuncunun savaşı (2);
      çapraz kararma, tekrarsız sıra; web yükleme ekranında ana tema (açma/kapama düğmeli)
- [x] Olay müzikleri: oyuncunun savaşı (siren + tutti) ile dünyada savaş farklı; zafer, yenilgi, barış; çalarken müzik kısılır
- [x] Her eylem için ses (`tools/make_audio.py`, 51 efekt, çeşitlemeli): tık/panel/sekme/anahtar/onay damgası, hız ve duraklatma,
      inşaat, üretim hattı, araştırma, odak, ticaret, diplomasi, konuşlandırma, telsizli birlik emirleri
- [x] Bildirim ve bitiş sesleri yumuşak ve kendine özgü; üst üste binmez, sırayla çalar (kuyruk)
- [x] Muharebe ambiyansı (3D, yakın zoom: tüfek, makineli, top, tank, uçak, gemi topu)
- [x] Ayarlar: ana ses, müzik, efekt ve arayüz sesi düzeyi; müzik seçimi (otomatik ya da istenen parça sürekli)
- [ ] İttifak ve barış konferansı sesleri; ses kanalları (bus) ve sıkıştırma

---

## BÖLÜM F — TASARIM DİLİ VE ARAYÜZ (Faz 15) ◐
- [x] Tek tasarım sistemi: metal doku seti (`tools/make_ui_skin.py`), tema varyasyonları, panel şablonu (`PanelLayout`)
- [x] Yeni ikon seti: kullanıcı prompt listesinden (`docs/art/ICON_PROMPTS.md`) üretti, `assets/ui/icons_new/` altında, oyun
      otomatik kullanıyor (web için boyut diyeti açık, bkz. WEB)
- [x] Yan panel şablonu (kapatma düğmesi, tek panel), ortada haberler
- [x] Sekmeli içerik (Ordu), tam ekran ve sürükleyerek kaydırılan ekranlar, tek sayfa araştırma zaman çizelgesi
- [◐] Lider portreleri: yükleyici hazır (üst çubuk, Siyaset, Diplomasi, Ctrl kartı; yoksa bayrak), dosyalar
      `assets/portraits/<TAG>.png` altına gelmeye devam ediyor
- [ ] Eksik 12 ülkenin gerçek bayrağı
- [ ] İç içe ipuçları (terimin üstüne gelince açıklaması)
- [ ] Mini harita; harita modları (ikmal, altyapı, kaynak, ideoloji, ittifak, deniz hâkimiyeti)
- [ ] Bildirim ayarları; arayüz ölçeği

---

## BÖLÜM UI — ARAYÜZ DURUMU (Faz 16) ◐
Bugünkü arayüz ilk sürümlerden kalma bir düzeni izliyor; kendi arayüz kimliğimiz BÖLÜM Ö Katman 2'de tasarlanacak
(yerleşim, kısayollar, ikon ve renk dili). Aşağıdakiler bugün çalışan işlevlerdir.
- [x] Üst çubuk: nüfuz, istikrar, iç cephe, insan gücü, fabrikalar, yakıt, kriz endeksi, tarih/hız
- [x] Üst çubuk (25 Eyl): ikmal doluluğu (ikmalli tümen oranı), konvoylar (stok / ithalat ihtiyacı), komuta gücü
      (+0,3/gün, savaşta +0,5; tavan 200; komuta zincirinde harcanır), kara/deniz/hava birikimi (muharebelerden; tavan 500;
      **henüz harcanmıyor → kilitli**) — kayıt/yüklemeye eklendi
- [x] HUD: bayrak · kompakt gösterge hücreleri (yakıt/ikmal çubuklu) · komuta gücü + birikim grubu; ekranın sol kenarında
      kısayol harfli menü (Q F I O R T Y U N H L) ve uyarı kutuları; yan paneller menünün sağında açılır
- [x] Lojistik ekranı (L): ekipman stok / kullanımda / günlük üretim / ihtiyaç / denge, kaynak üretim-kullanım, fabrika kullanımı
- [x] Ekranlar: Siyaset (lider, parti, pasta, dökümlü göstergeler, yasalar, danışmanlar, ulusal durumlar, kararlar; başka
      ülkeler salt okunur), Devlet Programı ağacı, Araştırma (yuvalar + tek sayfa zaman çizelgesi), Diplomasi, Ticaret (elle
      anlaşma), İnşaat, Üretim, Lojistik, Ordu (komuta zinciri + şablonlar), Donanma, Hava, Eyalet (yuvalar + doğrudan inşa),
      Olay penceresi, duraklatma, oyun sonu, Ayarlar
- [ ] Birikimin harcanacağı yer: **Genelkurmay** ekranı (doktrinler, general özellikleri) — V3/C3
- [ ] Tümen tasarımı ve eğitim: şablon düzenleyici (tabur/destek bölüğü, kara birikimi harcar), takviye/yükseltme önceliği
- [ ] Ayrı Kararlar ekranı, İstihbarat (ajanlar), dünya kaynak pazarı
- [ ] İkmal harita modu (demiryolu/ikmal merkezi) — B3 ile; radar ve tahkimat binaları (kara/kıyı tahkimatı)
- [ ] Savaş sonu: barış konferansı, sürgün hükümetleri, kukla yönetimi
- [ ] İç içe ipuçları

## BÖLÜM M — MEKANİK KAPSAMI ◐
✔ var · ◐ sade hâli var · ☐ yok
| Sistem | Durum | Eksik |
|---|---|---|
| Hükümet: ideoloji, parti, seçim, istikrar, iç cephe | ✔ | darbe, iç savaş, parti ayrılıkları |
| Yasalar (askerlik, ekonomi, ticaret) | ✔ | eğitim / basın / hükümet yasaları |
| Danışmanlar | ◐ | ülkeye özgü tarihî danışmanlar, tasarım büroları (tank/uçak/gemi) |
| Devlet programı | ◐ | 9 ağaç (Türkiye 33 program); diğer ülkeler ortak ağaç; büyük güçlere geniş ağaçlar |
| Olaylar | ◐ | seçenek şartları ✔; tarihî zincirler (İspanya İç Savaşı, Kış Savaşı, Balkanlar, Kuzey Afrika) |
| Kararlar | ◐ | ayrı Kararlar ekranı, kategoriler, süreli görevler |
| İnşaat, üretim, verimlilik | ✔ | ekipman varyantları, lisanslı üretim |
| Ticaret | ✔ | ilişkilerin etkisi, ambargo, dünya kaynak pazarı |
| Araştırma | ✔ | doktrin ağaçları (kara/deniz/hava), bilim insanları |
| Tümen şablonu | ◐ | destek bölükleri, şablon değişimi birikim harcar, takviye önceliği |
| Muharebe | ◐ | taktikler, cephe genişliği ayrıntısı, gece/gündüz, hava durumunun muharebeye etkisi |
| Ordular, cepheler | ◐ | taarruz planı okları; ✔ ordu grupları, generaller (beceri/tecrübe); ☐ general özellikleri |
| Genelkurmay (komuta gücü, birikim harcama) | ◐ | ✔ komuta gücü generallere harcanıyor; ☐ doktrinler (birikim) |
| Lojistik | ◐ | ikmal merkezleri, demiryolu, kamyon, liman kapasitesi, yakıt ayrıntısı |
| Deniz | ◐ | görev bölgeleri, deniz çıkarması planı, üslerin menzili |
| Hava | ◐ | stratejik bombardıman, paraşütçü, hava bölgesi başına üstünlük |
| Diplomasi | ◐ | saldırmazlık paktı, gönüllüler, ödünç verme ve kiralama, ilişkiler, ittifak yönetimi |
| Barış | ◐ | barış konferansı, sürgün hükümetleri, kukla/özerklik |
| İşgal | ☐ | direniş, uyum, garnizon |
| İstihbarat | ☐ | ajanlar, operasyonlar, şifre çözme |
| Kriz endeksi | ✔ | eşikler ideolojiye göre ✔ |
| Modlar | ☐ | senaryo paketleri, bkz. BÖLÜM MOD |

## BÖLÜM MOD — MOD DESTEĞİ ☐
Oyun bir platform olacak: motor (harita, ekonomi, siyaset, savaş, yapay zekâ, arayüz) + senaryo paketleri. 1936 İkinci
Dünya Savaşı ilk senaryodur; başkaları bizden ya da oyunculardan gelebilir (ör. Atatürk'lü alternatif tarih/fantezi,
zombi salgını).
- [ ] Senaryo paketi biçimi: `mods/<ad>/` içinde `data/common/*.json` (ülkeler, yasalar, olaylar, programlar, teknolojiler,
      birimler, komutanlar...), metinler (`strings.csv`), isteğe bağlı harita, ikon, portre, müzik; bildirim dosyası (ad,
      sürüm, açıklama, başlangıç tarihi, temel senaryo)
- [ ] Yükleme sırası ve üzerine yazma (mod temel dosyaları değiştirir ya da genişletir), ana menüde mod listesi
- [ ] Motor metinlerinden 2. Dünya Savaşı varsayımlarının çıkarılması (tarihler, "1936–1945", bitiş tarihi senaryodan)
- [ ] Genel bir oyun adı (2. Dünya Savaşı'na bağlı değil) — bkz. BÖLÜM Ö, Oyun adı
- [ ] Mod yapımcıları için belge (İngilizce + Türkçe) ve doğrulama aracı (`tests/test_data.gd` veri testleri)

## BÖLÜM WEB — TARAYICI SÜRÜMÜ ◐
- [x] GitHub Pages yayını: https://gmmrx.github.io/iron-front/ (`.github/workflows/web.yml`; Compatibility renderer yalnız web'de,
      iş parçacığı desteği kapalı, pck 90 MB parçalara bölünüp `tools/web/shell.html` ile birleştirilir)
- [x] Compatibility renderer farkları çözüldü: sahne sRGB uzayında çizildiği için shader'lar `srgb_out` ile çıkışı çevirir;
      custom_data'lı MultiMesh'lerde renk yuvası sıfır kaldığından instance renkleri beyaz yapılır (yalnız web'de)
- [x] Renkler masaüstüyle aynı: Compatibility'de güneş gölgesi + glow/SSAO/renk ayarı kapalı (GLES3 bunlarla ton eşlemeyi
      LDR son işlemde yapıp aşırı parlatıyor); efekt shader'larında sRGB çıkışı; ölçülen fark 9/255 (SSAO ayrıntısı)
- [x] Web'de bölge ipucu/tıklama (RGBA8 kimlik çözümü düzeltildi)
- [x] Yükleme sayfası İngilizce
- [x] 25 Eyl (akşam) değişiklikleri Compatibility renderer'ında denendi: kara rengi aynı (98/137/114 ↔ 96/139/114), oklar,
      bayraklar ve paneller aynı; deniz web'de biraz açık (önceden de böyleydi)
- [ ] Web'de birim gölgeleri yok (GLES3 gölge geçişi parlaklığı bozduğu için kapalı)
- [ ] Web için varlık diyeti: yükseklik haritası yarım çözünürlük, doku boyutları (yeni ikon ve portreler ~57 MB ekliyor;
      128 px'e düşürülerek alınabilir), ilk yükleme süresi
- [ ] Mobil tarayıcı desteği (bellek), kayıt dosyalarının tarayıcıda kalıcılığı

## BÖLÜM G — PERFORMANS (sürekli) ◐
Hedef: 1080p, orta sistemde **60 FPS**; 5. hızda takılmadan.
- [x] Simülasyon profil araçları (`game/dev/sim.gd`, `--fps` ölçümü; `--prof_every=365` her yıl en pahalı sistemleri yazar)
- [x] Uzun savaşta donanma maliyeti (28 Eyl 2026): görevdeki her filo her saat bütün düşman filolarını tarıyordu (filolar
      çoğaldıkça karesel: donanma görevleri 1941–44'te oyun yılı başına 12 → 22 → 37 → 51 sn) → saatlik konum dizini ve
      görev bölgesi taraması (1944: 7 sn); deniz hâkimiyeti 6 saatte bir kurulur (nakliye 1942'ye kadar 22 → 8 sn);
      mahsur filo günde bir liman arar. 1936–44 ekransız: 560 → 436 sn
- [x] Hava çatışması görevdeki her kanadı her gün diğer bütün kanatlarla karşılaştırıyordu (karesel): kanatlar görev
      bölgesine göre toplanır, yakın bölge çiftleri bir kez ölçülür, sonuç aynı. Tarihî akıştan sonra yapay zekânın filo
      ve hava kanadı sayısına tavan (büyük güç 24 su üstü + 8 denizaltı filosu ve 40 kanat, diğerleri 6 + 2 ve 12; fazla
      gemi filoları büyütür, fazla uçak stokta kalır) — yılda ~60 filo ve ~55 kanat sınırsız artıyordu. 2 Eylül 1945'ten
      önce uygulanmaz: 1940–41'de tavan İngiliz filolarını birleştirip Fransa'nın düşüşünü geciktiriyordu
- [x] AI/ikmal/istatistik önbellekleri; ağaç gölgeleri kapalı; MSAA yerine FXAA; yarım çözünürlük SSAO
- [ ] Sayaç ve etiketleri tek çizim çağrısında toplu çizim (şu an ~2.600 çizim çağrısı)
- [ ] LOD: uzak zoom'da şehir modeli → ikon
- [ ] Simülasyonu ayrı iş parçacığına alma
- [ ] Grafik kalite ayarları menüde

---

## BÖLÜM AÇIK — AÇIK UÇLU OYUN ◐ ← uçtan uca oyundan önce gerekli
Bir strateji oyunu bir tarihte bitmez: **oyuncu bütün dünyayı ele geçirene** ya da **oyuncunun ülkesi tamamen yok
olana** kadar sürer. Bunun kaç yıl süreceği önceden bilinemez; hiçbir şey bir bitiş yılı varsaymamalı.
- [x] Bitiş tarihi yok (`END_DATE` kalktı): zafer = oyuncunun tarafının (oyuncu ve ittifakı) dışında ayakta ülke
      kalmaması; yenilgi = oyuncunun ülkesinin artık olmaması (son eyaleti kaybedildi ya da ilhak edildi). Teslim olup
      elinde toprak kalan oyuncu oynamayı sürdürür. Oyun sonu ekranı nedeni ve tarihi gösterir; zaferden sonra oyuncu
      oynamayı sürdürebilir (zafer kayda geçer, yeniden gelmez). `tests/test_open_game.gd`
- [x] Bitmeyen araştırma: bir dalın tarihî teknolojileri bitince dal iyileştirme seviyeleriyle sürer ("Piyade
      İyileştirmesi I, II, ...", `rep_<dal>_<n>`): maliyet 180 gün, seviye başına +%15; kazanç seviye başına −%15
      (toplamı sınırlı); her seviyenin yılı bir öncekinden bir yıl sonra (1943'ten), yıl cezası iyileştirmeleri tarihî
      ağacın ardında tutar; araştırma çizelgesinin son sütunu; yapay zekâ da araştırır, yalnız seviyenin yılı gelince
      (yıllar önce alınan seviye bir yuvayı yıllarca kilitlerdi) (formül ve gerekçeler
      `data/common/technologies.json` → `repeatable`)
- [ ] Savaş yıllarından sonra üretim ve birlikler: sonraki teçhizat kuşakları tekrarlanabilir araştırma seviyelerini izler
- [x] Tarihî akıştan sonra olaylar ve yapay zekâ: 2 Eylül 1945'ten sonra her ülkeye kurala dayalı, yinelenen olaylar
      gelir (`events.json` içinde `"recur"`: başlangıç, ortalama süre, bekleme, şartlar, karşı taraf olarak komşu) —
      Sınırda Çatışma (savaş gerekçesi: yapay zekâ yeni savaşları böyle bulur), Bankalara Hücum, Subay Komplosu (düşük
      istikrar), Askerler Evine Dönüyor (barıştaki büyük güçler); bu tarihten önce rastgele sayı çekilmez, tarihî akış
      değişmez
- [ ] Daha çok kurala dayalı olay: işgal altındaki topraklarda ayaklanma, gerçek darbe (rejim değişikliği), felaketler,
      sömürge krizleri
- [ ] Uzun oyunda da işe yarayan yasalar, programlar ve kararlar (savaş sonrası yeniden inşa, işgal politikası, büyük bir
      imparatorluğun ekonomisi)
- [ ] Performans ve kayıt boyutu onlarca oyun yılı boyunca kararlı (uzun koşu testi: 30+ oyun yılı)
- [ ] Sabit yıl içermeyen motor metinleri (BÖLÜM MOD'un da parçası: senaryo başlangıç tarihini verir, bitiş tarihini değil)

## BÖLÜM OL — DÜNYA OLAYLARI MENÜSÜ ◐
Dünyada sürekli bir şeyler olur (savaş ilanları, ittifaklar, darbeler, felaketler, başka ülkelerin kararları). Bunlar
oyuncuya bir akış olarak gelmeli; bir kısmına cevap verilebilmeli.
- [x] Solda dünya olayları menüsü (E, `game/ui/world_panel.gd`): dünyada olanlar, en yenisi üstte; ülke bayrağı, tarih,
      tür ve kısa metin; süzgeçler (komşularım, ittifakım, bütün dünya); tıklayınca harita oraya gider. Kayıt
      (`World.world_log`, son 400) kayda geçer; metinler şimdiki dilde yeniden kurulur
- [x] Olaylara tepki: oyuncunun taraf olmadığı bir savaş ilanı (30 gün) ya da ilhak (60 gün) seçenek taşır — kınamak /
      tüfek göndermek / uzak durmak, tanımamak (savaş gerekçesi) / tanımak — bedel, şart ve etkiler var olan etki
      sözlüğünden (`data/common/world_reactions.json`, `game/core/world_react.gd`); demokratik büyük güçler oyuncunun
      saldırısını aynı şekilde kınar
- [x] Yapay zekâ ülkelerinin savaşları, ittifakları, garantileri, teslimleri, ilhakları, barışları, seçimleri, yeni
      liderleri ve büyük güçlerin devlet programları kayıt olur
- [x] Bildirim akışı oyuncunun işlerine (ve büyük güçlerin savaş ve ilhaklarına) ayrılır; dünya menüsü dünyanın geri
      kalanıdır. `tests/test_world_events.gd`
- [ ] Daha çok cevap: gönüllüler, yaptırımlar, kayıttan garanti; darbeler, ayaklanmalar, felaketler kayıt olarak

## BÖLÜM H — İÇERİK DERİNLİĞİ (sürekli) ◐
- [ ] Her büyük güç için geniş devlet programı ağacı, orta güçlere özel ağaçlar
- [ ] Tarihî olay zincirleri (İspanya İç Savaşı, Kış Savaşı, Balkanlar, Kuzey Afrika)
- [ ] Seçimler, darbe, iç savaş
- [ ] Kukla devletler, barış konferansı ekranı, lend-lease, gönüllüler
- [ ] Ekipman tasarımcıları (tank, uçak, gemi)
- [x] Tüm dünya haritası

---

## BÖLÜM I — ÇOK OYUNCULU (Faz 10) ☐
- [ ] Deterministik simülasyon, lockstep ağ modeli, lobi, senkron kontrolü

---

## Önerilen sıra
1. **★ Görünür savaş**: modeller ✔ → kara birlikleri ✔ → donanma ✔ → hava ✔ → efektler ✔ (kalan: sesler,
   geri çekilme/teslim animasyonu, çıkarma planı, stratejik bombardıman, havuzlama)
2. **P** Oynanabilirlik: savaş dengesi (P1, 1939–41 akışı) → savaş planları (C2) → geri bildirim (P2)
3. **B** Ulaşım & lojistik (yollar, demiryolları, trenler, ikmal)
4. **C** Cephe hatlarının kalanı, komuta, muharebe derinliği
5. **D** Atmosfer, **E** ses, **F** tasarım dili (paralel)
6. **H** İçerik, **MOD** mod desteği, **I** çok oyunculu

---

## Mimari
```
data/            → içerik (JSON/CSV), üretilmiş harita dosyaları
tools/           → harita, doku, model (Blender), ses üretim betikleri
game/autoload/   → World, Economy, Politics, Research, Diplomacy, Military, Navy, Air, AI, Game, GameClock, Audio
game/core/       → saf simülasyon sınıfları (Country, StateRegion, Province, Division, Army, ArmyGroup, Commander, Fleet...)
game/map/        → 3D harita, kamera, şehir/ağaç/birim katmanları
game/ui/         → arayüz
game/dev/        → headless test ve simülasyon
tests/           → ekransız test paketi (tests/run.gd koşucu, test_*.gd testler)
assets/          → shader, model, doku, ikon, yazı tipi, ses
docs/            → wiki (docs/wiki İngilizce, docs/wiki/tr Türkçe), özgünlük, bulut görevleri, sanat promptları
```

## Geliştirici araçları
- Test paketi: `tools/run_tests.sh` (içe aktarma + `tests/run.gd` + country_check); CI: `.github/workflows/tests.yml`
  (PR ve main push'ta; denge testi elle tetiklenen ayrı iş)
- Denge testi: `tools/balance_parallel.sh 6` (6 paralel koşu, ~15–20 dk); tek koşu `game/dev/balance.gd`
- Performans: `godot --path . -- --play=GER --run --fps=10`
- Görsel QA (kare dizisi): `-- --play=DEN --war=GER,DEN --focus_battle=150 --speed=1 --shots=8 --every=30 --screenshot=out.png`
- Video: `godot --path . --write-movie out.avi --fixed-fps 30 -- --play=DEN --war=GER,DEN --focus_battle=200 --speed=2
  --film=5 --dolly=320,120` (`--pan=dx,dz`, `--track`, `--hide_ui`); klipler ffmpeg ile birleştirilir → `docs/media/`
