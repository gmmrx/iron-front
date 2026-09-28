# Zombi modu — 09 Siyaset, olaylar ve diplomasi

> **Özet.** Bu belge *Gri Kordon* modunda devletin salgın altında nasıl yönetildiğini, nasıl çöktüğünü ve öteki devletlerle nasıl
> konuştuğunu tanımlar. Kararlar 01_vizyon.md ve 02_oynanis_dongusu.md'ye, sayılar 03–07'ye dayanır.
> - **Üç gösterge kalır:** istikrar, halkın dayanma iradesi (motorda `war_support`) ve nüfuz. Modda bunlara salgından beslenen,
>   formülü yazılı terimler eklenir. 02'nin 4. açık sorusu burada kesinleşir: KSE 20'ye kadar dayanma iradesine puan başına +%0,3,
>   20'nin üstünde puan başına −%0,2. Ayrıca ulusal ralli, umut, yerel dehşet, kayıp ve önlem yorgunluğu terimleri vardır.
> - **Başlangıçtaki dayanma iradesi** 1936'nın savaş isteğinden değil, kurumlara güvenden türetilir:
>   `0,35 + 0,3·(etkin istikrar − 0,5)`. Ülkeler 0,26 ile 0,47 arasında başlar; medyan 0,35'tir.
> - **Beş yeni yasa grubu, 20 basamak:** Karantina Politikası, Olağanüstü Yönetim (sıkıyönetim dahil), Sivil Savunma, Basın ve Bilgi,
>   Zorunlu Hizmet. Tayınlama 07'deki Gıda Politikası grubudur ve bu belgede yeniden tanımlanmaz.
> - **İdeolojiler kalır.** Yanlarına dört **kriz tutumu** gelir: Önce Sağlık, Önce Düzen, Önce Geçim, Dayanışma. Hükümetin kamuoyuna
>   uyumu istikrarı ±%6 değiştirir ve iktidar partisini seçime taşır ya da seçimde düşürür.
> - **Devlet çöküşü bir durum makinesidir:** Ayakta → Sarsılmış → Parçalanan → Çökmüş. Kopan eyaletler 24 yuvalık bir havuzdan
>   *geçici yönetim* ya da *askerî valilik* olur. Komşular bu toprakları koruma altına alabilir; toprağı sahibine iade etmek ödüllendirilir.
> - **Diplomasi dört yeni değerle işler:** ilişki (−100…+100), itibar (0–100), şeffaflık (0,3–1,0) ve yardım puanı (0–1).
>   Diplomasi panelinde 12 eylem vardır. Yapay zekânın yürüttüğü **Uluslararası Karantina Konseyi** ayda bir toplanır ve dokuz karar
>   tasarısından birini oylar.
> - **36 seçenekli olay ve 6 olay zinciri** vardır. Motora 7 küçük kanca gerekir; bunların ikisi (S1 ve S4) zorunludur.

---

## 1. Kapsam, ilkeler ve motorla ilişki

### 1.1 Bu belge neyi kesinleştirir?

