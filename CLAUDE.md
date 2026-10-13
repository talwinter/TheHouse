# The House That Forgot Me — notes for Claude

First-person narrative exploration game, **Godot 4.7.2** (Forward+), GDScript. Main scene
`scenes/ui/main_menu.tscn` → `scenes/levels/house_entry.tscn`. The whole house (walls, rooms,
furniture, clues, lights, sounds) is built in code by `scripts/levels/house_entry.gd`.
Design brief (Hebrew): `../THE_HOUSE_THAT_FORGOT_ME_GODOT_PROMPT_HE.md` (may not be in the repo).
Status and history: `docs/NEXT_PLAN.md`, `docs/TEST_REPORT.md`, `ASSET_CREDITS.md`.
Optional after-story draft (not implemented): `docs/STORY_CONTINUATION.md`.
Layout: ground floor rooms + upstairs landing with three rooms; the basement is UNDER the house
(below the living room/study), reached by the door under the main stairs in the hall.

## Next steps (agreed with the user, to do on the home PC — RTX 3060, 12 GB VRAM)

1. **Voices with VoxCPM2** (not done yet; the user said not to download it on the work PC).
   - Model: `openbmb/VoxCPM2` (pip `voxcpm`), Apache-2.0, ~8 GB VRAM. Python ≥3.10 <3.13,
     PyTorch ≥2.5, CUDA ≥12. API: `VoxCPM.from_pretrained("openbmb/VoxCPM2")`,
     `model.generate(text=..., reference_wav_path=..., prompt_wav_path=..., prompt_text=...,
     cfg_value=2.0, inference_timesteps=10)`, save with `model.tts_model.sample_rate`.
     Voice Design: put a description in parentheses before the text, e.g.
     `"(A tired woman around thirty, quiet, slightly hoarse)Line..."`.
   - Plan: (a) a Godot tool script exports every spoken line to `data/voice_lines.json`
     (speaker, text, id = md5("speaker|text")[:12]) using the same parsing as
     `AudioManager.narrate()` (quoted text = speech, speaker named before the quote) plus the
     voicemail (`VOICEMAIL` in house_entry.gd), the morning texts (`GameManager.ENDINGS`) and the
     distant-argument phrases in `AudioManager._distant_argument()`.
     (b) `tools/generate_voices.py`: design ONE reference clip per character with Voice Design,
     then clone every line from that clip (consistent voices); write OGG to
     `assets/audio/voice/<id>.ogg`.
     (c) `AudioManager.speak()` plays the file if it exists (on a "Tape" bus with band-pass +
     slight saturation for tapes, a "Phone" bus for the voicemail/texts) and falls back to the
     current runtime TTS otherwise. Stopping a file is instant (no Windows TTS involved).
   - Characters (`AudioManager.CAST`): noa (≈30, warm, tired), miriam (late 50s, low, careful),
     yoav (60s, tired, low), man (muffled, tense), whisper (barely audible).
   - Brief §15: synthetic voices only if the licence allows (Apache-2.0: yes); keep texts and
     audio files separate; label AI voices in the credits.
2. **Better models in Blender** to replace the procedural box props and the weaker Poly Haven picks
   (kitchen counters, bathtub, toilet, stairs, doors, window frames, service cabinet...).
   Keep real-world metric scale and +Z as the front; `furnish_external.ph()` grounds/centres them.
3. **Fonts + overall UI pass**: the theme is in `scripts/ui/ui_theme.gd` (currently the default
   font); HUD in `scripts/ui/hud.gd`, menu in `scripts/ui/main_menu.gd`, shared settings in
   `scripts/ui/settings_panel.gd`.
4. **Inventory** (not implemented): items like the brass key are only "known" as clue ids
   (`GameManager.clues_found`, e.g. `photo_key` unlocks the study and the hidden panel). The user
   wants a real inventory (picking up the key, seeing it, using it).

## How to run / test (always from this folder)

Godot binary on the work PC: `../.tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.
Always pass `-- testsave` (tests use `user://test_save.cfg`; the bot clears the save and would
otherwise wipe the player's real one) and `--log-file <tmp>` (otherwise tests rotate the
player's own logs out of `user://logs`). Redirect stdout to a file rather than piping to grep.

| Test | Command |
|---|---|
| Story bot (chapters 1→9) | add `Bot="*res://scripts/debug/bot.gd"` under `[autoload]`, run `--path . -- testsave`, remove the line again |
| Walk (capsule through every door, stairs, rooms) | `--headless --path . --script res://tests/walk_test.gd -- testsave` |
| Reach (every clue/door can be stood near and aimed at) | `--headless --path . --script res://tests/reach_test.gd -- testsave` |
| Overlap/wall audit + screenshots | `--path . --script res://tests/inspect_tool.gd -- out=tests/shots_after audit testsave` |
| Dialogues (early E) | `--path . --script res://tests/dialog_test.gd -- testsave` |
| Tapes finish (no hang) | `--path . --script res://tests/tape_test.gd -- voices_off testsave` |
| UI screenshots | `--path . --script res://tests/ui_shots.gd -- testsave` |
| FPS | `--path . --script res://tests/fps_bench.gd -- testsave` |
| Export exe | `--headless --path . --export-release "Windows Desktop" build/TheHouseThatForgotMe.exe` |

## Things learned the hard way

- `DisplayServer.tts_stop()` blocks the main thread on Windows (~210 ms, once froze the game).
  Narration never calls tts_stop/pause/resume; it speaks one sentence at a time.
- Clue click-targets are on physics layer 2 (the interaction ray sees them, the player body
  doesn't). Furniture colliders come from model bounds; beds/chairs use `shrink_top` so clue
  targets on them stay reachable.
- Stairs: the walkable surface is an invisible ramp through the step nosings; step colliders
  go to the full step height; banisters are short upright boxes (tilted boxes overhang).
- Sun/moon shadows must stay on at every graphics level (without them it lights the interior).
- Settings live in `user://settings.cfg`, never in the game save.
- Never leave coplanar faces (two surfaces at exactly the same height/plane): they flicker
  (z-fighting). The old outside basement had wall tops level with the grass and flickered.
