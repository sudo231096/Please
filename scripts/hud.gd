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
var _rot_btn: Button
var _study: Control
var _study_list: VBoxContainer
var _study_btn: Button
var _toast: Label


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

	# --- hotbar инвентаря: нижняя середина (6 слотов, как в Rust) ---
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -330
	bar.offset_right = 330
	bar.offset_top = -70
	bar.offset_bottom = -10
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)

	# 6 ячеек инвентаря (кнопки: тап выбирает слот, повторный тап — использует)
	_slots.clear()
	for i in range(6):
		var slot := Button.new()
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(100, 60)
		slot.add_theme_font_size_override("font_size", 13)
		var slot_i := i
		slot.pressed.connect(func() -> void:
			if GameState.selected_slot == slot_i:
				# повторный тап по активному — использовать (съесть/выпить)
				GameState.use_slot(slot_i)
			else:
				GameState.selected_slot = slot_i
			refresh()
		)
		bar.add_child(slot)
		_slots.append(slot)

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
	tip.text = "WASD — ходьба · мышь — обзор · ЛКМ — удар · E — открыть ящик · Q — пить"
	tip.anchor_top = 1.0
	tip.anchor_bottom = 1.0
	tip.offset_left = 16
	tip.offset_top = -40
	tip.offset_right = 720
	tip.offset_bottom = -10
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(1, 1, 1, 0.6)
	add_child(tip)

	# кнопка «Карта» слева в углу
	var map_btn := Button.new()
	map_btn.text = "КАРТА"
	map_btn.focus_mode = Control.FOCUS_NONE
	map_btn.offset_left = 20
	map_btn.offset_top = 20
	map_btn.offset_right = 140
	map_btn.offset_bottom = 66
	map_btn.add_theme_font_size_override("font_size", 20)
	map_btn.modulate = Color(0.5, 0.75, 0.9)
	map_btn.pressed.connect(func() -> void:
		_save_pos_and_go("res://scenes/Map.tscn")
	)
	add_child(map_btn)

	# кнопка «Инвентарь»
	var inv_btn := Button.new()
	inv_btn.text = "ИНВЕНТАРЬ"
	inv_btn.focus_mode = Control.FOCUS_NONE
	inv_btn.offset_left = 20
	inv_btn.offset_top = 76
	inv_btn.offset_right = 200
	inv_btn.offset_bottom = 122
	inv_btn.add_theme_font_size_override("font_size", 18)
	inv_btn.modulate = Color(0.7, 0.7, 0.5)
	inv_btn.pressed.connect(func() -> void:
		_save_pos_and_go("res://scenes/Inventory.tscn")
	)
	add_child(inv_btn)

	# кнопка «В МЕНЮ» (правый верхний угол)
	var exit_btn := Button.new()
	exit_btn.text = "В МЕНЮ"
	exit_btn.focus_mode = Control.FOCUS_NONE
	exit_btn.anchor_left = 1.0
	exit_btn.anchor_right = 1.0
	exit_btn.offset_left = -170
	exit_btn.offset_right = -20
	exit_btn.offset_top = 20
	exit_btn.offset_bottom = 66
	exit_btn.add_theme_font_size_override("font_size", 20)
	exit_btn.modulate = Color(0.9, 0.5, 0.45)
	exit_btn.pressed.connect(func() -> void:
		GameState.return_to_pos = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	add_child(exit_btn)

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

	# кнопка «ВЗЯТЬ» (открыть ящик с лутом)
	var take_btn := Button.new()
	take_btn.text = "ВЗЯТЬ"
	take_btn.focus_mode = Control.FOCUS_NONE
	take_btn.anchor_left = side_anchor
	take_btn.anchor_right = side_anchor
	take_btn.anchor_top = 1.0
	take_btn.anchor_bottom = 1.0
	take_btn.offset_left = -170 if on_right else 20
	take_btn.offset_right = -20 if on_right else 170
	take_btn.offset_top = -420
	take_btn.offset_bottom = -320
	take_btn.add_theme_font_size_override("font_size", 22)
	take_btn.modulate = Color(0.95, 0.85, 0.4)
	take_btn.pressed.connect(func() -> void: _player.set_meta("mob_interact", true))
	add_child(take_btn)

	# кнопка «использовать» (съесть/выпить активный предмет)
	var use_btn := Button.new()
	use_btn.text = "ЕСТЬ/ПИТЬ"
	use_btn.focus_mode = Control.FOCUS_NONE
	use_btn.anchor_left = side_anchor
	use_btn.anchor_right = side_anchor
	use_btn.anchor_top = 1.0
	use_btn.anchor_bottom = 1.0
	use_btn.offset_left = -330 if on_right else 180
	use_btn.offset_right = -180 if on_right else 330
	use_btn.offset_top = -300
	use_btn.offset_bottom = -200
	use_btn.add_theme_font_size_override("font_size", 18)
	use_btn.modulate = Color(0.7, 0.9, 0.7)
	use_btn.pressed.connect(func() -> void:
		GameState.use_slot(GameState.selected_slot)
		refresh()
	)
	add_child(use_btn)

	# кнопка приседа (выше и правее)
	var crouch := Button.new()
	crouch.text = "СЕСТЬ"
	crouch.focus_mode = Control.FOCUS_NONE
	crouch.anchor_left = side_anchor
	crouch.anchor_right = side_anchor
	crouch.anchor_top = 1.0
	crouch.anchor_bottom = 1.0
	crouch.offset_left = -180 if on_right else 170
	crouch.offset_right = -30 if on_right else 320
	crouch.offset_top = -290
	crouch.offset_bottom = -200
	crouch.add_theme_font_size_override("font_size", 20)
	crouch.button_down.connect(func() -> void: _player.set_meta("mob_crouch", true))
	crouch.button_up.connect(func() -> void: _player.set_meta("mob_crouch", false))
	add_child(crouch)

	# кнопка крафта (выше)
	var craft_btn := Button.new()
	craft_btn.text = "КРАФТ"
	craft_btn.focus_mode = Control.FOCUS_NONE
	craft_btn.anchor_left = side_anchor
	craft_btn.anchor_right = side_anchor
	craft_btn.anchor_top = 1.0
	craft_btn.anchor_bottom = 1.0
	craft_btn.offset_left = -250 if on_right else 100
	craft_btn.offset_right = -100 if on_right else 250
	craft_btn.offset_top = -540
	craft_btn.offset_bottom = -440
	craft_btn.add_theme_font_size_override("font_size", 20)
	craft_btn.modulate = Color(0.8, 0.65, 0.4)
	craft_btn.pressed.connect(func() -> void:
		_craft.visible = not _craft.visible
		_refresh_craft()
	)
	add_child(craft_btn)

	_build_craft_menu()

	# кнопка «Изучить» (видна только когда построен верстак)
	_study_btn = Button.new()
	_study_btn.text = "ИЗУЧИТЬ"
	_study_btn.focus_mode = Control.FOCUS_NONE
	_study_btn.anchor_left = side_anchor
	_study_btn.anchor_right = side_anchor
	_study_btn.anchor_top = 1.0
	_study_btn.anchor_bottom = 1.0
	_study_btn.offset_left = -250 if on_right else 100
	_study_btn.offset_right = -100 if on_right else 250
	_study_btn.offset_top = -650
	_study_btn.offset_bottom = -560
	_study_btn.add_theme_font_size_override("font_size", 20)
	_study_btn.modulate = Color(0.6, 0.5, 0.9)
	_study_btn.visible = false
	_study_btn.pressed.connect(func() -> void:
		_study.visible = not _study.visible
		if _study.visible:
			_refresh_study()
	)
	add_child(_study_btn)

	_build_study_menu()

	# кнопка «Повернуть» (видна только в режиме строительства)
	_rot_btn = Button.new()
	_rot_btn.text = "ПОВЕРНУТЬ"
	_rot_btn.focus_mode = Control.FOCUS_NONE
	_rot_btn.anchor_left = 0.5
	_rot_btn.anchor_right = 0.5
	_rot_btn.anchor_top = 1.0
	_rot_btn.anchor_bottom = 1.0
	_rot_btn.offset_left = -90
	_rot_btn.offset_right = 90
	_rot_btn.offset_top = -190
	_rot_btn.offset_bottom = -130
	_rot_btn.add_theme_font_size_override("font_size", 20)
	_rot_btn.modulate = Color(0.9, 0.75, 0.4)
	_rot_btn.visible = false
	_rot_btn.pressed.connect(func() -> void: GameState.build_rot += PI / 2.0)
	add_child(_rot_btn)

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


func _save_pos_and_go(scene: String) -> void:
	if _player:
		GameState.last_pos = _player.global_position
		GameState.return_to_pos = true
	get_tree().change_scene_to_file(scene)


func _process(delta: float) -> void:
	_update_bars()
	_rot_btn.visible = GameState.build_mode
	_study_btn.visible = GameState.workbench_built


func _update_bars() -> void:
	var hp_w := (GameState.hp / GameState.max_hp) * 176.0
	_hp_fill.offset_right = 32.0 + hp_w
	var hg_w := (GameState.hunger / 100.0) * 176.0
	_hunger_fill.offset_right = 32.0 + hg_w
	var th_w := (GameState.thirst / 100.0) * 176.0
	_thirst_fill.offset_right = 32.0 + th_w


func refresh() -> void:
	# слоты hotbar (6): название + количество, подсветка активного
	for i in range(6):
		var slot: Button = _slots[i]
		var name: String = GameState.HOTBAR[i][1]
		var count: int = GameState.hotbar_count(i)
		if count > 0:
			slot.text = "%s\nx%d" % [name, count]
		else:
			slot.text = name
		# подсветка активного слота
		if i == GameState.selected_slot:
			slot.modulate = Color(1.0, 1.0, 0.55)
		else:
			slot.modulate = Color(1, 1, 1)


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


func _build_study_menu() -> void:
	_study = Control.new()
	_study.set_anchors_preset(Control.PRESET_FULL_RECT)
	_study.visible = false
	add_child(_study)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_study.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -260
	panel.offset_bottom = 260
	_study.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var t := Label.new()
	t.text = "ИЗУЧЕНИЕ (в верстаке)"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.modulate = Color(0.6, 0.5, 0.9)
	v.add_child(t)

	var scrap_l := Label.new()
	scrap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scrap_l.add_theme_font_size_override("font_size", 16)
	scrap_l.modulate = Color(0.9, 0.9, 0.85)
	scrap_l.name = "ScrapLabel"
	v.add_child(scrap_l)

	var sep := HSeparator.new()
	v.add_child(sep)

	_study_list = VBoxContainer.new()
	_study_list.add_theme_constant_override("separation", 6)
	v.add_child(_study_list)

	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: _study.visible = false)
	v.add_child(close)


