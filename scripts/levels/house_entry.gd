extends Node3D
## The House That Forgot Me — full game coordinator.
##
## Floor plan (ground floor, x right / z toward the street, metres):
##
##   z=-5 +-----------------+--------------------+--------------+
##        | KITCHEN         |  HALL  [service    | LIVING       |
##        | x -6..-1.2      |  x -1.2..3.0  cab] | x 3.0..6     |
##        |          arch ==|                    |              |
##   -1.6 +-------+---------+                   =door           |
##        | BATH  door  passage                  |              |
##    0.7 +-------+---door--+                    +--------------+ 1.9
##        | NOA'S ROOM      | photo wall         = STUDY (locked)|
##        | x -6..-1.2      |                    | x 3.0..6     |
##   z=5  +-----------------+-----[front door]---+--------------+
##
## Basement is reached from the front yard by an outside stairwell (x 0.7..2.3).
## Every wall is built by _wall(), which cuts real openings for doors and windows.

const MFScript := preload("res://scripts/core/material_factory.gd")
const InterScript := preload("res://scripts/interactables/interactable.gd")
const DoorScript := preload("res://scripts/interactables/door.gd")
const DK := preload("res://scripts/core/detail_kit.gd")
const F := preload("res://scripts/levels/furnish_external.gd")
const HP := preload("res://scripts/props/hero_props.gd")

const OBJECTIVES := {
	1: "Listen to Noa's message.",
	2: "Search the kitchen. Find what Mom left.",
	3: "Follow the corridor. Check the photographs.",
	4: "Search Noa's room.",
	5: "Unlock the study. Play every tape.",
	6: "Look behind the service cabinet.",
	7: "Go down to the basement. Hear the whole night.",
	8: "Return to the living room. Choose the version you can live with.",
	9: "Morning. Open the front door.",
}

const VOICEMAIL := "NOA — 02:17 voicemail\n\"Eitan, if you're hearing this, I came home. Everyone says the house is empty, but that's not true. Don't start in the basement. First find what Mom left in the kitchen. And if you hear three knocks... don't answer.\""

const HALL := 3.0          # ground-floor ceiling height
const UPPER_Y := 3.4       # upper floor level
const BF := -2.6           # basement floor level
const T_IN := 0.12         # interior wall thickness
const T_OUT := 0.3         # exterior wall thickness

var hud: CanvasLayer
var kitchen_light: OmniLight3D
var hall_light: OmniLight3D
var rain: GPUParticles3D
var _morning := false
var _study_lamp: OmniLight3D
var _fridge_hum: AudioStreamPlayer3D
var _street_spot: SpotLight3D
## Items on the living-room table, so the ending can leave just one of them.
var _table_items: Dictionary = {}
## True once the whole house is built (tests wait for this / the `built` signal).
var is_built := false
var _shadow_lights: Array = []
var _preloaded: Array = []
signal built

## Loading is spread over many frames behind a loading screen: in a browser the game
## runs on the page's only thread, and one long frame makes Edge offer "Wait / Exit".
func _ready() -> void:
	hud = $HUD
	var player: CharacterBody3D = $Player
	player.add_to_group("player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _preload_assets()
	var timing: bool = OS.get_cmdline_user_args().has("timing")
	var steps: Array = [_build_shell, _build_kitchen, _build_bathroom, _build_noa_room, _build_hall,
			_build_service_hidden, _build_living, _build_study, _build_outside, _build_basement,
			_build_stairs, _build_upper_floor, _place_doors, _atmosphere]
	for i in steps.size():
		var t0 := Time.get_ticks_usec()
		(steps[i] as Callable).call()
		if timing:
			print("BUILD %-22s %6.1f ms" % [(steps[i] as Callable).get_method(), (Time.get_ticks_usec() - t0) / 1000.0])
		if hud != null:
			hud.call("set_loading", "Building the house…", 0.7 + 0.3 * float(i + 1) / float(steps.size()))
		await get_tree().process_frame
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if hud != null:
		hud.call("fade", 1.0, 0.0)
		hud.call("set_loading", "", 1.0)
		hud.call("fade", 0.0, 1.4)
	_apply_visual_settings()
	_add_zones()
	_reverb_room(Vector3(4.0, BF + 1.2, 2.27), Vector3(3.7, 2.4, 5.15), "ReverbBasement", 0.55)
	_reverb_room(Vector3((BS_X0 + BS_X1) * 0.5, -1.3, -1.9), Vector3(0.8, 2.8, 3.4), "ReverbBasement", 0.3)
	_reverb_room(Vector3(-4.75, 1.4, -0.45), Vector3(2.2, 2.8, 2.2), "ReverbTile", 0.35)
	_clock_loop()
	var em: Node = get_node_or_null("/root/EventManager")
	if em != null:
		em.connect("event_fired", _on_event)
	var sm: Node = get_node_or_null("/root/SaveManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.connect("clue_found", func(_c: String) -> void:
			_advance.call_deferred()
			_apply_table_collected.call_deferred())
		gm.connect("ending_chosen", _apply_ending_table)
	if sm != null and bool(sm.call("has_save")):
		sm.call("load_game")
		_restore_world()
		_set_objective_current()
	else:
		if gm != null and gm.has_method("set_chapter"):
			gm.call("set_chapter", 1)
		_set_objective(1)
		if hud != null and hud.has_method("show_phone"):
			hud.call("show_phone", "A message waiting", VOICEMAIL, "noa", "voicemail_heard")
	_apply_table_collected()
	is_built = true
	built.emit()

## Loads every model and texture set up front, a few per frame (time-budgeted), and
## keeps references so building the rooms afterwards hits the resource cache.
func _preload_assets() -> void:
	var paths: Array = []
	var d := DirAccess.open(F.PH)
	if d != null:
		for n in d.get_directories():
			paths.append(F.PH + n + "/model.gltf")
	var mats: Array = [MFScript.wood_floor, MFScript.tile_floor, MFScript.concrete, MFScript.plaster,
		MFScript.plaster_old, MFScript.plaster_cold, MFScript.plaster_green, MFScript.ceiling,
		MFScript.wood_dark, MFScript.wood_mid, MFScript.wood_trim, MFScript.metal_dark,
		MFScript.paint_metal, MFScript.fabric_blue, MFScript.exterior, MFScript.grass,
		MFScript.roof, MFScript.bath_tile, MFScript.worktop, MFScript.paper]
	var total: int = paths.size() + mats.size()
	var done := 0
	var t_frame := Time.get_ticks_msec()
	for m in mats:
		_preloaded.append((m as Callable).call())
		done += 1
		if Time.get_ticks_msec() - t_frame > 40:
			if hud != null:
				hud.call("set_loading", "Loading the house…", 0.7 * float(done) / float(total))
			await get_tree().process_frame
			t_frame = Time.get_ticks_msec()
	for p in paths:
		if ResourceLoader.exists(p):
			_preloaded.append(load(p))
		done += 1
		if Time.get_ticks_msec() - t_frame > 40:
			if hud != null:
				hud.call("set_loading", "Loading the house…", 0.7 * float(done) / float(total))
			await get_tree().process_frame
			t_frame = Time.get_ticks_msec()

# ---------------------------------------------------------------- helpers
func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	if collide:
		var body := DK.collide(parent, pos, size)
		body.add_to_group("structure")
	return mi

## Axis-aligned wall from a to b (x,z). mat_pos faces +X (walls along Z) or +Z (walls
## along X); mat_neg faces the other way. openings: [c0, c1, bottom, top] in absolute
## coordinates along the wall.
func _wall(a: Vector2, b: Vector2, t: float, mat_pos: Material, mat_neg: Material, openings: Array = [], y0: float = 0.0, y1: float = HALL) -> void:
	var along_x: bool = absf(b.y - a.y) < 0.001
	var lo: float = minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi: float = maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var fixed: float = a.y if along_x else a.x
	var ops: Array = openings.duplicate()
	ops.sort_custom(func(p, q): return float(p[0]) < float(q[0]))
	var cur: float = lo
	for o in ops:
		var c0: float = float(o[0])
		var c1: float = float(o[1])
		if c0 > cur + 0.001:
			_wall_piece(along_x, fixed, cur, c0, y0, y1, t, mat_pos, mat_neg)
		if float(o[2]) > y0 + 0.001:
			_wall_piece(along_x, fixed, c0, c1, y0, float(o[2]), t, mat_pos, mat_neg)
		if float(o[3]) < y1 - 0.001:
			_wall_piece(along_x, fixed, c0, c1, float(o[3]), y1, t, mat_pos, mat_neg)
		cur = c1
	if hi > cur + 0.001:
		_wall_piece(along_x, fixed, cur, hi, y0, y1, t, mat_pos, mat_neg)

func _wall_piece(along_x: bool, fixed: float, s0: float, s1: float, ya: float, yb: float, t: float, mat_pos: Material, mat_neg: Material) -> void:
	var l: float = s1 - s0
	var h: float = yb - ya
	var mid: float = (s0 + s1) * 0.5
	var yc: float = (ya + yb) * 0.5
	var c := Vector3(mid, yc, fixed) if along_x else Vector3(fixed, yc, mid)
	var nrm := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var half := Vector3(l, h, t * 0.5) if along_x else Vector3(t * 0.5, h, l)
	_box(self, c + nrm * t * 0.25, half, mat_pos, false)
	_box(self, c - nrm * t * 0.25, half, mat_neg, false)
	var body := DK.collide(self, c, Vector3(l, h, t) if along_x else Vector3(t, h, l))
	body.add_to_group("structure")
	body.add_to_group("wall")

## Baseboard along a wall face a->b, skipping gaps [c0, c1] (absolute, along the run).
## Walk each room so the room interior is on the LEFT of a->b when seen from above
## with +Z down (i.e. north edge west->east, east edge north->south, ...).
func _bb(a: Vector2, b: Vector2, gaps: Array = [], y: float = 0.0) -> void:
	var along_x: bool = absf(b.y - a.y) < 0.001
	var s0: float = a.x if along_x else a.y
	var s1: float = b.x if along_x else b.y
	var dirn: float = signf(s1 - s0)
	var cuts: Array = [s0]
	for g in gaps:
		cuts.append(float(g[0]) if dirn > 0 else float(g[1]))
		cuts.append(float(g[1]) if dirn > 0 else float(g[0]))
	cuts.append(s1)
	var i := 0
	while i + 1 < cuts.size():
		var p0: float = cuts[i]
		var p1: float = cuts[i + 1]
		if absf(p1 - p0) > 0.05:
			var va := Vector3(p0, y, a.y) if along_x else Vector3(a.x, y, p0)
			var vb := Vector3(p1, y, a.y) if along_x else Vector3(a.x, y, p1)
			DK.baseboard(self, MFScript, va, vb)
		i += 2

func _interact(pos: Vector3, size: Vector3, title: String, body: String, clue: String, event_id: String, tape: String = "", show: bool = true, parent: Node3D = null) -> Node:
	var inter: StaticBody3D = InterScript.new()
	inter.name = "Clue_" + title.replace(" ", "_").replace("'", "").replace("(", "").replace(")", "").replace("/", "_")
	inter.position = pos
	inter.set("title", title)
	inter.set("body_text", body)
	inter.set("clue_id", clue)
	inter.set("event_id", event_id)
	inter.set("tape_id", tape)
	if show:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = MFScript.paper()
		inter.add_child(mi)
	inter.collision_layer = 2
	inter.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.1, 0.1, 0.1)
	cs.shape = shape
	inter.add_child(cs)
	(parent if parent != null else self).add_child(inter)
	return inter

