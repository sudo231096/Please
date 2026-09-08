extends CanvasLayer
## Игровой HUD в стиле Rust Mobile.
## Сверху: компас с направлением. Слева: джойстик, инвентарь, крафт, карта, меню.
## Справа: прыжок, присесть, удар, взаимодействие. Снизу: хотбар и показатели.
## В режиме строительства снизу появляется панель категорий и элементов.

const Kit := preload("res://scripts/ui_kit.gd")
const JoystickScr := preload("res://scripts/joystick.gd")

var _player: Node3D
var _slots: Array = []
var _stat := {}
var _toast_l: Label
var _compass: Control
var _compass_lbl: Label

# строительство
var _build_panel: Control
var _build_cat := "Фундамент"
var _build_cats_row: HBoxContainer
var _build_items_row: HBoxContainer
var _build_hint: Label

var _acc := 0.0


func bind(p: Node3D) -> void:
	_player = p
	if _player.has_signal("died"):
		_player.died.connect(_on_died)


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_build()
	refresh()


# ================= построение =================

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_compass(root)
	_build_crosshair(root)
	_build_left(root)
	_build_right(root)
	_build_bottom(root)
	_build_build_panel(root)

	_toast_l = Kit.label("", 18, Kit.GOLD)
	_toast_l.anchor_left = 0.5
	_toast_l.anchor_right = 0.5
	_toast_l.anchor_top = 0.22
	_toast_l.anchor_bottom = 0.22
	_toast_l.offset_left = -260
	_toast_l.offset_right = 260
	_toast_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_l.modulate.a = 0.0
	root.add_child(_toast_l)


func _build_crosshair(root: Control) -> void:
	var c := Kit.label("+", 30, Color(1, 1, 1, 0.75))
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = -14
	c.offset_right = 14
	c.offset_top = -20
	c.offset_bottom = 20
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)


func _build_compass(root: Control) -> void:
	var p := Kit.make_panel(Color(0.05, 0.05, 0.06, 0.75), 8)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -150
	p.offset_right = 150
	p.offset_top = 8
	p.offset_bottom = 46
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)

	_compass = Control.new()
	_compass.custom_minimum_size = Vector2(280, 22)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	p.add_child(_compass)

	_compass_lbl = Kit.label("С", 13, Kit.GOLD)
	_compass_lbl.anchor_left = 0.5
	_compass_lbl.anchor_right = 0.5
	_compass_lbl.offset_left = -30
	_compass_lbl.offset_right = 30
	_compass_lbl.offset_top = 46
	_compass_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compass_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_compass_lbl)


func _draw_compass() -> void:
	if _player == null:
		return
	var yaw: float = _player.rotation.y
	var w: float = _compass.size.x
	var font := ThemeDB.fallback_font
	var marks := [["С", 0.0], ["СВ", 45.0], ["В", 90.0], ["ЮВ", 135.0],
		["Ю", 180.0], ["ЮЗ", 225.0], ["З", 270.0], ["СЗ", 315.0]]
	var head: float = fmod(rad_to_deg(-yaw) + 360.0, 360.0)
	for m in marks:
		var ang: float = float(m[1])
		var diff: float = fmod(ang - head + 540.0, 360.0) - 180.0
		if absf(diff) > 70.0:
			continue
		var x: float = w * 0.5 + diff / 70.0 * (w * 0.5)
		var is_card: bool = String(m[0]).length() == 1
		var tick_h: float = 16.0 if is_card else 11.0
		_compass.draw_line(Vector2(x, 4), Vector2(x, tick_h),
			Color(1, 1, 1, 0.8) if is_card else Color(1, 1, 1, 0.45), 2.0)
		var fs: int = 12 if is_card else 10
		_compass.draw_string(font, Vector2(x - 7, 22), String(m[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 0.9, 0.6, 0.95) if is_card else Color(1, 1, 1, 0.55))
	# центральная риска
	_compass.draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, 20), Kit.ACCENT, 2.0)


func _side_button(text: String, size: Vector2, cb: Callable) -> Button:
	var b := Kit.button(text, 15, false, size)
	b.pressed.connect(cb)
	return b


