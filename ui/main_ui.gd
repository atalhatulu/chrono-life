extends Control
## Chronicle presentation. Simulation ownership remains in SimulationRunner.

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Delta = preload("res://simulation/year_delta.gd")
const Palette = preload("res://ui/chronicle_theme.gd")
const Words = preload("res://ui/chronicle_text.gd")
const Purchases = preload("res://simulation/purchase_system.gd")
const Relationships = preload("res://simulation/relationship_system.gd")
const Treatments = preload("res://simulation/health_treatment_system.gd")
const Housing = preload("res://simulation/housing_system.gd")
const FamilyDynamics = preload("res://simulation/family_dynamics_system.gd")
const HouseholdNetwork = preload("res://simulation/household_network_system.gd")
const Hobbies = preload("res://simulation/hobby_system.gd")
const Skills = preload("res://simulation/skill_system.gd")
const Assets = preload("res://simulation/asset_system.gd")
const Migration = preload("res://simulation/migration_system.gd")
const SocialStatus = preload("res://simulation/social_status_system.gd")
const FamilyTree = preload("res://simulation/family_tree_system.gd")
const LifeActions = preload("res://simulation/life_action_system.gd")
const Career = preload("res://simulation/career_system.gd")
const Education = preload("res://simulation/education_system.gd")

var pack: Dictionary = {}
var runner: RefCounted
var state: Dictionary = {}
var pending_prep: Dictionary = {}
var pages: Array[Dictionary] = []
var current_view: String = "life"
var _view_handlers: Dictionary = {}
var fields: Dictionary = {}
var navigation: Dictionary = {}
var bars: Dictionary = {}
var stats_row: HBoxContainer
var main_column: VBoxContainer
var content_column: VBoxContainer
var feed: VBoxContainer
var chronicle_scroll: ScrollContainer
var side_info: VBoxContainer
var right_panel: PanelContainer
var decision_box: VBoxContainer
var decision_panel: PanelContainer
var choice_buttons: Array[Button] = []
var btn_advance: Button
var filter_button: Button
var return_to_decision: Button
var page_margin: MarginContainer
var action_dock: HBoxContainer
var hero_banner: Control
var more_button: Button
var stop_auto_button: Button
var _auto_stop: bool = false
var auto_step_delay: float = 0.0 if DisplayServer.get_name() == "headless" else 0.45
var error_label: Label
var overlay: ColorRect
var modal_body: VBoxContainer
var modal_title: Label
var seed_input: LineEdit
var auto_policy: CheckBox
var show_quiet: bool = false
var _busy: bool = false


func _ready() -> void:
	theme = Palette.create()
	_init_view_handlers()
	_build()
	resized.connect(_responsive)
	var loaded: Dictionary = Content.load_pack()
	if not loaded.ok:
		_show_error("İçerik yüklenemedi: " + str(loaded.errors))
		btn_advance.disabled = true
		return
	pack = loaded.pack
	runner = Runner.new(pack)
	start_game(42)
	_responsive()


func _init_view_handlers() -> void:
	_view_handlers = {
		"life": _render_life_chronicle,
		"family": _render_family,
		"budget": _render_budget,
		"spending": _render_spending,
		"education": _render_education,
		"career": _render_career,
		"health": _render_health,
		"housing": _render_housing,
		"development": _render_development,
		"status": _render_status
	}


func _label(text: String, font_size: int = 14, color: Color = Palette.INK,
		serif: bool = false, wrap: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", Palette.SERIF)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _field(parent: Node, key: String, text: String, font_size: int = 14,
		color: Color = Palette.INK, serif: bool = false, wrap: bool = false) -> Label:
	var label = _label(text, font_size, color, serif, wrap)
	label.name = key
	parent.add_child(label)
	fields[key] = label
	return label


func _column(gap: int = 12) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", gap)
	return box


func _row(gap: int = 12) -> HBoxContainer:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box


func _flow(gap: int = 6) -> HFlowContainer:
	var flow = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", gap)
	flow.add_theme_constant_override("v_separation", gap)
	return flow


func _spacer(parent: Node, vertical: bool = false) -> Control:
	var spacer = Control.new()
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer


func _button(text: String, action: Callable, variation: String = "Button", icon: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 44
	if icon != "":
		button.icon = load("res://assets/ui/%s.svg" % icon)
	button.pressed.connect(action)
	return button


func _card(parent: Node, padding: int = 18) -> VBoxContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, 12, Palette.LINE, padding))
	parent.add_child(panel)
	var column = _column(10)
	panel.add_child(column)
	return column


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _build() -> void:
	var background = ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	page_margin = MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_margin)
	main_column = _column(14)
	page_margin.add_child(main_column)
	_build_header(main_column)
	_build_hero(main_column)
	var body = _row(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_column.add_child(body)
	content_column = _column(12)
	body.add_child(content_column)
	var section = _row()
	content_column.add_child(section)
	_field(section, "section", "Hayatından sayfalar", 22, Palette.INK, true)
	_spacer(section)
	filter_button = _button("Tüm yıllar", _toggle_filter, "Ghost")
	filter_button.add_theme_font_size_override("font_size", 12)
	section.add_child(filter_button)
	var scroll = ScrollContainer.new()
	chronicle_scroll = scroll
	scroll.name = "ChronicleScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_column.add_child(scroll)
	var stack = _column(12)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	decision_panel = PanelContainer.new()
	decision_panel.name = "DecisionCard"
	decision_panel.add_theme_stylebox_override("panel", Palette.box(Color("f5ecd8"), 12, Color("d9c7a5"), 20))
	stack.add_child(decision_panel)
	decision_box = _column(12)
	decision_panel.add_child(decision_box)
	decision_panel.hide()
	feed = _column(0)
	stack.add_child(feed)
	right_panel = PanelContainer.new()
	right_panel.custom_minimum_size.x = 260
	right_panel.size_flags_vertical = Control.SIZE_FILL
	right_panel.add_theme_stylebox_override("panel", Palette.box(Color("eeeee3"), 12, Color.TRANSPARENT, 18))
	body.add_child(right_panel)
	var side_scroll = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(side_scroll)
	side_info = _column(16)
	side_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_info)
	error_label = _label("", 13, Palette.RUST, false, true)
	error_label.hide()
	main_column.add_child(error_label)
	var footer = _row(12)
	main_column.add_child(footer)
	var footer_copy = _column(2)
	footer.add_child(footer_copy)
	_field(footer_copy, "footer", "Her yıl yeni bir sayfa.", 13)
	_field(footer_copy, "hint", "Büyük kararları şimdilik ailen veriyor.", 11, Palette.MUTED, false, true)
	return_to_decision = _button("Karara dön", func(): switch_view("life"), "Ghost", "arrow")
	footer.add_child(return_to_decision)
	stop_auto_button = _button("Otomatiği durdur", func(): _auto_stop = true, "Ghost")
	footer.add_child(stop_auto_button)
	stop_auto_button.hide()
	_build_dock(main_column)
	_build_stats(main_column)
	_build_modal()


