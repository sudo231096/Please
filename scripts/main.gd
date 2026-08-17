extends Node3D
## Городская улица: камерамен бежит вперёд, уровни растут, город генерируется кусками.

const PlayerScr := preload("res://scripts/player.gd")
const SkibidiScr := preload("res://scripts/skibidi.gd")
const HudScr := preload("res://scripts/hud.gd")

const CHUNK_LEN := 16.0
const HORIZON := 150.0
const LEVEL_LEN := 100.0

const ROAD_HALF := 5.0
const WALL_X := 6.5

var _player: CharacterBody3D
var _cam: Camera3D
var _hud: CanvasLayer
var _chunks: Array = []   # [{node, z}]
var _next_z := 0.0
var _level := 1
var _spawn_t := 1.0
var _road_rng := RandomNumberGenerator.new()


func _ready() -> void:
	GameState.reset_run()
	_road_rng.seed = randi()
	_build_light()
	_build_ground()
	_build_walls()
	_spawn_player()
	_build_hud()
	# первые куски города
	while _next_z > -HORIZON:
		_spawn_chunk()


func _process(delta: float) -> void:
	if not _player:
		return

	# камера: сверху-сзади, смотрит вперёд
	_cam.global_position = _player.global_position + Vector3(0, 11.5, 7.0)
	_cam.look_at(_player.global_position + Vector3(0, 1.0, -5.0), Vector3.UP)

	# уровень по пройденной дистанции
	var dist := -_player.global_position.z
	var lvl := 1 + int(dist / LEVEL_LEN)
	if lvl != _level:
		_level = lvl
		GameState.level = _level
		_hud.set_level(_level)
		_hud.flash_level(_level)

	# догоняем генерацию города вперёд
	while _next_z > _player.global_position.z - HORIZON:
		_spawn_chunk()

	# убираем куски позади
	_cleanup_chunks()

	# спавн врагов
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_enemies()
		_spawn_t = clampf(1.4 - float(_level) * 0.06, 0.35, 1.4)


# ---------- окружение ----------

func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D, emissive: Color = Color(0, 0, 0, 0)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emissive
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _build_light() -> void:
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-55, 30, 0)
	dl.light_energy = 1.2
	add_child(dl)


func _build_ground() -> void:
	var g := StaticBody3D.new()
	g.collision_layer = 1
	g.collision_mask = 0
	add_child(g)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(60, 0.5, 4000)
	col.shape = cs
	col.position = Vector3(0, -0.25, -2000)
	g.add_child(col)

	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 4000)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.26)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(0, -0.01, -2000)
	add_child(m)


func _build_walls() -> void:
	_wall(Vector3(0.5, 4.0, 4000), Vector3(-WALL_X, 2.0, -2000))
	_wall(Vector3(0.5, 4.0, 4000), Vector3(WALL_X, 2.0, -2000))


func _wall(size: Vector3, pos: Vector3) -> void:
	var w := StaticBody3D.new()
	w.collision_layer = 1
	w.collision_mask = 0
	w.position = pos
	add_child(w)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = size
	col.shape = cs
	w.add_child(col)


func _spawn_chunk() -> void:
	var z := _next_z
	_next_z -= CHUNK_LEN

	var chunk := Node3D.new()
	chunk.position = Vector3(0, 0, z)
	add_child(chunk)
	_chunks.append({"node": chunk, "z": z})

	# дорога (тёмный асфальт)
	_box(Vector3(ROAD_HALF * 2, 0.04, CHUNK_LEN), Vector3(0, 0.02, -CHUNK_LEN * 0.5), Color(0.14, 0.14, 0.16), chunk)

	# тротуары
	_box(Vector3(1.4, 0.06, CHUNK_LEN), Vector3(-(ROAD_HALF + 0.7), 0.03, -CHUNK_LEN * 0.5), Color(0.42, 0.42, 0.46), chunk)
	_box(Vector3(1.4, 0.06, CHUNK_LEN), Vector3(ROAD_HALF + 0.7, 0.03, -CHUNK_LEN * 0.5), Color(0.42, 0.42, 0.46), chunk)

	# здания по бокам
	_building(chunk, -1, z)  # левое
	_building(chunk, 1, z)   # правое

	# пешеходный переход каждые 4 куска
	if int(abs(z) / CHUNK_LEN) % 4 == 0:
		for s in range(5):
			_box(Vector3(0.7, 0.03, 0.6), Vector3(-2.8 + s * 1.4, 0.045, -CHUNK_LEN * 0.5), Color(0.9, 0.9, 0.92), chunk)

	# фонарь каждые 3 куска
	if int(abs(z) / CHUNK_LEN) % 3 == 0:
		_streetlight(chunk, -1, -CHUNK_LEN * 0.3)
		_streetlight(chunk, 1, -CHUNK_LEN * 0.7)

	# припаркованная машина (редко)
	if _road_rng.randf() < 0.12:
		_car(chunk, -CHUNK_LEN * 0.5)


