extends RefCounted
## All annual writes go to a detached candidate. The caller commits only on
## success. Trace IDs are stable within the same year and input sequence.

var candidate: Dictionary
var events: Array[Dictionary] = []
var year: int


func _init(state: Dictionary, target_year: int) -> void:
	candidate = state.duplicate(true)
	year = target_year


func record(kind: String, cause_id: String, details: Dictionary) -> String:
	var event_id: String = "%d:%04d" % [year, events.size()]
	events.append({"id": event_id, "year": year, "kind": kind,
		"cause_id": cause_id, "details": details.duplicate(true)})
	return event_id


func set_field(scope: String, field: String, value: Variant, cause_id: String,
		actor_id: String = "") -> void:
	var target: Dictionary = candidate[scope]
	if scope == "actors":
		target = candidate.actors[actor_id]
	var previous: Variant = target.get(field)
	if previous == value:
		return
	target[field] = value
	record("state_changed", cause_id, {"scope": scope, "actor_id": actor_id,
		"field": field, "before": previous, "after": value})


func finish() -> Dictionary:
	candidate.history.append_array(events)
	return candidate
