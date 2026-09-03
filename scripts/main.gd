extends Node3D
## Пустошь в духе Rust: выживание от первого лица.

const PlayerScr := preload("res://scripts/player.gd")
const AnimalScr := preload("res://scripts/animal.gd")
const HudScr := preload("res://scripts/hud.gd")

const AREA := 600.0  # большая карта (в 10 раз больше)

var _player: CharacterBody3D
var _hud: CanvasLayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
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


func _mat(color: Color, emissive := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive.a > 0.0:
		m.emission_enabled = true
		m.emission = emissive
	return m


func _build_sky() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var skymat := ProceduralSkyMaterial.new()
	skymat.sky_top_color = Color(0.3, 0.55, 0.9)
	skymat.sky_horizon_color = Color(0.7, 0.8, 0.9)
	skymat.ground_bottom_color = Color(0.3, 0.25, 0.2)
	skymat.ground_horizon_color = Color(0.6, 0.6, 0.55)
	skymat.sun_angle_max = 0.5
	sky.sky_material = skymat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	# лёгкий туман для атмосферы
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.7, 0.8)
	env.fog_density = 0.004
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
	# скачанная карта-террейн (Badlands) как земля.
	# Модель уже повёрнута внутри (ось Z вверх) — НЕ крутим её снова.
	# XZ — большая карта (1000 м), высота — мягкий рельеф (~2.4 м).
	# Нижняя точка террейна на высоте 0.045 (в локальных ед.) — опускаем, чтобы земля была на уровне игрока.
	var terrain: Node3D = preload("res://models/terrain.glb").instantiate()
	terrain.scale = Vector3(500, 10, 500)
	terrain.position = Vector3(0, -0.045 * 10.0, 0)
	add_child(terrain)

	# коллизия пола (плоская, по габаритам)
	var g := StaticBody3D.new()
	g.collision_layer = 1
	g.collision_mask = 0
	add_child(g)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(AREA * 2, 0.5, AREA * 2)
	col.shape = cs
	col.position = Vector3(0, -0.25, 0)
	g.add_child(col)


func _build_trees() -> void:
	for i in range(160):
		var pos := _random_spot(10.0)
		_tree(pos)


func _tree(pos: Vector3) -> void:
	# скачанная low-poly модель ёлки (по умолчанию крошечная ~0.11м -> масштабируем до 4-6м)
	var tree: Node3D = preload("res://models/tree.glb").instantiate()
	tree.position = pos
	var s := _rng.randf_range(38.0, 55.0)
	tree.scale = Vector3.ONE * s
	add_child(tree)
	_fit_flat(tree)


func _build_rocks() -> void:
	for i in range(40):
		var pos := _random_spot(8.0)
		var r := _rng.randf_range(0.4, 1.5)
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.6
		rock.mesh = sm
		rock.material_override = _mat(Color(0.42, 0.42, 0.45))
		rock.position = Vector3(pos.x, r * 0.5, pos.z)
		rock.scale = Vector3(1, _rng.randf_range(0.5, 0.9), 1)
		add_child(rock)


func _build_ores() -> void:
	# сера (жёлтые кристаллы), железо (тёмные куски), камень (светлые валуны)
	for i in range(30):
		var pos := _random_spot(10.0)
		var kind := _rng.randi_range(0, 2)
		match kind:
			0:  # сера — жёлтый кристалл
				var c := _ore_crystal(pos, Color(1.0, 0.85, 0.2), Color(1.0, 0.8, 0.15))
			1:  # железо — тёмный кусок с ржавчиной
				var r := _rng.randf_range(0.4, 0.9)
				var ore := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = r
				sm.height = r * 1.4
				ore.mesh = sm
				ore.material_override = _mat(Color(0.25, 0.22, 0.2))
				ore.position = Vector3(pos.x, r * 0.6, pos.z)
				ore.scale = Vector3(1, _rng.randf_range(0.6, 0.9), 1)
				add_child(ore)
				# ржавые прожилки
				var vein := MeshInstance3D.new()
				var sm2 := SphereMesh.new()
				sm2.radius = r * 0.4
				sm2.height = r * 0.8
				vein.mesh = sm2
				vein.material_override = _mat(Color(0.6, 0.3, 0.1))
				vein.position = Vector3(pos.x + r * 0.3, r * 0.7, pos.z)
				add_child(vein)
			2:  # камень — светлый валун
				var r2 := _rng.randf_range(0.5, 1.1)
				var stone := MeshInstance3D.new()
				var sm3 := SphereMesh.new()
				sm3.radius = r2
				sm3.height = r2 * 1.5
				stone.mesh = sm3
				stone.material_override = _mat(Color(0.55, 0.55, 0.6))
				stone.position = Vector3(pos.x, r2 * 0.5, pos.z)
				stone.scale = Vector3(1, _rng.randf_range(0.5, 0.85), 1)
				add_child(stone)


