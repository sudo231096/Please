extends Control
## Экран крафта в стиле Rust Mobile.
## Слева: категории. В центре: сетка рецептов. Справа: карточка предмета,
## список ресурсов с подсветкой нехватки, счётчик −/+/МАКС и кнопка создания.

const Kit := preload("res://scripts/ui_kit.gd")

const CATS := [
	{"id": "quick", "name": "Быстрый крафт", "glyph": "⚡"},
	{"id": "Строительство", "name": "Постройки", "glyph": "🏠"},
	{"id": "Инструменты", "name": "Инструменты", "glyph": "⛏"},
	{"id": "Оружие", "name": "Оружие", "glyph": "🗡"},
	{"id": "ammo", "name": "Боеприпасы", "glyph": "➹"},
	{"id": "Медицина", "name": "Медицина", "glyph": "✚"},
	{"id": "Броня", "name": "Броня", "glyph": "🛡"},
	{"id": "Одежда", "name": "Одежда", "glyph": "👕"},
	{"id": "res", "name": "Материалы", "glyph": "🪵"},
	{"id": "other", "name": "Другое", "glyph": "▦"},
]

var _cat := "quick"
var _sel := ""
var _amount := 1

var _cats_box: VBoxContainer
var _grid: GridContainer
var _detail: VBoxContainer
var _queue_box: VBoxContainer
var _res_row: HBoxContainer
var _ids: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	_refresh()


func _icon(n: String) -> Texture2D:
	var p := "res://icons/%s.png" % n
	return load(p) if ResourceLoader.exists(p) else null


# ---------- список рецептов ----------

func _recipes_for(cat: String) -> Array:
	var out: Array = []
	for id in GameState.RECIPES:
		var r: Dictionary = GameState.RECIPES[id]
		var rc: String = String(r.get("cat", ""))
		var rt: String = String(r.get("type", ""))
		var keep := false
		match cat:
			"quick":
				keep = GameState.can_craft(String(id))
			"ammo":
				keep = rt == "ammo"
			"res":
				keep = rt == "resource"
			"other":
				keep = rc == "" or (not rc in ["Строительство", "Инструменты", "Оружие", "Медицина", "Броня", "Одежда"] and rt != "ammo")
			_:
				keep = rc == cat
		if cat == "Оружие" and rt == "ammo":
			keep = false
		if keep:
			out.append(String(id))
	out.sort()
	return out


# ---------- построение ----------

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.06, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# шапка: заголовок, ресурсы, закрыть
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	var t := Kit.label("КРАФТ", 24, Kit.ACCENT)
	head.add_child(t)

	_res_row = HBoxContainer.new()
	_res_row.add_theme_constant_override("separation", 6)
	_res_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_res_row)

	var inv := Kit.button("ИНВЕНТАРЬ", 15, false, Vector2(140, 44))
	inv.pressed.connect(func() -> void:
		GameState.save_inventory()
		get_tree().change_scene_to_file("res://scenes/Inventory.tscn")
	)
	head.add_child(inv)

	var x := Kit.button("✕", 20, false, Vector2(50, 44))
	x.pressed.connect(_close)
	head.add_child(x)

	# тело: категории | сетка | детали
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# --- категории ---
	var catp := Kit.make_panel(Kit.BG, 12)
	catp.custom_minimum_size = Vector2(160, 0)
	body.add_child(catp)
	_cats_box = VBoxContainer.new()
	_cats_box.add_theme_constant_override("separation", 4)
	catp.add_child(_cats_box)
	_build_cats()

	# --- сетка рецептов ---
	var gp := Kit.make_panel(Kit.BG, 12)
	gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(gp)
	var gcol := VBoxContainer.new()
	gcol.add_theme_constant_override("separation", 6)
	gp.add_child(gcol)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gcol.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)

	# очередь крафта
	var ql := Kit.label("В ОЧЕРЕДИ", 12, Kit.TXT_DIM)
	gcol.add_child(ql)
	_queue_box = VBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 4)
	_queue_box.custom_minimum_size = Vector2(0, 76)
	gcol.add_child(_queue_box)

	# --- панель деталей ---
	var dp := Kit.make_panel(Kit.BG, 12)
	dp.custom_minimum_size = Vector2(268, 0)
	body.add_child(dp)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 7)
	dp.add_child(_detail)


