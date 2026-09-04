extends Control
## Инвентарь как в Rust: по центру 3D-персонаж, вокруг слоты экипировки,
## справа рюкзак-сетка предметов, снизу хотбар.

var _model: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _icon(name: String) -> Texture2D:
	return load("res://icons/%s.png" % name)


func _grid_cell(parent: Control, icon: String, title: String, count: int) -> void:
	# ячейка рюкзака: панель с рамкой, иконка и счётчик в углу
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(88, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.14, 0.95)
	style.border_color = Color(0.45, 0.45, 0.4)
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
	tex.custom_minimum_size = Vector2(42, 42)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tex)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 12)
	box.add_child(t)

	if count >= 0:
		var c := Label.new()
		c.text = "x%d" % count
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = -38
		c.offset_top = -22
		c.offset_right = -5
		c.offset_bottom = -5
		c.add_theme_font_size_override("font_size", 17)
		c.modulate = Color(1, 1, 1, 0.95)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(c)


func _equip_cell(parent: Control, icon: String, title: String, owned: bool) -> void:
	# слот экипировки (как слот одежды в Rust): подсвечен, если есть
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(78, 78)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.24, 0.19, 0.95) if owned else Color(0.13, 0.13, 0.12, 0.9)
	style.border_color = Color(0.9, 0.85, 0.5) if owned else Color(0.32, 0.32, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	var tex := TextureRect.new()
	tex.texture = _icon(icon)
	tex.custom_minimum_size = Vector2(40, 40)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.modulate = Color(1, 1, 1, 1.0) if owned else Color(1, 1, 1, 0.22)
	box.add_child(tex)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 11)
	t.modulate = Color(1, 1, 1, 1.0) if owned else Color(1, 1, 1, 0.4)
	box.add_child(t)


func _section(parent: Control, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 18)
	l.modulate = Color(0.9, 0.8, 0.5)
	parent.add_child(l)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.3
	title.anchor_right = 0.7
	title.offset_top = 12
	title.offset_bottom = 50
	title.add_theme_font_size_override("font_size", 30)
	title.modulate = Color(0.95, 0.85, 0.6)
	add_child(title)

	# --- центр: 3D-персонаж ---
	_build_character()

	# --- левая колонка: экипировка (как слоты одежды в Rust) ---
	var eq_v := VBoxContainer.new()
	eq_v.anchor_left = 0.03
	eq_v.anchor_right = 0.2
	eq_v.anchor_top = 0.12
	eq_v.anchor_bottom = 0.95
	eq_v.add_theme_constant_override("separation", 8)
	add_child(eq_v)
	_section(eq_v, "Экипировка")
	var eq := GridContainer.new()
	eq.columns = 2
	eq.add_theme_constant_override("h_separation", 6)
	eq.add_theme_constant_override("v_separation", 6)
	eq_v.add_child(eq)
	_equip_cell(eq, "hatchet", "Топор", GameState.has_hatchet)
	_equip_cell(eq, "pickaxe", "Кирка", GameState.has_pickaxe)
	_equip_cell(eq, "spear", "Копьё", GameState.has_spear)
	_equip_cell(eq, "bow", "Лук", GameState.has_bow)

	# --- правая панель: рюкзак (сетка ресурсов) ---
	var bag := VBoxContainer.new()
	bag.anchor_left = 0.62
	bag.anchor_right = 0.98
	bag.anchor_top = 0.08
	bag.anchor_bottom = 0.9
	bag.add_theme_constant_override("separation", 8)
	add_child(bag)
	_section(bag, "Рюкзак")

	var res := GridContainer.new()
	res.columns = 3
	res.add_theme_constant_override("h_separation", 8)
	res.add_theme_constant_override("v_separation", 8)
	bag.add_child(res)
	_grid_cell(res, "wood", "Дерево", GameState.wood)
	_grid_cell(res, "stone", "Камень", GameState.stone)
	_grid_cell(res, "sulfur", "Сера", GameState.sulfur)
	_grid_cell(res, "iron", "Железо", GameState.iron)
	_grid_cell(res, "metal", "Металл", GameState.metal)
	_grid_cell(res, "scrap", "Скрап", GameState.scrap)
	_grid_cell(res, "cloth", "Ткань", GameState.cloth)
	_grid_cell(res, "meat", "Мясо", GameState.meat)
	_grid_cell(res, "water", "Вода", GameState.water)

	# --- хотбар снизу (как в Rust) ---
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -330
	bar.offset_right = 330
	bar.offset_top = -86
	bar.offset_bottom = -10
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	for i in range(6):
		var slot := Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(100, 70)
		slot.add_theme_font_size_override("font_size", 13)
		var name: String = GameState.HOTBAR[i][1]
		var cnt: int = GameState.hotbar_count(i)
		slot.text = "%s\nx%d" % [name, cnt] if cnt > 0 else name
		if i == GameState.selected_slot:
			slot.modulate = Color(1.0, 1.0, 0.55)
		bar.add_child(slot)

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
	# 3D-персонаж в центре (как манекен в инвентаре Rust)
	var svpc := SubViewportContainer.new()
	svpc.anchor_left = 0.22
	svpc.anchor_right = 0.6
	svpc.anchor_top = 0.1
	svpc.anchor_bottom = 0.92
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
	env.background_color = Color(0.12, 0.13, 0.12)
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
	scene.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 1.6), Vector3(0, 0.85, 0), Vector3.UP)

	_model = preload("res://scripts/human_model.gd").new()
	scene.add_child(_model)
	_model.build()
	_model.rotation_degrees = Vector3(0, 180, 0)


func _process(delta: float) -> void:
	# медленный поворот персонажа в инвентаре
	if _model:
		_model.rotate_y(delta * 0.6)
