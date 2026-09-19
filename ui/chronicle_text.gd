extends RefCounted
## Human-facing wording only; IDs and simulation content stay unchanged.

const NAMES: Dictionary = {
	"dependent": "Henüz bir işi yok", "textile_worker": "Dokuma işçisi",
	"sewing_worker": "Dikiş işçisi", "child_factory_worker": "Fabrika çırağı",
	"skilled_textile_worker": "Nitelikli dokuma işçisi", "mill_overlooker": "Fabrika gözetmeni",
	"clerk": "Kâtip", "bookkeeper": "Muhasebe kâtibi",
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
	"temperance_benefit_solidarity": ["Ayıklık Cemiyeti dayanışması", "Ayıklık senedine sadık kalıp meyhanelerden uzak durduğun için cemiyet seni yıllık toplantısına davet ediyor; yardımlaşma sandığından pay teklif ediyor."]
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
	"modest_refusal": ["Yardımı sokaktaki dul ve yetimlere devret", "Büyük bir cömertlik göster; mahallede saygınlığını ve itibarını katla."]
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
	return {"year": int(state.world.year), "title": title, "body": "\n".join(lines),
		"tag": tag, "important": priority > 0}
