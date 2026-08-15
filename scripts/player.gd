extends CharacterBody3D
## FPS player with weapons, hitscan, mobile controls.

const Weapons = preload("res://scripts/weapons.gd")

const GRAV := 28.0
const SPEED := 7.0
const JUMP_V := 8.0
const LOOK_SENS := 0.0038
const MAX_HP := 100

var hp := MAX_HP
var alive := true
var spawn_pos := Vector3.ZERO

var _yaw := 0.0
var _pitch := 0.0
var _cam: Camera3D
var _ray: RayCast3D
var _vm: Node3D
var _gun_mesh: MeshInstance3D
var _muzzle: Marker3D
var _bob := 0.0
var _recoil := 0.0

var _wpn_id := "glock"
var _mag := 12
var _reserve := 48
var _cooldown := 0.0
var _reloading := false
var _reload_t := 0.0
var _wpn_idx := 0

signal died
signal stats_changed


func _ready() -> void:
	add_to_group("player")
	_cam = $Camera3D
	_ray = $Camera3D/RayCast3D
	_ray.target_position = Vector3(0, 0, -80)
	_ray.collision_mask = 1
	floor_snap_length = 0.25
	_build_viewmodel()
	_equip(Weapons.order()[_wpn_idx])
	stats_changed.emit()


func _build_viewmodel() -> void:
	_vm = Node3D.new()
	_vm.position = Vector3(0.28, -0.25, -0.45)
	_cam.add_child(_vm)
	_gun_mesh = MeshInstance3D.new()
	_vm.add_child(_gun_mesh)
	_muzzle = Marker3D.new()
	_muzzle.position = Vector3(0, 0.03, -0.35)
	_vm.add_child(_muzzle)
	# hand stub
	var hand := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.1, 0.1, 0.22)
	hand.mesh = hb
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.68, 0.52)
	hand.material_override = hm
	hand.position = Vector3(0.02, -0.08, 0.12)
	_vm.add_child(hand)


func _equip(id: String) -> void:
	_wpn_id = id
	var w: Dictionary = Weapons.table()[id]
	_mag = int(w["mag"])
	_reserve = int(w["reserve"])
	_reloading = false
	_reload_t = 0.0
	_cooldown = 0.0
	_rebuild_gun_mesh(w)
	stats_changed.emit()


func _rebuild_gun_mesh(w: Dictionary) -> void:
	var length: float = float(w["length"])
	var body := BoxMesh.new()
	body.size = Vector3(0.08, 0.1, length)
	_gun_mesh.mesh = body
	var mat := StandardMaterial3D.new()
	mat.albedo_color = w["color"]
	mat.roughness = 0.55
	mat.metallic = 0.35
	_gun_mesh.material_override = mat
	_gun_mesh.position = Vector3(0, 0, -length * 0.35)
	# accent barrel tip
	if _gun_mesh.get_child_count() > 0:
		for c in _gun_mesh.get_children():
			c.queue_free()
	var tip := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.05, 0.05, 0.12)
	tip.mesh = tb
	var tm := StandardMaterial3D.new()
	tm.albedo_color = w["accent"]
	tm.emission_enabled = true
	tm.emission = w["accent"]
	tm.emission_energy_multiplier = 0.5
	tip.material_override = tm
	tip.position = Vector3(0, 0.02, -length * 0.5)
	_gun_mesh.add_child(tip)
	_muzzle.position = Vector3(0, 0.03, -length * 0.55 - 0.05)


func current_weapon() -> Dictionary:
	return Weapons.table()[_wpn_id]


func weapon_title() -> String:
	return str(current_weapon()["title"])


func _input(event: InputEvent) -> void:
	if Controls.ui_open or not alive:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		Controls.look_delta += event.relative


