# Zombi modu — 07 Ekonomi, nüfus ve kaynaklar

> **Özet.** Bu belge *Gri Kordon* modunda salgının devlet ekonomisini nasıl aşındırdığını ve oyuncunun buna hangi araçlarla karşılık
> verdiğini tanımlar. Kararlar 01_vizyon.md ve 02_oynanis_dongusu.md'ye, nüfus bölmeleri 03_salgin_modeli.md'ye dayanır.
> - **Para birimi yine fabrikadır.** Yeni para, altın ya da bütçe sistemi yoktur. Mevcut ekonomi motoru olduğu gibi çalışır.
>   Mod ona dört katman ekler: **işgücü oranı** (ω), **gıda** (yedinci kaynak `food`), **karaborsa endeksi** (K) ve **mülteci kampları**.
> - **İşgücü:** Hasta, bakıcı, korkudan işe gelmeyen ve kamptaki nüfus çalışmaz. Fabrika ağırlıklı ülke oranı Ω, %5'lik kademeli
>   ulusal durumlarla fabrika çıktısını ve inşaat hızını düşürür (05'teki kademe kalıbı). Düşmüş eyalet hiç üretmez.
> - **Gıda:** 1 birim, 1 milyon kişinin bir günlük azığıdır (2.100 kcal). Açık önce **yerel** görülür: demiryolu aksayınca şehir aç
>   kalır, ülke tok olsa bile. Açlık ölümü, 1941–45 kıtlıklarından ölçeklenen bir eğriyle ancak azık ihtiyacın %60'ının altına inince başlar.
> - **Gıda Politikası** yeni bir yasa grubudur (4 basamak). Tayın ölümü önler ama karaborsayı ve istikrar kaybını getirir.
> - **Ticaret:** Liman karantinası ithalatı `30 / (30 + k)` oranında azaltır; kapalı sınır ticareti kesmez, pahalılaştırır.
> - **Sanayi taşıma** (1941 doğuya tahliyesinden ölçeklendi): hedefte yeniden kurma 3–4 ay sürer, kayıp riski %15.
> - **Motor değişikliği:** Beş küçük kanca gerekir ve hepsi WWII'de etkisizdir (§1.4). Geri kalan her şey JSON ve `rules.gd` ile yapılır.
> - **Örnek:** Romanya'nın 90 günü günlük sayısal çözümle hesaplandı (§13). Kordon kurulursa sanayi çıktısı %38 düşüyor, kurulmazsa %48.

---

## 1. Kapsam, ilkeler ve motorla ilişki

### 1.1 Kapsam
| Konu | Bu belgede | Başka belgede |
|---|---|---|
| Nüfus bölmeleri (S, E, F, H, R, V, Vb, D), yayılma, mülteci akış formülü | Ekonomik sınıflara çevrilmesi, işgücü | 03_salgin_modeli.md §3, §5.5 |
| Serum, aşı, tıbbi malzeme üretimi; sağlık yükü | Kaynak bağımlılığı (kauçuk) | 05_arastirma_merkezleri.md §4.5, §8 |
| Sürü, muharebe, kordon ordusu | Mühimmat tüketimi | 04_zombi_turleri.md §3 |
| Evreler, kazanma/kaybetme, puan | Yardım puanının ekonomik bileşenleri | 02_oynanis_dongusu.md §3–§4 |
| Gıda, işgücü, altyapı, ticaret, karaborsa, kamp, sanayi taşıma | **Bu belge** | — |

### 1.2 İlkeler
1. **Tek para birimi fabrikadır.** İthalatın bedeli, kampın gideri, onarımın maliyeti hep sivil fabrika, fabrika-gün ya da tüketim
   malı payı olarak ödenir. Oyuncu yeni bir kaynak türü öğrenmez; yalnız gıdayı öğrenir.
2. **Salgın ekonomiyi önce korkuyla vurur.** Dünya Bankası'nın salgın riski çalışması, 2003 SARS salgınının ekonomik etkisinin
   büyük bölümünün hastalıktan değil kaçınma davranışından geldiğini gösterir. Modda korku devamsızlığı hastalıktan önce gelir.
3. **Kıtlık çoğu zaman dağıtım sorunudur.** Sen'in 1943 Bengal çalışması, kıtlık yılında toplam gıdanın kıtlık olmayan yıllardan
   az olmadığını, ölümlerin fiyat ve gelir çöküşünden geldiğini gösterir. Bu yüzden gıda eyalet düzeyinde dağıtılır ve en yoksul
   dilim ayrıca hesaplanır.
4. **Oyuncu adına iş yapılmaz** (CLAUDE.md kural 1). Tayın, taşıma, sevkiyat ve kamp kararlarını oyuncu verir. Motorun kendiliğinden
   yaptığı tek şey sonuçları uygulamaktır: fabrika düşerse o fabrikanın üretimi de durur (§1.4, M1).
5. **Görünür ve sayılı.** Her ekonomik bedel bir ulusal durum (spirit) olarak Hükümet panelinde görünür. Aynı kalıp
   05_arastirma_merkezleri.md §4.3 ve §4.5'te de kullanılır. Böylece bedel kayda kendiliğinden girer ve motor değişmez.

### 1.3 Mevcut ekonomi: kalan, değişen, eklenen
| Sistem (kod) | Durum | Modda |
|---|---|---|
| Sivil fabrika, inşaat (`Economy._assign`, fabrika-gün) | Aynen | İnşaat hızı işgücü kademesiyle düşer |
| Askerî fabrika, tersane, üretim hattı (fabrika-saat, verimlilik %15→%50) | Aynen | Çıktı işgücü kademesiyle düşer. Düşen fabrikalar hattan kırpılır (M1) |
| Tüketim malı (`consumer_goods_factories`) | Aynen | Kamp ve tayın bürokrasisi `consumer_goods_mod` ile eklenir |
| Altı kaynak (petrol, çelik, alüminyum, tungsten, krom, kauçuk) | Aynen | Madenler işgücüyle ölçeklenir. Düşmüş eyalette kaynak sıfırlanır |
| **Gıda** | **Yeni** (`resources` listesine yedinci öğe) | §3 |
| Ticaret (8 kaynak = 1 sivil fabrika), ticaret yasası | Aynen | Gıda ihracatı yalnız artıktan yapılır (M2), ithalat liman durumuna bağlıdır (M3) |
| Konvoy (`convoy_factor`) | Aynen | Ortak başına ithalat çarpanı ile birlikte çalışır (M3) |
| Yakıt (`Military._fuel`) | Aynen | Petrol ithalatı da M3 çarpanından geçer |
| İnsan gücü (`manpower_pop`, askerlik yasası) | Aynen | Eyalet nüfusu haftada bir yaşayan nüfusa eşitlenir (§2.4) |
| İstikrarın etkileri (`stability_factory_mod` vb.) | Aynen | Açlık, karaborsa ve mülteci yükü istikrarı kademelerle düşürür (§9) |
| Altyapı binası (1.100 fabrika-gün/seviye) | Aynen | Düşmüş eyalette çürür (§5.3) |
| Eyalet sahipliği ve kontrolü | Aynen | Düşmüş eyaletin sahibi değişmez, fabrikası sayılmaz (M1) |

### 1.4 Motor kancaları (beş yöntem, hepsi WWII'de etkisiz)
Temel oyunda işgal edilen eyaletin fabrikası sahibine üretmeye devam eder. Bunun nedeni `Economy.count` işlevinin sahip olunan bütün
eyaletleri toplamasıdır. Zombi modunda bu kabul edilemez: düşmüş eyaletin fabrikası çalışmamalıdır. Aşağıdaki kancalar
`game/core/mode_rules.gd`'ye eklenir. Varsayılan değerleri motorun bugünkü davranışını değiştirmez. Mod altyapısı rehberindeki kural
geçerlidir: motor dosyasına dokunmak için onay gerekir (docs/modlar/README.md, "dur ve sor").

| # | Kanca | Varsayılan | Nerede çağrılır | Neden |
|---|---|---|---|---|
| M1 | `state_productive(st) -> bool` | `true` | `Economy.count`, `resource_total`, inşaat ilerlemesi | Düşmüş ya da boşalmış eyalet üretmez, inşaatı durur |
| M1b | `Economy.fit_lines(c)` (yeni yardımcı) | — | Sayım düşünce | Boşta kalmayan fabrikalar son eklenen hattan başlayarak kırpılır; oyuncuya haber gider |
| M2 | `extra_resource_need(c) -> Dictionary` | `{}` | `Economy.resource_need` | Gıda ihtiyacı yapay zekânın otomatik ticaretine ve ticaret panelindeki "ihtiyaç" sütununa girer |
| M2b | `export_cap(c, res, offered) -> float` | `offered` | `_run_trade` içinde arz hesabı | Ülke gıdasının yalnız artığını satar; kendi halkını aç bırakıp ihraç etmez |
| M3 | `import_factor(c, from_tag) -> float` | `1.0` | `resource_available`, `Military._fuel` (petrol), ticaret paneli | Liman karantinası ve sınır tutumu ortak başına ithalatı azaltır |

```gdscript
# economy.gd — M1 (özet): sayım yalnız üretken eyaletleri toplar
func _productive(st: StateRegion) -> bool:
	return Game.rules == null or Game.rules.state_productive(st)

func count(c: Country, building: String) -> int:
	...
	for sid in c.states:
		var st: StateRegion = World.states[sid]
		if _productive(st):
			n += st.building_level(building)
```
M1b bir kararı oyuncunun yerine vermez. Yalnız artık var olmayan fabrikayı hattan çıkarır. Hangi hattın öncelikli olduğu kararı
oyuncunun sıralamasından okunur ve yeniden dağıtım oyuncuya bırakılır. Bu, 02 §7.3'teki "oyuncu adına iş yapılmaz" denetiminden geçer.
Kancalar yalnız `Game.rules` doluyken çalışır. Yine de CLAUDE.md gereği motor değişikliğinden sonra WWII denge testi koşulur.

## 2. Nüfus muhasebesi

### 2.1 Bölmelerden ekonomik sınıflara
03_salgin_modeli.md §3.1'deki bölmeler ekonominin gördüğü altı sınıfa çevrilir. Oyuncu Salgın panelinde **bildirilen** sayıları görür
(01 Sütun 2). Ekonomi ise gerçek sayılarla işler: kuluçkadaki işçi, kimse bilmese de fabrikaya gelir.

| Sınıf (EN / TR) | Formül | Çalışır mı | Gıda tüketir mi | İnsan gücüne girer mi |
|---|---|---|---|---|
| Healthy / Sağlıklı | S + R + V + Vb | Evet | Evet | Evet |
| Incubating / Kuluçkada (görünmez) | E | Evet | Evet | Evet |
| Febrile / Ateşli hasta | F | Hayır; ayrıca 0,5 bakıcı bağlar | Evet | Hayır (haftalık güncellemede sayılır, bkz. §2.4) |
| In camps / Kampta | Q (mülteci kampı) | Hayır | Evet | Hayır |
| Hollow / Boş | H | — (yaşayan sayılmaz) | Hayır | Hayır |
| Dead / Ölen | D (salgın + açlık) | — | — | — |

Sömürge ve anavatan ayrımı yalnız motorun mevcut insan gücü kuralında kalır (sömürge %15). Gıda ve işgücü hesabında bütün eyaletler
aynı ağırlıktadır (01 §6.4: sömürgeler tampon değildir).

### 2.2 Eyalet işgücü oranı ω
```
ω_s = max(0, S + E + R + V + Vb − 0,75·U_s − c_bakım·F − Q_s) · (1 − a_s) / N⁰_s
a_s = a_max · clamp(bildirilen_yaygınlık_s / 0,01, 0, 1)
```
| Terim | Değer | Gerekçe |
|---|---|---|
| c_bakım | 0,5 | 1918'de fabrikalar ve çiftlikler, çalışanlar hasta olduğu ya da hasta yakınına baktığı için eksik kadroyla çalıştı. Oranın kendisi bizim tahminimiz: iki hastadan birinin evde bir çalışanı bağladığı varsayıldı |
| a_max (korku devamsızlığı) | 0,25 | 1918'de New York'ta telefon santrali çalışanlarının üçte biri hastaydı ve hizmet %15 kısıldı. Yine 1918'de salgından daha çok etkilenen ABD bölgelerinde imalat çıktısı %18 düştü (Correia ve ark.). Saldırgan bir hastalığın korkusu gripten güçlü olacağı için tavan bu mertebenin biraz üstünde seçildi |
| Doyma %1 | bildirilen (F+H)/N⁰ | Korku gerçek değil **bildirilen** sayıya tepki verir (01 Sütun 2). Bilgiyi saklayan hükümet devamsızlığı azaltır, ama bunun bedeli başka yerde (siyaset) ödenir |
| U_s | uyum bekleyen mülteci | Yeni gelen mülteci önce %25 verimle çalışır (§10.4) |
| Q_s | kamp nüfusu | §10.3 |

### 2.3 Ülke işgücü oranı ve kademeler
Sanayi, işçisinin olduğu yerde çalışır. Bu yüzden ülke oranı fabrika ağırlıklıdır. Şebeke etkisi (§5) de bu orana eklenir:
```
Ω   = Σ_s fab_s · min(ω_s, 1,05) / Σ_s fab_s          fab = sivil + askerî fabrika + tersane (yalnız üretken eyaletler)
Ω_e = Ω · (0,7 + 0,3 · E_şebeke)                       E_şebeke: §5.1
```
`rules.gd`, Ω_e'yi her gün hesaplar ve %5'lik kademeye yuvarlar. Kademe değiştiyse eski ulusal durum kaldırılır, yenisi eklenir
(`spirit` / `remove_spirit`). Bu, 05 §4.3'teki yöntemin aynısıdır.

| Ulusal durum | Ω_e | `factory_output` | `construction_speed` |
|---|---|---|---|
| — | ≥ 0,975 | 0 | 0 |
| `zm_workforce_05` Short-handed / Eksik Kadro | 0,925–0,975 | −0,05 | −0,05 |
| `zm_workforce_10` … `zm_workforce_55` | 5'er puan | −0,10 … −0,55 | aynı |
| `zm_workforce_60` Skeleton Shifts / İskelet Vardiya | < 0,425 | −0,60 | −0,60 |

Neden tavan 1,05? Uyum sağlamış mülteci ya da işgücü yönlendirmesiyle ω 1'i aşabilir, ama fabrika sayısı sabittir. Fazla işçi
ancak vardiya ekleyerek küçük bir artış sağlar.

### 2.4 Nüfusun motora yazılması ve insan gücü
`rules.gd` her pazartesi, üretken eyaletlerde `st.population = round(L_s)` (L = S+E+F+R+V+Vb, kamp hariç), düşmüş eyaletlerde
`0` yazar. Ardından ülke nüfusunu toplar ve `World.recompute_manpower_pop(c)` çağırır. Böylece:
- Askere alınabilir nüfus kendiliğinden küçülür. `manpower_used`, alınabilir sayıyı aşarsa takviye durur. Bu, mevcut kodun zaten
  uyguladığı "insan gücü tükendi" durumudur.
- Salgın modeli 1936 nüfusunu (N⁰) kendi dizisinde tutar. Motorun eyalet nüfusu yalnız "bugün denetimimizde yaşayan" anlamına gelir.
- Haftalık güncelleme, insan gücünün her gün oynamasını ve arayüzün titremesini önler.

**Örnek (§13):** Romanya'nın insan gücü nüfusu 16,53 milyondur (Besarabya, Bukovina ve Dobruca motor kuralıyla %15 sayılır).
Profesyonel ordu yasasıyla (%1,4) askere alınabilir nüfus 231.500 kişidir. 90 gün sonra bu sayı kordonlu senaryoda 225.900'e,
kordonsuz senaryoda 217.300'e iner.

### 2.5 İşgücü yönlendirmesi (karar)
**Labour Direction / İşgücü Yönlendirmesi** (`zm_labour_direction`): 75 nüfuz, 365 gün. ω'ya ×1,08 çarpanı ekler (180 günde
doğrusal olarak artar), istikrarı %3 düşürür. Şart: halkın dayanma iradesi ≥ %25.
Gerekçe: Britanya'da çalışan kadın sayısı 1939'dan 1943'e 5,1 milyondan 7,25 milyona çıktı; çalışma çağındaki kadınların oranı
%26'dan %36'ya yükseldi. Bu artış yönlendirme emirleriyle ve zorunlu hizmetle sağlandı. Mod bu dört yıllık dönüşümü %8'lik tek bir
çarpana indirir (kendi tahminimiz). Bu karar, olayı etkileyen bir **seçenektir**: oyun onu kendiliğinden açmaz.

