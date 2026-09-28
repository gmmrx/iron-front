[English](../02_interface.md) · **Türkçe**

# Arayüz

## Üst çubuk (soldan sağa)
| Gösterge | Ne anlatır |
|---|---|
| Lider portresi / bayrak | Portre dosyası varsa lider, yoksa bayrak; tıklanınca ülke bilgisi |
| Nüfuz | Günlük +2 × (1 + katkılar + istikrar etkisi). Yasa, danışman, karar, diplomasi harcar |
| İstikrar | Etkin değer; ipucunda döküm (taban, ulusal durumlar/yasalar/danışmanlar, iktidar partisi popülerliği) |
| İç cephe | Etkin değer; ipucunda döküm (taban, katkılar, kriz endeksi, savaş durumu) ve teslim sınırı |
| İnsan gücü | Askere alınabilir nüfus (askerlik yasasına bağlı) |
| Fabrikalar | Sivil / askeri; ipucunda tersane ve kaynaklar |
| Yakıt, İkmal, Konvoy | Çubuklu hücreler: yakıt stoğu, ikmalli tümen oranı, konvoy/ithalat ihtiyacı |
| Kriz, Savaş | Kriz endeksi; savaştaysan düşman sayısı ve teslim ilerlemesi |
| Komuta gücü, birikim | Ayrı kutu: komuta gücü (komuta zincirinde harcanır), kara/deniz/hava birikimi |
| Tarih ve hız | Sağ üstte; duraklat, hız düğmeleri |

Kara, deniz ve hava birikimi muharebede birikir ama **henüz hiçbir şeye harcanmıyor** (doktrinler sonra gelecek). Hücreleri
soluk görünür, üstünde yasak imleci çıkar; ipucu nedenini söyler.

Menü ekranın sol kenarında alt alta durur; her düğmede kısayol harfi yazar. Üst çubuğun yanındaki kırmızı kutular
uyarılardır (boş araştırma yuvası, boştaki fabrika, seçilmemiş devlet programı).

## Ekranlar
Tüm yan paneller aynı düzendedir: başlık bandı, üstte özet hücreleri, altında içerik (basılı tutup sürükleyerek kaydırılır).
Büyük ekranlar tam ekran açılır; açıkken harita kıpırdamaz.
- **Siyaset (Q)**: lider, parti, ideoloji pastası, seçimler; nüfuz / istikrar / iç cephe dökümü; ulusal durumlar;
  yan yana üç yasa grubu (şartları ipucunda); danışmanlar; kararlar.
- **Devlet Programı (F)**: tam ekran ağaç. Yeşil = bitti, altın = sürüyor, parlak = seçilebilir, soluk = kilitli,
  kırmızı kesik çizgi = ikisinden biri.
- **Araştırma (I)**: üstte yuvalar; bütün teknolojiler tek sayfada, yıllara ve kategorilere göre zaman çizelgesinde
  (önkoşul çizgileri ve "bugün" çizgisiyle). Araştırma bitmez: son sütunda (1943+) her dalın sıradaki **iyileştirme**
  seviyesi durur; dalın bütün teknolojileri bitince açılır. Her seviye bir öncekinden daha uzun sürer (+%15) ve daha az
  kazandırır (−%15): uzun oyunda dal hep işe yarar ama sınırsız büyümez. Her seviyenin yılı bir öncekinden bir yıl
  sonradır; erken araştırmak her yıl için yine +%150 süre alır.
- **Dünya olayları (E)**: dünyada olanlar, en yenisi üstte: savaşlar, ittifaklar, garantiler, teslimler, ilhaklar, barışlar,
  seçimler, yeni liderler, büyük güçlerin devlet programları — bayrak, metin, tarih ve tür. Süzgeçler: *Komşularım* (sen
  ve sınır komşuların), *İttifakım*, *Bütün dünya*. Satıra tıklayınca harita oraya gider. Taraf olmadığın bir savaş
  ilanına ya da ilhaka bir süre (30 / 60 gün; altın satırlar) cevap verebilirsin: seçenekler, bedelleri ve etkileri
  ipucunda (bkz. [Diplomasi](06_diplomasi.md)). Ekranın ortasındaki haber akışı senin işlerine (ve büyük güçlerin
  savaşlarına ve ilhaklarına) ayrılır; dünyanın geri kalanı bu menüdedir.
- **Diplomasi (O)**: ülke listesi, seçili ülkenin ayrıntısı ve eylemleri (kapalı olanların nedeniyle), dünya durumu
  (kriz endeksi, savaşlar, ittifaklar).
