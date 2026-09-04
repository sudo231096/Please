extends CharacterBody3D
## Игрок (от первого лица): выживание в пустоши, ходьба по рельефу.

const SPEED := 6.0
const CROUCH_SPEED := 2.5
const JUMP_V := 5.2
const GRAV := 14.0
const ATTACK_RANGE := 2.6
const ATTACK_DMG := 30.0
const ATTACK_CD := 0.55
const EYE_HEIGHT := 1.7
const CROUCH_EYE := 1.0
const FEET := 0.85  # смещение от центра до подошв

var _cam: Camera3D
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _vy := 0.0
var _grounded := true
var _bob_t := 0.0
var _swing_t := 0.0
var _base_cam := Vector3(0, EYE_HEIGHT, 0)
var _crouching := false
var _target_eye := EYE_HEIGHT
var _hud_ref: CanvasLayer = null
var _tool: Node3D = null

signal died


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	_cam = Camera3D.new()
	_cam.position = Vector3(0, EYE_HEIGHT, 0)
	_cam.current = true
	add_child(_cam)
	_build_tool()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	return m


func _build_tool() -> void:
	_tool = Node3D.new()
	_tool.position = Vector3(0.45, -0.4, -0.6)  # внизу справа от камеры
	_cam.add_child(_tool)
	if GameState.has_hatchet:
		# топор: рукоять + лезвие
		var handle := _box(Vector3(0.06, 0.6, 0.06), Color(0.42, 0.3, 0.16))
		handle.position = Vector3(0, 0.1, 0)
		_tool.add_child(handle)
		var head := _box(Vector3(0.28, 0.08, 0.12), Color(0.6, 0.6, 0.65))
		head.position = Vector3(0, 0.4, 0)
		_tool.add_child(head)
	elif GameState.has_pickaxe:
		var handle := _box(Vector3(0.06, 0.6, 0.06), Color(0.42, 0.3, 0.16))
		handle.position = Vector3(0, 0.1, 0)
		_tool.add_child(handle)
		var head := _box(Vector3(0.3, 0.08, 0.08), Color(0.55, 0.55, 0.6))
		head.position = Vector3(0, 0.4, 0)
		_tool.add_child(head)
	else:
		# камень
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.12
		sm.height = 0.2
		stone.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.55)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stone.material_override = mat
		_tool.add_child(stone)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# в режиме строительства колесо поворачивает постройку
		if GameState.build_mode and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			pass
		rotate_y(-event.relative.x * GameState.mouse_sens)
		_cam.rotate_x(-event.relative.y * GameState.mouse_sens)
		_cam.rotation.x = clampf(_cam.rotation.x, -1.45, 1.45)
	elif event is InputEventScreenDrag:
		var vp := get_viewport().get_visible_rect().size
		if event.position.x > vp.x * 0.5:
			rotate_y(-event.relative.x * GameState.mouse_sens * 2.2)
			_cam.rotate_x(-event.relative.y * GameState.mouse_sens * 2.2)
			_cam.rotation.x = clampf(_cam.rotation.x, -1.45, 1.45)
	# выбор слота hotbar: цифры 1-6 и колесо мыши
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			GameState.selected_slot = event.keycode - KEY_1
		elif event.keycode == KEY_TAB:
			GameState.last_pos = global_position
			GameState.return_to_pos = true
			get_tree().change_scene_to_file("res://scenes/Inventory.tscn")
		elif event.keycode == KEY_M:
			GameState.last_pos = global_position
			GameState.return_to_pos = true
			get_tree().change_scene_to_file("res://scenes/Map.tscn")
		elif event.keycode == KEY_R and GameState.build_mode:
			GameState.build_rot += PI / 2.0  # поворот постройки на 90°
		elif event.keycode == KEY_ESCAPE and GameState.build_mode:
			GameState.build_mode = false
	elif event is InputEventMouseButton and event.pressed:
		if GameState.build_mode:
			# в режиме строительства колесо поворачивает постройку (как в Rust)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				GameState.build_rot += PI / 2.0
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				GameState.build_rot -= PI / 2.0
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				GameState.build_mode = false  # отмена строительства
		else:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				GameState.selected_slot = (GameState.selected_slot - 1 + 6) % 6
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				GameState.selected_slot = (GameState.selected_slot + 1) % 6


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

	# присест: клавиша Ctrl или кнопка на телефоне
	var crouch := Input.is_physical_key_pressed(KEY_CTRL)
	if has_meta("mob_crouch") and bool(get_meta("mob_crouch")):
		crouch = true
	if crouch:
		if not _crouching:
			_crouching = true
			_target_eye = CROUCH_EYE
	else:
		if _crouching:
			_crouching = false
			_target_eye = EYE_HEIGHT

	# скорость: при приседе медленнее; базовая — с учётом прокачки
	var spd := CROUCH_SPEED if _crouching else SPEED

	# горизонтальное движение
	global_position.x += wish.x * spd * delta
	global_position.z += wish.z * spd * delta
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

	# режим строительства: ЛКМ ставит постройку
	if GameState.build_mode:
		var terrain := get_tree().get_first_node_in_group("terrain")
		var place := false
		if not DisplayServer.is_touchscreen_available():
			place = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if has_meta("mob_attack") and bool(get_meta("mob_attack")):
			place = true
			set_meta("mob_attack", false)
		if place and terrain and terrain.has_method("_place_building"):
			var fwd := -_cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			terrain._place_building(GameState.build_kind, global_position, fwd, GameState.build_rot)
			GameState.build_mode = false
			if _hud_ref:
				_hud_ref.refresh()
		# призрак обновляется в main
	else:
		# удар: на десктопе — ЛКМ или J; на телефоне — только кнопка «УДАР» (тап по экрану НЕ атакует)
		var attack := false
		if not DisplayServer.is_touchscreen_available():
			attack = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J)
		if has_meta("mob_attack") and bool(get_meta("mob_attack")):
			attack = true
			set_meta("mob_attack", false)
		if attack and _attack_cd <= 0.0:
			_attack()

	if Input.is_physical_key_pressed(KEY_E):
		GameState.eat()
	if Input.is_physical_key_pressed(KEY_Q):
		GameState.drink()

	_animate_cam(delta, wish.length())


