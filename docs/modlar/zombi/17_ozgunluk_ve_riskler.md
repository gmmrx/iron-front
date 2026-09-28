# Zombi modu — 17 Özgünlük, hassasiyet ve riskler

> **Özet.** Bu belge *Gri Kordon* modunun hukuki, etik ve teknik risklerini tek yerde toplar ve her birine azaltma yolu verir. Kurallar
> docs/OZGUNLUK.md'ye bağlıdır; bu belge onları zombi türüne uygular.
> - **Serbest olan:** Türün fikirleri (salgınla yayılan saldırgan hastalar, ısırıkla bulaş, karantina, kordon, sürü, bilim yarışı,
>   çöken devletler). Oyun fikirleri, kuralları ve oynanış yöntemleri telifle korunmaz.
> - **Korunan (kaçınılan):** Başka eserlerin kendine özgü adları, karakterleri, metinleri, görsel tasarımları, sayı tabloları, ekran
>   düzenleri. Bu moddaki bütün adlar ya tarihî gerçek adlardır ya da bizimdir; bütün sayıların gerekçesi yazılıdır (03–10).
> - **Ad riski:** Mod adı (*Gri Kordon*) genel web aramasından geçti, marka araması henüz yapılmadı. İngilizce tür karşılığı **"Hollow"**
>   yaygın bir sözcük olduğu için eğlence ürünlerinde benzer anlamda kullanılmış olabilir; yayından önce §3'teki yöntemle taranmalı,
>   gerekirse yedek ad kullanılmalı.
> - **Hassasiyet:** Hastalık kurgusal ve biyolojik; hiçbir halkla, dinle, yerle ya da gerçek kişiyle ilişkilendirilmez; gerçek liderler
>   hasta gösterilmez; sivile şiddet oynanamaz; aşı ve tedavi işe yarar (yanlış bilgi yaymaz). Haiti folklorunun kökeni saygıyla anılır,
>   dinî imge kullanılmaz.
> - **Yaş hedefi 16+** (01 §6.6): görüntü düzeyinde vahşet yok, ama kitlesel ölüm, korku teması ve ağır ahlaki seçimler var. "Sade içerik"
>   seçeneği ve açılışta içerik notu.
> - **Lisans:** Kod MIT; ses ve müzik prosedürel; görseller kullanıcı tarafından üretilir. Üretken yapay zekâyla yapılan görsellerin
>   kaydı tutulur, sanatçı/eser adı içeren komut yasaktır.
> - **Risk kaydı:** 24 risk (8 hukuki/etik, 8 teknik, 8 tasarım), olasılık, etki ve azaltma yoluyla (§9).

---

## 1. Serbest fikir ile korunan ifade

### 1.1 Hukuki çerçeve (genel ilke)

| Kaynak | Ne diyor | Bizim için anlamı |
|---|---|---|
| ABD Telif Ofisi, oyunlar bilgi notu | Telif, bir oyunun **fikrini, adını ya da oynanış yöntemlerini** korumaz; oyun yayımlandıktan sonra başkalarının benzer ilkelerle oyun yapmasını engellemez. Oyunun yeterli edebî ya da resimsel ifadesi korunabilir | Salgın stratejisi, kordon, sürü, bilim yarışı gibi **mekanikler** serbesttir; metin, görsel ve özgün adlar korunur |
| ABD Telif Yasası 17 U.S.C. §102(b) | Fikir, yöntem, sistem, işlem ilkesi korunmaz | Aynı |
| AB Bilgisayar Programları Yönergesi 2009/24/AT, Madde 1(2) | Bir programın herhangi bir öğesinin altındaki **fikir ve ilkeler** (arayüzünkiler dahil) korunmaz | İşlevsellik serbest; kod ve görsel ifade korunur |
| 5846 sayılı Fikir ve Sanat Eserleri Kanunu (Türkiye) | Eser, sahibinin hususiyetini taşıyan fikir ve sanat ürünüdür; öğretide fikir değil **ifade** korunur | Aynı ayrım Türkiye'de de geçerli |

