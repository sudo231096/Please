extends Control
## Минималистичный инвентарь в духе Rust: тёмный полупрозрачный фон,
## пустые квадратные ячейки, предмет = только иконка + число в углу.
## Перетаскивание между инвентарём, экипировкой и хотбаром.

const Kit := preload("res://scripts/ui_kit.gd")

const GRID_COLS := 6
const GRID_ROWS := 4
const GRID_SIZE := GRID_COLS * GRID_ROWS
const HOTBAR_SIZE := 6

const SLOT_LABEL := {"head": "голова", "chest": "торс", "legs": "ноги", "feet": "обувь"}

var _grid_cells: Array = []       # ячейки основного инвентаря
var _hot_cells: Array = []        # ячейки хотбара
var _equip_cells := {}            # слот -> ячейка
var _model: Node3D
var _sel_id := ""
var _info_box: VBoxContainer
var _ghost: Panel                 # предмет «в руке» под курсором
var _stat := {}
var _drag_src := ""               # откуда взяли: "grid:N" / "hot:N" / "equip:slot"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	_refresh()


func _icon(id: String) -> Texture2D:
	if id == "":
		return null
	var p := "res://icons/%s.png" % GameState.item_icon(id)
	return load(p) if ResourceLoader.exists(p) else null


# ---------- раскладка предметов ----------

## Порядок предметов в основной сетке (всё, что не в хотбаре)
func _grid_items() -> Array:
	var out: Array = []
	var in_hot := {}
	for h in GameState.hotbar:
		if String(h) != "":
			in_hot[String(h)] = true
	var cats := ["Ресурсы", "Еда", "Инструменты", "Оружие", "Боеприпасы", "Медицина", "Рейд", "Одежда", "Броня"]
	var seen := {}
	for cat in cats:
		for id in GameState.ITEMS:
			var sid := String(id)
			if seen.has(sid) or in_hot.has(sid):
				continue
			if String(GameState.ITEMS[sid].get("cat", "")) != cat:
				continue
			if GameState.count(sid) <= 0:
				continue
			seen[sid] = true
			out.append(sid)
	for id in GameState.items:
		var sid2 := String(id)
		if not seen.has(sid2) and not in_hot.has(sid2) and GameState.count(sid2) > 0:
			out.append(sid2)
	return out


func _grid_id(i: int) -> String:
	var arr := _grid_items()
	return String(arr[i]) if i < arr.size() else ""


# ---------- построение ----------

func _build() -> void:
	# затемнённый фон (игра как бы просвечивает)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.045, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 26
	root.offset_right = -26
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# --- шапка ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	var t := Kit.label("ИНВЕНТАРЬ", 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var craft := Kit.button("КРАФТ", 14, false, Vector2(104, 42))
	craft.pressed.connect(func() -> void: _go("res://scenes/Craft.tscn"))
	head.add_child(craft)
	var x := Kit.button("✕", 18, false, Vector2(48, 42))
	x.pressed.connect(_close)
	head.add_child(x)

	# --- середина: персонаж | сетка | инфо ---
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)

	_build_character(mid)
	_build_grid(mid)
	_build_info(mid)

	# --- низ: хотбар + показатели ---
	_build_bottom(root)

	# предмет под курсором при перетаскивании
	_ghost = _make_cell(56)
	_ghost.visible = false
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 200
	add_child(_ghost)


func _build_character(parent: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(230, 0)
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)

	var p := Kit.make_panel(Color(0.07, 0.075, 0.09, 0.7), 10)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var vp := SubViewportContainer.new()
	vp.stretch = true
	vp.custom_minimum_size = Vector2(0, 230)
	vp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(vp)
	var sub := SubViewport.new()
	sub.transparent_bg = true
	sub.size = Vector2i(220, 230)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(sub)
	var world := Node3D.new()
	sub.add_child(world)
	var l1 := DirectionalLight3D.new()
	l1.rotation_degrees = Vector3(-32, 34, 0)
	l1.light_energy = 1.5
	world.add_child(l1)
	var l2 := DirectionalLight3D.new()
	l2.rotation_degrees = Vector3(-12, -142, 0)
	l2.light_energy = 0.45
	l2.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(l2)
	_model = preload("res://scripts/human_model.gd").new()
	world.add_child(_model)
	_model.build(GameState.equipped)
	var cam := Camera3D.new()
	cam.fov = 32
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.05, 3.5), Vector3(0, 0.95, 0), Vector3.UP)

	# слоты экипировки — 4 квадрата под моделью
	var eq := HBoxContainer.new()
	eq.alignment = BoxContainer.ALIGNMENT_CENTER
	eq.add_theme_constant_override("separation", 7)
	v.add_child(eq)
	for slot in GameState.EQUIP_SLOTS:
		var sl := String(slot)
		var cell := _make_cell(50)
		cell.gui_input.connect(func(e: InputEvent) -> void: _on_equip_input(e, sl))
		eq.add_child(cell)
		_equip_cells[sl] = cell


