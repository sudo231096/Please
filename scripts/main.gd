extends Node3D
## Пустошь в духе Rust: выживание от первого лица, оптимизированный ландшафт.

const PlayerScr := preload("res://scripts/player.gd")
const AnimalScr := preload("res://scripts/animal.gd")
const HudScr := preload("res://scripts/hud.gd")

const TERRAIN_N := 160        # ячеек на сторону (6.4 м) — втрое меньше треугольников, рельеф тот же
const TERRAIN_SIZE := 1024.0  # метров
const TERRAIN_CELL := TERRAIN_SIZE / float(TERRAIN_N)
const HALF := TERRAIN_SIZE * 0.5

# остров: радиус суши и уровень воды
const ISLAND_R := 430.0
const WATER_LEVEL := -1.0

# горы: [x, z, высота, радиус] (внутри острова)
const MOUNTAINS := [
	[180.0, 180.0, 15.0, 60.0],
	[-240.0, -120.0, 18.0, 70.0],
	[100.0, -280.0, 13.0, 55.0],
	[-80.0, 260.0, 16.0, 65.0],
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
var _day_length := 2400.0    # 40 минут на полный цикл (день длится долго, не уходит в серое)
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
var _trees_mm_list: Array = []   # MultiMesh для каждого вида дерева
var _rocks_mm: MultiMesh

# монументы (как в Rust): склад, парковка, завод, АЭС — внутри острова
const MONUMENTS := [
	{"kind": "warehouse", "pos": Vector3(-260.0, 0, -220.0)},
	{"kind": "parking", "pos": Vector3(280.0, 0, -150.0)},
	{"kind": "factory", "pos": Vector3(-230.0, 0, 280.0)},
	{"kind": "npp", "pos": Vector3(260.0, 0, 250.0)},
]


func _ready() -> void:
	add_to_group("terrain")
	# на сервере у каждого мира своё детерминированное семя (Server 1..5 — разные миры),
	# в одиночной игре — случайное
	if GameState.active_server_id > 0 and GameState.world_seed != 0:
		_rng.seed = GameState.world_seed
	else:
		_rng.seed = randi()
	if not GameState.return_to_pos:
		# свежий запуск или рестарт после смерти — сбрасываем прогресс
		GameState.reset_run()
	_build_puddles()
	_build_sky()
	_build_ground()
	_build_water()
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
	_setup_multiplayer()
	_restore_base()
	_spawn_bandits()
	_setup_events()


const BanditScr := preload("res://scripts/bandit.gd")
const EventsScr := preload("res://scripts/world_events.gd")

var _events: Node3D = null


## Восстановление базы игрока из сохранения
func _restore_base() -> void:
	GameState.structures.clear()
	if GameState.saved_structures.is_empty():
		return
	for d in GameState.saved_structures:
		var kind: String = String(d["kind"])
		if not GameState.BUILD_CATALOG.has(kind):
			continue
		var pos: Vector3 = d["pos"]
		var node := Node3D.new()
		node.position = pos
		node.rotation.y = float(d.get("rot", 0.0))
		add_child(node)
		_make_building(kind, node, false, int(d.get("tier", 0)))
		_add_build_collision(node, kind)
		_set_lod(node, 220.0)
		GameState.structures.append({"kind": kind, "pos": pos, "rot": float(d.get("rot", 0.0)),
			"tier": int(d.get("tier", 0)), "hp": float(d.get("hp", 250.0)),
			"owner": String(d.get("owner", GameState.player_name)), "node": node})


## NPC-бандиты: сложность зависит от опасности зоны
func _spawn_bandits() -> void:
	# у монументов — сильные, в лесу — слабые
	for m in MONUMENTS:
		var mp: Vector3 = m["pos"]
		var n := 2 + _rng.randi() % 2
		for i in range(n):
			var x: float = mp.x + _rng.randf_range(-26.0, 26.0)
			var z: float = mp.z + _rng.randf_range(-26.0, 26.0)
			if not _on_land(x, z):
				continue
			_make_bandit(x, z, 2)
	# бродяги по карте
	for i in range(7):
		var pos := _grid_spot(30.0, 12.0)
		_make_bandit(pos.x, pos.z, _rng.randi() % 2)


func _make_bandit(x: float, z: float, tier: int) -> Node3D:
	var b: CharacterBody3D = BanditScr.new()
	add_child(b)
	b.global_position = Vector3(x, _surface_height(x, z), z)
	b.setup(tier)
	b.died.connect(func(t: int) -> void: _on_bandit_died(t))
	return b


func _on_bandit_died(tier: int) -> void:
	GameState.kills += 1
	# через время появляется новый бандит в другом месте
	await get_tree().create_timer(60.0).timeout
	if not is_inside_tree():
		return
	var pos := _grid_spot(30.0, 12.0)
	_make_bandit(pos.x, pos.z, tier)


func _setup_events() -> void:
	_events = EventsScr.new()
	_events.name = "WorldEvents"
	add_child(_events)


## Урон постройке рейдовым зарядом. Возвращает описание результата.
func raid_explode(origin: Vector3, tool_id: String) -> String:
	if not GameState.RAID_TOOLS.has(tool_id):
		return "Неизвестный заряд"
	if GameState.count(tool_id) <= 0:
		return "Нет заряда: " + String(GameState.RAID_TOOLS[tool_id]["name"])
	var info: Dictionary = GameState.RAID_TOOLS[tool_id]
	var radius: float = float(info["radius"])
	var dmg: float = float(info["dmg"])
	# ищем постройки в радиусе
	var hit: Array = []
	for st in GameState.structures:
		var sp: Vector3 = st["pos"]
		if sp.distance_to(origin) <= radius + 1.5:
			hit.append(st)
	if hit.is_empty():
		return "Рядом нет построек"
	GameState.remove_item(tool_id, 1)
	_explosion_fx(origin, radius)
	var destroyed := 0
	var damaged := 0
	for st in hit:
		var tier: int = int(st["tier"])
		# камень держит вдвое лучше
		var resist: float = 1.0 if tier == 0 else 0.5
		st["hp"] = float(st.get("hp", GameState.BUILD_HP[tier])) - dmg * resist
		if float(st["hp"]) <= 0.0:
			var n = st.get("node")
			if n != null and is_instance_valid(n):
				n.queue_free()
			destroyed += 1
		else:
			damaged += 1
	for st in hit:
		if float(st.get("hp", 1.0)) <= 0.0:
			GameState.structures.erase(st)
	GameState.save_inventory()
	return "Взрыв: разрушено %d, повреждено %d" % [destroyed, damaged]


func _explosion_fx(pos: Vector3, radius: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	for i in range(7):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r: float = radius * _rng.randf_range(0.3, 0.7)
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh = sm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mt.emission_enabled = true
		mt.emission = Color(1.0, 0.45, 0.08)
		mi.material_override = mt
		mi.position = Vector3(_rng.randf_range(-2, 2), _rng.randf_range(0.5, 3.0), _rng.randf_range(-2, 2))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3(2.2, 2.2, 2.2), 0.5)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(root.queue_free)


func _setup_multiplayer() -> void:
	# отрисовка других игроков этого сервера (данные приходят только от сервера)
	if GameState.active_server_id <= 0:
		return
	var rp := preload("res://scripts/remote_players.gd").new()
	rp.name = "RemotePlayers"
	add_child(rp)


# ---------- высота рельефа (остров) ----------

func _island_mask(x: float, z: float) -> float:
	# 1 в центре острова, 0 далеко в море (плавный берег)
	var d := sqrt(x * x + z * z)
	return clampf(1.0 - smoothstep(ISLAND_R - 70.0, ISLAND_R + 15.0, d), 0.0, 1.0)


func _on_land(x: float, z: float) -> bool:
	# достаточно ли высоко над водой, чтобы здесь что-то стояло
	return _surface_height(x, z) > WATER_LEVEL + 0.3


func _ground_height(x: float, z: float) -> float:
	var mask := _island_mask(x, z)
	var h := 0.0
	# многослойный шум — холмистая местность как в Rust
	h += 4.0 * sin(x * 0.006 + 1.3) * cos(z * 0.007 + 0.7)
	h += 2.2 * sin(x * 0.013 + 0.5) * sin(z * 0.011 + 2.1)
	h += 1.0 * sin(x * 0.027 + 0.2) * cos(z * 0.023 + 1.6)
	h += 0.5 * sin(x * 0.051 + 3.0) * sin(z * 0.047 + 0.9)
	# мелкие бугры и неровности
	h += 0.6 * sin(x * 0.09 + 1.1) * cos(z * 0.083 + 0.3)
	h += 0.3 * sin(x * 0.17 + 0.7) * sin(z * 0.19 + 2.3)
	for p in MOUNTAINS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var d2: float = dx * dx + dz * dz
		h += p[2] * exp(-d2 / (2.0 * p[3] * p[3]))
	# лужи: плавные углубления на суше (небольшие озёра)
	for p in _puddles:
		var dx: float = x - p["x"]
		var dz: float = z - p["z"]
		var d: float = sqrt(dx * dx + dz * dz)
		var r: float = p["r"]
		if d < r:
			var k := 1.0 - d / r
			h = lerpf(h, -1.4, k * 0.7)
	# суша: поднимаем базовый рельеф и умножаем на маску острова
	var land := (h + 7.0) * mask
	# море за берегом уходит на морское дно
	var seafloor := (WATER_LEVEL - 6.0) * (1.0 - mask)
	return land + seafloor


func _surface_height(x: float, z: float) -> float:
	# точная высота видимого меша: интерполяция ПО ТЕМ ЖЕ ТРЕУГОЛЬНИКАМ,
	# что и в _build_ground — объекты стоят ровно на поверхности, не «летают»
	if _heights.size() == 0:
		return _ground_height(x, z)
	var n := TERRAIN_N + 1
	var fx := (x + HALF) / TERRAIN_CELL
	var fz := (z + HALF) / TERRAIN_CELL
	var x0 := clampi(int(floor(fx)), 0, TERRAIN_N - 1)
	var z0 := clampi(int(floor(fz)), 0, TERRAIN_N - 1)
	var x1 := mini(x0 + 1, TERRAIN_N)
	var z1 := mini(z0 + 1, TERRAIN_N)
	var tx := clampf(fx - float(x0), 0.0, 1.0)
	var tz := clampf(fz - float(z0), 0.0, 1.0)
	var h00 := _heights[z0 * n + x0]
	var h10 := _heights[z0 * n + x1]
	var h01 := _heights[z1 * n + x0]
	var h11 := _heights[z1 * n + x1]
	# диагональ сетки идёт из (x, z+1) в (x+1, z): треугольники
	# A=(x,z),(x,z+1),(x+1,z)  и  B=(x+1,z),(x,z+1),(x+1,z+1)
	if tx + tz <= 1.0:
		# треугольник A
		return h00 + tx * (h10 - h00) + tz * (h01 - h00)
	else:
		# треугольник B
		return h11 + (1.0 - tx) * (h01 - h11) + (1.0 - tz) * (h10 - h11)


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


# кэш материалов: одинаковый цвет = один материал (меньше состояний рендера)
var _mat_cache := {}

func _mat(color: Color, emissive := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var key := "%d_%d" % [color.to_rgba32(), emissive.to_rgba32()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive.a > 0.0:
		m.emission_enabled = true
		m.emission = emissive
	_mat_cache[key] = m
	return m


# ---------- геометрия для MultiMesh (вершинные цвета, без нормалей) ----------

func _add_tri(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var base := verts.size()
	verts.append_array([a, b, c])
	cols.append(color); cols.append(color); cols.append(color)
	idx.append_array([base, base + 1, base + 2])


func _surface_arrays(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, uv_scale: float) -> Array:
	# собрать массивы поверхности с UV (планарная развёртка — для тайлинга текстур)
	var uvs := PackedVector2Array()
	for v in verts:
		# развёртка по «цилиндру» вокруг Y: X по окружности, Y по высоте
		uvs.append(Vector2((atan2(v.z, v.x) / TAU + 0.5) * uv_scale, -v.y * uv_scale * 0.5))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = _flat_normals(verts, idx)
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


# вид 0 — ель (конусы хвои), вид 1 — лиственное (шар кроны), вид 2 — сухое/мёртвое дерево
func _make_tree_mesh(species: int = 0) -> ArrayMesh:
	var am := ArrayMesh.new()
	# --- surface 0: СТВОЛ (текстура коры) ---
	var tv := PackedVector3Array()
	var tc := PackedColorArray()
	var ti := PackedInt32Array()
	var brown := Color(0.62, 0.5, 0.36)
	match species:
		1:
			# лиственное: толстый ствол
			_add_box(tv, tc, ti, Vector3(0, 0.8, 0), Vector3(0.24, 1.6, 0.24), brown)
			# пара ветвей
			_add_box(tv, tc, ti, Vector3(0.3, 1.5, 0), Vector3(0.5, 0.09, 0.09), brown)
			_add_box(tv, tc, ti, Vector3(-0.3, 1.7, 0), Vector3(0.5, 0.09, 0.09), brown)
		2:
			# сухое дерево: кривой ствол + голые ветви
			_add_box(tv, tc, ti, Vector3(0, 1.0, 0), Vector3(0.2, 2.0, 0.2), brown.darkened(0.25))
			_add_box(tv, tc, ti, Vector3(0.35, 1.7, 0.1), Vector3(0.7, 0.08, 0.08), brown.darkened(0.3))
			_add_box(tv, tc, ti, Vector3(-0.32, 2.1, -0.1), Vector3(0.62, 0.07, 0.07), brown.darkened(0.3))
			_add_box(tv, tc, ti, Vector3(0.15, 2.4, 0.25), Vector3(0.45, 0.06, 0.06), brown.darkened(0.3))
		_:
			# ель: тонкий ствол
			_add_box(tv, tc, ti, Vector3(0, 0.55, 0), Vector3(0.16, 1.1, 0.16), brown)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(tv, tc, ti, 2.0))

	# --- surface 1: ЛИСТВА (текстура растительности) ---
	if species != 2:
		var fv := PackedVector3Array()
		var fc := PackedColorArray()
		var fi := PackedInt32Array()
		var green := Color(0.75, 0.95, 0.7)
		if species == 1:
			# лиственное: плотная шапка из нескольких сфер-кластеров
			_add_sphere_cluster(fv, fc, fi, Vector3(0, 2.1, 0), 0.95, green)
			_add_sphere_cluster(fv, fc, fi, Vector3(0.5, 1.85, 0.2), 0.62, green.darkened(0.06))
			_add_sphere_cluster(fv, fc, fi, Vector3(-0.45, 1.9, -0.25), 0.6, green.darkened(0.04))
			_add_sphere_cluster(fv, fc, fi, Vector3(0.1, 2.5, -0.3), 0.55, green.lightened(0.05))
		else:
			# ель: три плотных яруса хвои
			_add_cone(fv, fc, fi, 0.95, 0.9, 1.35, green)
			_add_cone(fv, fc, fi, 1.7, 0.68, 1.15, green.darkened(0.05))
			_add_cone(fv, fc, fi, 2.4, 0.45, 0.95, green.lightened(0.05))
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _surface_arrays(fv, fc, fi, 3.0))
	return am


func _add_sphere_cluster(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, center: Vector3, r: float, color: Color) -> void:
	# низкополигональная сфера-крона (икосферо-подобная, дёшево для мобилы)
	var rings := 4
	var segs := 7
	var base := verts.size()
	for ring in range(rings + 1):
		var phi := PI * float(ring) / rings
		var y := cos(phi) * r
		var rr := sin(phi) * r
		for s in range(segs):
			var th := TAU * float(s) / segs
			verts.append(center + Vector3(cos(th) * rr, y, sin(th) * rr))
			cols.append(color)
	for ring in range(rings):
		for s in range(segs):
			var a := base + ring * segs + s
			var b := base + ring * segs + (s + 1) % segs
			var c := base + (ring + 1) * segs + s
			var d := base + (ring + 1) * segs + (s + 1) % segs
			idx.append_array([a, c, b, b, c, d])


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
	# рельеф с вершинными цветами (биомы), без текстуры — для деревьев/камней
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 1.0
	m.metallic = 0.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # строго непрозрачный
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ground_pbr_material() -> StandardMaterial3D:
	# ЗЕМЛЯ: скачанная PBR-текстура (ambientCG, CC0): Albedo + Normal + Roughness.
	# Вершинные цвета биомов умножаются на текстуру — детализация + разные зоны.
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/ground_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://textures/ground_normal.jpg")
	m.normal_scale = 1.0
	m.roughness_texture = load("res://textures/ground_rough.jpg")
	m.roughness = 1.0
	m.metallic = 0.0
	m.vertex_color_use_as_albedo = true  # смешивание с цветами биомов
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# лёгкое затухание детализации вдали (без резкого муара)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _bark_material() -> StandardMaterial3D:
	# КОРА: скачанная PBR-текстура коры (ambientCG, CC0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/bark_albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://textures/bark_normal.jpg")
	m.roughness_texture = load("res://textures/bark_rough.jpg")
	m.roughness = 1.0
	m.metallic = 0.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _foliage_material() -> StandardMaterial3D:
	# ЛИСТВА: скачанная PBR-текстура растительности (ambientCG, CC0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/foliage_albedo.jpg")
	m.albedo_color = Color(0.85, 1.0, 0.8)
	m.normal_enabled = true
	m.normal_texture = load("res://textures/foliage_normal.jpg")
	m.roughness_texture = load("res://textures/foliage_rough.jpg")
	m.roughness = 1.0
	m.metallic = 0.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
	env.background_color = Color(0.35, 0.55, 0.85)  # запасной синий фон (не серый)
	var sky := Sky.new()
	var skymat := ProceduralSkyMaterial.new()
	# яркое дневное небо — глубокий синий верх, светлый горизонт
	skymat.sky_top_color = Color(0.22, 0.5, 0.88)
	skymat.sky_horizon_color = Color(0.76, 0.85, 0.95)
	skymat.ground_bottom_color = Color(0.3, 0.27, 0.22)
	skymat.ground_horizon_color = Color(0.66, 0.66, 0.6)
	sky.sky_material = skymat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	_skymat = skymat
	_env = env
	# кинематографичная цветокоррекция: фильмический тонмаппинг + мягкий bloom
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.glow_enabled = false   # свечение дорого для мобильного GPU
	env.glow_intensity = 0.35
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	# лёгкая подкрутка насыщенности и контраста
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	env.adjustment_contrast = 1.06
	# лёгкая дымка на дальности — НЕ серый туман (почти не трогает небо)
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.76, 0.88)
	env.fog_density = 0.001
	env.fog_sky_affect = 0.1
	# SSAO — затенение в углублениях и у оснований объектов (глубина, как в Rust)
	env.ssao_enabled = false   # SSAO очень дорог на телефоне
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.2
	env.ssao_power = 2.0
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.06
	env.ssao_sharpness = 0.98
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 32, 0)
	sun.light_color = Color(1.0, 0.95, 0.85)  # тёплый солнечный свет
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = false
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_sun = sun
	# заполняющий свет (мягчит тени, подсвечивает тёмные стороны)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -150, 0)
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	add_child(fill)
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


