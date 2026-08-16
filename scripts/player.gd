extends CharacterBody3D
## Камерамен — игрок.

const SPEED := 6.0
const MAX_HP := 100
const FIRE_CD := 0.35
const DAMAGE := 34.0

var hp := MAX_HP
var _fire_t := 0.0
var _invuln := 0.0

signal died
signal hp_changed(hp: float, max_hp: float)

const BulletScr := preload("res://scripts/bullet.gd")


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_build()
	hp = MAX_HP


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	add_child(m)
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
	# ноги
	_box(Vector3(0.24, 0.5, 0.24), Vector3(-0.18, 0.5, 0), Color(0.1, 0.1, 0.14))
	_box(Vector3(0.24, 0.5, 0.24), Vector3(0.18, 0.5, 0), Color(0.1, 0.1, 0.14))
	# торс
	_box(Vector3(0.7, 0.9, 0.45), Vector3(0, 1.05, 0), navy)
	# руки
	_box(Vector3(0.2, 0.6, 0.2), Vector3(-0.5, 1.05, 0), navy)
	_box(Vector3(0.2, 0.6, 0.2), Vector3(0.5, 1.05, 0), navy)
	# шея
	_box(Vector3(0.16, 0.2, 0.16), Vector3(0, 1.55, 0), Color(0.93, 0.78, 0.62))
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
	_fire_t = maxf(0.0, _fire_t - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if hp <= 0.0:
		return

	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if has_meta("mob_dir"):
		dir += get_meta("mob_dir")
	if dir.length() > 1.0:
		dir = dir.normalized()

	velocity.x = dir.x * SPEED
	velocity.z = dir.y * SPEED

	# прицел: ближайший враг, иначе — направление движения
	var target := _nearest_enemy()
	if target:
		var look_p: Vector3 = target.global_position
		look_p.y = global_position.y
		if global_position.distance_to(look_p) > 0.05:
			look_at(look_p, Vector3.UP)
	elif dir.length() > 0.05:
		look_at(global_position + Vector3(dir.x, 0, dir.y), Vector3.UP)

	# стрельба
	var fire := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if has_meta("mob_fire") and bool(get_meta("mob_fire")):
		fire = true
	if fire and _fire_t <= 0.0:
		_fire()

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


func _fire() -> void:
	_fire_t = FIRE_CD
	var dir3 := Vector3(0, 0, -1)
	var t := _nearest_enemy()
	if t:
		dir3 = t.global_position - global_position
		dir3.y = 0.0
		if dir3.length() > 0.01:
			dir3 = dir3.normalized()
		else:
			dir3 = -global_transform.basis.z
			dir3.y = 0.0
			dir3 = dir3.normalized()
	else:
		dir3 = -global_transform.basis.z
		dir3.y = 0.0
		dir3 = dir3.normalized()

	var b := Area3D.new()
	b.set_script(BulletScr)
	var spawn := global_position + Vector3(0, 1.85, 0) + dir3 * 0.7
	get_tree().current_scene.add_child(b)
	b.global_position = spawn
	b.dir = dir3


func take_damage(amount: float, from: Node = null, knock: float = 0.0) -> void:
	if hp <= 0.0 or _invuln > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_invuln = 0.4
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0.0:
		died.emit()
