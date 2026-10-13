class_name MaterialFactory
extends RefCounted
## PBR materials. Prefers the external CC0 (Poly Haven) texture set; falls back to the
## in-engine procedural bakes so the game still builds if assets are missing.
## Everything uses triplanar mapping so box geometry never stretches UVs.

const EXT := "res://assets/textures/external/"
const TEX := "res://assets/textures/"

static var _ext_cache: Dictionary = {}
## Materials are shared: the same look returns the same material object, so the level
## uses a few dozen materials instead of hundreds (fewer draw-state changes, faster load).
static var _mat_cache: Dictionary = {}
static var _using_external := false

static func _ext_exists(name: String) -> bool:
	if _ext_cache.is_empty():
		var d := DirAccess.open(EXT)
		if d == null:
			_using_external = false
			return false
		_using_external = true
		d.list_dir_begin()
		var f: String = d.get_next()
		while f != "":
			if f.ends_with("_albedo.jpg"):
				_ext_cache[f.replace("_albedo.jpg", "")] = true
			f = d.get_next()
		d.list_dir_end()
	return _ext_cache.has(name)

static func _load_first(paths: Array) -> Texture2D:
	for p in paths:
		if ResourceLoader.exists(p):
			var t: Resource = load(p)
			if t is Texture2D:
				return t as Texture2D
	return null

static func _pbr(name: String, tint: Color = Color.WHITE, uv_scale: float = 1.0, triplanar: bool = true) -> StandardMaterial3D:
	var key := "pbr|%s|%s|%s|%s" % [name, tint, uv_scale, triplanar]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	_mat_cache[key] = m
	m.albedo_color = tint
	m.metallic = 0.0
	m.metallic_specular = 0.35
	m.normal_enabled = true
	m.normal_scale = 0.55
	var albedo: Texture2D = null
	var rough: Texture2D = null
	var norm: Texture2D = null
	if _ext_exists(name):
		albedo = _load_first([EXT + name + "_albedo.jpg", EXT + name + "_albedo.png"])
		rough = _load_first([EXT + name + "_rough.jpg", EXT + name + "_rough.png"])
		norm = _load_first([EXT + name + "_normal.jpg", EXT + name + "_normal.png"])
	if albedo == null:
		albedo = _load_first([TEX + name + "_albedo.png"])
		rough = _load_first([TEX + name + "_rough.png"])
		norm = _load_first([TEX + name + "_normal.png"])
	m.albedo_texture = albedo
	m.roughness_texture = rough
	m.normal_texture = norm
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
		m.uv1_triplanar_sharpness = 1.0
	else:
		m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	return m

# --- Floors ---
static func wood_floor() -> StandardMaterial3D:
	return _pbr("floor_wood", Color(0.95, 0.88, 0.80), 0.55)

static func tile_floor() -> StandardMaterial3D:
	return _pbr("floor_tile", Color(0.86, 0.87, 0.86), 0.85)

static func concrete() -> StandardMaterial3D:
	return _pbr("concrete", Color(0.82, 0.85, 0.90), 0.6)

# --- Walls ---
static func plaster() -> StandardMaterial3D:
	return _pbr("wall_plaster", Color(1.06, 1.04, 1.00), 0.42)

static func plaster_old() -> StandardMaterial3D:
	return _pbr("wall_plaster", Color(0.96, 0.90, 0.80), 0.42)

static func plaster_cold() -> StandardMaterial3D:
	return _pbr("wall_plaster", Color(0.84, 0.89, 0.98), 0.42)

static func plaster_green() -> StandardMaterial3D:
	return _pbr("wall_plaster", Color(0.92, 0.98, 0.80), 0.42)

static func ceiling() -> StandardMaterial3D:
	return _pbr("wall_plaster", Color(1.18, 1.16, 1.14), 0.32)

# --- Wood ---
static func wood_dark() -> StandardMaterial3D:
	return _pbr("wood_dark_panel", Color(1.0, 0.92, 0.86), 0.9)

static func wood_mid() -> StandardMaterial3D:
	return _pbr("wood_panel", Color(1.0, 0.94, 0.86), 0.9)

static func wood_trim() -> StandardMaterial3D:
	return _pbr("wood_dark_panel", Color(1.15, 1.06, 0.96), 1.4)

# --- Misc ---
static func metal_dark() -> StandardMaterial3D:
	var m := _pbr("metal_dark", Color(0.78, 0.80, 0.84), 1.4)
	m.metallic = 0.7
	return m

static func paint_metal() -> StandardMaterial3D:
	var m := _pbr("metal_dark", Color(1.5, 1.46, 1.38), 1.4)
	m.metallic = 0.2
	return m

static func fabric_blue() -> StandardMaterial3D:
	return _pbr("fabric_blue", Color(0.85, 0.90, 1.15), 2.2)

static func exterior() -> StandardMaterial3D:
	return _pbr("wall_plaster", Color(0.78, 0.74, 0.68), 0.3)

static func grass() -> StandardMaterial3D:
	var m := _pbr("concrete", Color(0.16, 0.22, 0.12), 0.35)
	m.roughness = 1.0
	return m

static func roof() -> StandardMaterial3D:
	return _pbr("wood_dark_panel", Color(0.42, 0.3, 0.28), 0.6)

static func bath_tile() -> StandardMaterial3D:
	return _pbr("floor_tile", Color(0.92, 0.95, 0.96), 1.6)

static func worktop() -> StandardMaterial3D:
	return _pbr("concrete", Color(0.42, 0.4, 0.38), 1.2)

## Stair materials use WORLD triplanar mapping so neighbouring step blocks share one
## continuous texture (no seams between boxes).
static func _world(m: StandardMaterial3D, key: String) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var w := m.duplicate() as StandardMaterial3D
	w.uv1_world_triplanar = true
	_mat_cache[key] = w
	return w

static func stair_tread() -> StandardMaterial3D:
	return _world(_pbr("floor_wood", Color(1.0, 0.86, 0.72), 0.9), "stair_tread")

static func stair_side() -> StandardMaterial3D:
	return _world(plaster_cold(), "stair_side")

static func stair_riser() -> StandardMaterial3D:
	return flat(Color(0.84, 0.81, 0.74), 0.55)

static func paper() -> StandardMaterial3D:
	return _pbr("paper", Color(0.80, 0.76, 0.68), 1.0, false)

static func flat(albedo: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "flat|%s|%s|%s" % [albedo, roughness, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	_mat_cache[key] = m
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	return m

static func emissive(albedo: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "emis|%s|%s" % [albedo, energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	_mat_cache[key] = m
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = albedo
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

static func glass_mat() -> StandardMaterial3D:
	if _mat_cache.has("glass"):
		return _mat_cache["glass"]
	var m := StandardMaterial3D.new()
	_mat_cache["glass"] = m
	m.albedo_color = Color(0.62, 0.74, 0.85, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.35, 0.45, 0.6)
	m.emission_energy_multiplier = 0.12
	return m
