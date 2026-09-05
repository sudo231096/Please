extends Node3D
## Пустошь в духе Rust: выживание от первого лица, оптимизированный ландшафт.

const PlayerScr := preload("res://scripts/player.gd")
const AnimalScr := preload("res://scripts/animal.gd")
const HudScr := preload("res://scripts/hud.gd")

const TERRAIN_N := 256        # ячеек на сторону (4 м на ячейку — детальный рельеф)
const TERRAIN_SIZE := 1024.0  # метров
const TERRAIN_CELL := TERRAIN_SIZE / float(TERRAIN_N)
const HALF := TERRAIN_SIZE * 0.5

# горы: [x, z, высота, радиус] (чуть ниже, чем раньше)
const MOUNTAINS := [
	[200.0, 200.0, 13.0, 60.0],
	[-280.0, -150.0, 16.0, 70.0],
	[120.0, -320.0, 11.0, 55.0],
	[-100.0, 300.0, 14.0, 65.0],
]

var _player: CharacterBody3D
var _hud: CanvasLayer
var _rng := RandomNumberGenerator.new()
var _heights := PackedFloat32Array()
# день/ночь и погода
var _sun: DirectionalLight3D
var _skymat: ProceduralSkyMaterial
var _env: Environment
var _sun_disc: MeshInstance3D
var _rain: GPUParticles3D
var _time_of_day := 0.4      # 0..1 (0.5 = полдень)
var _day_length := 480.0     # секунд на полный цикл
var _raining := false
var _weather_timer := 60.0
# позиции добываемых объектов (для добычи вблизи)
var _tree_spots: Array = []      # [{pos, index, alive}]
var _rock_spots: Array = []      # [{pos, index, alive}]
var _ore_spots: Array = []       # [{pos, kind, alive}]
var _barrel_spots: Array = []    # [{pos, alive, node}]
var _loot_spots: Array = []      # [{pos, opened, node, lid}]
var _puddles: Array = []         # [{x, z, r}]
var _trees_mm: MultiMesh
var _rocks_mm: MultiMesh

# монументы (как в Rust): склад, парковка, завод, АЭС
const MONUMENTS := [
	{"kind": "warehouse", "pos": Vector3(-300.0, 0, -250.0)},
	{"kind": "parking", "pos": Vector3(320.0, 0, -180.0)},
	{"kind": "factory", "pos": Vector3(-260.0, 0, 320.0)},
	{"kind": "npp", "pos": Vector3(310.0, 0, 290.0)},
]


func _ready() -> void:
	add_to_group("terrain")
	_rng.seed = randi()
	if not GameState.return_to_pos:
		# свежий запуск или рестарт после смерти — сбрасываем прогресс
		GameState.reset_run()
	_build_puddles()
	_build_sky()
	_build_ground()
	_build_roads()
	_build_trees()
	_build_rocks()
	_build_ores()
	_build_grass()
	_build_monuments()
	_build_barrels()
	_build_weather()
	_spawn_player()
	_build_hud()
	_spawn_animals()


# ---------- высота рельефа ----------

func _ground_height(x: float, z: float) -> float:
	var h := 0.0
	# многослойный шум — холмистая местность как в Rust
	h += 2.5 * sin(x * 0.006 + 1.3) * cos(z * 0.007 + 0.7)
	h += 1.5 * sin(x * 0.013 + 0.5) * sin(z * 0.011 + 2.1)
	h += 0.8 * sin(x * 0.027 + 0.2) * cos(z * 0.023 + 1.6)
	h += 0.4 * sin(x * 0.051 + 3.0) * sin(z * 0.047 + 0.9)
	# мелкие бугры и неровности
	h += 0.5 * sin(x * 0.09 + 1.1) * cos(z * 0.083 + 0.3)
	h += 0.25 * sin(x * 0.17 + 0.7) * sin(z * 0.19 + 2.3)
	for p in MOUNTAINS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var d2: float = dx * dx + dz * dz
		h += p[2] * exp(-d2 / (2.0 * p[3] * p[3]))
	# лужи: плавные углубления, заполненные водой
	for p in _puddles:
		var dx: float = x - p["x"]
		var dz: float = z - p["z"]
		var d: float = sqrt(dx * dx + dz * dz)
		var r: float = p["r"]
		if d < r:
			var k := 1.0 - d / r  # 1 в центре, 0 на краю
			h = lerpf(h, -0.7, k * 0.75)
	return h


