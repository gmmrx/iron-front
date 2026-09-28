# Zombi modu — 11 Harita ve arayüz

> **Özet.** Bu belge *Gri Kordon* modunda oyuncunun **neyi, nerede, nasıl gördüğünü** tanımlar ve 02–09'daki dağınık arayüz
> önerilerini tek plana bağlar. Kararlar 01_vizyon.md ve 02_oynanis_dongusu.md'ye, harita verisi 03 §13'e dayanır.
> - **Kural 5 sınırı:** Gölgelendirici, ışık, renk dili ve model değişikliği bu belgenin kapsamı dışındadır; insan gözüyle doğrulanması
>   gereken her görsel iş "sürüm 2" olarak ayrı işaretlidir. Sürüm 1 yalnız mevcut araçlarla kurulur: işgal çizgisi, eyalet işaret
>   dokusu, birim sayaçları, harita ikonları, ipuçları ve `game/ui/panel_layout.gd` yardımcıları.
> - **Harita:** Düşmüş bölgeler mevcut işgal çizgisiyle, sürüler mevcut birim sayaçlarıyla görünür. İşaret dokusu yalnız **anlamına
>   uygun** işlerde kullanılır ("güvenli / uygun hedef" = yeşil nabız). Renkli salgın ısı haritası sürüm 2'dir (yeni harita modu,
>   gölgelendirici değişikliği, insan onayı).
> - **Üst çubuk:** Kriz hücresi yerine Küresel Salgın Endeksi (KSE); İç cephe hücresinin adı "Dayanma iradesi" olur; savaş hücresi
>   yerine "Salgın" hücresi (kendi bildirilen vakan, düşmüş bölgen). Yeni kaynak hücresi: gıda.
> - **Yeni ekran: Salgın paneli (E),** altı sekme: Durum · Eyaletler · Bilim ve Dağıtım · Kordon · Ekonomi · Dünya. Doktrin ağacı
>   mevcut Devlet Programı ekranını (F) kullanır.
> - **Bildirimler:** 28 salgın uyarısı tek tabloda, öncelik ve günlük sınırla. Salgın Bülteni her cuma; yalnız ilki olay penceresi olarak
>   açılır, sonrakiler bildirim + panel bölümüdür.
> - **Öğretici:** İlk 30 günde 9 adımlık, yalnız bilgi veren rehber (kapatılabilir; oyuncu adına hiçbir şey yapmaz).
> - **Erişilebilirlik:** Hiçbir durum yalnız renkle anlatılmaz (metin + desen + ikon); sürüm 2 ısı haritası renk körlüğüne göre
>   optimize edilmiş ardışık palette; nabız 0,5 Hz (ışığa duyarlı epilepsi eşiğinin çok altında).
> - **Motor:** 6 küçük arayüz kancası (U1–U6, §11). WWII'de hepsi etkisizdir.

---

## 1. İlkeler ve bugünkü araçlar

### 1.1 İlkeler

| İlke | Uygulama |
|---|---|
| Görsel değişiklik yok (CLAUDE.md kural 5) | Yeni panel yalnız `panel_layout.gd` yardımcılarıyla: `frame`, `fixed`, `info_cells`, `section`, `row`, `row_action`, `table`, `table_row`, `small_button`, `progress`, `tile`, `empty`, `tabs`, `stat`, `detail`, `columns`, `bar`; tema `UiTheme.skin()`. Renk, gölgelendirici, kamera, model yok |
| Bilgi sisi (01 Sütun 2) | Harita ve panel yalnız **bildirilen** veriyi gösterir; her sayının yanında "veri yaşı" ve kaynak ("taramada yakalanan", "bülten") vardır (03 §13.3) |
| Oyuncu karar verir (kural 1) | Hiçbir düğme, uyarı ya da öğretici adımı oyuncu adına eylem yapmaz. Kolaylık kutuları kapalı başlar ve panelde görünür yerdedir |
| İpucunda döküm | Her türetilmiş sayı dökümüyle gösterilir (temel oyunun ipucu geleneği; 05 §11.3 örnekleri) |
| Duraklat–oku–karar ver | Dakika döngüsü (02 §1.2): uyarı → duraklat → oku → karar → sürdür. Arayüz bu döngüyü kısaltmak için vardır |
| Metinler EN + TR | Bütün yeni anahtarlar `strings.csv`'de iki dilde (kural 3); örnekler §10 |

### 1.2 Bugünkü araçlar (kod okundu)

