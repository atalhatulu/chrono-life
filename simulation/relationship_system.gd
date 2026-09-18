extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")

static func initialize(state: Dictionary) -> void:
	if not state.has("relationships"):
		state.relationships = {"people": {}}
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	for id: String in state.actors:
		if id == player_id:
			continue
		var actor: Dictionary = state.actors[id]
		var role := "family"
		if id.begins_with("parent"):
			role = "parent"
		state.relationships.people[id] = {
			"id": id, "name": actor.name, "role": role, "closeness": 65,
			"trust": 60, "conflict": 10, "alive": actor.alive
		}

static func normalize(state: Dictionary) -> void:
	initialize(state)
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		for key: String in ["closeness", "trust", "conflict"]:
			rel[key] = clampi(int(rel.get(key, 0)), 0, 100)
		if state.actors.has(id):
			rel.alive = bool(state.actors[id].alive)

static func annual_drift(state: Dictionary) -> void:
	normalize(state)
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if not rel.alive:
			continue
		rel.closeness = clampi(int(rel.closeness) - 2, 0, 100)
		rel.conflict = clampi(int(rel.conflict) - 1, 0, 100)

static func spend_time_with_family(state: Dictionary) -> Dictionary:
	normalize(state)
	var changed := 0
	for id: String in state.relationships.people:
		var rel: Dictionary = state.relationships.people[id]
		if rel.alive and rel.role in ["parent", "family"]:
			rel.closeness = clampi(int(rel.closeness) + 8, 0, 100)
			rel.trust = clampi(int(rel.trust) + 4, 0, 100)
			rel.conflict = clampi(int(rel.conflict) - 3, 0, 100)
			changed += 1
	return {"changed": changed}

static func make_friend(state: Dictionary) -> String:
	normalize(state)
	var player: Dictionary = state.actors[state.meta.player_id]
	var year := int(state.world.year)
	var friend_id := "friend_%d" % year
	if state.relationships.people.has(friend_id):
		return friend_id
	var seed := str(state.meta.master_seed).to_int()
	var names := ["Arthur", "George", "Eleanor", "Clara", "Henry", "Alice", "Samuel", "Florence"]
	var index := Rng.integer(seed, "relationships", year, str(player.id), "friend_name", 0, names.size() - 1)
	state.relationships.people[friend_id] = {"id": friend_id, "name": names[index],
		"role": "friend", "closeness": 45, "trust": 35, "conflict": 5, "alive": true}
	return friend_id

static func socialize(state: Dictionary) -> Dictionary:
	normalize(state)
	var friends: Array[String] = []
	for id: String in state.relationships.people:
		if state.relationships.people[id].role == "friend" and state.relationships.people[id].alive:
			friends.append(id)
	if friends.is_empty():
		var new_id := make_friend(state)
		return {"friend_id": new_id, "new_friend": true}
	friends.sort()
	var id := friends[0]
	var rel: Dictionary = state.relationships.people[id]
	rel.closeness = clampi(int(rel.closeness) + 10, 0, 100)
	rel.trust = clampi(int(rel.trust) + 5, 0, 100)
	return {"friend_id": id, "new_friend": false}