func _build_cats() -> void:
	for c in _cats_box.get_children():
		c.queue_free()
	for c in CATS:
		var id := String(c["id"])
		var cnt: int = _recipes_for(id).size()
		var b := Kit.button("%s %s" % [String(c["glyph"]), String(c["name"])], 14, id == _cat, Vector2(0, 42))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if cnt == 0:
			b.add_theme_color_override("font_color", Kit.TXT_DIM)
		b.pressed.connect(func() -> void:
			_cat = id
			_sel = ""
			_amount = 1
			_build_cats()
			_refresh()
		)
		_cats_box.add_child(b)


# ---------- отрисовка ----------

func _refresh() -> void:
	_refresh_resources()
	_refresh_grid()
	_refresh_detail()
	_refresh_queue()


func _refresh_resources() -> void:
	for c in _res_row.get_children():
		c.queue_free()
	for r in ["wood", "stone", "metal", "cloth", "scrap"]:
		var p := Kit.make_panel(Color(0.05, 0.05, 0.06, 0.9), 10)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		p.add_child(h)
		h.add_child(Kit.label(GameState.item_name(r).substr(0, 4), 12, Kit.TXT_DIM))
		h.add_child(Kit.label(str(GameState.count(r)), 14, Kit.GOLD))
		_res_row.add_child(p)


func _refresh_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_ids = _recipes_for(_cat)
	if _ids.is_empty():
		var e := Kit.label("В этой категории пока нет доступных рецептов.", 14, Kit.TXT_DIM)
		_grid.add_child(e)
		return
	for id in _ids:
		_grid.add_child(_recipe_cell(String(id)))


func _recipe_cell(id: String) -> Control:
	var r: Dictionary = GameState.RECIPES[id]
	var ok: bool = GameState.can_craft(id)
	var unlocked: bool = GameState.recipe_unlocked(id)

	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 2)

	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(84, 84)
	var bgc := Color(0.13, 0.14, 0.16, 0.95)
	if id == _sel:
		bgc = Color(0.32, 0.2, 0.08, 0.98)
	elif not unlocked:
		bgc = Color(0.1, 0.1, 0.11, 0.9)
	var sb := Kit.panel(bgc, 8)
	if id == _sel:
		sb.border_color = Kit.ACCENT
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	cell.add_theme_stylebox_override("panel", sb)

	var tex := _icon(GameState.item_icon(id))
	if tex != null:
		var ti := TextureRect.new()
		ti.texture = tex
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ti.set_anchors_preset(Control.PRESET_FULL_RECT)
		ti.offset_left = 8
		ti.offset_top = 6
		ti.offset_right = -8
		ti.offset_bottom = -18
		ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not ok:
			ti.modulate = Color(0.55, 0.55, 0.55, 0.8)
		cell.add_child(ti)

	# сколько можно сделать
	var maxn: int = _max_craftable(id)
	if maxn > 0:
		var mc := Kit.label("x%d" % maxn, 11, Kit.OK)
		mc.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mc.offset_left = -30
		mc.offset_top = 2
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(mc)

	if not unlocked:
		var lk := Kit.label("🔒", 16, Kit.TXT_DIM)
		lk.set_anchors_preset(Control.PRESET_CENTER)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lk)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func() -> void:
		_sel = id
		_amount = 1
		_refresh_grid()
		_refresh_detail()
	)
	cell.add_child(btn)
	holder.add_child(cell)

	var nm := Kit.label(String(r["name"]), 11, Kit.TXT if ok else Kit.TXT_DIM)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(84, 26)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(nm)
	return holder


func _max_craftable(id: String) -> int:
	if not GameState.recipe_unlocked(id):
		return 0
	var cost: Dictionary = GameState.RECIPES[id]["cost"]
	var best := 9999
	for r in cost:
		var need: int = int(cost[r])
		if need <= 0:
			continue
		best = mini(best, int(GameState.count(String(r)) / float(need)))
	return maxi(0, best if best < 9999 else 0)


