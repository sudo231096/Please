extends Node3D
## Пустошь в духе Rust: выживание от первого лица, оптимизированный ландшафт.

const PlayerScr := preload("res://scripts/player.gd")
const AnimalScr := preload("res://scripts/animal.gd")
const HudScr := preload("res://scripts/hud.gd")

const TERRAIN_N := 128        # ячеек на сторону
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


func _ready() -> void:
	add_to_group("terrain")
	_rng.seed = randi()
	_build_sky()
	_build_ground()
	_build_trees()
	_build_rocks()
	_build_ores()
	_build_grass()
	_spawn_player()
	_build_hud()
	_spawn_animals()


# ---------- высота рельефа ----------

func _ground_height(x: float, z: float) -> float:
	var h := 0.0
	h += 1.8 * sin(x * 0.006 + 1.3) * cos(z * 0.007 + 0.7)
	h += 1.1 * sin(x * 0.013 + 0.5) * sin(z * 0.011 + 2.1)
	for p in MOUNTAINS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var d2: float = dx * dx + dz * dz
		h += p[2] * exp(-d2 / (2.0 * p[3] * p[3]))
	return h


func _mat(color: Color, emissive := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	var brown := Color(0.42, 0.3, 0.16)
	var green := Color(0.16, 0.38, 0.14)
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
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var green := Color(0.28, 0.5, 0.2)
	# тонкая травинка (две пересечённые плоскости)
	var h := 1.0
	_add_tri(verts, cols, idx, Vector3(0, 0, 0), Vector3(0, h, 0), Vector3(0.05, 0, 0), green)
	_add_tri(verts, cols, idx, Vector3(0, 0, 0), Vector3(0, h, 0), Vector3(0, 0, 0.05), green)
	var am := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
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
	var gray := Color(0.42, 0.42, 0.45)
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
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


func _vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ---------- окружение ----------

func _build_sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skymat := ProceduralSkyMaterial.new()
	skymat.sky_top_color = Color(0.3, 0.55, 0.9)
	skymat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	skymat.ground_bottom_color = Color(0.3, 0.25, 0.2)
	skymat.ground_horizon_color = Color(0.6, 0.6, 0.55)
	sky.sky_material = skymat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.7, 0.8)
	env.fog_density = 0.003
	env.fog_sky_affect = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 6.0
	sm.height = 12.0
	disc.mesh = sm
	disc.material_override = _mat(Color(1.0, 0.95, 0.7), Color(1.0, 0.9, 0.5))
	disc.position = Vector3(0, 80, -60)
	add_child(disc)


func _build_ground() -> void:
	var n := TERRAIN_N + 1
	_heights.resize(n * n)
	for z in range(n):
		for x in range(n):
			var wx := -HALF + x * TERRAIN_CELL
			var wz := -HALF + z * TERRAIN_CELL
			_heights[z * n + x] = _ground_height(wx, wz)

	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var grass := Color(0.22, 0.42, 0.16)
	var dark := Color(0.18, 0.34, 0.13)
	var rock := Color(0.4, 0.4, 0.42)
	var snow := Color(0.9, 0.92, 0.95)
	for z in range(n):
		for x in range(n):
			var wx := -HALF + x * TERRAIN_CELL
			var wz := -HALF + z * TERRAIN_CELL
			var h := _heights[z * n + x]
			verts.append(Vector3(wx, h, wz))
			var c := grass
			if h > 9.0:
				c = snow
			elif h > 5.0:
				c = rock
			elif h > 2.0:
				c = grass
			else:
				c = dark
			cols.append(c.lightened(_rng.randf_range(-0.04, 0.04)))
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
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _vertex_color_material()
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


func _random_spot(min_r: float) -> Vector3:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(min_r, HALF - 20.0)
	var x := cos(ang) * r
	var z := sin(ang) * r
	return Vector3(x, _ground_height(x, z), z)


# ---------- деревья / камни / руды / трава (MultiMesh — оптимизация) ----------

func _build_trees() -> void:
	var mesh := _make_tree_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 150
	for i in range(150):
		var pos := _random_spot(12.0)
		var s := _rng.randf_range(0.7, 1.6)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(0, -0.1, 0))
		t = t.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _vertex_color_material()
	add_child(inst)


func _build_rocks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_rock_mesh()
	mm.instance_count = 80
	for i in range(80):
		var pos := _random_spot(8.0)
		var s := _rng.randf_range(0.6, 2.2)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos + Vector3(0, 0.15 * s, 0))
		t = t.scaled(Vector3(s, s * _rng.randf_range(0.6, 1.0), s))
		mm.set_instance_transform(i, t)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _vertex_color_material()
	add_child(inst)


func _build_grass() -> void:
	var mesh := _make_grass_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 500
	for i in range(500):
		var pos := _random_spot(8.0)
		var s := _rng.randf_range(0.5, 1.4)
		var t := Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), pos)
		t = t.scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, t)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = _vertex_color_material()
	add_child(inst)


func _build_ores() -> void:
	# руды — отдельные объекты (их мало)
	for i in range(20):
		var pos := _random_spot(10.0)
		var kind := _rng.randi_range(0, 2)
		match kind:
			0:
				_ore_crystal(pos, Color(1.0, 0.85, 0.2), Color(1.0, 0.8, 0.15))
			1:
				var r := _rng.randf_range(0.5, 1.0)
				var ore := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = r
				sm.height = r * 1.4
				ore.mesh = sm
				ore.material_override = _mat(Color(0.25, 0.22, 0.2))
				ore.position = Vector3(pos.x, pos.y + r * 0.5, pos.z)
				ore.scale = Vector3(1, _rng.randf_range(0.6, 0.9), 1)
				add_child(ore)
				var vein := MeshInstance3D.new()
				var sm2 := SphereMesh.new()
				sm2.radius = r * 0.4
				sm2.height = r * 0.8
				vein.mesh = sm2
				vein.material_override = _mat(Color(0.6, 0.3, 0.1))
				vein.position = Vector3(pos.x + r * 0.3, pos.y + r * 0.6, pos.z)
				add_child(vein)
			2:
				var r2 := _rng.randf_range(0.6, 1.2)
				var stone := MeshInstance3D.new()
				var sm3 := SphereMesh.new()
				sm3.radius = r2
				sm3.height = r2 * 1.5
				stone.mesh = sm3
				stone.material_override = _mat(Color(0.55, 0.55, 0.6))
				stone.position = Vector3(pos.x, pos.y + r2 * 0.4, pos.z)
				stone.scale = Vector3(1, _rng.randf_range(0.5, 0.85), 1)
				add_child(stone)


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


# ---------- игрок / животные / HUD ----------

func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScr)
	var pos := _random_spot(20.0)
	_player.position = Vector3(pos.x, pos.y + 1.0, pos.z)
	add_child(_player)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScr)
	add_child(_hud)
	_hud.bind(_player)


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
