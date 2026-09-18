extends RefCounted
## Shared visual tokens; presentation only.

const INK = Color("293d33")
const MUTED = Color("788174")
const PAPER = Color("fffcf6")
const BACKGROUND = Color("f4f1e9")
const LINE = Color("e0e2d7")
const GREEN = Color("748e78")
const RUST = Color("ad593d")
const DARK = Color("243d33")
const SERIF = preload("res://assets/fonts/NotoSerifDisplay-Regular.ttf")
const SANS = preload("res://assets/fonts/NotoSans-Regular.ttf")


static func box(color: Color, radius: int = 12, border: Color = Color.TRANSPARENT,
		padding: int = 18) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.border_color = border
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


static func create() -> Theme:
	var theme = Theme.new()
	theme.default_font = SANS
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "CheckBox", INK)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_color", "SpinBox", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_stylebox("panel", "PanelContainer", box(PAPER, 14, LINE))
	for type_name: String in ["Button", "Primary", "Navigation", "SelectedNav", "Ghost", "Choice"]:
		if type_name != "Button":
			theme.set_type_variation(type_name, "Button")
		var bg = PAPER
		var hover = Color("eaece1")
		var foreground = INK
		var border = LINE
		if type_name == "Primary":
			bg = RUST
			hover = Color("934930")
			foreground = Color("fffaf0")
			border = Color.TRANSPARENT
		elif type_name in ["Navigation", "SelectedNav"]:
			bg = Color("365246") if type_name == "SelectedNav" else DARK
			hover = Color("3a5648")
			foreground = Color("f4f0df") if type_name == "SelectedNav" else Color("b7c6b7")
			border = Color.TRANSPARENT
		elif type_name == "Ghost":
			bg = BACKGROUND
			border = Color.TRANSPARENT
		elif type_name == "Choice":
			bg = Color("fffaf0")
			border = Color("d9cfb7")
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var fill: Color = hover if state in ["hover", "pressed"] else bg
			if state == "disabled":
				fill = Color("e7e5dc")
			var style = box(fill, 9, border, 12)
			style.content_margin_left = 16
			style.content_margin_right = 16
			theme.set_stylebox(state, type_name, style)
		var focus = box(Color.TRANSPARENT, 9, GREEN, 0)
		focus.set_border_width_all(2)
		theme.set_stylebox("focus", type_name, focus)
		for property: String in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
			theme.set_color(property, type_name, foreground)
		theme.set_color("font_disabled_color", type_name, MUTED)
		theme.set_constant("h_separation", type_name, 12)
		theme.set_constant("icon_max_width", type_name, 20)
	theme.set_stylebox("normal", "LineEdit", box(Color("f1f0e8"), 8, LINE, 10))
	theme.set_stylebox("focus", "LineEdit", box(Color("f1f0e8"), 8, GREEN, 10))
	theme.set_stylebox("background", "ProgressBar", box(Color("e8eade"), 3, Color.TRANSPARENT, 0))
	theme.set_stylebox("fill", "ProgressBar", box(GREEN, 3, Color.TRANSPARENT, 0))
	theme.set_stylebox("scroll", "VScrollBar", box(Color.TRANSPARENT, 3, Color.TRANSPARENT, 3))
	theme.set_stylebox("grabber", "VScrollBar", box(Color("c8cdbd"), 3, Color.TRANSPARENT, 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(GREEN, 3, Color.TRANSPARENT, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(GREEN, 3, Color.TRANSPARENT, 3))
	return theme
