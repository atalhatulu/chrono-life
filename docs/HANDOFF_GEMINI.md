# ChronoLife — Gemini için geliştirme devir raporu

Tarih: 17 Eylül 2026. Devreden: Astra/Codex.

## 1. Önce bunu bil

Kullanıcı geliştirmeye devam edilmesini istedi; çalışma sırasında oturum limiti nedeniyle durdurup devamını Gemini'ye devretmeye karar verdi. Yeni özellik geliştirmeyi burada durdurduk.

**Phase 0A commit edilip GitHub'a push edildi. Phase 0B kodu yerelde yazıldı ve testlerden geçti, fakat teslim dokümanları henüz güncellenmedi; Phase 0B commit/push edilmedi.**

GitHub'dan yalnızca clone yaparsan son yerel çalışmayı alamazsın. Aynı makinede aşağıdaki proje klasörünü kullan. Başka ortamdaysan bu raporla birlikte hazırlanan `ChronoLife_Gemini_Source_0B_WIP.zip` paketini al. Paket motor binary'sini, `.git` geçmişini, `.godot` önbelleğini ve büyük `artifacts` dosyalarını içermez; uzak depodaki 0A'nın üzerine yerel kaynak değişikliklerini taşımak içindir.

## 2. Proje, ortam ve kullanıcı kararları

- Yerel proje: `/home/teha/Documents/GitHub/Godot/chrono-life`.
- GitHub: https://github.com/atalhatulu/chrono-life
- Remote: `git@github.com:atalhatulu/chrono-life.git`.
- Dal: `main`.
- Son commit: `ac916a3` — `feat: add Phase 0A headless household simulation`.
- Motor: **Godot 4.7.2 Standard**, GDScript. Çalışan ortam: `4.7.2.stable.arch_linux.ed1daf0bf`, Linux x86_64/CachyOS.
- `.godot-version` ve Makefile hedef sürümü kontrol eder.
- HTML/TypeScript alternatifi konuşuldu, **seçilmedi**. Motor tartışmasını tekrar açma; Godot ile devam et.
- Kullanıcı geliştirme boyunca anlamlı teslimlerde **commit + push** yapılmasını açıkça istedi.
- Kullanıcı terminalden tek tek test etmek istemiyor; ajanın kodu çalıştırmasını ve test etmesini bekliyor.
- Şu anda oyun arayüzü ve başlangıç sahnesi yok. F5 ile oynanabilir oyun açılmaz; headless giriş noktaları kullanılır.
- Yeni çalışma başlatırken varsa güncel `AGENTS.md` talimatlarını kontrol et. İnceleme sırasında bu proje için uygulanacak bir AGENTS.md bulunmadı.
- Önceki `/home/teha/Documents/GitHub/chronolife` geçici klasörü kaldırıldı. Doğru konum yukarıdaki `Godot/chrono-life` yoludur.

## 3. Oyunun kimliği ve değiştirilmeyecek yön

ChronoLife, tarihsel koşullarda **tek bir insanın doğumdan ölüme yaşamını** simüle eder. Oyuncu ülke, şehir veya hanedan yönetmez. Ölüm koşuyu bitirir; çocuğa geçerek devam etme yoktur. İlerleme `+1 Yıl` üzerinden yapılır.

Ana fikir: dünya koşulları → aile ekonomisi → karakterlerin seçenekleri → nedensel sonuçlar → oyuncuya sunulan anlamlı kararlar. Hikâye bütünüyle rastgele açılır pencerelerden oluşmamalı. “Baba ölür → çocuk kesin fabrikaya gider” gibi sabit zincir kurulmaz.

Önemli kurallar:

- Simülasyon arayüzden bağımsız, deterministik ve test edilebilir olacak.
- Aktörler Node/Node2D/Node3D değil, veri nesneleri. Aktör başına `_process()` yok.
- Tarihsel tanımlar mümkün olduğunca veriyle ifade edilecek.
- Sert/mekanik sonuçlar ile davranışsal seçimler ayrı sistemlerdir.
- Çalışma sırasında LLM çağrısı, mod API'si, hanedan, tüm dönemler, ayrıntılı kurum/suç/genetik sistemleri eklenmeyecek.
- Önce küçük Manchester teknik ortamı. Veriler **tarihsel olarak kalibre değil**; para birimi `test_credit`.
- Tam Phase 0 doğrulanınca küçük oynanabilir UI'ya geçilecek; yüzlerce içerik kaydı beklenmeyecek.

