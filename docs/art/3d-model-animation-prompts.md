# IRON FRONT — 3D model ve animasyon referans promptları

Tarih: 2026-09-25

Bu belge konuşmadaki 001–110 numaralı üretim listesini korur. 001–094 model/kit briefleri; 095–110 animasyon/efekt briefleridir. **110 brief, 110 tekil model veya görsel demek değildir:** kitlerdeki her nesne, rolün ülke varyantı ve animasyon klibi ayrı alt iş olarak üretilecektir.

## Kapsam ve kalite sınırı

- Mevcut oyun: 6 kara taburu türü, 3 hava ekipmanı sınıfı, 5 deniz ekipmanı sınıfı ve 8 bina türü. Bu bir ilk kapsamlı görsel paketidir, bütün WW2 tarihsel envanteri değildir.
- Malzeme/decal değişikliği yeni gövde değildir; farklı uçak, tank, üniforma ve miğfer geometrileri ayrı modellerdir.
- Üretilen paftalar **taslak referanstır**, tarihsel doğruluk sertifikası veya hazır 3D model değildir. Görünüş tutarlılığı ve dönem ayrıntıları Blender'a geçmeden doğrulanır. Gerçek ölçü, topoloji, UV, PBR, rig, LOD ve animasyon Blender aşamasında hazırlanır.
- 1936 başlangıcına sonraki yılların araçları konulmaz. Örneğin Spitfire hizmete 1938'de girdi; Zero 1940, P-51D 1944 dönemindendir. [Spitfire / RAF Museum](https://www.rafmuseum.org.uk/research/collections/supermarine-spitfire-i/), [Zero / USAF Museum](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/196313/AFmuseum/mitsubishi-a6m2-zero/), [P-51D / USAF Museum](https://www.nationalmuseum.af.mil/Visit/Museum-Exhibits/Fact-Sheets/Display/Article/196263/north-american-p-51d-mustang/).
- Temsilî gemi paketi tarihsel ülke filosu değildir: Fletcher Japon, King George V Alman gemisi diye yeniden boyanmaz; ülkeye özgü filolar ayrı gerçek sınıflar gerektirir.
- Köy/kasaba/şehir/başkent, bağımsız bina kitlerinden farklı yoğunluklarda oluşturulur; dört büyük birleşik mesh yapılmaz.
- Mevcut oyun tasarım dili, UI, modeller ve kod bu referans üretimi sırasında değiştirilmez.

## Dosya düzeni ve takip

- Görseller: `art/references/ww2/`
- İlerleme ve görsel bağlantıları: [Referans dizini](../../art/references/ww2/README.md)
- Makine tarafından okunabilir takip: [manifest.json](../../art/references/ww2/manifest.json)
- Her çıktı `NNN_slug/turnaround_v01.png` gibi sürümlü ad taşır; önceki çıktılar üzerine yazılmaz.
- Gerçekte gönderilen tam prompt görselle aynı klasörde `prompt_v01.md` olarak saklanır.
- Yerleşim ve animasyon kitlerinin alt parçaları tek tek açılır. İlk aşama: temel model paftası; sonra görünüş/parça çıktıları; ardından aynı onaylı model üzerinden animasyon referansları.
- Görseller Godot'a otomatik ithal edilmez; bu dizin yalnızca çalışma referansıdır.

## Ortak üretim promptu

> IRON FRONT adlı 1936–1945 dönemi büyük strateji oyunu için, Blender’da modellenmeye uygun bir 2D model referans seti üret. Gerçekçi oranlar, uzaktan okunabilir siluet ve ölçülü yüzey detayları kullan; oyuncak, çizgi film veya parlak plastik görünümü oluşturma. Aynı nesnenin ön, arka, sol, sağ, üst ve alt ortografik görünüşlerini; ayrıca ön ve arka üç çeyrek görünüşlerini göster. Bütün açılarda geometri, renk, aksesuar yerleşimi ve ölçek aynı kalsın. Ortografik açılarda perspektif kullanma. Nötr açık gri arka plan, eşit aydınlatma, minimum gölge; çevre, kaide, dramatik ışık, alan derinliği ve hareket bulanıklığı olmasın. Görünüşler birbirine değmesin. Önce numaralı bir referans paftası üret; onaydan sonra her görünüşü ayrı yüksek çözünürlüklü görsel olarak ver. Hareket edecek parçalar için ayrıca parça ayrım paftası hazırla. Ölçüleri yalnızca doğrulanmış kaynak varsa yaz; bilinmeyen ayrıntıları uydurma.

### Asker eki

> Ana referanslarda nötr A-pozu kullan. Eller açık, parmaklar birbirinden ayrılmış, bacaklar hafif açık olsun. Silah, miğfer, çanta ve teçhizatı ayrıca göster; silahı ellere kaynatma. Bütün ülke varyantları ortak insan iskeletine uyabilecek oranlarda olsun. Üniforma kesimini yalnızca renk değiştirerek geçiştirme.

### Tarihsel doğruluk eki

