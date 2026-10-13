extends SceneTree
## Plays every tape through AudioManager.narrate (voices on, quiet) and fails if any
## narration does not finish within its time budget. Needs a window (TTS is off headless).
var _t := 0.0
func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var am: Node = root.get_node("/root/AudioManager")
	var gm: Node = root.get_node("/root/GameManager")
	gm.get("settings")["voices"] = "voices_off" not in OS.get_cmdline_user_args()
	gm.get("settings")["story_volume"] = 0.25
	print("TAPE tts_ready=", am.call("voices_enabled"), " voices=", DisplayServer.tts_get_voices().size())
	var tapes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/tapes.json"))
	var fails := 0
	for id in tapes.keys():
		var lines: String = str(tapes[id]["lines"])
		var words: int = lines.split(" ", false).size()
		var budget: float = 6.0 + words * 0.8
		var t0 := Time.get_ticks_msec()
		am.call("narrate", lines)
		while am.call("is_narrating") and (Time.get_ticks_msec() - t0) / 1000.0 < budget:
			await create_timer(0.1).timeout
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		var ok: bool = not am.call("is_narrating")
		if not ok:
			fails += 1
			am.call("stop_narration")
		print("TAPE %-14s %5.1fs (budget %.0fs) %s" % [id, secs, budget, "ok" if ok else "HUNG"])
	print("TAPE RESULT ", "ALL PASSED" if fails == 0 else "FAILURES %d" % fails)
	quit(0 if fails == 0 else 1)
