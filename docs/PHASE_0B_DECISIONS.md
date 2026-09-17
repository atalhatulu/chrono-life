# Phase 0B Uygulama Kararları

17 Eylül 2026. Bu belge, Phase 0B (sağlık, ölüm, eğitim, kariyer ve hanehalkı tepkileri) tesliminin mimari kararlarını, veri sözleşmelerini ve teknik sınırlarını kayıt altına alır.

## 1. Mimari Kapsam ve İlkeler

- **Arayüzsüz ve deterministik**: Simülasyon arayüzden bütünüyle bağımsızdır. Node/Node2D/Node3D nesneleri veya `_process()` döngüleri kullanılmaz. Tüm simülasyon birimleri `RefCounted` tabanlıdır.
- **Tek Hayat, Tek Koşu**: Simülasyon oyuncunun doğumundan (1850) ölümüne kadar sürer. Oyuncu öldüğünde simülasyon o yılın muhasebesini kapatıp derhal durur. Çocuğa geçiş veya hanedan mekaniği yoktur.
- **Sert Mekanik Sonuçlar ile Davranışsal Tepkilerin Ayrımı**: Sağlık değerlendirmesi, ölüm ve iş kaybı doğrudan Consequence Engine üzerinden kesin kurallarla yürütülür. Hanenin borç veya açık karşısında aldığı tepkiler (bekleme, iş arama, çocuk emeği, yardım arayışı) ayrı bir davranışsal seçim katmanıdır.
- **Gelecek Yıla Erteleme (Deferred Pipeline)**: Hanenin aldığı davranışsal kararlar (`start_job`, `aid`) anında aynı yılın gelirini sihirli biçimde artırmaz; gelecek yıla (`due_year = year + 1`) ertelenir ve yıl başında hazırlanır.

## 2. Yıllık İşlem Sırası (Execution Pipeline)

1. Giriş durumu ve komutların doğrulanması (`validate_state`, `_validate_commands`). Bitmiş yaşamın tekrar ilerletilmesi engellenir.
2. `YearDelta` ile derin çalışma kopyası alınır; yıl ve dünya koşulları (`economy_index`, `food_price_index`, `disease_pressure`, `employment_pressure`) ilerletilir.
3. Yaşayan aktörlerin yaşları ilerletilir; ölü aktörlerin yaşları dondurulur.
4. Geçen yıldan ertelenmiş etkiler (`pending_effects`) uygulanır; yetişkinlerin istihdam durumu kontrol edilir.
5. Sağlık sistemi işletilir (`Health.advance`): koşul edinimi, iyileşme, kronik devamlılık, sağlık/çalışma kapasitesi düşüşü ve ölüm riskleri hesaplanır.
6. Çalışma kapasitesi ve meslek üzerinden yıllık potansiyel ücret belirlenir. Gelir değişikliğinin nedeni (meslek değişimi, sağlık kaybı veya dünya endeksi) doğrudan ilgili olaya bağlanır.
7. İş kaybı ve ölümün sert sonuçları `ConsequenceEngine.process` üzerinden işletilir; erken kesilme zamanları (`worked_permille`) baz alınır.
8. Yaşayan aktörlerin eğitimi ilerletilir (`Career.education`); bakım durumu (`update_care`) değerlendirilir, gerekirse kurumsal yetim desteği aktarılır.
9. Gerçekleşen kazançlar ve tüketim üzerinden bütçe ve muhasebe kapatılır (`Household.calculate`).
10. Oyuncu öldüyse yaşam sonlandırılır (`status = "player_dead"`, `pending_effects` temizlenir); aksi takdirde hanehalkı bütçe açığı varsa tepki seçimi yapılır (`Responses.choose`).
11. Durum değişmezleri (`validate_state`) doğrulanır ve yıl atomik olarak kaydedilir.

## 3. Sağlık, Hastalık ve Ölüm Modeli

- **Koşullar (Conditions)**: Dört temel koşul tanımlıdır:
  1. `malnutrition` (yetersiz beslenme - beslenme güvenliği eşiğin altına düştüğünde ortaya çıkar, gıda düzelince iyileşir).
  2. `epidemic_disease` (salgın hastalık - dünya hastalık baskısına bağlı ortam maruziyeti, süreli).
  3. `chronic_disease` (kronik hastalık - süresiz/kalıcı etki).
  4. `workplace_injury` (iş kazası - mesleki risk permille oranına bağlı, süreli).
