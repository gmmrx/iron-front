# Yol Haritası — "Iron Front" (çalışma adı)

2. Dünya Savaşı büyük strateji türünün en iyileri ölçeğinde, Godot 4.7 ile yapılan büyük strateji oyunu.
Başlangıç: **1 Ocak 1936**. Harita: Avrupa, Kuzey Afrika, Orta Doğu, Batı SSCB (sonra tüm dünya).

İlke: **veri güdümlü mimari** — içerik `data/` altında JSON/CSV; motor kodu içerikten bağımsız.
Hedef: **en yakın zoom'da bile AAA görüntü, 60 FPS**, oynanış derinliği türün en iyileri seviyesinde.

Durum: ✔ bitti · ◐ temel hâli var, derinleşecek · ☐ yapılmadı
Son güncelleme: **25 Eylül 2026**

### Şu an nerede? (özet)
- Tüm dünya haritası, 80 ülke, 1936 ekonomisi ve tarihî akış (Polonya → Fransa → Barbarossa → Pasifik) çalışıyor.
- Savaş **görünür**: 3D piyade/tank/top figürleri yürüyüp ateş ediyor; filolar deniz yollarında seyrediyor, uçak kanatları
  görev bölgesinde tur atıp dalıp bombalıyor; muharebe efektleri (namlu alevi, patlama, duman, su sütunu) var.
- Komuta: oyuncu ve AI orduları cepheye atıyor; temas hattı dişli çizgiyle çiziliyor; uzak zoom'da sayaçlar birleşiyor.
- Derinlik: tümen tecrübesi, planlama bonusu, kış/çamur, yakıt, araştırma birikimi eklendi.

### Sıradaki işler (öncelik sırasıyla)
1. **P1** 1939–41 akışının tutarlılığı (anavatan savunması, teslim formülü) — otomatik denge testiyle
2. **C2** Savaş planı okları (taarruz oku çiz, planlama bonusu, yürüt/durdur) + **C1** ordu kartı ve general atama
3. **P2** Muharebe ayrıntı penceresi ve "neden?" ipuçları
4. **★5/E** Zoom'a göre muharebe sesleri; **★2** geri çekilme / teslim animasyonu
5. **V2/B** Lojistik: trenler, ikmal merkezleri, demiryolu

---

## BÖLÜM A — TAMAMLANAN TEMEL (Faz 0–9)

| Faz | Konu | Durum |
|---|---|---|
| 0 | Proje, harita üretim hattı, kamera, saat, temel arayüz | ✔ |
| 1 | 3D harita, kabartma, nehir/göl/boğaz, şehirler, ülke adları | ✔ (tüm dünya ✔, bkz. W) |
| 2 | Ekonomi: fabrikalar, inşaat, kaynaklar, ticaret, üretim hatları, yasalar | ✔ |
| 3 | Siyaset: odak ağaçları, olaylar, ruhlar, danışmanlar, kararlar | ◐ |
| 4 | Araştırma: 33 teknoloji, slotlar, yıl cezası | ◐ |
| 5 | Kara savaşı: tümenler, A*, muharebe, kuşatma, basit ikmal, ordular/cepheler (C1) | ◐ |
| 6 | Hava (gerçek kanatlar, ★4) & deniz (gerçek filolar, deniz yolları, ★3) | ◐ |
| 7 | Diplomasi: gerekçe, savaş, ittifak, garanti, teslim, barış | ◐ |
| 8 | Yapay zekâ: ekonomi + cephe + tarihî akış | ◐ |
| 9 | Kaydet/yükle (ordular dâhil), menüler, ayarlar, temel sesler | ◐ |
| 10 | Çok oyunculu | ☐ |

---

## BÖLÜM W — TÜM DÜNYA ✔ (Faz 11c)
- [x] Miller silindirik projeksiyon (türün klasiklerindeki gibi), 16384 px; dikiş Bering Boğazı'nda, komşuluk dikişten sarmalanır
- [x] Değişken bölge yoğunluğu: Avrupa ayrıntılı; Doğu Asya/Hindistan 2–2,5x, Sibirya/Afrika/okyanus 5x
      → 13.414 bölge (8.812 kara, 1.901 ada, 2.134 deniz, 567 göl), 1.652 eyalet, 1.847 şehir
