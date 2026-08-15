extends Node3D
## 3D-сцена с биомами: земля-текстура биомов, ресурсы, животные (с узорными текстурами), игрок-FPS, HUD.

const Player3DScn := preload("res://scenes/Player3D.tscn")
const ResNode := preload("res://scripts/resource_node.gd")
const JoystickScn := preload("res://scripts/joystick.gd")
const AnimalScn := preload("res://scripts/animal3d.gd")

enum Biome { WATER, SAND, PLAINS, FOREST, SNOW, ROCK }

const BCOLOR := {
	Biome.WATER: Color(0.18, 0.38, 0.62),
	Biome.SAND: Color(0.84, 0.76, 0.50),
	Biome.PLAINS: Color(0.34, 0.56, 0.26),
	Biome.FOREST: Color(0.15, 0.36, 0.15),
	Biome.SNOW: Color(0.90, 0.92, 0.95),
	Biome.ROCK: Color(0.50, 0.48, 0.45),
}

var _rng := RandomNumberGenerator.new()
var _labels := {}
var _hp_label: Label
var _player

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
		_hp_label.text = "HP: %d/%d" % [_player.hp, _player.hp_max]


# --- Биомы ---

func _init_biome_noise() -> void:
	_elev.seed = 101
	_elev.frequency = 0.010
	_elev.fractal_octaves = 3
	_moist.seed = 202
	_moist.frequency = 0.008
	_moist.fractal_octaves = 3
	_temp.seed = 303
	_temp.frequency = 0.007
	_temp.fractal_octaves = 3


func biome_at(x: float, z: float) -> int:
	var e := _elev.get_noise_2d(x, z)
	if e < -0.38:
		return Biome.WATER
	if e < -0.33:
		return Biome.SAND
	if e > 0.58:
		return Biome.ROCK
	var m := _moist.get_noise_2d(x, z)
	var t := _temp.get_noise_2d(x, z)
	if t < -0.35:
		return Biome.SNOW
	if m < -0.28:
		return Biome.SAND
	if m > 0.25:
		return Biome.FOREST
	return Biome.PLAINS


func _biome_texture(size := 320) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dn := FastNoiseLite.new()
	dn.seed = 777
	dn.frequency = 0.6
	for pz in range(size):
		for px in range(size):
			var wx := (float(px) / float(size)) * 200.0 - 100.0
			var wz := (float(pz) / float(size)) * 200.0 - 100.0
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
	_mat_wood = _bark_mat(Color(0.38, 0.24, 0.13), 2)
	_mat_foliage = _leaf_mat(Color(0.16, 0.42, 0.14), 3)
	_mat_stone = _rock_mat(Color(0.48, 0.47, 0.46), Color(0.32, 0.32, 0.33), 4)
	_mat_sulfur = _rock_mat(Color(0.82, 0.74, 0.22), Color(0.55, 0.48, 0.12), 5)
	_mat_chicken = _mat(_animal_tex(Color(0.96, 0.96, 0.92), Color(0.80, 0.60, 0.40), "speckle", 11), Vector3(1.5, 1.5, 1.5))
	_mat_deer = _mat(_animal_tex(Color(0.55, 0.40, 0.27), Color(0.95, 0.93, 0.85), "spots", 12), Vector3(1.2, 1.2, 1.2))
	_mat_boar = _mat(_animal_tex(Color(0.32, 0.26, 0.21), Color(0.55, 0.46, 0.38), "streaks", 13), Vector3(1.3, 1.3, 1.3))
	_mat_bear = _mat(_animal_tex(Color(0.30, 0.22, 0.16), Color(0.50, 0.38, 0.30), "patches", 14), Vector3(1.2, 1.2, 1.2))


func _noise_tex(base: Color, amp: float, seed: int, size := 128) -> ImageTexture:
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
func _animal_tex(base: Color, accent: Color, mode: String, seed: int, size := 96) -> ImageTexture:
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
	var size := 128
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
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, -0.4, 0)
	sun.light_energy = 1.1
	add_child(sun)


