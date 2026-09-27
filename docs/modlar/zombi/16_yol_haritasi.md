# Zombi modu — 16 Uygulama yol haritası

> **Özet.** *Gri Kordon* modunun tasarımdan oynanabilir sürüme giden yolu: beş aşama (altyapı ✔ → kancalar → MVP → oynanabilir alfa →
> içerik tamamlama → cila), her aşamada hangi belgeden neyin yapılacağı, bağımlılıklar, iş tahmini, test ve denge planı, varlık üretim
> sırası ve riskler.
> - **Aşama 0 (bitti):** Oyun modu altyapısı bu PR'da kuruldu (mod kaydı, veri katmanı, `own/`, kural kancaları, kayıt sürümü 2,
>   menü, testler, `tools/new_mode.py`).
> - **Toplam iş tahmini:** yazılım **~50–70 ajan günü** + insan incelemesi ve oyun testi **~25–40 gün** + varlık üretimi (kullanıcı,
>   267 görsel + 63 ses). En uzun yol: kancaların onayı → salgın çekirdeği → sürüler ve kordon → yapay zekâ → denge.
> - **İlk oynanabilir sürüm (MVP, Aşama 2):** "Sessiz Başlangıç" — 1 yıllık kısa senaryo, tek zorluk, salgın + sürü + kordon + serum.
>   Hedef: 1936'dan 1937'ye bir ülkeyle oynanır, 6 denge kontrolü geçer.
> - **Her PR'da:** tam test paketi, WWII birebir aynılık denetimi (tohumlu 400 gün), ve oyun mantığı değiştiyse WWII denge testi.
>   Mod kendi denge testini (`zm_balance`, 14 kontrol) Aşama 3'ten itibaren her mantık PR'ında koşar.

---

## 1. Aşamalar bir bakışta

```
[0 Altyapı ✔] → [1 Kancalar] → [2 MVP: Sessiz Başlangıç] → [3 Oynanabilir alfa] → [4 İçerik tamamlama] → [5 Cila ve yayın]
                     │                   │                          │                        │                     │
                 insan onayı        oyun testi (insan)         denge 14 kontrol        varlık dalgası 2      ısı haritası, katman müzik,
                 (motor dosyası)    varlık dalgası 1 (kısmi)   varlık dalgası 1 tam    ses/müzik             marka araması, hidden:false
```

| Aşama | Sonuç | Ajan günü | İnsan günü | Bağımlılık |
|---|---|---|---|---|
| 0 Altyapı | Mod sistemi (✔ bu PR) | — | — | — |
| 1 Kancalar | 48 kancanın A ve B kademeleri (34), `_template` örnekleri, WWII birebir | 6–9 | 2–4 (inceleme, onay) | 0 |
| 2 MVP | 1 yıllık kısa senaryo oynanır | 12–16 | 4–6 (oyun testi, görsel onay) | 1 (A kademesi) |
| 3 Oynanabilir alfa | Tam 4 yıllık kampanya, bütün sistemler | 16–22 | 6–10 | 2, 1 (B kademesi) |
| 4 İçerik tamamlama | Bütün olaylar, suşlar, parçalanma, Konsey, ses ve müzik | 10–14 | 6–10 (+ varlık üretimi) | 3 |
| 5 Cila ve yayın | Isı haritası, katmanlı müzik, efektler, performans, marka, görünür mod | 6–9 | 7–10 | 4 |
| **Toplam** | | **~50–70** | **~25–40** | |

**Tahminin dayanağı:** Bu depoda mod altyapısı (≈1.550 satır kod + test + belge, 42 dosya) ve inceleme düzeltmeleri yaklaşık 2 ajan
gününde yapıldı; 12 araştırma belgesi ~1 ajan günü. Zombi modu kodu 03–13'teki şemalara göre ~9.000–12.000 satır (9 alt sistem,
~12 test dosyası, 12 veri dosyası, ~60 olay) tahmin edilir; kanca PR'ları küçük ama onay ve birebir aynılık kanıtı gerektirir. İnsan
günleri oyun testini, görsel onayı (CLAUDE.md kural 5) ve inceleme turlarını içerir; varlık üretimi ayrıca sayılır.