func _surface_height(x: float, z: float) -> float:
	# точная высота видимого меша (билинейная интерполяция сетки высот) — объекты не «летают»
	if _heights.size() == 0:
		return _ground_height(x, z)
	var n := TERRAIN_N + 1
	var fx := (x + HALF) / TERRAIN_CELL
	var fz := (z + HALF) / TERRAIN_CELL
	var x0 := clampi(int(floor(fx)), 0, TERRAIN_N - 1)
	var z0 := clampi(int(floor(fz)), 0, TERRAIN_N - 1)
	var x1 := mini(x0 + 1, TERRAIN_N)
	var z1 := mini(z0 + 1, TERRAIN_N)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var h00 := _heights[z0 * n + x0]
	var h10 := _heights[z0 * n + x1]
	var h01 := _heights[z1 * n + x0]
	var h11 := _heights[z1 * n + x1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build_puddles() -> void:
	_puddles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in range(30):
		_puddles.append({
			"x": rng.randf_range(-HALF + 50.0, HALF - 50.0),
			"z": rng.randf_range(-HALF + 50.0, HALF - 50.0),
			"r": rng.randf_range(4.0, 12.0),
		})


func _puddle_factor(x: float, z: float) -> float:
	# 0..1 — насколько точка внутри лужи (для окраски воды)
	for p in _puddles:
		var dx: float = x - p["x"]
		var dz: float = z - p["z"]
		var d: float = sqrt(dx * dx + dz * dz)
		var r: float = p["r"]
		if d < r:
			return 1.0 - d / r
	return 0.0


func _mat(color: Color, emissive := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive.a > 0.0:
		m.emission_enabled = true
		m.emission = emissive
	return m


# ---------- геометрия для MultiMesh (вершинные цвета, без нормалей) ----------

func _add_tri(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c])
	cols.append(color); cols.append(color); cols.append(color)
	idx.append_array([base, base + 1, base + 2])


func _make_tree_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var brown := Color(0.45, 0.32, 0.17)
	var green := Color(0.22, 0.46, 0.16)
	# ствол (коробка)
	var bs := Vector3(0.16, 1.1, 0.16)
	var bc := Vector3(0, 0.55, 0)
	_add_box(verts, cols, idx, bc, bs, brown)
	# три яруса хвои (конусы)
	_add_cone(verts, cols, idx, 0.95, 0.85, 1.3, green)
	_add_cone(verts, cols, idx, 1.75, 0.62, 1.1, green.lightened(0.05))
	_add_cone(verts, cols, idx, 2.45, 0.4, 0.9, green.lightened(0.1))
	var am := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _flat_normals(verts, idx)
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _add_box(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, center: Vector3, size: Vector3, color: Color) -> void:
	var s := size * 0.5
	var p := [
		center + Vector3(-s.x, -s.y, -s.z), center + Vector3(s.x, -s.y, -s.z),
		center + Vector3(s.x, s.y, -s.z), center + Vector3(-s.x, s.y, -s.z),
		center + Vector3(-s.x, -s.y, s.z), center + Vector3(s.x, -s.y, s.z),
		center + Vector3(s.x, s.y, s.z), center + Vector3(-s.x, s.y, s.z),
	]
	var base := verts.size()
	verts.append_array(p)
	for i in range(8):
		cols.append(color)
	var f := [
		[0, 1, 2, 0, 2, 3], [4, 6, 5, 4, 7, 6],
		[0, 4, 5, 0, 5, 1], [3, 2, 6, 3, 6, 7],
		[0, 3, 7, 0, 7, 4], [1, 5, 6, 1, 6, 2],
	]
	for face in f:
		for i in face:
			idx.append(base + i)


func _add_cone(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, base_y: float, base_r: float, h: float, color: Color) -> void:
	var segs := 7
	var apex := Vector3(0, base_y + h, 0)
	var base := verts.size()
	verts.append(apex)
	cols.append(color)
	for i in range(segs):
		var ang := TAU * i / segs
		verts.append(Vector3(cos(ang) * base_r, base_y, sin(ang) * base_r))
		cols.append(color)
	for i in range(segs):
		var i0 := base + 1 + i
		var i1 := base + 1 + (i + 1) % segs
		idx.append_array([base, i0, i1])
	for i in range(1, segs - 1):
		idx.append_array([base + 1, base + 1 + i, base + 1 + i + 1])


func _make_grass_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var base_c := Color(0.36, 0.66, 0.26)
	var tip_c := Color(0.52, 0.82, 0.36)
	var h := 1.0
	var w := 0.28
	# пучок из 5 широких лезвий, нормали вверх (освещается солнцем — ярко-зелёная)
	for i in range(5):
		var ang := TAU * i / 5.0
		var side := Vector3(-sin(ang), 0, cos(ang))
		var b := verts.size()
		var p0 := side * w
		var p1 := -side * w
		var p2 := -side * w * 0.2 + Vector3(0, h, 0)
		var p3 := side * w * 0.2 + Vector3(0, h, 0)
		verts.append_array([p0, p1, p2, p3])
		norms.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
		cols.append(base_c); cols.append(base_c)
		cols.append(tip_c); cols.append(tip_c)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
	var am := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _make_rock_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var r := _rng
	# неровный куб
	var s := 0.6
	var p := []
	for i in range(8):
		var cx := s if (i & 1) != 0 else -s
		var cy := s if (i & 2) != 0 else -s
		var cz := s if (i & 4) != 0 else -s
		p.append(Vector3(cx + r.randf_range(-0.15, 0.15), cy + r.randf_range(-0.15, 0.15), cz + r.randf_range(-0.15, 0.15)))
	var gray := Color(0.5, 0.48, 0.46)
	var base := verts.size()
	verts.append_array(p)
	for i in range(8):
		cols.append(gray)
	var f := [
		[0, 1, 2, 0, 2, 3], [4, 6, 5, 4, 7, 6],
		[0, 4, 5, 0, 5, 1], [3, 2, 6, 3, 6, 7],
		[0, 3, 7, 0, 7, 4], [1, 5, 6, 1, 6, 2],
	]
	for face in f:
		for i in face:
			idx.append(base + i)
	var am := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _flat_normals(verts, idx)
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # строго непрозрачный
	m.cull_mode = BaseMaterial3D.CULL_DISABLED  # двухсторонний рендер (фикс «прозрачности»)
	return m


func _grass_material() -> StandardMaterial3D:
	# трава НЕ освещается — цвет берётся из вершинных цветов напрямую (всегда зелёная)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.4, 0.7, 0.3)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # строго непрозрачный
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _terrain_material() -> StandardMaterial3D:
	# освещённый рельеф: вершинные цвета + солнце + тени (глубина, а не плоское «мыло»)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 1.0
	m.metallic = 0.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # строго непрозрачный
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _flat_normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	# плоские нормали по граням (для деревьев/камней — чёткие грани, как в Rust)
	var n := PackedVector3Array()
	n.resize(verts.size())
	for i in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[i]]
		var b: Vector3 = verts[idx[i + 1]]
		var c: Vector3 = verts[idx[i + 2]]
		var fn := (b - a).cross(c - a)
		if fn.length_squared() > 0.0:
			fn = fn.normalized()
			n[idx[i]] += fn
			n[idx[i + 1]] += fn
			n[idx[i + 2]] += fn
	for i in range(n.size()):
		if n[i].length_squared() > 0.0:
			n[i] = n[i].normalized()
		else:
			n[i] = Vector3.UP
	return n


# ---------- окружение ----------