- [x] Dünya yükseltisi (Terrarium z5 + Avrupa z6), enleme göre kar çizgisi, güney yarıküre biyomları
- [x] 1936 siyasi durumu: 80 ülke, bütün sömürge imparatorlukları, dominyonlar, Mançukuo, Çin savaş ağaları
- [x] Dünya ekonomisi (ABD, Japonya, Çin, Hindistan...), gerçek yataklar (Malaya kauçuğu, Teksas petrolü...)
- [x] Coğrafi mesafe (büyük daire) ile hareket, yol bulma, deniz bölgeleri, hava menzili
- [x] Bellek bütçesi (~750 MB): 16 bit bölge dokusu, yarım çözünürlük SDF/arazi, 128 parçalı harita ağı
- [x] Kamera: görüş alanı hiçbir zoom'da haritadan taşmaz (kenar boşluğu yok); en uzak zoom tüm dünya; bulut yok
- [x] Asya odakları: Japonya (Marco Polo 1937, Üçlü Pakt, Güneye Saldırı 1941), ABD, Çin
- [x] Sömürge nüfusu insan gücüne %15 katılır (türün klasiklerindeki gibi)
- [x] Almanya Balkan/Barbarossa ve İtalya Yunanistan odakları Fransa savaşı bitmeden açılmaz
- [x] Dünya denge testi 12 kontrol ≥5/6: Polonya 1940-02, Fransa 1940 Tem–Eyl, Barbarossa 1941-09,
      Japonya–Çin 1937-08, Pasifik Savaşı 1941-12, Çin/İngiltere/SSCB ayakta
- [x] Doğu–batı kesintisiz kaydırma: dikişte harita kopyası, kamera sarmalanır, dikiş çizgisi/karartma yok
- [x] Messina / Küçük Belt / Panama kanalları (harita yeniden üretimi; 11 boğaz, Manş karadan geçilmez)
- [ ] Diğer büyük güçler için ayrıntılı odak ağaçları (ABD, Japonya, Çin genişletilecek)

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
- [x] Deniz muharebesi: saatlik ateş/hasar, denizaltı tespiti, organizasyon, geri çekilme, batan gemiler
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
- [x] Aynı yerdeki filolar/tümenler tek temsilci grup (en çok 3 gemi / 1 tümen düzeni), sayı sayaçta
- [x] Konvoy / ticaret rotalarının haritada görünmesi (Yollar modu)

### ★4. Hava kuvvetleri (sistem + görünüm) ◐
- [x] Hava kanadı birimi (`Air` + `AirWing`): avcı / yakın destek / bombardıman kanatları hava üslerinde (100 uçak)
- [x] Görevler bölge başına (≈350 km, menzil kontrollü): hava üstünlüğü, yakın hava desteği, liman baskını
- [x] Günlük it dalaşı + uçaksavar kayıpları; bölgesel hava üstünlüğü ve yakın destek kara muharebesine bonus
- [x] AI: en sıcak cepheye üs değiştirir ve görev verir; oyuncu kanatları "Otomatik" ile AI'a bırakılabilir
- [x] Hava paneli (H): kanat kur (stoktan, seçilen üsse), görev, bölge seçimi, otomatik mod, takviye, dağıt
- [x] türün klasiklerindeki gibi: oyuncunun ürettiği uçaklar stokta bekler, elle kanat olarak konuşlandırılır
- [x] Görünüm: üslerde park etmiş uçaklar, görev bölgesi üstünde V düzeninde tur atan filolar,
      it dalaşı (iz mermisi), düşen uçak, yakın destek bombaları + yer patlamaları
