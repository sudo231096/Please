extends CharacterBody3D
## Скибиди-туалет: преследует камерамена и кусает.

const WHITE := Color(0.95, 0.95, 0.97)
const LIGHT := Color(0.82, 0.85, 0.9)
const SKIN := Color(0.93, 0.78, 0.62)

var hp := 40.0
var max_hp := 40.0
var speed := 3.0
var contact_dmg := 15
var _player: Node3D
var _head: Node3D
var _hit_cd := 0.0
var _t := 0.0

signal died


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_build()
	_player = get_tree().get_first_node_in_group("player")


func setup(wave: int) -> void:
	max_hp = 40.0 + wave * 14.0
	hp = max_hp
	speed = 2.7 + wave * 0.28
	contact_dmg = 12 + wave * 2


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
	# коллизия
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(1.0, 1.8, 0.9)
	col.shape = cs
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	# чаша унитаза
	_box(Vector3(1.0, 0.7, 0.85), Vector3(0, 0.35, 0), WHITE)
	# бачок сзади
	_box(Vector3(0.9, 0.55, 0.28), Vector3(0, 0.82, -0.55), WHITE)
	# сиденье
	_box(Vector3(1.02, 0.12, 0.86), Vector3(0, 0.72, 0), LIGHT)

	# голова (вылезает из унитаза, поёт)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.95, 0)
	add_child(_head)
	_box(Vector3(0.16, 0.4, 0.16), Vector3(0, 0.2, 0), SKIN, _head)
	_box(Vector3(0.5, 0.5, 0.5), Vector3(0, 0.5, 0), SKIN, _head)
	# глаза
	_box(Vector3(0.12, 0.1, 0.06), Vector3(-0.12, 0.55, -0.26), Color(0.05, 0.05, 0.05), _head)
	_box(Vector3(0.12, 0.1, 0.06), Vector3(0.12, 0.55, -0.26), Color(0.05, 0.05, 0.05), _head)
	# поющий рот
	_box(Vector3(0.2, 0.12, 0.06), Vector3(0, 0.36, -0.26), Color(0.7, 0.2, 0.2), _head)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	_t += delta
	# голова покачивается (поёт)
	_head.position.y = 0.95 + sin(_t * 8.0) * 0.06

	var to: Vector3 = _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.9:
		velocity.x = to.x / dist * speed
		velocity.z = to.z / dist * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# поворот к игроку
	if dist > 0.05:
		var look_p: Vector3 = _player.global_position
		look_p.y = global_position.y
		look_at(look_p, Vector3.UP)

	# контактный урон
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if dist < 1.3 and _hit_cd <= 0.0:
		_player.take_damage(contact_dmg)
		_hit_cd = 1.0

	move_and_slide()


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit()
		queue_free()
