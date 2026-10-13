extends RefCounted
## DetailKit: multi-part props so rooms stop looking like stacked boxes.
## Every helper returns the created node and sets collision only where needed.

static func box_mi(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	return mi

static func cyl_mi(parent: Node3D, pos: Vector3, r_top: float, r_bot: float, h: float, mat: Material, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	return mi

static func sphere_mi(parent: Node3D, pos: Vector3, r: float, mat: Material, seg: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(4, seg / 2)
	mi.mesh = sm
	mi.position = pos
	if mat != null:
		mi.material_override = mat
	parent.add_child(mi)
	return mi

static func collide(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body

## Baseboard + picture rail run along a wall segment.
static func baseboard(parent: Node3D, MF, a: Vector3, b: Vector3, height: float = 0.12, depth: float = 0.04) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var len_v: float = a.distance_to(b)
	# rotation.y maps local +X to (cos, 0, -sin); align it with (b-a).
	var ang: float = atan2(-(b.z - a.z), b.x - a.x)
	var n := Node3D.new()
	n.position = mid
	n.rotation.y = ang
	parent.add_child(n)
	box_mi(n, Vector3(0, height * 0.5, depth * 0.5), Vector3(len_v, height, depth), MF.wood_trim())

## Door casing (frame) around an opening.
static func door_casing(parent: Node3D, MF, pos: Vector3, w: float, h: float, rot_y: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(-w * 0.5 - 0.06, h * 0.5, 0), Vector3(0.12, h + 0.12, 0.16), MF.wood_trim())
	box_mi(n, Vector3(w * 0.5 + 0.06, h * 0.5, 0), Vector3(0.12, h + 0.12, 0.16), MF.wood_trim())
	box_mi(n, Vector3(0, h + 0.06, 0), Vector3(w + 0.24, 0.12, 0.16), MF.wood_trim())

## Window: frame, mullions, glass. Optionally open (gap) for the upstairs window.
static func window_frame(parent: Node3D, MF, pos: Vector3, w: float, h: float, rot_y: float = 0.0, open_ratio: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var t := 0.07
	box_mi(n, Vector3(-w * 0.5 - t * 0.5, 0, 0), Vector3(t, h + t * 2.0, 0.12), MF.wood_trim())
	box_mi(n, Vector3(w * 0.5 + t * 0.5, 0, 0), Vector3(t, h + t * 2.0, 0.12), MF.wood_trim())
	box_mi(n, Vector3(0, h * 0.5 + t * 0.5, 0), Vector3(w + t * 2.0, t, 0.12), MF.wood_trim())
	box_mi(n, Vector3(0, -h * 0.5 - t * 0.5, 0), Vector3(w + t * 2.0, t * 1.6, 0.16), MF.wood_trim())
	var pane := box_mi(n, Vector3(0, 0, 0), Vector3(w, h, 0.02), MF.glass_mat())
	if open_ratio > 0.0:
		pane.position.z = -open_ratio * 0.25
		pane.rotation.x = deg_to_rad(-open_ratio * 22.0)
	# mullions
	box_mi(n, Vector3(0, 0, -0.02), Vector3(0.035, h, 0.035), MF.wood_trim())
	box_mi(n, Vector3(0, 0, -0.02), Vector3(w, 0.035, 0.035), MF.wood_trim())

## Table lamp with emissive shade + practical light.
static func table_lamp(parent: Node3D, MF, pos: Vector3, color: Color = Color(1.0, 0.86, 0.66), energy: float = 1.4, range_m: float = 5.0) -> OmniLight3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	n.name = "TableLamp"
	cyl_mi(n, Vector3(0, 0.015, 0), 0.08, 0.095, 0.03, MF.metal_dark(), 14)
	var body := sphere_mi(n, Vector3(0, 0.12, 0), 0.075, MF.flat(Color(0.55, 0.42, 0.3), 0.4), 12)
	body.scale = Vector3(1, 1.3, 1)
	cyl_mi(n, Vector3(0, 0.27, 0), 0.012, 0.012, 0.14, MF.metal_dark(), 8)
	var shade := cyl_mi(n, Vector3(0, 0.38, 0), 0.1, 0.15, 0.17, MF.emissive(color.darkened(0.15), 0.55), 16)
	shade.name = "Shade"
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0.36, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	n.add_child(l)
	return l

## Ceiling pendant.
static func pendant(parent: Node3D, MF, pos: Vector3, color: Color = Color(1.0, 0.88, 0.7), energy: float = 1.6, range_m: float = 7.0) -> OmniLight3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cyl_mi(n, Vector3(0, 0.22, 0), 0.006, 0.006, 0.44, MF.metal_dark(), 6)
	cyl_mi(n, Vector3(0, -0.04, 0), 0.06, 0.24, 0.18, MF.emissive(color, 1.4), 16)
	var l := OmniLight3D.new()
	l.position = Vector3(0, -0.1, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	n.add_child(l)
	return l

## Fridge: body, door split, handle, kick plate.
static func fridge(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.68), MF.metal_dark())
	box_mi(n, Vector3(0, 1.28, 0.35), Vector3(0.66, 1.0, 0.04), MF.metal_dark())
	box_mi(n, Vector3(0, 0.55, 0.35), Vector3(0.66, 0.66, 0.04), MF.metal_dark())
	box_mi(n, Vector3(0.26, 1.3, 0.39), Vector3(0.04, 0.5, 0.04), MF.metal_dark())
	box_mi(n, Vector3(0.26, 0.6, 0.39), Vector3(0.04, 0.3, 0.04), MF.metal_dark())
	box_mi(n, Vector3(0, 0.03, 0.2), Vector3(0.68, 0.06, 0.1), MF.flat(Color(0.1, 0.1, 0.11), 0.9))
	return n

## Kitchen counter run with cabinet doors + handles + worktop overhang.
static func counter_run(parent: Node3D, MF, pos: Vector3, length: float, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.44, 0), Vector3(length, 0.88, 0.62), MF.wood_dark())
	box_mi(n, Vector3(0, 0.9, 0.02), Vector3(length + 0.04, 0.05, 0.68), MF.flat(Color(0.13, 0.12, 0.12), 0.55))
	var doors: int = maxi(1, int(length / 0.55))
	for i in doors:
		var x: float = -length * 0.5 + (float(i) + 0.5) * (length / float(doors))
		box_mi(n, Vector3(x, 0.46, 0.315), Vector3(length / float(doors) - 0.04, 0.78, 0.03), MF.wood_mid())
		box_mi(n, Vector3(x, 0.72, 0.35), Vector3(0.16, 0.025, 0.025), MF.metal_dark())
	return n

## Upper cabinets.
static func wall_cabinets(parent: Node3D, MF, pos: Vector3, length: float, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0, 0), Vector3(length, 0.7, 0.34), MF.wood_dark())
	var doors: int = maxi(1, int(length / 0.5))
	for i in doors:
		var x: float = -length * 0.5 + (float(i) + 0.5) * (length / float(doors))
		box_mi(n, Vector3(x, 0, 0.18), Vector3(length / float(doors) - 0.03, 0.66, 0.02), MF.wood_mid())
		box_mi(n, Vector3(x, -0.26, 0.2), Vector3(0.14, 0.02, 0.02), MF.metal_dark())
	return n

## Sink basin + tap.
static func sink(parent: Node3D, MF, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.0, 0), Vector3(0.6, 0.16, 0.44), MF.metal_dark())
	box_mi(n, Vector3(0, -0.07, 0), Vector3(0.5, 0.06, 0.34), MF.flat(Color(0.05, 0.05, 0.06), 0.4))
	cyl_mi(n, Vector3(0, 0.16, -0.2), 0.018, 0.018, 0.26, MF.metal_dark(), 8)
	cyl_mi(n, Vector3(0, 0.28, -0.12), 0.015, 0.015, 0.18, MF.metal_dark(), 8)
	return n

## Stove: body, oven door, handle, burner rings.
static func stove(parent: Node3D, MF, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.45, 0), Vector3(0.62, 0.9, 0.62), MF.metal_dark())
	box_mi(n, Vector3(0, 0.92, 0), Vector3(0.64, 0.04, 0.64), MF.flat(Color(0.08, 0.08, 0.09), 0.4))
	for i in 4:
		var ox: float = -0.15 + float(i % 2) * 0.3
		var oz: float = -0.15 + float(i / 2) * 0.3
		var ring := cyl_mi(n, Vector3(ox, 0.945, oz), 0.1, 0.1, 0.01, MF.flat(Color(0.2, 0.2, 0.21), 0.6), 12)
		ring.name = "Burner%d" % i
	box_mi(n, Vector3(0, 0.5, 0.32), Vector3(0.56, 0.5, 0.03), MF.flat(Color(0.1, 0.1, 0.11), 0.5))
	box_mi(n, Vector3(0, 0.72, 0.36), Vector3(0.5, 0.03, 0.03), MF.metal_dark())
	for i in 4:
		cyl_mi(n, Vector3(-0.21 + float(i) * 0.14, 0.78, 0.33), 0.025, 0.025, 0.04, MF.metal_dark(), 8)
	return n

## Sofa: base, cushions, back, arms, legs.
static func sofa(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0, seats: int = 2) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var w: float = 0.85 * float(seats)
	box_mi(n, Vector3(0, 0.22, 0), Vector3(w, 0.3, 0.92), MF.fabric_blue())
	box_mi(n, Vector3(0, 0.6, -0.38), Vector3(w, 0.62, 0.18), MF.fabric_blue())
	box_mi(n, Vector3(-w * 0.5 + 0.09, 0.48, 0), Vector3(0.18, 0.34, 0.92), MF.fabric_blue())
	box_mi(n, Vector3(w * 0.5 - 0.09, 0.48, 0), Vector3(0.18, 0.34, 0.92), MF.fabric_blue())
	for i in seats:
		var cx: float = -w * 0.5 + (float(i) + 0.5) * (w / float(seats))
		box_mi(n, Vector3(cx, 0.42, 0.06), Vector3(w / float(seats) - 0.06, 0.14, 0.78), MF.fabric_blue())
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			cyl_mi(n, Vector3(sx * (w * 0.5 - 0.08), 0.05, sz * 0.38), 0.03, 0.025, 0.1, MF.wood_dark(), 6)
	return n

## Coffee table with lower shelf.
static func coffee_table(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.4, 0), Vector3(1.0, 0.05, 0.55), MF.wood_mid())
	box_mi(n, Vector3(0, 0.16, 0), Vector3(0.88, 0.03, 0.45), MF.wood_dark())
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box_mi(n, Vector3(sx * 0.45, 0.19, sz * 0.23), Vector3(0.05, 0.38, 0.05), MF.wood_dark())
	return n

