extends RefCounted
## Yaşam Ağacı Sistemi (Life Decision & Pathway Tree).
## Karakterin doğumundan ölümüne kadar yaptığı tüm kritik tercihleri,
## hikaye kararlarını, inisiyatiflerini ve dönüm noktalarını bir ağaç yapısında toplar.

const Words = preload("res://ui/chronicle_text.gd")
const Origin = preload("res://simulation/origin_system.gd")

static func build_tree(state: Dictionary) -> Array[Dictionary]:
	var path_nodes: Array[Dictionary] = []
	if state.is_empty() or not state.has("meta") or not state.has("actors"):
		return path_nodes

	var player_id: String = str(state.meta.get("player_id", "player"))
	var player: Dictionary = state.actors.get(player_id, {})
	var birth_year: int = int(player.get("birth_year", 1850))

	# 1. Kök Düğüm: Doğum & Aile Kökeni
	var origin_id: String = str(state.meta.get("origin_id", "factory_working"))
	var origin_narr: Dictionary = Origin.get_narrative(origin_id)
	var origin_label: String = str(state.meta.get("origin_label", "Fabrika İşçisi Ailesi"))
	path_nodes.append({
		"year": birth_year,
		"age": 0,
		"kind": "origin",
		"tag": "HAYATIN BAŞLANGICI",
		"title": "Manchester'da Dünyaya Geliş",
		"choice_label": "Köken: " + origin_label,
		"summary": origin_narr.body,
		"badge": "DOĞUM"
	})

	# 2. Tarihçe Olaylarından Kararları Çıkar
	var history: Array = state.get("history", [])
	var processed_storylets: Dictionary = {}

	for item: Dictionary in history:
		var yr: int = int(item.get("year", birth_year))
		var age: int = yr - birth_year
		var kind: String = str(item.get("kind", ""))
		var d: Dictionary = item.get("details", {})

		match kind:
			"storylet_choice_made":
				var choice_id: String = str(d.get("choice_id", ""))
				var storylet_id: String = str(d.get("storylet_id", ""))
				var choice_text: String = choice_id
				if Words.CHOICES.has(choice_id):
					choice_text = str(Words.CHOICES[choice_id][0])
				else:
					choice_text = Words.word(choice_id)

				var st_title: String = "Hayatın Bir Dönemeci"
				if Words.STORIES.has(storylet_id):
					st_title = str(Words.STORIES[storylet_id][0])
				else:
					st_title = Words.word(storylet_id)

				path_nodes.append({
					"year": yr,
					"age": age,
					"kind": "decision",
					"tag": "BÜYÜK YOL AYRIMI",
					"title": st_title,
					"choice_label": "Tercihin: " + choice_text,
					"summary": "Bu kritik ikilemde kendi iradenle bu yolu seçtin ve hayatının akışını değiştirdin.",
					"badge": "KARAR"
				})

			"life_action":
				if str(d.get("actor_id", "")) == player_id:
					var act_id: String = str(d.get("action_id", ""))
					var act_title: String = "Kişisel Gayret"
					var act_desc: String = "Bu yıl kişisel bir adım attın."
					if Words.ACTION_DESCRIPTIONS.has(act_id):
						act_desc = Words.ACTION_DESCRIPTIONS[act_id][0]
						act_title = Words.ACTION_DESCRIPTIONS[act_id][1]

					# Ağaçta kalabalık yapmaması için yalnızca önemli eylemleri veya ilkleri al
					if act_id in ["study", "self_education", "work_hard", "buy_book", "gentleman_club_visit", "church_pew_devotion", "parish_charity_volunteer"]:
						path_nodes.append({
							"year": yr,
							"age": age,
							"kind": "initiative",
							"tag": "YILLIK İNİSİYATİF",
							"title": act_title,
							"choice_label": "Odak: " + Words.word(act_id),
							"summary": act_desc,
							"badge": "ODAK"
						})

			"marriage":
				var spouse_name: String = str(d.get("spouse_name", "Eşiniz"))
				path_nodes.append({
					"year": yr,
					"age": age,
					"kind": "family",
					"tag": "AİLE BİRLİĞİ",
					"title": "Evlilik ve Yuva Kurma",
					"choice_label": spouse_name + " ile Hayatını Birleştirdin",
					"summary": "Kendi ocağını kurdun ve ailenin temellerini attın.",
					"badge": "EVLİLİK"
				})

			"child_born":
				var child_name: String = str(d.get("name", "Bebeğiniz"))
				path_nodes.append({
					"year": yr,
					"age": age,
					"kind": "family",
					"tag": "YENİ NESİL",
					"title": "Evlat Sahibi Olma",
					"choice_label": child_name + " Dünyaya Geldi",
					"summary": "Ailen büyüdü; geleceğe yeni bir can bıraktın.",
					"badge": "EVLAT"
				})

			"job_changed":
				if str(d.get("actor_id", "")) == player_id:
					var new_job: String = Words.word(str(d.get("new_occupation_id", "")))
					path_nodes.append({
						"year": yr,
						"age": age,
						"kind": "career",
						"tag": "MESLEKİ ADIM",
						"title": "Kariyer Terfisi",
						"choice_label": new_job + " Olarak İşe Başladın",
						"summary": "Emek ve gayretlerinle yeni bir mesleğe adım attın.",
						"badge": "MESLEK"
					})

			"moved_in":
				var dwelling_id: String = str(d.get("dwelling_id", ""))
				if dwelling_id not in ["family_room", ""]:
					path_nodes.append({
						"year": yr,
						"age": age,
						"kind": "housing",
						"tag": "YENİ BİR ÇATI",
						"title": "Konut Değişimi",
						"choice_label": Words.word(dwelling_id) + " Konutuna Taşındın",
						"summary": "Yaşam standardını değiştirip yeni bir çevreye yerleştin.",
						"badge": "KONUT"
					})

	# 3. Son Düğüm: Vefat & Miras (Eğer oyuncu vefat etmişse)
	if not bool(player.get("alive", true)):
		var death_yr: int = int(player.get("death_year", state.world.year))
		var death_age: int = int(player.get("age", death_yr - birth_year))
		var cause: String = Words.word(str(player.get("death_cause", "old_age")))
		path_nodes.append({
			"year": death_yr,
			"age": death_age,
			"kind": "death",
			"tag": "HAYATIN SONU",
			"title": "Bir Ömrün Sonu & Miras",
			"choice_label": "%d Yaşında Vefat (%s)" % [death_age, cause],
			"summary": "Manchester'da başlayan yürüyüş burada nihayete erdi. Arkanda verdiğin kararların izi kaldı.",
			"badge": "MİRAS"
		})

	return path_nodes