---

## 2. Aşama 1 — Motor kancaları

14_teknik_plan.md §3.4'teki PR grupları. Her PR: kanca + `_template` modunda örnek kullanım + test + `docs/modlar/README.md` kanca tablosu +
WWII birebir aynılık kanıtı.

| PR | Kancalar | İçerik | Ajan günü |
|---|---|---|---|
| PR-K1 | H01–H08 (A kademesi) | Günlük sıra, salgın savaşı türü, teslim yerine mod kuralı, kordon cephesi, üretmeyen eyalet, mod paneli, muharebe çarpanı ve kayıp kancası | 2–3 |
| PR-K2 | H17–H27 | Ekonomi (ihtiyaç, ihracat sınırı, ithalat çarpanı, bina şartları), siyaset (doktrin puanı, karar para birimi, araştırma hızı, yasa şartı ve bedeli, uyuyan ülkeler, olay yer tutucuları) | 2–3 |
| PR-K3 | H09–H16, H28–H31 | Askerî (arazi, ikmal, yorgunluk, hava, tümen kaybı, tabur `extra`, hareket, görünürlük), yapay zekâ (stratejik, askerî, yasa, savaş ilanı) | 1,5–2 |
| PR-K4 | H32–H34 | Üst çubuk, uyarılar, kurulum ekranı | 0,5–1 |
| (Aşama 4–5) | H35–H47 (C), H48 (G) | Ses, oyun sonu, harita ikonları, yapay zekâ çeşitliliği, arayüz cilası; ısı haritası | 2–3 |

**Bitti ölçütü:** CI yeşil; WWII 400 günlük anlık görüntü main ile aynı; WWII denge testi 12 kontrolde ≥ 5/6; `_template` testleri yeni
kancaları kullanıyor.

---

## 3. Aşama 2 — MVP: "Sessiz Başlangıç"

01 §7'deki "kısa senaryo (1 saatlik Sessiz Başlangıç)" hedefi. Modun çekirdek hissini (salgın bir cephedir, geç ve eksik bilgiyle
yönetirsin) en az içerikle kanıtlar.

| İş | Belge | Kapsam (MVP) | Kapsam dışı (sonra) |
|---|---|---|---|
| İskelet | 14 §2 | `tools/new_mode.py zombie`, manifest (`hidden: true`, bitiş **1937-01-01**), `--blank` olaylar ve programlar, `UND` | — |
| Salgın çekirdeği | 03 | 7 bölme, günlük adım, yolcu + deniz + sürü yürüyüşü, iklim, sönme, gözetim ve bildirilen veri, KSE, evre 0–2 | Mülteci akışı, suş payları, zaman dilimleme |
| Sürüler | 04 §2–§3, 10 §3 | Olağan Boş + Seğirtken; cephe doğumu, yerel puan, Φ, sınır | 7 tablo daha, evrim |
| Kordon | 08 §4 | Kordon ordusu (H04), ısırık (H07), arazi çarpanı (H08) | Tahkimat, mühimmat, kuşatma |
| Bilim (en az) | 05 | Saha laboratuvarı + enstitü, "etkeni tanımla" ve "Serum I", serum dozu ve elle dağıtım | Numune, kaza, aşı, kadro ayrıntısı |
| Siyaset (en az) | 09 | Karantina Politikası yasa grubu (4 basamak), sınır tutumu, 10 olay (evre açılışları + 4 kriz) | Öteki yasa grupları, tutumlar, çöküş makinesi |
| Yapay zekâ (en az) | 10 §4 | Sınır tutumu, karantina yasası, kordon kurma, enstitü | Diplomasi, Konsey, doktrin |
| Arayüz | 11 | Salgın paneli: Durum, Eyaletler, Kordon; üst çubuk KSE; 10 uyarı; ipucu satırları | Öteki sekmeler, kurulum ekranı, rehber |
| Oyun sonu | 02 §4 | 1937'ye ulaşma (Dayanma), Çöküş | Tedavi ve arındırma zaferi |
| Testler | 14 §7 | `test_mode_zombie`, `test_zm_epidemic`, `test_zm_military` (kordon), `test_zm_save`, `test_zm_determinism`, country_check | — |

