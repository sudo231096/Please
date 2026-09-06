extends Control
## Инвентарь как в Rust: сетка ячеек с перетаскиванием, экипировка, хотбар,
## окно информации о предмете, персонаж с надетой одеждой, сохранение.

const GRID_COLS := 5
const GRID_ROWS := 4
const GRID_SIZE := GRID_COLS * GRID_ROWS

var _grid_cells: Array = []       # Panel на каждый слот сетки
var _order: Array = []            # порядок id предметов в сетке
var _equip_cells := {}            # слот -> Panel
var _hotbar_cells: Array = []
var _info: VBoxContainer
var _info_name: Label
var _info_desc: Label
var _info_act: Button
var _info_id := ""
var _held_tex: TextureRect
var _res_cells := {}
var _model: Node3D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # курсор виден в меню
	_sync_order()
	_build()
	_refresh()


func _icon(name: String) -> Texture2D:
	return load("res://icons/%s.png" % name)


func _sync_order() -> void:
	# порядок: сначала по категориям, затем алфавит — стабильная раскладка
	var seen := {}
	var new_order: Array = []
	var cats := ["Инструменты", "Оружие", "Боеприпасы", "Медицина", "Одежда", "Броня"]
	for cat in cats:
		for id in GameState.items:
			if GameState.item_cat(id) == cat and not seen.has(id):
				seen[id] = true
				new_order.append(id)
	for id in GameState.items:
		if not seen.has(id):
			new_order.append(id)
	_order = new_order


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
	title.offset_top = 10
	title.offset_bottom = 48
	title.add_theme_font_size_override("font_size", 28)
	title.modulate = Color(0.95, 0.85, 0.6)
	add_child(title)

	# --- кнопки сверху ---
	var back := Button.new()
	back.text = "НАЗАД"
	back.focus_mode = Control.FOCUS_NONE
	back.offset_left = 16
	back.offset_top = 12
	back.offset_right = 150
	back.offset_bottom = 52
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void:
		# вернуть предмет «в руке» обратно в инвентарь
		if not GameState.held.is_empty():
			GameState.add_item(GameState.held["id"], GameState.held["count"])
			GameState.held = {}
		GameState.save_inventory()
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	add_child(back)

	var throw_btn := Button.new()
	throw_btn.text = "ВЫБРОСИТЬ"
	throw_btn.focus_mode = Control.FOCUS_NONE
	throw_btn.anchor_left = 1.0
	throw_btn.anchor_right = 1.0
	throw_btn.offset_left = -500
	throw_btn.offset_right = -350
	throw_btn.offset_top = 12
	throw_btn.offset_bottom = 52
	throw_btn.add_theme_font_size_override("font_size", 15)
	throw_btn.modulate = Color(0.9, 0.55, 0.45)
	throw_btn.pressed.connect(func() -> void:
		if not GameState.held.is_empty():
			GameState.held = {}
			_refresh()
	)
	add_child(throw_btn)

	var save_btn := Button.new()
	save_btn.text = "СОХРАНИТЬ"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.anchor_left = 1.0
	save_btn.anchor_right = 1.0
	save_btn.offset_left = -330
	save_btn.offset_right = -180
	save_btn.offset_top = 12
	save_btn.offset_bottom = 52
	save_btn.add_theme_font_size_override("font_size", 16)
	save_btn.modulate = Color(0.6, 0.8, 0.6)
	save_btn.pressed.connect(func() -> void:
		GameState.save_inventory()
		_toast("Инвентарь сохранён")
	)
	add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "ЗАГРУЗИТЬ"
	load_btn.focus_mode = Control.FOCUS_NONE
	load_btn.anchor_left = 1.0
	load_btn.anchor_right = 1.0
	load_btn.offset_left = -170
	load_btn.offset_right = -20
	load_btn.offset_top = 12
	load_btn.offset_bottom = 52
	load_btn.add_theme_font_size_override("font_size", 16)
	load_btn.modulate = Color(0.7, 0.7, 0.9)
	load_btn.pressed.connect(func() -> void:
		if GameState.load_inventory():
			_sync_order()
			_refresh()
			_toast("Инвентарь загружен")
		else:
			_toast("Нет сохранения")
	)
	add_child(load_btn)

	# --- слева: экипировка ---
	_build_equipment()

	# --- персонаж по центру ---
	_build_character()

	# --- справа: сетка предметов ---
	_build_grid()

	# --- ресурсы ---
	_build_resources()

	# --- хотбар ---
	_build_hotbar()

	# --- окно информации ---
	_build_info()

	# --- иконка «в руке» при перетаскивании ---
	_held_tex = TextureRect.new()
	_held_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_tex.custom_minimum_size = Vector2(52, 52)
	_held_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_tex.visible = false
	add_child(_held_tex)