func _build_sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skymat := ProceduralSkyMaterial.new()
	# яркое дневное небо с лёгкой дымкой — как в Rust
	skymat.sky_top_color = Color(0.25, 0.48, 0.82)
	skymat.sky_horizon_color = Color(0.74, 0.82, 0.9)
	skymat.ground_bottom_color = Color(0.3, 0.27, 0.22)
	skymat.ground_horizon_color = Color(0.62, 0.62, 0.56)
	sky.sky_material = skymat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	_skymat = skymat
	_env = env
	# кинематографичная цветокоррекция: фильмический тонмаппинг + лёгкий bloom
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	# лёгкая подкрутка насыщенности и контраста
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.04
	# атмосферная дымка на дальности
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.72, 0.84)
	env.fog_density = 0.0014
	env.fog_sky_affect = 0.55
	# SSAO — затенение в углублениях и у оснований объектов (глубина, как в Rust)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.3
	env.ssao_power = 2.0
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 32, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)  # тёплый солнечный свет
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_sun = sun
	# видимое солнце в небе (крупный яркий диск + широкое гало)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 26.0
	sm.height = 26.0
	disc.mesh = sm
	disc.material_override = _mat(Color(1.0, 0.99, 0.82), Color(1.0, 0.9, 0.55))
	disc.position = Vector3(0, 120, -240)
	add_child(disc)
	_sun_disc = disc
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 60.0
	hm.height = 60.0
	halo.mesh = hm
	var hmat := _mat(Color(1.0, 0.92, 0.6, 0.45), Color(1.0, 0.82, 0.35))
	halo.material_override = hmat
	halo.position = disc.position
	add_child(halo)


func _color_noise(x: float, z: float) -> float:
	# детерминированный шум 0..1 — для естественной пятнистости рельефа
	var n := sin(x * 0.09 + 1.7) * cos(z * 0.11 + 0.6)
	var n2 := sin(x * 0.21 + 0.4) * sin(z * 0.19 + 2.1)
	return clampf(0.5 + 0.35 * n + 0.15 * n2, 0.0, 1.0)


func _build_weather() -> void:
	# дождь: частицы-капли вокруг игрока
	_rain = GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(60, 1, 60)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 6.0
	mat.initial_velocity_min = 22.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -35, 0)
	mat.scale_min = 0.06
	mat.scale_max = 0.12
	_rain.process_material = mat
	_rain.amount = 1400
	_rain.lifetime = 1.1
	_rain.emitting = false
	# капля — тонкая вытянутая призма
	var drop := ArrayMesh.new()
	var db := BoxMesh.new()
	db.size = Vector3(0.03, 0.55, 0.03)
	drop.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, db.get_mesh_arrays())
	_rain.draw_pass_1 = drop
	var rm := _mat(Color(0.62, 0.72, 0.86, 0.5))
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain.material_override = rm
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


func _update_day_night(delta: float) -> void:
	_time_of_day = fmod(_time_of_day + delta / _day_length, 1.0)
	var elev := sin(_time_of_day * TAU - PI * 0.5)  # -1 ночь .. 1 день
	# плавный фактор дневного света (с рассветом/закатом)
	var dl := clampf((elev + 0.12) / 0.28, 0.0, 1.0)
	if _sun:
		_sun.rotation_degrees = Vector3(-90.0 + (1.0 - dl) * 78.0, 32.0, 0.0)
		_sun.light_energy = lerpf(0.06, 1.5, dl)
		_sun.light_color = Color(0.4, 0.5, 0.72).lerp(Color(1.0, 0.93, 0.8), dl)
	if _skymat:
		_skymat.sky_top_color = Color(0.02, 0.03, 0.09).lerp(Color(0.25, 0.48, 0.82), dl)
		_skymat.sky_horizon_color = Color(0.12, 0.15, 0.24).lerp(Color(0.74, 0.82, 0.9), dl)
		_skymat.ground_bottom_color = Color(0.06, 0.06, 0.07).lerp(Color(0.3, 0.27, 0.22), dl)
		_skymat.ground_horizon_color = Color(0.15, 0.17, 0.22).lerp(Color(0.62, 0.62, 0.56), dl)
	if _env:
		# дождь приглушает свет и делает картинку холоднее
		var rain_dark := 0.6 if _raining else 1.0
		_env.fog_light_color = Color(0.18, 0.22, 0.32).lerp(Color(0.62, 0.72, 0.84), dl) * rain_dark
		_env.ambient_light_energy = lerpf(0.35, 1.0, dl) * rain_dark
	if _sun_disc and _player and _sun_disc.is_inside_tree():
		# видимое солнце следует за направлением света
		var dir := -_sun.global_transform.basis.z
		_sun_disc.global_position = _player.global_position + dir * 400.0


func _update_weather(delta: float) -> void:
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_raining = not _raining
		_weather_timer = randf_range(50.0, 110.0)
		if _rain:
			_rain.emitting = _raining
	if _rain and _rain.is_inside_tree():
		_rain.global_position = _player.global_position + Vector3(0, 20, 0) if _player else Vector3(0, 20, 0)