## 3. Gıda ve tarım

### 3.1 Neden yedinci kaynak?
1936 dünyasında nüfusun çoğu toprakla geçiniyordu: 1930 Romanya sayımına göre nüfusun %78,2'si tarımla geçiniyordu. Salgının
sanayiden önce vurduğu şey tarladaki işgücü, demiryolu ve limandır. Tarihteki salgın ve savaş kıtlıklarının üçü de mod için kalıp
oluşturur: 1941–42 Yunanistan (abluka ve ticaretin kesilmesi), 1944–45 Hollanda (taşımacılığın kesilmesi), 1943 Bengal
(fiyatların halkın alım gücünü aşması). Motor kaynakları veriden okuduğu için (`buildings.json` → `resources`) gıda, ticaret
panelinde, eyalet panelinde ve lojistikte kendiliğinden görünür. Gereken iki şey `RES_food` çevirisi ve `resource_food` ikonudur.

### 3.2 Birim ve fiyat
| Karar | Değer | Gerekçe |
|---|---|---|
| 1 `food` birimi | 1 milyon kişinin 1 günlük azığı = 2,1 milyar kcal ≈ 620 ton buğday eşdeğeri | 2.100 kcal, BM mülteci ve gıda kurumlarının acil durum planlama değeridir |
| Fiyat | Motorun genel kuru: 8 birim = 1 sivil fabrika | Yeni fiyat sistemi yok. Doğrulama: Britanya 1939'da gıdasının ~%70'ini ithal ediyordu (yılda 20 milyon ton). 47,0 milyonluk anavatan için açık 32,9 birimdir. Bu 5 sivil fabrika eder, yani 28 sivil fabrikanın %18'i. Savaş öncesi dış ticaretin ağırlığıyla aynı mertebededir (kendi karşılaştırmamız) |
| İhtiyaç | L/10⁶ birim/gün (Boşlar yemez; asker de halktan sayılır) | Ordunun azığı ayrı bir kalem olarak açılmaz, halkın içinde sayılır |

### 3.3 Üretim
```
taban_s = Y_ülke · (N_ülke / 10⁶) · (N⁰_s · w_kat(s)) / Σ_{s∈ülke} (N⁰_s · w_kat)
üretim_s(t) = taban_s · min(ω̄_s, 1) · [eyalet üretken]         ω̄_s: ω_s'nin 60 günlük üstel ortalaması
```
- **Y (kendine yeterlilik)** modern ülke koduna (`st.adm0`) göre tutulur. Bu sayede İngiltere'nin sömürgeleri Britanya adalarının
  ithalat bağımlılığını devralmaz.

| adm0 | Y | Kaynak / gerekçe |
|---|---|---|
| `_default` | 1,05 | 1930'ların tarım ağırlıklı ülkeleri çoğunlukla kendine yetiyordu. %5 artış, piyasaya küçük bir arz sağlar (kendi tahminimiz) |
| GBR | 0,30 | Savaş öncesinde tüketilen gıdanın ~%30'u yurt içinde üretiliyordu |
| DEU | 0,85 | 1939'da gıdanın %15'i hâlâ ithal ediliyordu |
| ROU | 1,20 | Tarım nüfusu %78,2; Avrupa'nın başlıca mısır üreticisi. Artık payı kendi tahminimizdir |
| Diğer ithalatçılar ve ihracatçılar | 0,75 / 1,30 | **Doğrulanmalı** (açık soru 1) |

- **Kategori ağırlığı w_kat** tarım nüfusunun yerleşim türüne göre dağılımını temsil eder (kendi tahminimiz):
  wasteland 0,3 · pastoral 1,2 · rural 1,5 · town 1,3 · large_town 1,0 · city 0,6 · large_city 0,35 · metropolis 0,2 · megalopolis 0,1.
  Romanya'da bu ağırlıklarla Bükreş kendi ihtiyacının %46'sını, Braşov %133'ünü üretir.
- **60 günlük ortalama:** Tahıl yılda bir hasat edilir ve ambarda durur. İşgücü kaybının gıdaya yansıması haftalar alır. Salgın önce
  fabrikayı, bir mevsim sonra sofrayı vurur.
- Günlük üretim `rules.gd` tarafından haftada bir `st.resources["food"]` alanına yazılır. Motorun geri kalanı onu diğer kaynaklar
  gibi okur.

### 3.4 Stok
Ulusal tahıl stoku başlangıçta **30 günlük** ihtiyaçtır, en çok **120 gün** olabilir. Artık (ihracattan sonra kalan) stoka girer,
açık stoktan karşılanır. 30 gün kendi tahminimizdir: devlet ambarları ve şehir pazarları haftalar, çiftlik ambarları ise hasat
döngüsü boyunca stok tutar. Hasat mevsimliliği modellenmez (açık soru 3).

### 3.5 Dağıtım (eyalet düzeyi)
```
açık_s     = max(0, ihtiyaç_s − üretim_s)
havuz      = Σ artık_s − ihracat + ithalat · M3 + stok
teslim_s   = açık_s · min(1, havuz / Σ açık) · η_s
f_s        = (min(üretim_s, ihtiyaç_s) + teslim_s) / ihtiyaç_s          (eyaletin gıda yeterliliği)
η_s        = S(ω_s) · (0,8 kordonlu eyalet) · [üretken]  (+0,25 öncelikli sevkiyat, en çok 1)
```
Teslim edilemeyen gıda yok olmaz, stokta kalır. Ülke tok olabilir ama demiryolu işlemeyen şehir aç kalır. Tarihte bunun en açık örneği
Hollanda'dır: Eylül 1944 demiryolu grevine misilleme olarak batı eyaletlerine gıda ve yakıt taşımacılığı durduruldu. Resmî azık
26 Kasım 1944'te 1.000 kcal'nin, Nisan 1945'te 500 kcal'nin altına indi. Ülkenin doğusunda tarım sürüyordu. `S(ω)` hizmet eğrisi
§5.1'dedir. Kordonlu eyaletteki 0,8 çarpanı yük denetimini temsil eder ve 03 §7'deki kordon ordusuyla aynı eyaletlere uygulanır.

### 3.6 Yeterlilik, en yoksul dilim, açlık
**Eşitsizlik.** Ortalama f, en yoksulun f'si değildir:
```
f_yoksul_s = 1 − g · (1 − f_s),       g = yasa değeri (§3.7) + 1,5 · K        (K: karaborsa, §8)
```
Serbest piyasada g = 2,5. Bu, %10'luk bir açığın en yoksul beşte birin sofrasında %25'lik bir açık olarak görüneceği anlamına gelir.
Sen'in Bengal analizi niteliksel dayanaktır: fiyat artışı ücretleri geride bıraktığında yoksullar pazardan tamamen dışlanır.
2,5 katsayısı bizim seçimimizdir.

**Açlık ölümü** (günlük, eyalet başına):
```
m(x)    = 0                                   x ≥ 0,60
        = min(1,35·10⁻⁴ · e^{15(0,40 − x)}, 0,002)    x < 0,60
ölüm_s  = L_s · (0,8 · m(f_s) + 0,2 · m(f_yoksul_s))
```
| x (azık / ihtiyaç) | ≈ kcal | m (günde) | 6 ayda | Ölçek noktası |
|---|---|---|---|---|
| 0,60 (eşiğin hemen altı) | 1.260 | 0,0007% | %0,1 | Eşik |
| 0,50 | 1.050 | 0,003% | %0,5 | Hollanda 1944–45: resmî azık 500–1.000 kcal, ek kaynaklarla fiilî alım ~1.000 kcal; 4,5 milyon kişiden ~20.000 ölüm (~%0,45) |
| 0,40 | 840 | 0,014% | %2,4 | Ara bölge |
| 0,35 | 735 | 0,029% | %5 | Atina 1941–42 kışı: Atina–Pire'de 45.000 ölüm, Aralık 1941'de günde 300 |
| 0,25 | 525 | 0,13% | — | Leningrad, Aralık 1941: işçiye 250 g, bakmakla yükümlü olunana 125 g ekmek; Ocak 1942'de günde 3.500–4.000 ölüm |
| ≤ 0,22 | ≤ 460 | 0,2% (tavan) | — | Tavan, en kötü kuşatma aylarının mertebesidir |

