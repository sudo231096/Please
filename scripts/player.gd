extends CharacterBody3D
## Игрок (от первого лица): выживание в пустоши, камень/топор.

const SPEED := 6.0
const JUMP_V := 5.2
const GRAV := 14.0
const MOUSE_SENS := 0.0025
const ATTACK_RANGE := 2.6
const ATTACK_DMG := 30.0
const ATTACK_CD := 0.55

var _cam: Camera3D
var _attack_cd := 0.0
var _hurt_cd := 0.0

signal died


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.7, 0)
	_cam.current = true
	add_child(_cam)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.4
	cs.height = 1.7
	col.shape = cs
	col.position = Vector3(0, 0.85, 0)
	add_child(col)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_cam.rotate_x(-event.relative.y * MOUSE_SENS)
		_cam.rotation.x = clampf(_cam.rotation.x, -1.45, 1.45)
	elif event is InputEventScreenDrag:
		var vp := get_viewport().get_visible_rect().size
		if event.position.x > vp.x * 0.5:
			rotate_y(-event.relative.x * MOUSE_SENS * 2.2)
			_cam.rotate_x(-event.relative.y * MOUSE_SENS * 2.2)
			_cam.rotation.x = clampf(_cam.rotation.x, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hurt_cd = maxf(0.0, _hurt_cd - delta)

	# выживание: голод/жажда тикают
	GameState.tick(delta)
	if GameState.hp <= 0.0:
		died.emit()
		return

	if not is_on_floor():
		velocity.y -= GRAV * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	var mv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		mv.x += 1.0
	if has_meta("mob_dir"):
		mv += get_meta("mob_dir")
	if mv.length() > 1.0:
		mv = mv.normalized()

	var wish := global_transform.basis * Vector3(mv.x, 0, mv.y)
	wish.y = 0.0
	if wish.length() > 0.01:
		wish = wish.normalized()
	velocity.x = wish.x * SPEED
	velocity.z = wish.z * SPEED

	var jump := Input.is_physical_key_pressed(KEY_SPACE)
	if has_meta("mob_jump") and bool(get_meta("mob_jump")):
		jump = true
		set_meta("mob_jump", false)
	if jump and is_on_floor():
		velocity.y = JUMP_V

	var attack := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J)
	if has_meta("mob_attack") and bool(get_meta("mob_attack")):
		attack = true
		set_meta("mob_attack", false)
	if attack and _attack_cd <= 0.0:
		_attack()

	# поесть (E)
	if Input.is_physical_key_pressed(KEY_E):
		GameState.eat()
	# попить (Q)
	if Input.is_physical_key_pressed(KEY_Q):
		GameState.drink()

	move_and_slide()


func _attack() -> void:
	_attack_cd = ATTACK_CD
	var fwd := -_cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var to := en.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d <= ATTACK_RANGE and d > 0.01:
			if fwd.dot(to.normalized()) > 0.4 and en.has_method("take_damage"):
				en.take_damage(ATTACK_DMG)


func take_damage(amount: float, from: Node = null) -> void:
	if _hurt_cd > 0.0:
		return
	GameState.hp = maxf(0.0, GameState.hp - amount)
	_hurt_cd = 0.5
	if GameState.hp <= 0.0:
		died.emit()