> Belirtilen model, alt varyant, ülke, yıl ve cepheye bağlı kal. Farklı üretim yıllarının parçalarını karıştırma. Boyama tarifini bütün ülkenin tek standart rengi gibi yorumlama; bu çalışma için seçilmiş bir görünüm olarak uygula. İşaretlerin yerleşimini ayrı decal referansında göster. Sağ ve sol yazıları aynalama. Tarihî fotoğraf veya teknik çizimle doğrulanamayan ayrıntıları belirt.

### Uçak eki

> Üst ve alt yüzey boyamalarını ayrı ayrı göster. Pervane pal sayısı, kanat planformu, kuyruk, motor kaportası ve iniş takımı seçilen alt varyanta doğru olsun. Ana pafta uçuş konfigürasyonunda; iniş takımları açık hâli ayrı paftada bulunsun. Pervane, dümen, irtifa dümeni, kanatçık, flap ve varsa bomba kapağını ayrı hareketli parça olarak göster. Kokpit ve motor iç mekânı üretme. Ulusal işaretleri sonradan değiştirilebilir decal olarak ele al.

### Animasyon eki

> Eklediğim onaylı model referansını aynen koru. Yeni karakter veya araç tasarlama. Gerçek animasyon dosyası değil, Blender’da animasyon hazırlanması için numaralı 2D anahtar poz şeridi üret. Her hareketi ayrı paftada göster; sabit kamera, sabit ölçek, görünür zemin çizgisi kullan. Döngülerde ilk ve son poz uyumlu olsun. Hareket bulanıklığı, hayalet uzuv ve üst üste bindirilmiş poz kullanma. İnsan hareketlerinde ön ve yan görünüş; mekanik hareketlerde parçaların dönüş eksenini göster.

## Askerler

### 001 — Türk piyadesi

> 1939 Türk Kara Kuvvetleri er piyadesi. Haki yün üniforma, dönemine uygun başlık/miğfer, kahverengi deri teçhizat ve fişeklik, ahşap kundaklı Türk Mauser tüfeği. Cumhuriyet dönemi üniformasını esas al; Osmanlı veya modern Türk askeri unsurları ekleme. Üniforma, başlık ve tüfeğin alt varyantını tarihî referansla tutarlı seç.

### 002 — Alman piyadesi

> 1939–1940 Alman Heer er piyadesi. Feldgrau M36 üniforma, M35 çelik miğfer, siyah deri çizme ve teçhizat, Kar98k tüfek. Kumaş, deri, ahşap ve boyalı çeliği birbirinden ayır. Geç savaş kamuflajı veya modern aksesuar ekleme.

### 003 — Sovyet piyadesi

> 1941 Sovyet Kızıl Ordu er piyadesi. Haki-kahverengi gimnastyorka, SSh-40 miğfer, kahverengi deri kemer ve fişeklik, Mosin-Nagant 1891/30 tüfek. Subay üniforması veya 1943 sonrası omuz apoletlerini bu sete ekleme.

### 004 — Britanya piyadesi

> 1940 Britanya er piyadesi. Kahverengimsi haki battledress, Mk II çelik miğfer, Pattern 1937 dokuma teçhizat, SMLE No.1 Mk III tüfek. Dokuma çantalar, tozluklar ve ayakkabıları açıkça ayırt edilebilir göster.

### 005 — ABD piyadesi

> 1944 Avrupa cephesindeki ABD er piyadesi. M1 miğfer, zeytuni-haki M1941 ceket, yün pantolon, kanvas tozluk, kahverengi bot, M1 Garand. Mermi kemerleri ve saha çantaları dönemine uygun olsun; Vietnam dönemi teçhizat kullanma.

### 006 — Fransız piyadesi

> 1940 Fransız er piyadesi. Haki üniforma ve kaput, M1926 Adrian miğfer, kahverengi deri teçhizat, MAS-36 tüfek. Birinci Dünya Savaşı’nın ufuk mavisi üniformasını varsayılan yapma.

### 007 — İtalyan piyadesi

> 1940 İtalyan er piyadesi. Grigio-verde gri-yeşil üniforma, M33 miğfer, deri fişeklikler ve Carcano M91 tüfek. Alpini tüyü gibi uzman birlik unsurlarını standart piyadeye ekleme.

### 008 — Japon piyadesi

> 1941 Japon İmparatorluk Ordusu er piyadesi. Haki Type 98 üniforma, Type 90 miğfer, bez dolak, kahverengi deri teçhizat ve Type 38 Arisaka tüfek. Üniformayı deniz piyadesi veya pilot teçhizatıyla karıştırma.

### 009 — Çin Milliyetçi piyadesi

> 1937 Çin Milliyetçi Ordusu’nun Alman eğitimli birliğinden er piyadesi. Gri-yeşil üniforma, M35 tipi miğfer, kumaş dolak ve Type 24 tüfek. Bu görünümü bütün Çin birliklerinin ortak üniforması olarak sunma.

## Asker rol varyantları

### 010 — Makineli tüfekçi

> Seçilen ülkenin onaylı piyade modelini koru. O ülke ve yılda kullanılan hafif makineli tüfeği, mühimmat çantalarını ve taşıma düzenini ayrı aksesuarlar olarak tasarla. Ayakta taşıma, diz çökerek hazırlık ve destekli ateş pozlarını ayrı paftada göster. Yeni bir insan gövdesi tasarlama.

