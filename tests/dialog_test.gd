extends SceneTree
## Early-E checks for dialogues:
##  1. closing the voicemail before the voice finishes still updates the objective;
##  2. pressing E during the morning exchange shows every message instead of skipping them,
##     and only a second E closes the phone (then the credits appear).
##   Godot_console.exe --path . --script res://tests/dialog_test.gd -- testsave

var _i: Node
var _t := 0.0
var _step := 0
var _fails: Array = []

func _check(c: bool, msg: String) -> void:
	print("DIALOG ", "ok   " if c else "FAIL ", msg)
	if not c:
		_fails.append(msg)

func _e() -> void:
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = p
		Input.parse_input_event(ev)

func _process(d: float) -> bool:
	if _i == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
		root.get_node("/root/GameManager").get("settings")["voices"] = true
		root.get_node("/root/GameManager").get("settings")["story_volume"] = 0.15
		_i = (load("res://scenes/levels/house_entry.tscn") as PackedScene).instantiate()
		root.add_child(_i)
		return false
	if not bool(_i.get("is_built")):
		return false
	_t += d
	var hud: Node = get_nodes_in_group("hud")[0]
	var obj := hud.get("objective_label") as Label
	var phone := hud.get("phone_panel") as Control
	var body := hud.get("phone_body") as Label
	match _step:
		0:
			_check(obj.text.contains("Listen"), "objective before the voicemail: " + obj.text)
			_step = 1
			_t = 0.0
		1:
			if _t > 2.0:          # Noa is still talking
				_e()
				_step = 2
				_t = 0.0
		2:
			if _t > 0.3:
				_check(not phone.visible, "early E closes the voicemail")
				_check(obj.text.contains("kitchen"), "objective after an early E: " + obj.text)
				var gm: Node = root.get_node("/root/GameManager")
				gm.set("ending_choice", 2)
				hud.call("show_morning", gm.call("ending"))
				_step = 3
				_t = 0.0
		3:
			if _t > 0.6:          # only Noa's question is on screen yet
				_e()
				_step = 4
				_t = 0.0
		4:
			if _t > 0.3:
				_check(phone.visible, "first E during the exchange keeps the phone open")
				_check(body.text.contains("You:") and body.text.count("Noa:") == 2, "all messages shown after the first E")
				_e()
				_step = 5
				_t = 0.0
		5:
			if _t > 0.3:
				_check(not phone.visible and (hud.get("credits_panel") as Control).visible, "second E closes the phone and shows the credits")
				# the coroutine must not append anything later
				_step = 6
				_t = 0.0
		6:
			if _t > 4.0:
				_check(body.text.count("Noa:") == 2 and body.text.count("You:") == 1, "no duplicated messages afterwards")
				print("DIALOG RESULT ", "ALL PASSED" if _fails.is_empty() else "FAILURES: " + str(_fails))
				quit(0 if _fails.is_empty() else 1)
				return true
	return false
