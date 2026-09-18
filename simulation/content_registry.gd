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
	errors.append_array(_validate_life(pack))
	return errors


static func _validate_life(pack: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["systems", "world_rules", "health_rules", "education_rules", "response_rules"]:
		if not pack.get(key) is Dictionary:
			errors.append(key + " must be an object")
	if not pack.get("conditions") is Array:
		errors.append("conditions must be an array")
	if not errors.is_empty():
		return errors
	for key: String in ["health", "education", "adaptation"]:
		if not pack.systems.get(key) is bool:
			errors.append("systems." + key + " must be a boolean")
	if pack.systems.has("storylets") and not pack.systems.storylets is bool:
		errors.append("systems.storylets must be a boolean")
	if pack.systems.has("family") and not pack.systems.family is bool:
		errors.append("systems.family must be a boolean")
	if pack.has("family_rules"):
		if not pack.family_rules is Dictionary:
			errors.append("family_rules must be an object")
		else:
			for key: String in ["min_marriage_age", "max_marriage_age", "marriage_savings_threshold",
					"conception_chance_permille", "min_birth_interval_years", "max_children", "maternal_health_cost"]:
				if not is_integer(pack.family_rules.get(key)) or float(pack.family_rules.get(key, -1)) < 0:
					errors.append("Invalid family rule: " + key)
			_check_range(pack.family_rules, "conception_chance_permille", 0, 1000, errors)
	for key: String in ["disease_min", "disease_max", "employment_min", "employment_max"]:
		_check_range(pack.world_rules, key, 0, 1000, errors)
	for prefix: String in ["disease", "employment"]:
		var min_val: Variant = pack.world_rules.get(prefix + "_min")
		var max_val: Variant = pack.world_rules.get(prefix + "_max")
		if is_integer(min_val) and is_integer(max_val) and int(min_val) > int(max_val):
			errors.append("Invalid world pressure range: " + prefix)
	_check_range(pack.health_rules, "death_worked_permille", 0, 1000, errors)
	for key: String in ["start_age", "completion_age"]:
		_check_range(pack.education_rules, key, 1, 100, errors)
	for key: String in ["literacy_per_year", "minimum_health"]:
		_check_range(pack.education_rules, key, 0, 100, errors)
	var start_age: Variant = pack.education_rules.get("start_age")
	var comp_age: Variant = pack.education_rules.get("completion_age")
	if is_integer(start_age) and is_integer(comp_age) and int(start_age) >= int(comp_age):
		errors.append("School completion age must follow start age")
	for key: String in ["reserve_years", "minimum_work_capacity", "aid_amount", "aid_max_uses", "orphan_support_per_child"]:
		_check_range(pack.response_rules, key, 0, 100000, errors)
	if not pack.response_rules.get("weights") is Dictionary:
		errors.append("response weights must be an object")
	else:
		for key: String in ["wait", "adult_work", "child_work", "seek_aid"]:
			_check_range(pack.response_rules.weights, key, 0, 10000, errors)
		var wait_weight: Variant = pack.response_rules.weights.get("wait")
		if is_integer(wait_weight) and int(wait_weight) < 1:
			errors.append("wait must have a positive fallback weight")
	if not pack.health_rules.get("mortality_bands") is Array or pack.health_rules.get("mortality_bands", []).is_empty():
		errors.append("Nonempty mortality bands required")
	else:
		var previous_age: int = -1
		for band: Variant in pack.health_rules.mortality_bands:
			if not band is Dictionary:
				errors.append("Mortality band must be an object")
				continue
			_check_range(band, "minimum_age", 0, 200, errors)
			_check_range(band, "risk_bp", 0, 10000, errors)
			if is_integer(band.get("minimum_age")):
				if int(band.minimum_age) <= previous_age or (previous_age == -1 and band.minimum_age != 0):
					errors.append("Mortality bands must begin at zero and increase")
				previous_age = int(band.minimum_age)
	var condition_ids: Dictionary = {}
	for definition: Variant in pack.conditions:
		if not definition is Dictionary:
			errors.append("Condition must be an object")
			continue
		if not definition.get("id") is String or str(definition.get("id", "")).is_empty():
			errors.append("Condition id required")
		elif condition_ids.has(definition.id):
			errors.append("Duplicate condition: " + definition.id)
		else:
			condition_ids[definition.id] = true
		if definition.get("exposure") not in ["ambient", "work", "nutrition"]:
			errors.append("Unknown condition exposure")
		for key: String in ["incidence_bp", "mortality_bp"]:
			_check_range(definition, key, 0, 10000, errors)
		for key: String in ["food_threshold", "work_penalty"]:
			_check_range(definition, key, 0, 1000, errors)
		_check_range(definition, "duration_years", 0, 100, errors)
		_check_range(definition, "health_penalty", 0, 100, errors)
	for occupation: Dictionary in pack.occupations:
		_check_range(occupation, "maximum_age", 0, 200, errors)
		_check_range(occupation, "minimum_literacy", 0, 100, errors)
		_check_range(occupation, "risk_permille", 0, 1000, errors)
		var max_age: Variant = occupation.get("maximum_age")
		var min_age: Variant = occupation.get("minimum_age")
		if is_integer(max_age) and is_integer(min_age) and int(max_age) < int(min_age):
			errors.append("Invalid occupation age range")
	if pack.has("storylets"):
		if not pack.storylets is Array:
			errors.append("storylets must be an array")
		else:
			var storylet_ids: Dictionary = {}
			for entry: Variant in pack.storylets:
				if not entry is Dictionary:
					errors.append("Storylet must be an object")
					continue
				for key: String in ["id", "family", "title", "text"]:
					if not entry.get(key) is String or str(entry.get(key, "")).is_empty():
						errors.append("Storylet requires " + key)
				if storylet_ids.has(entry.get("id")):
					errors.append("Duplicate storylet: " + str(entry.get("id")))
				storylet_ids[entry.get("id")] = true
				if not entry.get("requirements") is Dictionary or not entry.get("utility") is Dictionary or \
						not entry.get("choices") is Array or entry.get("choices", []).is_empty():
					errors.append("Invalid storylet structure: " + str(entry.get("id")))
					continue
				_check_range(entry.utility, "base", 0, 1000, errors)
				var choice_ids: Dictionary = {}
				for choice: Variant in entry.choices:
					if not choice is Dictionary or not choice.get("id") is String or str(choice.get("id", "")).is_empty() or \
							not choice.get("label") is String or not choice.get("effects") is Dictionary:
						errors.append("Invalid storylet choice")
						continue
					if choice_ids.has(choice.id):
						errors.append("Duplicate storylet choice: " + choice.id)
					choice_ids[choice.id] = true
	return errors


static func _check_range(object: Dictionary, key: String, minimum: int, maximum: int,
		errors: Array[String]) -> void:
	if not is_integer(object.get(key)) or float(object[key]) < minimum or float(object[key]) > maximum:
		errors.append("%s must be an integer in [%d, %d]" % [key, minimum, maximum])


static func occupations_by_id(pack: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in pack.occupations:
		result[entry.id] = entry
	return result
