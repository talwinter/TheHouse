extends SceneTree
## FPS benchmark at fixed views (real window, real renderer). Prints avg/worst frame ms.
##   Godot_console.exe --path . --script res://tests/fps_bench.gd -- [low]
const VIEWS := [
	["hall", Vector3(0.4, 1.6, -3.4), Vector3(0.6, 1.2, 4.8)],
	["kitchen", Vector3(-2.0, 1.6, -1.2), Vector3(-3.6, 0.9, -4.6)],
	["living", Vector3(3.6, 1.6, 0.2), Vector3(4.6, 0.7, -3.4)],
	["noa", Vector3(-2.4, 1.6, 2.0), Vector3(-5.0, 0.6, 4.2)],
	["outside", Vector3(-2.4, 1.7, 10.5), Vector3(0.0, 1.2, 5.0)],
	["basement", Vector3(1.5, -1.0, 9.9), Vector3(1.5, -2.2, 12.6)],
]
var _inst: Node3D
var _cam: Camera3D
var _vi := -1
var _f := 0
var _acc := 0.0
var _worst := 0.0
var _last := 0
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm != null:
		gm.get("settings")["voices"] = false
		if "low" in OS.get_cmdline_user_args():
			gm.get("settings")["graphics"] = 0
	_inst = (load("res://scenes/levels/house_entry.tscn") as PackedScene).instantiate()
	root.add_child(_inst)
func _process(_d: float) -> bool:
	if not bool(_inst.get("is_built")):
		return false
	if _cam == null:
		var pl := _inst.get_node("Player")
		pl.process_mode = Node.PROCESS_MODE_DISABLED
		(_inst.get_node("HUD") as CanvasLayer).visible = false
		_cam = Camera3D.new()
		_cam.fov = 70
		_inst.add_child(_cam)
		_cam.make_current()
	var now := Time.get_ticks_usec()
	if _f == 0:
		_vi += 1
		if _vi >= VIEWS.size():
			quit(0)
			return true
		var v: Array = VIEWS[_vi]
		_cam.global_transform = Transform3D(Basis(), v[1]).looking_at(v[2], Vector3.UP)
		_acc = 0.0
		_worst = 0.0
	elif _f > 20:
		var dt := (now - _last) / 1000.0
		_acc += dt
		_worst = maxf(_worst, dt)
	_last = now
	_f += 1
	if _f > 140:
		var avg := _acc / 120.0
		print("FPS %-9s avg %5.1f ms (%3.0f fps)  worst %5.1f ms" % [VIEWS[_vi][0], avg, 1000.0 / avg, _worst])
		_f = 0
	return false
