# Zombi istilası modu — tasarım araştırması

**Ne?** Bu oyunun motoru ve dünya haritası üzerinde çalışan ikinci oyun modu: 1936'da bir limandan yayılan kurgusal bir hastalığa karşı
80 ülkeden birinin hükümetini yönetirsin. Çalışma adı *Gri Kordon* / *Grey Cordon*; menüde "Zombi İstilası / Zombie Outbreak".

**Neden?** Salgın, aynı devlet makinesini (fabrika, ordu, cephe, yasa, olay, araştırma, diplomasi) bambaşka bir düşmana karşı sınar:
sınır tanımayan, pazarlık etmeyen, nüfusunuzdan beslenen bir düşman. Motoru baştan yazmadan en farklı hissi veren ikinci moddur.

**Dönem ve süre:** 1 Ocak 1936 – 1 Ocak 1940, alternatif tarih; 1936'nın liderleri, fabrikaları, orduları yerinde, 2. Dünya Savaşı
olayları yok. **Oyuncu:** bir ülkenin hükümeti. **Ölçek:** tüm dünya; salgın 1.652 eyalette sayılarla, zombiler eyalet yoğunluğu ve
haritada 10.000'lik **sürü** birimleri olarak.

**Durum:** Tasarım ve araştırma tamam (17 belge). Kod yok; uygulama planı 14 ve 16'da. Oyun modu altyapısı bu depoda kuruldu
(`docs/modlar/README.md`).

---

## Belgeler

| # | Belge | Bir cümlede |
|---|---|---|
| 01 | [Vizyon ve temel kararlar](01_vizyon.md) | Dönem, rol, ölçek, süre, beş tasarım sütunu, ton ve içerik sınırları, çalışma adı, terimler sözlüğü |
| 02 | [Oynanış döngüsü](02_oynanis_dongusu.md) | Dakika–saat–oturum döngüsü, altı salgın evresi, kazanma/kaybetme, zorluk, ilk 30 gün |
| 03 | [Salgın modeli](03_salgin_modeli.md) | Yedi bölmeli eyalet modeli, yayılma ağları, iklim, gözetim, sürü doğumu, belirlenimcilik, ölçülmüş maliyet |
| 04 | [Zombi türleri](04_zombi_turleri.md) | 9 klinik tablo + 5 suş, muharebe değerleri (motor taklidiyle doğrulandı), evrim ağacı |
| 05 | [Araştırma merkezleri](05_arastirma_merkezleri.md) | 8 bina, bilim insanı kadrosu, numune, laboratuvar kazası, serum ve aşı, işbirliği |
| 06 | [Teknoloji ve yetenek ağacı](06_teknoloji_ve_yetenek_agaci.md) | 70 teknoloji, Kriz Doktrini (51 düğüm), doktrin puanı, karargâh emirleri, üç örnek kurgu |
| 07 | [Ekonomi ve nüfus](07_ekonomi_ve_nufus.md) | İşgücü, gıda (yedinci kaynak), karaborsa, mülteci kampları, ticaretin çöküşü, Romanya'nın 90 günü |
| 08 | [Askerî ve savunma](08_askeri_ve_savunma.md) | Kordon, 8 yeni tabur, tahkimat, mühimmat, ordu içi bulaş, moral, hava ve deniz gücü |
| 09 | [Siyaset, olaylar, diplomasi](09_siyaset_olaylar_diplomasi.md) | Kriz altındaki hükümet, 6 yasa grubu, kriz tutumları, devlet çöküşü, Konsey, 36 olay ve 6 zincir |
| 10 | [Yapay zekâ ve zorluk](10_yapay_zeka_ve_zorluk.md) | Sürü yapay zekâsı, devlet yapay zekâsı, hile yok, dinamik zorluğun reddi, 14 denge kontrolü |
| 11 | [Harita ve arayüz](11_harita_ve_arayuz.md) | Harita gösterimi (sürüm 1 / 2), üst çubuk, altı sekmeli Salgın paneli, 28 uyarı, rehber, erişilebilirlik |
| 12 | [Görsel varlıklar](12_gorsel_varliklar.md) | 267 dosyalık katalog (model, ikon, olay resmi, efekt), stil ve içerik sınırları, üretim sırası, bellek bütçesi |
| 13 | [Ses ve müzik](13_ses_ve_muzik.md) | 63 dosya (49 efekt, 7 parça, 7 stinger), müzik durum makinesi, sürü ambiyansı, radyo anonsları |
| 14 | [Teknik plan](14_teknik_plan.md) | Mod altyapısı üzerinde dosya yerleşimi, 48 motor kancası, mimari, kayıt, test planı |
| 15 | [Kalır / değişir / çıkar](15_kalir_cikar.md) | Temel oyunun her sistemi, dosyası ve aracı için karar ve yöntem |
| 16 | [Yol haritası](16_yol_haritasi.md) | Beş aşama (kancalar → MVP → alfa → içerik → cila), iş tahmini, test ve varlık sırası |
| 17 | [Özgünlük ve riskler](17_ozgunluk_ve_riskler.md) | Serbest fikir / korunan ifade, içerik hassasiyeti, ad denetimi, yaş hedefi, lisans, risk kaydı |

