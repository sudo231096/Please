extends CharacterBody3D
## Камерамен — бежит вперёд по улице, дерётся кулаками (ближний бой).

const RUN_SPEED := 6.0
const STRAFE_SPEED := 6.0
const MELEE_RANGE := 2.8
const MELEE_CD := 0.45
const STREET_HALF := 4.6

var max_hp := 100.0
var hp := 100.0
var damage := 34.0
var _punch_t := 0.0
var _punch_cd := 0.0
var _invuln := 0.0
var _fist_r: Node3D
var _fist_l: Node3D

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
	cs.radius = 0.35
	cs.height = 1.7
	col.shape = cs
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	var navy := Color(0.16, 0.2, 0.32)
	var skin := Color(0.93, 0.78, 0.62)
	# ноги
	_box(Vector3(0.24, 0.5, 0.24), Vector3(-0.18, 0.5, 0), Color(0.1, 0.1, 0.14))
	_box(Vector3(0.24, 0.5, 0.24), Vector3(0.18, 0.5, 0), Color(0.1, 0.1, 0.14))
	# торс
	_box(Vector3(0.7, 0.9, 0.45), Vector3(0, 1.05, 0), navy)

	# кулаки (руки) — узлы для анимации
	_fist_r = Node3D.new()
	_fist_r.position = Vector3(0.5, 1.05, 0)
	add_child(_fist_r)
	_box(Vector3(0.2, 0.6, 0.2), Vector3(0, 0, 0), navy, _fist_r)
	_box(Vector3(0.22, 0.22, 0.22), Vector3(0, -0.42, 0), skin, _fist_r)

	_fist_l = Node3D.new()
	_fist_l.position = Vector3(-0.5, 1.05, 0)
	add_child(_fist_l)
	_box(Vector3(0.2, 0.6, 0.2), Vector3(0, 0, 0), navy, _fist_l)
	_box(Vector3(0.22, 0.22, 0.22), Vector3(0, -0.42, 0), skin, _fist_l)

	# шея
	_box(Vector3(0.16, 0.2, 0.16), Vector3(0, 1.55, 0), skin)
	# голова-камера
	_box(Vector3(0.55, 0.55, 0.55), Vector3(0, 1.85, 0), Color(0.2, 0.22, 0.26))
	# объектив (вперёд, -Z)
	var lens := _cyl(0.13, 0.16, Color(0.05, 0.05, 0.08))
	lens.position = Vector3(0, 1.85, -0.3)
	lens.rotation_degrees = Vector3(-90, 0, 0)
	# красная лампочка записи
	_box(Vector3(0.08, 0.08, 0.08), Vector3(0, 2.14, 0), Color(1.0, 0.2, 0.2))


func _cyl(r: float, h: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)
	return m


func _physics_process(delta: float) -> void:
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if hp <= 0.0:
		return

	# стрейф влево/вправо
	var strafe := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		strafe -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		strafe += 1.0
	if has_meta("mob_dir"):
		var jd: Vector2 = get_meta("mob_dir")
		strafe += jd.x

	# авто-бег вперёд (-Z)
	velocity.z = -RUN_SPEED
	velocity.x = strafe * STRAFE_SPEED

	# не выходим за улицу
	global_position.x = clampf(global_position.x, -STREET_HALF, STREET_HALF)

	# прицел: ближайший враг, иначе — вперёд
	var target := _nearest_enemy()
	if target:
		var look_p: Vector3 = target.global_position
		look_p.y = global_position.y
		if global_position.distance_to(look_p) > 0.05:
			look_at(look_p, Vector3.UP)
	else:
		look_at(global_position + Vector3(0, 0, -1), Vector3.UP)

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
	_punch_t = 0.22
	# бьём всех врагов в радиусе
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var d: float = en.global_position.distance_to(global_position)
		if d <= MELEE_RANGE and en.has_method("take_damage"):
			en.take_damage(damage)


func _animate_punch(delta: float) -> void:
	if _punch_t > 0.0:
		_punch_t -= delta
		var k := _punch_t / 0.22  # 1 -> 0
		var reach := k * 0.9
		_fist_r.position.z = -reach
		_fist_l.position.z = -reach * 0.7
	else:
		_fist_r.position.z = 0.0
		_fist_l.position.z = 0.0


func take_damage(amount: float, from: Node = null, knock: float = 0.0) -> void:
	if hp <= 0.0 or _invuln > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_invuln = 0.4
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