var _dn_acc := 0.0

func _update_day_night(delta: float) -> void:
	_time_of_day = fmod(_time_of_day + delta / _day_length, 1.0)
	# цвета неба/света меняются медленно — пересчитываем 5 раз в секунду, а не 60
	_dn_acc += delta
	if _dn_acc < 0.2:
		if _sun_disc and _player and _sun_disc.is_inside_tree() and _sun:
			_sun_disc.global_position = _player.global_position + (-_sun.global_transform.basis.z) * 400.0
		return
	_dn_acc = 0.0
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


func _build_water() -> void:
	# море вокруг острова — полупрозрачная вода с бликом (fresnel-подобный вид)
	var plane := PlaneMesh.new()
	plane.size = Vector2(TERRAIN_SIZE * 2.5, TERRAIN_SIZE * 2.5)
	var w := MeshInstance3D.new()
	w.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.4, 0.6, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.02
	mat.metallic = 0.35
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.18, 0.3)
	mat.emission_energy = 0.5
	w.material_override = mat
	w.position = Vector3(0, WATER_LEVEL, 0)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)
	# второй слой воды ниже — глубина цвета
	var plane2 := PlaneMesh.new()
	plane2.size = Vector2(TERRAIN_SIZE * 2.5, TERRAIN_SIZE * 2.5)
	var w2 := MeshInstance3D.new()
	w2.mesh = plane2
	var mat2 := StandardMaterial3D.new()
	mat2.albedo_color = Color(0.03, 0.2, 0.34, 0.6)
	mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat2.roughness = 0.5
	w2.material_override = mat2
	w2.position = Vector3(0, WATER_LEVEL - 2.0, 0)
	w2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w2)


