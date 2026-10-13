extends SceneTree
## Basic headless playtest: files + scene instantiate + clue data.

func _init() -> void:
	var fails: Array[String] = []
	var base := "res://"
	# 1. clues
	var clues_path := "res://data/clues.json"
	if not FileAccess.file_exists(clues_path):
		fails.append("missing clues.json")
	else:
		var t: String = FileAccess.get_file_as_string(clues_path)
		var j: Variant = JSON.parse_string(t)
		if not (j is Dictionary) or (j as Dictionary).size() < 12:
			fails.append("clues <12")
		else:
			print("PASS clues=", (j as Dictionary).size())
	# 2. docs
	if not FileAccess.file_exists("res://data/documents.json"):
		fails.append("missing documents.json")
	else:
		print("PASS documents exists")
	# 3. kenney
	var dir := DirAccess.open("res://assets/models/kenney")
	if dir == null:
		fails.append("missing kenney dir")
	else:
		var n := 0
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while f != "":
			if f.ends_with(".glb"):
				n += 1
			f = dir.get_next()
		print("PASS kenney glb=", n)
		if n < 10:
			fails.append("kenney <10")
	# 4. audio
	for a in ["res://assets/audio/sfx/knock.wav", "res://assets/audio/sfx/static.wav", "res://assets/audio/ambience/rain.wav"]:
		if not FileAccess.file_exists(a):
			fails.append("missing " + a)
	print("PASS audio files checked")
	# 5. scene load
	var ps: PackedScene = load("res://scenes/levels/house_entry.tscn") as PackedScene
	if ps == null:
		fails.append("house_entry not loadable")
	else:
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		print("PASS instantiate children=", inst.get_child_count())
		# count interactables (have method interact)
		var found := 0
		var stack: Array = [inst]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur.has_method("interact"):
				found += 1
			for c in cur.get_children():
				stack.append(c)
		print("PASS interactables_in_tscn_only=", found, " (rooms spawn at runtime)")
		inst.queue_free()
	if fails.is_empty():
		print("ALL TESTS PASSED")
	else:
		printerr("FAIL: ", fails)
	quit(1 if not fails.is_empty() else 0)
