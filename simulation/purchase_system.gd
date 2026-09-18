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

static func _can_repurchase(state: Dictionary, item: Dictionary) -> bool:
	var economy: Dictionary = state.personal_economy
	var year := int(state.world.year)
	var item_id := str(item.id)
	var last_year := int(economy.last_purchase_year.get(item_id, -9999))
	var purchase_type := str(item.get("purchase_type", "consumable"))
	if purchase_type == "durable":
		var owned: Dictionary = economy.owned_items.get(item_id, {})
		if not owned.is_empty():
			var bought_year := int(owned.get("year", last_year))
			if year - bought_year < int(item.get("repurchase_years", 5)):
				return false
	elif purchase_type == "membership":
		var membership: Dictionary = economy.memberships.get(item_id, {})
		if not membership.is_empty() and int(membership.get("expires_year", year - 1)) >= year:
			return false
	var cooldown := int(item.get("cooldown_years", 0))
	return cooldown <= 0 or year - last_year >= cooldown


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
		if not _can_repurchase(state, item):
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
	var year := int(state.world.year)
	var purchase_type := str(item.get("purchase_type", "consumable"))
	state.personal_economy.last_purchase_year[item_id] = year
	if purchase_type == "durable":
		state.personal_economy.owned_items[item_id] = {
			"year": year, "label": item.label, "category": item.category,
			"replacement_after": year + int(item.get("repurchase_years", 5))
		}
	elif purchase_type == "membership":
		state.personal_economy.memberships[item_id] = {
			"year": year, "label": item.label,
			"expires_year": year + int(item.get("membership_years", 1)) - 1
		}
	elif purchase_type == "household_contribution":
		var contribution := maxi(1, int(item.cost / 2))
		state.household.savings += contribution
		state.history.append({
			"id": "%d:household_contribution:%s:%d" % [year, item_id, state.history.size()],
			"year": year, "kind": "household_contribution", "cause_id": "",
			"details": {"item_id": item_id, "amount": contribution}
		})
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
		"details": {"item_id": item_id, "label": item.label, "category": item.category, "cost": item.cost, "purchase_type": purchase_type}
	})
	return {"ok": true, "item": item}


static func owned_items(state: Dictionary) -> Array[Dictionary]:
	PersonalEconomy.normalize(state)
	var out: Array[Dictionary] = []
	for id: String in state.personal_economy.owned_items:
		var entry: Dictionary = state.personal_economy.owned_items[id].duplicate(true)
		entry.id = id
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.label) < str(b.label))
	return out


static func active_memberships(state: Dictionary) -> Array[Dictionary]:
	PersonalEconomy.normalize(state)
	var out: Array[Dictionary] = []
	for id: String in state.personal_economy.memberships:
		var entry: Dictionary = state.personal_economy.memberships[id].duplicate(true)
		entry.id = id
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.label) < str(b.label))
	return out
