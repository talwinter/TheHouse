extends RefCounted
## HeroProps: detailed story props, multi-part composites (Blockbench-style, Godot-first).

static func build_key(parent: Node3D, pos: Vector3, mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.02
	tm.outer_radius = 0.05
	ring.mesh = tm
	ring.material_override = mat
	root.add_child(ring)
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 0.14)
	shaft.mesh = bm
	shaft.position = Vector3(0, -0.07, 0.0)
	shaft.material_override = mat
	root.add_child(shaft)
	for i in 2:
		var tooth := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.03, 0.02, 0.02)
		tooth.mesh = tb
		tooth.position = Vector3(0.02, -0.11 - float(i) * 0.03, 0.04)
		tooth.material_override = mat
		root.add_child(tooth)
	return root

static func build_photo_frame(parent: Node3D, pos: Vector3, MF) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.42, 0.32, 0.03)
	frame.mesh = fb
	frame.material_override = MF.wood_dark()
	root.add_child(frame)
	var photo := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.36, 0.26, 0.035)
	photo.mesh = pb
	photo.material_override = MF.paper()
	root.add_child(photo)
	return root

static func build_tape(parent: Node3D, pos: Vector3, MF) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.18, 0.11, 0.03)
	body.mesh = bb
	root.add_child(body)
	for x in [-0.04, 0.04]:
		var reel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.035
		reel.mesh = cm
		reel.rotation_degrees.x = 90
		reel.position = Vector3(x, 0, 0)
		reel.material_override = MF.paper()
		root.add_child(reel)
	return root

static func build_radio(parent: Node3D, pos: Vector3, MF) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.4, 0.22, 0.15)
	body.mesh = bb
	body.material_override = MF.metal_dark()
	root.add_child(body)
	var ant := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.5
	ant.mesh = cm
	ant.position = Vector3(0.15, 0.32, 0)
	ant.rotation_degrees.z = -18
	root.add_child(ant)
	for i in 2:
		var knob := MeshInstance3D.new()
		var kb := CylinderMesh.new()
		kb.top_radius = 0.02
		kb.bottom_radius = 0.02
		kb.height = 0.03
		knob.mesh = kb
		knob.rotation_degrees.x = 90
		knob.position = Vector3(-0.1 + float(i) * 0.08, -0.04, 0.09)
		root.add_child(knob)
	return root

static func build_box(parent: Node3D, pos: Vector3, MF) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var base := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.5, 0.3, 0.35)
	base.mesh = bb
	base.material_override = MF.wood_mid()
	root.add_child(base)
	var lid := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.52, 0.05, 0.37)
	lid.mesh = lb
	lid.position = Vector3(0, 0.17, 0)
	lid.material_override = MF.wood_dark()
	root.add_child(lid)
	return root