func _build_header(parent: Node) -> void:
	var header = _row(12)
	parent.add_child(header)
	header.add_child(_label("C H R O N O L I F E", 16, Palette.INK))
	_field(header, "tagline", "Bir hayat. Bir hikâye.", 13, Palette.MUTED, true)
	_spacer(header)
	var settings = _button("Ayarlar", _open_tools, "Ghost", "settings")
	settings.tooltip_text = "Simülasyon bilgileri ve otomatik karar ayarları"
	header.add_child(settings)
	var profile = _row(18)
	parent.add_child(profile)
	var badge = PanelContainer.new()
	badge.custom_minimum_size = Vector2(64, 64)
	badge.add_theme_stylebox_override("panel", Palette.box(Palette.DARK, 32, Color.TRANSPARENT, 8))
	profile.add_child(badge)
	var initials = _field(badge, "initials", "WT", 24, Palette.PAPER, true)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var identity = _column(2)
	profile.add_child(identity)
	var name_label = _field(identity, "name", "William Thompson", 26, Palette.INK, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 140
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field(identity, "age", "0 yaş · İlk yıllar", 13, Palette.MUTED)
	var balance = _column(2)
	balance.size_flags_horizontal = Control.SIZE_SHRINK_END
	profile.add_child(balance)
	var caption = _label("HANE BİRİKİMİ", 10, Palette.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.add_child(caption)
	var savings = _field(balance, "savings", "0", 27, Palette.INK, true)
	savings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	savings.tooltip_text = "Ailenin ortak birikimi · test birimi"


func _build_hero(parent: Node) -> void:
	var hero = Control.new()
	hero_banner = hero
	hero.custom_minimum_size.y = 64
	hero.clip_contents = true
	parent.add_child(hero)
	var background = ColorRect.new()
	background.color = Color("e7e6d7")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(background)
	var texture = TextureRect.new()
	texture.texture = preload("res://assets/ui/manchester.svg")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.anchor_left = 0.45
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(texture)
	var copy = _row(18)
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy.offset_left = 18
	copy.offset_right = -18
	hero.add_child(copy)
	_field(copy, "year", "1850", 31, Palette.INK, true)
	var location = _column(1)
	location.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_child(location)
	_field(location, "location", "MANCHESTER, İNGİLTERE", 10, Palette.INK)
	_field(location, "hero_caption", "Hikâyen burada başlıyor.", 12, Palette.INK)


func _build_dock(parent: Node) -> void:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.DARK, 16, Color.TRANSPARENT, 10))
	parent.add_child(panel)
	action_dock = _row(8)
	panel.add_child(action_dock)
	for item: Array in [["life", "Hayatım", "book"], ["family", "Ailem", "family"], ["advance", "+1 yıl", ""], ["budget", "Geçim", "wallet"], ["more", "Diğer", "settings"]]:
		var key: String = item[0]
		var action: Callable = func(): switch_view(key)
		if key == "advance":
			action = _on_advance_pressed
		elif key == "more":
			action = _open_sections
		var button = _button(item[1], action, "Primary" if key == "advance" else "Navigation", item[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size.y = 54
		action_dock.add_child(button)
		if key == "advance":
			btn_advance = button
			button.name = "AdvanceYear"
			button.clip_text = true
			button.custom_minimum_size = Vector2(196, 68)
			button.add_theme_font_size_override("font_size", 22)
		elif key == "more":
			more_button = button
		else:
			button.name = "Nav_" + key
			navigation[key] = button


func _open_sections() -> void:
	if _busy:
		return
	modal_title.text = "Yaşam Alanları"
	_clear(modal_body)
	seed_input.hide()
	auto_policy.hide()

	modal_body.add_child(_label("BEDEN VE ZİHİN", 10, Palette.RUST))
	var grid_body := GridContainer.new()
	grid_body.columns = 2
	grid_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_body.add_theme_constant_override("h_separation", 8)
	grid_body.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(grid_body)

	for item: Array in [["health", "Sağlık & Tedavi"], ["education", "Eğitim & Akıl"], ["development", "Beceriler & Mizaç"]]:
		var key: String = item[0]
		var button := _button(item[1], func():
			overlay.hide()
			switch_view(key))
		button.name = "Section_" + key
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_body.add_child(button)

	modal_body.add_child(_label("GEÇİM VE VARLIK", 10, Palette.RUST))
	var grid_wealth := GridContainer.new()
	grid_wealth.columns = 2
	grid_wealth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wealth.add_theme_constant_override("h_separation", 8)
	grid_wealth.add_theme_constant_override("v_separation", 8)
	modal_body.add_child(grid_wealth)

	for item: Array in [["career", "Kariyer & İş"], ["spending", "Kişisel Harcama"], ["housing", "Barınma & Konut"], ["status", "Varlıklar & Statü"]]:
		var key: String = item[0]
		var button := _button(item[1], func():
			overlay.hide()
			switch_view(key))
		button.name = "Section_" + key
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_wealth.add_child(button)

	var actions_row := _row(8)
	actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_child(actions_row)

	var auto_button := _button("Oto hayat", _open_auto_life)
	auto_button.disabled = not pending_prep.is_empty() or state.meta.status != "running"
	auto_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(auto_button)

	var new_button := _button("Yeni hayat", _open_new_game, "Ghost", "plus")
	new_button.name = "NewLife"
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_child(new_button)

	overlay.show()


func _open_auto_life() -> void:
	if _busy or not pending_prep.is_empty() or state.meta.status != "running":
		return
	modal_title.text = "Hayatın devam etsin"
	_clear(modal_body)
	seed_input.hide()
	auto_policy.hide()
	modal_body.add_child(_label("Şu anki hayatın kaldığı yıldan ilerleyecek. Kararlar ve aktiviteler otomatik seçilecek. İstediğin yıl durdurabilirsin.", 14, Palette.INK, false, true))
	modal_body.add_child(_button("Otomatik devam et", _run_auto_life, "Primary"))
	overlay.show()


func _get_stat_value(key: String) -> int:
	if state.is_empty() or not state.has("actors"):
		return 50
	var player: Dictionary = state.actors.get(state.meta.player_id, {})
	match key:
		"health":
			return int(player.get("health", 100))
		"happiness":
			return int(player.get("needs", {}).get("happiness", 55))
		"smarts":
			return int(player.get("literacy", 0))
		"prestige":
			return int(state.get("social_status", {}).get("score", player.get("willpower", 50)))
		_:
			return int(player.get(key, 50))


func _build_stats(parent: Node) -> void:
	stats_row = _row(8)
	stats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stats_row)
	for item: Array in [["health", "Sağlık"], ["happiness", "Mutluluk"], ["smarts", "Akıl"], ["prestige", "İtibar"]]:
		var stat := _column(3)
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_row.add_child(stat)
		var line := _row(2)
		stat.add_child(line)
		line.add_child(_label(item[1], 10, Palette.MUTED))
		_spacer(line)
		_field(line, item[0], "100", 10)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 5
		stat.add_child(bar)
		bars[item[0]] = bar


func _build_modal() -> void:
	overlay = ColorRect.new()
	overlay.name = "ModalOverlay"
	overlay.color = Color(0.08, 0.16, 0.12, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 460
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, 16, Palette.LINE, 28))
	center.add_child(panel)
	var content = _column(18)
	panel.add_child(content)
	modal_title = _label("", 28, Palette.INK, true)
	content.add_child(modal_title)
	modal_body = _column(12)
	content.add_child(modal_body)
	seed_input = LineEdit.new()
	seed_input.name = "SeedInput"
	seed_input.placeholder_text = "Örn. 42"
	content.add_child(seed_input)
	auto_policy = CheckBox.new()
	auto_policy.text = "Kararları otomatik ver"
	content.add_child(auto_policy)
	content.add_child(_button("Kapat", func(): overlay.hide(), "Ghost"))
	overlay.hide()


func _open_new_game() -> void:
	if _busy:
		return
	modal_title.text = "Yeni bir hayat"
	_clear(modal_body)
	modal_body.add_child(_label("Mevcut hayat kapanacak. Henüz kayıt sistemi yok;\nbaşlangıç sayısıyla aynı hayatı yeniden deneyebilirsin.", 13, Palette.MUTED))
	seed_input.text = str(state.get("meta", {}).get("master_seed", "42"))
	seed_input.show()
	auto_policy.hide()
	modal_body.add_child(_button("Hayatı başlat", _confirm_new_game, "Primary"))
	overlay.show()
	seed_input.grab_focus()


func _confirm_new_game() -> void:
	var value: String = seed_input.text.strip_edges()
	if not value.is_valid_int() or value.length() > 10 or value.to_int() < 0 or value.to_int() > 2147483647:
		seed_input.tooltip_text = "0 ile 2147483647 arasında bir tam sayı gir."
		seed_input.add_theme_color_override("font_color", Palette.RUST)
		var note = _label("0 ile 2147483647 arasında bir tam sayı gir.", 12, Palette.RUST)
		if not modal_body.has_node("SeedError"):
			note.name = "SeedError"
			modal_body.add_child(note)
		else:
			note.free()
		return
	seed_input.remove_theme_color_override("font_color")
	overlay.hide()
	start_game(value.to_int())


func _run_auto_life() -> void:
	if runner == null or _busy or not pending_prep.is_empty() or state.meta.status != "running":
		return
	overlay.hide()
	_busy = true
	_auto_stop = false
	stop_auto_button.show()
	error_label.hide()
	current_view = "life"
	while not _auto_stop and state.meta.status == "running":
		var result: Dictionary = runner.auto_step(state, "balanced")
		if not result.ok:
			_show_error("Otomatik hayat durdu: " + str(result.get("errors", [])))
			break
		_accept_result(result)
		_refresh_ui()
		if auto_step_delay > 0.0:
			await get_tree().create_timer(auto_step_delay).timeout
		else:
			await get_tree().process_frame
	_busy = false
	stop_auto_button.hide()
	_refresh_ui()


func _open_tools() -> void:
	if _busy:
		return
	modal_title.text = "Geliştirici araçları"
	_clear(modal_body)
	seed_input.hide()
	auto_policy.show()
	if not state.is_empty():
		modal_body.add_child(_label("Başlangıç sayısı: %s\nEkonomi endeksi: %d\nGıda fiyat endeksi: %d\nİstihdam baskısı: %d\nHastalık baskısı: %d" % [state.meta.master_seed, state.world.economy_index, state.world.food_price_index, state.world.employment_pressure, state.world.disease_pressure], 14))
	modal_body.add_child(_label("Tutarlar tarihsel para değil, test birimidir.\nBu görünüm simülasyonu incelemek içindir.", 12, Palette.MUTED))
	overlay.show()


func start_game(seed_value: int) -> void:
	if runner == null:
		return
	state = runner.initial_state(seed_value)
	pending_prep = {}
	_busy = false
	error_label.hide()
	pages.clear()
	pages.append({"year": int(state.world.year), "title": "Hayata merhaba.",
		"body": "Manchester’da dünyaya geldin. Fabrikaların gölgesinde, ailenin yanında büyüyeceksin. Bu hayatın nasıl ilerleyeceği henüz yazılmadı.",
		"tag": "İLK SAYFA", "important": true})
	current_view = "life"
	_refresh_ui()


func switch_view(view: String) -> void:
	if view not in ["life", "family", "budget", "education", "career", "health", "housing", "development", "status", "spending"]:
		return
	current_view = view
	_refresh_ui()


func _toggle_filter() -> void:
	show_quiet = not show_quiet
	_refresh_ui()


