extends Control
## Клановое меню: создание, участники, приглашения, роли, союзники/враги, чат.

const Kit := preload("res://scripts/ui_kit.gd")

var _body: VBoxContainer
var _msg: Label
var _chat_box: VBoxContainer
var _chat_input: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameState.load_clan()
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.065, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22
	root.offset_right = -22
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var t := Kit.label("КЛАН", 26, Kit.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := Kit.button("✕", 18, false, Vector2(52, 46))
	x.pressed.connect(_close)
	head.add_child(x)

	_msg = Kit.label("", 14, Kit.GOLD)
	root.add_child(_msg)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_refresh()


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	if GameState.in_clan():
		_build_clan_view()
	else:
		_build_no_clan_view()


# ---------- нет клана ----------

func _build_no_clan_view() -> void:
	var p := Kit.make_panel(Kit.BG, 12)
	_body.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.label("СОЗДАТЬ КЛАН", 20, Kit.ACCENT))

	var name_in := LineEdit.new()
	name_in.placeholder_text = "Название клана"
	name_in.max_length = 20
	name_in.custom_minimum_size = Vector2(0, 46)
	name_in.add_theme_font_size_override("font_size", 17)
	v.add_child(name_in)

	var tag_in := LineEdit.new()
	tag_in.placeholder_text = "Тег (2–5 символов)"
	tag_in.max_length = 5
	tag_in.custom_minimum_size = Vector2(0, 46)
	tag_in.add_theme_font_size_override("font_size", 17)
	v.add_child(tag_in)

	var mk := Kit.button("СОЗДАТЬ", 17, true, Vector2(220, 52))
	mk.pressed.connect(func() -> void:
		var err: String = GameState.create_clan(name_in.text, tag_in.text)
		_msg.text = err if err != "" else "Клан создан!"
		_refresh()
	)
	v.add_child(mk)

	# входящие приглашения
	var ip := Kit.make_panel(Kit.BG, 12)
	_body.add_child(ip)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	ip.add_child(iv)
	iv.add_child(Kit.label("ПРИГЛАШЕНИЯ", 18, Kit.ACCENT))
	if GameState.clan_invites.is_empty():
		iv.add_child(Kit.label("Пока нет приглашений.", 14, Kit.TXT_DIM))
	else:
		for i in range(GameState.clan_invites.size()):
			var inv: Dictionary = GameState.clan_invites[i]
			var row := Kit.make_panel(Kit.BG_SOFT, 8)
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 10)
			row.add_child(h)
			h.add_child(Kit.label("[%s] %s — от %s" % [String(inv["tag"]), String(inv["name"]), String(inv["from"])], 15))
			var sp := Control.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(sp)
			var idx := i
			var acc := Kit.button("ПРИНЯТЬ", 13, true, Vector2(110, 42))
			acc.pressed.connect(func() -> void:
				var e: String = GameState.accept_invite(idx)
				_msg.text = e if e != "" else "Вы вступили в клан"
				_refresh()
			)
			h.add_child(acc)
			var dec := Kit.button("ОТКЛОНИТЬ", 13, false, Vector2(120, 42))
			dec.pressed.connect(func() -> void:
				GameState.decline_invite(idx)
				_refresh()
			)
			h.add_child(dec)
			iv.add_child(row)


# ---------- клан есть ----------

