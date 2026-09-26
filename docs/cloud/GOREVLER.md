# Claude Code Cloud görevleri

Her görev ekransız yapılabilir ve testle doğrulanabilir. Ortak kurallar, kurulum ve test komutları kök dizindeki
`CLAUDE.md` içinde (Claude Code onu kendiliğinden okur). Bir görevi vermek için başlığın altındaki metni olduğu gibi yapıştır.
Önerilen sıra: 1 → 2 → 3, sonra kalanlar herhangi bir sırayla. Her görev ayrı PR açar.

---

## 1. Otomatik test paketi ve CI (temel altyapı)
```
Oyunun tamamı için ekransız çalışan bir test paketi kur ve GitHub Actions'a bağla.

1) tests/ klasöründe küçük bir test çatısı (GDScript, `extends SceneTree`): her test dosyası `test_*` fonksiyonları içerir,
   `tests/run.gd` hepsini bulur, çalıştırır, geçen/kalan sayısını ve hataları yazar, hata varsa quit(1).
   Her test `Game.new_game()` + `World.start_game(TAG)` ile temiz başlar.
2) Veri bütünlüğü testleri: data/common/*.json içindeki her başvuru geçerli mi (olay seçenek etkilerindeki ruh/olay/ülke
   kodları, odak önkoşulları ve dışlayıcıları, odak koordinat çakışmaları, teknoloji gereklilikleri, yasa anahtarları,
   şablonlardaki taburlar, ekipman adları, ülke başlangıç ruhları/yasaları). Kodda kullanılan her tr("ANAHTAR") ve
   strings.csv satırı: eksik anahtar yok, her satırda en ve tr dolu, % yer tutucu sayıları iki dilde aynı.
3) tools/run_tests.sh: import + tests/run.gd + country_check (kısa: --days=60) koşar, toplam sonucu yazar.
4) .github/workflows/tests.yml: pull request'lerde ve main'e push'ta Godot 4.7.2 kurar (web.yml'deki gibi, önbellekli),
   --import yapar, tools/run_tests.sh koşar. Denge testini yalnız elle tetiklenen (workflow_dispatch) ayrı bir işe koy.
5) game/dev/gov_check.gd, playtest.gd, sim.gd sorun bulunca quit(1) ile çıksın.

Bitti sayılır: yerelde ve CI'da tests/run.gd yeşil; bilerek bozulan bir veri (ör. olmayan ruh adı) testi kırmızı yapıyor
(PR açıklamasında göster, sonra geri al).
```

## 2. Sistem testleri: oyunun her senaryosu
```
1. görevdeki çatıyı kullanarak oyunun her mekaniği için senaryo testleri yaz. Her test bir davranışı sayıyla doğrular.
En az şunlar:
- Ekonomi: inşaat ilerler ve biter (bina seviyesi artar), yuva sınırı, en az 1 fabrikalık kamu inşaat tabanı;
  üretim hattı verimlilik artışı ve tavanı, kaynak açığında yavaşlama; tüketim malı yasaya ve istikrara göre değişir.
- Ticaret: oyuncu elle anlaşma yapar, kaynak artar; ödenemeyen anlaşma reddedilir; düşmandan alınmaz; otomatik ticaret
  oyuncuda kapalı başlar, AI'da açık; konvoy yetmezse ithalat düşer.
- Siyaset: istikrar ve savaş desteği formülleri (parti katkısı, gerginlik, savaş durumu), yasa şartları, danışman ve karar
  etkileri, süreli ruhun bitmesi, seçim sonucu, tarihli olayların tarihinde gelmesi, şartlı seçeneğin kilitli olması,
  oyuncuya gelen olayın kendiliğinden seçilmemesi (pending_events'te beklemesi).
- Diplomasi: gerekçe süresi ve maliyeti, ideolojiye göre gerginlik eşikleri, savaş ilanında müttefik/garantör katılımı,
  teslim ilerlemesi (başkent +%10, sömürge ¼), teslim sınırı formülü, teslimde eyalet devri, beyaz barış.
- Kara savaşı: muharebe çözümü (saldıran/savunan hasarı), nehir/çıkarma cezası, ikmalsizlik ve yakıtsızlık cezası,
  siper bonusu, "son askere kadar" açık tümenin geri çekilmemesi ve bitince yok olması, kapalıyken geri çekilmesi,
  kuşatılmış tümenin yok olması, ordu → cephe dağılımı.
- Deniz ve hava: filo görev ve dönüş, deniz muharebesi, konvoy baskını; kanat konuşlandırma, oyuncu kanadının
  otomatik kapalı başlaması, hava üstünlüğünün kara muharebesine etkisi.
- Kayıt/yükleme: 200 gün oyna → kaydet → yükle → tüm ülke ve tümen alanları aynı (ticaret anlaşmaları, hold,
  lider, sonraki seçim, olay geçmişi, ruhlar, yasalar, stok, kuyruklar). Fark varsa hangi alan olduğunu yaz.
- Belirlenimcilik: aynı tohumla iki koşu aynı sonucu verir (ya da vermiyorsa nedenini PR'da raporla).

Bulduğun her hatayı ayrı commit'te düzelt ve PR'da listele. Denge testi her kontrolde en az 5/6 kalmalı.
```

