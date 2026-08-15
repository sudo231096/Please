extends CharacterBody3D
## Животное 3D: более реалистичные low-poly модели + текстура шерсти + анимация ног.
## Мирные убегают, хищники нападают.

const GRAV := 22.0

enum Kind { CHICKEN, DEER, BOAR, BEAR }

const STATS := {
	Kind.CHICKEN: {"hp": 2, "speed": 3.0, "aggr": false, "dmg": 0, "meat": 1, "size": 0.4},
	Kind.DEER: {"hp": 3, "speed": 5.0, "aggr": false, "dmg": 0, "meat": 2, "size": 1.1},
	Kind.BOAR: {"hp": 4, "speed": 4.0, "aggr": true, "dmg": 8, "meat": 2, "size": 0.8},
	Kind.BEAR: {"hp": 7, "speed": 4.5, "aggr": true, "dmg": 14, "meat": 3, "size": 1.3},
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


func _ready() -> void:
	add_to_group("animals")
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
		var swing: float = float(entry[2]) if entry.size() > 2 else 0.55
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


# --- Модели ---

func _build(s: Dictionary) -> void:
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
	bs.size = Vector3(sz * 1.4, sz * 1.7, sz * 1.9)
	col.shape = bs
	col.position = Vector3(0, sz * 0.85, 0)
	add_child(col)


func _leg_pivot(mat: Material, hip: Vector3, h: float, r_top: float, r_bot: float, off: float, swing := 0.55) -> void:
	var pivot := Node3D.new()
	pivot.position = hip
	add_child(pivot)
	# бедро
	var thigh := MeshInstance3D.new()
	var c1 := CylinderMesh.new()
	c1.top_radius = r_top
	c1.bottom_radius = r_top * 0.85
	c1.height = h * 0.55
	c1.radial_segments = 8
	c1.material = mat
	thigh.mesh = c1
	thigh.position = Vector3(0, -h * 0.275, 0)
	pivot.add_child(thigh)
	# голень
	var shin := MeshInstance3D.new()
	var c2 := CylinderMesh.new()
	c2.top_radius = r_top * 0.75
	c2.bottom_radius = r_bot
	c2.height = h * 0.45
	c2.radial_segments = 8
	c2.material = mat
	shin.mesh = c2
	shin.position = Vector3(0, -h * 0.775, 0)
	pivot.add_child(shin)
	# копыто / лапа
	var foot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r_bot * 1.35
	sm.height = r_bot * 1.6
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = mat
	foot.mesh = sm
	foot.position = Vector3(0, -h - r_bot * 0.15, r_bot * 0.35)
	foot.scale = Vector3(1.1, 0.55, 1.4)
	pivot.add_child(foot)
	_legs_arr.append([pivot, off, swing])


func _legs4(mat: Material, hw: float, hl: float, h: float, r: float, swing := 0.55) -> void:
	for sx in [-1.0, 1.0]:
		for sl in [-1.0, 1.0]:
			var off := 0.0 if (sx * sl < 0.0) else PI
			_leg_pivot(mat, Vector3(sx * hw, h, sl * hl), h, r, r * 0.65, off, swing)


func _build_chicken(sz: float) -> void:
	var feather := body_mat if body_mat else _flat(Color(0.95, 0.93, 0.88))
	var yellow := _flat(Color(0.95, 0.72, 0.12))
	var red := _flat(Color(0.85, 0.12, 0.12))
	var dark := _flat(Color(0.15, 0.12, 0.10))
	var orange := _flat(Color(0.92, 0.45, 0.08))
	var lh := sz * 0.42
	var body_y := lh + sz * 0.48

	# туловище — овальное
	_sphere(Vector3(sz * 0.55, sz * 0.48, sz * 0.72), feather, Vector3(0, body_y, 0))
	# грудка чуть светлее/выпукле
	_sphere(Vector3(sz * 0.38, sz * 0.32, sz * 0.42), feather, Vector3(0, body_y - sz * 0.05, sz * 0.18))
	# хвост — веер
	for i in range(5):
		var a := (float(i) - 2.0) * 0.22
		var t := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sz * 0.08, sz * 0.35, sz * 0.04)
		bm.material = feather
		t.mesh = bm
		t.position = Vector3(sin(a) * sz * 0.12, body_y + sz * 0.15, -sz * 0.55)
		t.rotation = Vector3(-0.7, a, a * 0.3)
		add_child(t)
	# шея
	_cyl_taper(sz * 0.12, sz * 0.09, sz * 0.28, feather, Vector3(0, body_y + sz * 0.35, sz * 0.42), Vector3(0.55, 0, 0))
	# голова
	_sphere(Vector3(sz * 0.28, sz * 0.26, sz * 0.30), feather, Vector3(0, body_y + sz * 0.58, sz * 0.58))
	# гребень
	for i in range(3):
		_sphere(Vector3(sz * 0.06, sz * 0.12, sz * 0.08), red,
			Vector3(0, body_y + sz * 0.78 + float(i) * sz * 0.02, sz * 0.52 + float(i) * sz * 0.08))
	# серёжки
	_sphere(Vector3(sz * 0.06, sz * 0.10, sz * 0.05), red, Vector3(0, body_y + sz * 0.48, sz * 0.72))
	# клюв
	var beak := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(sz * 0.12, sz * 0.10, sz * 0.18)
	pr.material = yellow
	beak.mesh = pr
	beak.position = Vector3(0, body_y + sz * 0.55, sz * 0.82)
	beak.rotation = Vector3(PI * 0.5, 0, 0)
	add_child(beak)
	# глаза
	_sphere(Vector3(sz * 0.04, sz * 0.04, sz * 0.04), dark, Vector3(-sz * 0.14, body_y + sz * 0.62, sz * 0.72))
	_sphere(Vector3(sz * 0.04, sz * 0.04, sz * 0.04), dark, Vector3(sz * 0.14, body_y + sz * 0.62, sz * 0.72))
	# крылья
	_sphere(Vector3(sz * 0.12, sz * 0.35, sz * 0.45), feather, Vector3(-sz * 0.48, body_y, sz * 0.05))
	_sphere(Vector3(sz * 0.12, sz * 0.35, sz * 0.45), feather, Vector3(sz * 0.48, body_y, sz * 0.05))
	# ноги
	_leg_pivot(orange, Vector3(-sz * 0.16, lh, sz * 0.05), lh, sz * 0.045, sz * 0.03, 0.0, 0.7)
	_leg_pivot(orange, Vector3(sz * 0.16, lh, sz * 0.05), lh, sz * 0.045, sz * 0.03, PI, 0.7)


