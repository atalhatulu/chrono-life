extends RefCounted

const DEFAULT_PATH: String = "res://content/manchester_test.json"


static func load_pack(path: String = DEFAULT_PATH) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "errors": ["Cannot read content: " + path]}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "errors": ["Invalid JSON at line %d: %s" %
			[parser.get_error_line(), parser.get_error_message()]]}
	if not parser.data is Dictionary:
		return {"ok": false, "errors": ["Content root must be an object"]}
	var errors: Array[String] = validate(parser.data)
	return {"ok": errors.is_empty(), "errors": errors, "pack": parser.data}


static func is_integer(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floor(value))


static func validate(pack: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["version", "location_id", "currency_unit", "player_id"]:
		if not pack.get(key) is String or str(pack.get(key, "")).is_empty():
			errors.append("Missing/nonempty string required: " + key)
	if not is_integer(pack.get("start_year")):
		errors.append("start_year must be an integer")
	if not pack.get("historically_calibrated") is bool:
		errors.append("historically_calibrated must be a boolean")
	for key: String in ["economy", "limits"]:
		if not pack.get(key) is Dictionary:
			errors.append(key + " must be an object")
	for key: String in ["occupations", "actors"]:
		if not pack.get(key) is Array or pack.get(key, []).is_empty():
			errors.append(key + " must be a nonempty array")
	if not errors.is_empty():
		return errors
	var economy: Dictionary = pack.economy
	for key: String in ["initial_index", "minimum_index", "maximum_index", "annual_drift",
			"food_initial_index", "food_minimum_index", "food_maximum_index", "food_annual_drift",
			"rent", "adult_food", "child_food", "adult_age", "essentials_per_person",
			"initial_savings", "credit_limit", "debt_interest_basis_points"]:
		if not is_integer(economy.get(key)) or float(economy.get(key, -1)) < 0:
			errors.append("economy.%s must be a nonnegative integer" % key)
	for key: String in ["max_years", "max_consequences"]:
		if not is_integer(pack.limits.get(key)) or float(pack.limits.get(key, 0)) < 1:
			errors.append("limits.%s must be a positive integer" % key)
	if not errors.is_empty():
		return errors
	for prefix: String in ["", "food_"]:
		if economy[prefix + "minimum_index"] < 1 or \
				economy[prefix + "minimum_index"] > economy[prefix + "initial_index"] or \
				economy[prefix + "initial_index"] > economy[prefix + "maximum_index"]:
			errors.append(prefix + "index range is invalid")
	if economy.adult_age < 1 or economy.debt_interest_basis_points > 10000:
		errors.append("Invalid adult age or interest rate")
	var occupations: Dictionary = {}
	for entry: Variant in pack.occupations:
		if not entry is Dictionary:
			errors.append("Occupation must be an object")
			continue
		if not entry.get("id") is String or str(entry.get("id", "")).is_empty():
			errors.append("Occupation requires an id")
			continue
		if occupations.has(entry.id):
			errors.append("Duplicate occupation: " + entry.id)
		occupations[entry.id] = entry
		for key: String in ["annual_income", "minimum_age"]:
			if not is_integer(entry.get(key)) or float(entry.get(key, -1)) < 0:
				errors.append("Invalid occupation field: " + key)
	if not occupations.has("dependent"):
		errors.append("A dependent occupation is required")
	elif occupations.dependent.get("annual_income") != 0 or occupations.dependent.get("minimum_age") != 0:
		errors.append("dependent must be available at birth with zero income")
	if not errors.is_empty():
		return errors
	var ids: Dictionary = {}
	for entry: Variant in pack.actors:
		if not entry is Dictionary:
			errors.append("Actor must be an object")
			continue
		for key: String in ["id", "name", "occupation_id"]:
			if not entry.get(key) is String or str(entry.get(key, "")).is_empty():
				errors.append("Actor requires " + key)
		if not is_integer(entry.get("birth_year")):
			errors.append("Actor birth_year must be an integer")
		if not errors.is_empty():
			continue
		if ids.has(entry.id):
			errors.append("Duplicate actor: " + entry.id)
		ids[entry.id] = true
		if not occupations.has(entry.occupation_id):
			errors.append("Unknown occupation: " + entry.occupation_id)
		elif pack.start_year - entry.birth_year < occupations[entry.occupation_id].minimum_age:
			errors.append("Actor too young for occupation: " + entry.id)
	if not ids.has(pack.player_id):
		errors.append("player_id does not reference an actor")
	return errors


static func occupations_by_id(pack: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in pack.occupations:
		result[entry.id] = entry
	return result