## 3. Hareket ve animasyon mantığı testleri (+ gemiler karaya çıkmasın)
```
Görsel sonuç göremezsin ama animasyonların mantığı sayıyla test edilebilir. tests/ altına ekle:
- Deniz yolları: data/map/sea_lanes.json'daki her rota yalnız deniz bölgelerinden geçmeli (data/map/provinces.png +
  provinces.json ile örnekle). Bilinen durum: 62 rota karaya değiyor (en kötüleri 9033-12949, 9295-13269, 10215-13110),
  12 liman–deniz rotası eksik (San Juan, Valparaíso/Viña del Mar, Newcastle...). tools/build_sea_lanes.py'yi düzelt,
  JSON'u yeniden üret, test yeşil olsun.
- Filo hareketi: PathMotion.fleet / sea_pose ile rota boyunca örneklenen her konum suda olmalı (limandan çıkış ve
  rıhtım noktaları dahil). FleetLayer'ın filo grubu konumu ve gemi düzeni (_ship_pos, spread) kıyıda karaya
  taşmamalı: grup konumu karadaysa en yakın su noktasına sabitle. Bunu ekransız test edilebilir bir fonksiyona ayır.
- Kara birlikleri: tümen yolu boyunca konum (PathMotion) komşu bölgeler arasında sürekli (zıplama yok), varışta
  hedef bölgede.
- Hareket okları: UnitLayer._curve/_ribbon geometrisi — düşman hedefte kırmızı, değilse yeşil; uç noktası hedef
  bölgede; üçgen sayısı ve UV aralıkları geçerli.
- Hava durumu: WeatherLayer.weather_at aynı gün ve hücrede belirlenimci; kışın kuzeyde kar, çöl kuşağında yağış az.
- Zoom kipleri: UnitLayer ve FleetLayer — FLAG_MODE altında sayı, üstünde bayrak, HIDE_ALL üstünde hiçbiri
  (düğüm görünürlüklerini sahneyi kurarak kontrol et).

Render/shader/renk değiştirme. Bitti sayılır: tüm yeni testler yeşil, deniz yolu testi 0 kara teması.
```

## 4. İsteğe bağlı: yazılım rendereriyle ekran görüntüsü duman testi
```
Linux'ta xvfb + mesa (llvmpipe) ile oyunu `--rendering-method gl_compatibility` kipinde açıp game/main.gd'deki geliştirici
argümanlarıyla (--play, --panel, --event, --demo_order, --dist, --screenshot, --wait) şu kareleri al: her yan panel açık,
olay penceresi, odak ağacı, 3 zoom seviyesi. Görüntüye bakıp yorum yapamazsın; yalnız şunu doğrula: oyun çökmeden
kareyi yazıyor, script hatası yok, kare tamamen siyah/tek renk değil (piksel varyansı eşiği). tests/screens.sh olarak
ekle ve CI'da elle tetiklenen işe koy; kareleri artifact olarak yükle. Çalışmazsa nedenini PR'da yaz, zorlama.
```

