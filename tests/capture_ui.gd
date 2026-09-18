extends SceneTree
## Run with an actual display driver. Captures the engine's own framebuffer.


func _initialize() -> void:
	call_deferred("run")


func capture(filename: String) -> void:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var result: int = root.get_texture().get_image().save_png("res://artifacts/" + filename)
	if result != OK:
		printerr("Screenshot failed: " + filename)
		quit(1)
	print("Captured " + filename)


func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Use a display driver to capture actual rendered UI")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	root.size = Vector2i(1440, 900)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await capture("ui_birth_1440.png")
	for index: int in range(25):
		if not ui.pending_prep.is_empty():
			break
		ui._on_advance_pressed()
		await process_frame
	await capture("ui_decision_1440.png")
	root.size = Vector2i(960, 640)
	await capture("ui_decision_960.png")
	ui.switch_view("family")
	await capture("ui_pending_family_960.png")
	ui.return_to_decision.pressed.emit()
	root.size = Vector2i(1440, 900)
	if not ui.pending_prep.is_empty():
		ui._on_choice_selected(ui.pending_prep.storylet.choices[0].id)
	ui.auto_policy.button_pressed = true
	while int(ui.state.world.year) < 1875 and ui.state.meta.status == "running":
		ui._on_advance_pressed()
		await process_frame
	await capture("ui_journal_1440.png")
	ui.switch_view("family")
	await capture("ui_family_1440.png")
	ui.switch_view("budget")
	await capture("ui_budget_1440.png")
	root.size = Vector2i(1000, 720)
	ui.switch_view("life")
	await capture("ui_narrow_1000.png")
	root.size = Vector2i(960, 640)
	await capture("ui_minimum_960.png")
	ui._open_new_game()
	await capture("ui_restart_960.png")
	ui.overlay.hide()
	root.size = Vector2i(1440, 900)
	while ui.state.meta.status == "running":
		ui._on_advance_pressed()
		await process_frame
	await capture("ui_memorial_1440.png")
	ui.queue_free()
	await process_frame
	quit(0)
