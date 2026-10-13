extends Node
## AudioManager: buses, sound effects, rain occlusion, captions and TTS narration. Autoload.
##
## Voices use Godot's built-in text-to-speech (DisplayServer.tts_*): on Windows desktop
## that is the OS voices, in a browser it is the browser's voices (Edge ships natural
## neural voices). Nothing is pre-rendered or shipped, so there is no voice licence to
## track. TTS bypasses the audio buses, so its volume comes from the Story setting.

signal caption(text: String, seconds: float)
signal narration_finished

const BUSES := ["Ambience", "Foley", "Story", "Music", "UI"]
const FEMALE := ["aria", "jenny", "zira", "michelle", "sonia", "libby", "ana", "emma", "ava", "hazel", "susan", "natasha", "clara", "sara", "jane", "nancy", "amber", "ashley", "cora", "elizabeth", "monica", "samantha", "karen", "moira", "tessa", "fiona", "female", "hila"]
const MALE := ["guy", "david", "mark", "ryan", "christopher", "eric", "roger", "steffan", "andrew", "brian", "davis", "tony", "jason", "william", "thomas", "daniel", "alex", "fred", "george", "male", "asaf", "avri"]
## Character voice table: gender, which voice of that gender (0 = best), pitch, rate, volume scale.
const CAST := {
	"noa": ["f", 0, 1.05, 1.0, 1.0],
	"miriam": ["f", 1, 0.88, 0.92, 1.0],
	"yoav": ["m", 0, 0.92, 0.92, 1.0],
	"man": ["m", 1, 0.78, 0.85, 0.75],
	"whisper": ["f", 1, 1.0, 0.85, 0.4],
}

var muted := false
var _rain_player: AudioStreamPlayer
var _static_player: AudioStreamPlayer
var _step_timer: float = 0.0
var _occl_timer: float = 0.0
var _rain_target_db: float = -14.0
var _rain_target_cut: float = 900.0
var _lowpass: AudioEffectLowPassFilter
var _narr_token := 0
var _narrating := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for b in BUSES:
		_ensure_bus(b)
	for rv in [["ReverbBasement", 0.85, 0.6, 0.35], ["ReverbTile", 0.35, 0.3, 0.55]]:
		_ensure_bus(str(rv[0]))
		var bi: int = AudioServer.get_bus_index(str(rv[0]))
		if AudioServer.get_bus_effect_count(bi) == 0:
			var r := AudioEffectReverb.new()
			r.room_size = float(rv[1])
			r.damping = float(rv[2])
			r.spread = 0.8
			r.dry = 0.0
			r.wet = float(rv[3]) + 0.4
			AudioServer.add_bus_effect(bi, r)
	var amb: int = AudioServer.get_bus_index("Ambience")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 900.0
	AudioServer.add_bus_effect(amb, _lowpass)
	apply_settings(_settings())
	start_ambience()

func _settings() -> Dictionary:
	var gm: Node = get_node_or_null("/root/GameManager")
	return gm.get("settings") if gm != null else {}

func set_muted(v: bool) -> void:
	muted = v
	if _rain_player != null:
		if v:
			_rain_player.stop()
		elif not _rain_player.playing:
			_rain_player.play()

func _skip() -> bool:
	return muted

# ---------------------------------------------------------------- buses
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)

func apply_settings(s: Dictionary) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(s.get("master_volume", 0.8)), 0.001)))
	var per := {
		"Ambience": float(s.get("ambience_volume", 0.8)),
		"Foley": float(s.get("sfx_volume", 0.8)),
		"UI": float(s.get("sfx_volume", 0.8)),
		"Story": float(s.get("story_volume", 0.9)),
		"Music": float(s.get("music_volume", 0.6)),
	}
	for b in per.keys():
		var i: int = AudioServer.get_bus_index(b)
		if i != -1:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(per[b]), 0.001)))

# ---------------------------------------------------------------- ambience + occlusion
func start_ambience() -> void:
	if _rain_player != null:
		return
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = "Ambience"
	_rain_player.stream = _load_loop(["res://assets/audio/ambience/rain_loop.wav", "res://assets/audio/ambience/rain.wav"])
	_rain_player.volume_db = -14.0
	add_child(_rain_player)
	if not muted:
		_rain_player.play()