func _build_deer(sz: float) -> void:
	var fur := body_mat if body_mat else _flat(Color(0.55, 0.40, 0.27))
	var tan := _flat(Color(0.72, 0.56, 0.36))
	var cream := _flat(Color(0.93, 0.90, 0.82))
	var dark := _flat(Color(0.12, 0.10, 0.08))
	var nose_c := _flat(Color(0.08, 0.07, 0.06))
	var lh := sz * 0.88
	var body_y := lh + sz * 0.32

	# туловище
	_sphere(Vector3(sz * 0.42, sz * 0.38, sz * 0.85), fur, Vector3(0, body_y, 0))
	# грудь
	_sphere(Vector3(sz * 0.38, sz * 0.36, sz * 0.40), fur, Vector3(0, body_y + sz * 0.02, sz * 0.45))
	# живот светлее
	_sphere(Vector3(sz * 0.30, sz * 0.22, sz * 0.55), cream, Vector3(0, body_y - sz * 0.18, sz * 0.05))
	# круп
	_sphere(Vector3(sz * 0.40, sz * 0.36, sz * 0.38), fur, Vector3(0, body_y + sz * 0.02, -sz * 0.55))
	# хвост
	_sphere(Vector3(sz * 0.10, sz * 0.16, sz * 0.10), cream, Vector3(0, body_y + sz * 0.15, -sz * 0.85))
	# шея
	_cyl_taper(sz * 0.14, sz * 0.16, sz * 0.55, fur, Vector3(0, body_y + sz * 0.35, sz * 0.70), Vector3(0.85, 0, 0))
	# голова
	_sphere(Vector3(sz * 0.22, sz * 0.20, sz * 0.32), fur, Vector3(0, body_y + sz * 0.70, sz * 0.95))
	# морда
	_sphere(Vector3(sz * 0.14, sz * 0.12, sz * 0.22), cream, Vector3(0, body_y + sz * 0.62, sz * 1.18))
	_sphere(Vector3(sz * 0.06, sz * 0.05, sz * 0.06), nose_c, Vector3(0, body_y + sz * 0.62, sz * 1.35))
	# глаза
	_sphere(Vector3(sz * 0.045, sz * 0.045, sz * 0.04), dark, Vector3(-sz * 0.14, body_y + sz * 0.76, sz * 1.10))
	_sphere(Vector3(sz * 0.045, sz * 0.045, sz * 0.04), dark, Vector3(sz * 0.14, body_y + sz * 0.76, sz * 1.10))
	# уши
	_ear(fur, Vector3(-sz * 0.16, body_y + sz * 0.92, sz * 0.88), -0.35, sz)
	_ear(fur, Vector3(sz * 0.16, body_y + sz * 0.92, sz * 0.88), 0.35, sz)
	# рога
	_antler(tan, Vector3(-sz * 0.10, body_y + sz * 0.92, sz * 0.92), -1.0, sz)
	_antler(tan, Vector3(sz * 0.10, body_y + sz * 0.92, sz * 0.92), 1.0, sz)
	# ноги
	_legs4(fur, sz * 0.22, sz * 0.48, lh, sz * 0.07, 0.5)


