# ChronoLife — Örnek Simülasyon Çıktıları

Bu belge, headless simülasyon çıktılarının doğrulanması ve incelenmesi için teknik referans sunar.

---

## 0. Phase 0C Storylet ve Bot Politikası Karşılaştırmalı Çıktıları

Phase 0C ile birlikte simülasyona veri tabanlı storylet katmanı, sakin yıllar mekanizması ve deterministik bot karar politikaları eklenmiştir.

### Aynı Tohum, Farklı Hayat Yolları (Seed 42 Karşılaştırması)

Aynı tohum (Seed 42) ve aynı dünya koşulları altında, farklı bot politikalarının aldığı kararlar ve ürettiği hayat sonuçları:

#### 1. Politika: `heuristic_v1` / `pragmatic` (Pragmatik ve Dengeli Yaklaşım)
- **1860 Yılı Olayı**: `night_reading` (Reading by Candlelight)
- **Verilen Karar**: `rest` (Yarınki çalışma için dinlenmeyi tercih etti)
- **Sonuç**: Sağlık 100/100 korundu, Okuryazarlık 70/100 kaldı.
- **SHA-256 Parmak İzi**: `27b5dc258ed4ac182fff67f74a184236b2859a9d17415a2e2063505502248e7c`

```text
EVENT 1851 | quiet_year | {"year":1851}
EVENT 1852 | condition_acquired | {"actor_id":"player","chance_bp":316,"condition_id":"epidemic_disease"}
EVENT 1852 | quiet_year | {"year":1852}
EVENT 1856 | school_started | {"actor_id":"player"}
EVENT 1859 | condition_acquired | {"actor_id":"parent_1","chance_bp":450,"condition_id":"workplace_injury"}
EVENT 1860 | storylet_triggered | {"family":"self_improvement","storylet_id":"night_reading","title":"Reading by Candlelight"}
EVENT 1860 | storylet_choice_made | {"applied_effects":{"health":100},"choice_id":"rest","storylet_id":"night_reading"}
EVENT 1861 | quiet_year | {"year":1861}
EVENT 1862 | quiet_year | {"year":1862}
Outcome: age 12, literacy 70, health 100, savings 5100
```

#### 2. Politika: `education_first` (Öğrenme ve İnsani Sermaye Önceliği)
- **1860 Yılı Olayı**: `night_reading` (Reading by Candlelight)
- **Verilen Karar**: `study_diligently` (Mum ışığında ders çalıştı ve yazdı)
- **Sonuç**: Okuryazarlık +15 artarak 85/100 seviyesine yükseldi, Sağlık göz yorgunluğu/uykusuzluk nedeniyle 90/100'e düştü.
- **SHA-256 Parmak İzi**: `56848d388c9231f16158275dc814218efa23459aa600f537a8b59ba344daa2c3`

```text
EVENT 1860 | storylet_triggered | {"family":"self_improvement","storylet_id":"night_reading","title":"Reading by Candlelight"}
EVENT 1860 | storylet_choice_made | {"applied_effects":{"health":90,"literacy":65},"choice_id":"study_diligently","storylet_id":"night_reading"}
Outcome: age 12, literacy 85, health 90, savings 5100
```

### Sakin Yıllar ("Quiet Years") Doğrulaması
12 yıllık koşuda 10 yıl `quiet_year` olarak kaydedilmiş, sadece 1 yıl (`1860`) storylet tetiklenmiştir. Bu durum her yıl yapay kriz üretilmediğini ve sakin yılların modelde doğal olarak var olduğunu kanıtlar.

---

## 1. Phase 0B Tam Yaşam Çıktıları (Doğumdan Ölüme)

Phase 0B ile birlikte oyuncunun 1850 yılındaki doğumundan ölümüne kadar tüm yaşam döngüsü simüle edilmektedir. Komut:
```bash
godot --headless --path . --script cli/simulate.gd -- --seed <SEED> --life
```

