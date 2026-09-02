extends Node3D
## Пустошь в духе Rust: от первого лица, деревья/камни/трава, дикие звери.

const PlayerScr := preload("res://scripts/player.gd")
const EnemyScr := preload("res://scripts/enemy.gd")
const HudScr := preload("res://scripts/hud.gd")

const AREA := 60.0
const ENEMY_COUNT := 6

var _player: CharacterBody3D
var _hud: CanvasLayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = randi()
	_build_sky()
	_build_ground()
	_build_trees()
	_build_rocks()
	_build_grass()
	_spawn_player()
	_build_hud()
	_spawn_enemies()


# ---------- окружение ----------

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
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.6, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# солнце (свет)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	# видимый диск солнца
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 6.0
	sm.height = 12.0
	disc.mesh = sm
	disc.material_override = _mat(Color(1.0, 0.95, 0.7), Color(1.0, 0.9, 0.5))
	disc.position = Vector3(0, 80, -60)
	add_child(disc)


func _build_ground() -> void:
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

	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(AREA * 2, AREA * 2)
	m.mesh = pm
	m.material_override = _mat(Color(0.36, 0.3, 0.2))  # сухая земля
	m.position = Vector3(0, -0.01, 0)
	add_child(m)


func _build_trees() -> void:
	for i in range(24):
		var x := _rng.randf_range(-AREA + 3, AREA - 3)
		var z := _rng.randf_range(-AREA + 3, AREA - 3)
		if Vector2(x, z).length() < 8.0:
			continue  # не на спавне игрока
		_tree(Vector3(x, 0, z))


func _tree(pos: Vector3) -> void:
	var h := _rng.randf_range(3.5, 6.0)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.2
	cm.height = h
	trunk.mesh = cm
	trunk.material_override = _mat(Color(0.35, 0.24, 0.12))
	trunk.position = pos + Vector3(0, h * 0.5, 0)
	add_child(trunk)

	var crown := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 2.6
	crown.mesh = sm
	crown.material_override = _mat(Color(0.2, 0.38, 0.16))
	crown.position = pos + Vector3(0, h + 0.4, 0)
	add_child(crown)


func _build_rocks() -> void:
	for i in range(18):
		var x := _rng.randf_range(-AREA + 2, AREA - 2)
		var z := _rng.randf_range(-AREA + 2, AREA - 2)
		if Vector2(x, z).length() < 8.0:
			continue
		var r := _rng.randf_range(0.4, 1.2)
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.6
		rock.mesh = sm
		rock.material_override = _mat(Color(0.42, 0.42, 0.45))
		rock.position = Vector3(x, r * 0.5, z)
		rock.scale = Vector3(1, _rng.randf_range(0.5, 0.9), 1)
		add_child(rock)


func _build_grass() -> void:
	for i in range(120):
		var x := _rng.randf_range(-AREA + 1, AREA - 1)
		var z := _rng.randf_range(-AREA + 1, AREA - 1)
		if Vector2(x, z).length() < 8.0:
			continue
		var blade := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.04
		cm.height = _rng.randf_range(0.4, 0.9)
		blade.mesh = cm
		blade.material_override = _mat(Color(0.5, 0.45, 0.2))
		blade.position = Vector3(x, cm.height * 0.5, z)
		add_child(blade)


# ---------- игрок / враги / HUD ----------

func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScr)
	_player.position = Vector3(0, 1.0, 0)
	add_child(_player)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScr)
	add_child(_hud)
	_hud.bind(_player)


func _spawn_enemies() -> void:
	for i in range(ENEMY_COUNT):
		_spawn_one()


func _spawn_one() -> void:
	var e := CharacterBody3D.new()
	e.set_script(EnemyScr)
	var ang := _rng.randf() * TAU
	var r := _rng.randf_range(15.0, AREA - 3.0)
	e.position = Vector3(cos(ang) * r, 1.0, sin(ang) * r)
	add_child(e)
	e.setup(1)
	e.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	if _hud:
		_hud.add_kill()
	# респавн нового зверя
	_spawn_one()
