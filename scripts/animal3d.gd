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
	var kind_name := ""
	match kind:
		Kind.CHICKEN:
			kind_name = "CHICKEN"
		Kind.DEER:
			kind_name = "DEER"
		Kind.BOAR:
			kind_name = "BOAR"
		Kind.BEAR:
			kind_name = "BEAR"
	var path := AssetLib.animal_path(kind_name)
	var target_h := 1.0
	match kind:
		Kind.CHICKEN:
			target_h = 0.55
		Kind.DEER:
			target_h = 1.35
		Kind.BOAR:
			target_h = 0.95
		Kind.BEAR:
			target_h = 1.7
	var mdl := AssetLib.spawn_model(path, _root, Vector3.ONE, Vector3.ZERO, Vector3.ZERO, target_h)
	if mdl:
		# поставить на землю
		var hnow := AssetLib._approx_height(mdl)
		mdl.position = Vector3(0, 0.0, 0)
		match kind:
			Kind.BOAR:
				_tint_meshes(mdl, Color(0.4, 0.3, 0.24))
				mdl.scale *= Vector3(1.15, 0.9, 1.2)
			Kind.BEAR:
				_tint_meshes(mdl, Color(0.22, 0.15, 0.1))
				mdl.scale *= Vector3(1.2, 1.05, 1.25)
			Kind.CHICKEN:
				_tint_meshes(mdl, Color(0.92, 0.88, 0.8))
	else:
		# minimal fallback box animal
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = sz * 0.5
		sm.height = sz
		mi.mesh = sm
		mi.position = Vector3(0, sz * 0.5, 0)
		if body_mat:
			mi.material_override = body_mat
		_root.add_child(mi)
	# simple animated leg stubs optional skip for asset models
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var ch := target_h
	bs.size = Vector3(ch * 0.9, ch, ch * 1.3)
	col.shape = bs
	col.position = Vector3(0, ch * 0.5, 0)
	add_child(col)


func _tint_meshes(n: Node, color: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		mi.material_override = mat
	for c in n.get_children():
		_tint_meshes(c, color)
