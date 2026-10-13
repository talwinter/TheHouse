# TECHNICAL_PLAN — The House That Forgot Me

Env verified 2026-10-11:
- OS: Windows 11 64-bit, Ryzen 7 PRO 5850U, ~45GB RAM
- Godot: 4.7.2.stable.official.ed1daf0bf at `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe`
- Node 22.23.2 / npm 10.9.8 / git 2.51.2 — MCP runnable
- MCP: `@coding-solo/godot-mcp` 0.1.1 via `opencode.json` with `GODOT_PATH` set. Headless CLI is source of truth; MCP wraps same commands.

## Decisions
- Godot 4.7 Forward+ on PC, fallback gl_compatibility mobile (set). 1280x720, stretch canvas_items/expand.
- GDScript typed, InputMap actions: move_forward/back/left/right, sprint(Shift), interact(E), journal(J), pause(Esc).
- First-person: CharacterBody3D + Camera3D + RayCast3D 2.5m. No aggressive bob (toggleable, off by default in slice).
- Autoloads: GameManager (clues/chapter/events state), SaveManager (user://save.cfg), AudioManager (buses + procedural placeholder streams), EventManager (one-shot triggers).
- Data-driven clues: `res://data/clues.json` + `res://data/documents.json`, not hardcoded strings.
- Collision: separate simple BoxShape3D StaticBody from decorative meshes.
- Lighting budget: 1 Directional (moon) + <6 Omni/Spot practicals in slice. WorldEnvironment: faint glow, subtle SSAO, very light vignette/grain (toggleable). No per-frame random flicker — Tweens only.
- Audio buses: Ambience, Foley, Story, Music, UI. 3D positional where relevant, reverb light. Procedural WAV placeholders until CC0/recorded assets land.
- Save: chapter, clues_found Array, opened doors/drawers, ending choice, settings. Autosave on clue + chapter change. New/Continue in main menu (minimal in slice).
- Godot-first 3D, no Blender dependency: CSG + MeshInstance primitives + MaterialFactory procedural StandardMaterial3D. Blockbench only for hero story props later. CC0 (Kenney/Poly Pizza/Poly Haven/Quaternius) only if license checked.

## Vertical Slice scope (Stage 2)
- Level `house_entry.tscn`: outside path (gate/fence/lamp/rain), entry hall, kitchen (tea cup, calendar, mother note, stuck drawer+photo+key, radio static), corridor stub (family photos, wall clock 02:17).
- 3+ inspectables, 1 clue (photo back "count to three"), 1 light/sound event (fridge cut + pipe sound on key pickup), basic save/continue.
- HUD: dot + `E — לבדוק / E - Inspect` (language: Hebrew UI for now per prompt source; final game consistent HE or EN), inspect panel, journal (J), pause (Esc).

## Risks / limits
- No real voice acting yet — subtitles + radio static placeholders, documented.
- No export templates yet — run in editor/headless only until slice passes TEST_REPORT.
- Rain = GPUParticles3D simple, capped amounts for iGPU.

## Commands
- Run headless check: `.tools/godot-4.7.2/Godot_v4.7.2-stable_win64.exe --headless --path TheHouseThatForgotMe --quit-after 5`
- Edit: open `TheHouseThatForgotMe/project.godot` in Godot editor.
- MCP: `GODOT_PATH` set in opencode.json; tools: get_godot_version, list_projects, run_project, get_debug_output.
