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
| Tarih ve hız | Sağ üstte; duraklat, hız düğmeleri; beş hız 0,1× · 0,2× · 0,3× · 0,5× · 1× (1× = saniyede 5 oyun saati) |
| Dünya saati | Tarihin solundaki küçük dünya: başkentine bakar, aydınlık yarı oyun saatine ve mevsime göre döner (gündüz / gece) |

Kara, deniz ve hava birikimi muharebede birikir ama **henüz hiçbir şeye harcanmıyor** (doktrinler sonra gelecek). Hücreleri
soluk görünür, üstünde yasak imleci çıkar; ipucu nedenini söyler.

Menü ekranın sol kenarında alt alta altı düğmedir: hükümet, diplomasi, üretim, ordu, donanma ve hava; her düğmede
kısayol harfi yazar. Program, araştırma, dünya olayları, ticaret, inşaat ve lojistik ekranları artık menüde yok
(kısayolları hâlâ açar) ve sadeleşiyor (yol haritası 3. aşama). Üst çubuğun yanındaki kutular
uyarılardır: cevap bekleyen olay, asker almaya yeten sanayi puanı (başkenti açar), boştaki hava kanatları, ikmalsiz
tümenler, azalan insan gücü, teslim tehlikesi. Haritadaki yapılar (liman, hava üssü, fabrika) sabittir ve haritada
görünür; yabancı eyaletin yapıları keşfedilene kadar sisin altında gizli kalır.

## Ekranlar
Tüm yan paneller aynı düzendedir: başlık bandı, üstte özet hücreleri, altında içerik (basılı tutup sürükleyerek kaydırılır).
Büyük ekranlar tam ekran açılır; açıkken harita kıpırdamaz.
- **Siyaset (Q)**: lider, parti, ideoloji pastası, seçimler; nüfuz / istikrar / iç cephe dökümü; ulusal durumlar;
  yan yana üç yasa grubu (şartları ipucunda); danışmanlar; kararlar.
- **Devlet Programı (F)**: tam ekran ağaç. Yeşil = bitti, altın = sürüyor, parlak = seçilebilir, soluk = kilitli,
  kırmızı kesik çizgi = ikisinden biri. Harita gibi gezilir: tekerlek (ya da trackpad sıkıştırması) imlecin olduğu yere
  yakınlaşır, boş yerde sürüklemek kaydırır (bırakınca süzülür), ok tuşları / WASD da kaydırır; −, + ve *Sığdır*
  başlıkta. Her hareket sıçramadan, yumuşak geçişle.
- **Araştırma (I)**: üstte yuvalar; bütün teknolojiler tek sayfada, yıllara ve kategorilere göre zaman çizelgesinde
  (önkoşul çizgileri ve "bugün" çizgisiyle). Araştırma bitmez: son sütunda (1943+) her dalın sıradaki **iyileştirme**
  seviyesi durur; dalın bütün teknolojileri bitince açılır. Her seviye bir öncekinden daha uzun sürer (+%15) ve daha az
  kazandırır (−%15): uzun oyunda dal hep işe yarar ama sınırsız büyümez. Her seviyenin yılı bir öncekinden bir yıl
  sonradır; erken araştırmak her yıl için yine +%150 süre alır. Süren teknolojinin ilerlemesi düğmesini (ve yuvasını)
  soldan altın bir zemin olarak doldurur; yazılar önde kalır.
- **Dünya olayları (E)**: dünyada olanlar, en yenisi üstte: savaşlar, ittifaklar, garantiler, teslimler, ilhaklar, barışlar,
  seçimler, yeni liderler, büyük güçlerin devlet programları — bayrak, metin, tarih ve tür. Süzgeçler: *Komşularım* (sen
  ve sınır komşuların), *İttifakım*, *Bütün dünya*. Satıra tıklayınca harita oraya gider. Taraf olmadığın bir savaş
  ilanına ya da ilhaka bir süre (30 / 60 gün; altın satırlar) cevap verebilirsin: seçenekler, bedelleri ve etkileri
  ipucunda (bkz. [Diplomasi](06_diplomasi.md)). Ekranın ortasındaki haber akışı senin işlerine (ve büyük güçlerin
  savaşlarına ve ilhaklarına) ayrılır; dünyanın geri kalanı bu menüdedir.
