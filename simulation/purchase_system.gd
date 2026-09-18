extends RefCounted

const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const Needs = preload("res://simulation/needs_system.gd")
const Relationships = preload("res://simulation/relationship_system.gd")

const CATALOG_PATH := "res://content/manchester_spending.json"

static var _catalog_cache: Dictionary = {}

static func _catalog() -> Dictionary:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	if not FileAccess.file_exists(CATALOG_PATH):
		return {"items": []}
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_catalog_cache = parsed
	else:
		_catalog_cache = {"items": []}
	return _catalog_cache

static func items_by_id() -> Dictionary:
	var out: Dictionary = {}
	for item: Dictionary in _catalog().get("items", []):
		out[item.id] = item
	return out

static func available_items(state: Dictionary, category: String = "") -> Array[Dictionary]:
	PersonalEconomy.normalize(state)
	var p: Dictionary = state.actors[state.meta.player_id]
	var year := int(state.world.year)
	var cash := int(state.personal_economy.cash)
	var out: Array[Dictionary] = []
	for raw: Variant in _catalog().get("items", []):
		if not raw is Dictionary:
			continue
		var item: Dictionary = raw
		if category != "" and str(item.category) != category:
			continue
		if int(p.age) < int(item.get("min_age", 0)):
			continue
		if item.has("max_age") and int(p.age) > int(item.max_age):
			continue
		if year < int(item.get("min_year", 0)):
			continue
		if item.has("max_year") and year > int(item.max_year):
			continue
		if int(item.cost) > cash:
			continue
		out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.label) < str(b.label))
	return out

static func purchase(state: Dictionary, item_id: String) -> Dictionary:
	var by_id := items_by_id()
	if not by_id.has(item_id):
		return {"ok": false, "error": "Unknown purchase item: " + item_id}
	var item: Dictionary = by_id[item_id]
	var allowed := false
	for candidate: Dictionary in available_items(state):
		if candidate.id == item_id:
			allowed = true
			break
	if not allowed:
		return {"ok": false, "error": "Purchase is not available right now: " + item_id}
	var spend_result := PersonalEconomy.spend(state, int(item.cost), str(item.category), item_id)
	if not spend_result.ok:
		return spend_result
	var p: Dictionary = state.actors[state.meta.player_id]
	Needs.normalize_actor(p)
	for key: String in ["health", "literacy", "willpower"]:
		if item.get("effects", {}).has(key):
			p[key] = clampi(int(p[key]) + int(item.effects[key]), 0, 100)
	for key: String in ["happiness", "stress", "social", "energy"]:
		if item.get("effects", {}).has(key):
			p.needs[key] = clampi(int(p.needs[key]) + int(item.effects[key]), 0, 100)
	if str(item.category) == "social" and item_id in ["gift_small", "flower_purchase"]:
		Relationships.socialize(state)
	state.history.append({
		"id": "%d:purchase:%s:%d" % [int(state.world.year), item_id, state.history.size()],
		"year": int(state.world.year), "kind": "purchase", "cause_id": "",
		"details": {"item_id": item_id, "label": item.label, "category": item.category, "cost": item.cost}
	})
	return {"ok": true, "item": item}