func _load_loop(paths: Array) -> AudioStream:
	for p in paths:
		if ResourceLoader.exists(p):
			var s: AudioStream = load(p)
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamWAV:
				var w := s as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_end = int(w.get_length() * w.mix_rate)
			return s
	return _make_tone(300.0, 2.0, 0.08, 0.95)

## Rain is loud and open outside, muffled indoors, almost gone in the basement.
func _update_occlusion(delta: float) -> void:
	_occl_timer -= delta
	if _occl_timer <= 0.0:
		_occl_timer = 0.25
		var ps: Array = get_tree().get_nodes_in_group("player")
		if ps.size() > 0 and ps[0] is Node3D:
			var p: Vector3 = (ps[0] as Node3D).global_position
			if p.y < -1.0:
				_rain_target_db = -24.0
				_rain_target_cut = 450.0
			elif p.z > 5.15 or p.z < -5.15 or absf(p.x) > 6.15:
				_rain_target_db = -6.0
				_rain_target_cut = 18000.0
			else:
				_rain_target_db = -15.0
				_rain_target_cut = 850.0
	if _rain_player != null:
		_rain_player.volume_db = lerpf(_rain_player.volume_db, _rain_target_db, clampf(delta * 2.0, 0.0, 1.0))
	if _lowpass != null:
		_lowpass.cutoff_hz = lerpf(_lowpass.cutoff_hz, _rain_target_cut, clampf(delta * 2.0, 0.0, 1.0))

func set_morning() -> void:
	var tw := create_tween()
	tw.tween_property(_rain_player, "volume_db", -40.0, 6.0)
	_rain_target_db = -40.0

func _process(delta: float) -> void:
	_step_timer = maxf(0.0, _step_timer - delta)
	if _rain_target_db > -39.0:
		_update_occlusion(delta)

# ---------------------------------------------------------------- one-shots
## Plays one of `paths` (picked at random, small pitch/level variation), otherwise a
## generated placeholder tone. With a finite `pos` the sound is placed in the world
## (AudioStreamPlayer3D, fades with distance, picks up room reverb).
func _play(paths: Array, bus: String, vol_db: float = 0.0, vary: float = 0.06, fallback: Array = [440.0, 0.2, 0.2, 0.3], pos: Vector3 = Vector3.INF) -> Node:
	if _skip():
		return null
	var stream: AudioStream = null
	var existing: Array = paths.filter(func(x): return ResourceLoader.exists(str(x)))
	if not existing.is_empty():
		stream = load(str(existing[_rng.randi() % existing.size()]))
	else:
		stream = _make_tone(float(fallback[0]), float(fallback[1]), float(fallback[2]), float(fallback[3]))
	var world: Node = get_tree().current_scene
	if pos.is_finite() and world is Node3D:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = bus
		p3.stream = stream
		p3.unit_size = 3.0
		p3.max_distance = 30.0
		p3.pitch_scale = 1.0 + _rng.randf_range(-vary, vary)
		p3.volume_db = vol_db + 4.0 + _rng.randf_range(-2.0, 0.0)
		world.add_child(p3)
		p3.global_position = pos
		p3.play()
		p3.finished.connect(p3.queue_free)
		return p3
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = stream
	p.pitch_scale = 1.0 + _rng.randf_range(-vary, vary)
	p.volume_db = vol_db + _rng.randf_range(-2.0, 0.0)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p

## Every variation of a sound: name_1.ogg, name_2.ogg ... (or .wav). Falls back to
## name.ogg / name.wav. _play() picks one at random.
func _sfx(name: String, count: int = 5) -> Array:
	var out: Array = []
	for i in count:
		out.append("res://assets/audio/sfx/%s_%d.ogg" % [name, i + 1])
		out.append("res://assets/audio/sfx/%s_%d.wav" % [name, i + 1])
	var numbered: Array = out.filter(func(x): return ResourceLoader.exists(str(x)))
	if not numbered.is_empty():
		return numbered
	return ["res://assets/audio/sfx/%s.ogg" % name, "res://assets/audio/sfx/%s.wav" % name]