**Varlıklar (MVP'nin gerektirdiği, varlık dalgası 1'den 38 dosya):** 7 evre/bülten olay resmi, 6 üst çubuk/menü/zorluk ikonu (zorluk
karoları gerekmese de set birlikte üretilir), 10 uyarı ikonu, 2 tür ikonu (Olağan, Seğirtken), 4 sürü figürü (`hol_common_a/b`,
`hol_courser_a`, `hol_greatcoat_a` — Kaputlu MVP'de yok ama figür üretimi paket hâlinde), 4 bilim ikonu (saha lab., enstitü, serum dozu,
`map_institute`), 5 ses (`zm_horde_common_loop`, `zm_horde_far_loop`, `zm_siren_hand`, `zm_breach_alert`, `zm_alert_generic`). Dosya yoksa
oyun ikonsuz/sessiz çalışır; MVP varlık beklemez.

**Bitti ölçütü:**
- Türkiye, Birleşik Krallık ve Romanya ile 1 yıl oynanır; oyuncu adına hiçbir iş yapılmaz (country_check).
- `zm_balance` (1 yıllık kısaltılmış sürüm) kontrolleri: 1 (ilk tespit 8–31), 2 (evre 2: 60–150), 9 (belirlenimcilik), 10 (hız ≤ ×1,3),
  14 (sürü sınırı), 11'in 1 yıllık hâli (orta ülkelerin ≥ %70'i ayakta) — her biri ≥ 5/6.
- 02 §2.3 tablosu ±1 günle üretilir (`test_zm_epidemic`).
- Oyun testi (insan): 3 oturum, notlar `docs/modlar/zombi/` altında bir test raporuna.

---

## 4. Aşama 3 — Oynanabilir alfa

Tam 4 yıllık kampanya ve bütün sistemler. 14 §8'deki T3–T6 aşamaları.

| İş | Belge | Kapsam |
|---|---|---|
| Evreler ve zaferler | 02 §3–§4 | Altı evre, İkinci Dalga, üç zafer, üç yenilgi, puan |
| Salgın tamamı | 03 | Mülteciler, suş payları, zaman dilimleme (gerekirse), bütün ayarlar |
| Türler | 04 | 9 tablo, önder etkisi, top sesi, gece, kış, nehir; evrim ağacı Aşama 4'te |
| Bilim tamamı | 05 | 8 bina, kadro, 4 numune sınıfı, kaza, serum ve aşı, dağıtım, işbirliği |
| Teknoloji ve doktrin | 06 | 70 teknoloji, Kriz Doktrini (51 düğüm), DP, 10 karargâh emri, 8 uzman |
| Ekonomi | 07 | İşgücü, gıda, karaborsa, kamplar, sanayi taşıma, gıda politikası |
| Askerî tamamı | 08 | 8 tabur, tahkimat, mühimmat, kuşatma, yorgunluk, hava ve deniz rolleri |
| Siyaset ve diplomasi | 09 | 6 yasa grubu, kriz tutumları, çöküş makinesi, 4 diplomasi değeri, 12 eylem |
| Yapay zekâ tamamı | 10 | Devlet YZ karar tabloları, kişilik, zorluk, hile yok |
| Arayüz tamamı | 11 | Altı sekme, kurulum ekranı, rehber, oyun sonu dökümü, erişilebilirlik |
| Zorluk | 02 §7, 10 §7 | Tatbikat, Salgın, Kara Yıl, Özel |

