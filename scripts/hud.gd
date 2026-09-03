extends CanvasLayer
## HUD: прицел, HP/голод/жажда, hotbar инвентаря внизу по центру, сенсорное управление.

const JoystickScr := preload("res://scripts/joystick.gd")

var _player: Node3D
var _hp_fill: ColorRect
var _hunger_fill: ColorRect
var _thirst_fill: ColorRect
var _hp_l: Label
var _slots: Array = []
var _over: Control
var _craft: Control
var _craft_list: VBoxContainer


func bind(p: Node3D) -> void:
	_player = p
	_player.died.connect(_on_died)


func _ready() -> void:
	layer = 10
	_build()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_craft.visible = not _craft.visible
			_refresh_craft()


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

	# --- hotbar инвентаря: нижняя середина ---
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -210
	bar.offset_right = 210
	bar.offset_top = -70
	bar.offset_bottom = -10
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	# 4 ячейки инвентаря
	for i in range(4):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(96, 60)
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.text = "—"
		slot.add_child(lbl)
		bar.add_child(slot)
		_slots.append(lbl)

	# --- HP / голод / жажда: чуть выше hotbar ---
	_hp_fill = _bar(Color(0.3, 0.9, 0.4), -110, 30, 180)
	_hunger_fill = _bar(Color(0.95, 0.6, 0.2), -140, 30, 180)
	_thirst_fill = _bar(Color(0.3, 0.65, 1.0), -170, 30, 180)

	var hp_icon := Label.new()
	hp_icon.text = "HP"
	hp_icon.anchor_top = 1.0
	hp_icon.anchor_bottom = 1.0
	hp_icon.offset_left = 30
	hp_icon.offset_top = -112
	hp_icon.offset_right = 80
	hp_icon.offset_bottom = -90
	hp_icon.add_theme_font_size_override("font_size", 16)
	hp_icon.modulate = Color(1, 1, 1, 0.8)
	add_child(hp_icon)

	var hg_icon := Label.new()
	hg_icon.text = "ЕДА"
	hg_icon.anchor_top = 1.0
	hg_icon.anchor_bottom = 1.0
	hg_icon.offset_left = 30
	hg_icon.offset_top = -142
	hg_icon.offset_right = 80
	hg_icon.offset_bottom = -120
	hg_icon.add_theme_font_size_override("font_size", 14)
	hg_icon.modulate = Color(1, 1, 1, 0.8)
	add_child(hg_icon)

	var th_icon := Label.new()
	th_icon.text = "ВОДА"
	th_icon.anchor_top = 1.0
	th_icon.anchor_bottom = 1.0
	th_icon.offset_left = 30
	th_icon.offset_top = -172
	th_icon.offset_right = 80
	th_icon.offset_bottom = -150
	th_icon.add_theme_font_size_override("font_size", 14)
	th_icon.modulate = Color(1, 1, 1, 0.8)
	add_child(th_icon)

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

	# кнопка крафта
	var craft_btn := Button.new()
	craft_btn.text = "КРАФТ"
	craft_btn.focus_mode = Control.FOCUS_NONE
	craft_btn.anchor_left = side_anchor
	craft_btn.anchor_right = side_anchor
	craft_btn.anchor_top = 1.0
	craft_btn.anchor_bottom = 1.0
	craft_btn.offset_left = -250 if on_right else 100
	craft_btn.offset_right = -100 if on_right else 250
	craft_btn.offset_top = -300
	craft_btn.offset_bottom = -200
	craft_btn.add_theme_font_size_override("font_size", 20)
	craft_btn.modulate = Color(0.8, 0.65, 0.4)
	craft_btn.pressed.connect(func() -> void:
		_craft.visible = not _craft.visible
		_refresh_craft()
	)
	add_child(craft_btn)

	_build_craft_menu()

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


func _bar(color: Color, top: float, left: float, width: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.6)
	bg.anchor_top = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = left
	bg.offset_top = top
	bg.offset_right = left + width
	bg.offset_bottom = top + 22
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.anchor_top = 1.0
	fill.anchor_bottom = 1.0
	fill.offset_left = left + 2
	fill.offset_top = top + 2
	fill.offset_right = left + width - 2
	fill.offset_bottom = top + 20
	add_child(fill)
	return fill


func _on_joy(dir: Vector2) -> void:
	if _player:
		_player.set_meta("mob_dir", dir)


func _process(delta: float) -> void:
	_update_bars()


func _update_bars() -> void:
	var hp_w := (GameState.hp / GameState.max_hp) * 176.0
	_hp_fill.offset_right = 32.0 + hp_w
	var hg_w := (GameState.hunger / 100.0) * 176.0
	_hunger_fill.offset_right = 32.0 + hg_w
	var th_w := (GameState.thirst / 100.0) * 176.0
	_thirst_fill.offset_right = 32.0 + th_w


func refresh() -> void:
	# слоты hotbar: дерево, камень, мясо, вода
	var items := [["Дерево", GameState.wood], ["Камень", GameState.stone], ["Мясо", GameState.meat], ["Сера", GameState.sulfur]]
	for i in range(4):
		var name: String = items[i][0]
		var count: int = items[i][1]
		if count > 0:
			_slots[i].text = "%s\nx%d" % [name, count]
		else:
			_slots[i].text = "—"


func _build_craft_menu() -> void:
	_craft = Control.new()
	_craft.set_anchors_preset(Control.PRESET_FULL_RECT)
	_craft.visible = false
	add_child(_craft)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_craft.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -320
	panel.offset_bottom = 320
	_craft.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var t := Label.new()
	t.text = "КРАФТ"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.modulate = Color(0.8, 0.65, 0.4)
	v.add_child(t)

	var res := Label.new()
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.add_theme_font_size_override("font_size", 16)
	res.modulate = Color(0.9, 0.9, 0.85)
	res.name = "ResLabel"
	v.add_child(res)

	var sep := HSeparator.new()
	v.add_child(sep)

	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override("separation", 6)
	v.add_child(_craft_list)

	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: _craft.visible = false)
	v.add_child(close)


func _refresh_craft() -> void:
	for c in _craft_list.get_children():
		c.queue_free()
	# строка ресурсов
	var res_label := _craft.find_child("ResLabel", true, false) as Label
	if res_label:
		res_label.text = "Дерево:%d  Камень:%d  Сера:%d  Железо:%d  Ткань:%d  Металл:%d" % [GameState.wood, GameState.stone, GameState.sulfur, GameState.iron, GameState.cloth, GameState.metal]
	# кнопки рецептов
	for id in GameState.RECIPES:
		var rec: Dictionary = GameState.RECIPES[id]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 18)
		# стоимость строкой
		var cost_txt := ""
		for r in rec["cost"]:
			cost_txt += " %s:%d" % [r, rec["cost"][r]]
		btn.text = rec["name"] + "  (" + cost_txt.strip_edges() + ")"
		btn.disabled = not GameState.can_craft(id)
		btn.pressed.connect(func() -> void:
			GameState.craft(id)
			_refresh_craft()
			refresh()
		)
		_craft_list.add_child(btn)


func _on_died() -> void:
	_over.visible = true
