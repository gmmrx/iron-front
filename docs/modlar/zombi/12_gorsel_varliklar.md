# Zombi modu — 12 Görsel varlıklar

> **Özet.** *Gri Kordon* modu için üretilmesi gereken **her görselin** tek kataloğu: 3D modeller, animasyon parametreleri, ikonlar,
> olay resimleri, harita ikonları, efektler ve şehir hâlleri. 04–09'daki listeleri toplar, eksikleri (harita, üst çubuk, uyarı, zorluk,
> evre olayları) ekler, adlandırmayı motorun ikon arama kalıbına göre düzeltir, bellek bütçesini ve üretim sırasını verir.
> - **Toplam: 267 dosya** — 16 mesh, 205 ikon, 36 olay resmi, 2 efekt dokusu, 8 şehir hâli (sürüm 2+). **Yeni portre yok:**
>   1936 liderlerinin 166 portresi aynen kullanılır; kabine uzmanları nesne ikonudur (06 §7.2).
> - **Üç dalga:** Dalga 1 (oynanabilir MVP) **106 dosya**, Dalga 2 (içerik tamamlama) **147**, Dalga 3 (görsel zenginlik, insan onayı)
>   **14**. Dosya yoksa oyun çalışır: `UiTheme.icon` `null` döner, arayüz ikonsuz çizilir (kod değişikliği yok).
> - **Stil:** Beş stil cümlesi (`STYLE_ZM_ICON`, `STYLE_ZM_STRAIN`, `STYLE_ZM_DOCTRINE`, `STYLE_SMALL`, `STYLE_ZM_EVENT`) ve ortak
>   **içerik sınırları**: kan/yara yok, çocuk yok, yüzler uzakta ya da dönük, din simgesi yok, gerçek ülke işareti yok, kızılhaç/kızılay yok.
> - **Bu depo dosya üretmez** (CLAUDE.md kural 6). Liste ve üretim komutu (prompt) buradadır; komutlar mevcut
>   `tools/make_icon_prompts.py` kalıbıyla veriden üretilecek (§9), dosyaları kullanıcı üretir.
> - **Görsel doğrulama** (kural 5): model, efekt ve şehir hâlleri masaüstünde (Forward+) ve web'de (gl_compatibility) insan gözüyle
>   onaylanır. İkon ve olay resmi motorda görünümü değiştirmez; onay gerekmez.

---

## 1. İlkeler

### 1.1 İçerik sınırları (her görsel için)

01 §6'daki ton ve içerik sınırlarından türetildi; her üretim komutunun sonunda yazar.

