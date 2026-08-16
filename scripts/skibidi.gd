extends CharacterBody3D
## Скибиди-туалет с циркулярной пилой: преследует камерамена и режет.

const WHITE := Color(0.87, 0.87, 0.9)
const GRUNGE := Color(0.62, 0.6, 0.55)
const RUST := Color(0.45, 0.26, 0.14)
const BLOOD := Color(0.55, 0.07, 0.07)
const SKIN := Color(0.78, 0.8, 0.68)  # болезненно-бледный
const EYE := Color(1.0, 0.06, 0.04)
const METAL := Color(0.78, 0.8, 0.84)

var hp := 40.0
var max_hp := 40.0
var speed := 3.0
var contact_dmg := 15
var _player: Node3D
var _head: Node3D
var _saw: Node3D
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


func _cyl(r: float, h: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 24
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
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

	# чаша унитаза (грязная, с кровью)
	_box(Vector3(1.0, 0.7, 0.85), Vector3(0, 0.35, 0), WHITE)
	# бачок сзади
	_box(Vector3(0.9, 0.55, 0.28), Vector3(0, 0.82, -0.55), WHITE)
	# сиденье
	_box(Vector3(1.02, 0.12, 0.86), Vector3(0, 0.72, 0), GRUNGE)
	# ржавые подтёки на чаше
	_box(Vector3(0.2, 0.14, 0.05), Vector3(-0.28, 0.5, 0.44), RUST)
	_box(Vector3(0.14, 0.2, 0.05), Vector3(0.3, 0.42, 0.44), RUST)
	# кровь на ободке
	_box(Vector3(0.5, 0.05, 0.05), Vector3(0.05, 0.72, 0.42), BLOOD)
	_box(Vector3(0.2, 0.06, 0.05), Vector3(-0.25, 0.5, 0.44), BLOOD)

	# голова (вылезает из унитаза, поёт)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.95, 0)
	add_child(_head)
	# шея
	_box(Vector3(0.16, 0.4, 0.16), Vector3(0, 0.2, 0), SKIN, _head)
	# череп
	_box(Vector3(0.52, 0.5, 0.5), Vector3(0, 0.5, 0), SKIN, _head)
	# тёмные глазницы
	_box(Vector3(0.16, 0.13, 0.06), Vector3(-0.13, 0.56, -0.26), Color(0.06, 0.04, 0.04), _head)
	_box(Vector3(0.16, 0.13, 0.06), Vector3(0.13, 0.56, -0.26), Color(0.06, 0.04, 0.04), _head)
	# светящиеся красные глаза
	_box(Vector3(0.1, 0.07, 0.05), Vector3(-0.13, 0.56, -0.3), EYE, _head)
	_box(Vector3(0.1, 0.07, 0.05), Vector3(0.13, 0.56, -0.3), EYE, _head)
	# открытый рот
	_box(Vector3(0.24, 0.16, 0.08), Vector3(0, 0.34, -0.26), Color(0.15, 0.03, 0.03), _head)
	# зубы
	_box(Vector3(0.05, 0.06, 0.05), Vector3(-0.09, 0.42, -0.3), Color(0.9, 0.88, 0.8), _head)
	_box(Vector3(0.05, 0.06, 0.05), Vector3(-0.02, 0.42, -0.3), Color(0.9, 0.88, 0.8), _head)
	_box(Vector3(0.05, 0.06, 0.05), Vector3(0.05, 0.42, -0.3), Color(0.9, 0.88, 0.8), _head)
	_box(Vector3(0.05, 0.06, 0.05), Vector3(-0.09, 0.27, -0.3), Color(0.9, 0.88, 0.8), _head)
	_box(Vector3(0.05, 0.06, 0.05), Vector3(-0.02, 0.27, -0.3), Color(0.9, 0.88, 0.8), _head)
	_box(Vector3(0.05, 0.06, 0.05), Vector3(0.05, 0.27, -0.3), Color(0.9, 0.88, 0.8), _head)
	# шрам через глаз
	_box(Vector3(0.3, 0.03, 0.03), Vector3(0.06, 0.6, -0.28), BLOOD, _head)

	_build_saw()


func _build_saw() -> void:
	# циркулярная пила впереди (смотрит на игрока, -Z)
	_saw = Node3D.new()
	_saw.position = Vector3(0, 0.95, -0.72)
	add_child(_saw)

	# диск пилы (ось вдоль Z -> лицом к игроку)
	var disc := _cyl(0.4, 0.06, METAL, _saw)
	disc.rotation_degrees = Vector3(90, 0, 0)
	# ступица
	var hub := _cyl(0.1, 0.09, Color(0.3, 0.3, 0.34), _saw)
	hub.rotation_degrees = Vector3(90, 0, 0)

	# зубья по кругу
	for i in range(12):
		var a := float(i) * TAU / 12.0
		var tooth := _box(Vector3(0.16, 0.06, 0.06), Vector3(cos(a) * 0.44, sin(a) * 0.44, 0), METAL, _saw)
		tooth.rotation.z = a


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	_t += delta
	# голова покачивается (поёт), пила вращается
	_head.position.y = 0.95 + sin(_t * 8.0) * 0.06
	_saw.rotate_z(delta * 26.0)

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

	# контактный урон (пила)
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
