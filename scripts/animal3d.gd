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
var _ai_tick := 0
var _sleeping := false
var _spd_mul := 1.0


func _ready() -> void:
	add_to_group("animals")
	collision_layer = 1
	collision_mask = 1
	var s: Dictionary = STATS[kind]
	hp = int(s["hp"])
	_player = get_tree().get_first_node_in_group("player")
	_build(s)


func _physics_process(delta: float) -> void:
	_ai_tick += 1
	if is_instance_valid(_player):
		var dx: float = global_position.x - _player.global_position.x
		var dz: float = global_position.z - _player.global_position.z
		var d2: float = dx * dx + dz * dz
		# дальше 80м — sleep
		if d2 > 6400.0:
			if not _sleeping:
				_sleeping = true
				velocity = Vector3.ZERO
				visible = false
			if (_ai_tick % 30) != 0:
				return
			return
		if _sleeping:
			_sleeping = false
			visible = true
		if (_ai_tick % 3) == 0:
			_think(d2)
	elif (_ai_tick % 12) == 0 and _timer <= 0.0:
		_pick_wander()

	velocity.y -= GRAV * delta
	if _atk > 0.0:
		_atk -= delta
	_timer -= delta
	var s: Dictionary = STATS[kind]
	var spd: float = float(s["speed"]) * _spd_mul
	velocity.x = _dir.x * spd
	velocity.z = _dir.z * spd
	if _dir.length() > 0.1:
		rotation.y = atan2(_dir.x, _dir.z)
	if _sleeping:
		return
	move_and_slide()
	_animate_legs(delta, float(s["speed"]))


func _think(d2: float) -> void:
	var s: Dictionary = STATS[kind]
	var d: float = sqrt(d2)
	var aggr: bool = bool(s["aggr"])
	_spd_mul = 1.0
	if aggr and d < 11.0:
		_dir = (_player.global_position - global_position)
		_dir.y = 0.0
		if _dir.length() > 0.01:
			_dir = _dir.normalized()
		_spd_mul = 1.4
		if d < 1.6 and _atk <= 0.0:
			_player.take_damage(int(s["dmg"]))
			_atk = 1.0
	elif (not aggr) and d < 7.0:
		_dir = (global_position - _player.global_position)
		_dir.y = 0.0
		if _dir.length() > 0.01:
			_dir = _dir.normalized()
		_spd_mul = 1.3
	elif _timer <= 0.0:
		_pick_wander()


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


# --- Oxide/Rust-like low-poly models ---

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
	bs.size = Vector3(sz * 1.25, sz * 1.5, sz * 1.85)
	col.shape = bs
	col.position = Vector3(0, sz * 0.75, 0)
	add_child(col)


func _mi(mesh: Mesh, mat: Material, pos: Vector3, parent: Node = null, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _root).add_child(m)
	return m


