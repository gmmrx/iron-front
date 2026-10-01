[English](DESIGN.md) · **Türkçe**

# Oyun tasarımı: kurallar

Bu sayfa oyunun ne olduğunu ve ne olmadığını söyler. Bu sayfaya uymayan özellik yapılmaz; gerekirse önce sayfa değişir.
Son güncelleme: **29 Eylül 2026**.

## Tek cümlede
Bir ülke ve bir senaryo seçersin; 30–45 dakikada ordunu kurar, halkını ayakta tutar, kilit şehirleri tutarak kazanırsın.
Tek başına ya da 2–4 kişi çevrim içi oynanır.

## Tat: stratejik haritada gerçek zamanlı savaş, İkinci Dünya Savaşı
Emirler doğrudan haritada verilir, savaş gerçek zamanlı akar ama hiçbir zaman hızlı tıklama yarışı değildir. Yalnız
İkinci Dünya Savaşı'na katılan ülkeler oynanır ve hareket eder (`data/common/participants.json`); öbürleri haritada
birliksiz tarafsız olarak durur. Görüş alanının ötesi savaş sisidir (aralıklı bulut): ortak sınırda bir bölge derin
görürsün, gerisi keşif ister (Keşif düğmesi ya da K, sonra haritaya tık). Şu üçü korunur:
- **Tempo**: oyunu istediğin an durdurur, durmuşken emir verirsin. Çok oyunculuda duraklatma oylanır.
- **Kararlar**: nereye yükleneceğin, nerede durup siper kazacağın, uçakları nereye yollayacağın, hangi kartı seçeceğin.
  Birim birim oyalanma yoktur.
- **Dünya**: bütün ülkeler yaşar; tarihî baskılar 2–3 gerçek seçenekli olay olarak gelir.

## Oyun döngüsü
1. **Üret**: insan gücü ve sanayiyle piyade, zırhlı, topçu ve uçak alırsın; birlik şehirde çıkar.
2. **Ayakta tut**: moral sıfırlanan ülke teslim olur. Olay kartları ve bombardıman morali oynatır.
3. **Savaş**: haritada bölgeden bölgeye emir verirsin. Komşu düşmanlar birbirini vurur; boş düşman bölgesine giren asker
   orayı alır.

## Kalan ve kalkan
| Kalır | Kalkar |
|---|---|
| Dünya haritası ve bütün ülkeler | Yollar, yapı iğneleri |
| Bölgeden bölgeye kara savaşı, figürler | Ordu, ordular grubu, komutanlar |
| Dur, geri çekil, duruş, böl komutları | Şablonlar, taburlar, ekipman stoğu |
| Hava: bölgeye görev (üstünlük, yakın destek, bombardıman, keşif) | Üs üs kanat konuşlandırma |
| Deniz: hâkimiyet ve çıkarma | Akın, eskort, konvoy |
| İnsan gücü, sanayi, moral | Ticaret, inşaat, üretim hatları, tüketim malı, yakıt, ikmal |
| Seçenekli olaylar, buluş kartları | Yasalar, danışmanlar, partiler, seçimler, araştırma ağacı |
| İttifak, savaş ilanı, geçiş izni, barış | Haklı gösterme, garanti |

"Kalkar" sütunu kodda hâlâ duruyor; yol haritasındaki aşamalar onları sırayla siler. İnşaat şimdiden herkes için
kapalı (`Economy.CONSTRUCTION`): yapılar harita verisindeki gibi kalır; limanlar, hava üsleri ve fabrikalar arka planda
çalışır, haritada gösterilmez; yalnız şehirler görünür.

## Kazanmak
Süre yoktur. Senaryo taraflardan biri pes edince biter: morali çöker ve teslim olur ya da yok olur. Anahtar şehirler iki
tarafın da uğruna savaştığı yerlerdir.

## Değişmeyen kurallar
- Oyuncu her şeye kendisi karar verir; oyuncu adına kendiliğinden hiçbir şey yapılmaz.
- İçerik veridedir, motor içerikten bağımsızdır. Zombili senaryo aynı motorla, başka bir veri setiyle çalışır.
- Yeni özellik eklenmez; iş [yol haritasındaki](../ROADMAP.tr.md) aşamalardan gelir. Küçük güzel ayrıntılar sonra, yer yer
  eklenir.