func _build_ground() -> void:
	# процедурный холмистый рельеф (единый источник высоты _ground_height —
	# игрок, деревья, трава и камни ходят строго по нему, без проваливания и «парения»)
	var n := TERRAIN_N + 1
	_heights.resize(n * n)
	for z in range(n):
		for x in range(n):
			var wx := -HALF + x * TERRAIN_CELL
			var wz := -HALF + z * TERRAIN_CELL
			_heights[z * n + x] = _ground_height(wx, wz)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var grass := Color(0.34, 0.5, 0.22)
	var dark := Color(0.24, 0.4, 0.16)
	var dirt := Color(0.47, 0.38, 0.25)
	var rock := Color(0.42, 0.42, 0.46)
	var snow := Color(0.93, 0.95, 0.98)
	for z in range(n):
		for x in range(n):
			var wx := -HALF + x * TERRAIN_CELL
			var wz := -HALF + z * TERRAIN_CELL
			var h := _heights[z * n + x]
			verts.append(Vector3(wx, h, wz))
			# нормаль из градиента высоты (соседние ячейки сетки)
			var x0 := clampi(x - 1, 0, n - 1)
			var x1 := clampi(x + 1, 0, n - 1)
			var z0 := clampi(z - 1, 0, n - 1)
			var z1 := clampi(z + 1, 0, n - 1)
			var dxh := _heights[z * n + x1] - _heights[z * n + x0]
			var dzh := _heights[z1 * n + x] - _heights[z0 * n + x]
			var normal := Vector3(-dxh, 2.0 * TERRAIN_CELL, -dzh).normalized()
			norms.append(normal)
			var slope := 1.0 - normal.y  # 0 = ровно, 1 = отвесно
			var pf := _puddle_factor(wx, wz)
			var c := grass
			if pf > 0.12:
				# вода в луже
				c = Color(0.2, 0.45, 0.6).lerp(Color(0.35, 0.6, 0.75), pf)
			elif h > 9.0:
				c = snow
			elif h > 5.0:
				c = rock
			elif h > 2.0:
				c = grass
			else:
				c = dark
			# земляные проплешины в низинах
			if h < 2.5 and pf <= 0.12:
				c = c.lerp(dirt, _color_noise(wx, wz) * 0.5)
			# крутые склоны переходят в скалу
			if slope > 0.28 and pf <= 0.12:
				c = c.lerp(rock, clampf((slope - 0.28) / 0.45, 0.0, 1.0))
			# естественная пятнистость тона
			var v := _color_noise(wx * 1.7, wz * 1.7 + 9.0)
			c = c.lightened((v - 0.5) * 0.14)
			cols.append(c)
	for z in range(TERRAIN_N):
		for x in range(TERRAIN_N):
			var i0 := z * n + x
			var i1 := z * n + x + 1
			var i2 := (z + 1) * n + x
			var i3 := (z + 1) * n + x + 1
			idx.append_array([i0, i2, i1, i1, i2, i3])

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	add_child(mi)

	# страховочная коллизия внизу
	var g := StaticBody3D.new()
	g.collision_layer = 1
	g.collision_mask = 0
	add_child(g)
	var gcol := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(TERRAIN_SIZE * 2, 0.5, TERRAIN_SIZE * 2)
	gcol.shape = cs
	gcol.position = Vector3(0, -40.0, 0)
	g.add_child(gcol)


func _add_ribbon(ax: float, az: float, bx: float, bz: float, width: float, color: Color, y_off: float) -> void:
	# полоса (дорога/река), повторяющая рельеф
	var dir := Vector3(bx - ax, 0, bz - az).normalized()
	var normal := Vector3(-dir.z, 0, dir.x)
	var steps := 96
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in range(steps + 1):
		var t := float(i) / steps
		var px := lerpf(ax, bx, t)
		var pz := lerpf(az, bz, t)
		var h := _surface_height(px, pz) + y_off
		var c := Vector3(px, h, pz)
		verts.append(c + normal * (width * 0.5))
		verts.append(c - normal * (width * 0.5))
		cols.append(color)
		cols.append(color)
	for i in range(steps):
		var a := i * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _vertex_color_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_roads() -> void:
	# река через карту
	_add_ribbon(-520.0, 80.0, 520.0, -120.0, 16.0, Color(0.2, 0.4, 0.55), -0.5)
	# грунтовые дороги
	_add_ribbon(-520.0, -260.0, 520.0, 260.0, 7.0, Color(0.42, 0.36, 0.26), 0.05)
	_add_ribbon(-300.0, -520.0, 300.0, 520.0, 6.0, Color(0.4, 0.34, 0.25), 0.05)


func _random_spot(min_r: float) -> Vector3:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(min_r, HALF - 20.0)
	var x := cos(ang) * r
	var z := sin(ang) * r
	return Vector3(x, _surface_height(x, z), z)


func _grid_spot(grid_size: float, jitter: float) -> Vector3:
	# равномерное распределение по сетке (как в Rust — ресурсы разбросаны по всей карте)
	var cols := int(TERRAIN_SIZE / grid_size)
	var cell := int(TERRAIN_SIZE / float(cols))
	var cx := _rng.randi_range(0, cols - 1)
	var cz := _rng.randi_range(0, cols - 1)
	var x := -HALF + (cx + 0.5) * cell + _rng.randf_range(-jitter, jitter)
	var z := -HALF + (cz + 0.5) * cell + _rng.randf_range(-jitter, jitter)
	return Vector3(x, _surface_height(x, z), z)


# ---------- деревья / камни / руды / трава (MultiMesh — оптимизация) ----------

func _build_trees() -> void:
	var mesh := _make_tree_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 250
	_tree_spots.clear()
	for i in range(250):
		# равномерно по карте, ближе друг к другу
		var pos := _grid_spot(28.0, 10.0)
		var big := _rng.randf() < 0.35
		var s := _rng.randf_range(2.2, 3.2) if big else _rng.randf_range(0.7, 1.6)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(0, -0.1, 0))
		t = t.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
		_tree_spots.append({"pos": pos, "index": i, "alive": true, "big": big})
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _terrain_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.name = "Trees"
	add_child(inst)
	_trees_mm = mm


func _build_rocks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_rock_mesh()
	mm.instance_count = 160
	_rock_spots.clear()
	for i in range(160):
		var pos := _grid_spot(24.0, 9.0)
		var s := _rng.randf_range(0.6, 2.2)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(0, 0.15 * s, 0))
		t = t.scaled(Vector3(s, s * _rng.randf_range(0.6, 1.0), s))
		mm.set_instance_transform(i, t)
		_rock_spots.append({"pos": pos, "index": i, "alive": true})
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _terrain_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.name = "Rocks"
	add_child(inst)
	_rocks_mm = mm