Fiilî alım değerleri (x) belgelenmiş resmî azıklardan yaptığımız tahminlerdir. Eğri bu üç kıtlığın büyüklük sırasını izleyecek biçimde
seçildi, tek tek oturtulmadı (Hollanda ±1,6 kat). Açlık ölümleri 03'ün D bölmesine eklenir, Salgın panelinde ayrı satırda görünür.

**Açlık kademeleri** (ülke ortalaması f):
| Ulusal durum (EN / TR) | f | İstikrar | Dayanma iradesi | Fabrika çıktısı |
|---|---|---|---|---|
| `zm_hunger_1` Lean Tables / Kıt Sofralar | 0,85–0,95 | −%3 | −%2 | 0 |
| `zm_hunger_2` Shortage / Kıtlık | 0,70–0,85 | −%8 | −%5 | −%5 |
| `zm_hunger_3` Hunger / Açlık | 0,55–0,70 | −%15 | −%10 | −%15 |
| `zm_hunger_4` Famine / Büyük Açlık | < 0,55 | −%25 | −%15 | −%30 |

Doğrulama: Şubat 1946'da batı işgal bölgelerinde normal tüketici azığı 1.014 kcal'ye indirildi (f ≈ 0,48). Ruhr'da haftalık kömür
üretimi 1936 düzeyinin yarısının altına düştü. Modda f 0,48 olursa 4. kademe uygulanır: doğrudan −%30, ayrıca istikrar %50'den %25'e
iner ve motorun istikrar etkisi −%25 ekler. Toplam kayıp ≈ −%55 olur, yani gözlenen değerle aynı mertebededir.

### 3.7 Gıda Politikası (yeni yasa grubu `zm_rationing`)
| Yasa (EN / TR) | g | İhtiyaç tasarrufu | Karaborsa hızı r | İstikrar | Diğer | Şart |
|---|---|---|---|---|---|---|
| `zm_free_market` Free Market / Serbest Piyasa | 2,5 | 0 | 0 | 0 | — | — (1936'da herkes) |
| `zm_price_ceilings` Price Ceilings / Fiyat Tavanı | 1,8 | 0 | 0,02 | +%2 | `consumer_goods_mod` +0,01 | — |
| `zm_ration_cards` Ration Cards / Karne | 1,0 | %5 | 0,03 | −%3 | `consumer_goods_mod` +0,02 | Dayanma ≥ %10 |
| `zm_central_provisioning` Central Provisioning / Merkezî İaşe | 0,8 | %10 | 0,04 | −%6 | `consumer_goods_mod` +0,04, `factory_output` −0,02 | Dayanma ≥ %30 |

- **Karne:** Britanya'da tayın 8 Ocak 1940'ta başladı. Önce domuz pastırması, tereyağı ve şekerle sınırlıydı. Leningrad'da işçi ile
  bakmakla yükümlü olunan kişinin azığı iki katı farklıydı. Karne herkesi aynı açığa ortak eder (g = 1). Tasarruf (%5) istifçiliğin ve
  israfın azalmasını temsil eder (kendi tahminimiz).
- **Merkezî İaşe:** Ortak mutfaklar ve öncelikli kategoriler. Britanya'da 1943'te 2.160 "British Restaurant" günde 600.000 ucuz öğün
  veriyordu. g = 0,8, en yoksulu ortalamanın biraz üstüne taşır. Bedeli bürokrasi (tüketim malı) ve mutfaklara giden emektir.
- **Fiyat Tavanı** kısa vadede sevilir (+%2) ama karaborsayı besler. §13.4'teki hesapta en çok ölümü veren ikinci seçenektir.
- Yasa değerleri `law_def` ile doğrudan okunur (`zm_ration_gap`, `zm_ration_saving`, `zm_black_market_rate`). **Uyarı:** Yasalar
  `consumer_goods` ya da `manpower` anahtarı taşımamalıdır. Motor bu ikisini `law_value` ile "ilk bulunan" olarak okur ve askerlik ya da
  ekonomi yasasının değerini ezer. Bu yüzden yalnız `consumer_goods_mod` kullanılır.
- Değiştirme bedeli motorun yasa bedelidir (150 nüfuz). Şartlar yalnız motorun tanıdığı `war_support` anahtarıyla yazılır. Modda bu
  değer "halkın dayanma iradesi"dir.

**Gıda kararları**
| Karar (EN / TR) | Bedel | Etki | Gerekçe |
|---|---|---|---|
| `zm_priority_consignment` Priority Consignment / Öncelikli Sevkiyat | 25 nüfuz | Seçilen eyalette 30 gün η +0,25 | Demiryolu önceliği: yük vagonları yolcudan alınır |
| `zm_food_export_ban` Grain Export Ban / Tahıl İhracat Yasağı | 50 nüfuz | Artığın tamamı stoka gider (M2b: ihracat 0). Alıcı ülkelerle ilişki düşer | Kıtlıkta sık görülen ihracat yasakları |
| `zm_food_aid` Food Aid / Gıda Yardımı | Verilen gıda | Kendi stokundan hedef ülkenin stokuna aktarılır; varış 10–30 gün (deniz); 02 §4.1 yardım puanına sayılır | Yunanistan'da abluka Şubat 1942'de gevşetilince Atina gıda yardımı almaya başladı |

## 4. Diğer kaynaklar

| Kaynak | Modda | Gerekçe |
|---|---|---|
| Petrol, çelik, alüminyum, tungsten, krom | `st.resources = taban · min(ω̄, 1)`, haftalık; düşmüş eyalette 0 | Madenci de işçidir; motor değişmez |
| **Kauçuk** | Aynı kural, ama stratejik: serum (1), aşı (1) ve tıbbi malzeme hatları kauçuk ister (05 §8.1) | 1929'da dünya kauçuğunun %51,6'sı Malaya'dan geliyordu. 1930'larda plantasyonlar dünya üretiminin ~%90'ını Güneydoğu Asya'da sağlıyordu. Bu limanlar düşerse bütün dünyanın aşı hattı yavaşlar. Yedek, motordaki sentetik rafineridir |
| Yakıt | Motor aynen (`Military._fuel`). Petrol ithalatı M3'ten geçer | Motorlu kordon birlikleri, uçaklar ve devriye gemileri zaten yakıt harcar |
| **Mühimmat** | Ayrı kaynak **yok**. `UND` ile muharebedeki tümen her gün şablon ihtiyacının %0,3'ü kadar piyade teçhizatı ve %0,8'i kadar topçu teçhizatı harcar (`rules.gd`, `on_day`) | Standart piyade tümeni (7 piyade + 2 topçu taburu: 700 + 24) günde 2,1 + 0,19 birim harcar. Bu 9,3 fabrika-saat, yani %50 verimde ~0,8 askerî fabrika eder. Ölçek: ABD ordusunun planlama değeri tümen dilimi başına günde 650 tondu. Temmuz 1944'te 1. Piyade Tümeni muharebede günde 640 ton ikmal istiyordu. İlerleme sırasında ihtiyaç 300 tona indi ve bunun neredeyse tamamı yakıttı. Aradaki farkın çoğu cephanedir. "Bir tümen muharebede ~0,8 fabrika yer" hedefi bizim seçimimizdir |
| Yapı malzemesi | Ayrı kaynak **yok**. Fabrika-gün malzemeyi içerir | Motorda bina kaynak tüketmez. 05'teki bütün sağlık binası maliyetleri fabrika-gün cinsindendir; ayrı bir malzeme bu türetmeyi bozar |
| İlaç / tıbbi malzeme | 05'teki ekipmanlar: `zm_medical_supplies`, `zm_serum_dose`, `zm_vaccine_dose` | Bu belge yalnız kaynak bağımlılığını ekler: kauçuk ve alüminyum ithalatı M3 çarpanıyla yavaşlar |

## 5. Altyapı çöküşü: elektrik, demiryolu, haberleşme

### 5.1 Eşikli hizmet eğrisi
Ağlar küçük kayıpları tolere eder, büyük kayıplarda çöker. 1918'de New York'ta santral çalışanlarının üçte biri hastaydı ve hizmet
yalnız %15 kısıldı. Leningrad'da 1941–42 kışında yakıt tükendi: çalışan tek bir 30 MW türbin kaldı, toplu taşıma durdu, su şebekesi
dondu ve askerî üretim dışındaki fabrikalar kapandı. 1920 Rusya'sında da yakıt ile ulaşım birbirini aşağı çeken bir kısır döngüye
girmişti.
```
S(ω) = 1 − 0,45 · (1 − ω)                 ω ≥ 2/3      (1/3 eksik kadroda hizmet −%15: 1918 New York)
     = 0,85 · (ω − 0,40) / (2/3 − 0,40)    0,40 ≤ ω < 2/3
     = 0                                   ω < 0,40
E_şebeke = Σ fab_s · S(ω_s) / Σ fab_s
```
Alt kolun sıfır noktası (0,40) bizim seçimimizdir: kadronun %60'ı eksilince ağ işlemez.

### 5.2 Etkileri
| Ağ | Modeldeki yeri | Etki |
|---|---|---|
| Elektrik ve telefon | Ω_e = Ω · (0,7 + 0,3 · E_şebeke) | 1936 sanayisi şebekeye kısmen bağlıydı (buharla ve kendi kazanıyla çalışan tesisler vardı). 0,3 ağırlığı bizim tahminimizdir |
| Demiryolu (yük) | η_s = S(ω_s) (§3.5) | Şehirlerin gıdası |
| Demiryolu (yolcu) | 03 §5.2'deki yolcu çıkış payına S(ω_s) çarpanı (**öneri**; 03'te yok) | Çöken ağ salgını da yavaşlatır: acı ama gerçek bir yan etki |
| Haberleşme | Tespit gecikmesi (03 §8) | Bu belge sayı önermez; açık soru 6 |

### 5.3 Düşmüş eyalette altyapı çürümesi
Eyalet 120 gün düşmüş kalırsa altyapı binası 1 seviye kaybeder (en az 0). Yeniden inşa normal maliyettir (1.100 fabrika-gün).
Gerekçe: bakımsız demiryolu ve hat hızla bozulur; 1914–1925 Rusya'sında lokomotif stoku buna örnektir. 120 gün bizim seçimimizdir.

## 6. Fabrikalar: ele geçme, terk, taşıma, onarım

### 6.1 Durum makinesi (eyalet sanayisi)
```
 ÇALIŞIYOR ──(ω_s < 0,9)──▶ AKSIYOR ──(eyalet DÜŞMÜŞ, 02 §2.5)──▶ DÜŞMÜŞ ──(arındırma: bölgeler geri alındı)──▶ HASARLI ──▶ ÇALIŞIYOR
     │                          │                                      │
     │   oyuncu: "Sanayiyi taşı"│                                      └─(nüfus ~0)──▶ BOŞALMIŞ ──(yeniden yerleşim olayı, 02)──▶ AKSIYOR
     └──────────────────────────┴──▶ YOLDA (kaynak eyaletten düşer, hedefte yeniden kurma projesi) ──(proje biter)──▶ ÇALIŞIYOR (hedefte)
```
| Durum | Sayılır mı (M1) | Üretim | Oyuncuya |
|---|---|---|---|
| Çalışıyor | Evet | ω ile | — |
| Aksıyor | Evet | ω ile (kademe) | Eyalet satırında sarı |
| Düşmüş | **Hayır** | 0; hatlar kırpılır (M1b); eyaletteki inşaat durur | "Fabrikalar kaybedildi: N" haberi |
| Yolda | Hayır (kaynakta düştü) | 0 | Kuyrukta "Yeniden kurma" projesi |
| Hasarlı | Kalan seviyeler evet | Geri alınırken her seviye %25 olasılıkla yıkılmıştır (karmalı, belirlenimci) | Yıkılanlar normal inşaatla yeniden yapılır |
| Boşalmış | Evet ama ω ≈ 0 | ≈ 0 | Yeniden yerleşim olayı |

