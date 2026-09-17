extends RefCounted
## A named draw cannot consume another system's random sequence.
## Replay scope: pinned Godot version + identical input/content/code.

const VERSION: String = "sha256-keyed-godot-rng-v1"


static func integer(master_seed: int, domain: String, year: int, entity_id: String,
		draw_id: String, minimum: int, maximum: int) -> int:
	# JSON encodes the key without ambiguous separators. Keep 60 hash bits so
	# conversion is always within a signed GDScript integer's range.
	var key: String = JSON.stringify([str(master_seed), domain, year, entity_id, draw_id])
	var seed_value: int = key.sha256_text().substr(0, 15).hex_to_int()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randi_range(minimum, maximum)
