extends Node2D
## Один 2D-уровень: лес, платформы, разбойники, флаг финиша.

const PlayerScr := preload("res://scripts/player.gd")
const BanditScr := preload("res://scripts/bandit.gd")
const PixelArt = preload("res://scripts/pixel.gd")

var level_num := 1
var _player: CharacterBody2D
var _hp_l: Label
var _lvl_l: Label
var _coin_l: Label
var _msg_l: Label
var _camera: Camera2D
var _won := false
var _rng := RandomNumberGenerator.new()
var _map_w := 3200.0
var _ground_y := 520.0
var _diff := 1.0


func _ready() -> void:
	level_num = Progress.current
	_rng.seed = 1000 + level_num * 97
	_map_w = 2600.0 + float(level_num % 40) * 20.0
	_diff = 1.0 + float(level_num) * 0.03
	_build_background()
	_build_terrain()
	_spawn_player()
	_spawn_enemies()
	_spawn_flag()
	_build_hud()
	_build_mobile_ui()


func _px(tex: Texture2D, pos: Vector2, scale: float = 2.0, z: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.scale = Vector2(scale, scale)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	add_child(s)
	return s


func _build_background() -> void:
	# sky gradient via big rects
	var sky := ColorRect.new()
	sky.color = Color(0.45, 0.7, 0.95)
	sky.size = Vector2(_map_w + 400, 900)
	sky.position = Vector2(-200, -200)
	sky.z_index = -50
	add_child(sky)

	# sun
	var sun := ColorRect.new()
	sun.color = Color(1.0, 0.95, 0.55, 0.9)
	sun.size = Vector2(70, 70)
	sun.position = Vector2(180, 40)
	sun.z_index = -45
	add_child(sun)

	# far trees parallax-ish static silhouettes
	for i in range(int(_map_w / 70.0) + 5):
		var x := -100.0 + i * 70.0 + _rng.randf_range(-15, 15)
		var h := _rng.randf_range(90, 170)
		var trunk := ColorRect.new()
		trunk.color = Color(0.2, 0.28, 0.18, 0.55)
		trunk.size = Vector2(18, h)
		trunk.position = Vector2(x, _ground_y - h - 40)
		trunk.z_index = -40
		add_child(trunk)
		var crown := ColorRect.new()
		crown.color = Color(0.15, 0.35, 0.18, 0.5)
		crown.size = Vector2(70, 60)
		crown.position = Vector2(x - 26, _ground_y - h - 80)
		crown.z_index = -39
		add_child(crown)

	# mid forest layer denser
	for i in range(int(_map_w / 48.0) + 4):
		var x2 := -80.0 + i * 48.0 + _rng.randf_range(-10, 10)
		_draw_tree(Vector2(x2, _ground_y), _rng.randf_range(1.0, 1.5), -20)

	# clouds
	for i in range(10):
		var c := ColorRect.new()
		c.color = Color(1, 1, 1, 0.55)
		c.size = Vector2(_rng.randf_range(60, 120), _rng.randf_range(22, 36))
		c.position = Vector2(_rng.randf_range(0, _map_w), _rng.randf_range(30, 160))
		c.z_index = -30
		add_child(c)


func _draw_tree(base: Vector2, s: float, z: int) -> void:
	var trunk := ColorRect.new()
	trunk.color = Color(0.4, 0.25, 0.12)
	trunk.size = Vector2(14 * s, 50 * s)
	trunk.position = Vector2(base.x - 7 * s, base.y - 50 * s)
	trunk.z_index = z
	add_child(trunk)
	for j in range(3):
		var leaf := ColorRect.new()
		leaf.color = Color(0.18 + j * 0.05, 0.42 + j * 0.03, 0.16)
		var w := (55 - j * 10) * s
		leaf.size = Vector2(w, 28 * s)
		leaf.position = Vector2(base.x - w * 0.5, base.y - 70 * s - j * 18 * s)
		leaf.z_index = z + 1
		add_child(leaf)


func _add_block(rect: Rect2, top_grass: bool = true) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.position
	var col := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = rect.size
	col.shape = cs
	col.position = rect.size * 0.5
	body.add_child(col)
	add_child(body)

	# tiled look with color rects
	var ground := ColorRect.new()
	ground.color = Color(0.4, 0.28, 0.16)
	ground.size = rect.size
	ground.position = rect.position
	ground.z_index = -5
	add_child(ground)
	if top_grass:
		var g := ColorRect.new()
		g.color = Color(0.3, 0.55, 0.22)
		g.size = Vector2(rect.size.x, mini(12.0, rect.size.y * 0.35))
		g.position = rect.position
		g.z_index = -4
		add_child(g)


func _build_terrain() -> void:
	# main ground
	_add_block(Rect2(-100, _ground_y, _map_w + 200, 220), true)

	# pits / platforms based on level
	var difficulty := 1.0 + float(level_num) * 0.015
	var platform_count := 6 + int(level_num / 8.0)
	for i in range(platform_count):
		var x := 180.0 + i * ((_map_w - 400.0) / float(maxi(platform_count, 1))) + _rng.randf_range(-40, 40)
		var y := _ground_y - _rng.randf_range(70, 160 + difficulty * 8.0)
		var w := _rng.randf_range(90, 170)
		_add_block(Rect2(x, y, w, 24), true)
		if _rng.randf() < 0.45:
			_draw_tree(Vector2(x + w * 0.5, y), _rng.randf_range(0.7, 1.1), -8)

	# floating steps near end
	for i in range(3):
		_add_block(Rect2(_map_w - 420 + i * 90, _ground_y - 70 - i * 35, 80, 20), true)

	# left wall / right wall soft
	_add_block(Rect2(-120, -200, 40, 1000), false)
	_add_block(Rect2(_map_w + 60, -200, 40, 1000), false)


func _spawn_player() -> void:
	_player = CharacterBody2D.new()
	_player.set_script(PlayerScr)
	_player.position = Vector2(80, _ground_y - 40)
	add_child(_player)
	_player.hp_changed.connect(_on_hp)
	_player.died.connect(_on_player_died)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.limit_left = 0
	_camera.limit_right = int(_map_w)
	_camera.limit_top = -200
	_camera.limit_bottom = int(_ground_y + 200)
	_player.add_child(_camera)
	_camera.make_current()


func _spawn_enemies() -> void:
	var base := 2 + int(level_num / 10.0)
	var count := mini(2 + base + int(level_num % 7), 18)
	for i in range(count):
		var e := CharacterBody2D.new()
		e.set_script(BanditScr)
		var x := 300.0 + i * ((_map_w - 600.0) / float(maxi(count, 1))) + _rng.randf_range(-30, 30)
		e.position = Vector2(x, _ground_y - 40)
		add_child(e)
		if e.has_method("setup_patrol"):
			e.setup_patrol(x, 160.0 + float(level_num % 5) * 10.0, _diff)
		e.died.connect(_on_enemy_died)


func _on_enemy_died(pos: Vector2) -> void:
	# 1% шанс — джекпот 50 монет, иначе 2–3 монеты
	var roll := _rng.randf()
	var total := 0
	if roll < 0.01:
		total = 50
	else:
		total = _rng.randi_range(2, 3)
	if total >= 50:
		_spawn_coin(pos, 50, true)
	else:
		for i in range(total):
			_spawn_coin(pos + Vector2(_rng.randf_range(-22, 22), _rng.randf_range(-12, 4)), 1, false)


func _spawn_coin(pos: Vector2, value: int, big: bool) -> void:
	var c := Area2D.new()
	c.set_script(preload("res://scripts/coin.gd"))
	c.position = pos
	c.value = value
	c.big = big
	add_child(c)


func _spawn_flag() -> void:
	var flag := Area2D.new()
	flag.name = "Goal"
	flag.collision_layer = 0
	flag.collision_mask = 2
	flag.position = Vector2(_map_w - 90, _ground_y)
	var col := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = Vector2(30, 60)
	col.shape = cs
	col.position = Vector2(0, -30)
	flag.add_child(col)
	var spr := Sprite2D.new()
	spr.texture = PixelArt.flag_tex()
	spr.centered = false
	spr.position = Vector2(-16, -48)
	spr.scale = Vector2(2, 2)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flag.add_child(spr)
	var label := Label.new()
	label.text = "ФИНИШ"
	label.position = Vector2(-28, -70)
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.9, 1.0, 0.6)
	flag.add_child(label)
	flag.body_entered.connect(_on_goal)
	add_child(flag)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	_lvl_l = Label.new()
	_lvl_l.offset_left = 16
	_lvl_l.offset_top = 12
	_lvl_l.offset_right = 400
	_lvl_l.offset_bottom = 50
	_lvl_l.add_theme_font_size_override("font_size", 26)
	_lvl_l.text = "Уровень %d / %d" % [level_num, Progress.MAX_LEVEL]
	_lvl_l.modulate = Color(0.9, 0.95, 1.0)
	root.add_child(_lvl_l)

	_hp_l = Label.new()
	_hp_l.offset_left = 16
	_hp_l.offset_top = 48
	_hp_l.offset_right = 400
	_hp_l.offset_bottom = 90
	_hp_l.add_theme_font_size_override("font_size", 24)
	_hp_l.modulate = Color(0.4, 1.0, 0.5)
	root.add_child(_hp_l)
	_on_hp(_player.hp, _player.max_hp)

	_coin_l = Label.new()
	_coin_l.offset_left = 16
	_coin_l.offset_top = 84
	_coin_l.offset_right = 400
	_coin_l.offset_bottom = 124
	_coin_l.add_theme_font_size_override("font_size", 24)
	_coin_l.modulate = Color(1.0, 0.85, 0.3)
	_coin_l.text = "Монеты: %d" % Progress.coins
	root.add_child(_coin_l)
	Progress.coins_changed.connect(_on_coins)

	_msg_l = Label.new()
	_msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_l.anchor_left = 0.1
	_msg_l.anchor_right = 0.9
	_msg_l.anchor_top = 0.35
	_msg_l.anchor_bottom = 0.5
	_msg_l.add_theme_font_size_override("font_size", 40)
	_msg_l.visible = false
	root.add_child(_msg_l)

	var menu := Button.new()
	menu.text = "МЕНЮ"
	menu.focus_mode = Control.FOCUS_NONE
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -140
	menu.offset_right = -16
	menu.offset_top = 12
	menu.offset_bottom = 60
	menu.add_theme_font_size_override("font_size", 20)
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	root.add_child(menu)

	var tip := Label.new()
	tip.text = "A/D или стрелки · Пробел прыжок · J/Клик удар"
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.offset_left = 16
	tip.offset_top = -36
	tip.offset_right = 700
	tip.offset_bottom = -8
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(1, 1, 1, 0.7)
	root.add_child(tip)


