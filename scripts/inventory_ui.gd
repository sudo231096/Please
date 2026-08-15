extends CanvasLayer
## Инвентарь / крафт / броня. Без get_tree().paused — только Controls.ui_open.

const CraftDBScr = preload("res://scripts/craft.gd")

const RES_ORDER := ["wood", "stone", "sulfur", "meat"]
const RES_NAMES := {"wood": "Дерево", "stone": "Камень", "sulfur": "Сера", "meat": "Мясо"}
const TOOL_ORDER := [
	"axe", "pickaxe", "sword", "bow", "crossbow", "rod",
	"stone_axe", "stone_pickaxe", "stone_sword", "stone_bow", "stone_crossbow", "stone_rod",
]
const TOOL_NAMES := {
	"axe": "Топор", "pickaxe": "Кирка", "sword": "Меч", "bow": "Лук",
	"crossbow": "Арбалет", "rod": "Удочка",
	"stone_axe": "Кам. топор", "stone_pickaxe": "Кам. кирка", "stone_sword": "Кам. меч",
	"stone_bow": "Кам. лук", "stone_crossbow": "Кам. арбалет", "stone_rod": "Кам. удочка",
}
const BUILD_ORDER := ["wood_block", "wood_wall", "wood_floor", "wood_pillar", "stone_block", "stone_wall", "campfire"]
const BUILD_NAMES := {
	"wood_block": "Дер. блок", "wood_wall": "Дер. стена", "wood_floor": "Дер. пол",
	"wood_pillar": "Дер. столб", "stone_block": "Кам. блок", "stone_wall": "Кам. стена",
	"campfire": "Костёр",
}
const ARMOR_SLOTS := [
	{"id": "head", "title": "Шлем"},
	{"id": "chest", "title": "Нагрудник"},
	{"id": "legs", "title": "Поножи"},
	{"id": "feet", "title": "Ботинки"},
]
const ARMOR_NAMES := {
	"wood_helm": "Дер. шлем", "wood_chest": "Дер. нагрудник", "wood_legs": "Дер. поножи", "wood_boots": "Дер. ботинки",
	"stone_helm": "Кам. шлем", "stone_chest": "Кам. нагрудник", "stone_legs": "Кам. поножи", "stone_boots": "Кам. ботинки",
	"bone_helm": "Кост. шлем", "bone_chest": "Кост. нагрудник", "bone_legs": "Кост. поножи", "bone_boots": "Кост. ботинки",
}
const ARMOR_BAG_ORDER := [
	"wood_helm", "wood_chest", "wood_legs", "wood_boots",
	"stone_helm", "stone_chest", "stone_legs", "stone_boots",
	"bone_helm", "bone_chest", "bone_legs", "bone_boots",
]

var _tab := 0  # 0 inv, 1 craft, 2 armor
var _root: Control
var _content: VBoxContainer
var _tab_btns: Array = []
var _title: Label
var _status: Label


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	if not Inv.changed.is_connected(_on_inv_changed):
		Inv.changed.connect(_on_inv_changed)


func open_inv() -> void:
	_tab = 0
	_show()


func open_craft() -> void:
	_tab = 1
	_show()


func open_armor() -> void:
	_tab = 2
	_show()


func toggle_inv() -> void:
	if visible and _tab == 0:
		close()
	else:
		open_inv()


func toggle_craft() -> void:
	if visible and _tab == 1:
		close()
	else:
		open_craft()


func toggle_armor() -> void:
	if visible and _tab == 2:
		close()
	else:
		open_armor()


func close() -> void:
	visible = false
	Controls.ui_open = false
	# НЕ трогаем get_tree().paused — из‑за pause ломались кнопки HUD


func _show() -> void:
	visible = true
	Controls.ui_open = true
	Controls.move_vector = Vector2.ZERO
	Controls.jump_queued = false
	Controls.attack_queued = false
	_refresh_tabs()
	_rebuild_body()


func _on_inv_changed() -> void:
	if visible:
		_rebuild_body()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 560)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.12, 0.98)
	sb.border_color = Color(0.35, 0.55, 0.40, 1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var head := HBoxContainer.new()
	outer.add_child(head)
	_title = Label.new()
	_title.text = "ИНВЕНТАРЬ"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 28)
	head.add_child(_title)
	var close_btn := _btn("✕", Vector2(64, 52))
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	_tab_btns.clear()
	for i in range(3):
		var names := ["Инвентарь", "Крафт", "Броня"]
		var b := _btn(names[i], Vector2(0, 48))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		b.pressed.connect(func() -> void:
			_tab = idx
			_refresh_tabs()
			_rebuild_body()
		)
		tabs.add_child(b)
		_tab_btns.append(b)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 17)
	_status.modulate = Color(0.75, 0.9, 0.75)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(700, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	outer.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)


