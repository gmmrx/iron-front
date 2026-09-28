# Zombi modu — 08 Askerî ve savunma: tümen, kordon, tahkimat, kuşatma

> **Özet.** Ordunun, tahkimatın, hava ve deniz gücünün sürülere karşı nasıl çalıştığı. Dayanak: 01–02 kararları, 03 salgın sayıları, 04 sürü değerleri, 06 kimlikleri.
> - **Motor taklidi** (`military.gd`'nin Python kopyası, 04 §3.3'ü saatine kadar üretir): sürüye karşı siper ve savunma artışı sonucu değiştirmez; belirleyici olan personel ateşi, bütünlük ve bölgedeki tümen sayısıdır. Bu yüzden tahkimat, sürünün saldırı ve şokunu düşüren **engel**dir: 3. seviye Kordon Hattı piyade tümeninin karşılayabildiği sürü sayısını 3'ten 4'e çıkarır.
> - **8 yeni tabur/bölük** (alev, karantina jandarması, istihkâm, sıhhiye, nişancı, zırhlı taşıyıcı, köpekli iz ve nöbet, atlı devriye), 3 ekipman, 5 şablon; değerler piyade taburundan türetildi.
> - **Kordon** = `Army.enemy = "UND"` + seçilen kordon eyaletleri. Harita ölçümü: medyan eyaleti tam kuşatmak 10, yarım 5 tümen ister; Türkiye'nin 19 sınır bölgesi, 1936'da 20 tümeni var.
> - **Ordu içi bulaş:** sıhhiye bölüğü ordu içi üreme sayısını 0,45'ten 0,21'e (kuluçka testiyle 0,06'ya) indirir; sıhhiyesiz tümen hastalığı cephe gerisine taşır. **Mühimmat** yeni kaynak değildir, ekipman stokundan düşülür.
> - **Moral:** ilk temas şoku, muharebe yorgunluğu ve rotasyon, ahlaki yük olayı; sivile karşı askerî eylem hiçbir koşulda seçenek değildir.
> - **Hava:** motorun `UND`'ye karşı kendiliğinden verdiği +0,25 üstünlük kalkar, yakın destek hedef ayırt edilebilirliğiyle çarpılır. **Deniz:** boğaz nöbeti, liman devriyesi, deniz tahliyesi (1 konvoy ≈ 10.000 kişi/sefer), kıyı ateşi.
> - 11 küçük, içerikten bağımsız motor kancası (her birinin yedek planı var) ve öteki belgelere 6 bulgu (kent arazisi yok, `at_war` yan etkileri, 06'daki tel etkisinin işlememesi).

---

## 1. Kapsam, ilkeler ve öteki belgelerle ilişki

### 1.1 Bu belge neyi kesinleştirir?

| Konu | Bu belge | Kaynak belge |
|---|---|---|
| Sürü blokları, tür değerleri, ısırık payı, top sesi çekimi, `UND` kuralları | Kullanır | 04_zombi_turleri.md §2–§5 |
| Salgın denklemleri, κ_asker (garnizon bastırması), sürü doğumu, dağınık yürüyüş ve `g_ij`, tarama düzeyleri T0–T2 | Kullanır; κ_asker'e tabur ağırlığı ekler | 03_salgin_modeli.md §3, §5.6, §8.3, §10 |
| Silah, tahkimat, lojistik teknolojileri; D ve C doktrin dalları; karargâh emirleri; modifier anahtarları | Kullanır; iki etkinin yeniden hedeflenmesini önerir (§5.1) | 06_teknoloji_ve_yetenek_agaci.md §3.4–§3.10, §4.6, §4.8 |
| Serum ve aşı dozları, karantina hastanesi binası, numune | Kullanır | 05_arastirma_merkezleri.md §4, §6, §8 |
| Yeni taburlar, şablonlar, kordon ordusu, Kordon Hattı binası, kuşatma, mühimmat, ordu içi seyir, moral, hava/deniz kuralları | **Kesinleştirir** | — |

### 1.2 İlkeler

| İlke | Bu belgedeki uygulaması |
|---|---|
| Oyuncu karar verir (CLAUDE.md kural 1) | Hiçbir tümen kendiliğinden kurulmaz, kordona atanmaz, geri çekilmez, tahliye edilmez. Oyuncu tümenlerinde "son askere kadar" açık başlar (temel oyun) ve modda da öyle kalır. Bitkin tümen için yalnız **uyarı** gelir (§9.5). Tek kolaylık 02'deki "Kordonu otomatik genişlet" seçeneğidir ve kapalı başlar |
| Veri güdümlü (kural 2) | Taburlar, şablonlar, bina, engel ve moral katsayıları JSON'dadır (§16). Motor "alev" ya da "köpek" sözcüğünü bilmez; yalnız sayısal ek anahtarları toplar |
| Yeni sistem değil, kanca | Muharebe formülü, cephe, ikmal, takviye, yakıt ve karargâh kapasitesi aynen kalır. Her yeni kural ya mevcut bir çarpana eklenir ya da `rules.gd`'de yürür (§2.3) |
| Ton (01 §6) | Kan ve uzuv yok; alev etkisi duman olarak görünür. **Sivillere karşı hiçbir askerî eylem yoktur:** kalabalığı dağıtmak, kaçışı ateşle durdurmak, "sızanı vurmak" seçenek olarak yazılmaz. Gaz ve elektrikli tel kapsam dışıdır (§3.7) |
| Sayılar gerekçeli (docs/OZGUNLUK.md) | Her değer ya depodaki bir değerden (piyade taburu, motor sabitleri, harita ölçümü) ya da açıkça yazılmış bir varsayımdan türetildi. Muharebe sonuçları motor taklidiyle ölçüldü (Ek A) |

### 1.3 Bu oturumun sınırı
Belge yazılırken web araması ve sayfa çekme bu oturumda kullanılamadı (arama kotası dolmuştu, dış erişim kapalıydı). Bu yüzden:
- Sayıların büyük kısmı **depodaki veriden ve motor taklidinden** türetildi; bunlar yeniden üretilebilir (Ek A).
- 01–06'nın doğruladığı kaynaklar yeniden kullanıldı. Bu belgenin eklediği kaynaklar yazarın bilgisine dayanır, Kaynaklar bölümünde
  ayrı listelenir ve yayından önce denetlenmelidir. Emin olunamayan tarihî ayrıntılar metne sayı olarak girmedi; §19'da ayrıca
  sayıldı.

## 2. Motor: bugün ne var, modda ne değişir?

### 2.1 Mevcut askerî motorun ölçüleri (kod okundu)

| Parça | Değer | Yer |
|---|---|---|
| Piyade taburu | PA 30, TA 5, savunma 110, şok 15, can 50, bütünlük 100, genişlik 4, hız 4, 1.000 kişi, 100 piyade teçhizatı | `units.json` |
| Topçu taburu | PA 125, TA 10, savunma 50, şok 30, can 1,2, bütünlük 0 (ortalamaya girmez), genişlik 6, 500 kişi, 12 top | `units.json` |
| Tümen değeri | Tabur toplamı; bütünlük yalnız bütünlüğü > 0 olan taburların ortalaması; sertlik tabur sayısına bölünür | `Military.stats` |
| İsabet | Saldırının savunma (ya da şok) değerine kadar olan kısmı ×0,1, üstü ×0,4; isabet başına bütünlük −0,0367, güç −0,022/can | `_apply_hits` |
| Cephe genişliği | Arazi genişliği ×1,34 (ova 241, orman 225, tepe 214, dağ 201, bataklık 209, kent 257) | `_frontline` |
| Geri çekilme | Bütünlük < %12 ya da güç < %10; "son askere kadar" açıksa tümen çekilmez, güç < %4 olunca yok olur | `_resolve_battle` |
| Toparlanma | Muharebe dışında saatte bütünlüğün %2'si (yürürken %0,8); ikmalsizse en çok %40 | `_recover` |
| Siper | 240 saat bekleyişte savunma ×(1 + 0,15 + `entrenchment`) | `entrenchment` |
| İkmal | Kaynak: dost sahipli ve dost kontrollü **bütün** eyalet bölgeleri + dost limanlar; işgal edilmiş toprağa 9 bölge; ikmalsiz: −0,35 muharebe, günde −%1 güç | `_compute_supply` |
| Takviye | Günde en çok %8, ekipman ve insan gücüyle | `_reinforce` |
| Ordu → cephe | `Army.enemy` ülkesinin kontrolündeki bölgelere komşu kendi bölgeleri; savunmada her cephe bölgesine en az 1 tümen, taarruzda güç oranı ≥ 1 olan komşuya saldırı | `front_provinces`, `_army_spread`, `_army_attack` |
| Karargâh kapasitesi | Barışta +0,3/gün, savaşta +0,5/gün, tavan 200 | `_experience_tick` |

### 2.2 Altı bulgu (öteki belgelere geri bildirim)

| # | Bulgu | Ölçüm / kanıt | Öneri |
|---|---|---|---|
| B1 | **Haritada kent arazisi yok.** 9.827 kara bölgesinin dağılımı: ova 3.881, orman 2.216, tepe 2.123, çöl 870, dağ 684, bataklık 53, kent **0**. 04'ün "kent 0" kuralı, 06'nın `zm_urban_attack`'ı ve Dehlizci'nin "urban bölgesi" şartı bugün hiçbir yerde çalışmaz | `data/map/provinces.json` sayıldı | Mod kuralı: içindeki şehirlerin nüfusu ≥ 250.000 olan bölge **muharebede kent sayılır** → 391 bölge, 318 milyon kişi (Türkiye'de İstanbul, Ankara, İzmir). Kanca K5 (§2.3) |
| B2 | **`UND` ile kalıcı savaş, `Diplomacy.at_war()`'ı herkes için doğru yapar.** Yan etkiler: seçimler ertelenir, "savaşta" yasaları açılır, karargâh kapasitesi +0,5 olur, yapay zekâ silahlanma kipine geçer, bütün demokrasiler 270 gün "garip savaş" saldırı cezası (−0,25) alır | `politics.gd` 490, `economy.gd` 280, `military.gd` 362, `ai.gd` 66, `_phoney_war_malus` | `UND` savaş kaydı `"kind": "outbreak"` taşır ve `at_war()` onu saymaz. Muharebe `are_enemies()` ile çalışmaya devam eder. Manifestte `combat.phoney_war_days: 0`, `ai.phoney_war_days: 0`. Seçimlerin salgında yapılıp yapılmayacağı siyaset belgesinin kararıdır |
| B3 | **Temel ikmal kuralında kuşatma olmaz.** Kendi eyaletinin her dost kontrollü bölgesi kaynak sayılır; sürülerle çevrili bir anavatan kenti ikmalli kalır | `_compute_supply` | Modda kaynak: başkente dost toprakla **bağlı** bölgeler + deniz hâkimiyeti olan dost limanlar (K6, §6.4) |
| B4 | **Hava üstünlüğü `UND`'ye karşı kendiliğinden +0,25 verir.** Görevdeki her dost kanat için rakip hava gücü 0 olduğundan `(1 − 0,5) × 0,5 = 0,25` | `Air.bonus` | `UND`'ye karşı üstünlük terimi 0; yalnız yakın destek terimi, hedef ayırt edilebilirliğiyle (§10.1). Kanca K8 |
| B5 | **06'daki tel ve savunma etkileri sürüye karşı işlemez.** 3 sürü → siperli piyade tümeni: siper ×1,15 de, ×1,30 da (`zm_wire_obstacles`), savunma +%10 da aynı sonucu verir (57 sa, bütünlük %30). Sürünün toplam saldırısı (360) tümen savunmasının (1.000) altındadır; isabet bu durumda saldırının %10'udur ve savunma değerinden bağımsızdır | Ek A, B1 senaryosu | Engel etkisi **sürünün saldırı çarpanına ve şok değerine** yazılır (§5.1). 06'ya öneri: `zm_wire_obstacles` → `zm_obstacle +0,05`; `zm_final_protective_fire` → `artillery_soft +0,08` (yalnız savunmada). 02 §3.4'teki "Her karışı savun: savunma +%10" seçeneği de aynı nedenle `zm_obstacle`'a çevrilmeli |
| B6 | **Tümen içinde topçu yoksa sürü dağıtılamaz.** Topçusuz "sessiz" şablon (PA 235) 2 sürüyü 104 saatte zar zor, 3 sürüyü hiç dağıtamaz; topçulu şablon (PA 452) 3 sürüyü dağıtır | Ek A, B2 | 06 D2'deki "Ateş ve Hareket ↔ Sessiz Yaklaşma" seçimi sayıyla doğrulanır: sessizlik gerçek bir bedeldir. Bu bir sorun değil, kasıtlı bir ikilemdir; ipucunda yazılır |

### 2.3 Motor kancaları (içerikten bağımsız, küçük)

Mod kuralları (`docs/modlar/README.md`) motor dosyalarının mod için değiştirilmesini yasaklar: "gerekiyorsa dur ve sor". Aşağıdaki
kancalar içerikten bağımsızdır, WWII modunda varsayılan değerleriyle hiçbir şeyi değiştirmez ve insan onayıyla ayrı bir PR'da eklenir.
Her birinin yedek planı vardır.

| # | Kanca | Yer | İş | Yapılmazsa |
|---|---|---|---|---|
| K1 | Tabur verisinde isteğe bağlı `extra` sözlüğü; `stats()` her sayısal anahtarı hem adetle (`Σ v·adet`) hem genişlikle (`Σ v·genişlik·adet`) toplar | `Military.stats` | ~10 satır | `rules.gd` şablonun tabur sözlüğünü kendisi okur (her tümen için önbellekli); çalışır, biraz yavaş |
| K2 | `ModeRules.combat_mod(d, pid, attacker) -> float`; `attack_mod` ve `defend_mod`'a eklenir | `military.gd` | ~6 satır | Engel, alev, gece ve mühimmat kıtlığı çarpanları yok; yalnız ülke geneli modifier'larla yaklaşık olarak yazılır |
| K3 | `ModeRules.on_hits(d, hits, strength_loss, pid)`, `_apply_hits` sonrası | `military.gd` | ~4 satır | 04'ün `bite()` kancasıyla aynıdır; yoksa ısırık hesabı `on_hour`'da güç farkından (önceki saat − şimdi) çıkarılır |
| K4 | `ModeRules.front_provinces(a)` → boş değilse `front_provinces`'ın yerine geçer; `Army.cordon` (eyalet listesi) kayda girer | `military.gd`, `army.gd`, `game.gd` | ~15 satır | Kordon ordusu yalnız `UND` kontrolündeki bölgelere komşu cephe kurar ("düşmüş hat"); düşmeden önce kordon kurulamaz. Bu modu çok zayıflatır, **zorunlu kanca** sayılmalı |
| K5 | `ModeRules.terrain_of(pid) -> String` (boşsa bölgenin kendi arazisi) | `attack_mod`, `_resolve_battle`, `_speed` | ~5 satır | Kent kuralları çalışmaz (B1) |
| K6 | `ModeRules.supply_sources(c) -> Array` (boşsa temel kural) | `_compute_supply` | ~8 satır | Kuşatma yok; kuşatma olayları yalnız düşmüş komşu sayısıyla tetiklenir |
| K7 | `ModeRules.org_cap(d) -> float` (1,0 varsayılan), `_recover` tavanı | `military.gd` | ~2 satır | Muharebe yorgunluğu yok; rotasyon yalnız ordu içi bulaşla gerekçelenir |
| K8 | `ModeRules.air_bonus(pid, tag, own_f, foe_f, own_g) -> float` (−1 dönerse temel formül) | `Air.bonus` | ~4 satır | B4 düzeltilemez; `UND`'ye karşı her görevli kanat +0,25 verir |
| K9 | `ModeRules.on_division_destroyed(d, cause)` | `_retreat`, `_resolve_battle` | ~3 satır | Yok edilen tümenin ısırılanları Kaputlu havuzuna yazılamaz; `rules.gd` her gün tümen listesini karşılaştırır (yavaş ama çalışır) |
| K10 | Savaş kaydında `kind` alanı; `at_war(tag)` `"outbreak"` türünü saymaz | `diplomacy.gd` | ~3 satır | B2'nin yan etkileri kalır; manifestle yalnız garip savaş kapatılabilir |
| K11 | Şablon düzenleyicide taburun `max_per_template` alanı | `game/ui` şablon ekranı | ~5 satır | Destek bölükleri (alev, sıhhiye, köpek) yığılabilir; yapay zekâ yığmaz, oyuncu için ipucu uyarısı yazılır |

Mühimmat, ordu içi seyir, moral sayaçları ve kuşatma durumu **motor sınıflarına alan eklemeden** `rules.gd` durumunda
(`div_id → {...}`, `state_id → {...}`) tutulur ve `to_save()`'e yazılır. 04 aynı veri için `Division.infected` alanını önermişti.
Hangisi seçilirse seçilsin `test_save_load.gd` eksik alanı yakalar. Yok edilen tümenin kaydı K9 (ya da günlük karşılaştırma) ile silinir.

## 3. Tümen ve tabur sistemi nasıl uyarlanır?

### 3.1 Değişmeyenler
Şablon (tabur sözlüğü), tümen değerinin tabur toplamı olması, konuşlandırma (ekipman %50 + insan gücü), 14 günlük eğitim, günde
%8 takviye, tecrübe düzeyleri ve "son askere kadar" duruşu aynen kalır. Oyuncu savaş modunda öğrendiği şablon ekranını ve ordu
panelini kullanır (01 Sütun 1: öğrenme maliyeti düşük).

### 3.2 Yeni tabur anahtarları (`extra`, K1)

| Anahtar | Anlamı | Toplama | Kullanan kural |
|---|---|---|---|
| `sweep` | Tarama puanı: dağınık Boşları bulma gücü | adet toplamı | κ_asker (§4.4) |
| `bite_mult` | Isırık payı çarpanı | genişlik ağırlıklı ortalama | §8.2 |
| `terrain_attack_<arazi>` | Arazi başına saldırı eki (`terrain_attack_urban: 0.15`) | en büyük değer | K2 |
| `screen` | Tümen içi tarama düzeyi (1 = sıhhiye bölüğü var) | en büyük değer | §8.3 |
| `reveal` | Gizli sürüleri gösterme yarıçapı (bölge) | en büyük değer | 04 T03, T07, T08 |
| `night_guard` | Gece çarpanlarını yarıya indirme | en büyük değer | 04 T07 |
| `checkpoint` | Tutulan sınır bölgesini tarama noktası yapar | en büyük değer | 03 §8.3 |
| `leader_damage` | Kösemen'e isabet eki | adet toplamı | 04 T04, 06 `zm_leader_damage` |
| `entrench_rate`, `entrench_max` | Siperin dolma hızı, tavan eki | en büyük değer | `entrenchment` |
| `ammo_load_<ekipman>` | Bir mühimmat yükünün o ekipmandan karşılığı (birim) | adet toplamı | §7 |
| `fuel_use` | Saatlik yakıt (bugün kodda yalnız zırhlı ve motorlu için sabit) | adet toplamı | `_fuel` |
| `noise` | Top sesi çekimini başlatır | var/yok | 04 `noise_pull` |

### 3.3 Katalog

Karşılaştırma: piyade taburu 30 / 5 / 110 / 15 / 50 / 100 / 4 / 4 / 0, 1.000 kişi; topçu taburu 125 / 10 / 50 / 30 / 1,2 / 0 / 6.

| Kimlik | EN / TR | PA | TA | Sav | Şok | Can | Büt | Gen | Hız | Sert | Kişi | Ekipman | `extra` | Açan |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `zm_flame` | Flame and Disinfection Company / Alev ve Dezenfeksiyon Bölüğü | 20 | 2 | 20 | 10 | 1,2 | 0 | 1 | 4 | 0 | 250 | piyade teçhizatı 20, `zm_flame_equipment` 12 | kent +0,15, orman +0,10; `bite_mult` 0,8; `sweep` 0,3; `fuel_use` 0,03 | 06 `zm_urban_clearance` |
| `zm_gendarmerie` | Quarantine Gendarmerie Battalion / Karantina Jandarması Taburu | 12 | 1 | 45 | 6 | 30 | 60 | 2 | 4 | 0 | 600 | piyade teçhizatı 40 | `sweep` 1,5; `checkpoint` 1; `bite_mult` 1,1 | başlangıçta |
| `zm_engineer` | Engineer and Barricade Battalion / İstihkâm ve Barikat Taburu | 20 | 4 | 120 | 12 | 50 | 90 | 4 | 4 | 0 | 900 | piyade teçhizatı 60, destek ekipmanı 10 | `entrench_rate` 2; `entrench_max` +0,10; `sweep` 0,8 | başlangıçta |
| `zm_medical` | Sanitary and Decontamination Company / Sıhhiye ve Dekontaminasyon Bölüğü | 2 | 0 | 10 | 2 | 1,2 | 0 | 1 | 4 | 0 | 300 | destek ekipmanı 6 | `screen` 1; `sweep` 0,2 | başlangıçta |
| `zm_marksman` | Marksman Company / Nişancı Bölüğü | 8 | 1 | 30 | 4 | 12 | 90 | 1 | 4 | 0 | 200 | piyade teçhizatı 25 | `leader_damage` 0,25; `bite_mult` 0,9; `sweep` 0,4 | 06 `zm_marksman_teams` |
| `zm_carrier` | Armoured Carrier Battalion / Zırhlı Taşıyıcı Taburu | 30 | 6 | 90 | 40 | 35 | 70 | 4 | 9 | 0,6 | 800 | piyade teçhizatı 80, `zm_carrier_equipment` 40 | `bite_mult` 0,5; `fuel_use` 0,10; `sweep` 1,0 | `motorization` (temel) |
| `zm_dogs` | Tracker and Sentry Dog Company / Köpekli İz ve Nöbet Bölüğü | 3 | 0 | 15 | 3 | 1,2 | 0 | 1 | 4 | 0 | 150 | piyade teçhizatı 10, `zm_working_dogs` 10 | `reveal` 1; `night_guard` 1; `checkpoint` 1; `sweep` 1,0 | başlangıçta |
| `zm_mounted` | Mounted Patrol Battalion / Atlı Devriye Taburu | 18 | 2 | 60 | 12 | 40 | 80 | 4 | 6 | 0 | 700 | piyade teçhizatı 70 | `sweep` 2,0; `reveal` 1 | başlangıçta |

Destek bölüklerinde (bütünlüğü 0 olanlar: alev, sıhhiye, köpek) `max_per_template: 1` (K11). Topçu gibi bütünlük ortalamasına girmezler.
Mevcut taburların tarama puanı: piyade ve motorlu 1,0, topçu 0, hafif ve orta tank 0,2.

### 3.4 Değerlerin türetilmesi

Ortak kural: **kişi başına ateş** piyade taburundan alınır: 30 PA / 1.000 kişi = 0,03. Bir tabur bu oranla ve donanımının farkıyla
ölçeklenir. Savunma aynı yolla 110 / 1.000 kişi = 0,11 alınır. Can, 50 / 1.000 kişi oranıyla, kayıplara açıklığa göre ayarlanır.

**Alev ve Dezenfeksiyon Bölüğü.** Dönemin taşınabilir alev silahları 30–40 kg ağırlığında, kısa menzilli (birkaç on metre) ve birkaç
saniyelik yakıt taşıyan araçlardı. İlk kez Birinci Dünya Savaşı'nda istihkâm birliklerinin elinde kullanıldılar. Bölük 12 alev takımı
ve 190 kişilik bir koruma kolundan oluşur. Koruma kolu 190 × 0,03 = 5,7 PA verir. Alev takımının etkisi yalnız temas mesafesindedir.
Varsayım (bizim): bir fışkırma temas yoğunluğundaki (~0,5 kişi/m²) kalabalıkta ~75 m²'lik bir alanı etkiler ve saatte bir kez
kullanılabilir. Bu, temas hâlindeki bir tüfekçinin saatteki ~1 etkili isabetine göre ~35 kat eder. Ancak menzil ve yakıt kısıtı yüzünden
bu etkinin ~1/3'ü kullanılır: takım başına ~1,2 PA → 12 × 1,2 = 14,4. Toplam ≈ 20. Kent ve ormanda +0,15 / +0,10 saldırı ekini
şundan alır: siper ve bina içinde saklanan Durgun ve Dehlizci türlerine (04 T03, T08) ateşli silah ulaşmaz, alev ulaşır. Isırık çarpanı
0,8'dir, çünkü alev takımı kalabalığı birkaç on metrede tutar. Bedeli yakıttır (`fuel_use` 0,03 → muharebede günde 0,72 yakıt) ve
kentte yangın riskidir (§13 olay O4). **Görsel:** yalnız duman ve yanan yapı; yanan figür yoktur (01 §6.2).

**Karantina Jandarması Taburu.** 600 kişi; tabanca ve karabina taşır, kişi başına ateşi piyadenin 2/3'üdür → 600 × 0,03 × 0,67 = 12 PA.
Savunma 600 × 0,11 × 0,7 = 46 → 45 (siper ve ağır silah eğitimi azdır). Bütünlük 60: muharebe birliği değildir. İşi şudur:
- **Tarama:** Ev ev arama, nüfus kütüğü ve yerel bilgi kişi başına etkinliği 2,5 katına çıkarır → 0,6 × 2,5 = **1,5 tarama puanı**. 1911
  Mançurya vebasında şehir mahallelere bölünmüş, ev ev arama polis ve askerle yapılmıştı (01, 02 kaynakları).
- **Kontrol noktası:** Tuttuğu sınır bölgesi, 03 §8.3'teki tarama noktası olur (T düzeyi ülkenin teknolojisinden). Kapasite bağlayıcı
  değildir. Medyan eyaletin nüfusu 446.190'dır ve günlük %0,3 dışarı akışla sekiz bağlantıya ~1.340 yolcu düşer. Buna karşılık Ellis
  Adası tek bir istasyonla, kişi başına birkaç saniyelik "hat muayenesiyle" günde binlerce kişiyi süzebiliyordu (Kaynaklar). Sınırı
  koyan kapasite değil **duyarlılıktır**: T0 düzeyinde yalnız ateşliler (%60) yakalanır.
- **Isırık çarpanı 1,1:** kapıda yakın temas, koruyucu donanım azdır.

**İstihkâm ve Barikat Taburu.** 900 kişi (bir bölümü kazı ve tel işinde) → PA 20. Savunma 110 × 0,9 × 1,2 = 119 → 120 (hazırlanmış mevzi
ustalığı). İşi siperi **iki kat hızlı** doldurmak (5 gün) ve tavanını +0,10 artırmaktır. B5'teki bulgu yüzünden bu ek sürüye karşı
değil, bölgeyi **ülke ordularına karşı** da tutan genel bir yarardır. Sürüye karşı asıl katkısı Kordon Hattı inşasını hızlandırmaktır:
eyalette bulunan her istihkâm taburu `zm_cordon_line` inşasına +%25 hız verir (en çok +%50). 06'nın `zmo_blow_bridges` ve `zmo_tunnel_sweep`
emirleri için öneri: emir yalnız en az bir istihkâm taburunun bulunduğu kordon eyaletlerinde işlesin (06 kabul etmezse ülke geneli kalır).

**Sıhhiye ve Dekontaminasyon Bölüğü.** 300 kişi, silahı azdır (PA 2). İşi ordu içi taramadır (§8.3). Tümendeki ateşlileri günde 0,6
olasılıkla (T0), 0,85 (T1), kuluçka testiyle kuluçkadakileri de 0,5 olasılıkla (T2) bulur ve sahra karantina çadırına ayırır. Sayılar
03 §8.3'ün tarama düzeyleridir. Dayanak: 1914'ten itibaren İngiliz ordusu cephe gerisinde seyyar bakteriyoloji laboratuvarları
kurdu (06 kaynakları: Rowland, 1 No'lu Seyyar Laboratuvar). **Amblem yoktur:** ikon ve modelde kızılhaç/kızılay kullanılmaz (06: Cenevre
Sözleşmesi I, madde 44).

**Nişancı Bölüğü.** 200 kişi, dürbünlü tüfek; kişi başına ateşi piyadenin 1,3 katıdır → 200 × 0,03 × 1,3 = 7,8 → 8 PA. İşi Kösemen'i
bulup vurmaktır: `leader_damage` +0,25 (06'nın `zm_marksman_teams` teknolojisi +0,50 ekler). Motor taklidinde (Ek A, B5) bölük tek
başına 1 Kösemen + 2 Kaputlu saldırısını değiştirmez. Bölük + teknoloji Kösemen'i dağıtır ama tümeni kurtarmaz; bölük + teknoloji +
"Önder Avı" emri (06, +1,0) tümeni kurtarır. Önder avı, ayrı yatırım isteyen bir kurgudur ve 06 D4 seçimiyle uyumludur.

**Zırhlı Taşıyıcı Taburu.** 1930'larda hafif, açık üstlü, paletli taşıyıcılar (İngiliz taşıyıcı ailesi 1934'ten, Fransız hafif paletli
çekiciler 1932'den) piyadeyi ve makineli tüfeği zırh arkasında taşıyordu. 800 kişi → PA 30 (piyade gibi; makineli tüfek araçta).
Savunma 90: araçtan savaşan piyade siper kazmaz. Şok 40: araç kütlesi kalabalığı iter (hafif tank 110, piyade 15). Sertlik 0,6
(hafif tank 0,8; açık üst yüzünden daha düşük). Can 35: araç korur ama inen asker açıktadır. Isırık çarpanı 0,5: çarpışmanın yaklaşık
yarısı araçtan yürür. `zm_carrier_equipment` birimi bir taşıyıcıdır. Tabur 40 taşıyıcı ister (motorlu taburun 35 kamyonuna denk
soyutlama; bir bölük araçta, kalanı kamyonla). Maliyeti §3.5'te.

**Köpekli İz ve Nöbet Bölüğü.** 150 bakıcı ve ~100 köpek. 1930'ların ordularında nöbetçi ve haberci köpekleri yaygındı; köpeklerin
bazı enfeksiyonları kokudan ayırt edebildiği de modern çalışmalarla gösterildi (Kaynaklar: Jendrny ve ark. 2020). Kurgusal kural:
- `reveal` 1: Durgun, Dehlizci ve gece Gecegezer sayaçları bulunduğu ve komşu bölgelerde görünür (04'ün gizlilik kuralına ek).
- `night_guard`: Gecegezer'in gece çarpanlarını yarıya indirir (erken uyarı). 06'nın `zm_illumination` ekipmanı ise tamamen kaldırır.
  Motor taklidi: 3 Gecegezer → topçulu kordon tümeni, köpeksiz bütünlük %30, köpekli %41 (Ek A, B6).
- `checkpoint`: köpek taraması, T0'a ek olarak kuluçkadakileri **0,25**, ateşlileri **0,75** olasılıkla yakalar (kurgusal; T2 kan
  testinin 0,5'inden bilinçli olarak düşük tutuldu).
- `sweep` 1,0: 150 kişi, köpekle bin kişilik bir tabur kadar arama yapar.
Hayvanlar hastalanmaz (01 açık soru 6). Köpek kaybı ayrıca gösterilmez; ekipman kaybı olarak takviyeyle yenilenir.

**Atlı Devriye Taburu.** 700 kişi; atlıların dörtte biri at tutar → 525 × 0,03 = 15,8 → 18 PA (makineli tüfek dâhil). Savunma
525 × 0,11 = 58 → 60. Hız 6: at, yürüyen piyadenin ~1,5 katı (motor birimi km/sa). Tarama 2,0: günde 2–3 kat alan kolaçan eder.
Habsburg askerî sınırında kordonu atlı ve yaya nöbetçiler zinciri tuttu (06 kaynakları). Motor taklidi: iki Seğirtken sürüsüne karşı
**hat tutmaz** (70 saatte çekilir). Bu kasıtlıdır: devriye taburu tarama ve keşif içindir, sürü dalgasına karşı değil.

### 3.5 Yeni ekipman (`equipment.patch.json`)

Ölçek: `cost` birim başına fabrika-saattir (tüfek takımı 2,7; kamyon 13; destek ekipmanı 21; hafif tank 43).

| Kimlik | EN / TR | Cost | Kaynak | Açan | Gerekçe |
|---|---|---|---|---|---|
| `zm_flame_equipment` | Flamethrower Set / Alev Silahı Takımı | 6 | çelik 1 | `zm_urban_clearance` | Basınçlı depo, vana ve tabanca: iki tüfek takımından (5,4) biraz pahalı, destek ekipmanından (21) çok ucuz |
| `zm_carrier_equipment` | Light Armoured Carrier / Hafif Zırhlı Taşıyıcı | 25 | çelik 2 | `motorization` | Kamyon (13) motoru + palet + 7–10 mm zırh; taretsiz ve topsuz olduğundan hafif tankın (43) %58'i |
| `zm_working_dogs` | Trained Dogs (10) / Eğitimli Köpek (10) | 4 | — | — | Birim = 10 köpek. Yetiştirme ve birkaç aylık eğitim, üretim hattı olarak soyutlanır; kaynak istemez |

Tabur maliyetleri (ekipman × cost): alev bölüğü 20 × 2,7 + 12 × 6 = 126; jandarma 108; istihkâm 162 + 210 = 372; sıhhiye 126;
nişancı 68; taşıyıcı 216 + 1.000 = 1.216 (motorlu tabur 725, hafif tank taburu 2.580); köpek 27 + 40 = 67; atlı 189 fabrika-saat.

### 3.6 Şablonlar ve ölçülen değerler

Değerler `Military.stats` formülüyle hesaplandı (Ek A). Tarama = tabur tarama puanları toplamı. Mühimmat yükü §7'dedir.

| Şablon (EN / TR) | Taburlar | PA | Sav | Şok | Can | Büt | Gen | Sert | Kişi | Tarama | Isırık çarpanı |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Infantry Division / Piyade Tümeni (temel) | 7 piyade, 2 topçu | 460 | 870 | 165 | 352 | 100 | 40 | 0 | 8.000 | 7,0 | 1,00 |
| Cordon Division / Kordon Tümeni | 6 piyade, 2 topçu, 1 istihkâm, 1 sıhhiye | 452 | 890 | 164 | 354 | 98,6 | 41 | 0 | 8.200 | 7,0 | 1,00 |
| Clearance Division / Arındırma Tümeni | 5 piyade, 2 taşıyıcı, 1 alev, 1 topçu, 1 sıhhiye, 1 nişancı | 365 | 840 | 201 | 336 | 91,2 | 37 | 0,11 | 7.850 | 7,9 | 0,88 |
| City Garrison / Kent Garnizonu | 4 jandarma, 2 piyade, 1 sıhhiye, 1 köpek, 1 alev | 133 | 445 | 69 | 224 | 73,3 | 19 | 0 | 5.100 | 9,5 | 1,03 |
| Flying Column / Seyyar Kol | 3 atlı, 2 motorlu, 1 köpek | 117 | 415 | 69 | 221 | 88,0 | 21 | 0,03 | 4.650 | 9,0 | 1,00 |
| Silent Cordon / Sessiz Kordon | 7 piyade, 1 istihkâm, 1 sıhhiye, 1 köpek | 235 | 915 | 122 | 402 | 98,8 | 34 | 0 | 8.350 | 9,0 | 1,00 |

Ölçülen davranış (ova, siperli savunma, hava yok, Olağan sürü; Ek A):

| Durum | Sonuç |
|---|---|
| Kordon Tümeni ← 3 sürü | 59 saatte hepsi dağılır; tümen bütünlüğü %27, güç kaybı %12,2 (piyade tümeniyle aynı sınıf) |
| Kordon Tümeni ← 4 sürü | 51 saatte çekilir (piyade 52). **Kordon Tümeni daha güçlü değildir, daha sağlıklıdır:** farkı ordu içi bulaşta ve inşaattadır (§8, §5) |
| Sessiz Kordon ← 2 / 3 sürü | 2 sürü 104 saatte dağılır (bütünlük %14); 3 sürüde 68 saatte çekilir. Top sesi çekmez (04) ama zayıftır |
| Arındırma Tümeni → 2 sürü, kent (hazırlık tam) | 77 sa, bütünlük %32 (piyade tümeni 56 saatte durdu); `zm_urban_clearance` ile 53 sa, bütünlük %55, güç kaybı %7,4 |
| Kent Garnizonu ← 2 sürü, kent | 75 saatte çekilir. Hat tutmaz, **tarar**: İstanbul'da κ_asker'i piyade tümeninin 1,36 katıdır (§4.4) |
| Seyyar Kol ← 2 Seğirtken | 70 saatte çekilir (piyade tümeni 27 saatte dağıtır). Keşif ve tarama birliğidir |

**Tasarım sonucu:** Kordonu **piyade + topçu** tutar, yeni birlikler ise hattın *nasıl* tutulduğunu değiştirir: ordu içi bulaş (sıhhiye),
kentte arındırma (alev, taşıyıcı), gizli sürüler (köpek), önder (nişancı), hattın arkası (jandarma, atlı). Bu, 03 §10'daki iş bölümüyle
("hattı tutmak" ve "hattın arkasını temiz tutmak") örtüşür.

### 3.7 Dışarıda bırakılanlar

| Öneri | Karar | Neden |
|---|---|---|
| Zehirli gaz | **Yok** | 1925 Cenevre Protokolü dönemin normudur; gaz ayrım yapmaz, sivili de öldürür (01 §6.2); tonla bağdaşmaz |
| Elektrikli tel | **Yok** | 1915'te Belçika–Hollanda sınırına çekilen öldürücü elektrikli tel, geçmeye çalışan çok sayıda sivilin ölümüne yol açtı (Kaynaklar; sayı §19'da doğrulanacak). Engel siville Boş'u ayırmaz |
| Mayın tarlası (bina olarak) | **Yok**; yalnız olay seçeneği (§13 O6) | Hesap: 1 mayın en çok 1 Boş'u durdurur. 280 km'lik bir hatta metreye 3 mayın 840.000 mayın eder. Bir sürü ~400 m'lik bir şeritten geçerken en çok ~1.200 mayını (~%12) tetikler, sonra şerit açıktır. Pahalı, tek kullanımlık, geri dönen sivil için kalıcı tehlike |
| Zırhlı tren | Sürüm 2 | Haritada demiryolu ağı verisi yok; demiryolu 03'te yalnız yolcu akışının ağırlığıdır |
| Uçaktan tahliye | Yok | Hesap §10.4: dönemin nakliye uçağı 17 yolcu taşır; bir şehri boşaltmak yüzlerce gün sürer |
| "Sürü bombardımanı" görevi | Sürüm 2 (açık soru) | Etki tahmininin belirsizliği ±10 kat (§10.6) |
| Sivil milis taburu | Yok (06 E dalı) | Yerel muhafız 06'da doktrin olarak sivil bastırmaya (κ_sivil) yazılır; ayrıca tabur, silah dağıtımının bedelini ikinci kez sayardı |

## 4. Kordon: cephe sistemi sürülere karşı

### 4.1 Kordon ordusu
Mevcut ordu → cephe sistemi aynen kullanılır, yalnız hedef değişir:
- Ordu panelinde hedef listesine **"Salgın cephesi / Outbreak front"** (`UND`) eklenir.
- Ordu `cordon` listesi taşır: oyuncunun haritadan seçtiği **kordon eyaletleri** (kendi ya da yabancı; genellikle bildirilmiş ya da
  salgın durumundaki eyaletler).
- **Cephe (K4):**
  ```
  F(a) = { p : p kara, p'nin kontrolü sahip ya da müttefik, p ∉ cordon, ∃ komşu q ∈ cordon }     (dış halka)
       ∪ { p : p kara, p'nin kontrolü sahip ya da müttefik, ∃ komşu q, controller(q) = UND }     (düşmüş hat)
  ```
  `cordon` boşsa yalnız ikinci küme kullanılır. İsteğe bağlı "iç halka" kutusu, kordon eyaletinin kendi sınır bölgelerini de ekler
  (tümen enfekte bölgenin içinde durur; κ_asker yazar ama ısırık riski taşır).
- Tümenlerin cepheye dağılması mevcut `_army_spread` ile olur: tehdit = 1 + komşu hedef bölgelerdeki sürü sayısı. **Gizli sürüler**
  (04: Durgun, Dehlizci, gece Gecegezer) oyuncu ordusunun tehdit hesabına girmez (bilgi sisi, 01 Sütun 2). Yapay zekâ için de aynı süzgeç
  uygulanır (hile yok).
- 02'deki "Kordonu otomatik genişlet" kolaylığı **kapalı başlar**. Açıksa yalnız *bildirilen* yeni enfekte komşu eyaletleri `cordon`'a
  ekler, tümen konuşlandırmaz.

### 4.2 Bir kordon kaç tümen ister? (harita ölçümü)

`data/map/provinces.json` ve `states.json`'dan ölçüldü:

| Ölçü | Değer |
|---|---|
| Kara bölgesinin alanı (medyan / ortalama) | 9.427 / 13.619 km² → medyan bölge ~97 km genişliğinde |
| Bölgenin kara komşusu (medyan) | 5 |
| Eyalet başına kara bölgesi (medyan; %25–%75–%90) | 5 (3 – 8 – 12) |
| Eyaletin **iç sınır** bölgesi (başka eyalete değen kendi bölgesi; medyan / ort.) | 4 / 4,8 |
| Eyaletin **dış halkası** (eyalete değen dış bölgeler; medyan; %25–%75–%90) | 10 (6 – 13 – 16) |
| Aynı anda bir bölgeye saldırabilecek sürü (cephe genişliği / 40) | ova 6,0; kent 6,4; orman 5,6; tepe 5,4; bataklık 5,2; dağ 5,0 |

Buradan kurallar:
- **Tam kuşatma** (dış halkanın her bölgesinde en az 1 tümen): medyan eyalette **10 tümen**. **Yarım kuşatma** (yalnız sağlam nüfusa
  bakan yüz) ~5 tümen. Deniz, dağ ve nehir (sürü yürüyüşü ×0,5, saldırı −0,6; 03 §5.6, 04 §2.4) halkanın bir bölümünü bedavaya kapatır.
- **Dalga eşiği:** bir tümen 3 Olağan sürüyü dağıtır, 4'ünde çekilir. Aynı bölgedeki iki tümen 7 sürüyü dağıtır, 8'inde çekilir
  (Ek A, B9). Bir bölgeye aynı anda en çok ~6 sürü saldırabildiği için **tehdit altındaki bölgede 2 tümen** hattı genelde tutar.
- **Tepki süresi:** Olağan Boş günde ~14 km yürür, medyan bir bölgeyi ~7 günde geçer. Seğirtken ~2,7 günde geçer. Tümen yolda saatte
  4 km gider, bir bölgeyi ~1 günde geçer. Buradan **her 3 cephe bölgesine 1 yedek tümen**, cephenin 1–2 bölge gerisinde durur.
  Yarılmadan sonra yedek, sürü ikinci bölgeye varmadan yetişir.

**Türkiye örneği:** 102 kara bölgesi, 41 eyalet. Kara sınırında 19 kendi bölgesi 21 yabancı bölgeye değer (Sovyetler 3, Irak 2,
Fransız mandası 8, İran 4, Bulgaristan 3, Yunanistan 3; bazı bölgeler iki ülkeye birden değer). 1936'da 20 tümen vardır. Bütün
komşular düşerse her sınır bölgesine bir tümen koymak orduyu tüketir, yedek kalmaz. Oyuncu ya **hattı kısaltır** (§4.3), ya **yeni tümen**
kurar (insan gücü ve fabrika), ya da **müttefik kordonu** kurar (06 F4 Ortak Kordon Paktı).

### 4.3 Örnek: Trakya'da hattı kısaltmak
Harita verisinde Trakya üç kademeli bir savunma sunar:

| Kademe | Bölgeler (kimlik) | Cephe | Doğal engel |
|---|---|---|---|
| Dış hat: Kırklareli eyaleti | 1042, 1043, 1044, 1045 (dördü de sınırda) | 4 bölge, 4–8 tümen | 1043 ve 1044 nehir kıyısında (sınır nehri): o yüzde sürü saldırısı −0,6, yürüyüş ×0,5 |
| Orta hat: İstanbul'un Avrupa yakası | 4299, 4302, 4300 (Kırklareli'ye değenler) | 3 bölge, 3–6 tümen | 4299 ayrıca Gelibolu tarafındaki bir bölgeye (11917) değer: ikinci bir yüz |
| Son hat: İstanbul Boğazı | 4300 ↔ 11871 (`land_crossing`) | Boğaz | Filo boğaz nöbeti tutarsa sürü geçemez (§11.1) |

Orta hat, 1912'de Balkan Savaşı'nda bir orduyu durduran Çatalca hattının yaklaşık yerindedir. Oyuncuya sorulan soru, 02 §3.4'teki
"Hat mı, Halk mı?" olayının haritadaki karşılığıdır: dış hat 540 bin kişilik Kırklareli'yi korur ama 4–8 tümen ister; orta hat 3–6 tümenle
tutulur ama Kırklareli'yi tahliyeye (06 C2, 03 §5.5) ya da kaderine bırakır.

### 4.4 Hattın arkası: tarama puanıyla κ_asker
03 §3.2: `κ_asker,s = 0,10 · Σ_tümen (güç × bütünlük oranı) · sqrt(56.500 / A_s)`, üst sınır 0,6. Bu belge "tümen" yerine **tarama
puanı / 7** kullanılmasını önerir. Standart piyade tümeni 7 puandır, yani 03'ün sayıları aynen korunur. Yalnız birliğin bileşimi önem
kazanır:

| Birlik | Tarama | κ_asker katkısı (medyan eyalet, tam güç) | İstanbul'da (A = 11.845 km², kök çarpanı 2,18) |
|---|---|---|---|
| Piyade Tümeni | 7,0 | 0,100 | 0,218 |
| Kent Garnizonu | 9,5 | 0,136 | 0,296 |
| Seyyar Kol | 9,0 | 0,129 | 0,281 |
| Garnizon Tümeni (5 piyade) | 5,0 | 0,071 | 0,156 |

03 §3.6'ya göre d = 3 olan büyük liman şehrinde salgını söndürmek için karantina + sıkıyönetimle 0,511 κ_asker gerekir: bunu **2 Kent
Garnizonu** (0,59) ya da **3 piyade tümeni** (0,65; tavan 0,6'ya takılır) sağlar. Yalnız karantinayla 1,108 gerekir; bu 0,6 tavanının üstündedir. O
durumda
salgını asker söndüremez, serum söndürür (03'ün sonucu aynen geçerli). Jandarmanın asıl değeri burada ortaya çıkar: **daha az insan gücüyle
aynı tarama.** Kent Garnizonu 5.100 kişidir, piyade tümeni 8.000.

### 4.5 Yarılma ve yedek
- **Yarılma:** Kordon cephesindeki bir bölge `UND` kontrolüne geçer ya da içinde tümen kalmaz. 02'deki "Kordon yarıldı" uyarısı gelir.
- Motorun tümeni cepheye dağıtması, açılan bölgeye en yakın boş tümeni gönderir. Ordunun *yedek* kipi yoktur; oyuncu yedeği ayrı bir
  orduda (cephesiz, `enemy = ""`) tutar ve elle gönderir. Bu, kural 1 gereği bilinçli bir sınırdır.
- **Derin savunma:** iki kordon ordusu, iç içe iki `cordon` listesiyle kurulabilir (dış halka ve bir kademe geride). 06'nın "Kordon
  dayanıklılığı" DP kaynağı (90 gün yarılmadan) ordu başına sayılır.

### 4.6 Arındırma harekâtı (taarruz)
Ordu **Taarruz** kipine alınır. Mevcut `_army_attack`, komşu hedef bölgedeki gücü `(PA + savunma/2) × güç` ile karşılaştırır ve oran
≥ 1 ise saldırır. Olağan sürünün bu değeri 120 + 75 = 195, piyade tümeninin 895'tir; yani oran bir tümene karşı 4,6'dır ve saldırı
kolayca başlar. Sonra:
1. Tümen `UND` kontrolündeki bölgeye girince bölge sahibine döner (mevcut `_enter`).
2. Eyaletin bütün bölgeleri alınınca ve `H < yaşayan/2` olunca eyalet DÜŞMÜŞ'ten İZLEMEDE'ye geçer (02 §2.5).
3. Kalan dağınık Boşları, muharebede olmayan tümenlerin κ_asker'i ve Boş ömrü (μ) eritir. Medyan eyalette 3 tümen: κ_asker 0,3 + μ
   0,017 → dağınık H her gün ~%32 azalır (yeni dönüşenler hariç). 200.000 Boş ~35 günde 1'in altına iner. Bu, 42 günlük "temiz ilan" süresiyle aynı mertebededir.
4. Gizli Durgun yuvaları temiz ilan sayacını sıfırlar (04 T03). Köpek bölüğü ya da hava keşfi (06 `zm_aerial_survey`) olmadan temiz ilan
   uzar.

Arazi: kentte saldıran −0,3 alır (04 §2.4; B1 düzeltmesiyle kent bölgeleri artık vardır). Alev bölüğü +0,15, `zm_urban_clearance` +0,10,
06'nın `zmd_sweep_doctrine`'i +0,10 ekler; üçü birlikte kent cezasını kaldırır ama yakıt ve yangın riski getirir.

### 4.7 Kordon kesiminin durum makinesi
Her kordon ordusunun her cephe bölgesi için hesaplanır (günlük, ekranda):

```
            komşu kordon eyaletinde               komşuda sürü birimi ya da          bölge UND'ye geçti
            bildirilen vaka > 0                    son 24 saatte muharebe             ya da tümensiz kaldı
 SESSİZ ──────────────────────────▶ TEMASLI ─────────────────────────────▶ BASKI ─────────────────────▶ YARILDI
   ▲                                   ▲                                    │                           │
   │ 42 gün komşuda yeni vaka yok       │ 7 gün muharebe yok                  │ sürüler dağıldı           │ bölge geri alındı
   └───────────────────────────────────┴────────────────────────────────────┘ ◀─────────────────────────┘
                                                                            (GERİ ALINDI → BASKI)
```

| Durum (EN / TR) | Gösterim | Etki |
|---|---|---|
| Quiet / Sessiz | Salgın paneli, Kordon sekmesi, gri satır | — |
| Contact / Temaslı | Sarı | Kesimde dağınık sızıntı ölçülür ("sızan Boş/gün" sütunu) |
| Under pressure / Baskı altında | Turuncu | Uyarı şeridinde sayılır, mühimmat tüketimi görünür |
| Breached / Yarıldı | Kırmızı, 02 uyarısı "Cordon breached" | Kesimin `g` payı 0 olur; 06 DP sayacı sıfırlanır |

## 5. Tahkimat ve karantina hattı

### 5.1 Neden engel, neden siper değil?
B5'teki ölçüm: sürü saldırısı tümenin savunmasını aşmadıkça savunma değeri önemsizdir. Tarihte de dikenli telin işi, saldırganı
**ateş altında tutmak** ve hızını kesmekti; tel ateşle korunmadıkça kesilir ya da aşılırdı. Bu yüzden engel iki sayı olarak yazılır:
- **Sürü saldırı çarpanı eki** (K2): sürü telde oyalanır, temas eden sıra seyrelir.
- **Sürü şok değeri çarpanı** (K2 üzerinden `defend_mod` yerine sürünün şok değerine): telde duran kalabalık sabit hedeftir, savunanın
  ateşi daha çok "açık" isabet verir.
Motor taklidiyle ölçülen etki (piyade tümeni, ova, siperli):

| Kordon Hattı | 3 sürü | 4 sürü | 5 sürü |
|---|---|---|---|
| Yok | 57 sa dağıldı, bütünlük %30, güç kaybı %11,9 | 52 sa çekildi | 41 sa çekildi |
| 1 (−0,10 / −%10) | 51 sa, %44, %9,6 | 59 sa çekildi (sürüler %8,7 eridi) | 46 sa çekildi |
| 2 (−0,20 / −%20) | 46 sa, %55, %7,7 | 67 sa çekildi (%11,8 eridi) | 52 sa çekildi |
| 3 (−0,30 / −%30) | 42 sa, %64, %6,1 | **73 sa dağıldı**, %17 | 60 sa çekildi |
| 3, **iki tümen** | — | — | 8 sürü 58 sa, 10 sürü 74 sa, 12 sürü 90 sa: hepsi dağıldı |

Değerlerin gerekçesi: motorda nehir, saldırana −0,6 veren tam bir doğal engeldir (04 §2.4 ve temel oyun). Üç seviyelik hat bunun
yarısına (−0,3) ulaşır: tel, hendek ve ikinci hat bir nehrin yerini tutamaz. Şok çarpanı aynı adımla ilerler.

### 5.2 Kordon Hattı binası (`zm_cordon_line`)

| Seviye | EN / TR | İçerik | Sürü saldırısı | Sürü şoku | Dağınık yürüyüşü durdurma (tutulan / tutulmayan bölgede) |
|---|---|---|---|---|---|
| 1 | Wire and Posts / Tel ve Karakol | Çift sıra dikenli tel, her 2 km'de bir karakol, temizlenmiş atış alanı | −0,10 | −%10 | %92,5 / %15 |
| 2 | Ditch and Bank / Hendek ve Set | Tel önünde ~2 m derin, ~3 m geniş hendek; toprak set | −0,20 | −%20 | %95 / %30 |
| 3 | Second Line and Gates / İkinci Hat ve Kapılar | İkinci tel kuşağı, kontrol kapıları, küçük blokhauslar | −0,30 | −%30 | %97,5 / %45 |

- **Nerede işler:** Eyaletin bölgelerinde, saldıran `UND` iken ve bölgede kendi ya da müttefik tümeni varken (engel ateşle korunmalı).
  Dağınık yürüyüşte 03 §5.6'daki `g_ij` şöyle genişler: `durdurma = tutulan_pay · (0,9 + 0,025·L) + tutulmayan_pay · 0,15·L`. Kalan
  kaçağa 06'nın `zm_leak_mult`'ı çarpan olarak uygulanır.
- **Maliyet:** seviye başına **300 fabrika-gün**, en çok 3 seviye, eyalet slotu kullanmaz (altyapı gibi), yalnız kendi eyaletinde ve
  eyalet DÜŞMÜŞ değilken. Türetme 05 §4.1'in yöntemiyle, işin türüne göre çıpalara oranlandı. Hava üssü (300) tesviye, hangar ve
  depo işidir. Bir seviyelik kordon (~280 km tel ya da hendek, ~140 karakol) malzemesi hafif ama uzun bir iştir; hava üssüyle aynı
  mertebeye konuldu. Üç seviye toplam 900 fabrika-gündür, bir altyapı seviyesinden (1.100) ucuzdur: kordon kurmak yol yapmaktan kolaydır
  ama her eyalete ayrı kurulur. 12 fabrikalı şantiyede seviye başına 25 gün, üç seviye 75 gündür. Yani hat, Evre 2'nin (60–200. gün)
  işidir. İstihkâm taburları +%25'er hız verir (§3.4).
- **280 km nereden?** Medyan eyalet alanı 56.500 km². Eşdeğer dairenin çevresi `2·sqrt(π·A)` ≈ 843 km'dir; kordon genellikle enfeksiyona
  bakan yüzün yalnız üçte birini kapatır → ~280 km. Bu, 02 §2.4'teki "eyalet ~280 km genişliğinde" varsayımıyla örtüşür. Büyük
  eyaletler için sabit maliyet ucuz kalır; eyalete özgü maliyet çarpanı bir motor kancası ister (§19).
- **Karakol aralığı neden 2 km?** Roma'nın Hadrianus Suru'nda gözetleme kuleleri birbirini görecek sıklıkta, yarım kilometre kadar
  aralıklarla dizilmişti. Habsburg veba kordonunun ahşap gözetleme kuleleri de birbirini görecek biçimde kuruluyordu (06 kaynakları).
  1936'da tarla telefonu ve ışıldak görüş mesafesini artırır. 2 km bu yüzden seçildi.

### 5.3 Engel kataloğu

| Engel | Nasıl gelir | Etki | Bedel | Dayanak |
|---|---|---|---|---|
| Dikenli tel | Kordon Hattı 1; 06 `zm_wire_obstacles` (öneri: `zm_obstacle +0,05`, §2.2 B5) | Yukarıdaki tablo | İnşaat | Birinci Dünya Savaşı tel kuşakları: engel ateşle korunur |
| Hendek ve set | Kordon Hattı 2 | Yukarıdaki tablo | İnşaat | Kuduzda su korkusu gibi, Boş düşünce kolay çıkamaz (kurgu) |
| Köprüleri yıkmak | 06 emri `zmo_blow_bridges` | Nehirli sınırda yürüyüş ×0,15 (03 §5.6) | İkmal ve ticaret; piyade hızı −%10 | Rakun kuduzu çalışmasında büyük nehirler yayılımı ~7 kat yavaşlatmıştı (03) |
| **Su basma** | Karar (yeni): kıyı ya da nehir kıyısında, bataklık veya ova olan bölgede | O bölgeye sürü saldırısı −0,6 (nehirle aynı), dağınık yürüyüş ×0,15. **Sazlıkçı (04 T09) etkilenmez** | Bölgenin eyaletinde fabrika çıktısı −%10 ve istikrar −%1; kurutmak 180 gün sürer; 04'ün "Suya dayanım" özelliğini besler (04 §7.2) | 1914'te Yser'de Belçika ordusu set kapaklarını açıp ovayı su altında bırakarak cepheyi savaş boyunca tuttu |
| Tünel kapatma | 06 emri `zmo_tunnel_sweep` | Dehlizci yeraltı geçişi kapanır (04 T08) | Altyapı −1 | 04 |
| Mayın | Olay O6 (§13) | O sınırda yürüyüş ×0,5, saldırı −0,10 | Mülteci o sınırdan geçemez; yeniden yerleşim yavaşlar; temizlik 120 gün | §3.7 hesabı |
| Elektrikli tel, gaz | Yok | — | — | §3.7 |

### 5.4 Kontrol noktası: kapıda ne olur?
Kordonun "kapısı" 03 §8.3'teki tarama noktasıdır. Bu belge yalnız **kimin** tarayabileceğini söyler:
- Tutulan bir kordon bölgesinde jandarma ya da köpek bölüğü (`checkpoint`) varsa o sınırdan geçen yolcu akışı, ülkenin T düzeyiyle
  taranır. Köpek, T0'a kuluçka 0,25 / ateşli 0,75 ekler (§3.4); iki tarama bağımsız uygulanır.
- Kapıda bekletme (`k` gün) 03'ün formülüdür: `geçen_E = E·(1 − s_E)·(1 − σ)^k`. Oyuncu kordon ordusunun ayarında 0 / 5 / 14 gün seçer.
  Bekletilen kalabalık sınır havuzunda birikir (03 §5.5) ve §13 O1 olayını tetikler.
- **Sayısal örnek:** büyüyen salgında taşıyıcı yolcunun ~%46'sı kuluçkada, ~%54'ü ateşlidir (ateşliler yarı oranda yolculuk eder,
  süreleri 3 ve 7 gün). T0 jandarma kapısı taşıyıcıların 0,6 × 0,54 = %32'sini yakalar. T0 + köpek:
  `1 − (1 − 0,25)·0,46 − (1 − 0,6)(1 − 0,75)·0,54` = **%60**. T2 + köpek + 5 gün bekletme ise ~%97.

### 5.5 Tahkimatın bedelleri (01 Sütun 3)

| Önlem | Görünür bedel |
|---|---|
| Kordon Hattı | 300 fabrika-gün/seviye; yalnız asker varken işler |
| Kapıda bekletme | Sınır havuzu büyür, O1 olayı; istikrar |
| Köprü yıkma, su basma | İkmal, ticaret, fabrika çıktısı; Sazlıkçı ve "Suya dayanım" riski (04) |
| Jandarma kapıları | İnsan gücü (600/tabur); uzun süreli iç kordonda istikrar −%0,5/ay (1830–31 kolera ayaklanmaları, 01 Sütun 3); 06 A4 "Rızaya Dayalı Karantina" bu bedeli kaldırır |

## 6. Şehir savunması ve kuşatma

### 6.1 Kent bölgesi (B1 düzeltmesi)
Mod kuralı (K5): içindeki şehirlerin toplam nüfusu **≥ 250.000** olan bölge muharebede `urban` sayılır. Eşik ölçümü:

| Eşik | Bölge | Nüfus |
|---|---|---|
| ≥ 100.000 | 892 | 395 milyon |
| **≥ 250.000** | **391** | **318 milyon** |
| ≥ 500.000 | 182 | 242 milyon |
| ≥ 1.000.000 | 77 | 170 milyon |

250.000 seçildi, çünkü dünyanın kentli nüfusunun (cities.json'da 433 milyon) %73'ünü kapsar ve seyrek eyaletlerdeki orta kasabaları
kent savaşından ayırır. Kent bölgesinde: savunan genişliği 192 (ova 180), saldıran −0,3 (Boşlar 0; 04 §2.4), ısırık çarpanı ×1,2 (§8.2),
yakın hava desteği ×0,2 (§10.1). Hız etkisi yoktur (temel oyunda kentin `move` değeri 1,0).

### 6.2 Kent savunmasının katmanları

| Katman | Araç | Belge |
|---|---|---|
| Dış kordon | Kordon ordusu + Kordon Hattı; kentin çevresindeki bölgeler | §4, §5 |
| Mahalle kapıları | 06 C2 "Kapılı Mahalleler" (β −0,04) | 06 |
| Sokak barikatları, sivil nöbet | 06 C1, E1 (κ_sivil) | 06 |
| Garnizon (tarama) | Kent Garnizonu (jandarma + köpek) | §3.6, §4.4 |
| Hat (dalga) | Piyade + topçu; dalga eşiği §4.2 | §3.6 |
| Serum | Büyük şehrin asıl kaldıracı (03 §3.6) | 05 §8 |

### 6.3 Kent arındırması
Kentte sokak sokak arındırma yavaştır: piyade tümeni 1 sürüyü ovada 10, kentte 15 saatte dağıtır; 2 sürüde kentte başarısız olur
(56 saatte durur). Arındırma Tümeni + `zm_urban_clearance` aynı işi 53 saatte, %55 bütünlükle bitirir (Ek A, B3). Gizli türler kent
arındırmasının asıl yüküdür: Durgun yuvası tümene saldırmaz ama arındırmada ısırık payı 0,50'dir (04). Köpek bölüğü yuvayı gösterir,
alev bölüğü ateşli silahın ulaşmadığı yere ulaşır. Bedeli yangındır (O4).

### 6.4 Kuşatılmış eyalet (K6)
**Tanım:** Eyalette sahibinin kontrolünde en az bir bölge var, ama o bölgelerden hiçbiri başkente dost kontrollü kara yoluyla bağlı değil
**ve** eyaletin dost kontrollü bir limanı yok (ya da limanın deniz bölgesi düşman hâkimiyetinde).

- `UND`'nin donanması olmadığı için **kıyı kenti kuşatılmaz**: ikmal denizden gelir. Bedeli konvoydur: her kuşatılmış kıyı eyaleti için
  ülkenin `convoy_factor` hesabına 2 kaynaklık ek konvoy ihtiyacı yazılır. "Kıyı kenti kuşatılmaz, yalnız pahalıdır."
- **Etkiler** (kuşatma sürdükçe):
  - Eyaletteki tümenler ikmalsizdir (motor: −0,35, günde −%1 güç, toparlanma tavanı %40).
  - Fabrika çıktısı ×0,5 (hammadde gelmez).
  - **Erzak sayacı:** 60 gün (06 C3 "Şehir Erzak Depoları" +30). Sayaç bitince istikrar haftada −%1 ve yaşayan nüfusun haftada %0,2'si
    D'ye yazılır. Tarih: 1941'de Leningrad'da ekmek karnesi, bakmakla yükümlü olunanlar için günde 125 grama kadar düştü. 60 gün bir
    tasarım değeridir: 1930'ların kent depolarının birkaç haftalık tahıl tuttuğu varsayımıyla, oyuncuya iki bülten döngüsü tepki süresi
    tanır.
- **Çıkış yolları:** kara koridoru açmak (arındırma harekâtı), denizden ikmal (yalnız kıyı), havadan ikmal (sürüm 2, §10.3), tahliye (§11.3).
  Kuşatmanın 14. gününde §13 O3 olayı gelir.

### 6.5 Kuşatma ve çöküş
Çöküş, zafer puanlı şehirlerin `UND` elindeki payıyla ölçülür (02 §4.2). Kuşatılmış ama düşmemiş kent çöküşe **sayılmaz**. Düşerse sayılır.
Kuşatma bu yüzden oyuncuya somut bir takvim verir: erzak sayacı + ikmalsiz tümenin günde −%1 gücü ≈ **60–90 gün** içinde bir karar.

## 7. Mühimmat

### 7.1 Neden?
Temel oyunda mühimmat yoktur; ikmalsizlik cezası onu da içerir. Modda üç şey için gerekir: (1) topçunun bedeli yalnız top sesi çekimi
(04) olmasın, üretimde de görünsün; (2) uzun kordon savaşının ekonomik ağırlığı hissedilsin (01 Sütun 3); (3) "silah zaman kazandırır,
salgını bilim bitirir" (01 Sütun 4) sayıyla desteklensin.

### 7.2 Model (yeni kaynak yok)
- Bir tümenin **mühimmat yükü** = şablondaki taburların `ammo_load` toplamı (ekipman birimi olarak).
- Muharebede ön safta (`_frontline`'a giren) olan tümen, her saat `yük / 120` kadar ekipmanı **ülke stokundan** düşer (`rules.gd`,
  `on_hour`; `Military.battles` okunur, motor değişikliği gerekmez).
- Stokta o ekipman yoksa: o saatte ülkenin muharebedeki tümenlerine **mühimmat kıtlığı** −0,25 (saldırı ve savunma çarpanı, K2). Bu,
  ikmalsizlik cezasının (−0,35) yaklaşık 2/3'üdür: yiyecek ve yakıt gelir, cephane gelmez.
- İkmalsiz tümen stoktan çekemez; zaten −0,35 alır. İki ceza toplanmaz (büyük olan uygulanır).
- Ayrıca mühimmat stoku, sayaç ya da tümen başına alan yoktur. Tümen başına cephane sayacı düşünüldü ve reddedildi: kayda ve arayüze yük
  getirir, kuşatmayı zaten ikmal kuralı anlatır.

### 7.3 Türetme
Varsayımlar (bizim; dönem fiyat listeleriyle doğrulanmalı, §19):
- 1 piyade teçhizatı birimi = 10 kişilik silah takımı (tabur 1.000 kişi / 100 birim). Bir tüfeğin fiyatı ≈ 2.000 fişek varsayılır →
  1 birim ≈ **20.000 fişek**.
- Temel yük: asker başına ~80 fişek + makineli tüfek → tabur başına ~80.000 fişek = **4 birim**.
- Topçu: top başına ~50 mermi; bir top ≈ 300 mermi → 12 toplu tabur için 600 mermi = **2 birim** topçu ekipmanı.
- Sürüye karşı çarpan ×0,5: gerçek savaşta mühimmatın çoğu örtü arkasındaki düşmanı bastırmaya gider. Sürü hep açıktadır ve karşı
  batarya ateşi yoktur. Yukarıdaki yükler bu çarpanla zaten küçültülmüştür.
- **Bir yük kaç saat?** Aşağıdan hesap 96 muharebe saati verir (4 günlük yoğun savunma). Ekonomik hedef (§7.4) daha uzun bir süre ister.
  Başlangıç değeri **120 saat** alındı; denge testiyle 96–192 arasında ayarlanır (§18).

| Tabur | `ammo_load` | Fabrika-saat karşılığı |
|---|---|---|
| Piyade, motorlu, taşıyıcı | piyade teçhizatı 4 | 10,8 |
| Topçu | topçu ekipmanı 2 | 38 |
| İstihkâm | piyade teçhizatı 2,5 | 6,8 |
| Atlı | piyade teçhizatı 2 | 5,4 |
| Jandarma | piyade teçhizatı 1 | 2,7 |
| Alev | `zm_flame_equipment` 3 + piyade teçhizatı 0,5 | 19,4 |
| Nişancı | piyade teçhizatı 0,5 | 1,4 |
| Köpek | piyade teçhizatı 0,25 | 0,7 |
| Sıhhiye | — | 0 |

Yük başına: piyade tümeni 28 + 4 birim → **152 fabrika-saat**; Kordon Tümeni 26,5 + 4 → 148; Arındırma Tümeni 29 piyade + 2 topçu
+ 3 alev → 172.

### 7.4 Ekonomik ölçek
- Örnek muharebe (§12): iki tümen 47 saat ön safta → 2 × (47/120) × ~150 = **117 fabrika-saat**. Takviye maliyeti (%7 güç kaybı ×
  tümenin ekipman değeri ~2.770 fabrika-saat) tümen başına ~194, toplam ~388'dir. Mühimmat bunun ~%30'u kadardır.
- **Hedef:** Evre 3'te aktif kordonu olan bir ülkenin askerî üretiminin **%10–25**'i mühimmata gitsin. Türkiye 1936'da 3 askerî
  fabrikayla başlar (verimlilik %15'ten %50'ye; günde 11–36 fabrika-saat). 5 tümenlik bir kordon ayda tümen başına 40 saat muharebe
  görürse ayda 5 × 40/120 × 150 = 250 fabrika-saat, günde ~8 harcar. Bu, üretimin %23–75'idir. Yani küçük sanayili ülke ya fabrika
  kurar, ya ithalat yapar, ya da topçusuz (sessiz) şablona geçip dalga eşiğinden vazgeçer. Bu sert ama bilinçli bir seçimdir. Denge testi
  hedefin dışına çıkarsa ilk ayar `hours_per_load`'dur.

### 7.5 Etkileşimler

| Etken | Mühimmata etkisi |
|---|---|
| 06 `zm_fire_discipline`, emir `zmo_silent_line` | Topçu yükü ×0,75 (kısa atış). Ek öneri: 06 tablosuna "topçu mühimmatı −%25" satırı eklenmeli |
| Top sesi çekimi (04) | Daha çok sürü → daha çok muharebe saati: topçunun gizli ikinci bedeli |
| Kordon Hattı | Muharebeleri kısaltır (3 sürüde 57 → 42 sa): mühimmatı ~%25 azaltır |
| Kuşatma | İkmalsiz tümen stoktan çekmez, −0,35 alır |

## 8. Muharebede bulaşma (ordu içi bulaş)

### 8.1 04'ün kuralı ve bir netleştirme
04 §3.4: tümenin Boşlara karşı verdiği güç kaybının **0,35**'i ısırık yarasıdır ve "enfekte asker" olarak yazılır. Bu belge kişilerin
**nerede** olduğunu netleştirir: ısırılanlar güç kaybının içindedir (savaşamazlar), ama birlikten kopmazlar. Hafif yaralı olarak tümenin
sıhhiye zincirindedirler ve takviye onların yerini doldurur. Tümen başına tutulan sayı `infected` (kişi) ve bu kişilerin evresidir.
**Ölüler dirilmez** (01 §5): Boş'a dönüşebilecek olan yalnız ısırılıp hayatta kalandır.

### 8.2 Etkin ısırık payı
```
ısırılan = Δgüç × tümen_kişi × b_etkin
b_etkin  = ısırık_payı_tür (04: Olağan 0,35, Seğirtken 0,40, Durgun 0,50, Dehlizci 0,45, Gecegezer 0,40, Kışlayan kışta 0,20; suş ekleri 04 §6)
         × (1 + zm_inranks_mult)                       06: eldiven −0,25, sahra karantina istasyonu −0,15, doktrin −0,15, emir −0,30; tavan −0,60
         × Σ_b (genişlik_b · bite_mult_b) / genişlik    §3.3
         × arazi                                         kent 1,2 · orman 1,1 · diğer 1,0
         × bitkinlik                                     bütünlük < %12 iken 1,5
```
- **Kent ×1,2, orman ×1,1:** dar alan ve sürpriz el ve yüz ısırıklarını artırır (04 §3.4'ün "dar alan" notu). Kuduzda bulaş olasılığı
  ısırığın yerine bağlıdır: baş ve yüz en tehlikelisidir (04, Cleaveland ve ark. 2002).
- **Bitkinlik ×1,5:** bütünlüğü biten birlik ateşle tutamadığı hattı göğüs göğüse tutar. Bu kural "son askere kadar" duruşunun sürüye
  karşı gerçek bedelidir (§9.5).
- Birden çok sürü türüyle muharebede tür payı, sürülerin saldırı katkısıyla ağırlıklı ortalamadır.

### 8.3 Tümen içi seyir ve ordu içi üreme sayısı
Isırılan asker 03'ün evrelerini izler: ortalama 3 gün kuluçka, 7 gün ateşli, sonra %10 ölüm, %90 Boş. Tümen içinde iki bulaş yolu vardır:
- **Ateşli asker ısırır:** koğuş ve çadır yoğunluğu en yüksek kentle aynı alınır (d = 3): `φ·β·d = 0,15 × 0,30 × 3 = 0,135` ısırık/gün.
- **Dönüşen asker ısırır:** silahlı arkadaşları onu hızla etkisiz kılar. Gece ve fark edilmeden ortalama 4 saat sürdüğü varsayılırsa
  `β·d / κ_iç = 0,9 / 6 = 0,15` ısırık.

Tarama (§3.4) ateşli ya da kuluçkadaki askeri günde `s` olasılıkla bulup **ayırır**. Ayrılan kimseyi ısırmaz. Ordu içi üreme sayısı:
```
R_ordu = (1 − p_E) · [ 0,135 / (γ + s_F) + (γ / (γ + s_F)) · 0,9 · 0,15 ]      γ = 1/7,  p_E = s_E / (σ + s_E)
```

| Tümendeki tarama | s_E | s_F | R_ordu | Dönüşene kadar ayrılmayan payı |
|---|---|---|---|---|
| Hiç (ikmalsiz, kuşatılmış, "Sessiz kal" seçimi) | 0 | 0 | **1,08** (salgın tümen içinde büyür) | %100 |
| Alay reviri (sıhhiye bölüğü yok) | 0 | 0,2 | 0,45 | %42 |
| Sıhhiye bölüğü, T0 | 0 | 0,6 | **0,21** | %19 |
| Sıhhiye bölüğü, T1 (etken tanımlandı) | 0 | 0,85 | 0,16 | %14 |
| Sıhhiye bölüğü, T2 (kuluçka testi) | 0,5 | 0,95 | **0,06** | %5 |

**Ayrılanlar nereye gider?** Bu, belgenin ana ikilemidir:
- **Sıhhiye bölüğü varsa** sahra karantina çadırına. Serum varsa (05 §8; etkinlik 0,8) iyileşen asker insan gücüne döner. Yoksa hasta
  çadırda ölür; kimseye bulaşmaz.
- **Sıhhiye bölüğü yoksa** en yakın kendi eyaletinin hastanesine gönderilir. O eyalette 05'in **Karantina hastanesi** yoksa gönderilen
  hastalar **o eyaletin ateşli (F) bölmesine eklenir**. Bu, cephe gerisine salgın taşımak demektir. 1918 grip salgınında birlik hareketleri
  ve kalabalık sahra hastaneleri yayılımda rol oynadı (04 kaynakları: Ewald'ın 1918 hipotezi). İlk seferinde §13 O5 olayı gelir.
- **Ayrılmayanlar** dönüştüğünde tümenden kopar ve eyaletin **Kaputlu havuzuna** geçer (04 T05). Havuz 2.000'e ulaşınca bir Kaputlu
  sürüsü doğar.

### 8.4 Yok edilen tümen
Tümen sürülere karşı yok olursa (kuşatılıp çekilemedi ya da "son askere kadar" gücü %4'ün altına indi) kalan askerlerin (`güç × kişi`)
`b_etkin × 1,5` kadarı Kaputlu havuzuna, kalanı kayıplara yazılır (K9). Örnek: "son askere kadar" duran piyade tümeni 4 sürüye karşı 279
saatte yok oldu (Ek A, B4). Güç kaybı %96, kalan ~300 kişi. Muharebe boyunca ısırılanlar ~2.700 kişidir (7.700 × 0,35). Tarama yoksa bunun
~%90'ı, yani ~2.400 kişi Kaputlu olur: tek bir tümen Kaputlu havuzunu kendi başına doğum eşiğinin (2.000) üstüne çıkarır.

### 8.5 Askerin durum makinesi
```
             Boş muharebesinde güç kaybı
 SAĞLAM ───────────────────────────────▶ ÖLÜ / AĞIR YARALI (payı 1 − b_etkin)
   │
   │ b_etkin
   ▼
 ISIRILDI (E, 3 gün) ──tarama s_E──▶ AYRILDI ──serum──▶ İYİLEŞTİ (insan gücüne döner)
   │                                   │
   ▼ σ                                 ├── sıhhiye bölüğü var → çadırda ölür (bulaş yok)
 ATEŞLİ (F, 7 gün) ──tarama s_F──────▶ ┘── yoksa → cephe gerisi hastane (karantina hastanesi yoksa eyaletin F'sine)
   │  ↘ günde 0,135 arkadaşını ısırır (ayrılmadıysa)
   ▼ γ
 %10 ÖLÜ · %90 BOŞ ──▶ Kaputlu havuzu (04 T05) ; dönerken 0,15 arkadaşını ısırır
```

### 8.6 Askere serum ve aşı önceliği
05 §8'deki dağıtım, eyalet düzeyindedir. Bu belge bir **ordu önceliği** kararı önerir: "Askere öncelik / Priority to the ranks" açıkken
günlük serum dozu önce ayrılmış askerlere gider, kalan eyalete kalır. Varsayılan **kapalıdır** (kural 1). Açmanın bedeli sivil tedavinin
gecikmesidir; ipucu, eyaletin o gün serumsuz kalan ateşli sayısını gösterir. Aşı için de aynı seçenek vardır. Kordon tümenlerini aşılamak
`b_etkin`'i değil, ısırılanın hastalanma olasılığını aşı etkinliği (0,9) kadar düşürür (03 §9).

## 9. Moral ve panik

### 9.1 Bütünlük = moral
Motorda moralin karşılığı bütünlüktür: isabet onu düşürür, %12'de birlik çözülür. Bu belge yeni bir moral değeri eklemez. Üç etki
bütünlüğe bağlanır.

### 9.2 İlk temas şoku
Bir tümenin `UND`'ye karşı ilk **24 muharebe saatinde** aldığı bütünlük hasarı ×1,3 olur. Sayaç tümen başınadır (`rules.gd`).
Gerekçe: tanımadığı bir tehdit karşısında birliğin ilk tepkisi eğitimle değil deneyimle düzelir ("ateş vaftizi"). Motor taklidinde örnek
muharebenin (§12) sonunda bütünlük %58 yerine %51 olur. Etkisi sınırlıdır ama "ilk savaşı dinlenmiş tümenle karşıla" dersini verir.

### 9.3 Muharebe yorgunluğu ve rotasyon (K7)
- Sayaç: son 24 saatte muharebe görmüş tümen için "cephe günü" +1. Tümen 7 gün üst üste muharebesiz ve cephe dışı kalınca sayaç sıfırlanır.
- 20. günden sonra bütünlük tavanı günde −%1 düşer; taban %60'tır (40 gün sonra).
- Dayanak: İkinci Dünya Savaşı'nda Normandiya'daki ABD piyadesi üzerine yapılan bir psikiyatri çalışması, kesintisiz muharebenin
  ilk haftalarından sonra etkinliğin düştüğünü ve ~60 gün sonra hayatta kalanların neredeyse hepsinin çöktüğünü bildirdi (Swank ve
  Marchand 1946). Oyunda çöküş yerine tavan düşer, çünkü tümen içinde bireyler dönüşümlü dinlenir ve takviye gelir.
- **Sonuç:** kordon ordusu kalıcı bir garnizon değildir; **yedek ordu** ile dönüşümlü tutulur. Bu, §4.2'deki "her 3 bölgeye 1 yedek"
  kuralıyla aynı yedeği ister.

### 9.4 Ahlaki yük: "Tanıdık Yüzler"
Kendi anavatanında `UND`'ye karşı ilk muharebeden sonra bir olay gelir (§13 O2). Askerlerin karşısındaki Boşlar dün aynı kasabanın
insanlarıydı. Travma araştırmasında "ahlaki yara" kavramı, insanın kendi değerlerine aykırı bir eylemin ardından yaşadığı kalıcı suçluluk
ve utancı anlatır (Litz ve ark. 2009). Oyunda bu kavram bir **olay** olarak yer alır, sürekli bir ceza olarak değil. Seçenekler iç cephe,
istikrar ve yorgunluk eşiği arasında bedel dağıtır. Olay oyunu kan ya da sahneyle anlatmaz: yalnız bir mektup ve bir rapor vardır.

### 9.5 "Son askere kadar" ve bitkin tümen
Oyuncu tümenlerinde bu duruş açık başlar ve **mod bunu değiştirmez**. Geri çekilmeyi oyuncu adına açmak, kural 1'in açıkça yasakladığı
"geri çekilme" otomasyonu olurdu. Bunun yerine:
- Uyarı şeridine **"Bitkin tümen / Exhausted division"** eklenir: `UND` muharebesinde bütünlüğü %12'nin altında, "son askere kadar" açık
  tümen. Uyarı yalnız bilgi verir.
- İpucu şu sayıyı gösterir: "Bitkinken ısırık payı ×1,5". Oyuncu bedeli görerek karar verir (§8.4'teki 279 saatlik örnek).

### 9.6 Sivil "panik" (tasarım kararı)
Afet sosyolojisi, kalabalıkların tehlikede çoğunlukla örgütlü ve birbirine yardım ederek davrandığını, "kitlesel panik"in nadir olduğunu
gösterir (Quarantelli 1954; Clarke 2002; Drury, Cocking ve Reicher 2009). Bu yüzden modda "panik" bir sayı değildir. Sivilin tepkisi
03 §5.5'teki **kaçış** formülüdür: Boş payı %2'yi geçince insanlar gider. Bu mantıklı bir davranıştır, bir bozukluk değildir.
Askerî tarafta bunun üç sonucu vardır:
1. **Ordu sivil kalabalığa karşı hiçbir şey yapamaz.** Kaçışı durdurmanın tek yolları yasal ve lojistiktir: tahliye yasağı (03), kapıda
   bekletme (§5.4), kabul kampı. Hiçbiri kuvvet kullanımı değildir.
2. Kordon kapısında biriken kalabalık bir tehdit değil, bir **karardır** (§13 O1).
3. Tahliye kolu yavaştır: yaya mülteci günde 20–30 km yürür, Olağan Boş ~14 km. Tümen günde ~96 km gider (4 km/sa). Asker her zaman
   geri çekilebilir, sivil her zaman değil. Arka koruma görevinin anlamı budur.

## 10. Hava gücü

### 10.1 Hava desteğinin düzeltilmesi (B4, K8)
`UND`'ye karşı muharebede:
```
hava_ek = min( own_g · 0,0012 · tanıma_s · arazi_hava , 0,3 )        üstünlük terimi = 0
tanıma_s = H_top,s / (H_top,s + L_s)                                  eyaletteki Boş payı: pilot hedefi sivilden ayırabilir mi?
arazi_hava: ova 1,0 · çöl 1,0 · bataklık 0,8 · tepe 0,8 · dağ 0,5 · orman 0,4 · kent 0,2
```
- `own_g` motorun kendisidir: yakın destek kanadında uçak × `ground` (yakın destek 1,0; bombardıman 0,8; avcı 0,15). 0,0012 ve 0,3 tavanı
  temel oyunun katsayılarıdır.
- **tanıma** bu belgenin sayısıdır. Yaşayan halkın çoğunlukta olduğu eyalette hava desteği neredeyse işe yaramaz. Örnek muharebede
  (Kırklareli, L ≈ 540.000, H ≈ 50.000) tanıma 0,085'tir → 100 uçaklık kanat +0,01 verir. **Düşmüş eyalette arındırmada** (H ≫ L,
  tanıma ~0,9) aynı kanat +0,11 verir. Bu kural sivil kayıpları oyuna *ödül ya da ceza olarak* sokmadan, uçağı doğru yere yönlendirir.
- Yakın destek, top sesi gibi sürü çekmez (uçak sesi sürekli değildir; bu bir tasarım seçimidir).

### 10.2 Keşif
06 `zm_aerial_survey` (+1 görüş yarıçapı) ve emir `zmo_recon_sorties` (+2, 30 gün) aynen geçerlidir. Keşif Durgun ve Gecegezer'i gösterir,
yeraltındaki Dehlizci'yi göstermez (06). Kösemen'in haritada rozetle görünmesi için keşif ya da komşu tümen gerekir (04 T04).

### 10.3 Havadan ikmal (sürüm 2)
Dönemin bombardıman ve nakliye uçakları birkaç ton yük taşıyordu. İkinci Dünya Savaşı'nın büyük kuşatma hava ikmalleri, kuşatılmış bir
ordunun ihtiyacının çoğu zaman ancak bir bölümünü taşıyabildi (§19'da doğrulanacak). Oyun hesabı (bizim): 100 uçaklık bir bombardıman
kanadı, %70 hazır oranla ve sorti başına ~1 ton yükle günde ~70 ton taşır. Bir tümenin ihtiyacı 8.000 kişi × ~20 kg = 160 ton/gündür.
Kanat bir tümenin ikmalinin **~%44**'ünü taşır. Kural önerisi: yeni görev "İkmal atma"; kapsadığı kuşatılmış bölgelerde bir tümenin
ikmalsizlik cezasını yarıya indirir ve erzak sayacını günde 0,5 gün uzatır. Motor değişikliği (yeni `AirWing.Mission`) istediği için
sürüm 1'de yoktur.

### 10.4 Havadan tahliye neden yok?
1930'ların nakliye uçağı ~17 yolcu taşır. 100 uçak günde iki sorti yapsa 3.400 kişi eder. Bir milyonluk şehri boşaltmak ~300 gün sürer.
Hava tahliyesi yalnız olaylarda bir seçenek olarak geçer (örn. 05'teki bilim insanlarının tahliyesi). Ayrı bir mekanik yoktur.

### 10.5 Bildiri atma
Karar (öneri, 06'nın emirlerine ek): **"Bildiri Uçuşları / Leaflet Flights"**. Karargâh kapasitesi 15, 30 gün. Şartı hava üssü ve en az
bir kanattır. Seçilen kendi eyaletlerinde β −0,03 ve tespit +0,02 verir. Dayanak: 1918'de katmanlı önlemin bir parçası halkı
bilgilendirmekti (06: Hatchett ve ark. 2007). Havadan bildiri dağıtımı da Birinci Dünya Savaşı'ndan beri bilinen bir yöntemdi.

### 10.6 Sürü bombardımanı neden yok?
Etkiyi hesaplamak için ton başına Boş kaybı gerekir. Bu sayı; bombanın etkili alanına, kalabalığın yoğunluğuna (yürüyen sürüde 0,05 ile
temas anında 0,5 kişi/m² arası), hedef bulma oranına (%10–50) ve arazi örtüsüne bağlıdır. Bu çarpanların çarpımı ±10 kat belirsizdir.
Yanlış bir sayı, havayı ya işe yaramaz ya da tek çözüm yapar. Sürüm 1'de hava, kara muharebesine yakın destek olarak katılır. Ayrı
görev için §19'daki soru açık bırakıldı.

## 11. Deniz gücü

### 11.1 Adalar ve boğazlar
- Boşlar denizi geçemez. Yalnız `land_crossing` olan boğazlardan geçerler (03 §10). Haritada 11 boğazın 10'u `land_crossing`'dir.
  **Manş (Dover) Boğazı değildir:** Britanya adalarına sürü yürüyemez, yalnız yolcu (E, F) ve limanlardan Sazlıkçı gelir (04 T09).
- **Boğaz nöbeti (öneri):** boğazın deniz bölgesinde `UND` dışında birinin **deniz üstünlüğü ya da konvoy koruma** görevindeki filosu varsa
  sürü o boğazı geçemez. Motorun `strait_blocked(a, b, "UND")` işlevi bunu büyük ölçüde zaten hesaplar: `UND` herkesle savaşta olduğundan
  `hostile_sea` her filoyu düşman sayar. Dikkat: `_control_map` limandaki, liman görevindeki ve baskın görevindeki filoları **saymaz**;
  nöbet için filo denizde ve görev bölgesiyle olmalıdır (test §18.1'e eklenir). 1936'da bu boğazların çoğunda köprü değil vapur vardı.
  Kalabalığın vapursuz geçişini önlemek için bir muhrip yeterlidir.
- **Ada ülkelerinde ordunun işi hat değil, garnizondur:** iç salgına karşı κ_asker (§4.4) ve liman kapısı (§5.4).

### 11.2 Liman kapatma ve deniz devriyesi
03'e göre "kapalı" deniz sınırı yolcu akışının %5'ini sızdırır. Öneri: kapalı sınırın deniz hattı üzerindeki bir deniz bölgesinde **deniz
üstünlüğü ya da konvoy koruma görevinde** bir filo varsa sızıntı %5'ten %1'e iner. Kâğıt üstündeki kapalı limanı kaçakçı aşar, devriye
aşamaz. 1918'de Amerikan Samoası'nın deniz karantinası bunun örneğidir (01). Bedeli filonun yakıtıdır: denizdeki filo gemi başına
saatte 0,06 yakıt tüketir (motor).

### 11.3 Deniz tahliyesi
Karar: **"Denizden Tahliye / Evacuation by Sea"**. Kaynak liman eyaleti (kendi) ve hedef liman eyaleti (kendi ya da kabul eden dost)
seçilir, konvoy sayısı ayrılır.
```
sefer süresi = 2 · deniz_yolu_km / 480 + 2 gün (yükleme/boşaltma)     480 km/gün = motorun SEA_SPEED'i (20 km/sa)
günlük taşınan = ayrılan_konvoy · 10.000 / sefer süresi
yolculukta karantina: gelen E payı × (1 − σ)^{yolculuk günü}            03 §8.3'ün bekletme formülü; uzun yol kendiliğinden karantinadır
```
- **1 konvoy ≈ 10.000 kişi/sefer.** Türetme: İngiltere'nin başlangıç konvoy sayısı (300) ile 1930'ların sonundaki büyük ticaret filosu
  karşılaştırılınca 1 konvoy birimi ~10 okyanus gemisidir. Acil tahliyede bir gemi ~1.000 kişi taşıyabildi: 1920'de Kırım'dan
  ~146.000 kişi ~126 gemiyle tek seferde çıkarıldı (§19'da doğrulanacak).
- **Örnek:** Türkiye'nin 20 konvoyunun hepsi, İstanbul'dan İzmir'e (~600 km deniz yolu) → sefer 4,5 gün → günde ~44.000 kişi. 1940'ta
  Dunkerque'den 9 günde 338.000 asker, yani günde ~37.600 kişi taşınmıştı. Sayılar aynı mertebededir.
- **Bedel:** ayrılan konvoylar ithalattan düşer (`convoy_factor`), istikrar −%1. Yolcu taşıyan konvoy denizaltıya açıktır (motor).
- 1915–16'da Gelibolu'dan çekilme, düşman temasında bile büyük bir kuvvetin denizden kayıpsıza yakın çıkarılabildiğini gösterir.
  Oyunda da tahliye bir yenilgi değil, bir seçenektir (02 §3.4 "Hattı kısalt").

### 11.4 Kıyı ateş desteği
Öneri (K2 üzerinden, motor değişikliği yok): kıyı bölgesinde `UND`'ye karşı muharebede, komşu deniz bölgesinde deniz üstünlüğü
görevindeki kendi filosu varsa:
```
deniz_ek = min( Σ gemi_atk · 0,002 , 0,15 )           atk: zırhlı 18, kruvazör 6, muhrip 2 (Navy.SHIPS)
```
Örnek: 1 zırhlı + 2 kruvazör + 4 muhrip = 38 → +0,076. Büyük bir filo 0,15 tavanına ulaşır. Gerekçe: gemi topu, açıktaki hedefe karşı
etkiliydi, siperdekine karşı daha az (1915 Çanakkale bombardımanları). Sürü hep açıktadır ama gemi topu kıyıdan birkaç kilometre içeri
ulaşır ve atış yönetimi kara topçusu kadar yakın değildir. Bu yüzden tavan, bir topçu taburunun bir tümene kattığının (~+%27 PA) yarısı
kadar alındı. **Top sesi:** gemi topu 04'ün çekimini ×2 tetikler. Bu bir bedel olduğu kadar bir araçtır da: sürüyü kıyıya, şehirden uzağa
çekmek mümkündür ("Yem ateşi" fikri, §19).

## 12. Örnek muharebe hesabı

**Kurgu:** Salgın zorluğu, Mart 1937. Kırklareli'nin kuzeybatısındaki komşu eyalet düşmüş (kaynağı önemsizdir; salgın her oyunda başka
yerden başlar). 1042 numaralı bölge (ova, 3.119 km², kıyısız) sınırdadır. Savunanlar: bir **Kordon Tümeni** ve bir **piyade tümeni**,
ikisi de 10 günden beri siperde. Eyalette **Kordon Hattı 1** var. 06'nın `zm_gauntlets` teknolojisi araştırılmış. Hava ve deniz desteği yok,
tümenlerin ilk `UND` muharebesi. Saldıran: **1 Kösemen + 4 Olağan sürü** (50.000 Boş). Kösemen'in önder etkisiyle hepsinin bütünlüğü ×1,2'dir
ve aynı saatte saldırırlar.

**1. Muharebe (motor taklidi, Ek A):**

| | Kordon Hattı yok | **Kordon Hattı 1** | Hat 1 + ilk temas şoku |
|---|---|---|---|
| Süre | 51 sa | **47 sa** | 47 sa |
| Sonuç | 5 sürü dağıldı | 5 sürü dağıldı | 5 sürü dağıldı |
| Kordon Tümeni: bütünlük / güç kaybı | %50 / %8,4 (689 kişi) | %58 / %7,0 (571 kişi) | %51 / %7,0 |
| Piyade Tümeni: bütünlük / güç kaybı | %50 / %8,4 (675 kişi) | %59 / %7,0 (559 kişi) | %52 / %7,0 |
| Ölen Boş | ~9.460 | ~9.410 | ~9.410 |

Aynı saldırıya **tek** piyade tümeni 41 saatte çekilir (5 sürü) ve bölge düşer. Hat yalnız saatleri değil, kaybı da azaltır: 1.364 yerine
1.130 kişi.

**2. Dağılan sürüler:** 50.000 − 9.410 = **~40.600 Boş** kaynak eyaletin dağınık H'sine döner (04 §2.4). Tutulan sınırdan dağınık yürüyüşün
%92,5'i durur (§5.2). Kalan sızıntı Kırklareli'deki κ_asker'e düşer. Muharebede olmayan tümen yoksa bu değer yalnız sivil bastırmadır.
**Öneri:** kesimin gerisine bir jandarma taburu.

**3. Isırık:** `b_etkin = 0,35 × (1 − 0,25) × 1,0 × 1,0 = 0,2625`.

| | Kordon Tümeni (sıhhiye, T0) | Piyade Tümeni (alay reviri) |
|---|---|---|
| Isırılan | 571 × 0,2625 = **150** | 559 × 0,2625 = **147** |
| Dönüşmeden ayrılan | %81 → 121, sahra çadırına | %58 → 85, **cephe gerisi hastaneye** |
| Ayrılmadan dönüşen → Kaputlu havuzu | 150 × 0,19 × 0,9 = **26** | 147 × 0,42 × 0,9 = **55** |
| Sonraki iki haftada tümen içinde ek ısırılan (R_ordu) | 150 × 0,21/0,79 ≈ **40** | 147 × 0,45/0,55 ≈ **120** |
| Serum varsa (etkinlik 0,8) insan gücüne dönen | 97 | 68 (yalnız hastane karantina hastanesiyse) |

Piyade tümeninin hastaneye gönderdiği 85 kişi, arka eyalette karantina hastanesi yoksa **o eyaletin ateşli bölmesine** eklenir. Bu, 85
kişilik bir salgın tohumudur (§8.3) ve ilk seferde O5 olayı gelir. Kaputlu havuzuna bu muharebeden ~81 kişi, ikincil bulaşla
~50 kişi daha yazılır (40 × 0,19 × 0,9 + 120 × 0,42 × 0,9). Eşik (2.000) ~15 benzer dalgada dolar: sıhhiyesiz bir yıllık kordon bir
Kaputlu sürüsü doğurur. İki tümen de sıhhiyeli olsaydı pay yarıya inerdi.

**4. Mühimmat:** iki tümen 47 saat ön safta → Kordon Tümeni (47/120) × 148 = 58, piyade tümeni 60 fabrika-saat. Toplam **~117
fabrika-saat**, Türkiye'nin 1936 askerî üretiminin 3–11 günü eder (§7.4).

**5. Top sesi:** bölgede 4 topçu taburu ateş etti. 2 bölge içindeki öteki sürüler günde 0,3 olasılıkla buraya çekilir (04). `zm_fire_discipline`
ile 0,18'dir.

**6. Toparlanma:** muharebe biterse tümenler saatte %2 bütünlük toplar: %58'den %100'e ~21 saatte. Yeni bir dalga bir günden önce gelirse
tümenler yorgun karşılar. Kesim BASKI durumunda kalır. İki tümen 7 günde 20 cephe gününe yaklaşmaz, ama bu tempoda üç haftada yorgunluk
başlar (§9.3).

**Oyuncunun bu hesaptan çıkaracağı dersler** (ipucu metinleri): hat kaybı azaltır; sıhhiye bölüğü Kaputlu'yu yarıya indirir; sıhhiyesiz
tümen hastalığı cephe gerisine taşır; topçu hem kurtarır hem çeker; mühimmat ucuz değildir.

## 13. Olaylar (her biri 2–3 gerçek seçenekli)

Etkiler mevcut etki sözlüğüyle ya da 03/05/06'nın yeni anahtarlarıyla yazılır. Bu belgenin yeni anahtarları §16.4'tedir; hepsi
`apply_effect` ve `describe_effect`'e birlikte eklenir (CLAUDE.md kural 2).

### O1 — "Kordon Kapısında Kalabalık" / "A Crowd at the Cordon Gate"
Tetik: bir kordon kapısında sınır havuzu ≥ 20.000 kişi (aynı kesimde 30 günde en çok bir kez).
> EN: *"Several thousand people wait at the cordon gate: families with carts, the elderly, a few with fever. No one has tried to force
> the barrier, but the post commander reports that patience is running out. He asks for orders."*
> TR: *"Kordon kapısında birkaç bin kişi bekliyor: arabalı aileler, yaşlılar, birkaçında ateş var. Bariyeri zorlayan olmadı, ama karakol
> komutanı sabrın tükendiğini bildiriyor ve talimat istiyor."*

| Seçenek (EN / TR) | Etki | Bedel |
|---|---|---|
| Open a screened corridor / Denetimli koridor aç | Havuz 14 gün içinde kapıdan taranarak geçer (T düzeyi + köpek); istikrar +%1 | Kesimde `zm_leak_mult` +0,10 (30 gün) |
| Hold the gate, send provisions / Kapıyı tut, erzak gönder | Havuz kaynakta kalır, kapı sızdırmaz | −40 nüfuz; istikrar −%1; 30 gün sonra olay yinelenebilir |
| Open a reception camp / Kabul kampı kur | 14 günlük karantinalı kabul (03 §5.5); insan gücü kazancı | −25 nüfuz; Kızgın suş tetiği (04 §7.2) |

Kalabalığa karşı güç kullanma seçeneği **yoktur** (§1.2, 01 §6.2).

### O2 — "Tanıdık Yüzler" / "Familiar Faces"
Tetik: kendi anavatan eyaletinde `UND`'ye karşı ilk muharebe bitti.
> EN: *"A letter from the line, passed on by the censor's office: 'We knew some of them. The baker from the square was among them.
> The men did their duty. They do not sleep.'"*
> TR: *"Sansür dairesinden iletilen bir cephe mektubu: 'Bazılarını tanıyorduk. Meydandaki fırıncı da aralarındaydı. Askerler görevini yaptı.
> Uyuyamıyorlar.'"*

| Seçenek | Etki | Bedel |
|---|---|---|
| Doctors and chaplains to the line / Cepheye hekim ve manevi destek | Yorgunluk eşiği 20 → 25 gün (180 gün) | −50 nüfuz |
| Tell the country the truth / Halka gerçeği anlat | İç cephe +%3 (dayanışma) | İstikrar −%1 |
| Keep the letters back / Mektupları beklet | İstikrar +%1 | 60 gün içinde %30 olasılıkla duyulur: iç cephe −%5 |

### O3 — "Kuşatılmış Şehir" / "The City Encircled"
Tetik: zafer puanlı şehri olan eyalet 14 gündür kuşatılmış (§6.4).

| Seçenek | Etki | Bedel |
|---|---|---|
| Relief offensive / Kurtarma taarruzu | 30 gün: şok +0,10 (bütün tümenler) | Bütünlük −0,05; mühimmat tüketimi artar |
| Hold and ration / Dayan ve karneye geç | Erzak sayacı +30 gün | İstikrar −%3; fabrika çıktısı ×0,5 sürer |
| Evacuate the city / Şehri boşalt | Yaşayanların %30'u 30 günde tahliye (kıyıysa §11.3, değilse koridor gerekir) | İstikrar −%3; şehir düşerse çöküşe sayılır |

### O4 — "Yangın Kontrolden Çıktı" / "The Fire Got Away"
Tetik: kent bölgesinde alev bölüğünün katıldığı muharebe; muharebe günü başına %2.
Gerekçe: kentte yakma, rüzgârla kontrolden çıkabilen bir yöntemdir. Salgın tarihinde hastalıklı yapıları yakma kararlarının mahalleleri
yaktığı örnekler vardır (§19'da doğrulanacak).
> TR: *"Arındırma sırasında çıkan yangın rüzgârla iki mahalleye sıçradı. Ölü bildirilmedi, ama binlerce kişi evsiz."*

| Seçenek | Etki | Bedel |
|---|---|---|
| Firemen and engineers / İtfaiye ve istihkâm | Hasar yok | −30 nüfuz; o bölgede 7 gün taarruz yok |
| Cut a firebreak / Yangın şeridi aç | Taarruz sürer | Eyaletin altyapısı −1; istikrar −%1 |
| Withdraw flame units from towns / Alev bölüklerini kentten çek | 90 gün kentte alev eki yok | İstikrar +%1 |

### O5 — "Hattın Ardında Hasta Askerler" / "Sick Soldiers Behind the Line"
Tetik: sıhhiye bölüğü olmayan tümenden karantina hastanesi olmayan eyalete ilk hasta gönderimi (§8.3).

| Seçenek | Etki | Bedel |
|---|---|---|
| Build an army isolation hospital / Askerî tecrit hastanesi kur | O eyalette 05'in Karantina hastanesi inşaatı kuyruğun başına eklenir (oyuncunun kararıyla, bu seçenekle) | İnşaat maliyeti (05) |
| Keep the sick at the front / Hastaları cephe gerisinde tut | 90 gün: sıhhiyesiz tümenlerin ayırdığı hastalar çadırda kalır (arka eyalete gitmez) | Bu tümenlerde bütünlük −%5 |
| Send them to hospitals / Hastanelere gönder | Kural aynen sürer | Arka eyaletlere tohum |

### O6 — "Köprü Başlarına Mayın" / "Mines at the Bridgeheads"
Tetik: aynı kordon kesimi 60 gün içinde iki kez yarıldı ve 06'nın `zm_bridge_demolition` teknolojisi var.

| Seçenek | Etki | Bedel |
|---|---|---|
| Lay the mines / Mayın döşe | O sınırda sürü yürüyüşü ×0,5, sürü saldırısı −0,10 (kalıcı) | Mülteci o sınırdan geçemez; eyalet arındırılınca yeniden yerleşim −%25 hızla ve 120 gün temizlik; diplomasi kabul oranları −%5 (1 yıl) |
| Blow the bridges only / Yalnız köprüleri at | `zmo_blow_bridges` o kesimde bedelsiz (60 gün) | İkmal ve ticaret (06) |
| No / Hayır | — | — |

## 14. Arayüz (yalnız `panel_layout.gd` yardımcıları)

Yeni görsel stil yoktur (CLAUDE.md kural 5).

**Ordu paneli** (mevcut):
- `section` "Salgın cephesi / Outbreak front" (ordunun hedefi `UND` ise).
- `row_action` "Kordon eyaletleri: 3" + `small_button` "Ekle / Çıkar" (haritada eyalet seçimi; mevcut hedef seçme akışı).
- `info_cells`: ordu içi bulaş (%), ayrılmış hasta, mühimmat (ülke stoğunda kaç yük), en yorgun tümenin cephe günü.
- `table` / `table_row` sütunları: tümen, güç, bütünlük, cephe günü, bulaş %, sıhhiye (✓ yerine "var/yok" metni), konum.
- İpucu: "Bitkinken ısırık payı ×1,5", "Topçu 2 bölgedeki sürüleri çeker (%30/gün)".

**Salgın paneli (E), "Kordon" sekmesi** (02'deki panelin yeni sekmesi):
- `table`: kesim (eyalet adı), durum (§4.7; metin ve mevcut renk kodları), tutulan pay `g`, Kordon Hattı seviyesi, sızan Boş/gün,
  kapı taraması (T0/T1/T2, köpek), bekletme günü.
- `row_action`: "Bekletme: 0 / 5 / 14 gün" (`small_button` üçlüsü).
- `empty`: "Kordon ordusu yok. Ordu panelinden hedef olarak 'Salgın cephesi'ni seç."

**İnşaat paneli:** `zm_cordon_line` mevcut bina satırı olarak görünür.

**Uyarı şeridi** (`alert_bar.gd`), 02'nin listesine ek:

| Uyarı (EN / TR) | Tetik |
|---|---|
| Exhausted division / Bitkin tümen | `UND` muharebesinde bütünlük < %12, "son askere kadar" açık |
| Ammunition shortage / Mühimmat kıtlığı | Muharebedeki tümenin mühimmat ekipmanı stokta 0 |
| City encircled / Kuşatılmış şehir | §6.4 tanımı; erzak günü ipucunda |
| Battle-weary army / Yorgun ordu | Ordudaki bir tümenin cephe günü ≥ 20 |

## 15. Yapay zekâ

Yapay zekâ ülkeleri otomatik yönetilir (kural 1). Oyuncuya hiçbiri uygulanmaz. Yapay zekâ **bildirilen** verileri kullanır, gerçek
sayıları görmez (01 Sütun 2; hile yok).

| Karar | Kural | Gerekçe |
|---|---|---|
| Kordon ordusu kurma | Kendi eyaleti BİLDİRİLMİŞ ya da komşu eyalet SALGIN olunca; `cordon` = bu eyaletler | 02 evreleri |
| Kordona ayrılan pay | Tümenlerin en çok %70'i; kalanı yedek ordu | §4.2 "her 3 bölgeye 1 yedek" |
| Şablon | Kordon Tümeni (topçu, sıhhiye, istihkâm); kentli eyalette 1 Kent Garnizonu; `zm_urban_clearance` varsa Arındırma Tümeni | §3.6 |
| Rotasyon | Cephe günü ≥ 25 olan tümeni yedekle değiştirir | §9.3 |
| Arındırma | Evre ≥ Çöküş ve yerel güç oranı ≥ 1,5 (motorun 1,0'ından temkinli) | Sürüye karşı başarısız taarruz ısırık üretir |
| Kordon Hattı | SALGIN eyalete komşu kendi eyaletinde, en az 4 sivil fabrikası varsa 1. seviye; Evre ≥ Yayılma'da 2. seviye | §5.2 |
| Hava | Yakın desteği yalnız tanıma ≥ 0,5 olan eyaletlere verir. B2 düzeltmesinden sonra `Air._ai` `at_war` yerine `are_enemies(UND)` bakmalı; yoksa yapay zekâ kanatları sürülere karşı boşta kalır | §10.1 |
| Deniz | Kendi `land_crossing` boğazında boğaz nöbeti; kapalı deniz sınırında devriye | §11 |
| Askere serum önceliği | Açık (yapay zekâ için) | Yapay zekâ ordusunu korur; oyuncuya kapalı başlar |

**`country_check.gd` denetimi** (oyuncu hiçbir şey yapmazsa, 60 gün): oyuncu ülkesinde hiçbir ordu kurulmamış ve hedefi değişmemiş,
hiçbir şablon değişmemiş, `zm_cordon_line` kuyruğa girmemiş, deniz tahliyesi başlamamış, hiçbir tümenin "son askere kadar" bayrağı
değişmemiş, askere serum önceliği kapalı.

## 16. Veri: JSON şema örnekleri

Kesin yerleşim 14_teknik_plan.md §2: `data/modes/zombie/common/<dosya>.patch.json` ve modun kendi dosyası `own/military.json`.

### 16.1 `common/units.patch.json` (kesit)
`templates` kimliksiz bir dizidir; patch kuralı gereği tamamen değişir. Bu yüzden temel şablonlar da yazılır. Mod sözleşmesi: 0. piyade,
1. zırhlı olmalıdır.
```json
{
  "_comment": "Gri Kordon taburları. Türetme: docs/modlar/zombi/08_askeri_ve_savunma.md §3.3-§3.4. 'extra' anahtarlarını motor toplar (K1), rules.gd okur.",
  "battalions": {
    "zm_gendarmerie": {"name": {"en": "Quarantine Gendarmerie", "tr": "Karantina Jandarması"}, "category": "infantry",
      "soft": 12, "hard": 1, "defense": 45, "breakthrough": 6, "hp": 30, "org": 60, "width": 2, "speed": 4,
      "hardness": 0.0, "armor": 0, "piercing": 10, "manpower": 600, "equipment": {"infantry_equipment": 40},
      "extra": {"sweep": 1.5, "checkpoint": 1, "bite_mult": 1.1, "ammo_load_infantry_equipment": 1}},
    "zm_flame": {"name": {"en": "Flame and Disinfection Company", "tr": "Alev ve Dezenfeksiyon Bölüğü"}, "category": "support",
      "soft": 20, "hard": 2, "defense": 20, "breakthrough": 10, "hp": 1.2, "org": 0, "width": 1, "speed": 4,
      "hardness": 0.0, "armor": 0, "piercing": 5, "manpower": 250,
      "equipment": {"infantry_equipment": 20, "zm_flame_equipment": 12}, "requires": "zm_flame_equipment", "max_per_template": 1,
      "extra": {"terrain_attack_urban": 0.15, "terrain_attack_forest": 0.10, "bite_mult": 0.8, "sweep": 0.3, "fuel_use": 0.03,
                "ammo_load_zm_flame_equipment": 3, "ammo_load_infantry_equipment": 0.5}},
    "zm_medical": {"name": {"en": "Sanitary and Decontamination Company", "tr": "Sıhhiye ve Dekontaminasyon Bölüğü"}, "category": "support",
      "soft": 2, "hard": 0, "defense": 10, "breakthrough": 2, "hp": 1.2, "org": 0, "width": 1, "speed": 4,
      "hardness": 0.0, "armor": 0, "piercing": 0, "manpower": 300, "equipment": {"support_equipment": 6}, "max_per_template": 1,
      "extra": {"screen": 1, "sweep": 0.2}},
    "zm_carrier": {"name": {"en": "Armoured Carriers", "tr": "Zırhlı Taşıyıcı"}, "category": "infantry",
      "soft": 30, "hard": 6, "defense": 90, "breakthrough": 40, "hp": 35, "org": 70, "width": 4, "speed": 9,
      "hardness": 0.6, "armor": 10, "piercing": 15, "manpower": 800,
      "equipment": {"infantry_equipment": 80, "zm_carrier_equipment": 40}, "requires": "zm_carrier_equipment",
      "extra": {"bite_mult": 0.5, "fuel_use": 0.10, "sweep": 1.0, "ammo_load_infantry_equipment": 4}},
    "zm_dogs": {"name": {"en": "Tracker and Sentry Dogs", "tr": "Köpekli İz ve Nöbet"}, "category": "support",
      "soft": 3, "hard": 0, "defense": 15, "breakthrough": 3, "hp": 1.2, "org": 0, "width": 1, "speed": 4,
      "hardness": 0.0, "armor": 0, "piercing": 0, "manpower": 150,
      "equipment": {"infantry_equipment": 10, "zm_working_dogs": 10}, "max_per_template": 1,
      "extra": {"reveal": 1, "night_guard": 1, "checkpoint": 1, "sweep": 1.0, "ammo_load_infantry_equipment": 0.25}}
  },
  "templates": [
    {"name": {"en": "Infantry Division", "tr": "Piyade Tümeni"}, "battalions": {"infantry": 7, "artillery": 2}},
    {"name": {"en": "Armored Division", "tr": "Zırhlı Tümen"}, "battalions": {"light_armor": 4, "motorized": 4}},
    {"name": {"en": "Garrison Division", "tr": "Garnizon Tümeni"}, "battalions": {"infantry": 5}},
    {"name": {"en": "Cordon Division", "tr": "Kordon Tümeni"}, "battalions": {"infantry": 6, "artillery": 2, "zm_engineer": 1, "zm_medical": 1}},
    {"name": {"en": "Clearance Division", "tr": "Arındırma Tümeni"}, "battalions": {"infantry": 5, "zm_carrier": 2, "zm_flame": 1, "artillery": 1, "zm_medical": 1, "zm_marksman": 1}},
    {"name": {"en": "City Garrison", "tr": "Kent Garnizonu"}, "battalions": {"zm_gendarmerie": 4, "infantry": 2, "zm_medical": 1, "zm_dogs": 1, "zm_flame": 1}},
    {"name": {"en": "Flying Column", "tr": "Seyyar Kol"}, "battalions": {"zm_mounted": 3, "motorized": 2, "zm_dogs": 1}},
    {"name": {"en": "Silent Cordon", "tr": "Sessiz Kordon"}, "battalions": {"infantry": 7, "zm_engineer": 1, "zm_medical": 1, "zm_dogs": 1}}
  ]
}
```
Temel taburlara `extra` eklenir (`infantry`: `sweep` 1, `bite_mult` 1, `ammo_load_infantry_equipment` 4; `artillery`: `noise` 1,
`ammo_load_artillery_equipment` 2). Yeni `category: "support"` hiçbir temel modifier'ın hedefi değildir. Bu kasıtlıdır: topçu ve
piyade teknolojileri destek bölüklerini güçlendirmez.

### 16.2 `common/equipment.patch.json`
```json
{"equipment": {
  "zm_flame_equipment":   {"cost": 6,  "resources": {"steel": 1}, "category": "land", "name": {"en": "Flamethrower Set", "tr": "Alev Silahı Takımı"}},
  "zm_carrier_equipment": {"cost": 25, "resources": {"steel": 2}, "category": "land", "name": {"en": "Light Armoured Carrier", "tr": "Hafif Zırhlı Taşıyıcı"}},
  "zm_working_dogs":      {"cost": 4,  "resources": {},           "category": "land", "name": {"en": "Trained Dogs (10)", "tr": "Eğitimli Köpek (10)"}}
}}
```
Açan teknolojiler `technologies.patch.json`'da `unlock` ile yazılır: `zm_urban_clearance` → `zm_flame_equipment` (06'ya ek);
`motorization` → `zm_carrier_equipment`.

### 16.3 `common/buildings.patch.json`
```json
{"buildings": {
  "zm_cordon_line": {"cost": 300, "shared_slots": false, "max": 3,
    "name": {"en": "Cordon Line", "tr": "Kordon Hattı"},
    "_comment": "Seviye başına 300 fabrika-gün; türetme 08 §5.2. Etkileri rules.gd uygular (K2), motor binayı yalnız inşa eder."}
}}
```

### 16.4 `data/modes/zombie/own/military.json` (modun askerî kural dosyası)
Not (güncellendi): Mod altyapısı modun kendi verisi için `own/` klasörünü ekledi; bu dosya `own/military.json` olarak `--check`'ten
geçer ve kural betiği `GameModes.load_own("military.json")` ile okur (14_teknik_plan.md §2.1). §19 soru 11 bu yolla çözüldü.
```json
{
  "_comment": "Gri Kordon askerî kuralları. Gerekçeler: docs/modlar/zombi/08_askeri_ve_savunma.md.",
  "urban": {"min_city_pop": 250000, "bite_mult": 1.2, "air_mult": 0.2},
  "obstacle": {"building": "zm_cordon_line",
               "und_attack_per_level": -0.10, "und_breakthrough_per_level": -0.10,
               "walk_stop_held_base": 0.90, "walk_stop_held_per_level": 0.025, "walk_stop_unheld_per_level": 0.15,
               "engineer_build_speed": 0.25, "engineer_build_speed_max": 0.50},
  "bite": {"terrain": {"urban": 1.2, "forest": 1.1}, "exhausted_below_org": 0.12, "exhausted_mult": 1.5},
  "inranks": {"phi_barracks": 0.135, "turn_bites": 0.15, "p_death": 0.10,
              "screen": {"none": {"E": 0, "F": 0}, "regimental": {"E": 0, "F": 0.2},
                         "T0": {"E": 0, "F": 0.6}, "T1": {"E": 0, "F": 0.85}, "T2": {"E": 0.5, "F": 0.95}},
              "unsupplied_screen": "none",
              "isolated_without_medical": "rear_hospital",
              "destroyed_bitten_mult": 1.5,
              "priority_to_ranks_default": false},
  "sweep": {"kappa_per_infantry_division": 0.10, "infantry_division_points": 7},
  "ammo": {"hours_per_load": 120, "frontline_only": true, "shortage_mod": -0.25, "fire_discipline_artillery_mult": 0.75},
  "morale": {"first_contact_hours": 24, "first_contact_org_dmg_mult": 1.3,
             "fatigue_start_days": 20, "fatigue_per_day": 0.01, "fatigue_floor": 0.60, "rest_days": 7},
  "siege": {"connected_supply": true, "coastal_extra_convoy": 2, "factory_mult": 0.5,
            "ration_days": 60, "stability_per_week": -0.01, "starvation_per_week": 0.002},
  "air": {"superiority_vs_und": 0.0, "cas_coeff": 0.0012, "cas_cap": 0.3, "discrimination": "hollow_share",
          "terrain": {"plains": 1.0, "desert": 1.0, "marsh": 0.8, "hills": 0.8, "mountain": 0.5, "forest": 0.4, "urban": 0.2}},
  "navy": {"strait_guard_missions": ["SUPERIORITY", "ESCORT"], "closed_sea_leak_patrolled": 0.01,
           "sealift_per_convoy": 10000, "sealift_load_days": 2, "shore_per_atk": 0.002, "shore_cap": 0.15, "shore_noise_mult": 2.0},
  "flood": {"und_attack": -0.6, "walk_mult": 0.15, "factory_mult": 0.90, "drain_days": 180, "ignore_type": "waders"},
  "fire_risk": {"per_battle_day": 0.02, "event": "zm_fire_got_away"}
}
```

**Yeni etki ve şart anahtarları** (`rules.gd` → `effect_keys` / `apply_effect` / `describe_effect`; `condition_keys` / `check_condition`):

| Anahtar | Tür | describe (EN / TR) |
|---|---|---|
| `zm_obstacle` | modifier, sürü saldırısına ek (tavan 0,15) | "Obstacles %+.2f" / "Engeller %+.2f" |
| `zm_fatigue_threshold` | modifier, gün | "Battle-weariness after %d days" / "%d günden sonra muharebe yorgunluğu" |
| `zm_ration_days` | etki, kuşatılmış eyalette gün | "City rations %+d days" / "Şehir erzakı %+d gün" |
| `zm_flood_province` | etki (karar) | "Flood the lowlands" / "Ovayı su altında bırak" |
| `zm_sealift` | etki (karar) | "Evacuation by sea: %d convoys" / "Denizden tahliye: %d konvoy" |
| `zm_priority_to_ranks` | bayrak | "Serum priority to the ranks" / "Serumda askere öncelik" |
| `zm_mines_border` | etki (O6) | "Mined border with %s" / "%s sınırı mayınlı" |
| şart `zm_state_encircled` | eyalet | "a city is encircled" / "bir şehir kuşatılmış" |
| şart `zm_cordon_breached_times` | sayı, 60 gün | "cordon breached %d times" / "kordon %d kez yarıldı" |

**Kayda eklenecekler:** `Army.cordon` (K4), kordon kesimi durumları, tümen başına `{infected_E, infected_F, isolated, hollow_hours,
front_days, rest_days}`, eyalet başına `{encircled_days, ration_days, flooded_until, mined_borders}`, Kaputlu havuzu (04), bekletme ayarları,
askere öncelik bayrağı. Büyük tamsayılar `str()` ile yazılır (README kuralı).

## 17. Görsel ve ses varlıkları (liste ve üretim komutları)

Dosya üretilmez ve indirilmez (CLAUDE.md kural 6). Model ve animasyon parametreleri insan gözüyle masaüstünde (Forward+) ve web'de
(gl_compatibility) doğrulanır (kural 5). İkonlar 04'teki `STYLE_ZM_ICON` stil cümlesini kullanır; ek kural: **tıbbi birimlerde kızılhaç
ya da kızılay yok, hiçbir ülke işareti yok, yaralı hayvan yok, yanan insan figürü yok.**

### 17.1 İkonlar (`assets/ui/icons_new/`, 512×512)

| Dosya | Konu (prompt'un başı; sonuna `STYLE_ZM_ICON` eklenir) |
|---|---|
| `zm_bat_flame.png` | a 1930s flamethrower pack with twin steel tanks and a wand resting against a brick wall, a thin wisp of grey smoke, no fire on people |
| `zm_bat_gendarmerie.png` | a peaked cap, a whistle and a folded quarantine pass on a wooden checkpoint table beside a striped barrier pole |
| `zm_bat_engineer.png` | coils of barbed wire, a pick and a shovel beside a half-built earth bank |
| `zm_bat_medical.png` | a canvas stretcher, a thermometer and a disinfectant sprayer outside a plain field tent, no emblem, no cross |
| `zm_bat_marksman.png` | a scoped bolt-action rifle and binoculars resting on a sandbag at dawn, a distant crowd silhouette out of focus |
| `zm_bat_carrier.png` | a small open-topped tracked armoured carrier with a machine gun, seen three-quarter, muddy road |
| `zm_bat_dogs.png` | a handler kneeling beside an alert shepherd dog on a leash at a night checkpoint lantern |
| `zm_bat_mounted.png` | two mounted patrol riders on a ridge at dusk looking over a misty valley |
| `zm_eq_flame.png` | a steel flamethrower pack standing upright on a workbench |
| `zm_eq_carrier.png` | a light tracked carrier on a factory floor |
| `zm_eq_dogs.png` | three shepherd dogs sitting in a row beside a kennel gate |
| `zm_bld_cordon_line.png` | a double apron barbed-wire fence and a wooden watchtower along a low earth bank stretching into fog |
| `zm_alert_exhausted.png` | a dented helmet lying on a trench parapet (STYLE_SMALL) |
| `zm_alert_ammo.png` | an empty open ammunition crate (STYLE_SMALL) |
| `zm_alert_encircled.png` | a small walled town inside a closing ring of fog (STYLE_SMALL) |
| `zm_alert_weary.png` | a soldier's boots and puttees beside a camp cot (STYLE_SMALL) |
| `zm_dec_leaflets.png` | a biplane scattering paper leaflets over a village, papers blank |
| `zm_dec_sealift.png` | a crowded passenger steamer leaving a harbour at dawn, people seen from behind |
| `zm_dec_flood.png` | an opened sluice gate and water spreading across flat fields |

### 17.2 Olay resimleri (8:3, `STYLE_EVENT` yapısı; ek: "no gore, no children, figures at a distance")

| Dosya | Konu |
|---|---|
| `event_zm_cordon_gate.png` | a long queue of families with carts waiting at a striped barrier in drizzle, a gendarme with a lantern, seen from far behind |
| `event_zm_familiar_faces.png` | a soldier writing a letter by candlelight in a dugout, his rifle leaning on the wall |
| `event_zm_city_encircled.png` | a city skyline at dusk behind a ring of low fog, a single searchlight beam |
| `event_zm_fire_got_away.png` | smoke rising over rooftops of a town, firemen with hoses in a street, no bodies |
| `event_zm_sick_soldiers.png` | a row of canvas hospital tents behind a rope line, a nurse in a gauze mask with a clipboard |
| `event_zm_bridgehead_mines.png` | engineers kneeling at a riverbank bridgehead with small marker flags, morning mist |

### 17.3 3D modeller (isteğe bağlı; yoksa mevcut figürler)
Mevcut `unit_models.gd` rol sistemi (`inf`, `mg`, `art`, `truck`, `tank`) yeter: jandarma, istihkâm, sıhhiye, nişancı ve köpek bölükleri
`inf` figürüyle; taşıyıcı `truck` figürüyle; atlı `inf` ile gösterilir. 01'in "~10 model" bütçesini 04'ün `hol_*` figürleri kullanır.
Bu yüzden aşağıdakiler **ikinci önceliktir**:

| Mesh | Üçgen | Tarif | Yerine geçen |
|---|---|---|---|
| `inf_flame` | ≤ 1.200 | Sırtında çift depolu alev silahı, maske yok, tabanca aşağıda | `inf` |
| `inf_dog` | ≤ 1.400 | Tasmalı çoban köpeğiyle diz çökmüş asker | `inf` |
| `cav_rider` | ≤ 1.800 | Atlı devriye; at yürüyüşü kodla (mevcut adım sistemi) | `inf` |
| `carrier_light` | ≤ 1.500 | Açık üstlü küçük paletli taşıyıcı, makineli tüfek | `truck` |

### 17.4 Sesler (`tools/make_audio.py` yaklaşımı; telifli örnek yok, çığlık yok)

| Dosya | Süre | Prosedürel tarif | Üretim komutu (EN) |
|---|---|---|---|
| `zm_flame_burst` | 1,5 sn | Pembe gürültü, 200–2.500 Hz bant, 60 ms atak, 1,2 sn sönüm; 30–60 Hz gümbürtü; sonda 3–6 kHz çıtırtı taneleri | "a short roaring gas burst with crackling afterwards, no voices" |
| `zm_wire_building` | 6 sn döngü | Tahta kazığa çekiç (180 Hz rezonanslı tık, 1,1 sn aralık), tel gerilmesi (2–5 kHz süpürme), kürek sesi (gürültü tanesi) | "field engineers hammering stakes and stretching wire, distant, calm" |
| `zm_gate_crowd` | 8 sn döngü | 04'teki `zm_horde_common_loop`'tan farklı: 250–1.800 Hz kalabalık uğultusu (yaşayanlar), ara ara araba tekerleği (düşük tık dizisi), tek bir düdük (2,8 kHz, 0,4 sn) | "a waiting crowd murmuring at a checkpoint, cart wheels, one whistle, no words" |
| `zm_dog_alert` | 1,2 sn | İki kısa havlama: 400–1.200 Hz formant, 90 ms, 250 ms ara; uzaklık için alçak geçiren | "two short distant dog barks at night" |
| `zm_searchlight_hum` | 4 sn döngü | 50/100 Hz uğultu + ark cızırtısı (4–8 kHz, düşük seviye) | "the steady hum of a carbon-arc searchlight" |
| `zm_carrier_engine` | 5 sn döngü | 25–40 Hz motor darbesi, palet şakırtısı (8–12 Hz tık dizisi, 1–3 kHz) | "small tracked vehicle engine idling, track clatter" |
| `zm_field_phone` | 2 sn | 20 Hz zil darbesi, 1,1 kHz metal rezonans | "old field telephone ringing twice" |
| `zm_sealift_horn` | 3 sn | Buhar düdüğü: 180 Hz + 3 harmonik, yavaş atak | "a ship's steam whistle in a harbour at dawn" |

## 18. Test ve denge hedefleri

### 18.1 Birim testleri (`tests/test_zm_military.gd`)
1. **Motor taklidi eşleşmesi:** siperli piyade tümeni + 3 Olağan sürü → sürüler 57 ± 6 saatte dağılır; + 4 → tümen 52 ± 6 saatte çekilir
   (04 §3.3 ile aynı).
2. **Engel:** Kordon Hattı 3 + piyade tümeni + 4 sürü → sürüler dağılır (73 ± 8 sa); Kordon Hattı yok → tümen çekilir.
3. **Isırık korunumu:** bir muharebede yazılan ısırılan = `Σ Δgüç × kişi × b_etkin` (tolerans 1 kişi); ısırılan + ölen/yaralı = güç kaybı.
4. **R_ordu:** tek tümen, 1.000 ısırılan, sıhhiye T0 → 60 günde toplam ikincil ısırılan 230–330 (R 0,21 → beklenen 266).
5. **Sıhhiyesiz tümen**, karantina hastanesi olmayan eyalet → ayrılanlar o eyaletin F bölmesine eklenir. Karantina hastanesiyle eklenmez.
6. **Kent bölgesi sayısı:** eşik 250.000 → 391 bölge.
7. **Kuşatma:** başkente bağı kesilen, limansız eyalet `encircled`; limanlı olan değil.
8. **`at_war` (K10):** yalnız `UND` ile savaşan demokraside seçim ertelenmez, garip savaş cezası 0.
9. **Hava:** `UND`'ye karşı üstünlük terimi 0; tanıma 0,085 → 100 uçaklık yakın destek +0,010 ± 0,002.
10. **Mühimmat:** 47 saat ön safta piyade tümeni stoktan 47/120 × (28 piyade + 4 topçu) birim düşer; stok 0 → saldırı çarpanı −0,25.
11. **Kayıt/yükleme:** bütün yeni alanlar (§16.4 son paragraf) kaydedilip aynen yüklenir.
12. **Boğaz nöbeti:** İstanbul Boğazı'nın deniz bölgesinde deniz üstünlüğü görevinde bir muhrip varken `strait_blocked(4300, 11871, "UND")`
    doğru; aynı filo liman görevindeyken yanlış (motorun `_control_map` kuralı).

### 18.2 Denge hedefleri (oyuncusuz dünya, 6 koşu; her kontrol ≥ 5/6)

| # | Kontrol | Hedef |
|---|---|---|
| 1 | Evre 3'te aktif kordonu olan yapay zekâ ülkelerinde mühimmatın askerî üretimdeki payı | %10–25 |
| 2 | Sürülerin Kaputlu payı (04) | %1–3 |
| 3 | Yıl başına `UND`'ye karşı yok edilen yapay zekâ tümeni / toplam tümen | %3–10 |
| 4 | Evre 2'de kurulan kordonların 90 gün yarılmadan tutma oranı | %40–70 |
| 5 | Sıhhiye bölüklü ordularda ortalama ordu içi bulaş | < %1 (02 uyarı eşiği) |
| 6 | Kuşatılmış eyalet olayı (O3) bir koşuda | 3–15 kez |
| 7 | Sürü + tümen birimleriyle 1.461 günlük ekransız koşu süresi | 02 §8 kontrol 10'daki sınırın içinde |
| 8 | WWII modu denge testi (`balance_parallel.sh`), kancalar eklendikten sonra | 12 kontrolün hepsi ≥ 5/6 (kancalar varsayılanla etkisiz) |

## 19. Açık sorular

1. ~~**06'ya geri bildirim (B5):**~~ — **Çözüldü:** 06'daki `zm_wire_obstacles` → `zm_obstacle +0,05`, `zm_final_protective_fire` → `artillery_soft +0,08` (savunmada) ve 02 §3.4'teki seçenek düzeltildi.
2. ~~**`at_war` (B2, K10):**~~ — **Çözüldü:** salgın savaşı `at_war`'a sayılmaz, seçimler yapılır (09 S1 = 14 H02).
3. **Boğaz geçişi:** 03'e göre sürüler `land_crossing` boğazlarını geçer. 1936'da çoğunda köprü yoktu, geçiş vapurlaydı (Küçük Belt'te 1935
   köprüsü bir istisnaydı). Boşlar yalnız köprülü boğazı mı geçsin? Öyle olursa boğaz nöbeti (§11.1) gereksizleşir ama Sazlıkçı'nın limandan
   sıçraması önem kazanır.
4. **Kordon Hattı maliyeti eyalete göre değişsin mi?** Sabit 300 fabrika-gün büyük eyaletlerde (Sibirya, Sahra) ucuz kalır. Çevre
   uzunluğuyla çarpan bir motor kancası ister (bina maliyeti bugün türe göre sabit).
5. **Mühimmat:** `hours_per_load` 120 başlangıç değeri. Türkiye gibi 3 askerî fabrikalı ülkeler için fazla ağır mı? Tüfek ve fişek fiyat
   oranı (1 tüfek ≈ 2.000 fişek) dönem fiyat listeleriyle doğrulanmalı.
6. **Sürü bombardımanı** (§10.6): ayrı görev olsun mu? Belirsizlik ±10 kat. Öneri: sürüm 2'de, `sim.gd`'de ölçülen tek bir sayıyla
   (günde sürü gücünün %1–3'ü) ve yalnız DÜŞMÜŞ eyaletlerde.
7. **Havadan ikmal** (§10.3) yeni `AirWing.Mission` ister. Sürüm 1'e alınmalı mı? Kuşatma mekaniği onsuz da işliyor.
8. **Yem ateşi:** topçu ya da gemi topuyla sürüyü bilerek bir öldürme alanına çekmek (04'teki top sesi çekimini tersine kullanmak). Ordu
   başına bir "ateş düzeni" ayarı (normal / kısa atış / yem) ister (`Army` alanı + arayüz). Güçlü bir oyuncu aracı olabilir, ama
   yapay zekâ için zor. Değer mi?
9. **Destek bölüğü sınırı** (K11) yapılmazsa oyuncu 10 alev bölüğüyle PA'yı şişirebilir. Alternatif: bölüğün PA'sı şablonda birden fazla
   olursa azalan getiriyle (1 / 0,5 / 0,25) toplansın. Hangisi?
10. **Yerel birlik:** tümenlerin hangi eyaletten toplandığı motorda yok. "Tanıdık Yüzler" olayı bu yüzden genel. Tümen kökeni (kayıtta bir
    eyalet kimliği) eklenirse olay ve yorgunluk yerel olabilir. Değer mi?
11. ~~**Moda özgü veri dosyaları**~~ — **Çözüldü:** altyapıya karşılık aranmayan `own/` klasörü eklendi (14_teknik_plan.md §2.1).
12. **Bu belgede doğrulanamayan tarihî ayrıntılar** (web erişimi kapalıydı): 1920 Kırım tahliyesinin gemi ve kişi sayısı; Dunkerque'nin
    9 gün / 338.000 sayısı; İkinci Dünya Savaşı kuşatma hava ikmallerinin ihtiyaç karşısındaki oranı; 1900 Honolulu'da veba için yapılan
    denetimli yakmanın mahalleye sıçraması (O4 dayanağı); 1936–37'de İspanya'da kuşatılmış bir mevziye havadan ikmal atılması; Çatalca
    hattının 1912'deki uzunluğu; Swank ve Marchand'ın "60 gün" bulgusunun kesin ifadesi; dönemin nakliye uçağının yolcu sayısı (17); 1915 elektrikli telinde ölenlerin
    sayısı; 1 konvoy birimi ≈ 10 okyanus gemisi oranı (İngiliz ticaret filosunun 1930'ların sonundaki gemi sayısı).
    Yayından önce birincil kaynaklarla denetlenmeli; denetim sonucu sayıyı değiştirirse ilgili tablo güncellenir.

## 20. Kaynaklar

**01–06'da doğrulanmış olup burada yeniden kullanılanlar**
- Munz, P., Hudea, I., Imad, J., Smith, R. J. (2009). When zombies attack!: Mathematical modelling of an outbreak of zombie infection. —
  https://www.researchgate.net/publication/228509313_When_zombies_attack_mathematical_modelling_of_an_outbreak_of_zombie_infection
- Alemi, A. A. ve ark. (2015). You can run, you can hide: The epidemiology and statistical mechanics of zombies. *Phys. Rev. E* 92. — https://arxiv.org/abs/1503.01104
- Cleaveland, S. ve ark. (2002). Estimating human rabies mortality in the United Republic of Tanzania from dog bite injuries (ısırık yeri).
  *Bull. WHO* 80(4). — https://www.scielosp.org/article/bwho/2002.v80n4/304-310/
- Couzin, I. D. ve ark. (2005). Effective leadership and decision-making in animal groups on the move. *Nature* 433. — https://www.nature.com/articles/nature03236
- Horbec, I. At the Gates of Christian Europe: The Quarantines on the Habsburg–Ottoman Border. —
  https://www.researchgate.net/publication/274962221_At_the_Gates_of_Christian_Europe_The_Quarantines_on_the_Habsburg-Ottoman_Border_18th-19th_Century
- Askerî sınırda veba, kontumaz ve karantina. *Hrčak.* — https://hrcak.srce.hr/clanak/376728
- Habsburg veba kordonunun başarısı. — https://www.researchgate.net/publication/319857853_The_Austrian_success_of_controlling_plague_in_the_18th_century_maritime_quarantine_methods_applied_to_continental_circumstances
- 1910–11 Mançurya vebası: demiryolu karantinası, ev ev arama, maske. — https://pmc.ncbi.nlm.nih.gov/articles/PMC7110523/
- Hatchett, R. J., Mecher, C. E., Lipsitch, M. (2007). Public health interventions and epidemic intensity during the 1918 influenza pandemic. *PNAS* 104(18). — https://www.pnas.org/content/104/18/7582
- Ewald'ın 1918 hipotezi (siper ve sahra hastanesi). *Evolution, Medicine, and Public Health* (2018). — https://academic.oup.com/emph/article/2018/1/219/5088155
- 1918 Samoa. *NZ History.* — https://nzhistory.govt.nz/culture/1918-influenza-pandemic/samoa
- Rusya kolera ayaklanmaları 1830–31. — https://www.unm.edu/~ybosin/documents/rus_chol.pdf
- İngiliz ordusunda bakteriyoloji ve seyyar laboratuvarlar 1850–1918. — https://pubmed.ncbi.nlm.nih.gov/20919615/
- Sydney Domville Rowland ve 1 No'lu Seyyar Laboratuvar. — https://en.wikipedia.org/wiki/Sydney_Domville_Rowland
- Birinci Dünya Savaşı hastane trenleri. *National Railway Museum.* — https://www.railwaymuseum.org.uk/objects-and-stories/ambulance-trains-bringing-first-world-war-home
- Polonya tifüs salgını ve Milletler Cemiyeti Salgın Komisyonu. — https://pmc.ncbi.nlm.nih.gov/articles/PMC11675154/
- İngiltere'de hava saldırısı önlemleri (1937–1939). *Imperial War Museums.* — https://www.iwm.org.uk/history/how-britain-prepared-for-air-raids-in-the-second-world-war
- Cenevre Sözleşmesi I (1949), madde 44: amblemin kullanımı. *ICRC.* — https://ihl-databases.icrc.org/en/ihl-treaties/gci-1949/article-44
- Farnell, A. (2010). *Designing Sound.* MIT Press. — https://mitpress.mit.edu/9780262014410/designing-sound/
- Roads, C. (2001). *Microsound.* MIT Press. — https://mitpress.mit.edu/9780262681544/microsound/
- Leningrad kuşatması (1941–44). — https://www.britannica.com/event/Siege-of-Leningrad

**Bu belgede eklenenler** (yazarın bilgisine dayanır; bu oturumda erişilemedi, yayından önce denetlenmeli)
- Swank, R. L., Marchand, W. E. (1946). Combat neuroses: Development of combat exhaustion. *Archives of Neurology and Psychiatry* 55(3). —
  https://doi.org/10.1001/archneurpsyc.1946.02300140067004
- Litz, B. T. ve ark. (2009). Moral injury and moral repair in war veterans: A preliminary model and intervention strategy.
  *Clinical Psychology Review* 29(8). — https://doi.org/10.1016/j.cpr.2009.07.003
- Quarantelli, E. L. (1954). The nature and conditions of panic. *American Journal of Sociology* 60(3). — https://doi.org/10.1086/221536
- Clarke, L. (2002). Panic: Myth or reality? *Contexts* 1(3). — https://doi.org/10.1525/ctx.2002.1.3.21
- Drury, J., Cocking, C., Reicher, S. (2009). Everyone for themselves? A comparative study of crowd solidarity among emergency survivors.
  *British Journal of Social Psychology* 48. — https://doi.org/10.1348/014466608X357893
- Jendrny, P. ve ark. (2020). Scent dog identification of samples from COVID-19 patients – a pilot study. *BMC Infectious Diseases* 20. —
  https://doi.org/10.1186/s12879-020-05281-3
- Rostker, B. D. ve ark. (2008). Evaluation of the New York City Police Department Firearm Training and Firearm-Discharge Review Process
  (stres altında isabet oranları; nişancı ve jandarma ateş değerlerinin sınaması için). RAND MG-717. — https://www.rand.org/pubs/monographs/MG717.html
- 1925 Cenevre Protokolü (boğucu ve zehirli gazların yasaklanması). *UNODA.* — https://www.un.org/disarmament/wmd/bio/1925-geneva-protocol/
- Kara mayınlarını yasaklayan sözleşme (1997; mayının sivil yükü üzerine). — https://www.apminebanconvention.org/
- Belçika–Hollanda sınırındaki öldürücü elektrikli tel (1915). — https://en.wikipedia.org/wiki/Wire_of_Death
- Yser Muharebesi ve 1914 su baskını. — https://en.wikipedia.org/wiki/Battle_of_the_Yser
- Çatalca hattı (1912). — https://en.wikipedia.org/wiki/First_Battle_of_%C3%87atalca
- Hadrianus Suru (gözetleme kuleleri ve kaleler). — https://en.wikipedia.org/wiki/Hadrian%27s_Wall
- Ellis Adası ve göçmen sağlık muayenesi. — https://en.wikipedia.org/wiki/Ellis_Island
- Flammenwerfer 35 (dönemin taşınabilir alev silahı). — https://en.wikipedia.org/wiki/Flammenwerfer_35
- Universal Carrier (1930'ların hafif paletli taşıyıcısı). — https://en.wikipedia.org/wiki/Universal_Carrier
- Junkers Ju 52 (dönemin nakliye uçağı). — https://en.wikipedia.org/wiki/Junkers_Ju_52
- Dunkerque tahliyesi (1940). — https://www.britannica.com/event/Dunkirk-evacuation
- Gelibolu seferi ve 1915–16 çekilmesi. — https://www.britannica.com/event/Gallipoli-Campaign
- Wrangel'in filosu ve 1920 Kırım tahliyesi. — https://en.wikipedia.org/wiki/Wrangel%27s_fleet
- Alcázar kuşatması (1936). — https://en.wikipedia.org/wiki/Siege_of_the_Alc%C3%A1zar

**Depo içi**
- `game/autoload/military.gd` (muharebe, cephe, ikmal, siper, toparlanma, takviye, yakıt, karargâh), `game/core/division.gd`, `game/core/army.gd`,
  `game/autoload/air.gd` (`bonus`, `_ai`), `game/autoload/navy.gd` (`SHIPS`, `strait_blocked`, `_transports`), `game/autoload/diplomacy.gd`
  (`at_war`), `game/autoload/politics.gd`, `game/autoload/economy.gd` (`convoy_factor`, inşaat), `game/core/mode_rules.gd`,
  `game/map/unit_models.gd`, `data/common/units.json`, `data/common/equipment.json`, `data/common/buildings.json`,
  `data/map/provinces.json`, `data/map/states.json`, `data/map/cities.json`, `data/map/straits.json`, `data/history/states_1936.json`,
  `docs/modlar/README.md`, `docs/modlar/zombi/01`–`06`.

---

## Ek A — Motor taklidi (yeniden üretmek için)

`Military._resolve_battle`, `_apply_hits`, `_frontline`, `attack_mod`/`defend_mod` ve `entrenchment` Python'a birebir aktarıldı. Rastgelelik
ortalamasında (×1,0) koşuldu. Kısaltılmış çekirdek:

```python
ORG_DMG, STR_DMG, HIT_DEF, HIT_OPEN, RETREAT = 0.0367, 0.022, 0.1, 0.4, 0.12
def hits(per, dfn):                       # _apply_hits
    return HIT_DEF * min(per, dfn) + HIT_OPEN * max(per - dfn, 0.0)
# her saat:
#   ön saf = org'a göre sıralı, toplam genişlik ≤ arazi_genişliği × 1,34
#   saldırı = Σ (PA·(1−karşı_sertlik) + TA·karşı_sertlik) · güç · çarpan · tecrübe      (UND: tecrübe 1,0)
#   savunana: per = saldırı / n_savunan;  dfn = savunma · güç · (1 + siper · (0,15 + ek))
#   saldırana: per = karşı_saldırı / n_saldıran;  dfn = şok · güç · (1 − engel_şok)        (08: engel yalnız UND saldırırken)
#   bütünlük −= isabet · ORG_DMG · (ilk 24 saatte 1,3);  güç −= isabet · STR_DMG / can
#   UND çarpanı = 1 + arazi(UND tablosu) − engel;  savunan çarpanı = 1 − 0,5 (bütünlük < %12 iken)
#   çözülme: bütünlük < %12 → UND dağılır; savunan çekilir ("son askere kadar": güç < %4 → yok olur)
```

**Doğrulama:** 04 §3.3'ün sekiz sonucunun hepsi aynı çıktı: 1 / 2 / 3 sürü → 11 / 27 / 57 saatte dağıldı; 4 sürü → 52 saatte çekildi;
2 sürü → garnizon 104 saatte çekildi; arındırma ovada 10, kentte 15 saat (04'te 14; yuvarlama). Bu belgenin bütün muharebe sayıları
(§3.6, §5.1, §12) aynı betikle üretildi. Senaryo adları: B1 kordon savunması, B2 sessiz kordon, B3 kent arındırması, B4 "son askere
kadar", B5 Kösemen + Kaputlu, B6 Gecegezer ve köpek, B7 Seğirtken ve seyyar kol, B8 kent savunması, B9 aynı bölgede iki tümen. Betik,
salgın modeli uygulandığında `tests/test_zm_military.gd`'ye (§18.1 madde 1–2) dönüştürülmelidir.
