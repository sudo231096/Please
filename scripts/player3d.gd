extends CharacterBody3D
## FPS-игрок: рука + модели инструментов, прицел-рейкаст, стройка блоков.

const GRAV := 22.0
const SPEED := 6.5
const JUMP := 7.5
const MAX_HP := 100
const BUILD_RANGE := 10.0
const RANGED_RANGE := 55.0
const GRID := 2.0

const BuildableScr := preload("res://scripts/buildable.gd")
const ItemModelsScr := preload("res://scripts/item_models.gd")

var hp := MAX_HP
var hp_max := MAX_HP
var spawn_pos := Vector3.ZERO

var _yaw := 0.0
var _pitch := 0.0
var _cam: Camera3D
var _ray: RayCast3D
var _vm: Node3D
var _hand: Node3D
var _tool_root: Node3D
var _armor_root: Node3D
var _armor_yaw: Node3D
var _fps_armor: Node3D
var _shown_armor := ""
var _models
var _vm_base := Vector3(0.35, -0.4, -0.6)
var _punch := 0.0
var _bob := 0.0
var _shown_tool := "__none__"

var _ghost: MeshInstance3D
var _ghost_mat_ok: StandardMaterial3D
var _ghost_mat_bad: StandardMaterial3D
var _can_build := false
var _build_pos := Vector3.ZERO
var _build_yaw := 0.0


func _ready() -> void:
	add_to_group("player")
	_models = ItemModelsScr.new()
	_cam = $Camera3D
	# не рисовать слой 2 (торс/голова/руки тела) — только ноги при взгляде вниз
	_cam.cull_mask = 1
	_ray = $Camera3D/RayCast3D
	_ray.target_position = Vector3(0, 0, -RANGED_RANGE)
	_ray.collision_mask = 1  # world + animals + builds
	_build_viewmodel()
	_build_body_model()
	_build_ghost()
	_update_armor_model()


func _input(event: InputEvent) -> void:
	if Controls.ui_open:
		return
	if event is InputEventScreenDrag:
		var size := get_viewport().get_visible_rect().size
		if event.position.x > size.x * 0.5 and event.position.y < size.y * 0.7:
			_yaw -= event.relative.x * 0.004
			_pitch -= event.relative.y * 0.004
			_pitch = clampf(_pitch, -1.2, 1.2)


func _physics_process(delta: float) -> void:
	# модели обновляем всегда (экип из меню)
	_update_tool_model()
	_update_armor_model()
	if Controls.ui_open:
		if _ghost:
			_ghost.visible = false
		return
	if hp <= 0:
		_respawn()
		return
	_cam.rotation = Vector3(_pitch, _yaw, 0)
	if _armor_yaw:
		_armor_yaw.rotation.y = _yaw
	velocity.y -= GRAV * delta

	var basis := _cam.global_transform.basis
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var mv := Vector3.ZERO
	mv += right * Controls.move_vector.x
	mv += fwd * -Controls.move_vector.y
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv += fwd
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv -= fwd
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv += right
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv -= right
	if mv.length() > 0.01:
		mv = mv.normalized()

	velocity.x = mv.x * SPEED
	velocity.z = mv.z * SPEED

	if (Controls.jump_queued or Input.is_physical_key_pressed(KEY_SPACE)) and is_on_floor():
		velocity.y = JUMP
	Controls.jump_queued = false

	move_and_slide()

	_update_build_ghost()

	if Controls.attack_queued:
		Controls.attack_queued = false
		if Controls.build_mode:
			_try_build()
		else:
			_use()

	_animate(delta)


func take_damage(amount: int) -> void:
	var def := Inv.total_defense()
	# каждый пункт защиты снимает 1 урон, минимум 1
	var dmg: int = maxi(1, amount - def)
	hp = clampi(hp - dmg, 0, hp_max)


func _respawn() -> void:
	hp = MAX_HP
	global_position = spawn_pos
	velocity = Vector3.ZERO