## Timer that stops while the game is paused (narration waits with the game).
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout

func play_paper() -> void:
	_play(_sfx("paper"), "Foley", -6.0, 0.08, [500.0, 0.3, 0.25, 0.8])

func play_ui() -> void:
	_play(_sfx("ui"), "UI", -10.0, 0.03, [700.0, 0.08, 0.1, 0.25])

func play_door(closing: bool = false, pos: Vector3 = Vector3.INF) -> void:
	_play(_sfx("door_close" if closing else "door"), "Foley", -6.0, 0.05, [90.0, 0.6, 0.3, 0.2], pos)
	if not closing and _rng.randf() < 0.4:
		_play(_sfx("creak"), "Foley", -14.0, 0.08, [90.0, 0.6, 0.3, 0.2], pos)

## A locked door: the latch rattles but does not give.
func play_latch(pos: Vector3 = Vector3.INF) -> void:
	_play(_sfx("latch"), "Foley", -8.0, 0.1, [900.0, 0.05, 0.3, 0.2], pos)
	await get_tree().create_timer(0.14).timeout
	_play(_sfx("latch"), "Foley", -11.0, 0.1, [900.0, 0.05, 0.3, 0.2], pos)

func play_pipe(pos: Vector3 = Vector3.INF, with_caption: bool = true) -> void:
	if with_caption:
		caption.emit("[a pipe knocks inside the wall]", 3.0)
	for i in 2:
		_play(_sfx("pipe"), "Story", -14.0, 0.1, [300.0, 0.1, 0.3, 0.3], pos)
		await get_tree().create_timer(_rng.randf_range(0.25, 0.4)).timeout

func play_buzz() -> void:
	for i in 2:
		_play(_sfx("buzz"), "UI", -8.0, 0.0, [180.0, 0.35, 0.3, 0.3])
		await get_tree().create_timer(0.5).timeout

## Footsteps somewhere else in the house (ch3: upstairs).
func play_steps(pos: Vector3 = Vector3.INF) -> void:
	caption.emit("[footsteps upstairs]", 3.0)
	for i in 4:
		_play(_sfx("step_wood"), "Story", -12.0, 0.08, [95.0, 0.12, 0.25, 0.3], pos + Vector3(float(i) * 0.5, 0, 0) if pos.is_finite() else pos)
		await get_tree().create_timer(_rng.randf_range(0.55, 0.75)).timeout

## A car passing on the wet street: the source actually moves along the road.
func play_car() -> void:
	caption.emit("[a car passes on the wet street]", 3.0)
	var p := _play(_sfx("car"), "Ambience", -6.0, 0.04, [70.0, 2.2, 0.12, 0.3], Vector3(-22.0, 0.6, 15.5))
	if p is AudioStreamPlayer3D:
		(p as AudioStreamPlayer3D).max_distance = 45.0
		var tw := create_tween()
		tw.tween_property(p, "global_position", Vector3(22.0, 0.6, 15.5), 4.5)

func _player_pos() -> Vector3:
	var ps: Array = get_tree().get_nodes_in_group("player")
	return (ps[0] as Node3D).global_position if not ps.is_empty() and ps[0] is Node3D else Vector3.INF

## The player's own footsteps, at their feet (so rooms with reverb colour them).
func play_step(surface: String = "") -> void:
	if _step_timer > 0.0:
		return
	_step_timer = 0.46
	if surface == "":
		surface = _surface_under_player()
	var p: Vector3 = _player_pos()
	_play(_sfx("step_" + surface), "Foley", -21.0, 0.08, [110.0, 0.12, 0.2, 0.18], p + Vector3(0, 0.1, 0) if p.is_finite() else p)

