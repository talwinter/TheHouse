extends SceneTree
## Visual + spatial inspection tool (replaces the player-driven probe_walk).
##
## Renders from a FREE camera (player + HUD disabled), so eye height and view
## direction are exact. Also renders orthographic top-down plans of every room
## and dumps every furniture/prop node's world AABB to stdout.
##
## Usage (needs a GPU, not --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tests/inspect_tool.gd -- out=tests/shots_after [only=v03,plan_kitchen] [dump]

const EYE := 1.6

# name, eye, target  (eye is the real camera position)
const SHOTS := [
	["v00_photo_wall", Vector3(1.4, EYE, 3.0), Vector3(-1.14, 1.6, 2.8)],
	["v01_front_door_in", Vector3(0.8, EYE, 1.4), Vector3(0.0, 1.1, 5.0)],
	["v02_front_door_out", Vector3(0.0, EYE, 8.5), Vector3(0.0, 1.3, 5.0)],
	["v03_kitchen", Vector3(-2.0, EYE, -1.2), Vector3(-3.6, 0.9, -4.6)],
	["v04_kitchen_counter", Vector3(-3.0, EYE, -2.4), Vector3(-3.8, 1.0, -4.8)],
	["v05_corridor", Vector3(1.0, EYE, 4.2), Vector3(0.8, 1.2, -4.0)],
	["v06_living", Vector3(3.6, EYE, 0.2), Vector3(4.6, 0.7, -3.4)],
	["v07_living_shelf", Vector3(3.5, EYE, -2.4), Vector3(5.5, 1.0, 1.5)],
	["v08_noa_door", Vector3(-2.25, EYE, 0.0), Vector3(-4.2, 0.8, 3.5)],
	["v09_noa_bed", Vector3(-2.4, EYE, 2.0), Vector3(-5.0, 0.6, 4.2)],
	["v10_noa_desk", Vector3(-3.4, EYE, 3.2), Vector3(-5.6, 0.8, 1.4)],
	["v11_study_door", Vector3(1.4, EYE, 2.9), Vector3(3.0, 1.1, 2.9)],
	["v12_study_in", Vector3(3.4, EYE, 2.3), Vector3(5.4, 0.8, 3.6)],
	["v13_service", Vector3(3.55, EYE, -3.45), Vector3(5.4, 0.8, -4.9)],
	["v14_bathroom", Vector3(-3.2, EYE, -0.5), Vector3(-5.4, 0.7, -0.8)],
	["v15_basement", Vector3(2.55, -1.0, 0.3), Vector3(4.6, -2.2, 3.6)],
	["v16_basement_wide", Vector3(5.3, -1.0, 4.3), Vector3(2.6, -2.2, 0.0)],
	["v17_exterior", Vector3(-4.5, 1.7, 11.5), Vector3(0.0, 2.0, 4.0)],
	["v18_house_wide", Vector3(8.0, 4.0, 16.0), Vector3(0.0, 3.0, 0.0)],
	["v19_hall", Vector3(0.4, EYE, -3.4), Vector3(0.6, 1.2, 4.8)],
	["v20_basement_door", Vector3(0.3, EYE, -2.4), Vector3(2.12, 1.0, -3.55)],
	["v21_bath_inside", Vector3(-4.0, EYE, 0.3), Vector3(-5.5, 0.8, -1.4)],
	["v22_study_desk", Vector3(4.0, EYE, 4.2), Vector3(5.6, 0.9, 2.6)],
	["v30_service_door", Vector3(3.4, EYE, -0.6), Vector3(3.6, 1.0, -4.0)],
	["v31_eitan_room", Vector3(-1.6, 3.5 + EYE, -1.2), Vector3(-5.0, 3.9, -4.2)],
	["v32_parents_room", Vector3(-1.6, 3.5 + EYE, 3.6), Vector3(-4.5, 3.9, 0.6)],
	["v33_storage_room", Vector3(3.6, 3.5 + EYE, 4.2), Vector3(4.8, 3.9, -3.8)],
	["v34_clock", Vector3(-0.55, 1.95, 4.35), Vector3(-1.115, 1.95, 4.35)],
	["v35_stairs_user", Vector3(0.6, EYE, 1.8), Vector3(2.4, 1.6, -2.6)],
	["v36_stairs_side", Vector3(0.2, EYE, -1.0), Vector3(2.6, 1.2, -2.8)],
	["v24_stairs_bottom", Vector3(1.2, EYE, 1.6), Vector3(2.5, 1.6, -3.0)],
	["v25_stairs_up", Vector3(2.53, 1.4 + EYE, -2.3), Vector3(1.5, 3.4, -4.6)],
	["v26_upper_landing", Vector3(0.8, 3.5 + EYE, 2.5), Vector3(1.2, 3.9, -4.8)],
	["v27_upper_window", Vector3(0.6, 3.5 + EYE, -3.2), Vector3(1.2, 4.6, -5.0)],
	["v28_back_door", Vector3(-3.0, EYE, -2.4), Vector3(-6.0, 1.1, -2.1)],
	["v29_back_door_out", Vector3(-8.5, EYE, -1.0), Vector3(-6.0, 1.2, -2.6)],
	["v23_living_tv", Vector3(4.85, EYE, 0.6), Vector3(4.9, 0.9, -3.1)],
]

