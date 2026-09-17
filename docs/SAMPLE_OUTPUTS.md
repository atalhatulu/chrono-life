# Phase 0A örnek çıktıları

Bu dosya gerçek çalıştırmalardan alınan ekonomik deney çıktılarıdır; tamamlanmış hayat hikâyeleri değildir. Başlangıç 1850, bitiş 1862; `parent_1` için 1858 yılında `worked_permille=500` iş kaybı uygulanmıştır.

Tekrar üretmek için seed yerine 7, 42 veya 99 yazın:

```bash
godot --headless --path . --script cli/simulate.gd -- --seed 42 --years 12 --shock-year 1858
```

`earned`: o yıl kazanılan para. `needs`: planlanan ihtiyaç. `unmet`: karşılanamayan ihtiyaç. `food`: gıda finansmanı, 1000 tam karşılanma. Tüm paralar araştırılmamış test birimleridir.

## Seed 7

```text
1857 earned 6409 needs 4891 savings 8216 debt    0 unmet   0 food 1000
1858 earned 4514 needs 4623 savings 8107 debt    0 unmet   0 food 1000
1859 earned 2325 needs 4815 savings 5617 debt    0 unmet   0 food 1000
1860 earned 2178 needs 4535 savings 3260 debt    0 unmet   0 food 1000
1861 earned 2032 needs 4633 savings  659 debt    0 unmet   0 food 1000
1862 earned 1877 needs 4594 savings    0 debt 1800 unmet 258 food 1000
```

Önceki birikim, gelir kaybının ardından birkaç yıl tampon oluşturuyor. 1862'de gıda karşılanabilse de diğer zorunlu ihtiyaçların bir kısmı karşılanamıyor.

## Seed 42

```text
1857 earned 4829 needs 4789 savings 5129 debt    0 unmet    0 food 1000
1858 earned 3338 needs 4451 savings 4016 debt    0 unmet    0 food 1000
1859 earned 1675 needs 4347 savings 1344 debt    0 unmet    0 food 1000
1860 earned 1603 needs 4145 savings    0 debt 1198 unmet    0 food 1000
1861 earned 1605 needs 4080 savings    0 debt 1800 unmet 1896 food  521
1862 earned 1670 needs 4080 savings    0 debt 1836 unmet 2410 food  274
```

İş kaybı → düşük gelir → birikimin tüketilmesi → borç → gıda açığı. Aynı seed ile iş kaybı verilmediğinde 1862 birikimi 7141 ve borcu 0.

## Seed 99

```text
1857 earned 5029 needs 4836 savings 2163 debt    0 unmet    0 food 1000
1858 earned 3657 needs 5127 savings  693 debt    0 unmet    0 food 1000
1859 earned 1904 needs 5439 savings    0 debt 1800 unmet 1042 food  958
1860 earned 1996 needs 5374 savings    0 debt 1836 unmet 3378 food  265
1861 earned 2167 needs 5049 savings    0 debt 1872 unmet 2882 food  349
1862 earned 2239 needs 5086 savings    0 debt 1909 unmet 2847 food  369
```

Daha az birikim ve daha pahalı ihtiyaçlar nedeniyle gıda açığı daha erken başlıyor. İleride aile davranışları ve yeni iş imkanları bu yola müdahale edebilecek; bu teslimde mevcut yollar sabit muhasebe tepkileriyle sınırlı.
