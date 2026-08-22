extends CharacterBody3D
## Герой: камерамен / спикер-мен / ТВ-мен. Ближний бой + суперсила.

const RUN_SPEED := 6.0
const STRAFE_SPEED := 6.0
const MELEE_RANGE := 2.8
const MELEE_CD := 0.45
const STREET_HALF := 4.6

# герои: [модель, масштаб, yaw, offset_y]
const HEROES := [
	{"model": preload("res://models/cameraman.glb"), "scale": 0.0957, "yaw": 180.0, "offset": Vector3(0, 0, 0.099)},
	{"model": preload("res://models/speakerman.glb"), "scale": 0.26, "yaw": 180.0, "offset": Vector3(0, 0, 0.03)},
	{"model": preload("res://models/tvman.glb"), "scale": 0.95, "yaw": 180.0, "offset": Vector3(0, 0, 0.02)},
]
const HERO_NAMES := ["Камерамен", "Спикер-мен", "ТВ-мен"]
const HERO_SUPER := ["Вспышка (оглушение)", "Звуковая волна", "Луч из экрана"]

const PUNCH_TIME := 0.42
# целевые повороты костей (в костном локальном пространстве, откалиброваны в игре): кулак вперёд
const PUNCH_R := Vector3(deg_to_rad(90.0), deg_to_rad(-90.0), 0.0)
const PUNCH_L := Vector3(deg_to_rad(90.0), deg_to_rad(90.0), 0.0)

var max_hp := 100.0
var hp := 100.0
var damage := 34.0
var _punch_t := 0.0
var _punch_cd := 0.0
var _punch_side := 1.0
var _super_cd := 0.0
var super_cooldown := 5.0
var _invuln := 0.0
var _model: Node3D
var _model_offset := Vector3.ZERO
var _finish_limit := -10000.0
var hero := 0

# кости для анимации удара (заполняются, если у героя есть скелет)
var _skel: Skeleton3D
var _bone_r_arm := -1
var _bone_l_arm := -1
var _bone_spine2 := -1

signal died
signal hp_changed(hp: float, max_hp: float)


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	hero = GameState.selected_hero
	_build()
	max_hp = GameState.player_max_hp()
	hp = max_hp
	damage = GameState.player_damage()


func _build() -> void:
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.4
	cs.height = 1.7
	col.shape = cs
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	var cfg: Dictionary = HEROES[hero]
	_model_offset = cfg["offset"]
	_model = (cfg["model"] as PackedScene).instantiate()
	_model.scale = Vector3.ONE * cfg["scale"]
	_model.rotation_degrees = Vector3(0, cfg["yaw"], 0)
	_model.position = _model_offset
	add_child(_model)

	# ищем скелет и нужные кости (руки, корпус)
	_skel = null
	for n in _model.find_children("*", "Skeleton3D", true, false):
		_skel = n
		break
	if _skel:
		for b in range(_skel.get_bone_count()):
			var nm := String(_skel.get_bone_name(b))
			if nm.begins_with("mixamorig_RightArm_"):
				_bone_r_arm = b
			elif nm.begins_with("mixamorig_LeftArm_"):
				_bone_l_arm = b
			elif nm.begins_with("mixamorig_Spine2_"):
				_bone_spine2 = b


