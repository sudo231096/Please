extends CharacterBody2D

const PixelArt = preload("res://scripts/pixel.gd")
## Разбойник — патруль + агро на игрока. Сложность растёт с уровнем.

const GRAV := 1100.0

var hp := 60
var max_hp := 60
var alive := true
var damage := 14
var walk_speed := 90.0
var chase_speed := 150.0
var _dir := -1.0
var _player: Node2D
var _sprite: Sprite2D
var _tex := {}
var _think := 0.0
var _attack_cd := 0.0
var _anim_t := 0.0
var _walk := 0
var left_bound := 0.0
var right_bound := 0.0

signal died(pos: Vector2)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_build()
	_player = get_tree().get_first_node_in_group("player")


func _build() -> void:
	var col := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = Vector2(14, 22)
	col.shape = cs
	col.position = Vector2(0, -11)
	add_child(col)

	_tex[0] = PixelArt.bandit_tex(0)
	_tex[1] = PixelArt.bandit_tex(1)
	_tex[2] = PixelArt.bandit_tex(2)
	_tex[3] = PixelArt.bandit_tex(3)

	_sprite = Sprite2D.new()
	_sprite.texture = _tex[0]
	_sprite.centered = true
	_sprite.position = Vector2(0, -12)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2, 2)
	add_child(_sprite)

	# зона удара по игроку
	var hurt := Area2D.new()
	hurt.collision_layer = 0
	hurt.collision_mask = 2
	hurt.monitoring = true
	add_child(hurt)
	var hcol := CollisionShape2D.new()
	var hs := RectangleShape2D.new()
	hs.size = Vector2(16, 20)
	hcol.shape = hs
	hcol.position = Vector2(0, -11)
	hurt.add_child(hcol)
	hurt.body_entered.connect(_on_touch_player)


func setup_patrol(center_x: float, width: float, diff: float = 1.0) -> void:
	left_bound = center_x - width * 0.5
	right_bound = center_x + width * 0.5
	# сложность: HP, скорость, урон растут с diff (зависит от уровня)
	max_hp = int(round(60.0 * diff))
	hp = max_hp
	walk_speed = 90.0 * diff
	chase_speed = 150.0 * diff
	damage = int(round(14.0 * diff))


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

	_attack_cd = maxf(0.0, _attack_cd - delta)
	_think -= delta

	var chase := false
	if is_instance_valid(_player):
		var dx: float = _player.global_position.x - global_position.x
		var dy: float = absf(_player.global_position.y - global_position.y)
		if absf(dx) < 220.0 and dy < 80.0:
			chase = true
			_dir = 1.0 if dx > 0.0 else -1.0
			velocity.x = _dir * chase_speed
			if dy > 24.0 and _player.global_position.y < global_position.y - 10.0 and is_on_floor() and absf(dx) < 90.0:
				velocity.y = -340.0

	if not chase:
		if _think <= 0.0:
			_think = randf_range(0.8, 1.8)
			if randf() < 0.2:
				_dir = 0.0
			else:
				_dir = -1.0 if randf() < 0.5 else 1.0
		velocity.x = _dir * walk_speed
		if global_position.x < left_bound:
			_dir = 1.0
		elif global_position.x > right_bound:
			_dir = -1.0

	if _dir != 0.0:
		_sprite.flip_h = _dir < 0.0

	_update_animation(delta)

	move_and_slide()


func _update_animation(delta: float) -> void:
	_anim_t += delta
	if _attack_cd > 0.55:
		_set_pose(3)
		return
	if absf(velocity.x) > 10.0 and is_on_floor():
		if _anim_t > 0.13:
			_anim_t = 0.0
			_walk = 1 - _walk
		_set_pose(1 + _walk)
	else:
		_set_pose(0)


func _set_pose(p: int) -> void:
	if _sprite.texture != _tex[p]:
		_sprite.texture = _tex[p]


func _on_touch_player(body: Node2D) -> void:
	if not alive or _attack_cd > 0.0:
		return
	if body and body.has_method("take_damage"):
		body.take_damage(damage, self)
		_attack_cd = 0.7


func take_damage(amount: int, from: Node = null) -> void:
	if not alive:
		return
	hp -= amount
	_sprite.modulate = Color(1, 0.4, 0.4)
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE
	)
	if from and from is Node2D:
		var push := global_position.x - (from as Node2D).global_position.x
		velocity.x = 200.0 * signf(push if push != 0.0 else 1.0)
		velocity.y = -160.0
	if hp <= 0:
		alive = false
		died.emit(global_position)
		queue_free()