func _build_boar(sz: float) -> void:
	var fur := body_mat if body_mat else _flat(Color(0.32, 0.26, 0.21))
	var snout_c := _flat(Color(0.55, 0.38, 0.32))
	var ivory := _flat(Color(0.93, 0.90, 0.82))
	var dark := _flat(Color(0.10, 0.08, 0.06))
	var lh := sz * 0.42
	var body_y := lh + sz * 0.42

	# массивное туловище
	_sphere(Vector3(sz * 0.58, sz * 0.48, sz * 0.95), fur, Vector3(0, body_y, 0))
	_sphere(Vector3(sz * 0.55, sz * 0.45, sz * 0.50), fur, Vector3(0, body_y + sz * 0.02, sz * 0.45))
	# горб / холк
	_sphere(Vector3(sz * 0.40, sz * 0.22, sz * 0.35), fur, Vector3(0, body_y + sz * 0.28, sz * 0.15))
	# зад
	_sphere(Vector3(sz * 0.52, sz * 0.42, sz * 0.42), fur, Vector3(0, body_y, -sz * 0.55))
	# щетина на холке
	for i in range(6):
		var br := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sz * 0.04, sz * 0.18, sz * 0.03)
		bm.material = dark
		br.mesh = bm
		br.position = Vector3((float(i) - 2.5) * sz * 0.08, body_y + sz * 0.42, sz * 0.05 + float(i % 3) * sz * 0.06)
		br.rotation.x = -0.3
		add_child(br)
	# голова
	_sphere(Vector3(sz * 0.38, sz * 0.32, sz * 0.40), fur, Vector3(0, body_y + sz * 0.18, sz * 0.85))
	# рыло
	_cyl_taper(sz * 0.16, sz * 0.18, sz * 0.28, snout_c, Vector3(0, body_y + sz * 0.08, sz * 1.15), Vector3(0.2, 0, 0))
	# пятачок
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = sz * 0.16
	cyl.bottom_radius = sz * 0.16
	cyl.height = sz * 0.06
	cyl.radial_segments = 10
	cyl.material = snout_c
	disc.mesh = cyl
	disc.position = Vector3(0, body_y + sz * 0.08, sz * 1.30)
	disc.rotation.x = PI * 0.5
	add_child(disc)
	# ноздри
	_sphere(Vector3(sz * 0.03, sz * 0.04, sz * 0.02), dark, Vector3(-sz * 0.05, body_y + sz * 0.10, sz * 1.34))
	_sphere(Vector3(sz * 0.03, sz * 0.04, sz * 0.02), dark, Vector3(sz * 0.05, body_y + sz * 0.10, sz * 1.34))
	# клыки
	_tusk(ivory, Vector3(-sz * 0.12, body_y + sz * 0.02, sz * 1.18), -1.0, sz)
	_tusk(ivory, Vector3(sz * 0.12, body_y + sz * 0.02, sz * 1.18), 1.0, sz)
	# глаза
	_sphere(Vector3(sz * 0.04, sz * 0.04, sz * 0.03), dark, Vector3(-sz * 0.22, body_y + sz * 0.28, sz * 1.00))
	_sphere(Vector3(sz * 0.04, sz * 0.04, sz * 0.03), dark, Vector3(sz * 0.22, body_y + sz * 0.28, sz * 1.00))
	# уши
	_ear(fur, Vector3(-sz * 0.22, body_y + sz * 0.42, sz * 0.78), -0.5, sz)
	_ear(fur, Vector3(sz * 0.22, body_y + sz * 0.42, sz * 0.78), 0.5, sz)
	# хвост
	_cyl_taper(sz * 0.04, sz * 0.02, sz * 0.25, fur, Vector3(0, body_y + sz * 0.15, -sz * 0.85), Vector3(-0.8, 0, 0))
	# ноги короткие толстые
	_legs4(fur, sz * 0.30, sz * 0.48, lh, sz * 0.10, 0.45)


