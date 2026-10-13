extends SceneTree
## Art shots: pose the camera at key spots and capture one PNG per view.

var _views: Array = []
var _i := -1
var _inst: Node
var _capture := false
var _wait := 0

const SHOTS := [
	["art_01_kitchen", Vector3(-0.6, 1.6, -1.2), Vector3(0, -14, 0)],
	["art_02_living", Vector3(3.6, 1.6, 0.4), Vector3(0, 132, 0)],
	["art_03_corridor", Vector3(-2.0, 1.6, 2.2), Vector3(0, 168, 0)],
	["art_04_noa_room", Vector3(-2.2, 1.6, 1.4), Vector3(0, 200, 0)],
	["art_05_study", Vector3(4.1, 1.6, 2.6), Vector3(0, 58, 0)],
	["art_06_hall_front", Vector3(0.0, 1.6, 1.2), Vector3(0, 4, 0)],
	["art_07_exterior", Vector3(-2.2, 1.7, 9.0), Vector3(-14, 8, 0)],
	["art_08_basement", Vector3(1.5, -0.5, 10.4), Vector3(0, 6, 0)],
	["art_09_upper", Vector3(3.8, 4.9, 2.4), Vector3(0, -150, 0)],
	["art_10_bathroom", Vector3(-4.2, 1.6, -0.6), Vector3(0, -108, 0)],
]

func _physics_process(_d: float) -> bool:
	if _inst == null:
		var ps: PackedScene = load("res://scenes/levels/house_entry.tscn") as PackedScene
		_inst = ps.instantiate()
		root.add_child(_inst)
		_wait = 90
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if _capture:
		return false
	if _i >= SHOTS.size():
		print("ART SHOTS DONE")
		quit(0)
		return true
	_i += 1
	var v: Array = SHOTS[_i]
	var cam: Camera3D = _inst.get_node("Player/Camera3D") as Camera3D
	var pl: Node3D = _inst.get_node("Player") as Node3D
	pl.global_position = v[1]
	pl.rotation.y = deg_to_rad(float(v[2].y))
	pl.rotation.x = deg_to_rad(float(v[2].x))
	pl.rotation.z = 0.0
	cam.rotation.x = deg_to_rad(float(v[2].x))
	cam.rotation.y = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_wait = 40
	_capture = true
	return false

func _process(_d: float) -> bool:
	if not _capture:
		return false
	_capture = false
	var v: Array = SHOTS[_i]
	var img: Image = root.get_texture().get_image()
	var err: Error = img.save_png("res://tests/shots/" + str(v[0]) + ".png")
	print("ART ", v[0], " err=", err)
	return false
