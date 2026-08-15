extends CanvasLayer
## Полноэкранный инвентарь + крафт. Открывается кнопками HUD.

const CraftDBScr = preload("res://scripts/craft.gd")

const RES_ORDER := ["wood", "stone", "sulfur", "meat"]
const RES_NAMES := {
	"wood": "Дерево",
	"stone": "Камень",
	"sulfur": "Сера",
	"meat": "Мясо",
}
const TOOL_ORDER := [
	"axe", "pickaxe", "sword", "bow", "crossbow", "rod",
	"stone_axe", "stone_pickaxe", "stone_sword", "stone_bow", "stone_crossbow", "stone_rod",
]
const TOOL_NAMES := {
	"axe": "Топор",
	"pickaxe": "Кирка",
	"sword": "Меч",
	"bow": "Лук",
	"crossbow": "Арбалет",
	"rod": "Удочка",
	"stone_axe": "Кам. топор",
	"stone_pickaxe": "Кам. кирка",
	"stone_sword": "Кам. меч",
	"stone_bow": "Кам. лук",
	"stone_crossbow": "Кам. арбалет",
	"stone_rod": "Кам. удочка",
}

var _tab := 0  # 0 inv, 1 craft
var _content: VBoxContainer
var _tab_inv: Button
var _tab_craft: Button
var _title: Label
var _status: Label


func _ready() -> void:
	layer = 20
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


func close() -> void:
	visible = false
	Controls.ui_open = false
	get_tree().paused = false


func _show() -> void:
	visible = true
	Controls.ui_open = true
	Controls.move_vector = Vector2.ZERO
	Controls.jump_queued = false
	Controls.attack_queued = false
	get_tree().paused = true
	_refresh_tabs()
	_rebuild_body()


func _on_inv_changed() -> void:
	if visible:
		_rebuild_body()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.12, 0.97)
	sb.border_color = Color(0.35, 0.55, 0.40, 1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)

	_title = Label.new()
	_title.text = "ИНВЕНТАРЬ"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 30)
	head.add_child(_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(64, 56)
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	outer.add_child(tabs)

	_tab_inv = Button.new()
	_tab_inv.text = "Инвентарь"
	_tab_inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_inv.custom_minimum_size = Vector2(0, 52)
	_tab_inv.add_theme_font_size_override("font_size", 22)
	_tab_inv.pressed.connect(func() -> void:
		_tab = 0
		_refresh_tabs()
		_rebuild_body()
	)
	tabs.add_child(_tab_inv)

	_tab_craft = Button.new()
	_tab_craft.text = "Крафт"
	_tab_craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_craft.custom_minimum_size = Vector2(0, 52)
	_tab_craft.add_theme_font_size_override("font_size", 22)
	_tab_craft.pressed.connect(func() -> void:
		_tab = 1
		_refresh_tabs()
		_rebuild_body()
	)
	tabs.add_child(_tab_craft)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	_status.modulate = Color(0.75, 0.9, 0.75)
	outer.add_child(_status)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(680, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)


func _refresh_tabs() -> void:
	_title.text = "ИНВЕНТАРЬ" if _tab == 0 else "КРАФТ"
	_tab_inv.disabled = _tab == 0
	_tab_craft.disabled = _tab == 1
	_status.text = "Ресурсы и инструменты · тап по инструменту = экипировать" if _tab == 0 else "Выбери рецепт и нажми Скрафтить"


func _rebuild_body() -> void:
	while _content.get_child_count() > 0:
		var ch := _content.get_child(0)
		_content.remove_child(ch)
		ch.free()
	if _tab == 0:
		_fill_inv()
	else:
		_fill_craft()


func _fill_inv() -> void:
	var h_res := Label.new()
	h_res.text = "Ресурсы"
	h_res.add_theme_font_size_override("font_size", 22)
	h_res.modulate = Color(0.85, 0.95, 0.85)
	_content.add_child(h_res)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)

	for id in RES_ORDER:
		grid.add_child(_slot_card(RES_NAMES.get(id, id), "× %d" % Inv.count(id), Color(0.16, 0.22, 0.18), ""))

	var h_tools := Label.new()
	h_tools.text = "Инструменты"
	h_tools.add_theme_font_size_override("font_size", 22)
	h_tools.modulate = Color(0.85, 0.95, 0.85)
	_content.add_child(h_tools)

	var eq := Label.new()
	if Controls.equipped != "" and Inv.count(Controls.equipped) > 0:
		eq.text = "В руках: %s" % TOOL_NAMES.get(Controls.equipped, Controls.equipped)
	else:
		eq.text = "В руках: кулак"
		Controls.equipped = ""
	eq.add_theme_font_size_override("font_size", 18)
	eq.modulate = Color(0.7, 0.85, 1.0)
	_content.add_child(eq)

	var any_tool := false
	var tgrid := GridContainer.new()
	tgrid.columns = 2
	tgrid.add_theme_constant_override("h_separation", 10)
	tgrid.add_theme_constant_override("v_separation", 10)
	tgrid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(tgrid)

	for id in TOOL_ORDER:
		if Inv.count(id) <= 0:
			continue
		any_tool = true
		var dur := Inv.durability_of(id)
		var mx := Inv.max_dur(id)
		var mark := " ★" if Controls.equipped == id else ""
		var sub := "%d/%d%s" % [dur, mx, mark]
		var bg := Color(0.20, 0.28, 0.22) if Controls.equipped == id else Color(0.18, 0.20, 0.28)
		var card := _slot_card(TOOL_NAMES.get(id, id), sub, bg, id)
		tgrid.add_child(card)

	if not any_tool:
		var empty := Label.new()
		empty.text = "Пока пусто — скрафть инструмент во вкладке Крафт"
		empty.add_theme_font_size_override("font_size", 18)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(empty)

	var uneq := Button.new()
	uneq.text = "Убрать из рук (кулак)"
	uneq.custom_minimum_size = Vector2(0, 48)
	uneq.add_theme_font_size_override("font_size", 18)
	uneq.pressed.connect(func() -> void:
		Controls.equipped = ""
		_status.text = "Экипировка снята"
		_rebuild_body()
	)
	_content.add_child(uneq)