- **Diplomasi (O)**: ülke listesi (bütün bayraklar aynı boyda; üstteki arama kutusu listeyi ada ya da ülke koduna göre
  süzer, Türkçe harf ve büyük/küçük harf fark etmez, Enter ilk eşleşeni seçer), seçili ülkenin ayrıntısı ve eylemleri
  (kapalı olanların nedeniyle), dünya durumu (kriz endeksi, savaşlar, ittifaklar).
- **Ticaret (R)**: kaynak tablosu, satın alma, anlaşmalar (+/−, iptal), ihracat. *Otomatik ticaret* üstteki özet
  hücrelerinden biridir: durumu (kapalı — elle / açık) ve yanında Aç / Kapat düğmesi.
- **İnşaat (T)**: özet, bina karoları, kuyruk (sıralama, iptal, çalışan fabrikalar).
- **Üretim (Y)**: askeri fabrika / tersane kullanımı, hatlar (fabrika simgeleri, verimlilik, kaynak açığı), stok. Her
  hatta fabrika sayısı (− n +) ve ayrı duran sil düğmesi sağda, satırın ortasında.
- Ordu ekranı (ordular, ordular grubu, komutanlar, şablonlar) artık menüde yok: tümenleri haritada seçip doğrudan
  yönetirsin (bkz. [Savaş](05_savas.md)).
- **Donanma (N)**, **Hava (H)**: filolar ve kanatlar, görevler, görev bölgesi; kanatların "Otomatik" kutusu kapalı başlar.
  Her filo / kanat bir karttır: simge yuvası, adı ve nerede olduğu, gemi bileşimi ya da kanadın uçakları, bütünlük / uçak
  çubuğu, görev şeridi (seçili görev altın ve kalın, öbürleri soluk) ve bölge ile düğmeleri. Seçili kart altın
  çerçeveli, adı altın. Hava paneli açıkken haritaya tıklamak o bölgeyi panelin başında **hedef** yapar; orada her
  kanadın görev düğmeleri vardır (bkz. Savaş → Hava).
- **Lojistik (L)**: ekipman stok / kullanımda / günlük üretim / ihtiyaç / denge, kaynak dengesi.
- **Eyalet paneli**: haritada eyalete tıkla. Bina yuvaları, eyalet binaları, kaynaklar; kendi eyaletinde doğrudan inşa.
- **Seçili tümenler** (altta): ordu başlığı, özet hücreleri, şablona göre bileşim, tümen kartları ve araç çubuğu
  (bkz. [Savaş](05_savas.md)).
- **Olay penceresi**: başlık, resim, açıklama, seçenekler (etkileri ipucunda; şartı sağlanmayan seçenek kilitli).

## Harita kartları
- Kara bölgesinin üstünde: sahibi ve bizimle ilişkisi (bizim / müttefik / düşman), kıyı / liman / nehir; **arazi ve
  hava** (arazi, hava — açık, çamur, kış, sert kış —, yürüyüş hızı, buraya saldırının cezası, cephe genişliği, ikmal,
  nehir ve çıkarma cezası, savaşta hava üstünlüğü); **bölge** (nüfus, zafer puanı, altyapı, yapı yuvası, yapılar ve
  kaynaklar ikonlu hücrelerde); ülkelere göre oradaki tümenler (eğitimdekiler de) ve oradaki muharebe.
- Deniz bölgesinin üstünde: hava (kış denizi), kıyılar ve limanlar; ülkelere göre **deniz hâkimiyeti** (renkli pay
  çubuğu), bizim tarafın payı, nakliyenin güvenli olup olmadığı, oradaki filolar.
- Bir ülkenin üstünde **Ctrl** basılı: lider portresi, ilişki, ittifak, ideoloji çubuğu, istikrar, iç cephe, nüfuz, nüfus,
  fabrikalar, tümen/gemi/uçak (bizden güçlüyse kırmızı, zayıfsa yeşil), savaşlar, ulusal durumlar ve sürdürdüğü devlet
  programı. **Ctrl + tık** o ülkenin siyaset ekranını salt okunur açar.
