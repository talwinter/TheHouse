extends SceneTree
## Repro: open a tape (voices on), press E mid-sentence, check the game keeps running
## and the player can still move afterwards.
var _i: Node
var _t := 0.0
var _phase := 0
var _last := 0
var _worst := 0
var _p0: Vector3
func _press(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)
func _process(d: float) -> bool:
	if _i == null:
		var gm: Node = root.get_node("/root/GameManager")
		gm.get("settings")["voices"] = true
		gm.get("settings")["story_volume"] = 0.2
		_i = (load("res://scenes/levels/house_entry.tscn") as PackedScene).instantiate()
		root.add_child(_i)
		return false
	if not bool(_i.get("is_built")):
		return false
	var now := Time.get_ticks_msec()
	if _last > 0:
		_worst = maxi(_worst, now - _last)
	_last = now
	_t += d
	var hud: Node = get_nodes_in_group("hud")[0]
	match _phase:
		0:
			hud.call("_close_top_modal")
			hud.call("show_tape", "tape1_living")
			_phase = 1
			_t = 0.0
		1:
			if _t > 2.5:
				print("STOP pressing E while narrating=", root.get_node("/root/AudioManager").call("is_narrating"))
				_worst = 0
				_press("interact", true)
				_phase = 2
				_t = 0.0
		2:
			if _t > 0.1:
				_press("interact", false)
				_phase = 3
				_t = 0.0
		3:
			if _t > 2.0:
				print("STOP after E: tape panel visible=", (hud.get("tape_panel") as Control).visible, " narrating=", root.get_node("/root/AudioManager").call("is_narrating"), " worst frame=", _worst, "ms paused=", paused)
				var pl := _i.get_node("Player") as Node3D
				_p0 = pl.global_position
				_press("move_forward", true)
				_phase = 4
				_t = 0.0
		4:
			if _t > 1.5:
				_press("move_forward", false)
				var pl2 := _i.get_node("Player") as Node3D
				print("STOP player moved ", _p0.distance_to(pl2.global_position), " m; mouse_mode=", Input.mouse_mode, " modal_open=", hud.call("_any_modal_open"))
				quit(0)
				return true
	return false