func _build_ground() -> void:
	# процедурный остров (единый источник высоты _ground_height —
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
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var grass := Color(0.32, 0.5, 0.2)
	var dark := Color(0.24, 0.4, 0.16)
	var dirt := Color(0.47, 0.38, 0.25)
	var sand := Color(0.78, 0.72, 0.52)
	var rock := Color(0.42, 0.42, 0.46)
	var snow := Color(0.93, 0.95, 0.98)
	var seabed := Color(0.45, 0.4, 0.3)
	for z in range(n):
		for x in range(n):
			var wx := -HALF + x * TERRAIN_CELL
			var wz := -HALF + z * TERRAIN_CELL
			var h := _heights[z * n + x]
			var mask := _island_mask(wx, wz)
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
			if h < WATER_LEVEL:
				# морское дно
				c = seabed.lerp(Color(0.5, 0.5, 0.44), clampf(-h * 0.1, 0.0, 1.0))
			elif pf > 0.12:
				# внутренние озёра
				c = Color(0.2, 0.45, 0.6).lerp(Color(0.35, 0.6, 0.75), pf)
			elif mask < 0.35:
				# песчаный берег
				c = sand
			elif h > 18.0:
				c = snow
			elif h > 10.0:
				c = rock
			elif h > 3.0:
				c = grass
			else:
				c = dark
			# земляные проплешины в низинах (только на суше)
			if h < 3.5 and h >= WATER_LEVEL and pf <= 0.12 and mask >= 0.35:
				c = c.lerp(dirt, _color_noise(wx, wz) * 0.5)
			# крутые склоны переходят в скалу
			if slope > 0.28 and h >= WATER_LEVEL and pf <= 0.12:
				c = c.lerp(rock, clampf((slope - 0.28) / 0.45, 0.0, 1.0))
			# естественная пятнистость тона
			var v := _color_noise(wx * 1.7, wz * 1.7 + 9.0)
			c = c.lightened((v - 0.5) * 0.14)
			cols.append(c)
			# UV для тайлинга PBR-текстуры земли (1 тайл = 8 м, без растяжения)
			uvs.append(Vector2(wx / 8.0, wz / 8.0))
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
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ground_pbr_material()
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
	# грунтовые дороги: от центра к каждому монументу + главная магистраль
	var center := Vector2.ZERO
	for m in MONUMENTS:
		_add_ribbon(center.x, center.y, m["pos"].x, m["pos"].z, 6.0, Color(0.42, 0.36, 0.26), 0.08)
	_add_ribbon(-380.0, 60.0, 380.0, -60.0, 7.0, Color(0.4, 0.34, 0.25), 0.08)
	_add_ribbon(-60.0, -380.0, 60.0, 380.0, 7.0, Color(0.4, 0.34, 0.25), 0.08)


