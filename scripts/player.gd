extends CharacterBody3D
## Игрок (от первого лица): выживание в пустоши, ходьба по рельефу.

const SPEED := 6.0
const CROUCH_SPEED := 2.5
const JUMP_V := 5.2
const GRAV := 14.0
const ATTACK_RANGE := 2.6
const ATTACK_DMG := 30.0
const ATTACK_CD := 0.62      # пауза между ударами (без спама)
const SWING_TIME := 0.42     # полная длительность взмаха
const SWING_HIT_AT := 0.42   # доля взмаха, на которой наносится урон (момент контакта)
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
var _swing_hit := false      # урон в этом взмахе уже нанесён
var _recoil := 0.0           # отдача камеры после контакта
var _hit_shake := 0.0        # тряска при попадании
var _base_cam := Vector3(0, EYE_HEIGHT, 0)
var _crouching := false
var _target_eye := EYE_HEIGHT
var _hud_ref: CanvasLayer = null
var _tool: Node3D = null
var _tool_key := ""
var _tool_home := Vector3(0.42, -0.42, -0.55)

signal died


func _ready() -> void:
	add_to_group("player")
	add_to_group("local_player")
	collision_layer = 2
	collision_mask = 1
	# форма столкновения игрока — без неё он проходил сквозь постройки
	var _cs := CollisionShape3D.new()
	var _cap := CapsuleShape3D.new()
	_cap.radius = 0.35
	_cap.height = 1.7
	_cs.shape = _cap
	_cs.position = Vector3(0, 0.85, 0)
	add_child(_cs)
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
	if _tool:
		_tool.queue_free()
	_tool = Node3D.new()
	_tool_home = Vector3(0.42, -0.42, -0.55)      # точка покоя «кисти» (внизу справа камеры)
	_tool.position = _tool_home
	_cam.add_child(_tool)
	var key := ""
	if GameState.selected_slot >= 0 and GameState.selected_slot < GameState.hotbar.size():
		key = GameState.hotbar[GameState.selected_slot]
	_tool_key = key
	match key:
		"hatchet":
			# топор: рукоять + лезвие (лезвие вперёд-вверх)
			var handle := _box(Vector3(0.06, 0.6, 0.06), Color(0.42, 0.3, 0.16))
			handle.position = Vector3(0, 0.05, 0)
			handle.rotation_degrees = Vector3(-20, 0, 0)
			_tool.add_child(handle)
			var head := _box(Vector3(0.3, 0.09, 0.14), Color(0.6, 0.6, 0.65))
			head.position = Vector3(0, 0.4, 0)
			head.rotation_degrees = Vector3(-20, 0, 0)
			_tool.add_child(head)
		"pickaxe":
			var handle := _box(Vector3(0.06, 0.6, 0.06), Color(0.42, 0.3, 0.16))
			handle.position = Vector3(0, 0.05, 0)
			handle.rotation_degrees = Vector3(-20, 0, 0)
			_tool.add_child(handle)
			var head := _box(Vector3(0.32, 0.08, 0.08), Color(0.55, 0.55, 0.6))
			head.position = Vector3(0, 0.4, 0)
			head.rotation_degrees = Vector3(-20, 0, 0)
			_tool.add_child(head)
		"spear":
			# копьё: длинное древко + наконечник
			var shaft := _box(Vector3(0.05, 1.0, 0.05), Color(0.45, 0.32, 0.18))
			shaft.position = Vector3(0, 0.25, 0)
			shaft.rotation_degrees = Vector3(-25, 0, 0)
			_tool.add_child(shaft)
			var tip := _box(Vector3(0.1, 0.2, 0.08), Color(0.7, 0.7, 0.75))
			tip.position = Vector3(0, 0.85, 0)
			tip.rotation_degrees = Vector3(-25, 0, 0)
			_tool.add_child(tip)
		"bow":
			# лук: дуга + тетива (упрощённо)
			var limb := _box(Vector3(0.06, 0.8, 0.06), Color(0.5, 0.36, 0.2))
			limb.position = Vector3(0, 0.1, 0)
			limb.rotation_degrees = Vector3(0, 0, 20)
			_tool.add_child(limb)
		_:
			# камень по умолчанию
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


