extends Node3D
## Главное меню: камерамен стоит на улице, лента уровней, монеты, магазин.

const CameramanIdle := preload("res://scripts/cameraman_idle.gd")
const MAX_LEVEL := 50

var _cam: Camera3D
var _angle := 0.0
var _cameraman: Node3D
var _coins_l: Label
var _unlocked_l: Label
var _strip: HBoxContainer
var _shop: Control
var _shop_coins_l: Label
var _dmg_lbl: Label
var _dmg_btn: Button
var _hp_lbl: Label
var _hp_btn: Button
var _promo: Control
var _promo_input: LineEdit
var _promo_status: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	_refresh()


func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D, emissive: Color = Color(0, 0, 0, 0)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive.a > 0.0:
		mat.emission_enabled = true
		mat.emission = emissive
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.52, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-55, 30, 0)
	dl.light_energy = 1.2
	add_child(dl)

	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.22, 0.24, 0.26)
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.material_override = gmat
	g.position = Vector3(0, -0.01, 0)
	add_child(g)

	_box(Vector3(10, 0.04, 40), Vector3(0, 0.02, 0), Color(0.14, 0.14, 0.16), self)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in range(8):
		var side := -1 if i % 2 == 0 else 1
		var z := -18.0 + (i * 4.5)
		var h := rng.randf_range(6.0, 14.0)
		var xc := side * 9.5
		var base := Color(rng.randf_range(0.25, 0.5), rng.randf_range(0.22, 0.4), rng.randf_range(0.2, 0.35))
		_box(Vector3(6.5, h, 4.0), Vector3(xc, h * 0.5, z), base, self)
		for r in range(3):
			var wy := 2.0 + r * 2.6
			if wy > h - 1.0:
				break
			_box(Vector3(0.1, 1.3, 1.0), Vector3(side * (xc - side * 3.2), wy, z), Color(0.1, 0.12, 0.16), self, Color(1.0, 0.9, 0.5))

	_cameraman = Node3D.new()
	_cameraman.set_script(CameramanIdle)
	_cameraman.position = Vector3(0, 0, -4)
	add_child(_cameraman)

	for i in range(2):
		_spawn_decor_skibidi(Vector3(-3.5 + i * 7.0, 0, -2))

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 55
	add_child(_cam)


