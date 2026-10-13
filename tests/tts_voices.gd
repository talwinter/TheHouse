extends SceneTree
## Lists the TTS voices this platform exposes (desktop: OS voices; web: browser voices).
func _initialize() -> void:
	print("TTS setting=", ProjectSettings.get_setting("audio/general/text_to_speech", "missing"))
	for v in DisplayServer.tts_get_voices():
		print("VOICE ", v)
	quit(0)