func _omni(pos: Vector3, col: Color, energy: float, rng: float, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadows
	add_child(l)
	if shadows:
		_shadow_lights.append(l)
	return l

# ---------------------------------------------------------------- shell
func _build_shell() -> void:
	var ext: Material = MFScript.exterior()
	var p_kit: Material = MFScript.plaster_old()
	var p_hall: Material = MFScript.plaster_cold()
	var p_noa: Material = MFScript.plaster()
	var p_liv: Material = MFScript.plaster()
	var p_study: Material = MFScript.plaster_green()
	var tile: Material = MFScript.bath_tile()
	var p_serv: Material = MFScript.plaster_cold()

	# Slabs
	# Ground-floor slab, with the basement stairwell cut out under flight 1 of the stairs
	# (x BS_X0..BS_X1, z BS_Z_TOP..-0.75).
	var wf: Material = MFScript.wood_floor()
	for r in [[-6.15, BS_X0, -5.15, 5.15], [BS_X1, 6.15, -5.15, 5.15], [BS_X0, BS_X1, -5.15, BS_Z_TOP], [BS_X0, BS_X1, -0.75, 5.15]]:
		_box(self, Vector3((float(r[0]) + float(r[1])) * 0.5, -0.1, (float(r[2]) + float(r[3])) * 0.5), Vector3(float(r[1]) - float(r[0]), 0.2, float(r[3]) - float(r[2])), wf)
	_box(self, Vector3(-3.555, 0.006, -3.255), Vector3(4.59, 0.012, 3.19), MFScript.tile_floor(), false)
	_box(self, Vector3(-4.755, 0.006, -0.45), Vector3(2.19, 0.012, 2.18), MFScript.tile_floor(), false)

	# --- Exterior walls (inside material per room, render outside)
	# North (z=-5): room side is +Z
	_wall(Vector2(-6.15, -5), Vector2(-1.2, -5), T_OUT, p_kit, ext)
	_wall(Vector2(-1.2, -5), Vector2(3.0, -5), T_OUT, p_hall, ext)
	_wall(Vector2(3.0, -5), Vector2(6.15, -5), T_OUT, p_serv, ext, [[SV_PANEL_X - 0.41, SV_PANEL_X + 0.41, 0.0, 1.52]])
	# South (z=5): room side is -Z
	_wall(Vector2(-6.15, 5), Vector2(-1.2, 5), T_OUT, ext, p_noa, [[-3.5, -2.5, 0.95, 2.15]])
	_wall(Vector2(-1.2, 5), Vector2(3.0, 5), T_OUT, ext, p_hall, [[-0.6, 0.6, 0.0, 2.1]])
	_wall(Vector2(3.0, 5), Vector2(6.15, 5), T_OUT, ext, p_study, [[4.95, 5.75, 1.0, 2.1]])
	# West (x=-6): room side is +X
	_wall(Vector2(-6, -4.85), Vector2(-6, -1.6), T_OUT, p_kit, ext, [[-4.1, -3.0, 1.0, 2.1], [-2.55, -1.7, 0.0, 2.05]])
	_wall(Vector2(-6, -1.6), Vector2(-6, 0.7), T_OUT, tile, ext, [[-0.9, -0.2, 1.25, 1.95]])
	_wall(Vector2(-6, 0.7), Vector2(-6, 4.85), T_OUT, p_noa, ext, [[2.1, 3.0, 0.95, 2.15]])
	# East (x=6): room side is -X
	_wall(Vector2(6, -4.85), Vector2(6, -3.2), T_OUT, ext, p_serv)
	_wall(Vector2(6, -3.2), Vector2(6, 1.9), T_OUT, ext, p_liv, [[-1.5, -0.3, 0.9, 2.15]])
	_wall(Vector2(6, 1.9), Vector2(6, 4.85), T_OUT, ext, p_study)

	# --- Interior walls
	_wall(Vector2(-1.2, -4.85), Vector2(-1.2, -1.6), T_IN, p_hall, p_kit, [[-3.6, -2.4, 0.0, 2.2]])
	_wall(Vector2(-5.85, -1.6), Vector2(-3.6, -1.6), T_IN, tile, p_kit)
	_wall(Vector2(-3.6, -1.6), Vector2(-3.6, 0.7), T_IN, p_hall, tile, [[-0.9, -0.1, 0.0, 2.05]])
	_wall(Vector2(-5.85, 0.7), Vector2(-3.6, 0.7), T_IN, p_noa, tile)
	_wall(Vector2(-3.6, 0.7), Vector2(-1.2, 0.7), T_IN, p_noa, p_hall, [[-2.7, -1.8, 0.0, 2.05]])
	_wall(Vector2(-1.2, 0.7), Vector2(-1.2, 4.85), T_IN, p_hall, p_noa)
	_wall(Vector2(3.0, -4.85), Vector2(3.0, -3.2), T_IN, p_serv, p_hall)
	_wall(Vector2(3.0, -3.2), Vector2(3.0, 1.9), T_IN, p_liv, p_hall, [[-0.5, 0.6, 0.0, 2.1]])
	_wall(Vector2(3.06, -3.2), Vector2(5.85, -3.2), T_IN, p_liv, p_serv, [[SV_DOOR_X - 0.45, SV_DOOR_X + 0.45, 0.0, 2.05]])
	_wall(Vector2(3.06, 1.9), Vector2(5.85, 1.9), T_IN, p_study, p_liv)
	_wall(Vector2(3.0, 1.9), Vector2(3.0, 4.85), T_IN, p_study, p_hall, [[2.4, 3.4, 0.0, 2.1]])

	# --- Openings: trims and glazing
	DK.doorway_trim(self, MFScript, Vector3(0, 0, 5.0), 1.2, 2.1, T_OUT)
	DK.doorway_trim(self, MFScript, Vector3(-1.2, 0, -3.0), 1.2, 2.2, T_IN, 90.0)
	DK.doorway_trim(self, MFScript, Vector3(-3.6, 0, -0.5), 0.8, 2.05, T_IN, 90.0)
	DK.doorway_trim(self, MFScript, Vector3(-2.25, 0, 0.7), 0.9, 2.05, T_IN)
	DK.doorway_trim(self, MFScript, Vector3(3.0, 0, 0.05), 1.1, 2.1, T_IN, 90.0)
	DK.doorway_trim(self, MFScript, Vector3(SV_DOOR_X, 0, -3.2), 0.9, 2.05, T_IN)
	DK.doorway_trim(self, MFScript, Vector3(3.0, 0, 2.9), 1.0, 2.1, T_IN, 90.0)
	DK.window_in_wall(self, MFScript, Vector3(-3.0, 1.55, 5.0), 1.0, 1.2, T_OUT)
	DK.window_in_wall(self, MFScript, Vector3(5.35, 1.55, 5.0), 0.8, 1.1, T_OUT)
	DK.window_in_wall(self, MFScript, Vector3(-6.0, 1.55, -3.55), 1.1, 1.1, T_OUT, 90.0)
	DK.doorway_trim(self, MFScript, Vector3(-6.0, 0, -2.125), 0.85, 2.05, T_OUT, 90.0)
	_box(self, Vector3(-6.45, 0.06, -2.125), Vector3(0.6, 0.12, 1.1), MFScript.concrete())
	DK.window_in_wall(self, MFScript, Vector3(-6.0, 1.6, -0.55), 0.7, 0.7, T_OUT, 90.0)
	DK.window_in_wall(self, MFScript, Vector3(-6.0, 1.55, 2.55), 0.9, 1.2, T_OUT, 90.0)
	DK.window_in_wall(self, MFScript, Vector3(6.0, 1.525, -0.9), 1.2, 1.25, T_OUT, 90.0)

	# --- Baseboards (room interior on the left of each run)
	_bb(Vector2(-5.85, -4.79), Vector2(-1.26, -4.79))
	_bb(Vector2(-1.26, -4.85), Vector2(-1.26, -1.66), [[-3.6, -2.4]])
	_bb(Vector2(-3.6, -1.66), Vector2(-5.85, -1.66))
	_bb(Vector2(-5.79, -1.66), Vector2(-5.79, -4.85), [[-2.55, -1.7]])
	_bb(Vector2(-5.85, -1.54), Vector2(-3.66, -1.54))
	_bb(Vector2(-3.66, -1.54), Vector2(-3.66, 0.64), [[-0.9, -0.1]])
	_bb(Vector2(-3.66, 0.64), Vector2(-5.85, 0.64))
	_bb(Vector2(-3.54, 0.64), Vector2(-3.54, -1.54), [[-0.9, -0.1]])
	_bb(Vector2(-1.2, 0.64), Vector2(-3.54, 0.64), [[-2.7, -1.8]])
	_bb(Vector2(-5.85, 0.76), Vector2(-1.26, 0.76), [[-2.7, -1.8]])
	_bb(Vector2(-1.26, 0.76), Vector2(-1.26, 4.85))
	_bb(Vector2(-1.26, 4.79), Vector2(-5.85, 4.79))
	_bb(Vector2(-5.79, 4.85), Vector2(-5.79, 0.76))
	_bb(Vector2(-1.14, 4.85), Vector2(-1.14, 0.7))
	_bb(Vector2(-1.14, -1.6), Vector2(-1.14, -4.85), [[-3.6, -2.4]])
	_bb(Vector2(-1.14, -4.79), Vector2(2.94, -4.79))
	_bb(Vector2(2.94, -4.85), Vector2(2.94, 4.85), [[-0.5, 0.6], [2.4, 3.4]])
	_bb(Vector2(2.94, 4.79), Vector2(-1.14, 4.79), [[-0.6, 0.6]])
	_bb(Vector2(3.06, -4.79), Vector2(5.85, -4.79), [[SV_PANEL_X - 0.41, SV_PANEL_X + 0.41]])
	_bb(Vector2(5.79, -4.85), Vector2(5.79, -3.26))
	_bb(Vector2(5.85, -3.26), Vector2(3.06, -3.26), [[SV_DOOR_X - 0.45, SV_DOOR_X + 0.45]])
	_bb(Vector2(3.06, -3.26), Vector2(3.06, -4.85))
	_bb(Vector2(3.06, -3.14), Vector2(5.85, -3.14), [[SV_DOOR_X - 0.45, SV_DOOR_X + 0.45]])
	_bb(Vector2(5.79, -3.14), Vector2(5.79, 1.84))
	_bb(Vector2(5.85, 1.84), Vector2(3.06, 1.84))
	_bb(Vector2(3.06, 1.84), Vector2(3.06, -3.14), [[-0.5, 0.6]])
	_bb(Vector2(3.06, 1.96), Vector2(5.85, 1.96))
	_bb(Vector2(5.79, 1.96), Vector2(5.79, 4.85))
	_bb(Vector2(5.85, 4.79), Vector2(3.06, 4.79))
	_bb(Vector2(3.06, 4.85), Vector2(3.06, 1.96), [[2.4, 3.4]])

	# Hall lights: one by the front door, one at the north end.
	hall_light = _omni(Vector3(1.0, 2.45, 2.6), Color(0.78, 0.85, 1.0), 0.9, 7.0)
	DK.pendant(self, MFScript, Vector3(1.0, HALL - 0.1, 2.6), Color(0.95, 0.9, 0.82), 0.5, 5.0)
	_omni(Vector3(1.0, 2.45, -2.6), Color(0.85, 0.88, 1.0), 0.6, 6.0)
	DK.pendant(self, MFScript, Vector3(1.0, HALL - 0.1, -2.6), Color(0.95, 0.9, 0.82), 0.4, 4.0)

# ---------------------------------------------------------------- kitchen
func _build_kitchen() -> void:
	# North wall run: fridge | counter (microwave, sink, kettle, cup) | stove
	DK.fridge(self, MFScript, Vector3(-5.45, 0, -4.45), 0.0)
	_fridge_hum = AudioStreamPlayer3D.new()
	_fridge_hum.name = "FridgeHum"
	_fridge_hum.bus = "Ambience"
	_fridge_hum.position = Vector3(-5.45, 1.0, -4.3)
	_fridge_hum.unit_size = 1.2
	_fridge_hum.max_distance = 9.0
	_fridge_hum.volume_db = -14.0
	if ResourceLoader.exists("res://assets/audio/ambience/fridge_loop.wav"):
		var hum: AudioStreamWAV = load("res://assets/audio/ambience/fridge_loop.wav")
		hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum.loop_end = int(hum.get_length() * hum.mix_rate)
		_fridge_hum.stream = hum
		_fridge_hum.autoplay = true
	add_child(_fridge_hum)
	DK.collide(self, Vector3(-5.45, 0.9, -4.45), Vector3(0.7, 1.8, 0.68))
	DK.counter_run(self, MFScript, Vector3(-3.7, 0, -4.52), 2.6)
	DK.collide(self, Vector3(-3.7, 0.46, -4.52), Vector3(2.6, 0.92, 0.66))
	var wt := 0.925
	DK.counter_sink(self, MFScript, Vector3(-3.85, wt, -4.5))
	F.ph(self, "Microwave", Vector3(-4.7, wt, -4.6), 0.0, {"scale": 0.5, "collide": false})
	F.ph(self, "Kettle", Vector3(-3.2, wt, -4.62), -20.0, {"collide": false})
	F.ph(self, "CuttingBoard", Vector3(-2.75, wt, -4.65), 8.0, {"collide": false})
	F.ph(self, "Stove", Vector3(-2.1, 0, -4.52))
	DK.wall_cabinets(self, MFScript, Vector3(-3.7, 1.9, -4.68), 2.6)
	# Ceiling fixture + practical light
	F.ph(self, "CeilingLamp", Vector3(-3.5, HALL - 0.1 - 0.48, -3.0), 0.0, {"floor": false})
	kitchen_light = _omni(Vector3(-3.5, 2.2, -3.0), Color(1.0, 0.84, 0.62), 1.5, 7.5, true)
	DK.radiator(self, MFScript, Vector3(-5.79, 0, -3.55), 90.0)

	# Table with two chairs; the family photo and key lie on it.
	# Table kept clear of the bathroom wall so there is a walkway to the back door.
	var table: Node3D = F.ph(self, "RoundTable", Vector3(-3.3, 0, -3.0), 0.0, {"scale": 0.68})
	var ty: float = F.top(table, 0.69)
	F.ph(self, "DiningChair", Vector3(-4.25, 0, -3.0), 90.0, {"scale": 0.9})
	F.ph(self, "DiningChair", Vector3(-2.35, 0, -3.0), -90.0, {"scale": 0.9})
	F.ph(self, "Bowl", Vector3(-3.52, ty, -3.2), 0.0, {"collide": false})

	# Clues
	DK.cup(self, MFScript, Vector3(-2.95, wt + 0.045, -4.45))
	_interact(Vector3(-2.95, wt + 0.05, -4.45), Vector3(0.14, 0.12, 0.14),
		"Warm tea cup", "A cup still lukewarm. Lipstick mark on the rim. Someone was here minutes ago.",
		"tea_cup", "", "", false)
	_interact(Vector3(-1.65, 1.42, -4.84), Vector3(0.24, 0.3, 0.008),
		"Mother's note", "\"If Noa called, tell her the box was not thrown away. It is where Dad always said there is nothing.\"",
		"mother_note", "")
	DK.photo_flat(self, MFScript, Vector3(-3.1, ty, -2.87), 15.0)
	DK.key_prop(self, MFScript, Vector3(-3.3, ty + 0.01, -2.73), 70.0)
	_interact(Vector3(-3.18, ty + 0.03, -2.81), Vector3(0.36, 0.06, 0.3),
		"Family photo + key", "On the back: 'The evening we counted to three'. In the window reflection a blurred figure. A small key taped behind.",
		"photo_key", "key_found", "", false)

# ---------------------------------------------------------------- bathroom
func _build_bathroom() -> void:
	DK.bathtub2(self, MFScript, Vector3(-5.47, 0, -0.75), 90.0, 1.55)
	DK.collide(self, Vector3(-5.47, 0.3, -0.75), Vector3(0.78, 0.6, 1.59))
	DK.toilet(self, MFScript, Vector3(-4.3, 0, 0.36), 180.0)
	DK.collide(self, Vector3(-4.3, 0.4, 0.36), Vector3(0.44, 0.8, 0.55))
	DK.pedestal_sink(self, MFScript, Vector3(-4.35, 0, -1.3))
	DK.collide(self, Vector3(-4.35, 0.45, -1.3), Vector3(0.48, 0.9, 0.42))
	F.ph(self, "Mirror", Vector3(-4.35, 1.55, -1.54), 0.0, {"floor": false, "wall": Vector3(0, 0, 1)})
	F.ph(self, "PlanterPot", Vector3(-5.6, 0, 0.45), 0.0, {"collide": false})
	_interact(Vector3(-5.0, 1.45, -1.535), Vector3(0.26, 0.34, 0.008),
		"Calendar", "Three dates marked. One erased. The remaining circle matches the storm night.",
		"calendar", "")
	_omni(Vector3(-4.75, 2.5, -0.45), Color(0.85, 0.9, 1.0), 0.7, 4.5)
	DK.pendant(self, MFScript, Vector3(-4.75, HALL - 0.1, -0.45), Color(0.9, 0.92, 1.0), 0.3, 3.0)

# ---------------------------------------------------------------- Noa
func _build_noa_room() -> void:
	# Bed: headboard against the west wall, along the south wall.
	F.ph(self, "Bed_Frame", Vector3(-4.85, 0, 4.2), 90.0)
	DK.bedding(self, MFScript, Vector3(-4.85, 0.44, 4.2), 0.86, 1.9, 90.0)
	var ns: Node3D = F.ph(self, "Nightstand", Vector3(-5.55, 0, 3.3), 90.0)
	var ny: float = F.top(ns, 0.62)
	DK.table_lamp(self, MFScript, Vector3(-5.6, ny, 3.25), Color(0.95, 0.85, 1.0), 1.0, 4.5)
	# Desk + chair under the window side, facing the west wall.
	var desk: Node3D = F.ph(self, "Desk", Vector3(-5.55, 0, 1.6), -90.0)
	var dy: float = F.top(desk, 0.88)
	F.ph(self, "Chair", Vector3(-4.88, 0, 1.6), 90.0)
	# Wardrobe ("closet") and bookshelf against the east wall.
	F.ph(self, "Wardrobe2", Vector3(-1.62, 0, 2.62), -90.0)
	F.ph(self, "Bookshelf_Worn", Vector3(-1.55, 0, 4.06), -90.0)
	F.ph(self, "Suitcase", Vector3(-3.75, 0, 0.98), 0.0, {"scale": 0.85})
	DK.rug(self, MFScript, Vector3(-3.6, 0, 2.7), 1.8, 1.2, Color(0.42, 0.24, 0.22))
	# Posters / photos
	DK.frame(self, MFScript, Vector3(-4.2, 1.75, 0.775), 0.6, 0.8, 0.0, MFScript.flat(Color(0.2, 0.24, 0.3), 0.7))
	DK.frame(self, MFScript, Vector3(-3.3, 1.65, 0.775), 0.5, 0.4, 0.0, MFScript.flat(Color(0.28, 0.22, 0.2), 0.7))
	DK.frame(self, MFScript, Vector3(-5.83, 1.75, 3.9), 0.42, 0.54, 90.0)

	# Clues
	DK.papers(self, MFScript, Vector3(-5.6, dy, 1.75), 80.0, 1)
	_interact(Vector3(-5.6, dy + 0.02, 1.75), Vector3(0.3, 0.04, 0.24),
		"Noa's journal", "\"Tuesday. Mom asked again if I heard the knocking. I said no.\" Pages missing.",
		"noa_journal", "", "", false)
	var cam := HP.build_box(self, Vector3(-5.6, dy + 0.06, 1.4), MFScript)
	cam.scale = Vector3(0.36, 0.4, 0.36)
	_interact(Vector3(-5.6, dy + 0.06, 1.4), Vector3(0.2, 0.14, 0.14),
		"Old camera", "Film still inside. No battery. Noa always finished the roll before she left a place.",
		"camera_old", "", "", false)
	HP.build_box(self, Vector3(-3.6, 0.15, 4.45), MFScript)
	_interact(Vector3(-3.6, 0.2, 4.45), Vector3(0.5, 0.36, 0.36),
		"Tape box (3 empty slots)", "A box with three empty slots. Something was taken out in a hurry.",
		"box_empty", "", "", false)
	_interact(Vector3(-2.0, 1.25, 2.62), Vector3(0.06, 0.4, 0.6),
		"Carving in closet", "Scratched inside the wardrobe: '2:17 / 3 knocks'.",
		"carving", "", "", false)

# ---------------------------------------------------------------- hall / corridor
func _build_hall() -> void:
	# Photo wall (hall face of Noa's wall, x=-1.14, facing +X)
	DK.frame(self, MFScript, Vector3(-1.12, 1.62, 1.45), 0.5, 0.62, 90.0)
	DK.frame(self, MFScript, Vector3(-1.12, 2.02, 2.2), 0.42, 0.54, 90.0)
	DK.box_mi(self, Vector3(-1.135, 1.72, 3.0), Vector3(0.006, 0.46, 0.56), MFScript.plaster())
	DK.box_mi(self, Vector3(-1.135, 1.66, 3.75), Vector3(0.006, 0.4, 0.46), MFScript.plaster())
	_interact(Vector3(-1.12, 1.72, 3.0), Vector3(0.02, 0.28, 0.36),
		"Folded note", "\"He came back, but not through the front door.\" The handwriting stops mid-word.",
		"folded_note", "")
	DK.wall_clock(self, MFScript, Vector3(-1.115, 1.95, 4.35), 90.0)
	_interact(Vector3(-1.08, 1.95, 4.35), Vector3(0.06, 0.34, 0.34),
		"Wall clock", "The hands twitch, then fall back to 02:17.",
		"clock_0217", "", "", false)
	F.ph(self, "KitchenTable", Vector3(-0.81, 0, 2.3), 90.0, {"name": "HallBench"})
	DK.radiator(self, MFScript, Vector3(-1.09, 0, -4.3), 90.0)
	F.ph(self, "WallLamp", Vector3(-1.14, 2.0, -2.0), 90.0, {"floor": false, "wall": Vector3(1, 0, 0)})
	F.ph(self, "PottedPlant2", Vector3(2.45, 0, 4.35))
	DK.rug(self, MFScript, Vector3(0.9, 0, 1.6), 1.0, 4.4, Color(0.3, 0.2, 0.18))
	# Wet envelope slipped under the front door
	DK.papers(self, MFScript, Vector3(0.45, 0.0, 4.5), 20.0, 1)
	_interact(Vector3(0.45, 0.03, 4.5), Vector3(0.26, 0.03, 0.3),
		"Wet envelope", "Your name, in rain-bleed ink. Nothing inside.",
		"envelope", "", "", false)

# ---------------------------------------------------------------- service cabinet + hidden recess
## Service room at the north end of the living room (x 3.06..5.85, z -4.85..-3.2), door
## from the living room. The heavy service cabinet stands against the outer north wall;
## behind it a wooden panel opens onto a recess cut into the wall (the "double wall").
const SV_DOOR_X := 3.6      # door centre in the partition (z -3.2)
const SV_PANEL_X := 5.35      # hidden panel / recess centre in the north wall
const SV_CAB_X := 5.1         # cabinet start (covers the panel)
const SV_CAB_MOVED_X := 3.78  # where it slides to

func _build_service_hidden() -> void:
	_box(self, Vector3(4.455, 0.006, -4.025), Vector3(2.79, 0.012, 1.65), MFScript.concrete(), false)
	var cab := StaticBody3D.new()
	cab.name = "ServiceCabinet"
	cab.position = Vector3(SV_CAB_X, 0, -4.6)
	cab.add_to_group("service_cabinet")
	add_child(cab)
	DK.box_mi(cab, Vector3(0, 1.0, 0), Vector3(1.4, 1.92, 0.5), MFScript.wood_dark())
	DK.box_mi(cab, Vector3(0, 1.98, 0.01), Vector3(1.46, 0.06, 0.54), MFScript.wood_mid())
	DK.box_mi(cab, Vector3(0, 0.04, 0.0), Vector3(1.38, 0.08, 0.46), MFScript.flat(Color(0.1, 0.08, 0.07), 0.9))
	for sx in [-0.345, 0.345]:
		DK.box_mi(cab, Vector3(sx, 1.02, 0.255), Vector3(0.66, 1.8, 0.02), MFScript.wood_mid())
		DK.box_mi(cab, Vector3(sx * 0.12, 1.05, 0.275), Vector3(0.025, 0.22, 0.025), MFScript.metal_dark())
	var ccs := CollisionShape3D.new()
	var csh := BoxShape3D.new()
	csh.size = Vector3(1.4, 2.0, 0.5)
	ccs.shape = csh
	ccs.position = Vector3(0, 1.0, 0)
	cab.add_child(ccs)
	_interact(Vector3(0, 1.3, 0.3), Vector3(0.6, 0.4, 0.04),
		"Service cabinet", "A heavy service cabinet. Dustless tracks on the floor — it has been moved before.",
		"", "cabinet_move", "", false, cab)
	# Drag marks where it has been moved before
	for z in [-4.42, -4.78]:
		DK.box_mi(self, Vector3((SV_CAB_X + SV_CAB_MOVED_X) * 0.5, 0.014, z), Vector3(SV_CAB_X - SV_CAB_MOVED_X + 1.2, 0.003, 0.05), MFScript.flat(Color(0.42, 0.34, 0.27), 1.0))
	# Water heater in the corner by the door, a wall shelf with cleaning things, a bare bulb.
	var heater := Node3D.new()
	heater.name = "WaterHeater"
	heater.position = Vector3(5.55, 0, -3.55)
	add_child(heater)
	DK.cyl_mi(heater, Vector3(0, 0.85, 0), 0.24, 0.24, 1.5, MFScript.paint_metal(), 18)
	DK.cyl_mi(heater, Vector3(0, 1.62, 0), 0.2, 0.24, 0.06, MFScript.paint_metal(), 18)
	DK.cyl_mi(heater, Vector3(-0.08, 2.2, 0), 0.025, 0.025, 1.1, MFScript.metal_dark(), 8)
	DK.cyl_mi(heater, Vector3(0.08, 2.2, 0), 0.025, 0.025, 1.1, MFScript.metal_dark(), 8)
	DK.box_mi(heater, Vector3(0, 0.55, 0.24), Vector3(0.12, 0.08, 0.02), MFScript.metal_dark())
	DK.collide(self, Vector3(5.55, 0.8, -3.55), Vector3(0.5, 1.6, 0.5))
	var shelf_mat: Material = MFScript.wood_mid()
	DK.box_mi(self, Vector3(4.55, 1.65, -3.39), Vector3(0.9, 0.03, 0.22), shelf_mat)
	for i in 5:
		var c := DK.cyl_mi(self, Vector3(4.2 + float(i) * 0.17, 1.75, -3.39), 0.045, 0.05, 0.17,
			MFScript.flat([Color(0.7, 0.2, 0.2), Color(0.85, 0.85, 0.8), Color(0.2, 0.4, 0.7), Color(0.5, 0.6, 0.3), Color(0.8, 0.7, 0.3)][i], 0.5), 10)
		c.name = "Jar"
	DK.box_mi(self, Vector3(3.09, 1.7, -3.9), Vector3(0.06, 0.4, 0.3), MFScript.paint_metal())   # fuse box
	F.ph(self, "PullChainLight", Vector3(4.4, HALL - 0.1 - 0.085, -4.0), 0.0, {"floor": false})
	DK.sphere_mi(self, Vector3(4.4, HALL - 0.32, -4.0), 0.05, MFScript.emissive(Color(1.0, 0.82, 0.6), 1.2), 10)
	_omni(Vector3(4.4, 2.45, -4.0), Color(1.0, 0.82, 0.6), 0.7, 4.5)

	# Recess behind the cabinet (hole cut in the north wall, y 0..1.52)
	var px: float = SV_PANEL_X
	var lining: Material = MFScript.wood_dark()
	_box(self, Vector3(px, 0.76, -5.2), Vector3(0.82, 1.52, 0.1), lining)
	DK.box_mi(self, Vector3(px - 0.4, 0.76, -5.0), Vector3(0.02, 1.52, 0.3), lining)
	DK.box_mi(self, Vector3(px + 0.4, 0.76, -5.0), Vector3(0.02, 1.52, 0.3), lining)
	DK.box_mi(self, Vector3(px, 1.51, -5.0), Vector3(0.82, 0.02, 0.3), lining)
	DK.box_mi(self, Vector3(px, 0.55, -5.03), Vector3(0.78, 0.03, 0.24), MFScript.wood_mid())
	DK.box_mi(self, Vector3(px, 1.1, -5.145), Vector3(0.3, 0.22, 0.004), MFScript.paper())
	_interact(Vector3(px, 1.1, -5.12), Vector3(0.3, 0.22, 0.04),
		"Miriam's hidden letter", "\"There are three knocks in this story, but not every one was heard on the same night. — Mom\"",
		"miriam_letter", "hidden_open", "", false)
	DK.cassette(self, MFScript, Vector3(px - 0.12, 0.565, -5.02), 10.0)
	_interact(Vector3(px - 0.12, 0.6, -5.02), Vector3(0.14, 0.06, 0.1),
		"Last tape", "A sealed tape, labeled in pencil: 'do not rewind'.",
		"last_tape", "knocks_wall", "last_tape", false)
	# The sealed box (brief ch6) on the recess floor
	var box := HP.build_box(self, Vector3(px + 0.1, 0.13, -5.02), MFScript)
	box.scale = Vector3(0.6, 0.7, 0.6)
	DK.box_mi(self, Vector3(px + 0.1, 0.25, -4.91), Vector3(0.04, 0.05, 0.01), MFScript.metal_dark())

# ---------------------------------------------------------------- living
## Living room (x 3.06..5.85, z -3.14..1.84). TV on the service-room wall, sofa facing
## it, coffee table between them with a 1 m walkway on the west side (door side) so the
## player can walk right up to the table; the service-room door stays clear.
func _build_living() -> void:
	var console: Node3D = F.ph(self, "Console", Vector3(4.98, 0, -2.85), 0.0)
	var top_c: float = F.top(console, 0.95)
	F.ph(self, "Television_01", Vector3(4.98, top_c, -2.88), 0.0, {"collide": false})
	DK.table_lamp(self, MFScript, Vector3(5.5, top_c, -2.85), Color(1.0, 0.82, 0.6), 1.1, 5.0)
	F.ph(self, "PottedPlant", Vector3(4.42, top_c, -2.85), 0.0, {"collide": false, "name": "Decor_Plant"})
	F.ph(self, "Sofa_01", Vector3(4.85, 0, -0.6), 180.0)
	F.ph(self, "ThrowPillows", Vector3(4.85, 0.42, -0.52), 180.0, {"scale": 0.8, "collide": false, "name": "Decor_SofaPillows"})
	var ct: Node3D = F.ph(self, "SmallTable", Vector3(4.5, 0, -1.75), 0.0)
	var cy: float = F.top(ct, 0.53)
	F.ph(self, "ArmChair_01", Vector3(5.42, 0, -2.05), -90.0)
	F.ph(self, "VintageCabinet", Vector3(4.61, 0, 1.5), 180.0)
	F.ph(self, "Shelf_01", Vector3(5.72, 0, 0.3), -90.0)
	DK.rug(self, MFScript, Vector3(4.5, 0, -1.6), 2.2, 1.7, Color(0.34, 0.2, 0.16))
	DK.radiator(self, MFScript, Vector3(5.79, 0, -0.9), -90.0)
	DK.frame(self, MFScript, Vector3(5.83, 1.7, 1.25), 0.6, 0.5, -90.0, MFScript.flat(Color(0.16, 0.16, 0.18), 0.7))
	_omni(Vector3(4.5, 2.5, -1.0), Color(1.0, 0.86, 0.7), 0.35, 5.0)
	# Clues on the coffee table: Noa's tape, and the "three versions" spread
	_table_items["tape"] = DK.cassette(self, MFScript, Vector3(4.23, cy, -1.77), -15.0)
	_table_items["tape_clue"] = _interact(Vector3(4.23, cy + 0.02, -1.77), Vector3(0.14, 0.04, 0.12),
		"Noa's tape 1", "A cassette with no label but a date: two weeks ago.",
		"tape1_living", "tape1", "tape1_living", false)
	_table_items["tape1"] = _table_items["tape"]
	_table_items["photo"] = DK.photo_flat(self, MFScript, Vector3(4.55, cy, -1.7), -6.0)
	_table_items["letter"] = DK.papers(self, MFScript, Vector3(4.78, cy, -1.77), 12.0, 1)
	# "the recording": the storm-night recorder, placed on the table once found
	_table_items["tape"] = F.ph(self, "Cassette", Vector3(4.4, cy, -1.9), 160.0, {"collide": false, "name": "TableRecorder"})
	_table_items["centre"] = Vector3(4.5, cy, -1.75)
	_table_items["versions"] = _interact(Vector3(4.67, cy + 0.02, -1.75), Vector3(0.42, 0.04, 0.3),
		"Three versions table", "Photo, tape, letter side by side. Time to choose what you can live with.",
		"versions_table", "show_endings", "", false)

# ---------------------------------------------------------------- study
func _build_study() -> void:
	var desk: Node3D = F.ph(self, "OfficeDesk", Vector3(5.38, 0, 3.4), -90.0)
	var dy: float = F.top(desk, 0.79)
	F.ph(self, "WoodenChair", Vector3(4.55, 0, 3.4), 90.0)
	F.ph(self, "DeskLamp", Vector3(5.5, dy, 4.2), -90.0, {"collide": false})
	F.ph(self, "Cassette", Vector3(5.3, dy, 2.75), -110.0, {"collide": false})
	F.ph(self, "Bookshelf_Worn", Vector3(4.1, 0, 4.56), 180.0)
	var crate: Node3D = F.ph(self, "WoodenCrate", Vector3(4.75, 0, 2.2), 0.0)
	_study_lamp = _omni(Vector3(5.45, 1.25, 4.0), Color(0.95, 1.0, 0.72), 1.6, 5.0)
	# Wall plan above the desk
	DK.box_mi(self, Vector3(5.845, 1.6, 3.4), Vector3(0.006, 0.4, 0.56), MFScript.paper())
	_interact(Vector3(5.83, 1.6, 3.4), Vector3(0.02, 0.4, 0.56),
		"Marked house plan", "Yoav's handwriting. One room circled twice: behind the service cabinet.",
		"house_plan", "", "", false)
	DK.papers(self, MFScript, Vector3(5.3, dy, 3.3), 95.0, 1)
	_interact(Vector3(5.3, dy + 0.02, 3.3), Vector3(0.28, 0.04, 0.22),
		"Yoav's note", "\"Fix the back lock. Do not replace the door. It was not broken from the outside.\"",
		"yoav_note", "", "", false)
	DK.papers(self, MFScript, Vector3(5.3, dy, 3.72), 75.0, 2)
	_interact(Vector3(5.3, dy + 0.02, 3.72), Vector3(0.28, 0.04, 0.22),
		"Back-door repair order", "Ordered the week of the storm. 'Rear lock reset. Door not forced from outside.' Paid cash.",
		"repair_doc", "", "", false)
	var cy: float = F.top(crate, 0.35)
	DK.papers(self, MFScript, Vector3(4.75, cy, 2.2), 0.0, 3)
	_interact(Vector3(4.75, cy + 0.03, 2.2), Vector3(0.4, 0.06, 0.3),
		"Bills and envelopes", "Unpaid, unsent, unopened. The house kept billing a life that had already paused.",
		"bills", "", "", false)
	DK.cassette(self, MFScript, Vector3(5.12, dy, 2.95), 20.0)
	DK.cassette(self, MFScript, Vector3(5.2, dy, 3.0), -5.0)
	_interact(Vector3(5.16, dy + 0.02, 2.98), Vector3(0.18, 0.04, 0.14),
		"Short tapes (2/3)", "[Static] Argument far away, storm, three knocks, long silence. Second tape is missing.",
		"tapes_study", "study_tapes", "study_tapes", false)

# ---------------------------------------------------------------- outside
func _ground(x0: float, x1: float, z0: float, z1: float, mat: Material) -> void:
	_box(self, Vector3((x0 + x1) * 0.5, -0.15, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.3, z1 - z0), mat)

func _build_outside() -> void:
	var g: Material = MFScript.grass()
	# Ground around the house (the basement is under the house now).
	_ground(-30, 30, -25, -5.15, g)
	_ground(-30, -6.15, -5.15, 30, g)
	_ground(6.15, 30, -5.15, 30, g)
	_ground(-6.15, 6.15, 5.15, 30, g)
	# Porch, doormat and path to the gate
	_box(self, Vector3(0, 0.06, 5.5), Vector3(1.4, 0.12, 0.7), MFScript.concrete())
	_box(self, Vector3(0, 0.125, 5.5), Vector3(0.9, 0.01, 0.5), MFScript.flat(Color(0.2, 0.16, 0.13), 0.95), false)
	_box(self, Vector3(0, 0.01, 9.125), Vector3(1.2, 0.02, 6.55), MFScript.concrete(), false)
	# Wall lantern by the door
	F.ph(self, "StreetLamp", Vector3(1.02, 2.05, 5.15), 0.0, {"floor": false, "wall": Vector3(0, 0, 1), "scale": 0.55, "name": "PorchLantern"})
	_omni(Vector3(1.02, 1.85, 5.5), Color(1.0, 0.72, 0.42), 0.8, 4.0)
	F.ph(self, "Fern", Vector3(-1.9, 0, 6.3))
	# Street lamp at the gate
	var lamp := Node3D.new()
	lamp.name = "StreetLight"
	lamp.position = Vector3(3.2, 0, 12.0)
	add_child(lamp)
	DK.cyl_mi(lamp, Vector3(0, 1.7, 0), 0.06, 0.09, 3.4, MFScript.metal_dark(), 10)
	DK.box_mi(lamp, Vector3(-0.25, 3.4, 0), Vector3(0.7, 0.09, 0.09), MFScript.metal_dark())
	DK.box_mi(lamp, Vector3(-0.55, 3.28, 0), Vector3(0.34, 0.2, 0.26), MFScript.emissive(Color(1.0, 0.72, 0.42), 1.6))
	var sl := SpotLight3D.new()
	_street_spot = sl
	sl.position = Vector3(2.65, 3.2, 12.0)
	sl.rotation_degrees = Vector3(-90, 0, 0)
	sl.light_color = Color(1.0, 0.74, 0.45)
	sl.light_energy = 2.6
	sl.spot_range = 9.0
	sl.spot_angle = 55.0
	sl.shadow_enabled = true
	_shadow_lights.append(sl)
	add_child(sl)
	# Fence along the street with a gate in line with the path
	var wd: Material = MFScript.wood_dark()
	for i in 11:
		var x: float = -6.0 + float(i) * 1.2
		if absf(x) < 0.7:
			continue
		DK.box_mi(self, Vector3(x, 0.5, 12.4), Vector3(0.1, 1.0, 0.1), wd)
	for y in [0.5, 0.85]:
		DK.box_mi(self, Vector3(-3.35, y, 12.4), Vector3(5.3, 0.08, 0.06), wd)
		DK.box_mi(self, Vector3(3.35, y, 12.4), Vector3(5.3, 0.08, 0.06), wd)
	DK.collide(self, Vector3(-3.35, 0.55, 12.4), Vector3(5.3, 1.1, 0.12))
	DK.collide(self, Vector3(3.35, 0.55, 12.4), Vector3(5.3, 1.1, 0.12))
	DK.box_mi(self, Vector3(-0.66, 0.95, 12.4), Vector3(0.12, 1.9, 0.12), wd)
	DK.box_mi(self, Vector3(0.66, 0.95, 12.4), Vector3(0.12, 1.9, 0.12), wd)
	for i in 4:
		DK.box_mi(self, Vector3(0, 0.35 + float(i) * 0.25, 12.4), Vector3(1.18, 0.14, 0.04), wd)
	_interact(Vector3(0, 0.75, 12.4), Vector3(1.1, 0.9, 0.06),
		"Garden gate", "It creaks exactly the way gates creak in the town you tried to forget.",
		"gate", "gate_creak", "", false)
	# Mailbox
	DK.box_mi(self, Vector3(-1.3, 0.7, 12.0), Vector3(0.1, 1.4, 0.1), wd)
	DK.box_mi(self, Vector3(-1.3, 1.45, 12.0), Vector3(0.3, 0.24, 0.22), MFScript.metal_dark())
	# Wet tree
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = Vector3(-4.3, 0, 9.0)
	add_child(tree)
	DK.cyl_mi(tree, Vector3(0, 1.3, 0), 0.14, 0.2, 2.6, MFScript.wood_dark(), 8)
	var bark: StandardMaterial3D = MFScript.flat(Color(0.2, 0.26, 0.14), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var a: float = rng.randf() * TAU
		var rad: float = rng.randf_range(0.3, 0.9)
		DK.sphere_mi(tree, Vector3(cos(a) * rad, 2.5 + rng.randf() * 0.8, sin(a) * rad), rng.randf_range(0.35, 0.6), bark, 10)
	for i in 3:
		var pd := DK.cyl_mi(self, Vector3(-3.0 + float(i) * 1.4, 0.006, 7.5 + float(i) * 1.1), rng.randf_range(0.4, 0.7), rng.randf_range(0.4, 0.7), 0.004, MFScript.flat(Color(0.1, 0.13, 0.18), 0.06, 0.6), 12)
		pd.name = "Puddle"
	rain = GPUParticles3D.new()
	rain.position = Vector3(0, 9.5, 2.0)
	rain.amount = 1400
	rain.lifetime = 1.3
	rain.collision_base_size = 0.02
	rain.visibility_aabb = AABB(Vector3(-14, -11, -14), Vector3(28, 12, 28))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(13, 0.2, 13)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.direction = Vector3(0.05, -1, 0)
	pm.spread = 4.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0.4, -4.0, 0)
	pm.scale_min = 0.02
	pm.scale_max = 0.035
	rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.02, 0.5)
	rain.draw_pass_1 = qm
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.7, 0.78, 0.9, 0.35)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop_mat.billboard_keep_scale = true
	qm.material = drop_mat
	rain.add_to_group("rain")
	add_child(rain)
	for c in [[Vector3(0, 4.6, 0), Vector3(12.9, 9.4, 10.9)], [Vector3(0, -0.6, 2.0), Vector3(60, 1.0, 60)]]:
		var col := GPUParticlesCollisionBox3D.new()
		col.position = c[0]
		col.size = c[1]
		add_child(col)

