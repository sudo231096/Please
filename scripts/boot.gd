extends Control
## Пустой старт. Игру собираем заново с нуля.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	cc.add_child(box)

	var title := Label.new()
	title.text = "ASHVEIL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "чистый проект · игра снесена\nждём новые задачи"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	box.add_child(sub)

	var btn := Button.new()
	btn.text = "Выход"
	btn.custom_minimum_size = Vector2(220, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(btn)
