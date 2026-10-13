extends RefCounted
## Furniture layer. Prefers the realistic Poly Haven CC0 models; falls back to the
## Kenney CC0 kit; falls back to procedural DetailKit geometry.
##
## All external meshes are VISUAL ONLY. Collision stays on the simple procedural box
## colliders built by house_entry.gd, so navigation and the interaction raycast are
## unaffected by any asset swap.

const PH := "res://assets/models/polyhaven/"
const KENNEY := "res://assets/models/kenney/"
const MFScript := preload("res://scripts/core/material_factory.gd")

## Poly Haven models are authored at true metric scale; Kenney's kit is ~0.6x.
const KENNEY_SCALE := 1.7

static func _ph_path(local: String) -> String:
	var p: String = PH + local + "/model.gltf"
	return p if ResourceLoader.exists(p) else ""

static func _load_polyhaven(parent: Node3D, local: String, pos: Vector3, rot_y: float) -> Node3D:
	var path: String = _ph_path(local)
	if path == "":
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	if n == null:
		return null
	n.name = "PH_" + local
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	_tame_materials(n)
	return n

## Kenney ships flat toon materials; re-skin so they match the house palette.
static func _reskin(n: Node3D, tint: Color, rough: float, metallic: float = 0.0) -> void:
	var mat: StandardMaterial3D = MFScript.flat(tint, rough, metallic)
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			(cur as MeshInstance3D).material_override = mat
		for c in cur.get_children():
			stack.append(c)

static func _load_kenney(parent: Node3D, model: String, pos: Vector3, rot_y: float, tint: Color, rough: float, metallic: float = 0.0, extra_scale: float = 1.0) -> Node3D:
	var path: String = KENNEY + model + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	if n == null:
		return null
	n.name = "K_" + model
	n.position = pos
	n.rotation_degrees.y = rot_y
	var s: float = KENNEY_SCALE * extra_scale
	n.scale = Vector3(s, s, s)
	parent.add_child(n)
	_reskin(n, tint, rough, metallic)
	return n

## Tames imported PBR materials for indoor night lighting:
##  - metallic surfaces go near-black without reflections, so clamp metallic down
##  - emissive bulbs blow out, so cap emission energy
static func _tame_materials(n: Node3D) -> void:
	var seen: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			_collect_mats(mi, seen)
		for c in cur.get_children():
			stack.append(c)

static func _collect_mats(mi: MeshInstance3D, seen: Array) -> void:
	if mi.material_override != null and mi.material_override is StandardMaterial3D:
		_tame_one(mi.material_override as StandardMaterial3D, seen)
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	for si in mesh.get_surface_count():
		var m: Material = mi.get_surface_override_material(si)
		if m == null:
			m = mesh.surface_get_material(si)
		if m is StandardMaterial3D:
			_tame_one(m as StandardMaterial3D, seen)

static func _tame_one(sm: StandardMaterial3D, seen: Array) -> void:
	if seen.has(sm.get_rid()):
		return
	seen.append(sm.get_rid())
	if sm.metallic > 0.35:
		sm.metallic = 0.15
	if sm.emission_enabled and sm.emission_energy_multiplier > 0.8:
		sm.emission_energy_multiplier = 0.6

## AABB of every visible mesh under n, in n's LOCAL frame. Walks the full glTF
## hierarchy via global transforms (nested nodes carry their own transforms, so
## using only mi.transform is wrong). n must be inside the tree.
static func local_aabb(n: Node3D) -> AABB:
	var inv: Transform3D = n.global_transform.affine_inverse()
	var box := AABB()
	var found := false
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null and mi.visible:
				var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
				box = b if not found else box.merge(b)
				found = true
		for c in cur.get_children():
			if not (c is CollisionObject3D):
				stack.append(c)
	return box if found else AABB()

static func world_aabb(n: Node3D) -> AABB:
	return n.global_transform * local_aabb(n)

## Kept for older callers: AABB size in the parent frame.
static func measure(n: Node3D) -> AABB:
	return world_aabb(n)

