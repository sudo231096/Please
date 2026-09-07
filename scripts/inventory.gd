extends Control
## Инвентарь в стиле Rust Mobile.
## Слева: вкладки категорий, 3D-модель персонажа, слоты экипировки.
## Справа: сетка предметов с количеством, перетаскивание, действия.
## Внизу: хотбар, здоровье, голод, жажда.
## Кнопка «X» возвращает точно в игру, на то же место.

const Kit := preload("res://scripts/ui_kit.gd")

const GRID_COLS := 6
const GRID_ROWS := 5
const GRID_SIZE := GRID_COLS * GRID_ROWS

# вкладки фильтрации сетки
const TABS := [
	{"id": "all", "name": "ВСЁ", "glyph": "▦"},
	{"id": "Ресурсы", "name": "Ресурсы", "glyph": "🪵"},
	{"id": "Инструменты", "name": "Инструменты", "glyph": "⛏"},
	{"id": "Оружие", "name": "Оружие", "glyph": "🗡"},
	{"id": "Еда", "name": "Еда", "glyph": "🍖"},
	{"id": "Медицина", "name": "Медицина", "glyph": "✚"},
	{"id": "Одежда", "name": "Одежда", "glyph": "👕"},
	{"id": "Броня", "name": "Броня", "glyph": "🛡"},
]

const SLOT_NAMES := {
	"head": "Голова",
	"chest": "Торс",
	"legs": "Ноги",
	"feet": "Обувь",
}

var _tab := "all"
var _order: Array = []
var _grid_cells: Array = []
var _equip_cells := {}
var _hotbar_cells: Array = []
var _model: Node3D
var _sel_id := ""

# правая инфо-панель
var _info_box: VBoxContainer
var _held_tex: Control
var _tabs_box: VBoxContainer
var _grid: GridContainer
var _stat_bars := {}
var _title: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_sync_order()
	_build()
	_refresh()


func _icon(n: String) -> Texture2D:
	var path := "res://icons/%s.png" % n
	if ResourceLoader.exists(path):
		return load(path)
	return null


# ---------- данные ----------

func _all_ids() -> Array:
	# ресурсы + предметы, стабильный порядок по категориям
	var out: Array = []
	var seen := {}
	var cats := ["Ресурсы", "Еда", "Инструменты", "Оружие", "Боеприпасы", "Медицина", "Одежда", "Броня"]
	for cat in cats:
		for id in GameState.ITEMS:
			if String(GameState.ITEMS[id].get("cat", "")) != cat:
				continue
			if seen.has(id):
				continue
			if GameState.count(String(id)) <= 0:
				continue
			seen[id] = true
			out.append(String(id))
	for id in GameState.items:
		if not seen.has(id) and GameState.count(String(id)) > 0:
			out.append(String(id))
	return out


func _sync_order() -> void:
	var all := _all_ids()
	if _tab == "all":
		_order = all
		return
	var f: Array = []
	for id in all:
		if GameState.item_cat(String(id)) == _tab:
			f.append(id)
	_order = f


func _id_at(i: int) -> String:
	return String(_order[i]) if i >= 0 and i < _order.size() else ""


# ---------- построение ----------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.06, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# ===== ЛЕВО: вкладки =====
	_tabs_box = VBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 5)
	_tabs_box.custom_minimum_size = Vector2(132, 0)
	root.add_child(_tabs_box)
	_build_tabs()

	# ===== ЦЕНТР: персонаж + экипировка =====
	var center := VBoxContainer.new()
	center.add_theme_constant_override("separation", 8)
	center.custom_minimum_size = Vector2(300, 0)
	root.add_child(center)
	_build_character(center)

	# ===== ПРАВО: сетка + инфо =====
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	_build_right(right)

	# ===== перетаскиваемый предмет =====
	_held_tex = _make_cell(58)
	_held_tex.visible = false
	_held_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_tex.z_index = 100
	add_child(_held_tex)


func _build_tabs() -> void:
	var head := Kit.make_panel(Kit.BG, 10)
	var hl := Kit.label("КАТЕГОРИИ", 14, Kit.ACCENT)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(hl)
	_tabs_box.add_child(head)

	for t in TABS:
		var id := String(t["id"])
		var b := Kit.button("%s %s" % [String(t["glyph"]), String(t["name"])], 14, id == _tab, Vector2(0, 44))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("tab", id)
		b.pressed.connect(func() -> void:
			_tab = id
			_sel_id = ""
			_rebuild_tabs()
			_refresh()
		)
		_tabs_box.add_child(b)