func _build_left(root: Control) -> void:
	# джойстик движения
	var joy: Control = JoystickScr.new()
	joy.anchor_top = 1.0
	joy.anchor_bottom = 1.0
	joy.offset_left = 24
	joy.offset_top = -230
	joy.offset_right = 224
	joy.offset_bottom = -30
	root.add_child(joy)
	joy.dir_changed.connect(_on_joy)

	# кнопки слева сверху
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.offset_left = 16
	col.offset_top = 62
	root.add_child(col)

	col.add_child(_side_button("🎒 ИНВЕНТАРЬ", Vector2(150, 48), func() -> void:
		_go("res://scenes/Inventory.tscn")))
	col.add_child(_side_button("🔨 КРАФТ", Vector2(150, 46), func() -> void:
		_go("res://scenes/Craft.tscn")))
	col.add_child(_side_button("🗺 КАРТА", Vector2(150, 46), func() -> void:
		_go("res://scenes/Map.tscn")))
	col.add_child(_side_button("🏠 СТРОИТЬ", Vector2(150, 46), _toggle_build))
	col.add_child(_side_button("⚔ КЛАН", Vector2(150, 46), func() -> void:
		_go("res://scenes/Clan.tscn")))
	col.add_child(_side_button("☰ МЕНЮ", Vector2(150, 46), func() -> void:
		_go("res://scenes/Players.tscn")))


func _build_right(root: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = -190
	col.offset_right = -16
	col.offset_top = -300
	col.offset_bottom = -20
	root.add_child(col)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)

	grid.add_child(_side_button("✋\nВЗЯТЬ", Vector2(82, 70), func() -> void:
		if _player and _player.has_method("_interact"):
			_player._interact()))
	grid.add_child(_side_button("⚔\nУДАР", Vector2(82, 70), func() -> void:
		if _player:
			_player.set_meta("mob_attack", true)))
	grid.add_child(_side_button("⤓\nСЕСТЬ", Vector2(82, 70), func() -> void:
		if _player:
			_player.set_meta("mob_crouch", not bool(_player.get_meta("mob_crouch", false)))))
	grid.add_child(_side_button("⤒\nПРЫЖОК", Vector2(82, 70), func() -> void:
		if _player:
			_player.set_meta("mob_jump", true)))
	var raid := _side_button("💣\nРЕЙД", Vector2(82, 70), _do_raid)
	raid.tooltip_text = "Подорвать постройку рейдовым зарядом"
	grid.add_child(raid)
	var loot := _side_button("📦\nСОБРАТЬ", Vector2(82, 70), _loot_event)
	grid.add_child(loot)


func _build_bottom(root: Control) -> void:
	# хотбар
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -300
	bar.offset_right = 300
	bar.offset_top = -76
	bar.offset_bottom = -18
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)

	_slots.clear()
	for i in range(6):
		var b := Kit.button("", 12, false, Vector2(94, 58))
		var idx := i
		b.pressed.connect(func() -> void: _use_slot(idx))
		bar.add_child(b)
		_slots.append(b)

	# показатели слева снизу
	var st := VBoxContainer.new()
	st.add_theme_constant_override("separation", 4)
	st.anchor_top = 1.0
	st.anchor_bottom = 1.0
	st.offset_left = 244
	st.offset_top = -96
	st.offset_bottom = -20
	root.add_child(st)

	for spec in [["hp", "❤", Color(0.85, 0.3, 0.28)],
			["hunger", "🍖", Color(0.85, 0.6, 0.25)],
			["thirst", "💧", Color(0.3, 0.62, 0.9)]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		st.add_child(line)
		line.add_child(Kit.label(String(spec[1]), 14))
		var pb := Kit.bar(100, 100, Color(spec[2]), 12.0)
		pb.custom_minimum_size = Vector2(150, 12)
		line.add_child(pb)
		var vl := Kit.label("100", 12, Kit.TXT)
		vl.custom_minimum_size = Vector2(34, 0)
		line.add_child(vl)
		_stat[String(spec[0])] = {"bar": pb, "label": vl}


# ---------- панель строительства ----------

func _build_build_panel(root: Control) -> void:
	_build_panel = Control.new()
	_build_panel.anchor_left = 0.0
	_build_panel.anchor_right = 1.0
	_build_panel.anchor_top = 1.0
	_build_panel.anchor_bottom = 1.0
	_build_panel.offset_top = -178
	_build_panel.offset_bottom = -6
	_build_panel.visible = false
	_build_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_build_panel)

	var p := Kit.make_panel(Color(0.05, 0.05, 0.06, 0.93), 12)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -370
	p.offset_right = 370
	p.offset_top = 0
	p.offset_bottom = 168
	_build_panel.add_child(p)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)

	# верхняя строка: категории + выход
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	_build_cats_row = HBoxContainer.new()
	_build_cats_row.add_theme_constant_override("separation", 5)
	_build_cats_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_build_cats_row)

	var rot := Kit.button("↻", 18, false, Vector2(54, 44))
	rot.pressed.connect(func() -> void: GameState.build_rot += PI / 2.0)
	top.add_child(rot)

	var up := Kit.button("УЛУЧШИТЬ", 13, false, Vector2(104, 44))
	up.pressed.connect(_upgrade)
	top.add_child(up)

	var dem := Kit.button("РАЗОБРАТЬ", 13, false, Vector2(104, 44))
	dem.pressed.connect(_demolish)
	top.add_child(dem)

	var x := Kit.button("✕", 16, false, Vector2(48, 44))
	x.pressed.connect(_toggle_build)
	top.add_child(x)

	# элементы категории
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 74)
	col.add_child(sc)
	_build_items_row = HBoxContainer.new()
	_build_items_row.add_theme_constant_override("separation", 6)
	sc.add_child(_build_items_row)

	_build_hint = Kit.label("Зелёный контур — можно ставить, красный — нельзя", 12, Kit.TXT_DIM)
	col.add_child(_build_hint)

	_refresh_build_cats()
	_refresh_build_items()