# ---------------------------------------------------------------- basement
## Under the living room and the study (x 2.15..5.85, z -0.3..4.85, floor at BF).
## Reached through the door under the main stairs: a straight flight runs south under
## flight 1 (x BS_X0..BS_X1, z BS_Z_TOP -> -0.3) and arrives in the room's north-west corner.
func _build_basement() -> void:
	var conc: Material = MFScript.concrete()
	var wy: float = (BF - 0.3 - 0.2) * 0.5        # walls from below the floor up to the slab (-0.2)
	var wh: float = -0.2 - (BF - 0.3)
	_box(self, Vector3(3.99, BF - 0.15, 0.55), Vector3(4.23, 0.3, 9.1), conc)            # floor
	_box(self, Vector3(2.0125, wy, 0.42), Vector3(0.275, wh, 8.85), conc)                  # west
	_box(self, Vector3(3.07, wy, -2.275), Vector3(0.26, wh, 3.95), conc)                   # stairwell east
	_box(self, Vector3(2.545, wy, -4.125), Vector3(1.1, wh, 0.25), conc)                   # stairwell end
	_box(self, Vector3(4.52, wy, -0.425), Vector3(3.16, wh, 0.25), conc)                   # room north
	_box(self, Vector3(5.975, wy, 2.275), Vector3(0.25, wh, 5.65), conc)                   # room east
	_box(self, Vector3(3.99, wy, 4.975), Vector3(4.23, wh, 0.25), conc)                    # room south
	# Ceiling joists under the floorboards
	for i in 6:
		DK.box_mi(self, Vector3(2.45 + float(i) * 0.6, -0.29, 2.27), Vector3(0.08, 0.18, 5.15), MFScript.wood_dark())
	# Stairs down: 13 risers of 0.2 m, visual blocks + one smooth ramp through the back edges
	var bx: float = (BS_X0 + BS_X1) * 0.5
	for k in 12:
		var top: float = -0.2 * float(k + 1)
		var z0: float = BS_Z_TOP + BS_RUN * float(k)
		DK.box_mi(self, Vector3(bx, (top + BF) * 0.5, z0 + BS_RUN * 0.5), Vector3(BS_X1 - BS_X0, top - BF, BS_RUN), conc)
		DK.box_mi(self, Vector3(bx, top - 0.015, z0 + BS_RUN * 0.5 - 0.012), Vector3(BS_X1 - BS_X0, 0.03, BS_RUN + 0.024), MFScript.wood_mid())
	_along(Vector3(bx, 0.0, BS_Z_TOP), Vector3(bx, BF, BS_Z_TOP + BS_RUN * 13.0), BS_X1 - BS_X0, 0.2, 0.0, null, true, false)
	_along(Vector3(BS_X1 - 0.06, 0.0, BS_Z_TOP), Vector3(BS_X1 - 0.06, BF, BS_Z_TOP + BS_RUN * 13.0), 0.04, 0.05, 0.9, MFScript.wood_dark(), false)
	DK.box_mi(self, Vector3(bx, BF + 0.45, 4.84), Vector3(3.6, 0.1, 0.01), MFScript.flat(Color(0.3, 0.29, 0.24), 0.98))   # flood line
	DK.box_mi(self, Vector3(5.84, BF + 0.45, 2.27), Vector3(0.01, 0.1, 5.1), MFScript.flat(Color(0.3, 0.29, 0.24), 0.98))
	var pipe := DK.cyl_mi(self, Vector3(4.0, -0.48, 4.6), 0.05, 0.05, 3.6, MFScript.metal_dark(), 8)
	pipe.rotation_degrees.z = 90.0

	# Contents: furnace + barrel in the far corner, shelving on the east wall, storage on the
	# south wall, the crate with Noa's note under the main bulb, the recorder on a stool
	# just off the foot of the stairs (the first thing you see coming down).
	F.ph(self, "BarrelStove", Vector3(5.4, BF, 0.1))
	F.ph(self, "Barrel", Vector3(5.4, BF, 0.95), 20.0)
	F.ph(self, "SteelShelves", Vector3(5.6, BF, 2.55), -90.0, {"scale": 0.1})
	DK.storage_shelf(self, MFScript, Vector3(4.4, BF, 4.62), 180.0, 3)
	DK.collide(self, Vector3(4.4, BF + 0.75, 4.62), Vector3(1.15, 1.5, 0.42))
	F.ph(self, "WoodenCrate", Vector3(3.1, BF, 4.62), 0.0)
	F.ph(self, "CardboardBox", Vector3(5.45, BF, 4.4), 22.0)
	F.ph(self, "Crate2", Vector3(2.45, BF, 3.4), 0.0)
	DK.pump(self, MFScript, Vector3(2.55, BF, 4.45))
	var crate: Node3D = F.ph(self, "Crate2", Vector3(4.05, BF, 2.2), 90.0, {"name": "NoteCrate"})
	var stool: Node3D = F.ph(self, "Stool", Vector3(3.75, BF, 0.95), 0.0)
	# Clues
	var ny: float = F.top(crate, BF + 0.46)
	DK.papers(self, MFScript, Vector3(4.05, ny, 2.2), 30.0, 1)
	_interact(Vector3(4.05, ny + 0.02, 2.2), Vector3(0.3, 0.04, 0.3),
		"Noa's farewell note", "\"I left before you arrived. You have to see it yourself. Choose what you can live with. — Noa\"",
		"noa_farewell", "basement_tape", "", false)
	var sy: float = F.top(stool, BF + 0.44)
	F.ph(self, "Cassette", Vector3(3.75, sy, 0.95), 30.0, {"collide": false, "name": "StormRecorder"})
	_interact(Vector3(3.75, sy + 0.07, 0.95), Vector3(0.2, 0.14, 0.12),
		"Storm-night recorder", "The counter stopped mid-tape. Someone pressed play and never came back to stop it.",
		"storm_tape", "storm_play", "storm_full", false)
	# Practical lights: bare bulbs hanging from the joists
	F.ph(self, "PullChainLight", Vector3(4.05, -0.2 - 0.085, 2.2), 0.0, {"floor": false})
	DK.sphere_mi(self, Vector3(4.05, -0.42, 2.2), 0.05, MFScript.emissive(Color(0.75, 0.85, 1.0), 1.2), 10)
	_omni(Vector3(4.05, -0.55, 2.2), Color(0.6, 0.74, 1.0), 1.1, 7.0, true)
	F.ph(self, "PullChainLight", Vector3(3.0, -0.2 - 0.085, 0.3), 0.0, {"floor": false})
	DK.sphere_mi(self, Vector3(3.0, -0.42, 0.3), 0.05, MFScript.emissive(Color(1.0, 0.8, 0.55), 1.2), 10)
	_omni(Vector3(3.0, -0.55, 0.3), Color(1.0, 0.8, 0.55), 1.0, 5.0)