func _build_grid(parent: HBoxContainer) -> void:
	var p := Kit.make_panel(Color(0.07, 0.075, 0.09, 0.7), 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)

	var g := GridContainer.new()
	g.columns = GRID_COLS
	g.add_theme_constant_override("h_separation", 7)
	g.add_theme_constant_override("v_separation", 7)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(g)
	for i in range(GRID_SIZE):
		var idx := i
		var cell := _make_cell(62)
		cell.gui_input.connect(func(e: InputEvent) -> void: _on_grid_input(e, idx))
		g.add_child(cell)
		_grid_cells.append(cell)


func _build_info(parent: HBoxContainer) -> void:
	var p := Kit.make_panel(Color(0.07, 0.075, 0.09, 0.7), 10)
	p.custom_minimum_size = Vector2(196, 0)
	parent.add_child(p)
	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 6)
	p.add_child(_info_box)


func _build_bottom(root: VBoxContainer) -> void:
	var p := Kit.make_panel(Color(0.07, 0.075, 0.09, 0.7), 10)
	root.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	p.add_child(row)

	# хотбар
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 7)
	row.add_child(hb)
	for i in range(HOTBAR_SIZE):
		var idx := i
		var cell := _make_cell(58)
		cell.gui_input.connect(func(e: InputEvent) -> void: _on_hot_input(e, idx))
		hb.add_child(cell)
		_hot_cells.append(cell)

	# показатели
	var st := VBoxContainer.new()
	st.add_theme_constant_override("separation", 4)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(st)
	for spec in [["hp", Color(0.85, 0.3, 0.28)], ["hunger", Color(0.85, 0.6, 0.25)], ["thirst", Color(0.3, 0.62, 0.9)]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		st.add_child(line)
		var bar := Kit.bar(100, 100, Color(spec[1]), 10.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(bar)
		var vl := Kit.label("100", 12, Kit.TXT_DIM)
		vl.custom_minimum_size = Vector2(32, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(vl)
		_stat[String(spec[0])] = {"bar": bar, "label": vl}


# ---------- ячейка ----------

func _make_cell(size: float) -> Panel:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(size, size)
	c.add_theme_stylebox_override("panel", _cell_style(false, false))
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


func _cell_style(filled: bool, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# пустая ячейка — едва заметная рамка, ничего лишнего
	sb.bg_color = Color(0.10, 0.105, 0.125, 0.55) if not filled else Color(0.14, 0.145, 0.165, 0.9)
	if selected:
		sb.bg_color = Color(0.26, 0.17, 0.07, 0.95)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = Kit.ACCENT if selected else Color(0.26, 0.27, 0.30, 0.85)
	return sb


## Заполнение ячейки: ТОЛЬКО иконка + число. Никаких подписей.
func _fill(cell: Panel, id: String, count: int, selected: bool = false) -> void:
	for c in cell.get_children():
		c.queue_free()
	cell.add_theme_stylebox_override("panel", _cell_style(id != "", selected))
	if id == "":
		return

	var tex := _icon(id)
	if tex != null:
		var ti := TextureRect.new()
		ti.texture = tex
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ti.set_anchors_preset(Control.PRESET_FULL_RECT)
		ti.offset_left = 6
		ti.offset_top = 6
		ti.offset_right = -6
		ti.offset_bottom = -6
		ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ti)
	else:
		# запасной вариант: цветной квадрат, но без текста
		var cr := ColorRect.new()
		cr.color = Color(0.45, 0.4, 0.3, 0.8)
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.offset_left = 14
		cr.offset_top = 14
		cr.offset_right = -14
		cr.offset_bottom = -14
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cr)

	# количество — маленькое число в правом нижнем углу
	if count > 1:
		var l := Label.new()
		l.text = str(count)
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 3)
		l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		l.offset_left = -30
		l.offset_top = -17
		l.offset_right = -3
		l.offset_bottom = -2
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(l)

	# надет — тонкая зелёная полоска сверху
	if GameState.is_equipped(id):
		var m := ColorRect.new()
		m.color = Kit.OK
		m.set_anchors_preset(Control.PRESET_TOP_WIDE)
		m.offset_left = 4
		m.offset_right = -4
		m.offset_top = 3
		m.offset_bottom = 6
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(m)


# ---------- перетаскивание ----------

func _take(id: String, src: String) -> void:
	if id == "" or not GameState.held.is_empty():
		return
	var n: int = GameState.count(id)
	if n <= 0:
		return
	# из хотбара берём саму привязку, предмет остаётся в инвентаре
	if src.begins_with("hot:"):
		var hi := int(src.split(":")[1])
		GameState.hotbar[hi] = ""
		GameState.held = {"id": id, "count": n, "virtual": true}
	elif src.begins_with("equip:"):
		var sl := src.split(":")[1]
		GameState.unequip(sl)
		GameState.held = {"id": id, "count": 1, "virtual": true}
	else:
		if GameState.remove_item(id, n):
			GameState.held = {"id": id, "count": n}
	_drag_src = src
	_sel_id = id
	_refresh()


## Вернуть «в руку» назад в инвентарь
func _return_held() -> void:
	if GameState.held.is_empty():
		return
	var hid: String = String(GameState.held["id"])
	var hc: int = int(GameState.held["count"])
	var virt: bool = bool(GameState.held.get("virtual", false))
	GameState.held = {}
	if not virt:
		GameState.add_item(hid, hc)
	_drag_src = ""
	GameState.save_inventory()
	_refresh()


func _on_grid_input(e: InputEvent, index: int) -> void:
	if not (e is InputEventMouseButton) or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := e as InputEventMouseButton
	if mb.pressed:
		var id := _grid_id(index)
		if id != "":
			if GameState.held.is_empty():
				_take(id, "grid:%d" % index)
			else:
				_return_held()
		elif not GameState.held.is_empty():
			_return_held()
	else:
		# отпустили над сеткой — вернуть в инвентарь
		if not GameState.held.is_empty():
			_return_held()


func _on_hot_input(e: InputEvent, index: int) -> void:
	if not (e is InputEventMouseButton) or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := e as InputEventMouseButton
	if not mb.pressed and not GameState.held.is_empty():
		# положили предмет в слот хотбара
		var hid: String = String(GameState.held["id"])
		var hc: int = int(GameState.held["count"])
		var virt: bool = bool(GameState.held.get("virtual", false))
		GameState.held = {}
		if not virt:
			GameState.add_item(hid, hc)
		GameState.hotbar[index] = hid
		_drag_src = ""
		GameState.save_inventory()
		_refresh()
		return
	if mb.pressed:
		var cur := String(GameState.hotbar[index])
		if GameState.held.is_empty() and cur != "":
			_take(cur, "hot:%d" % index)


func _on_equip_input(e: InputEvent, slot: String) -> void:
	if not (e is InputEventMouseButton) or (e as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var mb := e as InputEventMouseButton
	if not mb.pressed and not GameState.held.is_empty():
		var hid: String = String(GameState.held["id"])
		var hc: int = int(GameState.held["count"])
		var virt: bool = bool(GameState.held.get("virtual", false))
		GameState.held = {}
		if not virt:
			GameState.add_item(hid, hc)
		if GameState.equip_slot_of(hid) == slot:
			GameState.equip_item(hid)
		_drag_src = ""
		GameState.save_inventory()
		_refresh()
		return
	if mb.pressed:
		var eid := String(GameState.equipped.get(slot, ""))
		if GameState.held.is_empty() and eid != "":
			_take(eid, "equip:%s" % slot)


# ---------- инфо-панель ----------

func _rebuild_info() -> void:
	for c in _info_box.get_children():
		c.queue_free()
	if _sel_id == "" or GameState.count(_sel_id) <= 0:
		var h := Kit.label("Выберите предмет", 14, Kit.TXT_DIM)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(h)
		return
	var id := _sel_id
	_info_box.add_child(Kit.label(GameState.item_name(id), 16, Kit.GOLD))
	_info_box.add_child(Kit.label("x%d" % GameState.count(id), 13, Kit.TXT))
	var d := Kit.label(GameState.item_desc(id), 12, Kit.TXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(170, 0)
	_info_box.add_child(d)
	_info_box.add_child(HSeparator.new())

	var slot: String = GameState.equip_slot_of(id)
	if slot != "":
		if GameState.is_equipped(id):
			var un := Kit.button("СНЯТЬ", 13, false, Vector2(0, 40))
			un.pressed.connect(func() -> void:
				GameState.unequip(slot); GameState.save_inventory(); _refresh())
			_info_box.add_child(un)
		else:
			var eb := Kit.button("НАДЕТЬ", 13, true, Vector2(0, 40))
			eb.pressed.connect(func() -> void:
				GameState.equip_item(id); GameState.save_inventory(); _refresh())
			_info_box.add_child(eb)
	if GameState.is_usable(id):
		var ub := Kit.button("ИСПОЛЬЗОВАТЬ", 13, true, Vector2(0, 40))
		ub.pressed.connect(func() -> void:
			GameState.use_item(id); GameState.save_inventory()
			if GameState.count(id) <= 0: _sel_id = ""
			_refresh())
		_info_box.add_child(ub)
	var dr := Kit.button("ВЫБРОСИТЬ", 12, false, Vector2(0, 38))
	dr.add_theme_color_override("font_color", Kit.BAD)
	dr.pressed.connect(func() -> void:
		GameState.drop_item(id, GameState.count(id))
		GameState.save_inventory(); _sel_id = ""; _refresh())
	_info_box.add_child(dr)


# ---------- обновление ----------

func _refresh() -> void:
	for i in range(GRID_SIZE):
		var id := _grid_id(i)
		_fill(_grid_cells[i], id, GameState.count(id) if id != "" else 0, id != "" and id == _sel_id)
	for i in range(_hot_cells.size()):
		var hid := String(GameState.hotbar[i]) if i < GameState.hotbar.size() else ""
		var cnt: int = GameState.count(hid) if hid != "" else 0
		if hid != "" and cnt <= 0:
			GameState.hotbar[i] = ""
			hid = ""
		_fill(_hot_cells[i], hid, cnt, hid != "" and hid == _sel_id)
	for slot in GameState.EQUIP_SLOTS:
		var sl := String(slot)
		var eid := String(GameState.equipped.get(sl, ""))
		_fill(_equip_cells[sl], eid, 1 if eid != "" else 0, false)
	_set_stat("hp", GameState.hp, GameState.max_hp)
	_set_stat("hunger", GameState.hunger, 100.0)
	_set_stat("thirst", GameState.thirst, 100.0)
	if _model:
		_model.build(GameState.equipped)
	_rebuild_info()


func _set_stat(key: String, v: float, maxv: float) -> void:
	if not _stat.has(key):
		return
	var d: Dictionary = _stat[key]
	(d["bar"] as ProgressBar).max_value = maxv
	(d["bar"] as ProgressBar).value = v
	(d["label"] as Label).text = str(int(round(v)))


func _process(delta: float) -> void:
	if not GameState.held.is_empty():
		_ghost.visible = true
		_fill(_ghost, String(GameState.held["id"]), int(GameState.held["count"]))
		_ghost.position = get_global_mouse_position() - Vector2(28, 28)
	else:
		_ghost.visible = false
	if _model:
		_model.rotate_y(delta * 0.45)


func _input(e: InputEvent) -> void:
	# отпустили мимо ячеек — предмет возвращается
	if e is InputEventMouseButton and not (e as InputEventMouseButton).pressed \
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not GameState.held.is_empty():
		_return_held()
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_TAB or k == KEY_I:
			_close()


func _go(scene: String) -> void:
	_return_held()
	GameState.save_inventory()
	GameState.return_to_pos = true
	get_tree().change_scene_to_file(scene)


func _close() -> void:
	# возвращаем «в руке», чтобы предмет не потерялся, и уходим в игру
	_return_held()
	GameState.save_inventory()
	GameState.return_to_pos = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
