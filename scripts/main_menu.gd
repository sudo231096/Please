extends Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# neon side bars
	var l := ColorRect.new()
	l.color = Color(0.2, 0.85, 1.0, 0.35)
	l.anchor_bottom = 1.0
	l.offset_right = 8
	add_child(l)
	var r := ColorRect.new()
	r.color = Color(1.0, 0.35, 0.45, 0.35)
	r.anchor_left = 1.0
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.offset_left = -8
	add_child(r)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	cc.add_child(box)

	var title := Label.new()
	title.text = "NEON CLASH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.modulate = Color(0.55, 0.95, 1.0)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "mobile FPS · арена против ботов\nв духе Standoff"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(0.75, 0.8, 0.9)
	box.add_child(sub)

	var play := Button.new()
	play.text = "ИГРАТЬ  ·  Deathmatch"
	play.custom_minimum_size = Vector2(360, 74)
	play.add_theme_font_size_override("font_size", 26)
	play.pressed.connect(func() -> void:
		Controls.ui_open = false
		Controls.move_vector = Vector2.ZERO
		Controls.fire_held = false
		GameState.reset_match()
		get_tree().change_scene_to_file("res://scenes/Arena.tscn")
	)
	box.add_child(play)

	var tip := Label.new()
	tip.text = "ОГОНЬ · R перезарядка · ОРУЖИЕ смена\nGlock / AK / AWM  ·  до 10 фрагов"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(0.6, 0.65, 0.75)
	box.add_child(tip)

	var exit := Button.new()
	exit.text = "Выход"
	exit.custom_minimum_size = Vector2(360, 56)
	exit.add_theme_font_size_override("font_size", 22)
	exit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(exit)