Ana tasarım belgesi: `docs/ChronoLife_Master_Plan_v0.2.md`. Tamamını oku; özellikle 8–13, 18–22, 43–56, 63–66. Dosyadaki 4.7.1 hedefi sonraki kullanıcı görüşmesinde 4.7.2 olarak güncellendi.

## 4. Tamamlanmış 0A ve yeni 0B arasındaki fark

0A'da tek hane, üç aktör, yıllık gelir/gider, birikim, borç/faiz, gıda açığı, dışarıdan verilen iş kaybı, deterministik RNG, işlem kaydı ve toplu ekonomik koşular vardı. 0A raporu `PHASE_0_REPORT.md` içinde tarihsel teslim kaydı olarak duruyor.

0B'nin **mevcut yerel kodunda** eklenenler:

1. Aktör sağlığı, constitution/willpower, traits, genetic_seed, çalışma kapasitesi, koşullar, eğitim ve okuryazarlık alanları.
2. Veriyle tanımlı dört sağlık koşulu: malnutrition, epidemic_disease, chronic_disease, workplace_injury.
3. Koşul edinme, süreli iyileşme, kronik devamlılık, beslenme etkisi, çalışma kapasitesi ve ölüm riski.
4. Yaş bantlarına göre temel ölüm riski ve deterministik ölüm nedeni seçimi.
5. Ölümde aktif gelir/mesleğin bitmesi; yıl içinde önceden kazanılmış ücretin korunması; tüketimin yıl içi orana göre azaltılması.
6. Ölüm yaşının sabitlenmesi, tekrar ölümün engellenmesi, oyuncu ölümünde koşunun durması.
7. Okula başlama, okuryazarlık ilerlemesi, tamamlanma, işe girince eğitimin kesilmesi.
8. Yetişkinin iş bulması/yeniden işe girmesi; yaş sınırı aşılınca çocuk işinden çıkması.
9. Hane baskısı altında ağırlıklı seçim: bekleme, yetişkin işi, uygun yaşta çocuk işi, sınırlı yardım talebi.
10. İş/yardım kararının gelecek yıla ertelenmesi; artık uygun olmayan iş etkisinin iptali.
11. Ebeveynler kaybedildiğinde çocuğu hane yöneticisi yapmayan basit kurumsal bakım/yardım varsayımı.
12. Dünya hastalık ve istihdam baskısı değişkenleri.
13. `simulate_life(seed)` ve ölüm/yaş/eğitim bilgili basit `life_result`.
14. CLI `--life` ve `--shock-type job_lost|actor_died` seçenekleri.

**Bunlar yeni kodun kapsamıdır; tam Phase 0 bitti demek değildir.** Storylet sistemi ve oyuncu/bot karar arayüzü hâlâ yok.

## 5. Değişen dosyalar

Yeni, henüz takip edilmeyen kaynaklar:

- `simulation/health_system.gd`
- `simulation/career_education_system.gd`
- `simulation/household_response_system.gd`
- `simulation/consequence_engine.gd`
- `tests/run_life_tests.gd`
- Yukarıdaki scriptler için oluşmuş `.uid` dosyaları; editör kalan UID'leri de üretebilir.
- Bu devir raporu: `docs/HANDOFF_GEMINI.md`.

Değişmiş takip edilen dosyalar:

- `simulation/simulation_runner.gd`: 0B sürümü, yeni durum, yıllık işlem ve yaşam sonucu.
- `simulation/household_system.gd`: dış yardım geliri ve ölüm yılındaki tüketim payı.
- `simulation/content_registry.gd`: yeni içerik alanlarını doğrulama.
- `simulation/deterministic_rng.gd`: deterministik ağırlıklı seçim.
- `content/manchester_test.json`: 0B içerik sürümü, sistem anahtarları, sağlık/eğitim/aile verileri, 120 yıllık güvenlik sınırı.
- `cli/simulate.gd`: yaşam modu, ölüm şoku, olay ve yaşam özetleri.
- `tests/run_tests.gd`: 0A ekonomik regresyonları için sağlık/eğitim/adaptasyon kapalı fixture; 30 yıllık fixture sınırı korunuyor.
- `Makefile`: yeni yaşam test paketi, `make life`, yaşam temelli `make batch`.

Henüz yenilenmeyen belgeler: `README.md`, `PHASE_0_REPORT.md`, `docs/SAMPLE_OUTPUTS.md`. Bunlar 0A'yı anlatıyor; yeni durumla çelişen ifadeleri teslimden önce düzelt. `docs/PHASE_0A_DECISIONS.md` eski teslimin tarihsel karar belgesi olarak korunabilir; yeni 0B kararları ayrı yazılabilir.