| Konu | Bu belgede | Başka belgede |
|---|---|---|
| İstikrar, dayanma iradesi, nüfuz formülleri; 02'nin 4. açık sorusu | **Kesinleşir** | Ekonomik baskılar (açlık, karaborsa, mülteci yükü): 07_ekonomi_ve_nufus.md §9 |
| Karantina, olağanüstü yönetim, sivil savunma, basın, zorunlu hizmet yasaları | **Kesinleşir** | Önlemlerin salgın modelindeki etkisi: 03_salgin_modeli.md §7. Gıda Politikası (`zm_rationing`): 07 §3.7 |
| Kriz tutumları, seçimler | **Kesinleşir** | Kabine Üslubu ve doktrin dalları: 06_teknoloji_ve_yetenek_agaci.md §4 |
| Devlet çöküşü, parçalanma, koruma altına alma, devletler arası savaş (01'in 3. açık sorusu) | **Kesinleşir** | Oyuncunun kaybetme koşulları: 02 §4.2 |
| İlişki, itibar, şeffaflık (03 §8.2'nin katsayısı), yardım puanı (02 §4.1'in normalize edilmesi) | **Kesinleşir** | Bulgu paylaşımı, ortak enstitü ve komisyon: 05_arastirma_merkezleri.md §9. Temiz Liman Anlaşması'nın ekonomisi: 07 §7.4 |
| Uluslararası Karantina Konseyi (05'in 8. açık sorusu: komisyon ve havuzu yapay zekâ nasıl yürütür) | **Kesinleşir** | Haftalık bülten: 02 §1.2, 03 §8.2 |
| Siyasi ve diplomatik olaylar (36) | **Bu belge** | Evre açılış olayları ve İç Çöküş: 02 §3.4, §4.2. Bilim olayları: 05 §10. Mülteci ve istifçi olayları: 07 §10. Tür olayları: 04 §9. Kordon ordusu ve askerî moral olayları: 08_askeri_ve_savunma.md |

### 1.2 İlkeler

| İlke | Uygulama |
|---|---|
| Oyuncu karar verir (CLAUDE.md kural 1) | Hiçbir yasa, sınır, anlaşma ya da oy oyuncu adına verilmez. Oyuncunun ülkesini etkileyen dünya olayları (ayrılan eyaletler, darbe girişimi) seçenekli olay olarak gelir. Yapay zekâ ülkeleri aynı kurallarla otomatik oynar |
| Her önlemin bedeli var (01 Sütun 3) | Her yasa basamağı en az bir göstergeden (istikrar, fabrika, itibar, nüfuz) bir şey alır. Sert önlemler ayrıca "önlem yorgunluğu" biriktirir (§2.3) |
| Kötülük ödüllendirilmez (01 §6.2, §6.4) | Hiçbir seçenek sivile şiddeti, günah keçisi göstermeyi, rızasız deneyi ya da toprak kapmayı sayıyla ödüllendirmez. Bu yollar yalnız bedel doğurur. Ret seçenekleri vardır ama puan getirmez |
| Rejimlerin suçları aklanmaz (01 §6.5) | "Kamp", "sürgün", "tasfiye" çözüm olarak sunulmaz. İdeoloji yalnız **devlet kapasitesi** farkı yaratır (§2.7) |
| Gerçek kişi yok | Olaylarda bakan, vali, general **makam** olarak geçer. Darbe olayında lider adı yerine "Askerî Yönetim Kurulu" yazar (`set_leader`) |
| Veri güdümlü (kural 2) | Yasalar `laws.patch.json`, olaylar `events.patch.json`, formül katsayıları `own/politics.json` içindedir (§10). Motor "sıkıyönetim" ya da "Konsey" sözcüğünü bilmez |

### 1.3 Motorun bugünkü siyaset ve diplomasi yetenekleri (kod okundu)

| Parça | Bugün | Bu mod için sonucu |
|---|---|---|
| Etki sözlüğü (`Politics._apply`) | `pp`, `stability`, `war_support`, `tension`, `spirit`, `remove_spirit`, `research_slot`, `research_bonus`, `building`, `resource`, `equipment`, `add_divisions`, `popularity`, `war_goal`, `give_war_goal`, `declare_war`, `join_war_of`, `guarantee`, `grant_access`, `white_peace_with`, `annex`, `annexed_by`, `cede_border_to`, `cede_city_to`, `create_faction`, `join_faction`, `invite`, `event`, `flag_target`, `news`, `set_leader`, `ai_only`; bilinmeyen anahtar `Game.rules.apply_effect`'e gider | Yeni etkiler yalnız `rules.gd`'de (`effect_keys` / `apply_effect` / `describe_effect`) tanımlanır (§10.5) |
| Şartlar (`Politics.check`) | `date`, `has_focus`, `exists`, `tension`, `ideology`, `leader`, `allied_with`, `at_war_with`, `has_flag`, `at_war`, `enemies_at_war`, `owns_city_not`, `not`; bilinmeyen anahtar `Game.rules.check_condition`'a gider | **İstikrar ya da iç cephe şartı yok**; mod ekler (`zm_stability_below` vb.) |
| Olay tetiği (`_scheduled_events`) | Yalnız "şu ülkeye, şu tarihte, bir kez" | Şarta bağlı olaylar `rules.gd` içindeki bir dağıtıcıyla gönderilir (`Politics.fire_event`). Motor değişmez (§7.1) |
| Olay metni (`event_popup.gd`) | Sabit metin; `{country}` gibi yer tutucu yok | S7 kancası; yoksa genel metin |
| Yasa (`Economy.law_block_reason`, `change_law`) | Şart yalnız `war_support`, `at_war`, `authoritarian_or_at_war`; bedel her yasada **150** | S2 ve S3 kancaları |
| Seçim (`Politics._elections`) | Savaştaki ülkede seçim ertelenir; kazanan, popülerliği %50'yi aşan ideolojidir | `UND` herkesle savaşta olduğu için (03 §10) S1 yapılmazsa **bütün seçimler oyun boyunca ertelenir** |
| İç cephe (`Politics.war_support`) | Taban + modifier + kriz endeksi (%1 başına +%0,4) + savunma savaşı (+%20) | S1 yapılmazsa her ülke `UND` savaşından kalıcı +%20 alır; `any_war()` gerginliği günde +0,05 artırır |
| Teslim (`Diplomacy._surrender_progress`, `capitulate`) | Yalnız savaştaki ülkeler denetlenir; işgal edilen eyaletler **işgalciye geçer** | S4 yapılmazsa düşmüş eyaletlerin sahibi `UND` olur. Bu, 07'deki "düşmüş eyaletin sahibi değişmez" kuralını bozar |
| İlişki / itibar | **Yok.** Ülkeler arası tutum, kamuoyu, itibar tutulmuyor | Mod kendi dizilerinde tutar (`rules.gd` durumu, kayda girer) |
| Ülke yaratma | **Yok.** 80 ülke `countries.json`'dan gelir; renk indeksi 1..255 | S5: "uyuyan ülke" havuzu |
| Diplomasi paneli (`diplomacy_panel.gd`) | `_action(ikon, metin, ipucu, hata, işlev)` satırları | S6 kancası; yoksa eylemler Salgın panelinde durur |

### 1.4 Motor kancaları (içerikten bağımsız; WWII modunda etkisiz)

Mod rehberindeki kural geçerlidir: motor dosyasına dokunmak için insan onayı gerekir ("dur ve sor", docs/modlar/README.md).

| # | Kanca | Yer | İş | Yapılmazsa |
|---|---|---|---|---|
| **S1** | Savaş kaydına isteğe bağlı `"kind": "outbreak"`. `at_war(tag, include_outbreak := false)`; `any_war()`, `war_state_support`, `_elections`, yapay zekânın savaş denetimleri salgın savaşını saymaz. `are_enemies` ve teslim denetimi sayar. 08_askeri_ve_savunma.md'deki K10 kancasıyla aynıdır; bu belge onu teslim denetimi, gerginlik ve seçimleri de kapsayacak biçimde genişletir | `diplomacy.gd`, `politics.gd`, `ai.gd` | ~12 satır | **Zorunlu.** Seçimler hiç yapılmaz, herkes +%20 iç cephe alır, gerginlik 1.461 günde 73'e tırmanır (08'deki B2 bulgusu) |
| S2 | Yasanın `requires` alanındaki bilinmeyen anahtarlar mod şartına gider (`Game.rules.check_condition`); ipucu 06'daki M8 `describe_condition` ile yazılır | `economy.gd` (`law_block_reason`) | ~4 satır | Evre kapısı olmaz, yalnız `war_support` eşiği kalır |
| S3 | Yasaya isteğe bağlı `cost`; gruba isteğe bağlı `relax_cost` (listede aşağı inerken) | `economy.gd` (`can_change_law`, `change_law`), `politics_panel.gd` | ~6 satır | Her basamak 150 nüfuz tutar; gevşetmek sıkılaştırmak kadar pahalı olur |
| **S4** | `ModeRules.on_capitulate(c) -> bool` (`true` dönerse motorun `capitulate`'i çalışmaz) | `diplomacy.gd` | ~3 satır | **Zorunlu.** Düşmüş eyaletler `UND`'ye devredilir |
| S5 | `countries.json` kaydında `"dormant": true` (kuruluşta atlanır); `World.activate_country(tag, states, parent)` ve `World.deactivate_country(tag)`; `Military.transfer_divisions(from, to, states)` | `world.gd`, `military.gd`, `game.gd` (kayıt) | ~35 satır + test | Parçalanma olmaz; çöken ülkenin kalan eyaletleri "yönetimsiz" kalır ve yalnız koruma altına alınabilir |
| S6 | `ModeRules.diplomacy_actions(me, t) -> Array` (`{icon, text, tip, err, id}`) ve `do_diplomacy_action(id, me, t)` | `diplomacy_panel.gd` | ~12 satır | Eylemler Salgın panelinin "Hükümet ve Dünya" sekmesinde ülke tablosundan verilir |
| S7 | Bekleyen olaya `args` (`{"country": ..., "state": ...}`); başlık ve açıklama `String.format(args)` ile doldurulur | `politics.gd` (`fire_event`), `event_popup.gd` | ~6 satır | Metinler yer tutucusuz yazılır; ad bildirim akışında görünür |

Kanca listesi 06 §2.2'deki M1–M8 ve 07 §1.4'teki M1–M3 ile çakışmaz. S2 ve M8 birlikte çalışır.

## 2. Hükümetin kriz altındaki durumu

### 2.1 Üç gösterge

| Gösterge | Motorda | Modda anlamı | Modda neyi belirler |
|---|---|---|---|
| **İstikrar** | `Politics.stability` | Devletin işleyişi: memur işe gelir mi, emir uygulanır mı? | Motorun etkileri aynen geçerlidir: %50'nin altında fabrika −%1/puan, inşaat −%0,5/puan. Modda ayrıca önlemlere **uyum** (§2.5) ve İç Çöküş (02 §4.2) |
| **Halkın dayanma iradesi** | `Politics.war_support` | Halkın bedel ödemeye razı olması | Teslim sınırı: `0,8 − max(0,5 − irade; 0)·0,6`, en az 0,2 (motor). Sert yasaların şartı. Gıda yasalarının şartı (07 §3.7) |
| **Nüfuz** | `political_power` | Hükümetin siyasi sermayesi | Yasa, danışman, karar, diplomasi eylemi, Konsey aidatı, olay seçenekleri |

### 2.2 Başlangıçtaki dayanma iradesi

1936 verisindeki `war_support`, **savaşa gitme isteğini** ölçer. Demokrasilerde bu değer barışçı kamuoyu yüzünden düşüktür: ABD 0,05, İngiltere 0,15.
Ülkeye özgü ulusal durumlar da (ör. Türkiye'nin Reformlara Direnç ve Yeniden Yapılanan Ordu durumları, toplam −0,30) bu değeri
düşürür. Oysa bir salgında dayanma iradesi, halkın kurumlara güvenine bağlıdır. Liberya'da 2014 Ebola salgınında yapılan anket,
hükümete güvenmeyenlerin salgın önlemlerine daha az uyduğunu gösterdi (Blair, Morse ve Tsai 2017). COVID-19 sırasında Avrupa
bölgelerinde de kurumlara güven, hareketlilik kısıtlamalarına uyumla birlikte arttı (Bargain ve Aminjonov 2020). Bu yüzden mod
başlangıçta ulusal durumları silmez; yalnız tabanı ayarlar ve **etkin** iradenin şu değere eşit olmasını sağlar:

```
R0_c = clamp( 0,35 + 0,3 · (etkin_istikrar_c − 0,5) ; 0,20 ; 0,50 )
c.war_support = R0_c − c.mod("war_support")          (on_new_game, bir kez)
```

- **0,35:** Motorun teslim sınırı irade 0,5'in altında düşmeye başlar. 0,35'te sınır 0,71'dir: ortalama bir ülke zafer puanlarının
  %71'ini kaybetmeden çökmez. Bu değer 02'nin denge hedefiyle uyumludur (bitişte 1–25 çökmüş ülke).
- **0,3 eğim:** İstikrar farkının üçte birinden azı iradeye yansır. Güven bir etkendir ama tek etken değildir.
- **Sonuç** (80 ülke; etkin istikrar parti popülerliği ve ulusal durumlarla hesaplandı): en düşük İspanya 0,26, medyan 0,35, en yüksek
  ABD 0,47. Örnekler: Türkiye 0,35 · İngiltere 0,47 · Almanya 0,44 · SSCB 0,29 · Polonya 0,34.

### 2.3 Dayanma iradesinin salgın terimleri

`rules.gd` terimlerin toplamını her gün hesaplar. Toplam, bir önceki günün toplamından farkı kadar `c.war_support`'a eklenir
(**delta yöntemi**). Böylece olayların kalıcı `war_support` etkileri silinmez ve motor değişmez. Döküm, Salgın panelinde gösterilir (§11).

```
T_irade = T_KSE + T_ralli + T_umut − T_yerel − T_kayıp − T_yorgunluk

T_KSE        = 0,003 · min(KSE, 20) − 0,002 · max(KSE − 20, 0)               [+0,06 … −0,10]
T_ralli      = 0,10 · max(0, 1 − (gün − ilk_vaka_günü) / 180)                  [0 … +0,10]
T_umut       = 0,04·[serum anavatanda dağıtılıyor] + 0,06·[aşı dağıtılıyor]
               + 0,01 · min(6, temizlenen anavatan eyaleti)                      [0 … +0,16]
T_yerel      = 0,20 · YE_algı                                                    [0 … 0,20]
T_kayıp      = min(0,20 ; 0,5 · D_anavatan / N⁰_anavatan)                        [0 … 0,20]
T_yorgunluk  = min(0,12 ; 0,01 · F)                                              [0 … 0,12]
```

| Terim | Gerekçe |
|---|---|
| T_KSE | 02'nin önerisi aynen kabul edildi. KSE, motordaki kriz endeksinin salgındaki karşılığıdır. Temel oyunda kriz endeksi iç cepheye puan başına +%0,4 ekler. Modda uzak bir salgının birleştirici etkisi bundan zayıftır (+%0,3). KSE 20'yi geçince dünya çapındaki yıkım dehşete dönüşür. KSE 50'de terim sıfırdır, 100'de −%10'dur |
| T_ralli | "Bayrak etrafında toplanma" etkisi kısa sürer (Mueller 1970). Danimarka'da Mart 2020'deki kapanmanın ardından kurumlara güven arttı (Baekgaard ve ark. 2020). Motor savunma savaşına +%20 verir. Yüzü olmayan bir hastalığa bunun yarısı verildi (+%10) ve etki 180 günde doğrusal olarak söner |
| T_umut | İyi haber de iradeyi besler. Serum ve aşı, oyuncuya "zaman kazandırmanın bir sonu var" duygusunu verir. Değerler kendi tahminimizdir; aşının payı daha büyüktür, çünkü salgını bitiren odur (01 Sütun 4) |
| T_yerel | `YE_algı`, anavatandaki **yerel salgın endeksidir**: KSE formülünün yalnız kendi eyaletlerine uygulanmış hâli (02 §3.1). Sayı bildirilen vakalarla hesaplanır ve basın yasasının panik çarpanıyla çarpılır (§3.5). Halk gerçek sayıyı değil, duyduğunu bilir (01 Sütun 2). Nüfusun yarısı salgın eyaletlerindeyse terim −%10 olur |
| T_kayıp | 1918 salgını ABD'de nüfusun yaklaşık binde 6'sını öldürdü; Batı Samoa'da bu oran %22 oldu (01). Nüfusun %10'u ölürse terim −%5'tir. Tavana (−%20) ancak Batı Samoa'dan ağır bir kayıpla (%40) ulaşılır |
| T_yorgunluk | `F`, **önlem yorgunluğu** puanıdır. Sert bir yasanın yürürlükte olduğu (§3'te `zm_strict` işaretli basamaklar) her 30 günde +1 artar; hiç sert yasa yokken her 30 günde −2 azalır; tavanı 12'dir. Dünya Sağlık Örgütü Avrupa Bölgesi 2020'de, uzun süren kısıtlamalar altında halkın motivasyonunun zamanla düştüğünü "salgın yorgunluğu" adıyla tanımladı. San Francisco'da ikinci maske zorunluluğu Ocak 1919'da gelince birkaç gün içinde Maske Karşıtı Birlik kuruldu. Bir yıl kesintisiz sert önlem −%12'ye mal olur |

**Örnek gidiş** (Salgın zorluğu; ilk vaka 60. günde; anavatan için tipik YE ve kayıp değerleri; zorunlu karantina 60. günden beri yürürlükte):

| Gün | KSE | YE_algı | Ölen payı | F | Umut | T_irade | Türkiye (R0 0,35): irade / teslim sınırı | İngiltere (0,47) | SSCB (0,29) |
|---|---|---|---|---|---|---|---|---|---|
| 30 | 0,4 | 0 | 0 | 0 | 0 | +0,001 | 0,35 / 0,71 | 0,47 / 0,78 | 0,29 / 0,67 |
| 90 | 3 | 0,02 | 0 | 1 | 0 | +0,078 | 0,43 / 0,76 | 0,55 / 0,80 | 0,37 / 0,72 |
| 180 | 12 | 0,12 | %0,4 | 4 | 0 | +0,003 | 0,35 / 0,71 | 0,47 / 0,78 | 0,29 / 0,68 |
| 300 | 30 | 0,30 | %2 | 8 | 0 | −0,110 | 0,24 / 0,64 | 0,36 / 0,71 | 0,18 / 0,61 |
| 420 | 45 | 0,35 | %5 | 12 | +0,04 | −0,165 | 0,18 / 0,61 | 0,30 / 0,68 | 0,12 / 0,58 |
| 600 | 25 | 0,15 | %7 | 10 | +0,06 | −0,055 | 0,29 / 0,68 | 0,41 / 0,75 | 0,23 / 0,64 |
| 900 | 8 | 0,03 | %8 | 4 | +0,14 | +0,078 | 0,43 / 0,76 | 0,55 / 0,80 | 0,37 / 0,72 |

420. gündeki çukur, oyunun "Kuşatma" perdesine (02 §1.4) denk gelir. Bu noktada Türkiye'nin sınırı 0,61'dir: zafer puanlarının %61'i
düşerse ülke çöker. İradeyi yükseltmenin yolları şunlardır: 06'daki doktrinler (`war_support` +0,03/+0,05), Basın ve Yayın Bakanı (+%8, temel
oyun), Dayanışma Tahvilleri kararı (§3.8), yorgunluğu azaltmak (gevşetmek ya da Karantina Affı) ve serumu bulmak.

### 2.4 İstikrarın salgın terimleri

İstikrar da aynı delta yöntemiyle güncellenir:

```
T_istikrar = − 0,10 · YE_algı                       (korku; 02 §2.5 "salgın istikrarı düşürür")
             − 0,15 · düşmüş_pay                    (anavatan 1936 nüfusunun DÜŞMÜŞ eyaletlerdeki payı)
             + 0,06 · A                             (kriz tutumlarına uyum, §4.4; −1 … +1)
```
Yasalar, ulusal durumlar ve 07'deki açlık, karaborsa ve mülteci yükü kademeleri motorun normal yolundan (`Country.mod`) gelir.

**Örnek istikrar defteri: Türkiye, 300. gün** (taban 0,50 = 1936 değeri, ulusal durumlar ve parti; YE_algı = bildirilen 0,24 × Haber Denetimi 0,7):

| Kalem | Değer |
|---|---|
| 1936 etkin istikrar | 0,500 |
| Korku (−0,10 × 0,168) | −0,017 |
| Düşmüş pay (%5) | −0,008 |
| Kriz tutumlarına uyum (A = 0,53, §4.5) | +0,032 |
| Zorunlu Karantina | −0,080 |
| Olağanüstü Yetki Kanunu | −0,020 |
| Haber Denetimi | +0,020 |
| Karne (07 §3.7) | −0,030 |
| **Toplam** | **0,397** |

İstikrar %40'ın altında olduğu için fabrika çıktısı −%10 ve inşaat −%5 ceza alır (motor). Oyuncu sert önlemi yalnız **bulaşla** değil,
fabrika çıktısıyla da öder: Sütun 3'ün sayıdaki karşılığı budur.

### 2.5 Uyum: önlemin gücü istikrara bağlıdır

Karantina, sokağa çıkma yasağı ve bilgilendirme gibi davranışa dayalı önlemler, halk uyduğu ölçüde işe yarar. 03 §7'deki birleşik
bulaş azaltması `m` şöyle ölçeklenir:
```
u     = clamp( 1 + 0,8 · min(0 ; istikrar − 0,5) + c.mod("zm_compliance") ; 0,5 ; 1,1 )
m_etk = min( 0,75 ; u · m )
```
- **İstikrar %50 ve üstündeyse u = 1:** 03'ün tablolarındaki değerler aynen geçerlidir.
- İstikrar %20'de u = 0,76 olur: Zorunlu Karantina'nın %35'lik etkisi %27'ye iner. Referans eyalette R₀ 2,02 yerine 2,19 olur.
- Uyum yalnız davranışsal önlemleri (`zm_beta_mult`) etkiler. Garnizon ve sivil bastırma (κ) uyumdan bağımsızdır: bunlar silahlı güçtür.
- `zm_compliance` rejim durumlarından (§2.7), Tam Sansür'den (−0,05) ve bazı olay seçeneklerinden gelir.

### 2.6 Nüfuz bütçesi

Motorun kuralı değişmez: nüfuz günde 2 × (1 + katkılar + istikrar etkisi) gelir. Yani yılda yaklaşık 730 puan. Olağanüstü Yetki
Kanunu (+%15) ve Olağanüstü Hal Kabinesi (06, +%15) bunu yaklaşık 950'ye çıkarır.

| Harcama (ilk yıl, tipik) | Nüfuz |
|---|---|
| Karantina Politikası: Gönüllü → Zorunlu Karantina (S3: hedef basamağın bedeli) | 150 |
| Olağanüstü Yetki Kanunu | 100 |
| Resmî Sağlık Bültenleri | 50 |
| Sağlık Hizmeti Yükümlülüğü | 75 |
| Sivil Savunma Teşkilatı | 50 |
| İki danışman (06 §4.9 kabine uzmanları) | 300 |
| Konsey aidatı + gözetim havuzu (05) | 25 + 40 |
| Olay seçenekleri (ortalama 5 × 30) | 150 |
| Diplomasi (bir bulgu paylaşımı, bir ortak kordon paktı) | 90 |
| **Toplam** | **~1.030** |

İlk yıl oyuncu isteğinin ~%70–90'ını karşılayabilir. Bu bilinçli bir darlıktır: "hepsini birden" yapılamaz, sıra seçilir.

### 2.7 İdeoloji ve devlet kapasitesi

01 §6.5'e göre ideoloji salgın yanıtında yalnız kapasite farkı yaratır. Başlangıçta her ülkeye ideolojisine göre bir **rejim durumu**
verilir. İdeoloji değişirse (seçim ya da darbe) `rules.gd` bu durumu ayda bir yeniler.

| Kimlik | EN / TR | İdeoloji | Etki | Gerekçe |
|---|---|---|---|---|
| `zm_regime_consent` | Government by Consent / Rızaya Dayalı Yönetim | demokratik | `zm_compliance +0,10`; itibar +5 | Güven uyumu artırır (Blair 2017; Bargain ve Aminjonov 2020). Buna karşılık karar yavaştır: sert basamakların çoğu evre ve irade şartı ister (§3) |
| `zm_regime_decree` | Government by Decree / Kararname Yönetimi | faşist, komünist | `political_power_gain +0,10`; `zm_compliance −0,10`; itibar −5 | Kararname hızlıdır ama güveni aşındırır: 1830–31 kolera ayaklanmaları (01 Sütun 3) |
| `zm_regime_bureaucratic` | Bureaucratic Order / Bürokratik Düzen | bağlantısız | `political_power_gain +0,05` | Monarşiler, askerî ve tek parti yönetimleri: ne güçlü bir güven tabanı ne kararname aygıtı var |

Değerler bilerek küçük tutuldu (±0,10). Oyunun sorusu "hangi rejim salgını yener?" değil, "sen bu devletle ne yaparsın?" sorusudur.

## 3. Yasalar

### 3.1 Genel kurallar

- Beş yeni grup `laws.patch.json` ile eklenir. Temel üç grup (askerlik, ekonomi, ticaret) ve 07'deki Gıda Politikası kalır; toplam
  9 grup olur. Hükümet panelindeki yasa listesinin 9 grubu kaydırmayla (`PanelLayout.fit_scroll`) gösterdiği insan gözüyle doğrulanmalıdır (§14).
- **Bedel (S3):** Yasanın `cost` alanı, o basamağa **çıkmanın** bedelidir. Listede aşağı inmek, yani gevşetmek, grubun `relax_cost`
  değeri kadar tutar (50 nüfuz). Gerekçe: bir yasağı kaldırmak siyasi olarak ucuzdur, yeni bir yasak koymak pahalıdır.
- **Şart (S2):** `requires` alanında motorun `war_support` anahtarı ve modun `zm_phase_at_least` (06) anahtarı kullanılır.
- **Tutum etiketi** (`zm_stance`): Basamağın dört kriz tutumunu nasıl etkilediğini gösterir (§4). Değer bir sözlüktür ve
  `Country.mod`'dan okunmaz; `rules.gd` onu `law_def` ile okur.
- **`zm_strict: 1`:** Basamak önlem yorgunluğu biriktirir (§2.3).
- Yasa değerleri 07'nin uyarısına uyar: `consumer_goods` ve `manpower` anahtarları kullanılmaz. Bunların yerine `consumer_goods_mod` kullanılır.

### 3.2 Karantina Politikası (`zm_quarantine`)

| Kimlik | EN / TR | Bedel | Bulaş `zm_beta_mult` | Diğer | `factory_output` | `stability` | Şart | Tutum etiketi |
|---|---|---|---|---|---|---|---|---|
| `zm_voluntary_reporting` | Voluntary Reporting / Gönüllü Bildirim | — | 0 | — | 0 | 0 | başlangıç (herkes) | geçim +1, sağlık −1 |
| `zm_compulsory_notification` | Compulsory Notification / Zorunlu Bildirim | 50 | −0,05 | `zm_detection +0,05` | 0 | −0,01 | — | sağlık +1 |
| `zm_home_isolation` | Home Isolation / Ev Tecridi | 100 | −0,20 | `zm_strict` | −0,04 | −0,04 | Alarm | sağlık +2, geçim −1 |
| `zm_compulsory_quarantine` | Compulsory Quarantine / Zorunlu Karantina | 150 | −0,35 | `zm_strict` | −0,10 | −0,08 | Alarm | sağlık +2, düzen +1, geçim −2 |
| `zm_travel_ban` | Internal Travel Ban / Yurt İçi Seyahat Yasağı | 100 | −0,35 | `zm_travel_mult −0,80` (yolcu ×0,2); `zm_strict` | −0,13 | −0,10 | Yayılma; irade ≥ 0,15 | sağlık +2, düzen +1, geçim −3 |

- **Başlangıç Gönüllü Bildirim'dir.** Hastalık 1936'da hiçbir bildirim listesinde yoktur. İngiltere'nin 1889 bulaşıcı hastalık
  bildirim yasası ve Türkiye'nin 1930 tarihli, 1593 sayılı Umumi Hıfzıssıhha Kanunu, bildirimi zorunlu hastalıkları listeyle belirler.
  Zorunlu Bildirim, EF'yi bu listeye eklemek demektir. Hazırlık serbesttir; oyuncu bu adımı ilk günden atabilir.
- **−0,05 / +0,05:** Bildirilen hasta ayrılır. Etkisi küçüktür, çünkü Ateşli hastanın bulaş payı düşüktür (φ = 0,15). Tespit eki 03 §8.1'deki
  araştırma merkezi ekiyle aynı ölçektedir.
- **−0,20:** 1918'de ABD şehirlerinde önlemler bulaşı %30–50 azalttı (Bootsma ve Ferguson 2007). Yalnız bilinen hastayı ve ev halkını
  ayıran tecrit bu aralığın altında kalır (kendi tahminimiz). −%4 fabrika, işe gidemeyen ev halkıdır.
- **−0,35 / −0,10 / −0,08:** 02 ve 03'teki değerlerdir. Yeni bir değer türetilmedi.
- **Seyahat yasağı:** Yolcu çarpanı ×0,2, 03 §7'deki "yurt içi seyahat yasağı" değeridir. Fabrikaya ek −%3, 07 §11'deki işe gidiş önerisidir.
  Bulaş azaltması Zorunlu Karantina ile aynıdır, çünkü yasak eyalet **içindeki** teması değil, eyaletler **arasındaki** akışı keser.

### 3.3 Olağanüstü Yönetim (`zm_emergency`)

| Kimlik | EN / TR | Bedel | Etki | Şart | Tutum etiketi |
|---|---|---|---|---|---|
| `zm_ordinary_rule` | Ordinary Government / Olağan Yönetim | — | — | başlangıç | — |
| `zm_emergency_powers` | Emergency Powers Act / Olağanüstü Yetki Kanunu | 100 | `political_power_gain +0,15`; `stability −0,02`; seçim erteleme seçeneği açılır (olay A3) | Alarm | düzen +1 |
| `zm_curfew` | Curfew / Sokağa Çıkma Yasağı | 75 | `zm_beta_mult −0,10`; `factory_output −0,05`; `stability −0,05`; `political_power_gain +0,10`; `zm_strict` | Yayılma | düzen +2, geçim −1 |
| `zm_martial_law` | Martial Law / Sıkıyönetim | 100 | `zm_beta_mult −0,15`; `zm_martial_kappa +0,05`; `factory_output −0,08`; `stability −0,15`; `political_power_gain +0,20`; itibar −20; şeffaflık −0,15; seçimler 12'şer ay kayar; `zm_strict` | Yayılma; irade ≥ 0,20 | düzen +3, dayanışma −1, geçim −1 |

- **Olağanüstü Yetki:** İngiltere'nin 1920 tarihli Olağanüstü Yetki Yasası, hükümete bir aylık olağanüstü hal ilan etme yetkisi verdi.
  Bu süre yenilenebiliyordu ve parlamentonun beş gün içinde toplanması gerekiyordu. Yasa zorunlu askerlik ve zorunlu sanayi hizmeti
  getirmeyi açıkça yasakladı. Modda bu basamak bir hız aracıdır (nüfuz +%15). Sert önlem ise ayrı basamaklardadır.
- **Sıkıyönetim:** Bulaş ve bastırma değerleri 03 §7'dendir, istikrar bedeli (−%15) ve itibar bedeli (−20, yani kabul oranları −0,20) 02
  §3.4'tendir. Bastırma eki ayrı bir anahtardır (`zm_martial_kappa`), çünkü 06 §3.10'daki `zm_kappa_flat` tavanı yasayı kapsamaz. 02'nin
  "Hat mı, Halk mı?" olayındaki "Sıkıyönetim ilan et" seçeneği, `{"zm_set_law": {"zm_emergency": "zm_martial_law"}}` etkisidir; bedelsiz
  olarak bu basamağa geçirir. İç Çöküş olayının sıkıyönetim seçeneği buna ek olarak 180 günlük "−%30 fabrika" durumunu verir (02 §4.2).
- **Seçimler:** Sıkıyönetim altındaki ülkede seçim tarihi geldiğinde tarih 12 ay ileri kayar. Bu, oyuncunun seçtiği yasanın açık bir
  sonucudur ve ipucunda yazar. İngiltere'de 1935'te seçilen parlamento savaş boyunca her yıl uzatıldı; sonraki genel seçim 1945'te yapıldı.

### 3.4 Sivil Savunma (`zm_civil_defence`)

| Kimlik | EN / TR | Bedel | κ_sivil çarpanı (`zm_civil_kappa_law`) | Diğer | Şart | Tutum etiketi |
|---|---|---|---|---|---|---|
| `zm_police_only` | Police and Gendarmerie / Polis ve Jandarma | — | ×1,0 | — | başlangıç | — |
| `zm_civil_defence_corps` | Civil Defence Corps / Sivil Savunma Teşkilatı | 50 | ×1,2 | `zm_evacuation_mult +0,20`; `consumer_goods_mod +0,01` | — | dayanışma +1, düzen +1 |
| `zm_local_guards` | Local Guards / Yerel Muhafızlar | 100 | ×1,5 | `stability −0,03`; parçalanma olasılığı +0,05 (§5.2) | Alarm | düzen +2, dayanışma −1 |
| `zm_general_arming` | General Arming / Genel Silahlanma | 100 | ×1,8 | `stability −0,08`; itibar −5; parçalanma +0,10 ve askerî valilik olasılığı ×2 (§5.3) | Çöküş; irade ≥ 0,25 | düzen +1, dayanışma −2, sağlık −1 |

- ×1,5, 03 §7'deki sivil savunma yasası değeridir. ×1,2 örgütlü ama silahsız sivilin etkisidir (06'daki "Silahsız Sivil Savunma"
  doktrininin ölçeği). ×1,8 azalan getiriyi yansıtır.
- **Silah salgını durdurmaz.** Sivil bastırma (κ = 0,08) ile hesaplanan R₀ (02 §2.3 formülü) şöyledir:

| Çarpan | Referans eyalet (d = 1) R₀ | Büyük liman şehri (d = 3) R₀ |
|---|---|---|
| ×1,0 | 3,11 | 4,10 |
| ×1,2 | 2,71 | 3,60 |
| ×1,5 | 2,29 | 3,10 |
| ×1,8 | 2,00 | 2,75 |

  Direnç oranı α = κ/β en iyi durumda bile 0,48'dir, yani 1'in altındadır. Silahlı halk düşmeyi geciktirir ama tek başına durduramaz.
  Bu yüzden Genel Silahlanma'nın bedeli (istikrar ve parçalanma) yüksek tutuldu. İpucunda şu cümle yazar: *"Silah zaman kazandırır;
  halkı kurtaran serumdur."*
- Dayanak: İngiltere'de hava saldırısı önlemleri teşkilatı (ARP) 1937'de kuruldu; 1938'de gönüllü sayısı yüz binlerle ölçülüyordu (06).

### 3.5 Basın ve Bilgi Politikası (`zm_information`)

| Kimlik | EN / TR | Bedel | Etki | Panik çarpanı p_bilgi | Şeffaflık τ_yasa | İtibar | Örtbas katsayısı h | Başlangıç | Tutum etiketi |
|---|---|---|---|---|---|---|---|---|---|
| `zm_free_press` | Free Press / Serbest Basın | — | — | 1,0 | 1,0 | +5 | 0 | demokrasiler | sağlık +1, dayanışma +1, düzen −1 |
| `zm_official_bulletins` | Official Health Bulletins / Resmî Sağlık Bültenleri | 50 | `zm_beta_mult −0,10`; `political_power_gain −0,03` | 1,0 | 1,0 | +5 | 0 | — (şart: Alarm) | sağlık +2 |
| `zm_news_control` | News Control / Haber Denetimi | 75 | `stability +0,02` | 0,7 | 0,7 | −5 | 0,3 | bağlantısızlar | düzen +1, sağlık −1 |
| `zm_full_censorship` | Full Censorship / Tam Sansür | 75 | `stability +0,04`; `zm_compliance −0,05` | 0,4 | 0,4 | −15 | 0,6 | faşist ve komünist ülkeler | düzen +2, sağlık −2, dayanışma −1 |

**Panik çarpanı** halkın algıladığı yaygınlığı küçültür. Bu değer korkuya bağlı devamsızlığa (07 §2.2), istikrar korkusuna (§2.4) ve
yerel dehşete (§2.3) girer. **Sansür sokaktaki Boş'u gizleyemez:** mülteci kaçışı (03 §5.5) gerçek sayıya bakar. Böylece sansür kısa
vadede ekonomiyi ve istikrarı korur, ama iki bedeli vardır:

1. **Bilgilendirmenin bulaş azaltması kaybolur.** Resmî Bülten −0,10 verir; sansürde bu yoktur ve üstüne uyum düşer.
2. **Örtbas borcu birikir:**
```
G(t+1) = G(t) · (1 − 1/120) + h · bildirilen_yeni_vaka(t)
s      = G / (0,0005 · N_anavatan)
haftalık skandal olasılığı p = min(0,30 ; 0,05 · s)        → olay A8 "Sızan Rapor"
```
Gizlenen haber 120 günde eskir. Eşik, anavatan nüfusunun on binde 5'i kadar gizlenmiş vakadır. Türkiye örneğinde bu yaklaşık 8.000 vakadır.

| Türkiye (N = 16,0 milyon) | Günde 100 yeni bildirilen | Günde 500 | Günde 2.000 |
|---|---|---|---|
| Haber Denetimi (h = 0,3): denge G / s / haftalık p | 3.600 / 0,45 / %2 (≈44 haftada bir) | 18.000 / 2,2 / %11 (≈9 hafta) | 72.000 / 9 / %30 (≈3 hafta) |
| Tam Sansür (h = 0,6) | 7.200 / 0,9 / %4,5 (≈22 hafta) | 36.000 / 4,5 / %22 (≈4,5 hafta) | %30 (≈3 hafta) |

Salgın küçükken sansür uzun süre sessiz kalır. Büyüdüğünde ise haftalar içinde patlar. Tarihte bunun iki yüzü görülür. Birinci
Dünya Savaşı'nda savaşan ülkelerin basını sansür altındaydı; tarafsız İspanya'nın basını salgını serbestçe yazdı ve hastalık dünyaya
"İspanyol gribi" adıyla yayıldı. 1892'de Hamburg yönetimi, ticareti korumak için koleranın varlığını birkaç gün geç kabul etti (02 kaynağı).

**Şeffaflık katsayısı** (03 §8.2'nin 0,3–1,0 katsayısı; yabancı bültenlerde bu ülkenin sayıları bu katsayıyla çarpılır):
```
τ = clamp( τ_yasa + 0,10·[gözetim havuzu üyesi, 05 §9] − 0,15·[sıkıyönetim] − 0,20·[Konsey bildirimi askıda, §6.2] ; 0,3 ; 1,0 )
```
Askerî valiliklerde τ = 0,3'tür. Çökmüş ülkeden veri gelmez ve bültende "Veri yok" yazar (03 §8.1).

### 3.6 Zorunlu Hizmet (`zm_service`)

| Kimlik | EN / TR | Bedel | Etki | Şart | Tutum etiketi |
|---|---|---|---|---|---|
| `zm_voluntary_service` | Voluntary Service / Gönüllü Hizmet | — | — | başlangıç | geçim +1 |
| `zm_medical_service` | Medical Service Obligation / Sağlık Hizmeti Yükümlülüğü | 75 | `zm_distribution_mult +0,15`; `stability −0,01`; `consumer_goods_mod +0,01` | Alarm | sağlık +2 |
| `zm_labour_service` | Compulsory Public Service / Zorunlu Kamu Hizmeti | 100 | `construction_speed +0,10`; `zm_evacuation_mult +0,15`; `factory_output −0,03`; `stability −0,03` | irade ≥ 0,20 | düzen +1, geçim −1 |
| `zm_total_mobilisation` | Total Civil Mobilisation / Topyekûn Sivil Seferberlik | 150 | `construction_speed +0,15`; `zm_distribution_mult +0,15`; `zm_evacuation_mult +0,25`; `factory_output −0,06`; `stability −0,06` | Çöküş; irade ≥ 0,35 | düzen +2, dayanışma +1, geçim −2 |

- 07'deki "İşgücü Yönlendirmesi" kararı fabrika işgücünü (ω) artırır. Bu grup ise emeği **kamu işine** (tahkimat, tahliye, aşı kolu)
  yönlendirir. Bu yüzden fabrika çıktısını azaltır; iki etki birbirinin tekrarı değildir.
- **Dayanaklar:** Almanya'nın 26 Haziran 1935 tarihli Reich Çalışma Hizmeti yasası 18–25 yaş erkeklere altı aylık zorunlu çalışma
  getirdi. Türkiye'de 7–8 Ağustos 1921'de yayımlanan Tekâlif-i Milliye emirleri, Başkomutanlık yetkisiyle mal ve hizmet yükümlülüğü
  koydu. 18 Ocak 1940 tarihli Millî Korunma Kanunu fiyat denetimi ve çalışma yükümlülüğü dahil olağanüstü yetkiler tanıdı. 1918'deki
  hemşire açığı için 07 §2.2'ye bakınız.
- Sağlık Hizmeti Yükümlülüğü'nün +0,15'i, 06'daki "Hastane Seferberliği" doktriniyle aynı ölçektedir. İkisinin toplamı 05'in dağıtım
  tavanına (%1,5/gün) tabidir.

### 3.7 Tayınlama: Gıda Politikası

Görevdeki "tayınlama" 07 §3.7'deki `zm_rationing` grubudur (Serbest Piyasa, Fiyat Tavanı, Karne, Merkezî İaşe). Bu belge yalnız
tutum etiketlerini ekler: Serbest Piyasa (geçim +1, dayanışma −1), Fiyat Tavanı (geçim +1), Karne (dayanışma +2, geçim −1),
Merkezî İaşe (dayanışma +2, düzen +1, geçim −2).

### 3.8 Kararlar (siyasi)

Kararlar mevcut karar motoruyla yürür; `available` alanı 06'daki M2 kancasıyla eklenir.

| Kimlik | EN / TR | Bedel / süre | Etki | Şart | Gerekçe |
|---|---|---|---|---|---|
| `zm_solidarity_bonds` | Solidarity Bonds / Dayanışma Tahvilleri | 50 / 90 gün | `war_support +0,08` | Alarm | Temel oyundaki Savaş Tahvilleri savaş şartı ister. S1'den sonra salgın savaş sayılmadığı için modun karşılığı budur; değer temel karardan alındı |
| `zm_quarantine_amnesty` | Quarantine Amnesty / Karantina Affı | 40 / bir kez, 180 günde bir | F −3; `stability +0,03`; `transmission +0,03` [60 gün] | F ≥ 4 | Yorgunluğu kırmanın bir bedeli olmalı: kısa bir gevşeme |
| `zm_lift_vaccine_mandate` | Lift the Vaccine Mandate / Aşı Zorunluluğunu Kaldır | 25 | Olay B2'nin zorunluluk durumunu kaldırır | zorunluluk var | Geri adımın yolu olmalı (1904 Rio) |
| `zm_suspend_reporting` | Suspend Reporting to the Council / Konsey Bildirimini Askıya Al | 20 / süresiz | τ −0,20; haftada %5 olasılıkla ortaya çıkar: itibar −15 | Konsey üyesi | 1926 Sözleşmesi bildirimi yükümlülük yaptı (03 §8.2); çiğnemek bir seçimdir, bedelsiz değildir |

### 3.9 Yapay zekânın yasa politikası (`rules.gd`, yalnız yapay zekâ ülkeleri)

| Grup | Kural (her 14 günde bir, nüfuz ≥ bedel + 30 ise) |
|---|---|
| Karantina | YE_bild ≥ 0,01 → Zorunlu Bildirim · anavatanda bildirilen vaka → Ev Tecridi · YE ≥ 0,05 → Zorunlu Karantina · YE ≥ 0,25 ve irade ≥ 0,15 → Seyahat Yasağı · 60 gün YE < 0,01 ya da (F ≥ 10 ve istikrar < 0,25) → bir basamak gevşet |
| Olağanüstü | İlk vaka → Olağanüstü Yetki · YE ≥ 0,15 → Sokağa Çıkma · düşmüş pay ≥ 0,10 ya da istikrar < 0,15 → Sıkıyönetim (Kararname Yönetimi olan ülkede eşikler ×0,7) |
| Sivil Savunma | Yayılma → Teşkilat · YE ≥ 0,20 → Yerel Muhafız · düşmüş pay ≥ 0,25 → Genel Silahlanma |
| Basın | Demokrasi Alarm'da Resmî Bülten'e geçer; ötekiler başlangıç yasasında kalır. Skandaldan (A8) sonra %50 olasılıkla bir basamak açılır |
| Hizmet | Alarm'da Sağlık Hizmeti · düşmüş pay ≥ 0,10 → Kamu Hizmeti · ≥ 0,25 → Topyekûn |

## 4. Kriz tutumları

### 4.1 İdeoloji yerine mi, yanında mı?

| Seçenek | Artı | Eksi | Karar |
|---|---|---|---|
| Yalnız ideolojiler | Kod yok | Salgın tartışması (kapat mı, aç mı? kimi önce koru?) ideoloji pastasında görünmez | — |
| İdeolojilerin **yerine** tutumlar | Tema saf | Seçim motoru, yapay zekânın ittifak ve savaş kararları, 1936 verisi (liderler, partiler) ideolojiye bağlı; hepsi yeniden yazılır | — |
| İdeolojilerin **yanında** tutumlar | Motor değişmez; tutum, iktidar partisinin popülerliği üzerinden seçime bağlanır | Yeni bir gösterge öğrenilir | **Seçildi** |

### 4.2 Dört tutum

Tutumlar salgın tanınınca oluşur: Alarm evresine girişte her ülkede dört pay da 0,25 olarak başlar (olay A2). Salgından önce kimsenin
bir "salgın görüşü" yoktur.

| Kimlik | EN / TR | Ne ister? | Tarihten ses |
|---|---|---|---|
| `health` | Health First / Önce Sağlık | Karantina, bilgilendirme, bilim, hekim seferberliği | 1918'de erken ve katmanlı önlem isteyen belediye sağlık yöneticileri (Markel ve ark. 2007) |
| `order` | Order First / Önce Düzen | Sıkıyönetim, kapalı sınır, silahlı nöbet | Kordon ve jandarma isteyen, düzensizlikten korkan kesim |
| `livelihood` | Livelihood First / Önce Geçim | Açık ticaret, gevşek önlem, ekmek ve ücret | 1892 Hamburg tüccarları; 1919 San Francisco Maske Karşıtı Birliği |
| `solidarity` | Solidarity / Dayanışma | Mülteci kabulü, yardım, adil karne | Nansen'in mülteci çalışmaları; 1921–23 Rusya kıtlığında Amerikan Yardım İdaresi (ARA) |

### 4.3 Payların dinamiği (ay başında)

```
P_sağlık     = 1 + 4·YE_algı + 25·(D / N⁰)
P_düzen      = 1 + 4·düşmüş_pay + 0,3·(son 90 günde kargaşa olayı sayısı) + 0,5·[anavatanda sürü birimi var]
P_geçim      = 1 + 0,1·F + 2·(1 − Ω_e) + 0,1·açlık_kademesi              (Ω_e ve açlık: 07 §2.3, §3.6)
P_dayanışma  = 1 + 0,3·[Konsey üyesi] + 0,3·[son 180 günde yardım aldı] − 0,25·mülteci_yükü_kademesi   (07 §10.5)

hedef_k = P_k / Σ P ;     pay_k ← pay_k + 0,20 · (hedef_k − pay_k)       (yarı ömür ≈ 3 ay)
```
Olaylar `zm_stance` etkisiyle payı doğrudan kaydırabilir (±0,02…0,05); ardından paylar yeniden 1'e ölçeklenir.
Katsayılar kendi tahminimizdir. Amaç, bir yıllık sert kapanmanın geçim payını yaklaşık 0,25'ten 0,32–0,35'e taşımasıdır:
bu, olay A12'nin (Genel Grev) eşiğidir.

### 4.4 Uyum ve etkileri

```
a_k = clamp( Σ yürürlükteki basamakların etiketi_k / 4 ; −1 ; +1 )
A   = Σ_k pay_k · a_k                                         (−1 … +1)
İstikrar: +0,06 · A (§2.4) ;   iktidar ideolojisinin popülerliği: her ay +0,01 · A
```
Etiket kaynakları beş yasa grubu, Gıda Politikası (§3.7), mülteci politikası (kabul: dayanışma +3, düzen −1; kamp: dayanışma +1,
sağlık +1; ret: düzen +1, dayanışma −3) ve en sert sınır tutumudur (açık: geçim +1, dayanışma +1, sağlık −1; denetimli: sağlık +1;
kapalı: düzen +1, sağlık +1, geçim −2, dayanışma −1).

### 4.5 Örnek: Türkiye, 300. gün

Paylar: sağlık 0,34 · düzen 0,24 · geçim 0,27 · dayanışma 0,15. Yürürlükte: Zorunlu Karantina, Olağanüstü Yetki, Haber Denetimi,
Sivil Savunma Teşkilatı, Sağlık Hizmeti, Karne, kamplı mülteci kabulü, denetimli sınır.

| Tutum | Etiket toplamı | a_k | pay × a_k |
|---|---|---|---|
| Sağlık | 2 − 1 + 2 + 1 + 1 = 5 | +1 | +0,34 |
| Düzen | 1 + 1 + 1 + 1 = 4 | +1 | +0,24 |
| Geçim | −2 − 1 = −3 | −0,75 | −0,20 |
| Dayanışma | 1 + 2 + 1 = 4 | +1 | +0,15 |
| **A** | | | **+0,53 → istikrar +%3,2** |

Oyuncu seyahat yasağı ve tam sansüre geçerse A 0,42'ye iner. Bir yıl daha sürerse geçim payı büyür ve A negatife döner. Bu hesap
oyuncuya şunu gösterir: **aynı önlem, halkın neyi istediğine göre farklı bir siyasi bedel taşır.**

### 4.6 Seçimler

08'in 2. açık sorusunun ("Salgında seçimler yapılacak mı?") yanıtı **evettir**. S1'den sonra seçimler motorun kuralıyla yapılır:
popülerliği %50'yi aşan ideoloji kazanır. Seçim ancak oyuncunun seçtiği bir sonuçla ertelenir: A3 olayındaki erteleme seçeneği ya da
Sıkıyönetim yasası (§3.3). Mod iki şey ekler:
- **Popülerlik kayması:** §4.4'teki aylık +0,01·A. Bir yıl boyunca A = −0,5 ile yönetilen bir demokraside iktidar partisi 6 puan kaybeder.
- **Olay A3 "Salgının Gölgesinde Seçim":** seçimden 21 gün önce gelir. ABD 1918 ara seçimini (5 Kasım) ve İngiltere 1918 genel
  seçimini (14 Aralık) salgının içinde yaptı. İngiltere 1935'te seçilen parlamentoyu ise savaş boyunca uzattı. Oyunun üç seçeneği bu üç
  tarihî yolu yansıtır.

## 5. Devlet çöküşü ve parçalanma

### 5.1 Durum makinesi (her ülke; oyuncunun ülkesi için yalnız Çökmüş = kayıp)

```
           istikrar ≤ 0,20 ya da teslim ≥ ½ sınır ya da YE ≥ 0,5
  AYAKTA ──────────────────────────────────────────────────────▶ SARSILMIŞ
     ▲                 hepsi 60 gün sağlanmıyor                     │
     └──────────────────────────────────────────────────────────────┤
                                                                    │ başkent kopuk (eyaletlerin ≥ %25'i başkente bağlı değil)
                                                                    │ ya da istikrar ≤ 0,05 (30 gün)
                                                                    ▼
                                                               PARÇALANAN ──(kopuk grup → bölgesel yönetim, §5.2)
                                                                    │
     teslim ilerlemesi ≥ sınır (S4) · nüfus < %20 · İç Çöküş'te     │
     "hükümeti bırak" (02 §4.2)                                     ▼
                                                               ÇÖKMÜŞ ──▶ bölgesel yönetimler · yönetimsiz eyaletler
                                                                    │     · koruma altına alma (§5.4)
                                                                    ▼
                                                     YENİDEN KURULMUŞ (olay C5; ülke S5 ile yeniden etkinleşir)
```

| Durum | Etki (yapay zekâ ülkesi) | Oyuncuya görünen |
|---|---|---|
| Sarsılmış | Yardım göndermez; ayda bir yardım çağrısı yapar (olay D6); Konsey aidatını ödemez | Diplomasi panelinde turuncu "Sarsılmış" etiketi (mevcut `row` alt satırı) |
| Parçalanan | Kopuk gruplarda her ay oluşum denetimi yapılır (§5.2) | Bildirim + haritada yeni ülke rengi |
| Çökmüş | Hükümet yoktur: üretim, araştırma ve ordu durur; tümenler bölgesel yönetimlere geçer ya da dağılır (`Military.remove_all`). Eyaletlerin sahibi değişmez. Düşmüş eyaletlerdeki bölgeler `UND` kontrolünde kalır (07 kuralı) | Olay C2 (komşulara) |

**AI'nın İç Çöküş seçimi:** sıkıyönetim 0,5, ulusal birlik 0,4, hükümeti bırak 0,1 ağırlıklarıyla. Denge hedefi 02 §8'dedir
(bitişte 1–25 çökmüş ülke).

### 5.2 Kopuk gruplar ve bölgesel yönetimler

**Kopuk grup:** Ülkenin DÜŞMÜŞ olmayan eyaletlerinden, kara komşuluğuyla birbirine bağlı olan ama başkent eyaletine bağlanmayan
bir küme. Denizaşırı eyaletler, kendi limanı ve başkent limanı düşmemişse bağlı sayılır. **Oluşum şartı:** grubun yaşayan nüfusu ≥ 300.000.
Bu eşik, ortalama eyaletin (dünya nüfusu / 1.652 ≈ 1,3 milyon) yaklaşık dörtte biridir. Daha küçük gruplar (küçük adalar, boşalmış kırlar)
kendi yönetimini kuramaz ve "yönetimsiz" kalır.

```
Parçalanan ülkede, her ay her kopuk grup için:
p = clamp( 0,10 + 0,10·[ana ülke istikrarı < 0,20] + 0,05·[Yerel Muhafızlar] + 0,10·[Genel Silahlanma]
           + 0,10·[grupta ana ülkenin ≥ 3 tümeni var] ; 0 ; 0,40 )
Çökmüş ülkede: şartı sağlayan her grup hemen oluşur (havuzda yer varsa).
```

**Havuz (S5):** `countries.patch.json` içinde 24 uyuyan kayıt vardır (`ZR01` … `ZR24`, `"dormant": true`). Toplam ülke sayısı
80 + `UND` + 24 = 105 olur ve 255'lik renk indeksinin içinde kalır. **Neden 24?** Denge hedefi tipik olarak ~8 çöken ülkedir ve her
çöküşten 0–3 yönetim çıkar. 24 yuva tipik oyuna yeter. Havuz dolarsa kalan gruplar yönetimsiz kalır (performans ve harita okunaklılığı).

| Özellik | Geçici Yönetim (sivil) | Askerî Valilik (savaş ağası) |
|---|---|---|
| Ne zaman? | Varsayılan | Grupta ana ülkenin ≥ 3 tümeni varsa, ya da Genel Silahlanma yürürlükteyse olasılık ×2 (en çok %60) |
| Ad (EN / TR) | "Provisional Administration of {state}" / "{state} Geçici Yönetimi" | "{state} Military Governorate" / "{state} Askerî Valiliği" |
| Lider alanı (makam) | "Council of Governors" / "Valiler Kurulu" | "Military Governor" / "Askerî Vali" |
| Renk ve bayrak | Ana ülkenin rengi, %25 açık; bayrak aynı renklerle `FlagFactory` (yeni sanat yok) | Ana ülkenin rengi, %25 koyu |
| Başlangıç | İdeoloji ana ülkeninkidir; istikrar 0,35; irade = ana ülkenin iradesi; nüfuz 50; yasalar ana ülkeden; 1 bedava tümen (`add_divisions`) | İstikrar 0,30; Sıkıyönetim ve Tam Sansür; gruptaki tümenler (S5 `transfer_divisions`) |
| Konsey | %90 olasılıkla katılır | %10 |
| Şeffaflık | Yasasına göre | 0,3 |
| Davranış | Yardım ister, bir komşudan **himaye** ister (olay C3), Karşı Saldırı'da ana ülke ayaktaysa ona katılmayı müzakere eder | Komşu yönetimsiz eyaletleri koruma altına alır; "tanıma karşılığı geçiş ve ticaret" önerir (olay C4); devletler arası savaş ayarı izin verirse yalnız başka bölgesel yönetimlerle savaşır |

**Tarihî dayanak.** Merkezî otorite çözüldüğünde yerel yönetimler doğar. Ekim 1918'de Avusturya-Macaristan dağılırken Prag ve
Zagreb'deki ulusal konseyler yönetimi devraldı. 1918'de Rusya'da Samara'daki Kurucu Meclis Komitesi gibi bölgesel hükümetler kuruldu.
Çin'de 1916'dan 1928'e kadar süren "savaş ağaları dönemi"nde eyaletleri bölgesel komutanlar yönetti. Mod bu örüntüyü alır ama
şiddeti oynanabilir kılmaz: askerî valilik yalnız ordusuyla ve diplomasisiyle vardır, sivillere yönelik hiçbir eylemi yoktur.

### 5.3 Oyuncunun ülkesi parçalanırsa

Ayrılma oyuncu adına verilmiş bir karar değildir, bir dünya olayıdır. Yine de 2–3 seçenekli olay olarak gelir (olay C1, "Kopan Eyaletler"):
geçici özerklik (grup, oyuncunun ittifakında sadık bir yönetim olur ve Karşı Saldırı'da %80 olasılıkla geri katılır), tam yetkili temsilci
(60 nüfuz, 90 gün erteleme) ya da ayrılığı kabul. Oyuncu kopukluğu önlemek için koridoru açık tutabilir. Bu, kordon kararına yeni bir
anlam katar.

### 5.4 Koruma altına alma ve iade

Milletler Cemiyeti Misakı'nın 22. maddesi, "kendi başına ayakta duramayan" halkların yönetimini "uygarlığın kutsal emaneti" diye
başka devletlere bıraktı. Uygulamada bu manda sistemi çoğu zaman ilhakın örtüsü oldu. Mod bu dersi kurala çevirir: **koruma puan
getirmez; iade ödüllendirilir.**

| Kural | Değer | Gerekçe |
|---|---|---|
| Hedef | Çökmüş ülkenin yönetimsiz eyaleti ya da himaye isteyen geçici yönetim; DÜŞMÜŞ olmayan ve koruyucunun kontrolündeki bir bölgeye kara ya da liman komşusu olan eyaletler | Koruyamayacağın yeri koruma altına alamazsın |
| Bedel | Eyalet başına 25 nüfuz; 30 gün içinde eyalete en az 1 tümen girmezse talep düşer ve nüfuz iade edilmez | Asker şartı, kâğıt üstündeki koruma kestirmesini kapatır |
| Devir | `World.transfer_state`; kayıtta `zm_protectorate: {asıl: tag, gün: n}` | — |
| Çöküş hesabı | Eyaletin `adm0`'ı farklı olduğu için motor onu ¼ ağırlıkla sayar (sömürge kuralı) | Motor değişmez |
| Puan | 02'nin zafer puanı kalemi yalnız 1936'daki kendi eyaletlerini sayar; korunan eyalet sayılmaz. Korunan **yaşayan nüfus** yardım puanına girer (§6.4) | Toprak değil, insan sayılır |
| Yük | Korunan eyalet başına istikrar −%0,5 (en çok −%5) | Yönetim bedeli |
| İade (olay C5) | Karşı Saldırı ya da sonrasında, asıl ülkenin 1936 başkent eyaleti koruma altındaysa ve 42 gündür temizse gelir. İade: itibar +15, yardım puanı +0,10, ilişki +50. Sürdürmek: her ay itibar −1 | 01 Sütun 5; "sömürgeler tampon değildir" ilkesinin aynası |

**Yapay zekâ:** Boşta tümeni olan ve eyalete komşu olan yapay zekâ koruma altına alır. İade olayında %70 olasılıkla iade eder.

### 5.5 Devletler arası savaş (01'in 3. açık sorusu)

02 §7.2'deki ayar geçerlidir: *Kapalı / Yalnız Çöküş evresinde (varsayılan) / Serbest.*

| Kural | Oyuncu | Yapay zekâ |
|---|---|---|
| Savaş gerekçesi | 60 nüfuz (temel oyunda 30); gerekçe tamamlanınca itibar −10 | Aşağıdaki şartların hepsi sağlanırsa, ayda %5 olasılıkla |
| Şartlar | Ayar izin vermeli | Ayar izin vermeli; evre ≥ Çöküş; hedef Sarsılmış, bölgesel yönetim ya da yönetimsiz; kendi YE'si < 0,20; ordusu hedefin 1,5 katı |
| Bedel | Çöküş evresinde savaş ilanı: itibar −20 ve Konsey'de kınama tasarısı (R9) | Aynı |
| Ödül | Fethedilen eyalet 02'nin puanına girmez (yalnız 1936 toprakları sayılır). Yaşayan nüfus puanı da değişmez | — |

1919–21 Polonya-Sovyet savaşı, Doğu Avrupa'yı kasıp kavuran tifüs salgınının içinde yapıldı. Milletler Cemiyeti'nin Salgın Komisyonu
Polonya'nın doğu sınırında çalışırken savaş sürüyordu. Tarih, salgının savaşı kendiliğinden durdurmadığını gösterir. Bu yüzden mod
savaşı yasaklamaz, yalnız ödüllendirmez.

## 6. Diplomasi

### 6.1 Dört yeni değer

| Değer | Aralık | Başlangıç | Değişim | Kullanıldığı yer |
|---|---|---|---|---|
| **İlişki** `r_ij` (i'nin j'ye tutumu; yönlü) | −100 … +100 | Taban `b_ij` = +20 aynı ittifak · +10 aynı ideoloji · +10 j, i'ye garanti vermiş · −30 son 365 günde savaş | Olaylar ve eylemler (aşağıdaki tablo); her gün tabana doğru 1/180 oranında kayar | Kabul formülü (§6.3); 05 §9'daki "tutum" budur |
| **İtibar** `I_c` | 0 … 100 | 50 + rejim (±5) + basın yasası (+5 / +5 / −5 / −15) + Konsey üyeliği (+5) | Kalıcı bileşen (yasa, üyelik) anlıktır. Olay bileşeni günde ×0,996 söner (yarı ömür ≈ 173 gün) | Kabul formülü; yardımcı yapay zekâların öncelik sırası; Konsey'de tasarı önerme |
| **Şeffaflık** `τ_c` | 0,3 … 1,0 | §3.5 | Yasa, sıkıyönetim, havuz, askıya alma | Yabancı bülten sayıları (03 §8.2) |
| **Yardım puanı** `Y_c` | 0 … 1 | 0 | §6.4 | 02 §4.1 puanının 150 puanlık kalemi |

**İlişki değişimleri** (hedefin sana karşı ilişkisi):

| Eylem | Δ | Eylem | Δ |
|---|---|---|---|
| Gıda yardımı aldı (10 günlük ulusal ihtiyacı başına) | +15 | Mültecisi kabul edildi (olay ya da anlaşma) | +20 |
| Doz yardımı aldı (nüfusunun %1'i kadar doz başına) | +20 | Mültecisi reddedildi | −10 |
| Tıbbi heyet aldı | +10 | Sınırını ona kapattın (onun bildirilen yaygınlığı seninkinin 2 katından azken) | −15 |
| Ortak kordon paktı / bilgi paktı | +20 / +10 | Sınırını ona kapattın (haklı durumda) | −5 |
| Konsey'de lehine / aleyhine oy | +3 / −5 | Konsey'e şikâyet ettin | −20 |
| Bölgesel yönetimini tanıdın (yönetim / ana ülke) | +30 / −20 | Himaye talebini kabul ettin | +25 |
| İade ettin (yeniden kurulan ülke) | +50 | Savaş gerekçesi hazırladın | −50 |

**İtibar değişimleri** (olay bileşeni): yardım (her +0,02 Y için +1; 90 günde en çok +10) · tıbbi heyet +3 · mülteci kabulü +3 / kamp +2 /
ret −3 · bulgu paylaşımı +2 · laboratuvar kazasını bildirmek +5 / gizlenen kazanın sızması −15 (05 §10.5) · rızasız deney −10 (05 §10.1) ·
Konsey kararına uymamak −3 · kınanmak −15 · denetimi reddetmek −12 · Çöküş evresinde savaş ilanı −20 · iade +15 · aşı havuzu +10 / +15.

### 6.2 Eylemler (diplomasi paneli; S6 ya da Salgın paneli)

| # | Eylem (EN / TR) | Bedel | Şart | Etki | Karşı taraf |
|---|---|---|---|---|---|
| 1 | Border posture / Sınır tutumu | Açık ↔ denetimli 0; kapalı 10 nüfuz | Kara ya da deniz komşusu | 03 §7: yolcu ×1 / ×0,5 / ×0,05; ticaret 07 §7.2 | Tek taraflı; ilişki tablosu. Konsey'in seyahat uyarısından (R1) sertse itibar −3 |
| 2 | Port quarantine / Liman karantinası (k gün) | 0 | Limanı var | 03 §8.3; 07 `30/(30+k)` | Tek taraflı. Konsey'in liman kuralı (R2) kabul edildiyse belgeli gemiye 6 günü aşan her ay itibar −1 |
| 3 | Send aid / Yardım gönder: gıda (07), doz (05), malzeme (`equipment`), tıbbi heyet (05) | Verilen | Hedef Sarsılmış ya da yardım istiyor | Y (§6.4), ilişki, itibar | Kabul eder (yardım reddedilmez) |
| 4 | Appeal for aid / Yardım çağrısı | 10 nüfuz; 90 günde bir | Anavatanda salgın var | Yapay zekâ bağışçıları ay sonunda karar verir (§6.7). Yardım gelirse istikrar +%2 (180 günde bir) | — |
| 5 | Share findings, request findings, joint institute / Bulgu paylaş, bulgu iste, ortak enstitü | 05 §9 | 05 §9 | 05 §9 | §6.3 formülü |
| 6 | Reception accord / Mülteci kabul anlaşması | 25 nüfuz | Karşı tarafın sınır havuzu var | 365 gün boyunca o kaynaktan gelen mülteciye kamp politikası uygulanır (oyuncu imzalar; her geliş için ayrı olay gelmez) | Kaynak ülke +20 ilişki; ev sahibine itibar +3 |
| 7 | Joint cordon pact / Ortak kordon paktı | 30 nüfuz | Kara komşusu | İki taraf da birbirine geçiş verir (`grant_access`); ortak sınırda kaçak ×0,85; iki tarafa da bildirim gecikmesi −1 gün; 365 gün | §6.3; e_eylem +0,20 (iki tarafta da salgın varsa) |
| 8 | Clean Port Accord / Temiz Liman Anlaşması | 20 nüfuz | 07 §7.4 | 07 §7.4. Bir limanda yeni vaka çıkarsa antlaşma maddesi gereği askıya alınır; oyuncuya bildirilir | e_eylem +0,30 |
| 9 | Protectorate claim / Koruma altına al | 25 nüfuz / eyalet | §5.4 | §5.4 | — |
| 10 | Recognise / Tanı | 0 | Hedef bölgesel yönetim | Ticaret ve geçiş mümkün olur; ilişki tablosu | Yönetim her zaman kabul eder |
| 11 | Complain to the Council / Konsey'e şikâyet et | 15 nüfuz | Konsey üyesi; hedef τ < 0,5 ya da Çöküş'te savaş ilan etmiş | Gündeme R7 ya da R9 tasarısı girer | İlişki −20 |
| 12 | Justify war / Savaş gerekçesi | 60 nüfuz | §5.5 | Motorun gerekçe kuralı | İtibar −10 |

### 6.3 Kabul formülü (05 §9 formülünün genişletilmiş hâli)

```
kabul = clamp( 0,15 + 0,004·r_hedef→öneren + 0,25·karşılıklılık + 0,010·KSE + 0,01·(I_öneren − 50)
               − 0,30·rakip − 0,20·aynı_zafer + e_eylem ; 0,02 ; 0,95 )
```
- 05'teki "tutum" terimi burada ilişki (`r`) olarak kesinleşir. Ölçeği ±0,40'tır.
- **İtibar terimi** ±0,50'dir. Sıkıyönetimin −20'lik itibar bedeli, 02 §3.4'teki "kabul oranları −%20" ile birebir örtüşür.
- `e_eylem`: ortak kordon +0,20 (iki tarafta salgın varken) · temiz liman +0,30 · mülteci kabul anlaşmasında **ev sahibinden istenen**
  (−0,30·[ev sahibinin YE ≥ 0,10] − 0,10·ev sahibinin yük kademesi).
- **Örnek:** Türkiye (itibar 58), Bulgaristan'a ortak kordon öneriyor. Bulgaristan'ın ilişkisi +10, karşılıklılık 0, KSE 18, iki tarafta da
  salgın var: 0,15 + 0,04 + 0,18 + 0,08 + 0,20 = **%65**.

### 6.4 Yardım puanı (02 §4.1'in normalize edilmesi)

```
Y = clamp( Y_mülteci + Y_yardım + Y_bilim + Y_koruma − cezalar ; 0 ; 1 )

Y_mülteci = 0,35 · min(1 ; kabul edilen mülteci / (0,01 · N⁰))
Y_yardım  = 0,30 · min(1 ; yararlanan / (0,02 · N⁰))      yararlanan = gıda birimi·10⁶/365 + gönderilen doz
Y_bilim   = min(0,15 ; 0,03·paylaşım + 0,05·ortak enstitü + 0,10·tıbbi heyet)     (heyet değeri 05 §9'dan)
Y_koruma  = 0,20 · min(1 ; korunan yaşayan nüfus / (0,05 · N⁰)) + 0,10 · iade edilen ülke
cezalar   : bilim insanı mültecilerini geri çevirmek −0,05 (05 §10.7)
```
- **N⁰ bağışçının 1936 nüfusudur.** Böylece küçük ülke de tam puan alabilir.
- **%1 mülteci:** 1922'de Yunanistan nüfusunun dörtte biri kadar mülteci aldı (07). Eşik bunun yirmi beşte biridir; çöken bir ülkenin
  komşusu buna ulaşabilir.
- **%2 yararlanan:** Amerikan Yardım İdaresi 1922 yazında Rusya'da günde 10 milyonu aşkın kişiyi doyurdu. Bu, ABD nüfusunun yaklaşık
  %9'uydu. Eşik bu çabanın dörtte birinden azıdır. Bir kişinin bir yıllık azığı 07'nin biriminde 1/365 × 10⁶'dır. Türkiye için tam puan
  yaklaşık 117 gıda birimi ya da 320.000 doz eder; bu da yaklaşık 7 günlük ulusal tüketimdir.
- Kalemlerin tavanları toplamı 1'dir. Oyuncu tek bir yolla en çok 0,35 alabilir: **dayanışmanın birden çok yolu vardır.**

### 6.5 Mülteci anlaşmaları ve tarih

| Tarih | Ne oldu? | Moddaki karşılığı |
|---|---|---|
| 1922 | Nansen pasaportu: vatansız mültecilere kimlik belgesi; 50'yi aşkın hükümet tanıdı | Kabul anlaşması (eylem 6): tek bir imzayla bir yıllık kural |
| 1923–30 | Yunan Mülteci İskân Komisyonu, Milletler Cemiyeti gözetiminde dış borçla iskân (07 §10.4) | Konsey'in yardım çağrısı (R3) ve İskân Programı (07) |
| 1933 | Mültecilerin Uluslararası Statüsüne İlişkin Sözleşme: geri göndermeme ilkesinin ilk yazılı taahhütlerinden biri (md. 3); az sayıda devlet onayladı | Ret seçenekleri vardır ama itibar kaybettirir ve hiçbir puan getirmez |
| Temmuz 1938 | Évian Konferansı: 32 ülke toplandı, neredeyse hiçbiri kotasını artırmadı; yalnız Dominik Cumhuriyeti büyük sayıda kabul önerdi | Yük Paylaşım Planı (R6): yapay zekâ "evet" oyu verir ama kotayı düşük olasılıkla kabul eder (§6.6) |
| Mayıs–Haziran 1939 | St. Louis gemisi: çoğu zulümden kaçan 937 yolcu Küba, ABD ve Kanada'dan geri çevrildi, Avrupa'ya döndü | Olay D8 "Kimsenin İstemediği Gemi" (metinde hiçbir halk anılmaz) |
| Ocak–Şubat 1939 | Retirada: Fransa sınırı önce kapalı tuttu, sonra açtı; kamplar (03, 07) | 07'nin "Sınırda Mülteciler" olayı ve kamp ekonomisi |

### 6.6 Uluslararası Karantina Konseyi

**Kimlik.** 1936'da iki kurum vardır: 1907 Roma anlaşmasıyla Paris'te kurulan Uluslararası Halk Sağlığı Bürosu ve 1923'ten itibaren
Cenevre'de çalışan Milletler Cemiyeti Sağlık Teşkilatı (Singapur bülteni onundur). Modda Alarm evresine girilince bu iki kurumun daimî
kurulları ortak bir organ kurar: **Uluslararası Karantina Konseyi / International Quarantine Council**. Ad bizimdir; kurumsal biçim tarihîdir.
Merkezi Cenevre'dir (İsviçre'nin başkent eyaleti). Konsey'i yapay zekâ yürütür; oyuncu onu yönetmez (01 §3b).

**Üyelik.** Alarm'da her ülkeye davet gelir (olay D1). Yapay zekâ ülkeleri demokrat ve bağlantısızsa %90, faşist ve komünistse %60
olasılıkla katılır. 1930'larda Milletler Cemiyeti'nden ayrılanlar (Japonya ve Almanya 1933, İtalya 1937) otoriter rejimlerdi. Aidat
yılda 25 nüfuzdur. Aidatı ödemeyen üye oy hakkını kaybeder. Sarsılmış ülkeler aidattan muaftır.

**Kapasite.** Aynı anda en çok `1 + floor(aidat ödeyen üye / 15)` heyet yürütülür. 60 üyede bu 5 heyettir.

**Aylık oturum** (her ayın ilk pazartesi). Tetiklenen tasarılardan en yüksek öncelikli olanı oylanır. Tasarı, aidat ödeyen
üyelerin yarısı oy kullanır ve "evet" oyları "hayır"ı geçerse kabul edilir. Oyuncu üyeyse ilgili olay açılır; öteki tasarılarda
oyuncuya "Konsey Oylaması" olayı gelir (evet / hayır / çekimser).

| Öncelik | Kod | Tasarı (EN / TR) | Gündeme gelir | İçerik | Uyum / ihlal | Yapay zekânın "evet" olasılığı |
|---|---|---|---|---|---|---|
| 1 | R9 | Censure / Kınama | Bir üye Çöküş evresinde savaş ilan etti ya da gizlediği kaza sızdı | Hedefin itibarı −15 | — | 0,6 − 0,5·[hedef müttefik] |
| 2 | R7 | Data Inspection / Veri Denetimi | Bir üyenin τ'su < 0,5 ve komşusu ondan kaynaklanan vaka bildiriyor | Müfettiş heyeti (olay D4) | Ret: itibar −12 | 0,55 − 0,4·[oy verenin τ'su < 0,5] |
| 3 | R3 | Aid Appeal / Yardım Çağrısı | Bir üye Sarsılmış | 60 gün içinde katkıda bulunan üyeye itibar +3 | — | 0,8 |
| 4 | R4 | Commission Mission / Komisyon Heyeti | Bir üyede bildirilen vaka > 1.000 ve τ ≥ 0,5 | Hedef kabul ederse 180 gün boyunca `detection +0,10` ve β −%5 | Hedef reddederse itibar −5 | 0,75 |
| 5 | R6 | Burden-Sharing Plan / Yük Paylaşım Planı | Sınır havuzlarında toplam ≥ 200.000 mülteci | Kota `q_c ∝ N⁰_c · (1 − YE_c)`, toplam havuzun yarısı (olay D3) | Ret: itibar −3 | Oy 0,6; **kotayı kabul** 0,3 − 0,3·[YE ≥ 0,2] − 0,1·yük kademesi |
| 6 | R1 | Travel Advisory / Seyahat Uyarısı | Bir ülkede YE_bild ≥ 0,10 | Üyelere o ülkeye "denetimli" sınır önerilir | Kapalı: −3 (orantısız); açık: −2 (ihmal) | 0,6 + 0,3·[komşu] − 0,9·[oy veren hedefin kendisi] |
| 7 | R8 | Vaccine Pool / Aşı Havuzu | Evre ≥ Karşı Saldırı ve bir üye aşı üretiyor | Üreten üyelerden serbest bırakılan dozun %10'u istenir; havuz en çok etkilenen üyelere dağıtılır (olay D11) | Katılmamak: itibar −10 | Üretmeyen 0,8; üreten 0,3 |
| 8 | R2 | Port Rules / Liman Kuralları | Alarm'da bir kez | Belgeli gemiye en çok 6 gün karantina (olay D2) | 6 günü aşmak: ayda itibar −1 | 0,6 + 0,2·[ihracatçı] |
| 9 | R5 | Serum Standard / Serum Standardı | Bir üye serumu bulunca | 05 §9'daki Standart Birim Komisyonu | 05 | 05 |

**Neden bu tasarılar?** 1926 Uluslararası Sıhhiye Sözleşmesi hem bildirimi zorunlu kıldı hem de karantinayı sınırladı: kolerada 5,
vebada 6 gün (03 §8.3). Konsey'in iki yüzü de budur: **gizlemeye karşı denetim, aşırılığa karşı ölçü.** 1911 Nisan'ında Mukden'de
11 ülkenin katıldığı Uluslararası Veba Konferansı, Mançurya salgınının ardından ortak bilimsel bulguları kayda geçirdi. 1920–22'de
Milletler Cemiyeti'nin Salgın Komisyonu Polonya'da tifüse karşı heyetlerle çalıştı. Aşı Havuzu tarihte yoktur; modun geleceğe dönük
tek icadıdır ve yalnız Karşı Saldırı evresinde açılır.

**Evrelere göre Konsey:** Sessizlik: yok (olağan kurumlar çalışır) · Alarm: kuruluş, davet, R2 · Yayılma: R1, R3, R4, R6 · Çöküş: R7, R9;
merkez tehlikedeyse olay D10 · Karşı Saldırı: R8; iade gözetimi (olay C5'in ikinci seçeneği) · Sonuç: yalnız R3.

**Sürgün.** Merkez eyaleti SALGIN ya da DÜŞMÜŞ olursa, ya da İsviçre çökerse, olay D10 gelir. Ev sahibi çıkmazsa Konsey kapasitesini
yarıya indirerek "sürgünde" sürer. 1940'ta Milletler Cemiyeti'nin ekonomi ve maliye birimleri Princeton'a, Uluslararası Çalışma Örgütü
Montreal'e taşındı; kurumlar yer değiştirerek yaşadı.

### 6.7 Yapay zekânın diplomasisi (`rules.gd`)

| Konu | Kural |
|---|---|
| Sınır tutumu (her 14 günde) | j'nin YE_bild'i < 0,01 → açık · 0,01–0,10 → denetimli · ≥ 0,10 ya da j çökmüşse → kapalı. Kararname Yönetimi eşikleri yarıya iner |
| Bağışçılık (ay sonunda) | Kendi YE_bild'i < 0,05, istikrarı ≥ 0,40 ve gıda oranı ≥ 1,05 ise 10 günlük gıdayı, çağrı yapanlardan `ihtiyaç × (r + 100)/200` puanı en yüksek olana gönderir. Aşı kapsamı ≥ ½ V_c ise dozların %10'u R8 havuzuna |
| Ortak kordon | Kara komşusunda salgın varsa ve r ≥ 0 ise 180 günde bir önerir (oyuncuya olay D7) |
| Koruma, tanıma | §5.4; askerî valilikleri r ≥ −20 ise tanır |
| Protesto | Oyuncunun ona karşı "haksız" kapalı sınırı 30 gün sürmüşse olay D5 |
| Savaş | §5.5 |

## 7. Olaylar

### 7.1 Yazım kuralları

- **Biçim:** Mevcut `events.json` biçimi kullanılır (`title`, `desc`, `options[name, effects, ai, require]`). `trigger` alanı `null` olur.
  Şarta bağlı gönderimi `own/politics.json` içindeki dağıtıcı yapar (§10.3): her olay için `scope` (player / ai / all), `require`
  (şart listesi), `chance_per_week`, `cooldown_days`, `once`. Yapay zekâya gelen olaylarda motor `ai` ağırlığıyla seçer.
- **Tablo yazımı:** `anahtar: değer`, JSON'daki `{"anahtar": değer}` öğesidir. Yardımcı alanlar köşeli ayraçla gösterilir:
  `transmission: +0.05 [days 14]` → `{"transmission": 0.05, "days": 14}`. Ondalık ayırıcı JSON'da noktadır.
- **Kullanılan anahtarlar:** motorun kendi anahtarları · 03 §7'dekiler (`transmission`, `suppression`, `detection`, `border_posture`,
  `refugee_policy` …) · 05 §12.4'tekiler (`zm_vaccine_trust`, `zm_scientists` …) · 07 §14'tekiler (`zm_food_stock` …) · bu belgenin
  yenileri (§10.5).
- **Ton** (01 §6): resmî 1930'lar dili. Kan, vahşet, gerçek kişi, "zombi" sözcüğü, dinî imge ve halk adı yoktur.

### 7.2 A — Hükümet ve iç siyaset (16 olay)

**A1 `zm_pol_cabinet_emergency` — Emergency Cabinet Meeting / Olağanüstü Kabine Toplantısı.** Tetik: anavatanda ilk bildirilen vaka
(`zm_homeland_reported_at_least: 1`), bir kez, herkese.
> EN: *"The Minister of Health reads the district officer's telegram aloud: fever, confusion, a bite. The cabinet must decide how the
> country will hear of it."* TR: *"Sağlık Bakanı kaymakamın telgrafını yüksek sesle okuyor: ateş, bilinç bulanıklığı, bir ısırık. Kabine,
> ülkenin bunu nasıl duyacağına karar vermeli."*

| Seçenek (EN / TR) | Etki | AI |
|---|---|---|
| Declare a national emergency / Ulusal olağanüstü hal ilan edin | `zm_set_law: {zm_emergency: zm_emergency_powers}`; `war_support: +0.03`; `stability: -0.02` | 0,4 |
| Form a scientific crisis committee / Bilimsel kriz kurulu kurun | `pp: -50`; `zm_timed_spirit: zm_crisis_committee [days 180]` (`zm_detection +0,05`, `research_speed +0,03`) | 0,4 |
| "The situation is under control" / "Durum kontrol altında" | `stability: +0.03`; `war_support: -0.03`; `zm_concealment: +2000` | 0,2 |

**A2 `zm_pol_stances_form` — Public Opinion Takes Sides / Kamuoyu Saf Tutuyor.** Tetik: dünya Alarm evresine girer; herkese, bir kez.
Dört pay 0,25'ten başlar (§4.2).

| Seçenek | Etki | AI |
|---|---|---|
| "Science will guide us" / "Bize bilim yol gösterecek" | `zm_stance: {health: +0.05}`; `zm_timed_spirit: zm_line_science [days 180]` (`zm_compliance +0,03`) | 0,4 |
| "Order before all" / "Her şeyden önce düzen" | `zm_stance: {order: +0.05}`; `pp: +25` | 0,3 |
| "No one will go hungry" / "Kimse aç kalmayacak" | `zm_stance: {livelihood: +0.05}`; `stability: +0.02` | 0,3 |

**A3 `zm_pol_election_shadow` — An Election in the Shadow of the Sickness / Salgının Gölgesinde Seçim.** Tetik: seçime ≤ 21 gün
(`zm_election_within: 21`); `zm_phase_at_least: alarm`; anavatanda bildirilen vaka > 0.

| Seçenek | Etki | AI |
|---|---|---|
| Hold it as scheduled / Seçim takvimde yapılsın | `transmission: +0.05 [days 14]`; `stability: +0.02` | 0,5 |
| Postpone by one year / Bir yıl ertelensin — şart: `zm_law_at_least: {zm_emergency: zm_emergency_powers}` | `zm_postpone_election: 12`; `stability: -0.03`; `zm_standing: -3`; `zm_ruling_popularity: -0.03` | 0,3 |
| Spread voting over a month / Oylama bir aya yayılsın | `pp: -50` | 0,2 |

**A4 `zm_pol_quarantine_unrest` — Disturbance at the Quarantine Station / Karantina İstasyonunda Kargaşa.** Tetik:
`zm_law_at_least: {zm_quarantine: zm_home_isolation}`, `zm_stability_below: 0.35`, `zm_fatigue_at_least: 4`; haftada %8; 120 gün bekleme.

| Seçenek | Etki | AI |
|---|---|---|
| Hear grievances, pay compensation / Şikâyetleri dinleyin, tazminat ödeyin | `pp: -40`; `stability: +0.02`; `zm_fatigue: -2` | 0,45 |
| Send the gendarmerie / Jandarma gönderin | `stability: -0.05`; `war_support: -0.03`; `zm_standing: -3`; `zm_stance: {order: +0.03}`; `zm_unrest: +1` | 0,35 |
| Ease the rules in that district / O ilçede kuralları gevşetin | `transmission: +0.10 [days 60, where event_state]`; `stability: +0.03` | 0,2 |

Dayanak: 1771 Moskova veba kargaşası; 1830–31 ve 1892 Rusya kolera ayaklanmaları.

**A5 `zm_pol_search_parties` — The Search Parties / Arama Ekipleri.** Tetik: `zm_law_at_least: {zm_emergency: zm_curfew}`, `zm_ye_at_least: 0.05`; bir kez.
> TR: *"Valilik, hastaları saklayan evleri bulmak için askerlerin kapı kapı dolaşmasını öneriyor."*

| Seçenek | Etki | AI |
|---|---|---|
| Soldiers search house by house / Askerler ev ev arasın | `detection: +0.10 [days 60]`; `stability: -0.06`; `zm_stance: {order: +0.03, health: -0.02}`; `zm_chain: {event: zm_pol_inspector_attacked, chance: 0.35, delay: 30}` | 0,35 |
| Local doctors and health visitors, with consent / Yerel hekim ve sağlık ziyaretçileri, rızayla | `pp: -40`; `detection: +0.05 [days 60]` | 0,5 |
| Rely on notification / Bildirime güvenin | — | 0,15 |

**A6 `zm_pol_inspector_attacked` — An Inspector Is Attacked / Bir Müfettişe Saldırı.** Tetik: A5'in ilk seçeneğinin zinciri.
Dayanak: 1897'de Pune'da veba önlemlerini yürüten kurul, İngiliz askerleriyle ev araması yaptı. Veba komiseri Rand 22 Haziran 1897'de
suikaste kurban gitti. Aynı yıl çıkarılan Salgın Hastalıklar Yasası hükümete geniş yetkiler tanıyordu.

| Seçenek | Etki | AI |
|---|---|---|
| Public inquiry and reform / Açık soruşturma ve düzenleme | `pp: -30`; `stability: +0.03`; `detection: -0.03 [days 60]` | 0,4 |
| Crackdown / Sert kovuşturma | `stability: -0.08`; `zm_standing: -5`; `zm_unrest: +1`; `flag_target: zm_army_ascendant` | 0,3 |
| Withdraw soldiers, send health visitors / Askerleri çekin, sağlık ziyaretçisi gönderin | `pp: -20`; `stability: +0.02`; `detection: -0.05 [days 60]` | 0,3 |

**A7 `zm_pol_whispers` — Whispers Against Neighbours / Komşuya Kara Çalmak.** Tetik: `zm_ye_at_least: 0.10`, `zm_stability_below: 0.40`; 365 gün bekleme.
> TR: *"Bir söylenti hastalığı geçen yıl kasabaya yerleşen ailelere yüklüyor. Vali gerginliğin arttığını bildiriyor."*

| Seçenek | Etki | AI |
|---|---|---|
| The government speaks: this sickness has no nation / Hükümet konuşsun: bu hastalığın milleti yoktur | `pp: -30`; `zm_standing: +3`; `zm_stance: {solidarity: +0.03}` | 0,5 |
| Police protect the threatened streets / Polis tehdit altındaki sokakları korusun | `pp: -20`; `stability: -0.02`; `zm_standing: +1` | 0,4 |
| Stay silent / Sessiz kalın | `zm_timed_spirit: zm_communal_unrest [days 120]` (`stability −0,06`, `factory_output −0,03`); `zm_standing: -5` | 0,1 |

**Zulüm seçeneği yoktur.** Sessiz kalmanın yalnız bedeli vardır (01 §6.4). Dayanak: 1348–49 Kara Ölüm pogromları (Strazburg, 14 Şubat 1349);
Papa VI. Clemens 1348'de iki fermanla suçlamanın asılsız olduğunu duyurdu. 1900'de San Francisco'da bir göçmen mahallesini hedef alan
karantinayı federal mahkeme ayrımcı bularak kaldırdı (*Jew Ho v. Williamson*).

**A8 `zm_pol_leaked_report` — The Leaked Report / Sızan Rapor.** Tetik: örtbas tehlikesi (§3.5, haftalık p).
> EN: *"A provincial daily has printed the true figures from a ministry memorandum. The capital's cafés speak of nothing else."*
> TR: *"Bir taşra gazetesi bakanlık notundaki gerçek sayıları bastı. Başkentin kahvelerinde başka bir şey konuşulmuyor."*

| Seçenek | Etki | AI |
|---|---|---|
| Admit and publish the figures / Kabul edin, sayıları yayımlayın | `stability: -0.06`; `zm_concealment: reset`; `zm_standing: +2`; `zm_stance: {health: +0.03}` | 0,4 |
| Deny / Yalanlayın | `zm_concealment_mult: 1.5`; `zm_chain: {event: zm_pol_second_leak, chance: 0.5, delay: 45}` | 0,35 |
| Close the newspaper / Gazeteyi kapatın — şart: `zm_law_at_least: {zm_information: zm_news_control}` | `zm_standing: -5`; `zm_concealment_mult: 1.2`; `zm_stance: {order: +0.02, health: -0.03}` | 0,25 |

**A9 `zm_pol_second_leak` — The Second Leak / İkinci Sızıntı.** Tetik: A8'in ikinci seçeneğinin zinciri.

| Seçenek | Etki | AI |
|---|---|---|
| The cabinet resigns / Kabine istifa etsin | `pp: -100`; `stability: -0.04`; `zm_concealment: reset`; `zm_timed_spirit: zm_fresh_cabinet [days 180]` (`stability +0,06`, `war_support +0,03`) | 0,4 |
| Blame the officials / Suçu memurlara yükleyin | `stability: -0.10`; `zm_standing: -8`; `zm_concealment: reset` | 0,4 |
| Martial law and full censorship / Sıkıyönetim ve tam sansür — şart: `zm_phase_at_least: spread` | `zm_set_law: {zm_emergency: zm_martial_law, zm_information: zm_full_censorship}`; `zm_standing: -10` | 0,2 |

**A10 `zm_pol_minister_resigns` — The Health Minister Resigns / Sağlık Bakanı İstifa Etti.** Tetik: bir kez, şunlardan ilki gerçekleşince:
05'teki kaza haberinin sızması, `zm_unrest_at_least: 3`, `zm_fallen_share_at_least: 0.10`.

| Seçenek | Etki | AI |
|---|---|---|
| Appoint an expert / Bir uzman atayın | `pp: -50`; `zm_timed_spirit: zm_expert_minister [days 365]` (`zm_detection +0,03`, `stability +0,02`) | 0,45 |
| Appoint a party loyalist / Partiden güvenilir birini atayın | `stability: +0.03`; `zm_timed_spirit: zm_loyal_minister [days 365]` (`zm_detection −0,03`) | 0,35 |
| The Prime Minister takes the portfolio / Başbakan bakanlığı üstlensin | `pp: +25`; `stability: -0.03` | 0,2 |

**A11 `zm_pol_fatigue` — The City Tired of Waiting / Bekleyişten Bıkan Şehir.** Tetik: `zm_fatigue_at_least: 6`; 180 gün bekleme.

| Seçenek | Etki | AI |
|---|---|---|
| Phased reopening / Aşamalı açılış | `zm_relax_law: zm_quarantine`; `zm_fatigue: -4`; `zm_stance: {livelihood: +0.03, health: -0.02}` | 0,4 |
| Hold with support payments / Destek ödemesiyle sürdürün | `zm_timed_spirit: zm_support_payments [days 180]` (`consumer_goods_mod +0,03`, `war_support +0,03`); `zm_fatigue: -2` | 0,35 |
| Hold the line / Çizgiyi koruyun | `war_support: -0.03`; `zm_stance: {livelihood: +0.04}` | 0,25 |

`zm_relax_law` gevşetmeyi oyuncu adına yapmaz: oyuncunun bu seçeneği seçmesi bir karardır ve bedeli (`relax_cost`) alınmaz.

**A12 `zm_pol_general_strike` — General Strike / Genel Grev.** Tetik: `zm_stance_share_at_least: {livelihood: 0.33}` ve
(`zm_food_ratio_below: 0.9` ya da `zm_workforce_below: 0.85`, 07); 365 gün bekleme.

| Seçenek | Etki | AI |
|---|---|---|
| Wage and ration concessions / Ücret ve azık tavizi | `pp: -60`; `zm_timed_spirit: zm_wage_concessions [days 180]` (`consumer_goods_mod +0,04`, `stability +0,04`) | 0,45 |
| Emergency labour order / Olağanüstü çalışma emri — şart: `zm_law_at_least: {zm_service: zm_labour_service}` | `stability: -0.08`; `zm_timed_spirit: zm_labour_order [days 90]` (`factory_output +0,03`); `zm_stance: {order: +0.03, livelihood: +0.03}` | 0,25 |
| Arbitration board / Hakem kurulu | `pp: -30`; `zm_timed_spirit: zm_arbitration [days 30]` (`factory_output −0,10`); `stability: +0.03` | 0,3 |

Dayanak: 1896–97 Hamburg liman grevi (07). İngiltere'nin 1920 yasası grevler için çıkarıldı ama zorunlu sanayi hizmetini yasakladı.

**A13 `zm_pol_generals_memo` — The Generals' Memorandum / Generallerin Muhtırası.** Tetik: Sıkıyönetim 180 gündür yürürlükte ya da
(`zm_stability_below: 0.15` ve kordon ≥ 3 kez yarılmış); bir kez.

| Seçenek | Etki | AI |
|---|---|---|
| Hand the cordon zones to the army / Kordon bölgelerini orduya verin | `zm_timed_spirit: zm_army_cordon_control [days 180]` (`zm_garrison_kappa_mult +0,15`, `political_power_gain −0,10`); `stability: -0.03`; `flag_target: zm_army_ascendant` | 0,4 |
| Reassert civilian authority / Sivil otoriteyi hatırlatın | `pp: -75`; `war_support: -0.03` | 0,3 |
| Bring soldiers into the cabinet / Askerleri kabineye alın | `spirit: zm_military_ministers` (`defense +0,05`, `political_power_gain −0,05`) | 0,3 |

**A14 `zm_pol_barracks_night` — Night of the Barracks / Kışla Gecesi.** Tetik: `has_flag: zm_army_ascendant`, `zm_stability_below: 0.15`;
haftada %10; bir kez.

| Seçenek | Etki | AI |
|---|---|---|
| Yield to a military directorate / Askerî yönetim kuruluna bırakın | `set_leader: {en: "Military Directorate", tr: "Askerî Yönetim Kurulu"}`; `zm_set_law: {zm_emergency: zm_martial_law}`; `stability: +0.10`; `zm_standing: -15`; `zm_postpone_election: 48` | 0,35 |
| Resist with loyal units and parliament / Sadık birlikler ve meclisle direnin | `stability: -0.08`; `war_support: +0.05`; `zm_clear_flag: zm_army_ascendant` | 0,35 |
| Negotiate a caretaker government / Geçici hükümette uzlaşın | `pp: -100`; `stability: +0.05`; `zm_clear_flag: zm_army_ascendant`; `zm_timed_spirit: zm_caretaker [days 365]` (`political_power_gain −0,10`) | 0,3 |

Oyuncu ilk seçenekte de oynamayı sürdürür. Değişen şey lider alanı ve rejim durumudur (§2.7: yönetim ideolojisi değişmez, yasalar sertleşir).

**A15 `zm_pol_move_government` — Move the Government? / Hükümet Taşınsın mı?** Tetik: `zm_capital_threatened` (başkent eyaleti SALGIN
ya da komşusu DÜŞMÜŞ); bir kez; başkent eyaleti düşerse yeniden.

| Seçenek | Etki | AI |
|---|---|---|
| Move to a safer city / Daha güvenli bir şehre taşının | `zm_move_capital: safest`; `pp: -50`; `stability: -0.05` | 0,5 |
| The government stays / Hükümet yerinde kalır | `war_support: +0.08` | 0,3 |
| Ministries leave, the cabinet stays / Bakanlıklar gitsin, kabine kalsın | `pp: -25`; `war_support: +0.04`; `zm_timed_spirit: zm_split_government [days 90]` (`political_power_gain −0,10`) | 0,2 |

"En güvenli" şehir: DÜŞMÜŞ eyalete en az iki eyalet uzaklıkta olan, bildirilen yaygınlığı en düşük ve zafer puanı en yüksek eyalettir.
Taşınma, teslim hesabındaki "başkent düştü +%10" terimini önler (02 §4.2).

**A16 `zm_pol_mourning` — A Day of National Mourning / Ulusal Yas Günü.** Tetik: salgın ölümleri anavatan nüfusunun %1'ini, sonra %5'ini geçer
(`zm_homeland_dead_at_least`).

| Seçenek | Etki | AI |
|---|---|---|
| Declare a day of mourning / Yas günü ilan edin | `pp: -10`; `war_support: +0.05`; `stability: +0.02` | 0,7 |
| Keep the factories running / Fabrikalar çalışmayı sürdürsün | `war_support: -0.03` | 0,3 |

### 7.3 B — Tedavinin siyaseti (3 olay)

**B1 `zm_pol_serum_priority` — Who Gets the Serum First? / Serum Önce Kime?** Tetik: `zm_tech_any: [zm_hyperimmune_serum]` (05) ve stok ihtiyacın
altında; bir kez. Seçeneklerin hepsi etik açıdan savunulabilir; hiçbiri bir gruba göre ayrım yapmaz.

| Seçenek | Etki | AI |
|---|---|---|
| By medical need / Tıbbi ihtiyaca göre | `zm_stance: {health: +0.03}`; `stability: +0.01` | 0,5 |
| Cordon troops and medical staff first / Önce kordon askeri ve sağlık personeli | `zm_timed_spirit: zm_serum_front_first [days 180]` (`zm_inranks_mult −0,20`); `zm_stance: {order: +0.03}`; `stability: -0.02` | 0,3 |
| Essential workers first / Önce temel iş kolları | `zm_timed_spirit: zm_serum_workers_first [days 180]` (`factory_output +0,03`); `zm_stance: {livelihood: +0.03}`; `stability: -0.02` | 0,2 |

**B2 `zm_pol_vaccine_mandate` — Compulsory Vaccination? / Aşı Zorunlu mu Olsun?** Tetik: kendi aşı dağıtımın başladı; bir kez.

| Seçenek | Etki | AI |
|---|---|---|
| Compulsory, with conscientious exemption / Zorunlu, vicdani muafiyetle | `spirit: zm_vaccine_mandate_exempt` (`zm_distribution_mult +0,15`); `zm_vaccine_trust: -0.05 [days 180]`; `stability: -0.02` | 0,4 |
| Compulsory, no exemptions / Zorunlu, muafiyetsiz | `spirit: zm_vaccine_mandate_strict` (`zm_distribution_mult +0,25`); `zm_vaccine_trust: -0.15 [days 180]`; `stability: -0.06`; `zm_chain: {event: zm_pol_vaccine_riot, chance: 0.35, delay: 30}` | 0,25 |
| Voluntary, with a public campaign / Gönüllü, kamu kampanyasıyla | `pp: -40`; `zm_vaccine_trust: +0.10 [days 180]`; `zm_distribution_mult: +0.05 [days 180]` | 0,35 |

Dayanak: Leicester'da 1885'te zorunlu aşıya karşı büyük bir gösteri yapıldı; kent bildirim ve tecride dayanan kendi yöntemini uyguladı.
İngiltere 1898 Aşı Yasası'yla vicdani ret maddesi getirdi. Etki değerleri 05 §12.4'teki `zm_vaccine_trust` ve dağıtım çarpanı ölçeğindedir.

**B3 `zm_pol_vaccine_riot` — The Vaccine Riot / Aşı Kargaşası.** Tetik: B2'nin ikinci seçeneğinin zinciri. Dayanak: Rio de Janeiro,
Kasım 1904. Ekim sonunda çıkarılan zorunlu çiçek aşısı yasası bir haftalık ayaklanmaya yol açtı; hükümet sıkıyönetim ilan etti ve
zorunluluğu askıya aldı.

| Seçenek | Etki | AI |
|---|---|---|
| Repeal compulsion / Zorunluluğu kaldırın | `remove_spirit: zm_vaccine_mandate_strict`; `stability: +0.05`; `war_support: -0.02` | 0,4 |
| State of siege / Sıkıyönetim | `zm_set_law: {zm_emergency: zm_martial_law}`; `stability: -0.10`; `zm_standing: -10` | 0,2 |
| Negotiate exemptions / Muafiyet üzerinde uzlaşın | `remove_spirit: zm_vaccine_mandate_strict`; `spirit: zm_vaccine_mandate_exempt`; `pp: -50`; `stability: +0.02` | 0,4 |

### 7.4 C — Çöküş (6 olay)

**C1 `zm_col_provinces_cut_off` — The Cut-Off Provinces / Kopan Eyaletler.** Tetik: oyuncunun kopuk grubu için oluşum denetimi başarılı oldu (§5.2).

| Seçenek | Etki | AI |
|---|---|---|
| Grant provisional autonomy / Geçici özerklik tanıyın | `zm_regional_autonomy: {group: event_group, loyal: true}`; `stability: -0.03` | — |
| Send a plenipotentiary / Tam yetkili temsilci gönderin | `pp: -60`; `zm_secession_delay: 90` | — |
| Accept the separation / Ayrılığı kabul edin | `zm_regional_autonomy: {group: event_group, loyal: false}`; `war_support: -0.05` | — |

**C2 `zm_col_government_fallen` — The Government of {country} Has Fallen / {country} Hükümeti Düştü.** Tetik: komşu bir yapay zekâ
ülkesi ÇÖKMÜŞ oldu (FROM); oyuncuya.

| Seçenek | Etki | AI |
|---|---|---|
| Announce protection of the border provinces / Sınır eyaletlerini koruma altına alacağımızı duyurun | `zm_timed_spirit: zm_protector_mandate [days 60]` (koruma bedeli ×0,5); `zm_stance: {solidarity: +0.02}` | 0,4 |
| Recognise the provisional authorities / Geçici yönetimleri tanıyın | `zm_recognise: children_of_FROM`; `zm_standing: +2` | 0,3 |
| Close the border to the fallen lands / Düşen topraklara sınırı kapatın | `border_posture: closed [target FROM]`; `zm_stance: {order: +0.02}` | 0,3 |

**C3 `zm_col_protection_request` — A Request for Protection / Himaye Talebi.** Tetik: komşu geçici yönetim (FROM) Sarsılmış ve r ≥ 0.

| Seçenek | Etki | AI |
|---|---|---|
| Accept / Kabul edin | `zm_protectorate: FROM`; `stability: -0.02`; `zm_relation: +25 [target FROM]` | 0,5 |
| Send aid instead / Onun yerine yardım gönderin | `zm_send_aid: {type: food, days: 20} [target FROM]`; `zm_relation: +15 [target FROM]` | 0,3 |
| Decline / Geri çevirin | `zm_relation: -10 [target FROM]` | 0,2 |

**C4 `zm_col_governor_terms` — The Military Governor's Terms / Askerî Valinin Şartları.** Tetik: komşu askerî valilik (FROM); 90 günde bir.

| Seçenek | Etki | AI |
|---|---|---|
| Recognise and trade / Tanıyın ve ticaret yapın | `zm_recognise: FROM`; `zm_standing: -3` | 0,5 |
| Demand they join the Council and open their books / Konsey'e katılmalarını ve defterlerini açmalarını isteyin | `zm_relation: -10 [target FROM]`; `zm_demand_council: FROM` (%40 kabul: τ 0,7, üyelik) | 0,3 |
| No contact / Temas kurmayın | — | 0,2 |

**C5 `zm_col_restoration` — Restoring {country} / {country} Yeniden Kuruluyor.** Tetik: §5.4'teki iade şartı.

| Seçenek | Etki | AI |
|---|---|---|
| Restore sovereignty / Egemenliği iade edin | `zm_restore_nation: FROM`; `zm_standing: +15`; `zm_aid_score: +0.10` | 0,7 |
| Joint administration with the Council for 180 days / Konseyle 180 gün ortak yönetim | `zm_standing: +5`; `zm_chain: {event: zm_col_restoration, chance: 1, delay: 180}` | 0,2 |
| Continue our administration / Yönetimimizi sürdürün | `zm_standing: -5`; `spirit: zm_prolonged_protectorate` (itibar ayda −1) | 0,1 |

**C6 `zm_col_frontier_opportunity` — An Opportunity on the Frontier / Sınırda Fırsat.** Tetik: komşu Sarsılmış (FROM), ayar devletler arası
savaşa izin veriyor, evre ≥ Çöküş; 365 gün bekleme.

| Seçenek | Etki | AI |
|---|---|---|
| Decline the General Staff's plan / Genelkurmayın planını reddedin | `zm_standing: +2` | — |
| Prepare a claim / Hak iddiası hazırlayın | `war_goal: FROM`; `zm_standing: -10`; `tension: +5` | — |
| Offer a guarantee instead / Bunun yerine garanti önerin | `pp: -25`; `guarantee: FROM`; `zm_relation: +20 [target FROM]` | — |

### 7.5 D — Diplomasi ve Konsey (11 olay)

**D1 `zm_dip_council_invitation` — An Invitation from Geneva / Cenevre'den Davet.** Tetik: Alarm evresine giriş; herkese.

| Seçenek | Etki | AI |
|---|---|---|
| Join as a full member / Tam üye olun | `zm_council: member`; `pp: -25`; `zm_standing: +5` | §6.6 |
| Join as an observer / Gözlemci olun | `zm_council: observer` (bülten var, oy ve aidat yok) | — |
| Decline / Reddedin | `zm_standing: -5` | — |

**D2 `zm_dip_port_rules` — The Port Rules / Liman Kuralları.** Tetik: R2 oylamada.

| Seçenek | Etki | AI |
|---|---|---|
| Ratify: six days at most for certified ships / Onaylayın: belgeli gemiye en çok altı gün | `zm_council_vote: yes`; `zm_port_cap: 6`; `zm_standing: +3` | 0,6 |
| Ratify with a reservation: ten days / Çekinceyle onaylayın: on gün | `zm_council_vote: yes`; `zm_port_cap: 10`; `zm_standing: +1` | 0,25 |
| Reject / Reddedin | `zm_council_vote: no`; `zm_standing: -3` | 0,15 |

**D3 `zm_dip_burden_sharing` — The Burden-Sharing Plan / Yük Paylaşım Planı.** Tetik: R6 oylamada.
> EN: *"The Council proposes that each member receive a share of those waiting at the frontiers, in proportion to its population and its
> own safety."* TR: *"Konsey, sınırlarda bekleyenlerin nüfusla ve üyenin kendi güvenliğiyle orantılı olarak üyelere paylaştırılmasını öneriyor."*

| Seçenek | Etki | AI |
|---|---|---|
| Accept our quota / Kotamızı kabul edelim | `zm_council_vote: yes`; `zm_refugee_quota: {size: council, days: 180}`; `zm_standing: +5` | 0,3 |
| Pay instead of hosting / Barındırmak yerine ödeyelim | `zm_council_vote: yes`; `zm_send_aid: {type: food, days: 10} [target council_pool]`; `zm_standing: +2` | 0,4 |
| Refuse / Reddedelim | `zm_council_vote: no`; `zm_standing: -3` | 0,3 |

**D4 `zm_dip_inspectors` — The Inspectors Are Coming / Müfettişler Geliyor.** Tetik: R7 oyuncuya karşı kabul edildi.

| Seçenek | Etki | AI |
|---|---|---|
| Open the books / Defterleri açın | `zm_transparency: 0.9 [days 180]`; `zm_concealment: reset`; `stability: -0.04`; `zm_standing: +5` | 0,4 |
| A guided tour / Rehberli bir gezi | `pp: -50`; `zm_standing: -3` | 0,3 |
| Refuse entry / Girişi reddedin | `zm_standing: -12`; `zm_relation: -15 [target council_members]` | 0,3 |

**D5 `zm_dip_protest_note` — A Note of Protest / Protesto Notası.** Tetik: §6.7. Dayanak: 1919'da Avustralya eyaletleri federal anlaşmaya
rağmen sınırlarını tek taraflı kapattı ve eyaletler arasında çatışma çıktı.

| Seçenek | Etki | AI |
|---|---|---|
| Offer a filtered crossing / Süzgeçli geçiş önerin | `border_posture: controlled [target FROM]`; `zm_relation: +10 [target FROM]` | 0,5 |
| Keep it closed, compensate their trade / Kapalı tutun, ticaretlerini telafi edin | `zm_send_aid: {type: food, days: 5} [target FROM]`; `zm_relation: +5 [target FROM]` | 0,25 |
| Reject the protest / Protestoyu reddedin | `zm_relation: -15 [target FROM]` | 0,25 |

**D6 `zm_dip_aid_appeal` — An Appeal from {country} / {country} Yardım İstiyor.** Tetik: FROM Sarsılmış, r ≥ −20; 90 günde bir.

| Seçenek | Etki | AI |
|---|---|---|
| Send grain / Tahıl gönderin | `zm_send_aid: {type: food, days: 10} [target FROM]`; `zm_relation: +15 [target FROM]` | §6.7 |
| Send a medical mission / Tıbbi heyet gönderin — şart: `zm_free_scientists_at_least: 3` | `zm_mission: FROM` (05 §9: 3 kadro, 60 nüfuz) | — |
| Decline politely / Nazikçe reddedin | `zm_relation: -5 [target FROM]` | — |

**D7 `zm_dip_joint_cordon` — A Joint Cordon? / Ortak Kordon mu?** Tetik: yapay zekâ komşusu (FROM) önerir. Dayanak: 1910–11 Mançurya'da
Çin, Rus ve Japon demiryolu yönetimlerinin ortak karantinası (01).

| Seçenek | Etki | AI |
|---|---|---|
| Accept the pact / Paktı kabul edin | `zm_pact: {type: joint_cordon, days: 365} [target FROM]`; `grant_access: FROM`; `zm_relation: +20 [target FROM]` | §6.3 |
| Share intelligence only / Yalnız bilgi paylaşın | `zm_pact: {type: intel, days: 365} [target FROM]` (iki tarafa bildirim gecikmesi −1 gün) | — |
| Decline / Reddedin | `zm_relation: -5 [target FROM]` | — |

**D8 `zm_dip_unwanted_ship` — The Ship Nobody Wants / Kimsenin İstemediği Gemi.** Tetik: oyuncunun limanlı bir eyaleti var; evre ≥ Yayılma;
iki limandan geri çevrilmiş 800–1.200 kişilik bir gemi; 365 gün bekleme.
> TR: *"Kaptan telsizle soruyor: yolcuları iki limandan geri çevrilmiş, suyu üç günlük kalmış. Aralarında hasta olduğunu bilen yok."*

| Seçenek | Etki | AI |
|---|---|---|
| Land them through quarantine / Karantinadan geçirerek indirin | `refugee_policy: camp [n 1000, once]`; `zm_standing: +5` | 0,5 |
| Provision the ship and send it on / Gemiye erzak verip yoluna gönderin | `pp: -10`; `zm_standing: -2` | 0,3 |
| Refuse entry / Girişi reddedin | `zm_standing: -8` | 0,2 |

**D9 `zm_dip_grain_for_silence` — Grain for Silence? / Susma Karşılığı Tahıl.** Tetik: `zm_food_ratio_below: 0.95` (07); bir tahıl
ihracatçısı (FROM) hakkında R7 tasarısı gündemde. Dayanak: 1720 Marsilya'da ticari baskı karantinayı gevşetti (07); 1892 Hamburg.

| Seçenek | Etki | AI |
|---|---|---|
| Take the grain, vote with them / Tahılı alın, onlarla oy verin | `zm_food_stock: +15`; `zm_council_vote: no`; `zm_standing: -5` | 0,4 |
| Refuse politely / Nazikçe reddedin | `zm_relation: -10 [target FROM]` | 0,3 |
| Report the offer to the Council / Teklifi Konsey'e bildirin | `zm_standing: +3`; `zm_relation: -25 [target FROM]` | 0,3 |

**D10 `zm_dip_council_exile` — The Council in Exile / Sürgündeki Konsey.** Tetik: §6.6 "Sürgün"; yalnız üyelere.

| Seçenek | Etki | AI |
|---|---|---|
| Host the Council in our capital / Konsey'i başkentimizde ağırlayın — şart: başkent eyaleti TEMİZ | `pp: -50`; `zm_council_hq: self`; `zm_standing: +10`; `spirit: zm_council_host` (`zm_detection +0,05`) | itibarı en yüksek temiz üye |
| Offer funds / Para desteği verin | `pp: -40`; `zm_standing: +3` | — |
| Decline / Reddedin | — | — |

**D11 `zm_dip_common_vial` — The Common Vial / Ortak Şişe.** Tetik: R8; oyuncu aşı üretiyor.

| Seçenek | Etki | AI |
|---|---|---|
| Contribute a tenth / Onda birini verin | `zm_vaccine_pool: 0.10 [days 180]`; `zm_standing: +10` | 0,5 |
| Contribute a quarter / Dörtte birini verin | `zm_vaccine_pool: 0.25 [days 180]`; `zm_standing: +15` | 0,2 |
| Keep all doses / Bütün dozları tutun | `zm_standing: -10`; `zm_relation: -10 [target council_members]` | 0,3 |

Havuza verilen doz, yardım puanındaki "yararlanan" sayısına eklenir (§6.4).

## 8. Olay zincirleri

```
Z1 ÖRTBAS
 A1 "Durum kontrol altında" ─▶ G↑ ─▶ A8 Sızan Rapor ─┬─ kabul ─────────▶ (zincir biter)
 (ya da Haber Denetimi/Tam Sansür + büyüyen salgın)   ├─ yalanla (%50) ──▶ A9 İkinci Sızıntı ─▶ A10 Bakan İstifası ─▶ İç Çöküş riski (02)
                                                      └─ gazeteyi kapat ─▶ G ×1,2 ─▶ (R7 Veri Denetimi) ─▶ D4 Müfettişler

Z2 SERT EL
 Sokağa Çıkma ─▶ A5 Arama Ekipleri ─(askerle, %35)─▶ A6 Müfettişe Saldırı ─(kovuşturma)─▶ bayrak zm_army_ascendant
 Sıkıyönetim 180 gün ────────────────────────────────▶ A13 Generallerin Muhtırası ─(kordonu orduya ver)─▶ bayrak
 bayrak + istikrar < 0,15 ─▶ A14 Kışla Gecesi

Z3 AŞI
 B2 Aşı Zorunlu mu? ─(muafiyetsiz, %35)─▶ B3 Aşı Kargaşası ─(sıkıyönetim)─▶ Z2'ye bağlanır
 B2 ─(her seçenek)─▶ 05 §10.8 "Söylenti" olasılığı zm_vaccine_trust ile değişir

Z4 KOMŞUNUN ÇÖKÜŞÜ
 D6 Yardım İstiyor ─▶ (komşu Parçalanan) ─▶ C2 Hükümeti Düştü ─┬─ koruma duyurusu ─▶ C3 Himaye Talebi ─▶ … ─▶ C5 Yeniden Kuruluş
                                                              ├─ tanıma ─▶ C4 Askerî Valinin Şartları
                                                              └─ sınırı kapat ─▶ 07 "Sınırda Mülteciler" artar ─▶ D5 Protesto

Z5 KONSEY
 D1 Davet ─▶ D2 Liman Kuralları ─▶ (Yayılma) R1/R3/R4/R6 ─▶ D3 Yük Paylaşımı ─▶ (Çöküş) R7 ─▶ D4 / D9 ─▶ D10 Sürgün ─▶ (Karşı Saldırı) D11 Ortak Şişe

Z6 YORGUNLUK
 Zorunlu Karantina ─(F ≥ 4)─▶ A4 Kargaşa ─(F ≥ 6)─▶ A11 Bekleyişten Bıkan Şehir ─(geçim payı ≥ 0,33)─▶ A12 Genel Grev
                                                                             └─(seçim yaklaşırsa)─▶ A3 Salgının Gölgesinde Seçim
```

Zincirler dallanır ama **her dalın bir çıkışı vardır.** Hiçbir zincir oyuncuyu tek bir sonuca kilitlemez. Z1 ve Z2 İç Çöküş'e
(02 §4.2) varabilir; orada da üç seçenek vardır.

## 9. Ülke tepkilerinin tarihsel dayanakları

| Olay (yıl, yer) | Devletin tepkisi | Sonuç | Moddaki karşılığı |
|---|---|---|---|
| 1348–49, Avrupa | Salgın bir azınlığa yüklendi; Papa suçlamanın asılsız olduğunu duyurdu | Pogromlar | A7: zulüm seçeneği yok, susmanın bedeli var |
| 1720, Marsilya | Ticari baskıyla gevşetilen gemi karantinası | Veba kente girdi | D9; geçim tutumu |
| 1770'ler, Habsburg–Osmanlı sınırı | Kalıcı askerî veba kordonu (21/48 gün) | Uzun süreli koruma (01) | Sıkıyönetim ve kordon yasaları; 06'nın Kordon Devleti dalı |
| 1771, Moskova | Karantina ve toplanma yasakları | Veba kargaşası | A4 |
| 1830–31 ve 1892, Rusya | Silahlı kordon, yol yasakları | Kolera ayaklanmaları | A4, önlem yorgunluğu, Olağanüstü Yönetim'in istikrar bedeli |
| 1885, Leicester; 1898, İngiltere | Zorunlu aşıya direniş; vicdani ret maddesi | Uzlaşma | B2'nin ilk seçeneği |
| 1892, Hamburg | Koleranın geç kabul edilmesi | Ağır ölüm; komşu Altona'nın süzülmüş suyu korudu (02) | Örtbas borcu, A8 |
| 1897, Pune | Salgın Hastalıklar Yasası; askerle ev araması | Rand suikastı | A5, A6 |
| 1900, San Francisco | Bir göçmen mahallesine yönelik karantina | Mahkeme ayrımcı bularak kaldırdı | A7 |
| 1904, Rio de Janeiro | Zorunlu çiçek aşısı yasası | Ayaklanma, sıkıyönetim, zorunluluk askıya alındı | B3 |
| 1910–11, Mançurya | Üç demiryolu yönetiminin ortak karantinası; 1911 Mukden konferansı | Salgın bastırıldı | Ortak kordon paktı (D7), Konsey |
| 1914–18 | Savaşan ülkelerde basın sansürü | Salgın "İspanyol" diye anıldı | Basın ve Bilgi Politikası, şeffaflık |
| 1918, ABD şehirleri | Erken, katmanlı ve uzun önlem | Daha düşük tepe ölüm (Markel 2007; Hatchett 2007; Bootsma ve Ferguson 2007) | Karantina basamaklarının değerleri |
| 1918, Samoa | Amerikan Samoası'nda deniz karantinası, Batı Samoa'da ihmal | 0 ölüme karşı %22 (01) | Liman karantinası; sömürge ihmali itibar kaybettirir |
| 1918, ABD ve İngiltere | Seçimler salgının içinde yapıldı | — | A3 |
| 1919, San Francisco | İkinci maske zorunluluğu | Maske Karşıtı Birlik | Önlem yorgunluğu, A11 |
| 1919, Avustralya | Eyaletlerin tek taraflı sınır kapatması | Federal anlaşma çöktü | D5; bölgesel yönetimlerin gerilimi |
| 1919–22, Polonya | Milletler Cemiyeti Salgın Komisyonu; bu arada Polonya-Sovyet savaşı | Salgın ve savaş birlikte | Konsey heyetleri (R4); §5.5 |
| 1920, İngiltere | Olağanüstü Yetki Yasası (1 ay, meclis denetimi, zorunlu sanayi hizmeti yasak) | — | Olağanüstü Yetki basamağı |
| 1921, Türkiye; 1935, Almanya; 1940, Türkiye | Tekâlif-i Milliye; Reich Çalışma Hizmeti; Millî Korunma Kanunu | — | Zorunlu Hizmet grubu |
| 1921–23, Rusya | Amerikan Yardım İdaresi günde 10 milyonu aşkın kişiyi doyurdu | Kıtlık hafifledi | Yardım puanı eşiği (§6.4) |
| 1922, 1933, 1938 | Nansen pasaportu; 1933 Sözleşmesi; Évian | Kurallar yazıldı, paylaşım başarısız oldu | Mülteci anlaşması; R6 |
| 1916–28, Çin; 1918, Rusya ve Avusturya-Macaristan | Merkezin çözülmesi, bölgesel yönetimler | Parçalanma | §5.2 bölgesel yönetimler |
| 1919, Milletler Cemiyeti Misakı md. 22 | Manda sistemi | Koruma çoğu zaman ilhaka dönüştü | §5.4: koruma puan getirmez, iade ödüllenir |
| 1937–39, İngiltere | ARP, Eylül 1939 tahliyesi (ilk günlerde yaklaşık 1,5 milyon kişi) | — | Sivil Savunma Teşkilatı, `zm_evacuation_mult` |
| 1939, Atlantik | St. Louis gemisi geri çevrildi | Yolcular Avrupa'ya döndü | D8 |
| 2014, Liberya; 2020, Avrupa | Güven düşükken uyum düşük; kapanma sonrası güven arttı; yorgunluk | Blair 2017; Bargain ve Aminjonov 2020; Baekgaard 2020; DSÖ 2020 | Uyum (§2.5), ralli ve yorgunluk (§2.3) |

## 10. Veri: JSON şemaları

Yerleşim docs/modlar/README.md'ye uyar: değişen temel dosyalar `common/*.patch.json`, modun kendi verisi `own/*.json` olur.

### 10.1 `data/modes/zombie/common/laws.patch.json` (kesit)

```json
{
  "_comment": "Gri Kordon yasaları. Değerler ve gerekçeleri: docs/modlar/zombi/09_siyaset_olaylar_diplomasi.md §3. cost/relax_cost için S3, requires içindeki zm_ anahtarları için S2 gerekir.",
  "groups": {
    "zm_quarantine": {
      "name": {"en": "Quarantine Policy", "tr": "Karantina Politikası"},
      "relax_cost": 50,
      "laws": {
        "zm_voluntary_reporting":    {"name": {"en": "Voluntary Reporting", "tr": "Gönüllü Bildirim"},
                                      "zm_stance": {"livelihood": 1, "health": -1}},
        "zm_compulsory_notification":{"name": {"en": "Compulsory Notification", "tr": "Zorunlu Bildirim"}, "cost": 50,
                                      "zm_beta_mult": -0.05, "zm_detection": 0.05, "stability": -0.01,
                                      "zm_stance": {"health": 1}},
        "zm_home_isolation":         {"name": {"en": "Home Isolation", "tr": "Ev Tecridi"}, "cost": 100,
                                      "zm_beta_mult": -0.20, "factory_output": -0.04, "stability": -0.04, "zm_strict": 1,
                                      "requires": {"zm_phase_at_least": "alarm"},
                                      "zm_stance": {"health": 2, "livelihood": -1}},
        "zm_compulsory_quarantine":  {"name": {"en": "Compulsory Quarantine", "tr": "Zorunlu Karantina"}, "cost": 150,
                                      "zm_beta_mult": -0.35, "factory_output": -0.10, "stability": -0.08, "zm_strict": 1,
                                      "requires": {"zm_phase_at_least": "alarm"},
                                      "zm_stance": {"health": 2, "order": 1, "livelihood": -2}},
        "zm_travel_ban":             {"name": {"en": "Internal Travel Ban", "tr": "Yurt İçi Seyahat Yasağı"}, "cost": 100,
                                      "zm_beta_mult": -0.35, "zm_travel_mult": -0.80, "factory_output": -0.13, "stability": -0.10,
                                      "zm_strict": 1, "requires": {"zm_phase_at_least": "spread", "war_support": 0.15},
                                      "zm_stance": {"health": 2, "order": 1, "livelihood": -3}}
      }
    },
    "zm_emergency": {
      "name": {"en": "Emergency Government", "tr": "Olağanüstü Yönetim"},
      "relax_cost": 50,
      "laws": {
        "zm_ordinary_rule":    {"name": {"en": "Ordinary Government", "tr": "Olağan Yönetim"}},
        "zm_emergency_powers": {"name": {"en": "Emergency Powers Act", "tr": "Olağanüstü Yetki Kanunu"}, "cost": 100,
                                "political_power_gain": 0.15, "stability": -0.02,
                                "requires": {"zm_phase_at_least": "alarm"}, "zm_stance": {"order": 1}},
        "zm_curfew":           {"name": {"en": "Curfew", "tr": "Sokağa Çıkma Yasağı"}, "cost": 75,
                                "zm_beta_mult": -0.10, "factory_output": -0.05, "stability": -0.05, "political_power_gain": 0.10,
                                "zm_strict": 1, "requires": {"zm_phase_at_least": "spread"},
                                "zm_stance": {"order": 2, "livelihood": -1}},
        "zm_martial_law":      {"name": {"en": "Martial Law", "tr": "Sıkıyönetim"}, "cost": 100,
                                "zm_beta_mult": -0.15, "zm_martial_kappa": 0.05, "factory_output": -0.08, "stability": -0.15,
                                "political_power_gain": 0.20, "zm_standing_law": -20, "zm_transparency_law": -0.15,
                                "zm_postpones_elections": 1, "zm_strict": 1,
                                "requires": {"zm_phase_at_least": "spread", "war_support": 0.20},
                                "zm_stance": {"order": 3, "solidarity": -1, "livelihood": -1}}
      }
    }
  },
  "start": {
    "_default": {"conscription": "professional_army", "economy": "peacetime_economy", "trade": "clearing_agreements",
                 "zm_quarantine": "zm_voluntary_reporting", "zm_emergency": "zm_ordinary_rule",
                 "zm_civil_defence": "zm_police_only", "zm_information": "zm_news_control", "zm_service": "zm_voluntary_service"}
  }
}
```
- `start._default` bütün grupları içermelidir: `Economy` başlangıçta eksik grubu `_default`'tan okur (kod okundu). Basın yasası
  ideolojiye göre `rules.gd` `on_new_game` içinde düzeltilir (demokrasi → Serbest Basın; faşist, komünist → Tam Sansür). Böylece
  80 ülkelik bir `start` tablosu yazılmaz.
- Sözlük değerli anahtarlar (`zm_stance`) `Country.mod`'dan okunmaz; yalnız `rules.gd` okur (`Economy.law_def`).

### 10.2 `data/modes/zombie/common/countries.patch.json` (kesit, S5)

```json
{"countries": {
  "ZR01": {"name": {"en": "Provisional Administration", "tr": "Geçici Yönetim"}, "dormant": true,
           "color": "#8a8a80", "ideology": "neutrality", "leader": "—", "stability": 0.35, "war_support": 0.30,
           "flag": {"dir": "h", "colors": ["#8a8a80", "#d8d4c8", "#8a8a80"]}},
  "UND":  {"name": {"en": "The Hollow", "tr": "Boşlar"}, "dormant": true, "color": "#3c3f3a", "ideology": "neutrality",
           "leader": "—", "stability": 0.0, "war_support": 0.0, "flag": {"dir": "h", "colors": ["#3c3f3a"]}}
}}
```
Ad, renk, lider ve bayrak etkinleşme anında `rules.gd` tarafından yazılır ve kayda girer (§13.1). `UND` kaydının biçimi 04'e aittir;
burada yalnız uyuyan kayıt kuralını göstermek için yer alıyor.

### 10.3 `data/modes/zombie/own/politics.json` (kesit)

```json
{
  "_comment": "Siyaset ve diplomasi katsayıları. Gerekçe: docs/modlar/zombi/09_siyaset_olaylar_diplomasi.md §2–§6.",
  "resolve": {"base": 0.35, "slope": 0.30, "min": 0.20, "max": 0.50,
              "gsi_rally_per_pt": 0.003, "gsi_rally_cap_pt": 20, "gsi_dread_per_pt": 0.002,
              "rally": 0.10, "rally_days": 180, "hope_serum": 0.04, "hope_vaccine": 0.06, "hope_per_cleared": 0.01, "hope_cleared_max": 6,
              "local": 0.20, "loss_mult": 0.5, "loss_cap": 0.20, "fatigue_per_pt": 0.01, "fatigue_cap": 12,
              "fatigue_up_days": 30, "fatigue_down_per_30": 2},
  "stability": {"fear": 0.10, "fallen": 0.15, "alignment": 0.06, "protectorate_per_state": 0.005, "protectorate_cap": 0.05},
  "compliance": {"slope": 0.8, "min": 0.5, "max": 1.1, "cap_m": 0.75},
  "concealment": {"decay_days": 120, "threshold_share": 0.0005, "weekly_per_s": 0.05, "weekly_cap": 0.30},
  "information": {"zm_free_press": {"panic": 1.0, "tau": 1.0, "standing": 5, "h": 0.0},
                  "zm_official_bulletins": {"panic": 1.0, "tau": 1.0, "standing": 5, "h": 0.0},
                  "zm_news_control": {"panic": 0.7, "tau": 0.7, "standing": -5, "h": 0.3},
                  "zm_full_censorship": {"panic": 0.4, "tau": 0.4, "standing": -15, "h": 0.6}},
  "stances": {"ids": ["health", "order", "livelihood", "solidarity"], "relax_per_month": 0.20, "tag_divisor": 4,
              "ruling_popularity_per_month": 0.01},
  "regime": {"democratic": "zm_regime_consent", "fascism": "zm_regime_decree", "communism": "zm_regime_decree",
             "neutrality": "zm_regime_bureaucratic"},
  "collapse": {"shaken_stability": 0.20, "shaken_surrender_share": 0.5, "shaken_ye": 0.5, "recover_days": 60,
               "fragment_cutoff_share": 0.25, "fragment_stability": 0.05, "fragment_days": 30,
               "group_min_pop": 300000, "p_base": 0.10, "p_low_stab": 0.10, "p_guards": 0.05, "p_arming": 0.10,
               "p_divisions": 0.10, "p_cap": 0.40, "military_min_divisions": 3, "pool": 24,
               "protectorate_pp": 25, "protectorate_garrison_days": 30, "restore_clean_days": 42},
  "relations": {"baseline": {"faction": 20, "ideology": 10, "guarantee": 10, "recent_war": -30}, "drift_days": 180},
  "standing": {"start": 50, "event_decay_per_day": 0.004, "council_member": 5},
  "acceptance": {"base": 0.15, "relation": 0.004, "reciprocity": 0.25, "gsi": 0.010, "standing": 0.01,
                 "rival": -0.30, "same_goal": -0.20, "min": 0.02, "max": 0.95},
  "aid_score": {"refugee_w": 0.35, "refugee_share": 0.01, "aid_w": 0.30, "aid_share": 0.02,
                "science_cap": 0.15, "share_finding": 0.03, "joint_institute": 0.05, "mission": 0.10,
                "protect_w": 0.20, "protect_share": 0.05, "restore": 0.10},
  "council": {"dues": 25, "join_p": {"democratic": 0.9, "neutrality": 0.9, "fascism": 0.6, "communism": 0.6},
              "missions_base": 1, "missions_per_members": 15, "quorum": 0.5, "session": "first_monday"},
  "dispatcher": [
    {"event": "zm_pol_cabinet_emergency", "scope": "all", "once": true, "require": [{"zm_homeland_reported_at_least": 1}]},
    {"event": "zm_pol_quarantine_unrest", "scope": "all", "chance_per_week": 0.08, "cooldown_days": 120,
     "require": [{"zm_law_at_least": {"zm_quarantine": "zm_home_isolation"}}, {"zm_stability_below": 0.35},
                 {"zm_fatigue_at_least": 4}]},
    {"event": "zm_pol_fatigue", "scope": "all", "cooldown_days": 180, "require": [{"zm_fatigue_at_least": 6}]}
  ]
}
```

### 10.4 `data/modes/zombie/common/events.patch.json` (bir olay tam)

```json
{"events": {
  "zm_pol_leaked_report": {
    "title": {"en": "The Leaked Report", "tr": "Sızan Rapor"},
    "desc":  {"en": "A provincial daily has printed the true figures from a ministry memorandum. The capital's cafés speak of nothing else.",
              "tr": "Bir taşra gazetesi bakanlık notundaki gerçek sayıları bastı. Başkentin kahvelerinde başka bir şey konuşulmuyor."},
    "options": [
      {"name": {"en": "Admit and publish the figures", "tr": "Kabul edin, sayıları yayımlayın"}, "ai": 0.4,
       "effects": [{"stability": -0.06}, {"zm_concealment": "reset"}, {"zm_standing": 2}, {"zm_stance": {"health": 0.03}}]},
      {"name": {"en": "Deny", "tr": "Yalanlayın"}, "ai": 0.35,
       "effects": [{"zm_concealment_mult": 1.5},
                   {"zm_chain": {"event": "zm_pol_second_leak", "chance": 0.5, "delay": 45}}]},
      {"name": {"en": "Close the newspaper", "tr": "Gazeteyi kapatın"}, "ai": 0.25,
       "require": [{"zm_law_at_least": {"zm_information": "zm_news_control"}}],
       "effects": [{"zm_standing": -5}, {"zm_concealment_mult": 1.2}, {"zm_stance": {"order": 0.02, "health": -0.03}}]}
    ],
    "trigger": null
  }
}}
```

### 10.5 Yeni etki ve şart anahtarları (`rules.gd`: `apply_effect` + `describe_effect` birlikte; CLAUDE.md kural 2)

| Etki | Değer | describe (EN / TR) |
|---|---|---|
| `zm_set_law` | `{grup: yasa, …}` (bedelsiz) | "Law: %s" / "Yasa: %s" |
| `zm_relax_law` | grup (bir basamak aşağı, bedelsiz) | "Eases: %s" / "Gevşer: %s" |
| `zm_timed_spirit` | kimlik + `days` | "%s (%d days)" / "%s (%d gün)" |
| `zm_standing` | ± tamsayı | "Standing %+d" / "İtibar %+d" |
| `zm_relation` | ± + `target` | "Relations with %s %+d" / "%s ile ilişki %+d" |
| `zm_transparency` | değer + `days` | "Transparency %d%% (%d days)" / "Şeffaflık %%%d (%d gün)" |
| `zm_concealment`, `zm_concealment_mult` | ± sayı ya da `reset` / çarpan | "Hidden cases %+d" / "Gizlenen vaka %+d" |
| `zm_fatigue` | ± puan | "Measure fatigue %+d" / "Önlem yorgunluğu %+d" |
| `zm_stance` | `{tutum: ±pay}` | "Public opinion: %s %+d%%" / "Kamuoyu: %s %%%+d" |
| `zm_ruling_popularity` | ± | "Ruling party popularity %+d%%" / "İktidar partisi %%%+d" |
| `zm_unrest` | +1 (90 günlük sayaç) | "Unrest recorded" / "Kargaşa kaydı" |
| `zm_clear_flag` | bayrak | — (gizli) |
| `zm_chain` | `{event, chance, delay}` | "May lead to: %s" / "Şuna yol açabilir: %s" |
| `zm_postpone_election` | ay | "Election postponed %d months" / "Seçim %d ay ertelenir" |
| `zm_move_capital` | `safest` | "Government moves to %s" / "Hükümet %s şehrine taşınır" |
| `zm_regional_autonomy`, `zm_secession_delay` | §5.3 | "Autonomy for %s" / "%s için özerklik" |
| `zm_protectorate`, `zm_recognise`, `zm_restore_nation`, `zm_demand_council` | tag | "Protect %s" / "%s koruma altına" … |
| `zm_send_aid` | `{type, days}` + `target` | "Aid to %s: %s" / "%s ülkesine yardım: %s" |
| `zm_pact` | `{type, days}` + `target` | "Pact with %s" / "%s ile pakt" |
| `zm_refugee_quota`, `zm_vaccine_pool`, `zm_port_cap` | §6.6 | … |
| `zm_council`, `zm_council_vote`, `zm_council_hq` | üyelik / oy / merkez | "Council: %s" / "Konsey: %s" |
| `zm_aid_score` | ± | "Solidarity %+d%%" / "Dayanışma %%%+d" |
| `zm_mission` | tag | 05 §9 |

| Şart | Anlamı |
|---|---|
| `zm_homeland_reported_at_least` | Anavatanda bildirilen toplam vaka ≥ N |
| `zm_ye_at_least` | YE_algı ≥ x |
| `zm_stability_below`, `zm_resolve_below` | Etkin istikrar / irade < x (motorda yok) |
| `zm_law_at_least` | `{grup: yasa}`: gruptaki basamak ≥ verilen |
| `zm_fatigue_at_least`, `zm_unrest_at_least` | F ≥ N; 90 günde kargaşa ≥ N |
| `zm_stance_share_at_least` | `{tutum: pay}` |
| `zm_fallen_share_at_least`, `zm_homeland_dead_at_least` | Düşmüş pay / ölen pay ≥ x |
| `zm_election_within` | Sonraki seçime ≤ N gün |
| `zm_capital_threatened` | §7.2 A15 |
| `zm_council_member`, `zm_transparency_below`, `zm_standing_below` | — |
| `zm_country_state` | `{target: FROM, state: shaken / fragmenting / fallen}` |
| `zm_free_scientists_at_least` | 05'in kadro havuzunda atanmamış bilim insanı ≥ N |

Ayrıca 06'daki `zm_phase_at_least` ve `zm_tech_any`, 05'teki stok şartları ve 07'deki `zm_food_ratio_below` ve `zm_workforce_below` kullanılır.

## 11. Arayüz (yalnız `panel_layout.gd` yardımcıları; CLAUDE.md kural 5)

**Salgın paneli (E), "Hükümet ve Dünya" sekmesi** (sekmelerin sırası panel tasarımında kesinleşir):

| Bölüm (`PanelLayout.section`) | Yardımcı | İçerik |
|---|---|---|
| Durum | `info_cells` | İstikrar · Dayanma iradesi · Teslim sınırı · İtibar · Önlem yorgunluğu (F/12) · Gizlenen vaka (s) |
| Dayanma iradesi dökümü | `table` + `table_row` | §2.3'teki altı terim, her biri işaretli değeriyle; ipucunda formül |
| Kamuoyu | `row` + `progress` ×4 | Dört tutum payı; alt satırda "Uyum A = +0,53 → istikrar +%3" |
| Konsey | `row` + `row_action(small_button)` | Üyelik, aidat, gündemdeki tasarı, son 3 karar |
| Dünya | `table` (ülke, ilişki, sınır, anlaşmalar, durum) + `row_action` | S6 yoksa eylemler buradan verilir |
| Koruma altındakiler | `table` | Eyalet, asıl ülke, gün, yaşayan nüfus; iade şartının ilerlemesi (`progress`) |

- **Hükümet paneli:** Yeni yasa grupları kendiliğinden listelenir. Yasa ipucunda bedel, `relax_cost`, S2 şartı ve **tutum etiketi**
  yazar ("Önce Sağlık +2, Önce Geçim −2"); M8 kancası bunu yazdırır.
- **Diplomasi paneli (S6):** Mevcut `_action` satırları. Hedef ülkenin başlığının altına `stat` ile "İlişki +35 · İtibar 62 · Şeffaflık %70 ·
  Sarsılmış" eklenir.
- **Uyarı şeridi (`alert_bar.gd`):** "Konsey oylaması bekliyor", "Gizlenen vaka eşikte (s ≥ 2)", "Önlem yorgunluğu ≥ 8" uyarıları.
- **Harita:** Bölgesel yönetimler yeni ülke rengiyle çizilir (mevcut siyasi harita). Koruma altındaki eyaletler koruyucunun rengini alır.
  Yeni gölgelendirici ya da renk dili yoktur.

## 12. Görsel ve ses varlıkları (liste ve üretim komutları; dosya üretilmez, CLAUDE.md kural 6)

**İkonlar** (`assets/ui/icons_new/`, 05/06'daki `STYLE_ZM_ICON`; haç ve hilal amblemi yok, yüz yok, gerçek bayrak yok):

| Dosya | Konu (EN) |
|---|---|
| `law_zm_quarantine` | a yellow quarantine flag hanging from a harbour pole beside a closed gate |
| `law_zm_emergency` | a stamped decree with a heavy seal and a curfew bell on a desk |
| `law_zm_civil_defence` | a steel helmet, an armband and a hand lantern on a doorstep |
| `law_zm_information` | a folded newspaper under a brass microphone, a bulletin pinned beside it |
| `law_zm_service` | a canvas work bag, a shovel and a nurse's cap on a bench |
| `stance_health` | a physician's bag and an open ledger of figures |
| `stance_order` | a sentry box with a striped barrier at dusk |
| `stance_livelihood` | a loaf of bread and a wage envelope on a kitchen table |
| `stance_solidarity` | two hands passing a blanket over a low fence |
| `zm_council` | a long table with name cards and empty chairs beneath tall windows in a lakeside hall |
| `zm_standing` | a small brass scale in balance on a stack of treaties |
| `zm_fatigue` | a clock over an empty tram stop, a closed shutter |
| `zm_concealment` | a drawer half-open with papers stamped confidential, no readable text |
| `zm_admin_civil` / `zm_admin_military` | a town hall with a single lit window / a field headquarters tent with a flagpole without a flag |

**Olay resimleri** (8:3, `STYLE_EVENT`; 04 §10.3'teki mod eki: "no gore, no children, figures at a distance"):

| Dosya | Konu (EN) |
|---|---|
| `event_zm_pol_cabinet_emergency` | a 1930s cabinet room at night, ministers seen from behind around a table lit by a green lamp, a telegram in the centre |
| `event_zm_pol_election_shadow` | a polling station in a school hall, a short queue at distance, windows open, gauze masks on a few faces turned away |
| `event_zm_pol_quarantine_unrest` | a crowd in winter coats at a closed quarantine gate, gendarmes standing apart, breath visible in cold air |
| `event_zm_pol_leaked_report` | a newsstand at dawn, bundles of papers being cut open, no readable headline |
| `event_zm_pol_generals_memo` | an officer's gloved hand placing a sealed envelope on a minister's desk, rain on the window |
| `event_zm_pol_vaccine_riot` | an overturned handcart and scattered leaflets on a cobbled square, mounted police far in the background, smoke |
| `event_zm_col_government_fallen` | an empty ministry corridor, doors open, papers on the floor, a portrait hook without a portrait |
| `event_zm_col_restoration` | a border post at sunrise, two officials shaking hands beside a raised barrier, figures small in the landscape |
| `event_zm_dip_council` | a lakeside assembly hall with delegates seen from the gallery, sunlight through tall windows |
| `event_zm_dip_unwanted_ship` | an ocean liner at anchor outside a harbour, small boats circling, passengers as tiny silhouettes at the rails |
| `event_zm_dip_burden_sharing` | a railway siding with a line of carriages and a registration table, families at a distance |
| `event_zm_dip_council_exile` | crates of files being loaded onto a train at night, an official with a lantern |

**Sesler** (`tools/make_audio.py` yaklaşımı; yardımcılar `noise`, `band`, `env`, `tone`; telifli örnek yok):

| Dosya | Süre | Prosedürel tarif | Üretim komutu (EN) |
|---|---|---|---|
| `zm_council_gavel` | 1,2 sn | İki ahşap darbe: 20 ms `band(noise, 300, 2.000)`, 180 Hz rezonans, 0,4 sn salon yankısı | "two wooden gavel knocks in a large quiet hall" |
| `zm_radio_bulletin` | 2,5 sn | 1 kHz tanıtım tonu (0,3 sn) + `band(noise, 300, 3.000)` cızırtı, 2 Hz genlik kıpırtısı | "a 1930s radio interval tone followed by gentle static" |
| `zm_unrest_distant` | 4 sn döngü | Uzak kalabalık: `band(noise, 150, 800)` 10 katman, 0,3–0,6 Hz zarflar; ara ara ıslık (1,8–2,4 kHz, 0,3 sn); **bağırış yok** | "distant restless crowd murmur in a city square, a far whistle, no shouting, no words" |
| `zm_election_bell` | 2 sn | 523 ve 659 Hz çan kısmi tonları, 1,6 sn sönüm | "a single town-hall bell stroke, calm" |

**Öncelik:** P1 = 5 yasa ikonu + 4 tutum ikonu + Konsey ikonu + 4 olay resmi (kabine, sızan rapor, Konsey, düşen hükümet) = 14 varlık.
Dosya yoksa `UiTheme.icon` `null` döner ve arayüz ikonsuz çizilir; kod değişikliği gerekmez.

## 13. Kayıt, test ve denge hedefleri

### 13.1 Kayda eklenecekler (`rules.gd.to_save`)
Tutum payları; F, G (örtbas), 90 günlük kargaşa sayacı; ralli başlangıç günü ve umut bayrakları; terim toplamının dünkü değeri (delta
yöntemi için); ilişki matrisinin tabandan farkları (seyrek sözlük); itibarın olay bileşeni; şeffaflık süreli etkileri; süreli ulusal
durumların bitiş günleri; olay bekleme süreleri ve `once` kayıtları; zincir kuyruğu (olay, gün); Konsey (üyeler, aidat, merkez, gündem,
karar geçmişi, heyetler); anlaşmalar (tür, taraflar, bitiş); yardım puanı bileşenleri; çöküş durumları; bölgesel yönetim havuzu (tag →
ad, tür, ana ülke, sadakat); koruma kayıtları (eyalet → asıl ülke, gün). Uyuyan ülkelerin motor alanları (eyaletler, tümenler) motor
kaydındadır (S5 ile `game.gd`).

### 13.2 Birim testleri (`tests/test_zm_politics.gd`)
1. `R0_c` 80 ülkede [0,20; 0,50] aralığında; Türkiye 0,35 ± 0,01.
2. Delta yöntemi: bir olayın kalıcı `war_support +0,05` etkisi, terimler değişse de 30 gün sonra hâlâ yerindedir.
3. Uyum: istikrar 0,5'te `m_etk = m`; 0,2'de 0,76·m.
4. Örtbas: Tam Sansür, günde 500 vaka, Türkiye → 200 günde G, 36.000 ± %2 olur.
5. S1: `UND` savaşı varken `Diplomacy.at_war(tag)` `false`, `are_enemies(tag, "UND")` `true`; seçim tarihinde seçim yapılır.
6. S4: Teslim sınırını aşan ülkenin eyaletlerinin sahibi değişmez; ülke Çökmüş olur.
7. Parçalanma: başkenti kopuk, istikrarı 0,1 olan yapay ülke 12 ayda en az bir yönetim kurar (tohumlu).
8. Koruma → iade: eyaletlerin sahibi geri döner, yardım puanı +0,10.
9. Yasa bedeli (S3): Gönüllü → Zorunlu Karantina 150; geri dönüş 50.
10. Olay veri denetimi (`test_data.gd`): 36 olayın hepsinde 2–3 seçenek, her seçenekte `ai`, bütün etki ve şart anahtarları tanımlı,
    EN ve TR metin var.

### 13.3 Denge hedefleri (oyuncusuz dünya, 6 koşu; her kontrol ≥ 5/6)

| # | Kontrol | Hedef | Neden |
|---|---|---|---|
| 1 | Bitişte çökmüş ülke | 1–25 (02 §8) | 02 ile aynı |
| 2 | Etkinleşen bölgesel yönetim | 2–24 | Parçalanma görülmeli ama haritayı boğmamalı |
| 3 | Alarm'dan 60 gün sonra Konsey üyesi | ≥ 55 / 80 | 68 demokrat ve bağlantısız ülke × 0,9 + 12 faşist ve komünist ülke × 0,6 ≈ 68 |
| 4 | Kabul edilen tasarı payı | %40–75 | Évian dersi: her şey geçmemeli |
| 5 | Sıkıyönetim ilan etmiş yapay zekâ ülkesi (bitişe kadar) | 15–45 | Sert önlem yaygın ama evrensel değil |
| 6 | Çöküş evresinde dünya ortalama istikrarı | %20–40 | İç Çöküş olayı nadir (≤ 10 ülke) kalmalı |
| 7 | Yapılan seçim / planlanan seçim | ≥ %50 | S1 çalışıyor; erteleme bir seçim |
| 8 | İade edilen koruma payı | ≥ %50 | Yapay zekâ %70 iade eder |
| 9 | `country_check.gd`: oyuncu hiçbir şey yapmazsa | Oyuncunun yasası, sınırı, üyeliği, oyu değişmemiş | Kural 1 |

## 14. Açık sorular

1. **S1 ve S4 zorunlu.** İkisi yapılmadan mod oynanamaz (seçimler, iç cephe, düşmüş eyaletlerin sahibi). Motor değişikliğine kim, ne
   zaman onay verecek? Sonrasında WWII denge testi (`balance_parallel.sh`) koşulmalı.
2. **9 yasa grubu** Hükümet panelinde okunaklı mı? Kaydırmayla (`fit_scroll`) sığdığı insan gözüyle doğrulanmalı. Sığmazsa Salgın
   paneline ikinci bir yasa bölümü mü açılmalı?
3. **Başlangıç iradesinin yeniden tanımı** (§2.2), 1936'nın ulusal durumlarının `war_support` etkisini fiilen siler. Bu doğru mu,
   yoksa etkinin bir bölümü (ör. %30'u) korunmalı mı?
4. **Kriz tutumları dördü yeterli mi?** "Kaderci / içe kapanan" (hiçbir şey istemeyen) beşinci bir tutum düşünüldü; dinî çağrışım riski
   ve olay yükü yüzünden eklenmedi.
5. **Uyuyan ülke havuzu (S5)** harita renk dokusunu ve bayrak üretimini etkinleşme anında doğru güncelliyor mu? Web sürümünde
   (gl_compatibility) insan gözüyle bakılmalı.
6. **Konsey'in AI oylama olasılıkları** tamamen kendi tahminimizdir. Denge testinden (kontrol 4) sonra yeniden ayarlanmalı.
7. **Oyuncunun ülkesi bölgesel yönetim olarak devam edebilir mi?** 01'in "direniş yönetimi" sorusuyla birleştirilebilir: çöken oyuncu,
   en büyük kopuk grubunun geçici yönetimi olarak sürdürür (kapalı başlayan seçenek).
8. **Darbe (A14)** oyuncunun lider adını değiştirir. Kayıttan devamda (`World.resume_game`) lider adı korunuyor mu? Test gerekir.
9. **Kaynak doğrulaması:** Bu oturumda web arama kotası doldu ve dış ağ erişimi kapalıydı. §15'te † ile işaretli kaynaklar bu belgede
   ilk kez kullanıldı ve bu oturumda yeniden açılamadı. Birleştirmeden önce bağlantılar ve künyeler (tarih, sayı) denetlenmelidir.
   İşaretsiz kaynaklar 01–07'de daha önce kullanılanlardır.
10. **Aşı Havuzu (R8)** tarihî bir karşılığı olmayan tek mekaniktir. Dönem tonuna uyuyor mu, yoksa yalnız iki taraflı doz yardımı mı kalmalı?

## 15. Kaynaklar

Güven, uyum ve kamuoyu
- † Blair, R. A., Morse, B. S., Tsai, L. L. (2017). Public health and public trust: Survey evidence from the Ebola Virus Disease
  epidemic in Liberia. *Social Science & Medicine* 172, 89–97. — https://doi.org/10.1016/j.socscimed.2016.11.016
- † Bargain, O., Aminjonov, U. (2020). Trust and compliance to public health policies in times of COVID-19. *Journal of Public
  Economics* 192, 104316. — https://doi.org/10.1016/j.jpubeco.2020.104316
- † Baekgaard, M., Christensen, J., Madsen, J. K., Mikkelsen, K. S. (2020). Rallying around the flag in times of COVID-19: Societal
  lockdown and trust in democratic institutions. *Journal of Behavioral Public Administration* 3(2). — https://doi.org/10.30636/jbpa.32.172
- † Mueller, J. E. (1970). Presidential popularity from Truman to Johnson. *American Political Science Review* 64(1). — https://doi.org/10.2307/1955610
- † WHO Avrupa Bölge Ofisi (2020). Pandemic fatigue: reinvigorating the public to prevent COVID-19. — https://www.who.int/europe/publications/i/item/WHO-EURO-2020-1160-40906-55390

1918 önlemleri ve yolculuk kısıtlamaları
- Hatchett, R. J., Mecher, C. E., Lipsitch, M. (2007). Public health interventions and epidemic intensity during the 1918 influenza
  pandemic. *PNAS* 104(18). — https://www.pnas.org/content/104/18/7582
- Bootsma, M. C. J., Ferguson, N. M. (2007). The effect of public health measures on the 1918 influenza pandemic in U.S. cities.
  *PNAS* 104(18). — https://www.pnas.org/doi/10.1073/pnas.0611071104
- † Markel, H. ve ark. (2007). Nonpharmaceutical interventions implemented by US cities during the 1918–1919 influenza pandemic.
  *JAMA* 298(6), 644–654. — https://doi.org/10.1001/jama.298.6.644
- † Mateus, A. L. P. ve ark. (2014). Effectiveness of travel restrictions in the rapid containment of human influenza: a systematic
  review. *Bulletin of the WHO* 92, 868–880D. — https://doi.org/10.2471/BLT.14.135590
- † 1918 grip salgını ve savaş sansürü ("İspanyol gribi" adı). — https://en.wikipedia.org/wiki/Spanish_flu
- † San Francisco Maske Karşıtı Birliği (1919). — https://en.wikipedia.org/wiki/Anti-Mask_League_of_San_Francisco
- † 1918 ABD seçimleri. — https://en.wikipedia.org/wiki/1918_United_States_elections
- † 1945 İngiltere genel seçimi (1935 parlamentosunun uzatılması). — https://en.wikipedia.org/wiki/1945_United_Kingdom_general_election
- † Avustralya'da 1919 grip salgını ve eyalet sınırları. *National Museum of Australia.* — https://www.nma.gov.au/defining-moments/resources/influenza-pandemic
- Samoa 1918. *NZ History.* — https://nzhistory.govt.nz/culture/1918-influenza-pandemic/samoa

Karantina, kargaşa ve zorunlu aşı
- Rusya kolera ayaklanmaları 1830–31. Bosin, Y. — https://www.unm.edu/~ybosin/documents/rus_chol.pdf
- 1892 Astrahan kolera salgını ve sonrası. — https://www.researchgate.net/publication/376686284_The_Demographic_Social_and_Economic_Aftermath_of_the_Cholera_Epidemic_in_Astrakhan_in_1892
- † 1771 Moskova veba kargaşası. — https://en.wikipedia.org/wiki/Plague_Riot
- 1892 Hamburg kolerası (R. J. Evans ile söyleşi). — https://blogs.darden.virginia.edu/globalwater/2020/10/27/qa-with-richard-j-evans-on-the-relevance-of-a-past-cholera-epidemic/
- 1720 Marsilya vebası. — https://www.historyhit.com/1720-start-europes-last-deadly-plague/
- † 1897 Salgın Hastalıklar Yasası (Hindistan). — https://en.wikipedia.org/wiki/Epidemic_Diseases_Act,_1897
- † Chapekar kardeşler ve Rand suikastı (Pune, 1897). — https://en.wikipedia.org/wiki/Chapekar_brothers
- † *Jew Ho v. Williamson* (1900). — https://en.wikipedia.org/wiki/Jew_Ho_v._Williamson
- † Aşı İsyanı, Rio de Janeiro (1904). — https://en.wikipedia.org/wiki/Vaccine_Revolt
- † 1898 Aşı Yasası ve vicdani ret. — https://en.wikipedia.org/wiki/Vaccination_Act_1898
- † Kara Ölüm döneminde Yahudilere yönelik zulüm ve Papa VI. Clemens'in fermanları. — https://en.wikipedia.org/wiki/Black_Death_Jewish_persecutions
- 1889 bulaşıcı hastalık bildirim yasası (İngiltere). — https://www.legislation.gov.uk/ukpga/Vict/52-53/72/contents/enacted
- † 1593 sayılı Umumi Hıfzıssıhha Kanunu (1930). — https://www.mevzuat.gov.tr/mevzuatmetin/1.3.1593.pdf
- Gensini, G. F. ve ark. (2004). The concept of quarantine in history. — https://pmc.ncbi.nlm.nih.gov/articles/PMC7133622/

Olağanüstü yönetim ve zorunlu hizmet
- † Emergency Powers Act 1920 (İngiltere). — https://en.wikipedia.org/wiki/Emergency_Powers_Act_1920
- † Reich Çalışma Hizmeti (1935 yasası). — https://en.wikipedia.org/wiki/Reich_Labour_Service
- † Tekâlif-i Milliye Emirleri (1921). — https://tr.wikipedia.org/wiki/Tek%C3%A2lif-i_Milliye_Emirleri
- † Millî Korunma Kanunu (1940). — https://tr.wikipedia.org/wiki/Mill%C3%AE_Korunma_Kanunu
- Air Raid Precautions. — https://en.wikipedia.org/wiki/Air_Raid_Precautions
- † Pied Piper Harekâtı (Eylül 1939 tahliyesi). — https://en.wikipedia.org/wiki/Operation_Pied_Piper

Uluslararası kurumlar, mülteciler ve yardım
- 1926 Uluslararası Sıhhiye Sözleşmesi. BM Cenevre Arşivi. — https://archives.ungeneva.org/international-sanitary-convention-1926
- Milletler Cemiyeti Sağlık Teşkilatı Singapur Bürosu. — https://www.newmandala.org/singapore-bureau/
- Milletler Cemiyeti'nin sağlık çalışmaları. *Milbank Quarterly* 13(1). — https://www.milbank.org/wp-content/uploads/mq/volume-13/issue-01/13-1-Health-Work-of-the-League-of-Nations.pdf
- † Milletler Cemiyeti Sağlık Teşkilatı (Salgın Komisyonu, 1920–22). — https://en.wikipedia.org/wiki/League_of_Nations_Health_Organisation
- † Uluslararası Halk Sağlığı Bürosu (1907). — https://en.wikipedia.org/wiki/Office_International_d%27Hygi%C3%A8ne_Publique
- 1910–11 Mançurya vebası ve ortak karantina. — https://pmc.ncbi.nlm.nih.gov/articles/PMC7110523/
- † Nansen pasaportu. — https://en.wikipedia.org/wiki/Nansen_passport
- † 1933 Mültecilerin Uluslararası Statüsüne İlişkin Sözleşme. *Refworld.* — https://www.refworld.org/docid/3dd8cf374.html
- † Évian Konferansı (1938). — https://en.wikipedia.org/wiki/%C3%89vian_Conference
- † St. Louis gemisi (1939). — https://en.wikipedia.org/wiki/MS_St._Louis
- Yunan Mülteci İskân Komisyonu. BM Cenevre Arşivi. — https://archives.ungeneva.org/greek-refugee-settlement-commission
- Retirada (1939). — https://www.histoire-immigration.fr/en/migration-characteristics-by-country-of-origin/the-retirada-or-post-war-spanish-republican-exile
- † Amerikan Yardım İdaresi (1921–23 Rusya kıtlığı). — https://en.wikipedia.org/wiki/American_Relief_Administration
- † Milletler Cemiyeti Misakı, md. 22 (manda sistemi). *Avalon Project, Yale.* — https://avalon.law.yale.edu/20th_century/leagcov.asp

Devletin çözülmesi
- † Avusturya-Macaristan'ın dağılması (Ekim 1918 ulusal konseyleri). — https://en.wikipedia.org/wiki/Dissolution_of_Austria-Hungary
- † Kurucu Meclis Komitesi (Komuch, Samara 1918). — https://en.wikipedia.org/wiki/Komuch
- † Çin'de savaş ağaları dönemi (1916–1928). — https://en.wikipedia.org/wiki/Warlord_Era

Depo içi
- `game/autoload/politics.gd` (etki sözlüğü, şartlar, olaylar, seçimler), `game/autoload/diplomacy.gd` (savaş, teslim), `game/autoload/economy.gd`
  (yasa şartı ve bedeli), `game/autoload/world.gd` (ülke yükleme, `transfer_state`), `game/core/country.gd`, `game/core/mode_rules.gd`,
  `game/ui/diplomacy_panel.gd`, `game/ui/event_popup.gd`, `game/ui/panel_layout.gd`, `data/common/{countries,laws,spirits,events}.json`,
  `data/map/states.json`, `data/history/states_1936.json`, `docs/modlar/README.md`, `docs/wiki/tr/03_hukumet.md`, `docs/wiki/tr/06_diplomasi.md`.
