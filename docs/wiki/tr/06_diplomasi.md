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