# ---------------------------------------------------------------- upper floor + roof
## A box whose top edge runs along the line a->b (a sloped ramp, rail or banister).
## width is across the run, thickness is below the line, `lift` raises the top edge.
func _along(a: Vector3, b: Vector3, width: float, thickness: float, lift: float, mat: Material, collide: bool, visible: bool = true) -> void:
	var dir: Vector3 = b - a
	var basis := Basis.looking_at(dir.normalized(), Vector3.UP)
	# `lift` is vertical (a banister stands straight up from the stair line); the box
	# hangs below that point by half its thickness along its own up axis.
	var center: Vector3 = (a + b) * 0.5 + Vector3.UP * lift - basis.y * (thickness * 0.5)
	var size := Vector3(width, thickness, dir.length())
	if visible:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.transform = Transform3D(basis, center)
		add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.transform = Transform3D(basis, center)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size + Vector3(0, 0, 0.1)
		cs.shape = sh
		body.add_child(cs)
		body.add_to_group("structure")
		add_child(body)

# ---------------------------------------------------------------- stairs (hall -> upper landing)
## L-shaped stair in the north-east corner of the hall:
##   flight 1 runs north along the hall's east wall (x 2.12..2.94, z -0.75 -> -4.0, up to 2.8),
##   a corner landing (z -4.0..-4.85), flight 2 turns west along the north wall
##   (x 2.12 -> 1.12, up to the upper floor at 3.5).
## Built like a real closed-string stair: plastered spandrel underneath (one continuous
## world-mapped texture, no seams), painted risers, wooden treads with a nosing, a
## sloped stringer board and a handrail with balusters on the open side.
const ST_X0 := 2.12
const ST_X1 := 2.94
const ST_W := 0.82
const ST_ZB := -0.75
const ST_ZL := -4.0
const ST_LAND := 2.8
const ST_THICK := 0.25        # flight 1 is a floating flight this thick (basement stairs run under it)
## Basement door in the spandrel (hall side of flight 1) and the stairwell behind it.
const BS_X0 := 2.15           # stairwell between the spandrel ...
const BS_X1 := 2.94           # ... and the living-room wall
const BS_DOOR_Z0 := -4.0
const BS_DOOR_Z1 := -3.071
const BS_DOOR_H := 1.95
const BS_Z_TOP := -3.55       # first basement step
const BS_RUN := 0.25