### 011 — Topçu mürettebatı

> Seçilen ülkenin piyade modelinden topçu mürettebatı türet. Tüfeği kaldır; dürbün, top mermisi ve mürettebat ekipmanını ayrı nesneler olarak ver. Nişancı, doldurucu ve komutan görevleri için üç poz referansı üret. El ve mermi geometrileri birbirine geçmesin.

### 012 — Subay / birlik komutanı

> Seçilen ülke ve yılın üniformasına uygun bir saha subayı varyantı üret. Dürbün, harita çantası ve tabanca kılıfı ayrı aksesuarlar olsun. Nötr A-pozu ana referans olarak koru; emir verme pozunu ayrı göster. Tören üniforması kullanma.

## Tanklar

### 013 — Panzer II Ausf. C

> 1940 Panzer II Ausf. C. Koyu gri boyama; kompakt gövde, doğru tekerlek düzeni ve küçük kule. Gövde, kule, top, paletler ve yürüyüş takımı ayrı parça referanslarında gösterilsin.

### 014 — Panzer IV Ausf. G

> 1943 Panzer IV Ausf. G. Uzun namlulu top, koyu sarı taban üzerine ölçülü zeytin yeşili kamuflaj. Seçilen üretim örneğinin zırh ve yan etek durumunu bütün açılarda koru; farklı Ausführung parçalarını karıştırma.

### 015 — T-26

> 1939 tek kuleli T-26. Mat Sovyet koruyucu yeşili, ince gövde, perçin ve kaynak detayları, doğru yürüyüş takımı. Çift kuleli ilk modellerin parçalarını kullanma.

### 016 — T-34/76 Model 1942

> T-34/76 Model 1942. Mat yeşil, eğimli gövde zırhı, seçilen altıgen kule varyantı ve doğru palet genişliği. T-34/85 kulesi kullanma. Kule ve top pivotlarını parça paftasında işaretle.

### 017 — Light Tank Mk VI B

> 1940 Britanya Light Tank Mk VI B. Küçük yüksek kule, makineli tüfek silahlandırması ve dar paletler. Döneme uygun koyu yeşil iki tonlu boyama örneği seç; ayrıntıları teknik referansla doğrula.

### 018 — Cromwell IV

> 1944 Cromwell IV kruvazör tankı. SCC 15 olive drab görünümü, kutu biçimli kule ve gövde, büyük yol tekerlekleri. Challenger veya Comet parçaları kullanma.

### 019 — M3 Stuart

> 1942 M3 Stuart. Mat olive drab boyama, doğru küçük kule ve yüksek gövde silueti. M3 ve M5 gövde ayrıntılarını karıştırma. İşaretleri ayrı decal paftasında göster.

### 020 — M4A3 Sherman

> 1944 M4A3 Sherman, 75 mm top ve VVSS süspansiyonlu örnek. Olive drab boyama. Kaynaklı gövde, seçilen kapak düzeni ve kule bütün açılarda aynı olsun; 76 mm veya HVSS parçalarını ekleme.

### 021 — Renault R35

> 1940 Renault R35. Kısa namlu, küçük döküm kule, kompakt gövde. Yeşil, toprak kahverengisi ve sarımsı tonlardan oluşan dönem kamuflajı; desen bütün görünüşlerde süreklilik göstersin.

### 022 — SOMUA S35

> 1940 SOMUA S35. Karakteristik yüksek gövde ve tek kişilik kule, dönemine uygun çok renkli Fransız kamuflajı. Döküm yüzeylerini abartmadan göster; Renault R35 geometrisini büyüterek kullanma.

### 023 — L6/40

> İtalyan L6/40 hafif tankı, Kuzey Afrika görünümü. Açık kum rengi, kompakt perçinli gövde, küçük kule. Gerçek araç oranlarını ve palet düzenini koru.

### 024 — M13/40

> 1941 M13/40. Kum rengi gövde, perçinli zırh, karakteristik kule ve ön gövde makineli tüfek çıkıntısı. M14/41 ve sonraki modellerin ayrıntılarını bilinçsizce karıştırma.

### 025 — Type 95 Ha-Go

> Type 95 Ha-Go. Sarımsı toprak, yeşil ve kahverengi alanlardan oluşan tarihsel kamuflaj örneği. Asimetrik gövde ayrıntıları, küçük kule ve süspansiyon doğru olsun.

### 026 — Type 97 Chi-Ha

> İlk kuleli, kısa 57 mm toplu Type 97 Chi-Ha. Yeşil, kahverengi ve toprak sarısı kamuflaj. Shinhoto Chi-Ha’nın uzun toplu kulesini kullanma.

## Kamyonlar ve çekili silahlar

### 027 — Opel Blitz

> 1940 Opel Blitz 3 tonluk askerî kamyon. Koyu gri kabin ve gövde, mat koyu kanvas tente. Kabin, kasa, tente, tekerlekler ve ön direksiyon aksını ayrı göster. Açık ve tenteli kasa aynı şasiyi kullansın.

### 028 — ZiS-5

