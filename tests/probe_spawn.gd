extends SceneTree
## Physics spawn probe: instantiate the real level, run 120 physics frames, assert player rests on floor.

var _frames := 0
var _player: Node3D
var _ready_done := false

func _physics_process(_delta: float) -> bool:
	if not _ready_done:
		var ps: PackedScene = load("res://scenes/levels/house_entry.tscn") as PackedScene
		if ps == null:
			printerr("PROBE FAIL: level not loadable")
			quit(1)
			return true
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		_player = inst.get_node_or_null("Player") as Node3D
		if _player == null:
			printerr("PROBE FAIL: no Player")
			quit(1)
			return true
		print("PROBE spawn=", _player.global_position)
		_ready_done = true
		return false
	_frames += 1
	if _frames == 60:
		print("PROBE mid y=", _player.global_position.y)
	if _frames >= 120:
		var y: float = _player.global_position.y
		print("PROBE final y=", y)
		if y > -1.0 and y < 3.0:
			print("PROBE PASS: player rests on floor")
			quit(0)
		else:
			printerr("PROBE FAIL: player fell through (y=", y, ")")
			quit(1)
		return true
	return false