func _build_grass() -> void:
	var mesh := _make_grass_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 1800
	for i in range(1800):
		var pos := _random_spot(8.0)
		pos.y += 0.08  # чуть выше рельефа, чтобы не тонула и не зирила с ним
		var s := _rng.randf_range(0.7, 1.8)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos)
		t = t.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _grass_material()  # НЕ освещённая — всегда ярко-зелёная
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _build_ores() -> void:
	# руды: 0=сера (жёлтые валуны), 1=железо (тёмная), 2=камень (светлая), 3=металл (блестящая)
	_ore_spots.clear()
	for i in range(60):
		var pos := _grid_spot(20.0, 8.0)
		var kind := _rng.randi_range(0, 3)
		var container := Node3D.new()
		container.position = pos
		add_child(container)
		_ore_spots.append({"pos": pos, "kind": kind, "alive": true, "node": container})
		match kind:
			0:
				_sulfur_boulder_in(pos, container)
			1:
				var r := _rng.randf_range(0.5, 1.0)
				var ore := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = r
				sm.height = r * 1.4
				ore.mesh = sm
				ore.material_override = _mat(Color(0.25, 0.22, 0.2))
				ore.position = Vector3(0, r * 0.5, 0)
				ore.scale = Vector3(1, _rng.randf_range(0.6, 0.9), 1)
				container.add_child(ore)
				var vein := MeshInstance3D.new()
				var sm2 := SphereMesh.new()
				sm2.radius = r * 0.4
				sm2.height = r * 0.8
				vein.mesh = sm2
				vein.material_override = _mat(Color(0.6, 0.3, 0.1))
				vein.position = Vector3(r * 0.3, r * 0.6, 0)
				container.add_child(vein)
			2:
				var r2 := _rng.randf_range(0.6, 1.2)
				var stone := MeshInstance3D.new()
				var sm3 := SphereMesh.new()
				sm3.radius = r2
				sm3.height = r2 * 1.5
				stone.mesh = sm3
				stone.material_override = _mat(Color(0.55, 0.55, 0.6))
				stone.position = Vector3(0, r2 * 0.4, 0)
				stone.scale = Vector3(1, _rng.randf_range(0.5, 0.85), 1)
				container.add_child(stone)
			3:
				var r3 := _rng.randf_range(0.5, 1.0)
				var metal := MeshInstance3D.new()
				var sm4 := SphereMesh.new()
				sm4.radius = r3
				sm4.height = r3 * 1.3
				metal.mesh = sm4
				metal.material_override = _mat(Color(0.55, 0.58, 0.62), Color(0.3, 0.35, 0.4))
				metal.position = Vector3(0, r3 * 0.4, 0)
				container.add_child(metal)


func _sulfur_boulder_in(pos: Vector3, parent: Node3D) -> void:
	# крупный жёлтый валун серы (в контейнере)
	var r := _rng.randf_range(0.7, 1.3)
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.5
	b.mesh = sm
	b.material_override = _mat(Color(1.0, 0.8, 0.15), Color(0.8, 0.6, 0.05))
	b.position = Vector3(0, r * 0.5, 0)
	b.scale = Vector3(1, _rng.randf_range(0.5, 0.8), 1)
	parent.add_child(b)
	for i in range(3):
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.16
		cm.height = _rng.randf_range(0.3, 0.6)
		c.mesh = cm
		c.material_override = _mat(Color(1.0, 0.9, 0.3), Color(1.0, 0.7, 0.1))
		c.position = Vector3(_rng.randf_range(-0.4, 0.4), r * 0.6, _rng.randf_range(-0.4, 0.4))
		parent.add_child(c)


func _ore_crystal(pos: Vector3, color: Color, emissive: Color) -> void:
	for i in range(3):
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.14
		cm.height = _rng.randf_range(0.4, 0.8)
		c.mesh = cm
		c.material_override = _mat(color, emissive)
		c.position = Vector3(pos.x + _rng.randf_range(-0.25, 0.25), pos.y + cm.height * 0.4, pos.z + _rng.randf_range(-0.25, 0.25))
		c.rotation_degrees = Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20))
		add_child(c)


# ---------- бочки / монументы / ящики с лутом ----------

func _cyl_at(pos: Vector3, r: float, h: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.material_override = _mat(color)
	m.position = pos + Vector3(0, h * 0.5, 0)
	(parent if parent else self).add_child(m)
	return m


func _add_barrel(x: float, z: float) -> void:
	var y := _surface_height(x, z)
	var node := Node3D.new()
	node.position = Vector3(x, y, z)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 1.1
	body.mesh = cm
	body.material_override = _mat(Color(0.62, 0.3, 0.14))
	body.position = Vector3(0, 0.55, 0)
	node.add_child(body)
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.47
	bm.bottom_radius = 0.47
	bm.height = 0.14
	band.mesh = bm
	band.material_override = _mat(Color(0.35, 0.35, 0.38))
	band.position = Vector3(0, 0.55, 0)
	node.add_child(band)
	add_child(node)
	_barrel_spots.append({"pos": Vector3(x, y, z), "alive": true, "node": node})


func _add_lootbox(x: float, z: float) -> void:
	var y := _surface_height(x, z)
	var node := Node3D.new()
	node.position = Vector3(x, y, z)
	var crate := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.0, 0.9, 1.0)
	crate.mesh = cm
	crate.material_override = _mat(Color(0.5, 0.4, 0.24))
	crate.position = Vector3(0, 0.45, 0)
	crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(crate)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.06, 0.16, 1.06)
	lid.mesh = lm
	lid.material_override = _mat(Color(0.33, 0.26, 0.16))
	lid.position = Vector3(0, 0.95, 0)
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(lid)
	add_child(node)
	_loot_spots.append({"pos": Vector3(x, y, z), "opened": false, "node": node, "lid": lid})


# открыть ящик и забрать лут (не ломая его)
func _interact_lootbox(origin: Vector3, look_dir: Vector3) -> String:
	var best: Dictionary = {}
	var best_d := 3.4
	for l in _loot_spots:
		if l["opened"]:
			continue
		if _ahead(l["pos"], origin, look_dir, best_d):
			var d: float = (l["pos"] - origin).length()
			if d < best_d:
				best_d = d
				best = l
	if best.is_empty():
		return ""
	best["opened"] = true
	var roll := _rng.randi_range(0, 3)
	var text := ""
	if roll == 0:
		var n := _rng.randi_range(2, 5)
		GameState.add_resource("water", n)
		text = "Вода +%d" % n
	elif roll == 1:
		var n := _rng.randi_range(1, 3)
		GameState.add_resource("meat", n)
		text = "Еда +%d" % n
	elif roll == 2:
		var n := _rng.randi_range(5, 15)
		GameState.add_resource("metal", n)
		text = "Металл +%d" % n
	else:
		var n := _rng.randi_range(15, 40)
		GameState.add_resource("scrap", n)
		text = "Скрап +%d" % n
	# анимация: крышка откидывается
	var lid: Node3D = best["lid"]
	var tw := create_tween()
	tw.tween_property(lid, "position:y", lid.position.y + 0.6, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lid, "rotation:x", -0.9, 0.4)
	if _hud:
		_hud.refresh()
	return text