## Floor material under the player, from the house layout (tile in kitchen/bathroom,
## concrete in the basement, stairwell and porch, grass in the yard, rugs are carpet).
func _surface_under_player() -> String:
	var p: Vector3 = _player_pos()
	if not p.is_finite():
		return "wood"
	if p.y < -0.3:
		return "concrete"
	if p.z > 5.15 or p.z < -5.15 or absf(p.x) > 6.15:
		if absf(p.x) < 0.7 or (p.x > 0.4 and p.x < 2.6 and p.z > 5.9 and p.z < 13.8):
			return "concrete"
		return "grass"
	if p.y > 3.0:
		return "wood"
	if p.x < -1.2 and p.z < -1.6:
		return "concrete"   # kitchen tiles
	if p.x < -3.6 and p.z < 0.7:
		return "concrete"   # bathroom tiles
	if p.x > 3.06 and p.z < -3.2:
		return "concrete"   # service room
	if (absf(p.x - 0.9) < 0.5 and p.z > -0.6 and p.z < 3.8) or (absf(p.x + 3.6) < 0.9 and absf(p.z - 2.7) < 0.6):
		return "carpet"
	return "wood"

## Three knocks: the motif. Never exactly the same twice (pitch, level, spacing).
func play_knocks(times: int = 3, faint: bool = false, pos: Vector3 = Vector3.INF, with_caption: bool = true) -> void:
	if with_caption:
		caption.emit("[three knocks]" if times == 3 else "[knocking]", 3.0)
	var base: float = -16.0 if faint else -6.0
	for i in times:
		_play(_sfx("knock"), "Story", base, 0.05, [140.0, 0.18, 0.6, 0.15], pos)
		await get_tree().create_timer(_rng.randf_range(0.38, 0.58)).timeout

func play_static(dur: float = 1.2, pos: Vector3 = Vector3.INF) -> void:
	var p := _play(["res://assets/audio/sfx/static_loop.wav"], "Story", -14.0, 0.0, [440.0, dur, 0.15, 0.9], pos)
	if p != null:
		get_tree().create_timer(dur).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.queue_free())

func _start_static_bed() -> void:
	if _skip():
		return
	if _static_player == null:
		_static_player = AudioStreamPlayer.new()
		_static_player.bus = "Story"
		_static_player.stream = _load_loop(["res://assets/audio/sfx/static_loop.wav", "res://assets/audio/sfx/static.wav"])
		add_child(_static_player)
	_static_player.volume_db = -24.0
	_static_player.play()

func _stop_static_bed() -> void:
	if _static_player != null:
		_static_player.stop()

func _duck_bed(db: float, dur: float) -> void:
	if _static_player != null:
		create_tween().tween_property(_static_player, "volume_db", db, dur)

# ---------------------------------------------------------------- voices (TTS)
func voices_enabled() -> bool:
	return bool(_settings().get("voices", true)) and _tts_ready()

func _tts_ready() -> bool:
	return bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)) \
		and DisplayServer.get_name() != "headless"

## English voices, best first: neural ("Natural"/"Online") voices are preferred.
func _voices(gender: String) -> Array:
	var out: Array = []
	for v in DisplayServer.tts_get_voices():
		var lang: String = str(v.get("language", "")).to_lower()
		if not lang.begins_with("en"):
			continue
		var nm: String = str(v.get("name", "")).to_lower()
		var g := ""
		for f in FEMALE:
			if nm.contains(f):
				g = "f"
		for m in MALE:
			if nm.contains(m):
				g = "m"
		if g != gender:
			continue
		var score := 0
		if nm.contains("natural") or nm.contains("online") or nm.contains("neural"):
			score += 10
		if lang == "en_us" or lang == "en-us":
			score += 2
		out.append([score, str(v.get("id", ""))])
	out.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	return out.map(func(x): return x[1])

func _voice_for(who: String) -> Array:
	var c: Array = CAST.get(who, CAST["noa"])
	var list: Array = _voices(str(c[0]))
	if list.is_empty():
		list = _voices("f") if str(c[0]) == "m" else _voices("m")
	if list.is_empty():
		var all: Array = DisplayServer.tts_get_voices()
		if all.is_empty():
			return ["", 1.0, 1.0, 1.0]
		list = [str(all[0].get("id", ""))]
	var id: String = list[mini(int(c[1]), list.size() - 1)]
	return [id, float(c[2]), float(c[3]), float(c[4])]

