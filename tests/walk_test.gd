extends SceneTree
## Physics walk test: steers the real player capsule (via input actions) through a
## route of waypoints that crosses every doorway and the basement stairs, and
## fails if any leg is blocked.
##   Godot_console.exe --headless --path . --script res://tests/walk_test.gd

const ROUTE := [
	["front yard -> porch", Vector3(0.0, 0, 7.5), Vector3(0.0, 0, 5.8)],
	["porch -> hall (front door)", Vector3(0.0, 0, 5.8), Vector3(0.6, 0, 3.6)],
	["hall -> kitchen arch", Vector3(0.6, 0, 3.6), Vector3(-0.4, 0, -3.0)],
	["through kitchen arch", Vector3(-0.4, 0, -3.0), Vector3(-2.0, 0, -3.6)],
	["kitchen -> passage", Vector3(-2.0, 0, -3.6), Vector3(-2.5, 0, -0.5)],
	["passage -> bathroom", Vector3(-2.5, 0, -0.5), Vector3(-4.6, 0, -0.5)],
	["bathroom -> passage", Vector3(-4.6, 0, -0.5), Vector3(-2.25, 0, -0.1)],
	["passage -> Noa's room", Vector3(-2.25, 0, -0.1), Vector3(-2.25, 0, 1.6)],
	["Noa's room -> rug", Vector3(-2.25, 0, 1.6), Vector3(-3.3, 0, 2.9)],
	["Noa's room -> hall", Vector3(-3.3, 0, 2.9), Vector3(-2.25, 0, -0.3)],
	["passage -> living door", Vector3(-2.25, 0, -0.3), Vector3(2.4, 0, 0.05)],
	["through living-room door", Vector3(2.4, 0, 0.05), Vector3(3.45, 0, 0.05)],
	["into living room", Vector3(3.45, 0, 0.05), Vector3(3.45, 0, -1.2)],
	["living -> coffee table", Vector3(3.45, 0, -1.2), Vector3(3.6, 0, -1.75)],
	["coffee table -> service door", Vector3(3.6, 0, -1.75), Vector3(3.5, 0, -2.7)],
	["into service room", Vector3(3.5, 0, -2.7), Vector3(3.55, 0, -3.8)],
	["service room -> cabinet", Vector3(3.55, 0, -3.8), Vector3(4.6, 0, -3.85)],
	["service room -> living", Vector3(4.6, 0, -3.85), Vector3(3.45, 0, -1.2)],
	["living -> doorway", Vector3(3.45, 0, -1.2), Vector3(3.45, 0, 0.05)],
	["living -> hall", Vector3(3.45, 0, 0.05), Vector3(2.0, 0, 1.0)],
	["hall -> study (door open)", Vector3(2.0, 0, 1.0), Vector3(3.9, 0, 3.0)],
	["study -> hall", Vector3(3.9, 0, 3.0), Vector3(1.6, 0, 3.4)],
	["hall -> porch (front door)", Vector3(1.6, 0, 3.4), Vector3(0.0, 0, 5.75)],
	["porch -> hall", Vector3(0.0, 0, 5.75), Vector3(0.8, 0, 3.0)],
	["hall -> basement door", Vector3(0.8, 0, 3.0), Vector3(1.5, 0, -3.55)],
	["through the basement door", Vector3(1.5, 0, -3.55), Vector3(2.55, 0, -3.62)],
	["down to the basement", Vector3(2.55, 0, -3.62), Vector3(2.55, -2.6, 0.25)],
	["basement walk", Vector3(2.55, -2.6, 0.25), Vector3(3.0, -2.6, 1.6)],
	["basement middle", Vector3(3.0, -2.6, 1.6), Vector3(3.2, -2.6, 3.2)],
	["basement corner", Vector3(3.2, -2.6, 3.2), Vector3(4.8, -2.6, 3.6)],
	["hall -> stair foot", Vector3(0.6, 0, 3.6), Vector3(2.53, 0, -0.2)],
	["up flight 1 to landing", Vector3(2.53, 0, -0.2), Vector3(2.53, 2.8, -4.45)],
	["up flight 2 to upper floor", Vector3(2.53, 2.8, -4.45), Vector3(0.7, 3.5, -4.44)],
	["upper landing -> window", Vector3(0.7, 3.5, -4.44), Vector3(0.6, 3.5, -3.6)],
	["upper landing -> south end", Vector3(0.6, 3.5, -3.6), Vector3(0.6, 3.5, 4.0)],
	["landing -> Eitan's room", Vector3(0.6, 3.5, 4.0), Vector3(-0.6, 3.5, -2.6)],
	["into Eitan's room", Vector3(-0.6, 3.5, -2.6), Vector3(-3.4, 3.5, -2.2)],
	["Eitan's room -> landing", Vector3(-3.4, 3.5, -2.2), Vector3(-0.6, 3.5, -2.6)],
	["landing -> parents' room", Vector3(-0.6, 3.5, -2.6), Vector3(-0.6, 3.5, 2.2)],
	["through parents' door", Vector3(-0.6, 3.5, 2.2), Vector3(-2.0, 3.5, 2.3)],
	["into parents' room", Vector3(-2.0, 3.5, 2.3), Vector3(-3.5, 3.5, 3.0)],
	["parents' room -> door", Vector3(-3.5, 3.5, 3.0), Vector3(-2.0, 3.5, 2.3)],
	["parents' door -> landing", Vector3(-2.0, 3.5, 2.3), Vector3(-0.6, 3.5, 2.2)],
	["landing -> storage door", Vector3(-0.6, 3.5, 2.2), Vector3(2.4, 3.5, 2.4)],
	["through storage door", Vector3(2.4, 3.5, 2.4), Vector3(3.7, 3.5, 2.4)],
	["into storage room", Vector3(3.7, 3.5, 2.4), Vector3(4.4, 3.5, 0.5)],
	["storage room -> door", Vector3(4.4, 3.5, 0.5), Vector3(3.7, 3.5, 2.4)],
	["storage door -> landing", Vector3(3.7, 3.5, 2.4), Vector3(2.4, 3.5, 2.4)],
	["back to stair top", Vector3(2.4, 3.5, 2.4), Vector3(0.7, 3.5, -4.44)],
	["down flight 2", Vector3(0.7, 3.5, -4.44), Vector3(2.53, 2.8, -4.45)],
	["down flight 1", Vector3(2.53, 2.8, -4.45), Vector3(2.53, 0, -0.1)],
	["hall -> passage", Vector3(2.53, 0, -0.1), Vector3(-2.5, 0, -1.2)],
	["passage -> kitchen walkway", Vector3(-2.5, 0, -1.2), Vector3(-3.4, 0, -2.1)],
	["walkway -> back door", Vector3(-3.4, 0, -2.1), Vector3(-5.4, 0, -2.1)],
	["basement corner -> middle", Vector3(4.8, -2.6, 3.6), Vector3(3.2, -2.6, 3.2)],
	["basement middle -> walk", Vector3(3.2, -2.6, 3.2), Vector3(3.0, -2.6, 1.6)],
	["basement -> stair foot", Vector3(3.0, -2.6, 1.6), Vector3(2.55, -2.6, 0.1)],
	["back up the stairs", Vector3(2.55, -2.6, 0.1), Vector3(2.55, 0, -3.62)],
	["out of the basement door", Vector3(2.55, 0, -3.62), Vector3(1.5, 0, -3.55)],
]

