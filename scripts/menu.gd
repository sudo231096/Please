extends Node3D
## Главное меню: 3D-модель игрока, кнопка «Играть» справа внизу, настройки слева вверху.

var _cam: Camera3D
var _angle := 0.0
var _settings: Control
var _sens_l: Label
var _layout_btn: Button


func _ready() -> void:
	_build_world()
	_build_ui()


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(color)
	m.position = pos
	parent.add_child(m)
	return m


func _sphere(r: float, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.material_override = _mat(color)
	m.position = pos
	parent.add_child(m)
	return m


func _cyl(r: float, h: float, color: Color, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.material_override = _mat(color)
	parent.add_child(m)
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 40, 0)
	dl.light_energy = 1.2
	add_child(dl)

	# земля
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	g.mesh = pm
	g.material_override = _mat(Color(0.36, 0.3, 0.2))
	g.position = Vector3(0, -0.01, 0)
	add_child(g)

	# 3D-модель игрока (выживший с топором)
	var body := Node3D.new()
	body.position = Vector3(0, 0, -3)
	add_child(body)
	var navy := Color(0.25, 0.28, 0.32)
	var skin := Color(0.8, 0.66, 0.52)
	var jeans := Color(0.3, 0.34, 0.42)
	# ноги
	_box(Vector3(0.24, 0.8, 0.24), Vector3(-0.18, 0.4, 0), jeans, body)
	_box(Vector3(0.24, 0.8, 0.24), Vector3(0.18, 0.4, 0), jeans, body)
	# торс
	_box(Vector3(0.6, 0.7, 0.35), Vector3(0, 1.1, 0), navy, body)
	# руки
	_box(Vector3(0.2, 0.6, 0.2), Vector3(-0.42, 1.1, 0), navy, body)
	_box(Vector3(0.2, 0.6, 0.2), Vector3(0.42, 1.1, 0), navy, body)
	# топор в правой руке
	_box(Vector3(0.06, 0.7, 0.06), Vector3(0.5, 1.35, 0), Color(0.4, 0.28, 0.16), body)
	_box(Vector3(0.28, 0.08, 0.06), Vector3(0.5, 1.7, 0), Color(0.6, 0.6, 0.65), body)
	# голова
	_sphere(0.26, Vector3(0, 1.75, 0), skin, body)
	# шапка (бини)
	_sphere(0.27, Vector3(0, 1.88, 0), Color(0.5, 0.2, 0.15), body)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 55
	add_child(_cam)


func _process(delta: float) -> void:
	if not _cam:
		return
	_angle += delta * 0.3
	var r := 4.5
	_cam.global_position = Vector3(cos(_angle) * r, 1.6, -3 + sin(_angle) * r * 0.6)
	_cam.look_at(Vector3(0, 1.2, -3), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# затемнение
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	# название
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

	# чувствительность
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

	# расположение кнопок
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