## Invisible guard along a stair's open side: short upright boxes following the stair
## line (a single tilted box would poke its corners out past the ends of the flight).
func _banister(a: Vector3, b: Vector3) -> void:
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var n: int = maxi(2, int(ceil(flat.length() / 0.25)))
	var seg: float = flat.length() / float(n)
	var along_x: bool = absf(flat.x) > absf(flat.y)
	for k in n:
		var p: Vector3 = a.lerp(b, (float(k) + 0.5) / float(n))
		var size := Vector3(seg, 1.1, 0.06) if along_x else Vector3(0.06, 1.1, seg)
		DK.collide(self, p + Vector3(0, 0.55, 0), size).add_to_group("structure")

## One step: the visible block stops 3.5 cm short (the tread board sits on top), but the
## collider goes to the full step height so walking surfaces stay flush (no lips).
func _step_block(base: Vector3, size: Vector3, mat: Material) -> void:
	DK.box_mi(self, base + Vector3(0, (size.y - 0.035) * 0.5, 0), Vector3(size.x, size.y - 0.035, size.z), mat)
	DK.collide(self, base + Vector3(0, size.y * 0.5, 0), size).add_to_group("structure")

func _build_stairs() -> void:
	var tread: Material = MFScript.stair_tread()
	var riser: Material = MFScript.stair_riser()
	var side: Material = MFScript.stair_side()
	var trim: Material = MFScript.wood_trim()
	var cx: float = (ST_X0 + ST_X1) * 0.5
	var fl := UPPER_Y + 0.1
	var rise1: float = ST_LAND / 14.0
	var run1: float = (ST_ZB - ST_ZL) / 14.0
	# Flight 1 (climbs towards -Z; the front of each step faces +Z)
	for i in 14:
		var top: float = rise1 * float(i + 1)
		var z0: float = ST_ZB - run1 * float(i)
		var zc: float = z0 - run1 * 0.5
		_step_block(Vector3(cx, top - ST_THICK, zc), Vector3(ST_W, ST_THICK, run1), side)
		# Spandrel (closes the space under the flight on the hall side), open at the door.
		var st_top: float = top - ST_THICK
		var st_bot: float = BS_DOOR_H if (zc > BS_DOOR_Z0 and zc < BS_DOOR_Z1) else 0.0
		if st_top > st_bot + 0.01:
			DK.box_mi(self, Vector3(ST_X0 + 0.015, (st_bot + st_top) * 0.5, zc), Vector3(0.03, st_top - st_bot, run1), side)
			DK.collide(self, Vector3(ST_X0 + 0.015, (st_bot + st_top) * 0.5, zc), Vector3(0.03, st_top - st_bot, run1)).add_to_group("structure")
		DK.box_mi(self, Vector3(cx, top - rise1 * 0.5 - 0.0175, z0 - 0.008), Vector3(ST_W, rise1 - 0.035, 0.016), riser)
		DK.box_mi(self, Vector3(cx - 0.015, top - 0.0175, z0 - run1 * 0.5 + 0.015), Vector3(ST_W + 0.03, 0.035, run1 + 0.03), tread)
	# Corner landing
	var lz: float = (ST_ZL - 4.85) * 0.5
	_step_block(Vector3(cx, 0.0, lz), Vector3(ST_W, ST_LAND, 4.85 + ST_ZL), side)
	DK.box_mi(self, Vector3(cx - 0.015, ST_LAND - 0.0175, lz + 0.015), Vector3(ST_W + 0.03, 0.035, 4.85 + ST_ZL + 0.03), tread)
	# Flight 2 (climbs towards -X; fronts face +X), solid down to the floor
	var rise2: float = (fl - ST_LAND) / 4.0
	for j in 4:
		var top2: float = ST_LAND + rise2 * float(j + 1)
		var x0: float = ST_X0 - 0.25 * float(j)
		_step_block(Vector3(x0 - 0.125, 0.0, lz), Vector3(0.25, top2, ST_W), side)
		DK.box_mi(self, Vector3(x0 - 0.008, top2 - rise2 * 0.5 - 0.0175, lz), Vector3(0.016, rise2 - 0.035, ST_W), riser)
		DK.box_mi(self, Vector3(x0 - 0.11, top2 - 0.0175, lz + 0.015), Vector3(0.28, 0.035, ST_W + 0.03), tread)
	# Walkable ramps through the step nosings (front-top edges), so the solid step
	# colliders never stick out above them; each starts flush with the level below and
	# ends on the last tread, which is flush with the level above.
	_along(Vector3(cx, 0.0, ST_ZB + run1), Vector3(cx, ST_LAND, ST_ZL + run1), ST_W, 0.2, 0.0, null, true, false)
	_along(Vector3(ST_X0 + 0.25, ST_LAND, lz), Vector3(ST_X0 - 0.75, fl, lz), ST_W, 0.2, 0.0, null, true, false)
	# Stringer boards along the open sides, following the nosing line
	var nose := func(z: float) -> float: return ST_LAND * ((ST_ZB + run1) - z) / (ST_ZB - ST_ZL)
	_along(Vector3(ST_X0 - 0.03, 0.0, ST_ZB + run1), Vector3(ST_X0 - 0.03, ST_LAND, ST_ZL + run1), 0.04, 0.3, 0.07, trim, false)
	_along(Vector3(ST_X0 + 0.25, ST_LAND, -4.0 + 0.0), Vector3(ST_X0 - 0.75, fl, -4.0), 0.04, 0.3, 0.07, trim, false)
	# Handrail, balusters (two per step) and newel posts on flight 1's open side
	_along(Vector3(ST_X0 - 0.03, nose.call(ST_ZB), ST_ZB), Vector3(ST_X0 - 0.03, ST_LAND, ST_ZL + run1), 0.06, 0.06, 0.95, trim, false)
	_banister(Vector3(ST_X0 - 0.03, nose.call(ST_ZB - 0.6), ST_ZB - 0.6), Vector3(ST_X0 - 0.03, ST_LAND, ST_ZL + run1 + 0.05))
	for k in 26:
		var zz: float = lerpf(ST_ZB - 0.15, ST_ZL + run1, (float(k) + 0.5) / 26.0)
		DK.box_mi(self, Vector3(ST_X0 - 0.03, nose.call(zz) + 0.47, zz), Vector3(0.028, 0.92, 0.028), trim)
	DK.box_mi(self, Vector3(ST_X0 - 0.03, 0.55, ST_ZB - 0.05), Vector3(0.1, 1.1, 0.1), trim)
	DK.box_mi(self, Vector3(ST_X0 - 0.03, 0.03 + 1.1, ST_ZB - 0.05), Vector3(0.13, 0.06, 0.13), trim)
	DK.box_mi(self, Vector3(ST_X0 - 0.03, ST_LAND + 0.5, ST_ZL + 0.02), Vector3(0.1, 1.0, 0.1), trim)
	DK.doorway_trim(self, MFScript, Vector3(ST_X0 + 0.015, 0, (BS_DOOR_Z0 + BS_DOOR_Z1) * 0.5), BS_DOOR_Z1 - BS_DOOR_Z0 - 0.04, BS_DOOR_H, 0.03, 90.0)
	# Flight 2's open side (towards the hall): handrail + banister
	var n2 := func(x: float) -> float: return ST_LAND + (fl - ST_LAND) * (ST_X0 + 0.25 - x) / 1.0
	_along(Vector3(ST_X0, ST_LAND, -4.0), Vector3(ST_X0 - 0.75, fl, -4.0), 0.06, 0.06, 0.95, trim, false)
	_banister(Vector3(ST_X0 - 0.05, ST_LAND + 0.03, -3.98), Vector3(ST_X0 - 0.75, fl, -3.98))
	for k in 6:
		var xx: float = lerpf(ST_X0, ST_X0 - 0.75, (float(k) + 0.5) / 6.0)
		DK.box_mi(self, Vector3(xx, n2.call(xx) + 0.47, -4.0), Vector3(0.028, 0.92, 0.028), trim)

