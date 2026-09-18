extends SceneTree
## Interaction tests against the real UI and real simulation, no mock choices.

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)


func run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	check(ui.state.world.year == 1850 and ui.pages.size() == 1, "Birth page is initialized")
	check(not ui.overlay.visible and not ui.decision_panel.visible, "No modal blocks initial play")
	check(ui.fields.savings.text == str(ui.state.household.savings), "Profile shows actual shared household savings")
	ui.navigation.family.pressed.emit()
	check(ui.current_view == "family" and ui.feed.get_child_count() > 0, "Family navigation renders actual relatives")
	ui.navigation.budget.pressed.emit()
	check(ui.current_view == "budget" and ui.feed.get_child_count() > 0, "Budget navigation works before first ledger")
	ui.navigation.life.pressed.emit()
	check(ui.current_view == "life", "Return to timeline")
	for index: int in range(25):
		if not ui.pending_prep.is_empty() or not ui.state.actors[ui.state.meta.player_id].alive:
			break
		ui.btn_advance.pressed.emit()
		await process_frame
	check(not ui.pending_prep.is_empty(), "Actual simulation produces an interactive choice")
	if not ui.pending_prep.is_empty():
		var year: int = int(ui.state.world.year)
		check(ui.btn_advance.disabled and ui.decision_panel.visible, "Pending choice blocks next year")
		check(ui.choice_buttons.size() == ui.pending_prep.storylet.choices.size(), "All real choices are rendered")
		var before_navigation: String = JSON.stringify(ui.state)
		ui.navigation.family.pressed.emit()
		check(ui.return_to_decision.visible and not ui.decision_panel.visible, "Pending decision has a return action on family view")
		ui.return_to_decision.pressed.emit()
		check(ui.current_view == "life" and ui.decision_panel.visible and JSON.stringify(ui.state) == before_navigation, "Return action restores the same decision without committing a year")
		root.size = Vector2i(960, 640)
		await process_frame
		await process_frame
		check(Rect2(Vector2.ZERO, ui.size).encloses(ui.action_dock.get_global_rect()), "All bottom actions fit at minimum size while a decision is pending")
		var choices_visible: bool = true
		for button: Button in ui.choice_buttons:
			choices_visible = choices_visible and ui.chronicle_scroll.get_global_rect().encloses(button.get_global_rect())
		check(choices_visible, "Initial decision options are visible without scrolling at minimum size")
		ui._on_advance_pressed()
		check(ui.state.world.year == year, "Calling advance cannot silently pick the first choice")
		ui._on_choice_selected("not_a_choice")
		check(ui.state.world.year == year and not ui.pending_prep.is_empty(), "Invalid choice leaves pending state intact")
		ui.choice_buttons[0].pressed.emit()
		await process_frame
		check(ui.state.world.year == year + 1 and ui.pending_prep.is_empty(), "A choice commits exactly one year")
		check(not ui.btn_advance.disabled and not ui.decision_panel.visible, "Choice restores normal progression")
		check(not ui.error_label.visible, "Successful choice clears the previous validation error")
		check(ui.fields.savings.text == str(ui.state.household.savings), "Profile balance follows committed choices")
	ui._open_new_game()
	var previous: String = JSON.stringify(ui.state)
	ui.seed_input.text = "not a number"
	ui._confirm_new_game()
	check(ui.overlay.visible and JSON.stringify(ui.state) == previous, "Invalid seed cannot replace the life")
	ui.seed_input.text = "7"
	ui._confirm_new_game()
	check(ui.state.meta.master_seed == "7" and ui.pages.size() == 1 and ui.pending_prep.is_empty(), "Restart resets log and unfinished choice")
	check(not ui.overlay.visible, "Valid restart closes confirmation")
	ui._open_tools()
	check(ui.overlay.visible and ui.auto_policy.visible and not ui.seed_input.visible, "Developer tools separated from life view")
	ui.overlay.hide()
	ui.start_game(42)
	ui.auto_policy.button_pressed = true
	for index: int in range(int(ui.pack.limits.max_years)):
		if ui.state.meta.status != "running":
			break
		ui._on_advance_pressed()
		await process_frame
	check(ui.state.meta.status == "player_dead", "UI reaches actual end of life")
	check(ui.btn_advance.disabled and ui.pages.size() > 1, "Memorial keeps history and disables advancement")
	await process_frame
	check(Rect2(Vector2.ZERO, ui.size).encloses(ui.action_dock.get_global_rect()), "End-of-life actions remain inside the minimum window")
	await process_frame
	ui.chronicle_scroll.scroll_vertical = 1000
	await process_frame
	check(ui.chronicle_scroll.scroll_vertical > 0, "Long life history can be scrolled")
	ui.switch_view("family")
	ui.switch_view("life")
	await process_frame
	await process_frame
	check(ui.chronicle_scroll.scroll_vertical == 0, "Returning to life shows the latest page at the top")
	var death_state: String = JSON.stringify(ui.state)
	ui._on_advance_pressed()
	check(JSON.stringify(ui.state) == death_state, "Ended life cannot advance")
	ui.switch_view("family")
	check(ui.feed.get_child_count() == ui.state.actors.size() - 1, "Family view includes later family members and deceased relatives")
	ui.switch_view("budget")
	check(not ui.feed.get_children().is_empty(), "Final budget remains inspectable")
	root.size = Vector2i(1000, 720)
	await process_frame
	await process_frame
	ui._responsive()
	check(not ui.right_panel.visible, "Narrow layout hides duplicate aside, navigation keeps details accessible")
	root.size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	ui._responsive()
	check(ui.right_panel.visible, "Wide layout restores aside")
	check(absf(ui.btn_advance.get_global_rect().get_center().x - ui.size.x / 2.0) < 2.0, "Year advance stays centered in the action bar")
	ui.queue_free()
	await process_frame
	print("UI interactions: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
