extends Control
## Главное меню сюжетки.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# soft vignette bars
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.35)
	top.anchor_right = 1.0
	top.offset_bottom = 90
	add_child(top)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	cc.add_child(box)

	var title := Label.new()
	title.text = "ASHVEIL: ПЕПЕЛ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "3D сюжетная история · глава 1"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.75, 0.8, 0.9)
	box.add_child(sub)

	var play := Button.new()
	play.text = "Начать историю"
	play.custom_minimum_size = Vector2(320, 70)
	play.add_theme_font_size_override("font_size", 26)
	play.pressed.connect(_play)
	box.add_child(play)

	var cont := Button.new()
	cont.text = "Продолжить (сброс главы)"
	cont.custom_minimum_size = Vector2(320, 60)
	cont.add_theme_font_size_override("font_size", 20)
	cont.pressed.connect(_play)
	box.add_child(cont)

	var exit := Button.new()
	exit.text = "Выход"
	exit.custom_minimum_size = Vector2(320, 60)
	exit.add_theme_font_size_override("font_size", 22)
	exit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(exit)

	var tip := Label.new()
	tip.text = "Телефон: джойстик + ДЕЙСТВИЕ\nПК: WASD + мышь-свайп + E"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(0.6, 0.65, 0.7)
	box.add_child(tip)


func _play() -> void:
	Story.reset()
	Controls.ui_open = false
	Controls.move_vector = Vector2.ZERO
	get_tree().change_scene_to_file("res://scenes/World.tscn")