func _physics_process(delta: float) -> void:
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_super_cd = maxf(0.0, _super_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	if hp <= 0.0:
		return

	# движение во все стороны (управляет игрок)
	var mv_x := 0.0
	var mv_z := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv_x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv_z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv_z += 1.0
	if has_meta("mob_dir"):
		var jd: Vector2 = get_meta("mob_dir")
		mv_x += jd.x
		mv_z += jd.y

	var mv := Vector2(mv_x, mv_z)
	if mv.length() > 1.0:
		mv = mv.normalized()
	velocity.x = mv.x * STRAFE_SPEED
	velocity.z = mv.y * STRAFE_SPEED

	global_position.x = clampf(global_position.x, -STREET_HALF, STREET_HALF)
	global_position.z = clampf(global_position.z, _finish_limit, 10.0)

	# прицел
	var target := _nearest_enemy()
	if target:
		var look_p: Vector3 = target.global_position
		look_p.y = global_position.y
		if global_position.distance_to(look_p) > 0.05:
			look_at(look_p, Vector3.UP)
	elif mv.length() > 0.05:
		look_at(global_position + Vector3(mv.x, 0, mv.y), Vector3.UP)

	# удар рукой
	var punch := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if has_meta("mob_fire") and bool(get_meta("mob_fire")):
		punch = true
	if punch and _punch_cd <= 0.0:
		_punch()

	# суперсила
	var super_pressed := Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_Q)
	if has_meta("mob_super") and bool(get_meta("mob_super")):
		super_pressed = true
		set_meta("mob_super", false)
	if super_pressed and _super_cd <= 0.0:
		_use_super()

	_animate_punch(delta)
	move_and_slide()


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := 1.0e9
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var d: float = en.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _punch() -> void:
	_punch_cd = MELEE_CD
	_punch_t = PUNCH_TIME
	_punch_side = -_punch_side
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node3D
		var d: float = en.global_position.distance_to(global_position)
		if d <= MELEE_RANGE and en.has_method("take_damage"):
			en.take_damage(damage)


func _use_super() -> void:
	_super_cd = super_cooldown
	match hero:
		0:  # камерамен — вспышка, оглушает врагов вокруг
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Node3D
				if en.global_position.distance_to(global_position) <= 6.0 and en.has_method("stun"):
					en.stun(2.0)
		1:  # спикер-мен — звуковая волна, урон + отброс по площади
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Node3D
				var d: float = en.global_position.distance_to(global_position)
				if d <= 7.0 and en.has_method("take_damage"):
					en.take_damage(damage * 1.6)
					en.knockback(en.global_position - global_position, 9.0)
		2:  # ТВ-мен — луч из экрана, урон по конусу вперёд
			var fwd := -global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Node3D
				var to_e := en.global_position - global_position
				to_e.y = 0.0
				var d := to_e.length()
				if d <= 9.0 and d > 0.01:
					var ang := fwd.angle_to(to_e.normalized())
					if ang < deg_to_rad(55.0) and en.has_method("take_damage"):
						en.take_damage(damage * 2.0)


func _animate_punch(delta: float) -> void:
	if _punch_t > 0.0:
		_punch_t -= delta
		var t := 1.0 - _punch_t / PUNCH_TIME  # 0 -> 1
		var env := 0.0
		if t < 0.18:
			# замах: рука плавно отводится назад
			env = -0.15 * sin(t / 0.18 * PI * 0.5)
		elif t < 0.45:
			# удар: резкий выброс кулака вперёд
			var w := (t - 0.18) / 0.27
			env = lerp(-0.15, 1.0, smoothstep(0.0, 1.0, w))
		else:
			# возврат в стойку
			var w := (t - 0.45) / 0.55
			env = lerp(1.0, 0.0, smoothstep(0.0, 1.0, w))
		_apply_punch(env)
	else:
		_apply_punch(0.0)


func _apply_punch(env: float) -> void:
	if _skel == null:
		return
	# рука: правая или левая бьёт (в зависимости от _punch_side), ноги не трогаем
	if _punch_side > 0.0 and _bone_r_arm >= 0:
		_skel.set_bone_pose_rotation(_bone_r_arm, Quaternion.from_euler(PUNCH_R * env))
	elif _bone_l_arm >= 0:
		_skel.set_bone_pose_rotation(_bone_l_arm, Quaternion.from_euler(PUNCH_L * env))
	# корпус: лёгкий разворот вперёд (верх тела, ноги остаются на месте — они от Hips)
	if _bone_spine2 >= 0:
		var tw := maxf(env, 0.0)
		_skel.set_bone_pose_rotation(_bone_spine2, Quaternion.from_euler(Vector3(-tw * 0.12, _punch_side * tw * 0.25, 0.0)))
	_skel.force_update_all_bone_transforms()


func take_damage(amount: float, from: Node = null, knock: float = 0.0) -> void:
	if hp <= 0.0 or _invuln > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_invuln = 0.4
	hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		died.emit()