func _build_bear(sz: float) -> void:
	var fur := body_mat if body_mat else _flat(Color(0.30, 0.22, 0.16))
	var dark := _flat(Color(0.12, 0.09, 0.07))
	var muzzle_c := _flat(Color(0.22, 0.16, 0.12))
	var nose_c := _flat(Color(0.05, 0.04, 0.03))
	var lh := sz * 0.52
	var body_y := lh + sz * 0.48

	# мощное туловище
	_sphere(Vector3(sz * 0.62, sz * 0.55, sz * 0.85), fur, Vector3(0, body_y, 0))
	_sphere(Vector3(sz * 0.58, sz * 0.52, sz * 0.50), fur, Vector3(0, body_y + sz * 0.05, sz * 0.40))
	# горб плеч
	_sphere(Vector3(sz * 0.48, sz * 0.28, sz * 0.40), fur, Vector3(0, body_y + sz * 0.35, sz * 0.15))
	# зад
	_sphere(Vector3(sz * 0.58, sz * 0.50, sz * 0.48), fur, Vector3(0, body_y, -sz * 0.50))
	# голова
	_sphere(Vector3(sz * 0.38, sz * 0.36, sz * 0.38), fur, Vector3(0, body_y + sz * 0.42, sz * 0.78))
	# морда
	_sphere(Vector3(sz * 0.20, sz * 0.16, sz * 0.28), muzzle_c, Vector3(0, body_y + sz * 0.32, sz * 1.05))
	_sphere(Vector3(sz * 0.08, sz * 0.06, sz * 0.07), nose_c, Vector3(0, body_y + sz * 0.36, sz * 1.25))
	# глаза
	_sphere(Vector3(sz * 0.04, sz * 0.04, sz * 0.03), dark, Vector3(-sz * 0.16, body_y + sz * 0.50, sz * 0.98))
	_sphere(Vector3(sz * 0.04, sz * 0.04, sz * 0.03), dark, Vector3(sz * 0.16, body_y + sz * 0.50, sz * 0.98))
	# уши круглые
	_sphere(Vector3(sz * 0.12, sz * 0.12, sz * 0.08), fur, Vector3(-sz * 0.22, body_y + sz * 0.68, sz * 0.72))
	_sphere(Vector3(sz * 0.12, sz * 0.12, sz * 0.08), fur, Vector3(sz * 0.22, body_y + sz * 0.68, sz * 0.72))
	_sphere(Vector3(sz * 0.06, sz * 0.06, sz * 0.04), dark, Vector3(-sz * 0.22, body_y + sz * 0.68, sz * 0.78))
	_sphere(Vector3(sz * 0.06, sz * 0.06, sz * 0.04), dark, Vector3(sz * 0.22, body_y + sz * 0.68, sz * 0.78))
	# передние лапы мощнее — через обычные ноги + «плечи»
	_sphere(Vector3(sz * 0.22, sz * 0.28, sz * 0.22), fur, Vector3(-sz * 0.40, body_y + sz * 0.05, sz * 0.35))
	_sphere(Vector3(sz * 0.22, sz * 0.28, sz * 0.22), fur, Vector3(sz * 0.40, body_y + sz * 0.05, sz * 0.35))
	# хвост-пень
	_sphere(Vector3(sz * 0.12, sz * 0.10, sz * 0.10), fur, Vector3(0, body_y + sz * 0.10, -sz * 0.85))
	# ноги
	_legs4(fur, sz * 0.28, sz * 0.42, lh, sz * 0.13, 0.4)