## 5. Tarihî olaylar: orta ve küçük ülkeler, 1937–1941 zincirleri
```
Şu an ilk 150 günde çoğu ülkeye hiç olay gelmiyor. data/common/events.json'a 2–3 gerçek seçenekli, tarihli
("trigger": {tag, from, date, require}) olaylar ekle. Kapsam:
- Orta güçler 1936–39: Avusturya (Anschluss baskısı), Çekoslovakya (Südet/Münih), Polonya (Danzig, Alman talepleri),
  Romanya, Macaristan (Viyana tahkimleri), Yugoslavya (1941 darbesi), Yunanistan (Metaksas, 1940 ültimatomu),
  Arnavutluk (1939 İtalyan işgali), Finlandiya (1939 Sovyet talepleri), Baltık ülkeleri (1939–40 Sovyet ültimatomu),
  Belçika/Hollanda (tarafsızlık), İsveç/İsviçre, İspanya (iç savaşın seyri), Portekiz, Türkiye (Hatay 1938–39).
- Büyük güçlerin 1937–41 zincirleri (Almanya, İtalya, İngiltere, Fransa, SSCB, ABD, Japonya), her birine en az 3 olay.
- Seçenekler gerçek karar olsun (ret / taviz / savaş); gerekiyorsa "require" ile şartlı seçenek; AI ağırlıkları tarihî
  sonucu seçmeye yatkın olsun. Etkiler var olan sözlükten; yeni etki gerekirse apply_effects ve describe_effects'e ekle.
- Her olay için strings/metin iki dilde (olay metinleri JSON içinde tr/en). Resim için ui_theme.gd PAINTED_ALIASES'e
  uygun bir takma ad ekle, tools/make_icon_prompts.py'yi çalıştırıp docs/art/ICON_PROMPTS.md'yi güncelle.
Doğrulama: country_check'te olay sayısı arttı (PR'da önce/sonra tablosu); denge testi her kontrolde en az 5/6;
oyuncuya gelen olay kendiliğinden seçilmiyor. docs/wiki/03_hukumet.md olay tablosunu güncelle.
```

## 6. Milli odak ağaçları: orta güçler ve Türkiye genişletmesi
```
data/common/focuses.json'a Polonya, Romanya, Macaristan, Yugoslavya, Yunanistan, Çekoslovakya, İspanya, Çin için
ülkeye özel ağaçlar (her biri 20–30 odak) ekle; Türkiye ağacını 45+ odağa genişlet (ekonomi, ordu, diplomasi dalları,
birbirini dışlayan dış politika yolları). Var olan etki sözlüğünü kullan; x/y koordinatları çakışmasın; önkoşullar
geçerli olsun; AI ağırlıkları mantıklı. 1. görevdeki veri testleri (varsa) yeşil kalmalı; yoksa odak doğrulamasını
kendin yazıp koş. Odak ikon adları için tools/make_icon_prompts.py'yi çalıştır. Denge testi en az 5/6.
```

## 7. Barış konferansı ve kukla devletler
```
Şu an teslim olan ülkenin işgal edilen eyaletleri işgalciye geçiyor. Bunu seçenekli hâle getir:
- Teslimde kazanan tarafa, katkı (işgal ettiği zafer puanı) oranında pay; oyuncu kazanansa olay penceresi ile seçer:
  ilhak et / kukla devlet kur / çekirdek toprakları geri ver. AI tarihî davranışa yakın seçsin.
- Kukla sistemi: Country'ye overlord alanı; kukla, efendisinin savaşlarına katılır, ittifakına girer, kendi kararlarını
  AI ile verir; kayıt/yükleme; diplomasi panelinde (PanelLayout.row ile) kukla ilişkisi görünür.
- Wiki (06_diplomasi.md) ve ROADMAP güncelle.
Testler: senaryo testleriyle (kukla savaşa katılır, ilhak eyaletleri devreder, geri verme çalışır) doğrula; denge en az 5/6.
```

## 8. Diplomasi derinliği: saldırmazlık paktı, gönüllüler, ödünç verme
```
Diplomacy autoload'a ekle: saldırmazlık paktı (süre, bozma cezası: gerginlik + istikrar), gönüllü tümen gönderme
(iç savaştaki ya da savaştaki bir ülkeye, savaşa girmeden), ödünç verme (ekipman stoğundan başka ülkeye gönderme).
Her eylem: şartlar (ideoloji, gerginlik), siyasi güç bedeli, AI kuralları, kayıt/yükleme, diplomasi panelinde bir satır
(var olan _action kalıbı). Oyuncuya gelen teklifler seçenekli olay olarak gelsin. Senaryo testleri + denge en az 5/6.
Wiki ve ROADMAP güncelle.
```

## 9. İşgal ve direniş
```
İşgal edilen eyaletlerde direniş ve uyum: direniş zamanla artar, garnizon (eyalette bulunan tümen sayısı/gücü) bastırır;
yüksek direniş o eyaletin kaynak ve fabrika çıktısını düşürür ve ikmali bozar; uyum zamanla artar ve katkıyı geri verir.
Veri güdümlü sabitler (JSON), eyalet panelinde bir satır bilgi (PanelLayout.stat), kayıt/yükleme, AI garnizon kuralı.
Senaryo testleri (garnizonsuz eyalette direniş artar, çıktı düşer; garnizon bastırır). Denge en az 5/6.
```