func _physics_process(delta: float) -> void:
	if Controls.ui_open or not alive:
		return

	# look
	var look := Controls.consume_look()
	_yaw -= look.x * LOOK_SENS
	_pitch -= look.y * LOOK_SENS
	# desktop look with mouse motion captured? use arrow residual
	_pitch = clampf(_pitch, -1.25, 1.25)
	rotation.y = _yaw
	_cam.rotation.x = _pitch - _recoil
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)

	# move
	velocity.y -= GRAV * delta
	var basis_y := Basis(Vector3.UP, _yaw)
	var fwd: Vector3 = -basis_y.z
	var right: Vector3 = basis_y.x
	var mv := Vector3.ZERO
	mv += right * Controls.move_vector.x
	mv += fwd * -Controls.move_vector.y
	if Input.is_physical_key_pressed(KEY_W):
		mv += fwd
	if Input.is_physical_key_pressed(KEY_S):
		mv -= fwd
	if Input.is_physical_key_pressed(KEY_D):
		mv += right
	if Input.is_physical_key_pressed(KEY_A):
		mv -= right
	if mv.length() > 0.01:
		mv = mv.normalized()
		_bob += delta * 12.0
	velocity.x = mv.x * SPEED
	velocity.z = mv.z * SPEED
	if (Controls.jump_queued or Input.is_physical_key_pressed(KEY_SPACE)) and is_on_floor():
		velocity.y = JUMP_V
	Controls.jump_queued = false
	move_and_slide()
	_cam.position = Vector3(sin(_bob) * 0.02, 1.6 + absf(sin(_bob)) * 0.025 * mv.length(), 0)

	# weapons
	if _cooldown > 0.0:
		_cooldown -= delta
	if _reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_finish_reload()
	else:
		var w := current_weapon()
		var want_fire := Controls.fire_held or Controls.fire_pressed or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_K)
		if Controls.fire_pressed:
			Controls.fire_pressed = false
		if want_fire and _cooldown <= 0.0:
			if _mag > 0:
				_fire()
				if not bool(w["auto"]):
					Controls.fire_held = false
			elif _reserve > 0:
				_start_reload()

	if Controls.reload_queued or Input.is_physical_key_pressed(KEY_R):
		Controls.reload_queued = false
		_start_reload()
	if Controls.switch_queued or Input.is_physical_key_pressed(KEY_Q):
		Controls.switch_queued = false
		_cycle_weapon()

	# vm sway
	_vm.position = Vector3(0.28, -0.25 - _recoil * 0.05, -0.45 + _recoil * 0.08)
	_vm.rotation.x = -_recoil * 0.4


func _cycle_weapon() -> void:
	if _reloading:
		return
	var order := Weapons.order()
	_wpn_idx = (_wpn_idx + 1) % order.size()
	_equip(str(order[_wpn_idx]))


func _start_reload() -> void:
	if _reloading or not alive:
		return
	var w := current_weapon()
	var cap := int(w["mag"])
	if _mag >= cap or _reserve <= 0:
		return
	_reloading = true
	_reload_t = float(w["reload"])
	stats_changed.emit()


func _finish_reload() -> void:
	var w := current_weapon()
	var cap := int(w["mag"])
	var need := cap - _mag
	var take: int = mini(need, _reserve)
	_mag += take
	_reserve -= take
	_reloading = false
	_reload_t = 0.0
	stats_changed.emit()


func _fire() -> void:
	var w := current_weapon()
	_mag -= 1
	_cooldown = 60.0 / float(w["rpm"])
	_recoil = minf(_recoil + 0.06 + float(w["spread"]) * 2.0, 0.25)
	stats_changed.emit()

	# spread ray
	var spread: float = float(w["spread"])
	var dir := -_cam.global_transform.basis.z
	dir += _cam.global_transform.basis.x * randf_range(-spread, spread)
	dir += _cam.global_transform.basis.y * randf_range(-spread, spread)
	dir = dir.normalized()
	var from := _cam.global_position
	var to := from + dir * 90.0

	_ray.target_position = _cam.to_local(to)
	# better: direct space state
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	var end := to
	if hit:
		end = hit.position
		var col = hit.collider
		if col and col.has_method("take_damage"):
			var dmg := int(w["damage"])
			# headshot if high hit
			if hit.position.y > col.global_position.y + 1.35:
				dmg = int(float(dmg) * 1.75)
			col.take_damage(dmg, self)
	_spawn_tracer(from + dir * 0.6, end)
	_muzzle_flash()


func _muzzle_flash() -> void:
	var f := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	f.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.2)
	m.emission_energy_multiplier = 3.0
	f.material_override = m
	_muzzle.add_child(f)
	get_tree().create_timer(0.05).timeout.connect(func() -> void:
		if is_instance_valid(f):
			f.queue_free()
	)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var dist := from.distance_to(to)
	c.top_radius = 0.012
	c.bottom_radius = 0.012
	c.height = maxf(dist, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.0
	c.material = mat
	mi.mesh = c
	var mid := (from + to) * 0.5
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root
	parent.add_child(mi)
	mi.global_position = mid
	mi.look_at(to, Vector3.UP)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	get_tree().create_timer(0.06).timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)


func take_damage(amount: int, _from: Node = null) -> void:
	if not alive:
		return
	hp = maxi(0, hp - amount)
	stats_changed.emit()
	if hp <= 0:
		_die()


func _die() -> void:
	alive = false
	velocity = Vector3.ZERO
	died.emit()
	GameState.add_bot_kill()
	# respawn soon
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		respawn()


func respawn() -> void:
	hp = MAX_HP
	alive = true
	global_position = spawn_pos + Vector3(randf_range(-2, 2), 1.5, randf_range(-2, 2))
	velocity = Vector3.ZERO
	_reloading = false
	var w := current_weapon()
	_mag = int(w["mag"])
	stats_changed.emit()


func ammo_text() -> String:
	if _reloading:
		return "REL..."
	return "%d / %d" % [_mag, _reserve]
