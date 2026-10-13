extends RefCounted
## Shared UI look: dark translucent panels with a faint warm border, quiet buttons.

const TEXT := Color(0.9, 0.88, 0.82)
const TEXT_DIM := Color(0.66, 0.64, 0.6)
const ACCENT := Color(0.86, 0.72, 0.5)

static func _box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 6, mx: int = 14, my: int = 8, bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.035, 0.04, 0.055, 0.92), Color(0.86, 0.72, 0.5, 0.28), 8, 24, 18, 1))
	t.set_color("font_color", "Label", TEXT)
	# Dark outline on all text so it stays readable over bright scenes.
	for type in ["Label", "Button", "CheckButton", "CheckBox", "OptionButton"]:
		t.set_color("font_outline_color", type, Color(0, 0, 0, 0.85))
		t.set_constant("outline_size", type, 4)
	t.set_color("font_outline_color", "RichTextLabel", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "RichTextLabel", 4)
	t.set_color("default_color", "RichTextLabel", TEXT)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, _box(Color(0.1, 0.105, 0.12, 0.9), Color(1, 1, 1, 0.06), 5, 14, 8, 1))
		t.set_stylebox("hover", type, _box(Color(0.17, 0.16, 0.15, 0.95), Color(0.86, 0.72, 0.5, 0.45), 5, 14, 8, 1))
		t.set_stylebox("pressed", type, _box(Color(0.24, 0.21, 0.17, 0.95), Color(0.86, 0.72, 0.5, 0.7), 5, 14, 8, 1))
		t.set_stylebox("focus", type, _box(Color(0, 0, 0, 0), Color(0.86, 0.72, 0.5, 0.6), 5, 14, 8, 1))
		t.set_stylebox("disabled", type, _box(Color(0.07, 0.07, 0.08, 0.7), Color(0, 0, 0, 0), 5, 14, 8, 0))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color(1.0, 0.95, 0.86))
		t.set_color("font_pressed_color", type, ACCENT)
		t.set_color("font_disabled_color", type, Color(0.45, 0.44, 0.42))
	for type in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color(1.0, 0.95, 0.86))
		t.set_color("font_pressed_color", type, ACCENT)
		var clear := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 6, 4)
		for st in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
			t.set_stylebox(st, type, clear)
	t.set_stylebox("background", "ProgressBar", _box(Color(0.12, 0.12, 0.14, 1.0), Color(0, 0, 0, 0), 3, 0, 3))
	t.set_stylebox("fill", "ProgressBar", _box(ACCENT.darkened(0.25), Color(0, 0, 0, 0), 3, 0, 3))
	t.set_stylebox("slider", "HSlider", _box(Color(0.16, 0.16, 0.18, 1.0), Color(0, 0, 0, 0), 2, 0, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(ACCENT.darkened(0.3), Color(0, 0, 0, 0), 2, 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(ACCENT.darkened(0.1), Color(0, 0, 0, 0), 2, 0, 2))
	return t
