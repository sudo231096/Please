extends Node3D
## Простая сцена с выбранным агентом (Камера Мен по умолчанию).

const UI = preload("res://scripts/ui_theme.gd")

var _player: CharacterBody3D
var _yaw := 0.0
var _pitch := 0.0
var _cam: Camera3D
var _info: Label


func _ready() -> void:
	_build_world()
	_spawn_agent()
	_build_hud()


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.8
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.1
	add_child(sun)

	# floor
	var floor_b := StaticBody3D.new()
	var fmi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(40, 1, 40)
	fmi.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.22, 0.25, 0.28)
	fmi.material_override = fmat
	floor_b.add_child(fmi)
	var fcol := CollisionShape3D.new()
	var fcs := BoxShape3D.new()
	fcs.size = Vector3(40, 1, 40)
	fcol.shape = fcs
	floor_b.add_child(fcol)
	floor_b.position = Vector3(0, -0.5, 0)
	add_child(floor_b)

	# simple blocks
	for i in range(8):
		var b := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(1.5, 3.0), randf_range(1.0, 2.5), randf_range(1.5, 3.0))
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.33, 0.38)
		mi.material_override = mat
		b.add_child(mi)
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = box.size
		col.shape = cs
		b.add_child(col)
		b.position = Vector3(randf_range(-12, 12), box.size.y * 0.5, randf_range(-12, 12))
		add_child(b)


func _spawn_agent() -> void:
	_player = CharacterBody3D.new()
	_player.collision_layer = 2
	_player.collision_mask = 1
	_player.position = Vector3(0, 1.2, 6)
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.4
	col.shape = cs
	col.position = Vector3(0, 1.05, 0)
	_player.add_child(col)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.6, 0)
	_cam.current = true
	_cam.fov = 72.0
	_player.add_child(_cam)
	add_child(_player)
	_build_camera_man_model(_player)
	# mark
	_player.set_meta("agent", GameData.selected_agent)


func _build_camera_man_model(parent: Node3D) -> void:
	# body visible when looking down a bit - third person-ish attachment on player root
	var root := Node3D.new()
	root.name = "AgentModel"
	parent.add_child(root)

	var info: Dictionary = GameData.AGENTS.get(GameData.selected_agent, GameData.AGENTS["camera_man"])
	var body_c: Color = info["color"]
	var accent: Color = info["accent"]

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.1
	body.mesh = cap
	var bm := StandardMaterial3D.new()
	bm.albedo_color = body_c
	body.material_override = bm
	body.position = Vector3(0, 0.95, 0)
	# hide from FPS cam: put behind slightly? keep for now on layer default - user sees hands
	root.add_child(body)

	# head by agent type
	var agent_id := str(GameData.selected_agent)
	if agent_id == "speakerman":
		var head := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.22
		hc.bottom_radius = 0.22
		hc.height = 0.35
		head.mesh = hc
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.2, 0.2, 0.22)
		hm.metallic = 0.5
		head.material_override = hm
		head.position = Vector3(0, 1.72, 0)
		root.add_child(head)
		var cone := MeshInstance3D.new()
		var pr := CylinderMesh.new()
		pr.top_radius = 0.28
		pr.bottom_radius = 0.08
		pr.height = 0.25
		cone.mesh = pr
		var cm := StandardMaterial3D.new()
		cm.albedo_color = accent
		cone.material_override = cm
		cone.rotation_degrees = Vector3(90, 0, 0)
		cone.position = Vector3(0, 1.72, -0.22)
		root.add_child(cone)
	elif agent_id == "tv_man":
		var head := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.55, 0.4, 0.2)
		head.mesh = hb
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.12, 0.12, 0.14)
		head.material_override = hm
		head.position = Vector3(0, 1.72, 0)
		root.add_child(head)
		var screen := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.45, 0.3, 0.04)
		screen.mesh = sb
		var sm := StandardMaterial3D.new()
		sm.albedo_color = accent
		sm.emission_enabled = true
		sm.emission = accent
		sm.emission_energy_multiplier = 1.2
		screen.material_override = sm
		screen.position = Vector3(0, 1.72, -0.12)
		root.add_child(screen)
	else:
		# Камера Мен
		var head := MeshInstance3D.new()
		var hb := BoxMesh.new()
		hb.size = Vector3(0.42, 0.32, 0.38)
		head.mesh = hb
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.15, 0.16, 0.18)
		hm.metallic = 0.4
		hm.roughness = 0.45
		head.material_override = hm
		head.position = Vector3(0, 1.7, 0)
		root.add_child(head)
		var lens := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.1
		lc.bottom_radius = 0.12
		lc.height = 0.18
		lens.mesh = lc
		var lm := StandardMaterial3D.new()
		lm.albedo_color = accent
		lm.emission_enabled = true
		lm.emission = accent
		lm.emission_energy_multiplier = 0.8
		lens.material_override = lm
		lens.rotation_degrees = Vector3(90, 0, 0)
		lens.position = Vector3(0, 1.7, -0.25)
		root.add_child(lens)

	# FP hands
	var hand := MeshInstance3D.new()
	var hmesh := BoxMesh.new()
	hmesh.size = Vector3(0.12, 0.12, 0.3)
	hand.mesh = hmesh
	var handm := StandardMaterial3D.new()
	handm.albedo_color = Color(0.85, 0.7, 0.55)
	hand.material_override = handm
	hand.position = Vector3(0.28, -0.25, -0.4)
	_cam.add_child(hand)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_info = UI.make_label("", 22, Color(0.85, 0.95, 1.0))
	_info.offset_left = 16
	_info.offset_top = 16
	_info.offset_right = 600
	_info.offset_bottom = 80
	root.add_child(_info)
	_info.text = "Агент: %s\nWASD/джойстик · свайп — камера · ESC/Меню" % GameData.agent_name(GameData.selected_agent)

	var menu := UI.make_btn("МЕНЮ", Vector2(120, 52), 20)
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -140
	menu.offset_right = -16
	menu.offset_top = 16
	menu.offset_bottom = 68
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	root.add_child(menu)

	# simple touch look + move via buttons for mobile
	_build_mobile_controls(root)