func _spawn_decor_skibidi(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	_box(Vector3(1.0, 0.7, 0.85), Vector3(0, 0.35, 0), Color(0.87, 0.87, 0.9), n)
	_box(Vector3(0.9, 0.55, 0.28), Vector3(0, 0.82, -0.55), Color(0.87, 0.87, 0.9), n)
	_box(Vector3(0.5, 0.5, 0.5), Vector3(0, 1.45, 0), Color(0.78, 0.8, 0.68), n)


func _process(delta: float) -> void:
	if not _cam or not _cameraman:
		return
	_angle += delta * 0.35
	var r := 7.0
	var cx: Vector3 = _cameraman.global_position
	_cam.global_position = cx + Vector3(cos(_angle) * r, 3.6, sin(_angle) * r)
	_cam.look_at(cx + Vector3(0, 1.3, 0), Vector3.UP)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	# --- заголовок ---
	var title := Label.new()
	title.text = "SKIBIDI TOILET SURVIVAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.offset_top = 16
	title.offset_bottom = 70
	title.add_theme_font_size_override("font_size", 40)
	title.modulate = Color(0.6, 0.85, 1.0)
	layer.add_child(title)

	# --- монеты (сверху слева) ---
	_coins_l = Label.new()
	_coins_l.offset_left = 20
	_coins_l.offset_top = 18
	_coins_l.offset_right = 400
	_coins_l.offset_bottom = 58
	_coins_l.add_theme_font_size_override("font_size", 28)
	_coins_l.modulate = Color(1.0, 0.85, 0.3)
	layer.add_child(_coins_l)

	# --- кнопка магазина (сверху справа) ---
	var shop_btn := Button.new()
	shop_btn.text = "МАГАЗИН"
	shop_btn.focus_mode = Control.FOCUS_NONE
	shop_btn.anchor_left = 1.0
	shop_btn.anchor_right = 1.0
	shop_btn.offset_left = -180
	shop_btn.offset_right = -20
	shop_btn.offset_top = 16
	shop_btn.offset_bottom = 66
	shop_btn.add_theme_font_size_override("font_size", 24)
	shop_btn.modulate = Color(1.0, 0.85, 0.4)
	shop_btn.pressed.connect(func() -> void:
		_shop.visible = not _shop.visible
		_refresh_shop()
	)
	layer.add_child(shop_btn)

	# --- кнопка промокода ---
	var promo_btn := Button.new()
	promo_btn.text = "ПРОМОКОД"
	promo_btn.focus_mode = Control.FOCUS_NONE
	promo_btn.anchor_left = 1.0
	promo_btn.anchor_right = 1.0
	promo_btn.offset_left = -180
	promo_btn.offset_right = -20
	promo_btn.offset_top = 74
	promo_btn.offset_bottom = 124
	promo_btn.add_theme_font_size_override("font_size", 22)
	promo_btn.modulate = Color(0.5, 0.85, 1.0)
	promo_btn.pressed.connect(func() -> void:
		_promo.visible = not _promo.visible
	)
	layer.add_child(promo_btn)

	_unlocked_l = Label.new()
	_unlocked_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlocked_l.anchor_left = 0.05
	_unlocked_l.anchor_right = 0.95
	_unlocked_l.offset_top = 74
	_unlocked_l.offset_bottom = 108
	_unlocked_l.add_theme_font_size_override("font_size", 22)
	_unlocked_l.modulate = Color(0.9, 0.9, 0.9, 0.85)
	layer.add_child(_unlocked_l)

	# --- большая кнопка ИГРАТЬ ---
	var play := Button.new()
	play.text = "ИГРАТЬ"
	play.focus_mode = Control.FOCUS_NONE
	play.anchor_left = 0.5
	play.anchor_right = 0.5
	play.offset_left = -170
	play.offset_right = 170
	play.offset_top = 160
	play.offset_bottom = 250
	play.add_theme_font_size_override("font_size", 40)
	play.modulate = Color(0.5, 1.0, 0.55)
	play.pressed.connect(func() -> void:
		_start(GameState.unlocked)
	)
	layer.add_child(play)

	# --- горизонтальная лента уровней (внизу) ---
	var strip_scroll := ScrollContainer.new()
	strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_scroll.anchor_left = 0.0
	strip_scroll.anchor_right = 1.0
	strip_scroll.anchor_top = 1.0
	strip_scroll.anchor_bottom = 1.0
	strip_scroll.offset_top = -150
	strip_scroll.offset_bottom = -20
	strip_scroll.offset_left = 10
	strip_scroll.offset_right = -10
	layer.add_child(strip_scroll)

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 8)
	strip_scroll.add_child(_strip)

	_build_shop(layer)
	_build_promo(layer)


func _build_promo(layer: CanvasLayer) -> void:
	_promo = Control.new()
	_promo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_promo.visible = false
	layer.add_child(_promo)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_promo.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -160
	panel.offset_bottom = 160
	_promo.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	var t := Label.new()
	t.text = "ПРОМОКОД"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.modulate = Color(0.5, 0.85, 1.0)
	v.add_child(t)

	_promo_input = LineEdit.new()
	_promo_input.placeholder_text = "Введите код"
	_promo_input.add_theme_font_size_override("font_size", 24)
	v.add_child(_promo_input)

	var ok := Button.new()
	ok.text = "Применить"
	ok.focus_mode = Control.FOCUS_NONE
	ok.add_theme_font_size_override("font_size", 24)
	ok.pressed.connect(_redeem_promo)
	v.add_child(ok)

	_promo_status = Label.new()
	_promo_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_promo_status.add_theme_font_size_override("font_size", 20)
	_promo_status.text = ""
	v.add_child(_promo_status)

	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func() -> void:
		_promo.visible = false
	)
	v.add_child(close)


