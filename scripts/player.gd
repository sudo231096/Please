extends CharacterBody2D

const PixelArt = preload("res://scripts/pixel.gd")
## 2D human like Terraria.

const SPEED := 210.0
const JUMP_V := -390.0
const GRAV := 1100.0
const ATTACK_TIME := 0.22

var max_hp := 100
var hp := 100
var damage := 34
var shield := 0
var alive := true
var facing := 1
var _attack_t := 0.0
var _invuln := 0.0
var _sprite: Sprite2D
var _tex := {}
var _attack_box: Area2D
var _attack_shape: CollisionShape2D
var _jump_held := false
var _anim_t := 0.0
var _walk := 0

signal died
signal hp_changed(hp: int, max_hp: int)
signal attacked


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	# баффы от скинов и прокачки
	max_hp = Progress.player_max_hp()
	hp = max_hp
	damage = Progress.player_damage()
	shield = Progress.shield_hits()
	_build()


func _build() -> void:
	var col := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = Vector2(14, 22)
	col.shape = cs
	col.position = Vector2(0, -11)
	add_child(col)

	_tex[0] = PixelArt.player_tex(0)
	_tex[1] = PixelArt.player_tex(1)
	_tex[2] = PixelArt.player_tex(2)
	_tex[3] = PixelArt.player_tex(3)

	_sprite = Sprite2D.new()
	_sprite.texture = _tex[0]
	_sprite.centered = true
	_sprite.position = Vector2(0, -12)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2, 2)
	add_child(_sprite)

	_attack_box = Area2D.new()
	_attack_box.collision_layer = 8
	_attack_box.collision_mask = 4
	_attack_box.monitoring = false
	_attack_box.monitorable = false
	add_child(_attack_box)
	_attack_shape = CollisionShape2D.new()
	var ash := RectangleShape2D.new()
	ash.size = Vector2(22, 16)
	_attack_shape.shape = ash
	_attack_shape.position = Vector2(16, -12)
	_attack_box.add_child(_attack_shape)
	_attack_box.body_entered.connect(_on_hit_enemy)

	# меч (визуал)
	var sword := ColorRect.new()
	sword.name = "SwordVis"
	sword.size = Vector2(18, 4)
	sword.position = Vector2(8, -16)
	sword.color = Color(0.75, 0.75, 0.8)
	sword.visible = false
	add_child(sword)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _invuln > 0.0:
		_invuln -= delta
		_sprite.modulate.a = 0.45 if fmod(_invuln * 20.0, 2.0) < 1.0 else 1.0
	else:
		_sprite.modulate.a = 1.0

	if not is_on_floor():
		velocity.y += GRAV * delta
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	var dir := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir += 1.0
	if has_meta("mob_left") and bool(get_meta("mob_left")):
		dir -= 1.0
	if has_meta("mob_right") and bool(get_meta("mob_right")):
		dir += 1.0

	velocity.x = dir * SPEED
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
		_sprite.flip_h = facing < 0
		_attack_shape.position.x = 16.0 * facing
		var sv = get_node_or_null("SwordVis")
		if sv:
			sv.position.x = (8 if facing > 0 else -26)

	# анимация
	_update_animation(delta)

	var jump_down := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_action_pressed("ui_accept")
	var jump_pressed := jump_down and not _jump_held
	_jump_held = jump_down
	if has_meta("mob_jump") and bool(get_meta("mob_jump")):
		jump_pressed = true
		set_meta("mob_jump", false)
	if jump_pressed and is_on_floor():
		velocity.y = JUMP_V

	var attack_pressed := Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_K) or Input.is_physical_key_pressed(KEY_ENTER) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if has_meta("mob_attack") and bool(get_meta("mob_attack")):
		attack_pressed = true
		set_meta("mob_attack", false)
	if attack_pressed and _attack_t <= 0.0:
		_start_attack()

	if _attack_t > 0.0:
		_attack_t -= delta
		if _attack_t <= 0.0:
			_attack_box.monitoring = false
			var sv2 = get_node_or_null("SwordVis")
			if sv2:
				sv2.visible = false

	move_and_slide()


func _update_animation(delta: float) -> void:
	_anim_t += delta
	if _attack_t > 0.0:
		_set_pose(3)
		return
	if absf(velocity.x) > 10.0 and is_on_floor():
		if _anim_t > 0.12:
			_anim_t = 0.0
			_walk = 1 - _walk
		_set_pose(1 + _walk)
	else:
		_set_pose(0)


func _set_pose(p: int) -> void:
	if _sprite.texture != _tex[p]:
		_sprite.texture = _tex[p]


func _start_attack() -> void:
	_attack_t = ATTACK_TIME
	_attack_box.monitoring = true
	var sv = get_node_or_null("SwordVis")
	if sv:
		sv.visible = true
	attacked.emit()


func _on_hit_enemy(body: Node2D) -> void:
	if body and body.has_method("take_damage"):
		body.take_damage(damage, self)


func take_damage(amount: int, from: Node = null) -> void:
	if not alive or _invuln > 0.0:
		return
	# щит (скин 1) поглощает удар
	if shield > 0:
		shield -= 1
		_invuln = 0.5
		_sprite.modulate = Color(0.5, 0.8, 1.0)
		get_tree().create_timer(0.15).timeout.connect(func() -> void:
			if is_instance_valid(_sprite):
				_sprite.modulate = Color.WHITE
		)
		hp_changed.emit(hp, max_hp)
		return
	hp = maxi(0, hp - amount)
	_invuln = 0.8
	hp_changed.emit(hp, max_hp)
	if from and from is Node2D:
		var push := global_position.x - (from as Node2D).global_position.x
		velocity.x = 220.0 * signf(push if push != 0.0 else 1.0)
		velocity.y = -180.0
	if hp <= 0:
		alive = false
		died.emit()


func heal_full() -> void:
	hp = max_hp
	alive = true
	_invuln = 0.0
	hp_changed.emit(hp, max_hp)
