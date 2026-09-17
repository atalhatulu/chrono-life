extends RefCounted

const Rng = preload("res://simulation/deterministic_rng.gd")


static func decide(storylet: Dictionary, state: Dictionary, ledger: Dictionary,
		seed_value: int, year: int, policy_name: String = "heuristic_v1") -> String:
	var choices: Array = storylet.choices
	if choices.is_empty():
		return ""
	if choices.size() == 1:
		return choices[0].id

	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	var player_traits: Array = player.get("traits", [])

	match policy_name:
		"pragmatic":
			for ch: Dictionary in choices:
				if ch.id in ["comply", "rest", "pawn_heirloom", "accept_overtime", "errands_contribution", "seek_cure", "join_society"]:
					return ch.id
			return choices[0].id

		"education_first":
			for ch: Dictionary in choices:
				if ch.id in ["protest_for_school", "study_diligently", "decline_overtime", "refuse_pawn", "seek_cure", "join_society"]:
					return ch.id
			return choices[0].id

		"heuristic_v1", _:
			var deficit: int = int(ledger.get("budget_deficit", 0))
			var savings: int = int(state.household.savings)
			var health: int = int(player.health)

			match storylet.id:
				"childhood_labor_demand":
					if "education_first" in player_traits:
						return "protest_for_school"
					elif deficit > 0 and savings < 500:
						return "comply"
					else:
						return "errands_contribution"

				"night_reading":
					if health < 35:
						return "rest"
					elif "education_first" in player_traits or int(player.willpower) >= 50:
						return "study_diligently"
					else:
						return "rest"

				"overtime_shift":
					if health < 40:
						return "decline_overtime"
					elif deficit > 0 or savings < 1000:
						return "accept_overtime"
					else:
						return "decline_overtime"

				"pawn_family_heirloom":
					if deficit > 500 or savings == 0:
						return "pawn_heirloom"
					else:
						return "refuse_pawn"

				"dispensary_treatment":
					if savings >= 100 and (player.conditions.has("epidemic_disease") or player.conditions.has("malnutrition")):
						return "seek_cure"
					else:
						return "endure_home"

				"mutual_aid_subscription":
					if savings >= 4000:
						return "join_society"
					else:
						return "decline_society"

	return choices[0].id
