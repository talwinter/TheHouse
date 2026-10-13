extends Node
## SaveManager: local user://save.cfg. Autoload.

## Tests run with `-- testsave` so they never touch (or delete) the player's real save.
var SAVE_PATH := "user://test_save.cfg" if OS.get_cmdline_user_args().has("testsave") else "user://save.cfg"

const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

## Settings live in their own file, so changing a slider never touches the game save.
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "values", GameManager.settings)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var s: Dictionary = cfg.get_value("settings", "values", {})
	for k in s.keys():
		GameManager.settings[k] = s[k]
	if AudioManager != null:
		AudioManager.apply_settings(GameManager.settings)

func autosave(reason: String = "") -> void:
	save_game()

func save_game() -> bool:
	var cfg := ConfigFile.new()
	var state: Dictionary = GameManager.get_state()
	cfg.set_value("game", "chapter", state.get("chapter", 1))
	cfg.set_value("game", "clues", state.get("clues", []))
	cfg.set_value("game", "ending", state.get("ending", 0))
	var em: Node = get_node_or_null("/root/EventManager")
	if em != null:
		cfg.set_value("game", "events", em.call("get_state"))
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Save failed: %s" % err)
		return false
	return true

func load_game() -> bool:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		return false
	var state := {
		"chapter": cfg.get_value("game", "chapter", 1),
		"clues": cfg.get_value("game", "clues", []),
		"ending": cfg.get_value("game", "ending", 0),
	}
	GameManager.apply_state(state)
	var em: Node = get_node_or_null("/root/EventManager")
	if em != null:
		em.call("apply_state", cfg.get_value("game", "events", []))
	if AudioManager != null:
		AudioManager.apply_settings(GameManager.settings)
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