## 10. Subay Heyeti: doktrinler ve generaller (arka uç)
```
Komuta gücü ve kara/deniz/hava tecrübesinin harcanacağı sistem:
- Doktrinler: data/common/doctrines.json — üç kol (kara/deniz/hava), her kolda 3 okul, her okulda 6–8 kademe; kademe
  tecrübe ile alınır ve modifier verir (var olan c.mod() sözlüğü: attack/defense/org/speed/planning...).
- Generaller: ülke başına başlangıç generalleri (veri), özellik ve seviye; orduya atanır, ordunun tümenlerine bonus;
  muharebe kazandıkça tecrübe; atama komuta gücü harcar.
- Arayüz: var olan PanelLayout yardımcılarıyla sade bir "Subay Heyeti" paneli (kısayol boş bir harfe), yeni stil yok.
- Kayıt/yükleme, AI (doktrin seçimi, general ataması), wiki (05_savas.md) ve ROADMAP.
Senaryo testleri: doktrin alınca modifier uygulanıyor, general bonusu muharebeye yansıyor. Denge en az 5/6.
```

## 11. Hava durumu ve gün/gece muharebeye etkisi
```
WeatherLayer.weather_at'in belirlenimci hava kararını görsel katmandan bağımsız bir yardımcıya (ör. autoload fonksiyonu)
taşı ki simülasyon da kullanabilsin; görsel katman aynı sonucu kullanmaya devam etsin (görüntü değişmemeli).
Muharebeye etkisi: yağmur saldırı −%10 ve hava görevleri −%30, kar saldırı −%20 ve hız −%25 (veri güdümlü sabitler).
Gün/gece: gece saldırı cezası (−%25), gece hava görevi yok. Muharebe ipucu/panelinde neden gösterilsin (metin).
Senaryo testleri + denge en az 5/6; wiki 05_savas.md.
```

## 12. Yapay zekâ iyileştirmesi (ölçülebilir)
```
AI (game/autoload/ai.gd) şunları mantıklı kullansın: yasalar (savaş desteğine göre askerlik/ekonomi), danışmanlar,
kararlar, ticaret yasası, inşaat önceliği (sivil → askeri geçişi zamanı), araştırma önceliği, konvoy üretimi.
Ölçüt: game/dev/sim.gd'ye 1939-09 ve 1941-06 anlık görüntüsü ekle (büyük güçlerin fabrika sayısı, tümen sayısı,
insan gücü, yasalar) ve PR'da önce/sonra tablosu ver. Tarihî değerlere yaklaşmalı; denge testi en az 5/6 (tercihen 6/6).
Oyuncunun ülkesine AI müdahale etmemeli (bunu test et).
```

## 13. Stratejik bombardıman ve deniz çıkarması planı (arka uç)
```
- Hava kanadı görevi "stratejik bombardıman": hedef bölgedeki fabrika ve altyapıya hasar (onarım inşaat kuyruğu ister),
  uçaksavar ve avcılar kayıp verdirir.
- Deniz çıkarması: oyuncu/AI bir kıyı bölgesine çıkarma planlar; hazırlık süresi, deniz üstünlüğü şartı, çıkarma cezası
  (Military.amphibious_attack), başarısızsa kayıp.
Veri güdümlü sabitler, kayıt/yükleme, AI kuralları, var olan panellere birer satır/görev düğmesi (yeni stil yok).
Senaryo testleri + denge en az 5/6. Wiki ve ROADMAP güncelle.
```

## 14. Simülasyon performansı
```
game/dev/sim.gd ile günlük tik süresini profil et (GameClock.timed zaten bölüm bölüm ölçüyor). En pahalı 3 bölümü
davranışı değiştirmeden hızlandır (ör. Economy._run_trade O(n²) satıcı sıralaması, AI döngüleri, ikmal hesabı önbelleği).
Ölçüt: 1936–1942 simülasyon süresi en az %30 kısalmalı; denge testi sonuçları istatistiksel olarak aynı kalmalı
(12 kontrol, en az 5/6); country_check yeşil. PR'da önce/sonra süre tablosu.
```

## 15. Wiki sayıları veriden otomatik
```
tools/make_wiki.py: docs/wiki sayfalarındaki tabloları (yasalar, danışmanlar, kararlar, binalar, olaylar, ülkeler, ruhlar)
data/common/*.json ve oyun sabitlerinden üretsin; elle yazılmış metin bölümlerine dokunmasın (işaretli bloklar arası
yeniden yazılsın). 1. görevin CI işine "wiki güncel mi" kontrolü ekle (üretilen çıktı ile dosya farklıysa kırmızı).
```