func _refresh_study() -> void:
	for c in _study_list.get_children():
		c.queue_free()
	var scrap_l := _study.find_child("ScrapLabel", true, false) as Label
	if scrap_l:
		scrap_l.text = "Скрап: %d" % GameState.scrap
	for id in GameState.TECH_TREE:
		var t: Dictionary = GameState.TECH_TREE[id]
		var tid: String = id
		var row := HBoxContainer.new()
		_study_list.add_child(row)
		var name_l := Label.new()
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 17)
		if GameState.is_tech_learned(tid):
			name_l.text = t["name"] + " — изучено"
			name_l.modulate = Color(0.5, 0.9, 0.6)
		else:
			var u := ""
			for uid in t["unlocks"]:
				u += " " + uid
			name_l.text = "%s (%d скрапа)%s" % [t["name"], t["cost"], " → " + u.strip_edges() if u != "" else ""]
		row.add_child(name_l)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "Изучить"
		btn.add_theme_font_size_override("font_size", 16)
		btn.disabled = GameState.is_tech_learned(tid) or not GameState.tech_available(tid) or GameState.scrap < int(t["cost"])
		btn.pressed.connect(func() -> void:
			if GameState.research(tid):
				_refresh_study()
				_refresh_craft()
				refresh()
		)
		row.add_child(btn)


