extends CharacterBody3D
## Дикий зверь (медведь): преследует игрока и кусает.

const GRAV := 14.0

var hp := 80.0
var max_hp := 80.0
var speed := 3.8
var contact_dmg := 18.0
var _player: Node3D
var _hit_cd := 0.0

signal died


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_build()
	_player = get_tree().get_first_node_in_group("player")


func setup(level: int) -> void:
	max_hp = 60.0 + level * 15.0
	hp = max_hp
	speed = 3.2 + level * 0.2
	contact_dmg = 14.0 + level * 2.0


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


func _sphere(r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
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
	cs.radius = 0.6
	cs.height = 1.4
	col.shape = cs
	col.position = Vector3(0, 0.7, 0)
	add_child(col)

	var brown := Color(0.45, 0.3, 0.18)
	var dark := Color(0.3, 0.2, 0.12)
	# тело
	_box(Vector3(1.1, 0.8, 1.6), Vector3(0, 0.7, 0), brown)
	# голова
	_sphere(0.42, Vector3(0, 1.25, -0.75), brown)
	# морда
	_sphere(0.16, Vector3(0, 1.2, -1.15), dark)
	# уши
	_sphere(0.13, Vector3(-0.28, 1.6, -0.7), dark)
	_sphere(0.13, Vector3(0.28, 1.6, -0.7), dark)
	# лапы
	_box(Vector3(0.28, 0.5, 0.28), Vector3(-0.45, 0.25, 0.55), dark)
	_box(Vector3(0.28, 0.5, 0.28), Vector3(0.45, 0.25, 0.55), dark)
	_box(Vector3(0.28, 0.5, 0.28), Vector3(-0.45, 0.25, -0.55), dark)
	_box(Vector3(0.28, 0.5, 0.28), Vector3(0.45, 0.25, -0.55), dark)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	if not is_on_floor():
		velocity.y -= GRAV * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 1.3:
		velocity.x = to.x / dist * speed
		velocity.z = to.z / dist * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if dist > 0.05:
		var lp := _player.global_position
		lp.y = global_position.y
		look_at(lp, Vector3.UP)

	_hit_cd = maxf(0.0, _hit_cd - delta)
	if dist < 1.6 and _hit_cd <= 0.0:
		_player.take_damage(contact_dmg)
		_hit_cd = 1.0

	move_and_slide()


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit()
		queue_free()