- Sayılar renklidir: iyi yeşil, kötü kırmızı.

## Harita: iğneler
Harita bir kurmay masasıdır: 3D arazi kalır, üstündeki her şey model yerine haritaya saplanmış bir iğnedir. Uzakta
yalnız ülkeler, adları ve başkentler görünür; her zamanki harita ikonları (büyük şehir, liman, hava üssü), şehir adları
ve birlik rozetleri bir cepheye yaklaşınca belirir, yakında her ikon yerden yükselen bir iğneye dönüşür.
- **Zemin** boyalı bir haritadır: yakında tarlalar koyu kenarlı parsellerden bir yama işidir (yeşil, zeytin, hardal,
  buğday), dağlarda kuzeybatıdan aydınlanan ince sırtlar ve dereler toprak tonlarındadır, kıyıda turkuaz sığ su ve ince
  bir köpük çizgisi vardır. Ağaç modeli yoktur. **Siyasi** kip sadedir: her ülkenin rengi zeminin üstünde ince bir
  boya gibi durur — ülkenin içinde yarı saydam, sınırına doğru koyulaşır — ülkeler bir bakışta okunur. Renkler ülkelerin
  kendi renkleridir, tek bir açık ve canlı aralığa getirilir (koyu olan açılır, çok soluk olan koyulaşır, renk tonu hiç
  değişmez). Uzakta harita düz renktir: kabartma, nehir, bölge çizgisi yok; eyalet çizgileri yalnız cephe
  ölçeğinde; kabartma, nehirler ve bölge çizgileri yaklaştıkça gelir (bu kipte parsel, sırt, orman ayrıntısı yok);
  **Arazi** kipi ayrıntıyı her zoom'da gösterir (sırtlar, orman
  dokusu ve tarla yamaları ekranda sabit boyda, kabartma daha güçlü); **Arazi** kipi zemini kendi renkleriyle gösterir.
- **Şehir**: uzakta sade beyaz ad (başkentte altın). Yalnız büyük şehirlerin (başkentler ve 10+ zafer puanlı şehirler)
  modeli vardır; öbürleri her zoom'da sade ad olarak kalır. Yaklaşınca büyük şehrin belediye binası minyatürü (koyu,
  yuvarlak kaide üstünde kubbeli bina, `assets/models/city-hall.glb`) haritada yaylanarak çıkar, girişi kameraya bakar;
  şehir büyüdükçe model büyür, başkentin çatısı şehirde duran tümenin sayacının altında kalır. Ad bu kez kaidenin hemen
  altında koyu, ince çerçeveli bir kutudadır. Kaydırırken modeller boyunu ve yerini korur, görüş menzilinden çıkan model
  küçülüp kaybolur.
- **Uçaklar** yalnız yakında görünür.
- **Kara yolları ve demiryolları** yalnız **Yollar** harita kipinde (yakında) görünür: yollar ince krem, demiryolları
  traversli koyu çizgi; dağın arkasında kalan yol görünmez.
- **Tümenler, filolar, hava kanatları** aynı görünür. Uzaktan haritanın üstünde iğnesiz küçük rozetlerdir: tümende
  "bayrak | sayı", filoda "gemi | sayı", hava kanadında "uçak | sayı" (rozet ülke renginin koyusu, çerçevesi ülke
  renginde açıktan koyuya; seçilir ve emir verilir). Yaklaşınca her rozet demir bir iğnenin ucunda yuvarlak bir başa
  dönüşür (`art/soldier-pins.png` tasarımı): bronz çerçeveli (seçiliyse altın) koyu levha, solda şerit hâlinde ülkenin
  bayrağı, ortada birliğin resmi (piyade, motorlu, hafif ya da orta tank — yığında en çok olan —, gemi, denizaltı, uçak),
  sağ üstte küçük harita işareti, sağ altta büyük rakamla sayı. Haritada ad yazılmaz (savaşta yalnız kalabalık
  ediyordu; ad ipucunda ve seçim panelinde); onun yerine ordunun sayaçlarında levhanın sol üst köşesinin hemen dışında
  rütbe yıldızları: komutansız ordu ★, generalli ordu ★★, mareşalli ★★★; ordusuz tümende yıldız yok. Bayrak levhanın tam boyunda bir şerittir, sancak gibi dikey asılır (kesilmez,
  esnemez; kare bayrak kare kalır), renkleri boyalı haritanın tonuna uydurulmuştur (çok açık renkler yumuşatılır). Çok
  yakında yığın dağılır:
  içindeki taburlar aynı boyda yuvarlak başlarla ve sayılarıyla görünür (piyade, topçu, tanksavar, kamyon, tank).
  Bütünlük ve güç seçim panelindedir. Fare üstüne gelince iğneler büyümez. Her ordunun kendi sayacı vardır. Yakında ordunun ana sayacının (en çok tümenli olan) üstünde
  komutanının portresi durur; ordular bir bakışta ayırt edilir. Komutanın resmi yoksa adının baş harfleri görünür.