> 1941 ZiS-5 kamyon. Koruyucu yeşil kabin, ahşap kasa ve koyu lastikler. Kabin, şasi, kasa ve tekerlekleri ayrı parçalar olarak göster; Opel Blitz gövdesini yeniden boyama.

### 029 — GMC CCKW

> 1944 GMC CCKW 6×6 askerî kamyon. Olive drab boyama, üç aks, kanvas tenteli yük kasası. Seçilen kabin tipini bütün açılarda koru; tekerlek ve direksiyon hareketleri için parçaları ayır.

### 030 — 10,5 cm leFH 18

> 1940 Alman leFH 18 obüsü. Koyu gri, iki tekerlekli kundak ve açılır ayaklar. Namlu, geri tepme grubu, yükseliş mekanizması ve taşıma pozunu ayrı göster.

### 031 — 25-pounder

> Britanya QF 25-pounder saha topu. Zeytuni yeşil boyama, karakteristik kalkan ve ateşleme platformu. Çekili taşıma ve mevzilenmiş hâllerini göster; topu platformla tek katı parça yapma.

### 032 — ZiS-3

> Sovyet 76,2 mm ZiS-3. Koruyucu yeşil, ince namlu, karakteristik kalkan ve açılır kundak ayakları. Ateşleme ve taşıma konfigürasyonları aynı geometriyi kullansın.

### 033 — PaK 40

> 1943 Alman 7,5 cm PaK 40. Koyu sarı boyama, uzun namlu, düşük siluet ve çift katmanlı kalkan. Kundak ayaklarını, tekerlekleri ve namlu hareketini ayrı göster.

### 034 — Bofors 40 mm L/60

> II. Dünya Savaşı dönemi çekili, tek namlulu Bofors 40 mm L/60. Mat askerî yeşil. Döner üst grup, namlu yükselişi, mürettebat koltukları ve destek ayakları ayrı olsun. Modern L/70 ayrıntıları ekleme.

### 035 — 8,8 cm FlaK 36

> 1940 FlaK 36 ağır uçaksavar. Koyu gri, haç biçimli platform ve ayrılabilir taşıma düzeni. Yatay dönüş, namlu yükselişi ve geri tepme mekanizması için temiz parça ayrımı göster.

## Uçaklar

### 036 — Bf 109 E-4

> 1940 Bf 109 E-4 avcı uçağı. RLM 02/71 üst yüzeyler ve RLM 65 alt yüzeylerden oluşan bir Britanya Muharebesi boyama örneği. Sarı burun kullanılıyorsa belirli referans örneğine bağlı kal. Sonraki G serisinin kaporta çıkıntılarını ekleme.

### 037 — Ju 87 B-2

> 1940 Ju 87 B-2 Stuka. RLM 70/71 keskin sınırlı üst kamuflaj, RLM 65 alt yüzey. Ters martı kanat, sabit kaportalı iniş takımı ve gövde altı bomba taşıyıcısı belirgin olsun.

### 038 — He 111 H-3

> 1940 Heinkel He 111 H-3. RLM 70/71 üst kamuflaj ve RLM 65 alt yüzey. Asimetrik camlı burun, iki motor ve eliptik kanat planı doğru olsun; P serisi ayrıntılarını karıştırma.

### 039 — I-16 Type 24

> 1940 Polikarpov I-16 Type 24. Yeşil üst yüzey, açık mavi alt yüzey; kısa kalın gövde, radyal motor ve açık kokpit. İniş takımları kapalı uçuş görünümü esas olsun.

### 040 — Il-2

> 1943 iki kişilik Il-2 yer taarruz uçağı. AMT-4 yeşil ve AMT-6 siyah üst kamuflaj, AMT-7 mavi alt yüzey örneği. Seçilen düz veya geriye süpürülmüş kanat varyantını bütün görünüşlerde aynı tut.

### 041 — Pe-2

> 1942 Petlyakov Pe-2. Yeşil-siyah üst yüzeyler ve açık mavi alt yüzey. Çift motor, çift dikey kuyruk ve ince gövde. Seçilen üretim serisinin cam ve silah yerleşimini koru.

### 042 — Spitfire Mk I

> 1940 yaz sonu RAF Spitfire Mk I. Dark Earth ve Dark Green üst kamuflaj; Sky alt yüzey. Eliptik kanatlar ve üç palli pervane. Sonraki markların top çıkıntılarını veya büyük kuyruklarını ekleme.

### 043 — Typhoon Mk IB

> 1944 Hawker Typhoon Mk IB. Dark Green ve Ocean Grey üst yüzey, Medium Sea Grey alt yüzey; büyük çene radyatörü, kabarcık kanopi ve kanat altı roket rayları. İstila şeritlerini ayrı isteğe bağlı decal olarak göster.

### 044 — Blenheim Mk IV

> 1940 Bristol Blenheim Mk IV. Dark Earth/Dark Green üst kamuflaj; seçilen gündüz bombardıman örneğine uygun siyah alt yüzey. Uzatılmış camlı burun ve iki radyal motor doğru olsun.

### 045 — P-40E

> 1942 USAAF P-40E. Olive Drab üst, Neutral Gray alt yüzey; burun altı radyatör ve üç palli pervane. Köpekbalığı ağzını varsayılan ekleme; birliğe özel süslemeleri ayrı decal olarak ele al.

