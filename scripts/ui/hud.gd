extends CanvasLayer

const UITheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const POSTFX := preload("res://assets/shaders/postfx.gdshader")
## Full HUD: prompt, inspect, categorized journal, tapes, phone, captions, objectives,
## pause (with sound settings), endings, morning.

var prompt_label: Label
var objective_label: Label
var caption_label: Label
var inspect_panel: PanelContainer
var inspect_title: Label
var inspect_body: Label
var journal_panel: PanelContainer
var journal_label: RichTextLabel
var _fade_rect: ColorRect
var _postfx: ColorRect
var pause_panel: PanelContainer
var toast_label: Label
var phone_panel: PanelContainer
var phone_title: Label
var phone_body: Label
var tape_panel: PanelContainer
var tape_title: Label
var tape_body: Label
var credits_panel: PanelContainer
var ending_panel: PanelContainer
var _journal_open := false
var _pause_open := false
var _morning_armed := false
var _clues_meta: Dictionary = {}
var _docs: Dictionary = {}
var _tapes: Dictionary = {}
var _tape_by_clue: Dictionary = {}
var _caption_token := 0
## Event fired when the current phone message is dismissed (e.g. "voicemail_heard").
var _phone_event := ""
## Morning messages not shown yet; E shows them all at once instead of skipping them.
var _phone_pending: Array = []
var tape_rich: RichTextLabel
var _tape_lines: PackedStringArray = []
var _loading_panel: ColorRect
var _loading_label: Label
var _loading_bar: ProgressBar

func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_data()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make()
	add_child(root)
	# Vignette / film grain: its own canvas layer under the HUD so text stays clean.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = -1
	add_child(fx_layer)
	_postfx = ColorRect.new()
	_postfx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_postfx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = POSTFX
	_postfx.material = sm
	fx_layer.add_child(_postfx)
	add_to_group("postfx")
	apply_settings()

	# Objective on a soft dark backing (readable over bright rooms).
	var obj_bg := PanelContainer.new()
	obj_bg.name = "ObjectiveBox"
	obj_bg.position = Vector2(10, 8)
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color(0, 0, 0, 0.45)
	obj_style.set_corner_radius_all(6)
	obj_style.content_margin_left = 12
	obj_style.content_margin_right = 12
	obj_style.content_margin_top = 6
	obj_style.content_margin_bottom = 6
	obj_bg.add_theme_stylebox_override("panel", obj_style)
	obj_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(obj_bg)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.custom_minimum_size = Vector2(0, 0)
	obj_bg.add_child(objective_label)

	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.offset_top = -150
	prompt_label.offset_bottom = -120
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	prompt_label.add_theme_constant_override("outline_size", 6)
	root.add_child(prompt_label)

	caption_label = Label.new()
	caption_label.add_theme_font_size_override("font_size", 17)
	caption_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82))
	caption_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	caption_label.add_theme_constant_override("outline_size", 6)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_label.offset_top = -80
	caption_label.offset_bottom = -50
	root.add_child(caption_label)

	var cross := Label.new()
	cross.text = "·"
	cross.add_theme_font_size_override("font_size", 28)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cross.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(cross)

	inspect_panel = _modal(root, 440)
	inspect_title = _modal_title(inspect_panel, 20)
	inspect_body = _modal_body(inspect_panel, 420)

	phone_panel = _modal(root, 480)
	phone_title = _modal_title(phone_panel, 20)
	phone_body = _modal_body(phone_panel, 460)

	tape_panel = _modal(root, 500)
	tape_title = _modal_title(tape_panel, 20)
	tape_body = _modal_body(tape_panel, 480, "[E] stop")
	# Rich-text transcript so the line being played can be highlighted.
	tape_rich = RichTextLabel.new()
	tape_rich.bbcode_enabled = true
	tape_rich.fit_content = true
	tape_rich.custom_minimum_size = Vector2(460, 0)
	var tvb := _vb(tape_panel)
	tvb.add_child(tape_rich)
	tvb.move_child(tape_rich, tape_body.get_index())
	tape_body.visible = false

	credits_panel = _modal(root, 480)
	_modal_title(credits_panel, 22).text = "Morning"
	var cb := _modal_body(credits_panel, 460)
	cb.name = "CreditsBody"

	journal_panel = PanelContainer.new()
	journal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	journal_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	journal_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	journal_panel.offset_right = -16
	journal_panel.custom_minimum_size = Vector2(420, 460)
	journal_panel.visible = false
	root.add_child(journal_panel)
	var js := ScrollContainer.new()
	js.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_panel.add_child(js)
	journal_label = RichTextLabel.new()
	journal_label.bbcode_enabled = true
	journal_label.fit_content = true
	journal_label.custom_minimum_size = Vector2(390, 0)
	js.add_child(journal_label)

	_build_pause(root)

	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 40
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 17)
	root.add_child(toast_label)

	_loading_panel = ColorRect.new()
	_loading_panel.color = Color(0.02, 0.025, 0.04, 1.0)
	_loading_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_loading_panel)
	var lv := VBoxContainer.new()
	_centered(lv)
	lv.custom_minimum_size = Vector2(360, 0)
	_loading_panel.add_child(lv)
	_loading_label = Label.new()
	_loading_label.text = "Loading the house…"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_loading_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = 1.0
	_loading_bar.show_percentage = false
	lv.add_child(_loading_bar)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade_rect)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.connect("clue_found", _on_clue)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.connect("caption", show_caption)
		am.connect("narration_line", _on_narration_line)