## 6. Yıllık işlem ve veri sözleşmesi

Mevcut sıra:

1. Giriş durumunu ve komutları doğrula; bitmiş koşuyu tekrar ilerletme.
2. `YearDelta` ile derin çalışma kopyası al, yıl/dünya koşullarını ilerlet.
3. Yaşayan aktörlerin yaşını ilerlet; ölülerin yaşı sabit kalır.
4. Geçen yıldan gelen iş/yardım etkilerini uygula; yetişkin istihdamını değerlendir.
5. Sağlık koşulları ve ölüm adaylarını hesapla.
6. Mevcut meslek/çalışma kapasitesinden yıllık ücret hesapla.
7. İş kaybı ve ölümün sert sonuçlarını sınırlı, tekrarları ayıklayan kuyrukta uygula.
8. Yaşayan aktörlerin eğitimini ilerlet; bakım durumunu ve varsa yetim desteğini belirle.
9. Gerçekleşen gelir/tüketim üzerinden muhasebeyi kapat.
10. Oyuncu öldüyse yaşamı bitir; aksi halde hane tepkisini seçip gelecek yıla planla.
11. Değişmezleri doğrula ve tek seferde commit et.

Hatalı işlem giriş durumunu değiştirmez. Yayılım sınırı aşılırsa teşhis olayları döner, yeni kalıcı durum dönmez.

Aktif yıllık gelir ile gerçekleşmiş yıl kazancı farklıdır. Aynı yıl iş kaybı ve ölüm varsa gelir payları birbiriyle çarpılmaz; en erken kesilme zamanı kullanılır. Ölümde o yıl yaşanan kısım kadar gıda/kişisel zorunlu tüketim hesaplanır. Kira hane o yıl herhangi bir süre yaşadıysa tam yıllıktır.

`member_ids` aile kimliklerini, ölüler dahil, korur. Aktif ücret, yaş ilerlemesi, sağlık/iş/eğitim işlemleri yaşayanlar üzerinden yürür. Ölüler aile ağacından silinmez.

Yardım geliri `external_income`, ücretler `earned_income`, toplamı `available_income` alanındadır. Nakit ve borç mutabakatları ayrı kontrol edilir.

Başlangıç yılı 1850, ilk aralık 1850→1851. İlk aralıkta bebeklik ölüm riski değerlendirilir; tam sayı yaş ve yıl sonu tarihleme nedeniyle o aralıktaki ölüm sonuçta yaş 1 olarak görünür. Ay/gün ve tam neonatal yaş modeli yok; bunu belgede açıkla.

RNG anahtarı seed/sistem/yıl/aktör/çekiliş adıdır. Tekrar üretilebilirlik kod, içerik özeti, komutlar ve Godot sürümüne bağlıdır. Motor/platformlar arası eşitlik iddiası yok.

## 7. Gerçekten çalıştırılan kontroller

Son `make test` işlemi tamamlandı ve **exit code 0** döndü.

- Ekonomik regresyon paketi: **56 kontrol, 0 hata**.
- Yeni yaşam paketi: **55 kontrol, 0 hata**.
- Toplam: **111 kontrol**.
- Yaşam testlerinin içinde 100 seed üzerinde tam yaşam koşuları, muhasebe değişmezleri, tek ölüm, nedensel olay bağlantıları ve sonuç çeşitliliği kontrolleri bulunuyor.
- Test, bu örnek grubunda 90'dan fazla yaşamın doğal olarak tamamlandığını doğruluyor. Tam dağılım/metrik raporu henüz üretilmedi; “100'ünün de öldüğü ölçüldü” diye varsayma.
- Devir öncesi `git diff --check` temizdi.

Ayrıca çalıştırılan komut:

```bash
godot --headless --path . --script cli/simulate.gd -- --seed 42 --life --output artifacts/phase0b_seed42.json
```

Sonuç: başarılı, 83 yıllık koşu, oyuncu 1933'te 83 yaşında öldü. `cause_of_death`/özet etiketi `baseline`; bu araştırılmış tıbbi bir tanı değil modelin temel ölüm riski etiketidir. Temel eğitim tamamlandı, okuryazarlık 80. Yaklaşık çekirdek/özet süresi 329 ms; evrensel performans ölçütü değildir.

Örnek önemli olaylar:

- 1856: temel okula başlangıç.
- 1859: ebeveynin iş kazası koşulu.
- 1864: temel eğitimin tamamlanması.
- 1866: oyuncunun sewing_worker işine başlaması.
- 1896: parent_2 ölümü.
- 1906: parent_1 ölümü.
- 1933: oyuncu ölümü ve koşu sonu.

Ham JSON yerelde `artifacts/phase0b_seed42.json` altında; `.gitignore` nedeniyle GitHub'da ve kaynak ZIP'inde yok. Komutla yeniden üretilebilir.

Yeni CLI seçeneklerinin tüm hata durumları, yeni bir temiz-kopya denemesi, son değişikliklerin editor import kontrolü ve 0B dağılım/performance raporu **henüz tamamlanmadı**. 0A'daki 11 CLI hata testi geçmiş teslimin kanıtıdır; 0B için otomatik olarak geçerli sayma.

## 8. Kod incelemesinde öncelikle bakılacak noktalar

Aşağıdakiler testlerde görülmüş kesin hatalar olarak sunulmuyor; teslim öncesi gözden geçirilmesi gereken somut riskler/eksiklerdir:

1. **Yeni içerik doğrulayıcısının hatalı tip güvenliği.** `_validate_life` bazı alanları `_check_range` ile kontrol ettikten sonra hata birikmiş olsa da alanlar arasında karşılaştırma yapıyor. Örneğin yaş/aralık/weight alanına string konursa runtime karşılaştırma hatası çıkabilir. Hatalı veri sessizce veya motor script hatasıyla değil açık doğrulama sonucu ile reddedilmeli; ilgili testleri ekle.
2. **Gelir değişiminin nedensel açıklaması.** Çalışma kapasitesi sağlık nedeniyle düşüyor; runner'ın `income` alan güncellemesi hâlâ `world_event` üzerinden kaydediliyor. Sağlık/meslek değişikliği ile ücret kaydı arasındaki neden bağlantısını güçlendir; dünya fiyat etkisini de koru.
3. **Takvimlenmiş senaryo doğrulaması.** `simulate_years` takvim anahtarlarını başlangıçta, komutların içeriklerini ilgili yıla gelince doğruluyor. Oyuncu erken ölürse sonraki komut incelenmeyebilir. Genel API'nin geçersiz senaryoları nasıl raporlayacağı açık olmalı. CLI aktör ve oranı önceden kontrol ediyor. `skip_if_unavailable` alanının boolean tipini de gözden geçir.
4. **Erteleme/ölüm çakışmaları.** Şu an gelecek yıl işine başlama, sağlık ve o yıl ölümü öncesinde uygulanıyor. Basit yıllık model için başlangıç işi/yarıyıl ölüm varsayımı makul; bu varsayımı açıkla ve artık uygun olmayan/dead aktörün bekleyen işinin iptalini ayrıca test et.
5. **Eğitim geri dönüşü.** Kesilmiş eğitim otomatik yeniden başlamıyor; yalnızca `none` durumundan okula kayıt var. Bu davranışı bilerek koru veya küçük ve açık bir kuralla değiştir; geniş eğitim sistemi açma.
6. **Ekonomik denge.** Seed 42 yüksek birikimle bitiyor; emeklilik, evden ayrılma, yeni hane ve evlilik yok. Bu küçük test hane modeli bütün hayatı aynı hanede geçiriyor. Genişleterek çözmeye çalışma; denge eksikliğini dürüstçe raporla. Okuryazarlık henüz farklı ücretli iş kapısı açmıyor, çünkü mevcut işlerin minimum literacy değeri sıfır.
7. **Tarihsel kapsam.** Dünya yılları 1900'ü geçiyor ama gerçek tarihsel olay/law değişimleri yok. Bu bir teknik sandbox; tarihsel Manchester hayatı tamamlandı diye sunma. 120 yıllık emniyet sınırına ulaşan yaşam `year_limit` olur; ölüm uydurulmaz.
8. **State validation kapsamı.** Doğrulayıcı iç durum sözleşmesi içindir, rastgele dış JSON kayıtlarını güvenli parse eden save/load katmanı değildir. Yeni pending effect, condition ve guardian alanlarında gerekli iç değişmezleri gözden geçir; gereksiz genel şema motoru ekleme.

## 9. Gemini'nin sıradaki işi — önce 0B'yi teslim et

