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
	"courtship_and_marriage": ["Irwell kıyısında bir yürüyüş", "Birlikte geçirilen ayların ardından, sevdiğin kişi aynı evi paylaşmaktan söz ediyor. Önünüzde, artık beraber yazabileceğiniz bir hayat var."]
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
	"remain_single": ["Biraz daha bekle", "Yeni sorumlulukları daha sonraya bırak."]
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
