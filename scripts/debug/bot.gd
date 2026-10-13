extends Node
## BOT driver (dev only, autoloaded temporarily): plays ch1-9, asserts, screenshots.

var _stage := -2
var _wait := 0
var _fails: Array[String] = []
var _shots := 0

func gm() -> Node:
	return get_node_or_null("/root/GameManager")

func em() -> Node:
	return get_node_or_null("/root/EventManager")

func hud() -> Node:
	var hs: Array = get_tree().get_nodes_in_group("hud")
	return hs[0] if hs.size() > 0 else null

func player() -> Node3D:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("Player") as Node3D

func ch() -> int:
	return int(gm().get("chapter")) if gm() != null else -1

func has_clue(c: String) -> bool:
	return bool(gm().call("has_clue", c)) if gm() != null else false

func fired(e: String) -> bool:
	return bool(em().call("was_fired", e)) if em() != null else false

func find_title(t: String) -> Node:
	var stack: Array = [get_tree().current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null:
			continue
		if str(n.get("title")) == t:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func tp(p: Vector3) -> void:
	var pl := player()
	pl.global_position = p
	if pl.get("velocity") != null:
		pl.set("velocity", Vector3.ZERO)

func go(stage: int, wait: int) -> void:
	_stage = stage
	_wait = wait

func check(cond: bool, msg: String) -> void:
	if cond:
		print("BOT ok: ", msg)
	else:
		_fails.append(msg)
		printerr("BOT FAIL: ", msg)

func do_interact(t: String) -> bool:
	var n := find_title(t)
	if n == null:
		_fails.append("missing node: " + t)
		printerr("BOT FAIL missing: ", t)
		return false
	n.call("interact")
	return true

func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := "user://shots/"
	DirAccess.make_dir_recursive_absolute(dir)
	var img: Image = get_viewport().get_texture().get_image()
	var err: Error = img.save_png(dir + name + ".png")
	_shots += 1
	print("BOT shot ", name, " err=", err, " at ", ProjectSettings.globalize_path(dir + name + ".png"))

func _press_button(n: Node, label: String) -> bool:
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur == null:
			continue
		if cur is Button and str((cur as Button).text) == label:
			(cur as Button).pressed.emit()
			return true
		for c in cur.get_children():
			stack.append(c)
	return false

func _physics_process(_delta: float) -> void:
	if _stage == -2:
		if get_tree().current_scene == null:
			return
		var sc := get_tree().current_scene.name
		if sc == "HouseEntry":
			go(-1, 60)
			return
		if sc == "MainMenu":
			var sm0: Node = get_node_or_null("/root/SaveManager")
			if sm0 != null:
				sm0.call("clear_save")
			(gm().get("clues_found") as Array).clear()
			gm().set("chapter", 1)
			gm().set("ending_choice", 0)
			em().call("reset_all")
			print("BOT at menu, pressing New Game")
			_press_button(get_tree().current_scene, "New Game")
		return
	if player() == null or not bool(get_tree().current_scene.get("is_built")):
		return
	if _wait > 0:
		_wait -= 1
		return
	match _stage:
		-1:
			gm().get("settings")["voices"] = false
			print("BOT start ch=", ch())
			print("BOT spawn pos=", player().global_position)
			check(absf(player().global_position.y) < 2.0, "player is not below the world at start")
			_wait = 10000
			await shot("01_intro_phone")
			hud().call("_close_top_modal")
			check(fired("voicemail_heard"), "closing the voicemail counts as heard")
			check(str((hud().get("objective_label") as Label).text).contains("kitchen"), "objective now points to the kitchen")
			tp(Vector3(-2.2, 0.5, 10.0))
			go(1, 25)
		1:
			check(fired("stepped_out"), "stepped outside fires car event")
			do_interact("Garden gate")
			check(has_clue("gate"), "gate clue")
			tp(Vector3(2.3, 0.5, 2.9))
			go(2, 20)
		2:
			do_interact("Study door")
			var sd := find_title("Study door")
			check(sd != null and not bool(sd.get("is_open")), "study stays locked without key")
			do_interact("Wet envelope")
			check(has_clue("envelope"), "envelope clue")
			tp(Vector3(-1.8, 0.5, -3.7))
			go(3, 30)
		3:
			check(ch() == 2, "kitchen chapter 2")
			do_interact("Warm tea cup")
			do_interact("Mother's note")
			do_interact("Family photo + key")
			check(has_clue("photo_key"), "photo+key clue")
			check(fired("key_found"), "key event fired")
			go(4, 5)
		4:
			check(ch() == 3, "photo+key advances to chapter 3")
			check(fired("corridor_steps"), "ch3 footsteps upstairs play")
			tp(Vector3(0.5, 0.5, 2.6))
			do_interact("Wall clock")
			do_interact("Folded note")
			check(has_clue("folded_note"), "folded note clue")
			go(5, 5)
		5:
			check(ch() == 4, "corridor clues advance to chapter 4")
			tp(Vector3(-2.0, 0.5, 1.2))
			do_interact("Noa's journal")
			do_interact("Old camera")
			do_interact("Tape box (3 empty slots)")
			do_interact("Carving in closet")
			go(6, 5)
		6:
			check(ch() == 5, "Noa's room advances to chapter 5")
			tp(Vector3(2.3, 0.5, 2.9))
			do_interact("Study door")
			go(7, 30)
		7:
			var sd2 := find_title("Study door")
			check(sd2 != null and bool(sd2.get("is_open")), "study opens with key")
			tp(Vector3(3.8, 0.5, 3.0))
			_wait = 10000
			await shot("05_study")
			do_interact("Yoav's note")
			do_interact("Back-door repair order")
			do_interact("Bills and envelopes")
			do_interact("Short tapes (2/3)")
			do_interact("Marked house plan")
			go(8, 5)
		8:
			check(ch() == 6, "house plan advances to chapter 6")
			tp(Vector3(3.55, 0.5, -3.8))
			do_interact("Service cabinet")
			go(9, 40)
		9:
			do_interact("Wooden panel")
			go(10, 30)
		10:
			check(fired("hidden_open"), "panel opened")
			do_interact("Miriam's hidden letter")
			do_interact("Last tape")
			# The ending table must refuse before the storm recording is found.
			do_interact("Three versions table")
			check(not fired("show_endings"), "ending table stays closed without the recording")
			tp(Vector3(3.0, -2.5, 1.6))
			go(11, 30)
		11:
			check(ch() == 7, "hidden recess advances to chapter 7")
			_wait = 10000
			await shot("07_basement")
			do_interact("Noa's farewell note")
			do_interact("Storm-night recorder")
			go(12, 5)
		12:
			check(ch() == 8, "basement clues advance to chapter 8")
			tp(Vector3(2.3, 0.5, -1.0))
			do_interact("Noa's tape 1")
			do_interact("Three versions table")
			go(13, 15)
		13:
			check(fired("show_endings"), "endings open once photo, recording and letter are found")
			hud().call("_choose_ending", 2)
			check(int(gm().get("ending_choice")) == 2, "ending 2 chosen")
			var items: Dictionary = get_tree().current_scene.get("_table_items")
			check((items["tape"] as Node3D).visible and not (items["photo"] as Node3D).visible and not (items["letter"] as Node3D).visible, "only the tape is left on the table")
			check(str((items["versions"] as Node).get("body_text")).begins_with("Only the tape"), "table text follows the choice")
			check(str(gm().call("final_text")) == "He came back. No one opened.", "closing line follows the choice")
			tp(Vector3(0.0, 0.5, 4.0))
			go(14, 20)
		14:
			do_interact("Front door")
			go(15, 30)
		15:
			check(ch() == 9, "morning chapter 9")
			_wait = 10000
			await shot("09_morning")
			hud().call("_close_top_modal")
			go(16, 10)
		16:
			var n: int = (gm().get("clues_found") as Array).size()
			print("BOT clues total=", n)
			check(n >= 22, "22+ clues collected")
			var sm: Node = get_node_or_null("/root/SaveManager")
			check(sm != null and bool(sm.call("has_save")), "save file exists")
			if _fails.is_empty():
				print("BOT ALL PASSED")
			else:
				printerr("BOT FAILURES: ", _fails)
			set_physics_process(false)
			_wait = 10000
			await shot("10_credits")
			get_tree().quit(0 if _fails.is_empty() else 1)
