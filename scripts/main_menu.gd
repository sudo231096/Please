extends Control
## Главное меню 3D-игры.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.16, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	cc.add_child(vbox)

	var title := Label.new()
	title.text = "PIXEL SURVIVAL 3D"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "выживание от первого лица"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	vbox.add_child(sub)

	var play := Button.new()
	play.text = "Играть"
	play.custom_minimum_size = Vector2(280, 72)
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(_play)
	vbox.add_child(play)

	var exit := Button.new()
	exit.text = "Выход"
	exit.custom_minimum_size = Vector2(280, 72)
	exit.add_theme_font_size_override("font_size", 28)
	exit.pressed.connect(_exit)
	vbox.add_child(exit)


func _play() -> void:
	# новый заход — чистый инвентарь
	Inv.restore({"items": {}, "dur": {}})
	Controls.equipped = ""
	Controls.ui_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Game3D.tscn")


func _exit() -> void:
	get_tree().quit()
