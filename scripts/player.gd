extends CharacterBody3D
## Игрок (от первого лица): выживание в пустоши, ходьба по рельефу.

const SPEED := 6.0
const JUMP_V := 5.2
const GRAV := 14.0
const ATTACK_RANGE := 2.6
const ATTACK_DMG := 30.0
const ATTACK_CD := 0.55
const EYE_HEIGHT := 1.7
const FEET := 0.85  # смещение от центра до подошв

var _cam: Camera3D
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _vy := 0.0
var _grounded := true

signal died


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_cam = Camera3D.new()
	_cam.position = Vector3(0, EYE_HEIGHT, 0)
	_cam.current = true
	add_child(_cam)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * GameState.mouse_sens)
		_cam.rotate_x(-event.relative.y * GameState.mouse_sens)
		_cam.rotation.x = clampf(_cam.rotation.x, -1.45, 1.45)
	elif event is InputEventScreenDrag:
		var vp := get_viewport().get_visible_rect().size
		if event.position.x > vp.x * 0.5:
			rotate_y(-event.relative.x * GameState.mouse_sens * 2.2)
			_cam.rotate_x(-event.relative.y * GameState.mouse_sens * 2.2)
			_cam.rotation.x = clampf(_cam.rotation.x, -1.45, 1.45)


func _ground_height() -> float:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_ground_height"):
		return terrain._ground_height(global_position.x, global_position.z)
	return 0.0


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hurt_cd = maxf(0.0, _hurt_cd - delta)

	GameState.tick(delta)
	if GameState.hp <= 0.0:
		died.emit()
		return

	# ввод движения
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

	# горизонтальное движение
	global_position.x += wish.x * SPEED * delta
	global_position.z += wish.z * SPEED * delta
	global_position.x = clampf(global_position.x, -500.0, 500.0)
	global_position.z = clampf(global_position.z, -500.0, 500.0)

	# прыжок
	var jump := Input.is_physical_key_pressed(KEY_SPACE)
	if has_meta("mob_jump") and bool(get_meta("mob_jump")):
		jump = true
		set_meta("mob_jump", false)
	if jump and _grounded:
		_vy = JUMP_V
		_grounded = false

	# вертикаль: гравитация + прилипание к рельефу
	_vy -= GRAV * delta
	global_position.y += _vy * delta
	var gh := _ground_height()
	if _vy <= 0.0 and (global_position.y - FEET) <= gh:
		global_position.y = gh + FEET
		_vy = 0.0
		_grounded = true

	# удар
	var attack := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J)
	if has_meta("mob_attack") and bool(get_meta("mob_attack")):
		attack = true
		set_meta("mob_attack", false)
	if attack and _attack_cd <= 0.0:
		_attack()

	if Input.is_physical_key_pressed(KEY_E):
		GameState.eat()
	if Input.is_physical_key_pressed(KEY_Q):
		GameState.drink()


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
