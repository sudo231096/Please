extends CharacterBody3D
## Животное 3D: цельные low-poly модели (части с перекрытием) + текстура + анимация ног.
## Мирные убегают, хищники нападают.

const GRAV := 22.0

enum Kind { CHICKEN, DEER, BOAR, BEAR }

const STATS := {
	Kind.CHICKEN: {"hp": 2, "speed": 3.0, "aggr": false, "dmg": 0, "meat": 1, "size": 0.45},
	Kind.DEER: {"hp": 3, "speed": 5.0, "aggr": false, "dmg": 0, "meat": 2, "size": 1.05},
	Kind.BOAR: {"hp": 4, "speed": 4.0, "aggr": true, "dmg": 8, "meat": 2, "size": 0.85},
	Kind.BEAR: {"hp": 7, "speed": 4.5, "aggr": true, "dmg": 14, "meat": 3, "size": 1.25},
}

@export var kind: int = Kind.CHICKEN
var body_mat: Material

var hp := 2
var _dir := Vector3.ZERO
var _timer := 0.0
var _atk := 0.0
var _player
var _walk_phase := 0.0
var _legs_arr: Array = []
var _root: Node3D


func _ready() -> void:
	add_to_group("animals")
	collision_layer = 1
	collision_mask = 1
	var s: Dictionary = STATS[kind]
	hp = int(s["hp"])
	_player = get_tree().get_first_node_in_group("player")
	_build(s)


func _physics_process(delta: float) -> void:
	velocity.y -= GRAV * delta
	if _atk > 0.0:
		_atk -= delta
	_timer -= delta
	var s: Dictionary = STATS[kind]
	var spd: float = float(s["speed"])
	if is_instance_valid(_player):
		var d: float = global_position.distance_to(_player.global_position)
		var aggr: bool = bool(s["aggr"])
		if aggr and d < 11.0:
			_dir = (_player.global_position - global_position)
			_dir.y = 0.0
			_dir = _dir.normalized()
			spd *= 1.4
			if d < 1.6 and _atk <= 0.0:
				_player.take_damage(int(s["dmg"]))
				_atk = 1.0
		elif not aggr and d < 7.0:
			_dir = (global_position - _player.global_position)
			_dir.y = 0.0
			_dir = _dir.normalized()
			spd *= 1.3
		elif _timer <= 0.0:
			_pick_wander()
	elif _timer <= 0.0:
		_pick_wander()
	velocity.x = _dir.x * spd
	velocity.z = _dir.z * spd
	if _dir.length() > 0.1:
		rotation.y = atan2(_dir.x, _dir.z)
	move_and_slide()
	_animate_legs(delta, spd)