### 6.2 Sanayiyi taşıma kararı (`zm_relocate_industry`)
Oyuncu, Salgın panelindeki eyalet satırından kararı başlatır. Taşınacak fabrika sayısını ve hedef eyaleti (boş yuvası olan, kendi
üretken eyaleti) seçer.
- Bedel: 25 nüfuz. Kaynak eyaletten k seviye hemen düşer. Her seviye %85 olasılıkla yola çıkar (karmalı; %15 kayıp).
- Hedefte, bina maliyetinin **%40'ı** kadar bir "yeniden kurma" projesi kuyruğun başına eklenir. Oyuncu sırayı değiştirebilir.
- Örnek: Romanya'nın bir askerî fabrikası 1.440 × 0,4 = 576 fabrika-gün tutar. 7 kullanılabilir sivil fabrika, altyapı 2 ve barış
  ekonomisi yasasıyla (−%25) günde ~5,8 iş yapılır. İstikrar %42 (−%4) ve işgücü kademesi (−%5) bunu ~5,1'e indirir;
  proje 100–115 günde biter.
- Gerekçe: Temmuz–Kasım 1941'de 1.523 sanayi kuruluşu doğuya taşındı (667'si Urallara). Taşınan fabrikaların ilk ürünleri birkaç ay
  içinde çıktı. Doğu bölgelerinin askerî üretimi Mart 1942'de savaş başındaki bütün ülke düzeyine ulaştı. %40 maliyet ve ~3 aylık süre
  bu mertebeye göre seçildi. %15 kayıp bizim tahminimizdir.
- Oyuncu fabrikayı kendi elinde bırakmayı da seçebilir. Oyun, eyalet düşmeden önce taşımayı ya da yıkmayı kendiliğinden yapmaz.

### 6.3 Yeniden yerleşim (boşalmış eyalet)
02'deki "yeniden yerleşim olayı"nın ekonomik tarafı: gönüllü aileler başka eyaletten ya da uyum bekleyen mülteciler arasından
gelir (en çok N⁰'ın %10'u). Yerleşenler §10.4'teki uyum eğrisiyle çalışmaya başlar. Sayılar 02'deki olay metninde kesinleşir.

## 7. Ticaret: çöküş ve yeniden kurulma

### 7.1 Tarih
- **Hamburg 1892:** Kolera on hafta sürdü ve ticareti tamamen durdurdu. Kentin ticaret ve nakliye şirketlerinin zararı çok büyüktü;
  kent bütçesi 1892 ve 1893'te büyük açık verdi. Liman işçileri sendikasının üye sayısı bir yılda ~5.000'den 1.800'e indi; salgın
  bunun nedenlerinden biriydi.
- **Marsilya 1720:** Kıtlıktan çok hızlanan enflasyon kentin ticaretini vurdu; tüccarlar yabancı ortaklarına ödeme yapacak sağlam
  para bulamadı. Ayrıca gevşek karantina denetimi salgını başlatan gemiyi içeri aldı.
- **SARS ve Ebola:** Komşu ülkeler sınırlarını yalnız insana değil mala da kapattı. Kaçınma davranışının maliyeti hastalığınkini aştı.
- **1926 Uluslararası Sıhhiye Sözleşmesi:** Limanlar arası bildirim ve gemi sağlık belgesiyle karantinayı gereksiz yere uzatmamayı
  amaçlıyordu. Mod bu çerçeveyi "yeniden kurma" aracı olarak kullanır.

### 7.2 Model (M3: ortak başına ithalat çarpanı)
```
φ_ij = tutum_ij · T / (T + k_i)        T = 30 gün (ortalama sefer), k_i = alıcının liman karantinası (03 §7 `port_quarantine_days`)
tutum: açık 1,0 · denetimli 0,9 · kapalı 0,7                (02 §9'daki konvoy verimi değerleri)
```
- **Neden T/(T+k)?** Karantinada bekleyen gemi o sürede yeni sefere çıkamaz. Seferin k gün uzaması, aynı filonun taşıdığı yükü
  T/(T+k) oranında azaltır. T = 30 gün kendi tahminimizdir: 8–10 knot hızla giden bir 1930'lar yük gemisi için Akdeniz'de gidiş-dönüş
  ve liman süresi 2–3 hafta, Atlantik'te 4–5 haftadır.
- **Kapalı sınır ticareti kesmez, pahalılaştırır.** 02 kararı böyledir (−%30). Yolcu durur, denetlenen mal geçer.

| k (gün) | 0 | 7 | 14 | 21 | 40 |
|---|---|---|---|---|---|
| T/(T+k) | 1,00 | 0,81 | 0,68 | 0,59 | 0,43 |
| Denetimli tutumla | 0,90 | 0,73 | 0,61 | 0,53 | 0,39 |

Alıcı parayı sipariş miktarına göre öder (motor), ama elindeki gıda φ kadar azalır. Bu yüzden **karantina ithalatçı için ikinci bir
bedeldir.** Yapay zekâ bunu görür, çünkü açığını M2 ile yeniden hesaplar ve daha çok sipariş verir.

### 7.3 Piyasanın daralması
İhracatçının arzı yalnız üretken eyaletlerinden gelir (M1). Gıdada arz yalnız artıktır (M2b). Salgın büyük ihracatçıları vurdukça
dünya arzı küçülür ve siparişler "satıcı tamamını karşılayamıyor" uyarısıyla kısmen karşılanır (mevcut arayüz). Fiyat 8:1'de sabit
kalır; modda fiyatın işini karaborsa görür (§8). Ticaret kurunu değişken yapmak motor değişikliği ister (açık soru 5).

### 7.4 Yeniden kurma
| Araç (EN / TR) | Koşul | Etki |
|---|---|---|
| Clean Port Accord / Temiz Liman Anlaşması (iki taraflı) | İki ülkenin de liman eyaletlerinde 42 gün yeni vaka yok (02 "temiz ilan") | Karşılıklı liman karantinası en çok 5 gün, tutum en az "denetimli" |
| Bill of Health / Sağlık Belgesi (tek taraflı karar) | `zm_notifiable_disease` teknolojisi (05) | Kendi gemilerine uygulanan karantina −%30 (ortakların güveni) |
| Food Aid / Gıda Yardımı | §3.7 | Yardım puanı; alıcının açlık kademesi düşer |

Anlaşmanın diplomasi akışı (öneri, kabul olasılığı) diplomasi tasarımında kesinleşir. Bu belge yalnız ekonomik etkiyi tanımlar.

## 8. Karaborsa

### 8.1 Tarih
- **Fransa 1940–44:** Paris'te geçim maliyeti Ağustos 1939 ile Temmuz 1942 arasında %65,5 arttı. 1942 yazında azık %12 kısıldı.
  1944'te resmî azık günde 1.050 kcal'ydi. Kentliler açığı karaborsayla ve köylüyle doğrudan takasla kapattı.
- **Yunanistan 1941–42:** Abluka, el koyma ve bozulan altyapıya güçlü bir karaborsa eklendi; sonuç kıtlık oldu.
- **Batı Almanya, 20 Haziran 1948:** Para reformu ve fiyat denetimlerinin kaldırılmasıyla saklanan mallar raflara çıktı, karaborsa
  neredeyse bir gecede kayboldu, üretim kısa sürede savaş öncesi düzeye döndü.
- **Kara Ölüm (1348–51):** İşgücü kıtlığında nominal ücretler 1340'ların başından 1370'lerin başına yarıdan fazla arttı. Ücretleri
  dondurmaya çalışan 1351 yasası amacına ulaşamadı. Ders: kıtlıkta fiyatı yasakla tutmak arzı yer altına iter.

### 8.2 Model
```
baskı p = max(0, 1 − f_ülke) + 0,3 · tüketim_kesintisi              tüketim_kesintisi = max(0, 0,33 − tüketim_malı_payı) / 0,33
dK/dt   = r_yasa · p · (1 − K) − (0,01 + d_mücadele) · K            K ∈ [0, 1]
etkiler : g += 1,5·K (§3.6); kademeli istikrar ve nüfuz kaybı (aşağıda)
```
Denge değeri `K* = r·p / (r·p + d)`. Örneğin karnede (r = 0,03) %20'lik açıkta K* = 0,375 olur. Mücadele kararıyla (d = 0,03)
K* = 0,17'ye iner. Serbest piyasada K = 0'dır, çünkü orada tayını fiyat yapar (g = 2,5). Oyuncunun seçimi şudur: **açlığı yoksula mı
yıkacaksın, yoksa kuyruğa ve karaborsaya mı?**

| Ulusal durum (EN / TR) | K | İstikrar | `political_power_gain` | `consumer_goods_mod` |
|---|---|---|---|---|
| `zm_black_market_1` Under the Counter / Tezgâh Altı | 0,10–0,25 | −%2 | −0,05 | 0 |
| `zm_black_market_2` Black Market / Karaborsa | 0,25–0,50 | −%4 | −0,10 | +0,01 |
| `zm_black_market_3` Shadow Economy / Gölge Ekonomi | ≥ 0,50 | −%8 | −0,20 | +0,02 |

**Kararlar ve olaylar**
| Ad (EN / TR) | Bedel / koşul | Etki |
|---|---|---|
| `zm_crackdown` Crack Down on Profiteers / Vurguncularla Mücadele | 50 nüfuz, 90 gün; tayın yasası ≥ Fiyat Tavanı | d +0,02; istikrar −%2 |
| `zm_currency_reform` Currency Reform / Para Reformu | 100 nüfuz; f ≥ 0,95 (30 gün) ve evre ≥ Karşı Saldırı | K = 0; 60 gün istikrar −%5, ardından 120 gün `factory_output` +0,05 (1948) |
| Olay `zm_hoarders` The Hoarders / İstifçiler | K ≥ 0,25 | §10.6'daki metin |

## 9. İstikrar ve halkın dayanma iradesi

### 9.1 Ekonomik baskıların toplamı
| Kaynak | İstikrar | Dayanma iradesi | Bağlantı |
|---|---|---|---|
| Açlık kademesi | 0 … −%25 | 0 … −%15 | §3.6 |
| Karaborsa kademesi | 0 … −%8 | — | §8.2 |
| Mülteci yükü | 0 … −%10 | — | §10.5 |
| Gıda Politikası yasası | +%2 … −%6 | — | §3.7 |
| Karantina, sıkıyönetim | 02'deki değerler | 02 | 02 §3.4, §4.2 |
| İşgücü kademesi | **yok** | yok | İşgücü doğrudan üretimi keser; istikrara ikinci kez yansıtılmaz |

Motor, istikrarı fabrika çıktısına zaten bağlar: istikrar %50'nin altındaysa her puan için −%1 çıktı ve −%0,5 inşaat. Bu yüzden ekonomi
ile moral arasında **bir sarmal** vardır: açlık → istikrar ↓ → çıktı ↓ → gıda ithalatı için fabrika ↓ → açlık.

### 9.2 Sarmalı kıran araçlar
1. **Karne:** Ölümü keser (§13.4). Karşılığında istikrar ve karaborsa bedeli ödenir.
2. **Gıda yardımı almak:** Diğer ülkelerin yardım puanı bunu teşvik eder (02 §4.1).
3. **Sanayiyi taşımak:** Geçici kayıp, kalıcı güvence.
4. **Ulusal birlik hükümeti:** 02'deki İç Çöküş olayının seçeneği.
5. **Öncelikli sevkiyat:** Yerel açlığın ulusal krize dönüşmesini önler.

