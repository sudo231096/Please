extends Control
## Меню выбора уровня 1..250.

const MAX_LEVEL := 250


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.18, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# forest-ish decor bars
	for i in range(12):
		var t := ColorRect.new()
		t.color = Color(0.15, 0.28, 0.16, 0.55)
		t.size = Vector2(28, randf_range(120, 280))
		t.position = Vector2(40 + i * 105, 720 - t.size.y)
		add_child(t)

	var title := Label.new()
	title.text = "FOREST BANDIT RUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.offset_top = 24
	title.offset_bottom = 90
	title.add_theme_font_size_override("font_size", 44)
	title.modulate = Color(0.85, 0.95, 0.7)
	add_child(title)

	var sub := Label.new()
	sub.text = "2D · 250 уровней · разбойники в лесу\nОткрыто уровней: %d / %d" % [Progress.unlocked, MAX_LEVEL]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.05
	sub.anchor_right = 0.95
	sub.offset_top = 90
	sub.offset_bottom = 150
	sub.add_theme_font_size_override("font_size", 20)
	add_child(sub)

	var play := Button.new()
	play.text = "Играть · уровень %d" % Progress.unlocked
	play.focus_mode = Control.FOCUS_NONE
	play.anchor_left = 0.5
	play.anchor_right = 0.5
	play.offset_left = -180
	play.offset_right = 180
	play.offset_top = 170
	play.offset_bottom = 240
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(func() -> void:
		Progress.current = Progress.unlocked
		get_tree().change_scene_to_file("res://scenes/Level.tscn")
	)
	add_child(play)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.08
	scroll.anchor_right = 0.92
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = 270
	scroll.offset_bottom = -30
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for i in range(1, MAX_LEVEL + 1):
		var b := Button.new()
		b.text = str(i)
		b.custom_minimum_size = Vector2(72, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		var unlocked := i <= Progress.unlocked
		b.disabled = not unlocked
		if i == Progress.unlocked:
			b.modulate = Color(0.7, 1.0, 0.6)
		var lvl := i
		b.pressed.connect(func() -> void:
			Progress.current = lvl
			get_tree().change_scene_to_file("res://scenes/Level.tscn")
		)
		grid.add_child(b)
