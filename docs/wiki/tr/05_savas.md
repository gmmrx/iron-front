[English](../05_warfare.md) · **Türkçe**

# Savaş

## Tümenler ve şablonlar (U → Tümen şablonları)
- Tabur türleri: piyade, topçu, tanksavar, motorize piyade, hafif tank, orta tank (araştırma ister).
- Şablon tasarımcısı: tabur başına +/− (şablonda en çok 25 tabur). Değerler: personel/tanksavar ateşi, savunma, şok,
  bütünlük, hız, cephe genişliği, insan gücü. Piyade taburu: 30 personel ateşi, 110 savunma, 15 şok, 100 bütünlük, 50 dayanıklılık.
- **Birlik adları** arayüz dilinden bağımsız, her ülkenin kendi dilindedir: Türkiye'de "1. Piyade Tümeni", Almanya'da
  "1. Infanterie-Division", İngiltere'de "1st Infantry Division", Fransa'da "1re Armée", Japonya'da "Dai 1 Shidan" (Latin
  olmayan diller Latin harfleriyle). Adlar `data/common/unit_names.json`'dadır (24 dil; öbürleri İngilizce).
- **Konuşlandır**: panel kapanır, harita birliğin gidebileceği yerler dışında kararır (tümen: kendi bölgelerin; hava
  kanadı: hava üssü olan eyaletler; yeni gemiler: limanı olan eyaletler); vurgulu bir bölgeye tıklayınca oraya
  konuşlanır (sağ tık / Esc: vazgeç). Gemi, deniz üssü olan eyaletin limanında SP ile alınır (bölge
  paneli → asker al: muhrip 41, denizaltı 30, kruvazör 121, zırhlı 336 SP) ve oradaki yedek filoya katılır; bilgisayar da
  gemiyi aynı yoldan, 1936 donanmasının yılda %8 büyümüş haline kadar alır. İnsan gücü ve ekipman yeterliyse tümen 14 gün eğitim alır (bu sürede hareket etmez); askerlik yasası bunu değiştirir (İki Yıllık Mükellefiyet 13, İhtiyat Celbi 16, Kitlesel Celp 20 gün).

