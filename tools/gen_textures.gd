extends SceneTree
## Bakes procedural PBR textures (albedo + roughness + normal) to res://assets/textures/.
## Run headless: godot --headless --path <proj> --script res://tools/gen_textures.gd

const DIR := "res://assets/textures/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_bake_planks()
	_bake_plaster()
	_bake_tile()
	_bake_concrete()
	_bake_darkwood()
	_bake_panel("wood_panel", 101, Color(0.40, 0.26, 0.15))
	_bake_panel("wood_dark_panel", 102, Color(0.26, 0.16, 0.09))
	_bake_fabric()
	_bake_metal()
	_bake_paper()
	print("TEXTURES DONE")
	quit(0)

func _n(seed_v: int, freq: float, type: int, octaves: int = 4, lac: float = 2.0, gain: float = 0.5) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_lacunarity = lac
	n.fractal_gain = gain
	return n

func _save(name: String, albedo: Image, rough: Image, normal: Image) -> void:
	albedo.save_png(DIR + name + "_albedo.png")
	rough.save_png(DIR + name + "_rough.png")
	normal.save_png(DIR + name + "_normal.png")
	print("  baked ", name)

func _normal_from_height(h: PackedFloat32Array, size: int, strength: float) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var l: float = h[y * size + ((x - 1 + size) % size)]
			var r: float = h[y * size + ((x + 1) % size)]
			var u: float = h[((y - 1 + size) % size) * size + x]
			var d: float = h[((y + 1) % size) * size + x]
			var nx: float = (l - r) * strength
			var ny: float = (u - d) * strength
			var nz: float = 1.0
			var len_v := sqrt(nx * nx + ny * ny + nz * nz)
			img.set_pixel(x, y, Color(nx / len_v * 0.5 + 0.5, ny / len_v * 0.5 + 0.5, nz / len_v * 0.5 + 0.5))
	return img