var _move := Vector2.ZERO
var _touch_look := -1
var _last_look := Vector2.ZERO


func _build_mobile_controls(root: Control) -> void:
	# look zone right
	var look := Control.new()
	look.set_anchors_preset(Control.PRESET_FULL_RECT)
	look.anchor_left = 0.4
	look.mouse_filter = Control.MOUSE_FILTER_STOP
	look.gui_input.connect(_on_look_input)
	root.add_child(look)

	# move buttons left
	var panel := HBoxContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16
	panel.offset_top = -150
	panel.offset_right = 360
	panel.offset_bottom = -16
	panel.add_theme_constant_override("separation", 8)
	root.add_child(panel)
	for item in [["◀", Vector2(-1, 0)], ["▲", Vector2(0, -1)], ["▼", Vector2(0, 1)], ["▶", Vector2(1, 0)]]:
		var b := UI.make_btn(str(item[0]), Vector2(70, 70), 26)
		var dir: Vector2 = item[1]
		b.button_down.connect(func() -> void: _move += dir)
		b.button_up.connect(func() -> void: _move -= dir)
		panel.add_child(b)


func _on_look_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_look == -1:
			_touch_look = event.index
			_last_look = event.position
		elif (not event.pressed) and event.index == _touch_look:
			_touch_look = -1
	elif event is InputEventScreenDrag and event.index == _touch_look:
		var d: Vector2 = event.position - _last_look
		_last_look = event.position
		_yaw -= d.x * 0.005
		_pitch -= d.y * 0.005
		_pitch = clampf(_pitch, -1.2, 1.2)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.004
		_pitch -= event.relative.y * 0.004
		_pitch = clampf(_pitch, -1.2, 1.2)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_player.rotation.y = _yaw
	_cam.rotation.x = _pitch

	var basis := Basis(Vector3.UP, _yaw)
	var fwd: Vector3 = -basis.z
	var right: Vector3 = basis.x
	var mv := Vector3.ZERO
	mv += right * _move.x
	mv += fwd * -_move.y
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
	_player.velocity.x = mv.x * 6.5
	_player.velocity.z = mv.z * 6.5
	_player.velocity.y -= 24.0 * delta
	if Input.is_physical_key_pressed(KEY_SPACE) and _player.is_on_floor():
		_player.velocity.y = 7.0
	_player.move_and_slide()

	if Input.is_physical_key_pressed(KEY_ESCAPE):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