- **Ticaret (R)**: kaynak tablosu, satın alma, anlaşmalar (+/−, iptal), ihracat.
- **İnşaat (T)**: özet, bina karoları, kuyruk (sıralama, iptal, çalışan fabrikalar).
- **Üretim (Y)**: askeri fabrika / tersane kullanımı, hatlar (fabrika simgeleri, verimlilik, kaynak açığı), stok.
- **Ordu (U)**: iki sekme. *Komuta zinciri*: ordular grubu → ordu → tümen ağacı, seçili ordunun ya da grubun ayrıntısı
  (komutan, cephe, duruş, tümenler), komutan kadrosu. *Tümen şablonları*: şablonlar, tasarımcı (tabur ızgarası, +/−),
  konuşlandırma.
- **Donanma (N)**, **Hava (H)**: filolar ve kanatlar, görevler, görev bölgesi; kanatların "Otomatik" kutusu kapalı başlar.
- **Lojistik (L)**: ekipman stok / kullanımda / günlük üretim / ihtiyaç / denge, kaynak dengesi.
- **Eyalet paneli**: haritada eyalete tıkla. Bina yuvaları, eyalet binaları, kaynaklar; kendi eyaletinde doğrudan inşa.
- **Seçili tümenler** (altta): ordu başlığı, özet hücreleri, şablona göre bileşim, tümen kartları ve araç çubuğu
  (bkz. [Savaş](05_savas.md)).
- **Olay penceresi**: başlık, resim, açıklama, seçenekler (etkileri ipucunda; şartı sağlanmayan seçenek kilitli).

## Harita kartları
- Kara bölgesinin üstünde: sahibi, bizimle ilişkisi (bizim / müttefik / düşman), arazi, binalar, kaynaklar, tümenler.
- Deniz bölgesinin üstünde: ülkelere göre **deniz hâkimiyeti** (renkli pay çubuğu), bizim tarafın payı, nakliyenin
  güvenli olup olmadığı, oradaki filolar.
- Bir ülkenin üstünde **Ctrl** basılı: lider portresi, ilişki, ittifak, ideoloji çubuğu, istikrar, iç cephe, nüfuz, nüfus,
  fabrikalar, tümen/gemi/uçak (bizden güçlüyse kırmızı, zayıfsa yeşil), savaşlar, ulusal durumlar ve sürdürdüğü devlet
  programı. **Ctrl + tık** o ülkenin siyaset ekranını salt okunur açar.
- Sayılar renklidir: iyi yeşil, kötü kırmızı.

## Harita: iğneler
Harita bir kurmay masasıdır: 3D arazi kalır, üstündeki her şey model yerine haritaya saplanmış bir iğnedir. Uzakta
her zamanki harita ikonları (şehir, liman, hava üssü) görünür; yaklaştıkça her ikon yerden yükselen bir iğneye dönüşür.
- **Şehir**: şehri elinde tutan ülkenin renginde başlı iğne; şehir büyüdükçe iğne büyür. Adı başın üstündedir.
- **Tümen, filo, hava kanadı**: sayaç iğnenin bayrağıdır. Her ordunun kendi iğnesi vardır (aynı bölgedeki ordular yan
  yana durur, ordunun adı sayacının altında yazar). Yakında ordunun ana sayacının (en çok tümenli olan) üstünde
  komutanının portresi durur; ordular bir bakışta ayırt edilir. Komutanın resmi yoksa adının baş harfleri görünür.
- **Yapılar**: eyaletin yapıları yan yana resim olarak (sivil ve askerî fabrika, tersane, rafineri, uçaksavar, deniz
  üssü), köşesinde seviyesi; süren inşaat turuncu çerçeveli resim ve "+n". Hava üssünün kendi rozeti vardır. Orta
  uzaklıktan itibaren rozetler haritanın üstünde küçük ikon olarak durur; yaklaştıkça tam boya büyür ve iğne
  altlarından yükselir. Farenin
  rozetin üstüne gelmesiyle rozet büyür, o yapının sesi duyulur ve kart o yapıyı anlatır (seviye / en çok, süren inşaat,
  ülkedeki toplamı, hava üssünde konuşlu kanatlar). Rozete tıklamak eyaletini açar (İnşaat açıkken: oraya inşa eder).
- **Muharebeler**: muharebenin yanında küçük oklar belirip söner: durumu az önce düzelen tarafta yeşil ▲, zemin
  kaybeden tarafta kırmızı ▼ (saldıranın oku saldırının geldiği yanda).
- **Uçaklar** tek modeldir: ülke renginde küçük bir uçak, üste park etmiş ya da görevinde uçarken.
- **Eyalet sınırları** her zoom'da belirgin koyu çizgidir, yakında daha kalın.
İğneler her zoom'da ekranda aynı boydadır.

## Ayarlar
Ana menü → **Ayarlar** ya da oyunda Esc → **Ayarlar**: ana ses, müzik, ses efektleri ve arayüz sesleri; müzik (oyun
durumuna göre otomatik ya da istenen parça sürekli); dil (English / Türkçe, anında değişir, süren oyun kaldığı yerden
devam eder); tam ekran, ekran kenarında kaydırma. Hepsi kaydedilir.