func _refresh_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()

	if _sel == "" or not GameState.RECIPES.has(_sel):
		var h := Kit.label("Выберите предмет для крафта", 15, Kit.TXT_DIM)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(h)
		return

	var id := _sel
	var r: Dictionary = GameState.RECIPES[id]

	# большая иконка
	var big := Panel.new()
	big.custom_minimum_size = Vector2(0, 92)
	big.add_theme_stylebox_override("panel", Kit.panel(Color(0.14, 0.13, 0.11, 0.95), 10))
	var tex := _icon(GameState.item_icon(id))
	if tex != null:
		var ti := TextureRect.new()
		ti.texture = tex
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ti.set_anchors_preset(Control.PRESET_FULL_RECT)
		ti.offset_left = 10
		ti.offset_top = 8
		ti.offset_right = -10
		ti.offset_bottom = -8
		big.add_child(ti)
	_detail.add_child(big)

	_detail.add_child(Kit.label(String(r["name"]), 18, Kit.GOLD))
	var ds := Kit.label(GameState.item_desc(id), 12, Kit.TXT_DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(230, 0)
	_detail.add_child(ds)

	var tm: float = float(r.get("time", 0.0))
	if tm > 0.0:
		_detail.add_child(Kit.label("Время: %.0f сек" % (tm * _amount), 12, Kit.TXT_DIM))

	_detail.add_child(HSeparator.new())
	_detail.add_child(Kit.label("НУЖНЫ РЕСУРСЫ", 12, Kit.TXT_DIM))

	# ресурсы с подсветкой нехватки
	var cost: Dictionary = r["cost"]
	var enough_all := true
	for res in cost:
		var need: int = int(cost[res]) * _amount
		var have: int = GameState.count(String(res))
		var enough: bool = have >= need
		if not enough:
			enough_all = false
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.add_child(Kit.label(GameState.item_name(String(res)), 13, Kit.TXT if enough else Kit.BAD))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(sp)
		line.add_child(Kit.label("%d/%d" % [have, need], 13, Kit.OK if enough else Kit.BAD))
		_detail.add_child(line)

	if not GameState.recipe_unlocked(id):
		_detail.add_child(Kit.label("🔒 Нужно изучить в верстаке", 13, Kit.BAD))

	# счётчик −/+/МАКС
	var maxn: int = maxi(1, _max_craftable(id))
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 5)
	_detail.add_child(arow)

	var minus := Kit.button("−", 20, false, Vector2(50, 44))
	minus.pressed.connect(func() -> void:
		_amount = maxi(1, _amount - 1)
		_refresh_detail()
	)
	arow.add_child(minus)

	var amt := Kit.label(str(_amount), 20, Kit.GOLD)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amt.custom_minimum_size = Vector2(56, 44)
	amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arow.add_child(amt)

	var plus := Kit.button("+", 20, false, Vector2(50, 44))
	plus.pressed.connect(func() -> void:
		_amount = mini(maxi(1, _max_craftable(id)), _amount + 1)
		_refresh_detail()
	)
	arow.add_child(plus)

	var mx := Kit.button("МАКС.", 14, false, Vector2(76, 44))
	mx.pressed.connect(func() -> void:
		_amount = maxi(1, _max_craftable(id))
		_refresh_detail()
	)
	arow.add_child(mx)

	# кнопка создания
	var can: bool = GameState.can_craft(id) and enough_all
	var mk := Kit.button("СОЗДАТЬ" if can else "НЕТ РЕСУРСОВ", 17, can, Vector2(0, 54))
	mk.disabled = not can
	mk.pressed.connect(func() -> void: _do_craft(id))
	_detail.add_child(mk)


func _do_craft(id: String) -> void:
	var made := 0
	for i in range(_amount):
		if not GameState.start_craft(id):
			break
		made += 1
	if made > 0:
		GameState.save_inventory()
		_toast("В очереди: %s x%d" % [String(GameState.RECIPES[id]["name"]), made])
		_amount = 1
	else:
		_toast("Не хватает ресурсов")
	_refresh()


func _refresh_queue() -> void:
	for c in _queue_box.get_children():
		c.queue_free()
	var q: Array = GameState.craft_queue()
	if q.is_empty():
		_queue_box.add_child(Kit.label("пусто", 12, Kit.TXT_DIM))
		return
	for i in range(mini(3, q.size())):
		var c: Dictionary = q[i]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var nm := Kit.label(String(c["name"]), 12, Kit.TXT)
		nm.custom_minimum_size = Vector2(140, 0)
		line.add_child(nm)
		var total: float = maxf(0.001, float(c["total"]))
		var pb := Kit.bar(total - float(c["remaining"]), total, Kit.ACCENT, 10.0)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(pb)
		var idx := i
		var cancel := Kit.button("✕", 12, false, Vector2(34, 30))
		cancel.pressed.connect(func() -> void:
			GameState.cancel_craft(idx)
			GameState.save_inventory()
			_refresh()
		)
		line.add_child(cancel)
		_queue_box.add_child(line)


func _process(delta: float) -> void:
	var before: int = GameState.craft_queue().size()
	GameState.tick_craft(delta)
	if GameState.craft_queue().size() != before:
		GameState.save_inventory()
		_refresh()
	else:
		_refresh_queue()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_close()


func _close() -> void:
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
	p.position = Vector2(vs.x * 0.5 - p.size.x * 0.5, vs.y * 0.1)
	Kit.fade_in(p)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