func _update_tool() -> void:
	# перестроить инструмент, если сменился выбранный слот
	var key := ""
	if GameState.selected_slot >= 0 and GameState.selected_slot < GameState.hotbar.size():
		key = GameState.hotbar[GameState.selected_slot]
	if key != _tool_key:
		_build_tool()


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
			GameState.last_yaw = rotation.y
			GameState.last_pos = global_position
			GameState.return_to_pos = true
			get_tree().change_scene_to_file("res://scenes/Inventory.tscn")
		elif event.keycode == KEY_M:
			GameState.last_yaw = rotation.y
			GameState.last_pos = global_position
			GameState.return_to_pos = true
			get_tree().change_scene_to_file("res://scenes/Map.tscn")
		elif event.keycode == KEY_R and GameState.build_mode:
			GameState.build_rot += PI / 4.0  # поворот постройки на 45°
		elif event.keycode == KEY_ESCAPE and GameState.build_mode:
			GameState.build_mode = false
		elif event.keycode == KEY_E:
			_interact()  # открыть ящик с лутом
	elif event is InputEventMouseButton and event.pressed:
		if GameState.build_mode:
			# в режиме строительства колесо поворачивает постройку (как в Rust)
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				GameState.build_rot += PI / 4.0
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				GameState.build_rot -= PI / 4.0
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				GameState.build_mode = false  # отмена строительства
		else:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				GameState.selected_slot = (GameState.selected_slot - 1 + 6) % 6
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				GameState.selected_slot = (GameState.selected_slot + 1) % 6


func _ground_height() -> float:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_surface_height"):
		return terrain._surface_height(global_position.x, global_position.z)
	if terrain and terrain.has_method("_ground_height"):
		return terrain._ground_height(global_position.x, global_position.z)
	return 0.0


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	# ход взмаха и момент контакта (урон строго синхронизирован с анимацией)
	if _swing_t > 0.0:
		_swing_t = maxf(0.0, _swing_t - delta)
		if not _swing_hit and (1.0 - _swing_t / SWING_TIME) >= SWING_HIT_AT:
			_apply_hit()
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	_update_tool()

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

	# горизонтальное движение — через физику, чтобы упираться в постройки
	var before_xz := Vector2(global_position.x, global_position.z)
	velocity.x = wish.x * spd
	velocity.z = wish.z * spd
	velocity.y = 0.0
	move_and_slide()
	global_position.x = clampf(global_position.x, -500.0, 500.0)
	global_position.z = clampf(global_position.z, -500.0, 500.0)

	# не пускаем в глубокую воду (берег — граница острова)
	var water_h := _ground_height()
	if water_h < -2.0:
		global_position.x = before_xz.x
		global_position.z = before_xz.y

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
			var placed: bool = terrain._place_building(GameState.build_kind, global_position, fwd, GameState.build_rot)
			# режим строительства НЕ выключаем — можно ставить подряд (как в Rust)
			if _hud_ref:
				if placed:
					_hud_ref.refresh()
				elif _hud_ref.has_method("toast"):
					_hud_ref.toast("Здесь нельзя поставить")
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

	# взаимодействие с ящиками (кнопка «ВЗЯТЬ» на телефоне)
	if has_meta("mob_interact") and bool(get_meta("mob_interact")):
		set_meta("mob_interact", false)
		_interact()
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

	# --- анимация удара: замах, резкий рывок вперёд, плавный возврат ---
	if _swing_t > 0.0:
		# p: 0 в начале взмаха -> 1 в конце
		var p: float = clampf(1.0 - _swing_t / SWING_TIME, 0.0, 1.0)
		var swing_x := 0.0    # наклон инструмента (замах/удар)
		var push_z := 0.0     # движение вперёд
		var drop_y := 0.0     # опускание руки
		var roll := 0.0       # доворот кисти
		if p < 0.38:
			# ФАЗА 1 — замах назад-вверх, с разгоном (ease-in)
			var a: float = p / 0.38
			var e: float = a * a
			swing_x = e * 0.95
			push_z = e * 0.16
			drop_y = -e * 0.05
			roll = e * 0.28
		elif p < 0.62:
			# ФАЗА 2 — резкий удар вперёд-вниз (быстрая, мощная)
			var a2: float = (p - 0.38) / 0.24
			var e2: float = 1.0 - pow(1.0 - a2, 3.0)   # ease-out, резкий старт
			swing_x = lerpf(0.95, -1.35, e2)
			push_z = lerpf(0.16, -0.30, e2)
			drop_y = lerpf(-0.05, 0.12, e2)
			roll = lerpf(0.28, -0.22, e2)
		else:
			# ФАЗА 3 — плавный возврат в исходное
			var a3: float = (p - 0.62) / 0.38
			var e3: float = a3 * a3 * (3.0 - 2.0 * a3)  # smoothstep
			swing_x = lerpf(-1.35, 0.0, e3)
			push_z = lerpf(-0.30, 0.0, e3)
			drop_y = lerpf(0.12, 0.0, e3)
			roll = lerpf(-0.22, 0.0, e3)
		if _tool:
			_tool.rotation.x = swing_x
			_tool.rotation.z = roll
			# лёгкое покачивание кисти во время взмаха
			_tool.position = _tool_home + Vector3(
				sin(p * PI * 2.0) * 0.03,
				drop_y * 0.5,
				push_z)
		# камера слегка реагирует: подсядь на замахе, толчок на ударе
		var cam_dip: float = -drop_y * 0.35 + _recoil * 0.6
		_cam.position = _base_cam + Vector3(0, -cam_dip, 0)
		_cam.rotation.z = roll * 0.10 + _hit_shake * 0.5
	else:
		if _tool:
			# мягко возвращаем инструмент на место
			_tool.rotation.x = lerpf(_tool.rotation.x, 0.0, delta * 14.0)
			_tool.rotation.z = lerpf(_tool.rotation.z, 0.0, delta * 14.0)
			_tool.position = _tool.position.lerp(_tool_home, delta * 14.0)
		_cam.position = _base_cam + Vector3(0, -_recoil * 0.6, 0)
		_cam.rotation.z = _hit_shake * 0.5

	# затухание отдачи и тряски от попадания
	_recoil = lerpf(_recoil, 0.0, delta * 9.0)
	_hit_shake = lerpf(_hit_shake, 0.0, delta * 11.0)