- [x] Deniz aşırı harekette tümen nakliye gemisi olarak görünür
- [ ] Stratejik bombardıman (fabrika hasarı), üs kapasitesi cezası, şehir üstünde uçaksavar ateşi

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
- [x] Üst görev çubuğu kare simge düğmeleri + kare uyarı şeridi (olay, boş araştırma, odak, boş fabrika/tersane,
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
- [x] Otomatik denge testi (paralel, ~3,5 dk): `tools/balance_parallel.sh 6`
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
- [ ] 1939–41 akışı tutarlı olmalı (sıradaki): anavatan savunması / cephe atama (C1) ile birlikte çözülecek: şu an simülasyonların bir kısmında Almanya Şubat 1940'ta, İngiltere
      Haziran 1940'ta teslim oluyor (donanmadan bağımsız, eski sürümde de var) → teslim formülü, AI saldırı
      yoğunluğu, sömürge ağırlığı, ikmal etkisi ayarlanacak; 10 simülasyonluk otomatik denge testi
- [ ] Teslim olan ülkenin savaşları ve toprakları tutarlı devredilsin (teslim olan ülke savaş ilan edemesin)
- [ ] Barış konferansı (basit): kazanan taraf eyaletleri paylaşır

### P2. Oyuncuya geri bildirim
- [ ] Muharebe ayrıntı penceresi (iki taraf, güç, kayıplar, arazi/nehir cezaları)
- [ ] Tümen/filo seçilince yol önizlemesi ve varış süresi
- [ ] "Neden?" ipuçları: teslim ilerlemesi, ikmal açığı, konvoy açığı, deniz hâkimiyeti
- [ ] Hedefler / ipucu sistemi (ilk 30 dakika için rehber)

### P3. Mikro yönetimi azaltma
- [x] Ordu → cephe atama (C1) — temel hâli bitti; savaş planı okları (C2) sırada
- [ ] Otomatik takviye/konuşlandırma kuyruğu, şablon kopyala

## BÖLÜM V — REHBER VİDEOLARINDAN OYUN DERİNLİĞİ ◐ ← P ile birlikte sıradaki ana iş
Kaynak: `game-tutorial-yt1-turkish.txt` (sistemlerin ayrıntılı anlatımı) ve `game-tutorial-yt2-english.txt`
(Almanya ile açılış: araştırma, inşaat kuralı, üretim, odak). Her madde oyunda nasıl karşılık bulacağıyla yazıldı.

### V1. Savaş hissi ve muharebe matematiği ◐
- [x] Tümen tecrübesi: Yeşil −%25 · Eğitimli · Düzenli +%25 · Kıdemli +%50 · Seçkin +%75; muharebe ile artar,
      kayıpla (yeni asker) düşer; sayaçta yıldız, panelde çubuk
- [x] Planlama bonusu: düşmana komşu, bekleyen tümen 15 günde en çok +%20 planlama biriktirir; saldırdıkça erir
      (plan çizip beklemek → ilk darbe güçlü; tek tük saldırı zayıf)
- [x] Hava ve mevsim: kış (Ara–Şub, 45°K üstü) saldırı −%9…−%15, kış donanımı yoksa yıpranma; sonbahar çamuru (Eki–Kas,
      Doğu Avrupa) hız −%45; çölde sıcak yıpranması; haritada kış örtüsü (her modda, yamalı)
- [x] Yakıt: taban gelir (sanayi) + petrol → yakıt deposu; zırhlı/motorlu hareket ve muharebe, uçak görevleri, denizdeki
      gemiler tüketir; yakıt yoksa zırhlı/motorlu güç −%35, hız −%50 ("petrol yoksa eğlence de yok"); üst barda yakıt, uyarı
- [x] Araştırma birikimi: boş yuva 30 güne kadar araştırma biriktirir (fazlası kaybolur), yeni araştırmaya aktarılır
- [ ] Kuşatma cezası: çembere alınan birim −%30 (ikmalsizliğe ek); general yakalama (ileride)
- [ ] Muharebe ayrıntı penceresi (P2 ile): iki taraf, genişlik, arazi/nehir/hava/planlama/tecrübe/yakıt çarpanları

### V2. Lojistik (B ile birleşir) ☐
- [ ] Trenler ekipman olarak üretilir; demiryolu ağı tren ister (üst barda ihtiyaç/stok)
- [ ] İkmal merkezleri ve demiryolu seviyeleri; kamyonlar merkezden cepheye; ikmal açığı → yıpranma, org düşüşü
- [ ] Tümen ikmal tüketimi şablona göre (lojistik bölüğü −%); ağır tank en çok tüketir
- [ ] Konvoy: deniz aşırı ticaret, ikmal ve asker taşıma konvoy tüketir; üst barda konvoy

### V3. Ordu yapısı ve komuta ☐
- [ ] Tümen şablonları: tabur + destek bölükleri (mühendis, keşif, askerî inzibat, bakım, hastane, lojistik, sinyal,
      topçu, uçaksavar, tanksavar); muharebe genişliği hedefi (düzlük 70 → 35/70 bölen şablonlar)
- [ ] Özel kuvvetler: deniz piyadesi (çıkarma/nehir), dağcı, paraşütçü, ormancı; arazi bonusları
- [ ] Generaller ve mareşaller: özellikler (hücum, savunma, lojistik, planlama), seviye; komuta gücü (command power)
      ile özellik alma; ordu → cephe atama (C1), savaş planı okları (C2) ile birlikte
- [ ] Doktrinler: kara (Seyyar Harp / Üstün Ateş Gücü / Büyük Savaş Planı / Toplu Hücum), deniz, hava;
      ordu/donanma/hava tecrübesi ile açılır
- [ ] Taarruz tavrı: temkinli / dengeli / "ne olursa olsun" (plan saldırganlığı)

### V4. Ekonomi ve siyaset ayrıntıları ◐
- [x] Sivil/askerî fabrika, inşaat, altyapının inşaat hızı bonusu, ticaret yasası (ihracat payı), üretim verimliliği
- [ ] Altyapı eyaletin kaynak çıktısını artırır (seviye başına +%10), eyalet başına bina yuvası teknolojiyle artar
- [ ] Tüketim malları (consumer goods): seferberlik yasası + istikrar → sivil fabrikaların bir kısmı halka gider
- [ ] Kaynak açığında üretim hattı sırası: öndeki hat az, arkadakiler çok ceza (türün klasiklerindeki gibi sıralı)
- [ ] Siyasi güç 200'de birikmesin uyarısı; danışmanlar ve şirketler (tasarımcılar: tank/uçak/gemi bonusu)
- [ ] İstikrar ve savaş desteği etkileri: savaş desteği <50 → teslim sınırı düşer, askere alım yavaşlar
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
- [ ] İstihbarat ve ajanlar, kripto; atom bombası (teslim sınırını düşürür); trenle hava/füze saldırıları
- [ ] Tank/uçak tasarımcısı (modüller, güvenilirlik, maliyet)

## BÖLÜM B — ULAŞIM VE LOJİSTİK (Faz 12) ◐
Türün klasiklerinde ekonominin ve savaşın omurgası: ikmal, hareket hızı, sanayi ve kaynak taşıma buna bağlı.

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
- [ ] Bölge ikmal kapasitesi vs. tüketim → açık: organizasyon/saldırı/yıpranma cezası
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
- [ ] Ordu sayacı / ordu kartı, harita üzerinde tıklayarak cephe seçme, general atama (V3)
- [ ] Kuşatma cepleri görsel olarak işaretli

### C2. Savaş planları (oklar) ◐
- [ ] Taarruz oku çizme (sürükleyerek, kıvrımlı), mızrak ucu birlikleri
- [ ] Planlama bonusu, planı yürüt/durdur
- [ ] Savunma hattı, tahkimat hattı, deniz çıkarma planı, hava indirme
- [x] klasik strateji tarzı hareket oku: birimin bulunduğu yerden başlar, kesintisiz eğri gövde, kuyrukta incelir,
      çentikli geniş uç, gölge, degrade + kontur + akan parlaklık, kalınlık zoom'a göre; aynı hedefte tek uç
- [ ] İlerleme göstergesi

### C3. Komuta yapısı
- [ ] Ordular → Ordu Grupları → Mareşal; generaller (yetenek, özellik, deneyim)
- [ ] Ordu paneli: tümen listesi, ekipman doluluğu, ikmal durumu
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
- [ ] Yağmur/kar parçacıkları, sis; liman/fabrika dumanı; trenler

### D5. Arayüz animasyonları
- [x] Yan panel kayma, haber animasyonu
- [ ] Düğme hover/basma animasyonları
- [ ] Olay pencerelerinde dönem illüstrasyonları
- [ ] Savaş ilanı / teslim için sinematik manşet

---

## BÖLÜM E — SES (Faz 14) ◐
- [x] Temel sesler: arayüz tıkları, savaş ilanı, muharebe başlangıcı
- [ ] Her eylem için ses: seçim/emir (asker onayı), inşaat, araştırma bitişi
- [ ] Muharebe ambiyansı (zoom'a göre silah, top, tank, uçak sesleri)
- [ ] Haber sesleri: savaş ilanı (basit var), teslim, ittifak
- [ ] Dinamik müzik: barış / gerginlik / savaş / zafer / yenilgi
- [ ] Ayrı ses kanalları (müzik / efekt / arayüz)

---

## BÖLÜM F — TASARIM DİLİ VE ARAYÜZ (Faz 15) ◐
- [ ] Tek tasarım sistemi: renk paleti, tipografi ölçeği, boşluk, ikon seti, panel şablonu
- [x] Yan panel şablonu (kapatma düğmesi, tek panel), ortada haberler
- [ ] Sekmeli içerik, kaydırma; lider portreleri; eksik 12 ülkenin gerçek bayrağı
- [ ] İpucu içinde ipucu (türün klasiklerindeki gibi)
- [ ] Mini harita; harita modları (ikmal, altyapı, kaynak, ideoloji, ittifak)
- [ ] Bildirim ayarları; arayüz ölçeği

---

## BÖLÜM G — PERFORMANS (sürekli) ◐
Hedef: 1080p, orta sistemde **60 FPS**; 5. hızda takılmadan.
- [x] Simülasyon profil araçları (`game/dev/sim.gd`, `--fps` ölçümü)
- [x] AI/ikmal/istatistik önbellekleri; ağaç gölgeleri kapalı; MSAA yerine FXAA; yarım çözünürlük SSAO
- [ ] Sayaç ve etiketleri tek çizim çağrısında toplu çizim (şu an ~2.600 çizim çağrısı)
- [ ] LOD: uzak zoom'da şehir modeli → ikon
- [ ] Simülasyonu ayrı iş parçacığına alma
- [ ] Grafik kalite ayarları menüde

---

## BÖLÜM H — İÇERİK DERİNLİĞİ (sürekli) ◐
- [ ] Her büyük güç için tam odak ağacı (100+ odak), orta güçlere özel ağaçlar
- [ ] Tarihî olay zincirleri (İspanya İç Savaşı, Kış Savaşı, Balkanlar, Kuzey Afrika)
- [ ] Seçimler, darbe, iç savaş
- [ ] Kukla devletler, barış konferansı ekranı, lend-lease, gönüllüler
- [ ] Ekipman tasarımcıları (tank, uçak, gemi)
- [ ] Tüm dünya haritası

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
6. **H** İçerik, **I** çok oyunculu

---

## Mimari
```
data/            → içerik (JSON/CSV), üretilmiş harita dosyaları
tools/           → harita, doku, model (Blender), ses üretim betikleri
game/autoload/   → World, Economy, Politics, Research, Diplomacy, Military, Navy, AI, Game, Audio
game/core/       → saf simülasyon sınıfları (Country, StateRegion, Province, Division, Fleet...)
game/map/        → 3D harita, kamera, şehir/ağaç/birim katmanları
game/ui/         → arayüz
game/dev/        → headless test ve simülasyon
assets/          → shader, model, doku, ikon, yazı tipi, ses
```

## Geliştirici araçları
- Denge testi: `tools/balance_parallel.sh 6` (6 paralel koşu, ~3,5 dk); tek koşu `game/dev/balance.gd`
- Performans: `godot --path . -- --play=GER --run --fps=10`
- Görsel QA (kare dizisi): `-- --play=DEN --war=GER,DEN --focus_battle=150 --speed=1 --shots=8 --every=30 --screenshot=out.png`
- Video: `godot --path . --write-movie out.avi --fixed-fps 30 -- --play=DEN --war=GER,DEN --focus_battle=200 --speed=2
  --film=5 --dolly=320,120` (`--pan=dx,dz`, `--track`, `--hide_ui`); klipler ffmpeg ile birleştirilir → `docs/media/`
