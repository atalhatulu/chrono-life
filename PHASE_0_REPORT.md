# Phase 0 raporu — ilk teslim: 0A

Tarih: 17 Eylül 2026.

**Durum: Phase 0A tamamlandı. Ana plandaki Phase 0 bütünü henüz tamamlanmadı.**

## Sonuç

Tek hane ve üç aktör, Manchester test verisiyle arayüzsüz yıllık ekonomik simülasyondan geçebiliyor. Aynı girdiler aynı durum ve olay izini üretiyor. İş kaybı aktif geliri kaldırıyor; o yıl önceden kazanılmış ücret korunuyor. Bütçe açığı önce birikime, sonra sınırlı borca, ardından karşılanamayan ihtiyaçlara dönüşüyor.

Kod kullanıcının belirlediği `/home/teha/Documents/GitHub/Godot/chrono-life` deposuna taşındı. Eski geçici proje klasörü kaldırıldı. Mevcut `.git` ve kullanıcı tarafından oluşturulan proje dosyaları korundu; proje adı ve görüntüleme yöntemi güncellendi.

## Dosyalar ve mimari

| Dosya | İşlev |
|---|---|
| `simulation/simulation_runner.gd` | Başlangıç durumu, yıllık işlem, değişmezler, sınırlı sonuç kuyruğu, çok yıllık koşu |
| `simulation/year_delta.gd` | Derin çalışma kopyası, alan değişiklikleri ve nedensel kayıt |
| `simulation/household_system.gd` | Nakit/borç/harcama muhasebesi ve mutabakat |
| `simulation/deterministic_rng.gd` | İsimlendirilmiş, birbirinden bağımsız rastgele çekilişler |
| `simulation/content_registry.gd` | JSON okuma, kimlik/referans/aralık/yaş doğrulaması |
| `content/manchester_test.json` | Yerleşim, aile, dört meslek, bütçe ve sınır parametreleri |
| `cli/simulate.gd` | Tekli/toplu koşu, senaryo girdileri ve JSON rapor |
| `tests/run_tests.gd` | 56 otomatik kontrol; 100 seed üzerinde değişmez denetimi |
| `project.godot`, `.godot-version`, `Makefile` | Godot 4.7.2 hedefi ve çalıştırma komutları |
| `README.md`, `docs/PHASE_0A_DECISIONS.md` | Kullanım, kapsam ve uygulama sözleşmesi |
| `docs/ChronoLife_Master_Plan_v0.2.md` | Kullanıcının özgün planının değiştirilmemiş kopyası |
| `docs/SAMPLE_OUTPUTS.md` | Üç seed ve karşılaştırmalı ekonomik çıktı |

Godot tarafından üretilen script `.uid` dosyaları takip edilir. `.godot/` önbelleği ve `artifacts/` ham raporları takip edilmez. Kullanıcının mevcut ikon, import ve editör metin ayarları korunmuştur.

## Doğrulama

Ortam: Linux x86_64, `4.7.2.stable.arch_linux.ed1daf0bf`.

- `make test`: **56 kontrol, 0 hata**.
- Aynı seed ile 20 yıllık tam durum/iz eşitliği.
- Farklı seed'lerin ekonomik defterlerinin farklılığı.
- Aktör tanım sırası değişince ekonominin değişmemesi.
- İlgisiz rastgele çekilişin dünya çekilişini etkilememesi.
- 10 yıllık durumdan devam etmenin kesintisiz 20 yıl ile eşitliği.
- Başarılı ve başarısız işlemlerin giriş durumunu değiştirmemesi.
- Nakit/borç/harcama defterlerinin kapanması; sıfırın altına inen birikimin engellenmesi.
- Aynı gelir kaybı tetikleyicisinin iki kez uygulanmaması, çakışmaların reddedilmesi.
- Başlangıç/yarıyıl/yılsonu iş kaybında gerçekleşmiş kazancın korunması.
- Birikimi farklı iki ailenin aynı şoka farklı ekonomik tepki vermesi.
- Yayılım sınırı aşımında yılın iptali ve teşhis izinin korunması.
- 100 seed × 20 yıl için değişmezler ve muhasebe kontrolü.
- Ek komut satırı denemeleri: **11 geçersiz girdi** beklenen hata koduyla reddedildi; bilinmeyen seçenek, eksik/yinelenen argüman, hatalı sayı, geçersiz yıl/aktör/olay zamanı, yazılamayan çıktı yolu dahil.
- Yeni konumda Godot headless editör içe aktarması başarılı. İlk sandbox denemesinde yerel soket engeli vardı; izinli tekrar temiz tamamlandı. Bu, simülasyon kodu hatası değildi.