Tarihte bu sarmalın ters örnekleri de vardır. 1830–31 ve 1892 Rusya'sında kordon ve yol yasakları gıda yollarını kesti ve ayaklanmalara
yol açtı (01 Sütun 3). Modda bunun karşılığı, kordonlu eyaletteki η ×0,8 ile açlık kademesinin birleşmesidir.

## 10. Mülteciler: akın, kabul kararları, kamp ekonomisi

### 10.1 Akış
Kaçış formülü 03 §5.5'tedir: Boş payı %2'yi geçince başlar, günde en çok %3'tür, sınırda bir havuzda birikir. 03'ün ölçümüne göre
kaçanların çoğu sağlamdır ve mülteci katmanı dünya ölümlerini değiştirmez. Bu belge ekonomik tarafı ekler: gıda, kamp gideri,
uyum süresi ve işgücü.

### 10.2 Olay: "Sınırda Mülteciler" / "Refugees at the Border" (`zm_refugees_at_border`)
Havuz 5.000 kişiyi geçince gelir. Aynı kaynak eyaletten en çok 30 günde bir gelir (03). Seçilen politika, oyuncu değiştirene kadar
sonraki gelişleri de yönetir (03'ün `refugee_policy` etkisi).

> **EN:** *"Border post {province} reports {n} civilians from {country} waiting at the barrier: families with carts, railwaymen,
> a village doctor. They say the grey sickness has reached their towns. Our district officer asks for orders."*
> **TR:** *"{province} sınır karakolu, {country} tarafından gelen {n} sivilin bariyerde beklediğini bildiriyor: el arabalı aileler,
> demiryolcular, bir köy hekimi. Gri hastalığın kasabalarına ulaştığını söylüyorlar. Kaymakam emir bekliyor."*

| Seçenek (EN / TR) | Etki | Bedel |
|---|---|---|
| Open the barrier / Bariyeri açın | Havuz sınır eyaletine S ve E olarak girer (E görünmez, 03 §5.5). Yardım puanı + | Gıda ihtiyacı +n/10⁶; uyum süresince düşük verim; mülteci yükü (§10.5) |
| Admit through quarantine camps / Karantina kamplarından geçirin | 14 gün kamp: kuluçkadakilerin %99,7'si (1 − (2/3)¹⁴) belirti verir ve izole edilir. Sonra "Bariyeri açın" gibi. Yardım puanı + | 25 nüfuz; kamp gideri (§10.3); kamp nüfusu çalışmaz |
| Keep the barrier closed / Bariyer kapalı kalsın | Havuz kalır. Kapalı sınır %5 sızdırır (03). 30 gün sonra kalan havuz başka bir komşunun sınırına yönelir | Kaynak ülkeyle ve yardım veren ülkelerle ilişki −; yardım puanı yok; komşunun yükü artar (01 Sütun 5) |

İçerik kuralı (01 §6.2): Reddetme seçeneğinin metninde ve sonucunda şiddet yoktur. Mülteciler geri döner ya da başka yöne gider;
oyun bunu yalnız sayı olarak gösterir.

### 10.3 Kamp ekonomisi
| Kalem | Değer | Gerekçe |
|---|---|---|
| Süre | 14 gün | 03'ün karantinalı kabul kuralı. Kuluçka ortalama 3 gündür; 14 gün kuyruğu kapatır |
| Gıda | Kamp nüfusu kampın bulunduğu eyaletin ihtiyacına eklenir | — |
| Gider | `consumer_goods_mod` += 0,5 · (kamp nüfusu / ülke nüfusu) | Çadır, battaniye, sabun, kazan: sivil sanayiden. Nüfusun %1'i kadar kamp tüketim malını %0,5 artırır (kendi tahminimiz) |
| Kamp ölümü | f_kamp ≥ 0,9 ise ek ölüm yok. f < 0,6 ise günde %0,033; arası doğrusal | Retirada (1939): Şubat–Haziran arasında Argelès kampından 100.000'den fazla kişi geçti, en az 4.000'i öldü (~4 ayda %4) |

### 10.4 Uyum ve işgücü
```
U_s(t+1) = U_s(t) · (1 − 1/180)              yeni gelen U'ya eklenir; ω_s içinde −0,75·U (§2.2)
```
Yeni gelen %25 verimle başlar, 180 günlük sabitle tam verime yaklaşır. **İskân Programı** (`zm_resettlement_programme`,
her 100.000 mülteci için 200 fabrika-gün) sabiti 90 güne indirir. Gerekçe: 1922–23'te Yunanistan'a gelen 1,2 milyonu aşkın mülteci
nüfusu yaklaşık dörtte bir artırdı. Milletler Cemiyeti'nin kurduğu Mülteci İskân Komisyonu 1924 ve 1927'de iki dış borç yönetti,
tohum, alet, hayvan ve ev verdi. 1928'e kadar 145.127 aile 2.085 tarım köyüne yerleşti. Maliyet eşlemesi bizimdir.

### 10.5 Mülteci yükü (istikrar)
| Ulusal durum | Son 180 günde kabul edilen / nüfus | İstikrar |
|---|---|---|
| `zm_refugee_strain_1` | %0,5–2 | −%1 |
| `zm_refugee_strain_2` | %2–5 | −%3 |
| `zm_refugee_strain_3` | %5–10 | −%6 |
| `zm_refugee_strain_4` | ≥ %10 | −%10 |
1922 Yunanistan'ı (+%25) 4. kademeye düşer. §13'teki Romanya (35.000 kişi, %0,18) hiçbir kademeye girmez. Mültecinin asıl bedeli
istikrar değil, kamptaki organizasyondur. Faydası ise kısa sürede işgücü ve yardım puanı olarak geri döner.

### 10.6 Olay: "İstifçiler" / "The Hoarders" (`zm_hoarders`, K ≥ 0,25)
> **EN:** *"Inspectors found grain enough for a district locked in a merchant's warehouse, while the ration queues outside grow longer."*
> **TR:** *"Müfettişler, dışarıda karne kuyrukları uzarken bir tüccarın deposunda bir ilçeye yetecek tahıl buldu."*

| Seçenek | Etki |
|---|---|
| Requisition the stocks / Stokları müsadere edin | Stok +3 gün, K −0,05, istikrar −%2 (mülk sahiplerinin tepkisi) |
| Fine them and sell at the fixed price / Ceza kesip tavan fiyattan sattırın | Stok +1 gün, K −0,02, nüfuz +10 |
| Leave it to the courts / Mahkemeye bırakın | K +0,03 |

### 10.7 Yapay zekâ politikası
Oyuncu dışındaki ülkeler için (`rules.gd`, otomatik): f ≥ 1,0 ve sınır eyaleti SALGIN değilse **kabul**, 0,85 ≤ f < 1,0 ise **kamp**,
aksi hâlde **ret**. Gıda Politikası: f < 0,95 iken 14 günde karne, f < 0,80 iken merkezî iaşe (şart sağlanıyorsa). K ≥ 0,25 iken
mücadele kararı alınır. Politika ideolojiye göre değişmez; yalnız kapasiteye bakar (01 §6.4).

## 11. Önlemlerin ekonomik bedeli (özet)

| Önlem | Ekonomik bedel | Kaynak |
|---|---|---|
| Zorunlu Karantina (yasa) | Fabrika çıktısı −%10, istikrar −%8 | 02 |
| Sınır tutumu denetimli / kapalı | O ortaktan ithalat ×0,9 / ×0,7 | 02, §7.2 |
| Liman karantinası k gün | Bütün deniz ithalatı ×30/(30+k) | §7.2 |
| Yurt içi seyahat yasağı | Yolcu ×0,2 (03). **Öneri:** yük etkilenmez; `factory_output` −0,03 (işe gidiş) | 03 §7; öneri bu belgenin |
| Kordon ordusu | Kordonlu eyalete gıda sevkiyatı ×0,8; mühimmat §4 | §3.5, §4 |
| Sıkıyönetim | 02'deki değerler | 02 §3.4 |
| Tayın yasaları | §3.7 | Bu belge |
| Sanayi taşıma | Fabrika ~100 gün yok, %15 kayıp | §6.2 |
| Mülteci kampı | Tüketim malı, 25 nüfuz | §10 |

## 12. Günlük ekonomi adımı, performans ve kayıt

`rules.gd` `on_day()` sırası (03'ün salgın adımından **sonra**, AI'dan sonra, oyun sonu denetiminden önce):
```
1  eyalet ω_s, ω̄_s, S(ω_s)                         1.652 eyalet × ~20 işlem
2  ülke Ω, E_şebeke, Ω_e → işgücü kademesi (değiştiyse spirit değiştir, Economy.invalidate_counts)
3  gıda: üretim, ihtiyaç (M2 değeri önbelleğe), ithalat (resource_available, M3 dahil), dağıtım, f_s, f_yoksul
4  açlık ölümü → D (03 dizisine), açlık kademesi
5  karaborsa K, kamp kuyrukları, uyum U
6  mühimmat (UND ile muharebedeki tümenler)
7  pazartesi: st.population ve st.resources yaz, recompute_manpower_pop; ay başı Economy.mark_trade_dirty
```
**Maliyet:** Adım başına eyalet başına onlarca işlem yapılır. 03 §12'nin ölçtüğü salgın adımı 4–8 ms/gün sürüyor; ekonomi adımı
bunun altında kalmalıdır. Hedef: `sim.gd` profilinde "zm_economy" satırı web'de ≤ 3 ms/gün.
**Belirlenimcilik:** Rastgelelik yalnız kayıpta vardır (taşıma %15, geri alma %25). Bunlar 03 §11.2'deki durumsuz sayaç karmasıyla
(ayrı akış numarası) çekilir.
**Kayda eklenecekler** (`to_save`): ω̄_s dizisi, U_s dizisi, kamp kuyrukları (gün, kişi, E), ulusal stok, K, etkin kademeler,
taşıma projelerinin kaynak bilgisi, düşmüş kalma sayaçları (altyapı çürümesi), açlık ölümü toplamı. Diziler 03 §11.4'teki gibi
base64 `PackedFloat64Array` olarak yazılır.

## 13. Örnek: Romanya'nın 90 günü

### 13.1 Kurulum
- **Ülke:** Romanya, *Salgın* zorluğu. 19,56 milyon nüfus, 18 eyalet, 9 sivil ve 4 askerî fabrika, 1 tersane, petrol 36.
  Yasalar: profesyonel ordu, barış ekonomisi, kliring anlaşmaları. Başlangıç istikrarı %50 (taban %46, saray kliği −%5,
  iktidar partisi popülerliği +%9), dayanma iradesi %20.
- **Salgın:** İndeks küme başka bir kıtadadır. Doğu komşusunun 1,9 milyonluk kıyı eyaleti ("Komşu-D"; adı yazılmaz) 12. günde
  denizden gelen 200 kuluçkalıyla enfekte olur ve hiçbir önlem almaz. Köstence'ye 50. günden itibaren denizden günde 2 kuluçkalı gelir.
- **Hesap:** 02 §2.2 denklemleri (β 0,30 · κ 0,08 · μ 1/60 · σ 1/3 · γ 1/7 · p 0,10 · φ 0,15), gerçek eyalet nüfusu ve yoğunluğu,
  kara komşulukları, 02 §2.4 yolcu ve sürü yürüyüşü, bu belgenin ekonomi katmanı. Günlük adımla çözüldü.
  **Basitleştirmeler:** Tespit oranı sabit 0,25 ve 6 gün gecikme (03 §8 yerine); iklim çarpanı 1,0; serum yok; sürü birimleri yerine
  dağınık H. Pencere 60.–150. gündür (29 Şubat – 29 Mayıs 1936).

### 13.2 Günlük akış (kordonlu senaryo)
| Gün | Tarih | Ne oldu | Oyuncunun kararı | Gerçek enfekte (E+F+H) | Bildirilen | Ω_e | Fabrika çıktısı | Askerî üretim (fs/gün) | İnşaat (fg/gün) | Gıda f: ülke / Kişinev |
|---|---|---|---|---|---|---|---|---|---|---|
| 60 | 29 Şub | Başlangıç. Gıda: üretim 23,5, ihtiyaç 19,6, ihracat 3,9 + petrol 16,2 → 2 sivil fabrika kazanç. Stok 30 gün | — | 2.249 | 165 | 1,000 | ×1,00 | 42,3 | 5,25 | 1,00 / 1,00 |
| 66 | 6 Mar | Bülten ve Köstence'de şüpheli vakalar | **Zorunlu Karantina** (150 nüfuz); **Köstence limanına 14 gün karantina** | 4.561 | 363 | 0,999 | ×0,82 (yasa −%10, istikrar %42) | 35,2 | 4,97 | 1,00 / 1,00 |
| 70 | 10 Mar | Kişinev'de ilk bildirimler | Komşu-D sınırı **denetimli** | 6.267 | 603 | 0,998 | ×0,82 | 35,5 | 4,97 | 1,00 / 1,00 |
| 72 | 12 Mar | — | Köstence'ye garnizon (κ +0,10) | 7.349 | 775 | 0,998 | ×0,82 | 35,7 | 4,97 | 1,00 / 1,00 |
| 93 | 2 Nis | **Sınırda Mülteciler** (havuz 5.311) | **Karantina kamplarından geçirin** (Kişinev) | 43.756 | 4.492 | 0,987 | ×0,82 | 37,0 | 4,97 | 1,00 / 0,99 |
| 95 | 4 Nis | Komşu-D'nin %4'ü Boş; sürüler sınıra yürüyor | **Kordon ordusu** (3 tümen, g = 0,7) + Kişinev ve Bălţi'ye garnizon | 50.858 | 5.356 | 0,985 | ×0,82 | 37,1 | 4,97 | 1,00 / 0,95 |
| 104 | 13 Nis | İşgücü kademesi **−%5** (Kişinev ω 0,83); kampta 38.700 kişi | Sınır **kapalı** | 86.815 | 10.614 | 0,969 | ×0,77 | 35,2 | 4,62 | 0,99 / 0,94 |
| 118 | 27 Nis | Kişinev ω 0,67: şebeke eşiği | **Sanayiyi taşı:** Kişinev askerî fabrikası → Braşov (576 fg, ~110 gün) | 209.265 | 25.589 | 0,959 | ×0,77 | 26,6 | 4,61 | 0,99 / 0,93 |
| 123 | 2 May | Kişinev'e gıda sevkiyatı aksıyor (en düşük f) | — | 279.540 | 35.141 | 0,947 | ×0,77 | 26,7 | 4,61 | 0,99 / 0,91 |
| 125 | 4 May | — | **Öncelikli Sevkiyat** Kişinev (25 nüfuz, 30 gün) | 311.136 | 39.723 | 0,942 | ×0,77 | 26,8 | 4,61 | 0,99 / 0,95 |
| 137 | 16 May | Kademe **−%10**; Komşu-D %86 Boş | — | 535.153 | 75.457 | 0,899 | ×0,72 | 25,2 | 4,26 | 0,99 / 0,92 |
| 150 | 29 May | Kademe **−%20**; Kişinev ω 0,31 (düşmedi: tümen var) | — | 840.541 | 127.570 | 0,824 | ×0,62 | 21,8 | 3,56 | 0,99 / 1,00 |

(fs = fabrika-saat, fg = fabrika-gün; inşaat altyapı çarpanı hariç. Fabrika çıktısı = 1 − 0,10 yasa + işgücü kademesi + istikrar etkisi.)

### 13.3 Sonuç ve karşı-olgu
| 150. gün | Kordonlu (yukarıda) | Kordonsuz (garnizon ve kordon yok) |
|---|---|---|
| Gerçek enfekte / nüfus | 840.541 (%4,3) | 2.009.616 (%10,3) |
| Boş (H) / salgından ölen (D) | 212.785 / 126.215 | 711.538 / 265.780 |
| Yaşayan nüfus (1936'ya göre) | %93,8 | %86,6 |
| Düşmüş eyalet | 0 | 1 (Kişinev) |
| İşgücü kademesi / fabrika çıktısı | −%20 / ×0,62 | −%30 / ×0,52 |
| Askerî üretim (60. güne göre) | 21,8 fs (−%48) | 18,3 fs (−%57) |
| İnşaat (60. güne göre) | 3,56 fg (−%32) | 2,86 fg (−%46) |
| Askere alınabilir nüfus | 231.466 → 225.862 | → 217.320 |
| Mülteci: kabul / kampta izole edilen | 35.474 / 3.249 | 34.268 / 3.060 |
| Ulusal gıda f / stok | 0,99 / 33 gün | 0,99 / 35 gün |

**Senaryonun öğrettikleri:**
1. **Ekonomiyi önce korku ve bakım yükü vurur.** 100. günde Kişinev'in ω'su 0,87'ydi. Kaybın %60'ı korku devamsızlığıydı
   (bildirilen yaygınlık %0,33 → a = 0,08). Hasta ve bakıcılar 2 puan, kamp 1,3 puan götürüyordu. Gerçek Boş payı yalnız %0,56'ydı.
2. **Gıda yerel bir sorundur.** Romanya %20 artık veren bir tarım ülkesidir ve ulusal f hiç 0,99'un altına inmedi. Buna rağmen Kişinev'in
   sofrası 123. günde 0,91'e düştü, çünkü demiryolu işçisi de hasta ya da korkuyordu. Öncelikli sevkiyat kalıcı bir çözüm değil, zaman
   kazandıran bir araçtır: ω 0,48'deyken η yalnız 0,26'dan 0,51'e çıkabildi.
3. **Sanayi taşımanın bedeli peşin, faydası geç gelir.** Askerî üretim hemen %25 düştü; fabrika ~230. günde Braşov'da yeniden çalışacak.
   Kordonsuz senaryoda Kişinev düştüğü için fabrika zaten kaybedilecekti.
4. **Kamp ucuzdur.** 38.700 kişi kamptan geçti. Tüketim malı etkisi en yüksek hâlinde binde bir oldu, gıda ihtiyacına etkisi 0,04 birim.
   Kampta yakalanan 3.249 kuluçkalı ise Kişinev'e taşınmadı.
5. **Kordonun ekonomik getirisi büyüktür.** Kordon kurulmasaydı 90 günde fabrika çıktısı 10 puan, inşaat 14 puan daha düşük olurdu.

### 13.4 Yan hesap: aynı ülke gıda ithalatçısı olsaydı (Y = 0,75)
Ulusal gıda dengesi ele alındı. 100. günden sonra dünya piyasası açığın yalnız %40'ını (A) ya da hiçbirini (B) karşılıyor. Liman
karantinası ve ortakların denetimli tutumu ithalatı ×0,61'e indiriyor. Stok 10 günün altına inince oyuncu yasayı değiştiriyor.

| Politika | Stok bitişi (A / B) | Ülke f (A / B) | En yoksulun f'si, 330. gün (B) | K, 330. gün (B) | Açlık ölümü, 330. güne kadar (A / B) | İstikrar bedeli (B) |
|---|---|---|---|---|---|---|
| Serbest Piyasa | 238 / 204 | 0,81 / 0,75 | 0,375 | 0 | 7.075 / **96.533** | −%8 |
| Fiyat Tavanı (186. / 165. gün) | 238 / 204 | 0,81 / 0,75 | 0,444 | 0,28 | 0 / 21.609 | −%9 |
| Karne | 251 / 214 | 0,84 / 0,79 | 0,685 | 0,33 | 0 / 0 | −%14 |
| Karne + Vurguncularla Mücadele | 251 / 214 | 0,84 / 0,79 | 0,735 | 0,17 | 0 / 0 | −%13 |
| Merkezî İaşe | 273 / 230 | 0,87 / 0,83 | 0,786 | 0,33 | 0 / 0 | −%17 |

Hesap bir tasarım sonucunu doğrular: **tayın ölümü önler, bedeli istikrar ve karaborsadır.** Serbest piyasa en az istikrar kaybettiren ama
en çok öldüren seçenektir. Oyunun tek doğru bir cevabı yoktur (01 §6.3).

## 14. Veri: JSON şemaları

**Dosya yerleşimi.** Mod altyapısının denetimi (`tools/new_mode.py --check`), mod klasöründe `data/` altında karşılığı olmayan
dosyayı reddeder. Bu yüzden ekonomi parametreleri **var olan bir dosyanın patch'ine** yeni bir anahtar olarak konur. `Economy.load_data`
bu anahtarı görmezden gelir, `rules.gd` okur. (02'deki `rules.json` ve 03'teki `epidemic.json` için de aynı sorun geçerlidir; açık soru 7.)

`data/modes/zombie/common/buildings.patch.json`
```json
{
  "resources": ["oil", "steel", "aluminium", "tungsten", "chromium", "rubber", "food"],
  "zm_economy": {
    "_comment": "Gerekçeler: docs/modlar/zombi/07_ekonomi_ve_nufus.md",
    "workforce": {"care_per_febrile": 0.5, "fear_max": 0.25, "fear_saturation": 0.01, "labour_cap": 1.05,
                  "tier_step": 0.05, "tier_max": 0.60, "refugee_start_productivity": 0.25},
    "service": {"upper_slope": 0.45, "knee": 0.6667, "zero_at": 0.40, "grid_weight": 0.30},
    "food": {
      "kcal_per_person": 2100, "people_per_unit": 1000000,
      "self_sufficiency": {"_default": 1.05, "GBR": 0.30, "DEU": 0.85, "ROU": 1.20},
      "category_weight": {"wasteland": 0.3, "pastoral": 1.2, "rural": 1.5, "town": 1.3, "large_town": 1.0,
                          "city": 0.6, "large_city": 0.35, "metropolis": 0.2, "megalopolis": 0.1},
      "labour_smoothing_days": 60, "stock_start_days": 30, "stock_max_days": 120,
      "cordon_delivery": 0.8, "priority_bonus": 0.25,
      "mortality": {"threshold": 0.60, "base": 0.000135, "k": 15.0, "pivot": 0.40, "max": 0.002, "poor_share": 0.2},
      "hunger_tiers": [0.95, 0.85, 0.70, 0.55]
    },
    "black_market": {"decay": 0.01, "crackdown_decay": 0.02, "gap_per_k": 1.5, "consumer_cut_weight": 0.3,
                     "tiers": [0.10, 0.25, 0.50]},
    "trade": {"round_trip_days": 30, "posture": {"open": 1.0, "controlled": 0.9, "closed": 0.7}},
    "refugees": {"camp_days": 14, "camp_consumer_goods_per_share": 0.5, "integration_days": 180,
                 "integration_days_programme": 90, "camp_mortality_unfed": 0.00033, "strain_tiers": [0.005, 0.02, 0.05, 0.10]},
    "industry": {"relocate_cost_share": 0.40, "relocate_loss": 0.15, "recapture_loss": 0.25, "infra_decay_days": 120},
    "ammo": {"infantry_share": 0.003, "artillery_share": 0.008},
    "ai": {"accept_food_ratio": 1.0, "camp_food_ratio": 0.85, "cards_below": 0.95, "central_below": 0.80, "crackdown_k": 0.25}
  }
}
```
`data/modes/zombie/common/laws.patch.json` (kesit)
```json
{
  "groups": {
    "zm_rationing": {
      "name": {"en": "Food Policy", "tr": "Gıda Politikası"},
      "laws": {
        "zm_free_market":   {"name": {"en": "Free Market", "tr": "Serbest Piyasa"},
                             "zm_ration_gap": 2.5, "zm_ration_saving": 0.0, "zm_black_market_rate": 0.0},
        "zm_price_ceilings": {"name": {"en": "Price Ceilings", "tr": "Fiyat Tavanı"},
                             "zm_ration_gap": 1.8, "zm_ration_saving": 0.0, "zm_black_market_rate": 0.02,
                             "stability": 0.02, "consumer_goods_mod": 0.01},
        "zm_ration_cards":  {"name": {"en": "Ration Cards", "tr": "Karne"},
                             "zm_ration_gap": 1.0, "zm_ration_saving": 0.05, "zm_black_market_rate": 0.03,
                             "stability": -0.03, "consumer_goods_mod": 0.02, "requires": {"war_support": 0.10}},
        "zm_central_provisioning": {"name": {"en": "Central Provisioning", "tr": "Merkezî İaşe"},
                             "zm_ration_gap": 0.8, "zm_ration_saving": 0.10, "zm_black_market_rate": 0.04,
                             "stability": -0.06, "consumer_goods_mod": 0.04, "factory_output": -0.02,
                             "requires": {"war_support": 0.30}}
      }
    }
  },
  "start": {"_default": {"zm_rationing": "zm_free_market"}}
}
```
Not: `start._default` patch'le birleşir; ülkeye özel `start` kayıtları grup içermediği için `sanitize_laws` ve `reset` onları
`_default`'a düşürür. Mevcut motor bir grubun her ülkenin `start` kaydında olmasını beklerse bu satır `test_mode_zombie` ile denetlenir.
`zm_*` yasa anahtarları `law_sum` ile `c.mod()` toplamına da girer. Ama `rules.gd` onları doğrudan `law_def` ile okur.
Arayüz ipucu için `MOD_zm_ration_gap` vb. çeviri anahtarları gerekir.

`data/modes/zombie/common/spirits.patch.json` (kesit: kademeler ve kararlar)
```json
{
  "spirits": {
    "zm_workforce_05": {"name": {"en": "Short-handed", "tr": "Eksik Kadro"}, "mods": {"factory_output": -0.05, "construction_speed": -0.05}},
    "zm_hunger_2":     {"name": {"en": "Shortage", "tr": "Kıtlık"}, "mods": {"stability": -0.08, "war_support": -0.05, "factory_output": -0.05}},
    "zm_black_market_2": {"name": {"en": "Black Market", "tr": "Karaborsa"}, "mods": {"stability": -0.04, "political_power_gain": -0.10, "consumer_goods_mod": 0.01}},
    "zm_refugee_strain_2": {"name": {"en": "Strained Welcome", "tr": "Zorlanan Konukseverlik"}, "mods": {"stability": -0.03}}
  },
  "decisions": {
    "zm_crackdown":        {"name": {"en": "Crack Down on Profiteers", "tr": "Vurguncularla Mücadele"}, "cost": 50, "days": 90,
                            "mods": {"stability": -0.02, "zm_crackdown": 1}},
    "zm_labour_direction": {"name": {"en": "Labour Direction", "tr": "İşgücü Yönlendirmesi"}, "cost": 75, "days": 365,
                            "mods": {"stability": -0.03, "zm_labour_bonus": 0.08}},
    "zm_food_export_ban":  {"name": {"en": "Grain Export Ban", "tr": "Tahıl İhracat Yasağı"}, "cost": 50, "days": 180,
                            "mods": {"zm_export_ban": 1}}
  }
}
```
Eyalete ya da ülkeye hedeflenen kararlar (`zm_priority_consignment`, `zm_relocate_industry`, `zm_food_aid`,
`zm_resettlement_programme`) motorun ulusal karar yapısına uymaz. Bu kararlar Salgın panelindeki satır düğmeleriyle `rules.gd`
işlevlerini çağırır.

**Yeni etki ve şart anahtarları** (`rules.gd`; CLAUDE.md kural 2: `apply_effect` ve `describe_effect` birlikte)
| Etki | Anlamı | describe (EN / TR) |
|---|---|---|
| `zm_food_stock` | Stok ± gün | "Grain reserve %+d days" / "Tahıl stoku %+d gün" |
| `zm_black_market` | K ± | "Black market %+d%%" / "Karaborsa %%%+d" |
| `zm_workforce_bonus` | `{"value": 0.05, "days": 90}` | "Workforce %+d%% (%d days)" / "İşgücü %%%+d (%d gün)" |
| `refugee_policy` | 03'teki anahtar (accept / camp / refuse) | 03 |

| Şart | Anlamı |
|---|---|
| `zm_food_ratio_below` | Ülke f < değer |
| `zm_black_market_at_least` | K ≥ değer |
| `zm_workforce_below` | Ω_e < değer |
| `zm_camp_population_at_least` | Kamptaki kişi ≥ değer |

## 15. Arayüz

Yalnız `game/ui/panel_layout.gd` yardımcıları kullanılır (CLAUDE.md kural 5). Yeni stil yoktur.
- **Salgın paneli (E), "Ekonomi ve Nüfus" sekmesi** (sekme sırası panel tasarımında kesinleşir):
  - `info_cells`: Yaşayan nüfus · İşgücü Ω_e · Gıda f · Stok (gün) · Karaborsa K · Kamptaki kişi.
  - `section` "Eyaletler" + `table`: eyalet, yaşayan, ω, gıda f, η, durum (Çalışıyor/Aksıyor/Düşmüş/Yolda). Her satırda
    `row_action` ile iki düğme: "Öncelikli sevkiyat", "Sanayiyi taşı". Düğmeye basınca eylem yapılır; hiçbir satır kendiliğinden işlem yapmaz.
  - `progress`: stok günü (0–120). `empty`: "Henüz ekonomik etki yok."
- **Mevcut paneller:** Ticaret paneli gıdayı kendiliğinden listeler (`resource_names` döngüsü). Satır ipucuna "liman karantinası:
  ×0,68" eklenir (M3). Üst çubuktaki fabrika hücresi ipucuna "İşgücü: %82" satırı eklenir. Hükümet panelinde kademeler ulusal durum olarak görünür.
- **Uyarı şeridi** (`alert_bar.gd`, 02 §1.2'ye ek):

| Uyarı (EN / TR) | Tetik |
|---|---|
| Grain reserve low / Tahıl stoku azaldı | Stok < 10 gün |
| Hunger in {state} / {eyalet}'te açlık | Bir eyalette f < 0,85 |
| Production lines cut / Üretim hatları kırpıldı | M1b çalıştı |
| Black market spreading / Karaborsa yayılıyor | K ≥ 0,25 |
| Camps overcrowded / Kamplar dolu | Kamp > nüfusun %1'i |

## 16. Görsel ve ses varlıkları (liste ve üretim komutları)

Dosya üretilmez (CLAUDE.md kural 6). İkon adları mevcut kalıba uyar (`resource_`, `law_`, `spirit_`, `decision_`, `event_`); yollar
`assets/ui/icons_new/<ad>.png`. Stil satırları `tools/make_icon_prompts.py` içindeki `STYLE_ICON`, `STYLE_SMALL` ve `STYLE_EVENT`
ile aynıdır. Mod tonu için eklenen ifade: *"no gore, no children, figures at a distance"* (04 §10.3).

| Dosya | Konu (üretim komutunun başı, EN) | Stil |
|---|---|---|
| `resource_food` | "a burlap grain sack with a scoop of wheat and a loaf of dark bread, symbol of food supply" | STYLE_SMALL |
| `law_zm_free_market` | "an open market stall with baskets of produce and a hand-written price board without numbers" | STYLE_ICON |
| `law_zm_price_ceilings` | "a brass shop scale with an official lead seal hanging from it" | STYLE_ICON |
| `law_zm_ration_cards` | "a 1930s paper ration book with torn-out coupons, no readable text" | STYLE_ICON |
| `law_zm_central_provisioning` | "a large steaming field kitchen cauldron with a ladle and tin bowls" | STYLE_ICON |
| `spirit_zm_workforce` (bütün kademeler için takma ad) | "an empty factory workbench with a hanging work coat and a stopped clock" | STYLE_ICON |
| `spirit_zm_hunger` (takma ad) | "an almost empty bread basket with a few crumbs on a bare wooden table" | STYLE_ICON |
| `spirit_zm_black_market` (takma ad) | "a half-open back door of a shop at night with sacks passed through" | STYLE_ICON |
| `spirit_zm_refugee_strain` (takma ad) | "a railway platform crowded with suitcases and bundles, seen from above, no faces" | STYLE_ICON |
| `decision_zm_relocate_industry` | "a factory lathe being lifted onto a flat railway wagon by a crane" | STYLE_ICON |
| `decision_zm_priority_consignment` | "a freight train of grain wagons with a priority flag on the locomotive" | STYLE_ICON |
| `decision_zm_crackdown` | "an inspector's clipboard and a padlock on a warehouse door" | STYLE_ICON |
| `event_zm_refugees_at_border` | "historical scene: a striped border barrier on a muddy country road at dusk, a long line of families with carts waiting behind it, a few soldiers and a district officer with papers, seen from a distance" | STYLE_EVENT |
| `event_zm_hoarders` | "historical scene: officials opening a dim warehouse full of grain sacks while a ration queue waits in the street outside" | STYLE_EVENT |
| `event_zm_bread_queue` | "historical scene: a long quiet queue of coats and hats outside a bakery in a grey 1930s city street, early morning" | STYLE_EVENT |

`PAINTED_ALIASES` (`ui_theme.gd`) ile kademe ailelerinin tek ikonu paylaşması sağlanır: 12 + 4 + 3 + 4 kademe için 4 dosya yeter.
Toplam **15 dosya.**

**Ses** (`tools/make_audio.py` yaklaşımı: numpy sentezi, telifli örnek yok; `assets/audio/zm_*.wav`, mono 44,1 kHz):
| Dosya | Süre | Prosedürel tarif | Üretim komutu (EN) |
|---|---|---|---|
| `zm_ration_stamp` | 0,4 sn | Tahta masaya lastik damga: 90 Hz darbe (`thump`, 40 ms sönüm) + 2–5 kHz kâğıt hışırtısı taneleri | "a rubber stamp hitting a ration card on a wooden counter" |
| `zm_queue_amb` | 10 sn döngü | Uzak kalabalık mırıltısı (200–800 Hz pembe gürültü, 0,2 Hz genlik), ara ara ayak sürtmesi, uzak tramvay çanı (1,1 kHz, 1,5 sn sönüm) | "a quiet queue murmuring in a city street, shuffling feet, a distant tram bell, no words" |
| `zm_freight_train` | 6 sn | 55–70 Hz buhar puflaması (saniyede 3–4 darbe) + ray tıkırtısı (1,2 kHz kısa tık, 1,1 sn aralık) | "a slow steam freight train passing in the distance" |
| `zm_food_alert` | 1,2 sn | Mevcut `alert` motifinin alçak üç notalı çeşitlemesi | "short low three-note warning chime, restrained" |

## 17. Test ve denge hedefleri

**Birim testleri** (`tests/test_zm_economy.gd`):
1. Düşmüş eyalet: `Economy.count` o eyaletin fabrikalarını saymaz; boşta fabrika eksiye düşerse son hat kırpılır (M1, M1b).
2. WWII modunda kancalar hiçbir şeyi değiştirmez: `count`, `resource_available`, `_run_trade` sonuçları kancasız sürümle aynıdır.
3. §2.2 formülü: F = 10.000, bildirilen %0,5 → a = 0,125, ω beklenen değer ±1e-9.
4. Gıda: taban toplamı Y · N/10⁶'ya eşittir (±1e-6); teslim edilmeyen gıda stoka döner (korunum).
5. Açlık eğrisi: m(0,6) = 0, m(0,4) = 1,35·10⁻⁴, tavan 0,002.
6. §13.4 tablosu: aynı girdilerle ±1 gün / ±%1.
7. Kayıt: ω̄, U, kamp kuyruğu, stok, K kayıttan aynen döner (`test_save_load` kalıbı).
8. Oyuncu adına iş yok: 150 gün hiçbir şey yapmayan oyuncuda tayın yasası, taşıma, sevkiyat, kamp politikası değişmemiş olmalıdır
   (`country_check.gd` benzeri).

**Denge hedefleri** (oyuncusuz dünya, 6 koşu; her kontrol ≥ 5/6):
| # | Kontrol | Hedef |
|---|---|---|
| 1 | 540. günde en az bir ülke Açlık (3. kademe) yaşamış | evet |
| 2 | Bitişte dünya gıda arzı / ihtiyacı | 0,85–1,05 |
| 3 | Açlık ölümü / salgın ölümü (dünya) | ≤ %10 (açlık yan etkidir, ana ölüm nedeni değil) |
| 4 | Karne kullanan ülke sayısı, 730. gün | 10–50 |
| 5 | Web'de `zm_economy` adımı | ≤ 3 ms/gün |

## 18. Açık sorular

1. **Kendine yeterlilik tablosu:** GBR, DEU ve ROU dışındaki değerler tahmindir. 1930'ların tarım istatistik yıllıklarından
   (Roma'daki Uluslararası Tarım Enstitüsü'nün yıllıkları) doğrulanmalı mı, yoksa `_default` ile mi yetinilmeli?
2. **Korku devamsızlığı tavanı (%25)** Kişinev'de ω'yu hastalıktan önce düşürüyor. Bu istenen bir sonuç ama oyun testiyle ölçülmeli.
   Bilgi saklayan yasa (siyaset tasarımı) bu tavanı düşürmeli mi?
3. **Hasat mevsimi:** Gıda üretimi yıl boyu düz. Hasat öncesi stok kıtlığı (Mayıs–Temmuz) eklenirse "kış müttefiktir" ile birlikte
   ikinci bir mevsim ritmi oluşur. Ek bir gerekçe ve test ister.
4. **Başkent stoku:** Başkent düşerse ulusal stokun ya da ekipman stokunun bir kısmı kaybedilsin mi? (Öneri: %20, olayla.)
5. **Değişken ticaret kuru:** Kıtlıkta 8:1 kurunun gıda için 6:1'e inmesi (satıcı lehine) karaborsaya gerek kalmadan fiyat sinyali
   verir, ama `RESOURCES_PER_TRADE_FACTORY` sabitini kaynak başına yapmak motor değişikliği ister.
6. **Haberleşme çöküşü** tespit gecikmesine eklensin mi? 03 §8 ile birlikte karara bağlanmalı.
7. **Mod veri dosyası yerleşimi:** `--check` yeni üst düzey dosyayı reddediyor. 02 (`rules.json`) ve 03 (`epidemic.json`) için
   de geçerli. Seçenekler: (a) bu belgedeki gibi var olan dosyanın patch'ine anahtar koymak, (b) altyapıya `mode_data/` istisnası
   eklemek. Altyapı PR'ında karar verilmeli.
8. **Yolcu akışına hizmet çarpanı** (§5.2) 03'ün kalibrasyonunu (Türkiye'ye varış 24–87. gün) değiştirir mi? 03 prototipiyle yeniden ölçülmeli.
9. **Mühimmat çekişi** yalnız `UND` ile muharebede. Devletler arası savaş (01 açık soru 3) açılırsa orada da uygulansın mı? Bu,
   WWII ile tutarsızlık yaratır.

## 19. Kaynaklar

Salgın ekonomisi
- Barro, R. J., Ursúa, J. F., Weng, J. (2020). The Coronavirus and the Great Influenza Pandemic. NBER w26866 (1918–20'de tipik ülkede GSYH −%6, tüketim −%8). — https://www.nber.org/system/files/working_papers/w26866/w26866.pdf
- Correia, S., Luck, S., Verner, E. (2020). Pandemics Depress the Economy, Public Health Interventions Do Not: Evidence from the 1918 Flu (imalat −%18). — https://dx.doi.org/10.2139/ssrn.3561560
- Jonas, O. B. (2013). Pandemic Risk. Dünya Bankası, Dünya Kalkınma Raporu 2014 arka plan çalışması (kaçınma davranışı). — https://www.worldbank.org/content/dam/Worldbank/document/HDN/Health/WDR14_bp_Pandemic_Risk_Jonas.pdf
- Center for Global Development. Aversion Behavior Exacerbates the Economic Impact of Ebola. — https://www.cgdev.org/blog/aversion-behavior-exacerbates-economic-impact-ebola
- 1918'de telefon santralleri: New-York Historical Society. — https://womenatthecenter.nyhistory.org/how-telephone-operators-helped-people-connect-during-the-1918-flu-epidemic/
- 1918'de işgücü ve bakım yükü: Penn Nursing, Bates Center. — https://www.nursing.upenn.edu/history/publications/calm-cool-courageous/
- Evans, R. J., Hamburg 1892 kolera salgını üzerine söyleşi. — https://blogs.darden.virginia.edu/globalwater/2020/10/27/qa-with-richard-j-evans-on-the-relevance-of-a-past-cholera-epidemic/
- Marsilya 1720 vebası ve ticaret. — https://brewminate.com/a-commerce-of-corpses-the-great-plague-of-marseille-in-the-18th-century/
- Marsilya 1720: karantinanın gevşetilmesi. *History Hit.* — https://www.historyhit.com/1720-start-europes-last-deadly-plague/
- Hamburg liman işçileri ve 1892 sonrası sendika üyeliği. — https://en.wikipedia.org/wiki/1896%E2%80%9397_Hamburg_dockworkers%27_strike
- Hamburg 1892 kolera salgını. German History in Documents and Images. — https://ghdi.ghi-dc.org/sub_image.cfm?image_id=1608
- Munro, J. / EH.net. The Economic Impact of the Black Death. — https://eh.net/encyclopedia/the-economic-impact-of-the-black-death/

Kıtlık, tayın ve karaborsa
- Sen, A. (1981). Poverty and Famines (özet). — https://www.progress.org/wiki/sen-poverty-and-famines/
- Colonial Biopolitics and the Great Bengal Famine of 1943. *GeoJournal* / PMC. — https://pmc.ncbi.nlm.nih.gov/articles/PMC9735018/
- Lumey, L. H. ve ark. (2007). Cohort Profile: The Dutch Hunger Winter Families Study. *Int. J. Epidemiol.* 36(6). — https://academic.oup.com/ije/article/36/6/1196/814573
- Science History Institute. The Winter When People Ate Tulips. — https://www.sciencehistory.org/stories/disappearing-pod/the-winter-when-people-ate-tulips/
- Yunanistan işgal kıtlığı 1941–44. Memories of the Occupation in Greece (Freie Universität Berlin). — https://www.occupation-memories.org/en/deutsche-okkupation/ergebnisse-des-terrors/index.html
- Leningrad kuşatması, azıklar. Merkezî Deniz Müzesi. — https://eng.navalmuseum.ru/main_exposition/blockade
- Leningrad kuşatması, altyapı. EHNE (Sorbonne). — https://ehne.fr/en/encyclopedia/themes/wars-and-memories/war-fronts/siege-leningrad-1941-1944
- Savaş yıllarında yerel yakıtla santral işletimi. OSTI/ETDEWEB. — https://www.osti.gov/etdeweb/biblio/5354918
- Imperial War Museums. The impact of rationing on the Home Front. — https://www.iwm.org.uk/history/second-world-war/the-impact-of-rationing-on-the-home-front-during-the-second-world-war
- Atkins, P. Communal Feeding in War Time: British Restaurants 1940–1947. Durham Üniversitesi. — https://pjatkins.webspace.durham.ac.uk/wp-content/uploads/sites/201/2022/07/Communal-Feeding-in-War-Time-British-Restaurants-1940-1947.pdf
- Evans, R. J. Autarky: Fantasy or Reality? (Almanya'nın gıda ithalatı). — https://www.richardjevans.com/lectures/autarky-fantasy-reality/
- Mouré, K. (2010). Food Rationing and the Black Market in France (1940–1944). *French History* 24(2). — https://academic.oup.com/fh/article-abstract/24/2/262/543437
- Rationing and the Black Market in Paris During the War. *Aspects of History.* — https://aspectsofhistory.com/rationing-and-the-black-market-in-paris-during-the-war/
- Deutsche Bundesbank. The economic and currency reform of 1948. — https://www.bundesbank.de/en/press/contributions/the-economic-and-currency-reform-of-1948-the-basis-for-stable-money-915302
- German History in Documents and Images. Currency Reform (20 Haziran 1948). — https://germanhistorydocs.org/en/occupation-and-the-emergence-of-two-states-1945-1961/currency-reform-june-20-1948
- Ruhr 1946–47 açlık kışı ve kömür üretimi. Postwar Germany. — https://postwargermany.com/2012/09/26/hunger-winter/
- WFP/UNHCR. Guidelines for Estimating Food and Nutritional Needs in Emergencies (2.100 kcal). — https://www.unhcr.org/us/sites/en-us/files/legacy-pdf/3b9cbef7a.pdf

Savaş ekonomisi, sanayi ve lojistik
- Seventeen Moments in Soviet History. Wartime Evacuation. — https://soviethistory.msu.edu/1943-2/wartime-evacuation/
- Eighty years ago: evacuation of Soviet war factories. — https://www.left-horizons.com/2021/10/08/eighty-years-ago-evacuation-of-soviet-war-factories/
- Ransome, A. (1921). The Crisis in Russia, bölüm 1 (ulaşım ve yakıt kısır döngüsü). — https://www.marxists.org/history/archive/ransome/works/crisis/ch01.htm
- War, Civil War and the 'Restoration' of Russia's Industrial Infrastructure, 1914–25: The Fate of the Railway Locomotive Stock. *Revolutionary Russia* 25(1). — https://www.tandfonline.com/doi/abs/10.1080/09546545.2012.674371
- Ruppenthal, R. G. Logistical Support of the Armies, Cilt II (tümen başına günlük ikmal). — https://www.ibiblio.org/hyperwar/USA/USA-E-Logistics2/USA-E-Logistics2-6.html
- France, July 1944 (1. Piyade Tümeni günlük ikmali). *Forbes.* — https://www.forbes.com/2008/06/05/logistics-wwii-usarmy-tech-logistics08-cx_jc_0605normandy/
- Striking Women. World War II: 1939–1945 (Britanya'da kadın istihdamı). — https://www.striking-women.org/module/women-and-work/world-war-ii-1939-1945
- Economic History Malaysia. About rubber (Malaya'nın dünya kauçuk payı). — https://www.ehm.my/publications/articles/about-rubber
- Library of Congress. World production of rubber, 1930–1940. — https://www.loc.gov/item/2017700669/

Mülteciler
- Greek Refugee Settlement Commission. BM Cenevre Arşivi. — https://archives.ungeneva.org/greek-refugee-settlement-commission
- The Refugee Settlement Commission. 100 Sources. — https://100sources.gr/en/entry/the-refugee-settlement-commission/
- Colonizing New Lands: Rural Settlement of Refugees in Northern Greece (1922–40). *Cairn* (1924 ve 1927 borçları). — https://shs.cairn.info/revue-clara-2023-1-page-140?lang=en
- Anistoriton: rural settlement statistics (1928). — http://www.anistor.gr/english/enback/s012.htm
- The Asia Minor Catastrophe. Europeana. — https://www.europeana.eu/en/stories/the-asia-minor-catastrophe
- The Retirada or post-war Spanish republican exile. Musée de l'histoire de l'immigration. — https://www.histoire-immigration.fr/en/migration-characteristics-by-country-of-origin/the-retirada-or-post-war-spanish-republican-exile
- Argelès kampı. — https://en.wikipedia.org/wiki/Argelers_concentration_camp

Romanya
- The Romanian Agriculture – Between Myth and Reality (1930 sayımı). — https://newoeconomica.uab.ro/up/AUASO/articles/the_romanian_agriculture_-_between_myth_and_reality-article-663b14a011d41.pdf
- Oil Industry in Romania in the Period 1918–1948 (1936 üretimi). — https://www.icfm.ro/RePEc/vls/vls_pdf_jfme/vol6i1p160-168.pdf

Kurumlar
- 1926 Uluslararası Sıhhiye Sözleşmesi. BM Cenevre Arşivi. — https://archives.ungeneva.org/international-sanitary-convention-1926

Depo içi
- `game/autoload/economy.gd` (sayım, ticaret, üretim), `game/autoload/politics.gd` (istikrar etkileri, etki sözlüğü),
  `game/autoload/military.gd` (`_fuel`, ikmal), `game/autoload/world.gd` (`recompute_manpower_pop`), `game/core/mode_rules.gd`,
  `data/common/buildings.json`, `laws.json`, `equipment.json`, `units.json`, `data/map/states.json`, `data/history/states_1936.json`,
  `tools/new_mode.py`, `docs/modlar/README.md`.
- Senaryo hesap betikleri bu belgenin yazımında kullanıldı. Salgın modeli uygulandığında `tests/test_zm_economy.gd`'ye dönüştürülmeli
  (§17, test 6).
