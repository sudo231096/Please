extends CharacterBody2D

const PixelArt = preload("res://scripts/pixel.gd")
## Босс — гигантский разбойник (уровень 20). Рывок, прыжки, супер-удар на 50 HP + отброс.

const GRAV := 1100.0
const MAX_HP := 1200
const CHASE := 190.0
const CONTACT_DMG := 25
const SUPER_DMG := 50
const SUPER_RANGE := 150.0
const SUPER_TELEGRAPH := 0.55
const SUPER_CD := 3.2

var hp := MAX_HP
var max_hp := MAX_HP
var alive := true
var _dir := -1.0
var _player: Node2D
var _sprite: Sprite2D
var _tex := {}
var _anim_t := 0.0
var _walk := 0
var _touch_cd := 0.0
var _super_cd := 1.2
var _telegraph := -1.0
var _strike_t := 0.0

signal died(pos: Vector2)
signal hp_changed(hp: int, max_hp: int)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_build()
	_player = get_tree().get_first_node_in_group("player")
	hp_changed.emit(hp, max_hp)


func _build() -> void:
	var col := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = Vector2(28, 44)
	col.shape = cs
	col.position = Vector2(0, -22)
	add_child(col)

	_tex[0] = PixelArt.boss_tex(0)
	_tex[1] = PixelArt.boss_tex(1)
	_tex[2] = PixelArt.boss_tex(2)
	_tex[3] = PixelArt.boss_tex(3)

	_sprite = Sprite2D.new()
	_sprite.texture = _tex[0]
	_sprite.centered = true
	_sprite.position = Vector2(0, -24)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.5, 2.5)
	add_child(_sprite)

	# контактный урон при касании
	var hurt := Area2D.new()
	hurt.collision_layer = 0
	hurt.collision_mask = 2
	hurt.monitoring = true
	add_child(hurt)
	var hcol := CollisionShape2D.new()
	var hs := RectangleShape2D.new()
	hs.size = Vector2(30, 44)
	hcol.shape = hs
	hcol.position = Vector2(0, -22)
	hurt.add_child(hcol)
	hurt.body_entered.connect(_on_touch_player)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	if not is_on_floor():
		velocity.y += GRAV * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	_touch_cd = maxf(0.0, _touch_cd - delta)
	_super_cd = maxf(0.0, _super_cd - delta)

	if _telegraph >= 0.0:
		# подготовка супер-удара: стоит, мигает красным
		_telegraph -= delta
		velocity.x = 0.0
		_sprite.modulate = Color(1.0, 0.3, 0.3) if fmod(_telegraph * 20.0, 2.0) < 1.0 else Color(1.0, 0.7, 0.7)
		if _telegraph < 0.0:
			_sprite.modulate = Color.WHITE
			_do_strike()
	else:
		# преследование
		if is_instance_valid(_player):
			var dx: float = _player.global_position.x - global_position.x
			_dir = 1.0 if dx > 0.0 else -1.0
			velocity.x = _dir * CHASE
			if _player.global_position.y < global_position.y - 20.0 and absf(dx) < 120.0 and is_on_floor():
				velocity.y = -460.0
		# старт супер-удара, когда игрок близко
		if _super_cd <= 0.0 and is_instance_valid(_player):
			var dx2: float = _player.global_position.x - global_position.x
			if absf(dx2) < SUPER_RANGE:
				_telegraph = SUPER_TELEGRAPH
				_super_cd = SUPER_CD

	if _strike_t > 0.0:
		_strike_t -= delta

	if _dir != 0.0:
		_sprite.flip_h = _dir < 0.0

	_update_animation(delta)
	move_and_slide()


func _do_strike() -> void:
	_strike_t = 0.22
	if is_instance_valid(_player):
		var dx: float = _player.global_position.x - global_position.x
		var dy: float = _player.global_position.y - global_position.y
		if absf(dx) < 95.0 and absf(dy) < 70.0 and _player.has_method("take_damage"):
			_player.take_damage(SUPER_DMG, self, 560.0)


func _update_animation(delta: float) -> void:
	_anim_t += delta
	if _telegraph >= 0.0 or _strike_t > 0.0:
		_set_pose(3)
		return
	if absf(velocity.x) > 10.0 and is_on_floor():
		if _anim_t > 0.11:
			_anim_t = 0.0
			_walk = 1 - _walk
		_set_pose(1 + _walk)
	else:
		_set_pose(0)


func _set_pose(p: int) -> void:
	if _sprite.texture != _tex[p]:
		_sprite.texture = _tex[p]


func _on_touch_player(body: Node2D) -> void:
	if not alive or _touch_cd > 0.0:
		return
	if body and body.has_method("take_damage"):
		body.take_damage(CONTACT_DMG, self)
		_touch_cd = 0.8


func take_damage(amount: int, from: Node = null) -> void:
	if not alive:
		return
	hp -= amount
	_sprite.modulate = Color(1, 0.4, 0.4)
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE
	)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		alive = false
		died.emit(global_position)
		queue_free()