## Picture frame on wall with photo/paper insert.
static func frame(parent: Node3D, MF, pos: Vector3, w: float, h: float, rot_y: float = 0.0, insert: Material = null) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0, 0), Vector3(w, h, 0.035), MF.wood_dark())
	var fill: Material = insert if insert != null else MF.paper()
	box_mi(n, Vector3(0, 0, 0.02), Vector3(w - 0.06, h - 0.06, 0.012), fill)
	return n

## Bed: frame, mattress, pillows, duvet.
static func bed(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.16, 0), Vector3(1.0, 0.22, 2.0), MF.wood_dark())
	box_mi(n, Vector3(0, 0.62, -0.95), Vector3(1.0, 0.7, 0.08), MF.wood_mid())
	box_mi(n, Vector3(0, 0.36, 0.02), Vector3(0.96, 0.2, 1.9), MF.flat(Color(0.82, 0.8, 0.76), 0.9))
	box_mi(n, Vector3(0, 0.44, 0.24), Vector3(0.98, 0.1, 1.5), MF.fabric_blue())
	for sx in [-0.22, 0.22]:
		box_mi(n, Vector3(sx, 0.52, -0.72), Vector3(0.4, 0.12, 0.28), MF.flat(Color(0.9, 0.89, 0.86), 0.9))
	return n

