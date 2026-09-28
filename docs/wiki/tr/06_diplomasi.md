[English](../06_diplomacy.md) · **Türkçe**

# Diplomasi

## Tarih (diğer ülkeler ne yapar)
Oyuncunun ülkesi dışındaki her ülke tarihi izler: gerçek gününde yapay zekâ tarihî adımı atar — Rheinland (7 Mart 1936),
Marco Polo Köprüsü (7 Temmuz 1937), Anschluss (12 Mart 1938), Münih (30 Eylül 1938), Prag (15 Mart 1939), Arnavutluk
(7 Nisan 1939), Çelik Paktı, Molotov–Ribbentrop Paktı, Polonya (1 Eylül 1939), Sovyetlerin Polonya'ya girişi (17 Eylül),
Kış Savaşı (30 Kasım) ve Moskova Barışı, Danimarka ve Norveç (9 Nisan 1940), Batı (10 Mayıs 1940), İtalya'nın savaşa
girişi (10 Haziran 1940), Baltık ülkeleri ve Besarabya, Üçlü Pakt, Yunanistan (28 Ekim 1940), 1940–41'in Mihver üyeleri,
Balkanlar (6 Nisan 1941), Romanya, İtalya, Finlandiya ve Macaristan'la Barbarossa (22 Haziran 1941), Pearl Harbor
(7 Aralık 1941) ve ardından gelen savaş ilanları, Sovyetlerin Japonya'ya savaşına (8 Ağustos 1945) kadar. Mayıs 1940'ta Hollanda, Belçika ve Fransa (yapay zekâ oynuyorsa) 1 Ekim'e kadar "Cephenin
Çöküşü" durumunu alır (savunma −%40, bütünlük −%35, saldırı −%20, daha düşük teslim sınırı): 1940 seferi tarihteki gibi
haftalar içinde biter. Çizelge veridir (`data/common/history.json`).
- **Oyuncunun ülkesi hiçbir adımı kendiliğinden atmaz**: tarihî anları seçenekli olay olarak gelir. Tarih oyuncuya
  yöneliyorsa (ör. Polonya'yla oynuyorsan) yine gelir.
- **Oyuncu tarihi değiştirir**: her adımın koşulu vardır; artık tutmuyorsa (Almanya Polonya ile savaşta değil, Viborg
  artık Finlandiya'nın değil...) adım atlanır ve dünya oradan kendi yoluna gider.
- **2 Eylül 1945'e kadar** yapay zekâ kendi başına savaş açmaz ve müttefikinin saldırı savaşına çağrıyla katılmaz
  (müttefiki ya da garanti ettiği ülkeyi savunmak hemen olur). Bu tarihten sonra yapay zekâ serbestçe davranır.
- **Tarihî akıştan sonra dünya durmaz**: 2 Eylül 1945'ten sonra her ülkeye kurala dayalı olaylar gelir (oyuncu karar
  verir, yapay zekâ ağırlığa göre seçer); her biri ortalama kendi süresinde bir gelir, bekleme süresi dolmadan yeniden
  gelmez:
  | Olay | Kime gelir | Ortalama | Bekleme | Seçenekler |
  |---|---|---|---|---|
  | Sınırda Çatışma | barıştaki, müttefik olmayan komşusu olan ülke | 1.800 gün | 720 gün | tazminat iste (−20 nüfuz, komşuya karşı savaş gerekçesi, kriz +2) / büyükelçiliklerle çöz (istikrar +%2, iç cephe −%2) |
  | Bankalara Hücum | her ülke | 2.600 gün | 1.100 gün | bankaları kurtar (−40 nüfuz, istikrar +%2) / batmalarına izin ver (istikrar −%6, +15 nüfuz) |
  | Subay Komplosu | istikrarı %35'in altındaki ülke | 1.500 gün | 1.500 gün | tutukla (istikrar +%4, iç cephe −%3) / orduya söz hakkı ver (faşizm +%10, istikrar +%3, iç cephe +%3) / erken seçim (demokrasi +%10, istikrar −%2) |
  | Askerler Evine Dönüyor | barıştaki büyük güç | 400 gün | 10 yıl | terhis et (2 sivil fabrika, iç cephe −%8, istikrar +%3) / orduyu tut (iç cephe +%4, istikrar −%4) |

  Sınır çatışması yapay zekânın yeni savaş bulma yoludur: tazminat isteyen ülke savaş gerekçesi kazanır; gerekçesi
  olan, demokrasi olmayan yapay zekâ ordusu yeterince güçlüyse savaş açar. Olaylar veridir (`data/common/events.json`
  içinde `"recur"`).

## Kriz endeksi
Dünyanın genel savaşa ne kadar yaklaştığı. Saldırganlıkla artar (gerekçe hazırlama, ilhak, savaş). Herkesin iç cephesini güçlendirir (%1 başına +%0,4, en çok +%40).

| İdeoloji | Savaş gerekçesi | Garanti verebilmek | İttifaka girmek |
|---|---|---|---|
| Faşist / komünist | her zaman | her zaman | her zaman |
| Bağlantısız | endeks ≥ %50 | endeks ≥ %40 | endeks ≥ %40 |
| Demokratik | endeks %100 ve hedef demokrasi değil | endeks ≥ %25 | endeks ≥ %80 (savaştaysa %50) |

## Eylemler (O ya da haritada ülke → Diplomasi)
- **Savaş gerekçesi**: 30 nüfuz, 30 gün. Hazır olunca savaş ilan edilebilir.
- **Savaş ilanı**: hedefin müttefikleri ve garantörleri katılır.
- **Bağımsızlık garantisi**: ona saldırana karşı savaşa girersin.
- **Askerî geçiş**: tümenlerin topraklarından geçer (aynı ideoloji ya da müttefik kabul eder, diğerleri %30).
- **İttifaka davet**: yalnız ittifak lideri.
- **Beyaz barış**: toprak değişmeden barış; kaybeden taraf kabul eder. İki savaş lideri arasındaysa savaş herkes için biter;
  taraflardan biri müttefik üyeyse yalnız o savaştan çıkar, lider diğerleriyle savaşmayı sürdürür.
- Kapalı eylemin nedeni satırın altında turuncu yazar.

## Dünyaya cevap (Dünya olayları, E)
Bir ülke başka birine savaş ilan edince ya da onu ilhak edince, sen iki taraftan biri (ya da müttefiki) değilsen, dünya
olayları menüsündeki kayıt bir süre seçenek taşır:
| Olay | Seçenek | Etki |
|---|---|---|
| Savaş ilanı (30 gün) | Saldırıyı kınamak | −10 nüfuz, iç cephe +%2 (halk kenetlenir) |
| | Saldırıya uğrayana tüfek göndermek | stoğundan −500 tüfek, −5 nüfuz; saldırıya uğrayana 500 tüfek (stokta 500 gerekir) |
| | Uzak durmak | istikrar +%1 |
| İlhak (60 gün) | Tanımamak | −25 nüfuz, ilhak edene karşı savaş gerekçesi |
| | Tanımak | kriz endeksi −1 |

**Sen** savaş açınca, iki tarafta da olmayan demokratik büyük güçler demokrasi olmayan saldırganı kınar (aynı seçenek,
bedeli onlara); kınamaları menüde ve haber akışında görünür. Seçenekler ve sayılar veridedir
(`data/common/world_reactions.json`).

## Teslim
- Teslim ilerlemesi = şehirlerin zafer puanlarından düşman elindeki pay (sömürgeler ¼ sayılır) + başkent düştüyse %10.
- Sınır %80; iç cephe %50'nin altındaysa (0,5 − iç cephe) × 0,6 kadar düşer; bazı ulusal durumlar değiştirir
  (ör. Fransa'nın Kısa Ömürlü Kabineler durumu −%30). En düşük %20.
- Teslim olan ülkenin işgal edilen eyaletleri işgalciye geçer.
- Teslim olan ülke bütün savaşlardan ve (lideri değilse) ittifakından çıkar, verdiği garantiler düşer ve **iki yıl**
  savaş ilan edemez (mütareke: dağılan orduyu yeniden kurma süresi). Elinde toprak kaldıysa oynamayı sürdürür — oyuncu da.
