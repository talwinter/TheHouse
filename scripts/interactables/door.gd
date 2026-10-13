extends StaticBody3D
## Working door: locked (needs clue) → swing open, collision off. Fires event_id.

const MFScript := preload("res://scripts/core/material_factory.gd")

@export var title: String = "Door"
@export var locked: bool = false
@export var required_clue: String = ""
@export var locked_hint: String = "Locked. Something small and brass should fit."
@export var event_id: String = ""
@export var door_w: float = 1.1
@export var door_h: float = 2.1
@export var swing_deg: float = 100.0
## Clue added when the player tries this door while it is locked (e.g. the back door).
@export var inspect_clue: String = ""

var is_open := false
var _closed_rot := 0.0
var _col: CollisionShape3D
var _leaf: MeshInstance3D
var _busy := false

## `position` is given as the centre of the opening; the body is moved onto the
## hinge edge (local -X side) so the leaf swings like a real door.
func _ready() -> void:
	position -= basis.x.normalized() * door_w * 0.5
	_closed_rot = rotation_degrees.y
	_leaf = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(door_w - 0.01, door_h, 0.05)
	_leaf.mesh = bm
	_leaf.position = Vector3(door_w * 0.5, 0, 0)
	_leaf.material_override = MFScript.wood_dark()
	add_child(_leaf)
	# raised panels on both faces
	for side in [-1.0, 1.0]:
		for py in [0.24, -0.22]:
			var pnl := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(door_w * 0.7, door_h * 0.36, 0.012)
			pnl.mesh = pm
			pnl.position = Vector3(door_w * 0.5, door_h * py, side * 0.03)
			pnl.material_override = MFScript.wood_mid()
			add_child(pnl)
	for side in [-1.0, 1.0]:
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		knob.mesh = sm
		knob.position = Vector3(door_w - 0.09, -door_h * 0.02, side * 0.07)
		knob.material_override = MFScript.metal_dark()
		add_child(knob)
	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(door_w, door_h, 0.14)
	_col.shape = shape
	_col.position = Vector3(door_w * 0.5, 0, 0)
	add_child(_col)

func interact() -> void:
	if _busy:
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	if locked and required_clue != "":
		var has: bool = false
		if gm != null and gm.has_method("has_clue"):
			has = bool(gm.call("has_clue", required_clue))
		if not has:
			_toast(locked_hint)
			if inspect_clue != "" and gm != null and gm.has_method("add_clue"):
				gm.call("add_clue", inspect_clue)
			var am0: Node = get_node_or_null("/root/AudioManager")
			if am0 != null:
				am0.call("play_latch", global_position)
			return
		unlock_open()
		return
	_busy = true
	is_open = not is_open
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_door"):
		am.call("play_door", not is_open, global_position)
	var tw := create_tween()
	var target: float = _closed_rot + (swing_deg if is_open else 0.0)
	tw.tween_property(self, "rotation_degrees:y", target, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_on_swing_done)
	var em: Node = get_node_or_null("/root/EventManager")
	# Doors can be used many times, so their event fires on every opening (not one-shot).
	if is_open and event_id != "" and em != null and em.has_method("fire_always"):
		em.call("fire_always", event_id)

## Restores a saved state without animation or events.
func set_open_instant(open: bool) -> void:
	locked = false
	is_open = open
	rotation_degrees.y = _closed_rot + (swing_deg if open else 0.0)
	if _col != null:
		_col.disabled = open

func unlock_open() -> void:
	locked = false
	_toast("The small key turns.")
	interact()

func _on_swing_done() -> void:
	_busy = false
	if _col != null:
		_col.set_deferred("disabled", is_open)

func _toast(t: String) -> void:
	var hs: Array = get_tree().get_nodes_in_group("hud")
	if hs.size() > 0 and hs[0].has_method("toast"):
		hs[0].call("toast", t)
