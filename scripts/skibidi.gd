extends CharacterBody3D
## Скибиди-туалет (скачанная 3D-модель): преследует камерамена.
## Разновидности: 0 = обычный, 1 = быстрый (оранжевый), 2 = танк (красный, жирный).

const ModelScene := preload("res://models/skibidi_toilet.glb")
# Godot уже применяет scale 0.01 из файла, модель нативно ~1.1 x 1.15 x 0.91 м.
const MODEL_SCALE := 1.0
# Модель «лицом» смотрит вдоль +X в исходнике — поворачиваем на 90°, чтобы смотрела вперёд (-Z).
const MODEL_YAW := 90.0
const MODEL_OFFSET := Vector3(0.0, 0.13, -0.236)

# характеристики разновидностей: [scale, hp_mult, speed_mult, dmg_mult, tint]
const VARIANTS := [
	{"scale": 1.0, "hp": 1.0, "speed": 1.0, "dmg": 1.0, "tint": Color(1, 1, 1)},
	{"scale": 0.8, "hp": 0.6, "speed": 1.6, "dmg": 0.8, "tint": Color(1.0, 0.72, 0.35)},
	{"scale": 1.4, "hp": 2.5, "speed": 0.6, "dmg": 1.8, "tint": Color(1.0, 0.42, 0.42)},
]

var variant := 0
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
	set_variant(variant, wave)


func set_variant(v: int, wave: int) -> void:
	variant = clampi(v, 0, VARIANTS.size() - 1)
	var cfg: Dictionary = VARIANTS[variant]
	max_hp = (40.0 + wave * 14.0) * cfg["hp"]
	hp = max_hp
	speed = (2.7 + wave * 0.28) * cfg["speed"]
	contact_dmg = int((12 + wave * 2) * cfg["dmg"])

	if _model:
		var s: float = cfg["scale"]
		_model.scale = Vector3.ONE * s
		var tint: Color = cfg["tint"]
		for m in _model.find_children("*", "MeshInstance3D", true, false):
			var mat: Material = m.get_active_material(0)
			if mat and mat is StandardMaterial3D:
				var sm := (mat as StandardMaterial3D)
				if sm.albedo_texture == null:  # корпус туалета — красим в цвет варианта
					var tmat := StandardMaterial3D.new()
					tmat.albedo_color = tint
					tmat.roughness = 0.9
					m.material_override = tmat

	# коллизия под масштаб
	var col: CollisionShape3D = get_node_or_null("Col")
	if col and col.shape is BoxShape3D:
		var b := (col.shape as BoxShape3D)
		b.size = Vector3(1.0, 1.15, 0.9) * cfg["scale"]
		col.position = Vector3(0, 0.575 * cfg["scale"], 0)


func _build() -> void:
	# коллизия под размер туалета
	var col := CollisionShape3D.new()
	col.name = "Col"
	var cs := BoxShape3D.new()
	cs.size = Vector3(1.0, 1.15, 0.9)
	col.shape = cs
	col.position = Vector3(0, 0.575, 0)
	add_child(col)

	# скачанная модель
	_model = ModelScene.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation_degrees = Vector3(0, MODEL_YAW, 0)
	_model.position = MODEL_OFFSET
	add_child(_model)

	# голова в сериале Dafuq!?Boom! — чистая серая, а не тёмная «рваная» текстура.
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = m.get_active_material(0)
		if mat and mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture != null:
			var gray := StandardMaterial3D.new()
			gray.albedo_color = Color(0.76, 0.76, 0.79)
			gray.roughness = 0.9
			m.material_override = gray


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