func _build_barrels() -> void:
	_barrel_spots.clear()
	for i in range(22):
		var pos := _grid_spot(44.0, 16.0)
		_add_barrel(pos.x, pos.z)
	for m in MONUMENTS:
		var mp: Vector3 = m["pos"]
		_add_barrel(mp.x + 6.0, mp.z + 6.0)
		_add_barrel(mp.x - 6.0, mp.z - 6.0)


func _build_monuments() -> void:
	for m in MONUMENTS:
		var mp: Vector3 = m["pos"]
		var kind: String = m["kind"]
		match kind:
			"warehouse": _build_warehouse(mp.x, mp.z)
			"parking": _build_parking(mp.x, mp.z)
			"factory": _build_factory(mp.x, mp.z)
			"npp": _build_npp(mp.x, mp.z)


func _add_monument_model(path: String, x: float, z: float) -> Node3D:
	# скачанная качественная модель монумента (ставится основанием на рельеф)
	var model: Node3D = load(path).instantiate()
	var y := _surface_height(x, z)
	model.position = Vector3(x, y, z)
	add_child(model)
	_force_opaque(model)
	return model


# гарантируем непрозрачность и двухсторонний рендер скачанных моделей
# (защита от «прозрачной карты» из-за обратной намотки граней/альфы)
func _force_opaque(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			if mat is BaseMaterial3D:
				var m: BaseMaterial3D = mat.duplicate()
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, m)


func _build_warehouse(x: float, z: float) -> void:
	# скачанная модель склада (43×59 м)
	_add_monument_model("res://models/monument_warehouse.glb", x, z)
	_add_lootbox(x + 8, z + 10)
	_add_lootbox(x - 8, z + 12)
	_add_lootbox(x + 2, z - 12)
	_add_lootbox(x - 6, z - 10)


func _build_parking(x: float, z: float) -> void:
	# промышленная парковка: потёртый бетон, стёртая разметка, ржавые машины
	var y := _surface_height(x, z)
	var base := Node3D.new()
	base.position = Vector3(x, y, z)
	add_child(base)
	# потёртая бетонная площадка
	_box_at(Vector3(0, -0.05, 0), Vector3(42, 0.2, 42), Color(0.3, 0.3, 0.31), base)
	# стёртая жёлтая разметка (потрескавшаяся — куски с пропусками)
	for i in range(9):
		if i % 3 != 0:
			_box_at(Vector3(-19 + i * 4.7, 0.06, 0), Vector3(0.12, 0.02, 22), Color(0.72, 0.66, 0.32), base)
	# бетонные бордюры по краям
	_box_at(Vector3(-21, 0.3, 0), Vector3(0.5, 0.6, 42), Color(0.4, 0.4, 0.42), base)
	_box_at(Vector3(21, 0.3, 0), Vector3(0.5, 0.6, 42), Color(0.4, 0.4, 0.42), base)
	# ржавые брошенные машины (облезлый кузов)
	_car(Vector3(-7, 0, -8), Color(0.5, 0.22, 0.16), base)
	_car(Vector3(7, 0, 8), Color(0.3, 0.34, 0.38), base)
	_car(Vector3(7, 0, -6), Color(0.4, 0.3, 0.2), base)
	# ржавые бочки-ограждение
	_cyl_at(Vector3(-19, 0, -19), 0.5, 1.0, Color(0.5, 0.28, 0.16), base)
	_cyl_at(Vector3(19, 0, 19), 0.5, 1.0, Color(0.5, 0.28, 0.16), base)
	_add_lootbox(x + 8, z + 8)
	_add_lootbox(x - 8, z - 8)
	_add_lootbox(x + 10, z - 6)


func _car(pos: Vector3, color: Color, parent: Node3D) -> void:
	# простой ржавый легковой автомобиль
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.6, 4.0)
	body.mesh = bm
	body.material_override = _mat(color)
	body.position = pos + Vector3(0, 0.55, 0)
	parent.add_child(body)
	var cab := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.6, 0.5, 1.8)
	cab.mesh = cm
	cab.material_override = _mat(color.darkened(0.25))
	cab.position = pos + Vector3(0, 1.05, -0.2)
	parent.add_child(cab)
	# колёса
	for wx in [-0.75, 0.75]:
		for wz in [-1.3, 1.3]:
			_cyl_at(pos + Vector3(wx, 0, wz), 0.32, 0.3, Color(0.12, 0.12, 0.12), parent)


func _build_factory(x: float, z: float) -> void:
	# заброшенный промышленный завод: бетон, ржавый металл, трубы, технические здания
	var y := _surface_height(x, z)
	var base := Node3D.new()
	base.position = Vector3(x, y, z)
	add_child(base)
	var concrete := Color(0.42, 0.4, 0.38)
	var rust := Color(0.42, 0.26, 0.16)
	var steel := Color(0.35, 0.35, 0.37)
	# главный цех (бетон + ржавая крыша)
	_box_at(Vector3(0, 0, 0), Vector3(28, 8, 20), concrete, base)
	_box_at(Vector3(0, 8, 0), Vector3(29, 0.5, 21), rust, base)
	# техническая пристройка
	_box_at(Vector3(16, 0, 0), Vector3(10, 5, 12), concrete, base)
	# трубы с клапанами
	_cyl_at(Vector3(-10, 0, 0), 0.9, 13.0, rust, base)
	_cyl_at(Vector3(11, 0, 0), 0.9, 13.0, rust, base)
	_cyl_at(Vector3(-10, 0, 6), 0.5, 9.0, steel, base)
	_cyl_at(Vector3(11, 0, 6), 0.5, 9.0, steel, base)
	# дымовые сферы на трубах (ржавые)
	_sphere_at(Vector3(-10, 14.5, 0), 1.5, 1.5, rust, base)
	_sphere_at(Vector3(11, 14.5, 0), 1.5, 1.5, rust, base)
	# ржавые ворота
	_box_at(Vector3(0, 0, 10.2), Vector3(5, 4, 0.3), Color(0.35, 0.24, 0.15), base)
	_add_lootbox(x + 4, z + 4)
	_add_lootbox(x - 4, z - 4)
	_add_lootbox(x + 6, z - 3)
	_add_lootbox(x - 6, z + 3)