func _speaker(prefix: String) -> String:
	var p := prefix.to_lower()
	if p.contains("miriam") or p.contains("mom"):
		return "miriam"
	if p.contains("yoav") or p.contains("dad"):
		return "yoav"
	if p.contains("another voice") or p.contains("barely"):
		return "whisper"
	if p.contains("man"):
		return "man"
	return "noa"

## Stops narration WITHOUT calling DisplayServer.tts_stop(): on Windows that call can
## block the main thread (it froze the game when E was pressed mid-sentence). Lines are
## spoken one sentence at a time, so at most the current sentence finishes on its own.
func stop_narration() -> void:
	_narr_token += 1
	var was: bool = _narrating
	_narrating = false
	_stop_static_bed()
	if was:
		narration_finished.emit()

## Narration timers pause with the game; the TTS engine itself is never paused/resumed
## (same blocking risk as tts_stop).
func pause_narration(_p: bool) -> void:
	pass

func is_narrating() -> bool:
	return _narrating

func _sentences(text: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("[^.!?…]+[.!?…]*\\s*")
	for m in re.search_all(text):
		var s: String = m.get_string().strip_edges()
		if s != "":
			out.append(s)
	return out if not out.is_empty() else [text]

## Speaks text in a character's voice, one sentence per TTS call; returns when done.
func speak(who: String, text: String, vol_scale: float = 1.0) -> void:
	var token := _narr_token
	for s in _sentences(text):
		if token != _narr_token:
			return
		await _speak_one(who, s, token, vol_scale)

func _speak_one(who: String, text: String, token: int, vol_scale: float) -> void:
	var words: int = text.split(" ", false).size()
	var budget: float = 1.0 + float(words) * 0.42
	if not voices_enabled():
		await _wait(budget)
		return
	# A sentence left over from a stopped tape finishes first (it is never cut off).
	var w := 0.0
	while DisplayServer.tts_is_speaking() and w < 8.0:
		await _wait(0.1)
		w += 0.1
	if token != _narr_token:
		return
	var v: Array = _voice_for(who)
	var st: Dictionary = _settings()
	var vol: int = int(clampf(float(st.get("story_volume", 0.9)) * float(st.get("master_volume", 0.8)) * float(v[3]) * vol_scale * 100.0, 0.0, 100.0))
	DisplayServer.tts_speak(text, str(v[0]), vol, float(v[1]), float(v[2]))
	var t := 0.35
	await _wait(0.35)
	while t < budget * 1.6:
		if t > 0.8 and not DisplayServer.tts_is_speaking():
			break
		await _wait(0.1)
		t += 0.1

const _NUMBERS := {"two": 2.0, "three": 3.0, "four": 4.0, "five": 5.0, "six": 6.0}

## One comma/full-stop separated piece of a bracketed cue, e.g. "a chair drags" or
## "four seconds of silence". Starts its sound and returns how long to hold.
func _cue_part(part: String) -> float:
	var p := part.to_lower().strip_edges()
	if p == "":
		return 0.0
	if p.contains("knock"):
		var extra_faint: bool = p.contains("faint") or p.contains("distant")
		play_knocks(3, true, Vector3.INF, false)
		if extra_faint:
			_duck_bed(-30.0, 0.3)
		return 2.4
	if p.contains("same sequence"):
		_play(_sfx("rumble"), "Story", -22.0, 0.05)
		_echo_knocks()
		return 3.0
	if p.contains("silence"):
		var secs := 3.0
		for n in _NUMBERS.keys():
			if p.contains(n):
				secs = _NUMBERS[n]
		if p.contains("long"):
			secs = 4.5
		_duck_bed(-36.0, 0.4)
		get_tree().create_timer(secs, false).timeout.connect(func() -> void: _duck_bed(-24.0, 0.6))
		return secs
	if p.contains("chair") or p.contains("drag"):
		_play(_sfx("chair_drag"), "Story", -9.0, 0.05)
		return 1.6
	if p.contains("storm peak") or p.contains("thunder"):
		_play(_sfx("rumble"), "Story", -6.0, 0.05)
		_rain_swell(-8.0, 3.0)
		return 2.8
	if p.contains("storm") or p.contains("wind") or p.contains("rain") or p.contains("gutter"):
		_rain_swell(-12.0, 2.4)
		return 2.0
	if p.contains("slam") or p.contains("door"):
		_play(_sfx("door_close"), "Story", -14.0, 0.06)
		return 1.4
	if p.contains("pipe"):
		play_pipe(Vector3.INF, false)
		return 1.4
	if p.contains("argument") or p.contains("voices"):
		_distant_argument()
		return 3.2
	if p.contains("cut"):
		_duck_bed(-12.0, 0.05)
		get_tree().create_timer(0.35, false).timeout.connect(_stop_static_bed)
		return 1.2
	if p.contains("tape a") or p.contains("tape b"):
		_play(_sfx("latch"), "Story", -10.0, 0.05)
		return 0.6
	return clampf(float(p.length()) * 0.04, 0.4, 1.6)

## The storm night "remembered wrong": the knocks again, fainter and out of step.
func _echo_knocks() -> void:
	for i in 3:
		_play(_sfx("knock"), "Story", -26.0, 0.08)
		await get_tree().create_timer(_rng.randf_range(0.5, 0.8)).timeout

func _rain_swell(peak_db: float, dur: float) -> void:
	if _skip():
		return
	var p := AudioStreamPlayer.new()
	p.bus = "Story"
	p.stream = _load_loop(["res://assets/audio/ambience/rain_loop.wav"])
	p.volume_db = -40.0
	add_child(p)
	p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", peak_db, dur * 0.4)
	tw.tween_property(p, "volume_db", -40.0, dur * 0.8)
	tw.tween_callback(p.queue_free)

## Voices too far away to make out: quiet, overlapping, never subtitled as words.
func _distant_argument() -> void:
	var token := _narr_token
	for pair in [["man", "No."], ["miriam", "Listen to me."], ["man", "Not tonight."], ["miriam", "Please."]]:
		if token != _narr_token:
			return
		await _speak_one(str(pair[0]), str(pair[1]), token, 0.18)

## Plays a tape transcript line by line: quoted text is spoken by the speaker named
## before the quote; [bracketed] cues play their sounds in order. Emits narration_line
## for the line being played and narration_finished at the end (or when stopped).
signal narration_line(index: int)

func narrate(lines: String) -> void:
	stop_narration()
	var token := _narr_token
	_narrating = true
	_play(_sfx("latch"), "Story", -8.0, 0.03)      # tape button
	await _wait(0.5)
	_start_static_bed()
	var all: PackedStringArray = lines.split("\n", false)
	for i in all.size():
		if token != _narr_token:
			return
		narration_line.emit(i)
		var line: String = all[i].strip_edges()
		var q0: int = line.find("\"")
		var q1: int = line.rfind("\"")
		if q0 != -1 and q1 > q0:
			var prefix: String = line.substr(0, q0)
			if prefix.to_lower().contains("tape"):
				await _wait(_cue_part(prefix))
			await speak(_speaker(prefix), line.substr(q0 + 1, q1 - q0 - 1))
		else:
			var body: String = line.trim_prefix("[").trim_suffix("]")
			for part in body.replace(":", ",").replace(" — ", ",").replace(". ", ",").split(",", false):
				if token != _narr_token:
					return
				await _wait(_cue_part(part))
		if token != _narr_token:
			return
		await _wait(0.4)
	if token == _narr_token:
		_narrating = false
		_stop_static_bed()
		_play(_sfx("latch"), "Story", -8.0, 0.03)
		narration_finished.emit()

# ---------------------------------------------------------------- generated fallbacks
func _make_tone(freq: float, dur: float, volume: float = 0.4, noise: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in frames:
		var t: float = float(i) / rate
		var s: float = sin(TAU * freq * t) * (1.0 - noise) + (rng.randf() * 2.0 - 1.0) * noise
		s *= volume * (1.0 - float(i) / float(frames))
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