func _building(parent: Node3D, side: int, z: float) -> void:
	var h := _road_rng.randf_range(6.0, 15.0)
	var xc := side * 9.5
	var base := Color(_road_rng.randf_range(0.25, 0.5), _road_rng.randf_range(0.22, 0.4), _road_rng.randf_range(0.2, 0.35))
	_box(Vector3(6.5, h, CHUNK_LEN - 1.0), Vector3(xc, h * 0.5, -CHUNK_LEN * 0.5), base, parent)

	# окна (обращены к улице)
	var win_color := Color(1.0, 0.9, 0.5) if _road_rng.randf() < 0.3 else Color(0.75, 0.85, 1.0)
	var rows := int(h / 2.6)
	for r in range(rows):
		var wy := 1.8 + r * 2.6
		if wy > h - 1.2:
			break
		for c in range(2):
			var wz := -CHUNK_LEN * 0.25 + c * CHUNK_LEN * 0.5
			_box(Vector3(0.1, 1.3, 1.1), Vector3(side * (xc - side * 3.2), wy, wz), Color(0.1, 0.12, 0.16), parent, win_color)


func _streetlight(parent: Node3D, side: int, z: float) -> void:
	var x := side * (ROAD_HALF + 1.2)
	_box(Vector3(0.14, 4.2, 0.14), Vector3(x, 2.1, z), Color(0.25, 0.25, 0.3), parent)
	_box(Vector3(0.1, 0.1, 1.4), Vector3(side * (ROAD_HALF + 0.4), 4.15, z), Color(0.25, 0.25, 0.3), parent)
	_box(Vector3(0.4, 0.06, 0.5), Vector3(side * (ROAD_HALF + 0.4), 4.06, z + side * 0.5), Color(1.0, 0.95, 0.7), parent, Color(1.0, 0.9, 0.5))


func _car(parent: Node3D, z: float) -> void:
	var side := -1 if _road_rng.randf() < 0.5 else 1
	var x := side * (ROAD_HALF - 1.6)
	var c := Color(_road_rng.randf_range(0.1, 0.9), _road_rng.randf_range(0.1, 0.9), _road_rng.randf_range(0.1, 0.9))
	_box(Vector3(2.0, 1.0, 3.6), Vector3(x, 0.5, z), c, parent)
	_box(Vector3(1.8, 0.7, 1.6), Vector3(x, 1.05, z - 0.4), Color(0.15, 0.18, 0.22), parent)


func _cleanup_chunks() -> void:
	var i := 0
	while i < _chunks.size():
		var c: Dictionary = _chunks[i]
		if c["z"] > _player.global_position.z + 60.0:
			c["node"].queue_free()
			_chunks.remove_at(i)
		else:
			i += 1


# ---------- игрок / враги / HUD ----------

func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScr)
	_player.position = Vector3(0, 0, 6)
	add_child(_player)
	_player.died.connect(_on_player_died)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 60
	add_child(_cam)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.set_script(HudScr)
	add_child(_hud)
	_hud.bind(_player)
	_hud.set_level(1)


func _spawn_enemies() -> void:
	var count := 1 + int(_level / 4)
	if count > 4:
		count = 4
	for i in range(count):
		var e := CharacterBody3D.new()
		e.set_script(SkibidiScr)
		var z := _player.global_position.z - _road_rng.randf_range(22.0, 40.0)
		var x := _road_rng.randf_range(-ROAD_HALF + 0.8, ROAD_HALF - 0.8)
		e.position = Vector3(x, 0, z)
		add_child(e)
		e.setup(_level)
		e.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	GameState.add_score(10 * GameState.level)
	_hud.update_score()


func _on_player_died() -> void:
	_hud.show_game_over(GameState.score)
	set_process(false)