func _build_npp(x: float, z: float) -> void:
	# скачанная модель электростанции (реактор + трубы, 33×33 м)
	_add_monument_model("res://models/monument_npp.glb", x, z)
	_add_lootbox(x + 8, z + 8)
	_add_lootbox(x - 8, z + 9)
	_add_lootbox(x + 9, z - 8)
	_add_lootbox(x - 9, z - 8)


# ---------- игрок / животные / HUD ----------

func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScr)
	var fresh := not (GameState.return_to_pos and GameState.last_pos != Vector3.ZERO)
	var pos: Vector3
	if not fresh:
		pos = GameState.last_pos
		GameState.return_to_pos = false
	else:
		pos = _random_spot(20.0)
	_player.position = Vector3(pos.x, pos.y + 1.0, pos.z)
	add_child(_player)
	# гарантируем ресурсы рядом со спавном ТОЛЬКО при свежем старте
	# (иначе при каждом возврате из инвентаря/карты плодятся дубликаты)
	if fresh:
		_spawn_guaranteed_resources(pos)


func _spawn_guaranteed_resources(center: Vector3) -> void:
	# отдельные деревья, камни и сера вокруг точки спавна
	for i in range(6):
		var a := TAU * i / 6.0
		var r := 7.0
		var dx := center.x + cos(a) * r
		var dz := center.z + sin(a) * r
		var tp := Vector3(dx, _surface_height(dx, dz), dz)
		var tree := MeshInstance3D.new()
		tree.mesh = _make_tree_mesh()
		tree.material_override = _vertex_color_material()
		tree.position = tp + Vector3(0, -0.1, 0)
		tree.scale = Vector3.ONE * 1.2
		add_child(tree)
		_tree_spots.append({"pos": tp, "index": -1, "alive": true, "big": false, "node": tree})
	# пара камней
	for i in range(3):
		var a := TAU * i / 3.0 + 0.5
		var dx := center.x + cos(a) * 9.0
		var dz := center.z + sin(a) * 9.0
		var rp := Vector3(dx, _surface_height(dx, dz), dz)
		var rock := MeshInstance3D.new()
		rock.mesh = _make_rock_mesh()
		rock.material_override = _vertex_color_material()
		rock.position = rp + Vector3(0, 0.15, 0)
		rock.scale = Vector3.ONE * 1.3
		add_child(rock)
		_rock_spots.append({"pos": rp, "index": -1, "alive": true, "node": rock})
	# валун серы
	var sx := center.x + 6.0
	var sz := center.z + 6.0
	var sp := Vector3(sx, _surface_height(sx, sz), sz)
	var scont := Node3D.new()
	scont.position = sp
	add_child(scont)
	_sulfur_boulder_in(sp, scont)
	_ore_spots.append({"pos": sp, "kind": 0, "alive": true, "node": scont})


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScr)
	add_child(_hud)
	_hud.bind(_player)
	_player._hud_ref = _hud


func _spawn_animals() -> void:
	for i in range(6):
		_spawn_animal(0)
	for i in range(4):
		_spawn_animal(1)
	for i in range(3):
		_spawn_animal(2)
	for i in range(2):
		_spawn_animal(3)


func _spawn_animal(kind: int) -> void:
	var a := CharacterBody3D.new()
	a.set_script(AnimalScr)
	var pos := _random_spot(12.0)
	a.position = Vector3(pos.x, pos.y + 1.0, pos.z)
	add_child(a)
	a.setup(kind)
	a.died.connect(_on_animal_died)


func _on_animal_died(kind: int) -> void:
	var amount := 1
	if kind == 3:
		amount = 4
	elif kind == 1:
		amount = 3
	elif kind == 2:
		amount = 2
	GameState.add_meat(amount)
	GameState.kills += 1
	if _hud:
		_hud.refresh()
	_spawn_animal(kind)


# ---------- добыча ресурсов ----------

func _harvest(origin: Vector3, look_dir: Vector3) -> String:
	# ищем ближайший объект ПЕРЕД игроком в радиусе 4.5 м
	var best_kind := ""
	var best_spot: Dictionary = {}
	var best_d := 4.5
	for t in _tree_spots:
		if t["alive"] and _ahead(t["pos"], origin, look_dir, best_d):
			var d: float = (t["pos"] - origin).length()
			if d < best_d:
				best_d = d
				best_kind = "tree"
				best_spot = t
	for r in _rock_spots:
		if r["alive"] and _ahead(r["pos"], origin, look_dir, best_d):
			var d: float = (r["pos"] - origin).length()
			if d < best_d:
				best_d = d
				best_kind = "stone"
				best_spot = r
	for o in _ore_spots:
		if o["alive"] and _ahead(o["pos"], origin, look_dir, best_d):
			var d: float = (o["pos"] - origin).length()
			if d < best_d:
				best_d = d
				best_kind = "ore"
				best_spot = o
	for b in _barrel_spots:
		if b["alive"] and _ahead(b["pos"], origin, look_dir, best_d):
			var d: float = (b["pos"] - origin).length()
			if d < best_d:
				best_d = d
				best_kind = "barrel"
				best_spot = b
	if best_kind == "":
		return ""

	best_spot["alive"] = false
	match best_kind:
		"tree":
			var amt := 60 if best_spot.get("big", false) else 25
			GameState.add_resource("wood", int(amt * GameState.harvest_bonus()))
			_remove_resource(best_spot, _trees_mm)
		"stone":
			GameState.add_resource("stone", int(20.0 * GameState.mining_bonus()))
			_remove_resource(best_spot, _rocks_mm)
		"ore":
			if best_spot["kind"] == 0:
				GameState.add_resource("sulfur", int(15.0 * GameState.mining_bonus()))
			elif best_spot["kind"] == 1:
				GameState.add_resource("iron", int(12.0 * GameState.mining_bonus()))
			elif best_spot["kind"] == 2:
				GameState.add_resource("stone", int(20.0 * GameState.mining_bonus()))
			else:
				GameState.add_resource("metal", int(10.0 * GameState.mining_bonus()))
				GameState.add_resource("scrap", int(3.0 * GameState.mining_bonus()))
			_remove_resource(best_spot, null)
		"barrel":
			# бочка даёт от 10 до 50 скрапа
			GameState.add_resource("scrap", _rng.randi_range(10, 50))
			_remove_resource(best_spot, null)
	if _hud:
		_hud.refresh()
	return best_kind


