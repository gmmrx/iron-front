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
   alan adlarında aranmadan kullanılmaz. Oyun içi metinlerde adı sabit yazmak yerine tek bir çeviri anahtarı kullanılır.

## Farklılaştırma planı
Durum: ✔ bitti · ◐ başladı · ☐ yapılmadı

### Katman 1 — İfade (veri ve metin; bulutta test edilebilir)
- ◐ Kendi terim sözlüğümüz (siyasi güç, milli odak, milli ruh, dünya gerginliği, komuta gücü, muharebe değerleri...)
- ◐ Yasalar: kendi basamakları, adları ve değerleri; mümkün olduğunca 1930'ların gerçek düzenlemelerinden
- ◐ Danışmanlar: tarihî kişiler ya da kendi arketiplerimiz
- ◐ Milli ruhlar: kendi adlarımız ve değerlerimiz
- ◐ Teknoloji ağacı ve ortak odak ağacı: kendi adlarımız ve yapımız
- ◐ Sayılar: birim, bina, üretim ve inşaat değerleri kendi formüllerimizden

### Katman 2 — Arayüz kimliği (insan gözü gerekir)
- ☐ Kendi yerleşimimiz ve ekran akışımız, kendi kısayol düzenimiz ve renk dilimiz
- ☐ Harita sayaçları için açık bir askerî sembol standardı (ör. NATO APP-6) ya da kendi sembol dilimiz

### Katman 3 — İmza mekanikler
- ☐ "Karar oyuncuda": tarihî krizler çok seçenekli pazarlık olarak gelir
- ☐ Tarafsız ülke oyunu: bloklar arası denge diplomasisi (Türkiye 1939–45 başlı başına bir oyun)
- ☐ Hava ve mevsim, ordu → cephe sistemi öne çıkar

### Katman 4 — Süreç ve geçmiş
- ◐ "Türün klasiği" ifadeleri, parite bölümleri ve rehber videosu kaynakları temizlenir
- ◐ `THIRD_PARTY_LICENSES.md`: harita, yükseklik ve bayrak kaynakları; her bayrağın lisansı tek tek doğrulanır
- ☐ Herkese açık git geçmişinde eski ifadeler duruyor (ilk commit'teki bir shader yorumu başka oyunun adını anıyor).
  Ticari yayın, geçmişi olmayan temiz bir depodan yapılır.
- ☐ Tasarım günlüğü: önemli sayıların ve adların gerekçesi yazılı tutulur (JSON `_comment`, wiki)

## İnceleme listesi (her PR'da)
- [ ] Yeni ad, metin ya da değer başka bir oyundan alınmadı; kaynağı tarih ya da kendi hesabımız
- [ ] Kod, yorum, belge ve commit mesajında başka bir oyun adıyla ya da örtmeceyle anılmıyor
- [ ] Yeni dış kaynak `THIRD_PARTY_LICENSES.md`'de
- [ ] Oyuncuya görünen yeni metin `strings.csv`'de İngilizce ve Türkçe
