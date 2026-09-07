extends Node3D
## Главное меню в стиле Rust Mobile: персонаж в полный рост по центру,
## 3D-локация на фоне, профиль слева сверху, сервисные кнопки справа сверху,
## боковые панели разделов и крупные кнопки матча снизу справа.
## Всё адаптивно: раскладка считается от размера экрана.

const Kit := preload("res://scripts/ui_kit.gd")

var _layer: CanvasLayer
var _root: Control
var _model: Node3D
var _popup: Control = null

# элементы, которые обновляются по таймеру
var _lvl_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _coin_label: Label
var _rp_label: Label
var _supply_btn: Button
var _freecoins_btn: Button
var _continue_btn: Button
var _tick := 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_world()
	_build_player_model()
	_build_ui()
	get_viewport().size_changed.connect(_relayout)


# ================= 3D-фон =================

func _mat(color: Color, emissive := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive.a > 0.0:
		m.emission_enabled = true
		m.emission = emissive
	return m


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = _mat(color)
	m.position = pos
	add_child(m)
	return m


func _sphere(r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.material_override = _mat(color)
	m.position = pos
	add_child(m)
	return m


func _cyl(r: float, h: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.material_override = _mat(color)
	m.position = pos
	add_child(m)
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.18, 0.28, 0.45)
	sm.sky_horizon_color = Color(0.62, 0.55, 0.45)
	sm.ground_bottom_color = Color(0.16, 0.14, 0.12)
	sm.ground_horizon_color = Color(0.5, 0.44, 0.36)
	sm.sun_angle_max = 12.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.55, 0.55, 0.52)
	env.fog_sky_affect = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -150, 0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.6, 0.7, 0.9)
	add_child(fill)

	# земля
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	g.mesh = pm
	g.material_override = _mat(Color(0.28, 0.26, 0.19))
	g.position = Vector3(0, -0.01, 0)
	add_child(g)

	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	# скалы вдали — «большая локация» за спиной персонажа
	for i in range(9):
		var ang := rng.randf_range(-2.6, -0.5)
		var r := rng.randf_range(26.0, 46.0)
		var h := rng.randf_range(6.0, 16.0)
		var rock := _box(Vector3(rng.randf_range(6, 14), h, rng.randf_range(6, 12)),
			Vector3(cos(ang) * r, h * 0.4, sin(ang) * r - 12.0), Color(0.34, 0.33, 0.31))
		rock.rotation.y = rng.randf() * TAU

	# постройки на фоне (силуэт базы)
	for i in range(4):
		var bx := -14.0 + i * 9.0 + rng.randf_range(-1.5, 1.5)
		var bz := -22.0 - rng.randf_range(0.0, 6.0)
		var bh := rng.randf_range(3.0, 5.5)
		_box(Vector3(5, bh, 5), Vector3(bx, bh * 0.5, bz), Color(0.36, 0.28, 0.19))
		_box(Vector3(5.6, 0.3, 5.6), Vector3(bx, bh, bz), Color(0.3, 0.23, 0.16))

	# деревья
	for i in range(16):
		var ang := rng.randf() * TAU
		var r := rng.randf_range(9.0, 26.0)
		var x := cos(ang) * r
		var z := sin(ang) * r - 8.0
		if absf(x) < 3.0 and z > -8.0:
			continue
		var th := rng.randf_range(4.0, 7.0)
		_cyl(0.2, th, Vector3(x, th * 0.5, z), Color(0.3, 0.21, 0.12))
		_sphere(rng.randf_range(1.3, 2.0), Vector3(x, th + 0.5, z), Color(0.17, 0.32, 0.14))

	# камни ближе к камере
	for i in range(12):
		var ang := rng.randf() * TAU
		var r := rng.randf_range(4.0, 14.0)
		_sphere(rng.randf_range(0.25, 0.7), Vector3(cos(ang) * r, 0.15, sin(ang) * r - 6.0), Color(0.4, 0.4, 0.42))

	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 42
	add_child(cam)
	cam.global_position = Vector3(0, 1.45, 2.9)
	cam.look_at(Vector3(0, 1.0, -3.0), Vector3.UP)