### 046 — P-47D-25

> 1944 P-47D-25 yer taarruz konfigürasyonu. Doğal metal dış yüzey, olive drab parlama önleyici burun üstü panel; kabarcık kanopi, dört palli pervane ve ayrı bomba askıları. Metal yüzeyi krom gibi parlak yapma.

### 047 — B-25C Mitchell

> 1942 B-25C Mitchell. Olive Drab üst ve Neutral Gray alt yüzey. Çift motor, çift dikey kuyruk, camlı burun ve üç tekerlekli iniş takımı. B-25J’nin farklı burun ve silah düzenini kullanma.

### 048 — Dewoitine D.520

> 1940 Dewoitine D.520. Koyu mavi-gri, yeşil ve kahverengi üst kamuflaj; açık mavi-gri alt yüzey. Savaş öncesi/1940 Fransız işaretleri kullan; sonraki Vichy şeritlerini ekleme.

### 049 — Bréguet 693

> 1940 Bréguet 693 taarruz uçağı. Dönem Fransız yeşil, kahverengi ve mavi-gri üst kamuflajı; açık mavi-gri alt yüzey. Kompakt çift motorlu gövde ve çift kuyruk düzeni doğru olsun.

### 050 — LeO 451

> 1940 Lioré et Olivier LeO 451. Fransız üç renkli üst kamuflajı ve açık mavi-gri alt yüzey. İnce aerodinamik gövde, iki radyal motor ve çift kuyruk; Bréguet 693 geometrisini büyüterek kullanma.

### 051 — Macchi C.202

> 1942 Macchi C.202 Folgore. Nocciola Chiaro 4 kum-kahverengi taban üzerinde koyu yeşil lekeli seçilmiş tarihsel desen; açık gri alt yüzey. Üreticiye özgü deseni tek referans örneğine göre tutarlı uygula.

### 052 — Breda Ba.65

> 1940 Breda Ba.65, tek kişilik yer taarruz varyantı. Kuzey Afrika’ya uygun kum tonlu taban ve yeşil-kahverengi kamuflaj örneği; açık gri alt yüzey. Kanat ve motor kaportası alt varyantla tutarlı olsun.

### 053 — Fiat BR.20M

> 1940 Fiat BR.20M Cicogna. İki motorlu orta bombardıman uçağı; toprak sarısı, yeşil ve kahverengi üst kamuflaj, açık gri alt yüzey. BR.20 ilk modelinin burun ayrıntılarını karıştırma.

### 054 — A6M2 Model 21

> 1941 Mitsubishi yapımı A6M2 Model 21 Zero. Hafif sıcak zeytuni ton taşıyan açık gri genel boya, koyu motor kaportası ve kırmızı Hinomaru işaretleri. Uçağı saf beyaz veya geç savaş koyu yeşili olarak boyama.

### 055 — Aichi D3A1

> 1941 Aichi D3A1 dalış bombardıman uçağı. Seçilen erken dönem açık gri boyama, koyu motor kaportası, kırmızı Hinomaru işaretleri. Sabit kaportalı iniş takımı, iki kişilik uzun kanopi ve dalış frenleri.

### 056 — Ki-21-IIa

> 1942 Mitsubishi Ki-21-IIa kara konuşlu bombardıman uçağı. Açık gri temel üzerinde koyu yeşil düzensiz üst kamuflaj örneği. Çift motor, tek dikey kuyruk ve uzun camlı burun. Ki-21-IIb üst silah kulesini ekleme.

### 057 — Türk PZL P.24G

> 1938 Türk hizmetindeki PZL P.24G. Martı biçimli yüksek kanat, radyal motor ve sabit iniş takımı. Haki/yeşil üst ve açık alt yüzeyli Türk örneğinin renklerini tarihî referansla doğrula. Dönemin Türk kare milliyet işaretlerini ayrı decal paftasında göster; modern işaretleri otomatik kullanma.

### 058 — Türk Vultee V-11

> 1939 Türk hizmetindeki Vultee V-11. Tek motorlu alçak kanatlı gövde, uzun sera tipi kanopi. Türk hizmetindeki belirli bir uçağı referans al; haki üst, açık alt yüzey ve dönem milliyet işaretlerini doğrula. Görseli birebir tarihsel alt varyanta bağla.

### 059 — Türk He 111 F-1

> 1938 Türk hizmetindeki Heinkel He 111 F-1. Erken basamaklı kokpit ve F serisine özgü kanat geometrisi; H serisinin tamamen camlı burun tasarımını kullanma. Boyama ve dönem Türk işaretlerini tarihî fotoğrafla doğrula.

## Gemiler

### 060 — Konvoy — Liberty

> 1942 Liberty tipi yük gemisi. Gri gövde, sade üstyapı, yük ambarları ve dönem yükleme direkleri. Modern konteyner, radar veya vinç ekleme. Su hattı ile su altı gövdesini ayrı göster.

### 061 — Muhrip — Fletcher

> 1942 Fletcher sınıfı muhrip. İnce uzun gövde, iki baca, doğru ana top yerleşimi ve torpido tüpleri. İlk üretim konfigürasyonu kullan; sonraki modernizasyonları karıştırma. Gövde, top kuleleri, torpido grubu ve pervaneleri ayrı göster.