| Sınır | Neden | Komuttaki ifade |
|---|---|---|
| Kan, yara, uzuv kaybı, çürüme yok | 01 §6.2: korku karar ağırlığından gelir; 12+ hedefi | `no blood, no gore, no wounds` |
| Çocuk figürü yok (hasta ya da kurban) | 01 §6.2 | `no children` |
| Yüzler uzakta, dönük ya da gölgede | Gerçek kişiye benzeme riskini ve dehşet yakın çekimini önler | `figures faceless, turned away or at a distance` |
| Din simgesi yok | 01 §6.4 gerçek inançlara saygı | `no religious symbols` |
| Gerçek ülke işareti, bayrak, rütbe yok | Kaputlular hiçbir orduya ait değildir (04 T05); gerçek devletin askerini "Boş" göstermeyiz | `no national insignia, no real flags` |
| Kızılhaç, kızılay amblemi yok | Cenevre Sözleşmeleri'yle korunan koruyucu amblemler (06 §7.2, 05 §14) | `no red cross or red crescent emblem` |
| Ten rengi hastalıkla ilişkilendirilmez | Figürlerde çeşitli ten tonları; "gri hastalık" herkese aynı solgunluk katmanıyla gösterilir (04 §10.1) | `varied skin tones under the same grey pallor` |
| Yazı yok | Arayüz metni çeviriden gelir | `no text, no letters, no numbers` |
| Başka eserlerin ifadesi yok | docs/OZGUNLUK.md; stil yalnız dönemin kamu malı görsel dilinden (1930'lar halk sağlığı afişi, alan kılavuzu gravürü, basın fotoğrafı) | Komutta hiçbir eser, sanatçı, oyun ya da film adı geçmez |

### 1.2 Stil cümleleri

04 §10.2, 06 §7.2 ve temel oyunun `tools/make_icon_prompts.py` sabitleri. Tam komut = **konu** + ". " + **stil**.

| Stil | Nerede tanımlı | Kullanım | Boyut |
|---|---|---|---|
| `STYLE_ZM_ICON` | 04 §10.2 | Genel mod ikonları: türler, binalar, yasalar, emirler, uzmanlar, tutumlar | 512×512 |
| `STYLE_ZM_STRAIN` | 04 §10.2 | Bilim: suşlar, tıp teknolojileri (1930'lar bakteriyoloji levhası) | 512×512 |
| `STYLE_ZM_DOCTRINE` | 06 §7.2 | Kriz Doktrini düğümleri (emaye madalyon) | 512×512 |
| `STYLE_SMALL` | `make_icon_prompts.py` | Üst çubuk glifleri, uyarı kutuları, rozetler | 256×256 |
| `STYLE_ZM_EVENT` | **Bu belge** (aşağıda) | Olay resimleri | 1024×384 (8:3) |
| `STYLE_ZM_MAP` | **Bu belge** (aşağıda) | Harita ikonları (orta zoom, sabit ekran boyutu) | 256×256 |

Temel oyunun `STYLE_EVENT`'i "WWII grand strategy game" der; mod için ayrı cümle gerekir (04–09 "STYLE_EVENT + ek" diyordu,
burada tek cümleye bağlanır):

```
STYLE_ZM_EVENT = "Event illustration for a 1930s alternate-history epidemic grand strategy game, painted in the manner of a
sepia-tinted period press photograph turned into an oil painting, cinematic wide composition, muted desaturated colours, film grain,
figures small in the frame or seen from behind, no gore, no blood, no children, no religious symbols, no national insignia,
no red cross or red crescent emblem, no text, no captions, no borders, landscape 1024x384 (8:3)"

STYLE_ZM_MAP = "Map marker icon for a 1930s alternate-history strategy game, a small painted building or object on a round brass
token with a thin dark rim, readable at 32 px, strong silhouette, muted slate, ochre and teal palette, soft top light,
transparent background, no text, no letters, no numbers, square 1:1, 256x256"
```

### 1.3 Adlandırma: motorun arama kalıbına uy

`UiTheme.icon(name)` önce `assets/ui/icons_new/<name>.png`'yi arar. Panelin hangi adı istediği kodda sabittir (ör. ekipman için
`equipment_<id>`, bina için `building_<id>`, olay için `event_<id>`). Bu yüzden ad kalıbı veriden gelir:

| Varlık | Ad kalıbı | Kim arar |
|---|---|---|
| Teknoloji | `tech_<id>` | Araştırma paneli |
| Bina | `building_<id>` | İnşaat, eyalet paneli |
| Ekipman | `equipment_<id>` | Üretim, lojistik, ordu paneli (tabur ikonu = son ekipmanın ikonu) |
| Yasa | `law_<id>` | Hükümet paneli |
| Ulusal durum | `spirit_<id>` (kademe aileleri `PAINTED_ALIASES` ile tek ikon) | Hükümet paneli |
| Danışman | `advisor_<id>` | Hükümet paneli |
| Karar / emir | `decision_<id>` | Hükümet, ordu paneli |
| Program (doktrin) düğümü | `focus_<id>` | Devlet Programı ekranı |
| Olay | `event_<id>` | Olay penceresi |
| Kaynak | `resource_<id>` | Üst çubuk, ticaret |
| Harita ikonu | `map_<ad>` | `MapIconLayer` |

**Düzeltmeler** (öteki belgelerdeki adlar kalıba uymuyor; bu belge kesinleştirir):