var _inst: Node3D
var _pl: CharacterBody3D
var _leg := -1
var _frames := 0
var _fails: Array = []
var _start_wait := 30

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))

func _physics_process(_d: float) -> bool:
	if _inst == null:
		_inst = (load("res://scenes/levels/house_entry.tscn") as PackedScene).instantiate()
		root.add_child(_inst)
		_pl = _inst.get_node("Player") as CharacterBody3D
		var hud := _inst.get_node_or_null("HUD")
		if hud != null:
			hud.process_mode = Node.PROCESS_MODE_DISABLED
		return false
	if not bool(_inst.get("is_built")):
		return false
	if not has_meta("doors_open"):
		set_meta("doors_open", true)
		for dn in ["StudyDoor", "FrontDoor", "UpDoorNW", "UpDoorSW", "UpDoorE", "BasementDoor"]:
			var d := _inst.get_node_or_null(dn)
			if d != null:
				d.call("set_open_instant", true)
	if _start_wait > 0:
		_start_wait -= 1
		return false
	if _leg == -1 or _reached() or _frames > 60 * 12:
		if _leg >= 0:
			var leg: Array = ROUTE[_leg]
			if not _reached():
				_fails.append(leg[0])
				print("WALK FAIL ", leg[0], " stuck at ", _pl.global_position)
			else:
				print("WALK ok   ", leg[0], " (", _frames, " frames)")
		_leg += 1
		_frames = 0
		Input.action_release("move_forward")
		if _leg >= ROUTE.size():
			print("WALK RESULT ", "ALL PASSED" if _fails.is_empty() else "FAILURES: " + str(_fails))
			quit(0 if _fails.is_empty() else 1)
			return true
		var start: Vector3 = ROUTE[_leg][1]
		# Jump to the leg's start when it doesn't continue from where the player stands.
		if _leg == 0 or _fails.size() > 0 or _pl.global_position.distance_to(start) > 1.0:
			_pl.global_position = start + Vector3(0, 0.1, 0)
			_pl.velocity = Vector3.ZERO
		return false
	_frames += 1
	if OS.get_cmdline_user_args().has("trace") and _frames % 20 == 0:
		print("  TRACE ", ROUTE[_leg][0], " f=", _frames, " pos=", _pl.global_position, " floor=", _pl.is_on_floor())
	var tgt: Vector3 = ROUTE[_leg][2]
	var to := Vector3(tgt.x - _pl.global_position.x, 0, tgt.z - _pl.global_position.z)
	var yaw := atan2(-to.x, -to.z)
	_pl.rotation.y = yaw
	_pl.set("_yaw", yaw)
	Input.action_press("move_forward")
	return false

func _reached() -> bool:
	var tgt: Vector3 = ROUTE[_leg][2]
	var p := _pl.global_position
	return Vector2(p.x - tgt.x, p.z - tgt.z).length() < 0.3 and absf(p.y - tgt.y) < 0.6