### Seed 7 (Yaşam Süresi: 51 Yıl, 1850–1901)
- **Eğitim**: 1856'da okula başladı, 1864'te tamamladı (Okuryazarlık: 80).
- **Kariyer**: 1867'de yetişkin olarak `sewing_worker` (terzi işçisi) oldu.
- **Sağlık & Ölüm**: 1892'de `chronic_disease` edindi. 1901 yılında 51 yaşında kronik hastalık komplikasyonuyla vefat etti.
- **Ekonomi**: 64.456 birikim, 0 borç, 5 bütçe açığı yılı, 0 gıda güvensizliği yılı.

```text
EVENT 1856 | school_started | {"actor_id":"player"}
EVENT 1864 | school_completed | {"actor_id":"player"}
EVENT 1867 | occupation_started | {"actor_id":"player","occupation_id":"sewing_worker"}
EVENT 1878 | actor_died | {"actor_id":"parent_2","cause":"baseline"}
EVENT 1892 | condition_acquired | {"actor_id":"player","condition_id":"chronic_disease"}
EVENT 1901 | actor_died | {"actor_id":"player","cause":"chronic_disease"}
EVENT 1901 | life_ended | {"player_id":"player"}
```

### Seed 42 (Yaşam Süresi: 83 Yıl, 1850–1933)
- **Eğitim**: 1856'da okula başladı, 1864'te tamamladı (Okuryazarlık: 80).
- **Kariyer**: 1866'da `sewing_worker` olarak işe başladı.
- **Sağlık & Ölüm**: 1852'de salgın hastalık geçirdi (iyileşti). 1896'da `parent_2`, 1906'da `parent_1` vefat etti. 1933 yılında 83 yaşında temel yaşlılık riskiyle (`baseline`) vefat etti.
- **Ekonomi**: 66.213 birikim, 0 borç, 21 bütçe açığı yılı, 0 gıda güvensizliği yılı.

```text
EVENT 1852 | condition_acquired | {"actor_id":"player","condition_id":"epidemic_disease"}
EVENT 1856 | school_started | {"actor_id":"player"}
EVENT 1864 | school_completed | {"actor_id":"player"}
EVENT 1866 | occupation_started | {"actor_id":"player","occupation_id":"sewing_worker"}
EVENT 1896 | actor_died | {"actor_id":"parent_2","cause":"baseline"}
EVENT 1906 | actor_died | {"actor_id":"parent_1","cause":"baseline"}
EVENT 1933 | actor_died | {"actor_id":"player","cause":"baseline"}
EVENT 1933 | life_ended | {"player_id":"player"}
```

### Seed 99 (Yaşam Süresi: 61 Yıl, 1850–1911)
- **Eğitim**: 1856'da okula başladı, 1864'te tamamladı (Okuryazarlık: 80).
- **Kariyer**: 1867'de `textile_worker` (dokuma işçisi) olarak işe başladı.
- **Hane Tepkisi**: 1855'te ebeveynin hastalığı sonucu oluşan açıkta hane `seek_aid` (yardım talebi) seçti ve 1856'da dış destek aldı.
- **Sağlık & Ölüm**: 1877 ve 1910 yıllarında iş kazası (`workplace_injury`) geçirdi. 1911 yılında 61 yaşında iş kazası komplikasyonuyla vefat etti.
- **Ekonomi**: 71.661 birikim, 0 borç, 7 bütçe açığı yılı, 0 gıda güvensizliği yılı.

```text
EVENT 1855 | condition_acquired | {"actor_id":"parent_1","condition_id":"epidemic_disease"}
EVENT 1855 | household_response | {"selected":{"id":"seek_aid","type":"aid"}}
EVENT 1856 | school_started | {"actor_id":"player"}
EVENT 1864 | school_completed | {"actor_id":"player"}
EVENT 1867 | occupation_started | {"actor_id":"player","occupation_id":"textile_worker"}
EVENT 1907 | actor_died | {"actor_id":"parent_1","cause":"baseline"}
EVENT 1910 | condition_acquired | {"actor_id":"player","condition_id":"workplace_injury"}
EVENT 1911 | actor_died | {"actor_id":"player","cause":"workplace_injury"}
EVENT 1911 | life_ended | {"player_id":"player"}
```