func _refresh_craft() -> void:
	for c in _craft_list.get_children():
		c.queue_free()
	# строка ресурсов
	var res_label := _craft.find_child("ResLabel", true, false) as Label
	if res_label:
		res_label.text = "Дерево:%d  Камень:%d  Сера:%d  Железо:%d  Скрап:%d" % [GameState.wood, GameState.stone, GameState.sulfur, GameState.iron, GameState.scrap]
	# кнопки рецептов (все доступны сразу)
	for id in GameState.RECIPES:
		var rec: Dictionary = GameState.RECIPES[id]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 18)
		var cost_txt := ""
		for r in rec["cost"]:
			cost_txt += " %s:%d" % [r, rec["cost"][r]]
		btn.text = rec["name"] + "  (" + cost_txt.strip_edges() + ")"
		btn.disabled = not GameState.can_craft(id)
		var rid: String = id
		btn.pressed.connect(func() -> void:
			if GameState.craft(rid):
				if rec["type"] == "build":
					GameState.begin_build(rid)
					_craft.visible = false
				_refresh_craft()
				refresh()
		)
		_craft_list.add_child(btn)


func _on_died() -> void:
	_over.visible = true


func toast(msg: String) -> void:
	# всплывающее сообщение (что забрал из ящика и т.п.)
	if _toast == null:
		_toast = Label.new()
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.anchor_left = 0.2
		_toast.anchor_right = 0.8
		_toast.anchor_top = 0.3
		_toast.anchor_bottom = 0.4
		_toast.add_theme_font_size_override("font_size", 30)
		_toast.modulate = Color(1, 0.95, 0.6)
		add_child(_toast)
	_toast.text = msg
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_toast.visible = false
		_toast.modulate.a = 1.0
	)