| Araç | Dosya | Bugün ne yapar | Modda kullanımı |
|---|---|---|---|
| İşgal çizgisi | `assets/shaders/map3d.gdshader` (`data_tex` G kanalı) | `controller ≠ owner` bölgeyi kontrol edenin renginde çapraz çizgiler | **Düşmüş bölge**: kontrol `UND`'ye geçer, çizgi kendiliğinden çıkar (03 §13.1) |
| Eyalet işaret dokusu | `MapView3D.set_marked_states` | `true` → yeşil nabız, `false` ya da işaretsiz → %40 karartma | Yalnız "uygun hedef / güvenli" anlamında (§2.3) |
| Harita modları | `MapView3D.MapMode`: Siyasi, Arazi, Eyaletler, Yollar (F1–F4); `MapModeBar` | Gölgelendiricide `map_mode` | Sürüm 2'de beşinci mod "Salgın" (§2.4) |
| Birim sayaçları | `game/map/unit_layer.gd` | Tümen sayacı, bayrak, uzak zoom'da bayrak/gizli | Sürüler: `UND` bayrağıyla (§2.2) |
| Harita ikonları | `game/map/map_icon_layer.gd` | Uzak/orta zoom'da liman, hava üssü, şehir, başkent ikonları | Araştırma merkezi, karantina hastanesi, aşı tesisi, mülteci kampı (§2.5) |
| Harita ipucu | `game/ui/map_tooltip.gd` (`_show_land`, `_line`, `_cell`) | Bölge/eyalet bilgisi, ülke kartı | Salgın satırları (§2.6) |
| Üst çubuk | `game/ui/top_bar.gd` (`_stat` hücreleri) | Nüfuz, istikrar, iç cephe, insan gücü, fabrika, yakıt, ikmal, konvoy, kriz, savaş | §3 |
| Uyarı şeridi | `game/ui/alert_bar.gd` (`_collect`) | Kırmızı kutular (boş yuva, boştaki fabrika…) | Salgın uyarıları (§5) |
| Bildirim akışı | `game/ui/notification_feed.gd`, `World.notify(text, kind)` | Sıralı bildirimler | Bülten ve olay satırları (§5) |
| Olay penceresi | `game/ui/event_popup.gd` | Başlık, resim, açıklama, seçenekler | Salgın olayları, ilk bülten (§5.3) |
| Devlet Programı ekranı | `game/ui/focus_panel.gd` (F) | Tam ekran ağaç | Kriz Doktrini ağacı (06 §4; §4.8) |
| Kısayollar | `game/main.gd` | T Y Q R U N H L I O F; F1–F4 harita; F5 hızlı kayıt; WASD kamera | **E** Salgın paneli (boş), **F6** Salgın harita modu (sürüm 2) |

---

## 2. Harita

### 2.1 Düşmüş bölgeler

`UND` (Boşlar) oynanamayan bir ülke olarak `countries.json`'a (mod yaması) girer: dizin < 256, palet rengi ve `flag_def`. Kontrol
`UND`'ye geçen bölge mevcut işgal çizgisiyle görünür; **gölgelendirici değişikliği gerekmez**. Renk seçimi bir veri kararıdır ama
görünümü etkilediği için insan gözüyle onaylanmalıdır (açık soru 1). Öneri: koyu kül grisi (`#4a4a46`) — siyasi haritadaki ülke
renklerinin hiçbirine yakın değil, "boşluk" hissi veriyor, çizgi deseni sayesinde renk körü oyuncu için de ayırt edilebilir.

"Boşalmış" eyalet (Boşlar açlıktan ölmüş, kimse kalmamış; 02 §2.5) kontrolü sahibine döner ama eyalet panelinde "Boşalmış — yeniden
yerleşim bekliyor" yazar. Haritada ayrı bir görünümü yoktur (sürüm 2'de ısı haritasında "veri yok" rengi).

### 2.2 Sürüler

Sürü birimleri `UND`'nin `Division`'larıdır (01 §3c, 04 §2). Mevcut `UnitLayer` onları kendiliğinden çizer:

| Zoom | Temel oyunda tümen | Modda sürü |
|---|---|---|
| Yakın | Sayaç + model | Sayaç + (sürüm 2'de) sürü figürleri (12_gorsel_varliklar.md) |
| Orta | Sayaç, bayrak | Sayaç, `UND` bayrağı (`flag_def`: tek renk + amblem; `FlagFactory._render` üretir, dosya gerekmez) |
| Uzak | Bayrak, sonra gizli | Aynı |

Sayaçta sayı **tahmini** güçtür: "~30.000" (3 sürü). Gizli türler (Durgun, Dehlizci, gece Gecegezer) oyuncuya çizilmez
(04 §2.5 `hidden_from`); bu, sayaç çiziminde bir görünürlük süzgecidir (U4). Sürünün ipucunda tür payları (ör. "Olağan %80, Seğirtken
%20"), tahmini güç ve **bilgi yaşı** yazar.

### 2.3 İşaret dokusu: yalnız anlamına uygun işler

İşaret dokusu yeşil nabızla "uygun" der, geri kalanı karartır. Bu anlamı korumak için yalnız şu **seçim** anlarında açılır:

| Durum | Yeşil nabız | Karartılan | Kim açar |
|---|---|---|---|
| Tahliye hedefi seçme (07 §10, 08 §11.3) | Temiz ve kapasitesi olan kendi eyaletlerin | Geri kalanı | Oyuncu "Tahliye et" düğmesine basınca |
| Aşı / serum gönderme (05 §8) | Dağıtım kapasitesi olan kendi eyaletlerin | Geri kalanı | "Aşı gönder…" düğmesi |
| Kordon eyaleti ekleme (08 §4.1) | Ordunun kordonuna eklenebilecek eyaletler | Geri kalanı | Ordu panelinde "Ekle" |
| Araştırma merkezi kurma | Bina yuvası uygun eyaletler | Geri kalanı | İnşaat paneli (mevcut akış) |
| **Güvenli bölge görünümü** | Bildirilen vakası 42 gündür 0 olan ve komşusu SALGIN olmayan eyaletler | Geri kalanı | Salgın paneli "Durum" sekmesinde "Güvenli bölgeleri göster" (aç/kapa) |

Enfekte ya da düşmüş eyaletleri işaretlemek için **kullanılmaz**: gölgelendirici "işaretli" eyaleti yeşil yakar, bu salgın için
yanlış anlam taşır (03 §13.1'deki bulgu).

### 2.4 Salgın harita modu (sürüm 2; insan onayı gerekir)

| Konu | Öneri |
|---|---|
| Veri | 03 §13.2: bölge başına 1 bayt (`epi_bytes`, log ölçekli bildirilen yaygınlık, 251 izlemede, 252 düşmüş, 253 boşalmış) + isteğe bağlı veri yaşı |
| Mod | `MapMode.OUTBREAK = 4`; mod çubuğunda beşinci düğme, kısayol **F6** (F5 hızlı kayıt) |
| Palet | Ardışık, renk körlüğüne göre optimize edilmiş, parlaklığı doğrusal artan bir ölçek (bilimsel görselleştirmede kullanılan açık kaynak paletler bu özelliği taşır). 6 sınıf + "veri yok" (eyalet taban rengi, %30 soluk) + "düşmüş" (işgal çizgisi zaten var) |
| Eski veri | Veri yaşı > 14 gün ise renk %50 soluklaşır ("sis") |
| Lejant | Mod çubuğunun altında `PanelLayout.row` satırlarıyla 8 satırlık lejant; renk kutusu + metin + aralık (yalnız renge dayanmaz) |
| Doğrulama | Forward+ ve gl_compatibility'de ekran görüntüsüyle insan onayı (kural 5); renk körlüğü benzetimiyle kontrol |
| Yedek | Sürüm 2 gelene kadar: §2.6 ipucu + Salgın paneli "Eyaletler" tablosu (bildirilen yaygınlığa göre sıralı) |

### 2.5 Harita ikonları

`MapIconLayer` kalıbı: `Sprite3D`, sabit ekran boyutu, orta zoom'da görünür, yakında söner. Yeni ikonlar (12_gorsel_varliklar.md):

| İkon | Nerede | Ne zaman görünür |
|---|---|---|
| `map_institute` | Araştırma enstitüsü olan eyaletin merkezinde | 640–2.300 |
| `map_field_lab` | Saha laboratuvarı | 640–1.600 (daha küçük önem) |
| `map_quarantine_hospital` | Karantina hastanesi | 640–2.300 |
| `map_vaccine_works` | Aşı üretim tesisi | 640–2.300 |
| `map_refugee_camp` | Mülteci kampı olan eyalet | 640–2.300 |
| `map_cordon_gate` | Kordon Hattı kapısı olan sınır bölgesi | 400–1.200 |
| `map_council` | Cenevre (Konsey merkezi) | 900–3.000 |

Düşmüş eyaletteki merkez ikonu **gri** varyantla çizilir (ayrı dosya, aynı boyut; 05 §11.4). Yakın zoom'da 3D bina modeli **eklenmez**
(kural 5; 05 §11.4).

### 2.6 Harita ipucu (eyalet / bölge)

`map_tooltip.gd` → `_show_land` sonuna bir "Salgın" başlığı (`_heading`) ve en çok 5 satır (`_line`):

```
SALGIN · Kaynak: taramada yakalanan (veri 3 günlük)
Bildirilen yaygınlık   %0,4   ↑ artıyor (×1,8 / hafta)
Durum                  Salgın  (izleme: —)
Görünen sürü           2  (~20.000)
Önlemler               Zorunlu karantina · Kordon: %60 tutuluyor · T2 tarama
```

Yabancı eyalette kaynak "Salgın Bülteni (cuma)" ve veri yaşı bültene göredir. Gerçek değerler yalnız geliştirici bayrağıyla
(`--epi-reveal`) görünür (03 §13.3).

---

## 3. Üst çubuk

`top_bar.gd`'deki hücre sırası korunur; mod yalnız **içerik ve ipucu** değiştirir (U1: hücre sağlayıcı kancası).

| Temel hücre | Modda | İpucu dökümü |
|---|---|---|
| Nüfuz | Aynı | Aynı + salgın harcamaları |
| İstikrar | Aynı | + salgın terimleri (09 §2.4) |
| İç cephe | **Dayanma iradesi** (aynı değer, `war_support`) | Altı terim (09 §2.3) |
| İnsan gücü | Aynı, **yaşayan ve çalışabilen** nüfustan | + hasta, bakıcı, kamptaki kişi (07 §2) |
| Fabrikalar | Aynı | + "İşgücü: %82" (07 §15) |
| Yakıt, İkmal, Konvoy | Aynı | Aynı |
| Kriz | **KSE** (0–100) | Etkilenen eyalet, düşmüş eyalet, dünya Boş tahmini, evre (02 §3.1) |
| Savaş | **Salgın**: kendi bildirilen vakan ve düşmüş bölge sayın; devletler arası savaş varsa ikisi ipucunda | Evre, son bülten günü |
| — (yeni) | **Gıda**: stok günü (07 §3) | Tüketim, üretim, ithalat, tayın basamağı |

Tarih kutusunun yanında **evre adı** küçük harflerle yazar ("Yayılma"). Evre değişince bildirim ve (evre açılış olayı varsa) olay penceresi
gelir (02 §3.4).

---

## 4. Salgın paneli (E)

### 4.1 Yerleşim

Mevcut yan paneller gibi: `PanelLayout.frame(panel, tr("ZM_PANEL_TITLE"), "outbreak", -1.0)` (tam ekran, haritayı kilitler; ana
dalda gelen "tam ekran paneller" davranışı) ve `PanelLayout.tabs` ile altı sekme. Sekme sırası = oyuncunun ilk ay okuma sırası:

| # | Sekme (EN / TR) | Ne sorusunu yanıtlar | Kaynak belge |
|---|---|---|---|
| 1 | Status / **Durum** | "Dünya ve ülkem ne hâlde?" | 02, 03 |
| 2 | States / **Eyaletler** | "Nerede yanıyor, nerede güvenli?" | 03 §13.3 |
| 3 | Science & Relief / **Bilim ve Dağıtım** | "Bilim nerede, serum ve aşı kime gidiyor?" | 05 §11.1 |
| 4 | Cordon / **Kordon** | "Hat tutuyor mu?" | 08 §14 |
| 5 | Economy / **Ekonomi** | "Kaç kişi çalışıyor, ekmek yetiyor mu?" | 07 §15 |
| 6 | World / **Dünya** | "Kim ne yapıyor, kime güvenebilirim?" | 09 §11 |

Sol dikey menüye (ana daldaki yeni düzen) bir düğme eklenir: ikon `outbreak`, köşede **E**. Panel U2 kancasıyla kurulur (§11).

### 4.2 Sekme 1 — Durum

| Bölüm | Yardımcı | İçerik |
|---|---|---|
| Özet | `info_cells` | KSE · Evre · Kendi bildirilen vaka (7 gün) · Eğilim · Düşmüş bölge · Serum/Aşı durumu |
| Son bülten | `section` + `detail` | Cuma bülteninin metni (en çok 8 satır): en çok artan 5 ülke, yeni suş, Konsey kararı |
| Önlemler | `table` (önlem, durum, bedel) | Karantina basamağı, sınır tutumları özeti, tarama düzeyi, kordon ordusu sayısı, liman karantinası |
| Görünüm | `row_action` + `small_button` | "Güvenli bölgeleri göster" (aç/kapa, §2.3) |
| Kolaylıklar | `row` + onay kutusu | Otomatik serum, otomatik aşı, kordonu otomatik genişlet, otomatik ticaret — **hepsi kapalı başlar** (02 §7.3) |
| Boş hâl | `empty` | "Henüz bildirilen vaka yok. İlk bülten cuma." |

### 4.3 Sekme 2 — Eyaletler

`table` sütunları: Eyalet · Bildirilen yaygınlık · Eğilim · Veri yaşı · Durum · Sürü · Önlem. Varsayılan sıralama bildirilen
yaygınlığa göre azalan; başlığa tıklayınca sıralama değişir (mevcut `table` sıralama yoksa: üç sabit sıralama düğmesi `small_button`).
Satıra tıklayınca kamera o eyalete gider (mevcut "eyalete odaklan" davranışı) ve eyalet paneli açılır. İlk 60 satır gösterilir,
altında "…ve 312 eyalet daha (temiz)" satırı (performans).

`row_action` ile satır başına iki düğme: "Karantinaya al" / "Kaldır", "Taramayı artır". Düğme eylemi yapar; satır kendiliğinden işlem
yapmaz.

### 4.4 Sekme 3 — Bilim ve Dağıtım

05 §11.1'deki taslak aynen (enstitüler, numuneler, projeler, emirler). Ek "Dağıtım" bölümü:

| Bölüm | Yardımcı | İçerik |
|---|---|---|
| Stok | `info_cells` | Serum dozu · Aşı dozu · Serbest bırakma kapasitesi/gün · Denetim bekleyen |
| Dağıtım kuyruğu | `table` | Eyalet · Tür (serum/aşı) · Doz · Varış (gün) · Durum; satırda "İptal" |
| Emir | `row_action` | "Serum gönder…", "Aşı gönder…" → harita seçim kipine geçer (§2.3 yeşil nabız) |

### 4.5 Sekme 4 — Kordon

08 §14'teki tablo (kesim, durum, tutulan pay, Kordon Hattı seviyesi, sızan Boş/gün, kapı taraması, bekletme) ve bekletme düğmeleri.
Ek: "Kordonu haritada göster" düğmesi — kordon eyaletleri §2.3 kipinde yeşil nabızla gösterilir (salt görüntü).

### 4.6 Sekme 5 — Ekonomi

07 §15'teki içerik: yaşayan nüfus, işgücü Ω, gıda f, stok günü, karaborsa K, kamptaki kişi; eyalet tablosu ve "Öncelikli sevkiyat",
"Sanayiyi taşı" düğmeleri.

### 4.7 Sekme 6 — Dünya

09 §11'deki içerik: durum hücreleri, dayanma iradesi dökümü, kamuoyu (dört tutum), Konsey, dünya tablosu, koruma altındakiler.

### 4.8 Mevcut ekranlarda değişenler

| Ekran | Değişiklik | Kaynak |
|---|---|---|
| Devlet Programı (F) | Başlık "Kriz Doktrini" (manifestten), düğüm maliyeti "DP · gün", üstte doktrin puanı hücresi | 06 §4, §7.1 |
| Hükümet (Q) | Yeni yasa grupları kendiliğinden; yasa ipucunda tutum etiketi; kabine uzmanları | 09 §3, §11; 06 §4.9 |
| Araştırma (I) | Yeni sekmeler kendiliğinden; ipucunda numune bonusu | 05 §11.2, 06 §3 |
| Diplomasi (O) | Hedef ülke başlığı altında ilişki/itibar/şeffaflık/çöküş durumu; 12 eylem | 09 §6, §11 |
| Ticaret (R) | Gıda satırı kendiliğinden; liman karantinası çarpanı ipucunda | 07 §15 |
| İnşaat (T) | Sağlık binaları ayrı bölüm; Kordon Hattı satırı | 05 §11.2, 08 §14 |
| Üretim (Y) | Serum, aşı, tıbbi malzeme hatları; "serbest bırakma kapasitesi" ipucu | 05 §11.2 |
| Ordu (U) | "Salgın cephesi" bölümü, ordu içi bulaş, kordon eyaletleri | 08 §14 |
| Donanma (N) / Hava (H) | Boğaz nöbeti, liman devriyesi, deniz tahliyesi görevleri; yakın desteğin tanıma şartı ipucunda | 08 §10–§11 |
| Lojistik (L) | Mühimmat satırı (ekipman stoğundan) | 08 §7 |
| Eyalet paneli | "Salgın" bölümü: bölmelerin **bildirilen** hâli, veri yaşı, önlemler, binalar | 03, 05 |
| Olay penceresi | Aynı; mod olayları resim yoksa resimsiz (mevcut davranış) | 09 §7 |
| Oyun sonu | Puan dökümü (§8) | 02 §4 |

---

## 5. Bildirimler ve uyarılar

### 5.1 Uyarı şeridi (tek tablo)

Uyarılar `alert_bar.gd`'nin `_collect(c)` listesine mod kancasıyla (U3) eklenir. Öncelik 1 = en solda ve kırmızı; aynı anda en çok
8 kutu görünür (mevcut şerit genişliği), fazlası "+3" kutusunda toplanır.

| # | Uyarı (EN / TR) | Tetik | Öncelik | Kaynak |
|---|---|---|---|---|
| 1 | New outbreak in your territory / Topraklarında yeni salgın | Kendi eyaletinde bildirilen vaka 0 → > 0 | 1 | 02 §1.2 |
| 2 | Cordon breached / Kordon yarıldı | Sürü kordon bölgesinden geçti | 1 | 02 |
| 3 | Province overrun / Bölge düştü | Kendi bölgen `UND`'ye geçti | 1 | 02 |
| 4 | City encircled / Kuşatılmış şehir | 08 §6.4 | 1 | 08 |
| 5 | Refugees at the border / Sınırda mülteciler | Komşu eyalet düştü, sınır açık/denetimli | 2 | 02, 07 |
| 6 | Infected division / Enfekte tümen | Ordu içi bulaş > %1 | 2 | 02, 08 |
| 7 | Exhausted division / Bitkin tümen | `UND` muharebesinde bütünlük < %12 | 2 | 08 |
| 8 | Ammunition shortage / Mühimmat kıtlığı | Muharebedeki tümenin mühimmatı 0 | 2 | 08 |
| 9 | Battle-weary army / Yorgun ordu | Cephe günü ≥ 20 | 3 | 08 |
| 10 | Hunger in {state} / {eyalet}'te açlık | Eyalette f < 0,85 | 1 | 07 |
| 11 | Grain reserve low / Tahıl stoku azaldı | Stok < 10 gün | 2 | 07 |
| 12 | Production lines cut / Üretim hatları kırpıldı | İşgücü kademesi değişti | 3 | 07 |
| 13 | Black market spreading / Karaborsa yayılıyor | K ≥ 0,25 | 3 | 07 |
| 14 | Camps overcrowded / Kamplar dolu | Kamp > nüfusun %1'i | 2 | 07 |
| 15 | Serum stock empty / Serum stoğu bitti | Dağıtım emri var, stok 0 | 2 | 02, 05 |
| 16 | Idle research institute / Boş araştırma merkezi | Merkez var, proje yok | 2 | 02, 05 |
| 17 | Unstaffed institute / Kadrosuz araştırma merkezi | Kadro 0 | 2 | 05 |
| 18 | Unprocessed sample / İşlenmemiş numune | Numune var, bağlı proje yok | 3 | 05 |
| 19 | Sample decaying / Numune bozuluyor | Kalan ömür < 7 gün | 2 | 05 |
| 20 | Doses awaiting inspection / Denetim bekleyen doz | Kalite denetimi kuyruğu > 0 | 3 | 05 |
| 21 | Idle vaccine works / Boş aşı tesisi | Tesis var, hat yok | 2 | 05 |
| 22 | High accident risk / Yüksek kaza riski | Kaza riski > 0,05/yıl | 2 | 05 |
| 23 | Council vote pending / Konsey oylaması bekliyor | Oy verilmedi | 2 | 09 |
| 24 | Hidden cases near threshold / Gizlenen vaka eşikte | s ≥ 2 | 2 | 09 |
| 25 | Measure fatigue / Önlem yorgunluğu | ≥ 8 | 3 | 09 |
| 26 | Unspent doctrine points / Harcanmamış doktrin puanı | DP ≥ 3 ve seçilebilir düğüm var | 3 | 06 |
| 27 | Undecided event / Karar bekleyen olay | Bekleyen salgın olayı ≥ 7 gün | 2 | 10 §14-7 |
| 28 | New strain reported / Yeni suş bildirildi | Keşif (04 §7.4) | 2 | 04 |

Mevcut uyarılar (boş araştırma yuvası, boştaki fabrika, seçilmemiş program, ikmalsiz tümen) aynen kalır.

### 5.2 Bildirim akışı: sınır ve sıra

Ana dalda gelen "sıralı bildirimler" düzeni kullanılır (`World.notify(text, kind)`; `kind`: `good`, `bad`, `info`). Salgın bildirim
çığına karşı: **günde en çok 6 salgın bildirimi**; aynı türden bildirimler birleşir ("3 bölge düştü: Edirne, Kırklareli, +1"). Bülten
satırları cuma bir arada gelir.

### 5.3 Salgın Bülteni

| Konu | Karar | Gerekçe |
|---|---|---|
| İlk bülten | **Olay penceresi** (seçeneksiz tek "Okudum" düğmesi yerine 2 gerçek seçenekli evre olayına bağlanır; 02 §3.4) | Oyunun asıl başlangıcıdır; oyuncunun kaçırmaması gerekir |
| Sonraki bültenler | Bildirim akışında tek satır + Durum sekmesinde tam metin | Her cuma pencere açılırsa ritmi bozar |
| Biçim | 1930'ların telgraf/bülten dili; en çok 8 satır; sayılar "bildirilen" diye yazılır | 01 §6.1 ton |

Örnek (EN / TR):

```
OUTBREAK BULLETIN No. 7 — Friday 21 February 1936
Reported cases this week: 412 (↑ ×2.1). Countries reporting: 6.
Highest increase: Kingdom of ——— (+188). New: Romania (3).
The Council recommends inspection at all sea ports.

SALGIN BÜLTENİ No. 7 — Cuma, 21 Şubat 1936
Bu hafta bildirilen vaka: 412 (↑ ×2,1). Bildiren ülke: 6.
En çok artış: ——— Krallığı (+188). Yeni: Romanya (3).
Konsey bütün deniz limanlarında denetim öneriyor.
```

(Ülke adları çalışma anında doldurulur; örnek yer tutucudur.)

---

## 6. Öğretici (ilk oturum)

02 §7.2'deki "Rehber ipuçları" seçeneği (varsayılan açık). Yalnız bilgi verir; oyuncu adına tıklamaz, panel açmaz, oyunu duraklatmaz.
Her adım bildirim akışında "Rehber" etiketiyle çıkar ve ilgili düğmenin köşesinde küçük bir işaret (mevcut uyarı şeridi kutusu biçimi)
gösterir. "Rehberi kapat" düğmesi her zaman vardır; durum kayda yazılır (`mode_state`).

| # | Tetik | Metin (TR) | Metin (EN) |
|---|---|---|---|
| 1 | Oyun başı | Dünya sessiz görünüyor, ama salgın 21 gün önce başladı. Salgın panelini **E** ile aç. | The world looks quiet, but the outbreak began 21 days ago. Open the Outbreak panel with **E**. |
| 2 | Panel ilk açılış | Gördüğün sayılar **bildirilen** sayılardır: gerçeğin gecikmeli ve eksik hâli. | The numbers you see are **reported** numbers: late and incomplete. |
| 3 | 3. gün | Taramayı artırmak geç kalmanı azaltır. Hükümet panelinde (Q) Karantina Politikası'na bak. | Better screening means learning sooner. See Quarantine Policy in the Government panel (Q). |
| 4 | İlk bülten | Cuma bülteni dünyanın durumunu verir. Başka ülkeler de gerçeği saklayabilir. | The Friday bulletin shows the world. Other countries may hide the truth too. |
| 5 | Komşuda ilk vaka | Sınır tutumunu Diplomasi panelinde (O) değiştirebilirsin. Kapalı sınır yolcuyu durdurur, sürüyü durdurmaz. | You can change border posture in Diplomacy (O). A closed border stops travellers, not hordes. |
| 6 | Kendi ilk vakan | Bir ordunun hedefini "Salgın cephesi" yapıp kordon kurabilirsin (U). | Set an army's target to "Outbreak front" to raise a cordon (U). |
| 7 | 14. gün | Bilim zamanla yarışır. Bir araştırma merkezi kur (T) ve Bilim sekmesine bak. | Science races the clock. Build a research institute (T) and check the Science tab. |
| 8 | İlk doktrin puanı ≥ 3 | Kriz Doktrini'nde (F) yönünü seç. Her şeyi alamazsın. | Choose a direction in the Crisis Doctrine (F). You cannot have everything. |
| 9 | 30. gün | Rehber burada biter. Her önlemin bir bedeli var; bedelleri ipuçlarında okuyabilirsin. | The guide ends here. Every measure has a cost; read the costs in the tooltips. |

---

## 7. Erişilebilirlik

| Konu | Karar | Dayanak |
|---|---|---|
| Renk körlüğü | Hiçbir durum yalnız renkle anlatılmaz: durum sütunlarında metin ("Salgın", "Düşmüş"), haritada desen (işgal çizgisi), ikonlarda biçim farkı. Sürüm 2 ısı haritası renk körlüğüne göre optimize edilmiş, parlaklığı doğrusal artan ardışık palet | Renk görme kusuru erkeklerin ~%8'inde görülür; kırmızı–yeşil ayrımına dayanmamak önerilir (Wong 2011); CVD için optimize edilmiş palet (Nuñez ve ark. 2018) |
| Işığa duyarlılık | Nabız 0,5 Hz (`sin(t·3)`), düşük genlik (±%8); yanıp sönen uyarı yok | WCAG 2.2 başarı ölçütü 2.3.1: saniyede 3'ten fazla parlama olmamalı |
| Okunabilirlik | Yazı boyutları `UiTheme` ölçeğinde; tablo sayıları sağa hizalı, binlik ayırıcılı (TR: nokta, EN: virgül) | Temel oyun |
| Klavye | Bütün paneller kısayolla; Salgın paneli sekmeleri 1–6 tuşlarıyla (panel açıkken) | Temel oyunun kısayol yaklaşımı |
| Zaman baskısı | Oyun her an duraklatılabilir; olaylar süresizdir (10 §5) | 02 §1.2 dakika döngüsü |
| Şiddet | Kan/şiddet ayarı ve metin tonu 17_ozgunluk_ve_riskler.md'de | 01 §6.2 |
| Dil | Bütün metinler EN + TR; sayı biçimi dile göre | Kural 3 |

---

## 8. Oyun sonu ve istatistik

Mevcut `game_over.gd` ekranı (`_show(victory, reason)`) kullanılır. Mod, sebep metnini ve puanı `ModeRules.check_end` / `score` ile
verir (mod altyapısında var). Ekranın altına U5 kancasıyla bir **döküm tablosu** eklenir:

| Satır | Değer | Kaynak |
|---|---|---|
| Sonuç | Tedavi zaferi / Arındırma zaferi / Dayanma / Çöküş / Nüfus çöküşü / İç çöküş | 02 §4 |
| Kurtarılan nüfus | 1936 nüfusunun yüzdesi | 02 §4.1 |
| Salgından ölen | Bildirilen ve tahmini gerçek (oyun bittiği için gerçek sayı açıklanır) | 01 Sütun 2: sis oyun bitince kalkar |
| Temiz ilan edilen eyalet | Sayı | 02 |
| Dayanışma | Yardım puanı | 09 §6.4 |
| Bilim | Tamamlanan tıp projesi / 13 | 05 §11.2 |
| Zorluk çarpanı | ×0,6 / ×1,0 / ×1,5 / özel | 10 §7.3 |
| **Puan** | Toplam | 02 §4.1 |

**Salgın günlüğü:** Oyun sonunda "Günlük" sekmesi, önemli olayların tarihli listesi (`table`: tarih, olay). Veri, oyun boyunca
`mode_state`'e yazılan en çok 120 satırlık halkadır. Grafik yardımcısı olmadığı için KSE'nin seyri 12 aylık `bar` sütunlarıyla gösterilir
(`PanelLayout.bar`, mevcut).

---

## 9. Menü ve oyun kurulumu

Mod altyapısında akış: Ana menü → (birden çok görünür mod varsa) mod listesi → ülke seçimi. Zombi modunda ülke seçiminden **önce** bir
**Salgın ayarları** ekranı gelir (U6):

| Bölüm | Yardımcı | İçerik |
|---|---|---|
| Zorluk | `tile` × 3 + "Özel" | Tatbikat · Salgın · Kara Yıl (02 §7.1); karo altında 3 satırlık özet (R₀, katlanma, tespit) |
| Özel ayarlar | `table` + `small_button` | 02 §7.2: başlangıç yeri, bitiş tarihi, demir irade, devletler arası savaş, rehber, salgın tohumu |
| Başlangıç yeri | `row_action` | "Rastgele" / "Kıta seç" / "Eyalet seç" (harita seçim kipi) / "Kendi başkentim" |
| Onay | `small_button` | "Ülke seç →" |

Ayarlar `mode_state`'e yazılır (kayıtla gelir). Ana menüdeki alt başlık manifestteki `subtitle` alanından gelir (mod altyapısında var):
`{"en": "1936 — 1940 · ZOMBIE OUTBREAK", "tr": "1936 — 1940 · ZOMBİ İSTİLASI"}`. Çalışma adı (*Gri Kordon*) metne sabit yazılmaz;
menüde türün adı kullanılır (01 §8, CLAUDE.md kural 4).

---

## 10. Metinler (örnek anahtarlar, `strings.csv`)

| Anahtar | EN | TR |
|---|---|---|
| `ZM_PANEL_TITLE` | Outbreak | Salgın |
| `ZM_TAB_STATUS` / `_STATES` / `_SCIENCE` / `_CORDON` / `_ECONOMY` / `_WORLD` | Status · States · Science & Relief · Cordon · Economy · World | Durum · Eyaletler · Bilim ve Dağıtım · Kordon · Ekonomi · Dünya |
| `ZM_GOI` | Global Outbreak Index | Küresel Salgın Endeksi |
| `ZM_GOI_TIP` | Share of the world living where the outbreak is established.\n%d states affected · %d overrun · phase: %s | Dünya nüfusunun salgının yerleştiği yerlerde yaşayan payı.\n%d eyalet etkilendi · %d düştü · evre: %s |
| `ZM_RESOLVE` | Public resolve | Dayanma iradesi |
| `ZM_FOOD_DAYS` | Food: %d days | Gıda: %d gün |
| `ZM_SAFE_ZONES` | Show safe zones | Güvenli bölgeleri göster |
| `ZM_REPORTED` | Reported | Bildirilen |
| `ZM_DATA_AGE` | Data %d days old | Veri %d günlük |
| `ZM_GUIDE_OFF` | Close the guide | Rehberi kapat |
| `ZM_SETUP_TITLE` | Outbreak settings | Salgın ayarları |
| `ZM_DIFF_DRILL` / `_OUTBREAK` / `_BLACK_YEAR` | Drill · Outbreak · Black Year | Tatbikat · Salgın · Kara Yıl |
| `ZM_BULLETIN_TITLE` | Outbreak Bulletin No. %d | Salgın Bülteni No. %d |
| `ZM_MORE_STATES` | …and %d more states (clean) | …ve %d eyalet daha (temiz) |
| `MAPMODE_OUTBREAK` | Outbreak (F6) | Salgın (F6) |

Mod metinlerinin, temel oyunun aynı anahtarlarını **ezmesi** gerekir (ör. "İç cephe" → "Dayanma iradesi"). Bunun için U1'deki hücre
sağlayıcı kendi anahtarını verir; genel bir çeviri ezme mekanizması (moda özel `strings` dosyası) önerilmez: iki dilde tek tablo kuralı
(kural 3) korunur ve anahtarlar `ZM_` önekiyle ayrışır.

---

## 11. Motor kancaları (arayüz)

`ModeRules`'a eklenir; WWII'de boş döner, yani mevcut arayüz birebir aynı kalır.

| # | Kanca | Yer | Boyut | Yapılmazsa |
|---|---|---|---|---|
| U1 | `topbar_cells() -> Array` (hücre başına: ikon, değer, ipucu, renk) — boş dizi = temel hücreler | `top_bar.gd` güncelleme döngüsü | ~20 satır | KSE, dayanma iradesi, gıda üst çubukta görünmez; yalnız panelde |
| U2 | `panels() -> Array` (panel betiği, kısayol, ikon) | `hud.gd` (`_decorate_side_panel` + sol menü), `main.gd` kısayol | ~25 satır | Salgın paneli açılamaz; tüm içerik mevcut panellere dağıtılmak zorunda kalır |
| U3 | `alerts(c) -> Array` | `alert_bar.gd` `_collect` sonu | ~3 satır | Salgın uyarıları yalnız bildirim akışına düşer |
| U4 | `unit_visible(d, viewer_tag) -> bool` | `unit_layer.gd` sayaç çizimi (04 §2.5 `hidden_from`) | ~4 satır | Gizli türler görünür; bilgi sisi zayıflar |
| U5 | `game_over_rows() -> Array` | `game_over.gd` `_show` | ~10 satır | Oyun sonunda yalnız sebep ve puan |
| U6 | `setup_screen() -> Control` (null = yok) | `main.gd` `_enter_setup` öncesi | ~10 satır | Zorluk yalnız manifest varsayılanı; özel ayar yok |

Ayrıca harita ikonları için `MapIconLayer`'a veri güdümlü bir liste (`map_icons() -> Array[{icon, state, range}]`) eklenebilir (U7,
isteğe bağlı; yapılmazsa ikonlar yalnız eyalet panelinde).

Sürüm 2 (insan onayı): `MapMode.OUTBREAK` ve `epi_tex` (gölgelendirici değişikliği; §2.4). Bu kanca listesi 14_teknik_plan.md'de
öteki belgelerin kancalarıyla birleştirilir.

---

## 12. Test planı

| # | Test | Denetim |
|---|---|---|
| 1 | Panel kurulur | `tests/test_zm_ui.gd`: Salgın paneli ekransız kurulur, altı sekme açılır, motor/betik hatası yok (mevcut `test_menu_mode_picker` kalıbı) |
| 2 | Bilgi sisi | Panel ve ipucu yalnız `*_reported` alanlarını okur (sarmalayıcıyla sayılır) |
| 3 | Oyuncu adına iş yok | Rehber açıkken 30 gün: hiçbir yasa, emir, dağıtım değişmemiş (`country_check --game_mode=zombie`) |
| 4 | Metinler | Bütün `ZM_*` anahtarları `strings.csv`'de iki dilde (mevcut `test_strings_used_in_code`) |
| 5 | WWII birebir | U1–U6 WWII'de boş; mevcut arayüz testleri ve birebir aynılık denetimi yeşil |
| 6 | Uyarı sınırı | 100 bölge aynı gün düşünce bildirim akışına en çok 6 salgın satırı gider |

---

## 13. Açık sorular

1. **`UND` rengi** (§2.1) insan gözüyle seçilmeli; önerilen kül grisi siyasi haritada okunaklı mı?
2. **Sürüm 2 ısı haritası** ne zaman ve kim tarafından doğrulanacak? (01'in 2. açık sorusu; 03 §13.3 B yolu.)
3. **Tablo sıralaması:** `PanelLayout.table` başlığa tıklayarak sıralamayı destekliyor mu? Desteklemiyorsa üç sabit sıralama düğmesi
   yeterli mi (§4.3)?
4. **Sekme sayısı** (6) tam ekran panelde rahat mı? Oyun testinde "Ekonomi" ile "Dünya" birleştirilebilir.
5. **Sürü figürleri** (yakın zoom) 12'deki model bütçesine bağlı; sürüm 1'de yalnız sayaç.
6. **Rehber adımlarının** zamanlaması ilk oyun testinden sonra ayarlanmalı.

## 14. Kaynaklar

- Wong, B. (2011). *Points of view: Color blindness.* Nature Methods 8, 441. https://doi.org/10.1038/nmeth.1618
- Nuñez, J. R., Anderton, C. R., Renslow, R. S. (2018). *Optimizing colormaps with consideration for color vision deficiency to enable
  accurate interpretation of scientific data.* PLOS ONE 13(7): e0199239. https://doi.org/10.1371/journal.pone.0199239
- W3C (2023). *Web Content Accessibility Guidelines (WCAG) 2.2*, Success Criterion 2.3.1 Three Flashes or Below Threshold.
  https://www.w3.org/TR/WCAG22/#three-flashes-or-below-threshold
- Depodaki kod: `game/ui/panel_layout.gd`, `game/ui/top_bar.gd`, `game/ui/alert_bar.gd`, `game/ui/notification_feed.gd`,
  `game/ui/map_tooltip.gd`, `game/ui/event_popup.gd`, `game/ui/focus_panel.gd`, `game/ui/game_over.gd`, `game/ui/hud.gd`,
  `game/map/map_view_3d.gd` (`MapMode`, `set_marked_states`), `game/map/map_icon_layer.gd`, `game/map/unit_layer.gd`,
  `game/ui/flag_factory.gd`, `assets/shaders/map3d.gdshader` (yalnız okundu), `game/main.gd` (kısayollar), `docs/wiki/tr/02_arayuz.md`.
- Bu klasör: 01 §3e, §6; 02 §1.2, §3, §7; 03 §13; 04 §2.5, §7.4; 05 §8, §11; 06 §4, §7; 07 §15; 08 §14; 09 §11; 10 §5, §7.
