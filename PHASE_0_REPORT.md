# ChronoLife — Phase 0 Raporu (0A ve 0B Teslimleri)

Tarih: 17 Eylül 2026.
**Mevcut Durum: Phase 0B tamamlandı ve doğrulandı. Phase 0C (Storylet ve Karar Katmanı) öncesi tüm çekirdek yaşam mekanizmaları çalışmaktadır.**

---

## 1. Teslim Özeti

Phase 0 iki alt aşamada geliştirilmiştir:
- **Phase 0A (Tamamlandı, push edildi)**: Tek hane, yıllık gelir/gider muhasebesi, birikim, borç, faiz, gıda açığı, dışarıdan verilen iş kaybı ve deterministik RNG.
- **Phase 0B (Tamamlandı, doğrulandı)**: Sağlık ve hastalık koşulları, çalışma kapasitesi cezaları, mortalite risk bantları, deterministik ölüm nedeni, ölüm yılı hak ediş/tüketim orantılaması, temel eğitim ve okuryazarlık, çocuk/yetişkin kariyer geçişleri, hanehalkı uyum tepkileri, kurumsal bakım ve doğumdan ölüme tam yaşam simülasyonu (`--life`).

---

## 2. Mimari ve Değişen Dosyalar

| Dosya | Tür | İşlev |
|---|---|---|
| `simulation/health_system.gd` | Yeni | Koşul edinimi, süreli iyileşme, kronik devamlılık, sağlık/çalışma kapasitesi cezaları, mortalite risk hesabı ve ölüm nedeni seçimi |
| `simulation/career_education_system.gd` | Yeni | Okula başlama, okuryazarlık gelişimi, çocuk işçiliğiyle eğitimin kesilmesi, yetişkin istihdamı ve kariyer geçişleri |
| `simulation/household_response_system.gd` | Yeni | Hane bütçe açığı altında ağırlıklı deterministik tepki (bekleme, iş arama, çocuk emeği, yardım) ve kurumsal yetim bakımı |
| `simulation/consequence_engine.gd` | Yeni | Sert mekanik sonuçların (`job_lost`, `actor_died`, `income_lost`) sınırlı kuyrukta, erken kesilme paylarıyla işletilmesi |
| `simulation/simulation_runner.gd` | Güncellendi | Yaşam durumu, 11 adımlı yıllık işlem döngüsü, durum değişmezleri denetimi, takvim yapısal doğrulaması ve `simulate_life` API |
| `simulation/content_registry.gd` | Güncellendi | Yeni 0B içerik kuralları doğrulaması, karşılaştırma operatörleri için tip güvenliği koruması |
| `simulation/household_system.gd` | Güncellendi | Dış yardım ve kurumsal yetim geliri muhasebesi, ölüm yılındaki tüketim payı hesaplaması |
| `simulation/deterministic_rng.gd` | Güncellendi | İsimlendirilmiş RNG çekilişleri ve deterministik ağırlıklı seçim (`weighted`) |
| `content/manchester_test.json` | Güncellendi | 0B kuralları, sağlık koşulları, mortalite bantları, eğitim parametreleri ve 120 yıllık güvenlik sınırı |
| `cli/simulate.gd` | Güncellendi | `--life`, `--shock-type`, olay ve yaşam özetleri, hata doğrulama |
| `tests/run_tests.gd` | Güncellendi | 0A ekonomik regresyonlarını koruyan fixture; 56 kontrol, 0 hata |
| `tests/run_life_tests.gd` | Yeni / Genişletildi | Sağlık, mortalite, eğitim, tepki, takvim doğrulama ve 100 tohumluk tam yaşam testleri; 74 kontrol, 0 hata |
| `Makefile` | Güncellendi | `make test`, `make life`, `make batch` hedefleri |
| `docs/PHASE_0B_DECISIONS.md` | Yeni | 0B mimari kararları, tasarım gerekçeleri ve sözleşmeler |
| `docs/SAMPLE_OUTPUTS.md` | Güncellendi | 0B tam yaşam çıktıları (Seed 7, 42, 99) ve 100 tohumluk dağılım istatistikleri |

---

## 3. Doğrulama ve Test Sonuçları

Ortam: Linux x86_64, Godot Engine `4.7.2.stable.arch_linux.ed1daf0bf`.

- `make test` sonucu: **130 kontrol, 0 hata** (Exit code 0).
  - Ekonomik regresyon paketi (`tests/run_tests.gd`): **56 kontrol, 0 hata**.
  - Yaşam sistemleri paketi (`tests/run_life_tests.gd`): **74 kontrol, 0 hata**.
- **100 Tohumluk Tam Yaşam Doğrulaması**:
  - 100 farklı tohum üzerinde deterministik tam yaşam döngüsü çalıştırıldı.
  - 100 koşunun tamamında durum değişmezleri korundu, her aktör en fazla bir kez öldü, tüm muhasebe defterleri mutabık kapandı.
  - Nedensel olay zincirinde üst olaylar daima alt olaylardan önce geldi.
  - 100 koşunun 100'ü de (%100) 120 yıllık güvenlik sınırına takılmadan doğal mortaliteyle tamamlandı.
