extends Node3D
## Главное меню: 3D-модель игрока (скачанная), статичная камера, кнопка «Играть», настройки.

var _settings: Control
var _sens_l: Label
var _layout_btn: Button


func _ready() -> void:
	_build_world()
	_build_player_model()
	_build_ui()


func _mat(color: Color, emissive := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive.a > 0.0:
		m.emission_enabled = true
		m.emission = emissive
	return m


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(color)
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _sphere(r: float, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.material_override = _mat(color)
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


func _cyl(r: float, h: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.material_override = _mat(color)
	add_child(m)
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 5.0
	sm.height = 10.0
	disc.mesh = sm
	disc.material_override = _mat(Color(1.0, 0.95, 0.7), Color(1.0, 0.9, 0.5))
	disc.position = Vector3(0, 60, -50)
	add_child(disc)

	# земля
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	g.material_override = _mat(Color(0.36, 0.3, 0.2))
	g.position = Vector3(0, -0.01, 0)
	add_child(g)

	# деревья на фоне
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(12):
		var ang := rng.randf() * TAU
		var r := rng.randf_range(6.0, 20.0)
		var x := cos(ang) * r
		var z := sin(ang) * r - 4.0
		var h := rng.randf_range(3.0, 5.5)
		var trunk := _cyl(0.15, h, Color(0.35, 0.24, 0.12))
		trunk.position = Vector3(x, h * 0.5, z)
		var crown := _sphere(1.2, Vector3(x, h + 0.4, z), Color(0.2, 0.38, 0.16))
	# камни
	for i in range(10):
		var ang := rng.randf() * TAU
		var r := rng.randf_range(5.0, 16.0)
		var rock := _sphere(rng.randf_range(0.3, 0.8), Vector3(cos(ang) * r, 0.2, sin(ang) * r - 4.0), Color(0.42, 0.42, 0.45))

	# камера (статичная, смотрит на модель)
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 45
	add_child(cam)
	cam.global_position = Vector3(0, 1.5, 2.5)
	cam.look_at(Vector3(0, 1.1, -3.0), Vector3.UP)


func _build_player_model() -> void:
	# скачанная модель игрока (мускулистый варвар в духе Rust)
	var model: Node3D = preload("res://models/player.glb").instantiate()
	add_child(model)
	# модель ~25.6 юнитов ростом -> подгоняем под 1.8 м
	model.scale = Vector3.ONE * (1.8 / 25.6)
	model.rotation_degrees = Vector3(0, 180, 0)  # лицом к камере
	# скрыть оружие (копьё, булаву, кинжал) — в Rust игрок без оружия в меню
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(m.name)
		if nm.contains("weapon") or nm.contains("spear") or nm.contains("mace") or nm.contains("dagger"):
			m.visible = false
	# поставить на землю по габаритам
	await get_tree().process_frame
	await get_tree().process_frame
	var mn := Vector3(1e9, 1e9, 1e9)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if not m.visible:
			continue
		var aabb: AABB = m.mesh.get_aabb()
		var t: Transform3D = m.global_transform
		for i in range(8):
			var p: Vector3 = aabb.position + Vector3(
				aabb.size.x if (i & 1) != 0 else 0.0,
				aabb.size.y if (i & 2) != 0 else 0.0,
				aabb.size.z if (i & 4) != 0 else 0.0)
			p = t * p
			mn = mn.min(p)
	model.position += Vector3(0, -mn.y, 0)
	model.position.z = -3.0


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var title := Label.new()
	title.text = "SCRAPLANDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.1
	title.anchor_right = 0.9
	title.offset_top = 30
	title.offset_bottom = 100
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(0.95, 0.85, 0.6)
	layer.add_child(title)

	# кнопка ИГРАТЬ (справа внизу)
	var play := Button.new()
	play.text = "ИГРАТЬ"
	play.focus_mode = Control.FOCUS_NONE
	play.anchor_left = 1.0
	play.anchor_right = 1.0
	play.anchor_top = 1.0
	play.anchor_bottom = 1.0
	play.offset_left = -260
	play.offset_right = -40
	play.offset_top = -130
	play.offset_bottom = -50
	play.add_theme_font_size_override("font_size", 32)
	play.modulate = Color(0.5, 1.0, 0.55)
	play.pressed.connect(_start_game)
	layer.add_child(play)

	# кнопка НАСТРОЙКИ (слева вверху)
	var settings_btn := Button.new()
	settings_btn.text = "НАСТРОЙКИ"
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.offset_left = 20
	settings_btn.offset_top = 20
	settings_btn.offset_right = 200
	settings_btn.offset_bottom = 70
	settings_btn.add_theme_font_size_override("font_size", 22)
	settings_btn.modulate = Color(0.6, 0.75, 0.95)
	settings_btn.pressed.connect(func() -> void:
		_settings.visible = not _settings.visible
	)
	layer.add_child(settings_btn)

	_build_settings(layer)


func _build_settings(layer: CanvasLayer) -> void:
	_settings = Control.new()
	_settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.visible = false
	layer.add_child(_settings)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -250
	panel.offset_bottom = 250
	_settings.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	var t := Label.new()
	t.text = "НАСТРОЙКИ"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.modulate = Color(0.6, 0.75, 0.95)
	v.add_child(t)

	_sens_l = Label.new()
	_sens_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sens_l.add_theme_font_size_override("font_size", 22)
	v.add_child(_sens_l)

	var slider := HSlider.new()
	slider.min_value = 0.0005
	slider.max_value = 0.006
	slider.step = 0.0001
	slider.value = GameState.mouse_sens
	slider.value_changed.connect(func(val: float) -> void:
		GameState.mouse_sens = val
		GameState.save_settings()
		_refresh_settings()
	)
	v.add_child(slider)

	var sep := HSeparator.new()
	v.add_child(sep)

	_layout_btn = Button.new()
	_layout_btn.focus_mode = Control.FOCUS_NONE
	_layout_btn.add_theme_font_size_override("font_size", 22)
	_layout_btn.pressed.connect(func() -> void:
		GameState.buttons_left = not GameState.buttons_left
		GameState.save_settings()
		_refresh_settings()
	)
	v.add_child(_layout_btn)

	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void:
		_settings.visible = false
	)
	v.add_child(close)

	_refresh_settings()


func _refresh_settings() -> void:
	_sens_l.text = "Чувствительность: %.4f" % GameState.mouse_sens
	_layout_btn.text = "Кнопки: %s" % ("СЛЕВА" if GameState.buttons_left else "СПРАВА")


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