---

## 2. Phase 0B 100 Tohumluk Grup (Cohort) Dağılım İstatistikleri

100 farklı tohum (Seed 0–99) üzerinden yürütülen tam yaşam simülasyonunun toplu sonuçları:

- **Koşu Sayısı**: 100
- **Tamamlanma Oranı**: %100 (`completed` — 100 aktörün tamamı 120 yıllık güvenlik sınırına takılmadan doğal mortaliteyle hayatını tamamladı).
- **Ölüm Yaşı Dağılımı**:
  - En Düşük Yaş: 1 (bebeklik ölümü)
  - En Yüksek Yaş: 95
  - Ortalama Yaş: 52.5
- **Ölüm Nedenleri**:
  - `baseline` (yaşa bağlı genel yıpranma/doğal): 66
  - `chronic_disease` (kronik hastalık): 18
  - `epidemic_disease` (salgın hastalık): 8
  - `malnutrition` (yetersiz beslenme): 6
  - `workplace_injury` (iş kazası): 2
- **Eğitim Durumu**:
  - `completed` (eğitimi tamamlayan): 62
  - `interrupted` (çocuk işçiliği vb. nedenlerle kesilen): 26
  - `none` (okul çağı öncesi 0–5 yaş ölümü): 9
  - `basic_schooling` (okul çağında vefat eden): 3
- **Ekonomik Baskı Ortalamaları**:
  - Ortalama Bütçe Açığı Olan Yıl Sayısı: 20.8 yıl (Maks: 74)
  - Ortalama Gıda Güvensizliği Yaşanan Yıl Sayısı: 5.9 yıl (Maks: 63)

---

## 3. Tarihsel Referans: Phase 0A Ekonomik Şok Çıktıları

Phase 0A tesliminde doğrulanmış 12 yıllık sabit ekonomik şok (1858'de `parent_1` iş kaybı) deney çıktısı:

```text
# Seed 7
1857 earned 6409 needs 4891 savings 8216 debt    0 unmet   0 food 1000
1858 earned 4514 needs 4623 savings 8107 debt    0 unmet   0 food 1000
1859 earned 2325 needs 4815 savings 5617 debt    0 unmet   0 food 1000
1860 earned 2178 needs 4535 savings 3260 debt    0 unmet   0 food 1000
1861 earned 2032 needs 4633 savings  659 debt    0 unmet   0 food 1000
1862 earned 1877 needs 4594 savings    0 debt 1800 unmet 258 food 1000

# Seed 42
1857 earned 4829 needs 4789 savings 5129 debt    0 unmet    0 food 1000
1858 earned 3338 needs 4451 savings 4016 debt    0 unmet    0 food 1000
1859 earned 1675 needs 4347 savings 1344 debt    0 unmet    0 food 1000
1860 earned 1603 needs 4145 savings    0 debt 1198 unmet    0 food 1000
1861 earned 1605 needs 4080 savings    0 debt 1800 unmet 1896 food  521
1862 earned 1670 needs 4080 savings    0 debt 1836 unmet 2410 food  274

# Seed 99
1857 earned 5029 needs 4836 savings 2163 debt    0 unmet    0 food 1000
1858 earned 3657 needs 5127 savings  693 debt    0 unmet    0 food 1000
1859 earned 1904 needs 5439 savings    0 debt 1800 unmet 1042 food  958
1860 earned 1996 needs 5374 savings    0 debt 1836 unmet 3378 food  265
1861 earned 2167 needs 5049 savings    0 debt 1872 unmet 2882 food  349
1862 earned 2239 needs 5086 savings    0 debt 1909 unmet 2847 food  369
```
