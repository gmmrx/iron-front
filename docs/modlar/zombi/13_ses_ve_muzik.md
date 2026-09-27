# Zombi modu — 13 Ses ve müzik

> **Özet.** *Gri Kordon* modu için üretilmesi gereken **her sesin ve müzik parçasının** tek kataloğu, müzik durum makinesi, uzamsal
> ses ve karıştırma kuralları, üretim yolları ve web bütçesi. 04–09'daki ses listelerini toplar, eksikleri (sürü yoğunluk katmanları,
> siren, radyo, şehir ambiyansı, müzik) ekler.
> - **Toplam: 63 dosya + 8 isteğe bağlı ses kaydı.** 49 efekt (35'i öteki belgelerde, 14'ü bu belgede), 7 müzik parçası, 7 kısa olay
>   müziği (stinger). İkinci aşamada 2 parça 3'er katmana (stem) bölünür (+6).
> - **Her şey prosedüreldir:** efektler `tools/make_audio.py` (numpy sentezi), müzik `tools/make_music.py` (prosedürel orkestra) ile
>   üretilir; telifli örnek, belirsiz lisanslı ses paketi ve ses klonlama yoktur. Tek istisna isteğe bağlı radyo spikeri kaydıdır.
> - **Korku ritimden ve sessizlikten gelir:** çığlık, çiğneme, yırtılma, acı sesi yoktur (01 §6.1). Sürünün sesi yorgun nefes, sürüme
>   ve uzak uğultudur; yoğunluk arttıkça katman eklenir.
> - **Müzik yedi durumlu:** Menü · Sessizlik · Alarm · Yayılma · Kuşatma · Çöküş · Umut. Durum dünya evresinden (02 §3) ve oyuncunun
>   yerel tehdidinden seçilir. İlk sürüm mevcut müzik yönetmenini (`Audio._desired_state`, `MUSIC` tablosu) mod tablosuyla kullanır;
>   katmanlı müzik Godot 4.3+'ün etkileşimli müzik sınıflarıyla ikinci aşamadır.
> - **Web bütçesi:** ≈ +19 MB (müzik 16 MB, efekt 3 MB, OGG). Mod parçaları yalnız mod açılınca yüklenir.
> - **Motor:** 3 küçük kanca (A1–A3, §9). WWII'de etkisiz.

---

## 1. İlkeler

| İlke | Uygulama |
|---|---|
| Telif ve lisans (docs/OZGUNLUK.md, CLAUDE.md kural 6) | Bütün sesler kodla sentezlenir ya da (radyo kaydı) açık lisansla kaydedilir. Hazır örnek paketi, başka eserden kesit, ses klonlama yok. Bu depo dosya üretmez; üretim komutu ve tarif buradadır |
| Şiddet ve ton (01 §6) | Çığlık, çiğneme, kemik kırılması, acı iniltisi yok. Silah sesleri temel oyundakilerle aynı ölçüde. Sivile karşı şiddet sesi yok (olay seçenekleri soyut kalır) |
| Korku ritimden gelir | Sessizlik bir araçtır: Sessizlik evresinde parçalar arası 20–40 saniye boşluk (mevcut `_gap`); böcek sesinin aniden susması (04 `zm_night_amb`) |
| Dönem | 1930'ların ses dünyası: telgraf, radyo parazitı, el sireni, buharlı tren, tarla telefonu, daktilo. Modern elektronik ses yok |
| Din simgesi yok | Kilise çanı, ezan, ilahi yok (01 §6.4). Çan gerekiyorsa belediye binası ya da istasyon çanı |
| Oyuncu karar verir | Ses hiçbir eylem yapmaz; uyarı sesi yalnız bilgi verir |
| Okunabilirlik | Her uyarı sınıfının ayırt edilir bir sesi var; aynı ses 1 saniyede bir kereden çok çalmaz (mevcut `min_gap_ms`) |

---

## 2. Bugünkü ses sistemi (kod okundu)

