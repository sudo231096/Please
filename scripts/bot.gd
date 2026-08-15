extends CharacterBody3D
## Simple arena bot: chase player, shoot hitscan.

const GRAV := 28.0
const SPEED := 5.2
const MAX_HP := 90

var hp := MAX_HP
var alive := true
var _player: Node3D
var _cool := 0.0
var _nav_t := 0.0
var _dir := Vector3.ZERO
var _mesh: MeshInstance3D
var team_color := Color(1.0, 0.35, 0.3)
var spawn_pos := Vector3.ZERO


func _ready() -> void:
	add_to_group("bots")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.2
	_build_mesh()
	_player = get_tree().get_first_node_in_group("player")


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.2
	_mesh.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = team_color
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 1.0, 0)
	add_child(_mesh)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	head.mesh = sm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.9, 0.75, 0.6)
	head.material_override = hm
	head.position = Vector3(0, 1.75, 0)
	add_child(head)
	# weapon stick
	var gun := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(0.08, 0.08, 0.45)
	gun.mesh = gb
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.15, 0.15, 0.18)
	gun.material_override = gm
	gun.position = Vector3(0.25, 1.15, -0.25)
	add_child(gun)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.4
	col.shape = cs
	col.position = Vector3(0, 1.05, 0)
	add_child(col)


func _physics_process(delta: float) -> void:
	if not alive or Controls.ui_open:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return
	if not ("alive" in _player) or not _player.alive:
		return

	velocity.y -= GRAV * delta
	_nav_t -= delta
	var to_p: Vector3 = _player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if _nav_t <= 0.0:
		_nav_t = randf_range(0.25, 0.55)
		if dist > 1.0:
			_dir = to_p.normalized()
			# strafe
			var side := Vector3(-_dir.z, 0, _dir.x) * (1.0 if randf() > 0.5 else -1.0)
			_dir = (_dir + side * randf_range(0.1, 0.5)).normalized()
		else:
			_dir = Vector3.ZERO
	velocity.x = _dir.x * SPEED
	velocity.z = _dir.z * SPEED
	if _dir.length() > 0.1:
		rotation.y = atan2(_dir.x, _dir.z)
	move_and_slide()

	_cool -= delta
	if dist < 28.0 and _cool <= 0.0 and _can_see_player():
		_shoot()
		_cool = randf_range(0.35, 0.7)


func _can_see_player() -> bool:
	var from := global_position + Vector3(0, 1.5, 0)
	var to := _player.global_position + Vector3(0, 1.5, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	return hit.collider == _player


func _shoot() -> void:
	var from := global_position + Vector3(0, 1.5, 0)
	var aim := _player.global_position + Vector3(randf_range(-0.35, 0.35), 1.4 + randf_range(-0.2, 0.2), randf_range(-0.35, 0.35))
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, aim)
	q.collision_mask = 3 # world + player layer bit1+2? player is layer 2 -> mask bit1 = 2, bit0=1 => 3
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	var end := aim
	if hit:
		end = hit.position
		if hit.collider == _player and _player.has_method("take_damage"):
			_player.take_damage(randi_range(10, 16), self)
	_tracer(from, end)


func _tracer(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var dist := from.distance_to(to)
	c.top_radius = 0.015
	c.bottom_radius = 0.015
	c.height = maxf(dist, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.4, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.1)
	mat.emission_energy_multiplier = 2.0
	c.material = mat
	mi.mesh = c
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	get_tree().create_timer(0.07).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)


func take_damage(amount: int, _from: Node = null) -> void:
	if not alive:
		return
	hp -= amount
	# flash
	if _mesh and _mesh.material_override:
		var m := _mesh.material_override as StandardMaterial3D
		if m:
			m.emission_enabled = true
			m.emission = Color(1, 1, 1)
			m.emission_energy_multiplier = 1.5
			get_tree().create_timer(0.08).timeout.connect(func() -> void:
				if is_instance_valid(m):
					m.emission_energy_multiplier = 0.0
			)
	if hp <= 0:
		_die()


func _die() -> void:
	alive = false
	visible = false
	$CollisionShape3D.disabled = true
	velocity = Vector3.ZERO
	GameState.add_player_kill()
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(self):
		_respawn()


func _respawn() -> void:
	hp = MAX_HP
	alive = true
	visible = true
	$CollisionShape3D.disabled = false
	global_position = spawn_pos + Vector3(randf_range(-3, 3), 1.0, randf_range(-3, 3))
