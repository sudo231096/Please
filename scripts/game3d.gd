extends Node3D
## 3D-сцена с биомами: земля-текстура биомов, ресурсы, животные (с узорными текстурами), игрок-FPS, HUD.

const Player3DScn := preload("res://scenes/Player3D.tscn")
const ResNode := preload("res://scripts/resource_node.gd")
const JoystickScn := preload("res://scripts/joystick.gd")
const AnimalScn := preload("res://scripts/animal3d.gd")
const InventoryUIScr := preload("res://scripts/inventory_ui.gd")

enum Biome { WATER, SAND, PLAINS, FOREST, SNOW, ROCK }

const BCOLOR := {
	Biome.WATER: Color(0.14, 0.28, 0.38),
	Biome.SAND: Color(0.72, 0.62, 0.42),   # Oxide hot desert
	Biome.PLAINS: Color(0.32, 0.42, 0.22), # dry grass temperate
	Biome.FOREST: Color(0.16, 0.28, 0.14),
	Biome.SNOW: Color(0.78, 0.82, 0.86),   # Oxide cold
	Biome.ROCK: Color(0.38, 0.36, 0.34),
}

const WORLD_SIZE := 6400.0
const MESH_SIZE := 900.0  # видимый/играбельный рельеф вокруг спавна (оптимизация)
const MESH_RES := 48


var _rng := RandomNumberGenerator.new()
var _labels := {}
var _hp_label: Label
var _player
var _inv_ui
var _eq_label: Label
var _build_btn: Button
var _build_info: Label
var _cross: Control

var _elev := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _temp := FastNoiseLite.new()

var _mat_wood: StandardMaterial3D
var _mat_foliage: StandardMaterial3D
var _mat_stone: StandardMaterial3D
var _mat_sulfur: StandardMaterial3D
var _mat_chicken: StandardMaterial3D
var _mat_deer: StandardMaterial3D
var _mat_boar: StandardMaterial3D
var _mat_bear: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 99
	_init_biome_noise()
	_build_materials()
	_build_env()
	_build_ground()
	_build_resources()
	_spawn_animals()
	_build_player()
	_build_hud()


func _process(_delta: float) -> void:
	for r in _labels:
		_labels[r].text = "%s: %d" % [_rname(r), Inv.count(r)]
	if _hp_label and _player:
		_hp_label.text = "HP: %d/%d  DEF: %d" % [_player.hp, _player.hp_max, Inv.total_defense()]
	if _eq_label:
		var eq := Controls.equipped
		if eq != "" and Inv.count(eq) > 0:
			_eq_label.text = "В руках: %s (%d/%d)" % [_tname(eq), Inv.durability_of(eq), Inv.max_dur(eq)]
		else:
			_eq_label.text = "В руках: кулак"
	if _build_btn:
		_build_btn.text = "СТРОЙ:ВКЛ" if Controls.build_mode else "СТРОЙ"
	if _build_info:
		if Controls.build_mode:
			var pid := Controls.build_piece
			_build_info.text = "Стройка: %s ×%d | повёрнут %d°" % [_bname(pid), Inv.count(pid), (Controls.build_rotate % 4) * 90]
			_build_info.visible = true
		else:
			_build_info.visible = false
	if _cross:
		_cross.visible = not Controls.ui_open


# --- Биомы ---

func _init_biome_noise() -> void:
	# частоты ниже — огромные биомы на карте 6400
	_elev.seed = 101
	_elev.frequency = 0.00045
	_elev.fractal_octaves = 5
	_elev.fractal_gain = 0.5
	_moist.seed = 202
	_moist.frequency = 0.00035
	_moist.fractal_octaves = 3
	_temp.seed = 303
	_temp.frequency = 0.00018
	_temp.fractal_octaves = 2