| Parça | Dosya | Ne yapar |
|---|---|---|
| Efekt kaydı | `game/autoload/audio.gd` → `SOUNDS` | Ad → [dB, çeşitleme sayısı]; çeşitlemeler `ad_1.wav`, `ad_2.wav`… |
| Sıralı bildirim | `QUEUED`, `QUEUE_GAP = 0,12`, `QUEUE_MAX = 4` | Bildirim ve bitiş sesleri üst üste binmez |
| Müzik yönetmeni | `MUSIC` (durum → parçalar), `_desired_state()`, `_start_track` (çapraz kararma `FADE = 3`), `stinger(name)`, `_duck` | Durumlar: `menu`, `peace`, `tension` (dünya gerginliği ≥ 40), `war_world`, `war_player`; aynı durumda tekrarsız rastgele parça |
| Ayarlar | `music_db`, `sfx_db`, `ui_db`, `forced_track` | Ana daldaki Ayarlar ekranından; `user://settings.cfg` |
| Muharebe sesi | `game/map/battle_audio.gd` (`BattleAudio`) | 3D konumlu tüfek, makineli tüfek, topçu, patlama |
| Efekt üretimi | `tools/make_audio.py` | Yardımcılar: `noise`, `dec`, `mix`, `room`, `hall`, `tick`, `partials`, `thump`, `sweep_noise`, `radio`, `squelch`, `chatter`, `beep`, `bell`, `soft_note`, `crack` |
| Müzik üretimi | `tools/make_music.py` + `tools/audio_synth.py` | Enstrümanlar: yaylılar, bakır, tahta üflemeli, piyano, pizzicato, koro, çan, timpani, trampet, zil, tahta blok, **siren**; OGG + MP3 çıktısı |
| Mevcut boyut | `assets/audio/` 22 MB | 8 müzik parçası 1,6–2,6 MB, 5 stinger 0,13–0,35 MB (OGG); 51 efekt (WAV) |

**Sonuç:** Mod için yeni bir ses motoru gerekmez. Efekt kaydına mod adları, müzik yönetmenine mod durumları eklenir (§9).

---

## 3. Efekt kataloğu (49)

### 3.1 Başka belgelerde tarifi olanlar (35)

Tarif (prosedürel reçete) ve üretim komutu kaynak tablodadır.

| Grup | Dosyalar | Adet | Dalga 1 | Kaynak |
|---|---|---|---|---|
| Sürü ve türler | `zm_horde_common_loop`, `zm_courser_loop`, `zm_still_amb`, `zm_bellwether_call`, `zm_greatcoat_loop`, `zm_winter_amb`, `zm_thaw_sting`, `zm_night_amb`, `zm_sump_amb`, `zm_wader_amb`, `zm_strain_sting`, `zm_rasp_sting`, `zm_breach_alert` | 13 | 4 (`horde_common_loop`, `courser_loop`, `strain_sting`, `breach_alert`) | 04 §11 |
| Bilim | `zm_lab_amb`, `zm_breakthrough_sting`, `zm_accident_sting`, `zm_convoy_doses` | 4 | 2 (`breakthrough_sting`, `accident_sting`) | 05 §14 |
| Doktrin | `zm_doctrine_capstone`, `zm_order_issued`, `zm_dp_gain` | 3 | 2 (`order_issued`, `dp_gain`) | 06 §7.3 |
| Ekonomi | `zm_ration_stamp`, `zm_queue_amb`, `zm_freight_train`, `zm_food_alert` | 4 | 1 (`food_alert`) | 07 §16 |
| Askerî | `zm_flame_burst`, `zm_wire_building`, `zm_gate_crowd`, `zm_dog_alert`, `zm_searchlight_hum`, `zm_carrier_engine`, `zm_field_phone`, `zm_sealift_horn` | 8 | 3 (`flame_burst`, `wire_building`, `gate_crowd`) | 08 §17.4 |
| Siyaset | `zm_council_gavel`, `zm_radio_bulletin`, `zm_unrest_distant`, `zm_election_bell` | 4 | 2 (`council_gavel`, `radio_bulletin`) | 09 §12 |

04 §11 tablosunda `zm_winter_amb` ve `zm_thaw_sting` tek satırdadır; burada iki dosya sayıldı (13).

### 3.2 Bu belgenin ekledikleri (14)

Reçeteler `make_audio.py`'nin mevcut yardımcılarıyla yazıldı (`noise`, `dec`, `mix`, `room`, `hall`, `partials`, `thump`, `sweep_noise`,
`radio`, `tick`, `bell`). Mono, 44,1 kHz; döngüler sıfır geçişte kesilir ve baş–son 50 ms çapraz kararır.