func _redeem_promo() -> void:
	var res: String = GameState.redeem_promo(_promo_input.text)
	_promo_status.text = res
	if GameState.promo_redeemed:
		_promo_status.modulate = Color(0.5, 1.0, 0.55)
	else:
		_promo_status.modulate = Color(1.0, 0.5, 0.5)
	_refresh()


func _build_shop(layer: CanvasLayer) -> void:
	_shop = Control.new()
	_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.visible = false
	layer.add_child(_shop)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -400
	panel.offset_bottom = 400
	_shop.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var t := Label.new()
	t.text = "МАГАЗИН"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.modulate = Color(1.0, 0.85, 0.4)
	v.add_child(t)

	_shop_coins_l = Label.new()
	_shop_coins_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coins_l.add_theme_font_size_override("font_size", 24)
	_shop_coins_l.modulate = Color(1.0, 0.85, 0.3)
	v.add_child(_shop_coins_l)

	var sep := HSeparator.new()
	v.add_child(sep)

	_dmg_lbl = Label.new()
	_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dmg_lbl.add_theme_font_size_override("font_size", 28)
	v.add_child(_dmg_lbl)

	_dmg_btn = Button.new()
	_dmg_btn.focus_mode = Control.FOCUS_NONE
	_dmg_btn.add_theme_font_size_override("font_size", 44)
	_dmg_btn.custom_minimum_size = Vector2(560, 96)
	_dmg_btn.pressed.connect(func() -> void:
		GameState.buy_damage()
		_refresh_shop()
	)
	v.add_child(_dmg_btn)

	var sep2 := HSeparator.new()
	v.add_child(sep2)

	_hp_lbl = Label.new()
	_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_lbl.add_theme_font_size_override("font_size", 28)
	v.add_child(_hp_lbl)

	_hp_btn = Button.new()
	_hp_btn.focus_mode = Control.FOCUS_NONE
	_hp_btn.add_theme_font_size_override("font_size", 44)
	_hp_btn.custom_minimum_size = Vector2(560, 96)
	_hp_btn.pressed.connect(func() -> void:
		GameState.buy_hp()
		_refresh_shop()
	)
	v.add_child(_hp_btn)

	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void:
		_shop.visible = false
	)
	v.add_child(close)


func _refresh() -> void:
	for c in _strip.get_children():
		c.queue_free()
	_unlocked_l.text = "Открыто уровней: %d / %d" % [GameState.unlocked, MAX_LEVEL]
	_coins_l.text = "Монеты: %d" % GameState.coins

	for i in range(1, MAX_LEVEL + 1):
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(64, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		var opened := i <= GameState.unlocked
		b.disabled = not opened
		if i == GameState.unlocked:
			b.modulate = Color(0.7, 1.0, 0.6)
		elif opened:
			b.modulate = Color.WHITE
		else:
			b.modulate = Color(0.45, 0.45, 0.45)
		var lvl := i
		b.pressed.connect(func() -> void: _start(lvl))
		_strip.add_child(b)

	_refresh_shop()


func _refresh_shop() -> void:
	if _coins_l:
		_coins_l.text = "Монеты: %d" % GameState.coins
	if _shop_coins_l:
		_shop_coins_l.text = "Монеты: %d" % GameState.coins
	if _dmg_lbl:
		_dmg_lbl.text = "Урон: %.0f  (ур. %d)" % [GameState.player_damage(), GameState.damage_level]
	if _dmg_btn:
		_dmg_btn.text = "Прокачать урон — %d" % GameState.damage_upgrade_cost()
		_dmg_btn.disabled = GameState.coins < GameState.damage_upgrade_cost()
	if _hp_lbl:
		_hp_lbl.text = "HP: %.0f  (ур. %d)" % [GameState.player_max_hp(), GameState.hp_level]
	if _hp_btn:
		_hp_btn.text = "Прокачать HP — %d" % GameState.hp_upgrade_cost()
		_hp_btn.disabled = GameState.coins < GameState.hp_upgrade_cost()


func _start(level: int) -> void:
	GameState.start_level(level)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