func _rebuild_tabs() -> void:
	for c in _tabs_box.get_children():
		c.queue_free()
	_build_tabs()


func _build_character(parent: VBoxContainer) -> void:
	var panel := Kit.make_panel(Kit.BG, 12)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	_title = Kit.label("СНАРЯЖЕНИЕ", 16, Kit.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	# 3D-персонаж
	var vp := SubViewportContainer.new()
	vp.stretch = true
	vp.custom_minimum_size = Vector2(0, 210)
	vp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(vp)

	var sub := SubViewport.new()
	sub.transparent_bg = true
	sub.size = Vector2i(280, 210)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(sub)

	var world := Node3D.new()
	sub.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 35, 0)
	light.light_energy = 1.5
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, -140, 0)
	fill.light_energy = 0.5
	fill.light_color = Color(0.7, 0.8, 1.0)
	world.add_child(fill)

	_model = preload("res://scripts/human_model.gd").new()
	world.add_child(_model)
	_model.build(GameState.equipped)
	_model.position = Vector3(0, 0, 0)

	var cam := Camera3D.new()
	cam.fov = 34
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.05, 3.4), Vector3(0, 0.95, 0), Vector3.UP)

	# слоты экипировки
	var eq := GridContainer.new()
	eq.columns = 4
	eq.add_theme_constant_override("h_separation", 6)
	eq.add_theme_constant_override("v_separation", 6)
	col.add_child(eq)
	for slot in GameState.EQUIP_SLOTS:
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 2)
		var cell := _make_cell(56)
		cell.gui_input.connect(func(e: InputEvent) -> void: _on_equip_input(e, String(slot)))
		holder.add_child(cell)
		var nm := Kit.label(String(SLOT_NAMES.get(slot, slot)), 11, Kit.TXT_DIM)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(nm)
		eq.add_child(holder)
		_equip_cells[String(slot)] = cell


func _build_right(parent: VBoxContainer) -> void:
	# заголовок + закрыть
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	parent.add_child(head)

	var t := Kit.label("ИНВЕНТАРЬ", 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)

	var craft := Kit.button("КРАФТ", 15, false, Vector2(110, 44))
	craft.pressed.connect(func() -> void:
		GameState.save_inventory()
		get_tree().change_scene_to_file("res://scenes/Craft.tscn")
	)
	head.add_child(craft)

	var x := Kit.button("✕", 20, false, Vector2(50, 44))
	x.pressed.connect(_close)
	head.add_child(x)

	# сетка + инфо
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(mid)

	var gp := Kit.make_panel(Kit.BG, 12)
	gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(gp)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	gp.add_child(_grid)
	for i in range(GRID_SIZE):
		var cell := _make_cell(58)
		var idx := i
		cell.gui_input.connect(func(e: InputEvent) -> void: _on_grid_input(e, idx))
		_grid.add_child(cell)
		_grid_cells.append(cell)

	# правая инфо-панель предмета
	var ip := Kit.make_panel(Kit.BG, 12)
	ip.custom_minimum_size = Vector2(210, 0)
	mid.add_child(ip)
	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 6)
	ip.add_child(_info_box)

	# низ: хотбар + показатели
	_build_bottom(parent)


