extends VBoxContainer
## Settings controls shared by the main menu and the pause menu. Changes apply live and
## are written to user://settings.cfg (never to the game save).

const SLIDERS := [
	["Master volume", "master_volume"],
	["Ambience (rain, house)", "ambience_volume"],
	["Story & voices", "story_volume"],
	["Effects", "sfx_volume"],
]
const TOGGLES := [
	["Voices (text-to-speech)", "voices"],
	["Subtitles for sounds", "subtitles"],
	["Vignette", "vignette"],
	["Film grain", "film_grain"],
]

func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var st: Dictionary = _settings()
	for s in SLIDERS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = str(s[0])
		l.custom_minimum_size = Vector2(190, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.01
		sl.custom_minimum_size = Vector2(170, 20)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.value = float(st.get(s[1], 0.8))
		sl.value_changed.connect(_change.bind(str(s[1])))
		row.add_child(sl)
		add_child(row)
	var mrow := HBoxContainer.new()
	var ml := Label.new()
	ml.text = "Mouse sensitivity"
	ml.custom_minimum_size = Vector2(190, 0)
	mrow.add_child(ml)
	var ms := HSlider.new()
	ms.min_value = 0.0008
	ms.max_value = 0.006
	ms.step = 0.0001
	ms.custom_minimum_size = Vector2(170, 20)
	ms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ms.value = float(st.get("mouse_sensitivity", 0.0025))
	ms.value_changed.connect(_change.bind("mouse_sensitivity"))
	mrow.add_child(ms)
	add_child(mrow)
	var grow := HBoxContainer.new()
	var gl := Label.new()
	gl.text = "Graphics"
	gl.custom_minimum_size = Vector2(190, 0)
	grow.add_child(gl)
	var gq := OptionButton.new()
	for q in ["Low (fastest)", "Medium", "High"]:
		gq.add_item(q)
	gq.selected = int(st.get("graphics", 1))
	gq.item_selected.connect(func(i: int) -> void: _change(i, "graphics"))
	grow.add_child(gq)
	add_child(grow)
	for s in TOGGLES:
		var cb := CheckButton.new()
		cb.text = str(s[0])
		cb.button_pressed = bool(st.get(s[1], true))
		cb.toggled.connect(_change.bind(str(s[1])))
		add_child(cb)

func _settings() -> Dictionary:
	var gm: Node = get_node_or_null("/root/GameManager")
	return gm.get("settings") if gm != null else {}

func _change(v: Variant, key: String) -> void:
	var st: Dictionary = _settings()
	st[key] = v
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("apply_settings", st)
		if key == "voices" and not bool(v):
			am.call("stop_narration")
	var cs: Node = get_tree().current_scene
	if key == "graphics" and cs != null and cs.has_method("apply_graphics"):
		cs.call("apply_graphics")
	get_tree().call_group("postfx", "apply_settings")
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null:
		sm.call("save_settings")