func biome_at(x: float, z: float) -> int:
	# Oxide-style: крупные зоны cold / temperate / hot + вода/скалы
	var e := _elev.get_noise_2d(x, z)
	var t := _temp.get_noise_2d(x * 0.6, z * 0.6)
	var m := _moist.get_noise_2d(x, z)
	if e < -0.36:
		return Biome.WATER
	if e > 0.55:
		return Biome.ROCK
	# холодный сектор
	if t < -0.22:
		if e < -0.22:
			return Biome.WATER
		return Biome.SNOW
	# жаркий сектор
	if t > 0.22:
		if m > 0.15 and e > -0.1:
			return Biome.PLAINS  # оазис/саванна
		return Biome.SAND
	# умеренный
	if e < -0.28:
		return Biome.SAND  # берег
	if m > 0.12:
		return Biome.FOREST
	return Biome.PLAINS


func height_at(x: float, z: float) -> float:
	var e := _elev.get_noise_2d(x, z)
	var b: int = biome_at(x, z)
	var h := e * 4.2
	if b == Biome.WATER:
		h = minf(h, -0.35)
	elif b == Biome.SNOW:
		h += 1.2
	elif b == Biome.ROCK:
		h += 2.2 + maxf(e, 0.0) * 1.5
	elif b == Biome.SAND:
		h *= 0.5
	return h