func _random_spot(min_r: float) -> Vector3:
	# случайная точка НА СУШЕ (с отбраковкой точек в море)
	for attempt in range(60):
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(min_r, ISLAND_R - 30.0)
		var x := cos(ang) * r
		var z := sin(ang) * r
		if _on_land(x, z):
			return Vector3(x, _surface_height(x, z), z)
	return Vector3(0, _surface_height(0, 0), 0)


func _grid_spot(grid_size: float, jitter: float) -> Vector3:
	# равномерное распределение по сетке, только по суше (как в Rust — ресурсы по всему острову)
	var cols := int(TERRAIN_SIZE / grid_size)
	var cell := int(TERRAIN_SIZE / float(cols))
	for attempt in range(60):
		var cx := _rng.randi_range(0, cols - 1)
		var cz := _rng.randi_range(0, cols - 1)
		var x := -HALF + (cx + 0.5) * cell + _rng.randf_range(-jitter, jitter)
		var z := -HALF + (cz + 0.5) * cell + _rng.randf_range(-jitter, jitter)
		if _on_land(x, z):
			return Vector3(x, _surface_height(x, z), z)
	return Vector3(0, _surface_height(0, 0), 0)


# ---------- деревья / камни / руды / трава (MultiMesh — оптимизация) ----------

func _build_trees() -> void:
	# три вида деревьев: 0=ель, 1=лиственное, 2=сухое. Каждый вид — свой MultiMesh
	# (surface 0 = кора с PBR-текстурой, surface 1 = листва с PBR-текстурой)
	_tree_spots.clear()
	_trees_mm_list.clear()
	var counts := [110, 70, 35]   # ели, лиственные, сухие
	var names := ["TreesPine", "TreesLeafy", "TreesDead"]
	for species in range(3):
		var cnt: int = counts[species]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _make_tree_mesh(species)
		mm.instance_count = cnt
		for i in range(cnt):
			var pos := _grid_spot(24.0, 10.0)
			var big := _rng.randf() < 0.3
			var s: float
			if species == 1:
				s = _rng.randf_range(1.6, 2.4) if big else _rng.randf_range(0.9, 1.5)
			elif species == 2:
				s = _rng.randf_range(0.9, 1.6)
			else:
				s = _rng.randf_range(2.2, 3.2) if big else _rng.randf_range(0.8, 1.6)
			var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos)
			t = t.scaled_local(Vector3(s, s, s))
			mm.set_instance_transform(i, t)
			_tree_spots.append({"pos": pos, "index": i, "alive": true, "big": big, "mm": mm})
		# кора и листва — раздельные материалы со скачанными PBR-текстурами
		# (задаём прямо на поверхностях меша: MultiMesh не поддерживает override по поверхностям)
		var tmesh: ArrayMesh = mm.mesh
		tmesh.surface_set_material(0, _bark_material())
		if tmesh.get_surface_count() > 1:
			tmesh.surface_set_material(1, _foliage_material())
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.name = names[species]
		# LOD по дальности: далёкие деревья не рисуются
		inst.visibility_range_end = 260.0
		inst.visibility_range_end_margin = 30.0
		add_child(inst)
		_trees_mm_list.append(mm)
	# --- два скачанных вида деревьев (Quaternius, CC0): берёза и клён ---
	_build_downloaded_trees("res://models/tree_birch.glb", 85, 7.5, 10.5, "TreesBirch")
	_build_downloaded_trees("res://models/tree_maple.glb", 70, 8.0, 12.0, "TreesMaple")
	_trees_mm = _trees_mm_list[0] if _trees_mm_list.size() > 0 else null


