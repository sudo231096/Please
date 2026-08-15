extends Node3D
## Standoff-like arena match vs bots.

const PlayerScn := preload("res://scenes/Player.tscn")
const BotScr := preload("res://scripts/bot.gd")
const JoystickScr := preload("res://scripts/joystick.gd")
const LookScr := preload("res://scripts/look_zone.gd")

var _player: CharacterBody3D
var _hp_l: Label
var _ammo_l: Label
var _score_l: Label
var _wpn_l: Label
var _banner: Label
var _bots: Array = []


func _ready() -> void:
	randomize()
	GameState.reset_match()
	if not GameState.score_changed.is_connected(_on_score):
		GameState.score_changed.connect(_on_score)
	if not GameState.match_over.is_connected(_on_match_over):
		GameState.match_over.connect(_on_match_over)
	_build_env()
	_build_map()
	_spawn_player()
	_spawn_bots(5)
	_build_hud()
	_on_score()


func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.18, 0.25)
	env.fog_density = 0.0025
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(0.85, 0.9, 1.0)
	add_child(sun)


func _mat(c: Color, metal: float = 0.0, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _add_box(parent: Node, size: Vector3, pos: Vector3, color: Color, solid: bool = true) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = pos
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color, 0.05, 0.88)
	b.add_child(mi)
	if solid:
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = size
		col.shape = cs
		b.add_child(col)
	parent.add_child(b)
	return b


func _build_map() -> void:
	# floor
	_add_box(self, Vector3(70, 1, 70), Vector3(0, -0.5, 0), Color(0.14, 0.16, 0.2))
	# neon grid accents
	for i in range(-3, 4):
		_add_box(self, Vector3(0.15, 0.05, 70), Vector3(i * 8.0, 0.02, 0), Color(0.2, 0.7, 1.0), false)
		_add_box(self, Vector3(70, 0.05, 0.15), Vector3(0, 0.02, i * 8.0), Color(0.2, 0.7, 1.0), false)

	# outer walls
	var wc := Color(0.18, 0.2, 0.26)
	_add_box(self, Vector3(72, 6, 1.2), Vector3(0, 3, -35), wc)
	_add_box(self, Vector3(72, 6, 1.2), Vector3(0, 3, 35), wc)
	_add_box(self, Vector3(1.2, 6, 72), Vector3(-35, 3, 0), wc)
	_add_box(self, Vector3(1.2, 6, 72), Vector3(35, 3, 0), wc)

	# mid boxes / cover like dust-ish
	var covers := [
		[Vector3(4, 2, 4), Vector3(0, 1, 0), Color(0.25, 0.28, 0.34)],
		[Vector3(3, 1.4, 8), Vector3(-10, 0.7, -6), Color(0.3, 0.25, 0.2)],
		[Vector3(3, 1.4, 8), Vector3(10, 0.7, 6), Color(0.3, 0.25, 0.2)],
		[Vector3(8, 2.5, 2), Vector3(-6, 1.25, 12), Color(0.22, 0.24, 0.3)],
		[Vector3(8, 2.5, 2), Vector3(6, 1.25, -12), Color(0.22, 0.24, 0.3)],
		[Vector3(2, 3, 2), Vector3(-16, 1.5, -16), Color(0.2, 0.55, 0.7)],
		[Vector3(2, 3, 2), Vector3(16, 1.5, 16), Color(0.2, 0.55, 0.7)],
		[Vector3(12, 1.2, 2.5), Vector3(0, 0.6, -20), Color(0.28, 0.3, 0.35)],
		[Vector3(12, 1.2, 2.5), Vector3(0, 0.6, 20), Color(0.28, 0.3, 0.35)],
		[Vector3(2.5, 1.2, 12), Vector3(-20, 0.6, 0), Color(0.28, 0.3, 0.35)],
		[Vector3(2.5, 1.2, 12), Vector3(20, 0.6, 0), Color(0.28, 0.3, 0.35)],
		[Vector3(5, 3.5, 5), Vector3(-12, 1.75, 14), Color(0.24, 0.22, 0.28)],
		[Vector3(5, 3.5, 5), Vector3(12, 1.75, -14), Color(0.24, 0.22, 0.28)],
	]
	for c in covers:
		_add_box(self, c[0], c[1], c[2])

	# ramps
	for side in [-1.0, 1.0]:
		var ramp := StaticBody3D.new()
		ramp.collision_layer = 1
		ramp.position = Vector3(side * 8, 0.5, side * 4)
		ramp.rotation.z = side * 0.35
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6, 0.4, 3)
		mi.mesh = bm
		mi.material_override = _mat(Color(0.3, 0.32, 0.38))
		ramp.add_child(mi)
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = Vector3(6, 0.4, 3)
		col.shape = cs
		ramp.add_child(col)
		add_child(ramp)