## Emirler
- Sol tık / kutu ile seç, **sağ tık** (web ve Mac'te, tümen seçiliyken Ctrl + sol tık) hedef bölgeye git ya da saldır.
  **Başka bir sayaca** sağ tık tümenleri o sayacın bölgesine gönderir (yığına katılma): sayaçlar haritanın üstünde, şehrin
  yanında durur, altlarındaki zemin çoğu kez komşu bölgedir. Vurgu ve kart emrin gideceği bölgeyi gösterir.
- **Yürümek zaman alır ve yorar**: taburun hızı yol hızıdır (piyade 4 km/s, motorlu 12, hafif tank 10, orta tank 9; tümen
  en yavaş taburunun hızında gider), ama kimse günde 24 saat yürümez — mola, gece, ikmal kolu, tıkanan yol günlük
  ortalamayı üçte bire indirir: piyade günde ~33 km, zırhlı tümen ~84, motorlu ~100 (1939-45'te piyade günde 25-30 km
  yürürdü; zırhlı yarmalar 40-80 km yaptı). Arazi, altyapı, mevsim, yakıt ve ikmal de sayılır. Yürürken tümenin
  bütünlüğü her saat biraz düşer (en çok %60'a kadar), ancak durunca toparlanır: uzun yoldan yeni gelen tümen ilk
  saldırısında zayıftır, bir orduyu cepheden cepheye kaydırmanın bedeli vardır.
- **Ctrl'yi basılı tut**: tümen seçiliyken yürüme menzilleri görünür (seçilenlerin en yavaşınınki): bir günde varılan
  bölgeler parlak yeşil, üç günde orta yeşil, bir haftada soluk yeşil, haritanın geri kalanı kararır. Düşman bölgeleri
  menzilin kenarıdır (orada muharebe var); izinsiz tarafsız topraklar menzile girmez.
- **Nerede duracakları senin seçimin**: tümenler bölgenin içinde sağ tıkladığın noktada durur (sınırın dibi, bölgenin
  ortası, nehrin gerisi...); tümenin kendi bölgesinde bir noktaya sağ tık onu durdurup sayacını oraya alır. Nokta
  sayacın haritada durduğu yerdir (kayda yazılır); muharebe yine bölge bölge hesaplanır.
- Yol yoksa mesaj nedenini söyler: adı verilen ülkeye geçiş iznimiz yok (hedefte ya da yol üstünde; Diplomasi'den izin
  istenir), hedefe ancak denizden gidilir ve deniz kapalı (düşman donanması ya da çıkılacak kıyı yok) ya da tümenler hâlâ
  eğitimde.
- Tümen seçiliyken farenin altındaki bölgenin kartı **tahmini varışı** gösterir (emirden önce yol çizilmez) ("yaklaşık N gün", ilk üç tümenin en
  yavaşı; arazi, altyapı, mevsim, yakıt, ikmal ve bütünlük sayılır, muharebe sayılmaz) ya da yol olmadığını söyler.
- Oklar: gövde ve büyük ok başı yok — hedefe doğru akan, arka arkaya küçük işaretler; soluk, haritanın altından akıyormuş
  gibi; harekette ülkenin renginde, düşman toprağına taarruzda **kırmızı**. Emir verilen tümen yerinden kaymaz (bölge
  merkezine sıçramaz), yola durduğu yerden çıkar; ok sayaçların durduğu noktalardan (şehrin yanı ya da seçtiğin nokta)
  geçer ve orada biter,
  yığına verilen emrin oku o yığının altında biter.
- **Haritada hareket**: düşmanın durduğu bölgeye emir verilen tümen olduğu yerde durup oradan ateş eder (düşmana
  doğru kayıp geri gelmez, saldırı durdurulsa da); düşman çekilince yürür. Yürüyen
  tümenler yığından ayrılıp kendi sayaçlarında ilerler (yığın yerinde kalır); birlikte yürüyenler tek sayaçta, geride
  kalan kendi sayacında gelir. Sayaç bölge değiştirince aynı sayaç olarak sürer; yer değiştirmesi (katılma, geri
  çekilme, ilerleme) sıçramadan kayarak olur.
- **Saldırı tahmini**: tümen seçiliyken düşman bölgesinin kartı, seçili tümenlerin şimdi saldırsa ne olacağını gösterir:
  karar (umutsuz, zor, dengeli, üstünüz, ezici üstünlük), iki tarafta kaç tümen durduğu, savunmanın ne zaman çözüleceği
  ya da saldırımızın ne zaman tükeneceği ve tahmini en çok değiştiren etkenler (arazi, nehir geçişi, denizden çıkarma,
  düşman siperi, hava üstünlüğü, ikmal, çamur ve kış, planlama, komutanlar, komşudaki topçu). Muharebe formülünü zar
  atmadan kullanır. Askeri olmayan düşman bölgesinde "giren alır" yazar.
- **Dur**: yürüyüşü ve saldırıyı keser. Yerinde bekleyen tümen siper kazar: savunması 10 günde %15'e kadar artar.
- **Geri çekil**: tümen cephenin gerisindeki en yakın güvenli dost bölgeye (içinde ve yanında düşman olmayan) yürür.
  Saldıran tümen saldırıyı bedelsiz keser. Saldırı altındaki tümen hemen kopar ve bir bölge geri geçer ama
  bütünlüğünün dörtte birini kaybeder. Kuşatılmış tümenin gidecek yeri yoktur, emir verilmez.
- **Böl**: 1, Yarısı ya da Hepsi. Seçili her figürden sonraki emirle bir tümen, yarısı ya da hepsi gider; en dinçler
  (bütünlüğü en yüksek) önce gider, kalanlar yerinde kalır. Hepsi, o bölgelerde duran bütün tümenleri seçer.
- **Duruş**: **Son askere kadar** (oyuncunun tümenlerinde başlangıç) kendiliğinden geri çekilmez; bütünlüğü %12'nin
  altına inince yarı güçle savaşır, gücü bitince yok olur. **Esnek** bütünlüğü bitince en yakın güvenli bölgeye çekilir.
- **Dağıt** (insan gücü geri döner; ekipman döner**mez**).

## Seçili tümenler paneli (mikro yönetim)
Seçili tümenler ekranın sağ kenarından kayarak açılan panelde:
- **Başlık**: seçili tümen sayısı ve kapat düğmesi.
- **Özet hücreleri**: tümen sayısı, ortalama bütünlük ve güç, kaçı muharebede, ikmal.
- **Bileşim**: hangi şablondan kaç tane; bir şablona tıkla → seçimde yalnız onlar kalır.
- **Tümen kartları** (iki sütun): simge, ad, bütünlük ve güç çubukları, durum. Muharebede ya da ikmalsiz kart kırmızıdır.
  Karta tıkla → yalnız o tümen seçilir; × → seçimden çıkar.
- **Araç çubuğu** (panelin altında): Dur · Geri çekil · Böl (1 · Yarısı · Hepsi) · Duruş (Son askere kadar · Esnek) · Dağıt.

## Komuta zinciri (artık arayüzde yok)
Savaş oyunu tümen seçerek oynanır; Ordu ekranı ve ordu araçları arayüzden çıkarıldı (yol haritası yeni yön, aşama 1).
Aşağıdaki kurallar motorda duruyor ve yapay zekâ ülkeleri kullanıyor.
- **Ordular grubu** (mareşal) → **ordu** (general) → **tümen**.
- Ordu bir cepheye (ülke) atanır, tümenler sınır boyunca kendiliğinden dağılır; **Savun** ya da **Taarruz**.
  Ordular grubunda cephe ve duruş bütün ordulara tek seferde verilebilir.
- **Komutanlar**: her ülkenin kadrosu var (büyük güçlerde dönemin komutanları: Fevzi Çakmak, Manstein, Zhukov, Wavell...).
  Beceri 1–5. General becerisi × %4 ordunun tümenlerine saldırı ve savunma katkısı (24 tümene kadar tam, fazlası katkıyı böler);
  mareşal becerisi × %2 gruptaki bütün ordulara.
- Komutanlar tümenleri savaştıkça **tecrübe** kazanır; tecrübe dolunca becerisi 1 artar.
- **Terfi**: general → mareşal 30 komuta gücü. **Yeni general yetiştir**: 15 komuta gücü (beceri 1).
  Komuta gücü her gün artar, savaşta daha hızlı.
- Oyuncunun ordularına komutan **kendiliğinden atanmaz**; boş ordu da silinmez. Seçimi sen yaparsın.

## Muharebe
- Saldırı gücü: personel ateşi × (1 − hedefin zırh oranı) + tanksavar ateşi × zırh oranı, güç ve tecrübeyle çarpılır.
- Değiştiriciler: arazi, nehir (−), deniz aşırı çıkarma (−), ikmalsizlik −%35, yakıtsızlık −%35, kış ve çamur, gece −%25
  (yalnız saldırana; alacakaranlıkta ve şafakta hafif; `data/common/units.json` → `night`), hazırlık (en çok +%20),
  hava üstünlüğü ve yakın hava desteği, komuta katkısı (general ve mareşal becerisi).
- Savunma/şok ile karşılanan saldırıların %10'u, aşan kısmın %40'ı isabet eder. İsabetler bütünlüğü ve gücü düşürür.
- Siper: bekleyen tümen 10 günde en çok +%15 savunma kazanır.
- **Topçu desteği**: bir muharebenin yanındaki bölgede yerinde duran tümenler (yürümeyen, saldırmayan, başka muharebede
  olmayan) iki taraftan da muharebeye topçularıyla katılır. Her biri topçusunun personel ateşinin dörtte birini ekler
  (zırha karşı bunun onda biri); karşı ateş yemez. Bir tümen saatte tek muharebeye destek verir ve o saat komşu
  düşmanla karşılıklı ateşe girmez. Neden dörtte bir: piyade tümeninin iki topçu taburu personel ateşinin yarısından
  fazlasıdır, tam destek her komşuyu ikinci bir saldıran yapardı; dörtte birle iki destekçi saldırıya yaklaşık dörtte
  bir ekler, fark edilir ama muharebeyi tek başına çevirmez. Garnizon tümeninin topçusu yoktur, destek vermez.
- Tecrübe: Acemi → Talimli → Pişkin → Sınanmış → Seçme.
- **Cephe bütünlüğü**: tümen yalnız kendisinin (ya da müttefikinin) başka bir bölgesine de değen bölgeye saldırır; tek
  başına derine sızıp kesilen "parmak" oluşmaz (başkentler istisna). Dar yarımada ve koridorda (Jutland, Danzig koridoru)
  bu hiç sağlanmaz; orada açıkça üstünse (yerel güçte 2,5 kat) ve hedefin düşmandaki diğer komşuları en çok 3 ise saldırır.
- **Ordunun cephesi** (U → cephe: bir ülke) o ülkeyle sınırdır; ayrıca o ülkeyle savaşan ve anavatana karadan bağlı
  müttefiklerin toprağı. Müttefikin deniz aşırı sınırı tümenleri oraya çekmez.
- **Bütün eyaletlerini kaybeden ülke ordusuyla birlikte yok olur**: ilhak edilen ülkenin (ör. Bohemya-Moravya) tümenleri,
  filoları ve hava kanatları da haritadan kalkar.

## Haritada
Her tümen sayacı türünü gösterir: piyade ✕, motorlu tekerlekli ✕, zırhlı oval (palet). Ordularınız aynı bölgede de ayrı
iğnelerde durur, sayacın altında ordunun adı yazar; tek başına duran tümeninizin kendi adı yazar. Adlar yalnız yakında
görünür.

### Cephe çizgisi
Savaştayken senin tarafının (sen ve müttefiklerin) elindeki bölgelerle düşmanlarının elindeki bölgelerin sınırı, her
zoom'da yerin altından yanan bir ateş damarı gibi parlar. Yanına tıklayınca altta **cephe paneli** açılır: iki bölge, iki
taraftaki tümenler (sayı · ortalama güç; savaş sisinin altındaysa "?"), düşman bölgesinin üstündeki hava payın ve orada
süren muharebe (iki tarafın kalan bütünlüğü). İki düğme cepheye uzanabilen boştaki bir hava kanadını yollar: **Hava
desteği** (muharebenin üstüne yakın destek; muharebe yoksa düşman bölgesine) ve **Hava üstünlüğü**. Hava desteğine önce
yakın destek uçağı, üstünlüğe önce avcı gider; başka görevdeki kanat alınmaz. Bölge el değiştirince panel kendiliğinden
kapanır.

## İkmal ve yakıt
Dost topraktaki kaynaktan işgal edilen topraklarda en çok 9 bölge içeri ikmal ulaşır; ötesindeki ya da kuşatılmış tümenler ikmalsiz kalır: saldırı −%35, yavaş toparlanma.
Üst çubukta ikmalli tümen oranı görünür.

## Hava (H)
Stoktaki uçaklar **kendiliğinden kullanılmaz**: **Kanat kur** en çok 100'ünü başkente en yakın hava üssünde kanat yapar.
Görevler: bekle, hava üstünlüğü, yakın hava desteği, liman baskını, **bombardıman**. "Otomatik" kutusu kapalı başlar.
- **Önce bölge, sonra görev**: hava paneli açıkken haritada bir bölgeye tıkla. Bölge panelin başında **hedef** olur;
  oradaki hava üstünlüğümüz ve düşman eyaletiyse bombardıman hasarı yazar. Her kanadın bir satırı ve Hava üstünlüğü,
  Yakın destek, Bombardıman düğmeleri vardır. Kanadın üssü menzil dışındaysa kanat, hedefe yetişen en yakın hava
  üssümüze geçer; hiçbiri yetmiyorsa satır menzil dışı yazar. Temizle hedefi kaldırır.
- Eski yol da çalışır: kanat kartında görevi seç, sonra Bölge seç ile haritaya tıkla.
- **Yakın hava desteği** haritada görünür: uçaklar görev bölgesindeki muharebede düşman tümenlerinin üstüne dalıp bomba
  bırakır.
- **Bombardıman**: karadaki düşman eyaletinin fabrikalarını ve halkının savaşma isteğini vurur. Her gün eyaletin
  fabrikalarının uçak × bomba yükü × 0,0003 × oradaki hava üstünlüğümüz × (1 − uçaksavar seviyesi başına 0,1) kadarı
  durur, en çok %80; hasar günde %1 onarılır. Duran fabrika üretmez: askerî üretim hatları duran askerî fabrika payı
  kadar (gemilerde tersane) çıktı kaybeder, duran sivil fabrika inşaat yapmaz. Hedef ülkenin savaş desteği günde uçak ×
  bomba yükü × 0,00001 × üstünlük kadar düşer. Bomba yükü: bombardıman uçağı 1, yakın destek 0,3, avcı 0 (avcı bombalayamaz).
  Neden bu sayılar: karşı koymasız 100 uçaklık tam kanat günde %3 durdurur, onarım %1; bir aylık akın eyalet sanayisinin
  yarıdan fazlasını durdurur, iki ayda geri gelir. Savaş desteği kanat başına ayda ~%3 düşer; bir halkı yıldırmak için
  birkaç kanat ve aylar gerekir. Bombardıman uçakları eyaletin en büyük şehrinin üstünden geçer. Eyalet kartı hasarı
  gösterir; hangi eyaletimizin bombalandığı her hafta bildirilir.
- **Hızlı keşif**: sol menünün altındaki Keşif düğmesi (ya da K), sonra haritaya tık: bölgeye yetişen en yakın boştaki
  kanat üstünde uçar (önce avcılar; başka görevdeki kanat alınmaz).
- **Keşif**: kanat bölgenin üstünde uçar; merkezinin 350 km çevresindeki düşman tümenleri savaş sisine rağmen haritada
  görünür (gece yalnız 175 km: `data/common/recruit.json` → `night_recon_range`). Her uçak yapabilir; düşman avcıları
  ateş eder.

## Savaş sisi
Görüş alanının ötesi haritada aralıklı **bulutla** kaplıdır: dağınık bulutlar sürüklenir, araları açıktır; harita
gözü yormaz. Açık olan yerler: senin ya da müttefiklerinin elindeki bölgeler,
tümenlerinin durduğu bölgeler ve keşif kanatlarının bölgeleri. Sınırın öbür yanında yalnız bir şerit açık kalır: komşu
bölgelerde sınıra yakın kısım açıktır, yaklaşık 100 harita pikseli içeride bulut başlar (sınır şeridi; bu bölgelerde
duran tümenler görünür). Gerisi hep keşif ister. Gece tümen yalnız durduğu bölgeyi görür; komşu bölgeleri güneş doğunca açar. Bulutun altında müttefikin olmayan her
ülkenin tümenleri, filoları ve
hava kanatları gizlidir; bölge kartı bilgi yok der, saldırı tahmini düşman gücünün bilinmediğini söyler. Bilgisayarın
ülkeleri sisten etkilenmez; izleme kipinde sis yoktur. Bulutun altındaki yabancı bölgede keşfetmedikçe yalnız şehirler
görünür: şehir işaretleri kalır, yapılar (liman, hava üssü, fabrika) gizlidir, bölge kartı nüfusu ve şehri gösterir
ama altyapıyı, yapıları ve kaynakları göstermez.

## Deniz (N)
Filolar: limanda, deniz üstünlüğü, konvoy baskını, konvoy koruma. Görev bölgesi haritadan. Bütünlük düşünce filo limana döner.
Gemiler yalnız deniz yollarından gider. Bir deniz bölgesinin üstüne gelince ülkelere göre **deniz hâkimiyeti** ve
nakliyenin orada güvenli olup olmadığı görünür. Filo seçiliyken farenin altındaki kart emrin hedefine tahmini varışı
gösterir (kendi limanın: üs değişikliği; başka yer: görev bölgesi) — deniz yollarının gerçek uzunluğu, en yavaş geminin
hızıyla.
