# ARCHITECTURE
Autoloads: GameManager(clues/chapter/settings, signals), SaveManager(user://save.cfg), AudioManager(buses Ambience/Foley/Story/Music/UI + WAV files + procedural fallback), EventManager(one-shot).
Core: MaterialFactory (procedural), HeroProps (multi-part composites).
Player: CharacterBody3D + Camera + RayCast 2.5m, duck-typed interact (has_method interact), HUD via group hud.
Levels: house_entry.gd coordinator + room_builders.gd statics (living/noa/study/hidden/basement/bath). Interactable extends StaticBody3D with title/body/clue/event. Data: data/clues.json, data/documents.json (planned). UI: HUD CanvasLayer built in code (prompt/inspect/journal/pause/toast). Endings scaffold: GameManager.ending_choice 1/2/3 → living table + final text (stage 5).