## Desk with drawers and legs.
static func desk(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.74, 0), Vector3(1.2, 0.05, 0.6), MF.wood_mid())
	box_mi(n, Vector3(-0.42, 0.5, 0), Vector3(0.34, 0.44, 0.55), MF.wood_dark())
	for i in 3:
		box_mi(n, Vector3(-0.42, 0.32 + float(i) * 0.14, 0.285), Vector3(0.3, 0.11, 0.02), MF.wood_mid())
		box_mi(n, Vector3(-0.42, 0.32 + float(i) * 0.14, 0.31), Vector3(0.12, 0.02, 0.02), MF.metal_dark())
	for sz in [-0.24, 0.24]:
		box_mi(n, Vector3(0.5, 0.36, sz), Vector3(0.05, 0.72, 0.05), MF.wood_dark())
	return n

## Chair with seat, back, four legs.
static func chair(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.44, 0), Vector3(0.42, 0.05, 0.42), MF.wood_mid())
	box_mi(n, Vector3(0, 0.68, -0.19), Vector3(0.4, 0.44, 0.04), MF.wood_mid())
	for sx in [-0.17, 0.17]:
		for sz in [-0.17, 0.17]:
			box_mi(n, Vector3(sx, 0.22, sz), Vector3(0.04, 0.44, 0.04), MF.wood_dark())
	return n