func _build_ground() -> void:
	var g := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _biome_texture()
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	plane.material = gm
	mesh.mesh = plane
	g.add_child(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	g.add_child(col)
	add_child(g)


func _rand_pos() -> Vector3:
	return Vector3(_rng.randf_range(-90, 90), 0, _rng.randf_range(-90, 90))


func _pos_in_biomes(allowed: Array) -> Vector3:
	for _i in range(60):
		var p := _rand_pos()
		if biome_at(p.x, p.z) in allowed:
			return p
	return _rand_pos()


func _build_resources() -> void:
	for _i in range(55):
		_spawn_tree(_pos_in_biomes([Biome.FOREST, Biome.PLAINS]))
	for _i in range(26):
		_spawn_rock(_pos_in_biomes([Biome.PLAINS, Biome.ROCK, Biome.SAND]), "stone")
	for _i in range(16):
		_spawn_rock(_pos_in_biomes([Biome.ROCK, Biome.SAND, Biome.PLAINS]), "sulfur")


func _spawn_animals() -> void:
	var counts := {AnimalScn.Kind.CHICKEN: 7, AnimalScn.Kind.DEER: 5, AnimalScn.Kind.BOAR: 4, AnimalScn.Kind.BEAR: 2}
	var mats := {AnimalScn.Kind.CHICKEN: _mat_chicken, AnimalScn.Kind.DEER: _mat_deer, AnimalScn.Kind.BOAR: _mat_boar, AnimalScn.Kind.BEAR: _mat_bear}
	for k in counts:
		for _i in range(counts[k]):
			var a = AnimalScn.new()
			a.kind = k
			a.body_mat = mats[k]
			var p := _pos_in_biomes([Biome.PLAINS, Biome.FOREST])
			a.position = Vector3(p.x, 1.5, p.z)
			add_child(a)


func _spawn_tree(pos: Vector3) -> void:
	var n := StaticBody3D.new()
	n.set_script(ResNode)
	n.res_type = "wood"
	n.hp = 3
	n.position = pos
	# лёгкая вариация размера/поворота
	var s := _rng.randf_range(0.85, 1.25)
	var yaw := _rng.randf() * TAU
	n.rotation.y = yaw

	# ствол с лёгким наклоном и утолщением у корня
	var trunk_h := 2.4 * s
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18 * s
	cm.bottom_radius = 0.38 * s
	cm.height = trunk_h
	cm.radial_segments = 10
	cm.material = _mat_wood
	trunk.mesh = cm
	trunk.position = Vector3(0, trunk_h * 0.5, 0)
	trunk.rotation.z = _rng.randf_range(-0.06, 0.06)
	trunk.rotation.x = _rng.randf_range(-0.05, 0.05)
	n.add_child(trunk)

	# корневые наплывы
	for i in range(3):
		var a := float(i) * TAU / 3.0 + _rng.randf() * 0.4
		var root := MeshInstance3D.new()
		var rm := SphereMesh.new()
		rm.radius = 0.22 * s
		rm.height = 0.35 * s
		rm.radial_segments = 8
		rm.rings = 4
		rm.material = _mat_wood
		root.mesh = rm
		root.position = Vector3(cos(a) * 0.28 * s, 0.08 * s, sin(a) * 0.28 * s)
		root.scale = Vector3(1.4, 0.55, 1.1)
		n.add_child(root)

	# 1–2 ветки
	var branch_count := 1 + _rng.randi() % 2
	for i in range(branch_count):
		var ba := _rng.randf() * TAU
		var bh := trunk_h * _rng.randf_range(0.45, 0.75)
		var br := MeshInstance3D.new()
		var bcm := CylinderMesh.new()
		var blen := _rng.randf_range(0.6, 1.1) * s
		bcm.top_radius = 0.04 * s
		bcm.bottom_radius = 0.09 * s
		bcm.height = blen
		bcm.radial_segments = 6
		bcm.material = _mat_wood
		br.mesh = bcm
		br.rotation = Vector3(0.0, -ba, _rng.randf_range(0.7, 1.15))
		# основание ветки на стволе, длина уходит наружу
		br.position = Vector3(cos(ba) * 0.2 * s, bh, sin(ba) * 0.2 * s) + Vector3(cos(ba), 0.35, sin(ba)) * (blen * 0.35)
		n.add_child(br)

	# крона из нескольких пересекающихся сфер (не «леденец»)
	var crown_y := trunk_h + 0.35 * s
	var clusters := [
		Vector3(0, 0, 0),
		Vector3(0.55 * s, -0.15 * s, 0.25 * s),
		Vector3(-0.5 * s, -0.1 * s, -0.3 * s),
		Vector3(0.15 * s, 0.35 * s, -0.45 * s),
		Vector3(-0.25 * s, 0.2 * s, 0.5 * s),
		Vector3(0.05 * s, 0.55 * s, 0.05 * s),
	]
	for i in range(clusters.size()):
		var cpos: Vector3 = clusters[i]
		var fol := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rr := (0.85 if i == 0 else _rng.randf_range(0.55, 0.85)) * s
		sm.radius = rr
		sm.height = rr * 1.7
		sm.radial_segments = 12
		sm.rings = 8
		sm.material = _mat_foliage
		fol.mesh = sm
		fol.position = Vector3(cpos.x, crown_y + cpos.y, cpos.z)
		fol.scale = Vector3(_rng.randf_range(0.9, 1.15), _rng.randf_range(0.75, 1.0), _rng.randf_range(0.9, 1.15))
		n.add_child(fol)

	var col := CollisionShape3D.new()
	var cb := CylinderShape3D.new()
	cb.radius = 0.55 * s
	cb.height = trunk_h + 1.2 * s
	col.shape = cb
	col.position = Vector3(0, (trunk_h + 1.2 * s) * 0.45, 0)
	n.add_child(col)
	add_child(n)


func _spawn_rock(pos: Vector3, rtype: String) -> void:
	var n := StaticBody3D.new()
	n.set_script(ResNode)
	n.res_type = rtype
	n.hp = 3 if rtype == "stone" else 2
	n.position = pos
	n.rotation.y = _rng.randf() * TAU
	var mat: Material = _mat_stone if rtype == "stone" else _mat_sulfur
	var s := _rng.randf_range(0.85, 1.25)

	# основная глыба — сплюснутая/скошенная сфера
	var main := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55 * s
	sm.height = 0.85 * s
	sm.radial_segments = 12
	sm.rings = 8
	sm.material = mat
	main.mesh = sm
	main.position = Vector3(0, 0.32 * s, 0)
	main.scale = Vector3(_rng.randf_range(1.1, 1.5), _rng.randf_range(0.65, 0.95), _rng.randf_range(1.0, 1.4))
	main.rotation = Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.2, 0.2))
	n.add_child(main)

	# дополнительные обломки
	var bits := 2 + _rng.randi() % 3
	for i in range(bits):
		var a := _rng.randf() * TAU
		var dist := _rng.randf_range(0.25, 0.55) * s
		var bit := MeshInstance3D.new()
		var bsm := SphereMesh.new()
		var br := _rng.randf_range(0.18, 0.35) * s
		bsm.radius = br
		bsm.height = br * _rng.randf_range(1.2, 1.8)
		bsm.radial_segments = 10
		bsm.rings = 6
		bsm.material = mat
		bit.mesh = bsm
		bit.position = Vector3(cos(a) * dist, br * 0.45, sin(a) * dist)
		bit.scale = Vector3(_rng.randf_range(0.8, 1.3), _rng.randf_range(0.5, 0.9), _rng.randf_range(0.8, 1.3))
		bit.rotation = Vector3(_rng.randf() * 0.8, _rng.randf() * TAU, _rng.randf() * 0.8)
		n.add_child(bit)

	# у серы — яркие «вкрапления» кристаллов
	if rtype == "sulfur":
		var crystal_mat := StandardMaterial3D.new()
		crystal_mat.albedo_color = Color(0.95, 0.88, 0.25)
		crystal_mat.roughness = 0.35
		crystal_mat.metallic = 0.05
		for i in range(3):
			var a := _rng.randf() * TAU
			var cr := MeshInstance3D.new()
			var prm := PrismMesh.new()
			prm.size = Vector3(_rng.randf_range(0.12, 0.22) * s, _rng.randf_range(0.25, 0.45) * s, _rng.randf_range(0.12, 0.2) * s)
			prm.material = crystal_mat
			cr.mesh = prm
			cr.position = Vector3(cos(a) * 0.2 * s, 0.35 * s, sin(a) * 0.2 * s)
			cr.rotation = Vector3(_rng.randf_range(-0.3, 0.3), a, _rng.randf_range(-0.2, 0.2))
			n.add_child(cr)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.35 * s, 0.95 * s, 1.35 * s)
	col.shape = bs
	col.position = Vector3(0, 0.4 * s, 0)
	n.add_child(col)
	add_child(n)


func _build_player() -> void:
	var p := Player3DScn.instantiate()
	var sp := _pos_in_biomes([Biome.PLAINS, Biome.FOREST])
	p.position = Vector3(sp.x, 2, sp.z)
	p.spawn_pos = p.position
	add_child(p)
	_player = p


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _exit_to_menu() -> void:
	Controls.move_vector = Vector2.ZERO
	Controls.jump_queued = false
	Controls.attack_queued = false
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
