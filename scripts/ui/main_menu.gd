extends Control
## Main menu: Continue / New Game / Settings / Quit. First scene.

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var settings_panel: PanelContainer
var _fade: ColorRect

func _ready() -> void:
	theme = UITheme.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.offset_left = 120
	vb.custom_minimum_size = Vector2(320, 0)
	add_child(vb)
	var title := Label.new()
	title.text = "The House That Forgot Me"
	title.add_theme_font_size_override("font_size", 34)
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "A quiet house. 02:17."
	sub.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vb.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	vb.add_child(spacer)
	var sm: Node = get_node_or_null("/root/SaveManager")
	var has_save: bool = sm != null and bool(sm.call("has_save"))
	var b_cont := _button(vb, "Continue", _on_continue)
	b_cont.disabled = not has_save
	_button(vb, "New Game", _on_new)
	_button(vb, "Settings", func() -> void: settings_panel.visible = not settings_panel.visible)
	_button(vb, "Quit", func() -> void: get_tree().quit())
	if not has_save:
		var nl := Label.new()
		nl.text = "No save yet."
		nl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		vb.add_child(nl)

	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	settings_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	settings_panel.offset_left = 140
	settings_panel.offset_right = 140
	settings_panel.visible = false
	add_child(settings_panel)
	settings_panel.add_child(SettingsPanel.new())

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.8)
	if has_save:
		b_cont.grab_focus()
	else:
		(vb.get_child(4) as Button).grab_focus()

func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void:
		var am: Node = get_node_or_null("/root/AudioManager")
		if am != null:
			am.call("play_ui"))
	parent.add_child(b)
	return b

func _go_to_house() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file("res://scenes/levels/house_entry.tscn"))

func _on_continue() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null:
		sm.call("load_game")
	_go_to_house()

func _on_new() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null:
		sm.call("clear_save")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.set("chapter", 1)
		gm.set("ending_choice", 0)
		(gm.get("clues_found") as Array).clear()
		var em: Node = get_node_or_null("/root/EventManager")
		if em != null:
			em.call("reset_all")
	_go_to_house()
