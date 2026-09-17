extends Control

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")

# Dugum Referanslari
@onready var label_status: Label = %LabelStatus
@onready var line_edit_seed: LineEdit = %LineEditSeed
@onready var btn_new_game: Button = %BtnNewGame
@onready var btn_advance: Button = %BtnAdvance
@onready var check_bot_policy: CheckBox = %CheckBotPolicy

@onready var label_actor_name: Label = %LabelActorName
@onready var label_actor_age: Label = %LabelActorAge
@onready var label_actor_occ: Label = %LabelActorOcc
@onready var label_actor_edu: Label = %LabelActorEdu
@onready var bar_health: ProgressBar = %BarHealth
@onready var label_health_val: Label = %LabelHealthVal
@onready var bar_literacy: ProgressBar = %BarLiteracy
@onready var label_literacy_val: Label = %LabelLiteracyVal
@onready var bar_willpower: ProgressBar = %BarWillpower
@onready var label_willpower_val: Label = %LabelWillpowerVal
@onready var label_conditions: Label = %LabelConditions

@onready var label_world_year: Label = %LabelWorldYear
@onready var label_economy_index: Label = %LabelEconomyIndex
@onready var label_food_index: Label = %LabelFoodIndex
@onready var label_pressures: Label = %LabelPressures

@onready var label_household_income: Label = %LabelHouseholdIncome
@onready var label_household_expenses: Label = %LabelHouseholdExpenses
@onready var label_household_savings: Label = %LabelHouseholdSavings
@onready var label_household_debt: Label = %LabelHouseholdDebt
@onready var bar_food_security: ProgressBar = %BarFoodSecurity
@onready var label_food_security_val: Label = %LabelFoodSecurityVal
@onready var label_living_standard: Label = %LabelLivingStandard

@onready var panel_decision: PanelContainer = %PanelDecision
@onready var label_decision_title: Label = %LabelDecisionTitle
@onready var label_decision_family: Label = %LabelDecisionFamily
@onready var label_decision_text: Label = %LabelDecisionText
@onready var container_choices: VBoxContainer = %ContainerChoices

@onready var text_event_log: RichTextLabel = %TextEventLog

var pack: Dictionary
var runner: RefCounted
var state: Dictionary
var pending_prep: Dictionary = {}


func _ready() -> void:
	var load_res: Dictionary = Content.load_pack()
	if not load_res.ok:
		printerr("Paket yuklenemedi: ", load_res.errors)
		return
	pack = load_res.pack
	runner = Runner.new(pack)

	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_advance.pressed.connect(_on_advance_pressed)

	start_game(42)


func start_game(seed_val: int) -> void:
	line_edit_seed.text = str(seed_val)
	state = runner.initial_state(seed_val)
	pending_prep = {}
	text_event_log.clear()
	_append_log("[b]Simulasyon baslatildi.[/b] Tohum: %d, Baslangic Yili: %d" % [seed_val, pack.start_year])
	_refresh_ui()


func _on_new_game_pressed() -> void:
	var seed_text: String = line_edit_seed.text.strip_edges()
	var seed_val: int = seed_text.to_int() if seed_text.is_valid_int() else 42
	start_game(seed_val)


func _on_advance_pressed() -> void:
	if state.is_empty() or not state.has("meta") or state.meta.status != "running":
		return

	if not pending_prep.is_empty():
		# Bekleyen bir karar var ama oyuncu karar vermeden ilerletmek istiyorsa bot tercihiyle sonuclandir
		var policy: String = "heuristic_v1"
		var choice_id: String = ""
		if not pending_prep.storylet.is_empty():
			choice_id = pending_prep.storylet.choices[0].id
		var res: Dictionary = runner.step_resolve(pending_prep, choice_id)
		pending_prep = {}
		if res.ok:
			state = res.state
			_log_step_events(res.events)
			_refresh_ui()
		return

	if check_bot_policy.button_pressed:
		var res: Dictionary = runner.step(state, [], {}, "heuristic_v1")
		if res.ok:
			state = res.state
			_log_step_events(res.events)
			_refresh_ui()
		else:
			_append_log("[color=red]Hata: %s[/color]" % ", ".join(res.errors))
		return

	# Manuel karar modu: step_prepare ile adimi hazirla
	var prep: Dictionary = runner.step_prepare(state)
	if not prep.ok:
		_append_log("[color=red]Adim hatasi: %s[/color]" % ", ".join(prep.errors))
		return

	if prep.storylet.is_empty():
		# Olay cikmadi (sakin yil) veya oyuncu oldu
		var res: Dictionary = runner.step_resolve(prep, "")
		if res.ok:
			state = res.state
			_log_step_events(res.events)
			_refresh_ui()
		else:
			_append_log("[color=red]Sonuclandirma hatasi: %s[/color]" % ", ".join(res.errors))
	else:
		# Storylet secildi, oyuncunun karar vermesini bekle
		pending_prep = prep
		_present_decision(prep.storylet)
		btn_advance.disabled = true


