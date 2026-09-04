extends Control
## Инвентарь как в Rust: слева 3D-персонаж, справа сетка ячеек предметов.

var _model: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _icon(name: String) -> Texture2D:
	return load("res://icons/%s.png" % name)


func _cell(parent: Control, icon: String, title: String, count: int, highlight := false) -> void:
	# ячейка как в Rust: панель с рамкой, иконка и счётчик в углу
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(96, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.15, 0.95) if not highlight else Color(0.3, 0.32, 0.2, 0.95)
	style.border_color = Color(0.5, 0.5, 0.45) if not highlight else Color(0.9, 0.85, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var tex := TextureRect.new()
	tex.texture = _icon(icon)
	tex.custom_minimum_size = Vector2(48, 48)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tex)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 13)
	box.add_child(t)

	if count >= 0:
		var c := Label.new()
		c.text = "x%d" % count
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = -40
		c.offset_top = -24
		c.offset_right = -6
		c.offset_bottom = -6
		c.add_theme_font_size_override("font_size", 18)
		c.modulate = Color(1, 1, 1, 0.95)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(c)


func _equip_cell(parent: Control, icon: String, title: String, owned: bool) -> void:
	# слот экипировки: подсвечен, если предмет есть
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(96, 96)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.26, 0.2, 0.95) if owned else Color(0.14, 0.14, 0.13, 0.9)
	style.border_color = Color(0.9, 0.85, 0.5) if owned else Color(0.35, 0.35, 0.32)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var tex := TextureRect.new()
	tex.texture = _icon(icon)
	tex.custom_minimum_size = Vector2(48, 48)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.modulate = Color(1, 1, 1, 1.0) if owned else Color(1, 1, 1, 0.25)
	box.add_child(tex)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 12)
	t.modulate = Color(1, 1, 1, 1.0) if owned else Color(1, 1, 1, 0.4)
	box.add_child(t)


func _section(parent: Control, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 20)
	l.modulate = Color(0.9, 0.8, 0.5)
	parent.add_child(l)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.35
	title.anchor_right = 0.65
	title.offset_top = 14
	title.offset_bottom = 54
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(0.95, 0.85, 0.6)
	add_child(title)

	# --- слева: 3D-персонаж ---
	_build_character()

	# --- справа: сетка ячеек ---
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.48
	scroll.anchor_right = 0.98
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 60
	scroll.offset_bottom = -60
	add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)

	# --- экипировка (инструменты/оружие) ---
	_section(v, "Экипировка")
	var eq := GridContainer.new()
	eq.columns = 3
	eq.add_theme_constant_override("h_separation", 8)
	eq.add_theme_constant_override("v_separation", 8)
	v.add_child(eq)
	_equip_cell(eq, "hatchet", "Топор", GameState.has_hatchet)
	_equip_cell(eq, "pickaxe", "Кирка", GameState.has_pickaxe)
	_equip_cell(eq, "spear", "Копьё", GameState.has_spear)
	_equip_cell(eq, "bow", "Лук", GameState.has_bow)
	_equip_cell(eq, "campfire", "Костёр", GameState.built.get("campfire", 0) > 0)
	_equip_cell(eq, "workbench", "Верстак", GameState.workbench_built)

	# --- ресурсы ---
	_section(v, "Ресурсы")
	var res := GridContainer.new()
	res.columns = 3
	res.add_theme_constant_override("h_separation", 8)
	res.add_theme_constant_override("v_separation", 8)
	v.add_child(res)
	_cell(res, "wood", "Дерево", GameState.wood)
	_cell(res, "stone", "Камень", GameState.stone)
	_cell(res, "sulfur", "Сера", GameState.sulfur)
	_cell(res, "iron", "Железо", GameState.iron)
	_cell(res, "metal", "Металл", GameState.metal)
	_cell(res, "scrap", "Скрап", GameState.scrap)
	_cell(res, "cloth", "Ткань", GameState.cloth)
	_cell(res, "meat", "Мясо", GameState.meat)
	_cell(res, "water", "Вода", GameState.water)

	# --- стройматериалы ---
	_section(v, "Строительство")
	var build := GridContainer.new()
	build.columns = 3
	build.add_theme_constant_override("h_separation", 8)
	build.add_theme_constant_override("v_separation", 8)
	v.add_child(build)
	_cell(build, "wall", "Стена", GameState.built.get("wall", 0))
	_cell(build, "floor", "Фундамент", GameState.built.get("floor", 0))
	_cell(build, "door", "Дверь", GameState.built.get("door", 0))
	_cell(build, "furnace", "Печь", GameState.built.get("furnace", 0))
	_cell(build, "bag", "Спальник", GameState.built.get("bag", 0))

	# кнопка назад
	var back := Button.new()
	back.text = "НАЗАД"
	back.focus_mode = Control.FOCUS_NONE
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 20
	back.offset_top = -60
	back.offset_right = 180
	back.offset_bottom = -20
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	add_child(back)


func _build_character() -> void:
	# 3D-персонаж в левой части (как манекен в инвентаре Rust)
	var svpc := SubViewportContainer.new()
	svpc.anchor_left = 0.02
	svpc.anchor_right = 0.46
	svpc.anchor_top = 0.1
	svpc.anchor_bottom = 0.96
	svpc.stretch = true
	add_child(svpc)

	var svp := SubViewport.new()
	svp.transparent_bg = true
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svpc.add_child(svp)

	var scene := Node3D.new()
	svp.add_child(scene)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.14, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.65)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.4
	scene.add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 1.9)
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, 1.9), Vector3(0, 1.0, 0), Vector3.UP)

	_model = preload("res://models/player.glb").instantiate()
	_model.scale = Vector3.ONE * (1.9 / 47.0)
	_model.rotation_degrees = Vector3(0, 180, 0)
	scene.add_child(_model)
	for ap in _model.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation("Idle"):
			ap.play("Idle")
			break


func _process(delta: float) -> void:
	# медленный поворот персонажа в инвентаре
	if _model:
		_model.rotate_y(delta * 0.5)