func _use() -> void:
	_punch = 0.28
	var eq := Controls.equipped
	if eq != "" and Inv.count(eq) <= 0:
		Controls.equipped = ""
		eq = ""
	var base := eq.replace("stone_", "")
	# Дальний бой: лук / арбалет
	if base == "bow" or base == "crossbow":
		_ranged_shot(eq, base)
		return
	_ray.target_position = Vector3(0, 0, -BUILD_RANGE)
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return
	var col = _ray.get_collider()
	if col == null:
		return
	if col.has_method("gather"):
		var rtype := ""
		if "res_type" in col:
			rtype = str(col.res_type)
		var hits := 1
		if rtype == "wood" and (eq == "axe" or eq == "stone_axe"):
			hits = 3 if eq == "stone_axe" else 2
		elif (rtype == "stone" or rtype == "sulfur") and (eq == "pickaxe" or eq == "stone_pickaxe"):
			hits = 3 if eq == "stone_pickaxe" else 2
		for _i in range(hits):
			if not is_instance_valid(col):
				break
			col.gather()
		if eq != "" and Inv.is_tool(eq):
			Inv.use_tool(eq)
			if Inv.count(eq) <= 0:
				Controls.equipped = ""
	elif col.has_method("hit"):
		var dmg := 1
		if eq == "sword" or eq == "stone_sword":
			dmg = 3 if eq == "stone_sword" else 2
		elif eq == "axe" or eq == "stone_axe":
			dmg = 2
		elif eq == "pickaxe" or eq == "stone_pickaxe":
			dmg = 2
		col.hit(dmg)
		if eq != "" and Inv.is_tool(eq):
			Inv.use_tool(eq)
			if Inv.count(eq) <= 0:
				Controls.equipped = ""


func _ranged_shot(eq: String, base: String) -> void:
	_ray.target_position = Vector3(0, 0, -RANGED_RANGE)
	_ray.force_raycast_update()
	var dmg := 2
	if base == "crossbow":
		dmg = 4 if eq.begins_with("stone_") else 3
	else:
		dmg = 3 if eq.begins_with("stone_") else 2
	# визуал снаряда
	var start: Vector3 = _cam.global_position - _cam.global_transform.basis.z * 0.4
	var end: Vector3 = start - _cam.global_transform.basis.z * RANGED_RANGE
	var hit_ok := false
	if _ray.is_colliding():
		end = _ray.get_collision_point()
		var col = _ray.get_collider()
		if col and col.has_method("hit"):
			# только по животным/постройкам, не по ресурсам gather без нужды
			if col.is_in_group("animals") or col.has_method("hit"):
				col.hit(dmg)
				hit_ok = true
	_spawn_tracer(start, end, base == "crossbow")
	if eq != "" and Inv.is_tool(eq):
		Inv.use_tool(eq)
		if Inv.count(eq) <= 0:
			Controls.equipped = ""


func _spawn_tracer(from: Vector3, to: Vector3, bolt: bool) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	var dist := from.distance_to(to)
	c.top_radius = 0.02 if bolt else 0.012
	c.bottom_radius = 0.02 if bolt else 0.012
	c.height = maxf(dist, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.75, 0.45) if bolt else Color(0.75, 0.55, 0.25)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 1.5
	c.material = mat
	mi.mesh = c
	var mid := (from + to) * 0.5
	mi.global_position = mid
	# look along direction
	var dir := (to - from).normalized()
	if dir.length() > 0.01:
		mi.look_at(to, Vector3.UP)
		mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	get_tree().current_scene.add_child(mi)
	# удалить через кадр
	var tmr := get_tree().create_timer(0.12)
	tmr.timeout.connect(func() -> void:
		if is_instance_valid(mi):
			mi.queue_free()
	)


func _try_build() -> void:
	if not _can_build:
		return
	var pid := Controls.build_piece
	if pid == "" or Inv.count(pid) <= 0:
		return
	Inv.remove(pid, 1)
	var node := _make_build_piece(pid)
	node.position = _build_pos
	node.rotation.y = _build_yaw
	get_tree().current_scene.add_child(node)
	_punch = 0.18
	if Inv.count(pid) <= 0:
		# keep mode, but ghost will go bad until craft more
		pass