- **Yakında tümenler asker minyatürüdür** (masaüstünde; tarayıcı sürümünde levhalar kalır). Yakında tümen sayacı levha
  yerine yuvarlak koyu kaideli boyalı bir askerdir, masadaki bir minyatür gibi (çoğu zırhlı tümen olan yığın aynı
  kaidede, aynı biçimde dönen bir tanktır): kaidenin önünde ince pirinç çerçeveli ülke bayrağı ve tümen sayısı. Figürün haritada
  sabit bir boyu vardır (~12 km), bu yüzden zoom onu hiç yerinden oynatmaz — yaklaşınca büyük, uzaklaşınca küçük
  görünür, o kadar. Figürler yerde durur: yamaçta ya da tepede kaide araziye oturur (içine gömülmez), yamaç boyunca
  biraz yatar. Asker ve üstünde durduğu disk gittiği yöne döner: yürüyen asker yoluna (yol verirken adım attığı yana),
  muharebedeki düşmana, cephede duran en yakın düşman bölgeye bakar, boşta duran kameraya döner; bayraklı ve sayılı
  kaide hiç dönmez. Figürler birbirinin içinden geçmez ve kaymaz: her yer değişimi yürüme hızında, baktığı yöne bir
  yürüyüştür. Yürüyen figür yolundaki duranın çevresinden dolanır (duran itilmez), geçince yoluna döner; aynı yöne
  yürüyen ikiden arkadaki yol verir; karşılaşan iki yürüyen ikisi de yol verir; değecek iki duran figür biraz aralanır.
  Kamera güneyden baktığı için art arda duran figürler arasında bir figür boyu bırakılır. Varış yerindeki dostlarına
  yürüyen figür son bacaktan itibaren dizilişte boş bir yer ayırır ve dosdoğru oraya yürür; yola çıkan dizilişteki
  yerinden çıkar. Filolar ve hava kanatları levhalı kalır.
- **Yakında sayaçlar birbirini örtmez.** Ekranda değecek ya da binecek dost levhalar (yan yana ya da üst üste; örneğin
  bir bölgedeki birkaç ordu) tek noktada küçük bir ızgarada toplanır: ilk levha tam yerinde, iğnesinde durur, öbürleri
  yanına ve üstüne (sağ, sol, üst sıra...) iğnesiz dizilir. Her levha ızgarada kaldıkça hücresini korur — biri katılınca
  ya da ayrılınca öbürleri kıpırdamaz (boşluk kalır). Katılmak için değmek, ayrılmak için belirgin açılmak gerekir.
  Sayaç yalnız tümenleri gerçekten yürürken yer değiştirir. Bir noktada dokuzdan çok levha kapalı deste olur: toplam sayılı tek levha ve arkasında
  iki kart kenarı; tıklayınca hepsi seçilir, fare üstüne gelince ızgaraya açılır (fare çekilince kapanır). Figürlerde
  ızgara haritanın üstünde kurulur; yaklaşıp uzaklaşmak onu yeniden dizmez: üçer kişilik sıralar, her sıra öncekinin
  arkasında ve yarım yer kaymış, arkadakiler öndekilerin arasından görünür. Yürüyen
  sayaçlar yığına katılmadan geçer. Uzakta küçük rozetler yerinde kalır. Düşmana saldıran sayaç olduğu yerde durup
  oradan ateş eder (düşmana doğru kayıp geri gelmez); düşman temizlenince yürür. Yürürken düşmanla karşılaşan tümen
  bacağının yarısından önce durur: iki taraf da karşılıklı dursa arada bir buçuk figür boyu kalır — menzilden ateş
  ederler, dip dibe durmazlar. Tümenin duruş noktası hep kendi bölgesinin içindedir. Yok olan tümenin sayacı siyah-beyaz
  olur, birkaç saniyede yavaşça söner.
