extends Control
## Заставка при заходе: реклама Telegram-канала + переход в меню.

const CHANNEL := "@skraplands"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# переход в меню через 3 секунды (или по тапу)
	get_tree().create_timer(3.0).timeout.connect(_go_menu)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "SCRAPLANDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.anchor_top = 0.25
	title.anchor_bottom = 0.4
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color(0.95, 0.85, 0.6)
	add_child(title)

	var sub := Label.new()
	sub.text = "выживание в пустоши"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.05
	sub.anchor_right = 0.95
	sub.anchor_top = 0.4
	sub.anchor_bottom = 0.5
	sub.add_theme_font_size_override("font_size", 26)
	sub.modulate = Color(0.75, 0.8, 0.75)
	add_child(sub)

	# блок-реклама канала
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = 40
	panel.offset_bottom = 200
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var adv := Label.new()
	adv.text = "Наш Telegram-канал"
	adv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	adv.add_theme_font_size_override("font_size", 22)
	adv.modulate = Color(0.85, 0.85, 0.85)
	v.add_child(adv)

	var ch := Label.new()
	ch.text = CHANNEL
	ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ch.add_theme_font_size_override("font_size", 40)
	ch.modulate = Color(0.4, 0.75, 1.0)
	v.add_child(ch)

	var tip := Label.new()
	tip.text = "подпишись — там новости и обновления"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 18)
	tip.modulate = Color(0.6, 0.65, 0.6)
	v.add_child(tip)

	var hint := Label.new()
	hint.text = "нажми, чтобы продолжить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -60
	hint.offset_bottom = -30
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(0.5, 0.55, 0.5, 0.8)
	add_child(hint)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_menu()


func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