func _make_build_piece(pid: String) -> StaticBody3D:
	var n := StaticBody3D.new()
	n.set_script(BuildableScr)
	n.piece_id = pid
	n.collision_layer = 1
	n.collision_mask = 1
	var mat := _piece_mat(pid)
	var mesh_i := MeshInstance3D.new()
	var col := CollisionShape3D.new()
	match pid:
		"wood_wall", "stone_wall":
			var bm := BoxMesh.new()
			bm.size = Vector3(4.0, 3.5, 0.35)
			bm.material = mat
			mesh_i.mesh = bm
			mesh_i.position = Vector3(0, 1.75, 0)
			var bs := BoxShape3D.new()
			bs.size = Vector3(4.0, 3.5, 0.35)
			col.shape = bs
			col.position = Vector3(0, 1.75, 0)
			n.hp = 12
		"wood_floor":
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(4.0, 0.25, 4.0)
			bm2.material = mat
			mesh_i.mesh = bm2
			mesh_i.position = Vector3(0, 0.125, 0)
			var bs2 := BoxShape3D.new()
			bs2.size = Vector3(4.0, 0.25, 4.0)
			col.shape = bs2
			col.position = Vector3(0, 0.125, 0)
			n.hp = 10
		"wood_pillar":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.28
			cm.bottom_radius = 0.35
			cm.height = 3.5
			cm.material = mat
			mesh_i.mesh = cm
			mesh_i.position = Vector3(0, 1.75, 0)
			var cs := CylinderShape3D.new()
			cs.radius = 0.35
			cs.height = 3.5
			col.shape = cs
			col.position = Vector3(0, 1.75, 0)
			n.hp = 10
		"campfire":
			var wood := _flat(Color(0.35, 0.22, 0.12))
			var logm := CylinderMesh.new()
			logm.top_radius = 0.08
			logm.bottom_radius = 0.08
			logm.height = 0.7
			logm.material = wood
			var l1 := MeshInstance3D.new()
			l1.mesh = logm
			l1.position = Vector3(0, 0.1, 0)
			l1.rotation = Vector3(0, 0, PI * 0.5)
			n.add_child(l1)
			var l2 := MeshInstance3D.new()
			l2.mesh = logm
			l2.position = Vector3(0, 0.1, 0)
			l2.rotation = Vector3(0, PI * 0.5, PI * 0.5)
			n.add_child(l2)
			var fire_m := SphereMesh.new()
			fire_m.radius = 0.22
			fire_m.height = 0.4
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(1.0, 0.45, 0.08)
			fm.emission_enabled = true
			fm.emission = Color(1.0, 0.35, 0.05)
			fm.emission_energy_multiplier = 2.5
			fire_m.material = fm
			mesh_i.mesh = fire_m
			mesh_i.position = Vector3(0, 0.35, 0)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.25)
			light.light_energy = 1.6
			light.omni_range = 8.0
			light.position = Vector3(0, 0.5, 0)
			n.add_child(light)
			var bs3 := BoxShape3D.new()
			bs3.size = Vector3(0.8, 0.6, 0.8)
			col.shape = bs3
			col.position = Vector3(0, 0.3, 0)
			n.hp = 3
		_:
			# wood_block / stone_block
			var bm3 := BoxMesh.new()
			bm3.size = Vector3(2, 2, 2)
			bm3.material = mat
			mesh_i.mesh = bm3
			mesh_i.position = Vector3(0, 1.0, 0)
			var bs4 := BoxShape3D.new()
			bs4.size = Vector3(2, 2, 2)
			col.shape = bs4
			col.position = Vector3(0, 1.0, 0)
			n.hp = 5 if pid.begins_with("stone") else 4
	n.add_child(mesh_i)
	n.add_child(col)
	return n