func _btn(text: String, mins: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = mins
	b.add_theme_font_size_override("font_size", 20)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	return b


func _refresh_tabs() -> void:
	var titles := ["ИНВЕНТАРЬ", "КРАФТ", "БРОНЯ"]
	_title.text = titles[_tab]
	for i in range(_tab_btns.size()):
		_tab_btns[i].disabled = (i == _tab)
	var hints := [
		"Тап по инструменту = в руки. Тап по броне в сумке = надеть.",
		"Скрафти инструмент, блок или броню.",
		"4 слота брони. Тап по слоту = снять. Защита снижает урон.",
	]
	_status.text = hints[_tab]


func _rebuild_body() -> void:
	while _content.get_child_count() > 0:
		var ch := _content.get_child(0)
		_content.remove_child(ch)
		ch.free()
	match _tab:
		0:
			_fill_inv()
		1:
			_fill_craft()
		2:
			_fill_armor()


func _section(title: String) -> void:
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 22)
	h.modulate = Color(0.85, 0.95, 0.85)
	_content.add_child(h)


func _fill_inv() -> void:
	_section("Ресурсы")
	var grid := _grid()
	_content.add_child(grid)
	for id in RES_ORDER:
		grid.add_child(_info_card(RES_NAMES[id], "× %d" % Inv.count(id), Color(0.16, 0.22, 0.18)))

	_section("В руках")
	var eq_txt := "Кулак"
	if Controls.equipped != "" and Inv.count(Controls.equipped) > 0:
		eq_txt = TOOL_NAMES.get(Controls.equipped, Controls.equipped)
	else:
		Controls.equipped = ""
	var eq_l := Label.new()
	eq_l.text = eq_txt
	eq_l.add_theme_font_size_override("font_size", 18)
	eq_l.modulate = Color(0.7, 0.85, 1.0)
	_content.add_child(eq_l)

	_section("Инструменты")
	var tgrid := _grid()
	_content.add_child(tgrid)
	var any_tool := false
	for id in TOOL_ORDER:
		if Inv.count(id) <= 0:
			continue
		any_tool = true
		var mark := " ★" if Controls.equipped == id else ""
		var sub := "%d/%d%s" % [Inv.durability_of(id), Inv.max_dur(id), mark]
		var bg := Color(0.20, 0.28, 0.22) if Controls.equipped == id else Color(0.18, 0.20, 0.28)
		var tid := id
		var tname: String = TOOL_NAMES.get(id, id)
		tgrid.add_child(_action_card(tname, sub, bg, func() -> void:
			if Controls.equipped == tid:
				Controls.equipped = ""
				_status.text = "Снято: %s" % tname
			else:
				Controls.equipped = tid
				_status.text = "Экипировано: %s" % tname
			_rebuild_body()
		))
	if not any_tool:
		_hint("Пока пусто — скрафти во вкладке Крафт")

	var uneq := _btn("Убрать из рук (кулак)", Vector2(0, 48))
	uneq.pressed.connect(func() -> void:
		Controls.equipped = ""
		_status.text = "Экипировка снята"
		_rebuild_body()
	)
	_content.add_child(uneq)

	_section("Стройматериалы")
	var bgrid := _grid()
	_content.add_child(bgrid)
	var any_b := false
	for id in BUILD_ORDER:
		var c := Inv.count(id)
		if c <= 0:
			continue
		any_b = true
		var mark2 := " ★" if Controls.build_piece == id else ""
		var bg2 := Color(0.22, 0.24, 0.18) if Controls.build_piece == id else Color(0.18, 0.22, 0.20)
		var bid := id
		var bname: String = BUILD_NAMES.get(id, id)
		bgrid.add_child(_action_card(bname, "× %d%s" % [c, mark2], bg2, func() -> void:
			Controls.build_piece = bid
			Controls.build_mode = true
			_status.text = "Для стройки: %s" % bname
			_rebuild_body()
		))
	if not any_b:
		_hint("Нет блоков — скрафти, потом кнопка СТРОЙ")

	_section("Броня в сумке")
	var agrid := _grid()
	_content.add_child(agrid)
	var any_a := false
	for id in ARMOR_BAG_ORDER:
		var ac := Inv.count(id)
		if ac <= 0:
			continue
		any_a = true
		var an: String = ARMOR_NAMES.get(id, id)
		var aid := id
		agrid.add_child(_action_card(an, "× %d · DEF %d" % [ac, Inv.defense_of(id)], Color(0.22, 0.18, 0.28), func() -> void:
			if Inv.equip_armor(aid):
				_status.text = "Надето: %s" % an
			else:
				_status.text = "Не удалось надеть"
			_rebuild_body()
		))
	if not any_a:
		_hint("Нет брони в сумке — скрафти во вкладке Крафт")


func _fill_craft() -> void:
	for id in CraftDBScr.order():
		var rec: Dictionary = CraftDBScr.RECIPES[id]
		_content.add_child(_recipe_row(id, rec))