1. Bu raporu, ana planı ve mevcut kodu oku. `git status` ile yerel 0B değişikliklerini koruduğunu doğrula; reset/clean ile kaybetme.
2. `make test` çalıştır. Hata varsa önce düzelt; daha fazla özellik ekleyerek üstünü örtme.
3. Yukarıdaki somut riskleri incele; gerekli küçük düzeltme ve davranış testlerini yap. Testleri geçmesi için gerçek değişmezleri zayıflatma.
4. Seed 7/42/99 için tam hayat çıktıları ve 100 seed'lik özet al. Ölüm yaşları, nedenler, okul kesintileri, çocuk emeği, yardım ve bütçe açıklarının temel metriklerini raporla. Tarihsel kalibrasyon iddiasında bulunma.
5. CLI `--life`, `--years`, `--shock-type`, geçersiz aktör/oran ve erken ölüm yüzünden artık uygulanamayan şok gibi durumları kontrol et.
6. README ve `PHASE_0_REPORT.md` dosyalarını son durum etrafında yeniden yaz/güncelle. 0A örneklerini eski sürüme ait diye etiketle veya yeni örneklerle değiştir. Yeni kararları belgeye geçir.
7. `git diff --check`, Godot parse/import ve ilgili testler tamamlanınca **0B'yi commit edip `origin main` dalına push et**. Kullanıcı bu akışı önceden yetkilendirdi. Testleri geçmeyen veya kapsamı belirsiz kodu tamamlanmış teslim diye push etme.
8. Kullanıcıya ne değiştiğini, testleri, kalan sınırları ve commit bağlantısını kısa biçimde bildir.

## 10. 0B'den sonra — 0C, ardından küçük oynanabilir ekran

0C'nin amacı aynı simülasyona anlamlı karar katmanı bağlamak:

- En fazla 5–10 veri tabanlı storylet.
- Uygunluk filtreleri, bağlamsal utility, bekleme süresi/olay ailesi sınırları ve deterministik ağırlıklı seçim.
- Sakin yılların geçerli olması; her yıl zorunlu felaket yok.
- Simülasyonda gerçekleşen kazayı storylet'in tekrar uygulayıp çifte hasar yaratmaması.
- Açık karar talebi ve cevap sözleşmesi; headless koşular için sürümlenmiş bot politikası.
- Çocuklukta karar yetkisinin sınırlı olması; ebeveyn kararı ile oyuncunun tepkisinin ayrılması.
- Anlık seçim sonuçlarının commit öncesi sert sonuçlardan geçmesi; uzun vadeli etkilerin açıkça sonraki yıla ertelenmesi.
- Aynı seed + aynı politika/kararlar + aynı sürümlerde tekrarın kanıtlanması.
- Ana planın Phase 0 başarı ölçütlerinin tamamının tek tek değerlendirilmesi.

Bunlar doğrulanınca Godot Control tabanlı minimal ekran: kişi/yıl/yaş, aile bütçesi, olay çizelgesi, karar kartı ve `+1 Yıl`. UI simülasyon mantığını içermemeli. İlk oynanabilir test için evlilik, çok sayıda meslek, suç ve ikinci tarihsel dönemi bekleme.

## 11. Komutlar ve erişim notu

```bash
cd /home/teha/Documents/GitHub/Godot/chrono-life
git status --short --branch
make test
make life
make batch
godot --headless --path . --script cli/simulate.gd -- --seed 7 --life
godot --headless --path . --script cli/simulate.gd -- --seed 42 --years 20 --shock-year 1858 --shock-type actor_died
```

Bu oturumda sandbox içinden SSH, `/etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf` izin hatası verdi. İzinli/sandbox dışı `git ls-remote` ve `git push` çalıştı. Headless editör importu da sandbox içinde yerel soket açma hatası vermişti; izinli tekrar temizdi. Gemini ortamında aynı kısıt varsa yetkili normal erişim yolunu kullan; SSH ayarlarını veya sistem izinlerini keyfî değiştirme.

## Gemini'ye doğrudan verilebilecek görev

> Bu raporu ve ChronoLife kaynaklarını okuyup yereldeki Phase 0B çalışmasını devral. Godot 4.7.2/GDScript yönünü koru. Önce mevcut değişiklikleri ve testleri doğrula, raporun 8. bölümündeki somut riskleri değerlendir, gerekli düzeltmeleri yap ve belgeleri güncelle. 0B tamamlanınca testleri geçen değişiklikleri commit edip kullanıcının mevcut GitHub reposuna push et. Daha sonra 0C storylet/karar katmanına küçük kapsamla ilerle. Büyük yeni sistemler veya UI'yı çekirdekten önce ekleme. Kullanıcının kodu kendisinin test etmesine güvenme; çalıştırma ve doğrulamayı sen yap.