| Belgede | Doğru ad | Neden |
|---|---|---|
| 08 `zm_eq_flame`, `zm_eq_carrier`, `zm_eq_dogs` | `equipment_zm_flame_pack`, `equipment_zm_light_carrier`, `equipment_zm_dogs` | Ekipman ikonu `equipment_<id>` ile aranır (kimlikler 08 §3.5'teki ekipman kimliklerine göre yazılır) |
| 08 `zm_bld_cordon_line` | `building_zm_cordon_line` | Bina ikonu `building_<id>` |
| 08 `zm_bat_*` (8) | **Kaldırılır** (Dalga 3'e ertelenir) | Ordu paneli taburu ekipman ikonuyla çizer; ayrı tabur ikonu aranmaz. İstenirse U-kancası gerekir |
| 08 `zm_dec_leaflets`, `zm_dec_sealift`, `zm_dec_flood` | `decision_zm_leaflets`, `decision_zm_sealift`, `decision_zm_flood` | Karar kalıbı |
| 08 `zm_alert_*`, 04 `zm_type_*`, `zm_strain_*`, `zm_badge_leader`, 09 `stance_*`, `zm_council`… | Aynen | Moda özel paneller bu adlarla çağırır (11 §4); motor kalıbı yok |

---

## 2. Mevcut varlıklardan yeniden kullanılanlar

| Varlık | Yol | Modda |
|---|---|---|
| Dünya haritası dokuları, arazi, su | `assets/terrain/`, `data/map/` | Aynen (01 §3e) |
| Şehir dioramaları (4 bölge × 4 boy = 16) | `assets/models/city_*.glb` | Aynen; terk/yanık hâller Dalga 3 (§7) |
| Liman, hava üssü, ağaçlar, binalar | `port.glb`, `airbase.glb`, `trees.glb`, `buildings.glb` | Aynen |
| Asker ve araç figürleri | `muster_units.glb`, `soldiers.glb`, `units.glb`; `game/map/unit_models.gd` rolleri (`inf`, `mg`, `art`, `aa`, `tank`, `heavy`, `truck`, `cargo`) | Aynen; yeni taburlar mevcut rollerle çizilir (08 §17.3) |
| Lider portreleri (166) | `assets/portraits/` | Aynen; 1936 liderleri modda da hükümettedir |
| Bayraklar | `assets/flags/*.svg`, `FlagFactory._render` | Aynen; `UND` bayrağı veriden çizilir (`flag_def`), dosya gerekmez (11 §2.2) |
| İkon seti (264 PNG) ve atlaslar | `assets/ui/icons_new/`, `assets/ui/icon_atlases/` | Taşınan 20 teknoloji, askerlik/ekonomi yasaları, temel binalar, kaynaklar, menü ikonları aynen (06 §3) |
| Arayüz derisi | `assets/ui/skin`, `panel.png`, `button*.png`, `tooltip.png` | Aynen (kural 5; yeni stil yok) |
| Muharebe efektleri | Mevcut ★5 efektleri (ağız alevi, patlama, duman) | Aynen; alev silahı ve yanan şehir için Dalga 2–3 ekleri (§6) |

---

## 3. 3D modeller ve animasyon

### 3.1 Sürü figürleri (`assets/models/hollow_units.glb`, 04 §10.1)

Mevcut figür sistemi: `unit_models.gd` MultiMesh ile çizer, rol önekiyle ölçekler (`ROLE_SCALE`), yürüyüşü **kodla** (adım boyu, hız,
sallanma) üretir; iskeletli animasyon yoktur. Sürü için aynı yol: `ROLE_SCALE["hol"] = 2.6` (piyadeyle aynı ölçek) ve tür başına yürüyüş
parametreleri. Bir sürü sayacının yanında en çok 12 figür çizilir (yoğunluk hissi; tümen figür sayısıyla aynı düzen).

| # | Mesh | Üçgen | Dalga | Yürüyüş (adım / hız / sallanma) | Tarif (üretim komutunun başı, EN) |
|---|---|---|---|---|---|
| 1 | `hol_common_a` | ≤ 1.200 | 1 | 0,7 / 2,0 / belirgin | "low-poly 1930s civilian man in a worn long coat, head bowed, arms hanging, grey pallor" |
| 2 | `hol_common_b` | ≤ 1.200 | 1 | aynı | "low-poly 1930s civilian woman in a worn dress and cardigan, head bowed, grey pallor" |
| 3 | `hol_common_c` | ≤ 1.200 | 2 | aynı | "low-poly elderly man in a waistcoat and flat cap, stooped, grey pallor" |
| 4 | `hol_courser_a` | ≤ 1.200 | 1 | 1,4 / 8,0 / az | "low-poly lean man in shirtsleeves leaning forward mid-run, grey pallor" |
| 5 | `hol_courser_b` | ≤ 1.200 | 2 | aynı | "low-poly lean woman in a work apron leaning forward mid-run, grey pallor" |
| 6 | `hol_still_a` | ≤ 900 | 2 | 0 / 0 / yok | "low-poly figure standing perfectly still, arms at sides, grey pallor" |
| 7 | `hol_still_b` | ≤ 900 | 2 | 0 / 0 / yok | "low-poly figure leaning motionless against a wall, grey pallor" |
| 8 | `hol_bellwether` | ≤ 1.400 | 2 | 0,8 / 2,4 / az | "low-poly tall figure in a long overcoat walking with head raised, grey pallor" |
| 9 | `hol_greatcoat_a` | ≤ 1.400 | 1 | 0,8 / 2,6 / düzenli | "low-poly figure in a plain long wool greatcoat and an old helmet without any insignia, grey pallor" |
| 10 | `hol_greatcoat_b` | ≤ 1.400 | 2 | aynı | aynı, "helmet missing, coat unbuttoned" |
| 11 | `hol_winter` | ≤ 900 | 2 | 0 / 0 (kış) | "low-poly figure curled on the ground, frost on the coat, grey pallor" |
| 12 | `hol_wader` | ≤ 1.200 | 2 | 0,6 / 1,8 / belirgin | "low-poly figure with darker wet lower half, reed stains, grey pallor" |

Ortak komut sonu: *"single material with vertex colours, varied skin tones under the same grey pallor, no blood, no wounds, no
exposed bones, game-ready, triangulated, Y-up, 1.75 m tall, origin at feet"*. Dehlizci ve Gecegezer ayrı model istemez (koyu ton ve gece
kullanımı; 04 §10.1).

**Ölüm/dağılma animasyonu:** Kan ve düşen beden gösterilmez. Sürü dağılınca figürler 1,5 saniyede **yere çöker ve söner** (ölçek Y
1 → 0,2, saydamlık 1 → 0; kodla, mevcut yürüyüş koduna ek). Karar gerekçesi: 01 §6.2.

**Web bütçesi:** 1.200 sürü × 12 figür = 14.400 örnek; MultiMesh ile birkaç çizim çağrısı. Uzak zoom'da figür yoktur (sayaç ya da bayrak;
mevcut kural). Kesin sınır `sim.gd` değil, ekranlı performans testiyle ölçülür (ROADMAP G bölümü).