Bu hukuki bir görüş değildir; yalnız tasarım kararlarımızın dayandığı genel ilkedir. docs/OZGUNLUK.md'nin "temiz oda" kuralı bundan
daha sıkıdır: başka bir oyunun dosyası, wikisi, ekran görüntüsü ya da rehberi hiç açılmaz.

### 1.2 Zombi türü: ortak öğeler ve bizim ifademiz

| Tür öğesi (serbest fikir) | Bu moddaki ifademiz | Kaynağı |
|---|---|---|
| Ölümcül, saldırgan bir hastalık | **Öfke ensefaliti (EF)**; hastalar ölü değil, yaşayan hastalardır; erken evre tedavi edilebilir (01 §5) | Kuduz ve ensefalit klinik bilgisi, salgın modelleri |
| Isırıkla bulaş | Isırık payı kuduzda bulaşın ısırık yerine bağlılığından türetildi (04 §3.4) | Epidemiyoloji makaleleri |
| Kalabalık hâlinde yürüyen hastalar | **Sürü** = 10.000 Boş; yoğunluk + birim melezi (01 §3c) | Kalabalık dinamiği araştırması (10 §3.1) |
| Farklı "türler" | 9 klinik **tablo** + 5 **suş**; adları özgün (Olağan Boş, Seğirtken, Durgun, Kösemen, Kaputlu, Kışlayan, Gecegezer, Dehlizci, Sazlıkçı) | Evrimsel epidemiyoloji (04 §7) |
| Karantina ve sınır kapatma | **Sınır tutumu, kordon, Kordon Hattı**; tarihî kordonlar (1770 Habsburg–Osmanlı veba kordonu, 1910–11 Mançurya) | Salgın tarihi (01 §8, 09 §9) |
| Tedavi yarışı | Anlamak → yavaşlatmak → tedavi → önlemek; serum ve aşı 1930'ların bilimiyle (05) | Aşı ve serum tarihi |
| Çöken devletler | Durum makinesi, geçici yönetim, askerî valilik, koruma altına alma (09 §5) | Devlet çöküşü tarihi |

**Kaçındıklarımız:** Tanınmış eserlerin yaratık adları, karakterleri, mekânları, hastalık adları, amblemleri; "zombi kıyametinde
hayatta kalma" klişe metinleri; bilinen bir eserin ekran düzeni ya da sayı tablosu. Belgelerde hiçbir film, dizi, kitap ya da oyun
**model olarak** anılmaz (CLAUDE.md kural 4, docs/OZGUNLUK.md kural 6).

### 1.3 "Zombi" sözcüğü

"Zombi" genel bir tür adıdır ve serbesttir; menüde türün adı olarak kullanılır ("Zombi İstilası / Zombie Outbreak"). Oyun içinde
hastalara "zombi" denmez; tıbbi-halk dili kullanılır ("Boşlar", "Ateşliler"). Gerekçe: 01 §6.2 (hastalar aşağılanmaz) ve ifadenin
özgünlüğü.

---

## 2. İçerik hassasiyeti

### 2.1 Gerçek hastalıklar ve pandemi deneyimi

| Risk | Kural | Nerede uygulanır |
|---|---|---|
| Gerçek bir hastalığı taklit etmek ya da hafife almak | Etken kurgusaldır; gerçek bir patojenin adı, belirti tablosu ya da tedavisi kullanılmaz. Oyun tıbbi tavsiye vermez | 01 §6.3, 05 |
| Yanlış bilgi yaymak (aşı karşıtlığı) | **Aşı ve tedavi işe yarar.** "Söylenti" ve "aşı korkusu" olayları tarihî örneklere dayanır, ama oyun gerçeği belirsiz bırakmaz: söylenti yanlıştır, çaresi şeffaflıktır | 01 §6.3, 05 §10.8, 09 §7 |
| Yakın dönem pandemi travması | Açılışta içerik notu (§5.2); kısa yol: "Sade içerik" seçeneği; karantina ve maske gibi önlemler alay konusu edilmez | 01 §6.6, §5 |
| Hastalık adıyla damgalama | Dünya Sağlık Örgütü'nün 2015 adlandırma ilkeleri: coğrafi yer, kişi, halk, hayvan, meslek adı ve **korku uyandıran** terimlerden kaçın. Hastalık adı belirtiye dayalıdır (ensefalit); suş adları betimleyicidir (Hırıltılı, Kızgın, Dirençli, Soluk, Süreğen); hiçbiri yer ya da halk adı taşımaz | 01 §9, 04 §6 |

