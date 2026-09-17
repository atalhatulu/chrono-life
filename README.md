# ChronoLife

Tarihsel koşullar içinde tek bir insanın hayatını simüle eden oyun projesi.

**Mevcut teslim: Phase 0B — arayüzsüz tam yaşam simülasyonu çekirdeği.**
Bu teslim; sağlık koşulları, mortalite, eğitim, kariyer, hanehalkı uyum tepkileri ve doğumdan ölüme (`--life`) çalışan deterministik yaşam döngüsünü doğrular. Henüz oyuncu arayüzü ve storylet katmanı bulunmamaktadır.

## Çalıştırma

Godot **4.7.2 Standard** gerekir. Paket bağımlılığı veya eklenti gerekmez. Linux'ta proje klasöründen:

```bash
make test       # Ekonomik regresyon (56) + Yaşam sistemleri (74) = 130 test
make life       # Seed 42 için doğumdan ölüme tam yaşam simülasyonu
make batch      # 100 farklı tohum üzerinde toplu tam yaşam simülasyonu
make shock      # 1858 iş kaybı şoku teknik senaryosu
make simulate   # 12 yıllık temel ekonomik simülasyon
```

Make olmadan doğrudan komut satırından çalıştırma:

```bash
# Testleri çalıştırma
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script tests/run_life_tests.gd

# Tek bir tam hayat simülasyonu (doğumdan ölüme)
godot --headless --path . --script cli/simulate.gd -- --seed 42 --life

# 100 tohumluk toplu yaşam simülasyonu ve JSON raporu
godot --headless --path . --script cli/simulate.gd -- --seed 0 --count 100 --life --output artifacts/cohort100.json

# Belirli bir yılda aktör ölümü veya iş kaybı şoku
godot --headless --path . --script cli/simulate.gd -- --seed 42 --years 20 --shock-year 1858 --shock-type actor_died --actor parent_1
```

## Komut Satırı Seçenekleri

| Seçenek | Varsayılan | Açıklama |
|---|---|---|
| `--life` | — | Oyuncunun doğumundan ölümüne kadar tam yaşam simülasyonu (`--years` ile birlikte kullanılamaz) |
| `--years` | `12` | 1–120 yıllık teknik deney süresi |
| `--seed` | `42` | 0–2147483647; toplu koşuda başlangıç tohumu |
| `--count` | `1` | 1–1000 koşu; tohum her koşuda bir artar |
| `--shock-year` | Yok | Deney aralığında bir şok yılı |
| `--shock-type` | `job_lost` | Şok türü: `job_lost` veya `actor_died` |
| `--actor` | `parent_1` | Şoktan etkilenen aktör; `--shock-year` ile kullanılır |
| `--worked-permille` | `500` | Şoktan önce çalışılan yıl oranı: 0–1000 |
| `--output` | Yok | JSON raporu yolu; üst klasör mevcut olmalı |
| `--help` | — | Kullanımı gösterir |

Tam neden-sonuç izi ve durum çıktısı almak için:

```bash
mkdir -p artifacts
godot --headless --path . --script cli/simulate.gd -- --seed 42 --life --output artifacts/phase0b_seed42.json
```

## Şu Anda Çalışan Sistemler

- **Tek Hayat, Tek Koşu**: Doğumdan (1850) ölüme kadar tek bir aktörün simülasyonu; ölüm anında koşu atomik olarak sonlanır.
- **Sağlık ve Hastalık Modeli**: Veriyle tanımlı 4 sağlık koşulu (`malnutrition`, `epidemic_disease`, `chronic_disease`, `workplace_injury`), çalışma kapasitesi cezaları, iyileşme ve kronik devamlılık.
- **Mortalite ve Ölüm Nedenleri**: Yaş bantlarına göre temel ölüm riski, bünye (`constitution`) etkisi ve nedensel ölüm tanısı seçimi.
- **Ölüm Yılı Hak Ediş ve Tüketimi**: Ölüm anına kadar kazanılmış ücretin korunması; gıda ve kişisel zorunlu tüketimin yıl içi paya göre orantılanması; kira gibi sabit masrafların tam tahakkuku.
- **Eğitim ve Okuryazarlık**: 6–14 yaş temel okul, yıllık okuryazarlık artışı; çocuk işçiliğiyle eğitimin kesilmesi (`interrupted`).
- **Kariyer ve İstihdam**: Yetişkin iş bulma/yeniden istihdam; çocuk işçiliği yaş sınırı (16) aşıldığında işten ayrılma ve yetişkin işine geçiş.
- **Hanehalkı Uyum Tepkileri**: Bütçe baskısı altında deterministik ağırlıklı seçim (bekleme, yetişkin işi, çocuk işi, sınırlı dış yardım); koruyucu trait (`education_first`) etkisi.
- **Kurumsal Bakım**: Ebeveynlerin tamamı kaybedildiğinde hanehalkının `institutional` bakım moduna geçmesi ve kurumsal yetim desteği aktarılması.
- **Ertelenen Etki Boru Hattı**: Hane kararlarının gelecek yıla ertelenmesi; ölüm veya uygunsuzluk durumunda bekleyen etkilerin güvenle iptal edilmesi (`deferred_effect_cancelled`).
- **Deterministik RNG & Olay İzi**: Her çekiliş için isimlendirilmiş bağımsız anahtarlar; tüm durum değişikliklerinin neden-sonuç ilişkisiyle kaydedilmesi.

## Sınırlar ve MVP Kapsamı

- Manchester içeriği bir **teknik test ortamıdır**; para birimi `test_credit` olup veriler henüz tarihsel olarak kalibre edilmemiştir.
- Modelde henüz evlilik, evden ayrılma, emeklilik ve yeni hane kurma yoktur. Bütün ömür aynı çekirdek hanede geçirilir.
- Mevcut test mesleklerinin `minimum_literacy` değeri 0'dır; okuryazarlık henüz farklı meslek kapıları açmamaktadır.
- Hikâye/karar katmanı (Storylets) ve oyuncu kararları Phase 0C'de eklenecektir; şu anki kararlar sürümlenmiş hane tepki politikasıyla yürütülür.
- Godot Control tabanlı minimal grafik arayüz Phase 0 çekirdeği tamamlandıktan sonra eklenecektir.

## Dizinler

```text
cli/          Komut satırı giriş noktası (simulate.gd)
content/      Doğrulanan test içeriği (manchester_test.json)
simulation/   Sağlık, kariyer/eğitim, hane, sonuç motoru ve RNG
tests/        Headless ekonomik regresyon ve yaşam testleri
docs/         Ana tasarım planı ve aşama karar belgeleri
```

- Ana tasarım belgesi: [Master Plan v0.2](docs/ChronoLife_Master_Plan_v0.2.md)
- Phase 0B mimari kararları: [Phase 0B Kararları](docs/PHASE_0B_DECISIONS.md)
- Phase 0A tarihsel kararları: [Phase 0A Kararları](docs/PHASE_0A_DECISIONS.md)
- Örnek simülasyon çıktıları: [SAMPLE_OUTPUTS.md](docs/SAMPLE_OUTPUTS.md)
- Teslim raporu: [PHASE_0_REPORT.md](PHASE_0_REPORT.md)
