# NEXT_PLAN — what's left (written 2026-10-12, updated 2026-10-13)

## Done on 2026-10-13
- Voices: tapes + voicemail read by runtime TTS, one voice per character (`AudioManager.narrate`),
  static bed under tapes, [E] stops; voices/subtitles toggles in the pause menu.
- Real CC0 sounds (Kenney) + generated loops; audio unmuted; per-bus volumes (no more master²);
  footsteps by floor; doors open/close/creak; locked latch; rain muffled indoors, faint in basement.
- Captions for knocks, footsteps upstairs, car, fridge, pipe.
- Ch2 beat: fridge hum cuts out, then a pipe knocks in the wall (knocks motif kept for ch6).
- Chapter flow: one chapter at a time on story beats (no basement jump; ch3 footsteps never skipped);
  ending table only opens with photo + recording + letter; after the choice: "Open the front door".
- Save/load: fired events saved; cabinet, study door, hidden panel, fridge and morning restored.
- Morning lighting tweens in; phone order fixed (Noa asks, you answer).
- HUD: modals centred, real pause (`get_tree().paused`), Esc closes panels, scrollable journal
  with locations and tape transcripts; tape1 transcript bug fixed; data key mismatches fixed.
- Unused models moved to `../_unused_assets/`; fallback PNG textures excluded from exports.
- Web build (Edge): `build/web/`, run `python tools/serve_web.py`, open http://localhost:8060.
- Web freeze fixed: assets load a few per frame behind a loading screen (longest frame 4.6 s → 0.37 s
  native); materials cached (329 → 64). Browsers need a click to lock the mouse ("Click to look around").
- Tests: bot (story 1→9), walk_test (21 legs), tape_test (narration never hangs), audit: all pass.


State today: rooms rebuilt with real walls, furniture grounded and non-overlapping, doors hinged,
basement reachable by walking. Tests pass: `inspect_tool -- audit` (0 problems), `walk_test`
(21/21 legs), story bot (22 clues, chapters 1→9). Build in `build/`.
Fixed at end of day: front door now re-fires its event on every opening (morning ending was
unreachable), tape transcripts no longer get covered by the inspect panel, doors no longer show
a "<null>" panel.

Note: the bot calls `interact()` directly and teleports, so it does NOT prove a human can finish
the game. Do one full manual playthrough first thing tomorrow and log anything odd.

## Done on 2026-10-13 (afternoon)
- Back door in the kitchen west wall: locked from inside, new lock; trying it adds the clue
  `back_door` to the journal. Back step outside. Kitchen window moved north; table moved so the
  door is reachable.