func _on_advance_pressed() -> void:
	if _busy or not pending_prep.is_empty() or state.is_empty() or state.meta.status != "running" or overlay.visible:
		return
	_busy = true
	error_label.hide()
	if auto_policy.button_pressed:
		_accept_result(runner.step(state, [], {}, "heuristic_v1"))
	else:
		var prep: Dictionary = runner.step_prepare(state)
		if not prep.ok:
			_show_error(str(prep.errors))
		elif prep.storylet.is_empty():
			_accept_result(runner.step_resolve(prep, ""))
		else:
			pending_prep = prep
			current_view = "life"
	_busy = false
	_refresh_ui()


func _on_choice_selected(choice_id: String) -> void:
	if _busy or pending_prep.is_empty():
		return
	var valid: bool = false
	for choice: Dictionary in pending_prep.storylet.choices:
		valid = valid or str(choice.id) == choice_id
	if not valid:
		_show_error("Bu karar artık geçerli değil.")
		return
	_busy = true
	# Resolve a copy: a failed resolution must not damage the pending choice.
	var trial: Dictionary = pending_prep.duplicate(true)
	trial.delta = Delta.new(pending_prep.delta.candidate, int(pending_prep.year))
	trial.delta.events.assign(pending_prep.delta.events.duplicate(true))
	var result: Dictionary = runner.step_resolve(trial, choice_id)
	if result.ok:
		pending_prep = {}
	_accept_result(result)
	_busy = false
	_refresh_ui()


func _accept_result(result: Dictionary) -> void:
	if not result.ok:
		_show_error("Yıl tamamlanamadı: " + str(result.errors))
		return
	state = result.state
	error_label.hide()
	var all_events: Array = result.events.duplicate()
	var cur_year: int = int(state.world.year)
	for hist_item: Dictionary in state.history:
		if int(hist_item.get("year", 0)) == cur_year and str(hist_item.get("kind", "")) == "life_action":
			all_events.append(hist_item)
	pages.append(Words.page(all_events, state))


func _show_error(message: String) -> void:
	error_label.text = message
	error_label.show()


func _refresh_ui() -> void:
	if state.is_empty():
		return
	var player: Dictionary = state.actors[state.meta.player_id]
	var is_portrait: bool = size.x < 768 or (size.x < size.y)
	fields.name.text = player.name
	if player.alive:
		fields.age.text = "%d yaş · %s · %d" % [player.age, Words.stage(int(player.age)), state.world.year]
	else:
		fields.age.text = "%d yaş · Vefat (%d)" % [player.age, state.world.year]
	fields.location.text = str(state.world.location_id).replace("_", " ").to_upper()
	fields.year.text = str(state.world.year)
	fields.initials.text = ""
	for part: String in str(player.name).split(" ", false):
		fields.initials.text += part.left(1)
	fields.savings.text = str(state.household.savings)
	fields.hero_caption.text = "Hikâyen burada başlıyor." if player.age == 0 else "Bu yıl, hayatının %d. sayfası." % player.age
	if not player.alive:
		fields.hero_caption.text = "Yaşanmış bir hayat, geride kalan izler."
	for key: String in bars:
		var stat_val: int = _get_stat_value(key)
		bars[key].value = stat_val
		fields[key].text = str(stat_val)
	for key: String in navigation:
		navigation[key].theme_type_variation = "SelectedNav" if key == current_view else "Navigation"
	more_button.theme_type_variation = "SelectedNav" if current_view not in navigation else "Navigation"
	fields.section.text = {"life": "Hayatından sayfalar", "family": "Seni çevreleyen insanlar", "budget": "Evin geçimi", "education": "Eğitim hayatın", "career": "İş ve kariyer hayatın", "health": "Sağlığın ve tedavilerin", "housing": "Nerede ve nasıl yaşadığın", "development": "Becerilerin, kişiliğin ve uğraşların", "status": "Varlıkların, toplumsal konumun ve hareketliliğin", "spending": "Cebindeki para ve harcamalar"}[current_view]
	filter_button.visible = current_view == "life"
	filter_button.text = "Önemli anlar" if show_quiet else "Tüm yıllar"
	btn_advance.disabled = not player.alive or not pending_prep.is_empty() or _busy
	if not player.alive:
		btn_advance.text = "Son" if is_portrait else "Tamamlandı"
	elif not pending_prep.is_empty():
		btn_advance.text = "Karar" if is_portrait else "Karar bekliyor"
	else:
		btn_advance.text = "+1 yıl"
	return_to_decision.visible = not pending_prep.is_empty() and current_view != "life"
	fields.footer.text = "Her yıl yeni bir sayfa." if player.alive else "%d yıllık bir hayat." % player.age
	fields.hint.text = "Büyük kararları şimdilik ailen veriyor." if player.age < 16 else "Geçmişin seninle. Sıradaki yıl henüz yazılmadı."
	if not pending_prep.is_empty():
		fields.footer.text = "%d · Bir karar zamanı" % pending_prep.year
		fields.hint.text = "Yıl henüz kapanmadı. Devam etmek için karar kartını yanıtla."
		if current_view != "life":
			fields.hint.text = "Devam etmek için Hayatım sekmesindeki karar kartını yanıtla."
	elif not player.alive:
		fields.hint.text = "Hayatının sayfalarını inceleyebilir veya yeni bir hayata başlayabilirsin."
	_render_decision()
	_render_feed()
	_render_sidebar()
	chronicle_scroll.set_deferred("scroll_vertical", 0)


func _render_decision() -> void:
	_clear(decision_box)
	choice_buttons.clear()
	decision_panel.visible = not pending_prep.is_empty() and current_view == "life"
	if not decision_panel.visible:
		return
	var story: Dictionary = pending_prep.storylet
	var wording: Array = Words.story_wording(story.id, state, story.title, story.text)
	decision_box.add_child(_label("%d  /  BİR KARAR ZAMANI" % pending_prep.year, 11, Palette.RUST))
	decision_box.add_child(_label(wording[0], 25, Palette.INK, true, true))
	decision_box.add_child(_label(wording[1], 14, Palette.INK, false, true))
	var choices = GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 10)
	choices.add_theme_constant_override("v_separation", 8)
	decision_box.add_child(choices)
	for choice: Dictionary in story.choices:
		var copy: Array = Words.CHOICES.get(choice.id, [choice.label, choice.description])
		var id: String = choice.id
		var cues: Array[String] = []
		var fx: Dictionary = choice.get("effects", {})
		if fx.has("cash_cost"):
			cues.append("-%d Nakit" % int(fx.cash_cost))
		if fx.has("cash_grant"):
			cues.append("+%d Nakit" % int(fx.cash_grant))
		if fx.has("health_delta"):
			cues.append(("%+d Sağlık" % int(fx.health_delta)))
		if fx.has("willpower_delta"):
			cues.append(("%+d İrade" % int(fx.willpower_delta)))
		if fx.has("literacy_delta"):
			cues.append(("%+d Okuma" % int(fx.literacy_delta)))
		if fx.has("deferred_job"):
			cues.append("İş: %s" % Words.word(str(fx.deferred_job)))
		if fx.has("cure_condition"):
			cues.append("Şifa")
		if fx.has("injury_hazard_bp"):
			cues.append("Kaza Riski")
		if fx.has("agency_check"):
			var ac: Dictionary = fx.agency_check
			cues.append("%s Sınavı" % Words.word(str(ac.get("attr", "willpower"))))

		var btn_label: String = str(copy[0]) + "\n" + str(copy[1])
		if not cues.is_empty():
			btn_label += "\n[" + " · ".join(cues) + "]"

		var button = _button(btn_label, func(): _on_choice_selected(id), "Choice")
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 74
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.name = "Choice_" + id
		choices.add_child(button)
		choice_buttons.append(button)