func _attack() -> void:
	# запускаем взмах; урон наносится в момент контакта (_apply_hit)
	if _swing_t > 0.0:
		return
	_attack_cd = ATTACK_CD
	_swing_t = SWING_TIME
	_swing_hit = false


## Момент контакта: вызывается из _physics_process в середине взмаха
func _apply_hit() -> void:
	_swing_hit = true
	var fwd := -_cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var connected := false
	# сначала — добыча ресурса впереди
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_harvest"):
		var res: String = terrain._harvest(global_position, fwd)
		if res != "":
			connected = true
	# затем — урон врагам
	if not connected:
		var dmg := GameState.attack_damage()
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Node3D
			if not is_instance_valid(en):
				continue
			var to := en.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d <= ATTACK_RANGE and d > 0.01 and fwd.dot(to.normalized()) > 0.4:
				if en.has_method("take_damage"):
					en.take_damage(dmg)
					connected = true
	# отдача: по воздуху — слабая, по цели — ощутимый толчок и тряска
	if connected:
		_recoil = 0.075
		_hit_shake = 0.055
	else:
		_recoil = 0.03
		_hit_shake = 0.012


func _interact() -> void:
	# открыть ближайший ящик с лутом
	var terrain := get_tree().get_first_node_in_group("terrain")
	if not terrain or not terrain.has_method("_interact_lootbox"):
		return
	var fwd := -_cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var text: String = terrain._interact_lootbox(global_position, fwd)
	if text != "" and _hud_ref and _hud_ref.has_method("toast"):
		_hud_ref.toast(text)


func take_damage(amount: float, from: Node = null) -> void:
	if _hurt_cd > 0.0:
		return
	GameState.hp = maxf(0.0, GameState.hp - amount)
	_hurt_cd = 0.5
	if GameState.hp <= 0.0:
		died.emit()
