extends RefCounted

static var _cache: Dictionary = {}

static func _catalog(state: Dictionary) -> Dictionary:
	var path := str(state.get("meta", {}).get("status_path", ""))
	if path.is_empty():
		return {"weights": {}, "bands": []}
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		return {"weights": {}, "bands": []}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_cache[path] = parsed if parsed is Dictionary else {"weights": {}, "bands": []}
	return _cache[path]

static func initialize(state: Dictionary) -> void:
	if not state.has("social_status"):
		state.social_status = {"score": 0, "band_id": "", "history": [], "components": {}}

static func _occupation_component(state: Dictionary) -> int:
	var p: Dictionary = state.actors[state.meta.player_id]
	var career: Dictionary = p.get("career", {})
	return clampi(int(career.get("highest_level", 0)) * 20, 0, 100)

static func _education_component(state: Dictionary) -> int:
	var p: Dictionary = state.actors[state.meta.player_id]
	var completed: Array = p.get("education", {}).get("completed_stages", [])
	return clampi(int(p.literacy) / 2 + completed.size() * 15, 0, 100)

static func _housing_component(state: Dictionary) -> int:
	var path := str(state.get("meta", {}).get("housing_path", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return 50
	var parsed: Variant = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if not parsed is Dictionary:
		return 50
	for d: Dictionary in parsed.get("dwellings", []):
		if str(d.id) == str(state.housing.dwelling_id):
			return clampi(int(d.get("quality", 50)), 0, 100)
	return 50

static func recompute(state: Dictionary) -> void:
	initialize(state)
	var p: Dictionary = state.actors[state.meta.player_id]
	var household_income := int(state.household.income)
	var wealth := int(state.household.savings) + int(state.get("personal_economy", {}).get("cash", 0))
	for asset_id: String in state.get("assets", {}).get("owned", {}):
		wealth += int(state.assets.owned[asset_id].get("value", 0))
	var components := {
		"income": clampi(household_income / 80, 0, 100),
		"wealth": clampi(wealth / 80, 0, 100),
		"occupation": _occupation_component(state),
		"education": _education_component(state),
		"housing": _housing_component(state),
		"community": clampi(int(p.get("personality", {}).get("axes", {}).get("sociability", 50)), 0, 100)
	}
	var weights: Dictionary = _catalog(state).get("weights", {})
	var total_weight := 0
	var weighted := 0
	for key: String in components:
		var w := int(weights.get(key, 0))
		total_weight += w
		weighted += int(components[key]) * w
	var score := 0 if total_weight <= 0 else int(weighted / total_weight)
	var band_id := ""
	for band: Dictionary in _catalog(state).get("bands", []):
		if score >= int(band.get("min_score", 0)):
			band_id = str(band.id)
	var changed := band_id != str(state.social_status.get("band_id", ""))
	state.social_status.score = score
	state.social_status.band_id = band_id
	state.social_status.components = components
	if changed:
		state.social_status.history.append({"year": int(state.world.year), "band_id": band_id, "score": score})