func _animate_legs(delta: float, base_spd: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var amt: float = clampf(hspeed / maxf(base_spd, 0.1), 0.0, 1.0)
	_walk_phase += delta * 9.0 * amt
	for entry in _legs_arr:
		var pivot: Node3D = entry[0]
		var off: float = float(entry[1])
		var swing: float = float(entry[2]) if entry.size() > 2 else 0.5
		var target: float = sin(_walk_phase + off) * swing * amt
		pivot.rotation.x = lerp_angle(pivot.rotation.x, target, 0.4)


func _pick_wander() -> void:
	if randf() < 0.3:
		_dir = Vector3.ZERO
	else:
		var a := randf() * TAU
		_dir = Vector3(sin(a), 0.0, cos(a))
	_timer = randf_range(1.5, 4.0)


func hit(damage: int) -> void:
	hp -= damage
	if hp <= 0:
		Inv.add("meat", int(STATS[kind]["meat"]))
		queue_free()
	elif is_instance_valid(_player):
		_dir = (global_position - _player.global_position)
		_dir.y = 0.0
		_dir = _dir.normalized()


# --- Модели: все меши в _root, части с сильным перекрытием ---

func _build(s: Dictionary) -> void:
	_root = Node3D.new()
	_root.name = "Model"
	add_child(_root)
	var sz: float = float(s["size"])
	match kind:
		Kind.CHICKEN:
			_build_chicken(sz)
		Kind.DEER:
			_build_deer(sz)
		Kind.BOAR:
			_build_boar(sz)
		Kind.BEAR:
			_build_bear(sz)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(sz * 1.3, sz * 1.6, sz * 1.8)
	col.shape = bs
	col.position = Vector3(0, sz * 0.8, 0)
	add_child(col)


func _add(mesh: Mesh, pos: Vector3, rot := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation = rot
	(parent if parent else _root).add_child(m)
	return m


func _box_mesh(size: Vector3, mat: Material) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	return b


func _sph_mesh(r: float, mat: Material, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0.0 else r * 2.0
	s.radial_segments = 10
	s.rings = 6
	s.material = mat
	return s


func _cyl_mesh(r_top: float, r_bot: float, h: float, mat: Material) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 8
	c.material = mat
	return c


func _leg(mat: Material, hip: Vector3, h: float, r: float, off: float, swing := 0.5) -> void:
	## Цельная нога: один цилиндр + стопа, без щелей.
	var pivot := Node3D.new()
	pivot.position = hip
	_root.add_child(pivot)
	var leg_m := _add(_cyl_mesh(r, r * 0.7, h, mat), Vector3(0, -h * 0.5, 0), Vector3.ZERO, pivot)
	leg_m.scale = Vector3(1, 1, 1)
	var foot_r := r * 1.15
	_add(_sph_mesh(foot_r, mat, foot_r * 1.1), Vector3(0, -h + foot_r * 0.15, foot_r * 0.25), Vector3.ZERO, pivot).scale = Vector3(1.15, 0.55, 1.35)
	_legs_arr.append([pivot, off, swing])


func _legs4(mat: Material, hw: float, hl: float, h: float, r: float, swing := 0.5) -> void:
	for sx in [-1.0, 1.0]:
		for sl in [-1.0, 1.0]:
			var off := 0.0 if (sx * sl < 0.0) else PI
			# бёдра чуть внутри туловища (перекрытие)
			_leg(mat, Vector3(sx * hw, h, sl * hl), h, r, off, swing)


func _build_chicken(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _flat(Color(0.95, 0.93, 0.88))
	var yellow := _flat(Color(0.95, 0.72, 0.12))
	var red := _flat(Color(0.85, 0.12, 0.12))
	var dark := _flat(Color(0.12, 0.10, 0.08))
	var orange := _flat(Color(0.92, 0.45, 0.08))

	var lh := sz * 0.38
	var by := lh + sz * 0.40  # центр туловища

	# Туловище (овал) + грудка — одно пятно
	_add(_sph_mesh(sz * 0.42, fur, sz * 0.78), Vector3(0, by, 0)).scale = Vector3(1.15, 0.95, 1.35)
	_add(_sph_mesh(sz * 0.30, fur, sz * 0.50), Vector3(0, by - sz * 0.02, sz * 0.22))

	# Хвост прижат к заду
	_add(_box_mesh(Vector3(sz * 0.28, sz * 0.32, sz * 0.12), fur), Vector3(0, by + sz * 0.12, -sz * 0.42), Vector3(-0.55, 0, 0))
	_add(_box_mesh(Vector3(sz * 0.10, sz * 0.28, sz * 0.06), fur), Vector3(-sz * 0.10, by + sz * 0.18, -sz * 0.48), Vector3(-0.7, -0.25, 0))
	_add(_box_mesh(Vector3(sz * 0.10, sz * 0.28, sz * 0.06), fur), Vector3(sz * 0.10, by + sz * 0.18, -sz * 0.48), Vector3(-0.7, 0.25, 0))

	# Шея коротко стыкует тело и голову
	_add(_cyl_mesh(sz * 0.12, sz * 0.14, sz * 0.22, fur), Vector3(0, by + sz * 0.28, sz * 0.30), Vector3(0.7, 0, 0))
	# Голова вплотную к шее
	var hy := by + sz * 0.48
	var hz := sz * 0.48
	_add(_sph_mesh(sz * 0.20, fur, sz * 0.36), Vector3(0, hy, hz))
	# Гребень на голове
	_add(_box_mesh(Vector3(sz * 0.06, sz * 0.16, sz * 0.18), red), Vector3(0, hy + sz * 0.18, hz))
	_add(_box_mesh(Vector3(sz * 0.05, sz * 0.10, sz * 0.08), red), Vector3(0, hy + sz * 0.22, hz + sz * 0.06))
	# Серёжки
	_add(_sph_mesh(sz * 0.05, red, sz * 0.10), Vector3(0, hy - sz * 0.08, hz + sz * 0.12))
	# Клюв
	_add(_box_mesh(Vector3(sz * 0.08, sz * 0.06, sz * 0.16), yellow), Vector3(0, hy - sz * 0.02, hz + sz * 0.22))
	# Глаза
	_add(_sph_mesh(sz * 0.035, dark), Vector3(-sz * 0.10, hy + sz * 0.04, hz + sz * 0.12))
	_add(_sph_mesh(sz * 0.035, dark), Vector3(sz * 0.10, hy + sz * 0.04, hz + sz * 0.12))
	# Крылья вплотную к бокам
	_add(_sph_mesh(sz * 0.22, fur, sz * 0.40), Vector3(-sz * 0.32, by, sz * 0.02)).scale = Vector3(0.55, 0.9, 1.15)
	_add(_sph_mesh(sz * 0.22, fur, sz * 0.40), Vector3(sz * 0.32, by, sz * 0.02)).scale = Vector3(0.55, 0.9, 1.15)

	# Ноги из-под туловища
	_leg(orange, Vector3(-sz * 0.12, lh, 0.0), lh, sz * 0.04, 0.0, 0.65)
	_leg(orange, Vector3(sz * 0.12, lh, 0.0), lh, sz * 0.04, PI, 0.65)


func _build_deer(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _flat(Color(0.55, 0.40, 0.27))
	var tan := _flat(Color(0.72, 0.56, 0.36))
	var cream := _flat(Color(0.93, 0.90, 0.82))
	var dark := _flat(Color(0.12, 0.10, 0.08))
	var nose_c := _flat(Color(0.08, 0.07, 0.06))

	var lh := sz * 0.78
	var by := lh + sz * 0.28

	# Цельное туловище: центр + грудь + круп (сильное перекрытие)
	_add(_sph_mesh(sz * 0.36, fur, sz * 0.62), Vector3(0, by, 0)).scale = Vector3(1.05, 0.95, 1.7)
	_add(_sph_mesh(sz * 0.32, fur, sz * 0.55), Vector3(0, by + sz * 0.02, sz * 0.38))
	_add(_sph_mesh(sz * 0.30, cream, sz * 0.40), Vector3(0, by - sz * 0.12, sz * 0.05)).scale = Vector3(0.85, 0.7, 1.3)
	_add(_sph_mesh(sz * 0.32, fur, sz * 0.52), Vector3(0, by + sz * 0.02, -sz * 0.38))
	# Хвост
	_add(_sph_mesh(sz * 0.08, cream, sz * 0.14), Vector3(0, by + sz * 0.10, -sz * 0.62))

	# Шея — мост от груди к голове (перекрывает оба)
	var neck_h := sz * 0.42
	_add(_cyl_mesh(sz * 0.13, sz * 0.15, neck_h, fur), Vector3(0, by + sz * 0.22, sz * 0.52), Vector3(0.95, 0, 0))

	# Голова
	var hy := by + sz * 0.52
	var hz := sz * 0.78
	_add(_sph_mesh(sz * 0.18, fur, sz * 0.30), Vector3(0, hy, hz)).scale = Vector3(1.0, 0.95, 1.25)
	_add(_sph_mesh(sz * 0.11, cream, sz * 0.18), Vector3(0, hy - sz * 0.02, hz + sz * 0.16))
	_add(_sph_mesh(sz * 0.05, nose_c), Vector3(0, hy - sz * 0.02, hz + sz * 0.28))
	_add(_sph_mesh(sz * 0.035, dark), Vector3(-sz * 0.10, hy + sz * 0.04, hz + sz * 0.10))
	_add(_sph_mesh(sz * 0.035, dark), Vector3(sz * 0.10, hy + sz * 0.04, hz + sz * 0.10))

	# Уши из головы
	_add(_sph_mesh(sz * 0.07, fur, sz * 0.16), Vector3(-sz * 0.12, hy + sz * 0.16, hz - sz * 0.02)).scale = Vector3(0.7, 1.2, 0.45)
	_add(_sph_mesh(sz * 0.07, fur, sz * 0.16), Vector3(sz * 0.12, hy + sz * 0.16, hz - sz * 0.02)).scale = Vector3(0.7, 1.2, 0.45)

	# Рога из макушки
	_antler(tan, Vector3(-sz * 0.07, hy + sz * 0.14, hz - sz * 0.02), -1.0, sz)
	_antler(tan, Vector3(sz * 0.07, hy + sz * 0.14, hz - sz * 0.02), 1.0, sz)

	# Ноги под туловищем (бёдра внутри тела)
	_legs4(fur, sz * 0.18, sz * 0.32, lh, sz * 0.065, 0.48)


func _build_boar(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _flat(Color(0.32, 0.26, 0.21))
	var snout_c := _flat(Color(0.55, 0.38, 0.32))
	var ivory := _flat(Color(0.93, 0.90, 0.82))
	var dark := _flat(Color(0.10, 0.08, 0.06))

	var lh := sz * 0.38
	var by := lh + sz * 0.38

	# Массивное цельное тело
	_add(_sph_mesh(sz * 0.48, fur, sz * 0.78), Vector3(0, by, 0)).scale = Vector3(1.15, 0.95, 1.55)
	_add(_sph_mesh(sz * 0.42, fur, sz * 0.70), Vector3(0, by + sz * 0.02, sz * 0.35))
	_add(_sph_mesh(sz * 0.40, fur, sz * 0.65), Vector3(0, by, -sz * 0.32))
	# Горб
	_add(_sph_mesh(sz * 0.28, fur, sz * 0.40), Vector3(0, by + sz * 0.22, sz * 0.08))

	# Голова вплотную к груди
	var hy := by + sz * 0.10
	var hz := sz * 0.72
	_add(_sph_mesh(sz * 0.30, fur, sz * 0.48), Vector3(0, hy + sz * 0.06, hz))
	# Рыло + пятачок
	_add(_cyl_mesh(sz * 0.14, sz * 0.16, sz * 0.22, snout_c), Vector3(0, hy, hz + sz * 0.22), Vector3(PI * 0.5, 0, 0))
	_add(_cyl_mesh(sz * 0.15, sz * 0.15, sz * 0.05, snout_c), Vector3(0, hy, hz + sz * 0.34), Vector3(PI * 0.5, 0, 0))
	_add(_sph_mesh(sz * 0.025, dark), Vector3(-sz * 0.04, hy + sz * 0.02, hz + sz * 0.37))
	_add(_sph_mesh(sz * 0.025, dark), Vector3(sz * 0.04, hy + sz * 0.02, hz + sz * 0.37))
	# Клыки
	_add(_cyl_mesh(sz * 0.015, sz * 0.03, sz * 0.16, ivory), Vector3(-sz * 0.10, hy - sz * 0.04, hz + sz * 0.20), Vector3(0.9, 0, -0.4))
	_add(_cyl_mesh(sz * 0.015, sz * 0.03, sz * 0.16, ivory), Vector3(sz * 0.10, hy - sz * 0.04, hz + sz * 0.20), Vector3(0.9, 0, 0.4))
	# Глаза / уши
	_add(_sph_mesh(sz * 0.035, dark), Vector3(-sz * 0.16, hy + sz * 0.14, hz + sz * 0.08))
	_add(_sph_mesh(sz * 0.035, dark), Vector3(sz * 0.16, hy + sz * 0.14, hz + sz * 0.08))
	_add(_sph_mesh(sz * 0.09, fur, sz * 0.14), Vector3(-sz * 0.18, hy + sz * 0.24, hz - sz * 0.02)).scale = Vector3(0.8, 1.1, 0.5)
	_add(_sph_mesh(sz * 0.09, fur, sz * 0.14), Vector3(sz * 0.18, hy + sz * 0.24, hz - sz * 0.02)).scale = Vector3(0.8, 1.1, 0.5)
	# Хвост
	_add(_cyl_mesh(sz * 0.035, sz * 0.02, sz * 0.18, fur), Vector3(0, by + sz * 0.08, -sz * 0.58), Vector3(-0.9, 0, 0))

	_legs4(fur, sz * 0.26, sz * 0.32, lh, sz * 0.09, 0.42)


func _build_bear(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _flat(Color(0.30, 0.22, 0.16))
	var dark := _flat(Color(0.12, 0.09, 0.07))
	var muzzle_c := _flat(Color(0.22, 0.16, 0.12))
	var nose_c := _flat(Color(0.05, 0.04, 0.03))

	var lh := sz * 0.48
	var by := lh + sz * 0.42

	# Мощное цельное тело
	_add(_sph_mesh(sz * 0.52, fur, sz * 0.88), Vector3(0, by, 0)).scale = Vector3(1.15, 1.0, 1.45)
	_add(_sph_mesh(sz * 0.48, fur, sz * 0.80), Vector3(0, by + sz * 0.04, sz * 0.32))
	_add(_sph_mesh(sz * 0.46, fur, sz * 0.75), Vector3(0, by, -sz * 0.30))
	# Плечевой горб
	_add(_sph_mesh(sz * 0.36, fur, sz * 0.50), Vector3(0, by + sz * 0.28, sz * 0.10))

	# Голова вплотную
	var hy := by + sz * 0.30
	var hz := sz * 0.68
	_add(_sph_mesh(sz * 0.30, fur, sz * 0.52), Vector3(0, hy, hz))
	_add(_sph_mesh(sz * 0.16, muzzle_c, sz * 0.26), Vector3(0, hy - sz * 0.04, hz + sz * 0.22))
	_add(_sph_mesh(sz * 0.06, nose_c), Vector3(0, hy, hz + sz * 0.36))
	_add(_sph_mesh(sz * 0.035, dark), Vector3(-sz * 0.12, hy + sz * 0.08, hz + sz * 0.14))
	_add(_sph_mesh(sz * 0.035, dark), Vector3(sz * 0.12, hy + sz * 0.08, hz + sz * 0.14))
	# Уши
	_add(_sph_mesh(sz * 0.10, fur), Vector3(-sz * 0.18, hy + sz * 0.22, hz - sz * 0.02))
	_add(_sph_mesh(sz * 0.10, fur), Vector3(sz * 0.18, hy + sz * 0.22, hz - sz * 0.02))
	_add(_sph_mesh(sz * 0.05, dark), Vector3(-sz * 0.18, hy + sz * 0.22, hz + sz * 0.02))
	_add(_sph_mesh(sz * 0.05, dark), Vector3(sz * 0.18, hy + sz * 0.22, hz + sz * 0.02))
	# Плечи / передние массы влиты в тело
	_add(_sph_mesh(sz * 0.20, fur, sz * 0.36), Vector3(-sz * 0.36, by + sz * 0.02, sz * 0.22))
	_add(_sph_mesh(sz * 0.20, fur, sz * 0.36), Vector3(sz * 0.36, by + sz * 0.02, sz * 0.22))
	# Хвост
	_add(_sph_mesh(sz * 0.10, fur, sz * 0.14), Vector3(0, by + sz * 0.05, -sz * 0.58))

	_legs4(fur, sz * 0.24, sz * 0.30, lh, sz * 0.12, 0.38)


func _antler(mat: Material, base: Vector3, side: float, sz: float) -> void:
	var root := Node3D.new()
	root.position = base
	_root.add_child(root)
	var h1 := sz * 0.38
	var r0 := sz * 0.03
	_add(_cyl_mesh(r0 * 0.55, r0, h1, mat), Vector3(side * sz * 0.03, h1 * 0.5, 0), Vector3(0.15, 0, side * 0.28), root)
	var bh := h1 * 0.42
	_add(_cyl_mesh(r0 * 0.35, r0 * 0.65, bh, mat), Vector3(side * sz * 0.08, h1 * 0.55, 0), Vector3(-0.4, 0, side * 1.1), root)
	_add(_cyl_mesh(r0 * 0.3, r0 * 0.55, bh * 0.85, mat), Vector3(side * sz * 0.06, h1 * 0.85, 0), Vector3(-0.55, 0, side * 0.9), root)


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m