# name, center (x,z), half-extent (metres shown each side), floor y
const PLANS := [
	["plan_ground", Vector2(0, 0), 6.4, 0.0],
	["plan_kitchen", Vector2(-2.6, -3.0), 2.6, 0.0],
	["plan_noa", Vector2(-3.5, 2.8), 2.6, 0.0],
	["plan_living", Vector2(4.5, -2.0), 2.2, 0.0],
	["plan_study_hall", Vector2(2.4, 2.6), 2.6, 0.0],
	["plan_basement", Vector2(3.8, 0.6), 4.6, -2.6],
]

var _inst: Node3D
var _cam: Camera3D
var _queue: Array = []
var _wait := 0
var _cur: Dictionary = {}
var _out := "tests/shots_after"
var _only: PackedStringArray = []
var _dump := false
var _audit := false

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out = a.substr(4)
		elif a.begins_with("only="):
			_only = a.substr(5).split(",")
		elif a == "dump":
			_dump = true
		elif a == "audit":
			_audit = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + _out))
	for s in SHOTS:
		if _want(s[0]):
			_queue.append({"name": s[0], "eye": s[1], "tgt": s[2], "ortho": false})
	for p in PLANS:
		if _want(p[0]):
			_queue.append({"name": p[0], "c": p[1], "half": p[2], "floor": p[3], "ortho": true})

func _want(n: String) -> bool:
	if _only.is_empty():
		return true
	for o in _only:
		if n.begins_with(o):
			return true
	return false

func _physics_process(_d: float) -> bool:
	if _inst == null:
		var ps: PackedScene = load("res://scenes/levels/house_entry.tscn") as PackedScene
		_inst = ps.instantiate() as Node3D
		root.add_child(_inst)
		_wait = 30
		return false
	if not bool(_inst.get("is_built")):
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 25:
			_freeze_player()
			if _dump:
				_dump_props()
			if _audit:
				_run_audit()
		if _wait == 0 and not _cur.is_empty():
			_snap()
			_cur = {}
		return false
	if _queue.is_empty():
		print("INSPECT DONE")
		quit(0)
		return true
	_cur = _queue.pop_front()
	_aim(_cur)
	_wait = 12
	return false

func _freeze_player() -> void:
	var pl := _inst.get_node_or_null("Player") as Node3D
	if pl != null:
		pl.process_mode = Node.PROCESS_MODE_DISABLED
		pl.visible = false
		pl.global_position = Vector3(0, -50, 0)
	var hud := _inst.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.03
	_inst.add_child(_cam)
	_cam.make_current()

func _aim(s: Dictionary) -> void:
	if bool(s["ortho"]):
		var c: Vector2 = s["c"]
		var fy: float = float(s["floor"])
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = float(s["half"]) * 2.0
		# Sit just under the ceiling slab (ceiling bottom = floor + 2.9).
		var ch: float = 2.3 if fy < -1.0 else 2.85     # stay under the basement ceiling
		_cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(c.x, fy + ch, c.y))
		_cam.near = 0.02
		_cam.far = 4.0
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.near = 0.03
		_cam.far = 100.0
		var eye: Vector3 = s["eye"]
		var tgt: Vector3 = s["tgt"]
		_cam.global_transform = Transform3D(Basis(), eye).looking_at(tgt, Vector3.UP)