func _mat_c(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _leg(mat: Material, hip: Vector3, h: float, r: float, off: float, swing: float = 0.45) -> void:
	var pivot := Node3D.new()
	pivot.position = hip
	_root.add_child(pivot)
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 0.75
	c.height = h
	c.radial_segments = 6
	_mi(c, mat, Vector3(0, -h * 0.5, 0), pivot)
	var foot := SphereMesh.new()
	foot.radius = r * 1.2
	foot.height = r * 1.4
	foot.radial_segments = 6
	foot.rings = 3
	_mi(foot, mat, Vector3(0, -h, r * 0.25), pivot, Vector3.ZERO, Vector3(1.2, 0.55, 1.4))
	_legs_arr.append([pivot, off, swing])


func _legs4(mat: Material, hw: float, hl: float, h: float, r: float) -> void:
	for sx in [-1.0, 1.0]:
		for sl in [-1.0, 1.0]:
			var off := 0.0 if (sx * sl < 0.0) else PI
			_leg(mat, Vector3(sx * hw, h, sl * hl), h, r, off)


func _build_chicken(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _mat_c(Color(0.92, 0.90, 0.85))
	var red := _mat_c(Color(0.75, 0.12, 0.1))
	var yel := _mat_c(Color(0.9, 0.7, 0.15), 0.7)
	var dark := _mat_c(Color(0.1, 0.08, 0.07))
	var orange := _mat_c(Color(0.85, 0.45, 0.1))
	var lh := sz * 0.35
	var by := lh + sz * 0.42
	# body oval
	var body := SphereMesh.new(); body.radius = 0.5; body.height = 1.0; body.radial_segments = 10; body.rings = 6
	_mi(body, fur, Vector3(0, by, 0.02), null, Vector3.ZERO, Vector3(sz * 1.05, sz * 0.9, sz * 1.35))
	# tail fluff
	_mi(body, fur, Vector3(0, by + sz * 0.12, -sz * 0.45), null, Vector3(-0.5, 0, 0), Vector3(sz * 0.55, sz * 0.7, sz * 0.55))
	# head
	_mi(body, fur, Vector3(0, by + sz * 0.42, sz * 0.48), null, Vector3.ZERO, Vector3(sz * 0.55, sz * 0.5, sz * 0.55))
	# comb
	var comb := BoxMesh.new(); comb.size = Vector3(sz * 0.08, sz * 0.18, sz * 0.22)
	_mi(comb, red, Vector3(0, by + sz * 0.62, sz * 0.48))
	# wattle
	var wat := SphereMesh.new(); wat.radius = sz * 0.06; wat.height = sz * 0.14
	_mi(wat, red, Vector3(0, by + sz * 0.32, sz * 0.62))
	# beak
	var beak := PrismMesh.new(); beak.size = Vector3(sz * 0.1, sz * 0.08, sz * 0.14)
	_mi(beak, yel, Vector3(0, by + sz * 0.4, sz * 0.72), null, Vector3(PI * 0.5, 0, 0))
	# eyes
	var eye := SphereMesh.new(); eye.radius = sz * 0.035; eye.height = sz * 0.07
	_mi(eye, dark, Vector3(-sz * 0.12, by + sz * 0.48, sz * 0.62))
	_mi(eye, dark, Vector3(sz * 0.12, by + sz * 0.48, sz * 0.62))
	# wings
	_mi(body, fur, Vector3(-sz * 0.42, by, sz * 0.05), null, Vector3.ZERO, Vector3(sz * 0.35, sz * 0.7, sz * 0.9))
	_mi(body, fur, Vector3(sz * 0.42, by, sz * 0.05), null, Vector3.ZERO, Vector3(sz * 0.35, sz * 0.7, sz * 0.9))
	_leg(orange, Vector3(-sz * 0.12, lh, 0.0), lh, sz * 0.04, 0.0, 0.6)
	_leg(orange, Vector3(sz * 0.12, lh, 0.0), lh, sz * 0.04, PI, 0.6)


func _build_deer(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _mat_c(Color(0.55, 0.38, 0.24))
	var cream := _mat_c(Color(0.85, 0.78, 0.65))
	var dark := _mat_c(Color(0.12, 0.1, 0.08))
	var ant := _mat_c(Color(0.55, 0.42, 0.28), 0.75)
	var lh := sz * 0.72
	var by := lh + sz * 0.28
	var body := SphereMesh.new(); body.radius = 0.5; body.height = 1.0; body.radial_segments = 10; body.rings = 6
	_mi(body, fur, Vector3(0, by, 0), null, Vector3.ZERO, Vector3(sz * 0.85, sz * 0.75, sz * 1.55))
	_mi(body, cream, Vector3(0, by - sz * 0.12, 0.05 * sz), null, Vector3.ZERO, Vector3(sz * 0.55, sz * 0.4, sz * 1.1))
	_mi(body, fur, Vector3(0, by + sz * 0.02, sz * 0.55), null, Vector3.ZERO, Vector3(sz * 0.7, sz * 0.65, sz * 0.7))
	_mi(body, fur, Vector3(0, by + sz * 0.02, -sz * 0.55), null, Vector3.ZERO, Vector3(sz * 0.7, sz * 0.65, sz * 0.65))
	# neck
	var neck := CylinderMesh.new(); neck.top_radius = sz * 0.12; neck.bottom_radius = sz * 0.16; neck.height = sz * 0.45; neck.radial_segments = 8
	_mi(neck, fur, Vector3(0, by + sz * 0.28, sz * 0.72), null, Vector3(0.85, 0, 0))
	# head
	_mi(body, fur, Vector3(0, by + sz * 0.55, sz * 0.95), null, Vector3.ZERO, Vector3(sz * 0.42, sz * 0.38, sz * 0.55))
	_mi(body, cream, Vector3(0, by + sz * 0.48, sz * 1.15), null, Vector3.ZERO, Vector3(sz * 0.28, sz * 0.22, sz * 0.35))
	var nose := SphereMesh.new(); nose.radius = sz * 0.05; nose.height = sz * 0.08
	_mi(nose, dark, Vector3(0, by + sz * 0.48, sz * 1.32))
	var eye := SphereMesh.new(); eye.radius = sz * 0.04; eye.height = sz * 0.06
	_mi(eye, dark, Vector3(-sz * 0.14, by + sz * 0.6, sz * 1.08))
	_mi(eye, dark, Vector3(sz * 0.14, by + sz * 0.6, sz * 1.08))
	# ears
	_mi(body, fur, Vector3(-sz * 0.16, by + sz * 0.72, sz * 0.88), null, Vector3(-0.4, 0, 0.5), Vector3(sz * 0.12, sz * 0.28, sz * 0.1))
	_mi(body, fur, Vector3(sz * 0.16, by + sz * 0.72, sz * 0.88), null, Vector3(-0.4, 0, -0.5), Vector3(sz * 0.12, sz * 0.28, sz * 0.1))
	# antlers
	for side in [-1.0, 1.0]:
		var root := Node3D.new()
		root.position = Vector3(side * sz * 0.08, by + sz * 0.72, sz * 0.9)
		_root.add_child(root)
		var a1 := CylinderMesh.new(); a1.top_radius = sz * 0.02; a1.bottom_radius = sz * 0.035; a1.height = sz * 0.4; a1.radial_segments = 5
		_mi(a1, ant, Vector3(side * sz * 0.04, sz * 0.2, 0), root, Vector3(0.2, 0, side * 0.3))
		var a2 := CylinderMesh.new(); a2.top_radius = sz * 0.015; a2.bottom_radius = sz * 0.025; a2.height = sz * 0.22; a2.radial_segments = 5
		_mi(a2, ant, Vector3(side * sz * 0.12, sz * 0.28, 0), root, Vector3(-0.3, 0, side * 1.0))
		_mi(a2, ant, Vector3(side * sz * 0.08, sz * 0.4, -sz * 0.02), root, Vector3(-0.5, 0, side * 0.7))
	# tail
	_mi(body, cream, Vector3(0, by + sz * 0.12, -sz * 0.82), null, Vector3.ZERO, Vector3(sz * 0.15, sz * 0.22, sz * 0.12))
	_legs4(fur, sz * 0.2, sz * 0.42, lh, sz * 0.06)


func _build_boar(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _mat_c(Color(0.28, 0.22, 0.18))
	var snout := _mat_c(Color(0.5, 0.35, 0.3))
	var ivory := _mat_c(Color(0.9, 0.88, 0.8), 0.55)
	var dark := _mat_c(Color(0.08, 0.06, 0.05))
	var lh := sz * 0.38
	var by := lh + sz * 0.4
	var body := SphereMesh.new(); body.radius = 0.5; body.height = 1.0; body.radial_segments = 10; body.rings = 6
	_mi(body, fur, Vector3(0, by, 0), null, Vector3.ZERO, Vector3(sz * 1.15, sz * 0.95, sz * 1.55))
	_mi(body, fur, Vector3(0, by + sz * 0.08, sz * 0.35), null, Vector3.ZERO, Vector3(sz * 1.0, sz * 0.85, sz * 0.85))
	_mi(body, fur, Vector3(0, by + sz * 0.18, sz * 0.1), null, Vector3.ZERO, Vector3(sz * 0.7, sz * 0.45, sz * 0.7)) # hump
	_mi(body, fur, Vector3(0, by, -sz * 0.45), null, Vector3.ZERO, Vector3(sz * 1.0, sz * 0.85, sz * 0.75))
	# head
	_mi(body, fur, Vector3(0, by + sz * 0.12, sz * 0.78), null, Vector3.ZERO, Vector3(sz * 0.7, sz * 0.6, sz * 0.7))
	var sn := CylinderMesh.new(); sn.top_radius = sz * 0.16; sn.bottom_radius = sz * 0.18; sn.height = sz * 0.28; sn.radial_segments = 8
	_mi(sn, snout, Vector3(0, by + sz * 0.05, sz * 1.1), null, Vector3(PI * 0.5, 0, 0))
	var disc := CylinderMesh.new(); disc.top_radius = sz * 0.15; disc.bottom_radius = sz * 0.15; disc.height = sz * 0.05; disc.radial_segments = 10
	_mi(disc, snout, Vector3(0, by + sz * 0.05, sz * 1.26), null, Vector3(PI * 0.5, 0, 0))
	# tusks
	var tusk := CylinderMesh.new(); tusk.top_radius = sz * 0.015; tusk.bottom_radius = sz * 0.03; tusk.height = sz * 0.18; tusk.radial_segments = 5
	_mi(tusk, ivory, Vector3(-sz * 0.1, by + sz * 0.0, sz * 1.12), null, Vector3(1.0, 0, -0.5))
	_mi(tusk, ivory, Vector3(sz * 0.1, by + sz * 0.0, sz * 1.12), null, Vector3(1.0, 0, 0.5))
	var eye := SphereMesh.new(); eye.radius = sz * 0.035; eye.height = sz * 0.05
	_mi(eye, dark, Vector3(-sz * 0.22, by + sz * 0.22, sz * 0.95))
	_mi(eye, dark, Vector3(sz * 0.22, by + sz * 0.22, sz * 0.95))
	# ears
	_mi(body, fur, Vector3(-sz * 0.22, by + sz * 0.35, sz * 0.7), null, Vector3(-0.3, 0, 0.4), Vector3(sz * 0.18, sz * 0.22, sz * 0.1))
	_mi(body, fur, Vector3(sz * 0.22, by + sz * 0.35, sz * 0.7), null, Vector3(-0.3, 0, -0.4), Vector3(sz * 0.18, sz * 0.22, sz * 0.1))
	_legs4(fur, sz * 0.28, sz * 0.4, lh, sz * 0.09)


func _build_bear(sz: float) -> void:
	var fur: Material = body_mat if body_mat else _mat_c(Color(0.22, 0.15, 0.1))
	var muzzle := _mat_c(Color(0.18, 0.12, 0.09))
	var dark := _mat_c(Color(0.05, 0.04, 0.03))
	var lh := sz * 0.48
	var by := lh + sz * 0.45
	var body := SphereMesh.new(); body.radius = 0.5; body.height = 1.0; body.radial_segments = 10; body.rings = 6
	_mi(body, fur, Vector3(0, by, 0), null, Vector3.ZERO, Vector3(sz * 1.2, sz * 1.05, sz * 1.5))
	_mi(body, fur, Vector3(0, by + sz * 0.08, sz * 0.35), null, Vector3.ZERO, Vector3(sz * 1.05, sz * 0.95, sz * 0.9))
	_mi(body, fur, Vector3(0, by + sz * 0.28, sz * 0.12), null, Vector3.ZERO, Vector3(sz * 0.85, sz * 0.55, sz * 0.75)) # shoulder hump
	_mi(body, fur, Vector3(0, by, -sz * 0.4), null, Vector3.ZERO, Vector3(sz * 1.05, sz * 0.95, sz * 0.85))
	# head
	_mi(body, fur, Vector3(0, by + sz * 0.35, sz * 0.72), null, Vector3.ZERO, Vector3(sz * 0.7, sz * 0.65, sz * 0.7))
	_mi(body, muzzle, Vector3(0, by + sz * 0.28, sz * 1.0), null, Vector3.ZERO, Vector3(sz * 0.38, sz * 0.3, sz * 0.45))
	var nose := SphereMesh.new(); nose.radius = sz * 0.07; nose.height = sz * 0.1
	_mi(nose, dark, Vector3(0, by + sz * 0.32, sz * 1.2))
	var eye := SphereMesh.new(); eye.radius = sz * 0.04; eye.height = sz * 0.06
	_mi(eye, dark, Vector3(-sz * 0.16, by + sz * 0.42, sz * 0.95))
	_mi(eye, dark, Vector3(sz * 0.16, by + sz * 0.42, sz * 0.95))
	# round ears
	_mi(body, fur, Vector3(-sz * 0.22, by + sz * 0.58, sz * 0.65), null, Vector3.ZERO, Vector3(sz * 0.22, sz * 0.22, sz * 0.14))
	_mi(body, fur, Vector3(sz * 0.22, by + sz * 0.58, sz * 0.65), null, Vector3.ZERO, Vector3(sz * 0.22, sz * 0.22, sz * 0.14))
	_mi(body, dark, Vector3(-sz * 0.22, by + sz * 0.58, sz * 0.72), null, Vector3.ZERO, Vector3(sz * 0.1, sz * 0.1, sz * 0.06))
	_mi(body, dark, Vector3(sz * 0.22, by + sz * 0.58, sz * 0.72), null, Vector3.ZERO, Vector3(sz * 0.1, sz * 0.1, sz * 0.06))
	# thick shoulders
	_mi(body, fur, Vector3(-sz * 0.42, by + sz * 0.05, sz * 0.25), null, Vector3.ZERO, Vector3(sz * 0.4, sz * 0.55, sz * 0.4))
	_mi(body, fur, Vector3(sz * 0.42, by + sz * 0.05, sz * 0.25), null, Vector3.ZERO, Vector3(sz * 0.4, sz * 0.55, sz * 0.4))
	_legs4(fur, sz * 0.26, sz * 0.35, lh, sz * 0.13)
