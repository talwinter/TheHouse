extends SceneTree
## Reachability audit: can the player actually get close enough to every clue and door?
##
## 1. Flood-fills, on each floor level, every grid cell where the player capsule fits and
##    has floor under it, starting from a seed in each area (furniture and walls block).
## 2. For every interactable (clues, doors), looks for a reachable cell from which the
##    interaction ray (eye height, 2.5 m) hits that interactable first.
## Runs with the world "solved" (doors open, cabinet moved) so every clue exists/visible.
##   Godot_console.exe --headless --path . --script res://tests/reach_test.gd -- testsave

const STEP := 0.15
const EYE := 1.6
const REACH := 2.5
const LEVELS := [
	["ground", 0.0, [Vector2(0.6, 3.6), Vector2(0.0, 8.5)]],
	["basement", -2.6, [Vector2(3.0, 1.6)]],
	["upstairs", 3.5, [Vector2(0.6, 0.0)]],
]

var _inst: Node3D
var _frames := 0
var _space: PhysicsDirectSpaceState3D
var _shape := CapsuleShape3D.new()

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))
	_shape.radius = 0.35
	_shape.height = 1.7

func _physics_process(_d: float) -> bool:
	if _inst == null:
		_inst = (load("res://scenes/levels/house_entry.tscn") as PackedScene).instantiate()
		root.add_child(_inst)
		return false
	if not bool(_inst.get("is_built")):
		return false
	_frames += 1
	if _frames == 1:
		(_inst.get_node("Player") as Node3D).global_position = Vector3(0, -40, 0)
		_inst.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
		# The cabinet has been pushed aside before the hidden panel can be reached.
		for cab in get_nodes_in_group("service_cabinet"):
			(cab as Node3D).position.x = float(_inst.get_script().get_script_constant_map()["SV_CAB_MOVED_X"])
		return false
	if _frames == 4:
		# Pass A: doors as the player first meets them (closed).
		_space = _inst.get_world_3d().direct_space_state
		_bad += _run(true)
		for dn in ["StudyDoor", "FrontDoor", "HiddenPanel", "UpDoorNW", "UpDoorSW", "UpDoorE", "BasementDoor"]:
			var d := _inst.get_node_or_null(dn)
			if d != null:
				d.call("set_open_instant", true)
		return false
	if _frames == 8:
		# Pass B: every clue, with the world opened up as the story progresses.
		_bad += _run(false)
		print("REACH RESULT ", "ALL REACHABLE" if _bad == 0 else "%d UNREACHABLE" % _bad)
		quit(0 if _bad == 0 else 1)
		return true
	return false

var _bad := 0

func _fits(x: float, y: float, z: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _shape
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), Vector3(x, y + 0.9 + 0.08, z))
	if not _space.intersect_shape(q, 1).is_empty():
		return false
	var r := PhysicsRayQueryParameters3D.create(Vector3(x, y + 0.5, z), Vector3(x, y - 0.4, z), 1)
	return not _space.intersect_ray(r).is_empty()

func _run(doors: bool) -> int:
	var cells: Array = []   # [x, y, z]
	for lv in LEVELS:
		var y: float = lv[1]
		var seen: Dictionary = {}
		var queue: Array = []
		for s in lv[2]:
			var k := Vector2i(roundi((s as Vector2).x / STEP), roundi((s as Vector2).y / STEP))
			queue.append(k)
			seen[k] = true
		var n := 0
		while not queue.is_empty():
			var k: Vector2i = queue.pop_back()
			var x: float = k.x * STEP
			var z: float = k.y * STEP
			if absf(x) > 9.0 or z < -8.0 or z > 16.0 or not _fits(x, y, z):
				continue
			n += 1
			cells.append([x, y, z])
			for dk in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nk: Vector2i = k + dk
				if not seen.has(nk):
					seen[nk] = true
					queue.append(nk)
		print("REACH level %-9s walkable cells: %d" % [lv[0], n])
	var targets: Array = []
	var stack: Array = [_inst]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		if nd is CollisionObject3D and nd.has_method("interact") and nd.get("title") != null:
			if (nd.get("door_w") != null) == doors:
				targets.append(nd)
		for c in nd.get_children():
			stack.append(c)
	var bad := 0
	for t in targets:
		var node := t as CollisionObject3D
		var p: Vector3 = _target_point(node)
		var best := 99.0
		for c in cells:
			var eye := Vector3(c[0], float(c[1]) + EYE, c[2])
			var dist: float = eye.distance_to(p)
			if dist > REACH or dist >= best:
				continue
			var r := PhysicsRayQueryParameters3D.create(eye, eye + (p - eye).normalized() * REACH, 1 | 2)
			var hit: Dictionary = _space.intersect_ray(r)
			if not hit.is_empty() and _is_part(hit["collider"], node):
				best = dist
		if best > REACH:
			bad += 1
			print("REACH UNREACHABLE  %-28s at %s" % [str(node.get("title")), str(p)])
		else:
			print("REACH ok  %-28s from %.2f m" % [str(node.get("title")), best])
	print("REACH pass %s: %d targets, %d unreachable" % ["doors" if doors else "clues", targets.size(), bad])
	return bad

## Centre of the interactable's collision box in world space.
func _target_point(node: CollisionObject3D) -> Vector3:
	for c in node.get_children():
		if c is CollisionShape3D:
			return (c as CollisionShape3D).global_position
	return node.global_position

func _is_part(collider: Object, node: Node) -> bool:
	var n := collider as Node
	while n != null:
		if n == node:
			return true
		n = n.get_parent()
	return false