# ---------------------------------------------------------------- upper floor + roof
func _build_upper_floor() -> void:
	var y: float = UPPER_Y
	var fl: float = y + 0.1          # walking surface upstairs
	var ext: Material = MFScript.exterior()
	var inner: Material = MFScript.plaster_cold()
	var top: float = 6.0
	# Floor/ceiling sandwich between the storeys, with the stairwell cut out:
	# hole A over flight 1 (x 2.12..2.94, z -4.85..-1.5), hole B over flight 2 (x 1.12..2.12, z -4.85..-3.95).
	for r in [[-6.15, 1.12, -5.15, 5.15], [1.12, 2.12, -3.95, 5.15], [2.12, 2.94, -1.5, 5.15], [2.94, 6.15, -5.15, 5.15]]:
		var cxp: float = (float(r[0]) + float(r[1])) * 0.5
		var czp: float = (float(r[2]) + float(r[3])) * 0.5
		var sx: float = float(r[1]) - float(r[0])
		var sz: float = float(r[3]) - float(r[2])
		_box(self, Vector3(cxp, HALL + 0.1, czp), Vector3(sx, 0.4, sz), MFScript.ceiling(), false)
		_box(self, Vector3(cxp, y, czp), Vector3(sx, 0.2, sz), MFScript.wood_floor())
	# Upper-storey shell (y 3.0..6.0) with windows, so the house reads from outside.
	_wall(Vector2(-6.15, -5), Vector2(6.15, -5), T_OUT, inner, ext, [[-3.6, -2.4, 4.3, 5.5], [0.6, 1.8, 4.3, 5.5], [3.6, 4.8, 4.3, 5.5]], HALL, top)
	_wall(Vector2(-6.15, 5), Vector2(6.15, 5), T_OUT, ext, inner, [[-3.6, -2.4, 4.3, 5.5], [0.4, 1.6, 4.3, 5.5], [3.6, 4.8, 4.3, 5.5]], HALL, top)
	_wall(Vector2(-6, -4.85), Vector2(-6, 4.85), T_OUT, inner, ext, [[-3.1, -1.9, 4.3, 5.5], [0.6, 1.8, 4.3, 5.5]], HALL, top)
	_wall(Vector2(6, -4.85), Vector2(6, 4.85), T_OUT, ext, inner, [[-3.1, -1.9, 4.3, 5.5]], HALL, top)
	for p in [Vector3(-3.0, 4.9, -5.0), Vector3(4.2, 4.9, -5.0), Vector3(-3.0, 4.9, 5.0), Vector3(1.0, 4.9, 5.0), Vector3(4.2, 4.9, 5.0)]:
		DK.window_in_wall(self, MFScript, p, 1.2, 1.2, T_OUT)
	DK.window_in_wall(self, MFScript, Vector3(-6.0, 4.9, -2.5), 1.2, 1.2, T_OUT, 90.0)
	DK.window_in_wall(self, MFScript, Vector3(-6.0, 4.9, 1.2), 1.2, 1.2, T_OUT, 90.0)
	DK.window_in_wall(self, MFScript, Vector3(6.0, 4.9, -2.5), 1.2, 1.2, T_OUT, 90.0)
	for z in [-5.17, 5.17]:
		DK.box_mi(self, Vector3(0, HALL + 0.2, z), Vector3(12.4, 0.12, 0.05), MFScript.wood_trim())
	# Attic floor / upper ceiling + gable roof (ridge along X)
	_box(self, Vector3(0, top + 0.05, 0), Vector3(12.3, 0.1, 10.3), MFScript.ceiling(), false)
	var rise := 1.8
	var half_span := 5.6
	var pitch: float = atan2(rise, half_span)
	var slope_len: float = Vector2(half_span, rise).length() + 0.1
	var roof_mat: Material = MFScript.roof()
	for s in [-1.0, 1.0]:
		var r2 := DK.box_mi(self, Vector3(0, top + rise * 0.5 + 0.02, s * half_span * 0.5), Vector3(13.0, 0.14, slope_len), roof_mat)
		r2.rotation.x = s * pitch
	DK.box_mi(self, Vector3(0, top + rise + 0.04, 0), Vector3(13.0, 0.12, 0.25), MFScript.wood_dark())
	for sx2 in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(10.3, rise, 0.3)
		gable.mesh = prism
		gable.material_override = ext
		gable.position = Vector3(sx2 * 6.0, top + rise * 0.5, 0)
		gable.rotation_degrees.y = 90.0
		add_child(gable)

	# --- Upper landing (x -1.2..3.0 over the hall) with doors to three rooms.
	var p_nw: Material = MFScript.plaster()
	var p_sw: Material = MFScript.plaster_old()
	_wall(Vector2(-1.2, -4.85), Vector2(-1.2, 4.85), T_IN, inner, p_nw, [[UP_DOOR_NW - 0.45, UP_DOOR_NW + 0.45, fl, fl + 2.05], [UP_DOOR_SW - 0.45, UP_DOOR_SW + 0.45, fl, fl + 2.05]], fl, top)
	_wall(Vector2(3.0, -4.85), Vector2(3.0, 4.85), T_IN, inner, inner, [[UP_DOOR_E - 0.45, UP_DOOR_E + 0.45, fl, fl + 2.05]], fl, top)
	_wall(Vector2(-5.85, 0.0), Vector2(-1.26, 0.0), T_IN, p_sw, p_nw, [], fl, top)
	for dz in [UP_DOOR_NW, UP_DOOR_SW]:
		DK.doorway_trim(self, MFScript, Vector3(-1.2, fl, dz), 0.9, 2.05, T_IN, 90.0)
	DK.doorway_trim(self, MFScript, Vector3(3.0, fl, UP_DOOR_E), 0.9, 2.05, T_IN, 90.0)
	_bb(Vector2(-1.14, 4.85), Vector2(-1.14, -4.85), [[UP_DOOR_SW - 0.45, UP_DOOR_SW + 0.45], [UP_DOOR_NW - 0.45, UP_DOOR_NW + 0.45]], fl)
	_bb(Vector2(-1.14, -4.79), Vector2(1.12, -4.79), [], fl)
	_bb(Vector2(2.94, -1.5), Vector2(2.94, 4.85), [[UP_DOOR_E - 0.45, UP_DOOR_E + 0.45]], fl)
	_bb(Vector2(2.94, 4.79), Vector2(-1.14, 4.79), [], fl)
	_build_up_rooms(fl)
	# Railings round the stairwell
	var rail_mat: Material = MFScript.wood_trim()
	for r3 in [[Vector3(ST_X0 - 0.03, fl, -1.5), Vector3(ST_X0 - 0.03, fl, -3.95)],
			[Vector3(ST_X0, fl, -1.47), Vector3(ST_X1, fl, -1.47)],
			[Vector3(1.12, fl, -3.92), Vector3(ST_X0, fl, -3.92)]]:
		var a3: Vector3 = r3[0]
		var b3: Vector3 = r3[1]
		var mid: Vector3 = (a3 + b3) * 0.5
		var span := Vector3(absf(b3.x - a3.x) + 0.06, 0.06, absf(b3.z - a3.z) + 0.06)
		DK.box_mi(self, mid + Vector3(0, 0.95, 0), span, rail_mat)
		var n_posts: int = maxi(2, int(a3.distance_to(b3) / 0.35))
		for k in n_posts + 1:
			DK.box_mi(self, a3.lerp(b3, float(k) / float(n_posts)) + Vector3(0, 0.47, 0), Vector3(0.035, 0.95, 0.035), rail_mat)
		DK.collide(self, mid + Vector3(0, 0.55, 0), Vector3(maxf(span.x, 0.08), 1.1, maxf(span.z, 0.08)))
	# The half-open window and the curtain moving in the draught (ch3)
	DK.window_in_wall(self, MFScript, Vector3(1.2, 4.9, -5.0), 1.2, 1.2, T_OUT)
	var curtain := DK.box_mi(self, Vector3(1.62, fl + 1.45, -4.76), Vector3(0.5, 1.6, 0.025), MFScript.fabric_blue())
	curtain.name = "UpperCurtain"
	DK.box_mi(self, Vector3(1.2, fl + 2.3, -4.76), Vector3(1.6, 0.03, 0.03), MFScript.metal_dark())
	_interact(Vector3(1.2, fl + 0.85, -4.75), Vector3(0.3, 0.08, 0.12),
		"Window latch", "The latch is open. Whoever opened it did it from inside, in a hurry.",
		"upper_window", "", "", false)
	DK.rug(self, MFScript, Vector3(0.5, fl, 0.5), 1.0, 5.0, Color(0.26, 0.2, 0.2))
	F.ph(self, "Stool", Vector3(0.0, fl, -4.2), 15.0)
	DK.frame(self, MFScript, Vector3(-1.12, fl + 1.55, -0.6), 0.5, 0.62, 90.0)
	DK.frame(self, MFScript, Vector3(-1.12, fl + 1.6, 0.6), 0.42, 0.54, 90.0)
	_omni(Vector3(0.9, fl + 2.1, -1.0), Color(0.62, 0.72, 0.95), 0.45, 7.5)
	_omni(Vector3(1.2, fl + 1.5, -4.2), Color(0.55, 0.65, 0.9), 0.35, 3.5)

# ---------------------------------------------------------------- upstairs rooms
## Doors from the upper landing (z centres in the landing walls).
const UP_DOOR_NW := -2.6     # west wall: Eitan's old room
const UP_DOOR_SW := 2.2      # west wall: parents' bedroom
const UP_DOOR_E := 2.4       # east wall: storage room