func _build_clan_view() -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(top)

	# левая колонка: инфо + участники
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)

	var info := Kit.make_panel(Kit.BG, 12)
	left.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	info.add_child(iv)
	var title := Kit.label("[%s] %s" % [GameState.clan_tag(), String(GameState.clan["name"])], 22, GameState.clan_color())
	iv.add_child(title)
	iv.add_child(Kit.label("Лидер: %s" % String(GameState.clan["leader"]), 15, Kit.TXT_DIM))
	iv.add_child(Kit.label("Участников: %d / 12" % GameState.clan_members().size(), 14, Kit.TXT_DIM))
	iv.add_child(Kit.label("Свои не получают урон друг от друга.", 13, Kit.OK))

	# участники
	var mp := Kit.make_panel(Kit.BG, 12)
	mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(mp)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 5)
	mp.add_child(mv)
	mv.add_child(Kit.label("УЧАСТНИКИ", 17, Kit.ACCENT))
	for m in GameState.clan_members():
		var nm: String = String(m["name"])
		var row := Kit.make_panel(Kit.BG_SOFT, 8)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		h.add_child(Kit.label(nm, 16, Kit.GOLD if nm == GameState.player_name else Kit.TXT))
		h.add_child(Kit.label(String(m["role"]), 13, Kit.TXT_DIM))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		if GameState.is_clan_leader() and nm != GameState.player_name:
			var pr := Kit.button("★", 14, false, Vector2(44, 40))
			pr.tooltip_text = "Передать лидерство"
			pr.pressed.connect(func() -> void:
				_msg.text = GameState.transfer_leadership(nm)
				if _msg.text == "": _msg.text = "Лидерство передано " + nm
				_refresh()
			)
			h.add_child(pr)
			var kk := Kit.button("✕", 14, false, Vector2(44, 40))
			kk.tooltip_text = "Исключить"
			kk.pressed.connect(func() -> void:
				_msg.text = GameState.kick_member(nm)
				if _msg.text == "": _msg.text = nm + " исключён"
				_refresh()
			)
			h.add_child(kk)
		mv.add_child(row)

	# приглашение
	if GameState.is_clan_leader():
		var inv_row := HBoxContainer.new()
		inv_row.add_theme_constant_override("separation", 6)
		mv.add_child(inv_row)
		var inp := LineEdit.new()
		inp.placeholder_text = "Ник игрока"
		inp.custom_minimum_size = Vector2(0, 44)
		inp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inv_row.add_child(inp)
		var ib := Kit.button("ПРИГЛАСИТЬ", 14, true, Vector2(140, 44))
		ib.pressed.connect(func() -> void:
			var target: String = inp.text.strip_edges()
			var err: String = GameState.invite_to_clan(target)
			if err != "":
				_msg.text = err
				return
			# в сети приглашение уходит игроку; локально показываем, что отправлено
			if Net.is_online():
				_msg.text = "Приглашение отправлено: " + target
			else:
				_msg.text = "Приглашение отправлено. В одиночной игре принять его некому."
			inp.text = ""
		)
		inv_row.add_child(ib)

	# правая колонка: чат + отношения
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(340, 0)
	top.add_child(right)

	var cp := Kit.make_panel(Kit.BG, 12)
	cp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	cp.add_child(cv)
	cv.add_child(Kit.label("КЛАНОВЫЙ ЧАТ", 17, Kit.ACCENT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(sc)
	_chat_box = VBoxContainer.new()
	_chat_box.add_theme_constant_override("separation", 3)
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_chat_box)
	_refresh_chat()

	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 5)
	cv.add_child(crow)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Сообщение…"
	_chat_input.custom_minimum_size = Vector2(0, 42)
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(_chat_input)
	var send := Kit.button("→", 16, true, Vector2(52, 42))
	send.pressed.connect(_send_chat)
	crow.add_child(send)
	_chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())

	# отношения
	var rp := Kit.make_panel(Kit.BG, 12)
	right.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 5)
	rp.add_child(rv)
	rv.add_child(Kit.label("ОТНОШЕНИЯ", 16, Kit.ACCENT))
	var allies: Array = GameState.clan.get("allies", [])
	var enemies: Array = GameState.clan.get("enemies", [])
	rv.add_child(Kit.label("Союзники: %s" % ("нет" if allies.is_empty() else ", ".join(allies)), 13, Kit.OK))
	rv.add_child(Kit.label("Враги: %s" % ("нет" if enemies.is_empty() else ", ".join(enemies)), 13, Kit.BAD))
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 5)
	rv.add_child(rrow)
	var tin := LineEdit.new()
	tin.placeholder_text = "Тег клана"
	tin.max_length = 5
	tin.custom_minimum_size = Vector2(0, 42)
	tin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(tin)
	var ally := Kit.button("СОЮЗ", 13, false, Vector2(84, 42))
	ally.pressed.connect(func() -> void:
		GameState.set_relation(tin.text, "ally"); tin.text = ""; _refresh())
	rrow.add_child(ally)
	var foe := Kit.button("ВРАГ", 13, false, Vector2(84, 42))
	foe.pressed.connect(func() -> void:
		GameState.set_relation(tin.text, "enemy"); tin.text = ""; _refresh())
	rrow.add_child(foe)

	# выход из клана
	var leave := Kit.button("ПОКИНУТЬ КЛАН" if not GameState.is_clan_leader() else "РАСПУСТИТЬ КЛАН", 15, false, Vector2(0, 48))
	leave.add_theme_color_override("font_color", Kit.BAD)
	leave.pressed.connect(func() -> void:
		var err: String = GameState.leave_clan()
		_msg.text = err if err != "" else "Вы покинули клан"
		_refresh()
	)
	_body.add_child(leave)


func _refresh_chat() -> void:
	if _chat_box == null:
		return
	for c in _chat_box.get_children():
		c.queue_free()
	if GameState.clan_chat.is_empty():
		_chat_box.add_child(Kit.label("Сообщений пока нет.", 13, Kit.TXT_DIM))
		return
	for m in GameState.clan_chat:
		var l := Kit.label("%s: %s" % [String(m["who"]), String(m["text"])], 14, Kit.TXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		_chat_box.add_child(l)


func _send_chat() -> void:
	if _chat_input == null:
		return
	GameState.clan_say(_chat_input.text)
	_chat_input.text = ""
	_refresh_chat()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		_close()


func _close() -> void:
	GameState.save_clan()
	GameState.return_to_pos = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
