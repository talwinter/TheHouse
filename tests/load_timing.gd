extends SceneTree
## Measures level load cost: load(), instantiate(), add_child (_ready builds the house),
## then the first frames (shader compilation shows up here).
var _t0 := 0
var _frames := 0
var _last := 0
var _inst: Node
func _initialize() -> void:
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm != null:
		gm.get("settings")["voices"] = false
	var t := Time.get_ticks_msec()
	var ps: PackedScene = load("res://scenes/levels/house_entry.tscn")
	print("LOAD load()=", Time.get_ticks_msec() - t, "ms")
	t = Time.get_ticks_msec()
	_inst = ps.instantiate()
	print("LOAD instantiate=", Time.get_ticks_msec() - t, "ms")
	_last = Time.get_ticks_msec()
	_t0 = _last
func _process(_d: float) -> bool:
	if _inst.get_parent() == null:
		var t := Time.get_ticks_msec()
		root.add_child(_inst)
		print("LOAD add_child/_ready (house build)=", Time.get_ticks_msec() - t, "ms")
		_last = Time.get_ticks_msec()
		return false
	var now := Time.get_ticks_msec()
	_frames += 1
	if bool(_inst.get("is_built")) and not has_meta("reported"):
		set_meta("reported", true)
		print("LOAD built after ", now - _t0, "ms in ", _frames, " frames")
	if now - _last > 120:
		print("LOAD frame ", _frames, " took ", now - _last, "ms")
	_last = now
	if _frames >= 200:
		var meshes := 0
		var mats := {}
		var st: Array = [_inst]
		while not st.is_empty():
			var n: Node = st.pop_back()
			if n is MeshInstance3D:
				meshes += 1
				var m = (n as MeshInstance3D).material_override
				if m != null:
					mats[m.get_rid()] = true
			for c in n.get_children():
				st.append(c)
		print("LOAD total first 60 frames=", now - _t0, "ms meshes=", meshes, " override materials=", mats.size(), " lights=", _inst.find_children("*", "Light3D", true, false).size())
		quit(0)
		return true
	return false
