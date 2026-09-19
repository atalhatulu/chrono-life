extends RefCounted
## Human-facing wording only; IDs and simulation content stay unchanged.

const NAMES: Dictionary = {
	"dependent": "Henüz bir işi yok", "textile_worker": "Dokuma işçisi",
	"sewing_worker": "Dikiş işçisi", "child_factory_worker": "Fabrika çırağı",
	"skilled_textile_worker": "Nitelikli dokuma işçisi", "mill_overlooker": "Fabrika gözetmeni",
	"clerk": "Kâtip", "bookkeeper": "Muhasebe kâtibi",
	"foundry_apprentice": "Dökümhane çırağı", "iron_moulder": "Demir kalıpçısı",
	"master_machinist": "Usta makinist", "domestic_servant": "Konak hizmetlisi",
	"independent_shopkeeper": "Bağımsız esnaf",
	"elementary": "Temel eğitim", "evening_school": "Akşam eğitimi",
	"precarious": "Kırılgan", "working": "Emekçi", "stable": "Yerleşik",
	"comfortable": "Rahat", "affluent": "Varlıklı", "unknown": "Henüz belirlenmedi",
	"income": "Gelir", "wealth": "Birikim ve varlıklar", "occupation": "Meslek",
	"education": "Eğitim", "housing": "Barınma",
	"household_use": "Aileyle ortak kullanım", "rented": "Kiralık", "owned": "Mülk",
	"discipline": "Disiplin", "sociability": "Sosyallik", "curiosity": "Merak",
	"resilience": "Dayanıklılık", "risk_tolerance": "Risk eğilimi", "empathy": "Empati",
	"drink": "İçecek", "food": "Yiyecek", "health": "Sağlık", "media": "Yayınlar",
	"finance": "Mali işler", "leisure": "Boş zaman", "vice": "Alışkanlıklar",
	"unmarried": "Bekâr", "married": "Evli", "widowed": "Dul", "divorced": "Boşanmış",
	"none": "Henüz başlamadı", "basic_schooling": "Temel eğitim görüyor",
	"interrupted": "Eğitimi yarıda kaldı", "completed": "Temel eğitimi tamamladı",
	"malnutrition": "Yetersiz beslenme", "epidemic_disease": "Salgın hastalık",
	"chronic_disease": "Kronik hastalık", "workplace_injury": "İş kazası",
	"baseline": "Yaşamın doğal riskleri", "scenario": "Beklenmedik bir olay",
	"unassessed": "Yeni bir başlangıç", "basic": "Temel ihtiyaçlar karşılanıyor",
	"poor": "Geçinmek zorlaşıyor", "destitute": "Aile zor günler geçiriyor",
	"education_vs_work": "Eğitim ve geçim", "self_improvement": "Kendine ayırdığın zaman",
	"workplace": "Çalışma hayatı", "emergency_finance": "Zor bir karar",
	"health_care": "Sağlık", "community": "Birlikte yaşamak", "family_life": "Aile hayatı"
}
const STORIES: Dictionary = {
	"childhood_labor_demand": ["Okul mu, fabrika mı?", "Mahalleye gelen bir görevli, dokuma fabrikası için küçük eller arıyor. Evin geçimi zorlaşırken ailen senin de çalışmanı düşünüyor."],
	"night_reading": ["Mum ışığında bir sayfa daha", "Eline, tarih ve hesap dersleriyle dolu yıpranmış bir kitapçık geçti. Uzun bir günün ardından, uyumadan önce kendine ayırabileceğin bir saatin var."],
	"overtime_shift": ["Uzun bir gece vardiyası", "Fabrikaya yeni bir kumaş siparişi geldi. Gece boyunca kalanlara fazladan ücret verilecek; fakat makineler daha hızlı çalışacak."],
	"pawn_family_heirloom": ["Bir saatin hatırası", "Borçlar büyüyor. Rehinci, ailenin son gümüş saatine karşılık hemen para verebilir. Bu saat, evde kalan birkaç hatıradan biri."],
	"dispensary_treatment": ["Dispanserin önündeki sıra", "Gönüllü bir hekim, mahallede küçük bir dispanser açtı. Bekleyenlere bakılıyor ve ilaç dağıtılıyor. Sıraya girmek zaman ve biraz para gerektirecek."],
	"mutual_aid_subscription": ["Yalnız olmak zorunda değilsin", "Mahalledeki işçiler seni yardımlaşma cemiyetine davet ediyor. Küçük katkılar, hastalık ve zor günler için ortak bir sandıkta toplanıyor."],
	"courtship_and_marriage": ["Irwell kıyısında bir yürüyüş", "Birlikte geçirilen ayların ardından, sevdiğin kişi aynı evi paylaşmaktan söz ediyor. Önünüzde, artık beraber yazabileceğiniz bir hayat var."],
	"street_apprentice": ["Sokaklarda bir zanaat", "Mahalledeki demir ustası, ocağın başına alıp yetiştirecek güvenilir bir çırak arıyor. Bu iş hem kuvvet hem sabır ister."],
	"cholera_outbreak_1853": ["Kuyu suyu ve kolera", "1853 yazında mahalle tulumbasından su içenler birer birer yatağa düşüyor. Hekimler tulumba suyunun kaynatılmasını tembihliyor."],
	"cotton_famine_crisis": ["Pamuk kıtlığı ve sessiz tezgahlar", "Limanlara ham pamuk gelmiyor. Manchester dokuma fabrikaları bir bir kapılarına kilit vuruyor; işsizlik kapıda."],
	"tenancy_rent_hike": ["Kira zammı ve dar sokak", "Ev sahibi kapıya dayanıp haftalık kiraya zam istediğini bildirdi. Kabul etmezsen sokakta kalma tehlikesi var."],
	"temperance_pledge": ["Ayıklık Cemiyeti ve meyhane", "Pazar ayininden sonra Ayıklık Cemiyeti üyeleri sokakta broşür dağıtıyor; içkiyi bırakıp cemiyet defterine imza atmanı istiyorlar."],
	"child_marriage_alliance": ["Bir evladın izdivacı", "Yetişkin evladın, mahallenin saygın ailelerinden birinin çocuğuyla evlenmek istiyor. Senden çeyiz ve düğün desteği bekleniyor."],
	"factory_inspector_inquest": ["Krallık müfettişi fabrikada", "Londra'dan gelen fabrika müfettişi, çalışma saatlerini ve korumasız makineleri gizlice soruşturuyor; sana sorular soruyor."],
	"elder_retirement_decision": ["Ağırlaşan dokuma mekiği", "Mekik atarken ellerin titriyor, dizlerin rutubetli fabrika zemininde sızlıyor. Evdekiler artık tezgahı gençlere bırakmanı istiyor."],
	"infant_care_dilemma": ["Beşik ve dokuma tezgahı", "Evin geçimi için annenin pamuk fabrikasına dönmesi gerekiyor. Mahallenin yaşlı kadını birkaç peni karşılığı seni gündüz bakmayı öneriyor; fakat odadaki çocuklara afyon şurubu içirildiği fısıldanıyor."],
	"smallpox_vaccine_visit": ["Dispanserin aşı iğnesi", "Mahalleye gelen bir hekim, çocukları çiçek salgınından korumak için aşı yapıyor. Komşuların bir kısmı hekime şüpheyle bakarken salgın her kış can alıyor."],
	"street_perils_mud": ["Çamur ve demir tekerlekler", "İsli sokaklarda çocuklar ağır yük arabalarının ve kanal mavnalarının arasında koşturuyor. Sen de kapı eşiğinden dar sokaklara adım atıyorsun."],
	"first_hornbook_alphabet": ["Eski bir hece tahtası", "Bir akrabadan kalan yıpranmış tahta hece levhası eline geçiyor. Kömürle kararmış parmaklarınla harflerin şekillerini takip ediyorsun."],
	"mill_retaliation_or_respect": ["Müfettişin ardından gelen fısıltı", "Müfettişin teftiş raporu fabrikaya ulaştı; makinelerin etrafına koruyucu demir parmaklık takıldı. Masraflara öfkelenen ustabaşı, senin konuştuğunu sezip yağ fıçılarının yanında önünü kesiyor."],
	"journeyman_blacksmith_trial": ["Örs başında ustalık imtihanı", "Yıllarca kömür taşıyıp körük çektikten sonra demirci ustası eline ağır çekici tutuşturuyor: 'Lokomotif bağlantı demirini tek başına döv, sana kalfalık beratını vereyim.'"],
	"winter_fever_wave": ["Kış humması ve soğuk yağmurlar", "Dondurucu yağmurlar Manchester sokaklarını çamur deryasına çevirdi. Rutubetli bodrum katlarına sızan kızıl humma ve göğüs hırıltısı mahallede can alıyor."],
	"temperance_benefit_solidarity": ["Ayıklık Cemiyeti dayanışması", "Ayıklık senedine sadık kalıp meyhanelerden uzak durduğun için cemiyet seni yıllık toplantısına davet ediyor; yardımlaşma sandığından pay teklif ediyor."],
	"debt_bailiff_pawn_crisis": ["Tefecinin çekiç sesleri ({debt} şilin borç)", "Evin borcu {debt} şiline dayandı. Alacaklı esnaf ve mahallenin rehin simsarı kapıyı yumrukluyor. Önünüzde sadece iki acı yol var: Ya evdeki son döküm sobayı ve yatakları rehine vereceksiniz, ya da mahkemenin borçlu hapsi celbini bekleyeceksiniz."],
	"famine_bread_ration_dilemma": ["Boşalan un çuvalı", "Kilerde un bitti; {child} açlıktan ağlayarak uykuya dalıyor. Nehir kıyısında geceleyin tahıl mavnalarından dökülen çuvallar var; kilise kapısında ise düşkünler çorbası dağıtılıyor."],
	"overcrowded_cellar_fever": ["Daralan mahzen ve rutubet kokusu", "{dwelling} içinde nefes alacak yer kalmadı. Yerlerde yan yana yatan çocukların öksürükleri birbirine karışıyor. {sibling} göğsünü tutarak rutubet içinde titriyor."],
	"family_care_vs_ambition": ["Ailenin omuzlarına binen yük ({sibling})", "{sibling} fabrikada kaptığı göğüs iltihabı yüzünden yatağa mahkûm oldu. Kendi meslek ve istikbalinden vazgeçip gece gündüz ona bakmanı bekliyorlar."],
	"textile_strike_dilemma": ["Fabrikada grev ve nöbet", "Dokuma fabrikasında işçiler buhar kazanlarını durdurup 12 saatlik ağır vardiyalara karşı greve gitti. Kapıda nöbet tutanlar dayanışma beklerken ustabaşı, içeri girip tezgah başına geçenlere çift yevmiye ve gözetmenlik terfisi teklif ediyor."],
	"foundry_molten_crucible": ["Dökümhanede kızgın pota felaketi", "Döküm çukurunun üzerindeki vinç zinciri koptu; beyaz akkor halindeki erimiş demir makine kalıplarına doğru akıyor. Usta, atölye mahvolmadan önce kum setini çekecek cesur bir el arıyor."],
	"clerk_falsified_ledger": ["Tüccarın gizli defteri", "Sevkiyat defterlerini denkleştirirken patronun gümrük vergisinden kaçırdığı kaçak pamuk balyalarını gizleyen çift defter tuttuğunu fark ettin. Tüccar seni çalışma odasına çağırıp maun masanın üzerine bir tomar banknot koydu."],
	"open_independent_shop": ["Kendi dükkanının efendisi olmak", "Deansgate köşesindeki bakkal devrediliyor; dükkan kirası ve kuru erzak stoğu için nakit aranıyor. Yılların birikimini yatırıp fabrika gürültüsünden kurtulabilir, kendi işinin başına geçebilirsin."]
}
const CHOICES: Dictionary = {
	"comply": ["Fabrikada çalışmayı kabul et", "Okuldan ayrıl ve ailenin gelirine katkıda bulun."],
	"protest_for_school": ["Okulda kalmak için ısrar et", "Ailenin eğitime bakışı ve iraden sonucu etkileyebilir."],
	"errands_contribution": ["Okuldan sonra küçük işler yap", "Eğitimine devam ederken yorgunluğu göze al."],
	"study_diligently": ["Biraz daha oku", "Okuryazarlığını geliştir; dinlenmeye daha az zaman ayır."],
	"rest": ["Mumu söndür ve dinlen", "Yarın için güç topla."],
	"accept_overtime": ["Fazla mesaiye kal", "Ek gelir kazan; yorgunluk ve kaza riskini göze al."],
	"decline_overtime": ["Vardiya sonunda eve dön", "Dinlenmeye ve ailene zaman ayır."],
	"pawn_heirloom": ["Saati rehin ver", "Aile bütçesini rahatlat; bir hatıradan vazgeç."],
	"refuse_pawn": ["Saati ailede tut", "Hatıranı koru; geçim sıkıntısı devam etsin."],
	"seek_cure": ["Muayene için bekle", "Küçük bir ücret karşılığında iyileşme şansı ara."],
	"endure_home": ["Evde dinlen", "Paranı koru ve kendi gücüne güven."],
	"join_society": ["Cemiyete katıl", "Aidat öde ve yardımlaşma sandığına katkı yap."],
	"decline_society": ["Şimdilik katılma", "Birikimini elinde tut."],
	"marry": ["Birlikte bir hayat kur", "Evlen ve aynı haneyi paylaşmaya başla."],
	"remain_single": ["Biraz daha bekle", "Yeni sorumlulukları daha sonraya bırak."],
	"take_apprenticeship": ["Ocağın başına geç", "Demirci çıraklığını kabul et; ellerin nasır tutsun ama bir meslek öğren."],
	"stay_free": ["Okulda ve sokakta kal", "Ağır demir işinden kaçın; bağımsız kalmayı seç."],
	"boil_and_cleanse": ["Suyu kaynat ve evi temizle", "Kömüre ve temiz suya birkaç kuruş harca; aileni salgından koru."],
	"drink_and_pray": ["Olduğu gibi iç ve kadere güven", "Masraftan kaçın; tulumba suyunu kullanmaya devam et."],
	"soup_kitchen_relief": ["Aşevi kuyruğuna gir", "Yardım ekmeğini kabul et; gururu bir kenara bırakıp karnını doyur."],
	"dock_odd_jobs": ["Rıhtımda ne iş çıkarsa yap", "Günübirlik hamallık ve ağır işler ara; sağlığını zorlayarak geçin."],
	"pay_rent_hike": ["Zammı öde ve çatını koru", "Bütçeyi daha da kıs; başını sokacak bir evin olsun."],
	"dispute_rent": ["Ev sahibiyle pazarlık et ve diren", "Hakkını ara; anlaşamazsan tahliye edilme riskini göze al."],
	"sign_temperance": ["Ayıklık senedine imza at", "İçkiden ve meyhane masrafından uzak dur; cemiyetin saygısını kazan."],
	"tavern_fellowship": ["İşçi dostlarla kadeh kaldır", "Akşam yorgunluğunu meyhanede dostlarla at; birikiminden biraz harca."],
	"bless_marriage": ["Düğün masrafını karşıla ve kutsa", "Birikiminden fedakarlık yap; ailenin itibarını ve mutluluğunu artır."],
	"urge_frugality": ["Tutumlu olmalarını tembihle", "Düğünü sade tut; bütçeyi riske atma."],
	"speak_truth": ["Hakikati olduğu gibi anlat", "Makinelerin tehlikesini ve uzun saatleri açıkla; işten atılma riskini göze al."],
	"keep_head_down": ["Görmedim, bilmiyorum de", "Patronun kulağına gitmesinden kork; işini ve ekmeğini riske atma."],
	"retire_home": ["Tezgahı bırak ve ocağın başına çekil", "Fabrikadan ayrıl; sağlığını ve huzurunu koruyarak mütevazı bir ömür sür."],
	"labor_to_end": ["Nefesin yettiğince çalış", "Kimseye yük olmamak için son ana kadar dokuma tezgahında kal."],
	"dame_minder": ["Yaşlı bakıcıya emanet et", "Evin gelirini koru; kalabalık odada sulu çorba ve uyku şurubuyla idare et."],
	"mother_stays_home": ["Annenin evde kalması için bütçeyi kıs", "Kazançtan fedakarlık et; anne şefkati ve temiz bakımla büyü."],
	"accept_vaccination": ["Aşı bedelini öde ve iğneyi kabul et", "Koldaki küçük bir acıyla amansız çiçek hastalığına karşı korun."],
	"rely_on_hearth": ["Evdeki şifalı otlara ve duaya güven", "Parayı ekmeğe sakla; kış salgınlarının kapından geçip gitmesini um."],
	"brave_the_alleys": ["Sokak çetesiyle çamurda koştur", "Sokakta serbestçe büyü; uyanıklık ve dayanıklılık kazanırken kaza riskini göze al."],
	"stay_by_hearth": ["Eşik dibinde, kömür kovası yanında kal", "Evden uzaklaşma; soğuk yağmurdan ve at arabalarından korun."],
	"trace_letters": ["Harfleri ve sesleri çözmeye çalış", "Erken yaşta harfleri öğren; merakını ve zihnini geliştir."],
	"help_household_chores": ["Levhayı bırakıp su ve kül taşı", "Küçük ellerle küçük işlere koş; eve birkaç kuruş kazandır."],
	"stand_ground_inquest": ["Ustabaşının gözünün içine bak ve dik dur", "Sözlerinin arkasında dur; işçilerin saygısını kazanırken yönetimin şimşeklerini üzerine çek."],
	"humble_compliance": ["Başını öne eğ ve çok çalışmaya söz ver", "Ekmek kapısını kaybetmemek için alttan al; fazla mesai yaparak öfkeyi dindir."],
	"forge_masterpiece": ["Kızgın demire vur ve kalfalık hünerini göster", "Tüm gücünle çekici indir; kalfalık beratı ve nitelikli işçi kazancı kazan."],
	"remain_assistant": ["Henüz hazır olmadığını söyleyip körük başında kal", "Haddini bil; ustanın yanında güvenli ve mütevazı bir çırak olarak devam et."],
	"rely_on_constitution": ["Ocak başında yün battaniyeye sarıl", "Evdeki çorbayla hastalığı atlatmaya çalış; masraf yapma ama ciğerlerini zorla."],
	"call_parish_apothecary": ["Eczacıdan kına kına şurubu al", "Acı şurupla ateşi düşür; hastalığın nüksetmesini önle."],
	"accept_temperance_aid": ["Dayanışma payını ve kitapları kabul et", "Dürüstlüğünün karşılığı olan maddi desteği al; birikimini güçlendir."],
	"modest_refusal": ["Yardımı sokaktaki dul ve yetimlere devret", "Büyük bir cömertlik göster; mahallede saygınlığını ve itibarını katla."],
	"liquidate_hearth": ["Döküm sobayı ve yün yatağı rehine ver", "Eşyaları arabaya yükle; borcun 350 şilini kapansın ama ev buz kessin."],
	"face_magistrate_debt": ["Kapıyı sürgüle ve mahkeme celbini bekle", "Evin son eşyalarını kaptırma; borçlu hapsi ve amele cezası riskini göze al."],
	"scavenge_flour_barge": ["Kanal mavnalarından dökülen tahılı topla", "Gece karanlığında un toplayıp karnı doyur; bekçilerin sopası ve kaza riskini göze al."],
	"beg_parish_gruel": ["Kilise merdivenlerinde düşkünler çorbasına el aç", "Gururunu çiğne ama aileni tehlikeye atmadan açlığı bastır."],
	"separate_room_sacrifice": ["Birikimini döküp tavan arası oda tut", "Kişisel paranı harca; evi ferahlatıp ciğerleri rutubetten koru."],
	"endure_confined_air": ["Kaderine razı ol, omuz omuza sıkış", "Parayı elinde tut; rutubetli mahzen havasının sağlığını kemirmesine katlan."],
	"devote_to_kin": ["İşi bırakıp kardeşinin başucunda nöbet tut", "Kendi istikbalini feda et; kardeşlik bağını ve karakterini yücelt."],
	"pursue_own_station": ["İşini ve ekmeğini bırakma, çalışmaya devam et", "Soğukkanlı ve bencil ol; kazancını korurken bakımı başkalarına bırak."],
	"join_strike_picket": ["Grev nöbetine katıl ve sendikayla yürü", "Yevmiyeden vazgeç ve polis copunu göze al; sınıfının onurunu ve işçi dayanışmasını savun."],
	"scab_work_for_bonus": ["Nöbetçileri aşıp çift yevmiyeye çalış", "Altınları cebine koy ve patronun gözüne girip terfi al; fakat komşularının lanetini üstlen."],
	"brave_the_sparks": ["Dumanın içine atıl ve kum küreğine sarıl", "Büyük bir zanaatkarlık cesareti göster; adını efsane yap veya kalıcı yanık riskini göze al."],
	"step_back_to_safety": ["Geri çekil ve madenin dökülmesine izin ver", "Tenini ve ciğerlerini koru; kalıp yeniden dökülür ama can geri gelmez."],
	"accept_silence_premium": ["Katip payını al ve hileli defteri onayla", "Hemen nakit primi ve muhasebeci terfisini kap; kaderini usulsüz bir tüccara bağla."],
	"refuse_complicity": ["Sahtekarlığa ortak olmayıp kalemi bırak", "Vicdanını ve onurunu koru; derhal işten kovulmayı göze al."],
	"lease_corner_shop": ["Birikimini yatır ve tabelanı as", "Fabrika zeminini ebediyen terk et; bağımsız bir esnaf olarak kendi yolunu çiz."],
	"keep_hoarding_savings": ["Tereddüt et ve parayı kasada tut", "Güvenli sularda kal; yevmiyeli çalışmaya devam edip hane birikimini riske atma."]
}
const ACTION_DESCRIPTIONS: Dictionary = {
	"play": ["Sokakta akranlarınla koşturup çocukluğun tadını çıkardın.", "Çocukluk neşesi"],
	"study": ["Kandil ışığında ders çalıştın; okuryazarlığını geliştirdin.", "Öğrenme gayreti"],
	"rest": ["Bu yıl bedenini dinlendirdin ve güç topladın.", "Huzurlu bir mola"],
	"family_time": ["Ailenle ocak başında vakit geçirdin; bağlarınız güçlendi.", "Aile ocağı"],
	"socialize": ["Mahalledeki dostlarla bir araya gelip dertleştin.", "Dost meclisi"],
	"self_education": ["Geceleri gazete ve kitaplarla kendi kendini eğittin.", "Zihni diri tutmak"],
	"work_hard": ["İşine dört elle sarılıp fazla mesai yaptın; azmini kanıtladın.", "Alın teri"],
	"cheap_leisure": ["Cebinden küçük bir pay ayırıp çalgılı kahvede dinlendin.", "Küçük bir nefes"],
	"buy_book": ["Biriktirdiğin parayla yeni bir kitap alıp ufkunu açtın.", "Yeni bir sayfa"]
}


