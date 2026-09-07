extends Node3D
## Меню выбора сервера. Количество игроков берётся ТОЛЬКО с самого сервера
## (HTTP GET http://host:port+1/status). Никаких ботов и случайных чисел:
## если сервер недоступен — так и пишем.

var _rows: Array = []          # [{cfg, label, btn, status}]
var _info: Label
var _refresh_timer := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_ui()
	_refresh_all()
	Net.connection_state_changed.connect(_on_state)
	Net.server_message.connect(_on_msg)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var title := Label.new()
	title.text = "SERVERS"
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.9, 0.75, 0.4)
	title.offset_left = 40
	title.offset_top = 24
	title.offset_right = 500
	title.offset_bottom = 80
	layer.add_child(title)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 96
	v.offset_bottom = 96 + 5 * 78
	layer.add_child(v)

	for s in NetConfig.servers:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, 68)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		row.add_child(h)

		var nm := Label.new()
		nm.text = "%s  [%s]" % [String(s["name"]), String(s["region"])]
		nm.add_theme_font_size_override("font_size", 26)
		nm.custom_minimum_size = Vector2(300, 0)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(nm)

		var cnt := Label.new()
		cnt.text = "—/85"
		cnt.add_theme_font_size_override("font_size", 26)
		cnt.custom_minimum_size = Vector2(150, 0)
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(cnt)

		var st := Label.new()
		st.text = "CHECKING"
		st.add_theme_font_size_override("font_size", 22)
		st.custom_minimum_size = Vector2(260, 0)
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		st.modulate = Color(0.7, 0.7, 0.7)
		h.add_child(st)

		var btn := Button.new()
		btn.text = "ПОДКЛЮЧИТЬСЯ"
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(240, 54)
		btn.add_theme_font_size_override("font_size", 22)
		var cfg: Dictionary = s
		btn.pressed.connect(func() -> void: _join(cfg))
		h.add_child(btn)

		v.add_child(row)
		_rows.append({"cfg": s, "count": cnt, "status": st, "btn": btn})

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 20)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.anchor_left = 0.0
	_info.anchor_right = 1.0
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = 40
	_info.offset_right = -40
	_info.offset_top = -200
	_info.offset_bottom = -80
	_info.modulate = Color(0.75, 0.78, 0.8)
	layer.add_child(_info)
	_update_info()

	var back := Button.new()
	back.text = "НАЗАД"
	back.focus_mode = Control.FOCUS_NONE
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 40
	back.offset_right = 220
	back.offset_top = -70
	back.offset_bottom = -20
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	layer.add_child(back)

	var refresh := Button.new()
	refresh.text = "ОБНОВИТЬ"
	refresh.focus_mode = Control.FOCUS_NONE
	refresh.anchor_left = 1.0
	refresh.anchor_right = 1.0
	refresh.anchor_top = 1.0
	refresh.anchor_bottom = 1.0
	refresh.offset_left = -240
	refresh.offset_right = -40
	refresh.offset_top = -70
	refresh.offset_bottom = -20
	refresh.add_theme_font_size_override("font_size", 22)
	refresh.pressed.connect(_refresh_all)
	layer.add_child(refresh)


func _update_info(extra: String = "") -> void:
	var deployed := 0
	for s in NetConfig.servers:
		if NetConfig.is_deployed(s):
			deployed += 1
	var base := ""
	if deployed == 0:
		base = "Ни один сервер пока не развёрнут. Игровой сервер — отдельный процесс (godot --headless -- --server --id=N --port=PORT); адреса задаются в scripts/net_config.gd или user://servers.cfg. Инструкция для бесплатного хостинга — SERVERS.md в репозитории."
	else:
		base = "Развёрнуто серверов: %d из 5. Число игроков запрашивается напрямую у сервера." % deployed
	if extra != "":
		base = extra + "\n" + base
	_info.text = base


func _refresh_all() -> void:
	for r in _rows:
		var cfg: Dictionary = r["cfg"]
		if not NetConfig.is_deployed(cfg):
			r["status"].text = "NOT DEPLOYED"
			r["status"].modulate = Color(0.6, 0.6, 0.62)
			r["count"].text = "—/85"
			r["btn"].disabled = true
			continue
		r["btn"].disabled = false
		r["status"].text = "CHECKING…"
		r["status"].modulate = Color(0.7, 0.7, 0.7)
		_query_status(r)


func _query_status(row: Dictionary) -> void:
	var cfg: Dictionary = row["cfg"]
	var req := HTTPRequest.new()
	req.timeout = 4.0
	add_child(req)
	req.request_completed.connect(func(_res: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray) -> void:
		var st: Label = row["status"]
		var cl: Label = row["count"]
		if code == 200:
			var j: Variant = JSON.parse_string(body.get_string_from_utf8())
			if typeof(j) == TYPE_DICTIONARY:
				var players: int = int(j.get("players", 0))
				var maxp: int = int(j.get("max", NetConfig.MAX_PLAYERS))
				cl.text = "%d/%d" % [players, maxp]
				if players >= maxp:
					st.text = "FULL"
					st.modulate = Color(1.0, 0.45, 0.4)
					row["btn"].disabled = true
				else:
					st.text = "ONLINE"
					st.modulate = Color(0.5, 1.0, 0.55)
					row["btn"].disabled = false
			else:
				st.text = "BAD RESPONSE"
				st.modulate = Color(1.0, 0.6, 0.3)
		else:
			st.text = "OFFLINE"
			st.modulate = Color(0.9, 0.4, 0.4)
			cl.text = "—/85"
			row["btn"].disabled = true
		req.queue_free()
	)
	var err := req.request(NetConfig.status_url(cfg))
	if err != OK:
		row["status"].text = "OFFLINE"
		row["status"].modulate = Color(0.9, 0.4, 0.4)
		req.queue_free()


func _join(cfg: Dictionary) -> void:
	_update_info("Подключение к %s…" % String(cfg["name"]))
	GameState.set_active_server(int(cfg["id"]))
	Net.connect_to_server(cfg)


func _on_state(s: String) -> void:
	if s == "online":
		_update_info("Подключено. Загружаю мир…")
		get_tree().change_scene_to_file("res://scenes/Loading.tscn")
	elif s == "error":
		_update_info("Ошибка: " + Net.last_error)


func _on_msg(text: String) -> void:
	_update_info(text)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 8.0:
		_refresh_timer = 0.0
		_refresh_all()