func _render_life_summary(parent: Node) -> void:
	var player_id: String = str(state.meta.player_id)
	var player: Dictionary = state.actors[player_id]
	var economy: Dictionary = state.get("personal_economy", {})
	var career: Dictionary = player.get("career", {})
	var education: Dictionary = player.get("education", {})
	var family: Dictionary = state.get("family", {})
	var tree: Dictionary = FamilyTree.build_tree(state)
	var status: Dictionary = state.get("social_status", {})
	var current_dwelling: Dictionary = Housing.current_dwelling(state)

	var card: VBoxContainer = _card(parent, 16)
	card.add_child(_label("BİR HAYATIN ARDINDAN", 10, Palette.RUST))

	var header_box: VBoxContainer = _column(2)
	card.add_child(header_box)
	header_box.add_child(_label(str(player.name), 24, Palette.INK, true, true))

	var cause_name: String = Words.word(str(player.get("death_cause", "old_age")))
	var span_text: String = "%d — %d (%d yaşında) · %s" % [
		int(player.birth_year), int(player.death_year), int(player.age), cause_name
	]
	header_box.add_child(_label(span_text, 12, Palette.MUTED, false, true))

	# Biyografik Anlatı
	var bio: String = "%s, %d yılında başlayan ömrünü %d yaşında tamamladı. " % [
		str(player.name), int(player.birth_year), int(player.age)
	]
	var children_count: int = int(family.get("children_count", 0))
	var marriages_list: Array = family.get("marriages", [])
	if not marriages_list.is_empty():
		bio += "%d evlilik yaşadı ve %d evlat yetiştirdi. " % [marriages_list.size(), children_count]
	elif children_count > 0:
		bio += "%d evlat yetiştirdi. " % children_count
	else:
		bio += "Kendi yolunu bağımsız yürüdü. "

	var work_years: int = int(career.get("experience_years", 0))
	if work_years > 0:
		bio += "%d yıl boyunca emek verdi. " % work_years
	bio += "Geriye onurlu bir hayat ve ailesine bıraktığı hatıralar kaldı."
	card.add_child(_label(bio, 13, Color("4a544a"), false, true))

	# Kompakt 2 sütunlu yaşam tablosu
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	card.add_child(grid)

	var highest_occupation: String = Words.word(str(player.occupation_id))
	var current_education: String = Words.word(str(education.get("current_stage", "Yok")))
	var living_place: String = str(current_dwelling.get("label", "Bilinmeyen konut"))

	var items: Array = [
		["MESLEK", highest_occupation],
		["EĞİTİM", current_education],
		["KAZANILAN GELİR", "%d birim" % int(economy.get("lifetime_income", 0))],
		["TOPLAM HARCAMA", "%d birim" % int(economy.get("lifetime_spending", 0))],
		["HANE BİRİKİMİ", "%d birim" % int(state.household.savings)],
		["SON KONUT", living_place],
		["KONUM", Words.word(str(status.get("band_id", "halk")))],
		["AİLE MİRASI", "%d birey (%d kuşak)" % [int(tree.stats.total_members), int(tree.stats.generations_count)]]
	]

	for item: Array in items:
		var col := _column(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(col)
		col.add_child(_label(str(item[0]), 9, Palette.MUTED))
		var val_lbl := _label(str(item[1]), 12, Palette.INK, true)
		val_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(val_lbl)

	var btn_new := _button("Yeni bir hayat başlat", _open_new_game, "Primary")
	btn_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(btn_new)


func _render_feed() -> void:
	_clear(feed)
	feed.add_theme_constant_override("separation", 0 if current_view == "life" else 12)
	var handler: Callable = _view_handlers.get(current_view, _render_life_chronicle)
	handler.call(feed)


func _perform_life_action(action_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	if not state.actors[state.meta.player_id].alive:
		return
	var current_year: int = int(state.world.year)
	if int(state.meta.get("action_used_year", -1)) == current_year:
		_show_error("Bu yıl için kişisel inisiyatif hakkını zaten kullandın.")
		return
	var result: Dictionary = LifeActions.apply(state, action_id)
	if not result.ok:
		_show_error(str(result.get("error", "Eylem gerçekleştirilemedi.")))
		return
	state.meta["action_used_year"] = current_year
	_refresh_ui()


func _render_life_actions(parent: Node) -> void:
	if state.is_empty() or not state.actors[state.meta.player_id].alive:
		return
	var current_year: int = int(state.world.year)
	var used_this_year: bool = int(state.meta.get("action_used_year", -1)) == current_year

	var card := _card(parent, 12)
	var header := _row(6)
	card.add_child(header)
	header.add_child(_label("YILLIK İNİSİYATİF", 10, Palette.RUST))
	_spacer(header)
	var badge_txt: String = "Tamamlandı" if used_this_year else "1 Eylem Hakkı"
	header.add_child(_label(badge_txt, 10, Palette.MUTED if used_this_year else Palette.INK))

	if used_this_year:
		card.add_child(_label("Bu yılki kişisel eylemini tamamladın. Yeni yılda (+1 Yıl) tekrar bir tercih yapabilirsin.", 12, Palette.MUTED, false, true))
		return

	var available: Array[String] = LifeActions.available_actions(state)
	if available.is_empty():
		card.add_child(_label("Şu anda uygun bir serbest eylem görünmüyor.", 12, Palette.MUTED))
		return

	var by_id: Dictionary = LifeActions.actions_by_id(state)
	var flow := _flow(6)
	card.add_child(flow)

	for action_id: String in available:
		var act: Dictionary = by_id.get(action_id, {})
		var label_str: String = str(act.get("label", action_id))
		var cost: int = int(act.get("cash_cost", 0))
		if cost > 0:
			label_str += " (%d b.)" % cost
		var aid: String = action_id
		var btn := _button(label_str, func(): _perform_life_action(aid), "Ghost")
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size.y = 38
		flow.add_child(btn)


func _render_life_chronicle(parent: Node) -> void:
	if not state.actors[state.meta.player_id].alive:
		_render_life_summary(parent)
	if state.actors.has(state.meta.player_id) and state.actors[state.meta.player_id].alive:
		var current_age: int = int(state.actors[state.meta.player_id].age)
		var age_focus := _column(2)
		parent.add_child(age_focus)
		age_focus.add_child(_label("%d yaşındasın." % current_age, 25, Palette.INK, true))
		var occ_text: String = Words.word(str(state.actors[state.meta.player_id].occupation_id))
		var stage_text: String = Words.stage(current_age)
		age_focus.add_child(_label("%s · %s" % [stage_text, occ_text], 12, Palette.MUTED))
		var top_spacer := Control.new()
		top_spacer.custom_minimum_size.y = 6
		parent.add_child(top_spacer)
		_render_life_actions(parent)
		var act_spacer := Control.new()
		act_spacer.custom_minimum_size.y = 8
		parent.add_child(act_spacer)

	for index: int in range(pages.size() - 1, -1, -1):
		var page: Dictionary = pages[index]
		if not show_quiet and not page.important:
			continue
		var card := _card(parent, 14)
		var top_row := _row(8)
		card.add_child(top_row)
		var age: int = int(page.year) - int(state.actors[state.meta.player_id].birth_year)
		top_row.add_child(_label("%d · %d yaş" % [int(page.year), age], 11, Palette.RUST))
		_spacer(top_row)
		if page.get("tag", "") != "":
			top_row.add_child(_label(str(page.tag), 9, Palette.MUTED))
		card.add_child(_label(page.title, 17, Palette.INK, true, true))
		if str(page.body).strip_edges() != "":
			card.add_child(_label(page.body, 13, Color("4a544a"), false, true))
		var card_spacer := Control.new()
		card_spacer.custom_minimum_size.y = 6
		parent.add_child(card_spacer)


func _render_family_tree(parent: Node) -> void:
	var tree: Dictionary = FamilyTree.build_tree(state)
	var tree_card: VBoxContainer = _card(parent, 14)
	tree_card.add_child(_label("SOY AĞACI", 10, Palette.RUST))
	var summary_txt: String = "%d birey · %d kuşak · %d hayatta" % [
		int(tree.stats.total_members),
		int(tree.stats.generations_count),
		int(tree.stats.living_count)
	]
	tree_card.add_child(_label(summary_txt, 12, Palette.MUTED))

	for gen: Dictionary in tree.generations:
		var gen_box: VBoxContainer = _column(4)
		tree_card.add_child(gen_box)
		var gen_header: HBoxContainer = _row(6)
		gen_box.add_child(gen_header)
		gen_header.add_child(_label(str(gen.title).to_upper(), 10, Palette.INK))
		_spacer(gen_header)
		gen_header.add_child(_label(str(gen.description), 10, Palette.MUTED))

		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		gen_box.add_child(grid)

		for m: Dictionary in gen.members:
			var panel := PanelContainer.new()
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var bg_color: Color = Color("fbf8f1") if m.alive else Color("edeae1")
			var border_color: Color = Palette.RUST if m.is_player else (Palette.LINE if m.alive else Color.TRANSPARENT)
			panel.add_theme_stylebox_override("panel", Palette.box(bg_color, 8, border_color, 8))
			grid.add_child(panel)

			var col := _column(1)
			panel.add_child(col)

			var role_tag: String = "%s%s" % [str(m.role_label), " (Sen)" if m.is_player else ""]
			col.add_child(_label(role_tag.to_upper(), 8, Palette.RUST if m.is_player else Palette.MUTED))
			var name_lbl := _label(str(m.name), 12, Palette.INK, true)
			name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			col.add_child(name_lbl)

			var status_str: String = "%d yaş" % int(m.age) if m.alive else "† %d" % int(m.death_year)
			col.add_child(_label(status_str, 9, Palette.MUTED))


func _render_family(parent: Node, compact: bool = false) -> void:
	Relationships.normalize(state)
	var player_id: String = state.meta.player_id

	if not compact:
		_render_family_tree(parent)

	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		if id == player_id:
			continue
		var actor: Dictionary = state.actors[id]
		var relation_data: Dictionary = state.relationships.people.get(id, {})
		var column: VBoxContainer = _column(3) if compact else _card(parent)
		column.set_meta("actor_id", id)
		if compact:
			parent.add_child(column)
		var relation: String = str(relation_data.get("stage", "Aile üyesi"))
		if id in ["parent_1", "parent_2"]:
			relation = "Annen" if actor.get("sex", "male") == "female" else "Baban"
		elif str(state.family.get("current_spouse_id", "")) == id:
			relation = "Eşin"
		elif id.begins_with("spouse"):
			relation = "Eski eşin"
		elif id.begins_with("child"):
			relation = "Çocuğun"
		elif id.begins_with("grandchild"):
			relation = "Torunun"
		elif id.begins_with("partner_child") or id.begins_with("partner_"):
			relation = "Çocuğunun eşi"
		column.add_child(_label(relation.to_upper(), 9, Palette.MUTED))
		column.add_child(_label(str(actor.name), 15 if compact else 21, Palette.INK, true, true))
		var residence: String = "Aynı hanede" if str(actor.get("household_id", "")) == str(state.household.id) else "Ayrı hanede"
		column.add_child(_label("%d yaş · %s · %s" % [actor.age, "Hayatta" if actor.alive else "Anısına", residence], 11, Palette.MUTED))
		if not compact:
			column.add_child(_label(Words.word(str(actor.occupation_id)) if actor.alive else "%d yılında hayatını kaybetti." % actor.death_year, 13, Palette.MUTED, false, true))
			if not relation_data.is_empty():
				column.add_child(_label("Yakınlık %d · Güven %d · Çatışma %d" % [
					int(relation_data.get("closeness", 0)),
					int(relation_data.get("trust", 0)),
					int(relation_data.get("conflict", 0))
				], 12, Palette.MUTED))
				if actor.alive:
					var row = _flow(6)
					column.add_child(row)
					for action: String in ["talk", "spend_time", "apologize"]:
						var person_id = id
						var interaction = action
						row.add_child(_button({
							"talk": "Konuş",
							"spend_time": "Vakit geçir",
							"apologize": "Özür dile"
						}[action], func(): _relationship_interaction(person_id, interaction), "Ghost"))
					if id in state.family.get("children_ids", []):
						var parenting: Dictionary = state.family.get("parenting", {}).get(id, {})
						column.add_child(_label("Ebeveynlik · İlgi %d · Destek %d · Disiplin %d · Çatışma %d" % [
							int(parenting.get("involvement", 55)), int(parenting.get("support", 55)),
							int(parenting.get("discipline", 50)), int(parenting.get("conflict", 10))
						], 11, Palette.MUTED, false, true))
						var parenting_row = _flow(6)
						column.add_child(parenting_row)
						for p_action: String in ["support", "spend_time", "education_support", "discipline"]:
							var child_id = id
							var parenting_action = p_action
							parenting_row.add_child(_button({
								"support": "Destekle",
								"spend_time": "Birlikte ol",
								"education_support": "Eğitime yardım",
								"discipline": "Disiplin"
							}[p_action], func(): _parenting_interaction(child_id, parenting_action), "Ghost"))
					var parent_ids: Array = state.family.get("kinship", {}).get(player_id, {}).get("parents", [])
					if id in parent_ids and actor.alive and (int(actor.age) >= 60 or int(actor.health) < 55):
						var elder: Dictionary = state.family.get("elder_care", {}).get(id, {})
						column.add_child(_label("Bakım · Destek %d · Yük %d" % [
							int(elder.get("care", 0)), int(elder.get("burden", 0))
						], 11, Palette.MUTED))
						var elder_row = _flow(6)
						column.add_child(elder_row)
						for care_action: String in ["visit", "care", "financial_support"]:
							var parent_id = id
							var elder_action = care_action
							elder_row.add_child(_button({
								"visit": "Ziyaret et",
								"care": "Bakım ver",
								"financial_support": "Maddi destek"
							}[care_action], func(): _elder_care_interaction(parent_id, elder_action), "Ghost"))
	if compact:
		return

	var fam: Dictionary = state.get("family", {})
	var family_overview = _card(parent)
	family_overview.add_child(_label("AİLE GEÇMİŞİ", 10, Palette.MUTED))
	family_overview.add_child(_label("Durum: %s · Çocuk: %d · Evlilik: %d" % [
		Words.word(str(fam.get("marital_status", "unmarried"))),
		int(fam.get("children_count", 0)),
		fam.get("marriages", []).size()
	], 13, Palette.INK))
	var marriages: Array = fam.get("marriages", [])
	for marriage: Dictionary in marriages:
		var spouse_id: String = str(marriage.get("spouse_id", ""))
		var spouse_name: String = str(state.actors.get(spouse_id, {}).get("name", spouse_id))
		var end_year: int = int(marriage.get("end_year", 0))
		var line: String = "%s · %d" % [spouse_name, int(marriage.get("start_year", 0))]
		if end_year > 0:
			line += "–%d · %s" % [end_year, str(marriage.get("end_reason", "")).replace("_", " ")]
		else:
			line += "–"
		family_overview.add_child(_label(line, 12, Palette.MUTED))

	var sibling_bonds: Dictionary = fam.get("sibling_bonds", {})
	if not sibling_bonds.is_empty():
		var sibling_card = _card(parent)
		sibling_card.add_child(_label("KARDEŞ BAĞLARI", 10, Palette.MUTED))
		var bond_keys: Array = sibling_bonds.keys()
		bond_keys.sort()
		for key: Variant in bond_keys:
			var bond: Dictionary = sibling_bonds[key]
			var pair: Array = bond.get("actors", [])
			if pair.size() < 2:
				continue
			var a_name: String = str(state.actors.get(pair[0], {}).get("name", pair[0]))
			var b_name: String = str(state.actors.get(pair[1], {}).get("name", pair[1]))
			sibling_card.add_child(_label("%s ↔ %s · Yakınlık %d · Rekabet %d · Destek %d" % [
				a_name, b_name, int(bond.get("closeness", 0)),
				int(bond.get("rivalry", 0)), int(bond.get("support", 0))
			], 12, Palette.MUTED, false, true))

	var households_card = _card(parent)
	households_card.add_child(_label("AİLE HANELERİ", 10, Palette.MUTED))
	for household_entry: Dictionary in HouseholdNetwork.active_households(state):
		var names: Array[String] = []
		for member_id: String in household_entry.get("member_ids", []):
			if state.actors.has(member_id):
				names.append(str(state.actors[member_id].name))
		households_card.add_child(_label("%s · %s · %s" % [
			str(household_entry.id),
			str(household_entry.get("kind", "")).replace("_", " "),
			", ".join(names)
		], 12, Palette.MUTED, false, true))

	var social_ids: Array = state.relationships.people.keys()
	social_ids.sort()
	var shown_nonfamily: bool = false
	for id: String in social_ids:
		if state.actors.has(id):
			continue
		var rel: Dictionary = state.relationships.people[id]
		if not rel.alive:
			continue
		if not shown_nonfamily:
			var heading = _card(parent)
			heading.add_child(_label("SOSYAL ÇEVREN", 10, Palette.MUTED))
			shown_nonfamily = true
		var card = _card(parent)
		card.add_child(_label(str(rel.stage).replace("_", " ").to_upper(), 9, Palette.MUTED))
		card.add_child(_label(str(rel.name), 19, Palette.INK, true))
		card.add_child(_label("Yakınlık %d · Güven %d · Çatışma %d · Uyum %d · Çekim %d" % [
			int(rel.closeness), int(rel.trust), int(rel.conflict),
			int(rel.compatibility), int(rel.attraction)
		], 12, Palette.MUTED, false, true))
		card.add_child(_label("%d'de tanıştınız · %s" % [
			int(rel.met_year), str(rel.met_via).replace("_", " ")
		], 11, Palette.MUTED))
		var actions = _flow(6)
		card.add_child(actions)
		for action: String in ["talk", "spend_time", "gift", "flirt", "argue", "apologize"]:
			var person_id = id
			var interaction = action
			actions.add_child(_button({
				"talk": "Konuş",
				"spend_time": "Vakit geçir",
				"gift": "Hediye",
				"flirt": "Flört et",
				"argue": "Tartış",
				"apologize": "Özür dile"
			}[action], func(): _relationship_interaction(person_id, interaction), "Ghost"))

	var meet_card = _card(parent)
	meet_card.add_child(_label("YENİ İNSANLAR", 10, Palette.MUTED))
	meet_card.add_child(_label("Sosyal çevreni genişletebilir, yeni arkadaşlar veya romantik bağlar kurabilirsin.", 12, Palette.MUTED, false, true))
	meet_card.add_child(_button("Yeni biriyle tanış", _meet_new_person, "Primary"))


func _elder_care_interaction(parent_id: String, interaction: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = FamilyDynamics.care_for_parent(state, parent_id, interaction)
	if not result.ok:
		_show_error(str(result.get("error", "Bakım etkileşimi başarısız.")))
		return
	_refresh_ui()


func _parenting_interaction(child_id: String, interaction: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = FamilyDynamics.interact_with_child(state, child_id, interaction)
	if not result.ok:
		_show_error(str(result.get("error", "Ebeveynlik etkileşimi başarısız.")))
		return
	_refresh_ui()


func _relationship_interaction(person_id: String, interaction: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Relationships.interact(state, person_id, interaction)
	if not result.ok:
		_show_error(str(result.get("error", "Etkileşim başarısız.")))
		return
	_refresh_ui()


func _meet_new_person() -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var id: String = Relationships.meet_person(state)
	if id == "":
		_show_error("Şu anda yeni biriyle tanışamadın.")
		return
	_refresh_ui()


func _render_budget(parent: Node) -> void:
	var column = _card(parent)
	column.add_child(_label("AİLENİN ORTAK BÜTÇESİ", 10, Palette.MUTED))
	column.add_child(_label(Words.word(str(state.household.living_standard)), 23, Palette.INK, true, true))
	var has_ledger: bool = not state.ledgers.is_empty()
	var ledger: Dictionary = state.ledgers[state.ledgers.size() - 1] if has_ledger else {}
	for item: Array in [["Kazanılan gelir", ledger.get("earned_income", 0)], ["Dışarıdan destek", ledger.get("external_income", 0)], ["Yıllık ihtiyaç", ledger.get("planned_expenses", 0)], ["Karşılanamayan ihtiyaç", ledger.get("unmet_needs", 0)], ["Birikim", state.household.savings], ["Borç", state.household.debt]]:
		var row = _row()
		column.add_child(row)
		row.add_child(_label(item[0], 14, Palette.MUTED))
		_spacer(row)
		row.add_child(_label(str(item[1]), 17, Palette.INK, true))
	column.add_child(_label("Son tamamlanan yılın hesabı. Tutarlar test birimidir." if has_ledger else "İlk yılın hesabı henüz kapanmadı. Tutarlar test birimidir.", 11, Palette.MUTED, false, true))
	column.add_child(_label("Gıda ihtiyacının %%%d kadarı karşılanıyor." % int(state.household.food_security / 10), 13, Palette.MUTED, false, true))


func _render_housing(parent: Node) -> void:
	var current: Dictionary = Housing.current_dwelling(state)
	var housing: Dictionary = state.get("housing", {})
	var card = _card(parent)
	card.add_child(_label("BARINMA DURUMU", 10, Palette.MUTED))
	card.add_child(_label(str(current.get("label", "Bilinmeyen konut")), 24, Palette.INK, true))
	card.add_child(_label("Kullanım biçimi: %s · Yıllık maliyet: %d" % [
		Words.word(str(housing.get("tenure", ""))),
		int(current.get("annual_cost", 0))
	], 12, Palette.MUTED))
	card.add_child(_label("Kalite %d · Hijyen %d · Güvenlik %d · Mahremiyet %d" % [
		int(current.get("quality", 0)), int(current.get("sanitation", 0)),
		int(current.get("security", 0)), int(current.get("privacy", 0))
	], 12, Palette.MUTED, false, true))
	card.add_child(_label("Kapasite %d · Hanede %d kişi · Fazladan %d kişi" % [
		int(current.get("capacity", 0)), Housing.living_count(state), Housing.overcrowding(state)
	], 12, Palette.MUTED))
	card.add_child(_label("Bu konutta %d'den beri · %d taşınma · %d ödeme sorunu yılı" % [
		int(housing.get("since_year", state.world.year)),
		int(housing.get("move_count", 0)),
		int(housing.get("unpaid_years", 0))
	], 11, Palette.MUTED))
	var options = _card(parent)
	options.add_child(_label("KONUT SEÇENEKLERİ", 10, Palette.MUTED))
	for dwelling: Dictionary in Housing.available_dwellings(state):
		if str(dwelling.id) == str(housing.get("dwelling_id", "")):
			continue
		var row = _row(8)
		options.add_child(row)
		var copy = _column(2)
		row.add_child(copy)
		copy.add_child(_label(str(dwelling.label), 14, Palette.INK, true))
		copy.add_child(_label("%d/yıl · kalite %d · kapasite %d" % [
			int(dwelling.annual_cost), int(dwelling.quality), int(dwelling.capacity)
		], 11, Palette.MUTED))
		_spacer(row)
		var dwelling_id = str(dwelling.id)
		row.add_child(_button("Taşın", func(): _move_housing(dwelling_id), "Primary"))


func _move_housing(dwelling_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Housing.move_to(state, dwelling_id)
	if not result.ok:
		_show_error(str(result.get("error", "Taşınma başarısız.")))
		return
	SocialStatus.recompute(state)
	_refresh_ui()


func _render_health(parent: Node) -> void:
	var player: Dictionary = state.actors[state.meta.player_id]
	var profile: Dictionary = player.get("health_profile", {})
	var card = _card(parent)
	card.add_child(_label("SAĞLIK DURUMU", 10, Palette.MUTED))
	card.add_child(_label("%d / 100" % int(player.health), 27, Palette.INK, true))
	card.add_child(_label("Çalışma kapasitesi: %d / 1000" % int(player.work_capacity), 12, Palette.MUTED))
	if player.conditions.is_empty():
		card.add_child(_label("Aktif bir sağlık sorunu görünmüyor.", 13, Palette.MUTED))
	else:
		for condition_id: String in player.conditions:
			var condition: Dictionary = player.conditions[condition_id]
			card.add_child(_label("%s · Şiddet %d" % [
				Words.word(condition_id),
				int(condition.get("severity", 50))
			], 14, Palette.INK, true))
	var disabilities: Array = profile.get("disabilities", [])
	if not disabilities.is_empty():
		var permanent = _card(parent)
		permanent.add_child(_label("KALICI ETKİLER", 10, Palette.RUST))
		for disability: Variant in disabilities:
			permanent.add_child(_label(str(disability).replace("_", " ").capitalize(), 13, Palette.INK))
	var options: Array[Dictionary] = Treatments.available_treatments(state)
	if not options.is_empty():
		var treatment_card = _card(parent)
		treatment_card.add_child(_label("TEDAVİ SEÇENEKLERİ", 10, Palette.MUTED))
		for treatment: Dictionary in options:
			var row = _row(8)
			treatment_card.add_child(row)
			var text = _column(2)
			row.add_child(text)
			text.add_child(_label(str(treatment.label), 14, Palette.INK, true))
			text.add_child(_label("%d test birimi · başarı %d%%" % [
				int(treatment.cost), int(treatment.get("success_bp", 0)) / 100
			], 11, Palette.MUTED))
			_spacer(row)
			var treatment_id = str(treatment.id)
			row.add_child(_button("Tedavi ol", func(): _take_treatment(treatment_id), "Primary"))
	var history: Array = profile.get("treatment_history", [])
	if not history.is_empty():
		var history_card = _card(parent)
		history_card.add_child(_label("TEDAVİ GEÇMİŞİ", 10, Palette.MUTED))
		for index: int in range(history.size() - 1, maxi(-1, history.size() - 6), -1):
			var entry: Dictionary = history[index]
			history_card.add_child(_label("%d · %s · %d başarılı müdahale" % [
				int(entry.get("year", 0)),
				str(entry.get("treatment_id", "")).replace("_", " ").capitalize(),
				int(entry.get("success_count", 0))
			], 12, Palette.MUTED))


func _take_treatment(treatment_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Treatments.apply(state, treatment_id)
	if not result.ok:
		_show_error(str(result.get("error", "Tedavi uygulanamadı.")))
		return
	_refresh_ui()


func _render_career(parent: Node) -> void:
	var player: Dictionary = state.actors[state.meta.player_id]
	var career: Dictionary = player.get("career", {})
	var card = _card(parent)
	card.add_child(_label("KARİYER DURUMU", 10, Palette.MUTED))
	var occupation: String = str(player.occupation_id)
	var title: String = "Çalışmıyor" if occupation == "dependent" else Words.word(occupation)

	var header_row = _row(8)
	card.add_child(header_row)
	header_row.add_child(_label(title, 24, Palette.INK, true))
	_spacer(header_row)
	if occupation != "dependent":
		header_row.add_child(_button("İstifa Et", _resign_job, "Ghost"))

	card.add_child(_label("Yıllık gelir: %d" % int(player.income), 13, Palette.MUTED))
	for item: Array in [
		["Toplam deneyim", int(career.get("experience_years", 0))],
		["Ulaşılan en yüksek seviye", int(career.get("highest_level", 0))],
		["İş değişimi", int(career.get("job_changes", 0))]
	]:
		var row = _row()
		card.add_child(row)
		row.add_child(_label(str(item[0]), 13, Palette.MUTED))
		_spacer(row)
		row.add_child(_label(str(item[1]), 15, Palette.INK, true))

	# Açık Pozisyonlar ve Kariyer Fırsatları
	var all_jobs: Dictionary = Career.catalog_jobs(state)
	if not all_jobs.is_empty():
		var job_card = _card(parent)
		job_card.add_child(_label("İŞ FIRSATLARI VE AÇIK POZİSYONLAR", 10, Palette.RUST))
		var job_keys: Array = all_jobs.keys()
		job_keys.sort_custom(func(a: String, b: String): return int(all_jobs[a].get("level", 0)) < int(all_jobs[b].get("level", 0)))
		var shown_count: int = 0
		for jid: String in job_keys:
			if jid == "dependent" or jid == occupation:
				continue
			var job: Dictionary = all_jobs[jid]
			var is_elig: bool = Career.eligible(player, job, int(player.age))
			var missing: Array[String] = Career.missing_requirements(player, job, int(player.age)) if not is_elig else []
			if not is_elig and int(player.age) < int(job.get("minimum_age", 0)) - 3:
				continue

			shown_count += 1
			var row = _row(8)
			job_card.add_child(row)
			var copy = _column(2)
			row.add_child(copy)
			var job_name: String = str(job.get("label", Words.word(jid)))
			copy.add_child(_label(job_name, 14, Palette.INK if is_elig else Palette.MUTED, true))
			var info_txt: String = "Gelir: %d · Alan: %s" % [int(job.annual_income), str(job.get("career_track", "genel")).capitalize()]
			if not is_elig:
				info_txt += " · [Eksik: " + ", ".join(missing) + "]"
			copy.add_child(_label(info_txt, 11, Palette.MUTED))
			_spacer(row)
			var target_jid: String = jid
			if is_elig:
				row.add_child(_button("İşe Başla", func(): _apply_for_job(target_jid), "Primary"))
			else:
				var locked_btn = _button("Kilitli", func(): _show_error("Gereksinimler karşılanmıyor: " + ", ".join(missing)), "Ghost")
				locked_btn.disabled = true
				row.add_child(locked_btn)
		if shown_count == 0:
			job_card.add_child(_label("Şu anda uygun yeni bir iş ilanı bulunmuyor.", 12, Palette.MUTED))

	var tracks: Dictionary = career.get("track_experience", {})
	if not tracks.is_empty():
		var track_card = _card(parent)
		track_card.add_child(_label("ALAN DENEYİMİ", 10, Palette.MUTED))
		var keys: Array = tracks.keys()
		keys.sort()
		for track: Variant in keys:
			track_card.add_child(_label("%s · %d yıl" % [str(track).replace("_", " ").capitalize(), int(tracks[track])], 13, Palette.INK))
	var history: Array = career.get("history", [])
	if not history.is_empty():
		var history_card = _card(parent)
		history_card.add_child(_label("İŞ GEÇMİŞİ", 10, Palette.MUTED))
		for index: int in range(history.size() - 1, maxi(-1, history.size() - 8), -1):
			var entry: Dictionary = history[index]
			var reason: String = str(entry.get("reason", ""))
			var suffix: String = "" if reason == "" else " · " + reason.replace("_", " ").capitalize()
			history_card.add_child(_label("%d · %s · %s%s" % [
				int(entry.get("year", 0)),
				str(entry.get("occupation_id", "")).replace("_", " ").capitalize(),
				str(entry.get("kind", "")).capitalize(),
				suffix
			], 12, Palette.MUTED))


func _apply_for_job(job_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Career.apply_for_job(state, job_id)
	if not result.ok:
		_show_error(str(result.get("error", "İşe başvuru başarısız.")))
		return
	_refresh_ui()


func _resign_job() -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Career.resign_job(state)
	if not result.ok:
		_show_error(str(result.get("error", "İstifa işlemi gerçekleştirilemedi.")))
		return
	_refresh_ui()


func _render_education(parent: Node) -> void:
	var player: Dictionary = state.actors[state.meta.player_id]
	var education: Dictionary = player.get("education", {})
	var card = _card(parent)
	card.add_child(_label("EĞİTİM DURUMU", 10, Palette.MUTED))
	var current_stage: String = str(education.get("current_stage", ""))
	var title = "Şu anda eğitim almıyor"
	if current_stage != "":
		title = Words.word(current_stage)

	var header_row = _row(8)
	card.add_child(header_row)
	header_row.add_child(_label(title, 24, Palette.INK, true))
	_spacer(header_row)
	if current_stage != "":
		header_row.add_child(_button("Eğitimi Bırak", _leave_education, "Ghost"))

	var attendance: int = int(education.get("attendance", 0))
	var performance: int = int(education.get("performance", 0))
	var progress: int = int(education.get("progress", 0))
	for item: Array in [["Devam", attendance], ["Performans", performance], ["İlerleme", progress], ["Okuryazarlık", int(player.literacy)]]:
		var row = _row()
		card.add_child(row)
		row.add_child(_label(str(item[0]), 13, Palette.MUTED))
		_spacer(row)
		row.add_child(_label("%d%%" % int(item[1]), 15, Palette.INK, true))

	# Eğitim Başvuruları (Örn. Akşam Okulu)
	var available: Array[Dictionary] = Education.available_stages(state)
	if not available.is_empty():
		var app_card = _card(parent)
		app_card.add_child(_label("EĞİTİM BAŞVURULARI VE KURSLAR", 10, Palette.RUST))
		for stage: Dictionary in available:
			var row = _row(8)
			app_card.add_child(row)
			var copy = _column(2)
			row.add_child(copy)
			copy.add_child(_label(str(stage.label), 14, Palette.INK, true))
			var cost: int = int(stage.get("annual_cost", 0))
			copy.add_child(_label("Yıllık ücret: %d · Okuma: +%d/yıl · İlerleme: +%d/yıl" % [
				cost, int(stage.get("literacy_per_year", 0)), int(stage.get("progress_per_year", 0))
			], 11, Palette.MUTED))
			_spacer(row)
			var sid: String = str(stage.id)
			row.add_child(_button("Kayıt Ol", func(): _enroll_education(sid), "Primary"))

	var completed: Array = education.get("completed_stages", [])
	if not completed.is_empty():
		var completed_card = _card(parent)
		completed_card.add_child(_label("TAMAMLANAN EĞİTİMLER", 10, Palette.MUTED))
		for stage_id: Variant in completed:
			completed_card.add_child(_label(Words.word(str(stage_id)), 14, Palette.INK))
	var history: Array = education.get("history", [])
	if not history.is_empty():
		var history_card = _card(parent)
		history_card.add_child(_label("EĞİTİM GEÇMİŞİ", 10, Palette.MUTED))
		for index: int in range(history.size() - 1, maxi(-1, history.size() - 6), -1):
			var entry: Dictionary = history[index]
			history_card.add_child(_label("%d · %s · %s" % [
				int(entry.get("year", 0)),
				str(entry.get("stage_id", "")).replace("_", " ").capitalize(),
				str(entry.get("kind", "")).replace("_", " ").capitalize()
			], 12, Palette.MUTED))


func _enroll_education(stage_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Education.enroll_stage(state, stage_id)
	if not result.ok:
		_show_error(str(result.get("error", "Eğitime kayıt olunamadı.")))
		return
	_refresh_ui()


func _leave_education() -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Education.leave_education(state)
	if not result.ok:
		_show_error(str(result.get("error", "Eğitimi bırakma işlemi başarısız.")))
		return
	_refresh_ui()


func _render_development(parent: Node) -> void:
	var player: Dictionary = state.actors[state.meta.player_id]
	var skill_defs: Dictionary = Skills.definitions(state)
	var skill_values: Dictionary = player.get("skills", {}).get("values", {})
	var skills_card = _card(parent)
	skills_card.add_child(_label("BECERİLER", 10, Palette.MUTED))
	var skill_ids: Array = skill_values.keys()
	skill_ids.sort()
	for skill_id: String in skill_ids:
		var def: Dictionary = skill_defs.get(skill_id, {})
		var label: String = str(def.get("label", skill_id.replace("_", " ").capitalize()))
		var row = _row()
		skills_card.add_child(row)
		row.add_child(_label(label, 13, Palette.INK))
		_spacer(row)
		row.add_child(_label("%d" % int(skill_values[skill_id]), 15, Palette.INK, true))

	var personality_card = _card(parent)
	personality_card.add_child(_label("KİŞİLİK", 10, Palette.MUTED))
	var axes: Dictionary = player.get("personality", {}).get("axes", {})
	var axis_ids: Array = axes.keys()
	axis_ids.sort()
	for axis_id: String in axis_ids:
		var row = _row()
		personality_card.add_child(row)
		row.add_child(_label(Words.word(axis_id), 13, Palette.INK))
		_spacer(row)
		row.add_child(_label("%d" % int(axes[axis_id]), 15, Palette.INK, true))
	if not player.get("traits", []).is_empty():
		personality_card.add_child(_label("Traitler: " + ", ".join(player.traits), 11, Palette.MUTED, false, true))

	var hobbies_card = _card(parent)
	hobbies_card.add_child(_label("HOBİLER / UĞRAŞLAR", 10, Palette.MUTED))
	var active: Dictionary = player.get("hobbies", {}).get("active", {})
	for hobby: Dictionary in Hobbies.available_hobbies(state):
		var progress: Dictionary = active.get(hobby.id, {})
		var row = _row(8)
		hobbies_card.add_child(row)
		var copy = _column(2)
		row.add_child(copy)
		copy.add_child(_label(str(hobby.label), 14, Palette.INK, true))
		copy.add_child(_label("Ustalık %d · %d yıl · %d oturum" % [
			int(progress.get("mastery", 0)), int(progress.get("years", 0)), int(progress.get("sessions", 0))
		], 11, Palette.MUTED))
		_spacer(row)
		var hobby_id: String = str(hobby.id)
		row.add_child(_button("Uğraş", func(): _practice_hobby(hobby_id), "Ghost"))


func _practice_hobby(hobby_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Hobbies.practice(state, str(state.meta.player_id), hobby_id, "manual")
	if not result.ok:
		_show_error(str(result.get("error", "Hobi uygulanamadı.")))
		return
	_refresh_ui()


func _render_status(parent: Node) -> void:
	var status: Dictionary = state.get("social_status", {})
	var status_card = _card(parent)
	status_card.add_child(_label("TOPLUMSAL KONUM", 10, Palette.MUTED))
	status_card.add_child(_label(Words.word(str(status.get("band_id", "unknown"))), 25, Palette.INK, true))
	status_card.add_child(_label("Skor: %d / 100" % int(status.get("score", 0)), 13, Palette.MUTED))
	var components: Dictionary = status.get("components", {})
	var component_keys: Array = components.keys()
	component_keys.sort()
	for key: String in component_keys:
		var row = _row()
		status_card.add_child(row)
		row.add_child(_label(Words.word(key), 12, Palette.MUTED))
		_spacer(row)
		row.add_child(_label(str(components[key]), 13, Palette.INK, true))

	var asset_card = _card(parent)
	asset_card.add_child(_label("VARLIKLAR", 10, Palette.MUTED))
	asset_card.add_child(_label("Toplam değer: %d" % Assets.total_value(state), 18, Palette.INK, true))
	var owned: Dictionary = state.get("assets", {}).get("owned", {})
	if owned.is_empty():
		asset_card.add_child(_label("Kalıcı bir varlığın yok.", 12, Palette.MUTED))
	else:
		var asset_defs: Dictionary = Assets.definitions(state)
		var asset_ids: Array = owned.keys()
		asset_ids.sort()
		for asset_id: String in asset_ids:
			var entry: Dictionary = owned[asset_id]
			var def: Dictionary = asset_defs.get(asset_id, {})
			var row = _row(8)
			asset_card.add_child(row)
			var copy = _column(2)
			row.add_child(copy)
			copy.add_child(_label("%s · değer %d · adet %d" % [
				str(def.get("label", asset_id)),
				int(entry.get("value", 0)),
				int(entry.get("quantity", 1))
			], 12, Palette.INK))
			_spacer(row)
			var owned_asset_id: String = asset_id
			row.add_child(_button("Elden çıkar", func(): _liquidate_asset(owned_asset_id), "Ghost"))
	var buyable: Array[Dictionary] = Assets.available_assets(state)
	if not buyable.is_empty():
		asset_card.add_child(_label("EDİNİLEBİLİR", 10, Palette.RUST))
		for asset: Dictionary in buyable:
			var row = _row(8)
			asset_card.add_child(row)
			var copy = _column(2)
			row.add_child(copy)
			copy.add_child(_label(str(asset.label), 13, Palette.INK, true))
			copy.add_child(_label("%d test birimi" % int(asset.acquire_cost), 11, Palette.MUTED))
			_spacer(row)
			var asset_id: String = str(asset.id)
			row.add_child(_button("Edin", func(): _acquire_asset(asset_id), "Ghost"))

	var migration_card = _card(parent)
	migration_card.add_child(_label("YER DEĞİŞTİRME", 10, Palette.MUTED))
	migration_card.add_child(_label("Şu an: %s" % str(state.world.location_id).replace("_", " ").capitalize(), 16, Palette.INK, true))
	migration_card.add_child(_label("Toplam taşınma: %d" % int(state.get("migration", {}).get("move_count", 0)), 11, Palette.MUTED))
	var destinations: Array[Dictionary] = Migration.available_destinations(state)
	if destinations.is_empty():
		migration_card.add_child(_label("Şu anda uygun bir taşınma seçeneği yok.", 12, Palette.MUTED))
	else:
		for destination: Dictionary in destinations:
			var row = _row(8)
			migration_card.add_child(row)
			var copy = _column(2)
			row.add_child(copy)
			copy.add_child(_label(str(destination.label), 13, Palette.INK, true))
			copy.add_child(_label("Taşınma maliyeti: %d" % int(destination.move_cost), 11, Palette.MUTED))
			_spacer(row)
			var destination_id: String = str(destination.id)
			row.add_child(_button("Taşın", func(): _migrate_to(destination_id), "Primary"))


func _acquire_asset(asset_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Assets.acquire(state, asset_id)
	if not result.ok:
		_show_error(str(result.get("error", "Varlık edinilemedi.")))
		return
	SocialStatus.recompute(state)
	_refresh_ui()


func _liquidate_asset(asset_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Assets.liquidate(state, asset_id)
	if not result.ok:
		_show_error(str(result.get("error", "Varlık elden çıkarılamadı.")))
		return
	SocialStatus.recompute(state)
	_refresh_ui()


func _migrate_to(destination_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Migration.move_to(state, destination_id)
	if not result.ok:
		_show_error(str(result.get("error", "Taşınma başarısız.")))
		return
	_refresh_ui()


func _render_spending(parent: Node) -> void:
	var economy: Dictionary = state.get("personal_economy", {})
	var wallet = _card(parent)
	wallet.add_child(_label("KİŞİSEL PARA", 10, Palette.MUTED))
	wallet.add_child(_label("%d test birimi" % int(economy.get("cash", 0)), 27, Palette.INK, true))
	wallet.add_child(_label("Toplam kazanç: %d · Toplam harcama: %d" % [
		int(economy.get("lifetime_income", 0)), int(economy.get("lifetime_spending", 0))], 12, Palette.MUTED))
	var owned: Array[Dictionary] = Purchases.owned_items(state)
	if not owned.is_empty():
		var owned_card = _card(parent)
		owned_card.add_child(_label("SAHİP OLDUKLARIN", 10, Palette.MUTED))
		for entry: Dictionary in owned:
			owned_card.add_child(_label("%s · %d'de alındı" % [str(entry.label), int(entry.year)], 13, Palette.INK))
	var memberships: Array[Dictionary] = Purchases.active_memberships(state)
	if not memberships.is_empty():
		var member_card = _card(parent)
		member_card.add_child(_label("AKTİF ÜYELİKLER", 10, Palette.MUTED))
		for entry: Dictionary in memberships:
			member_card.add_child(_label("%s · %d sonuna kadar" % [str(entry.label), int(entry.expires_year)], 13, Palette.INK))
	var grouped: Dictionary = {}
	for item: Dictionary in Purchases.available_items(state):
		var category: String = str(item.category)
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(item)
	var categories: Array = grouped.keys()
	categories.sort()
	if categories.is_empty():
		var empty = _card(parent)
		empty.add_child(_label("Şu anda cebindeki parayla alınabilecek bir şey yok.", 14, Palette.MUTED, false, true))
		return
	for category: String in categories:
		var card = _card(parent)
		card.add_child(_label(Words.word(category).to_upper(), 10, Palette.RUST))
		for item: Dictionary in grouped[category]:
			var row = _row(10)
			card.add_child(row)
			var text = _column(2)
			row.add_child(text)
			text.add_child(_label(str(item.label), 15, Palette.INK, true))
			text.add_child(_label("%d test birimi" % int(item.cost), 11, Palette.MUTED))
			_spacer(row)
			var item_id: String = str(item.id)
			row.add_child(_button("Satın al", func(): _buy_item(item_id), "Ghost"))


func _buy_item(item_id: String) -> void:
	if _busy or not pending_prep.is_empty() or overlay.visible or state.meta.status != "running":
		return
	var result: Dictionary = Purchases.purchase(state, item_id)
	if not result.ok:
		_show_error(str(result.get("error", "Satın alma başarısız.")))
		return
	error_label.hide()
	_refresh_ui()


func _render_sidebar() -> void:
	_clear(side_info)
	side_info.add_child(_label("EVİNDE HAYAT", 10, Palette.MUTED))
	side_info.add_child(_label(Words.word(str(state.household.living_standard)), 20, Palette.INK, true, true))
	var summary = _row(16)
	side_info.add_child(summary)
	for item: Array in [["BİRİKİM", state.household.savings], ["BORÇ", state.household.debt]]:
		var value = _column(2)
		summary.add_child(value)
		value.add_child(_label(item[0], 9, Palette.MUTED))
		value.add_child(_label(str(item[1]), 24, Palette.INK, true))
	side_info.add_child(_label("Cebindeki para: %d" % int(state.get("personal_economy", {}).get("cash", 0)), 13, Palette.MUTED))
	side_info.add_child(_button("Bütçeyi incele", func(): switch_view("budget"), "Ghost"))
	side_info.add_child(HSeparator.new())
	side_info.add_child(_label("YANINDAKİ İNSANLAR", 10, Palette.MUTED))
	_render_family(side_info, true)
	side_info.add_child(_button("Ailene bak", func(): switch_view("family"), "Ghost"))


func _responsive() -> void:
	var is_portrait: bool = size.x < 768 or (size.x < size.y)
	if hero_banner != null:
		hero_banner.visible = size.y >= 760 and size.x >= 480
		main_column.add_theme_constant_override("separation", 12 if size.y >= 760 else 8)
	if right_panel != null:
		right_panel.visible = size.x >= 1280
	if page_margin != null:
		var min_inset: int = 12 if is_portrait else 24
		var inset: int = maxi(min_inset, int((size.x - 1280) / 2))
		page_margin.add_theme_constant_override("margin_left", inset)
		page_margin.add_theme_constant_override("margin_right", inset)
		page_margin.add_theme_constant_override("margin_top", 10 if is_portrait else 12)
		page_margin.add_theme_constant_override("margin_bottom", 12 if is_portrait else 16)
	if action_dock != null:
		action_dock.add_theme_constant_override("separation", 4 if is_portrait else 8)
		if btn_advance != null:
			if is_portrait:
				btn_advance.custom_minimum_size = Vector2(108, 54)
				btn_advance.add_theme_font_size_override("font_size", 18)
			else:
				btn_advance.custom_minimum_size = Vector2(196, 68)
				btn_advance.add_theme_font_size_override("font_size", 22)
		for btn: Button in [navigation.get("life"), navigation.get("family"), navigation.get("budget"), more_button]:
			if btn != null:
				btn.custom_minimum_size = Vector2(0, 48) if is_portrait else Vector2(0, 54)
				btn.add_theme_font_size_override("font_size", 11 if is_portrait else 14)
				btn.add_theme_constant_override("h_separation", 2 if is_portrait else 6)
	if stats_row != null:
		stats_row.add_theme_constant_override("separation", 8 if is_portrait else 18)
	if fields.has("tagline"):
		fields["tagline"].visible = not is_portrait or size.x >= 460
	if fields.has("name"):
		fields["name"].add_theme_font_size_override("font_size", 20 if is_portrait else 26)
