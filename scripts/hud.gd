extends CanvasLayer
## HUD: HP, очки, волна, джойстик, кнопка стрельбы, экран проигрыша.

const JoystickScr := preload("res://scripts/joystick.gd")

var _player: Node3D
var _hp_fill: ColorRect
var _score_l: Label
var _level_l: Label
var _coins_l: Label
var _high_l: Label
var _flash_l: Label
var _flash_t := 0.0
var _over: Control
var _over_score: Label


func bind(p: Node3D) -> void:
	_player = p
	_player.hp_changed.connect(_hp)


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var title := Label.new()
	title.text = "SKIBIDI TOILET SURVIVAL"
	title.offset_left = 20
	title.offset_top = 14
	title.offset_right = 700
	title.offset_bottom = 54
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(0.6, 0.85, 1.0)
	add_child(title)

	_score_l = Label.new()
	_score_l.offset_left = 20
	_score_l.offset_top = 56
	_score_l.offset_right = 400
	_score_l.offset_bottom = 92
	_score_l.add_theme_font_size_override("font_size", 28)
	_score_l.modulate = Color(1.0, 0.9, 0.4)
	add_child(_score_l)

	_level_l = Label.new()
	_level_l.offset_left = 20
	_level_l.offset_top = 94
	_level_l.offset_right = 400
	_level_l.offset_bottom = 126
	_level_l.add_theme_font_size_override("font_size", 22)
	_level_l.modulate = Color(1.0, 0.5, 0.4)
	add_child(_level_l)

	_coins_l = Label.new()
	_coins_l.offset_left = 20
	_coins_l.offset_top = 128
	_coins_l.offset_right = 400
	_coins_l.offset_bottom = 158
	_coins_l.add_theme_font_size_override("font_size", 22)
	_coins_l.modulate = Color(1.0, 0.85, 0.3)
	add_child(_coins_l)

	# вспышка при смене уровня
	_flash_l = Label.new()
	_flash_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_l.anchor_left = 0.15
	_flash_l.anchor_right = 0.85
	_flash_l.anchor_top = 0.28
	_flash_l.anchor_bottom = 0.42
	_flash_l.add_theme_font_size_override("font_size", 56)
	_flash_l.modulate = Color(1.0, 0.85, 0.3)
	_flash_l.visible = false
	add_child(_flash_l)

	_high_l = Label.new()
	_high_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_high_l.anchor_left = 0.6
	_high_l.anchor_right = 1.0
	_high_l.offset_left = -20
	_high_l.offset_right = -20
	_high_l.offset_top = 16
	_high_l.offset_bottom = 50
	_high_l.add_theme_font_size_override("font_size", 22)
	_high_l.modulate = Color(0.9, 0.9, 0.9, 0.8)
	add_child(_high_l)

	# кнопка меню
	var menu := Button.new()
	menu.text = "МЕНЮ"
	menu.focus_mode = Control.FOCUS_NONE
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -130
	menu.offset_right = -20
	menu.offset_top = 56
	menu.offset_bottom = 104
	menu.add_theme_font_size_override("font_size", 22)
	menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	add_child(menu)

	# HP бар
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.1, 0.1, 0.1, 0.6)
	hp_bg.offset_left = 20
	hp_bg.offset_top = 138
	hp_bg.offset_right = 320
	hp_bg.offset_bottom = 166
	add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.9, 0.4)
	_hp_fill.offset_left = 22
	_hp_fill.offset_top = 140
	_hp_fill.offset_right = 318
	_hp_fill.offset_bottom = 164
	add_child(_hp_fill)

	# джойстик
	var joy := Control.new()
	joy.set_script(JoystickScr)
	joy.position = Vector2(60, 520)
	add_child(joy)
	joy.dir_changed.connect(_on_joy)

	# кнопка стрельбы
	var fire := Button.new()
	fire.text = "УДАР"
	fire.focus_mode = Control.FOCUS_NONE
	fire.anchor_left = 1.0
	fire.anchor_right = 1.0
	fire.anchor_top = 1.0
	fire.anchor_bottom = 1.0
	fire.offset_left = -190
	fire.offset_right = -40
	fire.offset_top = -180
	fire.offset_bottom = -60
	fire.add_theme_font_size_override("font_size", 30)
	fire.button_down.connect(func() -> void: _set_fire(true))
	fire.button_up.connect(func() -> void: _set_fire(false))
	add_child(fire)

	# экран проигрыша
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.visible = false
	add_child(_over)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(dim)

	var go := Label.new()
	go.text = "ВЫ ПРОИГРАЛИ"
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.anchor_left = 0.1
	go.anchor_right = 0.9
	go.anchor_top = 0.3
	go.anchor_bottom = 0.45
	go.add_theme_font_size_override("font_size", 52)
	go.modulate = Color(1.0, 0.35, 0.35)
	_over.add_child(go)

	_over_score = Label.new()
	_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_score.anchor_left = 0.1
	_over_score.anchor_right = 0.9
	_over_score.anchor_top = 0.45
	_over_score.anchor_bottom = 0.55
	_over_score.add_theme_font_size_override("font_size", 30)
	_over.add_child(_over_score)

	var restart := Button.new()
	restart.text = "ЗАНОВО"
	restart.focus_mode = Control.FOCUS_NONE
	restart.anchor_left = 0.5
	restart.anchor_right = 0.5
	restart.anchor_top = 0.58
	restart.anchor_bottom = 0.68
	restart.offset_left = -140
	restart.offset_right = 140
	restart.add_theme_font_size_override("font_size", 30)
	restart.pressed.connect(func() -> void:
		get_tree().reload_current_scene()
	)
	_over.add_child(restart)

	var to_menu := Button.new()
	to_menu.text = "В МЕНЮ"
	to_menu.focus_mode = Control.FOCUS_NONE
	to_menu.anchor_left = 0.5
	to_menu.anchor_right = 0.5
	to_menu.anchor_top = 0.7
	to_menu.anchor_bottom = 0.8
	to_menu.offset_left = -140
	to_menu.offset_right = 140
	to_menu.add_theme_font_size_override("font_size", 30)
	to_menu.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	_over.add_child(to_menu)

	update_score()
	update_coins()
	set_level(1)
	_hp(100, 100)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash_l.modulate.a = minf(1.0, _flash_t * 2.0)
		if _flash_t <= 0.0:
			_flash_l.visible = false


