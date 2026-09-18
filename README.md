# ChronoLife

Tarihsel koşullar içinde bir insanın hayatını simüle eden Godot oyunu.
Manchester 1850 test içeriği üzerinde doğum, eğitim, çalışma, aile, sağlık,
konut, kişisel gelişim ve varlık sistemleri birlikte çalışır.

**Mevcut sürüm: 0.5.1 — genişletilmiş yaşam sistemlerinin entegrasyon düzeltmeleri.**
Önceki Phase 1–4 geliştirmeleri korunmuştur. Bu sürüm evlilik ve hane hesabı
hatalarını, mezuniyeti, kişisel para aktarımını ve otomatik oynatma akışını düzeltir.
Ayrıntılar: [Entegrasyon raporu](docs/INTEGRATION_REVIEW.md).

## Çalıştırma

Godot **4.7.2 Standard** gerekir. Harici paket veya eklenti gerekmez.
Projeyi Godot'ta açıp **F5** tuşuna bas veya proje klasöründe çalıştır:

```bash
godot --path .
```

- **+1 yıl:** bir sonraki yılı hazırlar; karar gelirse seçimini yaparak yılı tamamla.
- **Hayatım / Ailem / Geçim:** günlük, aile ilişkileri ve ortak hane bütçesi.
- **Diğer:** eğitim, kariyer, sağlık, barınma, gelişim, varlıklar/statü ve harcamalar.
- **Diğer → Oto hayat:** mevcut hayatı kaldığı yıldan otomatik devam ettirir.
  **Otomatiği durdur** ile bir yılın sonunda kontrolü geri alabilirsin.
  Bekleyen bir karar varsa önce onu yanıtlaman gerekir.
- **Diğer → Yeni hayat:** başlangıç sayısıyla yeni bir hayat başlatır.
- **Ayarlar:** teknik simülasyon bilgileri ve yalnız yıllık kararları otomatik seçme seçeneği.

Hane birikimi ile cebindeki para farklıdır. Kişisel maaş payı ve çocukluk harçlığı,
zorunlu giderlerden sonra hanede kalan paradan aktarılır; yeni para yaratılmaz.
Harcamalar ekranında kişisel para, Geçim ekranında ortak bütçe görülür.
Tutarlar henüz tarihsel paraya kalibre edilmemiş **test birimleridir**.

Arayüz 1440×900 açılır; minimum masaüstü boyutu 960×640'tır. Dar pencerede sağ özet,
kısa pencerede şehir şeridi gizlenir. Alt eylem çubuğu sabit kalır.

## Testler ve komut satırı

```bash
make test       # Ekonomi, yaşam, storylet, aile, AutoLife, entegrasyon ve UI testleri
make life       # Seed 42: yıllık karar botuyla doğumdan ölüme
make batch      # 100 farklı başlangıçla tam yaşam koşuları
make shock      # 1858 iş kaybı senaryosu
make simulate   # 12 yıllık ekonomik koşu
```

`make test`, artık `run_autolife_tests.gd`, `run_integration_tests.gd` ve
`run_ui_tests.gd` dosyalarını da çalıştırır. AutoLife yalnız karar seçmez;
aktivite, ilişki, bakım, hobi, satın alma ve taşınma tercihlerini de yönetir.

```bash
# Tam hayat ve ayrıntılı JSON raporu
mkdir -p artifacts
godot --headless --path . --script cli/simulate.gd -- --seed 42 --life --output artifacts/life42.json

# Bütünleşik otomatik hayat testleri
godot --headless --path . --script tests/run_autolife_tests.gd

# Gerçek masaüstü görüntülerini artifacts/ui_*.png altında üretir
godot --path . --script tests/capture_ui.gd

# CLI seçenekleri
godot --headless --path . --script cli/simulate.gd -- --help
```

## Mevcut sistemler

- Deterministik yıllık simülasyon, atomik karar hazırlama/tamamlama ve neden-sonuç kaydı.
- Sağlık, hastalık, tedavi, çalışma kapasitesi, ölüm ve hayat özeti.
- Eğitim aşamaları, beceri/deneyim koşullu meslekler ve terfi.
- Evlilik, yeniden evlilik, çocuklar, akrabalık, ebeveynlik ve yaşlı bakımı.
- Yetişkin çocukların bağımsız haneye geçmesi ve torunlar.
- Kişisel para, harcamalar, üyelikler, konut, kalıcı varlıklar ve elden çıkarma.
- İlişkiler, ihtiyaçlar, kişilik, beceriler, hobiler ve toplumsal konum.
- İçerikle tanımlı bölgesel taşınma ve kalıcı yerel dünya etkileri.
- Türkçe hayat günlüğü ve mevcut hayatı sürdüren, durdurulabilir AutoLife.

## Sınırlar

Bu hâlâ bir prototiptir. Ekonomi tarihsel olarak kalibre edilmemiştir; büyük bir
birikimin mümkün olması tek başına bir hesap hatası anlamına gelmez. Para aktarımı
hataları giderilmiştir, fakat uzun vadeli ekonomi dengesi ayrıca çalışılmalıdır.

Ayrılan aile üyelerinin haneleri kaydedilir, ancak dış hanelerin bütçeleri henüz ana
hane kadar ayrıntılı simüle edilmez. Kayıt/yükleme, mobil ve web export doğrulaması
bu teslimde yoktur. Bazı yeni sistemlerin olayları henüz günlükte ayrıntılı Türkçe
anlatıma dönüşmez. Otomatik testlerin geçmesi tüm oyun tasarımının tamamlandığı
anlamına gelmez.

## Dizinler ve belgeler

```text
assets/       Yazı tipleri, lisans ve SVG çizimler
cli/          Headless komut satırı giriş noktası
content/      Manchester test paketi ve sistem katalogları
simulation/   Arayüzden bağımsız yaşam sistemleri
ui/           Godot Control arayüzü, tema ve sunum metinleri
scenes/       Oynanabilir ana sahne
tests/        Simülasyon, entegrasyon ve arayüz kontrolleri
docs/         Tasarım, inceleme ve teslim belgeleri
```

- [Ana tasarım planı](docs/ChronoLife_Master_Plan_v0.2.md)
- [Güncel entegrasyon raporu](docs/INTEGRATION_REVIEW.md)
- [Arayüz tasarım geçmişi](docs/UI_REDESIGN_REPORT.md)
- [Önceki birikim incelemesi](docs/ECONOMY_BALANCE_AUDIT.md)
- [Phase 0C kararları](docs/PHASE_0C_DECISIONS.md)
- [Phase 0B kararları](docs/PHASE_0B_DECISIONS.md)
- [Phase 0A kararları](docs/PHASE_0A_DECISIONS.md)