func _exit_tree() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("stop_narration")
	get_tree().paused = false

# ---------------------------------------------------------------- building blocks
func _centered(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH

func _modal(root: Control, w: float) -> PanelContainer:
	var p := PanelContainer.new()
	_centered(p)
	p.custom_minimum_size = Vector2(w, 0)
	p.visible = false
	root.add_child(p)
	return p

func _vb(p: PanelContainer) -> VBoxContainer:
	if p.get_child_count() == 0:
		var vb := VBoxContainer.new()
		vb.name = "VB"
		vb.add_theme_constant_override("separation", 10)
		p.add_child(vb)
		return vb
	return p.get_node("VB") as VBoxContainer

func _modal_title(p: PanelContainer, fs: int) -> Label:
	var t := Label.new()
	t.add_theme_font_size_override("font_size", fs)
	_vb(p).add_child(t)
	return t

func _modal_body(p: PanelContainer, w: float, hint_text: String = "[E] to close") -> Label:
	var vb := _vb(p)
	var b := Label.new()
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(w - 20, 0)
	vb.add_child(b)
	var hint := Label.new()
	hint.text = hint_text
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(hint)
	return b

func _load_data() -> void:
	for pair in [["res://data/clues.json", "_clues_meta"], ["res://data/documents.json", "_docs"], ["res://data/tapes.json", "_tapes"]]:
		var path: String = pair[0]
		if FileAccess.file_exists(path):
			var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if j is Dictionary:
				set(pair[1], j)
	for k in _tapes.keys():
		_tape_by_clue[str((_tapes[k] as Dictionary).get("clue", k))] = k

func _build_pause(root: Control) -> void:
	pause_panel = PanelContainer.new()
	_centered(pause_panel)
	pause_panel.custom_minimum_size = Vector2(420, 0)
	pause_panel.visible = false
	root.add_child(pause_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pause_panel.add_child(pv)
	var pt := Label.new()
	pt.text = "Paused — Esc to resume"
	pt.add_theme_font_size_override("font_size", 20)
	pv.add_child(pt)
	for b in [["Resume", toggle_pause], ["Save", _on_save_pressed], ["Save + Return to Menu", _on_menu_pressed], ["Quit", func() -> void: get_tree().quit()]]:
		var btn := Button.new()
		btn.text = str(b[0])
		btn.pressed.connect(b[1])
		pv.add_child(btn)
	var sep := HSeparator.new()
	pv.add_child(sep)
	pv.add_child(SettingsPanel.new())

## Full-screen fade to `col` (alpha = target) over `dur` seconds.
func fade(target: float, dur: float, col: Color = Color(0, 0, 0)) -> void:
	_fade_rect.color = Color(col.r, col.g, col.b, _fade_rect.color.a)
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", target, dur)
	await tw.finished

## Vignette / grain from settings.
func apply_settings() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var st: Dictionary = gm.get("settings") if gm != null else {}
	var m := _postfx.material as ShaderMaterial
	m.set_shader_parameter("vignette", 0.45 if bool(st.get("vignette", true)) else 0.0)
	m.set_shader_parameter("grain", 0.035 if bool(st.get("film_grain", false)) else 0.0)
	_postfx.visible = bool(st.get("vignette", true)) or bool(st.get("film_grain", false))

## Loading screen. An empty text hides it.
func set_loading(text: String, progress: float) -> void:
	_loading_panel.visible = text != ""
	_loading_label.text = text
	_loading_bar.value = progress

# ---------------------------------------------------------------- loop + input
func _process(_delta: float) -> void:
	if _any_modal_open() or _pause_open or (ending_panel != null and ending_panel.visible):
		prompt_label.text = ""
		return
	if _loading_panel.visible:
		return
	# Browsers only lock the mouse after a click inside the page.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		prompt_label.text = "Click to look around"
		return
	var player: Node = _find_player()
	if player != null and player.has_method("current_focus"):
		var f: Variant = player.call("current_focus")
		prompt_label.text = ("[E]  " + str((f as Node).get("title"))) if f != null else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _any_modal_open():
			_close_top_modal()
		elif _journal_open:
			toggle_journal()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _pause_open:
		return
	if _any_modal_open() and event.is_action_pressed("interact"):
		_close_top_modal()
		get_viewport().set_input_as_handled()

func _any_modal_open() -> bool:
	return inspect_panel.visible or phone_panel.visible or tape_panel.visible or credits_panel.visible

func _close_top_modal() -> void:
	if credits_panel.visible:
		credits_panel.visible = false
	elif tape_panel.visible:
		tape_panel.visible = false
		var am: Node = get_node_or_null("/root/AudioManager")
		if am != null:
			am.call("stop_narration")
	elif phone_panel.visible:
		if not _phone_pending.is_empty():
			# Don't let an early E skip the conversation: show the rest, close on the next E.
			for m in _phone_pending:
				phone_body.text += "\n\n" + str(m)
			_phone_pending.clear()
			return
		phone_panel.visible = false
		var am2: Node = get_node_or_null("/root/AudioManager")
		if am2 != null:
			am2.call("stop_narration")
		if _phone_event != "":
			var em: Node = get_node_or_null("/root/EventManager")
			if em != null:
				em.call("fire", _phone_event)
			_phone_event = ""
		if _morning_armed:
			_morning_armed = false
			_show_credits_now()
	elif inspect_panel.visible:
		hide_inspect()

func toast(t: String, dur: float = 3.0) -> void:
	toast_label.text = t
	await get_tree().create_timer(dur).timeout
	if toast_label.text == t:
		toast_label.text = ""

## Subtitles for story-relevant sounds (knocks, steps, car...). Brief §21.
func show_caption(t: String, dur: float = 3.0) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and not bool((gm.get("settings") as Dictionary).get("subtitles", true)):
		return
	_caption_token += 1
	var tok := _caption_token
	caption_label.text = t
	await get_tree().create_timer(dur).timeout
	if tok == _caption_token:
		caption_label.text = ""

func set_objective(t: String) -> void:
	objective_label.text = t
	objective_label.get_parent().visible = t != ""

func _find_player() -> Node:
	var ps: Array = get_tree().get_nodes_in_group("player")
	if ps.size() > 0:
		return ps[0] as Node
	var cs: Node = get_tree().current_scene
	return cs.get_node_or_null("Player") if cs != null else null

func _open_modal(p: PanelContainer) -> void:
	for m in [inspect_panel, phone_panel, tape_panel, credits_panel]:
		if m != p:
			m.visible = false
	if not p.visible:
		p.modulate.a = 0.0
		create_tween().tween_property(p, "modulate:a", 1.0, 0.18)
	p.visible = true

# ---------------------------------------------------------------- panels
func show_inspect(title: String, body: String) -> void:
	inspect_title.text = title
	inspect_body.text = body
	_open_modal(inspect_panel)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("play_paper")

func hide_inspect() -> void:
	inspect_panel.visible = false

## Phone message. If `speaker` is set, the quoted part of the body is read aloud.
func show_phone(title: String, body: String, speaker: String = "", on_close_event: String = "") -> void:
	phone_title.text = title
	phone_body.text = body
	_phone_event = on_close_event
	_phone_pending.clear()
	_open_modal(phone_panel)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	am.call("play_buzz")
	if speaker != "":
		var q0: int = body.find("\"")
		var q1: int = body.rfind("\"")
		if q0 != -1 and q1 > q0:
			await get_tree().create_timer(1.1).timeout
			if phone_panel.visible:
				am.call("speak", speaker, body.substr(q0 + 1, q1 - q0 - 1))

func show_tape(tape_id: String) -> void:
	var d: Dictionary = _tapes.get(tape_id, {})
	tape_title.text = "▶ " + str(d.get("title", tape_id))
	tape_body.text = str(d.get("lines", ""))
	_tape_lines = str(d.get("lines", "")).split("
", false)
	_on_narration_line(-1)
	_open_modal(tape_panel)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am == null:
		return
	am.call("narrate", str(d.get("lines", "")))
	await am.narration_finished
	await get_tree().create_timer(1.5).timeout
	if not am.call("is_narrating"):
		tape_panel.visible = false

## Morning text exchange: Noa asks, Eitan answers (depends on the choice), Noa replies.
## Messages appear one by one; Noa's are read aloud.
## Highlights the transcript line currently playing; earlier lines are dimmed.
func _on_narration_line(index: int) -> void:
	var out: Array = []
	for i in _tape_lines.size():
		var l: String = _tape_lines[i].replace("[", "[lb]")
		if i == index:
			out.append("[color=#f2dfb6]▸ " + l + "[/color]")
		elif i < index:
			out.append("[color=#7d786f]" + l + "[/color]")
		else:
			out.append(l)
	tape_rich.text = "
".join(out)

func show_morning(e: Dictionary) -> void:
	_morning_armed = true
	var q := "Did you find what I left?"
	var reply: String = str(e.get("reply", "I don't know."))
	var noa: String = str(e.get("noa", ""))
	show_phone("NOA — 07:40", "Noa: \"" + q + "\"")
	var you_msg := "You: \"" + reply + "\""
	var noa_msg := "Noa: \"" + noa + "\""
	_phone_pending = [you_msg, noa_msg]
	var am: Node = get_node_or_null("/root/AudioManager")
	await get_tree().create_timer(1.1).timeout
	if am != null and phone_panel.visible and not _phone_pending.is_empty():
		await am.speak("noa", q)
	await get_tree().create_timer(0.8).timeout
	if not phone_panel.visible or not _phone_pending.has(you_msg):
		return
	_phone_pending.erase(you_msg)
	phone_body.text += "\n\n" + you_msg
	if am != null:
		am.call("play_ui")
	await get_tree().create_timer(2.2).timeout
	if not phone_panel.visible or not _phone_pending.has(noa_msg):
		return
	_phone_pending.erase(noa_msg)
	phone_body.text += "\n\n" + noa_msg
	if am != null:
		am.call("play_buzz")
		await get_tree().create_timer(0.9).timeout
		if phone_panel.visible:
			am.call("speak", "noa", noa)

func _show_credits_now() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var line := str(gm.call("final_text")) if gm != null and gm.has_method("final_text") else ""
	var cbl: Label = credits_panel.get_node("VB/CreditsBody") as Label
	cbl.text = line + "\n\nThe rain has stopped. The street looks ordinary.\nYou can keep walking the rooms.\n\nTHE HOUSE THAT FORGOT ME\nThanks for playing."
	_open_modal(credits_panel)

func toggle_journal() -> void:
	_journal_open = not _journal_open
	journal_panel.visible = _journal_open
	if _journal_open:
		journal_panel.modulate.a = 0.0
		create_tween().tween_property(journal_panel, "modulate:a", 1.0, 0.15)
	if _journal_open:
		_refresh_journal()

func toggle_pause() -> void:
	_pause_open = not _pause_open
	pause_panel.visible = _pause_open
	get_tree().paused = _pause_open
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		am.call("pause_narration", _pause_open)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _pause_open else Input.MOUSE_MODE_CAPTURED

func _on_save_pressed() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null:
		sm.call("save_game")
	toast("Saved.", 2.0)

func _on_menu_pressed() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm != null:
		sm.call("save_game")
	get_tree().paused = false
	pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await fade(1.0, 0.4)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _refresh_journal() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var found: Array = gm.get("clues_found") if gm != null else []
	if found.is_empty():
		journal_label.text = "[font_size=20]Journal[/font_size]   [color=#8a857c]J to close[/color]\n\n[i]Nothing yet.[/i]"
		return
	var groups := {"documents": [], "tapes": [], "photos": [], "findings": []}
	for c in found:
		var cs: String = str(c)
		var meta: Dictionary = _clues_meta.get(cs, {})
		var cat: String = str(meta.get("category", "findings"))
		var entry: String = "[b]" + str(meta.get("title", cs)) + "[/b]"
		if meta.has("location"):
			entry += "  [color=#8a857c]" + str(meta["location"]) + "[/color]"
		if _docs.has(cs):
			entry += "\n[indent][i]\"" + str(_docs[cs]) + "\"[/i][/indent]"
		elif _tape_by_clue.has(cs):
			entry += "\n[indent][color=#c9c2b4]" + str((_tapes[_tape_by_clue[cs]] as Dictionary).get("lines", "")) + "[/color][/indent]"
		if not groups.has(cat):
			groups[cat] = []
		(groups[cat] as Array).append(entry)
	var out := "[font_size=20]Journal[/font_size]   [color=#8a857c]J to close[/color]\n"
	for cat in ["documents", "tapes", "photos", "findings"]:
		var arr: Array = groups[cat]
		if not arr.is_empty():
			out += "\n[color=#dbb87f]" + cat.to_upper() + "[/color]\n" + "\n\n".join(arr) + "\n"
	journal_label.text = out

func _on_clue(clue_id: String) -> void:
	var meta: Dictionary = _clues_meta.get(clue_id, {})
	toast("Added to the journal — " + str(meta.get("title", clue_id)), 2.5)
	if _journal_open:
		_refresh_journal()

func show_endings() -> void:
	if ending_panel == null:
		ending_panel = PanelContainer.new()
		_centered(ending_panel)
		ending_panel.custom_minimum_size = Vector2(440, 0)
		(get_child(0) as Control).add_child(ending_panel)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		ending_panel.add_child(vb)
		var t := Label.new()
		t.text = "The photo. The recording. The letter.\nChoose the version you can live with:"
		vb.add_child(t)
		for o in [[1, "He left."], [2, "He came back. No one opened."], [3, "Memory is incomplete."]]:
			var b := Button.new()
			b.text = str(o[1])
			b.pressed.connect(_choose_ending.bind(int(o[0])))
			vb.add_child(b)
	ending_panel.visible = true
	hide_inspect.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var first := ending_panel.get_child(0).get_child(1) as Button
	first.grab_focus.call_deferred()

func _choose_ending(v: int) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("choose_ending"):
		gm.call("choose_ending", v)
	if ending_panel != null:
		ending_panel.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_objective("It is getting light. Open the front door.")
