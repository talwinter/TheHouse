extends SceneTree
## Screenshots of every UI screen (menu, loading, HUD panels, journal, pause, endings).
##   Godot_console.exe --path . --script res://tests/ui_shots.gd -- testsave

const OUT := "res://tests/shots_ui/"
var _step := 0
var _wait := 0
var _scene: Node

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.cfg"))

func _snap(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("UI shot ", name)

func _hud() -> Node:
	return get_nodes_in_group("hud")[0] if not get_nodes_in_group("hud").is_empty() else null

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			root.get_node("/root/GameManager").get("settings")["voices"] = false
			change_scene_to_file("res://scenes/ui/main_menu.tscn")
			_wait = 70
		1:
			_snap("01_main_menu")
			var mm := current_scene
			mm.get("settings_panel").visible = true
			_wait = 10
		2:
			_snap("02_menu_settings")
			change_scene_to_file("res://scenes/levels/house_entry.tscn")
			_wait = 3
		3:
			_snap("03_loading")
			_wait = 0
		4:
			if not bool(current_scene.get("is_built")):
				return false
			_wait = 120
		5:
			_snap("04_voicemail")
			_hud().call("_close_top_modal")
			_wait = 30
		6:
			_snap("05_ingame_vignette")
			var gm := root.get_node("/root/GameManager")
			for c in ["tea_cup", "mother_note", "photo_key", "folded_note", "tape1_living", "calendar", "back_door"]:
				gm.call("add_clue", c)
			_hud().call("show_inspect", "Mother's note", "\"If Noa called, tell her the box was not thrown away. It is where Dad always said there is nothing.\"")
			_wait = 30
		7:
			_snap("06_inspect")
			_hud().call("_close_top_modal")
			_hud().call("show_tape", "tape1_living")
			_wait = 40
		8:
			_snap("07_tape")
			_hud().call("_close_top_modal")
			_hud().call("toggle_journal")
			_wait = 30
		9:
			_snap("08_journal")
			_hud().call("toggle_journal")
			_hud().call("toggle_pause")
			_wait = 30
		10:
			_snap("09_pause")
			_hud().call("toggle_pause")
			_hud().call("show_endings")
			_wait = 30
		11:
			_snap("10_endings")
			quit(0)
			return true
	_step += 1
	return false