# --- примитивы ---

func _box(s: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = s
	b.material = mat
	m.mesh = b
	m.position = pos
	m.rotation = rot
	add_child(m)
	return m


func _sphere(s: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 8
	sm.material = mat
	m.mesh = sm
	m.position = pos
	m.scale = s
	add_child(m)
	return m


func _cyl(r: float, h: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	return _cyl_taper(r, r, h, mat, pos, Vector3.ZERO)


func _cyl_taper(r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 10
	c.material = mat
	m.mesh = c
	m.position = pos
	m.rotation = rot
	add_child(m)
	return m


func _ear(mat: Material, pos: Vector3, side: float, sz: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = mat
	m.mesh = sm
	m.position = pos
	m.scale = Vector3(sz * 0.14, sz * 0.28, sz * 0.10)
	m.rotation = Vector3(-0.45, side * 0.55, side * 0.7)
	add_child(m)


func _antler(mat: Material, base: Vector3, side: float, sz: float) -> void:
	var root := Node3D.new()
	root.position = base
	add_child(root)
	var h1 := sz * 0.45
	var r0 := sz * 0.035
	var main := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r0 * 0.6
	c.bottom_radius = r0
	c.height = h1
	c.radial_segments = 6
	c.material = mat
	main.mesh = c
	main.position = Vector3(side * sz * 0.04, h1 * 0.5, -sz * 0.02)
	main.rotation = Vector3(0.2, 0, side * 0.3)
	root.add_child(main)
	for i in range(2):
		var br := MeshInstance3D.new()
		var c2 := CylinderMesh.new()
		var bh := h1 * (0.5 - float(i) * 0.12)
		c2.top_radius = r0 * 0.35
		c2.bottom_radius = r0 * 0.7
		c2.height = bh
		c2.radial_segments = 6
		c2.material = mat
		br.mesh = c2
		br.position = Vector3(side * sz * (0.06 + float(i) * 0.03), h1 * (0.4 + float(i) * 0.28), -sz * 0.02)
		br.rotation = Vector3(-0.35 - float(i) * 0.2, 0, side * (1.0 + float(i) * 0.35))
		root.add_child(br)


func _tusk(mat: Material, pos: Vector3, side: float, sz: float) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = sz * 0.015
	c.bottom_radius = sz * 0.035
	c.height = sz * 0.22
	c.radial_segments = 6
	c.material = mat
	m.mesh = c
	m.position = pos
	m.rotation = Vector3(1.0, 0, side * 0.55)
	add_child(m)


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m