**Yeni ad eklerken denetim** (DSÖ ilkelerinin oyuna uyarlanması): (1) yer adı yok, (2) kişi adı yok, (3) halk, din, meslek, hayvan adı
yok, (4) aşağılayıcı ya da korku körükleyen sıfat yok, (5) EN ve TR karşılıklarının ikisi de bu dört koşulu sağlıyor.

### 2.2 Başlangıç yeri ve damgalama

İndeks küme gerçek bir liman eyaletinde başlar (02 §7.1). Bu, bir yeri "salgının kaynağı" gibi gösterme riski taşır. Azaltma:
- Başlangıç yeri **rastgele** (tohumdan) ve her oyunda farklıdır; hiçbir ülke ya da halk varsayılan kaynak değildir.
- Bülten ve olay metinleri kaynağı "bir liman" diye anar; ilk vaka bir kişi, milliyet ya da topluluk olarak anlatılmaz ("sıfır hasta"
  karakteri yoktur).
- Enfeksiyon oranını etnik köken, din ya da ideoloji değiştirmez (01 §6.4).

### 2.3 Gerçek halklar, dinler, inançlar

| Konu | Kural |
|---|---|
| Haiti ve "zombi" folkloru | Sözcüğün kökeni saygıyla anılır; folklorda zonbi iradesi elinden alınmış bir **kurbandır** ve akademisyenler bu imgeyi köleliğin deneyimiyle ilişkilendirir. Vodou dini, din adamı, ayin ya da "lanet" imgesi **yoktur**; salgının kaynağı biyolojiktir; Haiti oyunda öteki ülkelerle aynı muameleyi görür (01 §6.4) |
| Dinî imge | Kilise çanı, ezan, ilahi, dinî simge yok (12 §1.1, 13 §1). **Düzeltme:** 01 §6.1'deki "uzak kilise çanı" ifadesi "uzak istasyon çanı" olarak değiştirildi |
| Günah keçisi | Azınlığa yönelik şiddet yalnız oyuncunun **önlemesi gereken** bir risk olayıdır; zulmü seçmek hiçbir avantaj vermez (01 §6.4) |
| Sömürgeler | Sömürge nüfusunun kaybı anavatanınkiyle aynı bedeli taşır; tampon bölge değildir (01 §6.4) |
| Grup hedefleyen mekanik | **Hiçbir mekanik bir grubu etnik köken, din ya da milliyete göre hedeflemez.** Zorunlu hizmet yasaları (09 §3.6) herkese aynı uygulanır; "çalışma kampı", "sürgün", "tasfiye" gibi o dönemin suç kavramları çözüm olarak sunulmaz (01 §6.5) |
| "Kamp" sözcüğü | Yalnız "mülteci kampı" ve "karantina kampı" anlamında, nötr dille; tel örgü, gözetleme kulesi gibi toplama kampı imgesiyle birlikte gösterilmez (12 §5) |

### 2.4 Gerçek kişiler ve 1930'ların rejimleri

- 1936'nın gerçek liderleri başlangıç verisinde kalır (temel oyunla aynı portreler). **Hiçbir gerçek kişi hasta, Boş ya da salgından
  ölmüş gösterilmez**; liderin kaybı soyut bir halef olayıdır (01 §6.5).
- Gerçek rejimlerin suçları salgın önlemi olarak yeniden çerçevelenmez ya da aklanmaz (01 §6.5). Yapay zekânın salgın tutumu ideolojiden
  değil kapasiteden türer (10 §4.3): hiçbir rejim "salgında daha etkili" diye ödüllendirilmez.