### 062 — Denizaltı — Type VIIC

> 1941 Type VIIC denizaltı. Dar uzun gövde, dönem kulesi, güverte topu ve periskoplar. Gri üst yüzey, koyu su hattı altı. Sonraki genişletilmiş kule veya savaş sonrası düzen kullanma.

### 063 — Kruvazör — Southampton

> 1939 Southampton sınıfı hafif kruvazör. Dört üçlü ana top kulesi, iki baca ve dönem üstyapısı. Gri borda, koyu üst yüzeyler ve ahşap güverte bölgeleri ayrı malzemeler olsun.

### 064 — Zırhlı — King George V

> 1941 King George V sınıfı zırhlı. Önde dört namlulu ve iki namlulu, arkada dört namlulu ana kule düzeni doğru olsun. Dönem gri boyama; ana kule, ikincil silahlar ve gövdeyi ayrı parçalar olarak göster.

## Binalar

### 065 — Sivil fabrika

> 1930’lar tuğla sanayi fabrikası. Testere dişli çatı, ana üretim salonu, iki baca, yükleme kapısı ve küçük idare binası. Tuğla, kirli cam, beton ve çelik ayrı malzemeler. Tek bina ve büyüme modüllerini ayrı göster.

### 066 — Askerî fabrika

> 1940’lar silah ve araç fabrikası. Geniş üretim hangarı, yüksek endüstriyel pencereler, demiryolu yükleme kapısı ve kontrollü giriş. Sivil fabrikadan belirgin farklı siluet; modern depo veya cam ofis görünümü olmasın.

### 067 — Tersane

> 1930–1945 tersanesi. Kuru havuz, dönem kafes bomlu vinç, gemi yapım kızağı ve atölye. Boş kuru havuz ile inşa hâlindeki gemiyi ayrı nesneler olarak göster. Modern konteyner terminali oluşturma.

### 068 — Sentetik rafineri

> 1930–1945 kömürden sıvı yakıt üretimini temsil eden sanayi tesisi. İşleme kuleleri, boru bağlantıları, yatay ve dikey tanklar, kazan binası. Temiz okunabilir modüler yapı; modern dev petrokimya kompleksi görünümü kullanma.

### 069 — Altyapı bakım tesisi

> 1930’lar yol ve demiryolu bakım deposu. Küçük atölye, malzeme sundurması, taş ve travers istifleri, servis avlusu. Yol ve demiryolu parçalarını tesisten bağımsız göster.

### 070 — Hava üssü

> 1939 askerî hava meydanı. Çim veya sıkıştırılmış zemin pist, dönem hangarı, küçük kontrol binası ve dağınık uçak park alanları. Pist, hangar, kule ve sığınak ayrı modüller olsun. Jet üssü veya modern terminal ekleme.

### 071 — Deniz üssü

> 1939 donanma limanı. Askerî iskele, yakıt tankı, ikmal deposu, küçük idare binası ve mendirek. Tersanedeki kuru havuz ve gemi yapım tesislerinden farklı bir siluet oluştur. Gemileri modele birleştirme.

### 072 — Sabit uçaksavar mevzisi

> Daha önce üretilen uçaksavar topunu değiştirmeden kullanacak bir mevzi tasarla. Kum torbası veya alçak beton çevre, mühimmat nişi ve bağlantı yolu. Top için boş döner platform bırak; topu çevreyle tek parça yapma.

## Köprüler, yollar ve demiryolu

### 073 — Taş kemer köprü

> 1930’larda kullanılabilecek modüler taş kemer yol köprüsü. Tek açıklık, orta ayak, iki uç dayanak ve yaklaşım rampası ayrı parçalar. Yol üst kotu bütün birleşimlerde kesintisiz; kemer ve ayaklar fiziksel olarak bağlantılı olsun.

### 074 — Çelik kafes demiryolu köprüsü

> Dönem çelik kafes demiryolu köprüsü. Tek açıklık modülü, taş/beton ayak, uç dayanak ve ray tabliyesini ayrı göster. Kafesler ray açıklığını engellemesin; tekrar eden modüllerde ray uçları tam eşleşsin.

### 075 — Kısa beton yol köprüsü

> 1930’lar kısa betonarme kiriş köprüsü. Tabliye, korkuluk, uç dayanak ve isteğe bağlı orta ayak. Yol genişliği ve giriş yüksekliği sabit olsun; modern otoyol köprüsü tasarlama.

### 076 — Ahşap kırsal köprü

> Dar ahşap kırsal yol köprüsü. Ahşap tabliye, çapraz destekler, taş veya ahşap ayaklar. Sağlam taşıyıcı sistem ve düz giriş-çıkış; birbirine geçmeyen dekoratif kütükler oluşturma.

### 077 — Yol modül seti

> Aynı genişlikte düz, 45 derece viraj, 90 derece viraj, T kavşak ve dört yol kavşağı üret. Toprak ve dönem asfaltı iki yüzey varyantı olsun. Parçaları ayrı ayrı göster; kenar ve yükseklikleri birleşimde tam eşleşsin.

