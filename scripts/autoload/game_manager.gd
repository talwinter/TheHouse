extends Node
## GameManager: clues, chapter, settings. Autoload.

signal clue_found(clue_id: String)
signal chapter_changed(chapter: int)
signal ending_chosen(choice: int)

## The three versions (brief ch8/ch9). The choice changes the one item left on the table,
## Eitan's answer to Noa, Noa's last message and the closing line.
const ENDINGS := {
	1: {
		"version": "He left.",
		"item": "photo",
		"table": "Only the photograph is left on the table. The evening they counted to three, everyone smiling at the camera.",
		"reply": "I think so.",
		"noa": "Then keep the photo. It's the version Mom could live with. Maybe we can learn to live with it too.",
		"line": "He left. We kept ourselves.",
	},
	2: {
		"version": "He came back. No one opened.",
		"item": "tape",
		"table": "Only the tape is left on the table. Three knocks, and then nothing, for as long as the tape runs.",
		"reply": "Not all of it.",
		"noa": "Keep the tape. Somebody should remember that he knocked. I'm done pretending none of us heard.",
		"line": "He came back. No one opened.",
	},
	3: {
		"version": "Memory is incomplete.",
		"item": "letter",
		"table": "Only Mom's letter is left on the table. Some things we remember exactly. Some things we build again, so we can keep living.",
		"reply": "I'm not sure.",
		"noa": "Neither am I. Keep the letter. For once we can be unsure together, out loud.",
		"line": "Memory is incomplete. Each of us kept a different piece.",
	},
}

func ending() -> Dictionary:
	return ENDINGS.get(ending_choice, {})

var clues_found: Array[String] = []
var chapter: int = 1
var ending_choice: int = 0
var restored: bool = false
var settings: Dictionary = {
	"mouse_sensitivity": 0.0025,
	"master_volume": 0.8,
	"sfx_volume": 0.8,
	"ambience_volume": 0.8,
	"story_volume": 0.9,
	"music_volume": 0.6,
	"voices": true,
	"subtitles": true,
	"graphics": 1,
	"camera_bob": false,
	"vignette": true,
	"film_grain": false,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func has_clue(clue_id: String) -> bool:
	return clues_found.has(clue_id)

func add_clue(clue_id: String) -> void:
	if clues_found.has(clue_id):
		return
	clues_found.append(clue_id)
	clue_found.emit(clue_id)
	if SaveManager != null:
		SaveManager.autosave("clue:" + clue_id)

func set_chapter(value: int) -> void:
	if value == chapter:
		return
	chapter = value
	chapter_changed.emit(chapter)
	if SaveManager != null:
		SaveManager.autosave("chapter:" + str(chapter))

func choose_ending(v: int) -> void:
	ending_choice = clampi(v, 1, 3)
	set_chapter(8)
	ending_chosen.emit(ending_choice)
	if SaveManager != null:
		SaveManager.save_game()

## Closing line for the credits.
func final_text() -> String:
	return str(ending().get("line", ""))

func get_state() -> Dictionary:
	return {"chapter": chapter, "clues": clues_found.duplicate(), "settings": settings.duplicate(), "ending": ending_choice}

func apply_state(state: Dictionary) -> void:
	restored = true
	chapter = int(state.get("chapter", 1))
	ending_choice = int(state.get("ending", 0))
	clues_found.clear()
	for c in state.get("clues", []):
		clues_found.append(str(c))
	chapter_changed.emit(chapter)
	restored = false
