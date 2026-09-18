# GitHub geliştirmelerinin entegrasyon incelemesi

18 Eylül 2026. İncelenen başlangıç: `d2f5815` (`origin/main` ile aynı).
Önceki arayüz tesliminden (`5949110`) sonra 242 commit eklenmişti. Bunlar ihtiyaçlar,
kişisel para, ilişkiler, eğitim/kariyer, sağlık, konut, çoklu hane, aile dinamikleri,
beceri/kişilik/hobiler, varlıklar, statü, taşınma ve AutoLife geliştirmelerini içeriyor.
Son commitler ağırlıklı olarak Godot tip uyumluluğunu düzeltiyordu.

## Bulunan ve düzeltilen sorunlar

1. **Evlilik yıl kapanışını bozuyordu.** Yeni eş aktör listesine ekleniyor, aktif hane
   geliri ve hane kaydı güncellenmiyordu. Yeni eş artık bu kayıtlara da eklenir;
   kapanmış yıla geriye dönük bir yıllık maaş eklenmez.
2. **Yeni eşe uygun olmadığı iş verilebiliyordu.** Sadece yaş ve okuryazarlık
   kontrolüyle gözetmen seçiliyor, deneyim/beceri şartları atlanıyordu. Eşin tam
   başlangıç profili hazırlanır ve ortak kariyer uygunluk kontrolü kullanılır.
3. **Dış hanenin maaşları hesap dökümünde kalıyordu.** Hane gelir toplamı yalnız
   üyeleri sayarken aktör dökümü herkesin gelirini içeriyordu. Her ikisi artık aynı
   hane üyelerini kapsar. Dış hanelerin gelirleri ana haneye eklenmez.
4. **Okuldan mezun olunamıyordu.** Kayıt üst yaşı 13, mezuniyet yaşı 14 olan
   aşama, 14 yaşında kesiliyordu. Mezuniyet sınırı önce kontrol edilir; bitirilen
   aşamaya tekrar kayıt da önlenir.
5. **Çalışma kapasitesi sıfıra inince yıl reddediliyordu.** Yeni işe girme
   şartları ile mevcut işin sağlık nedeniyle gelir üretememesi ayrıldı. Sıfır
   kapasite yeni işe girişe izin vermez; o yıl mevcut işin sıfır gelirini bozmaz.
   Yaş sınırındaki zorunlu iş bitişi, adaptasyon kapalı teknik koşulda da uygulanır.
6. **Kişisel para üretiliyordu; elle oynarken ödeme yapılmıyordu.** Maaş payı ve
   harçlık yalnız AutoLife içinde kasadan düşmeden ekleniyordu. Şimdi bütün yollar
   aynı yıl kapanışını kullanır. Kişisel para haneden aktarılır, ödeme gerçekleşen
   kazanç üzerinden hesaplanır, hane rezervi aşılmaz ve yılda bir kez yapılır.
   İhtiyaç/ilişki yıllık değişimi de ortak hazırlık adımına taşındı.
7. **Alt menü 13 düğmeyle taşıyordu.** Beş ana düğme korunup ek ekranlar iki
   sütunlu **Diğer** penceresine alındı. Olmayan `home.svg` referansı kaldırıldı.
8. **Oto hayat mevcut hayatı baştan başlatıyordu.** Artık mevcut durumdan birer
   yıl ilerler, günlüğe sayfa ekler, arayüzü kilitlemez ve durdurulabilir. Bekleyen
   manuel kararı atlayamaz. Biten hayatı manuel işlemlerle değiştirmek de engellendi.
9. **Yeni testler ana test komutuna bağlı değildi.** AutoLife, entegrasyon ve UI
   testleri `make test` içine eklendi. AutoLife testindeki hata sonrasında eksik
   sözlük alanına erişip asılı kalma da giderildi.

Simülasyon sürümü `0.5.1-integration` oldu; önceki sürümün parmak izleriyle eşitlik
beklenmemelidir. Tarihsel içerik değerleri ve yeni sistemler kaldırılmadı.

## Para aktarımı kararı

Hane önce kira, gıda, temel ihtiyaçlar ve borç geri ödemesini karşılar. Önceden
tanımlı yaşa bağlı kişisel pay (%15 / %25 / %35), o yıl gerçekten kazanılan oyuncu
ücreti üzerinden hesaplanır ve kalan hane rezerviyle sınırlanır. Bu pay gelir
yaratmaz; hane kasası azalırken kişisel kasa aynı tutarda artar. Harçlık da aynı
kurala tabidir. Kişisel transferler ayrı geçmiş olaylarıdır; yıllık hane gider
dökümü transfer öncesi kapanışı, ekrandaki birikim ise güncel kasayı gösterir.

Bu bir tarihsel ekonomi kalibrasyonu değildir. Maaş paylaşımı, konut bedelleri,
uzun ömürlü hanelerin rezervleri ve yaşam standardı giderleri hâlâ oyun dengesi
çalışması gerektirir. Önceki altı haneli birikim incelemesi eski sürüme aittir;
bugünkü sürümde ayrı haneler ve iş üst yaş sınırları zaten vardır.

## Doğrulama

Godot 4.7.2 Standard; ekonomi 56, yaşam 74, storylet 31, aile 117, AutoLife 123,
entegrasyon 22, arayüz 54 kontrol. Yaşam testleri 100 başlangıcı; AutoLife testleri
tekrar oynatımı ve 20 farklı başlangıcı kapsar.

Gerçek OpenGL penceresinde ana akış, karar, aile, bütçe, tüm yeni bölümler,
960×640 menü ve ölüm ekranları yakalandı. Görseller yerelde `artifacts/ui_*.png`.
Tekrar üretim:

```bash
make test
godot --path . --script tests/capture_ui.gd
```

## Buradan devam

Öncelik, yeni sistemlerdeki eylemleri ve sonuçlarını hayat günlüğünde görünür
kılmak; ardından kayıt/yükleme ve çok yıllı ekonomi ölçümleri. Dış haneler hâlâ
basitleştirilmiş bütçe durumuyla çalışıyor. İçerik kataloglarındaki bazı alanlar
henüz tam mekanik karşılık bulmuyor; Phase 1–4 başlıkları tamamlanmış ürün anlamına
gelmiyor. Mobil/web export bu incelemenin kapsamı dışında kaldı.