func _build_downloaded_trees(path: String, count: int, hmin: float, hmax: float, node_name: String) -> void:
	# берём меш прямо из скачанной GLB (кора и листва — собственные текстуры модели)
	# и размножаем его через MultiMesh: дёшево для мобилы и даёт естественный лес
	if not ResourceLoader.exists(path):
		push_warning("Нет модели дерева: " + path)
		return
	var scene: PackedScene = load(path)
	var inst_root: Node3D = scene.instantiate()
	var src_mesh: ArrayMesh = null
	var src_h := 1.0
	for mi in inst_root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh != null:
			src_mesh = mi.mesh
			src_h = maxf(mi.mesh.get_aabb().size.y, 0.001)
			break
	inst_root.queue_free()
	if src_mesh == null:
		push_warning("В модели нет меша: " + path)
		return
	# материалы модели: непрозрачные, двухсторонние (листва — плоскости)
	for si in range(src_mesh.get_surface_count()):
		var mat: Material = src_mesh.surface_get_material(si)
		if mat is BaseMaterial3D:
			var m: BaseMaterial3D = mat.duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.roughness = 0.9
			src_mesh.surface_set_material(si, m)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = src_mesh
	mm.instance_count = count
	for i in range(count):
		var pos := _grid_spot(26.0, 11.0)
		# масштаб выводим из желаемой высоты в метрах — пропорции модели сохраняются
		var want_h := _rng.randf_range(hmin, hmax)
		var s: float = want_h / src_h
		# основание чуть утоплено, чтобы дерево не парило на неровностях
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos - Vector3(0, 0.15, 0))
		t = t.scaled_local(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
		_tree_spots.append({"pos": pos, "index": i, "alive": true, "big": want_h > (hmin + hmax) * 0.5, "mm": mm})
		# коллизия ствола: игрок не проходит сквозь дерево
		_add_trunk_collision(pos, want_h)
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.name = node_name
	# LOD по дальности: далёкие деревья этого вида не рисуются (производительность)
	node.visibility_range_end = 200.0
	node.visibility_range_end_margin = 30.0
	add_child(node)
	_trees_mm_list.append(mm)


func _add_trunk_collision(pos: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = clampf(height * 0.045, 0.22, 0.6)
	cap.height = height
	cs.shape = cap
	cs.position = Vector3(0, height * 0.5, 0)
	body.add_child(cs)
	body.position = pos
	add_child(body)


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
		t = t.scaled_local(Vector3(s, s * _rng.randf_range(0.6, 1.0), s))
		mm.set_instance_transform(i, t)
		_rock_spots.append({"pos": pos, "index": i, "alive": true})
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _terrain_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = 220.0
	inst.visibility_range_end_margin = 30.0
	inst.name = "Rocks"
	add_child(inst)
	_rocks_mm = mm


func _build_grass() -> void:
	# ТРАВА: основание каждого пучка утоплено в землю (никогда не висит в воздухе).
	# Ставим только на пологой суше выше воды, вдали от берега.
	var mesh := _make_grass_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var target := 1400
	var placed: Array = []
	var attempts := 0
	while placed.size() < target and attempts < target * 8:
		attempts += 1
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(6.0, ISLAND_R - 45.0)
		var x := cos(ang) * r
		var z := sin(ang) * r
		var h := _surface_height(x, z)
		# только уверенно над водой (не на пляже/в воде)
		if h < WATER_LEVEL + 1.2:
			continue
		# не на крутых склонах — иначе широкий пучок торчит углами
		var e := 1.2
		var nx := _surface_height(x + e, z) - _surface_height(x - e, z)
		var nz := _surface_height(x, z + e) - _surface_height(x, z - e)
		var slope := Vector2(nx, nz).length() / (2.0 * e)
		if slope > 0.35:
			continue
		# отбраковка резких перепадов рядом (обрывы) — трава не должна тонуть в стене
		var around_max := maxf(maxf(_surface_height(x + e, z), _surface_height(x - e, z)),
			maxf(_surface_height(x, z + e), _surface_height(x, z - e)))
		var around_min := minf(minf(_surface_height(x + e, z), _surface_height(x - e, z)),
			minf(_surface_height(x, z + e), _surface_height(x, z - e)))
		if around_max - around_min > 1.2:
			continue
		placed.append(Vector3(x, h, z))
	# ВАЖНО: instance_count задаём ДО записи трансформов (иначе буфер обнуляется)
	mm.instance_count = placed.size()
	for i in range(placed.size()):
		var p: Vector3 = placed[i]
		var s := _rng.randf_range(0.7, 1.5)
		# КЛЮЧЕВОЕ: опускаем основание НИЖЕ поверхности на величину, зависящую от масштаба —
		# трава «врастает» в землю и не может парить даже на неровностях
		var sink := 0.12 * s
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, p.y - sink, p.z))
		t = t.scaled_local(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _grass_material()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# дальность прорисовки травы (оптимизация: далёкая трава не рисуется)
	inst.visibility_range_end = 85.0
	inst.visibility_range_end_margin = 15.0
	inst.name = "Grass"
	add_child(inst)



# LOD: скрывать мелкие объекты на расстоянии (сильно снижает draw calls)
func _set_lod(node: Node3D, dist: float) -> void:
	for mi in node.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = mi
		g.visibility_range_end = dist
		g.visibility_range_end_margin = dist * 0.15
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_ores() -> void:
	# руды: 0=сера (жёлтые кристаллы), 1=железо (ржавый камень), 2=камень (серый валун), 3=металл (блестящий лом)
	_ore_spots.clear()
	for i in range(60):
		var pos := _grid_spot(20.0, 8.0)
		var kind := _rng.randi_range(0, 3)
		var container := Node3D.new()
		container.position = pos
		add_child(container)
		_ore_spots.append({"pos": pos, "kind": kind, "alive": true, "node": container})
		match kind:
			0: _ore_sulfur(container)
			1: _ore_iron(container)
			2: _ore_stone(container)
			3: _ore_metal(container)
		_set_lod(container, 140.0)


# --- отдельные модели руды (основание каждого меша на y=0, стоит на земле) ---

func _ore_sulfur(parent: Node3D) -> void:
	# сера: пучок ярких жёлтых светящихся кристаллов
	for i in range(4):
		var h := _rng.randf_range(0.5, 1.1)
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = _rng.randf_range(0.14, 0.24)
		cm.height = h
		c.mesh = cm
		c.material_override = _mat(Color(1.0, 0.85, 0.15), Color(0.85, 0.6, 0.05))
		c.position = Vector3(_rng.randf_range(-0.4, 0.4), h * 0.5, _rng.randf_range(-0.4, 0.4))
		c.rotation_degrees = Vector3(_rng.randf_range(-18, 18), 0, _rng.randf_range(-18, 18))
		parent.add_child(c)


func _ore_iron(parent: Node3D) -> void:
	# железо: тёмный камень с ржаво-оранжевыми прожилками
	var r := _rng.randf_range(0.6, 1.0)
	var rock := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.5
	rock.mesh = sm
	rock.material_override = _mat(Color(0.28, 0.22, 0.2))
	rock.position = Vector3(0, r * 0.5, 0)
	rock.scale = Vector3(1, _rng.randf_range(0.55, 0.8), 1)
	parent.add_child(rock)
	for i in range(3):
		var vein := MeshInstance3D.new()
		var vm := SphereMesh.new()
		vm.radius = r * 0.3
		vm.height = r * 0.5
		vein.mesh = vm
		vein.material_override = _mat(Color(0.62, 0.3, 0.12))
		vein.position = Vector3(_rng.randf_range(-r * 0.5, r * 0.5), _rng.randf_range(r * 0.4, r * 0.9), _rng.randf_range(-r * 0.5, r * 0.5))
		parent.add_child(vein)


func _ore_stone(parent: Node3D) -> void:
	# камень: серый неровный валун
	var r := _rng.randf_range(0.6, 1.2)
	var stone := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.5
	stone.mesh = sm
	stone.material_override = _mat(Color(0.55, 0.55, 0.6))
	stone.position = Vector3(0, r * 0.45, 0)
	stone.scale = Vector3(_rng.randf_range(0.8, 1.2), _rng.randf_range(0.5, 0.8), _rng.randf_range(0.8, 1.2))
	parent.add_child(stone)


func _ore_metal(parent: Node3D) -> void:
	# металл: блестящий металлический лом (куски под углами)
	for i in range(3):
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_rng.randf_range(0.4, 0.8), _rng.randf_range(0.1, 0.2), _rng.randf_range(0.4, 0.8))
		m.mesh = bm
		m.material_override = _mat(Color(0.58, 0.6, 0.64), Color(0.25, 0.3, 0.35))
		m.position = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0.1, 0.4), _rng.randf_range(-0.4, 0.4))
		m.rotation_degrees = Vector3(_rng.randf_range(-25, 25), _rng.randf_range(0, 180), _rng.randf_range(-25, 25))
		parent.add_child(m)


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
	_set_lod(node, 130.0)
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
	_set_lod(node, 130.0)
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
	_set_lod(model, 400.0)
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
	_ore_sulfur(scont)
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
			_remove_resource(best_spot, best_spot.get("mm", _trees_mm))
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
func _make_building(kind: String, parent: Node3D, ghost: bool, tier: int = 0) -> void:
	# tier 0 = дерево, tier 1 = камень/металл (улучшенная постройка)
	var wood_c := Color(0.46, 0.33, 0.18)
	var wood_d := Color(0.36, 0.25, 0.13)
	if tier > 0:
		wood_c = Color(0.46, 0.46, 0.48)
		wood_d = Color(0.36, 0.36, 0.38)
	var mat_col := wood_c
	if ghost:
		mat_col = Color(0.4, 1.0, 0.4, 0.45)
	var C := func(c: Color) -> Color: return mat_col if ghost else c

	match kind:
		"foundation":
			_box_at(Vector3(0, -0.15, 0), Vector3(3.0, 0.3, 3.0), C.call(wood_c), parent)
			for sx in [-1.35, 1.35]:
				for sz in [-1.35, 1.35]:
					_box_at(Vector3(sx, -0.75, sz), Vector3(0.25, 1.2, 0.25), C.call(wood_d), parent)
		"foundation_tri":
			_box_at(Vector3(0.5, -0.15, 0), Vector3(2.0, 0.3, 3.0), C.call(wood_c), parent)
			_box_at(Vector3(-0.8, -0.15, 0.7), Vector3(1.2, 0.3, 1.4), C.call(wood_c), parent)
			_box_at(Vector3(1.2, -0.75, 1.2), Vector3(0.25, 1.2, 0.25), C.call(wood_d), parent)
			_box_at(Vector3(1.2, -0.75, -1.2), Vector3(0.25, 1.2, 0.25), C.call(wood_d), parent)
		"wall":
			_box_at(Vector3(0, 1.5, 0), Vector3(3.0, 3.0, 0.2), C.call(wood_c), parent)
			_box_at(Vector3(0, 0.1, 0), Vector3(3.0, 0.2, 0.26), C.call(wood_d), parent)
			_box_at(Vector3(0, 2.9, 0), Vector3(3.0, 0.2, 0.26), C.call(wood_d), parent)
		"wall_window":
			_box_at(Vector3(0, 0.55, 0), Vector3(3.0, 1.1, 0.2), C.call(wood_c), parent)
			_box_at(Vector3(0, 2.6, 0), Vector3(3.0, 0.8, 0.2), C.call(wood_c), parent)
			_box_at(Vector3(-1.3, 1.6, 0), Vector3(0.4, 1.0, 0.2), C.call(wood_c), parent)
			_box_at(Vector3(1.3, 1.6, 0), Vector3(0.4, 1.0, 0.2), C.call(wood_c), parent)
		"wall_door":
			_box_at(Vector3(-1.1, 1.5, 0), Vector3(0.8, 3.0, 0.2), C.call(wood_c), parent)
			_box_at(Vector3(1.1, 1.5, 0), Vector3(0.8, 3.0, 0.2), C.call(wood_c), parent)
			_box_at(Vector3(0, 2.7, 0), Vector3(1.4, 0.6, 0.2), C.call(wood_c), parent)
		"floor":
			_box_at(Vector3(0, 3.0, 0), Vector3(3.0, 0.2, 3.0), C.call(wood_c), parent)
		"stairs":
			for i in range(6):
				var h: float = 0.5 + i * 0.5
				_box_at(Vector3(0, h * 0.5, -1.25 + i * 0.5), Vector3(2.6, h, 0.5), C.call(wood_c if i % 2 == 0 else wood_d), parent)
		"ramp":
			var r := _box_at(Vector3(0, 0.75, 0), Vector3(3.0, 0.2, 4.2), C.call(wood_c), parent)
			r.rotation.x = -0.35
		"door":
			_box_at(Vector3(0, 1.1, 0), Vector3(1.3, 2.2, 0.14), C.call(Color(0.5, 0.36, 0.2) if tier == 0 else Color(0.5, 0.5, 0.53)), parent)
			_sphere_at(Vector3(0.5, 1.1, 0.1), 0.08, 0.16, C.call(Color(0.8, 0.7, 0.3)), parent)
		"window_bars":
			for i in range(4):
				_box_at(Vector3(-0.6 + i * 0.4, 1.6, 0), Vector3(0.08, 1.0, 0.08), C.call(Color(0.45, 0.45, 0.48)), parent)
		"box":
			_box_at(Vector3(0, 0.4, 0), Vector3(1.1, 0.8, 0.8), C.call(Color(0.5, 0.37, 0.2)), parent)
			_box_at(Vector3(0, 0.82, 0), Vector3(1.15, 0.08, 0.85), C.call(Color(0.38, 0.28, 0.15)), parent)
		"locker":
			_box_at(Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.5), C.call(Color(0.44, 0.32, 0.18)), parent)
			_box_at(Vector3(0, 0.9, 0.27), Vector3(0.06, 1.7, 0.04), C.call(Color(0.3, 0.22, 0.12)), parent)
		"campfire":
			for i in range(6):
				var a := TAU * i / 6.0
				_sphere_at(Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5), 0.15, 0.3, C.call(Color(0.4, 0.4, 0.42)), parent)
			_sphere_at(Vector3(0, 0.4, 0), 0.25, 0.7, C.call(Color(1.0, 0.5, 0.1)), parent, Color(1.0, 0.4, 0.05) if not ghost else Color(0, 0, 0, 0))
		"furnace":
			_box_at(Vector3(0, 0.6, 0), Vector3(1.0, 1.2, 1.0), C.call(Color(0.34, 0.34, 0.36)), parent)
			_box_at(Vector3(0, 1.55, 0), Vector3(0.3, 0.7, 0.3), C.call(Color(0.28, 0.28, 0.3)), parent)
		"workbench":
			_box_at(Vector3(0, 0.9, 0), Vector3(1.6, 0.1, 0.9), C.call(Color(0.5, 0.36, 0.2)), parent)
			for sx in [-0.7, 0.7]:
				for sz in [-0.35, 0.35]:
					_box_at(Vector3(sx, 0.45, sz), Vector3(0.12, 0.9, 0.12), C.call(Color(0.4, 0.28, 0.16)), parent)
			_box_at(Vector3(0, 1.15, 0), Vector3(1.3, 0.4, 0.6), C.call(Color(0.32, 0.32, 0.34)), parent)
		"bag":
			_box_at(Vector3(0, 0.1, 0), Vector3(0.9, 0.2, 2.0), C.call(Color(0.25, 0.4, 0.28)), parent)
			_box_at(Vector3(0, 0.3, -0.9), Vector3(0.9, 0.25, 0.4), C.call(Color(0.18, 0.3, 0.22)), parent)
		"sapling_pine", "sapling_birch", "sapling_maple":
			# превью дерева: ствол + крона (реальная модель ставится при посадке)
			_box_at(Vector3(0, 1.4, 0), Vector3(0.3, 2.8, 0.3), C.call(Color(0.35, 0.25, 0.14)), parent)
			_sphere_at(Vector3(0, 3.4, 0), 1.3, 2.6, C.call(Color(0.2, 0.42, 0.18)), parent)
		"sapling_rock":
			_sphere_at(Vector3(0, 0.45, 0), 0.7, 0.9, C.call(Color(0.42, 0.42, 0.45)), parent)
		_:
			_box_at(Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0), mat_col, parent)