## Optional rooms: nothing here is needed to finish the story, but each tells a little more.
## Furniture stays clear of the door swings (each leaf opens into its room on the hinge side).
func _build_up_rooms(fl: float) -> void:
	# --- North-west: Eitan's old room (x -5.85..-1.26, z -4.85..-0.06)
	_bb(Vector2(-5.85, -4.79), Vector2(-1.26, -4.79), [], fl)
	_bb(Vector2(-1.26, -4.85), Vector2(-1.26, -0.06), [[UP_DOOR_NW - 0.45, UP_DOOR_NW + 0.45]], fl)
	_bb(Vector2(-1.26, -0.06), Vector2(-5.85, -0.06), [], fl)
	_bb(Vector2(-5.79, -0.06), Vector2(-5.79, -4.85), [], fl)
	F.ph(self, "Bed_Frame", Vector3(-4.85, fl, -4.2), 90.0, {"shrink_top": 0.6})
	DK.bedding(self, MFScript, Vector3(-4.85, fl + 0.44, -4.2), 0.86, 1.9, 90.0)
	var ns: Node3D = F.ph(self, "ClassicNightstand", Vector3(-5.55, fl, -3.3), 90.0)
	F.ph(self, "AlarmClock", Vector3(-5.55, F.top(ns, fl + 0.7), -3.3), 90.0, {"collide": false})
	F.ph(self, "Desk", Vector3(-2.0, fl, -4.57), 0.0)
	F.ph(self, "Chair", Vector3(-2.0, fl, -3.95), 180.0)
	F.ph(self, "CardboardBox", Vector3(-3.2, fl, -0.45), 10.0)
	F.ph(self, "WoodenCrate", Vector3(-4.5, fl, -0.3), 0.0)
	DK.rug(self, MFScript, Vector3(-3.6, fl, -2.2), 1.6, 1.2, Color(0.22, 0.28, 0.34))
	DK.frame(self, MFScript, Vector3(-5.0, fl + 1.75, -4.83), 0.5, 0.4, 0.0, MFScript.flat(Color(0.75, 0.72, 0.6), 0.8))
	_interact(Vector3(-5.0, fl + 1.75, -4.82), Vector3(0.5, 0.4, 0.02), "Child's drawing",
		"A house, a sun, four stick figures holding hands. Someone added a fifth, in pencil, standing outside the door.", "", "", "", false)
	_interact(Vector3(-4.4, fl + 0.72, -4.2), Vector3(0.8, 0.1, 0.7), "Your old bed",
		"Made, with clean sheets. As if someone was expecting you back.", "", "", "", false)
	_omni(Vector3(-3.5, fl + 2.0, -2.5), Color(0.6, 0.68, 0.92), 0.35, 6.0)

	# --- South-west: parents' bedroom (x -5.85..-1.26, z 0.06..4.85)
	_bb(Vector2(-5.85, 0.06), Vector2(-1.26, 0.06), [], fl)
	_bb(Vector2(-1.26, 0.06), Vector2(-1.26, 4.85), [[UP_DOOR_SW - 0.45, UP_DOOR_SW + 0.45]], fl)
	_bb(Vector2(-1.26, 4.79), Vector2(-5.85, 4.79), [], fl)
	_bb(Vector2(-5.79, 4.85), Vector2(-5.79, 0.06), [], fl)
	F.ph(self, "GothicBed", Vector3(-3.9, fl, 1.1), 0.0, {"shrink_top": 0.9})
	var n1: Node3D = F.ph(self, "Nightstand", Vector3(-5.0, fl, 0.36), 0.0)
	F.ph(self, "Nightstand", Vector3(-2.8, fl, 0.36), 0.0)
	F.ph(self, "AlarmClock", Vector3(-5.0, F.top(n1, fl + 0.62), 0.36), 20.0, {"collide": false, "name": "ParentsClock"})
	var dr: Node3D = F.ph(self, "Dresser", Vector3(-5.35, fl, 3.85), 90.0)
	F.ph(self, "StandingFrame", Vector3(-5.35, F.top(dr, fl + 1.09), 3.55), 90.0, {"collide": false})
	DK.rug(self, MFScript, Vector3(-3.9, fl, 2.9), 1.8, 1.2, Color(0.4, 0.3, 0.24))
	_interact(Vector3(-5.0, F.top(n1, fl + 0.62) + 0.08, 0.36), Vector3(0.14, 0.17, 0.08), "Alarm clock",
		"Stopped at 02:17. The batteries are fine.", "", "", "", false)
	_interact(Vector3(-3.9, fl + 0.75, 0.55), Vector3(1.2, 0.12, 0.5), "Pillows",
		"One side of the bed is made tight. The other side has not been slept in for a long time.", "", "", "", false)
	_interact(Vector3(-5.35, F.top(dr, fl + 1.09) + 0.12, 3.55), Vector3(0.12, 0.26, 0.22), "Wedding photo",
		"Miriam and Yoav, laughing at something outside the frame. The glass is cleaner than anything else in the room.", "", "", "", false)
	_omni(Vector3(-3.5, fl + 2.0, 2.5), Color(0.62, 0.68, 0.9), 0.35, 6.0)

	# --- East: storage room over the living room and study (x 3.06..5.85, z -4.85..4.85)
	_bb(Vector2(3.06, -4.79), Vector2(5.85, -4.79), [], fl)
	_bb(Vector2(5.79, -4.85), Vector2(5.79, 4.85), [], fl)
	_bb(Vector2(5.85, 4.79), Vector2(3.06, 4.79), [], fl)
	_bb(Vector2(3.06, 4.85), Vector2(3.06, -4.85), [[UP_DOOR_E - 0.45, UP_DOOR_E + 0.45]], fl)
	F.ph(self, "SteelShelves", Vector3(5.6, fl, -1.0), -90.0, {"scale": 0.1})
	F.ph(self, "WoodenCrate", Vector3(4.2, fl, -4.55), 0.0, {"name": "AtticCrate"})
	F.ph(self, "CardboardBox", Vector3(3.45, fl, -4.5), -12.0, {"name": "AtticBox"})
	var c2: Node3D = F.ph(self, "Crate2", Vector3(4.8, fl, 4.4), 90.0, {"name": "RadioCrate"})
	F.ph(self, "RockingChair", Vector3(4.2, fl, -3.3), 180.0, {"shrink_top": 0.45})
	DK.radio(self, MFScript, Vector3(4.8, F.top(c2, fl + 0.46), 4.4), 180.0)
	_interact(Vector3(4.8, F.top(c2, fl + 0.46) + 0.12, 4.4), Vector3(0.44, 0.24, 0.18), "Old radio",
		"You turn the dial. Between two stations, under the hiss, something like a voice.", "", "radio_on", "", false)
	_interact(Vector3(4.2, fl + 0.55, -3.3), Vector3(0.5, 0.2, 0.5), "Rocking chair",
		"Turned to face the street window. The cushion still holds a shape.", "", "", "", false)
	_omni(Vector3(4.5, fl + 2.0, 0.0), Color(0.6, 0.66, 0.9), 0.35, 7.0)

# ---------------------------------------------------------------- doors
func _place_doors() -> void:
	var sd: StaticBody3D = DoorScript.new()
	sd.name = "StudyDoor"
	sd.position = Vector3(3.0, 1.03, 2.9)
	sd.rotation_degrees.y = -90.0
	sd.set("title", "Study door")
	sd.set("locked", true)
	sd.set("required_clue", "photo_key")
	sd.set("locked_hint", "Locked. The family photo hid a small brass key.")
	sd.set("event_id", "study_open")
	sd.set("door_w", 0.98)
	sd.set("door_h", 2.05)
	sd.set("swing_deg", 90.0)
	add_child(sd)
	var pd: StaticBody3D = DoorScript.new()
	pd.name = "HiddenPanel"
	pd.position = Vector3(SV_PANEL_X, 0.76, -4.98)
	pd.rotation_degrees.y = 180.0
	pd.set("title", "Wooden panel")
	pd.set("locked", true)
	pd.set("required_clue", "photo_key")
	pd.set("locked_hint", "A small lock. The kitchen key should fit.")
	pd.set("event_id", "hidden_open")
	pd.set("door_w", 0.8)
	pd.set("door_h", 1.5)
	pd.set("swing_deg", 100.0)
	add_child(pd)
	var bsd: StaticBody3D = DoorScript.new()
	bsd.name = "BasementDoor"
	bsd.position = Vector3(ST_X0 + 0.015, BS_DOOR_H * 0.5, (BS_DOOR_Z0 + BS_DOOR_Z1) * 0.5)
	bsd.rotation_degrees.y = -90.0
	bsd.set("title", "Basement door")
	bsd.set("locked", false)
	bsd.set("door_w", BS_DOOR_Z1 - BS_DOOR_Z0 - 0.06)
	bsd.set("door_h", BS_DOOR_H - 0.02)
	bsd.set("swing_deg", -90.0)
	add_child(bsd)
	var bd: StaticBody3D = DoorScript.new()
	bd.name = "BackDoor"
	bd.position = Vector3(-6.0, 1.03, -2.125)
	bd.rotation_degrees.y = 90.0
	bd.set("title", "Back door")
	bd.set("locked", true)
	bd.set("required_clue", "__never__")
	bd.set("locked_hint", "Locked from the inside. The lock is new, brighter than the door around it.")
	bd.set("inspect_clue", "back_door")
	bd.set("door_w", 0.83)
	bd.set("door_h", 2.04)
	add_child(bd)
	var fl_up: float = UPPER_Y + 0.1
	for d in [["UpDoorNW", UP_DOOR_NW, "Door to your old room", -1.2, -90.0], ["UpDoorSW", UP_DOOR_SW, "Bedroom door", -1.2, -90.0], ["UpDoorE", UP_DOOR_E, "Storage room door", 3.0, 90.0]]:
		var ud: StaticBody3D = DoorScript.new()
		ud.name = str(d[0])
		ud.position = Vector3(float(d[3]), fl_up + 1.025, float(d[1]))
		ud.rotation_degrees.y = -90.0
		ud.set("title", str(d[2]))
		ud.set("locked", false)
		ud.set("door_w", 0.88)
		ud.set("door_h", 2.04)
		ud.set("swing_deg", float(d[4]))
		add_child(ud)
	var fd: StaticBody3D = DoorScript.new()
	fd.name = "FrontDoor"
	fd.position = Vector3(0, 1.04, 5.0)
	fd.set("title", "Front door")
	fd.set("locked", false)
	fd.set("event_id", "front_door")
	fd.set("door_w", 1.18)
	fd.set("door_h", 2.08)
	add_child(fd)

# ---------------------------------------------------------------- atmosphere
func _atmosphere() -> void:
	_add_dust(Vector3(-3.4, 1.8, -3.0), 56)
	_add_dust(Vector3(4.5, 1.8, -1.0), 36)
	_add_dust(Vector3(1.0, 1.6, 1.0), 24)
	var upper := get_node_or_null("UpperCurtain")
	if upper == null:
		for c in get_children():
			if c.name == "UpperCurtain":
				upper = c
	if upper != null:
		var tw2 := create_tween().set_loops()
		tw2.tween_property(upper, "rotation_degrees:x", 6.0, 1.9).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(upper, "rotation_degrees:x", -2.0, 1.9).set_trans(Tween.TRANS_SINE)

