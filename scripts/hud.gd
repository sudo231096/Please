extends CanvasLayer
## HUD: прицел, HP, голод, жажда, инвентарь, сенсорное управление.

const JoystickScr := preload("res://scripts/joystick.gd")

var _player: Node3D
var _hp_fill: ColorRect
var _hunger_fill: ColorRect
var _thirst_fill: ColorRect
var _inv_l: Label
var _over: Control


func bind(p: Node3D) -> void:
	_player = p
	_player.died.connect(_on_died)


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	var cross := Label.new()
	cross.text = "+"
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cross.anchor_left = 0.5
	cross.anchor_right = 0.5
	cross.anchor_top = 0.5
	cross.anchor_bottom = 0.5
	cross.offset_left = -20
	cross.offset_right = 20
	cross.offset_top = -20
	cross.offset_bottom = 20
	cross.add_theme_font_size_override("font_size", 36)
	cross.modulate = Color(1, 1, 1, 0.85)
	add_child(cross)

	# HP
	_hp_fill = _bar(Color(0.3, 0.9, 0.4), 20, 20)
	# голод
	_hunger_fill = _bar(Color(0.95, 0.6, 0.2), 20, 52)
	# жажда
	_thirst_fill = _bar(Color(0.3, 0.65, 1.0), 20, 84)

	# инвентарь (слева снизу)
	_inv_l = Label.new()
	_inv_l.anchor_top = 1.0
	_inv_l.anchor_bottom = 1.0
	_inv_l.offset_left = 20
	_inv_l.offset_top = -120
	_inv_l.offset_right = 500
	_inv_l.offset_bottom = -20
	_inv_l.add_theme_font_size_override("font_size", 20)
	_inv_l.modulate = Color(0.9, 0.9, 0.85)
	add_child(_inv_l)

	var tip := Label.new()
	tip.text = "WASD — ходьба · мышь — обзор · ЛКМ — удар · E — есть · Q — пить"
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.offset_left = 16
	tip.offset_top = -40
	tip.offset_right = 720
	tip.offset_bottom = -10
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(1, 1, 1, 0.6)
	add_child(tip)

	# джойстик (слева или справа — из настроек)
	var joy := Control.new()
	joy.set_script(JoystickScr)
	joy.position = Vector2(50, 480) if GameState.buttons_left else Vector2(1020, 480)
	add_child(joy)
	joy.dir_changed.connect(_on_joy)

	# кнопки действий — на противоположной стороне от джойстика
	var on_right := GameState.buttons_left
	var side_anchor := 1.0 if on_right else 0.0

	# прыжок
	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.focus_mode = Control.FOCUS_NONE
	jump.anchor_left = side_anchor
	jump.anchor_right = side_anchor
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -330 if on_right else 180
	jump.offset_right = -180 if on_right else 330
	jump.offset_top = -180
	jump.offset_bottom = -60
	jump.add_theme_font_size_override("font_size", 24)
	jump.pressed.connect(func() -> void: _player.set_meta("mob_jump", true))
	add_child(jump)

	# удар
	var atk := Button.new()
	atk.text = "УДАР"
	atk.focus_mode = Control.FOCUS_NONE
	atk.anchor_left = side_anchor
	atk.anchor_right = side_anchor
	atk.anchor_top = 1.0
	atk.anchor_bottom = 1.0
	atk.offset_left = -170 if on_right else 20
	atk.offset_right = -20 if on_right else 170
	atk.offset_top = -180
	atk.offset_bottom = -60
	atk.add_theme_font_size_override("font_size", 26)
	atk.button_down.connect(func() -> void: _player.set_meta("mob_attack", true))
	add_child(atk)

	# есть / пить
	var eat := Button.new()
	eat.text = "ЕСТЬ"
	eat.focus_mode = Control.FOCUS_NONE
	eat.anchor_left = side_anchor
	eat.anchor_right = side_anchor
	eat.anchor_top = 1.0
	eat.anchor_bottom = 1.0
	eat.offset_left = -330 if on_right else 180
	eat.offset_right = -180 if on_right else 330
	eat.offset_top = -300
	eat.offset_bottom = -200
	eat.add_theme_font_size_override("font_size", 20)
	eat.pressed.connect(func() -> void: GameState.eat(); refresh())
	add_child(eat)

	var drink := Button.new()
	drink.text = "ПИТЬ"
	drink.focus_mode = Control.FOCUS_NONE
	drink.anchor_left = side_anchor
	drink.anchor_right = side_anchor
	drink.anchor_top = 1.0
	drink.anchor_bottom = 1.0
	drink.offset_left = -170 if on_right else 20
	drink.offset_right = -20 if on_right else 170
	drink.offset_top = -300
	drink.offset_bottom = -200
	drink.add_theme_font_size_override("font_size", 20)
	drink.pressed.connect(func() -> void: GameState.drink(); refresh())
	add_child(drink)

	# экран смерти
	_over = Control.new()
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.visible = false
	add_child(_over)
	var dim := ColorRect.new()
	dim.color = Color(0.4, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(dim)
	var go := Label.new()
	go.text = "ВЫ ПОГИБЛИ"
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.anchor_left = 0.1
	go.anchor_right = 0.9
	go.anchor_top = 0.4
	go.anchor_bottom = 0.55
	go.add_theme_font_size_override("font_size", 52)
	go.modulate = Color(1, 0.35, 0.35)
	_over.add_child(go)
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

	refresh()


func _bar(color: Color, top: float, left: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.6)
	bg.offset_left = left
	bg.offset_top = top
	bg.offset_right = left + 200
	bg.offset_bottom = top + 24
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.offset_left = left + 2
	fill.offset_top = top + 2
	fill.offset_right = left + 198
	fill.offset_bottom = top + 22
	add_child(fill)
	return fill


func _on_joy(dir: Vector2) -> void:
	if _player:
		_player.set_meta("mob_dir", dir)


func _process(delta: float) -> void:
	_update_bars()


func _update_bars() -> void:
	var hp_w := (GameState.hp / GameState.max_hp) * 196.0
	_hp_fill.offset_right = 22.0 + hp_w
	var hg_w := (GameState.hunger / 100.0) * 196.0
	_hunger_fill.offset_right = 22.0 + hg_w
	var th_w := (GameState.thirst / 100.0) * 196.0
	_thirst_fill.offset_right = 22.0 + th_w


func refresh() -> void:
	_inv_l.text = "Камень: %d · Мясо: %d · Вода: %d" % [GameState.stone, GameState.meat, GameState.water]


func _on_died() -> void:
	_over.visible = true