## Можно ли поставить постройку в этой точке (проверка коллизий и опоры)
func can_place_at(kind: String, pos: Vector3) -> bool:
	var info: Dictionary = GameState.BUILD_CATALOG.get(kind, {})
	var grid: float = float(info.get("grid", 1.0))
	# 1) в воде строить нельзя
	if pos.y < WATER_LEVEL + 0.2:
		return false
	# 2) слишком крутой склон для наземных построек
	if String(info.get("snap", "free")) == "ground":
		var e := 1.0
		var dy: float = maxf(
			absf(_surface_height(pos.x + e, pos.z) - pos.y),
			absf(_surface_height(pos.x, pos.z + e) - pos.y))
		if dy > 1.6:
			return false
	# 3) пересечение с уже поставленной постройкой
	var min_d: float = grid * 0.75
	for st in GameState.structures:
		var sp: Vector3 = st["pos"]
		if String(st["kind"]) == kind and sp.distance_to(pos) < 0.35:
			return false
		if absf(sp.y - pos.y) < 1.2 and Vector2(sp.x - pos.x, sp.z - pos.z).length() < min_d:
			return false
	# 4) не ставить внутрь деревьев и камней
	for t in _tree_spots:
		if bool(t["alive"]) and (t["pos"] as Vector3).distance_to(pos) < 1.6:
			return false
	return true


