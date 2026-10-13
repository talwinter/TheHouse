extends SceneTree
## Model catalog: prints each Poly Haven model's real size and renders it from the
## front (+Z) and from the side (+X) so scale and facing can be checked by eye.
##   Godot_console.exe --path . --script res://tests/model_catalog.gd -- [only=Name1,Name2]

const PH := "res://assets/models/polyhaven/"
const Furnish := preload("res://scripts/levels/furnish_external.gd")

var _names: Array = []
var _i := -1
var _wait := 0
var _world: Node3D
var _cam: Camera3D
var _cur: Node3D
var _side := false

func _initialize() -> void:
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5).split(",")
	var d := DirAccess.open(PH)
	for n in d.get_directories():
		if only.is_empty() or only.has(n):
			_names.append(n)
	_names.sort()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/catalog"))
	_world = Node3D.new()
	root.add_child(_world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.37, 0.4)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.8
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	_world.add_child(sun)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	floor.mesh = pm
	_world.add_child(floor)
	# +Z marker so "front" is unambiguous in renders
	var mk := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.02, 0.6)
	mk.mesh = bm
	mk.position = Vector3(0, 0.01, 1.3)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1, 0.2, 0.2)
	mk.material_override = mm
	_world.add_child(mk)
	_cam = Camera3D.new()
	_cam.fov = 40
	_world.add_child(_cam)
	_cam.make_current()

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var img := root.get_texture().get_image()
			img.save_png("res://tests/catalog/%s_%s.png" % [_names[_i], "side" if _side else "front"])
			if not _side:
				_side = true
				_aim()
				_wait = 4
			return false
		return false
	_i += 1
	if _i >= _names.size():
		print("CATALOG DONE")
		quit(0)
		return true
	if _cur != null:
		_cur.queue_free()
	var path: String = PH + str(_names[_i]) + "/model.gltf"
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		print("CAT ", _names[_i], " LOAD FAILED")
		return false
	_cur = ps.instantiate() as Node3D
	_world.add_child(_cur)
	var b: AABB = Furnish.world_aabb(_cur)
	print("CAT %-16s size=(%.2f, %.2f, %.2f) min=(%.2f, %.2f, %.2f)" % [_names[_i], b.size.x, b.size.y, b.size.z, b.position.x, b.position.y, b.position.z])
	_cur.position -= Vector3(b.get_center().x, b.position.y, b.get_center().z)
	_side = false
	_aim()
	_wait = 4
	return false

func _aim() -> void:
	var b: AABB = Furnish.world_aabb(_cur)
	var r: float = maxf(b.size.length(), 0.3)
	var c: Vector3 = b.get_center()
	var dir := Vector3(0.35, 0.3, 1.0) if not _side else Vector3(1.0, 0.3, 0.0)
	_cam.global_transform = Transform3D(Basis(), c + dir.normalized() * r * 1.6).looking_at(c, Vector3.UP)
