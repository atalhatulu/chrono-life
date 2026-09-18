extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")
const Relationships = preload("res://simulation/relationship_system.gd")

static func _last_event_year(state: Dictionary, kind: String, person_id: String) -> int:
	var last: int = -9999
	for event: Dictionary in state.relationships.get("history", []):
		if event.get("kind") == "social_event" and str(event.get("event_type", "")) == kind and str(event.get("person_id", "")) == person_id:
			last = maxi(last, int(event.get("year", -9999)))
	return last

static func collect_candidates(state: Dictionary) -> Array[Dictionary]:
	Relationships.normalize(state)
	var out: Array[Dictionary] = []
	var year: int = int(state.world.year)
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if not rel.alive:
			continue
		if rel.role in ["parent", "child", "family", "spouse"]:
			continue
		if int(rel.conflict) >= 60 and year - _last_event_year(state,"conflict",id) >= 2:
			out.append({"type":"conflict","person_id":id,"weight":20 + int(rel.conflict)})
		if rel.stage == "romantic_interest" and int(rel.closeness) >= 55 and int(rel.attraction) >= 55 and year - _last_event_year(state,"romance_progress",id) >= 2:
			out.append({"type":"romance_progress","person_id":id,"weight":25 + int(rel.attraction)})
		if rel.stage == "dating" and int(rel.conflict) >= 45 and year - _last_event_year(state,"relationship_strain",id) >= 2:
			out.append({"type":"relationship_strain","person_id":id,"weight":20 + int(rel.conflict)})
		if rel.stage in ["friend","close_friend"] and int(rel.closeness) >= 65 and year - _last_event_year(state,"friend_support",id) >= 3:
			out.append({"type":"friend_support","person_id":id,"weight":15 + int(rel.closeness)})
		if int(rel.last_contact_year) <= year - 3 and int(rel.closeness) >= 35 and year - _last_event_year(state,"reconnect",id) >= 4:
			out.append({"type":"reconnect","person_id":id,"weight":18})
	return out

static func resolve_one(state: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = collect_candidates(state)
	if candidates.is_empty():
		return {}
	var weights: Array[int] = []
	for c: Dictionary in candidates:
		weights.append(int(c.weight))
	var seed: int = str(state.meta.master_seed).to_int()
	var idx: int = Rng.weighted(seed, "social_events", int(state.world.year), str(state.meta.player_id), "pick", weights)
	var selected: Dictionary = candidates[idx]
	return _apply(state, selected)

static func _apply(state: Dictionary, event: Dictionary) -> Dictionary:
	var id: String = str(event.person_id)
	var rel: Dictionary = state.relationships.people[id]
	var year: int = int(state.world.year)
	var kind: String = str(event.type)
	var title: String = ""
	var text: String = ""
	match kind:
		"conflict":
			title = "Gerilim tırmandı"
			text = "%s ile aranızdaki gerilim açık bir tartışmaya dönüştü." % rel.name
			Relationships.interact(state,id,"argue")
		"romance_progress":
			title = "Aranızdaki bağ değişiyor"
			text = "%s ile ilişkiniz arkadaşlığın ötesine geçmeye başladı." % rel.name
			Relationships.interact(state,id,"flirt")
			Relationships.interact(state,id,"spend_time")
		"relationship_strain":
			title = "İlişkide gerginlik"
			text = "%s ile ilişkinizde bir süredir biriken sorunlar yüzeye çıktı." % rel.name
			rel.conflict = clampi(int(rel.conflict) + 12,0,100)
			rel.trust = clampi(int(rel.trust) - 8,0,100)
			Relationships.normalize(state)
		"friend_support":
			title = "Bir dostun yanında"
			text = "%s zor bir dönemde sana destek oldu." % rel.name
			rel.trust = clampi(int(rel.trust) + 8,0,100)
			rel.closeness = clampi(int(rel.closeness) + 6,0,100)
			var p: Dictionary = state.actors[state.meta.player_id]
			p.needs.stress = clampi(int(p.needs.stress) - 8,0,100)
			p.needs.happiness = clampi(int(p.needs.happiness) + 5,0,100)
		"reconnect":
			title = "Yıllar sonra yeniden"
			text = "%s ile uzun bir aradan sonra tekrar görüştünüz." % rel.name
			rel.closeness = clampi(int(rel.closeness) + 10,0,100)
			rel.contact = clampi(int(rel.contact) + 20,0,100)
			rel.last_contact_year = year
	state.relationships.history.append({"year":year,"kind":"social_event","event_type":kind,"person_id":id})
	state.history.append({
		"id":"%d:social_event:%s:%s" % [year,kind,id],
		"year":year,"kind":"social_event","cause_id":"",
		"details":{"event_type":kind,"person_id":id,"title":title,"text":text}
	})
	return {"type":kind,"person_id":id,"title":title,"text":text}