func _build_bottom(parent: VBoxContainer) -> void:
	var bar := Kit.make_panel(Kit.BG, 12)
	parent.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)

	# хотбар
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	row.add_child(hb)
	hb.add_child(Kit.label("БЫСТРЫЙ ДОСТУП", 11, Kit.TXT_DIM))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 5)
	hb.add_child(hrow)
	for i in range(GameState.hotbar.size()):
		var cell := _make_cell(52)
		var idx := i
		cell.gui_input.connect(func(e: InputEvent) -> void: _on_hotbar_input(e, idx))
		hrow.add_child(cell)
		_hotbar_cells.append(cell)

	# показатели выживания
	var st := VBoxContainer.new()
	st.add_theme_constant_override("separation", 4)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(st)
	for spec in [["hp", "Здоровье", Color(0.85, 0.3, 0.28)],
			["hunger", "Голод", Color(0.85, 0.6, 0.25)],
			["thirst", "Жажда", Color(0.3, 0.62, 0.9)]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		st.add_child(line)
		var nm := Kit.label(String(spec[1]), 12, Kit.TXT_DIM)
		nm.custom_minimum_size = Vector2(70, 0)
		line.add_child(nm)
		var pb := Kit.bar(0, 100, Color(spec[2]), 12.0)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(pb)
		var vl := Kit.label("0", 12, Kit.TXT)
		vl.custom_minimum_size = Vector2(38, 0)
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(vl)
		_stat_bars[String(spec[0])] = {"bar": pb, "label": vl}


func _make_cell(size: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.add_theme_stylebox_override("panel", Kit.panel(Color(0.12, 0.13, 0.15, 0.95), 8))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


func _fill_cell(cell: Panel, id: String, count: int, selected: bool = false, badge: String = "") -> void:
	for c in cell.get_children():
		c.queue_free()
	var bg := Color(0.12, 0.13, 0.15, 0.95)
	if id != "":
		bg = Color(0.17, 0.16, 0.14, 0.97)
	if selected:
		bg = Color(0.3, 0.19, 0.08, 0.98)
	var sb := Kit.panel(bg, 8)
	if selected:
		sb.border_color = Kit.ACCENT
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	cell.add_theme_stylebox_override("panel", sb)
	if id == "":
		if badge != "":
			var e := Kit.label(badge, 11, Kit.TXT_DIM)
			e.set_anchors_preset(Control.PRESET_CENTER)
			e.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(e)
		return

	var tex := _icon(GameState.item_icon(id))
	if tex != null:
		var ti := TextureRect.new()
		ti.texture = tex
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ti.set_anchors_preset(Control.PRESET_FULL_RECT)
		ti.offset_left = 5
		ti.offset_top = 5
		ti.offset_right = -5
		ti.offset_bottom = -5
		ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ti)
	else:
		var nm := Kit.label(GameState.item_name(id).substr(0, 3), 13, Kit.TXT)
		nm.set_anchors_preset(Control.PRESET_CENTER)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(nm)

	if count > 1:
		var cl := Kit.label(str(count), 12, Color(1, 1, 1))
		cl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		cl.offset_left = -34
		cl.offset_top = -20
		cl.offset_right = -3
		cl.offset_bottom = -2
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cl)

	if GameState.is_equipped(id):
		var eq := Kit.label("●", 14, Kit.OK)
		eq.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		eq.offset_left = -18
		eq.offset_top = 1
		eq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(eq)

	if badge != "":
		var b := Kit.label(badge, 11, Kit.GOLD)
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.offset_left = 4
		b.offset_top = 1
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(b)


# ---------- взаимодействие ----------

func _on_grid_input(e: InputEvent, index: int) -> void:
	if not (e is InputEventMouseButton and e.pressed):
		return
	var mb := e as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_grid_click(index)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_split(index)


func _grid_click(index: int) -> void:
	var target := _id_at(index)
	var held: Dictionary = GameState.held
	if held.is_empty():
		if target != "":
			# выбрать предмет (показать инфо и действия)
			_sel_id = target
			_refresh()
		return
	# положить/объединить/поменять
	var hid: String = String(held["id"])
	var hcount: int = int(held["count"])
	if target == "" or target == hid:
		GameState.held = {}
		GameState.add_item(hid, hcount)
	else:
		GameState.held = {}
		GameState.add_item(hid, hcount)
	GameState.save_inventory()
	_refresh()


func _split(index: int) -> void:
	var id := _id_at(index)
	if id == "":
		return
	var c: int = GameState.count(id)
	if c < 2:
		return
	_sel_id = id
	_open_split_dialog(id, c)