**Varlıklar:** Varlık dalgası 1'in tamamı (106 dosya; 12 §8) ve ses çekirdeği (13 §3'te "Dalga 1" işaretli 20 efekt + 7 müzik parçası).

**Bitti ölçütü:** `zm_balance` 14 kontrolün hepsi ≥ 5/6 (varsayılan zorluk); öteki iki zorlukta hedefler ölçülüp yazılır (10 §8.2); tam
test paketi; 5 oyuncu oturumu (farklı ülke ve zorluk).

---

## 5. Aşama 4 — İçerik tamamlama

| İş | Belge |
|---|---|
| Olayların tamamı (~60 seçenekli olay ve 6 zincir) | 02 §3.4, 04 §9, 05 §10, 07 §10, 08 §13, 09 §7–§8 |
| Suşlar ve evrim ağacı, keşif | 04 §6–§7 |
| Devlet parçalanması: uyuyan ülke havuzu, geçici yönetim, askerî valilik, koruma ve iade | 09 §5 |
| Uluslararası Karantina Konseyi ve dokuz tasarı | 09 §6.6 |
| Ses ve müzik: kalan efektler, 7 stinger, radyo anonsları (metin) | 13 |
| Varlık dalgası 2 (147 dosya) | 12 §8 |
| C kademesi kancalar (H35–H47) | 14 §3 |

**Bitti ölçütü:** Bütün belgelerdeki denge hedefleri (05 §13.2, 06 §8, 07 §17, 08 §18, 09 §13.3, 10 §8) ölçülmüş ve ≥ 5/6; bütün olaylar
iki dilde; varlık listesi eksiksiz (dosya yoksa bilinçli olarak "sonra").

---

## 6. Aşama 5 — Cila ve yayın

| İş | Belge | Not |
|---|---|---|
| Salgın ısı haritası (H48) | 03 §13.3, 11 §2.4 | **İnsan onayı** (kural 5): iki hedefte ekran görüntüsü, renk körlüğü kontrolü |
| Katmanlı müzik | 13 §5.4 | Web'de eşzamanlılık ölçümü |
| Tabur figürleri, efektler, şehir hâlleri | 12 §3.2, §6, §7 | **İnsan onayı** |
| Web performansı | 03 §12, 10 §10 | Ekranlı ölçüm; sürü sınırı 800 doğrulaması |
| İçe aktarma ayarları | 12 §10 | İkonlar 256 px, olay resimleri kayıplı |
| "Sade içerik" ayarı, içerik notu | 17 §4–§5 | |
| Çeviri gözden geçirme | Kural 3 | İki dilde bütün metinler |
| Ad denetimleri | 17 §3 | Mod adı (marka), "Hollow" (çağrışım) |
| `hidden: false` ve ROADMAP | — | Mod menüde görünür |

**Bitti ölçütü:** Kullanıcı onayı; web sürümünde 30 dakikalık oturum akıcı; bütün testler yeşil.

---

## 7. Test ve denge planı

| Ne | Ne zaman | Araç | Eşik |
|---|---|---|---|
| Tam test paketi | Her PR | `tools/run_tests.sh` (CI) | Hepsi geçer |
| WWII birebir aynılık | Her kanca PR'ı ve her motor dokunuşu | Tohumlu 400 gün anlık görüntü, main ile | Yeni alanlar dışında aynı |
| WWII denge | Motor mantığı değişince | `tools/balance_parallel.sh 6` | 12 kontrol ≥ 5/6 |
| Mod birim testleri | Her mod PR'ı | `tests/test_zm_*.gd` | Hepsi geçer |
| Oyuncu adına iş yok | Her mod PR'ı | `country_check --game_mode=zombie --days=60` | 0 sorun |
| Mod denge | Aşama 3'ten itibaren mantık PR'larında | `zm_balance` + `balance_parallel.sh --game_mode=zombie` | 14 kontrol ≥ 5/6 |
| Performans | Aşama 2 sonu, 3 sonu, 5 | `sim.gd --game_mode=zombie`, ekranlı ölçüm | ≤ ×1,3 temel oyun; web akıcı |
| Oyun testi (insan) | Aşama 2, 3, 5 sonu | Oturum notları | Bulgular düzeltilir |