func _ahead(pos: Vector3, origin: Vector3, look_dir: Vector3, max_d: float) -> bool:
	var to: Vector3 = pos - origin
	to.y = 0.0
	var d: float = to.length()
	if d > max_d:
		return false
	if d < 0.05:
		return true
	return to.normalized().dot(look_dir) > 0.3


func _remove_resource(spot: Dictionary, mm: MultiMesh) -> void:
	# если есть отдельный node (гарантированные ресурсы) — удаляем его
	if spot.has("node") and spot["node"] is Node3D:
		(spot["node"] as Node3D).queue_free()
	# иначе скрываем экземпляр MultiMesh
	elif mm and int(spot["index"]) >= 0:
		var t := mm.get_instance_transform(int(spot["index"]))
		t.basis = Basis.IDENTITY.scaled(Vector3.ZERO)
		mm.set_instance_transform(int(spot["index"]), t)

# ---------- строительство ----------

func _box_at(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(color)
	m.position = pos + Vector3(0, size.y * 0.5, 0)
	(parent if parent else self).add_child(m)
	return m


func _sphere_at(pos: Vector3, r: float, h: float, color: Color, parent: Node3D = null, emissive := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h
	m.mesh = sm
	m.material_override = _mat(color, emissive)
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


# строит меши постройки в контейнер parent (локальные координаты от точки pos)
func _make_building(kind: String, parent: Node3D, ghost: bool) -> void:
	parent.scale = Vector3.ONE * 2.0  # все постройки в 2 раза больше
	var mat_col := Color(0.42, 0.3, 0.16)
	if ghost:
		mat_col = Color(0.4, 1.0, 0.4, 0.45)
	match kind:
		"campfire":
			for i in range(6):
				var a := TAU * i / 6.0
				_sphere_at(Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5), 0.15, 0.3, Color(0.4, 0.4, 0.42), parent)
			_sphere_at(Vector3(0, 0.4, 0), 0.25, 0.7, Color(1.0, 0.5, 0.1), parent, Color(1.0, 0.4, 0.05))
		"furnace":
			_box_at(Vector3.ZERO, Vector3(1.0, 1.2, 1.0), Color(0.3, 0.3, 0.32), parent)
			_box_at(Vector3(0, 1.4, 0), Vector3(0.3, 0.5, 0.3), Color(0.25, 0.25, 0.28), parent)
		"wall":
			_box_at(Vector3.ZERO, Vector3(2.5, 2.5, 0.2), mat_col, parent)
		"floor":
			_box_at(Vector3(0, -0.05, 0), Vector3(2.5, 0.1, 2.5), Color(0.45, 0.33, 0.18) if not ghost else mat_col, parent)
		"door":
			_box_at(Vector3.ZERO, Vector3(1.2, 2.2, 0.15), mat_col, parent)
			_box_at(Vector3(0, 1.1, 0), Vector3(0.1, 2.2, 0.25), Color(0.35, 0.25, 0.14) if not ghost else mat_col, parent)
		"bag":
			_box_at(Vector3.ZERO, Vector3(0.9, 0.2, 2.0), Color(0.2, 0.35, 0.25) if not ghost else mat_col, parent)
			_box_at(Vector3(0, 0.25, -0.9), Vector3(0.9, 0.25, 0.4), Color(0.15, 0.28, 0.2) if not ghost else mat_col, parent)
		"workbench":
			# верстак: стол + верстак
			_box_at(Vector3.ZERO, Vector3(1.6, 0.1, 0.9), Color(0.5, 0.36, 0.2) if not ghost else mat_col, parent)
			_box_at(Vector3(-0.6, 0, -0.3), Vector3(0.12, 0.9, 0.12), Color(0.4, 0.28, 0.16) if not ghost else mat_col, parent)
			_box_at(Vector3(0.6, 0, -0.3), Vector3(0.12, 0.9, 0.12), Color(0.4, 0.28, 0.16) if not ghost else mat_col, parent)
			_box_at(Vector3(-0.6, 0, 0.3), Vector3(0.12, 0.9, 0.12), Color(0.4, 0.28, 0.16) if not ghost else mat_col, parent)
			_box_at(Vector3(0.6, 0, 0.3), Vector3(0.12, 0.9, 0.12), Color(0.4, 0.28, 0.16) if not ghost else mat_col, parent)
			_box_at(Vector3(0, 0.35, 0), Vector3(1.3, 0.5, 0.6), Color(0.3, 0.3, 0.32) if not ghost else mat_col, parent)


func _place_building(kind: String, origin: Vector3, look_dir: Vector3, rot: float = 0.0) -> void:
	var px := roundf(origin.x + look_dir.x * 2.0)
	var pz := roundf(origin.z + look_dir.z * 2.0)
	var py := _surface_height(px, pz)
	var node := Node3D.new()
	node.position = Vector3(px, py, pz)
	node.rotation.y = rot
	add_child(node)
	_make_building(kind, node, false)


# строительный призрак
var _ghost: Node3D = null

func _process(delta: float) -> void:
	_update_day_night(delta)
	_update_weather(delta)
	if not GameState.build_mode:
		if _ghost:
			_ghost.queue_free()
			_ghost = null
		return
	# создать/обновить призрак
	if _ghost == null or _ghost.get_child_count() == 0:
		if _ghost:
			_ghost.queue_free()
		_ghost = Node3D.new()
		add_child(_ghost)
		_make_building(GameState.build_kind, _ghost, true)
	if _player:
		var cam: Camera3D = _player.get_node_or_null("Camera3D")
		var fwd := -(_player as Node3D).global_transform.basis.z
		if cam:
			fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var px: float = _player.global_position.x + fwd.x * 2.0
		var pz: float = _player.global_position.z + fwd.z * 2.0
		# привязка к сетке 1 м
		px = roundf(px)
		pz = roundf(pz)
		_ghost.position = Vector3(px, _surface_height(px, pz), pz)
		_ghost.rotation.y = GameState.build_rot