func _build_player_model() -> void:
	_model = preload("res://scripts/human_model.gd").new()
	add_child(_model)
	_model.build(GameState.equipped)
	_model.rotation_degrees = Vector3(0, 180, 0)
	_model.position = Vector3(0, 0, -3.0)


func _process(delta: float) -> void:
	# лёгкое покачивание камеры для «живого» меню
	if _model:
		_model.rotation.y = PI + sin(Time.get_ticks_msec() / 2600.0) * 0.12
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		_refresh_timers()


# ================= UI =================

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	_build_profile()      # слева сверху
	_build_services()     # справа сверху
	_build_left_rail()    # слева
	_build_right_rail()   # справа
	_build_bottom()       # снизу справа
	_relayout()


func _clear_popup() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null


# ---- профиль: аватар, ник, уровень, опыт, ID, валюты ----

func _build_profile() -> void:
	var wrap := Kit.make_panel(Kit.BG, 12)
	wrap.name = "Profile"
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(wrap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	wrap.add_child(row)

	# аватар
	var av := Kit.make_panel(Color(0.2, 0.16, 0.1, 0.95), 8)
	av.custom_minimum_size = Vector2(54, 54)
	var avl := Kit.label("👤", 26)
	avl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.add_child(avl)
	row.add_child(av)

	# ник / уровень / опыт / ID
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var nick := Kit.label(GameState.player_name, 17, Color(0.96, 0.94, 0.88))
	top.add_child(nick)
	_lvl_label = Kit.label("ур. %d" % GameState.level, 14, Kit.ACCENT)
	top.add_child(_lvl_label)

	_xp_bar = Kit.bar(GameState.xp, GameState.xp_needed(), Kit.ACCENT, 8.0)
	_xp_bar.custom_minimum_size = Vector2(150, 8)
	col.add_child(_xp_bar)

	var idrow := HBoxContainer.new()
	idrow.add_theme_constant_override("separation", 8)
	col.add_child(idrow)
	_xp_label = Kit.label("%d/%d XP" % [GameState.xp, GameState.xp_needed()], 11, Kit.TXT_DIM)
	idrow.add_child(_xp_label)
	idrow.add_child(Kit.label("ID %d" % GameState.player_id, 11, Kit.TXT_DIM))

	# валюты + кнопка магазина
	var cur := HBoxContainer.new()
	cur.add_theme_constant_override("separation", 6)
	row.add_child(cur)

	var gold := Kit.currency("🪙", GameState.coins, Kit.GOLD)
	_coin_label = gold.get_node("HBoxContainer/Amount") if gold.has_node("HBoxContainer/Amount") else _find_amount(gold)
	cur.add_child(gold)

	var rp := Kit.currency("💎", GameState.rp, Color(0.5, 0.85, 1.0))
	_rp_label = _find_amount(rp)
	cur.add_child(rp)

	var buy := Kit.button("+", 20, true, Vector2(44, 44))
	buy.pressed.connect(func() -> void: _open_shop())
	cur.add_child(buy)


func _find_amount(p: Node) -> Label:
	for c in p.find_children("Amount", "Label", true, false):
		return c
	return null


# ---- сервисные кнопки справа сверху ----

func _build_services() -> void:
	var wrap := Kit.make_panel(Kit.BG, 12)
	wrap.name = "Services"
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(wrap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	wrap.add_child(row)

	_supply_btn = Kit.icon_button("📦", "Бесплатная доставка", 50)
	_supply_btn.pressed.connect(_claim_supply)
	row.add_child(_supply_btn)

	_freecoins_btn = Kit.icon_button("🎁", "Бесплатные монеты", 50)
	_freecoins_btn.pressed.connect(_claim_coins)
	row.add_child(_freecoins_btn)

	var news := Kit.icon_button("📰", "Новости", 50)
	news.pressed.connect(func() -> void: _open_news())
	row.add_child(news)

	var help := Kit.icon_button("💬", "Поддержка", 50)
	help.pressed.connect(func() -> void: _open_support())
	row.add_child(help)

	var opt := Kit.icon_button("⚙", "Настройки", 50)
	opt.pressed.connect(func() -> void: _open_settings())
	row.add_child(opt)

	_refresh_timers()


# ---- левая панель разделов ----

func _build_left_rail() -> void:
	var col := VBoxContainer.new()
	col.name = "LeftRail"
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)

	var items := [
		["👥", "Соцсети", "social"],
		["🔥", "События", "events"],
		["🎫", "Боевой пропуск", "bp"],
		["🛒", "Магазин", "shop"],
		["🏷", "Акции", "sales"],
	]
	for it in items:
		col.add_child(_rail_button(String(it[0]), String(it[1]), String(it[2])))


# ---- правая панель разделов ----

func _build_right_rail() -> void:
	var col := VBoxContainer.new()
	col.name = "RightRail"
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)

	var items := [
		["🎽", "Скины", "skins"],
		["🎯", "Миссии", "missions"],
		["🎁", "Подарки", "gifts"],
		["🌐", "Онлайн", "online"],
		["📜", "История", "history"],
	]
	for it in items:
		col.add_child(_rail_button(String(it[0]), String(it[1]), String(it[2])))


