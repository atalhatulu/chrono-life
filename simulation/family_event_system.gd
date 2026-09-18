extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

static func _last_year(state: Dictionary, kind: String, subject_id: String) -> int:
	var last := -9999
	for event: Dictionary in state.family.get("history", []):
		if str(event.get("kind", "")) == kind and str(event.get("subject_id", "")) == subject_id:
			last = maxi(last, int(event.get("year", -9999)))
	return last

static func collect_candidates(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var year := int(state.world.year)
	for child_id: String in state.family.get("children_ids", []):
		if not state.actors.has(child_id):
			continue
		var child: Dictionary = state.actors[child_id]
		if not child.alive:
			continue
		var parenting: Dictionary = state.family.get("parenting", {}).get(child_id, {})
		if int(parenting.get("conflict", 0)) >= 60 and year - _last_year(state, "parent_child_conflict", child_id) >= 2:
			out.append({"type":"parent_child_conflict","subject_id":child_id,"weight":40 + int(parenting.conflict)})
		if int(parenting.get("support", 0)) >= 75 and year - _last_year(state, "parent_child_support", child_id) >= 3:
			out.append({"type":"parent_child_support","subject_id":child_id,"weight":30 + int(parenting.support)})
		if int(child.age) in [6, 14, 18] and year - _last_year(state, "child_milestone", child_id) >= 1:
			out.append({"type":"child_milestone","subject_id":child_id,"weight":60})
		if str(child.household_id) != str(state.household.id) and year - _last_year(state, "adult_child_visit", child_id) >= 3:
			out.append({"type":"adult_child_visit","subject_id":child_id,"weight":35})
	var player_id := str(state.meta.player_id)
	var parents: Array = state.family.get("kinship", {}).get(player_id, {}).get("parents", [])
	for parent_id: String in parents:
		if not state.actors.has(parent_id):
			continue
		var parent: Dictionary = state.actors[parent_id]
		if not parent.alive or (int(parent.age) < 60 and int(parent.health) >= 55):
			continue
		var care: Dictionary = state.family.get("elder_care", {}).get(parent_id, {})
		if int(care.get("care", 0)) < 30 and year - _last_year(state, "elder_care_need", parent_id) >= 2:
			out.append({"type":"elder_care_need","subject_id":parent_id,"weight":45 + (100 - int(parent.health))})
	for key: String in state.family.get("sibling_bonds", {}):
		var bond: Dictionary = state.family.sibling_bonds[key]
		if int(bond.get("rivalry", 0)) >= 55 and year - _last_year(state, "sibling_conflict", key) >= 2:
			out.append({"type":"sibling_conflict","subject_id":key,"weight":25 + int(bond.rivalry)})
		if int(bond.get("support", 0)) >= 70 and year - _last_year(state, "sibling_support", key) >= 3:
			out.append({"type":"sibling_support","subject_id":key,"weight":20 + int(bond.support)})
	return out

static func resolve_one(state: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = collect_candidates(state)
	if candidates.is_empty():
		return {}
	var weights: Array[int] = []
	for c: Dictionary in candidates:
		weights.append(int(c.weight))
	var seed: int = str(state.meta.master_seed).to_int()
	var idx: int = Rng.weighted(seed, "family_events", int(state.world.year), str(state.meta.player_id), "pick", weights)
	return _apply(state, candidates[idx])

static func _apply(state: Dictionary, event: Dictionary) -> Dictionary:
	var kind: String = str(event.type)
	var subject: String = str(event.subject_id)
	var title: String = ""
	var text: String = ""
	match kind:
		"parent_child_conflict":
			var child: Dictionary = state.actors[subject]
			var parenting: Dictionary = state.family.parenting[subject]
			parenting.conflict = clampi(int(parenting.conflict) + 6, 0, 100)
			parenting.support = clampi(int(parenting.support) - 4, 0, 100)
			child.needs.stress = clampi(int(child.needs.stress) + 5, 0, 100)
			title = "Aile içinde gerilim"
			text = "%s ile aranızdaki anlaşmazlık büyüdü." % child.name
		"parent_child_support":
			var child: Dictionary = state.actors[subject]
			child.needs.happiness = clampi(int(child.needs.happiness) + 5, 0, 100)
			child.willpower = clampi(int(child.willpower) + 1, 0, 100)
			title = "Desteğin karşılık buldu"
			text = "%s kendini yanında güvende hissetti." % child.name
		"child_milestone":
			var child: Dictionary = state.actors[subject]
			title = "Çocuğunun hayatında yeni bir dönem"
			text = "%s artık %d yaşında." % [child.name, int(child.age)]
		"adult_child_visit":
			var child: Dictionary = state.actors[subject]
			if state.relationships.people.has(subject):
				state.relationships.people[subject].closeness = clampi(int(state.relationships.people[subject].closeness) + 5, 0, 100)
				state.relationships.people[subject].contact = clampi(int(state.relationships.people[subject].contact) + 8, 0, 100)
			title = "Aile ziyareti"
			text = "%s kendi hayatından sana uğradı." % child.name
		"sibling_conflict":
			var bond: Dictionary = state.family.sibling_bonds[subject]
			bond.rivalry = clampi(int(bond.rivalry) + 5, 0, 100)
			bond.closeness = clampi(int(bond.closeness) - 4, 0, 100)
			title = "Kardeşler arasında gerilim"
			text = "Çocukların arasındaki rekabet açık bir tartışmaya dönüştü."
		"sibling_support":
			var bond: Dictionary = state.family.sibling_bonds[subject]
			bond.closeness = clampi(int(bond.closeness) + 5, 0, 100)
			title = "Kardeş dayanışması"
			text = "Çocukların zor bir anda birbirine destek oldu."
		"elder_care_need":
			var parent: Dictionary = state.actors[subject]
			title = "Yaşlanan ebeveynin sana ihtiyaç duyuyor"
			text = "%s artık günlük yaşamda daha fazla desteğe ihtiyaç duyuyor." % parent.name
	state.family.history.append({"year":int(state.world.year),"kind":kind,"subject_id":subject})
	return {"type":kind,"subject_id":subject,"title":title,"text":text}
