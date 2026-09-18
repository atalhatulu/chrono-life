extends RefCounted

const PersonalEconomy = preload("res://simulation/personal_economy_system.gd")
const Skills = preload("res://simulation/skill_system.gd")

static var _cache: Dictionary = {}

static func _catalog(state: Dictionary) -> Dictionary:
	var path: String = str(state.get("meta", {}).get("assets_path", ""))
	if path.is_empty():
		return {"assets": []}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"assets": []}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"assets": []}
	return _cache[path]

static func initialize(state: Dictionary) -> void:
	if not state.has("assets"):
		state.assets = {"owned": {}, "history": []}
	for asset: Dictionary in _catalog(state).get("assets", []):
		if bool(asset.get("initial", false)) and not state.assets.owned.has(asset.id):
			state.assets.owned[asset.id] = {
				"acquired_year": int(state.world.year),
				"value": int(asset.get("base_value", 0)),
				"quantity": 1
			}

static func definitions(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for a: Dictionary in _catalog(state).get("assets", []):
		out[a.id] = a
	return out

static func available_assets(state: Dictionary) -> Array[Dictionary]:
	initialize(state)
	PersonalEconomy.normalize(state)
	var player: Dictionary = state.actors[state.meta.player_id]
	var out: Array[Dictionary] = []
	for asset: Dictionary in _catalog(state).get("assets", []):
		if int(player.age) < int(asset.get("min_age", 0)):
			continue
		if int(asset.get("acquire_cost", 0)) > int(state.personal_economy.cash):
			continue
		if state.assets.owned.has(asset.id) and not bool(asset.get("stackable", false)):
			continue
		out.append(asset)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("acquire_cost", 0)) < int(b.get("acquire_cost", 0)))
	return out

static func acquire(state: Dictionary, asset_id: String) -> Dictionary:
	initialize(state)
	var defs: Dictionary = definitions(state)
	if not defs.has(asset_id):
		return {"ok": false, "error": "Unknown asset"}
	var allowed: bool = false
	for asset: Dictionary in available_assets(state):
		if str(asset.id) == asset_id:
			allowed = true
			break
	if not allowed:
		return {"ok": false, "error": "Asset unavailable"}
	var asset: Dictionary = defs[asset_id]
	var cost: int = int(asset.get("acquire_cost", 0))
	if cost > 0:
		var spend: Dictionary = PersonalEconomy.spend(state, cost, "asset", asset_id)
		if not spend.ok:
			return spend
	var entry: Dictionary = state.assets.owned.get(asset_id, {
		"acquired_year": int(state.world.year), "value": int(asset.get("base_value", cost)), "quantity": 0
	})
	entry.quantity = int(entry.get("quantity", 0)) + 1
	entry.value = int(entry.get("value", 0)) + (0 if int(entry.quantity) == 1 else int(asset.get("base_value", cost)))
	state.assets.owned[asset_id] = entry
	for skill_id: String in asset.get("skill_bonus", {}):
		Skills.add_xp(state, str(state.meta.player_id), skill_id, int(asset.skill_bonus[skill_id]) * 5, "asset:" + asset_id)
	state.assets.history.append({"year": int(state.world.year), "kind": "acquired", "asset_id": asset_id, "cost": cost})
	state.history.append({"id":"%d:asset:%s:%d" % [int(state.world.year), asset_id, state.history.size()],
		"year":int(state.world.year),"kind":"asset_acquired","cause_id":"",
		"details":{"asset_id":asset_id,"cost":cost}})
	return {"ok": true, "asset": asset}

static func annual_update(state: Dictionary) -> void:
	initialize(state)
	var defs: Dictionary = definitions(state)
	for asset_id: String in state.assets.owned:
		if not defs.has(asset_id):
			continue
		var entry: Dictionary = state.assets.owned[asset_id]
		var dep: int = int(defs[asset_id].get("depreciation_permille", 0))
		if dep > 0:
			entry.value = maxi(0, int(entry.value) * (1000 - dep) / 1000)

static func total_value(state: Dictionary) -> int:
	initialize(state)
	var total: int = 0
	for asset_id: String in state.assets.owned:
		total += int(state.assets.owned[asset_id].get("value", 0))
	return total


static func liquidate(state: Dictionary, asset_id: String) -> Dictionary:
	initialize(state)
	var defs: Dictionary = definitions(state)
	if not defs.has(asset_id) or not state.assets.owned.has(asset_id):
		return {"ok": false, "error": "Asset is not owned"}
	var entry: Dictionary = state.assets.owned[asset_id]
	var quantity: int = int(entry.get("quantity", 1))
	if quantity <= 0:
		return {"ok": false, "error": "Asset is not owned"}
	var definition: Dictionary = defs[asset_id]
	var unit_value: int = int(entry.get("value", 0)) / maxi(quantity, 1)
	var proceeds: int = int(unit_value * int(definition.get("liquidate_permille", 700)) / 1000.0)
	entry.quantity = quantity - 1
	entry.value = maxi(0, int(entry.value) - unit_value)
	if int(entry.quantity) <= 0:
		state.assets.owned.erase(asset_id)
	else:
		state.assets.owned[asset_id] = entry
	if proceeds > 0:
		PersonalEconomy.grant_income(state, proceeds, "asset_liquidation:" + asset_id)
	state.assets.history.append({"year": int(state.world.year), "kind": "liquidated",
		"asset_id": asset_id, "proceeds": proceeds})
	state.history.append({"id":"%d:asset_liquidated:%s:%d" % [int(state.world.year), asset_id, state.history.size()],
		"year":int(state.world.year),"kind":"asset_liquidated","cause_id":"",
		"details":{"asset_id":asset_id,"proceeds":proceeds}})
	return {"ok": true, "proceeds": proceeds}


static func remove_asset(state: Dictionary, asset_id: String, reason: String = "removed") -> bool:
	initialize(state)
	if not state.assets.owned.has(asset_id):
		return false
	var entry: Dictionary = state.assets.owned[asset_id]
	var quantity: int = int(entry.get("quantity", 1))
	if quantity <= 1:
		state.assets.owned.erase(asset_id)
	else:
		var unit_value: int = int(entry.get("value", 0)) / maxi(quantity, 1)
		entry.quantity = quantity - 1
		entry.value = maxi(0, int(entry.value) - unit_value)
		state.assets.owned[asset_id] = entry
	state.assets.history.append({"year": int(state.world.year), "kind": reason, "asset_id": asset_id})
	state.history.append({"id":"%d:asset_removed:%s:%d" % [int(state.world.year), asset_id, state.history.size()],
		"year":int(state.world.year),"kind":"asset_removed","cause_id":"",
		"details":{"asset_id":asset_id,"reason":reason}})
	return true