func _spawn_player() -> void:
	_player = PlayerScn.instantiate()
	_player.position = Vector3(0, 2, 22)
	_player.spawn_pos = Vector3(0, 2, 22)
	add_child(_player)
	if not _player.stats_changed.is_connected(_on_player_stats):
		_player.stats_changed.connect(_on_player_stats)
	_on_player_stats()


func _spawn_bots(n: int) -> void:
	var spots := [
		Vector3(0, 2, -22), Vector3(18, 2, 0), Vector3(-18, 2, 0),
		Vector3(12, 2, -12), Vector3(-12, 2, 12), Vector3(8, 2, -18),
		Vector3(-8, 2, 18),
	]
	for i in range(n):
		var b := CharacterBody3D.new()
		b.set_script(BotScr)
		var sp: Vector3 = spots[i % spots.size()]
		b.position = sp
		b.spawn_pos = sp
		b.team_color = Color(1.0, 0.3 + i * 0.05, 0.25)
		add_child(b)
		_bots.append(b)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# look zone under buttons
	var look := LookScr.new()
	root.add_child(look)

	# top score
	_score_l = Label.new()
	_score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_l.anchor_left = 0.2
	_score_l.anchor_right = 0.8
	_score_l.offset_top = 12
	_score_l.offset_bottom = 56
	_score_l.add_theme_font_size_override("font_size", 30)
	_score_l.modulate = Color(0.7, 0.95, 1.0)
	root.add_child(_score_l)

	_hp_l = Label.new()
	_hp_l.offset_left = 20
	_hp_l.offset_top = 20
	_hp_l.offset_right = 260
	_hp_l.offset_bottom = 70
	_hp_l.add_theme_font_size_override("font_size", 28)
	_hp_l.modulate = Color(0.4, 1.0, 0.55)
	root.add_child(_hp_l)

	_wpn_l = Label.new()
	_wpn_l.anchor_left = 1.0
	_wpn_l.anchor_right = 1.0
	_wpn_l.offset_left = -280
	_wpn_l.offset_right = -20
	_wpn_l.offset_top = 70
	_wpn_l.offset_bottom = 120
	_wpn_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wpn_l.add_theme_font_size_override("font_size", 24)
	_wpn_l.modulate = Color(0.85, 0.9, 1.0)
	root.add_child(_wpn_l)

	_ammo_l = Label.new()
	_ammo_l.anchor_left = 1.0
	_ammo_l.anchor_right = 1.0
	_ammo_l.anchor_top = 1.0
	_ammo_l.anchor_bottom = 1.0
	_ammo_l.offset_left = -260
	_ammo_l.offset_right = -24
	_ammo_l.offset_top = -280
	_ammo_l.offset_bottom = -230
	_ammo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_l.add_theme_font_size_override("font_size", 34)
	_ammo_l.modulate = Color(1.0, 0.9, 0.4)
	root.add_child(_ammo_l)

	# crosshair
	for d in [[-12, -2, 8, 4], [4, -2, 8, 4], [-2, -12, 4, 8], [-2, 4, 4, 8]]:
		var r := ColorRect.new()
		r.color = Color(0.4, 1.0, 0.85, 0.9)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_left = 0.5
		r.anchor_right = 0.5
		r.anchor_top = 0.5
		r.anchor_bottom = 0.5
		r.offset_left = float(d[0])
		r.offset_top = float(d[1])
		r.offset_right = float(d[0] + d[2])
		r.offset_bottom = float(d[1] + d[3])
		root.add_child(r)

	root.add_child(JoystickScr.new())

	# fire button
	var fire := Button.new()
	fire.text = "ОГОНЬ"
	fire.focus_mode = Control.FOCUS_NONE
	fire.anchor_left = 1.0
	fire.anchor_right = 1.0
	fire.anchor_top = 1.0
	fire.anchor_bottom = 1.0
	fire.offset_left = -210
	fire.offset_right = -24
	fire.offset_top = -210
	fire.offset_bottom = -40
	fire.add_theme_font_size_override("font_size", 28)
	fire.button_down.connect(func() -> void:
		Controls.fire_held = true
		Controls.fire_pressed = true
	)
	fire.button_up.connect(func() -> void:
		Controls.fire_held = false
	)
	root.add_child(fire)

	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.focus_mode = Control.FOCUS_NONE
	jump.anchor_left = 1.0
	jump.anchor_right = 1.0
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -400
	jump.offset_right = -230
	jump.offset_top = -140
	jump.offset_bottom = -40
	jump.add_theme_font_size_override("font_size", 22)
	jump.button_down.connect(func() -> void: Controls.jump_queued = true)
	root.add_child(jump)

	var rel := Button.new()
	rel.text = "R"
	rel.focus_mode = Control.FOCUS_NONE
	rel.anchor_left = 1.0
	rel.anchor_right = 1.0
	rel.anchor_top = 1.0
	rel.anchor_bottom = 1.0
	rel.offset_left = -400
	rel.offset_right = -230
	rel.offset_top = -230
	rel.offset_bottom = -150
	rel.add_theme_font_size_override("font_size", 24)
	rel.pressed.connect(func() -> void: Controls.reload_queued = true)
	root.add_child(rel)

	var sw := Button.new()
	sw.text = "ОРУЖИЕ"
	sw.focus_mode = Control.FOCUS_NONE
	sw.anchor_left = 1.0
	sw.anchor_right = 1.0
	sw.offset_left = -170
	sw.offset_right = -20
	sw.offset_top = 16
	sw.offset_bottom = 68
	sw.add_theme_font_size_override("font_size", 20)
	sw.pressed.connect(func() -> void: Controls.switch_queued = true)
	root.add_child(sw)

	var menu := Button.new()
	menu.text = "МЕНЮ"
	menu.focus_mode = Control.FOCUS_NONE
	menu.offset_left = 16
	menu.offset_top = 70
	menu.offset_right = 130
	menu.offset_bottom = 120
	menu.add_theme_font_size_override("font_size", 20)
	menu.pressed.connect(func() -> void:
		Controls.ui_open = false
		Controls.fire_held = false
		Controls.move_vector = Vector2.ZERO
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	root.add_child(menu)

	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.anchor_left = 0.1
	_banner.anchor_right = 0.9
	_banner.anchor_top = 0.4
	_banner.anchor_bottom = 0.55
	_banner.add_theme_font_size_override("font_size", 42)
	_banner.visible = false
	root.add_child(_banner)


func _on_player_stats() -> void:
	if _player == null:
		return
	if _hp_l:
		_hp_l.text = "HP %d" % _player.hp
		_hp_l.modulate = Color(0.4, 1.0, 0.55) if _player.hp > 30 else Color(1.0, 0.35, 0.3)
	if _ammo_l:
		_ammo_l.text = _player.ammo_text()
	if _wpn_l:
		_wpn_l.text = _player.weapon_title()


func _on_score() -> void:
	if _score_l:
		_score_l.text = "ТЫ  %d  :  %d  БОТЫ   (до %d)" % [GameState.player_kills, GameState.bot_kills, GameState.kill_limit]


func _on_match_over(won: bool) -> void:
	Controls.fire_held = false
	if _banner:
		_banner.visible = true
		_banner.text = "ПОБЕДА" if won else "ПОРАЖЕНИЕ"
		_banner.modulate = Color(0.4, 1.0, 0.6) if won else Color(1.0, 0.35, 0.35)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		GameState.reset_match()
		get_tree().reload_current_scene()
