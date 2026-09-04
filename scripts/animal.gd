extends CharacterBody3D
## Животное: курица (убегает), олень (убегает), кабан (нейтральный), медведь (агрессивный).

const GRAV := 14.0

# тип: 0=курица, 1=олень, 2=кабан, 3=медведь
var kind := 0
var hp := 30.0
var max_hp := 30.0
var speed := 3.0
var contact_dmg := 0.0
var aggressive := false
var _player: Node3D
var _hit_cd := 0.0
var _model: Node3D
var _wander_t := 0.0
var _wander_dir := Vector3.ZERO

signal died(kind: int)


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	_player = get_tree().get_first_node_in_group("player")


func setup(k: int) -> void:
	kind = k
	match kind:
		0:  # курица — маленькая, убегает
			max_hp = 15.0
			speed = 4.5
			contact_dmg = 0.0
			aggressive = false
		1:  # олень — быстрый, убегает
			max_hp = 50.0
			speed = 6.0
			contact_dmg = 0.0
			aggressive = false
		2:  # кабан — нейтральный, атакует если близко
			max_hp = 60.0
			speed = 3.5
			contact_dmg = 12.0
			aggressive = false
		3:  # медведь — агрессивный
			max_hp = 90.0
			speed = 4.0
			contact_dmg = 20.0
			aggressive = true
	hp = max_hp
	_build()  # строим модель ПОСЛЕ установки kind (фикс бага «все курицы»)


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _sphere(r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _cyl(r: float, h: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _build() -> void:
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.5
	cs.height = 1.2
	col.shape = cs
	col.position = Vector3(0, 0.6, 0)
	add_child(col)

	match kind:
		0:  # курица — ~0.7 м
			_model = preload("res://models/chicken.glb").instantiate()
			_model.scale = Vector3.ONE * 2.3
			_model.position = Vector3(0, 0.05, 0)
			add_child(_model)
		1:  # олень — ~1.6 м
			_model = preload("res://models/deer.glb").instantiate()
			_model.scale = Vector3.ONE * 0.95
			_model.position = Vector3(0, -0.1, 0)
			add_child(_model)
		2:
			_build_boar()
		3:
			_build_bear()


func _build_bear() -> void:
	# скачанная модель медведя (с автоподгонкой по габаритам)
	_model = preload("res://models/bear.glb").instantiate()
	add_child(_model)
	_fit_model(_model, 3.5)  # крупный медведь


func _fit_model(m: Node3D, target_height: float) -> void:
	# измерить глобальные габариты и подогнать: масштаб под высоту, центровка, на землю
	await get_tree().process_frame
	await get_tree().process_frame
	var origin := m.global_position
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for mesh in m.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mesh.mesh.get_aabb()
		var t: Transform3D = mesh.global_transform
		for i in range(8):
			var p: Vector3 = aabb.position + Vector3(
				aabb.size.x if (i & 1) != 0 else 0.0,
				aabb.size.y if (i & 2) != 0 else 0.0,
				aabb.size.z if (i & 4) != 0 else 0.0)
			p = t * p
			mn = mn.min(p)
			mx = mx.max(p)
	var h := mx.y - mn.y
	if h > 0.001:
		var s := target_height / h
		var center := (mn + mx) * 0.5
		m.scale = Vector3.ONE * s
		# после масштабирования вокруг origin центр станет origin + (center-origin)*s
		var desired := origin + Vector3(0, target_height * 0.5, 0)
		m.position = desired - (origin + (center - origin) * s)


func _build_boar() -> void:
	# дикий кабан (~1.1 м в холке): коренастый, горбатая спина, длинное рыло, клыки
	var body := Color(0.33, 0.2, 0.13)
	var dark := Color(0.2, 0.11, 0.08)
	var snout_c := Color(0.44, 0.29, 0.2)
	var ivory := Color(0.95, 0.92, 0.8)

	# туловище + горб (холка спереди выше зада)
	_box(Vector3(1.05, 0.8, 1.75), Vector3(0, 0.6, -0.05), body)
	_sphere(0.55, Vector3(0, 0.95, -0.5), body)   # холка
	_sphere(0.45, Vector3(0, 0.68, 0.7), body)    # круп
	# щетина-гребень вдоль спины
	_box(Vector3(0.16, 0.3, 1.6), Vector3(0, 1.2, 0.0), dark)

	# голова крупная, вытянутая вперёд (рыло вперёд, по ходу движения)
	_sphere(0.45, Vector3(0, 0.9, -1.05), body)
	_box(Vector3(0.42, 0.34, 0.5), Vector3(0, 0.82, -1.45), snout_c)  # рыло
	_sphere(0.14, Vector3(0, 0.78, -1.72), Color(0.5, 0.32, 0.28))    # пятачок
	# уши
	_sphere(0.14, Vector3(-0.32, 1.25, -0.95), dark)
	_sphere(0.14, Vector3(0.32, 1.25, -0.95), dark)
	# клыки (загнутые вверх)
	_box(Vector3(0.08, 0.26, 0.1), Vector3(-0.16, 0.6, -1.5), ivory)
	_box(Vector3(0.08, 0.26, 0.1), Vector3(0.16, 0.6, -1.5), ivory)

	# короткие крепкие ноги
	_box(Vector3(0.3, 0.5, 0.3), Vector3(-0.4, 0.25, -0.5), dark)
	_box(Vector3(0.3, 0.5, 0.3), Vector3(0.4, 0.25, -0.5), dark)
	_box(Vector3(0.3, 0.5, 0.3), Vector3(-0.4, 0.25, 0.6), dark)
	_box(Vector3(0.3, 0.5, 0.3), Vector3(0.4, 0.25, 0.6), dark)
	# хвостик
	_box(Vector3(0.1, 0.1, 0.3), Vector3(0, 0.95, 0.85), dark)


func _ground_height() -> float:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain and terrain.has_method("_surface_height"):
		return terrain._surface_height(global_position.x, global_position.z)
	if terrain and terrain.has_method("_ground_height"):
		return terrain._ground_height(global_position.x, global_position.z)
	return 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return

	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()

	var dir := Vector3.ZERO
	if aggressive:
		# медведь — преследует
		dir = to.normalized() if dist > 0.05 else Vector3.ZERO
	elif dist < 7.0:
		# курица/олень/кабан — убегают от игрока
		dir = -to.normalized() if dist > 0.05 else Vector3.ZERO
	else:
		# блуждание
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 5.0)
			_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		dir = _wander_dir

	# горизонтальное движение
	global_position.x += dir.x * speed * delta
	global_position.z += dir.z * speed * delta
	global_position.x = clampf(global_position.x, -500.0, 500.0)
	global_position.z = clampf(global_position.z, -500.0, 500.0)

	# прилипание к рельефу
	global_position.y = _ground_height()

	if dist > 0.05 and dir.length() > 0.05:
		look_at(global_position + dir, Vector3.UP)

	# контактный урон (только кабан вблизи, медведь всегда)
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if contact_dmg > 0.0 and dist < 1.6 and _hit_cd <= 0.0:
		_player.take_damage(contact_dmg)
		_hit_cd = 1.0


func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		died.emit(kind)
		queue_free()
