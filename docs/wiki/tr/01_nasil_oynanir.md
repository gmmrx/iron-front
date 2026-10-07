[English](../01_how_to_play.md) · **Türkçe**

# Nasıl oynanır

## Oyuna başlamak
Ana menüde **Yeni oyun**'u, sonra İkinci Dünya Savaşı'na katılan ülkelerden birini seç. Oyun 1 Ocak 1936'da başlar,
bitiş tarihi yoktur; öbür bütün ülkeleri bilgisayar yönetir. Senaryolar (savaşın hazır bir anı) artık menüde yok. Oyun
başkentinde sabah 07:00'de başlar.

**Öğretici** (ana menü): yaklaşık on dakika, Ocak 1936'da İtalya, Etiyopya'yla savaşta (savaş o gün sürüyordu). Alttaki
küçük rehber kartı her seferinde tek bir şey söyler: haritayı kaydır ve yaklaş, asker seç, Shift ile saldırı tahminini
oku, saldır, saati başlat, çarpışan askerleri teşvik et, bir bölge al, şehirde asker al, uyarı şeridi. Her adım sen onu
yapınca geçer (rehber senin yerine hiçbir şey yapmaz); **Göster** kamerayı oraya götürür, **Adımı geç** ve
**Öğreticiyi bitir** hep oradadır. Bitince oyun olduğu gibi sürer. Adımlar: `data/common/tutorial.json`.

## Oyun döngüsü
1. **Keşfet**: toprağının ve sınırın bir bölge ötesinin dışında harita karanlıktır. **K**'ya (ya da Keşif düğmesine) basıp
   bir bölgeye tıkla: boştaki bir hava kanadı bir gün üstünde uçar, 350 km çevresini kalıcı olarak açar. Bir uçuş 15 sanayi
   puanı (SP) tutar.
2. **Asker al**: kendi şehirlerinden birine tıkla: eyalet paneli orada alınabilecekleri (piyade, zırhlı, avcı, yakın destek
   ve bombardıman kanadı) SP bedeli, insan gücü ve eğitim günüyle listeler. Birlik o şehirde çıkar.