Bu kontroller tarihsel doğruluğu, oyunun eğlenceli olduğunu veya tüm platformlarda aynı sonucu kanıtlamaz.

## Ölçülen küçük model performansı

| Koşu | İşlenen yıllar | Çekirdek ve özet süresi |
|---|---:|---:|
| Tek seed | 12 | 8 ms |
| 10 seed | 200 | 166 ms |
| 100 seed | 2000 | 1661 ms |

Süreler tek yerel ölçümdür; Godot açılışı ve JSON dosya yazımı dahil değildir. Tam geçmiş kopyalama maliyeti mevcut; büyük NPC sayısına veya tamamlanmış hayat modeline yönelik performans iddiası yoktur. Şimdilik optimizasyon yapılmadı.

## Örnek sonuç

1858'de `parent_1` yılın yarısında işini kaybediyor; deney 1862'de bitiyor. Tutarlar tarihsel para değil test birimidir.

| Seed | 1862 birikim | 1862 borç | Bütçe açığı olan yıl | Gıdanın eksik finanse edildiği yıl |
|---|---:|---:|---:|---:|
| 7 | 0 | 1800 | 5 | 0 |
| 42 | 0 | 1836 | 5 | 2 |
| 99 | 0 | 1909 | 8 | 4 |

Seed 42'de iş kaybı uygulanmadığında 1862 birikimi 7141, borcu 0. İş kaybıyla 1860'ta borçlanma, 1861'de gıda açığı başlıyor. Seed 7'de önceki birikim daha fazla olduğu için gıda gideri 1862'ye kadar karşılanabiliyor; o yıl diğer zorunlu ihtiyaçlarda 258 birim açık oluşuyor. Böylece aynı şok tek bir sabit yoksulluk takvimi üretmiyor.

## Varsayımlar, sapmalar ve kalan işler

- Ana plandaki Godot 4.7.1 yerine mevcut ve doğrulanan 4.7.2 kullanıldı.
- Phase 0, küçük teslimlere ayrıldı. `simulate_life` ve ölümle tamamlanan `LifeResult` henüz yok; mevcut API `simulate_years(seed, years, schedule)`.
- 30 yıllık sınır teknik deney sınırıdır. Bitiş `year_limit`; ölüm uydurulmaz.
- Oyuncu/ebeveyn kimlikleri test verisinde sabit. Aile üretimi ve kardeşler henüz yok.
- Sağlık, ölüm, eğitim, yeniden işe girme, kariyer ilerleme, aile davranış seçimi ve storylet sistemi henüz yok.
- Muhasebe uyarlamaları sabit ödeme sırasına sahip; utility tabanlı aile kararları olarak sunulmuyor.
- Gelir kaybı dışarıdan verilen test komutudur; doğal işsizlik sistemi henüz yok.
- Günlük/aylık simülasyon yok; komut, yıl içindeki çalışılmış oranı açıkça taşır.
- Gelecek yıla ertelenen etki kuyruğu, oyuncu seçimleri ve kullanıcıya yönelik kayıt/yükleme ekranı henüz yok.
- Durum doğrulayıcı iç durum sözleşmesini kontrol eder; rastgele dış kayıt dosyalarını güvenle okuyan bir save parser değildir.
- Ayrı dünya değişkeni olarak hastalık ve istihdam baskısı 0B'de eklenecek. Tarihsel takvim henüz yok.
- Çapraz platform tekrar üretilebilirliği ve tam hayat performansı ölçülmedi.

Doğrulanan 0A kapsamındaki testlerde bilinen hata kalmadı. Yukarıdaki eksikler tamamlanmış özellik gibi değerlendirilmemelidir.

## Sonraki görev

0B'de birkaç sağlık koşulu ve ölüm, eğitim/iş uygunluğu, bağlama göre aile tepkileri eklenecek. Önce aynı gelir kaybının farklı aile koşullarında farklı geçerli sonuçlar doğurduğu doğrulanacak. Ardından 0C'de karar politikası ve 5–10 storylet ile doğumdan ölüme tam Phase 0 koşuları tamamlanacak.