func _build_equipment() -> void:
	var eq := VBoxContainer.new()
	eq.anchor_left = 0.02
	eq.anchor_right = 0.2
	eq.anchor_top = 0.1
	eq.anchor_bottom = 0.9
	eq.add_theme_constant_override("separation", 6)
	add_child(eq)

	var hdr := Label.new()
	hdr.text = "Экипировка"
	hdr.add_theme_font_size_override("font_size", 18)
	hdr.modulate = Color(0.9, 0.8, 0.5)
	eq.add_child(hdr)

	for slot in GameState.EQUIP_SLOTS:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(76, 76)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_equip_input.bind(slot))
		_equip_cells[slot] = panel
		eq.add_child(panel)


func _build_character() -> void:
	var svpc := SubViewportContainer.new()
	svpc.anchor_left = 0.22
	svpc.anchor_right = 0.6
	svpc.anchor_top = 0.08
	svpc.anchor_bottom = 0.72
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
	env.ambient_light_color = Color(0.62, 0.64, 0.67)
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
	cam.look_at_from_position(Vector3(0, 0.95, 1.9), Vector3(0, 0.9, 0), Vector3.UP)

	_model = preload("res://models/player.glb").instantiate()
	scene.add_child(_model)
	_model.scale = Vector3.ONE * (1.9 / 47.0)
	_model.rotation_degrees = Vector3(0, 180, 0)
	for ap in _model.find_children("*", "AnimationPlayer", true, false):
		if ap.has_animation("Idle"):
			ap.play("Idle")
			break
	# поставить ногами на центр сцены
	await get_tree().process_frame
	await get_tree().process_frame
	var mn := Vector3(1e9, 1e9, 1e9)
	for m in _model.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = m.mesh.get_aabb()
		var t: Transform3D = m.global_transform
		for i in range(8):
			var p: Vector3 = aabb.position + Vector3(
				aabb.size.x if (i & 1) != 0 else 0.0,
				aabb.size.y if (i & 2) != 0 else 0.0,
				aabb.size.z if (i & 4) != 0 else 0.0)
			p = t * p
			mn = mn.min(p)
	_model.position += Vector3(0, -mn.y, 0)


func _build_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = GRID_COLS
	grid.anchor_left = 0.62
	grid.anchor_right = 0.99
	grid.anchor_top = 0.1
	grid.anchor_bottom = 0.66
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)

	_grid_cells.clear()
	for i in range(GRID_SIZE):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(76, 76)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_grid_input.bind(i))
		panel.mouse_entered.connect(_on_grid_hover.bind(i))
		panel.mouse_exited.connect(_on_grid_unhover)
		grid.add_child(panel)
		_grid_cells.append(panel)


func _build_resources() -> void:
	var box := VBoxContainer.new()
	box.anchor_left = 0.62
	box.anchor_right = 0.99
	box.anchor_top = 0.68
	box.anchor_bottom = 0.9
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	var hdr := Label.new()
	hdr.text = "Ресурсы"
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.modulate = Color(0.9, 0.8, 0.5)
	box.add_child(hdr)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)

	for res in ["wood", "stone", "sulfur", "iron", "cloth", "metal", "scrap", "meat", "water"]:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(58, 64)
		cell.add_theme_constant_override("separation", 1)
		row.add_child(cell)
		var tex := TextureRect.new()
		tex.texture = _icon(GameState.item_icon(res))
		tex.custom_minimum_size = Vector2(34, 34)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(tex)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		cell.add_child(lbl)
		_res_cells[res] = lbl