func _bake_planks() -> void:
	var s := 1024
	var grain := _n(11, 0.055, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var fine := _n(12, 0.4, FastNoiseLite.TYPE_SIMPLEX, 2)
	var stain := _n(13, 0.012, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	var plank_h := 32
	for y in s:
		var row: int = y / plank_h
		var off: int = (row * 137) % s
		for x in s:
			var u: int = (x + off) % s
			var seam: float = 0.0
			if y % plank_h < 2 or u % 256 < 2:
				seam = 1.0
			var g: float = grain.get_noise_2d(float(u) * 0.25, float(y) * 0.02)
			var f: float = fine.get_noise_2d(float(u), float(y)) * 0.35
			var st: float = stain.get_noise_2d(float(x), float(y))
			var tone: float = 0.5 + g * 0.34 + f * 0.18 + st * 0.22
			tone = clampf(tone, 0.0, 1.0)
			var base := Color(0.42, 0.27, 0.155)
			var col: Color = base.lerp(Color(0.60, 0.42, 0.24), tone)
			col = col.lerp(Color(0.16, 0.10, 0.06), seam * 0.85)
			a.set_pixel(x, y, col)
			var rough: float = clampf(0.62 + (1.0 - tone) * 0.22 + seam * 0.12, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = -seam * 0.9 + g * 0.06 + f * 0.02
	_save("floor_wood", a, r, _normal_from_height(h, s, 2.2))

func _bake_plaster() -> void:
	var s := 1024
	var base_n := _n(21, 0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 5, 2.1, 0.55)
	var bump_n := _n(22, 0.55, FastNoiseLite.TYPE_SIMPLEX, 2)
	var stain_n := _n(23, 0.008, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			var b: float = base_n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var bp: float = bump_n.get_noise_2d(float(x), float(y)) * 0.5
			var st: float = stain_n.get_noise_2d(float(x), float(y))
			var v: float = 0.62 + b * 0.30 + bp * 0.07
			# yellowed water stains near bottom
			var wet: float = clampf((-float(y) / float(s)) * 0.5 + st * 0.5 + 0.25, 0.0, 1.0)
			var col := Color(0.76, 0.735, 0.675).lerp(Color(0.56, 0.52, 0.44), wet * 0.45)
			col = col * (0.88 + b * 0.22)
			a.set_pixel(x, y, col)
			var rough: float = clampf(0.90 - bp * 0.10, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = b * 0.10 + bp * 0.30
	_save("wall_plaster", a, r, _normal_from_height(h, s, 0.45))

func _bake_tile() -> void:
	var s := 1024
	var tint := _n(31, 0.05, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	var tile := 64
	for y in s:
		for x in s:
			var gx: int = x % tile
			var gy: int = y % tile
			var grout: float = 0.0
			if gx < 3 or gy < 3:
				grout = 1.0
			var check: int = ((x / tile) + (y / tile)) % 2
			var tn: float = tint.get_noise_2d(float(x / tile) * 8.0, float(y / tile) * 8.0) * 0.5 + 0.5
			var c1 := Color(0.80, 0.79, 0.75)
			var c2 := Color(0.30, 0.33, 0.33)
			var col: Color = (c1 if check == 0 else c2) * (0.86 + tn * 0.24)
			col = col.lerp(Color(0.42, 0.40, 0.36), grout)
			a.set_pixel(x, y, col)
			var rough: float = 0.22 if grout == 0.0 else 0.85
			rough += tn * 0.06
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = -grout * 1.0
	_save("floor_tile", a, r, _normal_from_height(h, s, 2.6))

func _bake_concrete() -> void:
	var s := 1024
	var base_n := _n(41, 0.018, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 5, 2.2, 0.55)
	var pit := _n(42, 0.9, FastNoiseLite.TYPE_SIMPLEX, 2)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			var b: float = base_n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var p: float = pit.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var pit_mask: float = clampf((p - 0.72) * 4.0, 0.0, 1.0)
			var v: float = 0.40 + b * 0.26 - pit_mask * 0.14
			var col := Color(v, v * 1.01, v * 1.03)
			a.set_pixel(x, y, col)
			var rough: float = clampf(0.88 - pit_mask * 0.25 + b * 0.08, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = b * 0.08 - pit_mask * 0.9
	_save("concrete", a, r, _normal_from_height(h, s, 0.9))

func _bake_darkwood() -> void:
	var s := 512
	var grain := _n(51, 0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 4)
	var fine := _n(53, 0.5, FastNoiseLite.TYPE_SIMPLEX, 2)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			# Straight, fine grain running along Y with only gentle wander.
			var wob: float = grain.get_noise_2d(float(x) * 0.08, float(y) * 0.012) * 3.0
			var ring: float = sin((float(x) + wob) * 0.85) * 0.5 + 0.5
			var f: float = fine.get_noise_2d(float(x) * 0.5, float(y) * 0.02) * 0.25
			var v: float = 0.30 + ring * 0.09 + f * 0.05
			a.set_pixel(x, y, Color(v * 1.02, v * 0.70, v * 0.44))
			var rough: float = clampf(0.52 + (1.0 - ring) * 0.16, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = ring * 0.10 + f * 0.05
	_save("wood_dark", a, r, _normal_from_height(h, s, 0.35))

## Seamless furniture-grade wood: fine straight grain, no plank seams, tiles cleanly.
func _bake_panel(name: String, seed_v: int, base: Color) -> void:
	var s := 512
	var wobble := _n(seed_v, 0.015, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var micro := _n(seed_v + 1, 0.45, FastNoiseLite.TYPE_SIMPLEX, 2)
	var tone_n := _n(seed_v + 2, 0.03, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			# Grain varies across X only, so it reads as long straight fibres.
			var wob: float = wobble.get_noise_2d(float(x) * 0.05, float(y) * 0.008) * 4.0
			var g: float = sin((float(x) + wob) * 0.55) * 0.5 + 0.5
			var m: float = micro.get_noise_2d(float(x) * 0.6, float(y) * 0.03) * 0.25
			var t: float = tone_n.get_noise_2d(float(x), float(y)) * 0.12
			var v: float = 0.5 + g * 0.22 + m * 0.10 + t
			var col := Color(base.r * v * 1.5, base.g * v * 1.5, base.b * v * 1.5)
			a.set_pixel(x, y, col)
			var rough: float = clampf(0.56 + (1.0 - g) * 0.14, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = g * 0.08 + m * 0.04
	_save(name, a, r, _normal_from_height(h, s, 0.3))

func _bake_fabric() -> void:
	var s := 512
	var weave := _n(61, 0.9, FastNoiseLite.TYPE_SIMPLEX, 1)
	var fuzz := _n(62, 0.06, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			var w: float = (sin(float(x) * 1.6) * sin(float(y) * 1.6)) * 0.5 + 0.5
			var f: float = fuzz.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var v: float = 0.20 + w * 0.06 + f * 0.10
			a.set_pixel(x, y, Color(v * 0.75, v * 0.92, v * 1.35))
			var rough: float = clampf(0.92 - w * 0.06, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = w * 0.4 + f * 0.2
	_save("fabric_blue", a, r, _normal_from_height(h, s, 1.4))

func _bake_metal() -> void:
	var s := 512
	var brush := _n(71, 0.9, FastNoiseLite.TYPE_SIMPLEX, 1)
	var dirt := _n(72, 0.03, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			var b: float = brush.get_noise_2d(float(x), float(y) * 0.15) * 0.5 + 0.5
			var d: float = dirt.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var v: float = 0.16 + b * 0.07 + d * 0.10
			a.set_pixel(x, y, Color(v, v * 1.02, v * 1.06))
			var rough: float = clampf(0.34 + d * 0.30 + b * 0.08, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = b * 0.12
	_save("metal_dark", a, r, _normal_from_height(h, s, 0.8))

func _bake_paper() -> void:
	var s := 512
	var fib := _n(81, 0.5, FastNoiseLite.TYPE_SIMPLEX, 3)
	var age := _n(82, 0.02, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3)
	var a := Image.create(s, s, false, Image.FORMAT_RGB8)
	var r := Image.create(s, s, false, Image.FORMAT_RGB8)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for y in s:
		for x in s:
			var f: float = fib.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var g: float = age.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var col := Color(0.90, 0.875, 0.80).lerp(Color(0.74, 0.68, 0.54), g * 0.45)
			col = col * (0.94 + f * 0.10)
			a.set_pixel(x, y, col)
			var rough: float = clampf(0.88 - f * 0.06, 0.0, 1.0)
			r.set_pixel(x, y, Color(rough, rough, rough))
			h[y * s + x] = f * 0.25
	_save("paper", a, r, _normal_from_height(h, s, 0.9))