- Olay resimlerinde yüzler uzakta ya da dönüktür (12 §1.1): gerçek kişiye benzeyen kurgusal yüz üretilmez.
- Tarihî kişilere ait sözler uydurulmaz; olay metinlerindeki konuşmacılar kurgusal görevlilerdir ("bakanlık sözcüsü", "vali").

### 2.5 Şiddet

01 §6.2: sivile karşı şiddet oynanabilir bir eylem değildir; kan, iç organ, uzuv kaybı yok; çocuk figürü yok; hastalar aşağılanmaz.
Alev silahı gibi araçlar insan figürü üzerinde gösterilmez (12 §6). Sesler çığlık ve acı içermez (13 §1).

---

## 3. Ad seçimi ve çakışma denetimi

### 3.1 Hangi adlar denetlenir?

| Ad türü | Denetim düzeyi | Neden |
|---|---|---|
| Mod adı (*Grey Cordon / Gri Kordon*) | **Tam** (marka + web + mağaza + alan adı) | Ürün adı gibi görünür; karışıklık riski en yüksek |
| Hastalık ve tür adları (EF, Boşlar/Hollow, tablolar, suşlar) | **Orta** (web + oyun ve eğlence bağlamı) | Ayırt edici adlar; başka bir eserle karışırsa ifade benzerliği algısı doğar |
| Kurum ve olay adları (Uluslararası Karantina Konseyi, Salgın Bülteni) | **Hafif** (web) | Genel betimleyici adlar; tarihî kurumlarla karışmamalı |
| Genel kelimeler (sürü, kordon, karantina) | Yok | Türün ve dilin ortak kelimeleri |

### 3.2 Yöntem

1. **Genel web araması:** Adın kendisi ve "<ad> game", "<ad> oyun" ile. Sonuç ve tarih belgeye yazılır (01 §8 örneği).
2. **Marka veri tabanları** (docs/OZGUNLUK.md kural 8): TÜRKPATENT, EUIPO (eSearch plus / TMview), USPTO (Trademark Search), WIPO
   Global Brand Database. **Nice sınıfları:** 9 (indirilebilir oyun yazılımı), 28 (oyuncak ve oyunlar), 41 (eğlence hizmetleri, çevrimiçi
   oyun sağlama).
3. **Dijital oyun mağazaları ve bağımsız oyun platformları:** ad araması.
4. **Alan adları:** `.com`, `.org`, `.io` ve ülke uzantıları.
5. **Karar kaydı:** Aday, sonuç, tarih, karar ("seçildi / yedek / elendi") tablosu ilgili belgede; kaynak ekran görüntüsü depoya **konmaz**
   (temiz oda), yalnız sonuç yazılır.

### 3.3 Açık denetimler

| Ad | Durum | Öneri |
|---|---|---|
| *Grey Cordon / Gri Kordon* | Web araması temiz (01 §8); marka araması yapılmadı | Yayından önce 2–4. adımlar |
| **"Hollow" / "the Hollow"** (EN tür adı) | Denetlenmedi. Yaygın bir sözcük ve eğlence ürünlerinde ölümsüz ya da yozlaşmış insanlar için kullanılmış olma olasılığı yüksek; tek başına korunmaz, ama çağrışım riski taşır | 3.2'deki 1. ve 3. adımlar. Çağrışım güçlü çıkarsa yedek: **"the Emptied"** (TR "Boşlar" anlamını korur) ya da **"the Grey"** (hastalığın halk adıyla uyumlu). Kimlik (`UND`) ve dosya adları (`hol_*`) değişmez; yalnız EN metin |
| Tür adları (EN: Common Hollow, Courser, The Still, Bellwether, Greatcoats, Winterers, Night Hollow, Sump Hollow, Waders) | Denetlenmedi | 1. adım; özellikle tek kelimelik olanlar (Courser, Bellwether) genel sözcüktür ve risk düşüktür |
| Uluslararası Karantina Konseyi | — | Tarihî kurumlarla karışmaz (1926 Uluslararası Sıhhiye Sözleşmesi ayrı bir addır); sorun görülmedi |

---

## 4. Yaş derecelendirme

### 4.1 Ölçütler