- **Çalışma Kapasitesi**: Sağlık koşulları ve yaşlanma aktörün `work_capacity` (0–1000) değerini düşürür. Ücret bu kapasiteyle orantılı olarak azalır.
- **Ölüm Riski ve Nedeni**: Temel ölüm riski yaş bantlarına (`mortality_bands`) göre belirlenir ve aktörün `constitution` (bünye) değeriyle ölçeklenir. Ölüm gerçekleştiğinde deterministik ağırlıklı seçim ile ölüm nedeni (baseline veya mevcut koşullardan biri) seçilir.
- **Yıl İçi Kesinti ve Tüketim**: Ölüm yılında kazanılan ücret `worked_permille` oranında korunur. Gıda ve kişisel zorunlu tüketim harcamaları da aynı oranda azaltılır. Sabit hane masrafları (kira) tam yıl olarak tahakkuk eder.

## 4. Eğitim ve Kariyer Modeli

- **Eğitim Yaş Bandı**: Temel okul 6 yaşında başlar, 14 yaşında tamamlanır. Yıllık okuryazarlık (`literacy`) artışı sağlanır.
- **Eğitimin Kesilmesi**: Bir çocuk hane baskısı nedeniyle işe girdiğinde (`child_factory_worker`) temel okul `interrupted` olur ve okuryazarlık ilerlemesi durur.
- **Geri Dönüş Politikası**: 19. yüzyıl Manchester işçi sınıfı gerçekliğine uygun olarak, erken çocuk işçiliğine başlayan aktörler daha sonra tekrar okula dönemez (okul yalnızca `none` durumundaki bağımlı çocuklara açıktır).
- **Yetişkinliğe Geçiş**: Çocukluk yaş sınırını (16 yaş) aşan bir aktör çocuk işinde kalamaz; otomatik olarak ayrılır ve yetişkin iş seçeneklerine yönelir.

## 5. Hanehalkı Uyum ve Kurumsal Bakım Modeli

- **Tepki Seçimi**: Bütçe açığı durumunda hane birikim tamponunu kontrol eder. Açık rezervlerle kapatılamıyorsa ağırlıklı deterministik seçim yapılır:
  - `wait`: Bekleme/mevcut duruma katlanma.
  - `adult_work`: Boştaki yetişkinin iş araması.
  - `child_work`: Uygun yaştaki (9+) çocuğun işe girmesi (koruyucu trait'i `education_first` ise ağırlık 3 kat azalır; aşırı gıda açığında ağırlık 2 kat artar).
  - `seek_aid`: Sınırlı dış yardım talebi (en fazla 3 kullanım).
- **Yetimlik ve Kurumsal Bakım**: Hanedeki tüm yetişkinler öldüğünde, çocuklar hane yöneticisi yapılmaz. Hane `care_mode = "institutional"` moduna geçer; kurumsal yetim desteği (`orphan_support_per_child`) dış gelir olarak bağlanır ve çocukların kendi başlarına çocuk işçiliği kararı vermesi engellenir.

## 6. Güvenlik, Doğrulama ve Tip Güvenliği Düzeltmeleri

- **İçerik Doğrulayıcı Tip Güvenliği**: `_validate_life` içinde string veya uyumsuz tiplerin karşılaştırma operatörlerine (`>`, `<`) girmesi engellendi; her iki tarafın tamsayı olduğu `is_integer()` ile teyit edilerek çalışma zamanı çökmeleri önlendi.
- **Takvimlenmiş Senaryo Doğrulaması**: `simulate_years` başında takvimdeki tüm komutların yapısal bütünlüğü (nesne tipi, geçerli komut türü, geçerli aktör referansı, oran aralığı ve `skip_if_unavailable` boolean kontrolü) peşinen denetlenir.
- **Erken Ölüm ve İptal Mekanizması**: Oyuncunun erken ölümü halinde simülasyon derhal biter. Ölüm veya uygunsuzluk nedeniyle uygulanamaz hale gelen bekleyen etkiler `deferred_effect_cancelled` olarak güvenle iptal edilir.
- **İç Durum Değişmezleri**: `validate_state` fonksiyonu, `care_mode`, `guardian_id`, `aid_uses` ve koşulların `acquired_year`/`remaining_years` değerlerini denetleyecek şekilde sıkılaştırıldı.

## 7. Bilinen Sınırlar ve MVP Sınırları

1. **Ekonomik Denge**: Modelde henüz emeklilik, evlilik, evden ayrılma ve yeni hane kurma yoktur. Dolayısıyla uzun yaşayan haneler (örneğin Seed 42, 83 yaş) yüksek miktarda birikim biriktirebilir.
2. **Okuryazarlık Rolü**: Mevcut test işlerinin tamamı `minimum_literacy: 0` olarak tanımlıdır; okuryazarlık henüz daha yüksek gelirli mesleklerin kapısını açmamaktadır.
3. **Tarihsel Kapsam**: Bu aşama bir **teknik test sandbox'ıdır**. Gerçek tarihsel mevzuat değişimleri (Fabrika Yasaları vb.) ve tarihsel para birimi kalibrasyonu henüz mevcut değildir.