**Okuma sırası:** Hızlı bakış için 01 → 02 → 16. Tasarımın çekirdeği 03 → 04 → 08 (salgın, türler, kordon). Uygulayacaksan 14 → 15 →
ilgili konu belgesi. Varlık üreteceksen 12 ve 13 (her varlığın dosya adı ve üretim komutu orada). Yayın öncesi 17.

---

## Temel kararlar

| Konu | Karar | Belge |
|---|---|---|
| Dönem | 1930'lar alternatif tarih, 1 Ocak 1936 – 1 Ocak 1940 | 01 §3a |
| Oyuncu | Bir ülkenin hükümeti (80 ülke) | 01 §3b |
| Salgın sayıları | Eyalet düzeyinde (1.652), günlük | 01 §3c, 03 §12 |
| Zombiler | Eyalet yoğunluğu + sürü birimi (10.000 Boş); oynanamayan taraf `UND` | 01 §3c, 04 §2 |
| Hastalık | Kurgusal, biyolojik; hastalar yaşar; erken evre tedavi edilir; ölüler dirilmez | 01 §5 |
| Evreler | Sessizlik → Alarm → Yayılma → Çöküş → Karşı Saldırı → Sonuç (İkinci Dalga ile geri dönüş) | 02 §3 |
| Kazanma | Tedavi zaferi, Arındırma zaferi, Dayanma (puanlı) | 02 §4 |
| Kaybetme | Çöküş, nüfus çöküşü, İç Çöküş'te teslim | 02 §4 |
| Zorluk | Tatbikat / Salgın / Kara Yıl + Özel; dinamik zorluk yok | 02 §7, 10 §7 |
| Bilgi | Oyuncu ve yapay zekâ yalnız **bildirilen** veriyi görür | 01 Sütun 2, 03 §8, 10 §6 |
| Oyuncu karar verir | Bütün kolaylıklar kapalı başlar | 02 §7.3 |
| Harita | Düşmüş bölgeler işgal çizgisiyle; ısı haritası sürüm 2 (insan onayı) | 11 §2 |
| Veri yerleşimi | `common/*.patch.json` + `own/*.json` + `game/modes/zombie/` | 14 §2 |
| Motor | 48 içerikten bağımsız kanca, 8'i zorunlu; WWII birebir aynı kalır | 14 §3 |
| Yaş hedefi | 16+; görüntüde vahşet yok | 01 §6.6, 17 §4 |

---

## Sayılarla kapsam

| Öğe | Sayı | Belge |
|---|---|---|
| Zombi "türleri" | **14** (9 klinik tablo + 5 suş), 9 evrim özelliği | 04 |
| Teknoloji | **70** (27 bilim çekirdeği + 23 yeni + 20 taşınan; 13 temel teknoloji silinir) | 05, 06 |
| Yetenek ağacı (Kriz Doktrini) | **51 düğüm** (1 kök + 6 dal), 10 karargâh emri, 8 kabine uzmanı; komutan özellikleri (10) sürüm 2 | 06 |
| Araştırma merkezi / bina | **8** bilim binası + Kordon Hattı + mülteci kampı | 05, 07, 08 |
| Yeni tabur/bölük | **8** (alev, karantina jandarması, istihkâm, sıhhiye, nişancı, zırhlı taşıyıcı, köpekli, atlı devriye) | 08 |
| Yasa | **6 yeni grup**, 24 basamak (5 grup 20 basamak + Gıda Politikası 4) | 07, 09 |
| Seçenekli olay | **~60** (09: 36 ve 6 zincir; 05: 8; 08: 6; 02: evre olayları; 04: 3; 07: 3) | 02–09 |
| Uyarı | **28** | 11 §5.1 |
| Görsel varlık | **267** (16 mesh, 205 ikon, 36 olay resmi, 2 efekt, 8 şehir hâli) | 12 |
| Ses varlığı | **63** (49 efekt, 7 müzik, 7 stinger) + 8 isteğe bağlı kayıt + 6 müzik katmanı | 13 |
| Motor kancası | **48** (8 zorunlu, 26 önemli, 13 cila, 1 görsel) | 14 |
| Denge kontrolü | **14** ana (10 §8) + belge başına hedefler | 10, 05–09 |
| İş tahmini | ~50–70 ajan günü + ~25–40 insan günü + varlık üretimi | 16 |

