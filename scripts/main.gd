extends Node3D
## Основная сцена: арена, камерамен, волны скибиди-туалетов.

const PlayerScr := preload("res://scripts/player.gd")
const SkibidiScr := preload("res://scripts/skibidi.gd")
const HudScr := preload("res://scripts/hud.gd")

const ARENA := 24.0
const CAM_OFFSET := Vector3(0, 15, 10)

var _player: CharacterBody3D
var _cam: Camera3D
var _hud: CanvasLayer
var _state := "spawning"
var _enemies_left := 0
var _spawn_left := 0
var _spawn_t := 0.3


func _ready() -> void:
	GameState.reset_run()
	_build_world()
	_spawn_player()
	_build_hud()
	_start_wave()


func _process(delta: float) -> void:
	if _player and _cam:
		_cam.global_position = _player.global_position + CAM_OFFSET
		_cam.look_at(_player.global_position + Vector3(0, 1, 0), Vector3.UP)

	if _state == "spawning":
		if _spawn_left > 0:
			_spawn_t -= delta
			if _spawn_t <= 0.0:
				_spawn_enemy()
				_spawn_left -= 1
				_spawn_t = 0.35
		else:
			_state = "playing"


func _build_world() -> void:
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-60, 30, 0)
	add_child(dl)

	# пол
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	floor.collision_mask = 0
	add_child(floor)
	var fcol := CollisionShape3D.new()
	var fcs := BoxShape3D.new()
	fcs.size = Vector3(ARENA * 2, 0.5, ARENA * 2)
	fcol.shape = fcs
	fcol.position = Vector3(0, -0.25, 0)
	floor.add_child(fcol)
	var fm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA * 2, ARENA * 2)
	fm.mesh = pm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = _grid_texture()
	fmat.uv1_scale = Vector3(12, 12, 12)
	fmat.texture_repeat = true
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.material_override = fmat
	floor.add_child(fm)

	# стены
	var wall_h := 3.0
	_wall(Vector3(ARENA * 2, wall_h, 0.5), Vector3(0, wall_h * 0.5, -ARENA))
	_wall(Vector3(ARENA * 2, wall_h, 0.5), Vector3(0, wall_h * 0.5, ARENA))
	_wall(Vector3(0.5, wall_h, ARENA * 2), Vector3(-ARENA, wall_h * 0.5, 0))
	_wall(Vector3(0.5, wall_h, ARENA * 2), Vector3(ARENA, wall_h * 0.5, 0))


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
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.28, 0.34)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	w.add_child(m)


func _grid_texture() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var c1 := Color(0.17, 0.21, 0.26)
	var c2 := Color(0.13, 0.16, 0.2)
	for y in range(s):
		for x in range(s):
			var cell := (int(x / 32) + int(y / 32)) % 2
			img.set_pixel(x, y, c1 if cell == 0 else c2)
	return ImageTexture.create_from_image(img)


func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.set_script(PlayerScr)
	_player.position = Vector3(0, 0, 0)
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


func _start_wave() -> void:
	var count := 2 + GameState.wave * 2
	if count > 34:
		count = 34
	_enemies_left = count
	_spawn_left = count
	_spawn_t = 0.3
	_state = "spawning"
	_hud.set_wave(GameState.wave)


func _spawn_enemy() -> void:
	var e := CharacterBody3D.new()
	e.set_script(SkibidiScr)
	var ang := randf() * TAU
	var r := ARENA - 4.0
	e.position = Vector3(cos(ang) * r, 0, sin(ang) * r)
	add_child(e)
	e.setup(GameState.wave)
	e.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	GameState.add_score(10 * GameState.wave)
	_hud.update_score()
	_enemies_left -= 1
	if _enemies_left <= 0 and _state == "playing":
		_state = "between"
		await get_tree().create_timer(1.5).timeout
		if _state != "over":
			GameState.wave += 1
			_start_wave()


func _on_player_died() -> void:
	if _state == "over":
		return
	_state = "over"
	_hud.show_game_over(GameState.score)