### 078 — Demiryolu modül seti

> Aynı ray açıklığında düz ray, geniş viraj, makas ve hemzemin geçit üret. Ray, travers ve balast yatağı okunabilir olsun. Her parçanın giriş ve çıkış ekseni eşleşsin; raylar kendi içine kesişmesin.

### 079 — İstasyon ve lojistik seti

> 1930’lar küçük demiryolu istasyonu, yük ambarı, su kulesi ve yükleme rampası. Her yapı ayrı nesne. Ek paftalarda buharlı lokomotif, kapalı yük vagonu ve açık yük vagonunu ayrı ayrı üret; binalarla birleştirme.

## Yerleşkeler

### 080 — Batı / Orta Avrupa kiti

> 1930’lar Batı ve Orta Avrupa yerleşkesi için bağımsız bir kır evi, bitişik şehir evi, köşe apartmanı, dükkân, belediye binası ve kilise üret. Kiremit veya arduvaz çatılar, sıva ve tuğla cepheler. Her binayı ayrı referans setinde göster.

### 081 — Anadolu / Balkan / Akdeniz kiti

> 1930’lar Anadolu ve yakın coğrafya için sıvalı kiremit çatılı ev, taş ev, küçük dükkân, avlulu yapı ve sade kamu binası üret. Cami ve kiliseyi ayrı isteğe bağlı bölgesel yapılar olarak göster; her şehre aynı dinî yapıyı yerleştirme.

### 082 — Doğu Avrupa kiti

> 1930’lar Doğu Avrupa yerleşkesi. Ahşap kırsal ev, sıvalı şehir evi, tuğla apartman, küçük istasyon binası ve bölgesel kamu yapısı. Savaş sonrası Sovyet panel apartmanlarını kullanma.

### 083 — Kuzey Avrupa kiti

> 1930’lar Kuzey Avrupa yerleşkesi. Dik çatılı ahşap ev, boyalı ahşap depo, tuğla şehir evi ve küçük kamu binası. Karsız ana modeller üret; kar örtüsünü geometriyi gizlemeyen ayrı varyant olarak göster.

### 084 — Doğu Asya kiti

> 1930’lar Japonya ve Çin için birbirinden ayrı iki mimari alt set oluştur. Japon ahşap ev ve dükkânlarını Çin avlulu ev ve dükkânlarıyla karıştırma. Tapınakları isteğe bağlı tekil yapılar olarak göster; bütün binaları süslü tapınak çatısıyla tasarlama.

## Kaynak ve üretim sahaları

### 085 — Petrol sahası

> 1930–1945 petrol çıkarma sahası. Dönem çelik sondaj kulesi, pompa ünitesi, küçük tank ve servis kulübesi. Her eleman ayrı nesne; modern açık deniz platformu veya çağdaş ekipman ekleme.

### 086 — Çelik tesisi

> 1930’lar çelik üretim tesisi. Yüksek fırın, dökümhane, baca ve yükleme alanı. Çeliği parlak metal dağlarıyla temsil etme; okunabilir endüstriyel siluet oluştur.

### 087 — Boksit madeni / alüminyum tesisi

> Boksit çıkarma alanı ile alüminyum işleme tesisini iki ayrı modül olarak üret. Açık kazı yüzeyi, cevher yükleme yapısı; diğer modülde uzun elektroliz salonları. Madeni doğrudan saf alüminyum külçeleriyle kaplama.

### 088 — Tungsten madeni

> 1930’lar sert kaya madeni. Maden ağzı, küçük kırıcı bina, cevher vagonu ve koyu cevher istifi. Tungsteni parlak mavi kristaller gibi gösterme.

### 089 — Krom madeni

> 1930’lar kromit madeni. Kaya ocağı, cevher ayıklama alanı, küçük yükleme tesisi ve koyu renkli cevher yığını. Tungsten madeninden yerleşim ve siluet farkıyla ayrışsın; fantastik metal kristalleri kullanma.

### 090 — Kauçuk plantasyonu

> 1930’lar kauçuk plantasyonu. Kauçuk ağacı, gövdede özsu toplama kabı ve küçük toplama kulübesi. Ağaçları ayrı model olarak göster; plantasyon tek katı blok olmasın.

## Doğal çevre

### 091 — Geniş yapraklı ağaç

> Strateji haritası için gerçekçi oranlı geniş yapraklı ağaç. Aynı türün küçük, orta ve büyük üç siluet varyantı. Gövde ve ana dallar okunabilir; yapraklar pamuk veya küre gibi görünmesin.

### 092 — İğne yapraklı ağaç

> Çam/ladin karakterli iğne yapraklı ağaç. Üç yükseklik ve taç silueti varyantı; açıkça ayrılan gövde ve dal katmanları. Kusursuz geometrik koni kullanma.

### 093 — Akdeniz bitki örtüsü

> Bir servi, bir zeytin ağacı ve bir kuru çalıyı ayrı modeller olarak tasarla. Mat yeşil-gri yapraklar, gerçekçi gövde ve uzaktan ayırt edilebilir siluet.

### 094 — Kaya seti