## Привязка позиции к сетке и к существующим постройкам
func snap_position(kind: String, want: Vector3) -> Vector3:
	var info: Dictionary = GameState.BUILD_CATALOG.get(kind, {})
	var grid: float = float(info.get("grid", 1.0))
	var mode: String = String(info.get("snap", "free"))
	var px: float = round(want.x / grid) * grid
	var pz: float = round(want.z / grid) * grid
	var py: float = _surface_height(px, pz)

	if mode == "free":
		px = want.x
		pz = want.z
		py = _surface_height(px, pz)
		return Vector3(px, py, pz)

	# ищем ближайший фундамент/пол для привязки по высоте (этажи)
	var best_d := 4.2
	var snapped := false
	for st in GameState.structures:
		var sk: String = String(st["kind"])
		if not sk.begins_with("foundation") and sk != "floor":
			continue
		var sp: Vector3 = st["pos"]
		var d: float = Vector2(sp.x - px, sp.z - pz).length()
		if d < best_d:
			best_d = d
			if mode == "edge":
				# стены встают на край плиты
				var dx: float = px - sp.x
				var dz: float = pz - sp.z
				if absf(dx) > absf(dz):
					px = sp.x + signf(dx) * grid * 0.5
					pz = sp.z
				else:
					pz = sp.z + signf(dz) * grid * 0.5
					px = sp.x
				py = sp.y
			elif mode == "level":
				px = sp.x
				pz = sp.z
				py = sp.y
			else:
				py = sp.y
			snapped = true
	if not snapped:
		py = _surface_height(px, pz)
	return Vector3(px, py, pz)


func _place_building(kind: String, origin: Vector3, look_dir: Vector3, rot: float = 0.0) -> bool:
	var want := Vector3(origin.x + look_dir.x * 3.0, 0.0, origin.z + look_dir.z * 3.0)
	var pos := snap_position(kind, want)
	if not can_place_at(kind, pos):
		return false
	if not GameState.pay_build(kind):
		return false
	# саженцы и камни — отдельная система посадки (точно на поверхность)
	if kind.begins_with("sapling_"):
		_plant_object(kind, pos, rot)
		GameState.save_inventory()
		return true
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	_make_building(kind, node, false, 0)
	# коллизия постройки, чтобы сквозь неё нельзя было пройти
	_add_build_collision(node, kind)
	_set_lod(node, 220.0)
	GameState.structures.append({"kind": kind, "pos": pos, "rot": rot, "tier": 0,
		"hp": GameState.BUILD_HP[0], "owner": GameState.player_name, "node": node})
	GameState.save_inventory()
	return true