## Bookshelf with individual books.
static func bookshelf(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0, shelves: int = 4) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var w := 0.8
	var h := 1.7
	box_mi(n, Vector3(-w * 0.5, h * 0.5, -0.14), Vector3(0.03, h, 0.28), MF.wood_dark())
	box_mi(n, Vector3(w * 0.5, h * 0.5, -0.14), Vector3(0.03, h, 0.28), MF.wood_dark())
	box_mi(n, Vector3(0, h - 0.02, -0.14), Vector3(w, 0.04, 0.28), MF.wood_dark())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var palette := [Color(0.42, 0.2, 0.16), Color(0.2, 0.26, 0.36), Color(0.34, 0.3, 0.2), Color(0.26, 0.3, 0.26), Color(0.44, 0.34, 0.22)]
	for s in shelves:
		var y: float = 0.08 + float(s) * (h - 0.2) / float(shelves)
		box_mi(n, Vector3(0, y, -0.14), Vector3(w, 0.03, 0.28), MF.wood_dark())
		var x: float = -w * 0.5 + 0.06
		while x < w * 0.5 - 0.08:
			var bw: float = rng.randf_range(0.025, 0.05)
			var bh: float = rng.randf_range(0.18, 0.3)
			var col: Color = palette[rng.randi() % palette.size()]
			box_mi(n, Vector3(x + bw * 0.5, y + bh * 0.5 + 0.015, -0.13), Vector3(bw, bh, rng.randf_range(0.14, 0.22)), MF.flat(col, 0.85))
			x += bw + 0.006
	return n

