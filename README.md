# ChronoLife

Tarihsel koşullar içinde tek bir insanın hayatını simüle eden oyun projesi.

**Mevcut teslim: Phase 0A — arayüzsüz ekonomik simülasyon temeli.** Henüz oynanabilir oyun, sağlık/ölüm modeli veya doğumdan ölüme çalışan tam yaşam çekirdeği yok. Bu teslim, bir ailenin yıllık bütçesini ve gelir kaybının sonuçlarını doğrular.

## Çalıştırma

Godot **4.7.2 Standard** gerekir. Paket bağımlılığı veya eklenti gerekmez. Linux'ta proje klasöründen:

```bash
make test
make simulate
make shock
make batch
```

`make shock`, 1858'de bir ebeveynin yılın yarısında işini kaybettiği teknik senaryoyu çalıştırır. Bu olay oyuncuya yazılmış sabit bir hayat hikâyesi değil, aynı ekonomik şokun farklı koşullardaki etkisini sınayan dış girdidir.

Make olmadan doğrudan:

```bash
godot --headless --path . --script tests/run_tests.gd
godot --headless --path . --script cli/simulate.gd -- --seed 42 --years 12
godot --headless --path . --script cli/simulate.gd -- --seed 42 --years 12 --shock-year 1858
godot --headless --path . --script cli/simulate.gd -- --seed 0 --years 20 --count 100
```

Komut satırı seçenekleri:

| Seçenek | Varsayılan | Açıklama |
|---|---|---|
| `--seed` | `42` | 0–2147483647; toplu koşuda başlangıç seed'i |
| `--years` | `12` | 1–30 yıllık teknik deney |
| `--count` | `1` | 1–1000 koşu; seed her koşuda bir artar |
| `--shock-year` | Yok | Deney aralığında bir iş kaybı yılı |
| `--actor` | `parent_1` | İşini kaybeden aktör; `--shock-year` ile kullanılır |
| `--worked-permille` | `500` | İş kaybından önce çalışılan yıl oranı: 0–1000 |
| `--output` | Yok | JSON raporu yolu; üst klasör mevcut olmalı |
| `--help` | — | Kullanımı gösterir |

Tam neden-sonuç izi ve durum çıktısı almak için:

```bash
mkdir -p artifacts
godot --headless --path . --script cli/simulate.gd -- --seed 42 --years 12 --shock-year 1858 --output artifacts/seed_42.json
```

Tek koşu çıktısı tüm durumu, muhasebe defterlerini, neden-sonuç kayıtlarını ve deterministik özeti içerir. Toplu çıktı her koşunun özetini içerir. Süre ölçümü sonuç parmak izinin dışındadır. `artifacts/` Git'e eklenmez.

Godot editöründe `project.godot` açılabilir; henüz başlangıç sahnesi olmadığı için F5 ile oyun başlamaz. Bu aşamanın giriş noktası yukarıdaki komutlardır.

## Şu anda çalışan sistemler

- Bir oyuncu, iki ebeveyn, bir hane ve bir yerleşim.
- JSON içerik doğrulaması ve veriyle tanımlanmış meslekler.
- Birbirinin rastgele çekilişlerini tüketmeyen, isimlendirilmiş RNG anahtarları.
- Yıllık ekonomik koşullar, gıda fiyatları ve yaş ilerlemesi.
- Mevcut gelir kaynağı ile yıl içinde kazanılmış paranın ayrılması.
- Tipi sınırlı iş kaybı → gelir kaybı sonuç zinciri; tekrar önleme ve yayılım sınırı.
- Birikim, sınırlı borç, faiz, borç geri ödemesi ve karşılanamayan ihtiyaçlar.
- Geçici durum üzerinde işlem; doğrulama başarılı olunca commit.
- Her değişiklik için kaynak olay, önceki/sonraki değer ve yıllık muhasebe kaydı.
- Otomatik testler ve toplu simülasyon komutu.

## Sınırlar

Manchester içeriği bir **teknik test ortamıdır**. `test_credit` birimi ve fiyatlar tarihsel araştırmaya dayanmıyor. İş kaybı henüz kendiliğinden oluşmaz; çalışma senaryosundan verilir. İş bulma, kariyer ilerleme, eğitim, sağlık, ölüm, aile davranışları ve storylet seçimi sonraki teslimlerdedir. Çocuk mesleği veri kaydı olarak vardır, henüz çocuğu işe yönlendiren sistem yoktur.

Deney süresinin bitişi `year_limit` olarak raporlanır; bir ölüm veya tamamlanmış hayat sayılmaz. Sürenin 30 yıl ile sınırlanması teknik kapsam sınırıdır. RNG tekrar üretilebilirliği aynı kod, içerik, komutlar ve Godot ortamıyla tanımlanır; farklı motor/platform sürümleri arasında eşitlik henüz doğrulanmadı.

## Dizinler

```text
cli/          Komut satırı giriş noktası
content/      Doğrulanan test içeriği
simulation/   Arayüzden bağımsız durum, RNG, işlem ve ekonomi
tests/        Bağımlılıksız headless test çalıştırıcısı
docs/         Ana tasarım planı ve uygulama kararları
```

Ana tasarım: [Master Plan v0.2](docs/ChronoLife_Master_Plan_v0.2.md). Güncel uygulama kararları: [Phase 0A kararları](docs/PHASE_0A_DECISIONS.md). Teslim sonucu: [PHASE_0_REPORT.md](PHASE_0_REPORT.md).

Geliştirme akışı: küçük teslim → ilgili testler → rapor → commit → `main` dalına push. Gizli bilgiler, motor önbelleği ve geçici çalışma çıktıları depoya eklenmez.