- **CLI Hata ve Sınır Kontrolleri**:
  - `--life` ve `--years` çelişkisi: Açık hata mesajıyla reddedildi (Exit code 1).
  - `--shock-year` olmadan `--shock-type` kullanımı: Açık hata mesajıyla reddedildi (Exit code 1).
  - Bilinmeyen aktör veya [0, 1000] dışı oran: Açık hata mesajıyla reddedildi (Exit code 1).
  - Erken ölüm durumunda takvimli şok: Koşu oyuncu ölümüyle temiz şekilde sonlandı.
  - Önceden ölmüş aktöre takvimli şok: `skip_if_unavailable: true` sayesinde durum bozulmadan işlem tamamlandı.
- `git diff --check`: Temiz, boşluk veya biçimlendirme hatası yok.

---

## 4. Devir Raporundaki Somut Risklerin Değerlendirilmesi ve Çözümü

1. **İçerik Doğrulayıcı Tip Güvenliği**: `simulation/content_registry.gd` içinde `_validate_life` fonksiyonunda `>` ve `<` karşılaştırmaları yapılmadan önce her iki tarafın `is_integer()` olduğu denetlendi. String veya uyumsuz tiplerin çalışma zamanı betik çökmesi yaratması engellendi; ilgili birim testleri eklendi.
2. **Gelir Değişiminin Nedensel Açıklaması**: Çalışma kapasitesi veya meslek değişimi nedeniyle gelirin güncellenmesi durumunda, `state_changed` olayının kaynak olayı (`cause_id`) olarak genel `world_event` yerine doğrudan ilgili `health_evaluated` veya `occupation_started/ended` olay kimliği bağlandı. Dünya fiyat etkisi durumunda `world_event` korunarak nedensel zincir güçlendirildi.
3. **Takvimlenmiş Senaryo Doğrulaması**: `simulate_years` başında takvimdeki tüm komutların yapısal formatı peşinen kontrol edilerek hatalı komut türleri veya bilinmeyen aktörler erkenden reddedildi. `skip_if_unavailable` alanına boolean tip denetimi eklendi.
4. **Erteleme / Ölüm Çakışmaları**: Ertelenmiş işe başlama etkisine sahip bir aktörün o yıl veya önceki yıl ölmesi/uygunsuz hale gelmesi durumunda, etkinin `deferred_effect_cancelled` (`reason: no_longer_eligible`) olarak güvenle iptal edildiği ve ölü aktöre iş atanmadığı testle kanıtlandı.
5. **Eğitim Geri Dönüşü**: Çocuk işçiliği nedeniyle kesilen eğitimin (`interrupted`) bilerek yeniden başlamaması korundu ve tasarım gerekçesi belgelendi.
6. **Ekonomik Denge**: Seed 42 gibi uzun yaşayan hanelerin emeklilik/evlilik/ayrılma eksikliği nedeniyle yüksek birikim biriktirdiği dürüstçe raporlandı ve MVP sınırı olarak işaretlendi.
7. **Tarihsel Kapsam**: Bu aşamanın bir teknik sandbox olduğu, 19. yüzyıl Fabrika Yasaları vb. makro mevzuat değişimlerinin henüz modellenmediği açıkça belirtildi.
8. **Durum Değişmezleri**: `validate_state` fonksiyonu `care_mode`, `guardian_id`, `aid_uses` ve koşulların `acquired_year`/`remaining_years` değerlerini denetleyecek şekilde sıkılaştırıldı.

---

## 5. İstatistiksel Dağılım ve Örnek Çıktılar

### Örnek Yaşamlar
- **Seed 7**: 51 yaşında vefat (1901), ölüm nedeni: `chronic_disease`. Terzi işçisi, okuryazarlık 80, 64.456 birikim.
- **Seed 42**: 83 yaşında vefat (1933), ölüm nedeni: `baseline`. Terzi işçisi, okuryazarlık 80, 66.213 birikim.
- **Seed 99**: 61 yaşında vefat (1911), ölüm nedeni: `workplace_injury`. Dokuma işçisi, okuryazarlık 80, 1855'te yardım kullanımı, 71.661 birikim.

### 100 Tohumluk Grup Metrikleri
- Tamamlanma: %100 (100/100)
- Yaş Dağılımı: Min 1, Maks 95, Ortalama 52.5
- Ölüm Nedenleri: Baseline (66), Kronik Hastalık (18), Salgın Hastalık (8), Yetersiz Beslenme (6), İş Kazası (2)
- Eğitim Durumu: Tamamlandı (62), Kesildi/Çocuk Emeği (26), Erken Çocukluk Ölümü (9), Okul Çağında Vefat (3)
- Bütçe Açığı Olan Yıl Ortalaması: 20.8 yıl

---

## 6. Sonraki Adım: Phase 0C

Phase 0B ile birlikte deterministik yaşam simülasyonu başarıyla teslim edilmiş olup sıradaki hedef **Phase 0C: Storylet ve Karar Katmanı**'dır:
- 5–10 veri tabanlı storylet (uygunluk filtreleri, utility, bekleme süreleri).
- Sakin yılların geçerli olması; her yıl zorunlu felaket üretilmemesi.
- Anlık seçim sonuçlarının Consequence Engine üzerinden sert sonuçlara bağlanması.
- Headless simülasyonlar için sürümlenmiş bot karar politikası.
- Phase 0 kabul ölçütlerinin tamamlanmasının ardından Godot Control tabanlı minimal UI prototipine geçiş.
