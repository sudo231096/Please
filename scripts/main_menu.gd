extends Control
## Меню выбора уровня 1..250 + магазин (урон и скины).

const MAX_LEVEL := 250

var _coin_l: Label
var _shop: Control
var _shop_coin_l: Label
var _dmg_lbl: Label
var _dmg_btn: Button
var _skin_btns := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_bg()
	_build_header()
	_build_level_grid()
	_build_shop()
	Progress.coins_changed.connect(_refresh)
	Progress.shop_changed.connect(_refresh)
	_refresh()


func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.18, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	for i in range(12):
		var t := ColorRect.new()
		t.color = Color(0.15, 0.28, 0.16, 0.55)
		t.size = Vector2(28, randf_range(120, 280))
		t.position = Vector2(40 + i * 105, 720 - t.size.y)
		add_child(t)


func _build_header() -> void:
	var title := Label.new()
	title.text = "FOREST BANDIT RUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.offset_top = 18
	title.offset_bottom = 82
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.85, 0.95, 0.7)
	add_child(title)

	# монеты — сверху справа
	_coin_l = Label.new()
	_coin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_l.anchor_left = 0.6
	_coin_l.anchor_right = 1.0
	_coin_l.offset_left = -20
	_coin_l.offset_right = -20
	_coin_l.offset_top = 16
	_coin_l.offset_bottom = 56
	_coin_l.add_theme_font_size_override("font_size", 30)
	_coin_l.modulate = Color(1.0, 0.85, 0.3)
	add_child(_coin_l)

	var sub := Label.new()
	sub.text = "2D · 250 уровней · разбойники в лесу\nОткрыто уровней: %d / %d" % [Progress.unlocked, MAX_LEVEL]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.05
	sub.anchor_right = 0.95
	sub.offset_top = 82
	sub.offset_bottom = 142
	sub.add_theme_font_size_override("font_size", 20)
	add_child(sub)

	var play := Button.new()
	play.text = "Играть · уровень %d" % Progress.unlocked
	play.focus_mode = Control.FOCUS_NONE
	play.anchor_left = 0.5
	play.anchor_right = 0.5
	play.offset_left = -300
	play.offset_right = -30
	play.offset_top = 152
	play.offset_bottom = 236
	play.add_theme_font_size_override("font_size", 30)
	play.pressed.connect(func() -> void:
		Progress.current = Progress.unlocked
		get_tree().change_scene_to_file("res://scenes/Level.tscn")
	)
	add_child(play)

	var shop_btn := Button.new()
	shop_btn.text = "МАГАЗИН"
	shop_btn.focus_mode = Control.FOCUS_NONE
	shop_btn.anchor_left = 0.5
	shop_btn.anchor_right = 0.5
	shop_btn.offset_left = 30
	shop_btn.offset_right = 300
	shop_btn.offset_top = 152
	shop_btn.offset_bottom = 236
	shop_btn.add_theme_font_size_override("font_size", 30)
	shop_btn.modulate = Color(1.0, 0.85, 0.4)
	shop_btn.pressed.connect(func() -> void:
		_shop.visible = not _shop.visible
		_refresh()
	)
	add_child(shop_btn)


func _build_level_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.08
	scroll.anchor_right = 0.92
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 260
	scroll.offset_bottom = -20
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for i in range(1, MAX_LEVEL + 1):
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(72, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		var unlocked := i <= Progress.unlocked
		b.disabled = not unlocked
		if i == Progress.unlocked:
			b.modulate = Color(0.7, 1.0, 0.6)
		var lvl := i
		b.pressed.connect(func() -> void:
			Progress.current = lvl
			get_tree().change_scene_to_file("res://scenes/Level.tscn")
		)
		grid.add_child(b)


func _build_shop() -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.visible = false
	add_child(_shop)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -320
	panel.offset_bottom = 320
	_shop.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var title := Label.new()
	title.text = "МАГАЗИН"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(1.0, 0.85, 0.4)
	v.add_child(title)

	_shop_coin_l = Label.new()
	_shop_coin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coin_l.add_theme_font_size_override("font_size", 24)
	_shop_coin_l.modulate = Color(1.0, 0.85, 0.3)
	v.add_child(_shop_coin_l)

	# --- урон ---
	_dmg_lbl = Label.new()
	_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dmg_lbl.add_theme_font_size_override("font_size", 20)
	v.add_child(_dmg_lbl)

	_dmg_btn = Button.new()
	_dmg_btn.focus_mode = Control.FOCUS_NONE
	_dmg_btn.add_theme_font_size_override("font_size", 22)
	_dmg_btn.pressed.connect(func() -> void:
		Progress.buy_damage_upgrade()
		_refresh()
	)
	v.add_child(_dmg_btn)

	var sep := HSeparator.new()
	v.add_child(sep)

	var skins_title := Label.new()
	skins_title.text = "Скины"
	skins_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skins_title.add_theme_font_size_override("font_size", 24)
	v.add_child(skins_title)

	for id in [1, 2, 3]:
		var skin_id: int = id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void:
			_on_skin_pressed(skin_id)
		)
		_skin_btns[skin_id] = b
		v.add_child(b)

	var unequip := Button.new()
	unequip.text = "Снять скин"
	unequip.focus_mode = Control.FOCUS_NONE
	unequip.add_theme_font_size_override("font_size", 20)
	unequip.pressed.connect(func() -> void:
		Progress.select_skin(0)
		_refresh()
	)
	v.add_child(unequip)

	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void:
		_shop.visible = false
	)
	v.add_child(close)


func _on_skin_pressed(id: int) -> void:
	if not Progress.owned_skins.has(id):
		Progress.buy_skin(id)
	else:
		Progress.select_skin(id)
	_refresh()


func _refresh() -> void:
	if _coin_l:
		_coin_l.text = "Монеты: %d" % Progress.coins
	if _shop_coin_l:
		_shop_coin_l.text = "Монеты: %d" % Progress.coins
	if _dmg_lbl:
		_dmg_lbl.text = "Урон: %d  (уровень прокачки %d)" % [Progress.player_damage(), Progress.damage_level]
	if _dmg_btn:
		_dmg_btn.text = "Прокачать урон — %d монет" % Progress.damage_upgrade_cost()
		_dmg_btn.disabled = Progress.coins < Progress.damage_upgrade_cost()
	for id in [1, 2, 3]:
		var b: Button = _skin_btns[id]
		var info: Dictionary = Progress.SKIN_INFO[id]
		var owned: bool = Progress.owned_skins.has(id)
		var selected: bool = Progress.selected_skin == id
		if not owned:
			b.text = "%s (%s) — купить: %d монет" % [info["name"], info["desc"], info["cost"]]
			b.disabled = Progress.coins < int(info["cost"])
			b.modulate = Color.WHITE
		elif selected:
			b.text = "%s (%s) — ВЫБРАН" % [info["name"], info["desc"]]
			b.disabled = false
			b.modulate = Color(0.6, 1.0, 0.6)
		else:
			b.text = "%s (%s) — надеть" % [info["name"], info["desc"]]
			b.disabled = false
			b.modulate = Color.WHITE
