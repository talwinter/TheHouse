extends SceneTree
## Stress: start a tape, press E after varying delays, repeat. A hang shows up as the
## process never reaching the next iteration (the runner's timeout catches it).
const DELAYS := [0.3, 0.8, 1.4, 2.0, 2.9, 3.6, 4.4, 5.3, 6.1, 7.0]
var _i: Node
var _t := 0.0
var _k := 0
var _armed := false
var _last := 0
var _worst := 0
func _process(d: float) -> bool:
	if _i == null:
		var gm: Node = root.get_node("/root/GameManager")
		gm.get("settings")["voices"] = true
		gm.get("settings")["story_volume"] = 0.15
		_i = (load("res://scenes/levels/house_entry.tscn") as PackedScene).instantiate()
		root.add_child(_i)
		return false
	if not bool(_i.get("is_built")):
		return false
	var now := Time.get_ticks_msec()
	if _last > 0:
		_worst = maxi(_worst, now - _last)
	_last = now
	var hud: Node = get_nodes_in_group("hud")[0]
	_t += d
	if not _armed:
		hud.call("_close_top_modal")
		hud.call("show_tape", ["tape1_living", "study_tapes", "last_tape"][_k % 3])
		_armed = true
		_t = 0.0
		return false
	if _t > DELAYS[_k]:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventAction.new()
		ev2.action = "interact"
		ev2.pressed = false
		Input.parse_input_event(ev2)
		print("STRESS %d delay %.1fs worst frame so far %d ms" % [_k, DELAYS[_k], _worst])
		_k += 1
		_armed = false
		if _k >= DELAYS.size():
			print("STRESS DONE worst frame ", _worst, " ms, panel=", (hud.get("tape_panel") as Control).visible)
			quit(0)
			return true
	return false