func _fill_armor() -> void:
	var def_l := Label.new()
	def_l.text = "Суммарная защита: %d  (урон режется)" % Inv.total_defense()
	def_l.add_theme_font_size_override("font_size", 20)
	def_l.modulate = Color(0.85, 0.9, 1.0)
	_content.add_child(def_l)

	_section("Слоты")
	var sgrid := _grid()
	_content.add_child(sgrid)
	for slot_info in ARMOR_SLOTS:
		var slot: String = slot_info["id"]
		var title: String = slot_info["title"]
		var worn: String = str(Inv.armor.get(slot, ""))
		var body := "пусто"
		var bg := Color(0.14, 0.14, 0.16)
		if worn != "":
			body = "%s · DEF %d" % [ARMOR_NAMES.get(worn, worn), Inv.defense_of(worn)]
			bg = Color(0.22, 0.26, 0.34)
		var sid := slot
		sgrid.add_child(_action_card(title, body, bg, func() -> void:
			if str(Inv.armor.get(sid, "")) != "":
				Inv.unequip_armor(sid)
				_status.text = "Снято со слота: %s" % title
				_rebuild_body()
			else:
				_status.text = "Слот пуст — надень броню из сумки (вкладка Инвентарь)"
		))

	_section("Броня в сумке (тап = надеть)")
	var bag := _grid()
	_content.add_child(bag)
	var any := false
	for id in ARMOR_BAG_ORDER:
		var c := Inv.count(id)
		if c <= 0:
			continue
		any = true
		var nm: String = ARMOR_NAMES.get(id, id)
		var aid := id
		bag.add_child(_action_card(nm, "× %d · DEF %d · %s" % [c, Inv.defense_of(id), Inv.armor_slot_of(id)], Color(0.22, 0.18, 0.28), func() -> void:
			if Inv.equip_armor(aid):
				_status.text = "Надето: %s" % nm
			_rebuild_body()
		))
	if not any:
		_hint("Скрафти броню во вкладке Крафт")


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g


func _hint(text: String) -> void:
	var empty := Label.new()
	empty.text = text
	empty.add_theme_font_size_override("font_size", 17)
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(empty)


func _info_card(title: String, value: String, bg: Color) -> PanelContainer:
	return _card_base(title, value, bg, Callable())


func _action_card(title: String, value: String, bg: Color, cb: Callable) -> PanelContainer:
	return _card_base(title, value, bg, cb)


func _card_base(title: String, value: String, bg: Color, cb: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(330, 70)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)

	# Кнопка-карточка целиком (надёжнее flat overlay)
	if cb.is_valid():
		var b := Button.new()
		b.flat = true
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.pressed.connect(cb)
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var t := Label.new()
		t.text = title
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_font_size_override("font_size", 20)
		hb.add_child(t)
		var v := Label.new()
		v.text = value
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_font_size_override("font_size", 18)
		v.modulate = Color(0.95, 0.9, 0.55)
		hb.add_child(v)
		p.add_child(b)
	else:
		var hb2 := HBoxContainer.new()
		p.add_child(hb2)
		var t2 := Label.new()
		t2.text = title
		t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2.add_theme_font_size_override("font_size", 20)
		hb2.add_child(t2)
		var v2 := Label.new()
		v2.text = value
		v2.add_theme_font_size_override("font_size", 18)
		v2.modulate = Color(0.95, 0.9, 0.55)
		hb2.add_child(v2)
	return p


func _recipe_row(id: String, rec: Dictionary) -> PanelContainer:
	var can := CraftDBScr.can_craft(id)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.18, 0.15) if can else Color(0.12, 0.12, 0.12)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.35, 0.7, 0.4) if can else Color(1, 1, 1, 0.08)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	var name_l := Label.new()
	name_l.text = str(rec["name"])
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_font_size_override("font_size", 22)
	top.add_child(name_l)

	var btn := _btn("Скрафтить", Vector2(150, 46))
	btn.disabled = not can
	var craft_id := id
	var craft_name := str(rec["name"])
	btn.pressed.connect(func() -> void:
		if CraftDBScr.craft(craft_id):
			if CraftDBScr.is_build_piece(craft_id):
				Controls.build_piece = craft_id
				_status.text = "Скрафчено: %s (стройка)" % craft_name
			elif CraftDBScr.is_armor(craft_id):
				_status.text = "Скрафчено: %s (надень во вкладке Броня)" % craft_name
			elif Inv.is_tool(craft_id):
				Controls.equipped = craft_id
				_status.text = "Скрафчено и в руках: %s" % craft_name
			else:
				_status.text = "Скрафчено: %s" % craft_name
			_rebuild_body()
		else:
			_status.text = "Не хватает ресурсов"
	)
	top.add_child(btn)

	var desc := Label.new()
	desc.text = str(rec.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 15)
	desc.modulate = Color(0.75, 0.8, 0.75)
	vb.add_child(desc)

	var cost_l := Label.new()
	cost_l.text = "Нужно: " + _cost_text(rec["cost"])
	cost_l.add_theme_font_size_override("font_size", 17)
	cost_l.modulate = Color(0.95, 0.85, 0.45) if can else Color(0.9, 0.45, 0.4)
	vb.add_child(cost_l)
	return p


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in cost:
		var need := int(cost[res])
		var have := Inv.count(str(res))
		var nm: String = RES_NAMES.get(str(res), str(res))
		parts.append("%s %d/%d" % [nm, have, need])
	return ", ".join(parts)
