extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

static func initialize(state: Dictionary) -> void:
	if not state.has("personal_economy"):
		state.personal_economy = {
			"cash": 0,
			"lifetime_income": 0,
			"lifetime_spending": 0,
			"year_income": 0,
			"year_spending": 0,
			"purchases": [],
			"owned_items": {},
			"memberships": {},
			"last_purchase_year": {},
			"last_allowance_year": -1
		}

static func normalize(state: Dictionary) -> void:
	initialize(state)
	for key: String in ["cash", "lifetime_income", "lifetime_spending", "year_income", "year_spending"]:
		state.personal_economy[key] = maxi(0, int(state.personal_economy.get(key, 0)))

static func begin_year(state: Dictionary) -> void:
	normalize(state)
	state.personal_economy.year_income = 0
	state.personal_economy.year_spending = 0
	var year := int(state.world.year)
	var expired: Array[String] = []
	for id: String in state.personal_economy.memberships:
		if int(state.personal_economy.memberships[id].get("expires_year", year)) < year:
			expired.append(id)
	for id: String in expired:
		state.personal_economy.memberships.erase(id)

static func grant_income(state: Dictionary, amount: int, source: String) -> void:
	if amount <= 0:
		return
	normalize(state)
	state.personal_economy.cash += amount
	state.personal_economy.year_income += amount
	state.personal_economy.lifetime_income += amount
	state.history.append({
		"id": "%d:personal_income:%s:%d" % [int(state.world.year), source, state.history.size()],
		"year": int(state.world.year), "kind": "personal_income", "cause_id": "",
		"details": {"amount": amount, "source": source}
	})

static func spend(state: Dictionary, amount: int, category: String, item_id: String = "") -> Dictionary:
	normalize(state)
	if amount <= 0:
		return {"ok": false, "error": "Amount must be positive"}
	if int(state.personal_economy.cash) < amount:
		return {"ok": false, "error": "Not enough personal cash"}
	state.personal_economy.cash -= amount
	state.personal_economy.year_spending += amount
	state.personal_economy.lifetime_spending += amount
	var purchase := {"year": int(state.world.year), "amount": amount, "category": category, "item_id": item_id}
	state.personal_economy.purchases.append(purchase)
	state.history.append({
		"id": "%d:personal_spending:%s:%d" % [int(state.world.year), category, state.history.size()],
		"year": int(state.world.year), "kind": "personal_spending", "cause_id": "",
		"details": purchase
	})
	return {"ok": true}

static func annual_income_share(state: Dictionary) -> int:
	normalize(state)
	var p: Dictionary = state.actors[state.meta.player_id]
	if not p.alive or int(p.income) <= 0:
		return 0
	var age := int(p.age)
	var permille := 0
	if age < 16:
		permille = 150
	elif age < 21:
		permille = 250
	else:
		permille = 350
	return int(int(p.income) * permille / 1000.0)

static func settle_year(state: Dictionary) -> void:
	var share := annual_income_share(state)
	if share > 0:
		grant_income(state, share, "wage_share")

static func maybe_allowance(state: Dictionary) -> void:
	normalize(state)
	var p: Dictionary = state.actors[state.meta.player_id]
	var year := int(state.world.year)
	if int(p.age) < 7 or int(p.age) > 15:
		return
	if int(state.personal_economy.last_allowance_year) == year:
		return
	if int(state.household.savings) <= 0:
		return
	var seed := str(state.meta.master_seed).to_int()
	var amount := Rng.integer(seed, "personal_economy", year, str(p.id), "allowance", 5, 25)
	grant_income(state, amount, "allowance")
	state.personal_economy.last_allowance_year = year
