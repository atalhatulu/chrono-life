extends RefCounted
## Direct consequences only. Behavioral responses are selected elsewhere.

const Career = preload("res://simulation/career_system.gd")


static func process(delta: RefCounted, commands: Array, earned: Dictionary,
		participation: Dictionary, parent_event: String, limit: int) -> Dictionary:
	var queue: Array = commands.duplicate(true)
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.worked_permille != b.worked_permille:
			return a.worked_permille < b.worked_permille
		if a.type != b.type:
			return a.type == "actor_died"
		return a.id < b.id)
	var full_earnings: Dictionary = earned.duplicate()
	var cutoffs: Dictionary = {}
	var seen: Dictionary = {}
	var event_ids: Array[String] = []
	var count: int = 0
	while not queue.is_empty():
		var trigger: Dictionary = queue.pop_front()
		var key: String = str(trigger.id) + ":" + str(trigger.type)
		if seen.has(key):
			continue
		seen[key] = true
		count += 1
		if count > limit:
			return {"ok": false, "errors": ["Consequence limit exceeded; year rolled back"]}
		var id: String = trigger.actor_id
		var actor: Dictionary = delta.candidate.actors[id]
		var source: String = str(trigger.get("cause_id", parent_event))
		if trigger.type == "income_lost":
			event_ids.append(delta.record("income_lost", source,
				{"actor_id": id, "retained_earnings": earned[id]}))
			continue
		if not actor.alive or (trigger.type == "job_lost" and actor.occupation_id == "dependent"):
			delta.record("event_superseded", source, {"actor_id": id, "command_id": trigger.id,
				"reason": "actor_dead_or_income_already_removed"})
			continue
		var event: String = delta.record(trigger.type, source,
			{"actor_id": id, "command_id": trigger.id, "worked_permille": trigger.worked_permille,
			"cause": trigger.get("cause", "scenario")})
		event_ids.append(event)
		var previous_job: String = str(actor.occupation_id)
		var had_income_source: bool = previous_job != "dependent"
		var cutoff: int = mini(int(cutoffs.get(id, 1000)), int(trigger.worked_permille))
		cutoffs[id] = cutoff
		earned[id] = int(int(full_earnings[id]) * cutoff / 1000.0)
		delta.set_field("actors", "occupation_id", "dependent", event, id)
		delta.set_field("actors", "income", 0, event, id)
		Career.initialize_actor(actor)
		if had_income_source:
			actor.career.current_job = "dependent"
			actor.career.history.append({"year": delta.year, "kind": "ended", "occupation_id": previous_job,
				"reason": "death" if trigger.type == "actor_died" else "job_lost"})
		if trigger.type == "actor_died":
			participation[id] = int(trigger.worked_permille)
			delta.set_field("actors", "alive", false, event, id)
			delta.set_field("actors", "death_year", delta.year, event, id)
			delta.set_field("actors", "death_cause", str(trigger.get("cause", "scenario")), event, id)
			delta.set_field("actors", "health", 0, event, id)
			delta.set_field("actors", "work_capacity", 0, event, id)
		if had_income_source:
			queue.append({"id": trigger.id, "type": "income_lost", "actor_id": id, "cause_id": event})
	return {"ok": true, "event_ids": event_ids, "count": count}