func _on_joy(dir: Vector2) -> void:
	if _player:
		_player.set_meta("mob_dir", dir)


func _set_fire(on: bool) -> void:
	if _player:
		_player.set_meta("mob_fire", on)


func update_score() -> void:
	if _score_l:
		_score_l.text = "Очки: %d" % GameState.score
	if _high_l:
		_high_l.text = "Рекорд: %d" % GameState.high_score


func update_coins() -> void:
	if _coins_l:
		_coins_l.text = "Монеты: %d" % GameState.coins


func set_level(lvl: int) -> void:
	if _level_l:
		_level_l.text = "Уровень %d" % lvl


func flash_level(lvl: int) -> void:
	if _flash_l:
		_flash_l.text = "УРОВЕНЬ %d" % lvl
		_flash_l.visible = true
		_flash_l.modulate.a = 1.0
		_flash_t = 1.5


func _hp(v: float, mx: float) -> void:
	var w := (v / mx) * 296.0
	_hp_fill.offset_right = 22.0 + w
	_hp_fill.color = Color(0.3, 0.9, 0.4) if v > 30 else Color(1.0, 0.3, 0.3)


func show_game_over(score: int) -> void:
	_over_score.text = "Очки: %d · Рекорд: %d" % [score, GameState.high_score]
	_over.visible = true


func show_complete(lvl: int) -> void:
	if _flash_l:
		_flash_l.text = "УРОВЕНЬ %d ПРОЙДЕН!" % lvl
		_flash_l.modulate = Color(0.5, 1.0, 0.55)
		_flash_l.visible = true
		_flash_l.modulate.a = 1.0
		_flash_t = 2.2