func _build_hotbar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -300
	bar.offset_right = 300
	bar.offset_top = -84
	bar.offset_bottom = -10
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	_hotbar_cells.clear()
	for i in range(6):
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(92, 70)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_hotbar_input.bind(i))
		bar.add_child(panel)
		_hotbar_cells.append(panel)


func _build_info() -> void:
	_info = VBoxContainer.new()
	_info.anchor_left = 0.22
	_info.anchor_right = 0.6
	_info.anchor_top = 0.74
	_info.anchor_bottom = 1.0
	_info.add_theme_constant_override("separation", 4)
	add_child(_info)

	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 20)
	_info_name.modulate = Color(0.95, 0.85, 0.6)
	_info.add_child(_info_name)

	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.add_theme_font_size_override("font_size", 14)
	_info_desc.modulate = Color(0.85, 0.88, 0.85)
	_info.add_child(_info_desc)

	_info_act = Button.new()
	_info_act.focus_mode = Control.FOCUS_NONE
	_info_act.add_theme_font_size_override("font_size", 16)
	_info_act.visible = false
	_info_act.pressed.connect(_on_info_action)
	_info.add_child(_info_act)


# ---------- взаимодействие с сеткой ----------

func _on_grid_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_grid_click(index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_grid_split(index)


func _grid_click(index: int) -> void:
	var target: String = _id_at(index)
	var held: Dictionary = GameState.held
	if held.is_empty():
		# взять предмет из слота
		if target != "":
			GameState.held = {"id": target, "count": GameState.count(target)}
			if not GameState.is_resource(target):
				GameState.items.erase(target)
			_clear_info()
			_refresh()
	else:
		# положить предмет
		var hid: String = held["id"]
		var hcount: int = held["count"]
		if target == "":
			# пустой слот — кладём
			GameState.held = {}
			GameState.add_item(hid, hcount)
			_refresh()
		elif target == hid:
			# слияние стопки
			var room: int = GameState.item_stack(hid) - GameState.count(hid)
			if room > 0:
				var move := mini(room, hcount)
				GameState.add_item(hid, move)
				hcount -= move
				if hcount <= 0:
					GameState.held = {}
				else:
					GameState.held = {"id": hid, "count": hcount}
			_refresh()
		else:
			# обмен: кладём held, забираем target
			GameState.held = {"id": target, "count": GameState.count(target)}
			GameState.items.erase(target)
			GameState.add_item(hid, hcount)
			_refresh()


func _grid_split(index: int) -> void:
	var target: String = _id_at(index)
	if target == "":
		return
	if GameState.is_resource(target):
		return
	var c: int = GameState.count(target)
	if c < 2:
		return
	var half := int(c / 2.0)
	GameState.items[target] = c - half
	GameState.held = {"id": target, "count": half}
	_refresh()


func _id_at(index: int) -> String:
	if index >= 0 and index < _order.size():
		return _order[index]
	return ""


func _on_grid_hover(index: int) -> void:
	var id: String = _id_at(index)
	if id != "":
		_show_info(id)
	else:
		_clear_info()


func _on_grid_unhover() -> void:
	pass


# ---------- экипировка ----------

func _on_equip_input(event: InputEvent, slot: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var held: Dictionary = GameState.held
		if not held.is_empty():
			# надеть предмет из «руки» в слот
			var hid: String = held["id"]
			if GameState.equip_slot_of(hid) == slot:
				GameState.held = {}
				GameState.add_item(hid, 1)
				GameState.equip_item(hid)
				_clear_info()
				_refresh()
		elif GameState.equipped.has(slot):
			# снять
			GameState.unequip(slot)
			_clear_info()
			_refresh()


# ---------- хотбар ----------

func _on_hotbar_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var held: Dictionary = GameState.held
		if not held.is_empty():
			# назначить предмет из руки в хотбар
			var hid: String = held["id"]
			GameState.hotbar[index] = hid
			GameState.held = {}
			GameState.add_item(hid, held["count"])
			_refresh()
		else:
			# переключить «цель назначения»
			if GameState.assigning_hotbar == index:
				GameState.assigning_hotbar = -1
			else:
				GameState.assigning_hotbar = index
			_refresh()


# ---------- инфо-панель ----------

func _show_info(id: String) -> void:
	_info_id = id
	_info_name.text = GameState.item_name(id)
	_info_desc.text = GameState.item_desc(id)
	var slot: String = GameState.equip_slot_of(id)
	if slot != "" and not GameState.is_equipped(id):
		_info_act.text = "НАДЕТЬ"
		_info_act.visible = true
	else:
		_info_act.visible = false


func _clear_info() -> void:
	_info_id = ""
	_info_name.text = ""
	_info_desc.text = ""
	_info_act.visible = false


func _on_info_action() -> void:
	if _info_id == "":
		return
	if GameState.equip_item(_info_id):
		_clear_info()
		_refresh()


# ---------- обновление ----------

func _refresh() -> void:
	_sync_order()
	# сетка
	for i in range(GRID_SIZE):
		var panel: Panel = _grid_cells[i]
		_clear_panel(panel)
		var id: String = _id_at(i)
		if id == "":
			panel.modulate = Color(1, 1, 1, 0.35)
			continue
		panel.modulate = Color(1, 1, 1, 1)
		_add_item_to_panel(panel, id)
	# экипировка
	for slot in GameState.EQUIP_SLOTS:
		var panel: Panel = _equip_cells[slot]
		_clear_panel(panel)
		if GameState.equipped.has(slot):
			var eid: String = GameState.equipped[slot]
			_add_item_to_panel(panel, eid)
		else:
			var lbl := Label.new()
			lbl.text = slot.to_upper()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.modulate = Color(1, 1, 1, 0.35)
			panel.add_child(lbl)
	# ресурсы
	for res in _res_cells:
		_res_cells[res].text = str(GameState.count(res))
	# хотбар
	for i in range(6):
		var panel: Panel = _hotbar_cells[i]
		_clear_panel(panel)
		var hid: String = GameState.hotbar[i]
		if hid != "" and GameState.count(hid) > 0:
			_add_item_to_panel(panel, hid)
			if i == GameState.assigning_hotbar:
				panel.modulate = Color(1.0, 0.9, 0.4)
		else:
			panel.modulate = Color(1, 1, 1, 0.3)
	# персонаж — ригнутая модель (одежда не меняет её геометрию)
	if _model:
		pass


func _clear_panel(panel: Panel) -> void:
	for c in panel.get_children():
		c.queue_free()


func _add_item_to_panel(panel: Panel, id: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.14, 0.95)
	style.border_color = Color(0.45, 0.45, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var tex := TextureRect.new()
	tex.texture = _icon(GameState.item_icon(id))
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 10
	tex.offset_top = 6
	tex.offset_right = -10
	tex.offset_bottom = -18
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tex)

	var cnt := Label.new()
	cnt.text = str(GameState.count(id))
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cnt.set_anchors_preset(Control.PRESET_FULL_RECT)
	cnt.offset_left = -40
	cnt.offset_top = -22
	cnt.offset_right = -5
	cnt.offset_bottom = -4
	cnt.add_theme_font_size_override("font_size", 16)
	cnt.modulate = Color(1, 1, 1, 0.95)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cnt)


# ---------- «в руке» + тост ----------

func _process(delta: float) -> void:
	# перетаскиваемый предмет следует за курсором
	if not GameState.held.is_empty():
		var hid: String = GameState.held["id"]
		_held_tex.texture = _icon(GameState.item_icon(hid))
		_held_tex.visible = true
		_held_tex.position = get_global_mouse_position() - Vector2(26, 26)
		_held_tex.modulate = Color(1, 1, 1, 0.9)
	else:
		_held_tex.visible = false
	# вращение персонажа
	if _model:
		_model.rotate_y(delta * 0.6)


func _toast(msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.3
	l.anchor_right = 0.7
	l.anchor_top = 0.5
	l.anchor_bottom = 0.56
	l.add_theme_font_size_override("font_size", 24)
	l.modulate = Color(1, 0.95, 0.6)
	add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