3. **Savaş**: figürlerini seçip haritadan emir ver; düşman bölgesinin kartı saldırıyı tahmin eder.
4. **Büyü**: ana şehrini elinde tuttuğun eyaletlerin fabrikaları her gün SP verir (askerî fabrika 1, sivil 0,4; üst çubuk
   SP'yi ve günlük geliri gösterir). Bir şehri alırsan fabrikaları senin için çalışır; bombalanan fabrika vermez.

## Başlangıç (serbest oyun)
1. Ana menüde **Yeni oyun** → üstteki kutulardan ya da haritadan bir ülke seç: haritanın geri kalanı kararır, ülkenin
   sınırı yanar ve kamera ona süzülür; solda lider ve ülkenin sayıları gelir → **Oyna**: seçim panelleri yukarı çekilir,
   kamera başkentine iner, oyun panelleri yukarıdan iner.
2. Oyun **duraklatılmış** başlar (1 Ocak 1936). Boşluk ile başlat/durdur, 1–5 ile hız seç.
3. Oyun İngilizce açılır; Türkçe için **Ayarlar → Dil** (ana menü ya da Esc menüsü).

## İlk 30 gün (her ülke için)
1. **Devlet programı seç (F)**: parlak programlar seçilebilir. Program 4–12 haftada biter, bitince etkisi uygulanır.
2. **Araştırma yuvalarını doldur (I)**: boş yuva kırmızı yanar. Erken yılın teknolojisi her yıl için +%150 süre alır.
3. **İnşaat (T)**: sivil fabrika ekonomiyi büyütür, askeri fabrika üretimi. Bina seç → haritada eyalete tıkla ya da eyalete
   tıklayıp "Burada inşa et".
4. **Üretim (Y)**: boştaki askeri fabrikaları hatlara ata. Boş fabrika hiçbir şey üretmez.
5. **Ticaret (R)**: kaynak açığı kırmızı satırdır. **Satın al** → satıcı ülkeyi seç. Otomatik ticaret yalnız sen açarsan çalışır.
6. **Siyaset (Q)**: 150 nüfuz biriktiğinde bir yasa değiştir ya da danışman ata.
7. **Ordu (U)**: tümenlerini ordularda topla, her birine general ve cephe ver (bkz. [Savaş](05_savas.md)).

## Kontroller
| Eylem | Kısayol |
|---|---|
| Duraklat / sürdür | Boşluk |
| Hız 1–5, hızlan/yavaşla | 1–5, + / − |
| Harita modları: siyasi, arazi, eyaletler, yollar | F1 F2 F3 F4 |
| Başkente dön | Home |
| Hızlı kayıt | F5 |
| Menü / panelleri kapat | Esc |
| Hükümet, Program, Araştırma, Diplomasi | Q, F, I, O |
| Ticaret, İnşaat, Üretim, Ordu | R, T, Y, U |
| Donanma, Hava, Lojistik, Dünya olayları | N, H, L, E |
| Tümen seç / kutu seçimi / seçime ekle | Sol tık / sürükle / Shift |
| Hareket veya saldırı emri | Sağ tık (web'de ve Mac'te tümen seçiliyken Ctrl + sol tık) |
| Ülkenin genel durumu | Haritada Ctrl basılı tut |
| O ülkenin siyaset ekranı (salt okunur) | Ctrl + sol tık (tümen seçili değilken) |
| Kamera | Orta tuş sürükle (bırakınca süzülür), tekerlek, iki parmak, ok tuşları / WASD; her hareket yumuşakça başlar ve durur |

Hareket okları **yeşil** (hareket) ya da **kırmızı** (düşman toprağına taarruz) çizilir. Uzak zoom'da tümen sayıları
yerine küçük ülke bayrakları görünür; daha uzakta harita sade kalsın diye birlik işaretleri gizlenir.

## Kazanma ve kaybetme
Oyunun **bitiş tarihi yoktur**: şunlardan biri olana kadar sürer.
- **Kaybetme**: ülken artık yok (son eyaletini kaybetti ya da ilhak edildi). Teslim olmak tek başına oyunu bitirmez:
  ülken teslim olunca işgal edilen eyaletler işgalcilere geçer ve savaştan çıkarsın; elinde toprak kaldıysa oynamayı
  sürdürür, yeniden toparlanabilirsin. Teslim ilerlemesi, şehirlerinin zafer puanlarından düşman elindeki paydır
  (sömürgeler ¼ sayılır, başkent düşerse +%10); sınır %80'dir, iç cephe %50'nin altındaysa %50'ye kadar düşer (bkz.
  [Diplomasi](06_diplomasi.md)).
- **Kazanma**: senin tarafının (sen ve ittifakın) dışında ayakta ülke kalmaması. Dünyayı gerekçe → savaş → teslim
  zinciriyle fethet (teslim olan ülkenin işgal edilen eyaletleri işgalciye geçer) ya da ülkeleri ittifakına al. Oyun
  sonu ekranı nedeni ve tarihi gösterir; zaferden sonra oynamayı sürdürebilirsin.

## Türkiye ile ipuçları
- Mayıs 1936'da **Sovyet Boğazlar baskısı** gelir: Atatürk'ün dostluğunu hatırlatan nazik ret (yalnız Atatürk liderken),
  üslere izin, ya da ret + seferberlik (Sovyetlere savaş gerekçesi verir).
- **Kasım 1938**: Atatürk'ün ölümü; halefini sen seçersin (İnönü, Çakmak, Bayar).
- **Ekim 1939**: Moskova görüşmeleri: İngiltere-Fransa antlaşması, Sovyet talepleri ya da seferberlik.
- Türkiye bağlantısızdır: savaş gerekçesi için kriz endeksi %50 olmalı. Çelik ithal etmeden fabrikalar tam çalışmaz.