## Посадка дерева/камня игроком: объект ставится ТОЧНО на поверхность,
## получает коллизию и попадает в список добываемых (его можно срубить).
func _plant_object(kind: String, pos: Vector3, rot: float) -> void:
	# высота берётся из той же функции, что и для всего мира
	var ground := _surface_height(pos.x, pos.z)
	var node := Node3D.new()
	node.position = Vector3(pos.x, ground, pos.z)
	node.rotation.y = rot
	add_child(node)

	if kind == "sapling_rock":
		var rm := MeshInstance3D.new()
		rm.mesh = _make_rock_mesh()
		rm.material_override = _terrain_material()
		var rs := _rng.randf_range(0.9, 1.5)
		rm.scale = Vector3(rs, rs * 0.8, rs)
		rm.position = Vector3(0, 0.15 * rs, 0)
		rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(rm)
		_set_lod(node, 220.0)
		_rock_spots.append({"pos": node.position, "index": -1, "alive": true, "node": node})
		return

	# дерево: своя модель на вид
	var height := 0.0
	match kind:
		"sapling_birch":
			height = _spawn_model_tree(node, "res://models/tree_birch.glb", 7.5, 10.5)
		"sapling_maple":
			height = _spawn_model_tree(node, "res://models/tree_maple.glb", 8.0, 12.0)
		_:
			var mi := MeshInstance3D.new()
			mi.mesh = _make_tree_mesh(0)
			var ts := _rng.randf_range(1.6, 2.6)
			mi.scale = Vector3(ts, ts, ts)
			mi.position = Vector3(0, -0.1, 0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var am: ArrayMesh = mi.mesh
			am.surface_set_material(0, _bark_material())
			if am.get_surface_count() > 1:
				am.surface_set_material(1, _foliage_material())
			node.add_child(mi)
			height = 3.0 * ts
	_set_lod(node, 220.0)
	_add_trunk_collision(node.position, maxf(3.0, height))
	# посаженное дерево можно срубить, как обычное
	_tree_spots.append({"pos": node.position, "index": -1, "alive": true, "big": false, "node": node})


func _spawn_model_tree(parent: Node3D, path: String, hmin: float, hmax: float) -> float:
	if not ResourceLoader.exists(path):
		return 0.0
	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	var src: MeshInstance3D = null
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		src = mi
		break
	if src == null:
		inst.queue_free()
		return 0.0
	var src_h: float = maxf(src.mesh.get_aabb().size.y, 0.001)
	var want := _rng.randf_range(hmin, hmax)
	var sc: float = want / src_h
	var vis := MeshInstance3D.new()
	vis.mesh = src.mesh
	vis.scale = Vector3(sc, sc, sc)
	vis.position = Vector3(0, -0.15, 0)
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(vis)
	inst.queue_free()
	return want


func _add_build_collision(node: Node3D, kind: String) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	match kind:
		"foundation", "foundation_tri":
			box.size = Vector3(3.0, 0.35, 3.0)
			cs.position = Vector3(0, -0.15, 0)
		"wall", "wall_window", "wall_door":
			box.size = Vector3(3.0, 3.0, 0.25)
			cs.position = Vector3(0, 1.5, 0)
		"floor":
			box.size = Vector3(3.0, 0.25, 3.0)
			cs.position = Vector3(0, 3.0, 0)
		"stairs", "ramp":
			box.size = Vector3(2.8, 1.6, 3.2)
			cs.position = Vector3(0, 0.8, 0)
		"locker":
			box.size = Vector3(0.9, 1.8, 0.5)
			cs.position = Vector3(0, 0.9, 0)
		"box", "furnace", "workbench":
			box.size = Vector3(1.2, 1.0, 1.0)
			cs.position = Vector3(0, 0.5, 0)
		_:
			return
	cs.shape = box
	body.add_child(cs)
	node.add_child(body)


## Разобрать ближайшую постройку (возврат половины ресурсов)
func demolish_near(origin: Vector3) -> String:
	var best := -1
	var best_d := 4.0
	for i in range(GameState.structures.size()):
		var st: Dictionary = GameState.structures[i]
		var d: float = (st["pos"] as Vector3).distance_to(origin)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return ""
	var st2: Dictionary = GameState.structures[best]
	var nm: String = String(GameState.BUILD_CATALOG.get(st2["kind"], {}).get("name", st2["kind"]))
	GameState.refund_build(String(st2["kind"]), int(st2["tier"]))
	var n: Node3D = st2["node"]
	if is_instance_valid(n):
		n.queue_free()
	GameState.structures.remove_at(best)
	GameState.save_inventory()
	return nm


## Улучшить ближайшую постройку (дерево -> камень)
func upgrade_near(origin: Vector3) -> String:
	var best := -1
	var best_d := 4.0
	for i in range(GameState.structures.size()):
		var st: Dictionary = GameState.structures[i]
		if int(st["tier"]) > 0:
			continue
		var d: float = (st["pos"] as Vector3).distance_to(origin)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return ""
	var st2: Dictionary = GameState.structures[best]
	var kind: String = String(st2["kind"])
	if not GameState.can_upgrade(kind):
		return "no_res"
	var u: Dictionary = GameState.upgrade_cost(kind)
	for r in u:
		GameState.remove_item(String(r), int(u[r]))
	var n: Node3D = st2["node"]
	if is_instance_valid(n):
		n.queue_free()
	var node := Node3D.new()
	node.position = st2["pos"]
	node.rotation.y = float(st2["rot"])
	add_child(node)
	_make_building(kind, node, false, 1)
	_add_build_collision(node, kind)
	_set_lod(node, 220.0)
	st2["node"] = node
	st2["tier"] = 1
	st2["hp"] = GameState.BUILD_HP[1]
	GameState.save_inventory()
	return String(GameState.BUILD_CATALOG.get(kind, {}).get("name", kind))


# строительный призрак (полупрозрачный предпросмотр)
var _ghost: Node3D = null
var _ghost_kind := ""
var _ghost_ok := false


## Может ли игрок поставить постройку прямо сейчас (для кнопки в HUD)
func ghost_placeable() -> bool:
	return _ghost_ok


func _tint_ghost(node: Node3D, col: Color) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		(mi as MeshInstance3D).material_override = m


func _process(delta: float) -> void:
	_update_day_night(delta)
	_update_weather(delta)
	GameState.tick_craft(delta)
	# урон от заражённых зон
	if _events and _player and is_instance_valid(_player):
		var hz: float = _events.tick_hazards(_player.global_position, delta)
		if hz > 0.0 and _player.has_method("take_damage"):
			_player.take_damage(hz, null)
	if not GameState.build_mode:
		if _ghost:
			_ghost.queue_free()
			_ghost = null
			_ghost_kind = ""
		return
	# пересоздаём призрак при смене типа постройки
	if _ghost == null or _ghost_kind != GameState.build_kind:
		if _ghost:
			_ghost.queue_free()
		_ghost = Node3D.new()
		add_child(_ghost)
		_make_building(GameState.build_kind, _ghost, true)
		_ghost_kind = GameState.build_kind
	if _player:
		var cam: Camera3D = _player.get_node_or_null("Camera3D")
		var fwd := -(_player as Node3D).global_transform.basis.z
		if cam:
			fwd = -cam.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var want := Vector3(
			_player.global_position.x + fwd.x * 3.0, 0.0,
			_player.global_position.z + fwd.z * 3.0)
		var pos := snap_position(GameState.build_kind, want)
		_ghost.position = pos
		_ghost.rotation.y = GameState.build_rot
		# зелёный — можно ставить, красный — нельзя (нет места или ресурсов)
		var ok: bool = can_place_at(GameState.build_kind, pos) and GameState.can_afford_build(GameState.build_kind)
		if ok != _ghost_ok or _ghost.get_meta("tinted", false) == false:
			_ghost_ok = ok
			_tint_ghost(_ghost, Color(0.35, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.3, 0.25, 0.45))
			_ghost.set_meta("tinted", true)