func _refresh_build_cats() -> void:
	for c in _build_cats_row.get_children():
		c.queue_free()
	for cat in GameState.BUILD_CATS:
		var name := String(cat)
		var b := Kit.button(name, 13, name == _build_cat, Vector2(0, 44))
		b.pressed.connect(func() -> void:
			_build_cat = name
			_refresh_build_cats()
			_refresh_build_items()
		)
		_build_cats_row.add_child(b)


func _refresh_build_items() -> void:
	for c in _build_items_row.get_children():
		c.queue_free()
	for kind in GameState.builds_in_cat(_build_cat):
		var k := String(kind)
		var info: Dictionary = GameState.BUILD_CATALOG[k]
		var afford: bool = GameState.can_afford_build(k)
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 1)
		var b := Kit.button(String(info["name"]), 12, k == GameState.build_kind, Vector2(118, 46))
		if not afford:
			b.add_theme_color_override("font_color", Kit.BAD)
		b.pressed.connect(func() -> void:
			GameState.build_kind = k
			GameState.build_mode = true
			_refresh_build_items()
		)
		holder.add_child(b)
		var cost: Dictionary = info["cost"]
		var parts: Array = []
		for r in cost:
			parts.append("%s %d" % [GameState.item_name(String(r)).substr(0, 4), int(cost[r])])
		var cl := Kit.label(", ".join(parts), 10, Kit.OK if afford else Kit.BAD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(cl)
		_build_items_row.add_child(holder)


func _toggle_build() -> void:
	GameState.build_mode = not GameState.build_mode
	if GameState.build_mode and String(GameState.build_kind) == "":
		GameState.build_kind = "foundation"
	_build_panel.visible = GameState.build_mode
	if GameState.build_mode:
		_refresh_build_items()


## Подрыв чужой постройки рейдовым зарядом (нужен предмет в инвентаре)
func _do_raid() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain == null or _player == null or not terrain.has_method("raid_explode"):
		return
	# берём самый мощный доступный заряд
	var tool_id := ""
	for t in ["explosive", "satchel", "torch_raid"]:
		if GameState.count(t) > 0:
			tool_id = t
			break
	if tool_id == "":
		toast("Нет рейдовых зарядов — скрафти их в разделе «Рейд»")
		return
	var fwd := -_player.global_transform.basis.z
	fwd.y = 0.0
	var target: Vector3 = _player.global_position + fwd.normalized() * 3.0
	toast(terrain.raid_explode(target, tool_id))
	refresh()


## Собрать лут мирового события рядом
func _loot_event() -> void:
	var ev := get_tree().get_first_node_in_group("world_events")
	if ev == null or _player == null:
		toast("Рядом нечего собирать")
		return
	# сначала пробуем аирдроп
	for node in get_tree().get_nodes_in_group("terrain"):
		pass
	var msg: String = ev.try_loot(_player.global_position)
	if msg == "":
		# может рядом аирдроп
		for e in ev.active:
			if String(e["kind"]) != "airdrop":
				continue
			var drop = e.get("node")
			if drop != null and is_instance_valid(drop) and drop.has_method("is_ready") and drop.is_ready():
				if drop.crate_position().distance_to(_player.global_position) < 6.0:
					msg = "Аирдроп вскрыт: " + drop.open()
					break
	toast(msg if msg != "" else "Рядом нечего собирать")
	refresh()


func _demolish() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain == null or _player == null or not terrain.has_method("demolish_near"):
		return
	var nm: String = terrain.demolish_near(_player.global_position)
	toast(("Разобрано: " + nm) if nm != "" else "Рядом нечего разбирать")
	_refresh_build_items()
	refresh()


func _upgrade() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain == null or _player == null or not terrain.has_method("upgrade_near"):
		return
	var res: String = terrain.upgrade_near(_player.global_position)
	if res == "":
		toast("Рядом нечего улучшать")
	elif res == "no_res":
		toast("Не хватает ресурсов для улучшения")
	else:
		toast("Улучшено: " + res)
	_refresh_build_items()
	refresh()


# ================= обновление =================

func _use_slot(i: int) -> void:
	if GameState.selected_slot == i:
		var msg: String = GameState.use_slot(i)
		if msg != "":
			toast(msg)
	else:
		GameState.selected_slot = i
	refresh()


func refresh() -> void:
	for i in range(_slots.size()):
		var b: Button = _slots[i]
		var key: String = String(GameState.hotbar[i]) if i < GameState.hotbar.size() else ""
		if key == "":
			b.text = "%d\n—" % (i + 1)
		else:
			var n: int = GameState.count(key)
			b.text = "%d %s\n%d" % [i + 1, GameState.item_name(key).substr(0, 9), n]
		var sel: bool = GameState.selected_slot == i
		var sb := Kit.panel(Color(0.34, 0.21, 0.08, 0.95) if sel else Color(0.11, 0.115, 0.13, 0.9), 8)
		if sel:
			sb.border_color = Kit.ACCENT
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_top = 2
			sb.border_width_bottom = 2
		b.add_theme_stylebox_override("normal", sb)


func _update_stats() -> void:
	_set_stat("hp", GameState.hp, GameState.max_hp)
	_set_stat("hunger", GameState.hunger, 100.0)
	_set_stat("thirst", GameState.thirst, 100.0)


func _set_stat(key: String, v: float, maxv: float) -> void:
	if not _stat.has(key):
		return
	var d: Dictionary = _stat[key]
	(d["bar"] as ProgressBar).max_value = maxv
	(d["bar"] as ProgressBar).value = v
	(d["label"] as Label).text = str(int(round(v)))


func _process(delta: float) -> void:
	_update_stats()
	if _compass:
		_compass.queue_redraw()
	if _compass_lbl and _player:
		var head: float = fmod(rad_to_deg(-_player.rotation.y) + 360.0, 360.0)
		_compass_lbl.text = "%d°" % int(head)
	# панель строительства следует за режимом
	if _build_panel and _build_panel.visible != GameState.build_mode:
		_build_panel.visible = GameState.build_mode
	# постройка, завершившая крафт, включает режим строительства
	if GameState.pending_build != "":
		var kind: String = GameState.pending_build
		GameState.pending_build = ""
		GameState.build_kind = kind
		GameState.build_mode = true
		if _build_panel:
			_build_panel.visible = true
			_refresh_build_items()
	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		refresh()
		if GameState.build_mode:
			_refresh_build_items()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_C:
			_go("res://scenes/Craft.tscn")
		elif k.keycode == KEY_B:
			_toggle_build()


func _on_joy(dir: Vector2) -> void:
	if _player:
		_player.set_meta("mob_dir", dir)


func _go(scene: String) -> void:
	if _player:
		GameState.last_pos = _player.global_position
		GameState.last_yaw = _player.rotation.y
	GameState.return_to_pos = true
	GameState.save_inventory()
	get_tree().change_scene_to_file(scene)


func _on_died() -> void:
	GameState.run_active = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func toast(msg: String) -> void:
	if _toast_l == null:
		return
	_toast_l.text = msg
	_toast_l.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_toast_l, "modulate:a", 0.0, 0.5)