static func word(id: String) -> String:
	return str(NAMES.get(id, id.replace("_", " ").capitalize()))


static func stage(age: int) -> String:
	if age < 4:
		return "İlk yıllar"
	if age < 13:
		return "Çocukluk"
	if age < 18:
		return "Gençlik"
	if age < 60:
		return "Yetişkinlik"
	return "İleri yaşlar"


static func person(state: Dictionary, id: String) -> String:
	if id == state.meta.player_id:
		return "Sen"
	return str(state.actors.get(id, {}).get("name", "Ailenden biri"))


static func page(events: Array, state: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var title: String = "Bir yıl daha geride kaldı"
	var tag: String = "HAYAT DEVAM EDİYOR"
	var priority: int = 0
	for event: Dictionary in events:
		var d: Dictionary = event.details
		var id: String = str(d.get("actor_id", ""))
		var who: String = person(state, id)
		var text: String = ""
		var heading: String = ""
		var level: int = 0
		match event.kind:
			"actor_died":
				text = "Hayatın sona erdi." if id == state.meta.player_id else "%s hayatını kaybetti." % who
				heading = "Bir hayatın son sayfası" if id == state.meta.player_id else "Ailende bir kayıp"
				level = 10
			"school_started", "education_started":
				text = "Okula başladın." if id == state.meta.player_id else "%s okula başladı." % who
				heading = "Yeni bir defter, yeni bir başlangıç"
				level = 5
			"school_completed", "education_completed":
				text = "Temel eğitimini tamamladın." if id == state.meta.player_id else "%s temel eğitimini tamamladı." % who
				heading = "Öğrendiklerin seninle kalacak"
				level = 5
			"school_interrupted", "education_interrupted":
				text = "Çalışmaya başlamak için eğitimine ara verdin." if id == state.meta.player_id else "%s eğitimine ara verdi." % who
				heading = "Okuldan ayrılırken"
				level = 6
			"occupation_started":
				text = "%s olarak işe başladın." % word(str(d.occupation_id)) if id == state.meta.player_id else "%s, %s olarak işe başladı." % [who, word(str(d.occupation_id)).to_lower()]
				heading = "Çalışma hayatında yeni bir sayfa"
				level = 4
			"job_lost":
				text = "İşini kaybettin; evin gelir kaynakları azaldı." if id == state.meta.player_id else "%s işini kaybetti; evin gelir kaynakları azaldı." % who
				heading = "Geçim derdi"
				level = 5
			"condition_acquired":
				text = "%s: %s." % [who, word(str(d.condition_id))]
				heading = "Sağlığın gölgesinde"
				level = 3
			"condition_recovered":
				text = "%s için %s geride kaldı." % [who, word(str(d.condition_id)).to_lower()]
				heading = "Biraz daha iyi"
				level = 2
			"marriage_formed":
				text = "%s ile evlendin. Artık aynı haneyi paylaşıyorsunuz." % str(d.get("name", "Sevdiğin kişi"))
				heading = "İki hayat, bir ev"
				level = 8
			"child_born":
				text = "%s dünyaya geldi. Ailen büyüdü." % str(d.get("name", "Bebeğiniz"))
				heading = "Evde yeni bir ses"
				level = 8
			"storylet_choice_made":
				var choice_id: String = str(d.get("choice_id", ""))
				text = "Kararın: %s." % str(CHOICES.get(choice_id, [word(choice_id)])[0])
				heading = "Kendi yolunu çizerken"
				level = 4
			"food_insecurity":
				text = "Ailenin gıda ihtiyacının tamamı karşılanamadı."
				heading = "Sofrada eksilenler"
				level = 3
			"aid_received", "orphan_support_received":
				text = "Hanene dışarıdan geçim desteği ulaştı."
				heading = "Bir yardım eli"
				level = 2
			"marriage_ended":
				text = "Eşini kaybettin. Evinde derin bir yalnızlık başladı."
				heading = "Yalnız kalan bir ev"
				level = 9
			"child_left_home":
				text = "Çocuğun kendi hayatını kurmak üzere evden ayrıldı."
				heading = "Yuvadan uçanlar"
				level = 6
			"personal_transfer":
				var amt: int = int(d.get("amount", 0))
				if amt > 0:
					text = "Bu yıl kişisel bütçene %d aktarıldı." % amt
					heading = "Cebindeki kazanç"
					level = 2
			"personal_spending":
				text = "%s için kişisel bütçenden %d harcadın." % [word(str(d.get("category", "Gereksinim"))), int(d.get("amount", 0))]
				heading = "Gündelik ihtiyaçlar"
				level = 2
			"moved_residence":
				text = "Yeni bir konuta taşındınız: %s." % word(str(d.get("residence_id", "Yeni ev")))
				heading = "Yeni bir çatı altında"
				level = 5
			"person_met":
				text = "Yeni biriyle tanıştın: %s." % str(d.get("person_name", "Yeni bir tanıdık"))
				heading = "Yeni bir sima"
				level = 3
			"treatment_administered":
				text = "%s tedavisi gördün." % word(str(d.get("treatment_id", "Tedavi")))
				heading = "Şifa arayışı"
				level = 4
			"disability_acquired":
				text = "Yaşanan kaza kalıcı bir bedensel etki bıraktı."
				heading = "Kalıcı bir iz"
				level = 7
			"family_event":
				text = "Aile içinde yeni bir hadise yaşandı."
				heading = "Aile meclisi"
				level = 3
			"life_action":
				var aid: String = str(d.get("action_id", ""))
				if ACTION_DESCRIPTIONS.has(aid):
					text = ACTION_DESCRIPTIONS[aid][0]
					heading = ACTION_DESCRIPTIONS[aid][1]
				else:
					text = "Bu yıl kişisel bir adım attın: %s." % word(aid)
					heading = "Kişisel gayret"
				level = 4
		if text != "" and text not in lines:
			lines.append(text)
		if level > priority:
			priority = level
			title = heading
			tag = "HAYATINDAN BİR AN"
	if lines.is_empty():
		lines.append("Gündelik hayat kendi akışında sürdü. Ailenin bütçesi ve sağlığı bu yıl da değişmeye devam etti.")

	var has_ledger: bool = not state.get("ledgers", []).is_empty()
	var ledger: Dictionary = state.ledgers[state.ledgers.size() - 1] if has_ledger else {}
	var player_id: String = str(state.get("meta", {}).get("player_id", ""))
	var player: Dictionary = state.get("actors", {}).get(player_id, {})
	var balance: Dictionary = {
		"income": int(ledger.get("earned_income", 0)),
		"expenses": int(ledger.get("paid_expenses", 0)),
		"savings": int(state.get("household", {}).get("savings", 0)),
		"debt": int(state.get("household", {}).get("debt", 0)),
		"food_security": int(state.get("household", {}).get("food_security", 1000)),
		"health": int(player.get("health", 0)),
		"willpower": int(player.get("willpower", 0)),
		"literacy": int(player.get("literacy", 0)),
		"living_standard": str(state.get("household", {}).get("living_standard", "basic"))
	}

	return {"year": int(state.world.year), "title": title, "body": "\n".join(lines),
		"tag": tag, "important": priority > 0, "balance": balance}


static func story_wording(story_id: String, state: Dictionary, raw_title: String, raw_text: String) -> Array:
	var base: Array = STORIES.get(story_id, [raw_title, raw_text])
	var title_tmpl: String = str(base[0])
	var text_tmpl: String = str(base[1])
	if state.is_empty():
		return [title_tmpl, text_tmpl]

	var player_id: String = str(state.get("meta", {}).get("player_id", ""))
	var player: Dictionary = state.get("actors", {}).get(player_id, {})
	var player_name: String = str(player.get("name", "Sen"))
	var debt_val: int = int(state.get("household", {}).get("debt", 0))
	var savings_val: int = int(state.get("household", {}).get("savings", 0))

	var child_name: String = "evladın"
	for cid: String in state.get("family", {}).get("children_ids", []):
		if state.get("actors", {}).has(cid) and state.actors[cid].get("alive", false):
			child_name = str(state.actors[cid].get("name", "evladın"))
			break

	var sibling_name: String = "kardeşin"
	var parents: Array = [player.get("parent_1_id", ""), player.get("parent_2_id", "")]
	for aid: String in state.get("actors", {}):
		if aid == player_id or not state.actors[aid].get("alive", false):
			continue
		var a: Dictionary = state.actors[aid]
		if (a.get("parent_1_id", "") != "" and a.get("parent_1_id", "") in parents) or (a.get("parent_2_id", "") != "" and a.get("parent_2_id", "") in parents):
			sibling_name = str(a.get("name", "kardeşin"))
			break

	var spouse_id: String = str(state.get("family", {}).get("current_spouse_id", ""))
	var spouse_name: String = str(state.get("actors", {}).get(spouse_id, {}).get("name", "eşin"))

	var replacements: Dictionary = {
		"{player}": player_name,
		"{debt}": str(debt_val),
		"{savings}": str(savings_val),
		"{child}": child_name,
		"{sibling}": sibling_name,
		"{spouse}": spouse_name,
		"{job}": word(str(player.get("occupation_id", "dependent"))).to_lower()
	}

	for k: String in replacements:
		title_tmpl = title_tmpl.replace(k, replacements[k])
		text_tmpl = text_tmpl.replace(k, replacements[k])

	return [title_tmpl, text_tmpl]