---

## Açık sorular (birleşik)

Belgelerde çözülen sorular kaynağında "Çözüldü" diye işaretlidir. Açık kalanların öne çıkanları, temaya göre:

**Karar bekleyen (proje sahibi)**
1. Motor kancalarının (özellikle 8 zorunlu) onayı ve sırası — 14 §10-1, 16 §11-2, 09 §14-1
2. Mod adı marka araştırması ve "Hollow" sözcüğünün çağrışım taraması — 01 §10-4, 17 §3.3, §11-1
3. Web yayın biçimi: aynı paket mi ayrı indirme mi (≈ +70 MB) — 16 §11-4
4. Varlıkları kim üretecek — 16 §11-3
5. Çöken oyuncu "direniş yönetimi" olarak devam edebilsin mi — 01 §10-1, 09 §14-7

**Görsel doğrulama bekleyen (CLAUDE.md kural 5)**
6. Salgın ısı haritası (gölgelendirici, palet) — 01 §10-2, 03 §16-5, 11 §13-2
7. `UND` rengi; sürü figür sayısı; Kordon Hattı'nın harita çizgisi; şehir hâlleri — 11 §13-1, 12 §11-1/2
8. Kaputlu figürünün bir orduyu çağrıştırıp çağrıştırmadığı — 04 §13-5

**Ölçüm bekleyen**
9. Web performansı: 800 sürü, salgın adımı, Φ, katmanlı müzik — 03 §16-6, 10 §14-1, 13 §11-2
10. Denge ayarları: Tatbikat/Kara Yıl hedefleri, Konsey oy olasılıkları, top sesi çekimi, mühimmat yükü — 10 §14-3, 09 §14-6, 04 §13-9, 08 §19-5
11. Kaynak doğrulaması: iki belgede web erişimi olmadan yazılan tarihî ayrıntılar (işaretli) — 08 §19-12, 09 §14-9

**Tasarım**
12. Evre 1→2 koşulu (KSE mi, bildirilen vaka mı) — 03 §16-3
13. Bekleyen olayın bedeli — 10 §14-7
14. Sürülerin kordonu "sezmesi" — 10 §14-2
15. Hasat mevsimi, başkent stoku, değişken ticaret kuru — 07 §18
16. Doktrin yeniden seçimi, emirlerin hedefi — 06 §9-3/5

---

## Bu belgeler nasıl güncellenir?

- **Tek kaynak ilkesi:** Her sayı ve karar tek belgede kesinleşir; öteki belgeler bölüm numarasıyla bağlanır. Bir karar değişirse önce
  sahibi belge, sonra bu README'deki tablolar güncellenir.
- **Çözülen soru** kaynağında üstü çizilip "Çözüldü: <nerede>" diye işaretlenir; silinmez (karar izi kalır).
- **Dosya yolları** 14 §2'ye uyar (`data/modes/zombie/common/*.patch.json`, `own/*.json`, `game/modes/zombie/`).
- **Kurallar:** CLAUDE.md (özellikle kural 1 oyuncu karar verir, 3 iki dil, 4 özgünlük, 5 görsel değişiklik yok, 6 sanat dosyası
  üretilmez) ve docs/OZGUNLUK.md; 17 §10'daki ek inceleme listesi.
- **Başka eser anılmaz:** Belgelerde hiçbir ticari oyun, film, dizi ya da kitap model veya kaynak olarak anılmaz; kaynaklar bilimsel,
  tarihî ve teknik yayınlardır.
- Belgeler Türkçedir; oyun içi metin önerileri İngilizce ve Türkçe verilir.