func _piece_mat(pid: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	if pid.begins_with("stone"):
		m.albedo_color = Color(0.48, 0.48, 0.50)
	elif pid == "campfire":
		m.albedo_color = Color(0.35, 0.22, 0.12)
	else:
		m.albedo_color = Color(0.45, 0.30, 0.16)
	return m


func _build_ghost() -> void:
	_ghost_mat_ok = StandardMaterial3D.new()
	_ghost_mat_ok.albedo_color = Color(0.3, 0.9, 0.4, 0.35)
	_ghost_mat_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat_ok.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mat_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat_bad = StandardMaterial3D.new()
	_ghost_mat_bad.albedo_color = Color(0.95, 0.25, 0.2, 0.35)
	_ghost_mat_bad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat_bad.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mat_bad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost = MeshInstance3D.new()
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	_ghost.top_level = true
	add_child(_ghost)


func _update_build_ghost() -> void:
	if _ghost == null:
		return
	if not Controls.build_mode or Controls.ui_open:
		_ghost.visible = false
		_can_build = false
		return
	var pid := Controls.build_piece
	if pid == "" or Inv.count(pid) <= 0:
		_ghost.visible = false
		_can_build = false
		return

	_ray.force_raycast_update()
	if not _ray.is_colliding():
		_ghost.visible = false
		_can_build = false
		return

	var hit_pos: Vector3 = _ray.get_collision_point()
	var hit_n: Vector3 = _ray.get_collision_normal()
	var raw := hit_pos + hit_n * 0.51
	# grid snap
	var gx := snappedf(raw.x - 0.5, GRID) + 0.5
	var gz := snappedf(raw.z - 0.5, GRID) + 0.5
	var gy: float
	if pid == "wood_floor":
		gy = snappedf(raw.y, 0.15)
	elif hit_n.y > 0.6:
		gy = snappedf(hit_pos.y, 0.05)
	else:
		gy = snappedf(raw.y - 0.5, GRID)
		if pid in ["wood_wall", "stone_wall", "wood_pillar", "campfire"]:
			pass
		else:
			gy = snappedf(raw.y - 0.5, GRID)

	# blocks sit on ground with y = floor
	if pid in ["wood_block", "stone_block"]:
		if hit_n.y > 0.5:
			gy = hit_pos.y
		else:
			gy = snappedf(raw.y - 0.5, GRID)
		_build_pos = Vector3(gx, gy, gz)
	elif pid in ["wood_wall", "stone_wall", "wood_pillar"]:
		if hit_n.y > 0.5:
			gy = hit_pos.y
		else:
			gy = snappedf(hit_pos.y, GRID)
		_build_pos = Vector3(gx, gy, gz)
	elif pid == "wood_floor":
		gy = hit_pos.y if hit_n.y > 0.5 else raw.y
		_build_pos = Vector3(gx, gy, gz)
	else:
		_build_pos = Vector3(gx, hit_pos.y if hit_n.y > 0.5 else gy, gz)

	_build_yaw = float(Controls.build_rotate % 4) * PI * 0.5

	# ghost mesh
	_ghost.mesh = _ghost_mesh_for(pid)
	_ghost.material_override = _ghost_mat_ok
	# ghost is child of player — set global
	_ghost.global_position = _build_pos + _ghost_offset(pid)
	_ghost.global_rotation = Vector3(0, _build_yaw, 0)
	_ghost.visible = true

	# validity: not too close to player, has piece
	var ppos := global_position
	var dist := Vector2(_build_pos.x - ppos.x, _build_pos.z - ppos.z).length()
	_can_build = dist > 1.1 and Inv.count(pid) > 0
	_ghost.material_override = _ghost_mat_ok if _can_build else _ghost_mat_bad


func _ghost_offset(pid: String) -> Vector3:
	match pid:
		"wood_wall", "stone_wall":
			return Vector3(0, 1.75, 0)
		"wood_floor":
			return Vector3(0, 0.125, 0)
		"wood_pillar":
			return Vector3(0, 1.75, 0)
		"campfire":
			return Vector3(0, 0.3, 0)
		_:
			return Vector3(0, 1.0, 0)


func _ghost_mesh_for(pid: String) -> Mesh:
	match pid:
		"wood_wall", "stone_wall":
			var b := BoxMesh.new()
			b.size = Vector3(4.0, 3.5, 0.35)
			return b
		"wood_floor":
			var b2 := BoxMesh.new()
			b2.size = Vector3(4.0, 0.25, 4.0)
			return b2
		"wood_pillar":
			var c := CylinderMesh.new()
			c.top_radius = 0.28
			c.bottom_radius = 0.35
			c.height = 3.5
			return c
		"campfire":
			var s := SphereMesh.new()
			s.radius = 0.3
			s.height = 0.5
			return s
		_:
			var b3 := BoxMesh.new()
			b3.size = Vector3(2, 2, 2)
			return b3


func _animate(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var move_amt: float = clampf(hspeed / SPEED, 0.0, 1.0)
	if hspeed > 0.3:
		_bob += delta * 11.0
	var bob_y: float = sin(_bob) * 0.035 * move_amt
	var bob_x: float = sin(_bob * 0.5) * 0.02 * move_amt
	_cam.position = Vector3(bob_x, 1.6 + bob_y, 0.0)

	if _punch > 0.0:
		_punch -= delta
		var prog: float = 1.0 - clampf(_punch / 0.28, 0.0, 1.0)
		var thrust: float = sin(prog * PI) * 0.35
		_vm.position = Vector3(_vm_base.x, _vm_base.y + bob_y * 0.6, _vm_base.z - thrust)
		_vm.rotation.x = -thrust * 0.8
	else:
		_vm.position = Vector3(_vm_base.x, _vm_base.y + bob_y * 0.6, _vm_base.z)
		_vm.rotation.x = 0.0



func _build_body_model() -> void:
	# Oxide-like survivor body (hoodie + jeans + boots). Torso on layer 2 (hidden in FPS).
	if _armor_yaw == null:
		_armor_yaw = Node3D.new()
		_armor_yaw.name = "ArmorYaw"
		add_child(_armor_yaw)
	var body := Node3D.new()
	body.name = "PlayerBody"
	_armor_yaw.add_child(body)
	var skin := _flat(Color(0.86, 0.68, 0.52))
	var hoodie := _flat(Color(0.22, 0.28, 0.24))  # muted green-grey
	var jeans := _flat(Color(0.18, 0.22, 0.32))
	var boot := _flat(Color(0.12, 0.09, 0.07))
	var hair := _flat(Color(0.14, 0.1, 0.07))
	var strap := _flat(Color(0.25, 0.2, 0.14))
	# torso hoodie
	var torso := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.5, 0.62, 0.3)
	torso.mesh = tb
	torso.material_override = hoodie
	torso.position = Vector3(0, 1.2, 0)
	torso.layers = 2
	body.add_child(torso)
	# hoodie hood bulge back
	var hood := MeshInstance3D.new()
	var hs0 := SphereMesh.new()
	hs0.radius = 0.16
	hs0.height = 0.28
	hood.mesh = hs0
	hood.material_override = hoodie
	hood.position = Vector3(0, 1.48, -0.12)
	hood.scale = Vector3(1.1, 0.7, 0.9)
	hood.layers = 2
	body.add_child(hood)
	# shoulders
	for sx in [-0.28, 0.28]:
		var sh := MeshInstance3D.new()
		var ss := SphereMesh.new()
		ss.radius = 0.11
		ss.height = 0.2
		sh.mesh = ss
		sh.material_override = hoodie
		sh.position = Vector3(sx, 1.42, 0)
		sh.layers = 2
		body.add_child(sh)
	# head
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.16
	hs.height = 0.32
	head.mesh = hs
	head.material_override = skin
	head.position = Vector3(0, 1.62, 0.02)
	head.layers = 2
	body.add_child(head)
	var hair_m := MeshInstance3D.new()
	var hh := SphereMesh.new()
	hh.radius = 0.17
	hh.height = 0.26
	hair_m.mesh = hh
	hair_m.material_override = hair
	hair_m.position = Vector3(0, 1.72, -0.03)
	hair_m.scale = Vector3(1.05, 0.65, 1.05)
	hair_m.layers = 2
	body.add_child(hair_m)
	# backpack scrap
	var pack := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.32, 0.4, 0.14)
	pack.mesh = pb
	pack.material_override = strap
	pack.position = Vector3(0, 1.22, -0.22)
	pack.layers = 2
	body.add_child(pack)
	# legs jeans
	for sx in [-0.12, 0.12]:
		var thigh := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.095
		tc.bottom_radius = 0.085
		tc.height = 0.42
		tc.radial_segments = 8
		thigh.mesh = tc
		thigh.material_override = jeans
		thigh.position = Vector3(sx, 0.72, 0)
		body.add_child(thigh)
		var shin := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.08
		sc.bottom_radius = 0.07
		sc.height = 0.4
		sc.radial_segments = 8
		shin.mesh = sc
		shin.material_override = jeans
		shin.position = Vector3(sx, 0.32, 0)
		body.add_child(shin)
		var ft := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.13, 0.1, 0.3)
		ft.mesh = fb
		ft.material_override = boot
		ft.position = Vector3(sx, 0.06, 0.07)
		body.add_child(ft)
	# arms
	for sx2 in [-0.38, 0.38]:
		var arm := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.06
		ac.bottom_radius = 0.065
		ac.height = 0.52
		ac.radial_segments = 8
		arm.mesh = ac
		arm.material_override = hoodie
		arm.position = Vector3(sx2, 1.18, 0)
		arm.rotation.z = 0.18 if sx2 < 0 else -0.18
		arm.layers = 2
		body.add_child(arm)


