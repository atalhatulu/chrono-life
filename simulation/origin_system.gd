extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Housing = preload("res://simulation/housing_system.gd")
const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const SocialStatus = preload("res://simulation/social_status_system.gd")

const ORIGINS: Dictionary = {
	"destitute_cellar": {
		"id": "destitute_cellar",
		"label": "Aşırı Yoksul Mahzen Ailesi",
		"short_desc": "Gündelik amelelik, rutubetli bodrum katı, açlık riski",
		"parent_1_job": "canal_bargee",
		"parent_2_job": "dependent",
		"dwelling_id": "cellar_dwelling",
		"initial_savings": 220,
		"status_score": 15,
		"player_health": 85,
		"player_happiness": 45,
		"player_stress": 40,
		"narrative_title": "Rutubetli bir mahzen",
		"narrative_body": "Manchester’ın en yoksul mahallesi Little Ireland’da, rutubetli ve ışıksız bir mahzen odasında dünyaya geldin. Baban kanal mavnalarında amelelik yapıyor, annen ise işsiz ve hasta. Bu evde sıcak bir çorba bile her gün kaynamıyor; hayatın ilk gününden itibaren hayatta kalmak bir mücadele olacak."
	},
	"factory_working": {
		"id": "factory_working",
		"label": "Fabrika İşçisi Ailesi",
		"short_desc": "Tekstil fabrikası vardiyası, işçi sıra evi, dengeli bütçe",
		"parent_1_job": "textile_worker",
		"parent_2_job": "sewing_worker",
		"dwelling_id": "family_room",
		"initial_savings": 800,
		"status_score": 35,
		"player_health": 95,
		"player_happiness": 55,
		"player_stress": 20,
		"narrative_title": "Fabrika bacalarının gölgesi",
		"narrative_body": "Ancoats işçi mahallesinde, fabrika bacalarının dumanı altında dünyaya geldin. Baban dokuma tezgâhlarında, annen ise dikiş atölyesinde ter döküyor. Evde pamuk tozu ve kömür isi kokuyor; geleceğin makinelerin ritmiyle şekillenecek."
	},
	"artisan_shopkeeper": {
		"id": "artisan_shopkeeper",
		"label": "Bağımsız Esnaf ve Zanaatkar",
		"short_desc": "Kendi dükkânı olan esnaf, kooperatif evi, zanaat mirası",
		"parent_1_job": "independent_shopkeeper",
		"parent_2_job": "dependent",
		"dwelling_id": "cooperative_cottage",
		"initial_savings": 2600,
		"status_score": 52,
		"player_health": 100,
		"player_happiness": 65,
		"player_stress": 15,
		"narrative_title": "Pazar yerinde bir ocak",
		"narrative_body": "Şehrin hareketli çarşısına yakın, kendi dükkânını işleten bir esnaf ocağında dünyaya geldin. Babanın küçük dükkânı aileyi kimseye muhtaç etmiyor. Evde bir gaz lambası, rafta bir İncil ve hesap defteri duruyor. Ailen senin de bir zanaat öğrenip saygın bir hayat sürmeni istiyor."
	},
	"clerk_respectable": {
		"id": "clerk_respectable",
		"label": "Saygın Orta Sınıf Katip",
		"short_desc": "Ticaret bürosu katibi, konforlu daire, okuryazarlık ve terbiye",
		"parent_1_job": "clerk",
		"parent_2_job": "dependent",
		"dwelling_id": "better_flat",
		"initial_savings": 4200,
		"status_score": 68,
		"player_health": 100,
		"player_happiness": 70,
		"player_stress": 10,
		"narrative_title": "Mürekkep ve hesap defterleri",
		"narrative_body": "Şehrin ticaret bürolarında defter tutan saygın bir katibin evinde dünyaya geldin. Eviniz fabrikaların zehirli dumanından uzakta, temiz ve düzenli bir sokakta yer alıyor. Babanın en büyük gayesi, senin de iyi bir eğitim alıp cemiyette hürmet gören bir beyefendi olman."
	},
	"merchant_gentry": {
		"id": "merchant_gentry",
		"label": "Varlıklı Tüccar ve Fabrikatör",
		"short_desc": "Sanayi burjuvazisi, banliyö tüccar konağı, yüksek itibar ve servet",
		"parent_1_job": "master_machinist",
		"parent_2_job": "dependent",
		"dwelling_id": "merchant_residence",
		"initial_savings": 14000,
		"status_score": 88,
		"player_health": 100,
		"player_happiness": 80,
		"player_stress": 5,
		"narrative_title": "Broughton konağında bir beşik",
		"narrative_body": "Şehrin en varlıklı banliyösü Broughton’da, geniş bahçeli ve şömineli bir tüccar konağında dünyaya geldin. Babanın büyük atölyeleri, hisseleri ve yatırımları var; kapıda bekleyen fayton ve evdeki hizmetkarlar rahat bir çocukluğu müjdeliyor. Önünde açılan kapılar ve beklenen itibar bambaşka."
	}
}