func _animate_cam(delta: float, moving: float) -> void:
	# плавное изменение высоты глаз (присед)
	var eye := _target_eye
	if moving > 0.1 and _grounded:
		_bob_t += delta * 10.0
		var bob_y := sin(_bob_t) * 0.05 * moving
		var bob_x := cos(_bob_t * 0.5) * 0.03 * moving
		_base_cam = Vector3(bob_x, eye + bob_y, 0)
	else:
		_bob_t = 0.0
		_base_cam = _base_cam.lerp(Vector3(0, eye, 0), delta * 12.0)

	# анимация удара — замах камеры + инструмента
	if _swing_t > 0.0:
		_swing_t -= delta
		var k := _swing_t / 0.28  # 1 -> 0
		var dip := sin(k * PI) * 0.12
		_cam.position = _base_cam + Vector3(0, -dip, 0)
		_cam.rotation.z = sin(k * PI) * 0.06
		if _tool:
			_tool.rotation.x = -sin(k * PI) * 1.2  # замах инструмента
	else:
		_cam.position = _base_cam
		_cam.rotation.z = 0.0
		if _tool:
			_tool.rotation.x = 0.0


func _attack() -> void:
	_attack_cd = ATTACK_CD
	_swing_t = 0.28  # замах
	var fwd := -_cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	# сначала — добыча (дерево/камень/руда впереди)
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_harvest"):
		var res: String = terrain._harvest(global_position, fwd)
		if res != "":
			return  # попали по ресурсу — не бьём зверей
	# затем — урон зверям
	var dmg := GameState.attack_damage()
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var to := en.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d <= ATTACK_RANGE and d > 0.01:
			if fwd.dot(to.normalized()) > 0.4 and en.has_method("take_damage"):
				en.take_damage(dmg)


func take_damage(amount: float, from: Node = null) -> void:
	if _hurt_cd > 0.0:
		return
	GameState.hp = maxf(0.0, GameState.hp - amount)
	_hurt_cd = 0.5
	if GameState.hp <= 0.0:
		died.emit()