Oyun ücretsiz bir tarayıcı oyunudur; mağaza derecelendirmesi zorunlu değildir. Yine de hedefi **ölçülebilir** tutmak için Avrupa'daki
derecelendirme sisteminin kamuya açık içerik tanımları kullanılır:

| Ölçüt | Tanım (özet) | Bu mod |
|---|---|---|
| Şiddet — 12 | Fantastik ortamda ya da insana benzeyen karakterlere gerçekçi olmayan şiddet | Harita düzeyinde soyut muharebe, figürler çöker ve söner (12 §3.1) → bu düzeyin içinde |
| Şiddet — 16 | Gerçek hayattakine benzeyen şiddet | Yok |
| Korku — 12 | Orta düzeyde korku sahneleri ya da rahatsız edici görüntüler | Olay resimleri ve ses tonu bu düzeyde |
| Korku — 16 | Yoğun ve süreğen korku sahneleri | Tema süreğen (4 yıllık salgın), görüntü değil |
| Tema | (Derecelendirmede tanımlı değil) | Kitlesel ölüm, devlet çöküşü, ağır ahlaki seçimler (01 §6.6) |

**Karar: hedef 16+** (01 §6.6). Görsel içerik 12 düzeyinde kalsa da tema ağırdır; muhafazakâr hedef seçildi. **Düzeltme:** 12 §1.1'deki
"12+ hedefi" ifadesi "16+ hedefi (01 §6.6)" olarak düzeltildi.

### 4.2 İçerik notu (açılışta, bir kez)

| EN | TR |
|---|---|
| This mode depicts a fictional epidemic, mass death and hard choices made by governments. It contains no graphic violence. Diseases, treatments and events in the game are fictional and are not medical advice. | Bu mod kurgusal bir salgını, kitlesel ölümü ve hükümetlerin zor seçimlerini anlatır. Açık şiddet içermez. Oyundaki hastalık, tedavi ve olaylar kurgusaldır ve tıbbi tavsiye değildir. |

---

## 5. Kan ve şiddet ayarı: "Sade içerik"

Mod zaten kan içermediği için "daha fazla şiddet" seçeneği **yoktur** (01 §6.2). Tersine, hassas oyuncular için bir kısma seçeneği vardır:

| Ayar | Varsayılan | "Sade" açıkken |
|---|---|---|
| Sürü figürleri (yakın zoom) | Görünür | Yalnız sayaç |
| Sürü sesleri | Açık (13 §4) | Uzak katman yalnız; nefes ve sürüme yok |
| Olay resimleri | Açık | Hastane, kamp ve çöküş resimleri gizli (metin kalır) |
| Olay metni | Standart | Ölüm sayıları "kayıp" olarak toplu verilir |
| Işık yanıp sönmesi | Nabız 0,5 Hz | Nabız yok (sabit vurgu) |

Ayar mevcut Ayarlar ekranında (`settings_panel.gd`, `user://settings.cfg`) bir onay kutusudur; oyun mantığını **değiştirmez** (yalnız
sunum). Arayüz yalnız mevcut yardımcılarla eklenir.

---

## 6. Lisans ve varlıkların kökeni