| # | Dosya | Dalga | Süre | Döngü | Çeşitleme | Prosedürel tarif | Üretim komutu (EN) |
|---|---|---|---|---|---|---|---|
| 1 | `zm_horde_far_loop` | 1 | 12 sn | evet | 1 | Uzak kalabalık: 04'teki `horde_common` nefes katmanının 6 sesi, 120–450 Hz bant, 0,15–0,3 Hz zarflar; `hall(d=1,6, wet=0,5, dark=1.800)`; sürüme taneleri yok | "a very distant, slow crowd murmur carried on the wind, no words, no screams, loopable" |
| 2 | `zm_horde_battle_loop` | 1 | 6 sn | evet | 2 | `horde_common` + yoğun sürüme taneleri (saniyede 14–20, 300–3.000 Hz) + tahta/tel teması (`tick(lo=1.500, hi=6.000)` saniyede 2–4); silah sesi yok (onu `BattleAudio` verir) | "a dense crowd pressing forward against obstacles, shuffling, wood and wire creaking, no voices, loopable" |
| 3 | `zm_barricade_press` | 2 | 3 sn | hayır | 2 | Tahta barikata yüklenme: 80–140 Hz `thump` dizisi (4–6 darbe, düzensiz), `partials([210, 530, 870], taus=0,3)` gıcırtı, sonda tel gerilmesi `sweep_noise(0,5, 2.000, 5.000)` | "a crowd pushing against a wooden barricade, creaking planks, straining wire, no voices" |
| 4 | `zm_siren_hand` | 1 | 5 sn | hayır | 1 | El sireni: `audio_synth.siren` yükselen 280→620 Hz (1,8 sn), 1,2 sn tepe, alçalan; hafif motor kıpırtısı 18 Hz; `room(d=0,8)` | "a hand-cranked 1930s siren winding up and down once, outdoors, distant" |
| 5 | `zm_bulletin_telegraph` | 1 | 1,6 sn | hayır | 1 | Telgraf alıcısı: 1.000 Hz `beep` kısa/uzun dizisi (anlamsız, kod içermez) + kâğıt şeridi hışırtısı (`noise` 3–7 kHz) | "a telegraph receiver clicking a short message, a paper strip rustling" |
| 6 | `zm_radio_static_loop` | 1 | 8 sn | evet | 1 | `radio(noise, drive=2,5)` 300–3.000 Hz; 0,8 Hz yavaş solma; ara ara `squelch()` | "gentle 1930s radio static with slow fading, loopable" |
| 7 | `zm_radio_tune` | 2 | 1,2 sn | hayır | 1 | Ayar ıslığı: 2.400→900 Hz süpürme sinüs + parazit | "an old radio dial being tuned, a short whistle through static" |
| 8 | `zm_city_abandoned_loop` | 2 | 14 sn | evet | 1 | Rüzgâr (400 Hz alçak geçiren, 0,1 Hz zarf), 5–9 sn'de bir kepenk tıkırtısı (`thump(f=160, d=0,2)` + 1,2 kHz rezonans), 11 sn'de bir uzak köpek (08 `zm_dog_alert`'in −14 dB kopyası) | "an empty city street in wind, a loose shutter knocking, a distant dog, no people, loopable" |
| 9 | `zm_city_burning_loop` | 3 | 10 sn | evet | 1 | Yangın: `noise` 200–4.000 Hz, saniyede 30–60 çıtırtı tanesi (`crack(lo=2.000, hi=7.000)`), 40–70 Hz gümbürtü; insan sesi yok | "a large building fire crackling and roaring at a distance, no voices, loopable" |
| 10 | `zm_harbour_quarantine_loop` | 2 | 12 sn | evet | 1 | Sis düdüğü (`partials([150, 300, 450])`, 2 sn, 9 sn'de bir), su şapırtısı (80–400 Hz), zincir şıngırtısı (2,4 / 3,1 kHz uyumsuz kısmi) | "a quiet harbour in fog, a distant foghorn, water lapping, a chain clinking, loopable" |
| 11 | `zm_overrun_thud` | 1 | 1,4 sn | hayır | 1 | Alçak, boğuk tek darbe (`thump(f=55, d=0,6)`) + kapanan ağır kapı rezonansı (180 Hz, 0,5 sn) + ani sessizlik | "a heavy door closing with a low thud in a large empty hall" |
| 12 | `zm_quarantine_stamp` | 1 | 0,6 sn | hayır | 2 | Mevcut `focus_done` damgasının daha kuru, daha ağır çeşitlemesi + kâğıt | "a heavy official stamp on thick paper, dry" |
| 13 | `zm_evacuation_whistle` | 2 | 2,5 sn | hayır | 1 | Buharlı tren düdüğü (`partials([392, 494, 587])`, yavaş atak) + istasyon görevlisi düdüğü (2,8 kHz, 0,4 sn) | "a steam train whistle and a guard's whistle at a crowded station" |
| 14 | `zm_alert_generic` | 1 | 0,9 sn | hayır | 1 | Mevcut `alert` motifinin alçak iki notalı çeşitlemesi (04 `zm_breach_alert`'ten farklı perde: 330/247 Hz) | "a short low two-note chime, restrained" |

### 3.3 Uyarılar hangi sesi çalar? (11 §5.1'in 28 uyarısı)

| Ses | Uyarılar |
|---|---|
| `zm_breach_alert` (04) | 2 Kordon yarıldı, 4 Kuşatılmış şehir |
| `zm_overrun_thud` | 3 Bölge düştü |
| `zm_siren_hand` | 1 Topraklarında yeni salgın (yalnız ilk kez; sonrakiler `zm_alert_generic`) |
| `zm_food_alert` (07) | 10 Açlık, 11 Tahıl stoku |
| `zm_strain_sting` (04) | 28 Yeni suş |
| `zm_council_gavel` (09) | 23 Konsey oylaması |
| `notify_bad` (mevcut) | 5, 6, 7, 8, 14, 15, 19, 22, 24 |
| `zm_alert_generic` | Kalan 12 uyarı (düşük öncelik) |

---

## 4. Sürü ambiyansı: yoğunluk katmanları

Sürünün sesi, kameranın gördüğü yerdeki **tahmini görünür yoğunluğa** göre katmanlanır; gerçek sayıyı sızdırmamak için yalnız ekranda
görünen (oyuncuya gösterilen) sürüler sayılır (11 §2.2, bilgi sisi).

| Katman | Dosya | Koşul (kamera merkezi çevresinde, zoom < 1.200) | Düzey |
|---|---|---|---|
| Uzak | `zm_horde_far_loop` | Ekranda ≥ 1 sürü sayacı | −26 dB; zoom 1.200'den 600'e inerken −26 → −20 |
| Yakın | `zm_horde_common_loop` (04) | Kamera merkezinden 2 bölge içinde sürü | −20 dB → −14 dB (sürü sayısı 1 → 6) |
| Muharebe | `zm_horde_battle_loop` | Ekranda `UND` muharebesi | −16 dB; `BattleAudio`'nun silah sesleriyle birlikte |
| Tür rengi | 04'ün tür döngüleri (Seğirtken, Kaputlu, Sazlıkçı…) | En yakın sürüde o türün payı ≥ %30 | Yakın katmanın −4 dB altında, onunla çapraz |

Kurallar: aynı anda en çok **3 döngü**; katmanlar 1,5 sn'de çapraz kararır; oyun duraklatılınca döngüler −10 dB'ye iner (sessizlik
değil, "nefes tutma"). Uzak zoom'da (> 1.200) sürü sesi yoktur: harita okunur kalır.

---

## 5. Müzik

### 5.1 Durum makinesi

| Durum | Ne zaman | Parça | Temel oyundaki karşılığı |
|---|---|---|---|
| `zm_menu` | Ana menü, kurulum | `zm_theme` | `menu` |
| `zm_silence` | Evre 0 Sessizlik; ya da oyuncunun ülkesinde bildirilen vaka yok ve KSE < 1 | `zm_silence` | `peace` |
| `zm_alarm` | Evre 1 Alarm; ya da komşuda bildirilen vaka | `zm_alarm` | `tension` |
| `zm_spread` | Evre 2 Yayılma, oyuncunun ülkesi SALGIN değil | `zm_spread` | `war_world` |
| `zm_siege` | Oyuncunun ülkesinde SALGIN eyalet **ya da** son 7 günde kendi bölgen düştü **ya da** kordon ordusu muharebede | `zm_siege` | `war_player` |
| `zm_collapse` | Evre 3 Çöküş ve oyuncunun düşmüş payı ≥ %10; ya da İkinci Dalga | `zm_collapse` | — |
| `zm_hope` | Evre 4 Karşı Saldırı ya da 5 Sonuç; ya da oyuncu serumu bitirdi ve kendi `YE_bild` düşüyor | `zm_hope` | — |

**Öncelik** (aynı anda birden çok koşul): `zm_siege` > `zm_collapse` > `zm_hope` > `zm_spread` > `zm_alarm` > `zm_silence`. Gerekçe:
oyuncunun **yerel tehdidi** dünya evresinden önce gelir; kordonun çöktüğü anda "umut" çalmamalı.

**Histerezis:** Durum değişikliği için koşul 5 oyun günü sürmelidir (mevcut yönetmen her kontrolde değiştirir; mod için 5 günlük bekleme,
A1 kancasıyla). Böylece sınırdaki bir değer müziği her gün değiştirmez.

```
 [menü] → [sessizlik] ──komşuda vaka──▶ [alarm] ──Evre 2──▶ [yayılma]
                                            │                  │
                        kendi eyaletinde salgın / bölge düştü ─┴──▶ [kuşatma] ◀─┐
                                                                     │          │ yeniden salgın
                                        Evre 3 + düşmüş ≥ %10 ──────▶ [çöküş] ──┤
                                                                     │          │
                                        Evre 4/5 ya da serum + düşüş ▶ [umut] ──┘
```

### 5.2 Parçalar (7)

`tools/make_music.py` ile üretilir (mevcut enstrümanlar). Tonalite ve tempo temel oyunun parçalarından **bilerek farklıdır** (temel:
Re minör menü, Fa ve Si bemol majör barış, Do minör gerginlik, Sol minör, Re minör, Mi minör savaş): mod kendi ses kimliğini taşısın.

| Dosya | Durum | Süre | Tonalite / tempo | Enstrümantasyon | Karakter |
|---|---|---|---|---|---|
| `zm_theme` | Menü | 2:30 | Fa diyez minör, 72 BPM | Solo viyolonsel, piyano, uzak çan (istasyon), alçak yaylılar | Ağıt ama dik; kapanışta majör üçlüye açılır (umut ipucu) |
| `zm_silence` | Sessizlik | 2:40 | La Dorian, 80 BPM | Piyano, yaylılar pianissimo, tahta blokla saat tıkırtısı (düzensiz aralıklarla) | Tedirgin huzur; müzik ara ara "takılır" (bir ölçü eksik) |
| `zm_alarm` | Alarm | 2:20 | Mi Frig, 96 BPM | Pizzicato ostinato, tremolo yaylılar, telgraf ritmi (tahta blok), tek obua | Haber gelmiş ama kimse emin değil |
| `zm_spread` | Yayılma | 2:30 | Do diyez minör, 108 BPM | Bas ostinato, timpani, kısa bakır vuruşları, yaylılar | Yürüyen bir tehdit; marş değil (asker yok) |
| `zm_siege` | Kuşatma | 2:00 | Sol diyez minör, 120 BPM | Trampet dizisi, bakır korali, yaylı ostinato, timpani | Hattı tutmak; en yoğun parça |
| `zm_collapse` | Çöküş | 3:00 | Si bemol minör, 58 BPM | Alçak yaylılar, sözsüz koro (uzak), uzak siren (`audio_synth.siren`, çok düşük), çan yok | Boşalan dünya; uzun sessizlikler |
| `zm_hope` | Umut | 2:30 | Re majör, 84 BPM | Obua, yaylılar, piyano, yumuşak bakır | Temkinli umut; zafer marşı değil |

### 5.3 Olay müzikleri (stinger, 7)

Mevcut `Audio.stinger(name)` ile çalar; çalarken müzik kısılır (`_duck`).

| Dosya | Tetik | Süre | Tarif |
|---|---|---|---|
| `zm_st_first_case` | Oyuncunun ülkesinde ilk bildirilen vaka | 6 sn | Tek piyano notası + alçak yaylı küme, telgraf tıkırtısıyla biter |
| `zm_st_overrun` | Oyuncunun başkent eyaleti ya da bir büyük şehri düştü | 7 sn | Alçak bakır akoru, kesik; sonra sessizlik |
| `zm_st_serum` | Oyuncu Serum'u bitirdi | 6 sn | Yükselen yaylılar, majör açılış |
| `zm_st_vaccine` | Oyuncu Aşı'yı bitirdi | 8 sn | `zm_hope` temasının kısa hâli |
| `zm_st_second_wave` | İkinci Dalga olayı | 6 sn | `zm_spread` ostinatosunun geri dönüşü, minör ve yavaş |
| `zm_st_victory` | Tedavi ya da Arındırma zaferi | 10 sn | `zm_theme`'in majör hâli |
| `zm_st_collapse` | Oyuncunun çöküşü (kayıp) | 10 sn | `zm_collapse`'ın tek cümlesi, çözülmeden biter |

### 5.4 Katmanlı müzik (Dalga 2)

Godot 4.3'ten beri motor, katmanlı (dikey) ve durum geçişli (yatay) müzik için hazır akış sınıfları taşır: aynı anda eşzamanlı çalan
katmanlar ve geçiş tablosuyla parçalar arası geçiş. İkinci aşamada `zm_spread` ve `zm_siege` üçer katmana bölünür; katman düzeyleri
oyuncunun yerel tehdidinden (kordondaki sürü sayısı, 0–1) gelir.

| Parça | Katman 1 (hep) | Katman 2 (tehdit ≥ 0,3) | Katman 3 (tehdit ≥ 0,7) |
|---|---|---|---|
| `zm_spread` | Yaylı ostinato + bas | Timpani | Bakır vuruşları |
| `zm_siege` | Yaylı ostinato | Trampet dizisi | Bakır korali |

Dosyalar: `zm_spread_l1/l2/l3.ogg`, `zm_siege_l1/l2/l3.ogg` (+6; aynı uzunluk, aynı tempo, örnek hassasiyetinde hizalı). Web'de bu
sınıfların davranışı ölçülmeli (açık soru 2); ölçülmeden önce ilk sürüm tek parça kullanır.

---

## 6. Radyo anonsları

Radyo, 1930'ların devletinin halka konuşma aracıdır ve modun tonunu taşır (01 §6.1). **İlk sürümde ses kaydı yoktur:** anons metni
bildirim akışında "Radyo" etiketiyle yazılır, `zm_radio_bulletin` (09) ve `zm_radio_static_loop` çalar. İsteğe bağlı kayıt §7'de.

| # | Tetik | EN | TR |
|---|---|---|---|
| 1 | Alarm evresi | "This is the national broadcast. The Ministry of Health reports cases of an unknown fever in several ports. Citizens are asked to remain calm and report any person showing signs of fever or violent confusion." | "Burası ulusal yayın. Sağlık Bakanlığı birkaç limanda bilinmeyen bir ateşli hastalık bildirdi. Yurttaşlardan sakin olmaları ve ateş ya da şiddetli bilinç bulanıklığı gösteren kişileri bildirmeleri rica olunur." |
| 2 | Karantina yasası | "By order of the government, quarantine is now compulsory in the following provinces. Travel permits will be issued at district offices." | "Hükümet kararıyla aşağıdaki illerde karantina zorunludur. Seyahat izinleri kaza idarelerinden verilecektir." |
| 3 | Sokağa çıkma yasağı | "A curfew is in effect from nine in the evening until six in the morning." | "Akşam saat dokuzdan sabah altıya kadar sokağa çıkma yasağı uygulanmaktadır." |
| 4 | Kordon kuruldu | "Troops have taken up positions along the eastern districts. Do not approach the cordon line." | "Askerî birlikler doğu ilçeleri boyunca mevzilendi. Kordon hattına yaklaşmayınız." |
| 5 | Tahliye | "Evacuation trains will depart from the central station at dawn. Bring one suitcase per person." | "Tahliye trenleri şafakta merkez istasyondan kalkacaktır. Kişi başına bir bavul alınız." |
| 6 | Serum bulundu | "Scientists at the national institute have announced a serum. Distribution will begin with the hardest-hit provinces." | "Ulusal enstitüdeki bilim insanları bir serum açıkladı. Dağıtım en çok etkilenen illerden başlayacaktır." |
| 7 | Aşı kampanyası | "Vaccination halls are open in every provincial capital. Vaccination is free." | "Her il merkezinde aşı salonları açıldı. Aşı ücretsizdir." |
| 8 | Temiz ilan | "The province has been declared clean. Families may return to their homes." | "İl temiz ilan edildi. Aileler evlerine dönebilir." |

Metinler bilerek resmî ve sakindir: 1930'ların devlet dili. İl adları çalışma anında doldurulur. Anons yalnız oyuncunun kendi
kararından sonra gelir (ör. karantina yasası çıkarıldıktan sonra); oyuncu adına karar anlatmaz.

---

## 7. Üretim yolları ve lisans

| Yol | Ne üretilir | Araç | Lisans |
|---|---|---|---|
| Prosedürel efekt | 49 efektin hepsi | `tools/make_audio.py` (yeni işlevler: her dosya için bir fonksiyon, `ALL` listesine eklenir) | Depo lisansı (MIT); üretilen dosya kodun çıktısıdır |
| Prosedürel müzik | 7 parça, 7 stinger, 6 katman | `tools/make_music.py` (yeni parça işlevleri) | Aynı |
| Ses kaydı (isteğe bağlı, Dalga 3) | 8 radyo anonsu × 2 dil = 16 kayıt | Gönüllü spiker, sessiz odada; sonra `radio()` süzgeci | CC0 ya da CC BY 4.0 (THIRD_PARTY_LICENSES.md'ye yazılır); gerçek kişi sesi taklidi ve ses klonlama **yok** |
| Yasak | Hazır örnek paketleri, belirsiz lisanslı ses, başka eserden kesit, üretken modelle gerçek kişi sesi | — | docs/OZGUNLUK.md |

Üretim komutları (tablolardaki "EN" sütunu) prosedürel reçeteye ek olarak verilir: reçete kodla sentez içindir, komut ise istenirse
başka bir üretim yoluyla (ör. lisansı açık bir ses üreticisi) aynı sesi tarif eder. Hangi yolla üretilirse üretilsin, çıktının lisansı
depoya uygun olmalıdır.

---

## 8. Uzamsal ses, karıştırma ve bütçe

### 8.1 Karıştırma düzeyleri

Mevcut `SOUNDS` tablosundaki dB değerleriyle aynı ölçek (arayüz −11…−24, bildirim −9…−13, muharebe `BattleAudio`).

| Sınıf | Düzey | Kural |
|---|---|---|
| Arayüz | Mevcut (`ui_db`) | Değişmez |
| Uyarı (§3.3) | −9 … −12 dB | Sıralı kuyrukta (`QUEUED`); `zm_siren_hand` −8 dB, yalnız ilk vaka |
| Stinger | Müzik kanalında, müziği −8 dB kısar | Mevcut `_duck` |
| Sürü katmanları | −26 … −14 dB | §4 |
| Ambiyans (şehir, liman, laboratuvar) | −24 … −18 dB | Yalnız yakın zoom (< 640) ve ilgili eyalet ekranda |
| Muharebe | `BattleAudio` (mevcut) | Alev: −10 dB |
| Müzik | `music_db` (varsayılan −14 dB) | Sürü katmanı −14 dB'nin üstüne çıkarsa müzik −3 dB kısılır |

**Ses yüksekliği hedefi:** Müzik parçaları tümleşik −23 LUFS'e normalize edilir (yayın standardındaki hedef); efektlerde tepe
−1 dBTP. Tek bir hedef, farklı araçlarla üretilen parçaların birbirine göre dengesini korur.

### 8.2 Uzamsal ses

- Muharebe sesleri mevcut `BattleAudio` ile 3D konumludur; değişmez.
- Sürü ve ambiyans döngüleri **kamera merkezine** bağlı 2D seslerdir (stereo kaydırma: sürü ekranın solundaysa pan −0,4). Gerekçe: 1.200
  sürü için 3D ses kaynağı açmak gereksizdir; oyuncu "nerede" bilgisini haritadan alır.
- Aynı anda en çok 3 döngü + 12 efekt (mevcut `POOL = 12`).

### 8.3 Dosya boyutu (web)

| Kalem | Adet | Tahmini boyut | Dayanak |
|---|---|---|---|
| Müzik parçası (OGG, ~2:30) | 7 | ~14 MB | Mevcut parçalar 1,6–2,6 MB |
| Stinger (OGG) | 7 | ~1,8 MB | Mevcut 0,13–0,35 MB |
| Efekt, kısa (WAV, mono, < 2 sn) | 30 | ~2,5 MB | 44,1 kHz × 16 bit × ~1 sn ≈ 88 KB |
| Efekt, döngü (OGG, q5) | 19 | ~1 MB | 4–14 sn döngüler; WAV olsaydı ~12 MB |
| **Toplam** | 63 | **≈ 19 MB** | Katmanlar (+6) ≈ +12 MB (Dalga 2) |

Öneri: döngüleri OGG olarak üret (web'de indirme ve bellek); kısa efektler WAV kalsın (gecikmesiz çalma). Mod parçaları yalnız mod
açılınca yüklenir (A2).

---

## 9. Motor kancaları

`ModeRules`'a eklenir; WWII'de boş döner (mevcut müzik ve efektler birebir aynı).

| # | Kanca | Yer | Boyut | Yapılmazsa |
|---|---|---|---|---|
| A1 | `music_table() -> Dictionary` ve `music_state() -> String` ("" = temel kural) + `music_hold_days` | `Audio._desired_state`, `MUSIC` | ~12 satır | Mod temel oyunun barış/gerginlik/savaş müziğini çalar |
| A2 | `sounds() -> Dictionary` (ad → [dB, çeşitleme]) | `Audio._ready` ve mod değişiminde yeniden yükleme | ~10 satır | Mod efektleri `Audio.play` ile çalınamaz (ad bilinmez) |
| A3 | `ambience(camera_pid, zoom) -> Array` ([dosya, dB, pan]) | `Audio._process` (saniyede 2) | ~25 satır | Sürü ve şehir ambiyansı yok; yalnız olay sesleri |

Veri: `data/modes/zombie/own/audio.json` (mod altyapısının `own/` klasörü) — efekt kaydı, müzik tablosu, durum eşikleri, katman eşikleri:

```json
{
 "_comment": "Zombi modu ses kaydı. Gerekçeler: docs/modlar/zombi/13_ses_ve_muzik.md",
 "sounds": {"zm_breach_alert": [-9.0, 1], "zm_overrun_thud": [-10.0, 1], "zm_siren_hand": [-8.0, 1], "zm_alert_generic": [-12.0, 1],
            "zm_quarantine_stamp": [-9.0, 2], "zm_bulletin_telegraph": [-11.0, 1]},
 "queued": ["zm_breach_alert", "zm_overrun_thud", "zm_siren_hand", "zm_alert_generic"],
 "music": {"zm_menu": ["zm_theme"], "zm_silence": ["zm_silence"], "zm_alarm": ["zm_alarm", "zm_silence"],
           "zm_spread": ["zm_spread", "zm_alarm"], "zm_siege": ["zm_siege"], "zm_collapse": ["zm_collapse"], "zm_hope": ["zm_hope", "zm_silence"]},
 "music_priority": ["zm_siege", "zm_collapse", "zm_hope", "zm_spread", "zm_alarm", "zm_silence"],
 "music_hold_days": 5,
 "ambience": {"far": ["zm_horde_far_loop", -26, -20], "near": ["zm_horde_common_loop", -20, -14], "battle": ["zm_horde_battle_loop", -16, -16],
              "max_loops": 3, "zoom_max": 1200, "crossfade": 1.5}
}
```

---

## 10. Test planı

| # | Test | Denetim |
|---|---|---|
| 1 | Kayıt tutarlı | `own/audio.json`'daki her ad için dosya ya var ya yoksa `Audio.play` sessizce geçer (mevcut davranış: `_streams[n]` boş dizi); motor hatası yok |
| 2 | Müzik durumu | Sahte durumlarla (`music_state` girdileri) §5.1 önceliği ve 5 günlük histerezis |
| 3 | Bilgi sisi | Sürü katmanı yalnız oyuncuya görünen sürüleri sayar (gizli türde ses yok) |
| 4 | WWII birebir | A1–A3 WWII'de boş; mevcut müzik durumları aynı |
| 5 | Üretim araçları | `python3 tools/make_audio.py zm_siren_hand` gibi tek dosya üretimi hatasız (araç koşulursa; dosya depoya elle eklenir) |

---

## 11. Açık sorular

1. **Radyo kaydı** yapılacak mı, kim yapacak? Metin + parazit yeterli olabilir; kayıt yapılırsa iki dilde tutarlı ses tonu gerekir.
2. **Etkileşimli müzik sınıflarının web davranışı** (§5.4) ölçülmeli: eşzamanlı katmanlar gl_compatibility / WASM'da kaymadan çalıyor mu?
3. **Sürü sesinin rahatsız ediciliği:** Uzun oturumda sürekli nefes sesi yorucu olabilir; oyun testinde ayarlar ekranına "Ortam sesi"
   kaydırıcısı gerekebilir (mevcut üç kaydırıcıya ek; arayüz yardımcılarıyla).
4. **Kuşatma müziğinin sıklığı:** Oyuncu uzun süre kordonda kalırsa `zm_siege` tekrar eder; ikinci bir kuşatma parçası (Dalga 2) gerekebilir.
5. **Çan kullanımı:** İstasyon ve belediye çanı din simgesi sayılmaz; yine de hiçbir çanın dinî tören çağrışımı (ör. cenaze ritmi) taşımaması
   gerekir. Parça üretildikten sonra dinlenip kontrol edilmeli.

## 12. Kaynaklar

- Farnell, A. (2010). *Designing Sound.* MIT Press. ISBN 978-0-262-01441-0. https://mitpress.mit.edu/9780262014410/designing-sound/
  (prosedürel ses: sesin veri değil süreç olarak tasarlanması)
- Roads, C. (2002). *Microsound.* MIT Press. ISBN 978-0-262-18215-7 (granüler sentez: sürüme ve kalabalık "taneleri")
- Collins, K. (2008). *Game Sound: An Introduction to the History, Theory, and Practice of Video Game Music and Sound Design.* MIT Press.
  ISBN 978-0-262-03378-7 (uyarlanır müzik, dikey katman ve yatay yeniden sıralama)
- Schafer, R. M. (1977). *The Tuning of the World.* Knopf (ses peyzajı: "anahtar ses" ve "işaret sesi" kavramları; siren, çan, düdük)
- European Broadcasting Union (2023). *EBU R 128: Loudness normalisation and permitted maximum level of audio signals.*
  https://tech.ebu.ch/publications/r128
- Godot Engine belgeleri: *AudioStreamInteractive* (4.3). https://docs.godotengine.org/en/4.3/classes/class_audiostreaminteractive.html
  · Etkileşimli müzik desteği: https://github.com/godotengine/godot/pull/64488
- Depodaki kod: `game/autoload/audio.gd` (`SOUNDS`, `QUEUED`, `MUSIC`, `_desired_state`, `stinger`), `game/map/battle_audio.gd`,
  `tools/make_audio.py`, `tools/make_music.py`, `tools/audio_synth.py`, `assets/audio/` (boyutlar ölçüldü).
- Bu klasör: 01 §6, 02 §3, 04 §11, 05 §14, 06 §7.3, 07 §16, 08 §17.4, 09 §12, 11 §2.2 ve §5.