func _ore_crystal(pos: Vector3, color: Color, emissive: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	for i in range(3):
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.14
		cm.height = _rng.randf_range(0.4, 0.8)
		c.mesh = cm
		c.material_override = _mat(color, emissive)
		c.position = Vector3(_rng.randf_range(-0.25, 0.25), cm.height * 0.4, _rng.randf_range(-0.25, 0.25))
		c.rotation_degrees = Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-20, 20))
		n.add_child(c)
	return n


func _build_grass() -> void:
	for i in range(260):
		var pos := _random_spot(8.0)
		var blade := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.04
		cm.height = _rng.randf_range(0.4, 1.0)
		blade.mesh = cm
		blade.material_override = _mat(Color(0.5, 0.45, 0.2))
		blade.position = Vector3(pos.x, cm.height * 0.5, pos.z)
		add_child(blade)


func _fit_flat(m: Node3D) -> void:
	# поставить модель на землю (низ на y=0) по её габаритам
	await get_tree().process_frame
	await get_tree().process_frame
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for mesh in m.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mesh.mesh.get_aabb()
		var t: Transform3D = mesh.global_transform
		for i in range(8):
			var p: Vector3 = aabb.position + Vector3(
				aabb.size.x if (i & 1) != 0 else 0.0,
				aabb.size.y if (i & 2) != 0 else 0.0,
				aabb.size.z if (i & 4) != 0 else 0.0)
			p = t * p
			mn = mn.min(p)
			mx = mx.max(p)
	m.position.y += -mn.y


func _random_spot(min_r: float) -> Vector3:
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(min_r, AREA - 2.0)
	return Vector3(cos(ang) * r, 0, sin(ang) * r)


func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScr)
	# разный спавн: случайная точка на краю
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(20.0, AREA - 5.0)
	_player.position = Vector3(cos(ang) * r, 1.0, sin(ang) * r)
	add_child(_player)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScr)
	add_child(_hud)
	_hud.bind(_player)


func _spawn_animals() -> void:
	# курицы (много, пассивные)
	for i in range(6):
		_spawn_animal(0)
	# олени (быстрые, пассивные)
	for i in range(4):
		_spawn_animal(1)
	# кабаны (нейтральные)
	for i in range(3):
		_spawn_animal(2)
	# медведи (агрессивные)
	for i in range(2):
		_spawn_animal(3)


func _spawn_animal(kind: int) -> void:
	var a := CharacterBody3D.new()
	a.set_script(AnimalScr)
	var pos := _random_spot(12.0)
	a.position = Vector3(pos.x, 1.0, pos.z)
	add_child(a)
	a.setup(kind)
	a.died.connect(_on_animal_died)


func _on_animal_died(kind: int) -> void:
	# добыча: мясо за убийство (кроме курицы — тоже даёт, но меньше)
	var amount := 1
	if kind == 3:  # медведь
		amount = 4
	elif kind == 1:  # олень
		amount = 3
	elif kind == 2:  # кабан
		amount = 2
	GameState.add_meat(amount)
	GameState.kills += 1
	if _hud:
		_hud.refresh()
	# респавн того же вида
	_spawn_animal(kind)