### 3.2 Yeni tabur figürleri (08 §17.3; Dalga 3)

| # | Mesh | Üçgen | Yerine geçen (Dalga 1–2) | Tarif (EN) |
|---|---|---|---|---|
| 13 | `inf_flame` | ≤ 1.200 | `inf` | "low-poly 1930s soldier carrying a twin-tank flamethrower pack, wand pointed down, no mask" |
| 14 | `inf_dog` | ≤ 1.400 | `inf` | "low-poly soldier kneeling with a leashed shepherd dog" |
| 15 | `cav_rider` | ≤ 1.800 | `inf` | "low-poly mounted patrol rider on a horse, walking pose" |
| 16 | `carrier_light` | ≤ 1.500 | `truck` | "low-poly small open-topped tracked armoured carrier with a machine gun" |

### 3.3 Binalar

Araştırma merkezi, karantina hastanesi, aşı tesisi, Kordon Hattı ve mülteci kampı için **3D model yoktur** (05 §11.4; kural 5). Haritada
iki boyutlu ikonla (§5) ve eyalet panelinde ikonla gösterilir. Kordon Hattı'nın haritada tel/duvar çizgisi olarak görünmesi Dalga 3
açık sorusudur (§11-2).

---

## 4. İkonlar (205)

### 4.1 Başka belgelerde tam listesi olanlar

Konu cümleleri (EN) kaynak tablodadır; burada adet, stil ve dalga verilir.

