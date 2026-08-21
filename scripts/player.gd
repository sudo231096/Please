extends CharacterBody3D
## Камерамен — свободно бегает по улице, дерётся кулаками (ближний бой).

const RUN_SPEED := 6.0
const STRAFE_SPEED := 6.0
const MELEE_RANGE := 2.8
const MELEE_CD := 0.45
const STREET_HALF := 4.6

const ModelScene := preload("res://models/cameraman.glb")
# Модель ~18.8 юнитов ростом (mixamorig). Приводим к ~1.8 м.
const MODEL_SCALE := 0.0957
# Модель смотрит «лицом» в +Z — разворачиваем на 180°, чтобы смотрела вперёд (-Z).
const MODEL_YAW := 180.0
const MODEL_OFFSET := Vector3(0, 0, 0.099)

var max_hp := 100.0
var hp := 100.0
var damage := 34.0
var _punch_t := 0.0
var _punch_cd := 0.0
var _punch_side := 1.0
var _invuln := 0.0
var _model: Node3D
var _finish_limit := -10000.0

signal died
signal hp_changed(hp: float, max_hp: float)


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_build()
	max_hp = GameState.player_max_hp()
	hp = max_hp
	damage = GameState.player_damage()


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _build() -> void:
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.4
	cs.height = 1.7
	col.shape = cs
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	# скачанная модель камерамена
	_model = ModelScene.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation_degrees = Vector3(0, MODEL_YAW, 0)
	_model.position = MODEL_OFFSET
	add_child(_model)


func _physics_process(delta: float) -> void:
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if hp <= 0.0:
		return

	# движение во все стороны (управляет игрок)
	var mv_x := 0.0  # влево/вправо
	var mv_z := 0.0  # вперёд/назад (+ = назад)
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv_x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv_z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv_z += 1.0
	if has_meta("mob_dir"):
		var jd: Vector2 = get_meta("mob_dir")
		mv_x += jd.x
		mv_z += jd.y

	var mv := Vector2(mv_x, mv_z)
	if mv.length() > 1.0:
		mv = mv.normalized()
	velocity.x = mv.x * STRAFE_SPEED
	velocity.z = mv.y * STRAFE_SPEED

	# не выходим за улицу
	global_position.x = clampf(global_position.x, -STREET_HALF, STREET_HALF)
	global_position.z = clampf(global_position.z, _finish_limit, 10.0)

	# прицел: ближайший враг, иначе — в сторону движения
	var target := _nearest_enemy()
	if target:
		var look_p: Vector3 = target.global_position
		look_p.y = global_position.y
		if global_position.distance_to(look_p) > 0.05:
			look_at(look_p, Vector3.UP)
	elif mv.length() > 0.05:
		look_at(global_position + Vector3(mv.x, 0, mv.y), Vector3.UP)

	# удар рукой
	var punch := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_K) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if has_meta("mob_fire") and bool(get_meta("mob_fire")):
		punch = true
	if punch and _punch_cd <= 0.0:
		_punch()

	_animate_punch(delta)

	move_and_slide()


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := 1.0e9
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var d: float = en.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _punch() -> void:
	_punch_cd = MELEE_CD
	_punch_t = 0.26
	_punch_side = -_punch_side  # чередуем левую/правую
	# бьём всех врагов в радиусе
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var d: float = en.global_position.distance_to(global_position)
		if d <= MELEE_RANGE and en.has_method("take_damage"):
			en.take_damage(damage)


func _animate_punch(delta: float) -> void:
	if _punch_t > 0.0:
		_punch_t -= delta
		var k := _punch_t / 0.26  # 1 -> 0 (от замаха к удару)
		# замах назад (первая фаза) -> выпад вперёд (вторая фаза)
		if k > 0.8:
			# ветерок: отводим корпус назад
			var wind := (k - 0.8) / 0.2
			_model.position.z = MODEL_OFFSET.z + wind * 0.25
			_model.rotation_degrees.x = wind * 8.0
		else:
			# удар: выпад вперёд + наклон + разворот корпуса
			var kk := 1.0 - k / 0.8
			_model.position.z = MODEL_OFFSET.z - kk * 0.8
			_model.rotation_degrees.x = -kk * 24.0
			_model.rotation_degrees.y = MODEL_YAW + _punch_side * kk * 26.0
	else:
		_model.position.z = MODEL_OFFSET.z
		_model.rotation_degrees.x = 0.0
		_model.rotation_degrees.y = MODEL_YAW


func take_damage(amount: float, from: Node = null, knock: float = 0.0) -> void:
	if hp <= 0.0 or _invuln > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_invuln = 0.4
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
