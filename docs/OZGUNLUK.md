# Özgünlük ve fikrî mülkiyet politikası

Bu sayfa bu depoda çalışan herkes (insan ya da yapay zekâ ajanı) içindir. Her işten önce okunur.
Hukuki tavsiye değildir; ticari yayından önce bir fikrî mülkiyet avukatına gösterilir.

## Neden var?
Oyunun ilk sürümleri, türün en bilinen ticari oyunu örnek alınarak yapıldı. Sistemlerin yanı sıra adlar, sayı tabloları,
terimler ve ekran düzeni de büyük ölçüde oradan geliyordu. Bu dava riski doğurur:

- **Telif** oyun kurallarını ve mekaniği korumaz; **ifadeyi** korur. İfade; adlar, metinler, görseller, arayüz görünüşü ve
  sistemli kopyalanmış veri tablolarıdır.
- **Haksız rekabet** (Türkiye'de TTK m.55): başkasının emek ürününü kendi katkısı olmadan almak.
- **Arayüz görünüşü**: ekran düzeninin, ikonların ve akışın bütünü.
- **Marka**: oyunun adı ve ayırt edici terimler.

Hedef: **oynanış (fikirler) kalır, ifade bizim olur.** Fabrika kurmak, tümen yürütmek, ideoloji, istikrar, cephe hattı
türün ortak fikirleridir; bunlar serbest. Başka bir oyunun kendine özgü adı, cümlesi, sayısı ve düzeni serbest değil.

## Kurallar
1. **Temiz oda.** Başka bir oyunun dosyası, wikisi, ekran görüntüsü, rehber videosu ya da video dökümü kaynak olarak
   kullanılmaz. Oradan ad, metin, değer ya da ekran düzeni alınmaz; "aynısı olsun" diye iş tanımı yazılmaz.
2. **Kaynaklarımız:** gerçek tarih (yasalar, kurumlar, kişiler, olaylar, üretim ve ordu istatistikleri), kendi tasarım
   hesabımız ve testlerimiz (denge testi, senaryo testleri).
3. **Adlar** ya tarihî gerçek adlardır (gerçek kanun, kurum, kişi, silah) ya da bizim uydurduğumuz adlardır. Türün genel
   kelimeleri (fabrika, tümen, istikrar, insan gücü, ideoloji) kullanılabilir. Başka bir oyunun kendine özgü adı
   kullanılmaz (ör. yasa basamaklarının, milli ruhların, danışman arketiplerinin, teknoloji ve doktrin adlarının uydurma
   adları).
4. **Sayılar** bizim formüllerimizden ve tarihî veriden türetilir. Gerekçe ilgili JSON'un `_comment` alanına ya da
   wikiye yazılır. Başka bir oyunun tablosundan bire bir değer alınmaz; tek tük rastlantı sorun değil, sistemli benzerlik
   sorundur.
5. **Arayüz:** yeni ekranlar kendi akışımızla tasarlanır. "Şu oyundaki ekranın aynısı" hedeflenmez. Ekranların bütünü
   (yerleşim, kısayollar, ikon dili, renkler) kendi kimliğimizi taşır.
6. **Yazı dili:** kodda, yorumda, belgede ve commit mesajında başka bir oyun ne adıyla ne örtmeceyle anılır.
   "Türün klasiği gibi", "X ile parite", "klasik değerler" gibi ifadeler kullanılmaz. Bir tasarım hedefi kendi gerekçesiyle
   yazılır ("oyuncu cepheyi tek bakışta görsün" gibi).
7. **Varlıklar** (harita verisi, bayrak, model, ses, yazı tipi) yalnız lisansı belli kaynaklardan gelir. Her yeni kaynak
   `THIRD_PARTY_LICENSES.md`'ye eklenir.
8. **Oyunun adı:** "Iron Front" bir **çalışma adıdır**. Aynı adı taşıyan, 2. Dünya Savaşı konulu ticari bir bilgisayar
   oyunu ve bir mobil oyun yayında; ad ayrıca 1930'ların gerçek bir siyasi örgütünün adıdır. Yayın ya da satıştan önce ad
   değişecek. Yeni ad; TÜRKPATENT, EUIPO, USPTO ve WIPO marka veri tabanlarında (Nice sınıfları 9, 28, 41), mağazalarda ve
   alan adlarında aranmadan kullanılmaz. Oyun içinde ad yalnız `GAME_TITLE` çeviri anahtarından okunur; ad değişince
   ayrıca `project.godot` (`config/name`) ve `tools/web/shell.html` güncellenir.

## Farklılaştırma planı
Durum: ✔ bitti · ◐ başladı · ☐ yapılmadı

### Katman 1 — İfade (veri ve metin; bulutta test edilebilir)
- ✔ Kendi terim sözlüğümüz (EN + TR): nüfuz, iç cephe, kriz endeksi, devlet programı, ulusal durum, karargâh kapasitesi,
  kara/deniz/hava birikimi; personel/tanksavar ateşi, şok, bütünlük, cephe genişliği, hazırlık; savaş gerekçesi (casus belli);
  tümen tecrübesi: Acemi → Talimli → Pişkin → Sınanmış → Seçme
- ✔ Yasalar: 6 askerlik (antlaşmayla sınırlı ordu → kitlesel celp), 4 ekonomi (barış ekonomisi → topyekûn savaş), 4 dış ticaret
  (açık pazar, kliring, otarşi, dış ticaret tekeli); başlangıç yasaları tarihe göre
- ✔ Danışmanlar: gerçek devlet makamları (Başbakanlık Müsteşarı, Planlama Komiseri, Silahlanma Bakanı...)
- ✔ Ulusal durumlar: uydurma adlar tarihî olgularla değişti (Reformlara Direnç, Moskova Duruşmaları, Barış Oylaması, Kısa Ömürlü
  Kabineler, Laval'in Deflasyon Kararnameleri, Saray Kamarillası, Südet Almanları Meselesi...)
- ✔ Teknoloji adları tarihî kavramlarla; ortak devlet programları kendi adlarımız ve 6–12 haftalık sürelerle
- ✔ Sayılar kendi ölçeğimizde: inşaat fabrika-gün, üretim fabrika-saat, proje/hat başına 12 fabrika, muharebe değerleri
  (piyade taburu 30 / 110 / 100 bütünlük), zırh ve delme mm
- ☐ Kalanlar (denge testiyle birlikte yapılmalı):
  - Nüfuz ölçeği (günde 2, yasa ve danışman 150, gerekçe 30) ve kararların bedelleri
  - Ticarette "8 kaynak = 1 fabrika", ithalatta "2 kaynak = 1 konvoy"
  - Kriz endeksi eşikleri (bağlantısız %50, demokrasi %100 / %25 / %80) ve iç cepheye etkisi (%1 başına +%0,4)
  - İstikrar etkileri tablosu (%100'de +%20 fabrika, +%10 nüfuz...) ve teslim sınırı formülü (%80, iç cephe < %50)
  - Tabur insan gücü ve ekipman sayıları (piyade 1000 kişi / 100 tüfek, topçu 500 kişi / 12 top), hızlar, zırh oranları
  - Ekipman kaynak ihtiyaçları (fabrika başına çelik, tungsten...); araştırmada "yıl başına +%150" erken araştırma cezası
  - 1936 başlangıç değerleri (istikrar, iç cephe, ideoloji popülerliği): `tools/setup_1936_government.py`'deki tablo tarihî
    seçim sonuçlarından ve kendi hesabımızdan yeniden türetilmeli
  - Ülke kodları (GXC, XSM, RAJ, AST...) yalnız iç kimlik; oyuncuya görünmez, düşük öncelik

### Katman 2 — Arayüz kimliği (insan gözü gerekir)
- ☐ Kendi yerleşimimiz ve ekran akışımız, kendi kısayol düzenimiz ve renk dilimiz
- ☐ Harita sayaçları için açık bir askerî sembol standardı (ör. NATO APP-6) ya da kendi sembol dilimiz

### Katman 3 — İmza mekanikler
- ☐ "Karar oyuncuda": tarihî krizler çok seçenekli pazarlık olarak gelir
- ☐ Tarafsız ülke oyunu: bloklar arası denge diplomasisi (Türkiye 1939–45 başlı başına bir oyun)
- ☐ Hava ve mevsim, ordu → cephe sistemi öne çıkar

### Katman 4 — Süreç ve geçmiş
- ✔ "Türün klasiği" ifadeleri, parite bölümleri ve rehber videosu kaynakları temizlendi; ikon prompt aracında "klasik strateji
  oyunu tarzı" ifadeleri çıkarıldı
- ◐ `THIRD_PARTY_LICENSES.md`: harita, yükseklik ve bayrak kaynakları yazıldı; her bayrağın lisansı tek tek doğrulanacak
- ☐ Herkese açık git geçmişinde eski ifadeler duruyor (ilk commit'teki bir shader yorumu başka oyunun adını anıyor).
  Ticari yayın, geçmişi olmayan temiz bir depodan yapılır.
- ☐ Tasarım günlüğü: önemli sayıların ve adların gerekçesi yazılı tutulur (JSON `_comment`, wiki)

## İnceleme listesi (her PR'da)
- [ ] Yeni ad, metin ya da değer başka bir oyundan alınmadı; kaynağı tarih ya da kendi hesabımız
- [ ] Kod, yorum, belge ve commit mesajında başka bir oyun adıyla ya da örtmeceyle anılmıyor
- [ ] Yeni dış kaynak `THIRD_PARTY_LICENSES.md`'de
- [ ] Oyuncuya görünen yeni metin `strings.csv`'de İngilizce ve Türkçe
