extends Node
## EventManager: one-shot story triggers. Autoload.

signal event_fired(event_id: String)

var _fired: Dictionary = {}

func fire(event_id: String) -> void:
	if _fired.get(event_id, false):
		return
	_fired[event_id] = true
	event_fired.emit(event_id)

## Re-triggerable event (e.g. a door that can be used many times). Still marks it fired.
func fire_always(event_id: String) -> void:
	_fired[event_id] = true
	event_fired.emit(event_id)

func was_fired(event_id: String) -> bool:
	return _fired.get(event_id, false)

## Events that must not survive a save (re-armed on load).
const TRANSIENT := ["show_endings", "front_door"]

func get_state() -> Array:
	var out: Array = []
	for k in _fired.keys():
		if _fired[k] and not TRANSIENT.has(k):
			out.append(k)
	return out

func apply_state(ids: Array) -> void:
	_fired.clear()
	for k in ids:
		_fired[str(k)] = true

func unfire(event_id: String) -> void:
	_fired.erase(event_id)

func reset_all() -> void:
	_fired.clear()