func _slot_card(title: String, value: String, bg: Color, equip_id: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(320, 72)
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

	var hb := HBoxContainer.new()
	p.add_child(hb)
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_size_override("font_size", 22)
	hb.add_child(t)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 20)
	v.modulate = Color(0.95, 0.9, 0.55)
	hb.add_child(v)

	if equip_id != "":
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(func() -> void:
			if Controls.equipped == equip_id:
				Controls.equipped = ""
				_status.text = "Снято: %s" % title
			else:
				Controls.equipped = equip_id
				_status.text = "Экипировано: %s" % title
			_rebuild_body()
		)
		p.add_child(btn)
	return p


func _fill_craft() -> void:
	for id in CraftDBScr.order():
		var rec: Dictionary = CraftDBScr.RECIPES[id]
		_content.add_child(_recipe_row(id, rec))


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
	name_l.add_theme_font_size_override("font_size", 24)
	top.add_child(name_l)

	var btn := Button.new()
	btn.text = "Скрафтить"
	btn.custom_minimum_size = Vector2(150, 48)
	btn.add_theme_font_size_override("font_size", 20)
	btn.disabled = not can
	var craft_id := id
	var craft_name := str(rec["name"])
	btn.pressed.connect(func() -> void:
		if CraftDBScr.craft(craft_id):
			Controls.equipped = craft_id
			_status.text = "Скрафчено и экипировано: %s" % craft_name
			_rebuild_body()
		else:
			_status.text = "Не хватает ресурсов"
	)
	top.add_child(btn)

	var desc := Label.new()
	desc.text = str(rec.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 16)
	desc.modulate = Color(0.75, 0.8, 0.75)
	vb.add_child(desc)

	var cost_l := Label.new()
	cost_l.text = "Нужно: " + _cost_text(rec["cost"])
	cost_l.add_theme_font_size_override("font_size", 18)
	cost_l.modulate = Color(0.95, 0.85, 0.45) if can else Color(0.9, 0.45, 0.4)
	vb.add_child(cost_l)

	if Inv.is_tool(id) and Inv.count(id) > 0:
		var own := Label.new()
		own.text = "Уже есть · прочность %d/%d (крафт обновит)" % [Inv.durability_of(id), Inv.max_dur(id)]
		own.add_theme_font_size_override("font_size", 16)
		own.modulate = Color(0.6, 0.85, 1.0)
		vb.add_child(own)

	return p


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for res in cost:
		var need := int(cost[res])
		var have := Inv.count(str(res))
		var nm: String = RES_NAMES.get(str(res), str(res))
		parts.append("%s %d/%d" % [nm, have, need])
	return ", ".join(parts)
