# Hayat Defteri — Godot arayüz yenilemesi

18 Eylül 2026. Amaç, mevcut simülasyonu oynarken değerlendirilebilen bir arayüz
sunmak; HTML'e geçiş kararını bu görünüm üzerinden verebilmek.

## Görünüm ve kullanım

- Kâğıt tonları, koyu yeşil yan menü, Noto Serif Display başlıklar, Noto Sans metinler.
- Manchester için projeye ait SVG çizim; harici servis veya indirme gerektirmez.
- Hayatım: son yıl en üstte, önemli anlar / tüm yıllar filtresi, Türkçe karar kartları.
- Ailem: gerçek aktör adları, yaş, meslek ve hayatta olma durumu.
- Geçim: son tamamlanan yılın gelir, ihtiyaç, birikim ve borç bilgileri.
- 1160 pikselden dar pencerede sağdaki özet kapanır; ayrıntılara menüden erişilir.
- Ölümde geçmiş korunur, ilerleme kapanır ve yeni hayat başlatılabilir.
- Teknik endeksler ve otomatik bot seçimi ayrı geliştirici penceresindedir.

Karar beklerken yıl henüz tamamlanmış sayılmaz. Yeni yıl düğmesi kilitlenir;
geçerli seçim, hazırlanan yılı bir kez tamamlar. Başarısız çözümün bekleyen kararı
bozmaması için çözüm kopyalanmış işlem üzerinde yürütülür. Yeni hayat açmak önce
başlangıç sayısının doğrulanmasını gerektirir. Görünüm yenilendiğinde en üstteki
güncel sayfa/karar görünür olur.

## Kod sınırı

`ui/main_ui.gd` düzen ve etkileşimi, `ui/chronicle_theme.gd` ortak görsel temayı,
`ui/chronicle_text.gd` sunum çevirilerini ve olaylardan üretilen anlatımı içerir.
Simülasyon kuralları değiştirilmedi; içerikteki teknik kimlikler korunur.
Türkçe metinler şu an mevcut Manchester paketi için hazırlanmıştır; yeni paketler
ve olay türleri eklendiğinde sunum karşılıkları da genişletilmelidir.

Çalışma klasöründe önceden bulunan aile/evlilik geliştirmeleri korunmuştur.
Arayüz aktör listesinden okuduğu için bu üyeleri de gösterir; aile simülasyonu
dosyaları bu görsel teslimin kapsamı dışındadır.

Yazı tipleri projeye gömülüdür. Noto Project Authors telif bildirimi ve SIL Open
Font License 1.1 metni `assets/fonts/OFL.txt` içindedir.

## Doğrulama

Godot 4.7.2 Standard üzerinde:

- Mevcut çalışma klasöründe ekonomik, yaşam, storylet ve aile testleri: 278 kontrol geçti.
- Gerçek sahne ve gerçek simülasyonla arayüz testi: 26 kontrol geçti.
- Commit'e alınacak dosyalardan oluşturulan temiz kopyada, önceki Phase 0C
  çekirdeğiyle aynı 26 arayüz kontrolü de geçti; yerel aile geliştirmelerine
  zorunlu bağımlılık yoktur.
- Gerçek OpenGL penceresinde doğum, karar, aile, bütçe, dar pencere, yeniden
  başlatma ve ölüm ekranları yakalandı; headless görüntü taklidi kullanılmadı.

```bash
godot --headless --path . --script tests/run_ui_tests.gd
# Masaüstü oturumunda gerçek ekran görüntülerini yeniden üretir:
godot --path . --script tests/capture_ui.gd
```

Ekran görüntüleri `artifacts/ui_*.png` altında yereldir ve Git'e eklenmez.
Desteklenen minimum masaüstü boyutu 960×640'tır. Bu teslim mobil veya web
export doğrulaması içermez; kayıt/yükleme de eklenmemiştir.