> Küçük kaya, geniş kaya çıkıntısı ve uçurum kenarı parçasını ayrı ayrı tasarla. Doğal tabakalaşma, mat yüzey ve yere oturan düz taban. Dokuya gömülü sert yönlü gölge kullanma.

## Animasyon ve efekt referansları

### 095 — idle

> Tüfeğini güvenli taşıyan piyadenin 4 anahtar pozlu sakin bekleme döngüsünü göster. Çok hafif nefes ve ağırlık aktarımı; ayaklar kaymasın, baş ve silah sürekli sallanmasın.

### 096 — walk

> Tüfek taşıyan piyade için 8 anahtar pozlu yerinde yürüme döngüsü. Temas, aşağı geçiş, geçiş ve yukarı geçiş pozlarını her iki bacak için göster. Ayaklar yere bassın; silah gövdeye girmesin.

### 097 — run

> Tüfeği iki elle tutan piyade için 8 anahtar pozlu yerinde koşu döngüsü. Kontrollü askerî koşu, kısa havada kalma evresi ve doğru ağırlık merkezi. Karikatürize sıçrama kullanma.

### 098 — turn_left / turn_right

> Piyadenin yerinde 90 derece sola ve sağa dönmesini ayrı 6 pozluk şeritlerde göster. Ayaklar küçük adımlarla yön değiştirsin; gövde sabit ayak üzerinde kayarak dönmesin.

### 099 — aim / fire / reload

> Nişan alma, tek atış ve yeniden doldurma hareketlerini üç ayrı paftada göster. Seçilen tüfeğin mekanizmasına uygun davran; sürgülü tüfek ile yarı otomatik tüfeğe aynı doldurma hareketini uygulama. Namlu alevini karakter çizimine gömme.

### 100 — MG deploy / fire / reload

> Seçilen ülkenin makineli tüfeğiyle destek açma, ateş pozuna geçme, kısa seri ateş ve mühimmat yenileme için ayrı anahtar poz şeritleri. Bipod, şarjör veya şerit besleme mekanizması seçilen silaha uygun olsun.

### 101 — Artillery deploy / aim / recoil / load

> Onaylı top modeli ve mürettebatıyla taşıma durumundan mevzilenme, yatay nişan, namlu yükselişi, geri tepme ve doldurma hareketlerini ayrı göster. Geri tepmede bütün top değil namlu grubu hareket etsin.

### 102 — Tank drive / steer / turret / fire

> Tankın düz sürüş, dönüş, kule dönüşü, namlu yükselişi ve atış geri tepmesini ayrı teknik şeritlerde göster. Paletler tekerleklerle tutarlı hareket etsin. Gövdenin tamamını ateş sırasında geriye sıçratma; namlu hareketini ayır.

### 103 — Truck drive / steer

> Kamyonun tekerlek dönüşü, ön tekerleklerle yönlenme ve hafif süspansiyon hareketini ayrı göster. Arka akslar ön aks gibi dönmesin. Araç gövdesini yumuşak lastik gibi bükme.

### 104 — AA traverse / elevate / fire

> Uçaksavarın yatay hedef takibi, namlu yükselişi ve geri tepmesini ayrı şeritlerde göster. Sabit platform yerde kalsın; yalnızca üst grup ve ilgili mekanizmalar hareket etsin.

### 105 — Aircraft propeller / controls / gear / attack

> Pervane dönüş ekseni, kanatçık ve dümen hareketleri, varsa iniş takımı açılma-kapanması ve bomba bırakma için ayrı teknik referanslar. Kanatlar organik biçimde bükülmesin. Sabit iniş takımlı uçaklara toplama animasyonu tasarlama.

### 106 — Ship sail / turret / fire / sink

> Geminin hafif yalpa, top kulesi dönüşü, namlu yükselişi, atış geri tepmesi ve batma durumlarını ayrı şeritlerde göster. Seyir izi ve su sıçramasını gövde geometrisine ekleme; ayrı efekt olarak işaretle.

### 107 — Submarine surface / dive / periscope

> Denizaltının yüzey seyri, kontrollü dalış ve periskop yükseltme hareketlerini ayrı göster. Gövde bükülmesin; dalış dümenlerini seçilen modelin doğru konumlarında kullan.

### 108 — Sanayi ve liman hareketleri

> Vinç bomu dönüşü, kanca yükselmesi, petrol pompası çevrimi ve fabrika kapısı açılması için her nesneye ayrı anahtar poz şeridi üret. Bina gövdeleri sabit kalsın. Dumanı modelin veya hareketli parçaların içine çizme.

### 109 — Buharlı tren

> Onaylı lokomotifin tekerlek ve biyel hareketini 8 pozluk yan görünüş şeridinde göster. Bağlantı çubukları tekerlek merkezlerine tutarlı bağlı kalsın. Buhar ve dumanı ayrı efekt olarak belirt.

### 110 — Efektler

> Namlu alevi, kısa patlama, duman, hareket tozu, gemi seyir izi ve su sıçraması için ayrı ayrı 8 karelik 2D efekt referans şeritleri üret. Şeffaf arka plan, sabit kare ölçüsü ve tutarlı merkez kullan. Bunların katı 3D model değil, oyun içi efekt referansı olduğunu koru.