func _add_dust(pos: Vector3, amount: int) -> void:
	var dust := GPUParticles3D.new()
	dust.position = pos
	dust.amount = amount
	dust.lifetime = 5.0
	dust.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.2, 0.8, 1.2)
	pm.direction = Vector3(0, -0.15, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3(0.01, -0.01, 0)
	pm.scale_min = 0.004
	pm.scale_max = 0.009
	dust.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(1, 0.96, 0.9, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.billboard_keep_scale = true
	qm.material = dm
	dust.draw_pass_1 = qm
	dust.add_to_group("dust")
	add_child(dust)

func _apply_visual_settings() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var we: WorldEnvironment = $WorldEnvironment as WorldEnvironment
	if gm == null or we == null or we.environment == null:
		return
	we.environment.glow_enabled = true
	we.environment.glow_intensity = 0.5
	we.environment.glow_bloom = 0.12
	we.environment.glow_hdr_threshold = 0.92
	we.environment.adjustment_enabled = true
	we.environment.adjustment_contrast = 1.05
	we.environment.adjustment_saturation = 0.9
	we.environment.ambient_light_energy = 0.75
	we.environment.ambient_light_color = Color(0.42, 0.47, 0.6, 1.0)
	we.environment.adjustment_brightness = 1.0
	apply_graphics()

## Graphics quality: 0 Low (no SSAO/glow/shadows, 75% render scale), 1 Medium (no SSAO,
## only the sun + kitchen + street lamp cast shadows), 2 High (everything).
func apply_graphics() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var q: int = int((gm.get("settings") as Dictionary).get("graphics", 1)) if gm != null else 1
	var we: WorldEnvironment = $WorldEnvironment as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.ssao_enabled = q >= 2
		we.environment.glow_enabled = q >= 1
	for i in _shadow_lights.size():
		var l: Light3D = _shadow_lights[i]
		l.shadow_enabled = q >= 2 or (q == 1 and i < 2)
	# The sun/moon must ALWAYS cast shadows: without them it shines straight through the
	# roof and walls and washes every room out. Low only lowers the shadow resolution.
	var sun: DirectionalLight3D = $Sun as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 30.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if q == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(1024 if q == 0 else 4096, true)
	get_viewport().scaling_3d_scale = 0.75 if q == 0 else 1.0

# ---------------------------------------------------------------- zones
func _add_zones() -> void:
	_zone(Vector3(-3.55, 1, -3.25), Vector3(4.5, 3, 3.1), 2)
	_zone(Vector3(-2, 1, 8.5), Vector3(8, 4, 7), 0, "stepped_out")

func _zone(pos: Vector3, size: Vector3, chapter: int, event_id: String = "") -> void:
	var a := Area3D.new()
	a.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	a.add_child(cs)
	a.set_meta("chapter", chapter)
	a.set_meta("event_id", event_id)
	a.body_entered.connect(_on_zone.bind(a))
	add_child(a)

func _on_zone(body: Node3D, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if int(area.get_meta("chapter", 0)) == 2:
		_kitchen_seen = true
		_advance()
	var ev: String = str(area.get_meta("event_id", ""))
	var em: Node = get_node_or_null("/root/EventManager")
	if ev != "" and em != null:
		em.call("fire", ev)

# ---------------------------------------------------------------- chapter progression
## Chapters advance one at a time, each on a story beat (clue/event), in whatever order
## the player finds things. Each passed beat fires its cue (ch3: footsteps upstairs).
var _kitchen_seen := false

func _has(c: String) -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	return gm != null and bool(gm.call("has_clue", c))

func _has_any(cs: Array) -> bool:
	for c in cs:
		if _has(str(c)):
			return true
	return false

func _fired(e: String) -> bool:
	var em: Node = get_node_or_null("/root/EventManager")
	return em != null and bool(em.call("was_fired", e))

func _chapter_ready(n: int) -> bool:
	match n:
		2: return _kitchen_seen or _has_any(["tea_cup", "mother_note", "photo_key"])
		3: return _has("photo_key")
		4: return _has_any(["clock_0217", "folded_note"])
		5: return _has_any(["noa_journal", "box_empty", "carving", "camera_old"])
		6: return _has("house_plan") or _fired("cabinet_move") or _fired("hidden_open")
		7: return _has_any(["miriam_letter", "last_tape"])
		8: return _has("storm_tape") and _has("noa_farewell")
	return false

func _advance() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var cur: int = int(gm.get("chapter"))
	if cur >= 8:
		return
	var c: int = cur
	while c < 8 and _chapter_ready(c + 1):
		c += 1
		if c == 3:
			var em: Node = get_node_or_null("/root/EventManager")
			if em != null:
				em.call("fire", "corridor_steps")
	if c != cur:
		gm.call("set_chapter", c)
		_set_objective(c)

## 3D sounds inside this box also go to a reverb bus (basement echo, tiled bathroom).
func _reverb_room(pos: Vector3, size: Vector3, bus: String, amount: float) -> void:
	var a := Area3D.new()
	a.name = "Reverb_" + bus
	a.position = pos
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = bus
	a.reverb_bus_amount = amount
	a.reverb_bus_uniformity = 0.6
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	add_child(a)

## The hall clock (ch3: "the hands twitch, then fall back to 02:17"). Every so often,
## while the player is near, the second hand ticks a few seconds, the minute hand jumps
## one minute, then both slide back to 02:17.
func _clock_loop() -> void:
	var clock := get_node_or_null("WallClock") as Node3D
	if clock == null:
		return
	var minute := clock.get_node("MinuteHand") as Node3D
	var second := clock.get_node("SecondHand") as Node3D
	var rest_m: float = minute.rotation.z
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(5.0, 11.0), false).timeout
		if not is_inside_tree():
			return
		var pl := get_node_or_null("Player") as Node3D
		if pl == null or pl.global_position.distance_to(clock.global_position) > 7.0:
			continue
		var am: Node = get_node_or_null("/root/AudioManager")
		for i in rng.randi_range(3, 6):
			second.rotation.z -= deg_to_rad(6.0)
			if am != null:
				am.call("_play", am.call("_sfx", "ui"), "Foley", -24.0, 0.02, [1200.0, 0.03, 0.2, 0.1], clock.global_position)
			await get_tree().create_timer(1.0, false).timeout
		var tw := create_tween()
		tw.tween_property(minute, "rotation:z", rest_m - deg_to_rad(6.0), 0.08)
		tw.tween_interval(0.9)
		tw.set_parallel(true)
		tw.tween_property(minute, "rotation:z", rest_m, 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(second, "rotation:z", 0.0, 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## After loading a save, put the world back the way the player left it.
const TABLE_NEEDS := {
	"photo": ["photo_key", "the family photo", "It was on the kitchen table, with the key taped behind it."],
	"tape": ["storm_tape", "the storm-night recording", "The recorder is in the basement, on a stool."],
	"letter": ["miriam_letter", "Mom's letter", "It is in the wall, behind the service cabinet."],
}

## Before the choice the table shows what you have found so far.
func _apply_table_collected() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null or _table_items.is_empty() or int(gm.get("ending_choice")) != 0:
		return
	for k in TABLE_NEEDS.keys():
		(_table_items[k] as Node3D).visible = _has(str(TABLE_NEEDS[k][0]))

## What the table says when you try to choose too early.
func _table_status() -> String:
	var have: Array = []
	var missing: Array = []
	for k in ["photo", "tape", "letter"]:
		var need: Array = TABLE_NEEDS[k]
		if _has(str(need[0])):
			have.append(str(need[1]))
		else:
			missing.append("Missing: %s. %s" % [need[1], need[2]])
	var t := "Not yet. "
	if not have.is_empty():
		t += "On the table: " + ", ".join(have) + ".\n\n"
	return t + "\n".join(missing)

## After the choice only one item stays on the table, moved to the middle.
func _apply_ending_table(_choice: int = 0) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm == null or _table_items.is_empty():
		return
	var e: Dictionary = gm.call("ending")
	if e.is_empty():
		return
	var keep: String = str(e["item"])
	(_table_items["tape1"] as Node3D).visible = false
	for k in ["photo", "tape", "letter"]:
		var n := _table_items[k] as Node3D
		n.visible = k == keep
		if k == keep:
			var c: Vector3 = _table_items["centre"]
			n.position = Vector3(c.x, n.position.y, c.z)
	(_table_items["tape_clue"] as CollisionObject3D).collision_layer = 0
	var vt := _table_items["versions"] as Node
	vt.set("title", "The table")
	vt.set("body_text", str(e["table"]))

func _restore_world() -> void:
	_apply_table_collected()
	_apply_ending_table()
	if _fired("key_found") and _fridge_hum != null:
		_fridge_hum.stop()
		_fridge_hum.autoplay = false
	if _fired("cabinet_move"):
		for cab in get_tree().get_nodes_in_group("service_cabinet"):
			(cab as Node3D).position.x = SV_CAB_MOVED_X
	var sd := get_node_or_null("StudyDoor")
	if sd != null and (_fired("study_open") or _has("photo_key")):
		sd.call("set_open_instant", _fired("study_open"))
	var pd := get_node_or_null("HiddenPanel")
	if pd != null and _fired("hidden_open"):
		pd.call("set_open_instant", true)
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and int(gm.get("chapter")) >= 9:
		_apply_morning(true)

## After the voicemail (however early it was closed) chapter 1 points to the kitchen,
## as Noa asked.
const OBJECTIVE_AFTER_VOICEMAIL := "Noa said to start in the kitchen. Find what Mom left there."

func _set_objective(ch: int) -> void:
	var t: String = str(OBJECTIVES.get(ch, ""))
	if ch == 1 and _fired("voicemail_heard"):
		t = OBJECTIVE_AFTER_VOICEMAIL
	if hud != null and hud.has_method("set_objective"):
		hud.call("set_objective", t)

func _set_objective_current() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null:
		_set_objective(int(gm.get("chapter")))

# ---------------------------------------------------------------- morning
func start_morning() -> void:
	if _morning:
		return
	_morning = true
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("set_chapter"):
		gm.call("set_chapter", 9)
	_set_objective(9)
	if hud != null:
		hud.call("fade", 0.35, 1.5, Color(0.92, 0.9, 0.86))
		get_tree().create_timer(1.6).timeout.connect(func() -> void: hud.call("fade", 0.0, 4.0, Color(0.92, 0.9, 0.86)))
	_apply_morning(false)
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("set_morning"):
		am.call("set_morning")
	if hud != null and hud.has_method("show_morning") and gm != null:
		hud.call("show_morning", gm.call("ending"))

## Dawn: the rain stops and the light comes up over a few seconds (instant on load).
func _apply_morning(instant: bool) -> void:
	_morning = true
	if rain != null:
		rain.emitting = false
	var dur: float = 0.01 if instant else 6.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	var sun: DirectionalLight3D = $Sun as DirectionalLight3D
	if sun != null:
		sun.rotation_degrees = Vector3(-38.0, 40.0, 0.0)
		tw.tween_property(sun, "light_color", Color(0.95, 0.96, 1.0), dur)
		tw.tween_property(sun, "light_energy", 1.6, dur)
	if kitchen_light != null:
		tw.tween_property(kitchen_light, "light_energy", 0.05, dur)
	if hall_light != null:
		tw.tween_property(hall_light, "light_energy", 0.2, dur)
	var we: WorldEnvironment = $WorldEnvironment as WorldEnvironment
	if we != null and we.environment != null:
		tw.tween_property(we.environment, "adjustment_brightness", 1.12, dur)
		tw.tween_property(we.environment, "fog_density", 0.008, dur)
		tw.tween_property(we.environment, "fog_light_color", Color(0.72, 0.76, 0.84), dur)
		tw.tween_property(we.environment, "background_color", Color(0.55, 0.62, 0.72), dur)
	for d in get_tree().get_nodes_in_group("dust"):
		if d is GPUParticles3D:
			(d as GPUParticles3D).emitting = false

# ---------------------------------------------------------------- events
func _on_event(event_id: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	var sm: Node = get_node_or_null("/root/SaveManager")
	var gm: Node = get_node_or_null("/root/GameManager")
	match event_id:
		"key_found":
			# Brief ch2: the fridge cuts out, then a pipe answers from inside the wall.
			if _fridge_hum != null and _fridge_hum.playing:
				var twh := create_tween()
				twh.tween_property(_fridge_hum, "volume_db", -60.0, 0.25)
				twh.tween_callback(_fridge_hum.stop)
				if hud != null:
					hud.call("show_caption", "[the fridge cuts out]", 2.5)
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					if am != null:
						am.call("play_pipe", Vector3(-5.9, 1.4, -3.9)))
			if kitchen_light != null:
				var tw := create_tween()
				tw.tween_property(kitchen_light, "light_energy", 0.15, 0.4)
				tw.tween_property(kitchen_light, "light_energy", 1.5, 1.5)
			if sm != null:
				sm.call("autosave", event_id)
		"hidden_open":
			_advance()
			if am != null and am.has_method("play_knocks"):
				am.call("play_knocks", 3, false, Vector3(SV_PANEL_X, 1.0, -5.15))
			if sm != null:
				sm.call("autosave", event_id)
		"cabinet_move":
			_advance.call_deferred()
			var cabs: Array = get_tree().get_nodes_in_group("service_cabinet")
			if cabs.size() > 0:
				var cab: Node3D = cabs[0] as Node3D
				if cab.position.x > SV_CAB_MOVED_X + 0.5:
					var tw2 := create_tween()
					tw2.tween_property(cab, "position:x", SV_CAB_MOVED_X, 1.2).set_trans(Tween.TRANS_SINE)
			if am != null and am.has_method("play_door"):
				am.call("play_door", false, Vector3(SV_CAB_MOVED_X, 1.0, -4.5))
			if hud != null and hud.has_method("toast"):
				hud.call("toast", "Behind it: a wooden panel with a small lock.")
		"study_tapes":
			# Chapter 5 beat: the desk lamp dips on one line of the tape.
			if _study_lamp != null:
				var tw3 := create_tween()
				tw3.tween_property(_study_lamp, "light_energy", 0.12, 0.25)
				tw3.tween_interval(0.5)
				tw3.tween_property(_study_lamp, "light_energy", 1.6, 0.9)
		"study_open":
			if sm != null:
				sm.call("autosave", event_id)
		"gate_creak":
			if am != null and am.has_method("play_door"):
				am.call("play_door", false, Vector3(0, 1.0, 12.4))
		"stepped_out":
			if am != null and am.has_method("play_car"):
				am.call("play_car")
			# The street lamp falters once as the car passes (no white flashes: brief section 14).
			if _street_spot != null:
				var e: float = _street_spot.light_energy
				var twl := create_tween()
				twl.tween_interval(1.4)
				for v in [0.3, e, 0.15, e * 0.7, e]:
					twl.tween_property(_street_spot, "light_energy", v, 0.07)
					twl.tween_interval(0.05)
		"corridor_steps":
			if am != null and am.has_method("play_steps"):
				am.call("play_steps", Vector3(0.2, UPPER_Y + 0.2, -1.5))
		"knocks_wall":
			# The last tape: the wall answers.
			if am != null:
				am.call("play_knocks", 3, false, Vector3(SV_PANEL_X, 1.0, -5.15))
		"basement_tape":
			# Noa's note in the basement: knocks from up the stairs, in the house.
			if am != null:
				am.call("play_knocks", 3, true, Vector3(ST_X0 - 0.2, 1.0, -3.55))
		"front_door":
			if gm != null and int(gm.get("ending_choice")) == 0:
				if hud != null and hud.has_method("toast"):
					hud.call("toast", "The street can wait. Finish inside first.")
			else:
				start_morning()
		"radio_on":
			if am != null:
				am.call("play_static", 2.5, Vector3(4.8, UPPER_Y + 0.7, 4.4))
				if _fired("hidden_open"):
					# Faint, and from somewhere else: the back door downstairs.
					get_tree().create_timer(1.2).timeout.connect(func() -> void: am.call("play_knocks", 3, true, Vector3(-6.0, 1.2, -2.1)))
			var em3: Node = get_node_or_null("/root/EventManager")
			if em3 != null:
				em3.call("unfire", "radio_on")
		"voicemail_heard":
			if gm != null and int(gm.get("chapter")) == 1:
				_set_objective(1)
		"show_endings":
			# The choice needs the three things the brief puts on the table.
			var ready: bool = _has("photo_key") and _has("storm_tape") and _has("miriam_letter")
			var vt := _table_items["versions"] as Node
			if gm != null and int(gm.get("ending_choice")) == 0 and ready:
				vt.set("body_text", "")          # no inspect panel: the choice opens instead
				if hud != null and hud.has_method("show_endings"):
					hud.call("show_endings")
			else:
				var em2: Node = get_node_or_null("/root/EventManager")
				if em2 != null:
					em2.call("unfire", "show_endings")
				if gm != null and int(gm.get("ending_choice")) == 0:
					vt.set("body_text", _table_status())
