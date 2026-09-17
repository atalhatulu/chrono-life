# Phase 0A uygulama kararları

17 Eylül 2026. Bu belge, özgün v0.2 planını koruyarak ilk teknik teslimin kapsamını netleştirir. Önceki web teknolojisi önerisi uygulanmadı; kullanıcıyla seçilen yön Godot/GDScript'tir.

## Ortam ve kapsam

- Proje: `/home/teha/Documents/GitHub/Godot/chrono-life`.
- Uzak depo: `git@github.com:atalhatulu/chrono-life.git`, dal `main`.
- Godot: 4.7.2 Standard. İlk doğrulama ortamı `4.7.2.stable.arch_linux.ed1daf0bf`.
- Kullanıcının oluşturduğu proje, ikon, Git deposu ve editör ayarları korundu. Görüntüleme yöntemi gelecekteki UI için Compatibility olarak ayarlandı.
- Phase 0, 0A (ekonomik temel), 0B (sağlık/ölüm/eğitim/aile tepkileri), 0C (storylet/karar politikası ve tam hayat koşuları) teslimlerine ayrıldı. Bu teslim yalnızca 0A'dır.
- GDScript nesneleri `RefCounted`; durum sözlükleri JSON uyumlu. Yalnızca komut satırı girişleri `SceneTree` türetir. Aktör başına Node ve `_process()` yoktur.

## Yıllık işlem sözleşmesi

1850 başlangıç anıdır; ilk işlenen yıl 1851. Yaş, yıl eksi doğum yılıdır. Bu aşamada herkes hayatta kalır; ölüm ve ölüm yaşının sabitlenmesi 0B'de eklenecektir.

Sıra: girdiyi doğrula → derin çalışma kopyası → yeni yıl/dünya koşulları → yaş ve gelir hesapları → dışarıdan verilen iş kaybı ve doğrudan gelir sonucu → hane bütçesi → değişmezleri doğrula → commit.

`step(state, commands)` başarılıysa yeni durumu döndürür; girdi hiçbir zaman değiştirilmez. Hata halinde yeni kalıcı durum döndürülmez. Yayılım sınırı aşılırsa tamamlanmamış yılın teşhis olayları döndürülür ve giriş durumu korunur. Farklı sistemlerin çakışan atamaları için genel bir uzlaştırma motoru henüz yoktur; mevcut kapalı komut kümesindeki çakışmalar açık hata üretir.

Olay kimlikleri yıl ve sıra numarasından oluşur. Alan değişikliklerinde önceki değer, yeni değer ve kaynak olay tutulur. Hane gelir kaydındaki `consequence_ids`, gelir kaybı nedenlerini bütçeye bağlar. Yıllık defter/history eklemeleri işlem kapanışının parçasıdır.

## İş kaybı ve ekonomi

`job_lost` komutu aktör, olay kimliği ve `worked_permille` taşır. `500`, yılın yarısı kadar kazanç elde edildiği varsayımıdır. Önceden kazanılmış para korunur; aktif meslek `dependent`, aktif gelir sıfır olur. Komut sırası kimliğe göre sabitlenir. Aynı olayın aynı yükle tekrarı yok sayılır; aynı kimlikte farklı yük veya bir aktöre iki farklı iş kaybı reddedilir.

Şimdilik yalnızca iki sonuç türü vardır: `job_lost` ve `income_lost`. Böylece sınırlı ve tekrarları ayıklayan yayılım mekanizması kanıtlanır; bunun tüm Consequence Engine olduğu iddia edilmez. `dependent`, tarihsel meslek adı değil çekirdeğin gelir üretmeyen durum sözleşmesidir. Diğer meslek adlarına özel kod yoktur.

Tüm parasal durum tamsayı test birimleriyle tutulur. Gelir ve fiyat endeksi hesabının kesirli kısmı aşağı atılır. Kullanılan büyüklükler küçüktür; gerçek para birimi ve tarihsel ücret araştırması sonraya bırakılmıştır.

Ödeme sırası kira → gıda → diğer zorunlu ihtiyaçlardır. Açık, önce birikimle sonra kredi sınırı dahilinde borçla karşılanır. Karşılanamayan tutar `unmet_needs` olur; otomatik sınırsız borca dönüşmez. Faiz borcu büyütebilir, bu nedenle toplam borç kredi limitini aşabilir; bu durumda yeni kredi verilmez. Fazla gelir önce borcu öder, kalanı birikime eklenir. Bu basit sıra şimdilik aile davranışı yerine sabit bir muhasebe politikasıdır.

Gıda güvenliği, ödenen gıda tutarının gerekli gıda tutarına oranıdır (0–1000). Yaşam standardı bütçeden türetilir. Bunların henüz sağlık/ölüm etkisi yoktur.

## Tekrarlanabilirlik

Seed + başlangıç/içerik + verilen komutlar + simülasyon/RNG/Godot sürümü tekrarın girdileridir. İçeriğin SHA-256 özeti de durumda saklanır; sadece görünen sürüm etiketine güvenilmez. RNG anahtarı seed, sistem, yıl, varlık ve çekiliş adının JSON dizisidir; SHA-256'nın ilk 60 biti Godot RNG seed'ine çevrilir. Bir sistemin ek çekilişi başka bir isimlendirilmiş çekilişi tüketmez.

Godot'un RNG algoritması sürümler arasında sabit kabul edilmez. `.godot-version` hedefi bildirir; Make komutları motor sürümünü kontrol eder. Doğrudan Godot komutları bu kontrolü atlayabilir; her sonuç yine tam motor sürümünü kaydeder. Sistem paketinin otomatik güncellemesi olursa aynı sürümdeki bir Godot binary'si `make GODOT=/path/to/godot test` ile kullanılmalıdır.

## Sonraki teslim

0B: sağlık koşulları, ölüm, gelir kaynağının sona ermesi, eğitim/çocuk emeği uygunluğu ve bağlama göre aile tepkileri. Aynı gelir kaybında birikim, farklı iş imkanları ve aile tercihleri farklı yollar üretmeli. 0C: 5–10 storylet, sürümlenmiş bot karar politikası, doğumdan ölüme koşular ve ana plandaki tüm Phase 0 kabul ölçütleri.

Çekirdek doğrulandıktan sonra sade oynanabilir arayüzle oyuncu kararlarının ilgi çekiciliği test edilecek; büyük içerik listelerinin tamamlanması beklenmeyecek.
