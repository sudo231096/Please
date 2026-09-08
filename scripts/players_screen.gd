extends Control
## Экран сервера: список подключённых игроков + меню паузы.
## Данные о реальных игроках приходят от сервера (Net). В одиночной игре
## показывается только сам игрок — никаких выдуманных ников.

const Kit := preload("res://scripts/ui_kit.gd")

var _list: VBoxContainer
var _title: Label
var _count: Label
var _refresh_acc := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	_refresh()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.045, 0.055, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_right = -20
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# ---- левая часть: список игроков ----
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	var head := Kit.make_panel(Kit.BG, 12)
	left.add_child(head)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	head.add_child(hrow)

	_title = Kit.label("", 22, Kit.ACCENT)
	hrow.add_child(_title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(sp)
	_count = Kit.label("", 20, Kit.GOLD)
	hrow.add_child(_count)

	var listp := Kit.make_panel(Kit.BG, 12)
	listp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(listp)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	listp.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 5)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)

	# ---- правая часть: меню ----
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(240, 0)
	right.add_theme_constant_override("separation", 9)
	root.add_child(right)

	var resume := Kit.button("ВОЗОБНОВИТЬ", 18, true, Vector2(230, 60))
	resume.pressed.connect(_resume)
	right.add_child(resume)

	var shop := Kit.button("МАГАЗИН", 16, false, Vector2(230, 50))
	shop.pressed.connect(_open_shop)
	right.add_child(shop)

	var respawn := Kit.button("ПЕРЕРОДИТЬСЯ", 16, false, Vector2(230, 50))
	respawn.pressed.connect(_respawn)
	right.add_child(respawn)

	var settings := Kit.button("НАСТРОЙКИ", 16, false, Vector2(230, 50))
	settings.pressed.connect(_open_settings)
	right.add_child(settings)

	var disc := Kit.button("ОТКЛЮЧИТЬСЯ", 16, false, Vector2(230, 50))
	disc.add_theme_color_override("font_color", Kit.BAD)
	disc.pressed.connect(_disconnect)
	right.add_child(disc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	# сводка по себе
	var me := Kit.make_panel(Kit.BG_SOFT, 10)
	right.add_child(me)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 3)
	me.add_child(mv)
	mv.add_child(Kit.label("ВЫ", 13, Kit.TXT_DIM))
	mv.add_child(Kit.label(GameState.player_name, 17, Kit.TXT))
	mv.add_child(Kit.label("Уровень %d · ID %d" % [GameState.level, GameState.player_id], 12, Kit.TXT_DIM))
	mv.add_child(Kit.label("Убийств: %d" % GameState.kills, 12, Kit.TXT_DIM))


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()

	var online: bool = Net.state == "online" and GameState.active_server_id > 0
	var srv_name := "ОДИНОЧНАЯ ИГРА"
	var srv_type := "локальный мир"
	var players: int = 1
	var maxp: int = 1

	if online:
		var cfg: Dictionary = Net.current_server
		srv_name = String(cfg.get("name", "Сервер"))
		srv_type = "%s · выделенный" % String(cfg.get("region", "—"))
		players = maxi(1, Net.server_player_count)
		maxp = Net.server_max_players
	_title.text = srv_name
	_count.text = "%d/%d" % [players, maxp]

	var sub := Kit.label(srv_type, 13, Kit.TXT_DIM)
	_list.add_child(sub)

	# сам игрок всегда в списке
	_list.add_child(_player_row(GameState.player_name, GameState.level, "вы", true))

	if online:
		for pid in Net.remote_players.keys():
			var d: Dictionary = Net.remote_players[pid]
			var nm: String = String(d.get("name", "игрок"))
			var hp: float = float(d.get("hp", 100.0))
			var status: String = "в игре" if hp > 0.0 else "мёртв"
			_list.add_child(_player_row(nm, 1, status, false))
	else:
		var note := Kit.label(
			"\nВы играете в одиночном мире.\nЧтобы видеть других игроков, зайдите\nчерез «СЕРВЕРЫ» в главном меню.", 13, Kit.TXT_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(note)


func _player_row(nick: String, lvl: int, status: String, is_me: bool) -> Control:
	var p := Kit.make_panel(Color(0.14, 0.13, 0.11, 0.95) if is_me else Kit.BG_SOFT, 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)

	var av := Kit.make_panel(Color(0.2, 0.17, 0.12, 0.95), 6)
	av.custom_minimum_size = Vector2(38, 38)
	var al := Kit.label("👤", 18)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(al)
	h.add_child(av)

	var lv := Kit.label("ур.%d" % lvl, 13, Kit.ACCENT)
	lv.custom_minimum_size = Vector2(52, 0)
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lv)

	var nm := Kit.label(nick, 16, Kit.GOLD if is_me else Kit.TXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(nm)

	h.add_child(Kit.label(status, 13, Kit.OK if status == "в игре" or is_me else Kit.TXT_DIM))
	return p


func _process(delta: float) -> void:
	_refresh_acc += delta
	if _refresh_acc >= 2.0:
		_refresh_acc = 0.0
		_refresh()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var k := e as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_resume()


# ---------- действия ----------

func _resume() -> void:
	GameState.return_to_pos = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _respawn() -> void:
	GameState.hp = GameState.max_hp
	GameState.hunger = maxf(GameState.hunger, 50.0)
	GameState.thirst = maxf(GameState.thirst, 50.0)
	GameState.return_to_pos = false   # появиться в новой точке
	GameState.save_inventory()
	get_tree().change_scene_to_file("res://scenes/Loading.tscn")


func _disconnect() -> void:
	GameState.save_inventory()
	if Net.state != "offline":
		Net.disconnect_from_server(false)
	GameState.run_active = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _open_shop() -> void:
	var body := _modal("МАГАЗИН")
	body.add_child(Kit.label("Монеты: %d" % GameState.coins, 17, Kit.GOLD))
	for g in [["wood", 500, 60], ["stone", 400, 70], ["metal", 120, 150], ["cloth", 150, 80]]:
		var id: String = String(g[0])
		var qty: int = int(g[1])
		var price: int = int(g[2])
		var row := Kit.make_panel(Kit.BG_SOFT, 8)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		h.add_child(Kit.label("%s x%d" % [GameState.item_name(id), qty], 16))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		h.add_child(Kit.label("🪙%d" % price, 15, Kit.GOLD))
		var b := Kit.button("КУПИТЬ", 14, true, Vector2(110, 42))
		b.pressed.connect(func() -> void:
			if GameState.spend_coins(price):
				GameState.add_item(id, qty)
				GameState.save_inventory()
			_close_modal()
			_open_shop()
		)
		h.add_child(b)
		body.add_child(row)


func _open_settings() -> void:
	var body := _modal("НАСТРОЙКИ")
	body.add_child(Kit.label("Чувствительность обзора", 16))
	var sl := HSlider.new()
	sl.min_value = 0.0005
	sl.max_value = 0.008
	sl.step = 0.0001
	sl.value = GameState.mouse_sens
	sl.custom_minimum_size = Vector2(0, 40)
	var vl := Kit.label("%.4f" % GameState.mouse_sens, 14, Kit.TXT_DIM)
	sl.value_changed.connect(func(v: float) -> void:
		GameState.mouse_sens = v
		GameState.save_settings()
		vl.text = "%.4f" % v
	)
	body.add_child(sl)
	body.add_child(vl)
	var lay := Kit.button("Кнопки: %s" % ("СЛЕВА" if GameState.buttons_left else "СПРАВА"), 16, false, Vector2(240, 48))
	lay.pressed.connect(func() -> void:
		GameState.buttons_left = not GameState.buttons_left
		GameState.save_settings()
		lay.text = "Кнопки: %s" % ("СЛЕВА" if GameState.buttons_left else "СПРАВА")
	)
	body.add_child(lay)


var _modal_node: Control = null

func _close_modal() -> void:
	if _modal_node and is_instance_valid(_modal_node):
		_modal_node.queue_free()
	_modal_node = null


func _modal(title: String) -> VBoxContainer:
	_close_modal()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_modal_node = overlay

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var vs := get_viewport_rect().size
	var w: float = minf(560.0, vs.x * 0.85)
	var h: float = minf(420.0, vs.y * 0.85)
	var panel := Kit.make_panel(Color(0.09, 0.095, 0.11, 0.99), 14)
	panel.custom_minimum_size = Vector2(w, h)
	panel.position = Vector2(vs.x * 0.5 - w * 0.5, vs.y * 0.5 - h * 0.5)
	overlay.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 9)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Kit.label(title, 22, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Kit.button("✕", 18, false, Vector2(46, 46))
	x.pressed.connect(_close_modal)
	head.add_child(x)
	col.add_child(HSeparator.new())

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	Kit.fade_in(overlay)
	return body
