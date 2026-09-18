extends RefCounted

static func initialize_actor(actor: Dictionary) -> void:
	if not actor.has("needs"):
		actor.needs = {"happiness": 55, "stress": 20, "social": 50, "energy": 70}

static func normalize_actor(actor: Dictionary) -> void:
	initialize_actor(actor)
	for key: String in ["happiness", "stress", "social", "energy"]:
		actor.needs[key] = clampi(int(actor.needs.get(key, 50)), 0, 100)

static func annual_drift(actor: Dictionary) -> void:
	normalize_actor(actor)
	actor.needs.energy = clampi(int(actor.needs.energy) - 8, 0, 100)
	actor.needs.social = clampi(int(actor.needs.social) - 6, 0, 100)
	actor.needs.stress = clampi(int(actor.needs.stress) + 4, 0, 100)
	if int(actor.health) < 40:
		actor.needs.happiness = clampi(int(actor.needs.happiness) - 5, 0, 100)
