# Phase 0C Uygulama Kararlari: Storylet, Karar ve Arayuz Katmani

17 Eylul 2026. Bu belge, ChronoLife projesinin Phase 0C (veri tabanli storylet sistemi, deterministik bot politikalari, sakin yillar, cocukluk iradesi ve minimal Godot Control arayuz prototipi) tesliminin mimari kararlarini, veri sozlesmelerini ve teknik sinirlarini kayit altina alir.

---

## 1. Mimari Kapsam ve Ilkeler

- **Is Mantigindan Tamamen Bagimsiz Salt Sunum Katmani**: Master Plan Bolum 52 geregince, Godot Control dugumleri ve UI scripti (`ui/main_ui.gd`) sifir is mantigi icerir. Tum simulasyon kurallari, hesaplamalar ve durum degisimleri `RefCounted` tabanli simulasyon motoru (`SimulationRunner`, `StoryletEngine`, `HouseholdSystem`, `HealthSystem`) tarafindan yonetilir.
- **Veri Tabanli Storylet Sozlesmesi**: Storylet'ler kod icine gomulmez; icerik paketi (`content/manchester_test.json`) icindeki semantik sozlesme ile tanimlanir. Kosullar, fayda agirliklari ve secenek sonuclari deklaratiftir.
- **Sakin Yillar (Quiet Years)**: Gercek hayatta her yil kriz veya dramatik donum noktasi yasanmaz. Storylet secim motoruna 35 puanlik sabit sakin yil agirligi entegre edilerek, kosullarin sakin gectigi yillarda anlamsiz zorlama olaylarin cikmasi engellenmistir.
- **Cocukluk Iradesi (Childhood Agency)**: Cocuklar pasif nesneler degildir. Fabrikaya gonderilme gibi hayati kararlarda cocuk protesto edebilir; ebeveynin egilimleri (`education_first`) veya cocugun irade gucu (`willpower >= 50`) kararin sonucunu belirler.
- **Cift Asamali Interaktif Pipeline**: Simulasyon adimi `step_prepare` ve `step_resolve` olmak uzere iki asamaya ayrilmistir. Bu sayede UI katmani yil ortasinda tetiklenen karari oyuncuya sunar; oyuncu secim yaptiginda yil atomik olarak sonlandirilir. Ayni zamanda headless modda `step()` fonksiyonu bot politikasiyla kesintisiz tek adimda calisir.

---

## 2. Storylet Veri Sozlesmesi ve Motoru

`content/manchester_test.json` icine 6 ozgun 19. yuzyil storylet'i eklenmistir:
1. `childhood_labor_demand` (Kategori: `education_vs_work`): Fabrika ise alim gorevlisinin gelişi ve cocuk iscilik talebi.
2. `night_reading` (Kategori: `self_improvement`): Mum isiginda kitap okuma ve oz-gelisim (okuryazarlik artisi vs. goz yorgunlugu/saglik kaybi).
3. `overtime_shift` (Kategori: `workplace`): Gece vardiyasi ve fazla mesai (nakit kazanci vs. kaza riski ve saglik kaybi).
4. `pawn_family_heirloom` (Kategori: `emergency_finance`): Nakit darliginda aile yadigarini rehine verme (acil nakit vs. irade kaybi ve bayrak atanmasi).
5. `dispensary_treatment` (Kategori: `health_care`): Salgin veya hastalikta ucretsiz dispansere basvuru.
6. `mutual_aid_subscription` (Kategori: `community`): Dost Yardimlasma Cemiyeti'ne (Friendly Society) uyelik ve aidat.

### Gereksinimler (Requirements)
Storylet'lerin uygunlugu asagidaki filtrelerle denetlenir:
- `min_age`, `max_age`, `player_alive`
- `occupation_id`, `not_occupation`
- `education_states` (ornek: `["basic_schooling", "none"]`)
- `min_health`, `max_literacy`, `min_savings`, `max_savings`
- `not_flag`, `has_flag` (tekrarli olay engeli, ornegin yadigar yalnizca bir kez rehin verilebilir)
- `cooldown_years` (bekleme suresi - son gorulme yilindan itibaren gecmesi gereken asgari sure)

### Baglamsal Fayda (Utility)
Uygun storylet'ler sabit degildir; hanehalkinin o yilki ekonomik durumuna gore dinamik puan alir:
- Butce acigi (`budget_deficit_gt_zero`) -> Cocuk isciligine ve fazla mesaiye ek agirlik (+30).
- Gida guvencesi dusuklugu (`food_security_lt_800`) -> Rehinciye ve ise yonelme agirligi (+30).
- Koruyucunun karakter ozelligi (`guardian_education_first`) -> Cocuk isciligine negatif agirlik (-30).

---

## 3. Bot Karar Politikalari (`BotPolicy`)

Headless testler ve karsilastirmali grup kosulari icin 3 ayri bot karar politikasi surumlenmistir:
1. `heuristic_v1`: Rasyonel/dengeli hane stratejisi. Butce acigi ve tasarruf durumuna gore saglik ile para arasinda denge kurar.
2. `pragmatic`: Kisa vadeli maddi guvence ve nakit odakli politika. Rehinciyi kullanir, fazla mesaiyi kabul eder, dinlenmeyi secer.
3. `education_first`: Uzun vadeli insani sermaye odakli politika. Fabrika calismasina karsi cikar, gece okumasini tercih eder, fazla mesaiyi reddeder.

Ayni tohum (seed) + ayni politika %100 deterministik sonuc verirken; farkli politikalar ayni tohumda anlamli bicimde farkli hayat sonuclari (okuryazarlik, saglik, servet) ve farkli SHA-256 parmak izleri uretmektedir.

---

## 4. Minimal Godot Control Arayuz Prototipi

`scenes/main.tscn` ve `ui/main_ui.gd` dosyalari ile calisir durumdaki arayuz bilesenleri:
- **Karakter Profili Paneli**: Isim, yas, dogum yili, saglik bari, okuryazarlik bari, irade bari, meslek, egitim durumu ve aktif tibbi kosullar.
- **Dunya Kosullari Paneli**: Guncel yil, ekonomi endeksi, gida fiyat endeksi, istihdam ve salgin baskilari.
- **Hanehalki Ekonomisi Paneli**: Aktif gelir, yillik harcamalar, net tasarruf/kasa, borc, gida guvencesi gostergesi ve yasam standardi.
- **Karar Karti (Storylet Decision Card)**: Tetiklenen storylet'in basligi, aciklamasi ve dinamik uretilen secenek butonlari.
- **Zaman Cizelgesi ve Olay Gunlugu**: Yil yil gerceklesen butce, saglik, egitim ve storylet olaylarini renklendirilmis BBCode metniyle listeleyen akis.
- **Etkilesim Kontrolleri**: Seed degistirme, Yeni Hayat baslatma, +1 Yil Ilerletme ve Otomatik Bot Karari gecisi.

---

## 5. Test ve Dogrulama Sonuclari

- `tests/run_tests.gd`: 56 kontrol, 0 hata (Ekonomik ve matematiksel regresyon).
- `tests/run_life_tests.gd`: 74 kontrol, 0 hata (Saglik, olum, nedensellik ve yetimlik).
- `tests/run_storylet_tests.gd`: 31 kontrol, 0 hata (Storylet semasi, uygunluk, bekleme sureleri, cocukluk iradesi, bot ayrisimi ve 100 tohumluk yasam simülasyonu).
- **Genel Toplam**: 161 kontrol, 0 hata.