Belge başına denge hedefleri: 02 §8, 05 §13.2, 06 §8, 07 §17, 08 §18, 09 §13.3, 10 §8. Aşama 3'te bunlar tek bir `zm_balance.gd` çıktısında
birleştirilir (kontrol başına satır, `balance.gd` biçimiyle).

---

## 8. Varlık üretim sırası

Kullanıcı üretir (CLAUDE.md kural 6). Sıra, oyunun hangi anına hizmet ettiğine göre (12 §8.2, 13 §3):

| Sıra | Paket | Adet | Aşama |
|---|---|---|---|
| 1 | Evre olayları + ilk bülten resmi | 7 | 2 |
| 2 | Üst çubuk, menü, zorluk ikonları | 6 | 2 |
| 3 | Uyarı ikonları | 10 | 2 |
| 4 | MVP sesleri (sürü, siren, uyarı) | 5 | 2 |
| 5 | Sürü figürleri (Dalga 1) | 4 | 2 |
| 6 | Tür ikonları + önder rozeti | 11 | 3 |
| 7 | Bilim ikonları ve harita ikonları | 17 | 3 |
| 8 | Doktrin kökleri/kapanışlar, emirler, DP glifi | 20 | 3 |
| 9 | Siyaset, ekonomi, askerî Dalga 1 ikonları | 23 | 3 |
| 10 | Kalan Dalga 1 olay resimleri | 8 | 3 |
| 11 | Müzik parçaları (7) ve ses çekirdeği | ~27 | 3 |
| 12 | Varlık dalgası 2 + kalan sesler, stinger'lar | ~175 | 4 |
| 13 | Dalga 3 (tabur figürleri, efekt, şehir hâlleri) + katmanlı müzik | ~20 | 5 |

Üretim komutları `tools/make_icon_prompts.py --game_mode=zombie` ile veriden üretilir (12 §9); ses ve müzik `make_audio.py` /
`make_music.py` işlevleri Aşama 3–4'te yazılır (dosyalar kodla üretilebilir, ama depoya eklenmeden önce dinlenip onaylanır).

---

## 9. Riskler (yol haritasına özgü)

Ayrıntılı risk kaydı 17_ozgunluk_ve_riskler.md §9'dadır. Planı doğrudan etkileyenler:

| Risk | Etki | Azaltma |
|---|---|---|
| Kanca onayı gecikir | Aşama 2 başlayamaz | PR-K1 küçük ve önce; her kancanın yedek planı (kaynak belgeler) |
| Kapsam kayması | Takvim uzar | MVP kapsam dışı listesi (§3) bağlayıcıdır; yeni fikirler Aşama 4 listesine |
| Varlık üretim hızı | Görsel olarak eksik alfa | Oyun varlıksız çalışır; dalga sırası oynanışa göre |
| Denge 80 ülkede tutmaz | Alfa gecikir | Kontrol 11 (orta ülkeler) erken; zorluk hazır ayarları; yardım mekanikleri |
| Web performansı | Web sürümü oynanamaz | Aşama 2'de ölçüm; web sınırları (800 sürü, 2/eyalet, Φ iki günde bir) |
| Temel oyun hızla değişiyor | Yama ve kancalar kırılır | Her CI koşusunda `test_mode_zombie`; kanca sözleşmeleri belgeli |

---

## 10. Belgelerin dışında kalan konular (sonraki araştırma)