func _rail_button(glyph: String, caption: String, id: String) -> Control:
	var p := Kit.make_panel(Color(0.08, 0.085, 0.1, 0.85), 10)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.custom_minimum_size = Vector2(96, 52)
	b.text = "%s  %s" % [glyph, caption]
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Kit.TXT)
	b.add_theme_color_override("font_hover_color", Kit.ACCENT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void: _open_section(id, caption))
	p.add_child(b)
	return p


# ---- нижние кнопки матча ----

func _build_bottom() -> void:
	var col := VBoxContainer.new()
	col.name = "Bottom"
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)

	_continue_btn = Kit.button("ПРОДОЛЖИТЬ", 22, false, Vector2(280, 62))
	_continue_btn.name = "BtnContinue"
	_continue_btn.disabled = not GameState.run_active
	_continue_btn.pressed.connect(_continue_game)
	col.add_child(_continue_btn)

	var newm := Kit.button("НОВЫЙ МАТЧ", 26, true, Vector2(280, 74))
	newm.name = "BtnNew"
	newm.pressed.connect(_new_match)
	col.add_child(newm)

	var srv := Kit.button("ВЫБОР СЕРВЕРА", 16, false, Vector2(280, 46))
	srv.name = "BtnServers"
	srv.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Servers.tscn")
	)
	col.add_child(srv)


# ================= адаптивная раскладка =================