func _build_mobile_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var left := _mbtn("◀", Vector2(20, -250), Vector2(200, 200))
	var right := _mbtn("▶", Vector2(240, -250), Vector2(200, 200))
	var jump := _mbtn("⬆", Vector2(-460, -250), Vector2(220, 200), true)
	var atk := _mbtn("⚔", Vector2(-230, -250), Vector2(220, 200), true)
	root.add_child(left)
	root.add_child(right)
	root.add_child(jump)
	root.add_child(atk)
	left.button_down.connect(func() -> void: _player.set_meta("mob_left", true))
	left.button_up.connect(func() -> void: _player.set_meta("mob_left", false))
	right.button_down.connect(func() -> void: _player.set_meta("mob_right", true))
	right.button_up.connect(func() -> void: _player.set_meta("mob_right", false))
	jump.pressed.connect(func() -> void: _player.set_meta("mob_jump", true))
	atk.pressed.connect(func() -> void: _player.set_meta("mob_attack", true))


func _mbtn(text: String, pos: Vector2, size: Vector2, from_right: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", 44)
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	if from_right:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
	b.offset_left = pos.x
	b.offset_right = pos.x + size.x
	b.offset_top = pos.y
	b.offset_bottom = pos.y + size.y
	return b


func _on_hp(v: int, mx: int) -> void:
	if _hp_l:
		var shield_txt := ""
		if _player and _player.shield > 0:
			shield_txt = "  ·  Щит %d" % _player.shield
		_hp_l.text = "HP %d/%d%s" % [v, mx, shield_txt]
		_hp_l.modulate = Color(0.4, 1.0, 0.5) if v > 30 else Color(1.0, 0.35, 0.3)


func _on_coins() -> void:
	if _coin_l:
		_coin_l.text = "Монеты: %d" % Progress.coins


func _on_player_died() -> void:
	_msg_l.visible = true
	_msg_l.text = "ПОРАЖЕНИЕ"
	_msg_l.modulate = Color(1.0, 0.35, 0.35)
	await get_tree().create_timer(1.4).timeout
	if is_inside_tree():
		get_tree().reload_current_scene()


func _on_goal(body: Node2D) -> void:
	if _won:
		return
	if body and body.is_in_group("player"):
		_won = true
		Progress.complete_level(level_num)
		_msg_l.visible = true
		_msg_l.modulate = Color(0.5, 1.0, 0.55)
		if level_num >= Progress.MAX_LEVEL:
			_msg_l.text = "ВСЕ 250 УРОВНЕЙ ПРОЙДЕНЫ!"
			await get_tree().create_timer(2.2).timeout
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		else:
			_msg_l.text = "УРОВЕНЬ %d ПРОЙДЕН!" % level_num
			await get_tree().create_timer(1.0).timeout
			Progress.current = level_num + 1
			get_tree().reload_current_scene()