func _snap() -> void:
	var img: Image = root.get_texture().get_image()
	var path := "res://" + _out + "/" + str(_cur["name"]) + ".png"
	var err := img.save_png(path)
	print("SHOT ", _cur["name"], " err=", err)

## World AABB of every mesh under n.
static func world_aabb(n: Node) -> AABB:
	var box := AABB()
	var found := false
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh != null and (cur as MeshInstance3D).is_visible_in_tree():
			var mi := cur as MeshInstance3D
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if not found else box.merge(b)
			found = true
		for c in cur.get_children():
			stack.append(c)
	return box if found else AABB()

func _dump_props() -> void:
	print("---- PROP DUMP (name | pos | rotY | aabb min -> max | size)")
	for c in _inst.get_children():
		if not (c is Node3D) or c is StaticBody3D and not String(c.name).begins_with("PH_"):
			continue
		if c is MeshInstance3D:
			continue
		var n := c as Node3D
		var b := world_aabb(n)
		if b.size == Vector3.ZERO:
			continue
		var tag := str(n.get_meta("tag", ""))
		print("PROP %s %s | (%.2f,%.2f,%.2f) | %.0f | (%.2f,%.2f,%.2f) -> (%.2f,%.2f,%.2f) | (%.2f,%.2f,%.2f)" % [
			n.name, tag, n.global_position.x, n.global_position.y, n.global_position.z,
			n.rotation_degrees.y, b.position.x, b.position.y, b.position.z, b.end.x, b.end.y, b.end.z,
			b.size.x, b.size.y, b.size.z])

# ---------------------------------------------------------------- audit
const SKIP_PREFIX := ["@", "Window", "Doorway", "Rug", "Papers", "Cassette", "PhotoFlat", "Puddle", "Bedding", "StreetLight", "Tree", "CounterSink", "PorchLantern", "Decor_"]
# Television_01 stands on the console by design; the audit treats it as decor too.
const ON_TOP := [["PH_Console", "PH_Television_01"]]

func _audit_props() -> Array:
	var out: Array = []
	for c in _inst.get_children():
		if not (c is Node3D) or c is MeshInstance3D or c is Light3D or c is GPUParticles3D or c is Area3D or c is Camera3D:
			continue
		if c is StaticBody3D and not (c as Node).is_in_group("service_cabinet"):
			continue
		var nm := String(c.name)
		var skip := false
		for p in SKIP_PREFIX:
			if nm.begins_with(p):
				skip = true
		if skip:
			continue
		var b := world_aabb(c)
		if b.size == Vector3.ZERO:
			continue
		out.append({"name": nm, "aabb": b})
	return out

func _shrink(a: AABB, m: float) -> AABB:
	return AABB(a.position + Vector3(m, m, m), (a.size - Vector3(m, m, m) * 2.0).max(Vector3.ZERO))

func _run_audit() -> void:
	var props := _audit_props()
	var walls: Array = []
	for w in get_nodes_in_group("wall"):
		for c in (w as Node).get_children():
			if c is CollisionShape3D and (c as CollisionShape3D).shape is BoxShape3D:
				var sz: Vector3 = ((c as CollisionShape3D).shape as BoxShape3D).size
				walls.append(AABB((w as Node3D).global_position - sz * 0.5, sz))
	var bad := 0
	for i in props.size():
		var a: AABB = _shrink(props[i]["aabb"], 0.02)
		for j in range(i + 1, props.size()):
			var b: AABB = _shrink(props[j]["aabb"], 0.02)
			if a.intersects(b) and not ([props[i]["name"], props[j]["name"]] in ON_TOP or [props[j]["name"], props[i]["name"]] in ON_TOP):
				var x := a.intersection(b)
				print("AUDIT OVERLAP %s <-> %s  (%.2f x %.2f x %.2f)" % [props[i]["name"], props[j]["name"], x.size.x, x.size.y, x.size.z])
				bad += 1
		for w in walls:
			if a.intersects(w):
				var x2 := a.intersection(w)
				print("AUDIT WALL %s  (%.2f x %.2f x %.2f) at %s" % [props[i]["name"], x2.size.x, x2.size.y, x2.size.z, str(x2.get_center())])
				bad += 1
	print("AUDIT props=%d walls=%d problems=%d %s" % [props.size(), walls.size(), bad, "OK" if bad == 0 else "FAIL"])
