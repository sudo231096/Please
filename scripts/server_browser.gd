extends Control
## Выбор сервера в стиле Rust Mobile. Количество игроков берётся только с самого
## сервера (HTTP /status). Никаких ботов и случайных чисел.

const Kit := preload("res://scripts/ui_kit.gd")

var _rows: Array = []
var _info: Label
var _acc := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()
	_refresh_all()
	Net.connection_state_changed.connect(_on_state)
	Net.server_message.connect(func(t: String) -> void: _info.text = t)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.06, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var t := Kit.label("ВЫБОР СЕРВЕРА", 26, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var refresh := Kit.button("ОБНОВИТЬ", 15, false, Vector2(140, 46))
	refresh.pressed.connect(_refresh_all)
	head.add_child(refresh)
	var back := Kit.button("НАЗАД", 15, false, Vector2(120, 46))
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	head.add_child(back)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)

	for s in NetConfig.servers:
		var cfg: Dictionary = s
		var p := Kit.make_panel(Kit.BG, 10)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		p.add_child(h)

		var nm := Kit.label("%s" % String(cfg["name"]), 20, Kit.TXT)
		nm.custom_minimum_size = Vector2(190, 56)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(nm)

		var rg := Kit.label(String(cfg["region"]), 14, Kit.TXT_DIM)
		rg.custom_minimum_size = Vector2(70, 0)
		rg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(rg)

		var cnt := Kit.label("—/85", 20, Kit.GOLD)
		cnt.custom_minimum_size = Vector2(110, 0)
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(cnt)

		var st := Kit.label("ПРОВЕРКА…", 15, Kit.TXT_DIM)
		st.custom_minimum_size = Vector2(190, 0)
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(st)

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)

		var join := Kit.button("ВОЙТИ", 17, true, Vector2(150, 52))
		join.pressed.connect(func() -> void: _join(cfg))
		h.add_child(join)

		list.add_child(p)
		_rows.append({"cfg": cfg, "count": cnt, "status": st, "btn": join})

	_info = Kit.label("", 14, Kit.TXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 60)
	root.add_child(_info)
	_update_info()


func _update_info(extra: String = "") -> void:
	var dep := 0
	for s in NetConfig.servers:
		if NetConfig.is_deployed(s):
			dep += 1
	var base := ""
	if dep == 0:
		base = "Серверы ещё не развёрнуты — в конфигурации нет адресов. Инструкция по бесплатному хостингу: SERVERS.md. Пока играйте в одиночном мире через «НОВЫЙ МАТЧ»."
	else:
		base = "Развёрнуто серверов: %d из 5. Счётчик игроков приходит с самого сервера." % dep
	_info.text = (extra + "\n" + base) if extra != "" else base


func _refresh_all() -> void:
	for r in _rows:
		var cfg: Dictionary = r["cfg"]
		if not NetConfig.is_deployed(cfg):
			r["status"].text = "НЕ РАЗВЁРНУТ"
			r["status"].modulate = Color(0.6, 0.6, 0.62)
			r["count"].text = "—/85"
			r["btn"].disabled = true
			continue
		r["btn"].disabled = false
		r["status"].text = "ПРОВЕРКА…"
		_query(r)


func _query(row: Dictionary) -> void:
	var req := HTTPRequest.new()
	req.timeout = 4.0
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		var st: Label = row["status"]
		var cl: Label = row["count"]
		if code == 200:
			var j: Variant = JSON.parse_string(body.get_string_from_utf8())
			if typeof(j) == TYPE_DICTIONARY:
				var pl: int = int(j.get("players", 0))
				var mx: int = int(j.get("max", 85))
				cl.text = "%d/%d" % [pl, mx]
				if pl >= mx:
					st.text = "ЗАПОЛНЕН"
					st.modulate = Kit.BAD
					row["btn"].disabled = true
				else:
					st.text = "ОНЛАЙН"
					st.modulate = Kit.OK
					row["btn"].disabled = false
			else:
				st.text = "ОШИБКА ОТВЕТА"
				st.modulate = Color(1.0, 0.6, 0.3)
		else:
			st.text = "НЕДОСТУПЕН"
			st.modulate = Kit.BAD
			cl.text = "—/85"
			row["btn"].disabled = true
		req.queue_free()
	)
	if req.request(NetConfig.status_url(row["cfg"])) != OK:
		row["status"].text = "НЕДОСТУПЕН"
		row["status"].modulate = Kit.BAD
		req.queue_free()


func _join(cfg: Dictionary) -> void:
	if not NetConfig.is_deployed(cfg):
		_update_info("Сервер «%s» не развёрнут — нет адреса." % String(cfg["name"]))
		return
	_update_info("Подключение к %s…" % String(cfg["name"]))
	GameState.set_active_server(int(cfg["id"]))
	Net.connect_to_server(cfg)


func _on_state(s: String) -> void:
	if s == "online":
		GameState.run_active = true
		get_tree().change_scene_to_file("res://scenes/Loading.tscn")
	elif s == "error":
		_update_info("Не удалось подключиться: " + Net.last_error)


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 8.0:
		_acc = 0.0
		_refresh_all()