func _biome_texture(size := 320) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dn := FastNoiseLite.new()
	dn.seed = 777
	dn.frequency = 0.6
	for pz in range(size):
		for px in range(size):
			var wx := (float(px) / float(size)) * 6400.0 - 3200.0
			var wz := (float(pz) / float(size)) * 6400.0 - 3200.0
			var b: int = biome_at(wx, wz)
			var c: Color = BCOLOR[b]
			var nv: float = dn.get_noise_2d(wx * 2.0, wz * 2.0) * 0.035
			c.r = clampf(c.r + nv, 0.0, 1.0)
			c.g = clampf(c.g + nv, 0.0, 1.0)
			c.b = clampf(c.b + nv, 0.0, 1.0)
			img.set_pixel(px, pz, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- Материалы ---

func _build_materials() -> void:
	_mat_wood = _bark_mat(Color(0.32, 0.22, 0.14), 2)
	_mat_foliage = _leaf_mat(Color(0.18, 0.32, 0.14), 3)
	_mat_stone = _rock_mat(Color(0.42, 0.40, 0.38), Color(0.28, 0.27, 0.26), 4)
	_mat_sulfur = _rock_mat(Color(0.7, 0.62, 0.22), Color(0.45, 0.4, 0.12), 5)
	_mat_chicken = _mat(_animal_tex(Color(0.9, 0.88, 0.82), Color(0.7, 0.55, 0.35), "speckle", 11), Vector3(1.4, 1.4, 1.4))
	_mat_deer = _mat(_animal_tex(Color(0.5, 0.36, 0.24), Color(0.82, 0.75, 0.62), "spots", 12), Vector3(1.2, 1.2, 1.2))
	_mat_boar = _mat(_animal_tex(Color(0.26, 0.2, 0.16), Color(0.4, 0.32, 0.26), "streaks", 13), Vector3(1.25, 1.25, 1.25))
	_mat_bear = _mat(_animal_tex(Color(0.2, 0.14, 0.1), Color(0.32, 0.24, 0.18), "patches", 14), Vector3(1.15, 1.15, 1.15))


func _noise_tex(base: Color, amp: float, seed: int, size := 64) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.09
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	for y in range(size):
		for x in range(size):
			var v: float = n.get_noise_2d(float(x), float(y))
			var c := Color(
				clampf(base.r + v * amp, 0.0, 1.0),
				clampf(base.g + v * amp, 0.0, 1.0),
				clampf(base.b + v * amp, 0.0, 1.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# Текстура животного с узором: speckle (крап), spots (пятна), streaks (полосы-щетина), patches (подпалины).
func _animal_tex(base: Color, accent: Color, mode: String, seed: int, size := 48) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var p := FastNoiseLite.new()
	p.seed = seed + 50
	p.frequency = 0.5
	p.fractal_octaves = 3
	var fur := FastNoiseLite.new()
	fur.seed = seed + 200
	fur.frequency = 2.5
	fur.fractal_octaves = 2
	for y in range(size):
		for x in range(size):
			var fv: float = fur.get_noise_2d(float(x), float(y)) * 0.05
			var c := Color(clampf(base.r + fv, 0.0, 1.0), clampf(base.g + fv, 0.0, 1.0), clampf(base.b + fv, 0.0, 1.0))
			if mode == "speckle":
				if p.get_noise_2d(float(x) * 5.0, float(y) * 5.0) > 0.5:
					c = base.lerp(accent, 0.6)
			elif mode == "spots":
				if p.get_noise_2d(float(x) * 2.5, float(y) * 2.5) > 0.55:
					c = accent
			elif mode == "streaks":
				if p.get_noise_2d(float(x) * 4.0, float(y) * 0.3) > 0.15:
					c = base.lerp(accent, 0.55)
			elif mode == "patches":
				if p.get_noise_2d(float(x) * 1.2, float(y) * 1.2) > 0.2:
					c = base.lerp(accent, 0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _mat(tex: ImageTexture, scale: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.uv1_scale = scale
	m.roughness = 0.88
	return m


func _bark_mat(base: Color, seed: int) -> StandardMaterial3D:
	# Вертикальные трещины коры + шум
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.08
	n.fractal_octaves = 4
	var cracks := FastNoiseLite.new()
	cracks.seed = seed + 40
	cracks.frequency = 0.25
	cracks.fractal_octaves = 2
	for y in range(size):
		for x in range(size):
			var v: float = n.get_noise_2d(float(x) * 0.6, float(y) * 2.2)
			var cack: float = cracks.get_noise_2d(float(x) * 3.0, float(y) * 0.4)
			var dark := 0.0
			if cack > 0.35:
				dark = 0.18
			var c := Color(
				clampf(base.r + v * 0.12 - dark, 0.0, 1.0),
				clampf(base.g + v * 0.10 - dark, 0.0, 1.0),
				clampf(base.b + v * 0.08 - dark, 0.0, 1.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := _mat(ImageTexture.create_from_image(img), Vector3(1.5, 3.5, 1.5))
	m.roughness = 0.95
	return m


func _leaf_mat(base: Color, seed: int) -> StandardMaterial3D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.15
	n.fractal_octaves = 3
	var blot := FastNoiseLite.new()
	blot.seed = seed + 70
	blot.frequency = 0.35
	for y in range(size):
		for x in range(size):
			var v: float = n.get_noise_2d(float(x), float(y))
			var b: float = blot.get_noise_2d(float(x), float(y))
			var gboost := 0.08 if b > 0.2 else 0.0
			var c := Color(
				clampf(base.r + v * 0.08 - gboost * 0.3, 0.0, 1.0),
				clampf(base.g + v * 0.12 + gboost, 0.0, 1.0),
				clampf(base.b + v * 0.06, 0.0, 1.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := _mat(ImageTexture.create_from_image(img), Vector3(2.5, 2.5, 2.5))
	m.roughness = 0.75
	return m


func _rock_mat(base: Color, vein: Color, seed: int) -> StandardMaterial3D:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.11
	n.fractal_octaves = 5
	var veins := FastNoiseLite.new()
	veins.seed = seed + 90
	veins.frequency = 0.22
	veins.fractal_octaves = 3
	for y in range(size):
		for x in range(size):
			var v: float = n.get_noise_2d(float(x), float(y))
			var vn: float = veins.get_noise_2d(float(x) * 1.7, float(y) * 0.9)
			var c := Color(
				clampf(base.r + v * 0.14, 0.0, 1.0),
				clampf(base.g + v * 0.14, 0.0, 1.0),
				clampf(base.b + v * 0.14, 0.0, 1.0))
			if absf(vn) < 0.08:
				c = c.lerp(vein, 0.65)
			elif vn > 0.45:
				c = c.darkened(0.18)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var m := _mat(ImageTexture.create_from_image(img), Vector3(1.2, 1.2, 1.2))
	m.roughness = 0.92
	return m


# --- Окружение ---

func _build_env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.55, 0.85)
	sm.sky_horizon_color = Color(0.72, 0.78, 0.85)
	sm.ground_bottom_color = Color(0.25, 0.22, 0.18)
	sm.ground_horizon_color = Color(0.55, 0.5, 0.4)
	sm.sun_angle_max = 35.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.85)
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.75, -0.55, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	# Оптимизация: детальный меш только около центра, дальше — плоская подложка
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var mesh_i := MeshInstance3D.new()
	var am: ArrayMesh = _build_height_mesh(MESH_RES, MESH_SIZE)
	mesh_i.mesh = am
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _biome_texture(192)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	gm.roughness = 0.95
	mesh_i.material_override = gm
	# отсечение далеко
	mesh_i.visibility_range_end = 420.0
	mesh_i.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	body.add_child(mesh_i)
	# коллизия: heightmap shape (быстрее trimesh) или box+сэмпл — heightmap из Image
	var col := CollisionShape3D.new()
	col.shape = _make_heightmap_shape(MESH_RES, MESH_SIZE)
	var cell := MESH_SIZE / float(MESH_RES)
	col.scale = Vector3(cell, 1.0, cell)
	body.add_child(col)
	add_child(body)
	# дальняя плоская «бесконечность» (дешёвая)
	var far_body := StaticBody3D.new()
	far_body.name = "FarFlat"
	var far_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	var fgm := StandardMaterial3D.new()
	fgm.albedo_texture = _biome_texture(128)
	fgm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	far_mi.mesh = plane
	far_mi.material_override = fgm
	far_mi.position = Vector3(0, -0.05, 0)
	far_body.add_child(far_mi)
	var fcol := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(WORLD_SIZE, 2.0, WORLD_SIZE)
	fcol.shape = fbox
	fcol.position = Vector3(0, -1.05, 0)
	far_body.add_child(fcol)
	add_child(far_body)
	_spawn_water_plane()
	_spawn_biome_props()


func _make_heightmap_shape(res: int, size: float) -> HeightMapShape3D:
	var hs := HeightMapShape3D.new()
	hs.map_width = res + 1
	hs.map_depth = res + 1
	var half := size * 0.5
	var step := size / float(res)
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize((res + 1) * (res + 1))
	var i := 0
	for iz in range(res + 1):
		for ix in range(res + 1):
			var x := -half + float(ix) * step
			var z := -half + float(iz) * step
			data[i] = height_at(x, z)
			i += 1
	hs.map_data = data
	# scale shape to world size (Godot heightmap cell = 1 unit by default)
	# Width/depth in units equals (map_width-1); scale node instead via CollisionShape transform
	return hs


func _build_height_mesh(res: int, size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size * 0.5
	var step := size / float(res)
	for iz in range(res):
		for ix in range(res):
			var x0 := -half + float(ix) * step
			var z0 := -half + float(iz) * step
			var x1 := x0 + step
			var z1 := z0 + step
			var h00 := height_at(x0, z0)
			var h10 := height_at(x1, z0)
			var h01 := height_at(x0, z1)
			var h11 := height_at(x1, z1)
			var u0 := float(ix) / float(res)
			var v0 := float(iz) / float(res)
			var u1 := float(ix + 1) / float(res)
			var v1 := float(iz + 1) / float(res)
			var p00 := Vector3(x0, h00, z0)
			var p10 := Vector3(x1, h10, z0)
			var p01 := Vector3(x0, h01, z1)
			var p11 := Vector3(x1, h11, z1)
			# tri 1
			st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
			# tri 2
			st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
	st.generate_normals()
	return st.commit()


func _spawn_water_plane() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MESH_SIZE * 1.2, MESH_SIZE * 1.2)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.12, 0.35, 0.55, 0.65)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.2
	mi.mesh = plane
	mi.material_override = wm
	mi.position = Vector3(0, -0.2, 0)
	mi.visibility_range_end = 500.0
	add_child(mi)


func _spawn_biome_props() -> void:
	# кактусы в пустыне, ели в снегу — Oxide vibe
	var cactus_mat := StandardMaterial3D.new()
	cactus_mat.albedo_color = Color(0.22, 0.48, 0.22)
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.18, 0.28, 0.18)
	var snow_top := StandardMaterial3D.new()
	snow_top.albedo_color = Color(0.92, 0.94, 0.97)
	for _i in range(120):
		var p := _pos_in_biomes([Biome.SAND])
		var h := height_at(p.x, p.z)
		var n := Node3D.new()
		n.position = Vector3(p.x, h, p.z)
		var stem := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.12
		c.bottom_radius = 0.16
		c.height = 1.4
		stem.mesh = c
		stem.material_override = cactus_mat
		stem.position = Vector3(0, 0.7, 0)
		n.add_child(stem)
		var arm := MeshInstance3D.new()
		var c2 := CylinderMesh.new()
		c2.top_radius = 0.08
		c2.bottom_radius = 0.1
		c2.height = 0.6
		arm.mesh = c2
		arm.material_override = cactus_mat
		arm.position = Vector3(0.25, 0.9, 0)
		arm.rotation.z = -1.1
		n.add_child(arm)
		add_child(n)
	for _j in range(24):
		var p2 := _pos_in_biomes([Biome.SNOW])
		var h2 := height_at(p2.x, p2.z)
		var t := Node3D.new()
		t.position = Vector3(p2.x, h2, p2.z)
		var trunk := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.12
		tc.bottom_radius = 0.18
		tc.height = 1.2
		trunk.mesh = tc
		trunk.material_override = _mat_wood
		trunk.position = Vector3(0, 0.6, 0)
		t.add_child(trunk)
		for k in range(3):
			var cone := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.9 - k * 0.18
			sm.height = 1.3 - k * 0.2
			cone.mesh = sm
			cone.material_override = snow_mat if k > 0 else snow_top
			cone.position = Vector3(0, 1.3 + k * 0.55, 0)
			cone.scale = Vector3(1.0, 0.7, 1.0)
			t.add_child(cone)
		add_child(t)


func _rand_pos() -> Vector3:
	# спавн объектов в активной зоне (меш), не по всей 6400 — иначе пусто рядом и лаги
	var half := MESH_SIZE * 0.45
	var x := _rng.randf_range(-half, half)
	var z := _rng.randf_range(-half, half)
	return Vector3(x, height_at(x, z), z)


func _pos_in_biomes(allowed: Array) -> Vector3:
	for _i in range(25):
		var p := _rand_pos()
		if biome_at(p.x, p.z) in allowed:
			return p
	return _rand_pos()


func _build_resources() -> void:
	for _i in range(70):
		_spawn_tree(_pos_in_biomes([Biome.FOREST, Biome.PLAINS]))
	for _i in range(36):
		_spawn_rock(_pos_in_biomes([Biome.PLAINS, Biome.ROCK, Biome.SAND]), "stone")
	for _i in range(20):
		_spawn_rock(_pos_in_biomes([Biome.ROCK, Biome.SAND, Biome.PLAINS]), "sulfur")


func _spawn_animals() -> void:
	var counts := {AnimalScn.Kind.CHICKEN: 10, AnimalScn.Kind.DEER: 7, AnimalScn.Kind.BOAR: 5, AnimalScn.Kind.BEAR: 3}
	var mats := {AnimalScn.Kind.CHICKEN: _mat_chicken, AnimalScn.Kind.DEER: _mat_deer, AnimalScn.Kind.BOAR: _mat_boar, AnimalScn.Kind.BEAR: _mat_bear}
	for k in counts:
		for _i in range(counts[k]):
			var a = AnimalScn.new()
			a.kind = k
			a.body_mat = mats[k]
			var p := _pos_in_biomes([Biome.PLAINS, Biome.FOREST])
			a.position = Vector3(p.x, height_at(p.x, p.z) + 1.2, p.z)
			add_child(a)


func _spawn_tree(pos: Vector3) -> void:
	var n := StaticBody3D.new()
	n.set_script(ResNode)
	n.res_type = "wood"
	n.hp = 3
	n.position = pos
	n.rotation.y = _rng.randf() * TAU
	var s := _rng.randf_range(0.9, 1.35)
	var path := AssetLib.tree_path(_rng.randi())
	var holder := Node3D.new()
	n.add_child(holder)
	var mdl := AssetLib.spawn_model(path, holder, Vector3(s, s, s))
	if mdl == null:
		# fallback simple
		var trunk := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.15 * s
		cm.bottom_radius = 0.25 * s
		cm.height = 2.2 * s
		trunk.mesh = cm
		trunk.material_override = _mat_wood
		trunk.position = Vector3(0, 1.1 * s, 0)
		n.add_child(trunk)
	var col := CollisionShape3D.new()
	var cb := CylinderShape3D.new()
	cb.radius = 0.5 * s
	cb.height = 3.0 * s
	col.shape = cb
	col.position = Vector3(0, 1.4 * s, 0)
	n.add_child(col)
	add_child(n)


func _spawn_rock(pos: Vector3, rtype: String) -> void:
	var n := StaticBody3D.new()
	n.set_script(ResNode)
	n.res_type = rtype
	n.hp = 3 if rtype == "stone" else 2
	n.position = pos
	n.rotation.y = _rng.randf() * TAU
	var s := _rng.randf_range(0.85, 1.4)
	var path := AssetLib.rock_path(_rng.randi())
	var holder := Node3D.new()
	n.add_child(holder)
	var mdl := AssetLib.spawn_model(path, holder, Vector3(s, s, s))
	if mdl and rtype == "sulfur":
		# yellow tint overlay crystal
		var crystal_mat := StandardMaterial3D.new()
		crystal_mat.albedo_color = Color(0.9, 0.8, 0.2)
		crystal_mat.emission_enabled = true
		crystal_mat.emission = Color(0.5, 0.4, 0.05)
		crystal_mat.emission_energy_multiplier = 0.4
		var cr := MeshInstance3D.new()
		var prm := PrismMesh.new()
		prm.size = Vector3(0.2 * s, 0.35 * s, 0.15 * s)
		cr.mesh = prm
		cr.material_override = crystal_mat
		cr.position = Vector3(0.1 * s, 0.45 * s, 0)
		n.add_child(cr)
	if mdl == null:
		var main := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55 * s
		sm.height = 0.9 * s
		main.mesh = sm
		main.material_override = _mat_stone if rtype == "stone" else _mat_sulfur
		main.position = Vector3(0, 0.35 * s, 0)
		n.add_child(main)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4 * s, 1.0 * s, 1.4 * s)
	col.shape = bs
	col.position = Vector3(0, 0.4 * s, 0)
	n.add_child(col)
	add_child(n)


func _build_player() -> void:

	var p := Player3DScn.instantiate()
	var sp := _pos_in_biomes([Biome.PLAINS, Biome.FOREST])
	var hy := height_at(sp.x, sp.z) + 2.0
	p.position = Vector3(sp.x, hy, sp.z)
	p.spawn_pos = p.position
	add_child(p)
	_player = p
	if p.has_node("Camera3D"):
		p.get_node("Camera3D").far = 450.0
		p.get_node("Camera3D").near = 0.08


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.add_theme_constant_override("separation", 4)
	root.add_child(vbox)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_hp_label)
	for r in ["wood", "stone", "sulfur", "meat"]:
		var l := Label.new()
		l.text = _rname(r) + ": 0"
		l.add_theme_font_size_override("font_size", 22)
		vbox.add_child(l)
		_labels[r] = l

	root.add_child(JoystickScn.new())

	var g_btn := Button.new()
	g_btn.text = "ДОБЫТЬ/УДАР"
	_stack(g_btn, 0)
	g_btn.button_down.connect(func() -> void: Controls.attack_queued = true)
	root.add_child(g_btn)

	var j_btn := Button.new()
	j_btn.text = "ПРЫЖОК"
	_stack(j_btn, 1)
	j_btn.button_down.connect(func() -> void: Controls.jump_queued = true)
	root.add_child(j_btn)

	# Кнопка выхода в главное меню (правый верхний угол)
	var exit_btn := Button.new()
	exit_btn.text = "ВЫХОД"
	exit_btn.anchor_left = 1.0
	exit_btn.anchor_right = 1.0
	exit_btn.anchor_top = 0.0
	exit_btn.anchor_bottom = 0.0
	exit_btn.offset_left = -150
	exit_btn.offset_right = -16
	exit_btn.offset_top = 16
	exit_btn.offset_bottom = 72
	exit_btn.add_theme_font_size_override("font_size", 22)
	exit_btn.pressed.connect(_exit_to_menu)
	root.add_child(exit_btn)

	# UI создаём сразу, до кнопок
	_inv_ui = InventoryUIScr.new()
	add_child(_inv_ui)

	# Инвентарь / Крафт / Броня — верхний ряд (не перекрывать)
	var inv_btn := Button.new()
	inv_btn.text = "ИНВ"
	inv_btn.focus_mode = Control.FOCUS_NONE
	inv_btn.anchor_left = 1.0
	inv_btn.anchor_right = 1.0
	inv_btn.anchor_top = 0.0
	inv_btn.anchor_bottom = 0.0
	inv_btn.offset_left = -310
	inv_btn.offset_right = -162
	inv_btn.offset_top = 16
	inv_btn.offset_bottom = 72
	inv_btn.add_theme_font_size_override("font_size", 22)
	inv_btn.pressed.connect(_on_inv_pressed)
	root.add_child(inv_btn)

	var craft_btn := Button.new()
	craft_btn.text = "КРАФТ"
	craft_btn.focus_mode = Control.FOCUS_NONE
	craft_btn.anchor_left = 1.0
	craft_btn.anchor_right = 1.0
	craft_btn.anchor_top = 0.0
	craft_btn.anchor_bottom = 0.0
	craft_btn.offset_left = -470
	craft_btn.offset_right = -322
	craft_btn.offset_top = 16
	craft_btn.offset_bottom = 72
	craft_btn.add_theme_font_size_override("font_size", 22)
	craft_btn.pressed.connect(_on_craft_pressed)
	root.add_child(craft_btn)

	var armor_btn := Button.new()
	armor_btn.text = "БРОНЯ"
	armor_btn.focus_mode = Control.FOCUS_NONE
	armor_btn.anchor_left = 1.0
	armor_btn.anchor_right = 1.0
	armor_btn.anchor_top = 0.0
	armor_btn.anchor_bottom = 0.0
	armor_btn.offset_left = -310
	armor_btn.offset_right = -162
	armor_btn.offset_top = 80
	armor_btn.offset_bottom = 136
	armor_btn.add_theme_font_size_override("font_size", 20)
	armor_btn.pressed.connect(_on_armor_pressed)
	root.add_child(armor_btn)

	_eq_label = Label.new()
	_eq_label.anchor_left = 0.0
	_eq_label.anchor_top = 1.0
	_eq_label.anchor_right = 0.0
	_eq_label.anchor_bottom = 1.0
	_eq_label.offset_left = 16
	_eq_label.offset_top = -48
	_eq_label.offset_right = 420
	_eq_label.offset_bottom = -12
	_eq_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_eq_label)

	# Прицел по центру (4 полоски + точка)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_cross)
	_make_crosshair(_cross)

	# Строительство
	_build_btn = Button.new()
	_build_btn.text = "СТРОЙ"
	_build_btn.anchor_left = 1.0
	_build_btn.anchor_right = 1.0
	_build_btn.anchor_top = 0.0
	_build_btn.anchor_bottom = 0.0
	_build_btn.offset_left = -630
	_build_btn.offset_right = -482
	_build_btn.offset_top = 16
	_build_btn.offset_bottom = 72
	_build_btn.add_theme_font_size_override("font_size", 20)
	_build_btn.pressed.connect(_toggle_build)
	root.add_child(_build_btn)

	var rot_btn := Button.new()
	rot_btn.text = "ПОВОР"
	rot_btn.anchor_left = 1.0
	rot_btn.anchor_right = 1.0
	rot_btn.anchor_top = 0.0
	rot_btn.anchor_bottom = 0.0
	rot_btn.offset_left = -790
	rot_btn.offset_right = -642
	rot_btn.offset_top = 16
	rot_btn.offset_bottom = 72
	rot_btn.add_theme_font_size_override("font_size", 20)
	rot_btn.pressed.connect(func() -> void:
		Controls.build_rotate = (Controls.build_rotate + 1) % 4
	)
	root.add_child(rot_btn)

	# кнопка поставить — в build mode основная ДОБЫТЬ ставит; доп. подсказка
	_build_info = Label.new()
	_build_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_info.anchor_left = 0.5
	_build_info.anchor_right = 0.5
	_build_info.anchor_top = 0.0
	_build_info.anchor_bottom = 0.0
	_build_info.offset_left = -280
	_build_info.offset_right = 280
	_build_info.offset_top = 90
	_build_info.offset_bottom = 130
	_build_info.add_theme_font_size_override("font_size", 20)
	_build_info.visible = false
	root.add_child(_build_info)

	# Переименовать основную кнопку динамически? оставим, в build mode она ставит
	g_btn.text = "ДЕЙСТВИЕ"


func _exit_to_menu() -> void:
	if _inv_ui and _inv_ui.visible:
		_inv_ui.close()
	Controls.move_vector = Vector2.ZERO
	Controls.jump_queued = false
	Controls.attack_queued = false
	Controls.ui_open = false
	Controls.build_mode = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _stack(btn: Button, idx: int) -> void:
	var bw := 170
	var bh := 80
	var gap := 12
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_right = -16
	btn.offset_left = -16 - bw
	var bottom := -16 - idx * (bh + gap)
	btn.offset_bottom = bottom
	btn.offset_top = bottom - bh
	btn.add_theme_font_size_override("font_size", 22)


func _rname(r: String) -> String:
	match r:
		"wood":
			return "Дерево"
		"stone":
			return "Камень"
		"sulfur":
			return "Сера"
		"meat":
			return "Мясо"
		_:
			return r


func _tname(id: String) -> String:
	match id:
		"axe":
			return "Топор"
		"pickaxe":
			return "Кирка"
		"sword":
			return "Меч"
		"bow":
			return "Лук"
		"crossbow":
			return "Арбалет"
		"rod":
			return "Удочка"
		"stone_axe":
			return "Кам. топор"
		"stone_pickaxe":
			return "Кам. кирка"
		"stone_sword":
			return "Кам. меч"
		"stone_bow":
			return "Кам. лук"
		"stone_crossbow":
			return "Кам. арбалет"
		"stone_rod":
			return "Кам. удочка"
		_:
			return id


func _make_crosshair(parent: Control) -> void:
	var col := Color(1, 1, 1, 0.9)
	var gap := 7
	var arm := 16
	var th := 3
	# left
	parent.add_child(_cross_bar(col, -gap - arm, -th / 2, arm, th))
	# right
	parent.add_child(_cross_bar(col, gap, -th / 2, arm, th))
	# up
	parent.add_child(_cross_bar(col, -th / 2, -gap - arm, th, arm))
	# down
	parent.add_child(_cross_bar(col, -th / 2, gap, th, arm))
	# dot
	parent.add_child(_cross_bar(col, -2, -2, 4, 4))


func _cross_bar(col: Color, ox: int, oy: int, w: int, h: int) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.5
	r.anchor_right = 0.5
	r.anchor_top = 0.5
	r.anchor_bottom = 0.5
	r.offset_left = float(ox)
	r.offset_top = float(oy)
	r.offset_right = float(ox + w)
	r.offset_bottom = float(oy + h)
	return r


func _toggle_build() -> void:
	Controls.build_mode = not Controls.build_mode
	if Controls.build_mode and Controls.build_piece == "":
		Controls.build_piece = "wood_block"
	# if no pieces, still allow mode (ghost red)
	if _build_btn:
		_build_btn.text = "СТРОЙ:ВКЛ" if Controls.build_mode else "СТРОЙ"


func _bname(id: String) -> String:
	match id:
		"wood_block":
			return "Дер. блок"
		"wood_wall":
			return "Дер. стена"
		"wood_floor":
			return "Дер. пол"
		"wood_pillar":
			return "Дер. столб"
		"stone_block":
			return "Кам. блок"
		"stone_wall":
			return "Кам. стена"
		"campfire":
			return "Костёр"
		_:
			return id


func _on_inv_pressed() -> void:
	if _inv_ui:
		_inv_ui.toggle_inv()


func _on_craft_pressed() -> void:
	if _inv_ui:
		_inv_ui.toggle_craft()


func _on_armor_pressed() -> void:
	if _inv_ui:
		_inv_ui.toggle_armor()
