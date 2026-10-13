extends SceneTree
## Rendered robot run: load real level, render ~5s, save screenshot, quit.

var _frames := 0
var _setup := false

func _initialize() -> void:
	print("SHOT boot display=", DisplayServer.get_name())

func _physics_process(_delta: float) -> bool:
	if not _setup:
		print("SHOT loading level...")
		var ps: PackedScene = load("res://scenes/levels/house_entry.tscn") as PackedScene
		print("SHOT loaded=", ps != null)
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_setup = true
		print("SHOT setup done children=", inst.get_child_count())
		return false
	_frames += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _frames % 60 == 0:
		print("SHOT frame ", _frames)
	if _frames >= 180:
		_capture = true
	return false

var _capture := false

func _process(_delta: float) -> bool:
	if _capture:
		_capture = false
		var img: Image = root.get_texture().get_image()
		var err: Error = img.save_png("res://tests/shot.png")
		print("SHOT saved err=", err, " size=", img.get_size())
		quit(0)
		return true
	return false
