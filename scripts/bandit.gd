extends CharacterBody3D
## NPC-бандит: патрулирует зону, замечает игрока, стреляет, роняет лут.
## Сложность зависит от опасности зоны (tier 0..2).

const GRAV := 16.0

signal died(tier: int)

var tier := 0                 # 0 = бродяга, 1 = наёмник, 2 = боец монумента
var hp := 60.0
var max_hp := 60.0
var speed := 3.4
var damage := 9.0
var sight := 42.0             # дальность обнаружения
var shoot_range := 26.0
var accuracy := 0.55

var _player: Node3D
var _model: Node3D
var _muzzle: MeshInstance3D
var _home := Vector3.ZERO
var _patrol := Vector3.ZERO
var _state := "patrol"        # patrol / chase / attack
var _cd := 0.0
var _repath := 0.0
var _vy := 0.0
var _flash := 0.0
var _hp_bar: Sprite3D


func _ready() -> void:
	add_to_group("bandits")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	_player = get_tree().get_first_node_in_group("player")
	_home = global_position
	_pick_patrol()


func setup(t: int) -> void:
	tier = clampi(t, 0, 2)
	match tier:
		0:
			max_hp = 55.0; speed = 3.2; damage = 8.0; sight = 36.0; accuracy = 0.45
		1:
			max_hp = 90.0; speed = 3.8; damage = 13.0; sight = 46.0; accuracy = 0.6
		2:
			max_hp = 140.0; speed = 4.2; damage = 18.0; sight = 56.0; accuracy = 0.72
	hp = max_hp
	_build()


func _build() -> void:
	for c in get_children():
		if c is Node3D and not (c is CollisionShape3D):
			c.queue_free()
	_model = Node3D.new()
	add_child(_model)

	var cloth := Color(0.32, 0.3, 0.24)
	var vest := Color(0.24, 0.26, 0.2)
	match tier:
		1:
			cloth = Color(0.26, 0.28, 0.22); vest = Color(0.18, 0.2, 0.16)
		2:
			cloth = Color(0.2, 0.21, 0.24); vest = Color(0.14, 0.15, 0.17)

	_box(Vector3(0.5, 0.65, 0.28), Vector3(0, 1.25, 0), cloth)      # торс
	_box(Vector3(0.54, 0.3, 0.32), Vector3(0, 1.35, 0), vest)       # разгрузка
	_sphere(0.16, Vector3(0, 1.72, 0), Color(0.78, 0.6, 0.46))      # голова
	_box(Vector3(0.36, 0.12, 0.36), Vector3(0, 1.83, 0), vest)      # шапка/каска
	_box(Vector3(0.14, 0.55, 0.14), Vector3(-0.32, 1.2, 0), cloth)  # руки
	_box(Vector3(0.14, 0.55, 0.14), Vector3(0.32, 1.2, 0), cloth)
	_box(Vector3(0.18, 0.8, 0.18), Vector3(-0.14, 0.45, 0), Color(0.2, 0.19, 0.16))  # ноги
	_box(Vector3(0.18, 0.8, 0.18), Vector3(0.14, 0.45, 0), Color(0.2, 0.19, 0.16))
	# оружие
	_box(Vector3(0.08, 0.1, 0.66), Vector3(0.3, 1.22, 0.34), Color(0.16, 0.15, 0.14))
	_muzzle = _box(Vector3(0.1, 0.1, 0.1), Vector3(0.3, 1.22, 0.7), Color(1.0, 0.75, 0.2), Color(1.0, 0.6, 0.1))
	_muzzle.visible = false

	# полоска здоровья над головой
	_hp_bar = Sprite3D.new()
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = false
	_hp_bar.pixel_size = 0.004
	_hp_bar.position = Vector3(0, 2.15, 0)
	_hp_bar.texture = _bar_texture(1.0)
	add_child(_hp_bar)


func _bar_texture(frac: float) -> ImageTexture:
	var w := 120
	var img := Image.create(w, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.06, 0.85))
	var fill := int(w * clampf(frac, 0.0, 1.0))
	var col := Color(0.85, 0.3, 0.25) if frac < 0.35 else Color(0.85, 0.55, 0.2) if frac < 0.7 else Color(0.4, 0.8, 0.35)
	for x in range(2, maxi(2, fill - 2)):
		for y in range(2, 12):
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _box(size: Vector3, pos: Vector3, color: Color, emis := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emis.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emis
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(m)
	return m


func _sphere(r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(m)
	return m


func _ground() -> float:
	var t := get_tree().get_first_node_in_group("terrain")
	if t and t.has_method("_surface_height"):
		return t._surface_height(global_position.x, global_position.z)
	return 0.0


func _pick_patrol() -> void:
	var a := randf() * TAU
	var r := randf_range(6.0, 22.0)
	_patrol = _home + Vector3(cos(a) * r, 0, sin(a) * r)


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	_cd = maxf(0.0, _cd - delta)
	_flash = maxf(0.0, _flash - delta)
	if _muzzle:
		_muzzle.visible = _flash > 0.0

	var to_player := 9999.0
	if _player:
		to_player = global_position.distance_to(_player.global_position)

	# --- состояние ---
	if to_player <= shoot_range:
		_state = "attack"
	elif to_player <= sight:
		_state = "chase"
	else:
		_repath -= delta
		if _repath <= 0.0:
			_repath = randf_range(3.0, 6.0)
			_pick_patrol()
		_state = "patrol"

	var target := _patrol
	if _state != "patrol" and _player:
		target = _player.global_position

	# --- движение ---
	var dir := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var dist := dir.length()
	if _state == "attack" and dist < 8.0:
		dir = Vector3.ZERO      # держим дистанцию, стреляем
	elif dist > 0.6:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO
		if _state == "patrol":
			_repath = 0.0

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	# гравитация и привязка к земле
	_vy -= GRAV * delta
	velocity.y = _vy
	move_and_slide()
	var gh := _ground()
	if global_position.y <= gh + 0.05:
		global_position.y = gh
		_vy = 0.0

	# поворот к цели
	if dir.length() > 0.01:
		var want := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, want, delta * 6.0)
	elif _state == "attack" and _player:
		var d2 := _player.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(d2.x, d2.z), delta * 8.0)

	# --- стрельба ---
	if _state == "attack" and _cd <= 0.0 and _player:
		_shoot()


func _shoot() -> void:
	_cd = 1.5 - tier * 0.25
	_flash = 0.09
	if _player == null or not _player.has_method("take_damage"):
		return
	# попадание с учётом точности и дистанции
	var d: float = global_position.distance_to(_player.global_position)
	var chance: float = accuracy * clampf(1.0 - d / (shoot_range * 1.4), 0.25, 1.0)
	if randf() < chance:
		_player.take_damage(damage, self)


func take_damage(amount: float, _from: Node = null) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	if _hp_bar:
		_hp_bar.texture = _bar_texture(hp / max_hp)
	# получив урон — сразу агрится
	if _state == "patrol":
		_state = "chase"
	if hp <= 0.0:
		_drop_loot()
		died.emit(tier)
		queue_free()


func _drop_loot() -> void:
	# лут зависит от сложности бандита
	var scrap := 15 + tier * 20 + randi() % 15
	GameState.add_item("scrap", scrap)
	GameState.add_item("cloth", 10 + tier * 8)
	if tier >= 1:
		GameState.add_item("metal", 8 + tier * 10)
	if tier >= 2:
		GameState.add_item("sulfur", 20 + randi() % 25)
	GameState.add_xp(12 + tier * 10)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("toast"):
		hud.toast("Бандит убит: +%d скрапа" % scrap)