| Grup | Ad kalıbı | Adet | Stil | Dalga 1 | Kaynak |
|---|---|---|---|---|---|
| Boş tabloları (türler) | `zm_type_*` | 10 | ZM_ICON | 10 | 04 §10.2 |
| Suşlar | `zm_strain_*` | 9 | ZM_STRAIN | 0 | 04 §10.2 |
| Önder rozeti | `zm_badge_leader` | 1 | SMALL | 1 | 04 §10.2 |
| Bilim binaları | `building_zm_*` | 8 | ZM_ICON | 8 | 05 §14 |
| Tıp teknolojileri (seçilmiş) | `tech_zm_*` | 6 | ZM_STRAIN | 0 | 05 §14 |
| Serum / aşı dozu | `equipment_zm_serum_dose`, `_vaccine_dose` | 2 | SMALL | 2 | 05 §14 |
| Bilim harita ikonları | `map_institute`, `map_hospital`, `map_vaccine_works` | 3 | ZM_MAP | 3 | 05 §14 (stil burada ZM_MAP'e bağlanır) |
| Doktrin düğümleri | `focus_zmd_*` | 51 | ZM_DOCTRINE | 9 (3 kök + 6 kapanış) | 06 §4.5–§4.6, §7.2 |
| Yeni teknolojiler | `tech_zm_*` | 23 | ZM_STRAIN / ZM_ICON | 0 | 06 §3.4–§3.8 |
| Karargâh emirleri | `decision_zmo_*` | 10 | ZM_ICON | 10 | 06 §7.2 |
| Kabine uzmanları | `advisor_zm_*` | 8 | ZM_ICON | 0 | 06 §7.2 |
| Aydınlatma ekipmanı, DP glifi | `equipment_zm_illumination`, `doctrine_points` | 2 | SMALL | 1 (DP) | 06 §7.2 |
| Gıda, gıda yasaları, ekonomi durumları, kararları | `resource_food`, `law_zm_*`, `spirit_zm_*`, `decision_zm_*` | 12 | SMALL / ZM_ICON | 5 (gıda + 4 yasa) | 07 §16 |
| Askerî (düzeltilmiş adlarla) | `equipment_zm_*` (3), `building_zm_cordon_line`, `zm_alert_*` (4), `decision_zm_*` (3) | 11 | ZM_ICON / SMALL | 8 (ekipman 3 + bina + 4 uyarı) | 08 §17.1 (§1.3 düzeltmeleri) |
| Siyaset | `law_zm_*` (5), `stance_*` (4), `zm_council`, `zm_standing`, `zm_fatigue`, `zm_concealment`, `zm_admin_*` (2) | 15 | ZM_ICON | 10 (5 yasa + 4 tutum + Konsey) | 09 §12 |
| **Ara toplam** | | **169** | | **67** | |

08'in `zm_bat_*` sekiz ikonu çıkarıldığı için (§1.3) 08 grubu 19 değil 11'dir.

### 4.2 Bu belgenin ekledikleri (36)

Harita ikonları (`STYLE_ZM_MAP`; `MapIconLayer`, 11 §2.5):

| # | Dosya | Dalga | Konu (EN) |
|---|---|---|---|
| 1 | `map_field_lab` | 1 | a canvas field tent with a small microscope on a folding table |
| 2 | `map_refugee_camp` | 1 | three pitched tents and a smoking stovepipe inside a rope fence |
| 3 | `map_cordon_gate` | 1 | a striped barrier pole between two posts with a lantern |
| 4 | `map_council` | 1 | a lakeside hall with tall windows and a flagpole without a flag |
| 5–9 | `map_institute_fallen`, `map_field_lab_fallen`, `map_hospital_fallen`, `map_vaccine_works_fallen`, `map_refugee_camp_fallen` | 2 | Aynı konu + "abandoned, broken windows, desaturated grey" (düşmüş eyalet varyantı; 05 §11.4) |

Üst çubuk, menü ve harita modu (`STYLE_SMALL`, 11 §3–§4):

| # | Dosya | Dalga | Konu (EN) |
|---|---|---|---|
| 10 | `menu_outbreak` | 1 | a folded outbreak bulletin with a thermometer laid across it |
| 11 | `zm_goi` | 1 | a small globe with a grey haze spreading over one side |
| 12 | `zm_outbreak_cell` | 1 | a stamped quarantine placard pinned to a door |
| 13 | `map_mode_outbreak` | 3 | a folded map with a spreading grey stain (harita modu düğmesi; sürüm 2 ile birlikte) |

Zorluk karoları (`STYLE_ZM_ICON`, 11 §9):

| # | Dosya | Dalga | Konu (EN) |
|---|---|---|---|
| 14 | `zm_diff_drill` | 1 | a practice drill: nurses and soldiers rehearsing with a stretcher in a sunny courtyard |
| 15 | `zm_diff_outbreak` | 1 | a quarantine notice on a closed shop door in a grey street |
| 16 | `zm_diff_black_year` | 1 | a snowbound railway station at night, an empty platform, one lamp |

Uyarı kutuları (`STYLE_SMALL`, 11 §5.1; öteki uyarılar mevcut ya da 08'in ikonlarını kullanır):

| # | Dosya | Dalga | Uyarı | Konu (EN) |
|---|---|---|---|---|
| 17 | `zm_alert_new_outbreak` | 1 | 1 | a red-rimmed map pin in a region |
| 18 | `zm_alert_breach` | 1 | 2 | a cut strand of barbed wire |
| 19 | `zm_alert_overrun` | 1 | 3 | a flag pole with the flag lowered (no national design) |
| 20 | `zm_alert_refugees` | 1 | 5 | a suitcase and a bundle at a barrier |
| 21 | `zm_alert_infected_div` | 1 | 6 | a helmet beside a thermometer |
| 22 | `zm_alert_hunger` | 1 | 10 | an empty tin bowl and a spoon |
| 23 | `zm_alert_serum_empty` | 1 | 15 | an empty ampoule rack |
| 24 | `zm_alert_sample_decay` | 1 | 19 | a melting block of ice in sawdust |
| 25 | `zm_alert_council_vote` | 1 | 23 | a ballot box with a brass slot |
| 26 | `zm_alert_new_strain` | 1 | 28 | a petri dish with a question-shaped wisp of mist (no letters) |
| 27 | `zm_alert_idle_institute` | 2 | 16 | a laboratory stool pushed back from an empty bench |
| 28 | `zm_alert_camps` | 2 | 14 | rows of tents packed tightly |
| 29 | `zm_alert_black_market` | 2 | 13 | a hand passing a sack through a half-open door |
| 30 | `zm_alert_fatigue` | 2 | 25 | a clock over a closed shutter |
| 31 | `zm_alert_accident_risk` | 2 | 22 | a cracked flask on a bench |
| 32 | `zm_alert_pending_event` | 2 | 27 | an unopened telegram on a desk |
| 33 | `zm_alert_unspent_dp` | 2 | 26 | a brass medallion beside an open ledger |
| 34 | `zm_alert_doses_waiting` | 2 | 20 | crates of vials with an inspector's tag |
| 35 | `zm_alert_idle_vaccine` | 2 | 21 | a silent incubator cabinet with an open door |
| 36 | `zm_alert_unstaffed` | 2 | 17 | an empty white coat on a hook |

Dalga 1'deki ikonların toplamı: 67 (§4.1) + 4 harita + 3 üst çubuk/menü + 3 zorluk + 10 uyarı = **87**; 117 ikon Dalga 2, 1 ikon
(harita modu düğmesi) Dalga 3.

---

## 5. Olay resimleri (36)

Hepsi `STYLE_ZM_EVENT`, 1024×384, `assets/ui/icons_new/event_<id>.png`. Olay resmi yoksa olay penceresi resimsiz açılır (mevcut davranış).

### 5.1 Başka belgelerde listesi olanlar (29)

| Grup | Adet | Dalga 1 | Kaynak |
|---|---|---|---|
| Türler ve suşlar | 4 | 1 (`event_zm_pale_strain`) | 04 §10.3 |
| Bilim | 4 | 1 (`event_zm_accident`) | 05 §14 |
| Ekonomi | 3 | 1 (`event_zm_refugees_at_border`) | 07 §16 |
| Askerî | 6 | 1 (`event_zm_cordon_gate`) | 08 §17.2 |
| Siyaset ve diplomasi | 12 | 4 (kabine, sızan rapor, Konsey, düşen hükümet) | 09 §12 |

### 5.2 Bu belgenin ekledikleri (7): evre açılışları ve ilk bülten

02 §3.4'teki evre açılış olayları ve ilk bülten (11 §5.3) oyuncunun en çok göreceği yedi penceredir; hepsi Dalga 1.

| # | Dosya | Olay | Konu (EN) |
|---|---|---|---|
| 1 | `event_zm_phase_alarm` | Evre 1 Alarm | a telegraph office at night, a clerk tearing a long telegram strip from the machine, a desk lamp |
| 2 | `event_zm_first_bulletin` | İlk Salgın Bülteni | a printing press running off a single-sheet bulletin, stacks of paper, workers seen from behind |
| 3 | `event_zm_phase_spread` | Evre 2 Yayılma | a railway junction at dusk, a long passenger train halted at a barrier, officials walking along the carriages with lanterns |
| 4 | `event_zm_phase_collapse` | Evre 3 Çöküş | an empty city boulevard in winter, shutters down, a tram stopped mid-street, smoke far on the horizon |
| 5 | `event_zm_phase_counterstroke` | Evre 4 Karşı Saldırı | a column of trucks and soldiers entering a quiet town at dawn, residents watching from windows at a distance |
| 6 | `event_zm_phase_second_wave` | İkinci Dalga | a hospital corridor where camp beds are being set up again, a tired nurse carrying folded blankets |
| 7 | `event_zm_phase_resolution` | Evre 5 Sonuç | a long queue at a vaccination hall in spring sunlight, doors open, figures small in the frame |

---

## 6. Efektler (VFX)

Mevcut muharebe efektleri (★5) sürülere karşı muharebede aynen çalışır (topçu, makineli tüfek, patlama). Ek efektler parçacık tabanlıdır;
web'de (gl_compatibility) parçacık desteği sınırlı olduğu için her biri iki hedefte insan gözüyle doğrulanır (kural 5).

| # | Efekt | Dalga | Doku | Tarif | Not |
|---|---|---|---|---|---|
| 1 | Alev silahı hüzmesi | 2 | `vfx_flame_sheet.png` (4×4 kare, 512×512) | Kısa (0,8 sn) turuncu-sarı alev dili, ucunda gri duman; **insan figürü üzerinde yanma yok** | Yalnız alev taburu olan tümenin muharebesinde, yakın zoom |
| 2 | Yanan şehir dumanı | 2 | Mevcut duman dokusu | Düşmüş kent bölgesinde ince, yavaş yükselen gri duman sütunu | 08 O4 "Yangın Kontrolden Çıktı" olayından sonra, yakın/orta zoom |
| 3 | Sürü toz bulutu | 3 | `vfx_dust_soft.png` (256×256) | Orta zoom'da hareket eden sürünün ardında düşük, geniş toz/buğu | Sayaç yerine hareket hissi; performans testiyle |
| 4 | Projektör hüzmesi | 3 | Doku yok (koni + sis) | Kordon kapısında gece dönen ışık | 06'daki gece nöbeti emri; ışık değişikliği sayılır, kural 5 |

**Sis ve enfeksiyon bulutu yoktur:** Hastalık havayla yayılan bir gaz değildir (01 §5); "yeşil bulut" dili hastalığı yanlış anlatır.

---

## 7. Şehir hâlleri (Dalga 3; insan onayı)

Düşmüş ve boşalmış eyaletlerdeki şehir dioramaları için iki hâl önerisi. Mevcut `CityLayer3D` dokunulmadan yapılamaz; bu yüzden
Dalga 3 ve ayrı bir görsel iş.

| Hâl | Yöntem önerisi | Dosya |
|---|---|---|
| Terk edilmiş | Aynı modelin koyu, doygunluğu düşük doku varyantı; kırık pencere için koyu yama | 4 bölge × 1 = 4 doku (`city_<bölge>_abandoned.png`) |
| Yanmış | Çatı ve cephede kurum lekeleri; duman efektiyle (§6-2) | 4 bölge × 1 = 4 doku (`city_<bölge>_burnt.png`) |

Toplam 8 doku. Gerekçe: şehir sayısı (1.847) ve 16 model varyantı sabit kalır; bellek artışı yalnız 8 doku.

---

## 8. Toplam, dalgalar ve üretim sırası

### 8.1 Toplam

| Tür | Dalga 1 | Dalga 2 | Dalga 3 | Toplam |
|---|---|---|---|---|
| 3D mesh | 4 | 8 | 4 | 16 |
| İkon | 87 | 117 | 1 | 205 |
| Olay resmi | 15 | 21 | 0 | 36 |
| Efekt dokusu | 0 | 1 | 1 | 2 |
| Şehir hâli dokusu | 0 | 0 | 8 | 8 |
| **Toplam** | **106** | **147** | **14** | **267** |

Dalga 1'deki olay resmi sayısı: 04, 05, 07, 08'den birer (4) + 09'dan 4 + bu belgenin 7'si = 15.

### 8.2 Üretim sırası (oyunun hangi anına hizmet ettiğine göre)

| Sıra | Paket | Adet | Neden önce |
|---|---|---|---|
| 1 | Evre olayları + ilk bülten (§5.2) | 7 | Oyuncunun ilk 30 günde gördüğü pencereler |
| 2 | Üst çubuk, menü, zorluk karoları (§4.2 #10–16) | 6 | Her oturumda görünür |
| 3 | 10 uyarı ikonu (§4.2 #17–26) | 10 | Dakika döngüsünün (02 §1.2) başlatıcısı |
| 4 | Boş tabloları + önder rozeti | 11 | Sürü ipucu ve Eyaletler sekmesi |
| 5 | Sürü figürleri (Dalga 1: 4 mesh) | 4 | Yakın zoom'da haritanın asıl yeni görüntüsü |
| 6 | Bilim binaları (8), dozlar (2), harita ikonları (3 + 4) | 17 | Bilim yarışı (01 Sütun 4) |
| 7 | Doktrin kökleri + kapanışlar (9), karargâh emirleri (10), DP glifi (1) | 20 | 06 P1 |
| 8 | Siyaset P1 (yasalar, tutumlar, Konsey) + ekonomi P1 + askerî P1 | 23 | Hükümet ve ordu panelleri |
| 9 | Dalga 1'in kalan 8 olay resmi | 8 | — |
| 10 | Dalga 2 (içerik tamamlama) | 147 | Kalan doktrin, teknoloji, uzman, suş, olay |
| 11 | Dalga 3 (görsel zenginlik, insan onayı) | 14 | Tabur figürleri, efekt, şehir hâlleri |

---

## 9. Üretim komutlarının veriden üretilmesi

Temel oyunda `tools/make_icon_prompts.py` veri dosyalarını okuyup `docs/art/ICON_PROMPTS.md`'yi üretir. Mod için aynı araca bir seçenek:
`python3 tools/make_icon_prompts.py --game_mode=zombie` → `docs/art/ICON_PROMPTS_zombie.md`.

| Kaynak (moddaki birleşik veri) | Üretilen satır |
|---|---|
| `technologies` (yeni `zm_*`) | `tech_<id>`: konu `icon_subject` alanından (JSON'a eklenir), stil `icon_style` alanından (`zm_strain` / `zm_icon`) |
| `buildings`, `equipment`, `laws`, `spirits`, `advisors`, `decisions`, `focuses` | Aynı kalıp |
| `events` | `event_<id>`: konu `image_subject` alanından |
| `own/assets.json` (bu belgenin §4.2, §5.2, §6, §7 tabloları) | Harita, uyarı, zorluk, efekt satırları |

Böylece **konu cümlesi verinin yanında durur**; yeni bir teknoloji eklenince prompt'u da gelir, liste elle bakım istemez. Araç, mod
verisini `GameModes.load_json` ile aynı kurallarla birleştirmek için Python'da `tools/new_mode.py`'deki birleştirme işlevini kullanır.
Alanlar yalnız araç içindir; oyun onları okumaz (JSON'da fazladan alan motoru etkilemez).

---

## 10. Bellek ve indirme bütçesi (tarayıcı)

Ölçüler depodan: `assets/ui/icons_new` 264 PNG, **47 MB**, ortalama **173 KB**; içe aktarma kayıpsız (`compress/mode=0`),
`size_limit=0` (tam boy yüklenir).

| Kalem | Tahmin | Nasıl hesaplandı |
|---|---|---|
| 205 yeni ikon (512², kayıpsız) | +35 MB indirme | 205 × 173 KB |
| 36 olay resmi (1024×384) | +18 MB | Kayıpsız PNG ~0,5 MB/adet (temel oyun olay resimleriyle aynı ölçek) |
| Açık ikonların bellekteki payı | ~1 MB/ikon (512² RGBA8) | Panel başına 30–60 ikon → 30–60 MB, panel kapanınca önbellekte kalır |
| 16 mesh | +2–4 MB | ≤ 1.400 üçgen, köşe rengi, tek malzeme |

**Öneriler** (içe aktarma ayarı değişikliği görüntüyü değiştirmez, ama kalite doğrulaması yine insan gözüyle yapılır):
1. Mod ikonları için `process/size_limit = 256`: ikonlar arayüzde en çok 96 px çizilir; indirme ve bellek ~¼'e iner (≈ +9 MB).
2. Olay resimleri için kayıplı sıkıştırma (`compress/mode=1`, kalite 0,8): ~×4–6 küçülme.
3. Web yapısında mod varlıkları **yalnız mod açılınca** yüklenir (ikonlar `load` ile tembel yükleniyor; ek iş yok). İndirme paketi ise
   bütün dosyaları içerir: ≈ +30 MB (öneri 1–2 uygulanırsa).

---

## 11. Açık sorular

1. **Sürü figürü sayısı:** Sayaç başına 12 figür web'de akıcı mı? Ekranlı ölçüm (ROADMAP G) gerekir.
2. **Kordon Hattı'nın haritada çizgi olarak görünmesi** (tel, hendek): harita katmanı işi; kural 5 gereği insan onayıyla, Dalga 3.
3. **Tabur ikonları** (08'in `zm_bat_*`): ordu panelinde taburun kendi ikonu gösterilsin mi? Motor değişikliği (tabur → ikon adı) gerekir.
4. **Kabine uzmanlarında portre** yerine nesne ikonu (06) kalıcı mı? Kurgusal kişi portresi gerçek kişiye benzeme riski taşır (17).
5. **İçe aktarma ayarları** (§10) temel oyunun ikonlarına da uygulanmalı mı? (Ayrı iş; temel oyunun web indirmesini de küçültür.)

## 12. Kaynaklar

- Cenevre Sözleşmesi (1949), I. Sözleşme, Madde 38 ve 44: koruyucu amblemlerin kullanımı. Uluslararası Kızılhaç Komitesi:
  https://ihl-databases.icrc.org/en/ihl-treaties/gci-1949/article-44
- Godot Engine belgeleri, *Importing images* (sıkıştırma kipleri, boyut sınırı): https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html
- Depodaki kod ve veri: `tools/make_icon_prompts.py` (stil sabitleri, kalıplar), `game/ui/ui_theme.gd` (`icon`, `PAINTED_ALIASES`,
  atlaslar), `game/map/unit_models.gd` (`ROLE_SCALE`, MultiMesh, kodla yürüyüş), `game/map/map_icon_layer.gd`, `game/ui/flag_factory.gd`,
  `assets/ui/icons_new/*.png.import` (içe aktarma ayarları), `docs/art/ICON_PROMPTS.md`.
- Bu klasör: 01 §5–§6, 04 §10, 05 §11.4 ve §14, 06 §7.2, 07 §16, 08 §17, 09 §12, 11 §2–§5.
