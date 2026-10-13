extends CharacterBody3D
## Smooth first-person, no aggressive bob. Uses InputMap.

@export var walk_speed: float = 2.6
@export var sprint_mult: float = 1.6

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/InteractRay

var _yaw: float = 0.0
var _pitch: float = 0.0
var _spawn: Vector3 = Vector3.ZERO
var _fall_guard: int = 0

func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	_yaw = rotation.y
	if ray != null:
		ray.collision_mask = 1 | 2   # world (1) + clue targets (2)
	_spawn = global_position
	_fall_guard = 0
	if camera != null:
		_pitch = camera.rotation.x
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Safety net: never let the player fall out of the world.
func _check_fall() -> void:
	_fall_guard += 1
	if global_position.y > -6.0:
		_fall_guard = 0
		return
	if _fall_guard > 20:
		_fall_guard = 0
		global_position = _spawn
		velocity = Vector3.ZERO
		var hs: Array = get_tree().get_nodes_in_group("hud")
		if hs.size() > 0 and hs[0].has_method("toast"):
			hs[0].call("toast", "...")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED \
			and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.0025
		if get_node_or_null("/root/GameManager") != null:
			sens = float(get_node("/root/GameManager").get("settings").get("mouse_sensitivity", 0.0025))
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens, -1.2, 1.2)
		rotation.y = _yaw
		camera.rotation.x = _pitch
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("journal"):
		_toggle_journal()

func _physics_process(delta: float) -> void:
	var dir2 := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed: float = walk_speed
	if Input.is_action_pressed("sprint"):
		speed *= sprint_mult
	var fwd: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	fwd.y = 0.0
	right.y = 0.0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()
	if right.length() > 0.01:
		right = right.normalized()
	var wish: Vector3 = (right * dir2.x + fwd * -dir2.y) * speed
	velocity.x = lerpf(velocity.x, wish.x, 1.0 - exp(-10.0 * delta))
	velocity.z = lerpf(velocity.z, wish.z, 1.0 - exp(-10.0 * delta))
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
		if wish.length() > 0.5:
			var am: Node = get_node_or_null("/root/AudioManager")
			if am != null and am.has_method("play_step"):
				am.call("play_step")
	move_and_slide()
	_check_fall()

func current_focus() -> Node:
	if ray != null and ray.is_colliding():
		var c: Object = ray.get_collider()
		if c is Node and (c as Node).has_method("interact"):
			return c as Node
	return null

func _get_hud() -> Node:
	var hs: Array = get_tree().get_nodes_in_group("hud")
	if hs.size() > 0:
		return hs[0]
	var cs: Node = get_tree().current_scene
	if cs != null:
		if cs.get("hud") != null:
			return cs.get("hud") as Node
		var h: Node = cs.get_node_or_null("HUD")
		if h != null:
			return h
	return null

func _try_interact() -> void:
	var hud: Node = _get_hud()
	var target: Node = current_focus()
	if target != null:
		target.call("interact")
		# Doors have no inspect text and tapes open their own transcript panel.
		var body: Variant = target.get("body_text")
		var tape: String = str(target.get("tape_id")) if target.get("tape_id") != null else ""
		if body != null and str(body) != "" and tape == "" and hud != null and hud.has_method("show_inspect"):
			hud.call("show_inspect", str(target.get("title")), str(target.get("body_text")))
	elif hud != null and hud.has_method("hide_inspect"):
		hud.call("hide_inspect")

func _toggle_journal() -> void:
	var hud: Node = _get_hud()
	if hud != null and hud.has_method("toggle_journal"):
		hud.call("toggle_journal")

func _toggle_pause() -> void:
	if DisplayServer.get_name() != "headless":
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var hud: Node = _get_hud()
	if hud != null and hud.has_method("toggle_pause"):
		hud.call("toggle_pause")
