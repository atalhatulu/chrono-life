extends Control
## Chronicle presentation. Simulation ownership remains in SimulationRunner.

const Content = preload("res://simulation/content_registry.gd")
const Runner = preload("res://simulation/simulation_runner.gd")
const Delta = preload("res://simulation/year_delta.gd")
const Palette = preload("res://ui/chronicle_theme.gd")
const Words = preload("res://ui/chronicle_text.gd")

var pack: Dictionary = {}
var runner: RefCounted
var state: Dictionary = {}
var pending_prep: Dictionary = {}
var pages: Array[Dictionary] = []
var current_view: String = "life"
var fields: Dictionary = {}
var navigation: Dictionary = {}
var bars: Dictionary = {}
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


func _label(text: String, font_size: int = 14, color: Color = Palette.INK,
		serif: bool = false, wrap: bool = false) -> Label:
	var label := Label.new()
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
	var label := _label(text, font_size, color, serif, wrap)
	label.name = key
	parent.add_child(label)
	fields[key] = label
	return label


func _column(gap: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", gap)
	return box


func _row(gap: int = 12) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	return box


func _spacer(parent: Node, vertical: bool = false) -> Control:
	var spacer := Control.new()
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer


func _button(text: String, action: Callable, variation: String = "Button", icon: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 44
	if icon != "":
		button.icon = load("res://assets/ui/%s.svg" % icon)
	button.pressed.connect(action)
	return button


func _card(parent: Node, padding: int = 18) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, 12, Palette.LINE, padding))
	parent.add_child(panel)
	var column := _column(10)
	panel.add_child(column)
	return column


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _build() -> void:
	var background := ColorRect.new()
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
	var body := _row(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_column.add_child(body)
	content_column = _column(12)
	body.add_child(content_column)
	var section := _row()
	content_column.add_child(section)
	_field(section, "section", "Hayatından sayfalar", 22, Palette.INK, true)
	_spacer(section)
	filter_button = _button("Tüm yıllar", _toggle_filter, "Ghost")
	filter_button.add_theme_font_size_override("font_size", 12)
	section.add_child(filter_button)
	var scroll := ScrollContainer.new()
	chronicle_scroll = scroll
	scroll.name = "ChronicleScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_column.add_child(scroll)
	var stack := _column(12)
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
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(side_scroll)
	side_info = _column(16)
	side_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_info)
	error_label = _label("", 13, Palette.RUST, false, true)
	error_label.hide()
	main_column.add_child(error_label)
	var footer := _row(12)
	main_column.add_child(footer)
	var footer_copy := _column(2)
	footer.add_child(footer_copy)
	_field(footer_copy, "footer", "Her yıl yeni bir sayfa.", 13)
	_field(footer_copy, "hint", "Büyük kararları şimdilik ailen veriyor.", 11, Palette.MUTED, false, true)
	return_to_decision = _button("Karara dön", func(): switch_view("life"), "Ghost", "arrow")
	footer.add_child(return_to_decision)
	_build_dock(main_column)
	_build_stats(main_column)
	_build_modal()