## Moves n so its footprint is centred on (pos.x, pos.z). floor_item=true rests the
## lowest vertex on pos.y; otherwise the AABB centre sits at pos.y. When `wall` is a
## non-zero direction (pointing from the wall INTO the room) the back of the model is
## pushed flush against the wall plane that passes through pos.
static func settle(n: Node3D, pos: Vector3, floor_item: bool, wall: Vector3 = Vector3.ZERO, gap: float = 0.0) -> void:
	var w: AABB = world_aabb(n)
	if w.size == Vector3.ZERO:
		n.global_position = pos
		return
	var c: Vector3 = w.get_center()
	var d := Vector3(pos.x - c.x, 0.0, pos.z - c.z)
	d.y = (pos.y - w.position.y) if floor_item else (pos.y - c.y)
	if wall != Vector3.ZERO:
		var nrm: Vector3 = wall.normalized()
		var half: float = absf(nrm.x) * w.size.x * 0.5 + absf(nrm.z) * w.size.z * 0.5
		d += nrm * (half + gap)
	n.global_position += d

## Back-compat wrapper.
static func ground(n: Node3D, target_y: float = 0.0, sink: float = 0.0) -> Vector2:
	var w: AABB = world_aabb(n)
	n.global_position.y += target_y + sink - w.position.y
	return Vector2(w.size.x, w.size.y)

## Real collision from the model's own local bounds (child body, so it follows the
## model's rotation exactly once). shrink_top lowers the collider top (e.g. so a
## worktop item does not block the raycast to objects lying on it).
static func add_collision(n: Node3D, shrink_top: float = 0.0) -> void:
	var lb: AABB = local_aabb(n)
	if lb.size == Vector3.ZERO:
		return
	var h: float = maxf(lb.size.y - shrink_top, 0.05)
	var body := StaticBody3D.new()
	body.name = "Col_" + n.name
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(lb.size.x, 0.05), h, maxf(lb.size.z, 0.05))
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(lb.get_center().x, lb.position.y + h * 0.5, lb.get_center().z)
	n.add_child(body)
	n.set_meta("aabb", world_aabb(n))

## floor_item=true  -> lowest point rests at pos.y, footprint centred on pos.x/z
## floor_item=false -> AABB centre placed at pos (wall / worktop mounted)
static func prop(parent: Node3D, ph: String, kenney: String, pos: Vector3, rot_y: float = 0.0, tint: Color = Color(0.34, 0.24, 0.16), rough: float = 0.7, metallic: float = 0.0, floor_item: bool = true, collide: bool = true, kenney_scale: float = 1.0, scale_mul: float = 1.0) -> Node3D:
	var n: Node3D = _load_polyhaven(parent, ph, pos, rot_y)
	var src := "PolyHaven:" + ph
	if n == null and kenney != "":
		n = _load_kenney(parent, kenney, pos, rot_y, tint, rough, metallic, kenney_scale)
		src = "Kenney:" + kenney
	if n == null:
		return null
	if scale_mul != 1.0:
		n.scale *= scale_mul
	settle(n, pos, floor_item)
	n.set_meta("placed_y", pos.y)
	n.set_meta("src", src)
	n.set_meta("floor_item", floor_item)
	if collide:
		add_collision(n)
	else:
		n.set_meta("aabb", world_aabb(n))
	return n

## Places a Poly Haven model.
##  pos      footprint centre (x/z); y = floor height (or centre height for non-floor items)
##  rot_y    degrees; all Poly Haven models face +Z, so 0=+Z, 90=+X, -90=-X, 180=-Z
##  opts     scale: float, floor: bool (default true), collide: bool (default = floor),
##           wall: Vector3 normal pointing from the wall INTO the room (back made flush
##           with the wall plane through pos), gap: float, name: String
## Sets meta "aabb" (world AABB) and "top" (world y of the highest point) so other
## items can be stood on it.
static func ph(parent: Node3D, local: String, pos: Vector3, rot_y: float = 0.0, opts: Dictionary = {}) -> Node3D:
	var n: Node3D = _load_polyhaven(parent, local, pos, rot_y)
	if n == null:
		push_warning("missing model " + local)
		return null
	if opts.has("name"):
		n.name = str(opts["name"])
	var sc: float = float(opts.get("scale", 1.0))
	if sc != 1.0:
		n.scale = Vector3(sc, sc, sc)
	var floor_item: bool = bool(opts.get("floor", true))
	settle(n, pos, floor_item, opts.get("wall", Vector3.ZERO), float(opts.get("gap", 0.0)))
	n.set_meta("src", "PolyHaven:" + local)
	n.set_meta("floor_item", floor_item)
	if bool(opts.get("collide", floor_item)):
		add_collision(n, float(opts.get("shrink_top", 0.0)))
	var w: AABB = world_aabb(n)
	n.set_meta("aabb", w)
	n.set_meta("top", w.end.y)
	return n

static func top(n: Node3D, fallback: float = 0.0) -> float:
	return float(n.get_meta("top", fallback)) if n != null else fallback
