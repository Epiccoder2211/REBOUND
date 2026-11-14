extends RefCounted
static func panel(color: Color = Color("253650"), fill: Color = Color("0d172c"), radius: int = 18) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", Color("e2ebfa"))
	theme.set_color("font_color", "Button", Color("d8ecff"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("67778f"))
	theme.set_stylebox("normal", "Button", panel(Color("2c4d65"), Color("102036"), 12))
	theme.set_stylebox("hover", "Button", panel(Color("69d9e9"), Color("173149"), 12))
	theme.set_stylebox("pressed", "Button", panel(Color("e9ce91"), Color("1a3547"), 12))
	theme.set_stylebox("disabled", "Button", panel(Color("243149"), Color("0b1426"), 12))
	theme.set_stylebox("focus", "Button", panel(Color("a1dbe4"), Color(0,0,0,0), 12))
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_constant("separation", "VBoxContainer", 14)
	return theme
