extends Control
## Главное меню: Играть / Магазин / Промокоды.

const UI = preload("res://scripts/ui_theme.gd")

var _coins_l: Label
var _agent_l: Label
var _status: Label
var _shop_layer: CanvasLayer
var _promo_layer: CanvasLayer
var _shop_list: VBoxContainer
var _promo_edit: LineEdit
var _promo_status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	_build_main()
	_build_shop()
	_build_promo()
	if not GameData.data_changed.is_connected(_refresh_header):
		GameData.data_changed.connect(_refresh_header)
	_refresh_header()


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# side neon
	var left := ColorRect.new()
	left.color = Color(0.2, 0.75, 1.0, 0.25)
	left.anchor_bottom = 1.0
	left.offset_right = 6
	add_child(left)
	var right := ColorRect.new()
	right.color = Color(1.0, 0.4, 0.25, 0.25)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -6
	add_child(right)


func _build_main() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.offset_bottom = 70
	add_child(top)

	_coins_l = UI.make_label("Монеты: 0", 24, Color(1.0, 0.9, 0.4))
	_coins_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_coins_l)
	_agent_l = UI.make_label("Агент: Камера Мен", 22, Color(0.7, 0.9, 1.0))
	_agent_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_agent_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_agent_l)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	cc.add_child(box)

	var title := UI.make_label("SKIBIDI TOILET SURVIVAL", 42, Color(0.55, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := UI.make_label("выбери агента и готовься к бою", 18, Color(0.7, 0.75, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	# preview card of starter agent
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(360, 120)
	preview.add_theme_stylebox_override("panel", UI.panel_style(Color(0.1, 0.14, 0.2, 0.95)))
	box.add_child(preview)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 16)
	preview.add_child(ph)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(88, 88)
	icon.color = Color(0.25, 0.45, 0.75)
	ph.add_child(icon)
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pv)
	pv.add_child(UI.make_label("Стартовый агент", 16, Color(0.65, 0.75, 0.85)))
	pv.add_child(UI.make_label("Камера Мен", 28, Color(0.85, 0.95, 1.0)))
	pv.add_child(UI.make_label("Камера на голове · уже в отряде", 16, Color(0.7, 0.8, 0.7)))

	var play := UI.make_btn("Играть", Vector2(320, 72), 28)
	play.pressed.connect(_on_play)
	box.add_child(play)

	var shop := UI.make_btn("Магазин", Vector2(320, 64), 26)
	shop.pressed.connect(func() -> void: _shop_layer.visible = true; _rebuild_shop())
	box.add_child(shop)

	var promo := UI.make_btn("Промокоды", Vector2(320, 64), 26)
	promo.pressed.connect(func() -> void: _promo_layer.visible = true; _promo_status.text = "Введи код и нажми Активировать")
	box.add_child(promo)

	_status = UI.make_label("", 18, Color(0.8, 0.95, 0.7))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func _refresh_header() -> void:
	if _coins_l:
		_coins_l.text = "Монеты: %d" % GameData.coins
	if _agent_l:
		_agent_l.text = "Агент: %s" % GameData.agent_name(GameData.selected_agent)


func _on_play() -> void:
	_status.text = "Загрузка... Агент: %s" % GameData.agent_name(GameData.selected_agent)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _build_shop() -> void:
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 30
	_shop_layer.visible = false
	add_child(_shop_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 520)
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var ht := UI.make_label("МАГАЗИН АГЕНТОВ", 28, Color(0.7, 0.95, 1.0))
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	var close := UI.make_btn("✕", Vector2(56, 48), 24)
	close.pressed.connect(func() -> void: _shop_layer.visible = false)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	v.add_child(scroll)
	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_shop_list)


func _rebuild_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	# wait free next frame-ish: free sync
	while _shop_list.get_child_count() > 0:
		var ch := _shop_list.get_child(0)
		_shop_list.remove_child(ch)
		ch.free()
	for id in GameData.AGENTS.keys():
		var info: Dictionary = GameData.AGENTS[id]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.15, 0.2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		row.add_theme_stylebox_override("panel", sb)
		_shop_list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.color = info["color"]
		h.add_child(icon)
		var vv := VBoxContainer.new()
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(vv)
		vv.add_child(UI.make_label(str(info["name"]), 24, Color(0.9, 0.95, 1.0)))
		var desc := UI.make_label(str(info["desc"]), 16, Color(0.7, 0.75, 0.8))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vv.add_child(desc)
		var price := int(info["price"])
		var unlocked: bool = GameData.is_unlocked(id)
		var selected: bool = GameData.selected_agent == id
		var btn := UI.make_btn("", Vector2(150, 56), 20)
		if selected:
			btn.text = "Выбран"
			btn.disabled = true
		elif unlocked:
			btn.text = "Выбрать"
			var aid := str(id)
			btn.pressed.connect(func() -> void:
				_status.text = GameData.select_agent(aid)
				_rebuild_shop()
			)
		else:
			btn.text = "%d монет" % price
			var aid2 := str(id)
			btn.pressed.connect(func() -> void:
				_status.text = GameData.try_buy(aid2)
				_rebuild_shop()
			)
		h.add_child(btn)


func _build_promo() -> void:
	_promo_layer = CanvasLayer.new()
	_promo_layer.layer = 31
	_promo_layer.visible = false
	add_child(_promo_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_promo_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 320)
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var ht := UI.make_label("ПРОМОКОДЫ", 28, Color(0.7, 0.95, 1.0))
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	var close := UI.make_btn("✕", Vector2(56, 48), 24)
	close.pressed.connect(func() -> void: _promo_layer.visible = false)
	head.add_child(close)
	v.add_child(UI.make_label("Введи код (например SKIBIDI)", 18, Color(0.75, 0.8, 0.85)))
	_promo_edit = LineEdit.new()
	_promo_edit.placeholder_text = "PROMOCODE"
	_promo_edit.custom_minimum_size = Vector2(0, 52)
	_promo_edit.add_theme_font_size_override("font_size", 24)
	v.add_child(_promo_edit)
	var act := UI.make_btn("Активировать", Vector2(0, 56), 24)
	act.pressed.connect(_on_promo)
	v.add_child(act)
	_promo_status = UI.make_label("", 18, Color(0.85, 0.95, 0.7))
	_promo_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_promo_status)
	v.add_child(UI.make_label("Коды: SKIBIDI · CAMERA · TOILET · FREE100", 15, Color(0.55, 0.6, 0.7)))


func _on_promo() -> void:
	var msg := GameData.try_promo(_promo_edit.text)
	_promo_status.text = msg
	_status.text = msg
	_promo_edit.text = ""