func _build_viewmodel() -> void:
	_vm = Node3D.new()
	_vm.position = _vm_base
	_cam.add_child(_vm)

	var skin := _flat(Color(0.86, 0.68, 0.52))
	# рука
	_hand = Node3D.new()
	_vm.add_child(_hand)
	var upper := MeshInstance3D.new()
	var cm1 := CylinderMesh.new()
	cm1.top_radius = 0.08
	cm1.bottom_radius = 0.07
	cm1.height = 0.28
	cm1.material = skin
	upper.mesh = cm1
	upper.position = Vector3(0, -0.1, 0.1)
	upper.rotation.x = -0.9
	_hand.add_child(upper)
	var fore := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.07
	cm2.bottom_radius = 0.06
	cm2.height = 0.26
	cm2.material = skin
	fore.mesh = cm2
	fore.position = Vector3(0, -0.32, 0.28)
	fore.rotation.x = -1.3
	_hand.add_child(fore)
	var fist := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.1
	bm.height = 0.2
	bm.material = skin
	fist.mesh = bm
	fist.position = Vector3(0, -0.46, 0.42)
	_hand.add_child(fist)

	# корень инструмента у кулака, ось модели: +Z вперёд от камеры
	_tool_root = Node3D.new()
	# кулак справа внизу; меч стоит вверх
	_tool_root.position = Vector3(0.08, -0.32, -0.28)
	_tool_root.rotation = Vector3(-0.35, 0.15, 0.25)
	_tool_root.scale = Vector3(1.25, 1.25, 1.25)
	_vm.add_child(_tool_root)

	# FPS-накладки брони на камере
	_fps_armor = Node3D.new()
	_fps_armor.name = "FpsArmor"
	_cam.add_child(_fps_armor)

	# тело-броня крутится с yaw камеры
	if _armor_yaw == null:
		_armor_yaw = Node3D.new()
		_armor_yaw.name = "ArmorYaw"
		add_child(_armor_yaw)
	if _armor_root == null:
		_armor_root = Node3D.new()
		_armor_root.name = "ArmorBody"
		_armor_yaw.add_child(_armor_root)