| Varlık | Kaynak | Lisans ve kural |
|---|---|---|
| Kod, veri, belgeler | Bu depo | MIT (`LICENSE`) |
| Ses efektleri ve müzik | `tools/make_audio.py`, `tools/make_music.py` ile sentez | Kodun çıktısı; depo lisansı. Hazır örnek paketi yok (13 §7) |
| Radyo spikeri kaydı (isteğe bağlı) | Gönüllü | CC0 ya da CC BY 4.0; `THIRD_PARTY_LICENSES.md`'ye yazılır; ses klonlama ve gerçek kişi taklidi yok |
| 3D figürler, ikonlar, olay resimleri | Kullanıcı üretir (CLAUDE.md kural 6) | Aşağıdaki kurallar |
| Mevcut asker figürleri | Muster WWII model arşivi | MIT (`THIRD_PARTY_LICENSES.md`'de) |

**Üretken yapay zekâyla üretilen görseller için kurallar:**
1. **Komut kuralları** (12 §1.1): Komutta hiçbir sanatçı, eser, oyun, film ya da marka adı geçmez; yalnız dönemin kamu malı görsel dili
   (1930'lar halk sağlığı afişi, alan kılavuzu gravürü, basın fotoğrafı) tarif edilir.
2. **Hizmet koşulları:** Kullanılan üretim aracının koşulları, çıktının açık kaynak projede **yeniden dağıtımına** izin vermeli.
3. **Kayıt:** Her dosya için üretim aracı, tarih ve komut `docs/art/ICON_PROMPTS_zombie.md` ile eşleşir (komutlar veriden üretilir,
   12 §9); ek olarak `THIRD_PARTY_LICENSES.md`'de "üretken araçla yapılan görseller" bölümü tutulur.
4. **Telif durumu:** ABD Telif Ofisi'nin 2023 yönergesine göre insan yaratıcılığının ürünü olmayan içerik telifle korunmayabilir. Bu,
   açık kaynak proje için sorun değildir (dosyalar zaten serbestçe paylaşılır), ama görselin **başka bir eserin korunan ifadesine
   benzememesi** hâlâ bizim sorumluluğumuzdur: her görsel gözle kontrol edilir (bilinen bir karakter, logo ya da ambleme benzerlik).
5. **Gerçek kişi yok:** Yeni portre üretilmez (12 §2); olay resimlerinde yüzler uzak ya da dönük.

---

## 7. Teknik riskler

| # | Risk | Olasılık | Etki | Azaltma | Belge |
|---|---|---|---|---|---|
| T1 | Web'de sürü sayısı akıcılığı bozar | Orta | Yüksek | Web sınırı 800, eyalet başına 2 birim, Φ iki günde bir; ekranlı ölçüm | 03 §12, 10 §10 |
| T2 | Günlük hesap WASM'da 1,5–3 kat yavaş | Orta | Orta | Zaman dilimleme (saatte 1/24); etkin küme; ölçüm | 03 §12.3 |
| T3 | Tarayıcı belleği (ikonlar tam boy yükleniyor) | Orta | Orta | İçe aktarma boyut sınırı 256, olay resimlerinde kayıplı sıkıştırma | 12 §10 |
| T4 | İndirme boyutu (+~50 MB görsel, +~19 MB ses) | Yüksek | Orta | Aynı öneriler; döngüler OGG; ileride modu ayrı paket olarak yükleme | 12 §10, 13 §8.3 |
| T5 | Kayıt boyutu ve yazma süresi (web IndexedDB) | Düşük | Düşük | base64 ikili, ~0,6 MB | 14 §5 |
| T6 | Belirlenimcilik kayması | Düşük | Orta | Durumsuz karma, çift tampon, sabit toplama sırası, test | 03 §11, 14 §6 |
| T7 | Motor kancası onay almaz ya da temel oyunla çakışır | Orta | Yüksek | Her kancanın yedek planı; birebir aynılık kanıtı; `_template` örnek kullanımı | 14 §3.4 |
| T8 | Temel oyun değiştikçe yamalar kırılır | Orta | Orta | Kimlikle çalışan yamalar; `test_mode_zombie` her CI koşusunda | 14 §9 |

---

## 8. Tasarım riskleri

| # | Risk | Belirti | Azaltma | Belge |
|---|---|---|---|---|
| D1 | **Tek düze oyun** | Her oyun "sınırı kapat, kordon kur, aşıyı bekle" | Rastgele başlangıç yeri; 80 farklı başlangıç; suş evrimi oyuncunun seçimlerine yanıt verir; Kriz Doktrini'nde birbirini dışlayan dallar (her şey alınamaz); Konsey gündemi | 04 §7, 06 §4, 09 §6.6 |
| D2 | **Kartopu zorluk** (bir kez düşen geri dönemez) | Çöküş evresinde oyuncu umutsuzca izler | Arındırma harekâtı ve temiz ilan ödülleri; dayanışma yardımı (oyuncunun seçtiği); "Dayanma" kısmi zaferi; evreler geri dönebilir (İkinci Dalga) ama Karşı Saldırı da vardır | 02 §3–§4, 08 §4.6, 09 §6.4 |
| D3 | **Tersine kartopu** (erken tam kontrol oyunu sıkıcılaştırır) | Ada ülkesi ilk ayda kapısını kapatıp bitirir | Deniz hatları çift yönlü (03 §5.3); gıda ve ticaret bağımlılığı (07 §7); yardım ve Konsey baskısı; Kara Yıl zorluğu | 03, 07, 09 |
| D4 | **Bilgi sisi hayal kırıklığı** | "Sayılar yalan söylüyor" hissi | Her sayının kaynağı ve yaşı görünür (11 §2.6); gözetim yatırımı sisi somut olarak azaltır; oyun sonunda gerçek sayılar açıklanır (11 §8) | 01 Sütun 2, 03 §8 |
| D5 | **Mikro yönetim** (kordon bölge bölge elle) | Oyuncu haritada yüzlerce tıklama yapar | Kordon eyalet listesiyle kurulur (08 §4.1); "kordonu otomatik genişlet" kolaylığı (kapalı başlar, oyuncu açar); sürüler zayıf nokta aramaz (10 §3.4) | 02 §7.3, 08, 10 |
| D6 | **Bildirim çığı** | Onlarca uyarı ve olay | Günlük sınır (6 salgın bildirimi), birleştirme, öncelik; bülten haftalık | 11 §5 |
| D7 | **80 ülke dengesi** | Bazı ülkeler hep kaybeder/kazanır | Orta ülke dayanıklılık kontrolü (10 §8, kontrol 11); zorluk hazır ayarları; yardım mekanikleri | 10 §8 |
| D8 | **Ahlaki yükün tekdüzeliği** (her olay "kötünün iyisi") | Oyuncu olayları okumadan geçer | Olaylarda gerçek seçenekler: bedeli farklı yerlere düşen 2–3 seçenek (CLAUDE.md kural 1); tarihî dayanakla somut metinler | 09 §7, §9 |

---

## 9. Birleşik risk kaydı

Olasılık ve etki: D (düşük), O (orta), Y (yüksek). "Sahip" o riski izleyecek belge ya da iş.

| # | Risk | Tür | Olasılık | Etki | Azaltma (özet) | Sahip |
|---|---|---|---|---|---|---|
| R1 | Başka eserin korunan ifadesine benzerlik (ad, görsel, metin) | Hukuki | D | Y | Temiz oda; özgün adlar; görsel gözle kontrol; komutta eser/sanatçı adı yok | Bu belge §1, §6 |
| R2 | Mod adı ya da tür adı marka/çağrışım çakışması | Hukuki | O | O | §3 yöntemi; "Hollow" için yedek ad | §3.3 |
| R3 | Üretken araç hizmet koşulları yeniden dağıtıma izin vermez | Hukuki | O | O | Araç seçerken koşul kontrolü; kayıt | §6 |
| R4 | Hastalık adıyla bir yeri/halkı damgalama | Etik | D | Y | DSÖ ilkeleri; rastgele başlangıç; "sıfır hasta" yok | §2.1–§2.2 |
| R5 | Aşı karşıtı yanlış bilgi izlenimi | Etik | D | Y | Aşı işe yarar; söylenti olayları gerçeği belirsiz bırakmaz; içerik notu | §2.1 |
| R6 | Dinî ya da kültürel imgeyle kötü tasvir (Haiti folkloru dahil) | Etik | D | Y | Dinî imge yok; kaynak biyolojik; köken saygıyla anılır | §2.3 |
| R7 | Gerçek kişileri ya da rejim suçlarını hafife alma | Etik | D | Y | Gerçek kişi hasta gösterilmez; suç kavramları çözüm değil | §2.4 |
| R8 | Pandemi travması olan oyuncuyu rahatsız etme | Etik | O | O | İçerik notu; "Sade içerik"; ton | §4.2, §5 |
| R9–R16 | Teknik riskler T1–T8 | Teknik | — | — | §7 | 14 |
| R17–R24 | Tasarım riskleri D1–D8 | Tasarım | — | — | §8 | 02, 10, 11 |

---

## 10. İnceleme listesi (zombi modu PR'larına ek)

docs/OZGUNLUK.md'nin inceleme listesine ek olarak:

- [ ] Yeni hastalık, tür, suş ya da kurum adı §2.1'deki beş koşulu sağlıyor (yer, kişi, halk/din/meslek/hayvan, aşağılayıcı/korku terimi yok)
- [ ] Yeni metin gerçek bir kişiyi hasta, Boş ya da salgından ölmüş göstermiyor; suç kavramlarını çözüm olarak sunmuyor
- [ ] Yeni mekanik hiçbir grubu etnik köken, din ya da milliyete göre hedeflemiyor
- [ ] Yeni görsel/ses komutu içerik sınırlarını (12 §1.1, 13 §1) taşıyor; komutta eser/sanatçı/marka adı yok
- [ ] Yeni olay seçenekleri gerçek seçenek (2–3), sivile şiddet seçeneği yok
- [ ] Aşı ve tedavi ile ilgili metin tıbbi yanlış bilgi izlenimi vermiyor

## 11. Açık sorular

1. **"Hollow" taraması** kim tarafından ve ne zaman yapılacak? Sonuca göre EN metinler tek seferde değiştirilebilir (kimlikler değişmez).
2. **Marka araması** (mod adı) ana oyunun yeni adı kararıyla birlikte mi yapılmalı? (docs/OZGUNLUK.md kural 8.)
3. **"Sade içerik"** ayarı yalnız bu mod için mi, yoksa temel oyunda da (savaş olayları) olsun mu?
4. **Hukuki görüş:** Açık kaynak ve ücretsiz dağıtımda risk düşük olsa da, oyunun ad ve marka kararı için bir uzmana danışılması önerilir.

## 12. Kaynaklar

- U.S. Copyright Office, *Games* (bilgi notu): https://www.copyright.gov/register/tx-games.html
- 17 U.S.C. §102(b): https://www.law.cornell.edu/uscode/text/17/102
- Directive 2009/24/EC on the legal protection of computer programs, Article 1(2): https://eur-lex.europa.eu/eli/dir/2009/24/oj
- 5846 sayılı Fikir ve Sanat Eserleri Kanunu: https://www.mevzuat.gov.tr/mevzuat?MevzuatNo=5846&MevzuatTur=1&MevzuatTertip=3
- World Health Organization (2015). *Best practices for the naming of new human infectious diseases.*
  https://www.who.int/publications/i/item/WHO-HSE-FOS-15.1 · duyuru: https://www.who.int/news/item/08-05-2015-who-issues-best-practices-for-naming-new-human-infectious-diseases
- Ackermann, H., Gauthier, J. (1991). *The Ways and Nature of the Zombi.* Journal of American Folklore 104(414), 466–494.
  https://doi.org/10.2307/541551
- U.S. Copyright Office (2023). *Copyright Registration Guidance: Works Containing Material Generated by Artificial Intelligence*,
  88 FR 16190. https://www.federalregister.gov/documents/2023/03/16/2023-05321/copyright-registration-guidance-works-containing-material-generated-by-artificial-intelligence
- PEGI, *What do the labels mean?*: https://pegi.info/what-do-the-labels-mean
- WIPO, *Nice Classification*: https://www.wipo.int/classifications/nice/en/ · WIPO Global Brand Database: https://branddb.wipo.int/
- TÜRKPATENT: https://www.turkpatent.gov.tr/ · EUIPO eSearch plus: https://euipo.europa.eu/eSearch/ · USPTO Trademark Search:
  https://www.uspto.gov/trademarks/search
- Depo: `docs/OZGUNLUK.md`, `LICENSE`, `THIRD_PARTY_LICENSES.md`, `tools/make_icon_prompts.py`, `tools/make_audio.py`, `tools/make_music.py`.
- Bu klasör: 01 §5–§6 ve §8–§9, 04 §6–§7, 05 §10, 09 §3–§7, 10 §4.3, 11 §5, 12 §1 ve §6, 13 §1 ve §7.
