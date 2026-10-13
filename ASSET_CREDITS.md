# ASSET_CREDITS

## Realistic 3D models — Poly Haven (primary, 27 models)
Stored in `assets/models/polyhaven/<Name>/` as glTF + 1K PBR textures
(diffuse + OpenGL normal + ARM). Manifest: `SOURCES.json` in that folder.
- Author: Poly Haven — <https://polyhaven.com>
- Downloaded via public API: `https://api.polyhaven.com/files/<asset>`
- **License: CC0 1.0 Universal** — public domain, commercial use, no attribution required.

Sofas/chairs/tables: Sofa_01, ArmChair_01, CoffeeTable_01, RoundCoffeeTable.
Storage: Shelf_01, DrawerCabinet, PaintedCabinet.
Bedroom/study: Bed_Frame, Desk, Chair, WoodenChair, OfficeDesk, DeskLamp, Cassette.
Kitchen: Stove, Microwave. Bathroom: Mirror.
Basement: BarrelStove, Barrel, CardboardBox.
Wall dressing: Frame_01, Frame_02, HangingFrame_01, HangingFrame_02, WallLamp.
Exterior/props: StreetLamp, Fern, CeramicPot.

Asset authors as listed on Poly Haven (e.g. Aron Łyczek, Kay Lousberg and others).
Poly Haven requires no attribution; listed anyway.

## Additional Poly Haven models (added 2026-10-12, CC0 1.0)
Bookshelf_Worn, Nightstand, VintageCabinet, Wardrobe2, Console, SteelShelves, WoodenCrate, Crate2,
PottedPlant, PottedPlant2, ThrowPillows, KitchenTable (used as hall bench), DiningChair, RoundTable,
Suitcase, SideTable, CeilingLamp, Kettle, PullChainLight, Stool, SmallTable, Bowl, CuttingBoard,
PlanterPot, GothicBed, Dresser (vintage_wooden_drawer_01), RockingChair, StandingFrame,
AlarmClock, ClassicNightstand (+ a few spares). Slugs and URLs in `assets/models/polyhaven/SOURCES.json`.

## Placement
`furnish_external.ph()` measures each model's world AABB through the full glTF hierarchy,
centres its footprint on the requested point, rests it on the floor (or flush against a wall)
and builds a box collider in the model's local frame. `tests/inspect_tool.gd -- audit` checks
for overlaps and wall clipping.

## Kenney Furniture Kit
No longer used by the level (replaced by Poly Haven models and procedural pieces); the files in
`assets/models/kenney/` can be deleted.

## External textures — Poly Haven (9 PBR sets, 1K, 12.5 MB)
Stored in `assets/textures/external/` (albedo + OpenGL normal + roughness, JPEG).
Manifest: `assets/textures/external/SOURCES.json`. **License: CC0 1.0.**
floor_wood=wood_floor_deck, wood_panel=wood_planks_grey, wood_dark_panel=dark_wood,
wall_plaster=painted_plaster_wall, concrete=chipped_concrete, floor_tile=floor_tiles_02,
fabric_blue=fabric_pattern_07, metal_dark=metal_plate_02, paper=book_pattern.

## Original procedural content
- Fallback texture set in `assets/textures/` baked in-engine by `tools/gen_textures.gd`.
  `MaterialFactory` automatically falls back to it when an external file is missing, so
  the project still builds with no network access.
- All architecture, trim, doors, windows, stairs, service cabinet, basement shelving,
  wall clock, key, radiators, frames, rain and dust are built in Godot by
  `scripts/core/detail_kit.gd` and `scripts/levels/house_entry.gd`.
- Furniture gets an auto-generated box collider from its bounds (see Placement).

## Audio
- **Kenney CC0 sound packs** (<https://kenney.nl>, CC0 1.0; licence files in `assets/audio/licenses/`):
  Impact Sounds (footsteps wood/concrete/grass/carpet, wood knocks, metal pipe taps),
  RPG Audio (door open/close, creaks, page flips, latch click), Interface Sounds (UI ticks).
  Copied into `assets/audio/sfx/` as `<name>_<n>.ogg` variations.
- **Generated in-house** (original, by `make_audio.py`-style synthesis): rain loop, radio
  static loop, passing car, phone buzz, fridge hum.
- **Voices: none are shipped.** Tapes and the voicemail are read at runtime by the player's own
  text-to-speech (`DisplayServer.tts_speak`): Windows voices on desktop, the browser's voices on
  web (Edge provides natural neural voices). No audio is generated or redistributed, so no voice
  licence applies. Transcripts stay on screen (brief section 15).

## Not used
- No Gone Home assets, text, design or references.
- No paid, pirated, or licence-unverified assets. Every external file above is CC0.
- Third-party reupload sites with unverifiable provenance were deliberately avoided.