func _relayout() -> void:
	if _root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var m := clampf(vs.x * 0.015, 8.0, 26.0)    # отступ от краёв зависит от ширины
	# коэффициент масштаба интерфейса: на узких экранах всё компактнее
	var k := clampf(vs.x / 1280.0, 0.62, 1.15)

	# кнопки матча тянутся по ширине экрана, но не больше трети
	var bw := clampf(vs.x * 0.26, 150.0, 300.0)
	var bc: Button = _root.get_node_or_null("Bottom/BtnContinue")
	var bn: Button = _root.get_node_or_null("Bottom/BtnNew")
	var bsv: Button = _root.get_node_or_null("Bottom/BtnServers")
	if bc:
		bc.custom_minimum_size = Vector2(bw, 46.0 * k + 16.0)
		bc.add_theme_font_size_override("font_size", int(clampf(22.0 * k, 13.0, 22.0)))
		bc.size = Vector2.ZERO
	if bn:
		bn.custom_minimum_size = Vector2(bw, 54.0 * k + 18.0)
		bn.add_theme_font_size_override("font_size", int(clampf(26.0 * k, 15.0, 26.0)))
		bn.size = Vector2.ZERO
	if bsv:
		bsv.custom_minimum_size = Vector2(bw, 34.0 * k + 12.0)
		bsv.add_theme_font_size_override("font_size", int(clampf(16.0 * k, 11.0, 16.0)))
		bsv.size = Vector2.ZERO

	# боковые панели разделов
	var rail_w := clampf(vs.x * 0.085, 62.0, 110.0)
	var rail_h := clampf(vs.y * 0.085, 38.0, 54.0)
	for rail_name in ["LeftRail", "RightRail"]:
		var rail: Control = _root.get_node_or_null(rail_name)
		if rail == null:
			continue
		for p in rail.get_children():
			for b in (p as Control).get_children():
				if b is Button:
					(b as Button).custom_minimum_size = Vector2(rail_w, rail_h)
					(b as Button).add_theme_font_size_override("font_size", int(clampf(14.0 * k, 9.0, 14.0)))
					# на узких экранах прячем подпись, оставляем только значок
					var full: String = String((b as Button).get_meta("full_text", (b as Button).text))
					(b as Button).set_meta("full_text", full)
					(b as Button).text = full.split("  ")[0] if vs.x < 900.0 else full
					(b as Button).size = Vector2.ZERO

	# сервисные кнопки сверху справа
	var sw := clampf(vs.x * 0.042, 36.0, 52.0)
	var serv_panel: Control = _root.get_node_or_null("Services")
	if serv_panel:
		for row in serv_panel.get_children():
			for b in (row as Control).get_children():
				if b is Button:
					(b as Button).custom_minimum_size = Vector2(sw, sw)
					(b as Button).size = Vector2.ZERO
	# ждём, пока контейнеры пересчитают размеры под новые custom_minimum_size
	await get_tree().process_frame
	await get_tree().process_frame

	var prof: Control = _root.get_node_or_null("Profile")
	if prof:
		prof.reset_size()
		prof.position = Vector2(m, m)

	var serv: Control = _root.get_node_or_null("Services")
	if serv:
		serv.reset_size()
		serv.position = Vector2(maxf(m, vs.x - serv.size.x - m), m)

	var lr: Control = _root.get_node_or_null("LeftRail")
	if lr:
		lr.reset_size()
		lr.position = Vector2(m, clampf(vs.y * 0.5 - lr.size.y * 0.5 + 20.0, prof.size.y + m * 2.0, vs.y - lr.size.y - m))

	var rr: Control = _root.get_node_or_null("RightRail")
	if rr:
		rr.reset_size()
		rr.position = Vector2(maxf(m, vs.x - rr.size.x - m), clampf(vs.y * 0.5 - rr.size.y * 0.5 + 20.0, serv.size.y + m * 2.0, vs.y - rr.size.y - m))

	var bt: Control = _root.get_node_or_null("Bottom")
	if bt:
		bt.reset_size()
		bt.position = Vector2(maxf(m, vs.x - bt.size.x - m), maxf(m, vs.y - bt.size.y - m))



# ================= действия =================

func _new_match() -> void:
	GameState.run_active = true
	GameState.return_to_pos = false
	if Net.state != "offline":
		Net.disconnect_from_server(false)
	GameState.set_active_server(0)
	GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/Loading.tscn")


func _continue_game() -> void:
	if not GameState.run_active:
		return
	GameState.return_to_pos = true
	get_tree().change_scene_to_file("res://scenes/Loading.tscn")


func _claim_supply() -> void:
	var loot := GameState.claim_supply()
	if loot.is_empty():
		_toast("Доставка будет через " + GameState.time_left(GameState.free_supply_at))
		return
	GameState.save_inventory()
	var parts: Array = []
	for k in loot:
		parts.append("%s x%d" % [GameState.item_name(String(k)), int(loot[k])])
	_toast("Получено: " + ", ".join(parts))
	_refresh_timers()


func _claim_coins() -> void:
	var got := GameState.claim_free_coins()
	if got <= 0:
		_toast("Монеты будут через " + GameState.time_left(GameState.free_coins_at))
		return
	_toast("Получено %d монет" % got)
	_refresh_values()
	_refresh_timers()