- **Yapılar**: eyaletin yapıları yan yana, altın çerçeveli koyu kare karolarda altın piktogramla (sivil ve askerî fabrika,
  tersane, rafineri, uçaksavar, deniz üssü), sağ alt köşesinde seviyesi; süren inşaat turuncu çerçeve ve "+n".
  Yapılar yalnız en yakın zoom adımlarında görünür. Hava üssünün kendi rozeti vardır.
  Binalar yalnız yakında görünür: yaklaşınca rozetler haritanın üstünde küçük ikon olarak belirir; daha da yaklaşınca
  tam boya büyür ve iğne altlarından yükselir. Farenin
  rozetin üstüne gelmesiyle rozet büyür, o yapının sesi duyulur ve kart o yapıyı anlatır (seviye / en çok, süren inşaat,
  ülkedeki toplamı, hava üssünde konuşlu kanatlar). Rozete tıklamak eyaletini açar (İnşaat açıkken: oraya inşa eder).
- **Muharebeler**: muharebedeki levhaların çevresi hafifçe nabız gibi yanıp söner: üstün gelen tarafta yeşil, zemin
  kaybeden tarafta kırmızı; aralarındaki çarpışan kılıçlar işareti hafifçe atar. Sayacın düşmana bakan yanında küçük
  turuncu namlu çakmaları çakar (figürde tüfeğinin yanında; figürün çevresi yanmaz). Sayaçların hemen yanında küçük oklar
  yükselip söner: durumu az önce düzelen tarafın yanında yeşil ▲, zemin kaybedenin yanında kırmızı ▼. Oklar sayacın
  parçasıdır, sayaç yürürse onunla gider (sayaç uzakta gizliyse ok muharebenin yanında çıkar). 1000 ve üstü sayılar
  kısaltılır (1.1K), uzun sayılar küçük yazılır: levhadan taşmaz.
- **Uçaklar** tek modeldir: iki kanadında ve dikey kuyruğunun iki yüzünde ülkenin bayrağını taşıyan küçük bir avcı;
  uçarken pervanesi döner (yerde durur). Üste park etmiş ya da görevinde uçarken görünür. Hava kanatlarının
  iğnesi yoktur: "uçak | sayı" rozeti hava üssünün üstünde durur (üsteki bütün uçaklar). Uçaklar uçak gibi uçar — sabit
  hız, sınırlı dönüş hızı, dönüşte yatış, keskin köşe yok — ve sefer yapar: kalkar, hedefe uçar, işini bir kez yapar,
  döner, iner, yerde bir süre yeniden silahlanır, sonra yine çıkar. Yakın destek hedefe dalar, dibinde bomba bırakır,
  dalışta makineliyle tarar; taktik bombardıman düz geçip bir dizi bomba atar; avcılar bölgelerinin çevresinde geniş
  devriye döngüsü yapar (it dalaşında manevra yapar). Hedefin üstünde durmadan dönüp bomba atmazlar.
- **Eyalet sınırları** belirgin koyu çizgidir, yakında daha kalın; Siyasi kipte bütün bir kıtaya uzaklaşınca söner
  (yalnız ülke sınırları kalır). Eyaletler ve Arazi kipinde her zoom'da görünür.
İğneler her zoom'da ekranda aynı boydadır.

## Ayarlar
Ana menü → **Ayarlar** ya da oyunda Esc → **Ayarlar**: ana ses, müzik, ses efektleri ve arayüz sesleri; müzik (oyun
durumuna göre otomatik ya da istenen parça sürekli); dil (English / Türkçe, anında değişir, süren oyun kaldığı yerden
devam eder); tam ekran, ekran kenarında kaydırma. Hepsi kaydedilir.
