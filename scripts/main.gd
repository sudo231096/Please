extends Node3D
## Уровень: камерамен бежит вперёд по городу до финиша, отбиваясь от туалетов.

const PlayerScr := preload("res://scripts/player.gd")
const SkibidiScr := preload("res://scripts/skibidi.gd")
const HudScr := preload("res://scripts/hud.gd")

const CHUNK_LEN := 16.0
const HORIZON := 150.0
const ROAD_HALF := 5.0
const WALL_X := 6.5

var _player: CharacterBody3D
var _cam: Camera3D
var _hud: CanvasLayer
var _chunks: Array = []
var _next_z := 0.0
var _level := 1
var _level_len := 100.0
var _finish_z := -100.0
var _spawn_t := 1.0
var _road_rng := RandomNumberGenerator.new()
var _state := "playing"   # playing / over / complete


func _ready() -> void:
	_level = GameState.current
	_road_rng.seed = 1000 + _level * 97
	_level_len = 90.0 + _level * 8.0
	_finish_z = -_level_len
	_build_light()
	_build_ground()
	_build_walls()
	_spawn_player()
	_build_hud()
	_build_finish()
	while _next_z > _finish_z - HORIZON * 0.5:
		_spawn_chunk()


func _process(delta: float) -> void:
	if not _player or _state != "playing":
		return

	_cam.global_position = _player.global_position + Vector3(0, 11.5, 7.0)
	_cam.look_at(_player.global_position + Vector3(0, 1.0, -5.0), Vector3.UP)

	# финиш достигнут
	if _player.global_position.z <= _finish_z:
		_complete_level()
		return

	# генерация города вперёд
	while _next_z > _player.global_position.z - HORIZON:
		_spawn_chunk()

	_cleanup_chunks()

	# спавн врагов
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_enemies()
		_spawn_t = clampf(1.5 - float(_level) * 0.06, 0.4, 1.5)


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
	# окружение: мягкий фоновый свет + небо
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.52, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# солнце
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-55, 30, 0)
	dl.light_energy = 1.2
	dl.shadow_enabled = true
	add_child(dl)


func _build_ground() -> void:
	var len := _level_len + 200.0
	var g := StaticBody3D.new()
	g.collision_layer = 1
	g.collision_mask = 0
	add_child(g)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(60, 0.5, len)
	col.shape = cs
	col.position = Vector3(0, -0.25, -len * 0.5)
	g.add_child(col)

	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, len)
	m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.26)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = Vector3(0, -0.01, -len * 0.5)
	add_child(m)


func _build_walls() -> void:
	var len := _level_len + 200.0
	_wall(Vector3(0.5, 4.0, len), Vector3(-WALL_X, 2.0, -len * 0.5))
	_wall(Vector3(0.5, 4.0, len), Vector3(WALL_X, 2.0, -len * 0.5))


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
	if _next_z < _finish_z - CHUNK_LEN:
		_next_z -= CHUNK_LEN
		return
	var z := _next_z
	_next_z -= CHUNK_LEN

	var chunk := Node3D.new()
	chunk.position = Vector3(0, 0, z)
	add_child(chunk)
	_chunks.append({"node": chunk, "z": z})

	_box(Vector3(ROAD_HALF * 2, 0.04, CHUNK_LEN), Vector3(0, 0.02, -CHUNK_LEN * 0.5), Color(0.14, 0.14, 0.16), chunk)
	_box(Vector3(1.4, 0.06, CHUNK_LEN), Vector3(-(ROAD_HALF + 0.7), 0.03, -CHUNK_LEN * 0.5), Color(0.42, 0.42, 0.46), chunk)
	_box(Vector3(1.4, 0.06, CHUNK_LEN), Vector3(ROAD_HALF + 0.7, 0.03, -CHUNK_LEN * 0.5), Color(0.42, 0.42, 0.46), chunk)

	_building(chunk, -1, z)
	_building(chunk, 1, z)

	if int(abs(z) / CHUNK_LEN) % 4 == 0:
		for s in range(5):
			_box(Vector3(0.7, 0.03, 0.6), Vector3(-2.8 + s * 1.4, 0.045, -CHUNK_LEN * 0.5), Color(0.9, 0.9, 0.92), chunk)

	if int(abs(z) / CHUNK_LEN) % 3 == 0:
		_streetlight(chunk, -1, -CHUNK_LEN * 0.3)
		_streetlight(chunk, 1, -CHUNK_LEN * 0.7)

	if _road_rng.randf() < 0.12:
		_car(chunk, -CHUNK_LEN * 0.5)


func _building(parent: Node3D, side: int, z: float) -> void:
	var h := _road_rng.randf_range(6.0, 15.0)
	var xc := side * 9.5
	var base := Color(_road_rng.randf_range(0.25, 0.5), _road_rng.randf_range(0.22, 0.4), _road_rng.randf_range(0.2, 0.35))
	_box(Vector3(6.5, h, CHUNK_LEN - 1.0), Vector3(xc, h * 0.5, -CHUNK_LEN * 0.5), base, parent)

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


func _build_finish() -> void:
	var fz := _finish_z
	# ворота
	var p1 := _box(Vector3(0.6, 6.0, 0.6), Vector3(-3.5, 3.0, fz), Color(0.9, 0.85, 0.6), self)
	var p2 := _box(Vector3(0.6, 6.0, 0.6), Vector3(3.5, 3.0, fz), Color(0.9, 0.85, 0.6), self)
	var banner := _box(Vector3(7.6, 1.4, 0.3), Vector3(0, 6.2, fz), Color(1.0, 0.85, 0.4), self, Color(0.4, 0.2, 0.05))


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
	_player._finish_limit = _finish_z
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
	_hud.set_level(_level)
	_hud.flash_level(_level)


func _spawn_enemies() -> void:
	var count := 1 + int(_level / 4)
	if count > 4:
		count = 4
	for i in range(count):
		var e := CharacterBody3D.new()
		e.set_script(SkibidiScr)
		var z := _player.global_position.z - _road_rng.randf_range(20.0, 38.0)
		z = maxf(z, _finish_z + 10.0)
		var x := _road_rng.randf_range(-ROAD_HALF + 0.8, ROAD_HALF - 0.8)
		e.position = Vector3(x, 0, z)
		add_child(e)
		e.setup(_level)
		e.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	GameState.add_score(10 * GameState.current)
	GameState.add_coins(2 + GameState.current)
	_hud.update_score()
	_hud.update_coins()


func _on_player_died() -> void:
	if _state != "playing":
		return
	_state = "over"
	_hud.show_game_over(GameState.score)


func _complete_level() -> void:
	if _state != "playing":
		return
	_state = "complete"
	GameState.complete_level(_level)
	GameState.add_coins(20 + _level * 5)
	_hud.show_complete(_level)
	await get_tree().create_timer(2.2).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