func _refresh_values() -> void:
	if _coin_label:
		_coin_label.text = Kit._fmt(GameState.coins)
	if _rp_label:
		_rp_label.text = Kit._fmt(GameState.rp)
	if _lvl_label:
		_lvl_label.text = "ур. %d" % GameState.level
	if _xp_bar:
		_xp_bar.max_value = GameState.xp_needed()
		_xp_bar.value = GameState.xp
	if _xp_label:
		_xp_label.text = "%d/%d XP" % [GameState.xp, GameState.xp_needed()]


func _refresh_timers() -> void:
	if _supply_btn:
		var rdy: bool = GameState.supply_ready()
		_supply_btn.text = "📦" if rdy else "📦\n" + GameState.time_left(GameState.free_supply_at)
		_supply_btn.add_theme_font_size_override("font_size", 24 if rdy else 11)
		_supply_btn.modulate = Color.WHITE if rdy else Color(0.65, 0.65, 0.65)
	if _freecoins_btn:
		var rdy2: bool = GameState.free_coins_ready()
		_freecoins_btn.text = "🎁" if rdy2 else "🎁\n" + GameState.time_left(GameState.free_coins_at)
		_freecoins_btn.add_theme_font_size_override("font_size", 24 if rdy2 else 11)
		_freecoins_btn.modulate = Color.WHITE if rdy2 else Color(0.65, 0.65, 0.65)
	if _continue_btn:
		_continue_btn.disabled = not GameState.run_active


# ================= всплывающие окна =================

func _toast(text: String) -> void:
	var t := Kit.make_panel(Color(0.05, 0.05, 0.06, 0.95), 10)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Kit.label(text, 18, Kit.GOLD)
	t.add_child(l)
	_root.add_child(t)
	t.reset_size()
	var vs := get_viewport().get_visible_rect().size
	t.position = Vector2(vs.x * 0.5 - t.size.x * 0.5, vs.y * 0.16)
	Kit.fade_in(t)
	var tw := t.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(t, "modulate:a", 0.0, 0.4)
	tw.tween_callback(t.queue_free)


