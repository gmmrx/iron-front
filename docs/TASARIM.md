[English](DESIGN.md) · **Türkçe**

# Oyun tasarımı: kurallar

Bu sayfa oyunun ne olduğunu ve ne olmadığını söyler. Bu sayfaya uymayan özellik yapılmaz; gerekirse önce sayfa değişir.
Son güncelleme: **1 Ekim 2026**.

## Tek cümlede
1936'da İkinci Dünya Savaşı'nın ülkelerinden birini seçer, sonu açık bir oyun oynarsın: şehirlerine yapı diker, ordunu
kurar, araştırır, halkını ayakta tutar, keşfeder ve savaşlarını kazanırsın. Tek başına, sonra 2–4 kişi çevrim içi
oynanır. Senaryolar (savaşın hazır bir anı) oynanmaz; kodları durur.

## Sürdürülebilir olmalı
Serbest oyun yıllarca oyun zamanı sürer. Ekonomi, bilgisayarın ülkeleri ve kare hızı sonuna kadar sağlam kalmalı:
hiçbir şey sonsuz birikmemeli, hiçbir ülke tıkanmamalı, dünya donmamalı. Oyun mantığındaki her değişiklikten sonra
denge testi (1936–1942, tarihî akış) ve 1948'e uzun bir koşu bunu denetler.

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
1. **İnşa et**: şehirlerine yapı dikersin (fabrika, hava üssü, deniz üssü, uçaksavar,
   altyapı); gemi deniz üssü olan limanda alınır; fabrika arttıkça sanayi puanı
   artar.
2. **Üret**: insan gücü ve sanayi puanıyla piyade, zırhlı, topçu ve uçak alırsın; birlik şehirde çıkar.
3. **Araştır**: 2–3 yuvada kısa bir teknoloji listesi; daha iyi tüfek, tank, uçak sürekli verdiğin bir karardır.
4. **Teşvik et**: nüfuz askerlere harcanır — seçili tümenlerin bütünlüğünün bir kısmı hemen döner, bir süre daha sıkı
   savaşırlar (`data/common/recruit.json` → `motivate`).
5. **Ayakta tut**: moral sıfırlanan ülke teslim olur. Olay kartları ve bombardıman morali oynatır.
6. **Savaş**: haritada bölgeden bölgeye emir verirsin. Komşu düşmanlar birbirini vurur; boş düşman bölgesine giren asker
   orayı alır.

## Hiç boş kalmamak
Hızlıca gel, doğru kararları ver, doğru askerî hamleleri yap, keşfet, kazan. Oyuncu bir dakika bile yapacak işi olmadan
beklememeli: üst çubuğun altındaki uyarılar her zaman sıradaki işi gösterir — boş araştırma yuvası, asker almaya yeten
sanayi, çarpışan tümenleri teşvike yeten nüfuz, ikmalsiz tümenler, boştaki hava kanatları, cevap bekleyen olay, boş
inşaat yuvası. Her uyarı
tek tıkla kararın
verildiği yere götürür.

## Kalan ve kalkan
| Kalır | Kalkar |
|---|---|
| Dünya haritası ve bütün ülkeler; haritada yapılar (sisin altında gizli) | Yollar |
| Bölgeden bölgeye kara savaşı, figürler | Ordu, ordular grubu, komutanlar |
| Dur, geri çekil, duruş, böl, teşvik komutları | Şablonlar, taburlar, ekipman stoğu (kapalı: kayıplar insan gücüyle yerine konur) |
| Hava: bölgeye görev (üstünlük, yakın destek, bombardıman, keşif) | Üs üs kanat konuşlandırma |
| Deniz: hâkimiyet ve çıkarma | Akın, eskort, konvoy |
| İnsan gücü, sanayi, moral, nüfuz; şehirlere inşaat; ikmal (kendiliğinden işler) | Ticaret, üretim hatları, tüketim malı, yakıt (kapalı) |
| Seçenekli olaylar, buluş kartları, kısa araştırma | Yasalar, danışmanlar, partiler, seçimler, uzun araştırma ağacı |
| İttifak, savaş ilanı, geçiş izni, barış | Haklı gösterme, garanti |

"Kalkar" sütunu kodda hâlâ duruyor; yol haritasındaki aşamalar onları sırayla siler. Şimdiden herkes için kapalı: yakıt ve
ekipman stoğu (`Military.FUEL`, `EQUIPMENT`: savaşa artık dokunmuyorlar). İkmal açık kalır (`Military.SUPPLY`):
yönetilecek bir şey yok, ama topraklarından kopan ya da denizden çıkıp kopan tümen zayıf savaşır, toparlanmaz; ikmalsiz
denge testi bozuluyordu (İngiltere düşüyor, Almanya 1941'de çöküyordu). İnşaat açık
(`Economy.CONSTRUCTION`), oyuncu da bilgisayar da inşa eder. Yapılar haritada görünür; bulutun altında yalnız şehirler
görünür.

## Kazanmak
Bitiş tarihi yoktur. Bir savaş taraflardan biri pes edince biter: morali çöker ve teslim olur ya da yok olur. Oyun
istediğin kadar sürer.

## Değişmeyen kurallar
- Oyuncu her şeye kendisi karar verir; oyuncu adına kendiliğinden hiçbir şey yapılmaz.
- İçerik veridedir, motor içerikten bağımsızdır. Zombili senaryo aynı motorla, başka bir veri setiyle çalışır.
- Yeni özellik eklenmez; iş [yol haritasındaki](../ROADMAP.tr.md) aşamalardan gelir. Küçük güzel ayrıntılar sonra, yer yer
  eklenir.
