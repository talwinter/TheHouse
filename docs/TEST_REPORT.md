# TEST_REPORT — layout/collision overhaul (2026-10-12)
Godot 4.7.2.stable, Windows 11, Vulkan Forward+.

## What was actually wrong (found during this pass)
- `scripts/levels/furnish_external.gd` had a **parse error** (mis-indented kitchen block), so
  the level did not load at all. `build/` was **empty**: the previous report's export did not exist.
- **Degrees passed as radians**: every `DetailKit` helper did `rotation.y = rot_y` with callers
  passing 90/180/-90, so windows, door casings, radiators, frames, the clock, key and shelves were
  turned by e.g. 90 rad = 117°.
- **Grounding math ignored nested glTF transforms** (`mi.transform` only), so the stove floated at
  y=0.81, the kitchen cabinet at 1.18, etc. The old `probe_props` used the same math and reported OK.
- **Kenney models pivot on a corner**: the rug reached x=7.47 (outside the house), sink/bathtub offset.
- **No interior walls**: Noa's room, the hall and the entry were one open space; kitchen counters were
  never built, so the cup, sink, key and microwave floated against the wall.
- Doors rotated around their centre (leaf clipped into walls when opened); the service cabinet slid
  into a wall; basement had 1.6 m headroom (player could not fit) and the fall guard (y < -2.5)
  teleported the player out of the basement; no ground outside the house.
- The old screenshot probe placed the *player body* at eye height, so every shot was taken from ~3.2 m.

## Fixes
- Floor plan rebuilt with `_wall()` (real door/window openings, two-sided materials per room),
  hinged doors, hidden recess behind the service cabinet, 2.6 m-deep basement with a walkable
  stairwell, ground + fence + gate outside, upper storey shell + gable roof.
- New placement API `furnish_external.ph()`: world-space AABB via global transforms, footprint
  re-centred on the requested point, flush-to-wall option, local-frame collision boxes.
- Kenney toy models replaced by Poly Haven CC0 models or new procedural pieces (counter + sink,
  bathtub, toilet, bedding, rug). All clues now rest on real surfaces.

## Verification (all automated, re-runnable)
| Check | Command | Result |
|---|---|---|
| Spatial audit (prop/prop overlap, prop/wall clipping) | `--path . --script res://tests/inspect_tool.gd -- audit only=none testsave` | 48 props, 78 wall pieces, **0 problems** |
| Physics walk (player capsule driven through 21 legs: every doorway, all rooms, basement stairs down + up) | `--headless --path . --script res://tests/walk_test.gd -- testsave` | **ALL PASSED** |
| Story bot (chapters 1→9, 22 clues, endings, save) | add `Bot="*res://scripts/debug/bot.gd"` to `[autoload]`, run `--path . -- testsave` (never without `testsave`: the bot clears the save) | **BOT ALL PASSED**, 22 clues |
| Screenshots (24 views + 6 top-down plans) | `--path . --script res://tests/inspect_tool.gd -- out=tests/shots_after` | `tests/shots_after/` (before: `tests/shots_before/`) |
| Reachability (every clue/door can be stood near and aimed at) | `--headless --path . --script res://tests/reach_test.gd -- testsave` | 7 doors + 32 inspectables **ALL REACHABLE** |
| UI screenshots (menu, loading, inspect, tape, journal, pause, endings) | `--path . --script res://tests/ui_shots.gd -- testsave` | `tests/shots_ui/` |
| Dialogues: early E (voicemail updates the objective; morning shows every message before closing) | `--path . --script res://tests/dialog_test.gd -- testsave` | **ALL PASSED** |
| Exported pack boots | `--headless --main-pack build/TheHouseThatForgotMe.pck --quit-after 900` | exit 0, no errors |

`tests/model_catalog.gd` renders every Poly Haven model with its real size (`tests/catalog/`).
Removed (superseded, gave false OKs): `probe_walk`, `probe_layout`, `probe_props`, `probe_verify`.
Originals are in `../_backup_before_claude/`.

## Build
`build/TheHouseThatForgotMe.exe` + `.pck` (≈ 320 MB total). The pack still contains unused assets:
Kenney kit and 13 unused Poly Haven models (CeramicPot, ClassicNightstand, CoffeeTable_01,
DrawerCabinet, Frame_01/02, HangingFrame_01/02, PaintedCabinet, RoundCoffeeTable, Television_02,
WallClock, WickerBasket) — delete them to shrink the build.

## Known limits
- Audio is still muted placeholder WAVs. Upper floor has no stairs (decoration only).
- See `docs/NEXT_PLAN.md` for the remaining work.