static func get_origins() -> Dictionary:
	return ORIGINS

static func resolve_origin(origin_id: String, seed_value: int) -> String:
	if origin_id != "" and origin_id != "random" and origin_id != "lottery" and ORIGINS.has(origin_id):
		return origin_id
	var roll: int = Rng.integer(seed_value, "origin_lottery", 1850, "player", "origin", 0, 99)
	if roll < 20:
		return "destitute_cellar"
	elif roll < 65:
		return "factory_working"
	elif roll < 80:
		return "artisan_shopkeeper"
	elif roll < 92:
		return "clerk_respectable"
	else:
		return "merchant_gentry"

static func apply_origin(state: Dictionary, origin_id: String, seed_value: int) -> void:
	var final_origin: String = resolve_origin(origin_id, seed_value)
	var data: Dictionary = ORIGINS.get(final_origin, ORIGINS["factory_working"])
	state.meta["origin_id"] = final_origin
	state.meta["origin_label"] = str(data.get("label", ""))

	# Ebeveyn meslek ve gelirlerini güncelle
	var active_income: int = 0
	if state.actors.has("parent_1"):
		active_income += _equip_parent_job(state, state.actors.parent_1, str(data.parent_1_job))

	if state.actors.has("parent_2"):
		active_income += _equip_parent_job(state, state.actors.parent_2, str(data.parent_2_job))

	# Hane bütçesi ve konut
	state.household.income = active_income
	state.household.savings = int(data.initial_savings)
	if not state.has("housing"):
		Housing.initialize(state, str(data.dwelling_id))
	else:
		state.housing.dwelling_id = str(data.dwelling_id)
		var defs: Dictionary = Housing.dwellings_by_id(state)
		if defs.has(data.dwelling_id):
			state.housing.tenure = str(defs[data.dwelling_id].get("tenure", "household_use"))
		state.housing.history = [{"year": int(state.world.year), "kind": "moved_in", "dwelling_id": str(data.dwelling_id)}]

	# Oyuncu ilk nitelikleri
	if state.actors.has(state.meta.player_id):
		var p: Dictionary = state.actors[state.meta.player_id]
		p.health = int(data.get("player_health", 100))
		if not p.has("needs"):
			p.needs = {}
		p.needs["happiness"] = int(data.get("player_happiness", 55))
		p.needs["stress"] = int(data.get("player_stress", 20))
		if final_origin == "merchant_gentry":
			p.literacy = 10

	# Sosyal statü
	if not state.has("social_status"):
		state.social_status = {}
	state.social_status["score"] = int(data.get("status_score", 35))
	SocialStatus.recompute(state)
	PersonalEconomy.normalize(state)

static func _equip_parent_job(state: Dictionary, actor: Dictionary, occupation_id: String) -> int:
	actor.occupation_id = occupation_id
	var path: String = str(state.get("meta", {}).get("careers_path", "res://content/manchester_careers.json"))
	var job: Dictionary = {}
	if FileAccess.file_exists(path):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for j: Dictionary in parsed.get("jobs", []):
					if str(j.get("id", "")) == occupation_id:
						job = j
						break

	if not job.is_empty():
		if int(job.get("minimum_literacy", 0)) > int(actor.get("literacy", 0)):
			actor.literacy = int(job.minimum_literacy)
		if not actor.has("skills"):
			actor.skills = {"values": {}, "history": {}}
		if not actor.skills.has("values"):
			actor.skills["values"] = {}
		for skill_id: String in job.get("required_skills", {}):
			actor.skills.values[skill_id] = maxi(int(actor.skills.values.get(skill_id, 0)), int(job.required_skills[skill_id]))
		for req_stage: Variant in job.get("required_education_stages", []):
			if not actor.has("education"):
				actor.education = {}
			if not actor.education.has("completed_stages"):
				actor.education["completed_stages"] = []
			if req_stage not in actor.education.completed_stages:
				actor.education.completed_stages.append(req_stage)
			actor.education_state = "completed"
		var track: String = str(job.get("career_track", ""))
		var req_exp: int = int(job.get("minimum_experience_years", 0))
		if req_exp > 0 and track != "":
			if not actor.has("career"):
				actor.career = {}
			if not actor.career.has("track_experience"):
				actor.career["track_experience"] = {}
			actor.career.track_experience[track] = maxi(int(actor.career.track_experience.get(track, 0)), req_exp)

	var econ_index: int = int(state.get("world", {}).get("economy_index", 1000))
	var capacity: int = int(actor.get("work_capacity", 1000))
	var income: int = int(int(job.get("annual_income", 0)) * econ_index * capacity / 1000000.0)
	actor.income = income
	return income

static func get_narrative(origin_id: String) -> Dictionary:
	var data: Dictionary = ORIGINS.get(origin_id, ORIGINS["factory_working"])
	return {
		"title": str(data.get("narrative_title", "Hayata merhaba.")),
		"body": str(data.get("narrative_body", "Manchester’da dünyaya geldin."))
	}
