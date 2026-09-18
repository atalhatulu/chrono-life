# Birikim artışı incelemesi — 18 Eylül 2026

> Bu rapor eski aile prototipinin ölçümüdür. Sonraki geliştirmelerde bağımsız
> haneler, kişisel para ve meslek yaş sınırları eklendi. Güncel bulgular ve para
> aktarımı düzeltmeleri için [entegrasyon raporuna](INTEGRATION_REVIEW.md) bakın.

Kullanıcı arayüzde altı haneli birikimler gördü. İnceleme, çalışma klasöründeki
aile sistemi açık Manchester test paketiyle yapıldı. Tutarlar `test_credit`;
tarihsel sterlin veya bugünkü satın alma gücü olarak yorumlanmamalıdır.

## Tekrar üretim

```bash
godot --headless --path . --script cli/simulate.gd -- --seed 42 --life --output artifacts/balance_seed42.json
godot --headless --path . --script cli/simulate.gd -- --seed 0 --count 20 --life --output artifacts/balance_cohort20.json
```

Politika: `heuristic_v1`. Arayüzde farklı seçimler farklı tutarlar üretir.

| Seed 42 yılı | Yaş | Yıllık kazanılan gelir | Planlanan ihtiyaç | Yıl sonu birikim |
|---|---:|---:|---:|---:|
| 1875 | 25 | 7.553 | 6.280 | 16.693 |
| 1900 | 50 | 13.108 | 11.304 | 42.697 |
| 1913 | 63 | 11.948 | 7.170 | 104.736 |
| 1933 | 83 | 10.481 | 7.337 | 210.933 |

Seed 42'nin bütün yıllık hesaplarında nakit korunum eşitliği sağlandı.
0–19 başlangıç sayılı 20 hayatın 7'sinde son birikim en az 100.000;
en yüksek değer 285.722, medyan 14.211. Örneklem erken ölümleri de içerir;
bu oran tüm oyuncular için bir tahmin değildir.

## Kaynaklar ve yorum

- `household_system.gd`, hanedeki herkesin kazancını aynı bütçeye ekliyor.
- Yetişkin çocukların evden ayrılması henüz yok. Seed 42'nin sonunda 48–59
  yaşlarında dört çocuk hâlâ aynı hanede gelir getiriyor.
- Kira hane başına sabit 1.100. Gıda ve temel ihtiyaçlar kişi sayısıyla artıyor,
  ancak ayrı evler ve onların kira giderleri oluşmuyor.
- Test paketindeki yetişkin işlerinin üst yaş sınırı 200; emeklilik mekanizması yok.
- Ücret ve gıda endeksleri sınırlı aralıkta oynuyor; kapsamlı tarihsel fiyat,
  yaşam standardı harcamaları veya varlık ekonomisi henüz modellenmiyor.

Sonuç: incelenen koşuda arayüzde yanlış değer okuma veya yıllık hesapta para
çoğaltma bulgusu yok. Uzun ömürlü ve çok çalışanlı hanede kalıcı fazla birikiyor.
Bu davranış mevcut kurallarla açıklanıyor, ancak dengelenmiş bir yaşam ekonomisi
olarak kabul edilmemeli. Bu teslimde ekonomik kurallar değiştirilmedi.

## Sonraki ekonomi işi

Önce kişisel para ile hane kasasının sahipliğini, yetişkinlerin ayrı hane kurmasını
ve birlikte yaşarken bütçeye ne kadar katkı verdiğini tanımla. Ardından konut,
yaşlılıkta çalışma kapasitesi ve yaşam standardı giderlerini birlikte dengele.
Başarıyı yalnız nominal rakamla değil, yıllık giderin kaç katı rezerv oluştuğu ve
farklı hayatlarda yoksulluk/birikim dağılımıyla ölç. Sırf sayıyı küçültmek için
gösterimi bölmek veya açıklamasız bir birikim tavanı koymak kök nedeni çözmez.
