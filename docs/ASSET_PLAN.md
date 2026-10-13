# ASSET_PLAN — practical combo (no Blender)

## Strategy: Godot-first + CC0 + Blockbench
1. House shell in-Godot: walls/floors/ceilings/frames/doors/windows/stairs as CSG + BoxMesh/CylinderMesh composites with `MaterialFactory` (wood, plaster_old, metal_dark, glass, fabric, paper, concrete). Reusable `PackedScene` modules in `scenes/modules/` (stage 4).
2. Story hero props in Blockbench (later): photo frame, key, box, tapes, radio. Export GLB → `assets/models/`. Keep .bbmodel source.
3. CC0 libraries (only with license check → ASSET_CREDITS.md):
   - Kenney (kenney.nl) — kitchen furniture base
   - Poly Pizza (poly.pizza) — small clutter
   - Quaternius — optional clutter
   - Poly Haven (polyhaven.com) — subtle wall/floor PBR + HDRI for reflections (low res)
   - OpenGameArt — only CC0/CC-BY with attribution
4. Material Maker (free OSS) for wood/plaster variation if needed. No AI textures without artifact/license check.
5. Audio: procedural placeholders now (rain/pipe/knocks/static via code). Replace order: rain/wind → footsteps/doors/paper → knocks motif → tapes static+subtitles → minimal music sting. Sources: self-recorded or CC0 (freesound with license check). No pirated files.

## Vertical Slice asset list (critical path only)
- Modules: wall_4m, floor_4x4, door_frame, door_leaf+handle, window+curtain(static anim later)
- Kitchen: counter, fridge (box+door), kettle/cup (cylinder+sphere), calendar (plane+texture from code), drawer (box-in-box), table+chairs simple
- Corridor: photo frames (box+plane), wall clock (cylinder+hands)
- Outside: path plane, fence posts, gate, mailbox (box), tree (cylinder+sphere blobs), street lamp (pole+SpotLight), puddles (plane metallic low rough), rain GPUParticles3D
- Story: family photo (plane), small key (torus+box composite), mother note (plane), radio (box+antenna cylinder)
- SFX placeholders generated: rain_loop, pipe_gurgle, fridge_cut (silence dip), knock_x3, radio_static, ui_tick, paper_rustle

## Licensing log
- All slice meshes/materials/audio-code are original procedural — no attribution needed. See `ASSET_CREDITS.md` when CC0 added.
- Do NOT use Gone Home assets/design/text. All names/texts original per prompt.

## QC (per prompt §31)
Eye-height check, scale/door 2.0m, corridor >=1.2m, no floating/clipping, interact ray hits correct part, heaviest light+particles area FPS check, reduced-quality check, document temp vs final.
