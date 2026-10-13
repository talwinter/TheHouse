extends StaticBody3D
## Uniform inspectable. Place CollisionShape3D + MeshInstance3D as children.

@export var title: String = "Object"
@export_multiline var body_text: String = "..."
@export var clue_id: String = ""
@export var event_id: String = ""
@export var tape_id: String = ""
@export var one_shot_text: String = ""

var _inspected: bool = false

func interact() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if clue_id != "" and gm != null and gm.has_method("add_clue"):
		gm.call("add_clue", clue_id)
	var em: Node = get_node_or_null("/root/EventManager")
	if event_id != "" and em != null and em.has_method("fire"):
		em.call("fire", event_id)
	if one_shot_text != "" and _inspected:
		body_text = one_shot_text
	_inspected = true
	if tape_id != "":
		var hs: Array = get_tree().get_nodes_in_group("hud")
		if hs.size() > 0 and hs[0].has_method("show_tape"):
			hs[0].call("show_tape", tape_id)