## Cardboard box with open flaps.
static func cardboard_box(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0, open: bool = true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var card: StandardMaterial3D = MF.flat(Color(0.52, 0.42, 0.3), 0.92)
	box_mi(n, Vector3(0, 0.2, 0), Vector3(0.5, 0.4, 0.36), card)
	if open:
		var flap := box_mi(n, Vector3(0, 0.42, -0.2), Vector3(0.5, 0.02, 0.2), card)
		flap.rotation.x = deg_to_rad(-70.0)
		var flap2 := box_mi(n, Vector3(0, 0.42, 0.2), Vector3(0.5, 0.02, 0.2), card)
		flap2.rotation.x = deg_to_rad(70.0)
	else:
		box_mi(n, Vector3(0, 0.41, 0), Vector3(0.52, 0.02, 0.38), card)
	return n

## Ceramic cup with handle + liquid disc.
static func cup(parent: Node3D, MF, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var c: StandardMaterial3D = MF.flat(Color(0.88, 0.86, 0.82), 0.35)
	cyl_mi(n, Vector3.ZERO, 0.045, 0.038, 0.09, c, 14)
	cyl_mi(n, Vector3(0, 0.045, 0), 0.04, 0.04, 0.004, MF.flat(Color(0.28, 0.16, 0.07), 0.25), 14)
	var h := cyl_mi(n, Vector3(0.052, 0.005, 0), 0.012, 0.012, 0.05, c, 8)
	h.rotation.z = deg_to_rad(90.0)
	return n

## Old radio: body, speaker grille, dials, antenna.
static func radio(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var body: StandardMaterial3D = MF.flat(Color(0.34, 0.24, 0.15), 0.6)
	box_mi(n, Vector3(0, 0.11, 0), Vector3(0.42, 0.22, 0.16), body)
	box_mi(n, Vector3(-0.08, 0.11, 0.081), Vector3(0.2, 0.15, 0.01), MF.flat(Color(0.12, 0.1, 0.08), 0.9))
	for i in 5:
		box_mi(n, Vector3(-0.08, 0.05 + float(i) * 0.028, 0.088), Vector3(0.18, 0.008, 0.008), MF.metal_dark())
	for i in 2:
		cyl_mi(n, Vector3(0.11, 0.15 - float(i) * 0.09, 0.085), 0.022, 0.022, 0.03, MF.metal_dark(), 10)
	var ant := cyl_mi(n, Vector3(0.17, 0.34, -0.04), 0.005, 0.005, 0.36, MF.metal_dark(), 6)
	ant.rotation.z = deg_to_rad(-16.0)
	return n

## Key: ring, shaft, teeth.
static func key_prop(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var m: StandardMaterial3D = MF.metal_dark()
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.014
	tm.outer_radius = 0.032
	tm.rings = 8
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = m
	ring.rotation.x = deg_to_rad(90.0)
	ring.position = Vector3(0, 0, 0.05)
	n.add_child(ring)
	box_mi(n, Vector3(0, 0, -0.04), Vector3(0.016, 0.016, 0.11), m)
	for i in 2:
		box_mi(n, Vector3(0.012, 0, -0.075 - float(i) * 0.022), Vector3(0.026, 0.012, 0.012), m)
	return n

## Wall clock with face, rim and hands on centre pivots (named HourHand, MinuteHand,
## SecondHand) so they can be animated. Shows 02:17. Front faces local +Z.
static func wall_clock(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "WallClock"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var rim := cyl_mi(n, Vector3.ZERO, 0.17, 0.17, 0.05, MF.wood_dark(), 24)
	rim.rotation.x = deg_to_rad(90.0)
	var face := cyl_mi(n, Vector3(0, 0, 0.026), 0.15, 0.15, 0.01, MF.paper(), 24)
	face.rotation.x = deg_to_rad(90.0)
	var ink: Material = MF.flat(Color(0.08, 0.08, 0.09))
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		var tick := box_mi(n, Vector3(sin(a) * 0.125, cos(a) * 0.125, 0.033), Vector3(0.012 if i % 3 else 0.018, 0.028, 0.004), ink)
		tick.rotation.z = -a
	# Hands: each a pivot at the centre, rotation.z = -angle (clockwise seen from the front).
	for h in [["HourHand", 0.085, 0.016, 0.036, (2.0 + 17.0 / 60.0) * 30.0, ink],
			["MinuteHand", 0.125, 0.011, 0.038, 17.0 * 6.0, ink],
			["SecondHand", 0.13, 0.004, 0.040, 0.0, MF.flat(Color(0.6, 0.12, 0.1))]]:
		var pivot := Node3D.new()
		pivot.name = str(h[0])
		pivot.position = Vector3(0, 0, float(h[3]))
		pivot.rotation.z = -deg_to_rad(float(h[4]))
		n.add_child(pivot)
		box_mi(pivot, Vector3(0, float(h[1]) * 0.5 - 0.015, 0), Vector3(float(h[2]), float(h[1]), 0.004), h[5])
	cyl_mi(n, Vector3(0, 0, 0.043), 0.01, 0.01, 0.006, ink, 10).rotation.x = deg_to_rad(90.0)
	return n

## Potted plant: pot + a few leaf blobs.
static func potted_plant(parent: Node3D, MF, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cyl_mi(n, Vector3(0, 0.13, 0), 0.16, 0.12, 0.26, MF.flat(Color(0.36, 0.22, 0.16), 0.9), 12)
	cyl_mi(n, Vector3(0, 0.26, 0), 0.15, 0.15, 0.02, MF.flat(Color(0.14, 0.1, 0.07), 0.95), 12)
	var leaf: StandardMaterial3D = MF.flat(Color(0.16, 0.3, 0.16), 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 5:
		var a: float = rng.randf() * TAU
		var rad: float = rng.randf_range(0.05, 0.18)
		sphere_mi(n, Vector3(cos(a) * rad, 0.34 + rng.randf() * 0.22, sin(a) * rad), rng.randf_range(0.09, 0.16), leaf, 8)
	return n

## Bathtub.
static func bathtub(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var c: StandardMaterial3D = MF.flat(Color(0.86, 0.86, 0.84), 0.3)
	box_mi(n, Vector3(0, 0.28, 0), Vector3(0.76, 0.56, 1.6), c)
	box_mi(n, Vector3(0, 0.5, 0), Vector3(0.6, 0.16, 1.42), MF.flat(Color(0.7, 0.72, 0.72), 0.35))
	cyl_mi(n, Vector3(0, 0.56, -0.6), 0.02, 0.02, 0.1, MF.metal_dark(), 8)
	return n

## Sink pedestal + basin for the bathroom.
static func pedestal_sink(parent: Node3D, MF, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cyl_mi(n, Vector3(0, 0.4, 0), 0.08, 0.11, 0.8, MF.paper(), 12)
	cyl_mi(n, Vector3(0, 0.84, 0), 0.24, 0.2, 0.14, MF.paper(), 16)
	cyl_mi(n, Vector3(0, 0.9, 0), 0.02, 0.02, 0.16, MF.metal_dark(), 8)
	return n

## Water pump for the basement.
static func pump(parent: Node3D, MF, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	cyl_mi(n, Vector3(0, 0.25, 0), 0.14, 0.16, 0.5, MF.metal_dark(), 12)
	cyl_mi(n, Vector3(0.16, 0.34, 0), 0.06, 0.06, 0.34, MF.metal_dark(), 10)
	cyl_mi(n, Vector3(-0.18, 0.06, 0), 0.07, 0.07, 0.16, MF.metal_dark(), 10)
	box_mi(n, Vector3(0.16, 0.52, 0), Vector3(0.14, 0.03, 0.03), MF.metal_dark())
	return n

## Shelf with boxes/jars (basement clutter).
static func storage_shelf(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0, levels: int = 3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var w := 1.1
	var h := 1.5
	for sx in [-1.0, 1.0]:
		box_mi(n, Vector3(sx * w * 0.5, h * 0.5, 0), Vector3(0.05, h, 0.4), MF.metal_dark())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for l in levels:
		var y: float = 0.25 + float(l) * (h - 0.4) / float(levels - 1)
		box_mi(n, Vector3(0, y, 0), Vector3(w, 0.04, 0.4), MF.metal_dark())
		var x: float = -w * 0.5 + 0.14
		while x < w * 0.5 - 0.1:
			var bw: float = rng.randf_range(0.14, 0.26)
			if rng.randf() < 0.5:
				box_mi(n, Vector3(x + bw * 0.5, y + 0.12, 0), Vector3(bw, 0.2, 0.3), MF.flat(Color(0.44, 0.36, 0.26), 0.9))
			else:
				cyl_mi(n, Vector3(x + bw * 0.5, y + 0.11, 0), 0.06, 0.07, 0.18, MF.flat(Color(0.3, 0.32, 0.3), 0.7), 10)
			x += bw + 0.05
	return n

## Towering wall clock / radiator detail: simple radiator for corridors.
static func radiator(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var c: StandardMaterial3D = MF.paint_metal()
	box_mi(n, Vector3(0, 0.3, 0), Vector3(0.7, 0.5, 0.1), c)
	for i in 7:
		box_mi(n, Vector3(-0.3 + float(i) * 0.1, 0.3, 0.055), Vector3(0.045, 0.46, 0.02), c)
	return n

# ------------------------------------------------------------------ architecture
## Window set into a real wall opening. pos = centre of the opening (in the wall
## mid-plane), rot_y = 0 for a wall running along X (normal +-Z), 90 for walls along Z.
## Adds trim on both faces, a lining for the reveal, a sill, glass and a sash.
static func window_in_wall(parent: Node3D, MF, pos: Vector3, w: float, h: float, t: float, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Window"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var trim: Material = MF.wood_trim()
	var tw := 0.07
	for side in [-1.0, 1.0]:
		var z: float = side * (t * 0.5 + 0.012)
		box_mi(n, Vector3(-w * 0.5 - tw * 0.5, 0, z), Vector3(tw, h + tw * 2.0, 0.025), trim)
		box_mi(n, Vector3(w * 0.5 + tw * 0.5, 0, z), Vector3(tw, h + tw * 2.0, 0.025), trim)
		box_mi(n, Vector3(0, h * 0.5 + tw * 0.5, z), Vector3(w + tw * 2.0, tw, 0.025), trim)
		box_mi(n, Vector3(0, -h * 0.5 - 0.03, side * (t * 0.5 + 0.04)), Vector3(w + 0.16, 0.04, 0.08), trim)
	# reveal lining
	box_mi(n, Vector3(-w * 0.5 + 0.01, 0, 0), Vector3(0.02, h, t), trim)
	box_mi(n, Vector3(w * 0.5 - 0.01, 0, 0), Vector3(0.02, h, t), trim)
	box_mi(n, Vector3(0, h * 0.5 - 0.01, 0), Vector3(w, 0.02, t), trim)
	box_mi(n, Vector3(0, -h * 0.5 + 0.01, 0), Vector3(w, 0.02, t), trim)
	# sash + glass
	var sash: Material = MF.flat(Color(0.82, 0.8, 0.74), 0.6)
	box_mi(n, Vector3(0, 0, 0), Vector3(w - 0.04, h - 0.04, 0.012), MF.glass_mat())
	box_mi(n, Vector3(0, 0, 0), Vector3(0.04, h - 0.04, 0.05), sash)
	box_mi(n, Vector3(0, h * 0.08, 0), Vector3(w - 0.04, 0.04, 0.05), sash)
	for sx in [-1.0, 1.0]:
		box_mi(n, Vector3(sx * (w * 0.5 - 0.04), 0, 0), Vector3(0.04, h - 0.04, 0.05), sash)
	box_mi(n, Vector3(0, h * 0.5 - 0.04, 0), Vector3(w - 0.04, 0.04, 0.05), sash)
	box_mi(n, Vector3(0, -h * 0.5 + 0.04, 0), Vector3(w - 0.04, 0.04, 0.05), sash)
	return n

## Casing on both faces of a doorway plus the reveal lining. pos = bottom-centre.
static func doorway_trim(parent: Node3D, MF, pos: Vector3, w: float, h: float, t: float, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Doorway"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var trim: Material = MF.wood_trim()
	for side in [-1.0, 1.0]:
		var z: float = side * (t * 0.5 + 0.012)
		box_mi(n, Vector3(-w * 0.5 - 0.045, h * 0.5 + 0.03, z), Vector3(0.09, h + 0.06, 0.025), trim)
		box_mi(n, Vector3(w * 0.5 + 0.045, h * 0.5 + 0.03, z), Vector3(0.09, h + 0.06, 0.025), trim)
		box_mi(n, Vector3(0, h + 0.045, z), Vector3(w + 0.18, 0.09, 0.025), trim)
	box_mi(n, Vector3(-w * 0.5 + 0.01, h * 0.5, 0), Vector3(0.02, h, t), trim)
	box_mi(n, Vector3(w * 0.5 - 0.01, h * 0.5, 0), Vector3(0.02, h, t), trim)
	box_mi(n, Vector3(0, h - 0.01, 0), Vector3(w, 0.02, t), trim)
	return n

# ------------------------------------------------------------------ kitchen / bath
## Sink dropped into a worktop. pos = worktop surface at the sink centre.
static func counter_sink(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "CounterSink"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var steel: StandardMaterial3D = MF.flat(Color(0.62, 0.63, 0.64), 0.28, 0.6)
	box_mi(n, Vector3(0, 0.006, 0), Vector3(0.62, 0.012, 0.46), steel)
	box_mi(n, Vector3(0, 0.0125, 0.02), Vector3(0.5, 0.002, 0.34), MF.flat(Color(0.12, 0.12, 0.13), 0.35, 0.4))
	cyl_mi(n, Vector3(0, 0.13, -0.19), 0.016, 0.02, 0.26, steel, 10)
	var spout := cyl_mi(n, Vector3(0, 0.25, -0.12), 0.013, 0.013, 0.16, steel, 8)
	spout.rotation_degrees.x = 90.0
	for sx in [-0.09, 0.09]:
		cyl_mi(n, Vector3(sx, 0.04, -0.19), 0.022, 0.022, 0.05, steel, 8)
	return n

## Cast-iron style bathtub (long side along X when rot_y=0).
static func bathtub2(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0, length: float = 1.6) -> Node3D:
	var n := Node3D.new()
	n.name = "Bathtub"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var enamel: StandardMaterial3D = MF.flat(Color(0.9, 0.9, 0.88), 0.22)
	var inner: StandardMaterial3D = MF.flat(Color(0.78, 0.8, 0.8), 0.18)
	var d := 0.74
	box_mi(n, Vector3(0, 0.31, 0), Vector3(length, 0.44, d), enamel)
	box_mi(n, Vector3(0, 0.555, 0), Vector3(length + 0.04, 0.05, d + 0.04), enamel)
	box_mi(n, Vector3(0, 0.582, 0), Vector3(length - 0.16, 0.004, d - 0.16), inner)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var f := sphere_mi(n, Vector3(sx * (length * 0.5 - 0.12), 0.06, sz * (d * 0.5 - 0.1)), 0.06, MF.metal_dark(), 8)
			f.scale = Vector3(1, 1.0, 1)
	var steel: StandardMaterial3D = MF.flat(Color(0.7, 0.7, 0.72), 0.25, 0.7)
	cyl_mi(n, Vector3(-length * 0.5 + 0.12, 0.71, -d * 0.5 + 0.06), 0.015, 0.015, 0.26, steel, 8)
	var sp := cyl_mi(n, Vector3(-length * 0.5 + 0.19, 0.83, -d * 0.5 + 0.06), 0.013, 0.013, 0.14, steel, 8)
	sp.rotation_degrees.z = 90.0
	return n

## Toilet: pedestal, bowl, seat, cistern (front faces +Z).
static func toilet(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Toilet"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	var c: StandardMaterial3D = MF.flat(Color(0.92, 0.92, 0.9), 0.2)
	cyl_mi(n, Vector3(0, 0.18, 0.05), 0.12, 0.15, 0.36, c, 16)
	var bowl := cyl_mi(n, Vector3(0, 0.36, 0.1), 0.2, 0.15, 0.12, c, 18)
	bowl.scale = Vector3(1, 1, 1.25)
	var seat := cyl_mi(n, Vector3(0, 0.433, 0.1), 0.2, 0.2, 0.025, MF.flat(Color(0.95, 0.94, 0.92), 0.35), 18)
	seat.scale = Vector3(1, 1, 1.25)
	box_mi(n, Vector3(0, 0.62, -0.2), Vector3(0.42, 0.38, 0.18), c)
	box_mi(n, Vector3(0, 0.825, -0.2), Vector3(0.44, 0.03, 0.2), c)
	box_mi(n, Vector3(0.14, 0.76, -0.105), Vector3(0.06, 0.02, 0.02), MF.metal_dark())
	return n

## Flat rug / runner with a darker border.
static func rug(parent: Node3D, MF, pos: Vector3, w: float, d: float, col: Color, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Rug"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.004, 0), Vector3(w, 0.008, d), MF.flat(col.darkened(0.35), 0.97))
	box_mi(n, Vector3(0, 0.0095, 0), Vector3(w - 0.14, 0.003, d - 0.14), MF.flat(col, 0.97))
	return n

## Mattress, folded duvet and pillow (head at -Z when rot_y=0). pos = top of the springs.
static func bedding(parent: Node3D, MF, pos: Vector3, w: float, l: float, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Bedding"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.08, 0), Vector3(w - 0.04, 0.16, l - 0.06), MF.flat(Color(0.78, 0.76, 0.72), 0.95))
	box_mi(n, Vector3(0, 0.185, l * 0.16), Vector3(w, 0.05, l * 0.62), MF.fabric_blue())
	box_mi(n, Vector3(0, 0.215, -l * 0.15), Vector3(w + 0.01, 0.03, 0.2), MF.flat(Color(0.86, 0.85, 0.82), 0.9))
	var p := box_mi(n, Vector3(0, 0.22, -l * 0.5 + 0.22), Vector3(w * 0.7, 0.11, 0.32), MF.flat(Color(0.9, 0.89, 0.86), 0.9))
	p.rotation_degrees.x = -8.0
	return n

## Small photograph lying flat in a thin frame. pos = surface.
static func photo_flat(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "PhotoFlat"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.006, 0), Vector3(0.22, 0.012, 0.17), MF.wood_dark())
	box_mi(n, Vector3(0, 0.0125, 0), Vector3(0.18, 0.002, 0.13), MF.flat(Color(0.55, 0.5, 0.44), 0.6))
	return n

## Sheet(s) of paper lying on a surface. pos = surface.
static func papers(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0, count: int = 2) -> Node3D:
	var n := Node3D.new()
	n.name = "Papers"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	for i in count:
		var s := box_mi(n, Vector3(float(i) * 0.02, 0.002 + float(i) * 0.002, float(i) * -0.015), Vector3(0.21, 0.002, 0.29), MF.paper())
		s.rotation_degrees.y = float(i) * 9.0
	return n

## Cassette tape lying flat. pos = surface.
static func cassette(parent: Node3D, MF, pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = "Cassette"
	n.position = pos
	n.rotation_degrees.y = rot_y
	parent.add_child(n)
	box_mi(n, Vector3(0, 0.007, 0), Vector3(0.1, 0.014, 0.064), MF.flat(Color(0.08, 0.08, 0.09), 0.5))
	box_mi(n, Vector3(0, 0.0145, 0.004), Vector3(0.08, 0.002, 0.034), MF.paper())
	return n
