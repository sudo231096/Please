extends CanvasLayer
## HUD: прицел, HP, счёт убийств, сенсорное управление.

const JoystickScr := preload("res://scripts/joystick.gd")

var _player: Node3D
var _hp_fill: ColorRect
var _kills_l: Label
var _hp_l: Label
var _over: Control
var kills := 0


func bind(p: Node3D) -> void:
	_player = p
	_player.hp_changed.connect(_hp)
	_player.died.connect(_on_died)


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	# прицел
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

	# HP бар
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.1, 0.1, 0.1, 0.6)
	hp_bg.offset_left = 20
	hp_bg.offset_top = 20
	hp_bg.offset_right = 320
	hp_bg.offset_bottom = 48
	add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.9, 0.4)
	_hp_fill.offset_left = 22
	_hp_fill.offset_top = 22
	_hp_fill.offset_right = 318
	_hp_fill.offset_bottom = 46
	add_child(_hp_fill)
	_hp_l = Label.new()
	_hp_l.offset_left = 22
	_hp_l.offset_top = 22
	_hp_l.offset_right = 320
	_hp_l.offset_bottom = 46
	_hp_l.add_theme_font_size_override("font_size", 18)
	_hp_l.modulate = Color(1, 1, 1)
	add_child(_hp_l)

	# счёт убийств
	_kills_l = Label.new()
	_kills_l.offset_left = 20
	_kills_l.offset_top = 56
	_kills_l.offset_right = 400
	_kills_l.offset_bottom = 88
	_kills_l.add_theme_font_size_override("font_size", 22)
	_kills_l.modulate = Color(1.0, 0.85, 0.4)
	add_child(_kills_l)

	# подсказка (десктоп)
	var tip := Label.new()
	tip.text = "WASD — ходьба · мышь — обзор · ЛКМ — удар · Space — прыжок"
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.offset_left = 16
	tip.offset_top = -40
	tip.offset_right = 700
	tip.offset_bottom = -10
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(1, 1, 1, 0.6)
	add_child(tip)

	# джойстик (левый)
	var joy := Control.new()
	joy.set_script(JoystickScr)
	joy.position = Vector2(50, 480)
	add_child(joy)
	joy.dir_changed.connect(_on_joy)

	# кнопка прыжка
	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.focus_mode = Control.FOCUS_NONE
	jump.anchor_left = 1.0
	jump.anchor_right = 1.0
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -330
	jump.offset_right = -180
	jump.offset_top = -180
	jump.offset_bottom = -60
	jump.add_theme_font_size_override("font_size", 24)
	jump.pressed.connect(func() -> void: _player.set_meta("mob_jump", true))
	add_child(jump)

	# кнопка удара
	var atk := Button.new()
	atk.text = "УДАР"
	atk.focus_mode = Control.FOCUS_NONE
	atk.anchor_left = 1.0
	atk.anchor_right = 1.0
	atk.anchor_top = 1.0
	atk.anchor_bottom = 1.0
	atk.offset_left = -170
	atk.offset_right = -20
	atk.offset_top = -180
	atk.offset_bottom = -60
	atk.add_theme_font_size_override("font_size", 26)
	atk.button_down.connect(func() -> void: _player.set_meta("mob_attack", true))
	add_child(atk)

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

	_hp(100, 100)
	_kills_l.text = "Убито: 0"


func _on_joy(dir: Vector2) -> void:
	if _player:
		_player.set_meta("mob_dir", dir)


func _hp(v: float, mx: float) -> void:
	var w := (v / mx) * 296.0
	_hp_fill.offset_right = 22.0 + w
	_hp_fill.color = Color(0.3, 0.9, 0.4) if v > 30 else Color(1.0, 0.3, 0.3)
	_hp_l.text = "HP %d/%d" % [int(v), int(mx)]


func add_kill() -> void:
	kills += 1
	_kills_l.text = "Убито: %d" % kills


func _on_died() -> void:
	_over.visible = true
