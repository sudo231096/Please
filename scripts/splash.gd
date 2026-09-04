extends Control
## Заставка при заходе: анимированная «гифка» (вращающаяся шестерня + пульсирующий логотип),
## реклама Telegram-канала и переход в меню.

const CHANNEL := "@skraplands"

var _gear: Polygon2D
var _title: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_animate()
	# переход в меню через 3.5 секунды (или по тапу)
	get_tree().create_timer(3.5).timeout.connect(_go_menu)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# вращающаяся шестерня (за логотипом)
	_gear = Polygon2D.new()
	_gear.polygon = _make_gear(Vector2.ZERO, 150.0, 12, 38.0)
	_gear.color = Color(0.32, 0.4, 0.3, 0.5)
	_gear.antialiased = true
	_gear.position = Vector2(640, 260)
	add_child(_gear)

	var gear2 := Polygon2D.new()
	gear2.polygon = _make_gear(Vector2.ZERO, 88.0, 10, 24.0)
	gear2.color = Color(0.5, 0.55, 0.42, 0.35)
	gear2.antialiased = true
	gear2.position = Vector2(640, 260)
	add_child(gear2)

	_title = Label.new()
	_title.text = "SCRAPLANDS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.05
	_title.anchor_right = 0.95
	_title.anchor_top = 0.25
	_title.anchor_bottom = 0.42
	_title.add_theme_font_size_override("font_size", 72)
	_title.modulate = Color(0.95, 0.85, 0.6)
	_title.pivot_offset = Vector2(640, 60)
	add_child(_title)

	var sub := Label.new()
	sub.text = "выживание в пустоши"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.anchor_left = 0.05
	sub.anchor_right = 0.95
	sub.anchor_top = 0.42
	sub.anchor_bottom = 0.52
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
	panel.offset_top = 30
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


func _make_gear(center: Vector2, r: float, teeth: int, tooth: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs := teeth * 2
	for i in range(segs):
		var ang := TAU * i / segs
		var rr := r + (tooth if i % 2 == 0 else 0.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * rr)
	return pts


func _animate() -> void:
	# появление логотипа (масштаб + прозрачность)
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.6).from(0.0)
	tw.parallel().tween_property(_title, "scale", Vector2(1, 1), 0.6).from(Vector2(0.5, 0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# бесконечное «дыхание» логотипа (как гифка)
	var loop := create_tween().set_loops()
	loop.tween_property(_title, "scale", Vector2(1.05, 1.05), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_property(_title, "scale", Vector2(1.0, 1.0), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	# вращение шестерни
	_gear.rotation += delta * 0.6


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_go_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_menu()


func _go_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
