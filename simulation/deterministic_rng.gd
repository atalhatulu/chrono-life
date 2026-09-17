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


static func weighted(master_seed: int, domain: String, year: int, entity_id: String,
		draw_id: String, weights: Array[int]) -> int:
	var total: int = 0
	for weight: int in weights:
		total += maxi(0, weight)
	if total == 0:
		return -1
	var roll: int = integer(master_seed, domain, year, entity_id, draw_id, 0, total - 1)
	for index: int in range(weights.size()):
		roll -= maxi(0, weights[index])
		if roll < 0:
			return index
	return -1