Belgeler yazılırken ele alınmayan ya da yüzeysel kalan konular; her biri için önerilen aşama:

| Konu | Durum | Öneri | Aşama |
|---|---|---|---|
| **Başarımlar** | Yok | Oyun içi, yalnız yerel (ör. "Temiz Liman: bir liman eyaletini 180 gün temiz tut"); motor desteği yok, küçük bir sistem | 5 |
| **Sonsuz oyun** (1940 sonrası devam) | 02 §7.2 bitiş tarihi seçenekli (1938/1940/1942) | "Bitiş yok" seçeneği; puan 1940'ta dondurulur | 4 |
| **Kısa senaryolar** | MVP "Sessiz Başlangıç" | Kıta senaryoları (`scenario.json` + başlangıç yeri kısıtı): "Balkan Kordonu", "Atlantik Limanları" | 4 |
| **Ülkeye özgü içerik** | Genel olaylar | Her büyük ülke ve Türkiye için 3–5 olay (ör. boğazlar ve deniz yolu nöbeti, Anadolu demiryolu hattı, 1938'de açılan Ankara Radyosu ile bilgilendirme) — gerçek felaketler (deprem vb.) salgınla birleştirilmez | 4 |
| **Gece / gündüz** | Oyun saati var (`GameClock.hour`); ışık değişmez | Yalnız çarpan olarak (Gecegezer, gece nöbeti emri); görsel gece yok (kural 5) | 3 |
| **İstatistik grafikleri** | Grafik yardımcısı yok | `PanelLayout.bar` sütunlarıyla 12 aylık seyir (11 §8); gerçek grafik yardımcısı ayrı arayüz işi | 5 |
| **Üçüncü dil** | EN + TR | Mod metinleri anahtar tabanlı; yeni dil sütunu eklenebilir | Sonra |
| **Çok oyunculu** | ROADMAP I | Belirlenimci salgın (durumsuz karma) lockstep'e uygun; devlet YZ'nin global üreteci engel | Sonra |
| **Mod içinde mod** (topluluk içerikleri) | Altyapı tek mod katmanı destekliyor | "Alt senaryo" = aynı modun farklı `scenario.json` ve `own/` ayarı; ayrı bir manifest yerine | Sonra |
| **Kayıt uyumu** (mod sürümleri arası) | `mode_state.v` | Sürüm yükselince eksik alan varsayılanla doldurulur (14 §5); eski mod kaydı açılamazsa açık uyarı | 3 |
| **Haritada kordon çizgisi** | Yok | Harita katmanı işi, insan onayı | 5 |

---

## 11. Açık sorular (yol haritası)

1. **MVP'nin bitiş tarihi** 1937 mi, yoksa tam oyunun 1940'ı mı (MVP'de yalnız kısıtlı içerikle)? Öneri: 1937 (kısa senaryo olarak kalıcı).
2. **Kanca PR'larını kim onaylayacak** ve hangi sırayla? (14 §10-1.)
3. **Varlık üretimi** kullanıcı tarafından mı, yoksa gönüllü katkıcılarla mı? Katkıcı için 12 ve 13'teki komutlar yeterli mi?
4. **Mod yayın biçimi:** web sürümünde mod, ana oyunla aynı pakette mi (≈ +70 MB) yoksa ayrı indirme mi?

## 12. Kaynaklar

- Bu klasör: 01–15, 17 (her aşamanın kapsam satırlarında bölüm numaralarıyla).
- Depo: `ROADMAP.md` (BÖLÜM MOD, G, I), `docs/modlar/README.md`, `tools/run_tests.sh`, `tools/balance_parallel.sh`, `game/dev/balance.gd`,
  `game/dev/sim.gd`, `game/dev/country_check.gd`, `tools/new_mode.py`, `tools/make_icon_prompts.py`, `tools/make_audio.py`, `tools/make_music.py`.