func _on_equip_input(e: InputEvent, slot: String) -> void:
	if not (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if GameState.equipped.has(slot):
		GameState.unequip(slot)
		GameState.save_inventory()
		_sel_id = ""
		_refresh()


func _on_hotbar_input(e: InputEvent, index: int) -> void:
	if not (e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	# если выбран предмет в сетке — назначаем его в этот слот
	if _sel_id != "":
		GameState.hotbar[index] = _sel_id
		GameState.save_inventory()
		_refresh()
	else:
		# очистить слот
		GameState.hotbar[index] = ""
		GameState.save_inventory()
		_refresh()


# ---------- инфо-панель ----------

func _rebuild_info() -> void:
	for c in _info_box.get_children():
		c.queue_free()
	if _sel_id == "":
		var hint := Kit.label("Выберите предмет", 15, Kit.TXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(hint)
		var h2 := Kit.label("\nЛКМ — выбрать\nПКМ — разделить стопку\nПотом: надеть / использовать /\nвыбросить / в хотбар", 12, Kit.TXT_DIM)
		h2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(h2)
		return

	var id := _sel_id
	var big := _make_cell(76)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box.add_child(big)
	_fill_cell(big, id, GameState.count(id))

	var nm := Kit.label(GameState.item_name(id), 17, Kit.GOLD)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_box.add_child(nm)

	_info_box.add_child(Kit.label("Количество: %d" % GameState.count(id), 13, Kit.TXT))
	_info_box.add_child(Kit.label(GameState.item_cat(id), 12, Kit.TXT_DIM))

	var ds := Kit.label(GameState.item_desc(id), 12, Kit.TXT_DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(180, 0)
	_info_box.add_child(ds)

	var sep := HSeparator.new()
	_info_box.add_child(sep)

	# --- действия ---
	var slot: String = GameState.equip_slot_of(id)
	if slot != "":
		if GameState.is_equipped(id):
			var un := Kit.button("СНЯТЬ", 14, false, Vector2(0, 42))
			un.pressed.connect(func() -> void:
				GameState.unequip(slot)
				GameState.save_inventory()
				_refresh()
			)
			_info_box.add_child(un)
		else:
			var eqb := Kit.button("НАДЕТЬ", 14, true, Vector2(0, 42))
			eqb.pressed.connect(func() -> void:
				if GameState.equip_item(id):
					GameState.save_inventory()
					_toast("Надето: " + GameState.item_name(id))
					_refresh()
			)
			_info_box.add_child(eqb)

	if GameState.is_usable(id):
		var ub := Kit.button("ИСПОЛЬЗОВАТЬ", 14, true, Vector2(0, 42))
		ub.pressed.connect(func() -> void:
			var msg: String = GameState.use_item(id)
			GameState.save_inventory()
			if msg != "":
				_toast(msg)
			if GameState.count(id) <= 0:
				_sel_id = ""
			_refresh()
		)
		_info_box.add_child(ub)

	var hb := Kit.button("В ХОТБАР", 13, false, Vector2(0, 40))
	hb.pressed.connect(func() -> void:
		for i in range(GameState.hotbar.size()):
			if String(GameState.hotbar[i]) == "":
				GameState.hotbar[i] = id
				GameState.save_inventory()
				_toast("Добавлено в слот %d" % (i + 1))
				_refresh()
				return
		GameState.hotbar[0] = id
		GameState.save_inventory()
		_toast("Заменён слот 1")
		_refresh()
	)
	_info_box.add_child(hb)

	var dr := Kit.button("ВЫБРОСИТЬ", 13, false, Vector2(0, 40))
	dr.add_theme_color_override("font_color", Kit.BAD)
	dr.pressed.connect(func() -> void: _open_drop_dialog(id))
	_info_box.add_child(dr)


# ---------- диалоги: разделить / выбросить ----------

func _amount_dialog(title: String, id: String, maxv: int, ok_text: String, on_ok: Callable) -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := Kit.make_panel(Color(0.1, 0.105, 0.12, 0.99), 14)
	panel.custom_minimum_size = Vector2(360, 220)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -180
	panel.offset_right = 180
	panel.offset_top = -110
	panel.offset_bottom = 110
	overlay.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(Kit.label(title, 19, Kit.ACCENT))
	col.add_child(Kit.label(GameState.item_name(id), 15, Kit.TXT))

	var amount := maxi(1, int(maxv / 2.0))
	var al := Kit.label("%d / %d" % [amount, maxv], 20, Kit.GOLD)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(al)

	var sl := HSlider.new()
	sl.min_value = 1
	sl.max_value = maxv
	sl.step = 1
	sl.value = amount
	sl.custom_minimum_size = Vector2(0, 40)
	col.add_child(sl)
	sl.value_changed.connect(func(v: float) -> void:
		amount = int(v)
		al.text = "%d / %d" % [amount, maxv]
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var cancel := Kit.button("ОТМЕНА", 15, false, Vector2(150, 46))
	cancel.pressed.connect(overlay.queue_free)
	row.add_child(cancel)
	var ok := Kit.button(ok_text, 15, true, Vector2(150, 46))
	ok.pressed.connect(func() -> void:
		on_ok.call(amount)
		overlay.queue_free()
	)
	row.add_child(ok)
	Kit.fade_in(overlay)


func _open_drop_dialog(id: String) -> void:
	var have: int = GameState.count(id)
	if have <= 0:
		return
	if have == 1:
		GameState.drop_item(id, 1)
		GameState.save_inventory()
		_toast("Выброшено: " + GameState.item_name(id))
		_sel_id = ""
		_refresh()
		return
	_amount_dialog("ВЫБРОСИТЬ", id, have, "ВЫБРОСИТЬ", func(n: int) -> void:
		GameState.drop_item(id, n)
		GameState.save_inventory()
		_toast("Выброшено %d шт." % n)
		if GameState.count(id) <= 0:
			_sel_id = ""
		_refresh()
	)


func _open_split_dialog(id: String, have: int) -> void:
	_amount_dialog("РАЗДЕЛИТЬ СТОПКУ", id, have - 1, "ВЗЯТЬ", func(n: int) -> void:
		# «в руку» — предмет следует за курсором, кладётся кликом по сетке
		if GameState.remove_item(id, n):
			GameState.held = {"id": id, "count": n}
			GameState.save_inventory()
			_refresh()
	)


# ---------- обновление ----------

func _refresh() -> void:
	_sync_order()
	# сетка
	for i in range(GRID_SIZE):
		var cell: Panel = _grid_cells[i]
		var id := _id_at(i)
		_fill_cell(cell, id, GameState.count(id) if id != "" else 0, id != "" and id == _sel_id)
	# экипировка
	for slot in GameState.EQUIP_SLOTS:
		var c: Panel = _equip_cells[String(slot)]
		var eid: String = String(GameState.equipped.get(slot, ""))
		_fill_cell(c, eid, 1 if eid != "" else 0, false, "" if eid != "" else String(SLOT_NAMES.get(slot, "")).substr(0, 4))
	# хотбар
	for i in range(_hotbar_cells.size()):
		var hc: Panel = _hotbar_cells[i]
		var hid: String = String(GameState.hotbar[i]) if i < GameState.hotbar.size() else ""
		var cnt: int = GameState.count(hid) if hid != "" else 0
		if hid != "" and cnt <= 0:
			_fill_cell(hc, "", 0, false, str(i + 1))
		else:
			_fill_cell(hc, hid, cnt, false, str(i + 1))
	# показатели
	_set_stat("hp", GameState.hp, GameState.max_hp)
	_set_stat("hunger", GameState.hunger, 100.0)
	_set_stat("thirst", GameState.thirst, 100.0)
	# модель персонажа с текущей экипировкой
	if _model:
		_model.build(GameState.equipped)
	_rebuild_info()


func _set_stat(key: String, v: float, maxv: float) -> void:
	if not _stat_bars.has(key):
		return
	var d: Dictionary = _stat_bars[key]
	var pb: ProgressBar = d["bar"]
	pb.max_value = maxv
	pb.value = v
	(d["label"] as Label).text = str(int(round(v)))


func _process(delta: float) -> void:
	if not GameState.held.is_empty():
		var hid: String = String(GameState.held["id"])
		_held_tex.visible = true
		_fill_cell(_held_tex, hid, int(GameState.held["count"]))
		_held_tex.position = get_global_mouse_position() - Vector2(29, 29)
	else:
		_held_tex.visible = false
	if _model:
		_model.rotate_y(delta * 0.5)


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_TAB or k.keycode == KEY_I:
			_close()


func _close() -> void:
	# вернуть «в руке» обратно, чтобы предмет не потерялся
	if not GameState.held.is_empty():
		GameState.add_item(String(GameState.held["id"]), int(GameState.held["count"]))
		GameState.held = {}
	GameState.save_inventory()
	GameState.return_to_pos = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _toast(msg: String) -> void:
	var p := Kit.make_panel(Color(0.05, 0.05, 0.06, 0.96), 10)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(Kit.label(msg, 16, Kit.GOLD))
	add_child(p)
	p.reset_size()
	var vs := get_viewport_rect().size
	p.position = Vector2(vs.x * 0.5 - p.size.x * 0.5, vs.y * 0.12)
	Kit.fade_in(p)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
