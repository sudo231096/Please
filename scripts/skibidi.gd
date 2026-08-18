extends CharacterBody3D
## Скибиди-туалет (скачанная 3D-модель): преследует камерамена.

const ModelScene := preload("res://models/skibidi_toilet.glb")
# Godot уже применяет scale 0.01 из файла, модель нативно ~1.1 x 1.15 x 0.91 м.
const MODEL_SCALE := 1.0
# Центрируем по X/Z и ставим на землю (низ модели на y = -0.13).
const MODEL_OFFSET := Vector3(0.235, 0.13, 0.0)

var hp := 40.0
var max_hp := 40.0
var speed := 3.0
var contact_dmg := 15
var _player: Node3D
var _model: Node3D
var _hit_cd := 0.0

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


func _build() -> void:
	# коллизия под размер туалета
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(1.0, 1.15, 0.9)
	col.shape = cs
	col.position = Vector3(0, 0.575, 0)
	add_child(col)

	# скачанная модель
	_model = ModelScene.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.position = MODEL_OFFSET
	add_child(_model)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	# если отстал далеко позади игрока — исчезаем
	if global_position.z > _player.global_position.z + 35.0:
		queue_free()
		return

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