func _present_decision(storylet: Dictionary) -> void:
	panel_decision.visible = true
	label_decision_title.text = storylet.title
	label_decision_family.text = "Kategori: " + storylet.family
	label_decision_text.text = storylet.text

	for child in container_choices.get_children():
		child.queue_free()

	for choice: Dictionary in storylet.choices:
		var btn = Button.new()
		btn.text = "%s - %s" % [choice.label, choice.description]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var cid: String = choice.id
		btn.pressed.connect(func(): _on_choice_selected(cid))
		container_choices.add_child(btn)


func _on_choice_selected(choice_id: String) -> void:
	if pending_prep.is_empty():
		return

	var res: Dictionary = runner.step_resolve(pending_prep, choice_id)
	pending_prep = {}
	panel_decision.visible = false
	btn_advance.disabled = false

	if res.ok:
		state = res.state
		_log_step_events(res.events)
		_refresh_ui()
	else:
		_append_log("[color=red]Karar uygulama hatasi: %s[/color]" % ", ".join(res.errors))


func _log_step_events(events: Array) -> void:
	var year: int = int(state.world.year)
	_append_log("[b]--- Yil %d ---[/b]" % year)
	for ev: Dictionary in events:
		match ev.kind:
			"quiet_year":
				_append_log("Yil sakin gecti; onemli bir kriz yasanmadi.")
			"storylet_triggered":
				_append_log("Olay: [b]%s[/b] (%s)" % [ev.details.title, ev.details.family])
			"storylet_choice_made":
				_append_log("Karar verildi: [i]%s[/i]" % ev.details.choice_id)
			"life_ended":
				_append_log("[color=red][b]Hayat sona erdi.[/b] Vefat nedeni: %s[/color]" % state.actors.player.death_cause)
			"actor_died":
				_append_log("[color=orange]%s vefat etti. Neden: %s[/color]" % [ev.details.actor_id, ev.details.get("cause", "")])
			"occupation_started":
				_append_log("%s ise basladi: %s (Ucret: %d)" % [ev.details.actor_id, ev.details.occupation_id, ev.details.income])
			"budget_deficit":
				_append_log("[color=yellow]Hanehalki butce acigi verdi: %d[/color]" % ev.details.amount)
			"food_insecurity":
				_append_log("[color=salmon]Gida guvencesi dustu: %d / 1000[/color]" % ev.details.food_security)


func _append_log(line: String) -> void:
	text_event_log.append_text(line + "\n")


func _refresh_ui() -> void:
	var player: Dictionary = state.actors[state.meta.player_id]
	var world: Dictionary = state.world
	var household: Dictionary = state.household

	# Durum
	if player.alive:
		label_status.text = "Simulasyon Suruyor"
		label_status.modulate = Color(0.2, 0.8, 0.2)
		btn_advance.disabled = not pending_prep.is_empty()
	else:
		label_status.text = "Hayat Sona Erdi (%s, %d Yas)" % [player.death_cause, player.age]
		label_status.modulate = Color(0.9, 0.2, 0.2)
		btn_advance.disabled = true

	# Aktor
	label_actor_name.text = "%s (%s)" % [player.name, player.sex]
	label_actor_age.text = "Yas: %d (Dogum: %d)" % [player.age, player.birth_year]
	label_actor_occ.text = "Meslek: %s (Gelir: %d)" % [player.occupation_id, player.income]
	label_actor_edu.text = "Egitim: %s" % player.education_state

	bar_health.value = player.health
	label_health_val.text = "%d / 100" % player.health
	bar_literacy.value = player.literacy
	label_literacy_val.text = "%d / 100" % player.literacy
	bar_willpower.value = player.willpower
	label_willpower_val.text = "%d / 100" % player.willpower

	var cond_keys: Array = player.conditions.keys()
	label_conditions.text = "Kosullar: " + (", ".join(cond_keys) if not cond_keys.is_empty() else "Saglikli")

	# Dunya
	label_world_year.text = "Yil: %d" % world.year
	label_economy_index.text = "Ekonomi Endeksi: %d" % world.economy_index
	label_food_index.text = "Gida Fiyat Endeksi: %d" % world.food_price_index
	label_pressures.text = "Istihdam: %d | Salgin: %d" % [world.employment_pressure, world.disease_pressure]

	# Hanehalki
	label_household_income.text = "Hane Geliri: %d" % household.income
	label_household_expenses.text = "Harcamalar: %d" % household.expenses
	label_household_savings.text = "Kasa / Tasarruf: %d" % household.savings
	label_household_debt.text = "Borc: %d" % household.debt
	bar_food_security.value = household.food_security
	label_food_security_val.text = "%d / 1000" % household.food_security
	label_living_standard.text = "Yasam Standardi: " + household.living_standard

	if pending_prep.is_empty():
		panel_decision.visible = false