func _update_tool_model() -> void:
	if _tool_root == null or _models == null:
		return
	var eq := Controls.equipped
	if eq != "" and Inv.count(eq) <= 0:
		eq = ""
		Controls.equipped = ""
	var key := eq if eq != "" else ""
	if key == _shown_tool:
		return
	_shown_tool = key
	while _tool_root.get_child_count() > 0:
		var c := _tool_root.get_child(0)
		_tool_root.remove_child(c)
		c.free()
	if key == "":
		_hand.visible = true
		return
	_hand.visible = true
	_models.build_tool(_tool_root, key)


func _update_armor_model() -> void:
	if _models == null:
		return
	var key := "%s|%s|%s|%s" % [
		str(Inv.armor.get("head", "")),
		str(Inv.armor.get("chest", "")),
		str(Inv.armor.get("legs", "")),
		str(Inv.armor.get("feet", "")),
	]
	if key == _shown_armor and _armor_root != null:
		return
	_shown_armor = key

	if _armor_root == null:
		return
	while _armor_root.get_child_count() > 0:
		var c := _armor_root.get_child(0)
		_armor_root.remove_child(c)
		c.free()
	if _fps_armor:
		while _fps_armor.get_child_count() > 0:
			var c2 := _fps_armor.get_child(0)
			_fps_armor.remove_child(c2)
			c2.free()

	# ноги/ботинки — на теле (видно если смотреть вниз)
	for slot in ["legs", "feet"]:
		var pid := str(Inv.armor.get(slot, ""))
		if pid == "":
			continue
		var holder := Node3D.new()
		holder.name = slot
		_armor_root.add_child(holder)
		_models.build_armor_piece(holder, pid, false)

	# нагрудник только на теле (не лезет в FPS-экран)
	var chest_id := str(Inv.armor.get("chest", ""))
	if chest_id != "":
		var ch := Node3D.new()
		ch.name = "chest"
		_armor_root.add_child(ch)
		_models.build_armor_piece(ch, chest_id, false)

	# шлем — FPS-накладка по краям экрана
	var helm_id := str(Inv.armor.get("head", ""))
	if helm_id != "" and _fps_armor:
		var hh := Node3D.new()
		hh.name = "helm_fps"
		_fps_armor.add_child(hh)
		_models.build_armor_piece(hh, helm_id, true)


func _flat(color: Color) -> StandardMaterial3D:
	if _models:
		return _models.mat(color)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