func _modal(title: String, min_size: Vector2 = Vector2(560, 380)) -> VBoxContainer:
	_clear_popup()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(overlay)
	_popup = overlay

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var vs := get_viewport().get_visible_rect().size
	var w: float = minf(min_size.x, vs.x * 0.9)
	var h: float = minf(min_size.y, vs.y * 0.88)

	var panel := Kit.make_panel(Color(0.09, 0.095, 0.11, 0.97), 14)
	panel.custom_minimum_size = Vector2(w, h)
	panel.position = Vector2(vs.x * 0.5 - w * 0.5, vs.y * 0.5 - h * 0.5)
	overlay.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Kit.label(title, 24, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Kit.button("✕", 20, false, Vector2(46, 46))
	x.pressed.connect(_clear_popup)
	head.add_child(x)

	var sep := HSeparator.new()
	col.add_child(sep)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	Kit.fade_in(overlay)
	return body


func _open_section(id: String, caption: String) -> void:
	match id:
		"shop": _open_shop()
		"skins": _open_skins()
		"missions": _open_missions()
		"bp": _open_battlepass()
		"online": _open_online()
		_: _open_stub(caption)


func _open_stub(caption: String) -> void:
	var b := _modal(caption.to_upper(), Vector2(520, 300))
	b.add_child(Kit.label("Раздел «%s» скоро откроется." % caption, 18, Kit.TXT_DIM))
	b.add_child(Kit.label("Основные разделы уже работают: магазин, скины,\nмиссии, боевой пропуск, онлайн, настройки.", 15, Kit.TXT_DIM))


func _open_shop() -> void:
	var b := _modal("МАГАЗИН", Vector2(640, 460))
	b.add_child(Kit.label("Обменивай ресурсы и монеты на снаряжение.", 15, Kit.TXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var goods := [
		["wood", 500, 60], ["stone", 400, 70], ["metal", 120, 150],
		["cloth", 150, 80], ["scrap", 40, 120], ["arrow", 25, 90],
	]
	for g in goods:
		var id: String = String(g[0])
		var qty: int = int(g[1])
		var price: int = int(g[2])
		var row := Kit.make_panel(Kit.BG_SOFT, 8)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		h.add_child(Kit.label("%s x%d" % [GameState.item_name(id), qty], 17))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		h.add_child(Kit.label("🪙 %d" % price, 16, Kit.GOLD))
		var buy := Kit.button("КУПИТЬ", 15, true, Vector2(110, 44))
		buy.pressed.connect(func() -> void:
			if GameState.spend_coins(price):
				GameState.add_item(id, qty)
				GameState.save_inventory()
				_refresh_values()
				_toast("Куплено: %s x%d" % [GameState.item_name(id), qty])
			else:
				_toast("Не хватает монет")
		)
		h.add_child(buy)
		list.add_child(row)


func _open_skins() -> void:
	var b := _modal("СКИНЫ", Vector2(600, 420))
	b.add_child(Kit.label("Внешний вид персонажа зависит от надетой экипировки.", 15, Kit.TXT_DIM))
	var eq: Dictionary = GameState.equipped
	if eq.is_empty():
		b.add_child(Kit.label("Сейчас ничего не надето.\nСкрафти одежду и надень её в инвентаре —\nмодель в меню обновится.", 17))
	else:
		for slot in eq:
			b.add_child(Kit.label("• %s: %s" % [String(slot), GameState.item_name(String(eq[slot]))], 17, Kit.OK))
	var go := Kit.button("ОТКРЫТЬ ИНВЕНТАРЬ", 17, true, Vector2(240, 50))
	go.pressed.connect(func() -> void:
		GameState.run_active = true
		get_tree().change_scene_to_file("res://scenes/Inventory.tscn")
	)
	b.add_child(go)


func _open_missions() -> void:
	var b := _modal("МИССИИ", Vector2(600, 420))
	var missions := [
		["Добудь 500 дерева", GameState.count("wood"), 500, 120],
		["Добудь 300 камня", GameState.count("stone"), 300, 120],
		["Убей 5 животных", GameState.kills, 5, 200],
		["Достигни 5 уровня", GameState.level, 5, 500],
	]
	for m in missions:
		var cur: int = int(m[1])
		var need: int = int(m[2])
		var row := Kit.make_panel(Kit.BG_SOFT, 8)
		var v := VBoxContainer.new()
		row.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(Kit.label(String(m[0]), 17))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		var done: bool = cur >= need
		h.add_child(Kit.label("🪙 %d" % int(m[3]), 15, Kit.GOLD))
		h.add_child(Kit.label("  ✔" if done else "  %d/%d" % [cur, need], 15, Kit.OK if done else Kit.TXT_DIM))
		v.add_child(Kit.bar(minf(cur, need), need, Kit.OK if done else Kit.ACCENT, 7.0))
		b.add_child(row)


func _open_battlepass() -> void:
	var b := _modal("БОЕВОЙ ПРОПУСК", Vector2(600, 400))
	b.add_child(Kit.label("Сезон 1 — «Пустоши»", 20, Kit.ACCENT))
	b.add_child(Kit.label("Уровень пропуска: %d / 30" % GameState.bp_tier, 17))
	b.add_child(Kit.bar(GameState.bp_tier, 30, Kit.ACCENT, 12.0))
	b.add_child(Kit.label("Опыт пропуска начисляется за добычу ресурсов,\nкрафт и выживание в матче.", 15, Kit.TXT_DIM))
	if GameState.has_battlepass:
		b.add_child(Kit.label("✔ Пропуск активирован", 18, Kit.OK))
	else:
		var buy := Kit.button("АКТИВИРОВАТЬ — 💎 20", 18, true, Vector2(260, 52))
		buy.pressed.connect(func() -> void:
			if GameState.rp >= 20:
				GameState.rp -= 20
				GameState.has_battlepass = true
				GameState.save_profile()
				_refresh_values()
				_toast("Боевой пропуск активирован")
				_clear_popup()
			else:
				_toast("Не хватает кристаллов")
		)
		b.add_child(buy)


func _open_online() -> void:
	var b := _modal("ОНЛАЙН", Vector2(560, 340))
	b.add_child(Kit.label("Игра поддерживает выделенные серверы.", 16, Kit.TXT_DIM))
	b.add_child(Kit.label("Состояние: %s" % ("подключён" if Net.state == "online" else "офлайн"), 18,
		Kit.OK if Net.state == "online" else Kit.TXT_DIM))
	var go := Kit.button("СПИСОК СЕРВЕРОВ", 18, true, Vector2(240, 52))
	go.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Servers.tscn")
	)
	b.add_child(go)


func _open_news() -> void:
	var b := _modal("НОВОСТИ", Vector2(600, 400))
	var news := [
		["Обновление интерфейса", "Меню, инвентарь, крафт, строительство и карта переделаны под сенсорное управление."],
		["Новые деревья", "Добавлены берёза и клён с настоящими текстурами коры и листвы."],
		["Медведи стали крупнее", "Размер увеличен, коллизия исправлена."],
	]
	for n in news:
		var row := Kit.make_panel(Kit.BG_SOFT, 8)
		var v := VBoxContainer.new()
		row.add_child(v)
		v.add_child(Kit.label(String(n[0]), 18, Kit.ACCENT))
		var d := Kit.label(String(n[1]), 15, Kit.TXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(480, 0)
		v.add_child(d)
		b.add_child(row)


func _open_support() -> void:
	var b := _modal("ПОДДЕРЖКА", Vector2(560, 340))
	b.add_child(Kit.label("Ваш ID: %d" % GameState.player_id, 20, Kit.GOLD))
	b.add_child(Kit.label("Ник: %s" % GameState.player_name, 17))
	b.add_child(Kit.label("Уровень: %d" % GameState.level, 17))
	b.add_child(Kit.label("Сообщайте ID при обращении —\nпо нему находится ваш прогресс.", 15, Kit.TXT_DIM))
	var copy := Kit.button("СКОПИРОВАТЬ ID", 17, false, Vector2(220, 48))
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(str(GameState.player_id))
		_toast("ID скопирован")
	)
	b.add_child(copy)


func _open_settings() -> void:
	var b := _modal("НАСТРОЙКИ", Vector2(560, 420))

	b.add_child(Kit.label("Чувствительность обзора", 17))
	var sl := HSlider.new()
	sl.min_value = 0.0005
	sl.max_value = 0.008
	sl.step = 0.0001
	sl.value = GameState.mouse_sens
	sl.custom_minimum_size = Vector2(0, 40)
	var sv := Kit.label("%.4f" % GameState.mouse_sens, 15, Kit.TXT_DIM)
	sl.value_changed.connect(func(v: float) -> void:
		GameState.mouse_sens = v
		GameState.save_settings()
		sv.text = "%.4f" % v
	)
	b.add_child(sl)
	b.add_child(sv)

	var lay := Kit.button("Кнопки: %s" % ("СЛЕВА" if GameState.buttons_left else "СПРАВА"), 17, false, Vector2(260, 50))
	lay.pressed.connect(func() -> void:
		GameState.buttons_left = not GameState.buttons_left
		GameState.save_settings()
		lay.text = "Кнопки: %s" % ("СЛЕВА" if GameState.buttons_left else "СПРАВА")
	)
	b.add_child(lay)

	var nick := Kit.button("Сменить ник", 17, false, Vector2(260, 50))
	var le := LineEdit.new()
	le.text = GameState.player_name
	le.max_length = 16
	le.custom_minimum_size = Vector2(260, 44)
	le.add_theme_font_size_override("font_size", 17)
	b.add_child(le)
	nick.pressed.connect(func() -> void:
		var t: String = le.text.strip_edges()
		if t.length() >= 3:
			GameState.player_name = t
			GameState.save_profile()
			_toast("Ник изменён")
			_clear_popup()
		else:
			_toast("Минимум 3 символа")
	)
	b.add_child(nick)