func _build_header(parent: Node) -> void:
	var header := _row(12)
	parent.add_child(header)
	header.add_child(_label("C H R O N O L I F E", 16, Palette.INK))
	_field(header, "tagline", "Bir hayat. Bir hikâye.", 13, Palette.MUTED, true)
	_spacer(header)
	var settings := _button("Ayarlar", _open_tools, "Ghost", "settings")
	settings.tooltip_text = "Simülasyon bilgileri ve otomatik karar ayarları"
	header.add_child(settings)
	var profile := _row(18)
	parent.add_child(profile)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(64, 64)
	badge.add_theme_stylebox_override("panel", Palette.box(Palette.DARK, 32, Color.TRANSPARENT, 8))
	profile.add_child(badge)
	var initials := _field(badge, "initials", "WT", 24, Palette.PAPER, true)
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var identity := _column(2)
	profile.add_child(identity)
	var name_label := _field(identity, "name", "William Thompson", 29, Palette.INK, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 200
	_field(identity, "age", "0 yaş · İlk yıllar", 13, Palette.MUTED)
	var balance := _column(2)
	balance.size_flags_horizontal = Control.SIZE_SHRINK_END
	profile.add_child(balance)
	var caption := _label("HANE BİRİKİMİ", 10, Palette.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance.add_child(caption)
	var savings := _field(balance, "savings", "0", 27, Palette.INK, true)
	savings.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	savings.tooltip_text = "Ailenin ortak birikimi · test birimi"


func _build_hero(parent: Node) -> void:
	var hero := Control.new()
	hero_banner = hero
	hero.custom_minimum_size.y = 64
	hero.clip_contents = true
	parent.add_child(hero)
	var background := ColorRect.new()
	background.color = Color("e7e6d7")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(background)
	var texture := TextureRect.new()
	texture.texture = preload("res://assets/ui/manchester.svg")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.anchor_left = 0.45
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(texture)
	var copy := _row(18)
	copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	copy.offset_left = 18
	copy.offset_right = -18
	hero.add_child(copy)
	_field(copy, "year", "1850", 31, Palette.INK, true)
	var location := _column(1)
	location.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_child(location)
	_field(location, "location", "MANCHESTER, İNGİLTERE", 10, Palette.INK)
	_field(location, "hero_caption", "Hikâyen burada başlıyor.", 12, Palette.INK)


func _build_dock(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.DARK, 16, Color.TRANSPARENT, 10))
	parent.add_child(panel)
	action_dock = _row(8)
	panel.add_child(action_dock)
	for item: Array in [["life", "Hayatım", "book"], ["family", "Ailem", "family"], ["advance", "+1 yıl", ""], ["auto", "Oto hayat", ""], ["budget", "Geçim", "wallet"], ["new", "Yeni hayat", "plus"]]:
		var key: String = item[0]
		var action: Callable = func(): switch_view(key)
		if key == "advance":
			action = _on_advance_pressed
		elif key == "auto":
			action = _run_auto_life
		elif key == "new":
			action = _open_new_game
		var button := _button(item[1], action, "Primary" if key == "advance" else "Navigation", item[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.custom_minimum_size.y = 54
		action_dock.add_child(button)
		if key == "advance":
			btn_advance = button
			button.name = "AdvanceYear"
			button.custom_minimum_size = Vector2(196, 68)
			button.add_theme_font_size_override("font_size", 22)
		elif key == "new":
			button.name = "NewLife"
		else:
			button.name = "Nav_" + key
			navigation[key] = button


func _build_stats(parent: Node) -> void:
	var stats := _row(18)
	parent.add_child(stats)
	for item: Array in [["health", "Sağlık"], ["literacy", "Okuryazarlık"], ["willpower", "İrade"]]:
		var stat := _column(6)
		stats.add_child(stat)
		var line := _row()
		stat.add_child(line)
		line.add_child(_label(item[1], 12, Palette.MUTED))
		_spacer(line)
		_field(line, item[0], "100", 12)
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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 460
	panel.add_theme_stylebox_override("panel", Palette.box(Palette.PAPER, 16, Palette.LINE, 28))
	center.add_child(panel)
	var content := _column(18)
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
		var note := _label("0 ile 2147483647 arasında bir tam sayı gir.", 12, Palette.RUST)
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
	if runner == null or _busy:
		return
	_busy = true
	var seed_value: int = str(state.meta.master_seed).to_int()
	var result: Dictionary = runner.simulate_auto_life(seed_value, "balanced")
	_busy = false
	if not result.ok:
		_show_error("Otomatik hayat tamamlanamadı: " + str(result.get("errors", [])))
		return
	state = result.state
	pending_prep = {}
	var summary: Dictionary = result.life_result
	modal_title.text = "Hayat tamamlandı"
	_clear(modal_body)
	seed_input.hide()
	auto_policy.hide()
	modal_body.add_child(_label("%s · %d yaş" % [summary.name, summary.age_at_death], 20, Palette.INK, true))
	modal_body.add_child(_label("Ölüm: %s\nOkuryazarlık: %d\nSon birikim: %d\nBorç: %d\nEvlilik: %s\nÇocuk: %d\nToplam aktivite: %d" % [
		summary.death_cause if summary.death_cause != "" else "Hayat sınırı",
		summary.literacy, summary.final_savings, summary.final_debt,
		summary.marital_status, summary.children, result.actions.size()], 14, Palette.INK, false, true))
	modal_body.add_child(_label("Aktiviteler: " + str(summary.actions), 12, Palette.MUTED, false, true))
	overlay.show()
	_refresh_ui()


func _open_tools() -> void:
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
	if view not in ["life", "family", "budget"]:
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
	pages.append(Words.page(result.events, state))


func _show_error(message: String) -> void:
	error_label.text = message
	error_label.show()


func _refresh_ui() -> void:
	if state.is_empty():
		return
	var player: Dictionary = state.actors[state.meta.player_id]
	fields.name.text = player.name
	fields.age.text = "%d yaş · %s" % [player.age, Words.stage(int(player.age))]
	fields.location.text = "MANCHESTER, İNGİLTERE"
	fields.year.text = str(state.world.year)
	fields.initials.text = ""
	for part: String in str(player.name).split(" ", false):
		fields.initials.text += part.left(1)
	fields.savings.text = str(state.household.savings)
	fields.hero_caption.text = "Hikâyen burada başlıyor." if player.age == 0 else "Bu yıl, hayatının %d. sayfası." % player.age
	if not player.alive:
		fields.hero_caption.text = "Yaşanmış bir hayat, geride kalan izler."
	for key: String in bars:
		bars[key].value = player[key]
		fields[key].text = str(player[key])
	for key: String in navigation:
		navigation[key].theme_type_variation = "SelectedNav" if key == current_view else "Navigation"
	fields.section.text = {"life": "Hayatından sayfalar", "family": "Seni çevreleyen insanlar", "budget": "Evin geçimi"}[current_view]
	filter_button.visible = current_view == "life"
	filter_button.text = "Önemli anlar" if show_quiet else "Tüm yıllar"
	btn_advance.disabled = not player.alive or not pending_prep.is_empty() or _busy
	btn_advance.text = "Hayat tamamlandı" if not player.alive else ("Kararını bekliyor" if not pending_prep.is_empty() else "+1 yıl")
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
	var wording: Array = Words.STORIES.get(story.id, [story.title, story.text])
	decision_box.add_child(_label("%d  /  BİR KARAR ZAMANI" % pending_prep.year, 11, Palette.RUST))
	decision_box.add_child(_label(wording[0], 25, Palette.INK, true, true))
	decision_box.add_child(_label(wording[1], 14, Palette.INK, false, true))
	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 12)
	choices.add_theme_constant_override("v_separation", 10)
	decision_box.add_child(choices)
	for choice: Dictionary in story.choices:
		var copy: Array = Words.CHOICES.get(choice.id, [choice.label, choice.description])
		var id: String = choice.id
		var button := _button(str(copy[0]) + "\n" + str(copy[1]), func(): _on_choice_selected(id), "Choice")
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 68
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.name = "Choice_" + id
		choices.add_child(button)
		choice_buttons.append(button)


func _render_feed() -> void:
	_clear(feed)
	feed.add_theme_constant_override("separation", 0 if current_view == "life" else 12)
	if current_view == "family":
		_render_family(feed)
		return
	if current_view == "budget":
		_render_budget(feed)
		return
	if not state.actors[state.meta.player_id].alive:
		var memorial := _card(feed)
		memorial.add_child(_label("BİR HAYATIN ARDINDAN", 10, Palette.RUST))
		memorial.add_child(_label(state.actors[state.meta.player_id].name, 27, Palette.INK, true))
		memorial.add_child(_label("%s · %s" % ["%d — %d" % [state.actors[state.meta.player_id].birth_year, state.actors[state.meta.player_id].death_year], Words.word(str(state.actors[state.meta.player_id].death_cause))], 13, Palette.MUTED, false, true))
		memorial.add_child(_button("Yeni bir hayat başlat", _open_new_game, "Primary"))
	for index: int in range(pages.size() - 1, -1, -1):
		var page: Dictionary = pages[index]
		if not show_quiet and not page.important:
			continue
		var entry := _row(20)
		feed.add_child(entry)
		var date := _column(2)
		date.size_flags_horizontal = Control.SIZE_FILL
		date.custom_minimum_size.x = 72
		entry.add_child(date)
		date.add_child(_label(str(page.year), 23, Palette.RUST, true))
		var age: int = int(page.year) - int(state.actors[state.meta.player_id].birth_year)
		date.add_child(_label("%d yaş" % age, 11, Palette.MUTED))
		var copy := _column(5)
		entry.add_child(copy)
		copy.add_child(_label(page.title, 19, Palette.INK, true, true))
		copy.add_child(_label(page.body, 14, Color("637063"), false, true))
		var separator := HSeparator.new()
		separator.add_theme_stylebox_override("separator", Palette.box(Palette.LINE, 0, Color.TRANSPARENT, 0))
		separator.add_theme_constant_override("separation", 25)
		feed.add_child(separator)


func _render_family(parent: Node, compact: bool = false) -> void:
	var player_id: String = state.meta.player_id
	var ids: Array = state.actors.keys()
	ids.sort()
	for id: String in ids:
		if id == player_id:
			continue
		var actor: Dictionary = state.actors[id]
		var column: VBoxContainer = _column(3) if compact else _card(parent)
		if compact:
			parent.add_child(column)
		var relation: String = "Aile üyesi"
		if id in ["parent_1", "parent_2"]:
			relation = "Annen" if actor.get("sex", "male") == "female" else "Baban"
		elif id == "spouse":
			relation = "Eşin"
		elif id.begins_with("child"):
			relation = "Çocuğun"
		column.add_child(_label(relation.to_upper(), 9, Palette.MUTED))
		column.add_child(_label(str(actor.name), 15 if compact else 21, Palette.INK, true, true))
		column.add_child(_label("%d yaş · %s" % [actor.age, "Hayatta" if actor.alive else "Anısına"], 11, Palette.MUTED))
		if not compact:
			column.add_child(_label(Words.word(str(actor.occupation_id)) if actor.alive else "%d yılında hayatını kaybetti." % actor.death_year, 13, Palette.MUTED, false, true))


func _render_budget(parent: Node) -> void:
	var column := _card(parent)
	column.add_child(_label("AİLENİN ORTAK BÜTÇESİ", 10, Palette.MUTED))
	column.add_child(_label(Words.word(str(state.household.living_standard)), 23, Palette.INK, true, true))
	var has_ledger: bool = not state.ledgers.is_empty()
	var ledger: Dictionary = state.ledgers.back() if has_ledger else {}
	for item: Array in [["Kazanılan gelir", ledger.get("earned_income", 0)], ["Dışarıdan destek", ledger.get("external_income", 0)], ["Yıllık ihtiyaç", ledger.get("planned_expenses", 0)], ["Karşılanamayan ihtiyaç", ledger.get("unmet_needs", 0)], ["Birikim", state.household.savings], ["Borç", state.household.debt]]:
		var row := _row()
		column.add_child(row)
		row.add_child(_label(item[0], 14, Palette.MUTED))
		_spacer(row)
		row.add_child(_label(str(item[1]), 17, Palette.INK, true))
	column.add_child(_label("Son tamamlanan yılın hesabı. Tutarlar test birimidir." if has_ledger else "İlk yılın hesabı henüz kapanmadı. Tutarlar test birimidir.", 11, Palette.MUTED, false, true))
	column.add_child(_label("Gıda ihtiyacının %%%d kadarı karşılanıyor." % int(state.household.food_security / 10), 13, Palette.MUTED, false, true))


func _render_sidebar() -> void:
	_clear(side_info)
	side_info.add_child(_label("EVİNDE HAYAT", 10, Palette.MUTED))
	side_info.add_child(_label(Words.word(str(state.household.living_standard)), 20, Palette.INK, true, true))
	var summary := _row(16)
	side_info.add_child(summary)
	for item: Array in [["BİRİKİM", state.household.savings], ["BORÇ", state.household.debt]]:
		var value := _column(2)
		summary.add_child(value)
		value.add_child(_label(item[0], 9, Palette.MUTED))
		value.add_child(_label(str(item[1]), 24, Palette.INK, true))
	side_info.add_child(_button("Bütçeyi incele", func(): switch_view("budget"), "Ghost"))
	side_info.add_child(HSeparator.new())
	side_info.add_child(_label("YANINDAKİ İNSANLAR", 10, Palette.MUTED))
	_render_family(side_info, true)
	side_info.add_child(_button("Ailene bak", func(): switch_view("family"), "Ghost"))


func _responsive() -> void:
	if hero_banner != null:
		hero_banner.visible = size.y >= 760
		main_column.add_theme_constant_override("separation", 14 if size.y >= 760 else 10)
	if right_panel != null:
		right_panel.visible = size.x >= 1280
	if page_margin != null:
		var inset: int = maxi(24, int((size.x - 1280) / 2))
		page_margin.add_theme_constant_override("margin_left", inset)
		page_margin.add_theme_constant_override("margin_right", inset)
		page_margin.add_theme_constant_override("margin_top", 12)
		page_margin.add_theme_constant_override("margin_bottom", 16)
