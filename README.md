# ChronoLife

Tarihsel koşullar içinde tek bir insanın hayatını simüle eden oyun projesi.

**Mevcut teslim: Phase 0C simülasyonu ve yenilenmiş “Hayat Defteri” arayüzü.**
Veri tabanlı storylet motoru, sakin yıllar, çocukluk iradesi ve deterministik bot politikaları; Türkçe karar kartları, aile ve geçim ekranlarıyla oynanabilir. Arayüz Godot Control ile hazırlanmıştır; simülasyon kuralları sunum katmanından bağımsızdır.

## Çalıştırma

Godot **4.7.2 Standard** gerekir. Paket bağımlılığı veya eklenti gerekmez.

### 1. Grafik Arayüzü Başlatma
```bash
godot scenes/main.tscn
# veya doğrudan editörden / proje kökünden F5 ile
```

Alt çubuğun ortasındaki **+1 yıl** ile oyna; karar geldiğinde karttaki seçeneklerden birini seç.
**Ailem** ve **Geçim** sekmeleri ayrıntıları gösterir. **Yeni hayat** başlangıç sayısını
değiştirerek yeniden başlatır. Otomatik karar seçimi, **Ayarlar** içindeki geliştirici araçlarında bulunur.
Üstte karakter ve hane birikimi, ortada yıl/yaş sütunlu günlük, altta sabit eylemler ve
durum göstergeleri yer alır. Karar beklerken başka sekmeye geçersen **Karara dön** ile geri gel.
Pencere 1440×900 açılır; 960×640 boyutuna kadar yeniden düzenlenir.

### 2. Headless Komut Satırı ve Testler
```bash
make test       # Ekonomik regresyon (56) + Yaşam sistemleri (74) + Storyletler (31) = 161 test
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
godot --headless --path . --script tests/run_storylet_tests.gd
godot --headless --path . --script tests/run_ui_tests.gd

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
- **Veri Tabanlı Storyletler**: Manchester test içeriğinde 6 özgün storylet (`childhood_labor_demand`, `night_reading`, `overtime_shift`, `pawn_family_heirloom`, `dispensary_treatment`, `mutual_aid_subscription`).
- **Sakin Yıllar ("Quiet Years")**: Sabit ağırlıklandırmayla kriz olmayan yılların sakin geçmesi, her yıl yapay olay zorlanmaması.
- **Çocukluk İradesi (`Childhood Agency`)**: Koruyucunun trait'i (`education_first`) veya çocuğun irade eşiği (`willpower >= 50`) ile ebeveyn baskısına itiraz edebilme.
- **Deterministik Bot Politikaları**: Headless koşturmalar için 3 politika (`heuristic_v1`, `pragmatic`, `education_first`).
- **Hayat Defteri Arayüzü**: Türkçe hayat akışı, karar kartları, aile ve bütçe görünümleri; teknik dünya endeksleri ayrı geliştirici penceresindedir.
- **Sağlık ve Hastalık Modeli**: Veriyle tanımlı 4 sağlık koşulu (`malnutrition`, `epidemic_disease`, `chronic_disease`, `workplace_injury`), çalışma kapasitesi cezaları, iyileşme ve kronik devamlılık.
- **Mortalite ve Ölüm Nedenleri**: Yaş bantlarına göre temel ölüm riski, bünye (`constitution`) etkisi ve nedensel ölüm tanısı seçimi.
- **Ölüm Yılı Hak Ediş ve Tüketimi**: Ölüm anına kadar kazanılmış ücretin korunması; gıda ve kişisel zorunlu tüketimin yıl içi paya göre orantılanması; kira gibi sabit masrafların tam tahakkuku.
- **Eğitim ve Okuryazarlık**: 6–14 yaş temel okul, yıllık okuryazarlık artışı; çocuk işçiliğiyle eğitimin kesilmesi (`interrupted`).
- **Kariyer ve İstihdam**: Yetişkin iş bulma/yeniden istihdam; çocuk işçiliği yaş sınırı (16) aşıldığında işten ayrılma ve yetişkin işine geçiş.
- **Hanehalkı Uyum Tepkileri**: Bütçe baskısı altında deterministik ağırlıklı seçim (bekleme, yetişkin işi, çocuk işi, sınırlı dış yardım); koruyucu trait (`education_first`) etkisi.
- **Kurumsal Bakım**: Ebeveynlerin tamamı kaybedildiğinde hanehalkının `institutional` bakım moduna geçmesi ve kurumsal yetim desteği aktarılması.
- **Ertelenen Etki Boru Hattı**: Hane ve storylet kararlarının gelecek yıla ertelenmesi; ölüm veya uygunsuzluk durumunda bekleyen etkilerin güvenle iptal edilmesi (`deferred_effect_cancelled`).
- **Deterministik RNG & Olay İzi**: Her çekiliş için isimlendirilmiş bağımsız anahtarlar; tüm durum değişikliklerinin neden-sonuç ilişkisiyle kaydedilmesi.

## Sınırlar ve MVP Kapsamı

- Manchester içeriği bir **teknik test ortamıdır**; para birimi `test_credit` olup veriler henüz tarihsel olarak kalibre edilmemiştir.
- Modelde henüz evlilik, evden ayrılma, emeklilik ve yeni hane kurma yoktur. Bütün ömür aynı çekirdek hanede geçirilir.
- Mevcut test mesleklerinin `minimum_literacy` değeri 0'dır; okuryazarlık henüz farklı meslek kapıları açmamaktadır.
- LLM çağrıları, karmaşık DSL ve serbest metin üretimi Phase 0 kapsamı dışındadır; storyletler deklaratif şablonlarla çalışır.

## Dizinler

```text
cli/          Komut satırı giriş noktası (simulate.gd)
content/      Doğrulanan test içeriği (manchester_test.json)
assets/       Yerel yazı tipleri, lisans ve SVG çizimler
scenes/       Oynanabilir sahne (main.tscn)
simulation/   Sağlık, kariyer/eğitim, hane, storylet motoru, bot politikası, sonuç motoru ve RNG
tests/        Headless ekonomik regresyon, yaşam ve storylet testleri
ui/           Godot Control arayüzü, ortak tema ve Türkçe sunum metinleri
docs/         Ana tasarım planı ve aşama karar belgeleri
```

- Ana tasarım belgesi: [Master Plan v0.2](docs/ChronoLife_Master_Plan_v0.2.md)
- Arayüz tasarımı ve doğrulama: [UI Redesign Report](docs/UI_REDESIGN_REPORT.md)
- Phase 0C mimari kararları: [Phase 0C Kararları](docs/PHASE_0C_DECISIONS.md)
- Phase 0B mimari kararları: [Phase 0B Kararları](docs/PHASE_0B_DECISIONS.md)
- Phase 0A tarihsel kararları: [Phase 0A Kararları](docs/PHASE_0A_DECISIONS.md)
- Örnek simülasyon çıktıları: [SAMPLE_OUTPUTS.md](docs/SAMPLE_OUTPUTS.md)
- Teslim raporu: [PHASE_0_REPORT.md](PHASE_0_REPORT.md)