- Interior stairs: L-shaped stair in the NE corner of the hall (flight along the east wall,
  corner landing, short flight west along the north wall over the cabinet's slide path), with
  stairwell cut through ceiling + upper floor, railings. Upper landing over the hall with three
  stuck doors, rug, stool, and the half-open window with the curtain + latch clue (ch3).
- Clue click-targets moved to physics layer 2: the interaction ray sees them, the player body
  does not (they no longer block walking).
- Graphics setting (pause menu): Low / Medium / High (SSAO, glow, shadows, render scale).
- Tests use `-- testsave` (user://test_save.cfg) so they never delete the player's save.
- Measured on this laptop (exe, 1280x720): ~50-75 fps; Low helps a little. Mesh batching was tried
  and gave no clear gain (benchmark noise), so it was not kept.

## Done on 2026-10-13 (evening)
- Service room (brief ch6): north end of the living room, door from the living room. Service
  cabinet against the outer wall slides aside; hidden panel (hinged on the east so the open leaf
  hugs the wall) opens onto the recess with the letter, last tape and the sealed box. Water
  heater, wall shelf, fuse box, bare bulb. Hall north wall is plain again.
- Living room re-laid out: the coffee table (tape 1 + the ending choice) was boxed in by the
  sofa, side table, cabinet and armchair. Now TV on the service-room wall, sofa facing it,
  1 m walkway on the door side.
- New test `tests/reach_test.gd`: flood-fills where the player capsule can stand on every floor
  and checks every clue/door has a clear interaction ray within 2.5 m (doors checked closed,
  clues with the story's doors open). Found the boxed-in table and an 8 cm squeeze to the
  service door; both fixed. Result: 4 doors + 28 clues reachable.

## Done on 2026-10-13 (night)
- Upstairs rooms opened (real hinged doors): Eitan's old room (bed, desk, child's drawing),
  parents' bedroom (four-poster, dresser, wedding photo, alarm clock stopped at 02:17), storage
  room (shelves, crates, rocking chair, old radio). All optional; reach test covers them.
- Radio upstairs: static; after the hidden wall is open, the three knocks answer faintly (brief ch6).
- Effects: vignette + optional film grain overlay (settings), fade from black after loading,
  fade to menu, soft dawn fade, street lamp falters once when the car passes, rain now falls
  all round the house but never indoors or into the basement (particle collision).
- UI: shared dark theme, one settings panel for menu + pause (volumes, mouse, graphics, voices,
  subtitles, vignette, grain), panels fade in, journal with headings/locations/transcripts,
  "[E] title" prompts, redesigned main menu.
- Bug fixed: changing settings in the main menu used to overwrite the game save; settings now
  live in user://settings.cfg.
- `tests/ui_shots.gd` captures every UI screen into tests/shots_ui/.

## Done: endings (brief ch8/ch9)
- The choice now changes the one item left on the living-room table (photo / tape / letter,
  moved to the middle, the others put away), the table's text, Eitan's answer to Noa
  ("I think so." / "Not all of it." / "I'm not sure."), Noa's last message (read aloud) and
  the closing line. Texts live in `GameManager.ENDINGS`. Restored correctly from a save.

## Done: tapes, clock, 3D sound
- Freeze when pressing E during a tape: the stop called DisplayServer.tts_stop(), which blocks
  the main thread on Windows (~210 ms every call, and once it never came back for the user).
  Narration no longer calls tts_stop/pause/resume; speech is one sentence per call and the next
  sentence waits until the engine is idle, so at most one sentence finishes after E.
  Could not reproduce the permanent freeze here - needs a retest by the user.
- Tape cues play: chair drag, silences (hiss drops), storm swells + rumble, slammed door, pipe,
  distant argument (very quiet voices), knocks, the "remembered wrong" echo, the tape cutting
  out; tape button clicks; the playing line is highlighted in the transcript.
- Wall clock: hands on real pivots, correct 02:17; when you are near, the second hand ticks,
  the minute hand jumps, then both spring back to 02:17.
- 3D sound: doors, latch, cabinet, gate, knocks (recess wall, stairwell, back door for the
  radio), pipe in the kitchen wall, upstairs footsteps, the car drives past along the street,
  radio static, your own footsteps. Reverb in the basement/stairwell and the tiled bathroom.
- Tests now log to their own file (`--log-file`) so they no longer push the player's own logs out.

## Done: stairs, readability, table
- Stairs rebuilt as a closed-string stair: wooden treads with nosing, painted risers, seamless
  plastered spandrel (world-mapped texture), stringer, balusters, newels; upper flight solid.
- Low graphics no longer turns off the moon's shadows (that lit every room through the roof).
- All UI text has a dark outline; the objective sits on a dark backing.
- The living-room table shows the photo / recording / letter as you find them; choosing too early
  says exactly what is missing and where; when ready, the choice opens (no inspect panel on top).
- Next steps for the home PC are in CLAUDE.md (VoxCPM2 voices, Blender models, fonts/UI, inventory).

## Done: basement moved under the house
- Door under the main stairs (hall side) → straight flight down under flight 1 → basement room
  under the living room/study, re-furnished (recorder first in view, Noa's note under the bulb).
- Old outside stairwell/basement removed (its wall tops were level with the grass and flickered).
- Porch lantern smaller, beside the door at head height.
- Story continuation draft: docs/STORY_CONTINUATION.md.

## Still open
- Browser build: no sound heard (check AudioContext resume after first click). Low priority now
  that the exe is the main target.

## 1. MUST (blocks a real playthrough or the story)
- [ ] **Manual playthrough** of the new build, start to morning ending. Note every blocker.
- [ ] **Audio is muted with no way to unmute**: `AudioManager.muted = true` (audio_manager.gd:4),
      `set_muted` never called. Unmute, check levels; master volume is applied twice (≈ master² × sfx,
      audio_manager.gd:150-157).
- [ ] **Captions for key sounds** (knocks, steps, car): brief §21 requires them, and without
      audio the knock motif is invisible.
- [ ] **Chapter flow**:
  - entering the basement early jumps straight to ch7 and later zones stop updating the objective;
  - after choosing an ending the objective is reset to 8 (hud.gd:365); add a clear ch9 prompt,
    "Open the front door";
  - gate the ending table on the key clues (it can be used in minute 1).
- [ ] **Save/load state**: doors, the service cabinet position, morning, and EventManager `_fired`
      are not saved. Continue after Save restores the cabinet but `cabinet_move` stays fired, so
      the hidden recess becomes unreachable (softlock).
- [ ] **HUD modals are off-centre** (inspect/journal panel anchored at screen centre, hud.gd:120 / :74).
- [ ] **Data key mismatches**:
  - tape ids `study_tapes`/`storm_full` vs clue ids `tapes_study`/`storm_tape`;
  - 5 documents.json keys never match a clue;
  - clue `upper_window` is missing from clues.json.

## 2. Rooms vs. story
- [ ] **Back door** (locked, inspectable). The plot hinges on it: Yoav's note, the repair order,
      "not through the front door". Proposed spot: kitchen west wall or north wall of the hall.
- [ ] **Interior stairs to the upper landing**. Ch3 needs footsteps overhead and the half-open
      window with the moving curtain; it all exists but can't be reached. Needs a hole in the
      ground-floor ceiling and the upper slab underside, plus a stair run (hall east side has room).
- [ ] Decide: basement from inside too (brief says "Don't start in the basement", implying an
      indoor door)? Option: door in the hall leading to the existing stairwell.
- [ ] Ch1: the player spawns inside but objective 1 says "Go inside". Either spawn at the gate
      (street/car intro) or reword the objective.
- [ ] Brief placements:
  - calendar belongs in the kitchen (now in the bathroom);
  - tape 1 belongs in Noa's room (now in the living room);
  - family photo + key should be in a stuck kitchen drawer;
  - kitchen radio missing (`DK.radio` exists, never placed).

## 3. Story beats to finish
- [ ] Key found: fridge hum cuts out, then a pipe sound (currently a light dip + knocks).
- [ ] Study lamp dip is wired to the living-room `tape1` event; wire it to the study tapes
      (they have an empty event_id).
- [ ] Ch6: knocks return when the radio or recorder plays. Ch7: faint replay of the storm night
      through the house.
- [ ] Ending table item and Noa's final line should change with the choice.
- [ ] Morning: tween the lighting change and fade; fix message order on the phone
      (hud.gd:256); restore morning lighting on load.
- [ ] Clock: animate the hands' twitch back to 02:17 (now static).

## 4. Audio (all placeholders today)
- [ ] Real ambience: rain outside vs. muffled inside, wind, house creaks, fridge hum, pipes,
      distant street; morning birds.
- [ ] 3D positional sounds (AudioStreamPlayer3D) and a reverb bus for the basement.
- [ ] Footsteps per surface (wood / tile / concrete / grass); knock variations (pitch/volume).
- [ ] Doors: latch, creak, locked rattle; gate creak; drawer; keys; light switch.
- [ ] Tape playback: radio-filtered voice or static bed; voicemail audio; one minimal music sting.
- [ ] UI ticks (`play_ui` is never called).
- [ ] Sources: CC0 only (freesound CC0 filter, Sonniss GDC bundles, or generate). Log every file in
      ASSET_CREDITS.md.

## 5. Effects / visuals
- [ ] Rain falls indoors: the emitter overlaps the front rooms. Add particle collision or shrink
      the emitter to the yard. Give the drops a material.
- [ ] Vignette + light film grain shader with settings toggles (the "vignette" setting only
      changes brightness today).
- [ ] Street lamp: a single flicker on a story beat. No lightning (brief §14: no white flashes).
- [ ] Fades: menu → game, ending, morning.
- [ ] Optional: 3D close-up when inspecting an item.

## 6. UI / UX
- [ ] Pause should really pause (`get_tree().paused`), with a Settings entry; Esc closes the inspect panel.
- [ ] Settings: ambience, story and music volumes, subtitles, shadow quality, vignette/grain,
      reduce effects.
- [ ] Journal: scrolling, show locations, re-listen to tapes, Tab as well as J.
- [ ] Replace the generic "Clue found:" toasts with in-voice text.

## 7. Cleanup
- [ ] Delete unused assets to shrink the ~320 MB build:
  - `assets/models/kenney/`;
  - unused Poly Haven models: CeramicPot, ClassicNightstand, CoffeeTable_01, DrawerCabinet,
    Frame_01/02, HangingFrame_01/02, PaintedCabinet, RoundCoffeeTable, Television_02, WallClock,
    WickerBasket.
- [ ] Fix doc drift:
  - README names the wrong main scene;
  - ARCHITECTURE.md lists a room_builders.gd that doesn't exist.
- [ ] Dead code: `apply_state` (game_manager.gd:62,72), duplicate `return`s in AudioManager.
- [ ] Optional: `git init` so changes are tracked (today's originals are in `../_backup_before_claude/`).

## Tools for tomorrow
- **Godot MCP**: configured in `C:\Projects\OpenCode\Games\.mcp.json` (`@coding-solo/godot-mcp`).
  It loads in a **new** Claude Code session; approve it when prompted.
- `tests/inspect_tool.gd`: free-camera screenshots, top-down plans, `dump` (prop bounds), `audit`.
- `tests/walk_test.gd`: drives the player through every doorway and the stairs.
- `tests/model_catalog.gd` + `tests/contact_sheet.gd`: size and facing check for new models.
- Re-export: `Godot_console.exe --headless --path . --export-release "Windows Desktop" build/TheHouseThatForgotMe.exe`

## Suggested order for tomorrow
1. Manual playthrough (30 min).
2. Must list §1 (audio unmute, captions, chapter flow, save state, modal centring, data keys).
3. Back door and interior stairs (§2).
4. Audio pass (§4).
5. Effects and UI polish (§5–6).
6. Cleanup and re-export.
