extends Control
## Инвентарь: ресурсы, инструменты, стройматериалы с иконками.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _icon(name: String) -> Texture2D:
	return load("res://icons/%s.png" % name)


func _cell(parent: Control, icon: String, title: String, subtitle: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(110, 96)
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var tex := TextureRect.new()
	tex.texture = _icon(icon)
	tex.custom_minimum_size = Vector2(56, 56)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tex)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 15)
	box.add_child(t)

	var s := Label.new()
	s.text = subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 12)
	s.modulate = Color(0.8, 0.8, 0.75)
	box.add_child(s)


func _section(parent: Control, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 22)
	l.modulate = Color(0.9, 0.8, 0.5)
	parent.add_child(l)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "ИНВЕНТАРЬ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.3
	title.anchor_right = 0.7
	title.offset_top = 16
	title.offset_bottom = 60
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(0.95, 0.85, 0.6)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.05
	scroll.anchor_right = 0.95
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 70
	scroll.offset_bottom = -70
	add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	# --- ресурсы ---
	_section(v, "Ресурсы")
	var res := GridContainer.new()
	res.columns = 5
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(res)
	_cell(res, "wood", "Дерево", "x%d" % GameState.wood)
	_cell(res, "stone", "Камень", "x%d" % GameState.stone)
	_cell(res, "sulfur", "Сера", "x%d" % GameState.sulfur)
	_cell(res, "metal", "Металл", "x%d" % GameState.metal)
	_cell(res, "scrap", "Скрап", "x%d" % GameState.scrap)
	_cell(res, "iron", "Железо", "x%d" % GameState.iron)
	_cell(res, "cloth", "Ткань", "x%d" % GameState.cloth)
	_cell(res, "meat", "Мясо", "x%d" % GameState.meat)
	_cell(res, "water", "Вода", "x%d" % GameState.water)

	# --- инструменты ---
	_section(v, "Инструменты и оружие")
	var tools := GridContainer.new()
	tools.columns = 5
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(tools)
	_cell(tools, "hatchet", "Топор", "есть" if GameState.has_hatchet else "нет")
	_cell(tools, "pickaxe", "Кирка", "есть" if GameState.has_pickaxe else "нет")
	_cell(tools, "spear", "Копьё", "есть" if GameState.has_spear else "нет")
	_cell(tools, "bow", "Лук", "есть" if GameState.has_bow else "нет")

	# --- стройматериалы / постройки ---
	_section(v, "Строительство")
	var build := GridContainer.new()
	build.columns = 5
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(build)
	_cell(build, "campfire", "Костёр", _build_status("campfire"))
	_cell(build, "furnace", "Печь", _build_status("furnace"))
	_cell(build, "wall", "Стена", _build_status("wall"))
	_cell(build, "floor", "Фундамент", _build_status("floor"))
	_cell(build, "door", "Дверь", _build_status("door"))
	_cell(build, "bag", "Спальник", _build_status("bag"))
	_cell(build, "workbench", "Верстак", _build_status("workbench"))

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


func _build_status(id: String) -> String:
	if GameState.recipe_unlocked(id):
		var built: int = GameState.built.get(id, 0)
		return "построено %d" % built if built > 0 else "доступно"
	return "закрыто"
