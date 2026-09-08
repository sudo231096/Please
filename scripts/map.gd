extends Control
## Карта мира в стиле Rust: квадратная сетка с координатами (A1…), биомы,
## дороги, реки, монументы со значками, позиция игрока, свои метки.
## Перетаскивание и масштабирование, метки сохраняются.

const Kit := preload("res://scripts/ui_kit.gd")

# ВАЖНО: значения синхронизированы с main.gd
const TERRAIN_SIZE := 1024.0
const HALF := TERRAIN_SIZE * 0.5
const ISLAND_R := 430.0
const WATER_LEVEL := -1.0
const MAP_N := 96              # разрешение растра карты
const GRID_CELLS := 12         # сетка секторов A1..L12

const MOUNTAINS := [
	[180.0, 180.0, 15.0, 60.0],
	[-240.0, -120.0, 18.0, 70.0],
	[100.0, -280.0, 13.0, 55.0],
	[-80.0, 260.0, 16.0, 65.0],
]

const MONUMENTS := [
	{"name": "Склад", "glyph": "🏭", "pos": Vector2(-260.0, -220.0)},
	{"name": "Парковка", "glyph": "🅿", "pos": Vector2(280.0, -150.0)},
	{"name": "Завод", "glyph": "⚙", "pos": Vector2(-230.0, 280.0)},
	{"name": "АЭС", "glyph": "☢", "pos": Vector2(260.0, 250.0)},
	{"name": "Шахта", "glyph": "⛏", "pos": Vector2(-40.0, -330.0)},
	{"name": "Ангар", "glyph": "✈", "pos": Vector2(340.0, 60.0)},
	{"name": "Заправка", "glyph": "⛽", "pos": Vector2(-330.0, 40.0)},
]

var _puddles: Array = []
var _zoom := 1.0
var _offset := Vector2.ZERO
var _dragging := false
var _drag_from := Vector2.ZERO
var _marker_mode := false
var _canvas: Control
var _hint: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in range(30):
		_puddles.append(Vector2(rng.randf_range(-HALF + 50.0, HALF - 50.0), rng.randf_range(-HALF + 50.0, HALF - 50.0)))
	_build_ui()


# ---------- рельеф (та же формула, что в main.gd) ----------

func _island_mask(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	return clampf(1.0 - smoothstep(ISLAND_R - 70.0, ISLAND_R + 15.0, d), 0.0, 1.0)


func _ground_height(x: float, z: float) -> float:
	var mask := _island_mask(x, z)
	var h := 0.0
	h += 4.0 * sin(x * 0.006 + 1.3) * cos(z * 0.007 + 0.7)
	h += 2.2 * sin(x * 0.013 + 0.5) * sin(z * 0.011 + 2.1)
	h += 1.0 * sin(x * 0.027 + 0.2) * cos(z * 0.023 + 1.6)
	h += 0.5 * sin(x * 0.051 + 3.0) * sin(z * 0.047 + 0.9)
	for p in MOUNTAINS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		h += p[2] * exp(-(dx * dx + dz * dz) / (2.0 * p[3] * p[3]))
	var land := (h + 7.0) * mask
	var sea := (WATER_LEVEL - 6.0) * (1.0 - mask)
	return land + sea


func _biome_color(x: float, z: float) -> Color:
	var h := _ground_height(x, z)
	if h < WATER_LEVEL - 2.5:
		return Color(0.09, 0.20, 0.35)        # глубина
	if h < WATER_LEVEL:
		return Color(0.16, 0.34, 0.50)        # мелководье
	if h < WATER_LEVEL + 1.2:
		return Color(0.72, 0.66, 0.45)        # пляж
	if h > 17.0:
		return Color(0.92, 0.94, 0.96)        # снег на вершинах
	if h > 12.0:
		return Color(0.45, 0.44, 0.42)        # скалы
	# лес/поле — по шуму
	var f := sin(x * 0.02 + 1.0) * cos(z * 0.018 - 0.5)
	if f > 0.15:
		return Color(0.18, 0.32, 0.16)        # лес
	return Color(0.35, 0.42, 0.22)            # поле


# ---------- преобразование координат ----------

func _view_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var pad := 90.0
	var side: float = minf(vs.x - pad * 2.0, vs.y - pad * 1.4)
	return Rect2(Vector2(vs.x * 0.5 - side * 0.5, vs.y * 0.5 - side * 0.5 + 10.0), Vector2(side, side))


func _to_screen(wx: float, wz: float) -> Vector2:
	var r := _view_rect()
	var u := (wx + HALF) / TERRAIN_SIZE
	var v := (wz + HALF) / TERRAIN_SIZE
	return r.position + Vector2(u * r.size.x, v * r.size.y) * _zoom + _offset


func _to_world(sp: Vector2) -> Vector2:
	var r := _view_rect()
	var local := (sp - _offset - r.position) / _zoom
	return Vector2(local.x / r.size.x * TERRAIN_SIZE - HALF, local.y / r.size.y * TERRAIN_SIZE - HALF)


func _sector_of(wx: float, wz: float) -> String:
	var cx: int = clampi(int((wx + HALF) / TERRAIN_SIZE * GRID_CELLS), 0, GRID_CELLS - 1)
	var cz: int = clampi(int((wz + HALF) / TERRAIN_SIZE * GRID_CELLS), 0, GRID_CELLS - 1)
	return "%s%d" % [char(65 + cx), cz + 1]


# ---------- отрисовка ----------

func _draw_map() -> void:
	var r := _view_rect()
	var step: float = r.size.x / float(MAP_N) * _zoom
	# биомы
	for iz in range(MAP_N):
		for ix in range(MAP_N):
			var wx: float = -HALF + (ix + 0.5) / MAP_N * TERRAIN_SIZE
			var wz: float = -HALF + (iz + 0.5) / MAP_N * TERRAIN_SIZE
			var p := _to_screen(wx - TERRAIN_SIZE / MAP_N * 0.5, wz - TERRAIN_SIZE / MAP_N * 0.5)
			_canvas.draw_rect(Rect2(p, Vector2(step + 1.0, step + 1.0)), _biome_color(wx, wz), true)

	# реки (мягкие линии от гор к морю)
	for m in MOUNTAINS:
		var from := Vector2(m[0], m[1])
		var dir := from.normalized()
		var pts: PackedVector2Array = []
		for i in range(22):
			var t := i / 21.0
			var w := from.lerp(dir * (ISLAND_R + 10.0), t)
			w += Vector2(sin(t * 6.0 + m[0]) * 16.0, cos(t * 5.0 + m[1]) * 16.0)
			pts.append(_to_screen(w.x, w.y))
		if pts.size() > 1:
			_canvas.draw_polyline(pts, Color(0.32, 0.55, 0.75, 0.85), maxf(2.0, 2.5 * _zoom))

	# дороги между монументами
	var road := Color(0.55, 0.5, 0.42, 0.9)
	for i in range(MONUMENTS.size()):
		var a: Vector2 = MONUMENTS[i]["pos"]
		var b: Vector2 = MONUMENTS[(i + 1) % MONUMENTS.size()]["pos"]
		_canvas.draw_line(_to_screen(a.x, a.y), _to_screen(b.x, b.y), road, maxf(2.0, 3.0 * _zoom))

	# озёра
	for p in _puddles:
		var pv: Vector2 = p
		_canvas.draw_circle(_to_screen(pv.x, pv.y), maxf(2.0, 5.0 * _zoom), Color(0.22, 0.45, 0.62, 0.9))

	# сетка секторов + подписи
	var grid_col := Color(0, 0, 0, 0.35)
	for i in range(GRID_CELLS + 1):
		var t: float = -HALF + TERRAIN_SIZE * i / float(GRID_CELLS)
		_canvas.draw_line(_to_screen(t, -HALF), _to_screen(t, HALF), grid_col, 1.0)
		_canvas.draw_line(_to_screen(-HALF, t), _to_screen(HALF, t), grid_col, 1.0)
	var font := ThemeDB.fallback_font
	for i in range(GRID_CELLS):
		var cx: float = -HALF + TERRAIN_SIZE * (i + 0.5) / GRID_CELLS
		_canvas.draw_string(font, _to_screen(cx, -HALF) + Vector2(-6, -6), char(65 + i),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.8, 0.9))
		_canvas.draw_string(font, _to_screen(-HALF, cx) + Vector2(-16, 5), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.85, 0.8, 0.9))

	# рамка острова
	_canvas.draw_arc(_to_screen(0, 0), ISLAND_R / TERRAIN_SIZE * r.size.x * _zoom, 0, TAU, 64,
		Color(0.9, 0.85, 0.6, 0.35), 2.0)

	# монументы
	for m in MONUMENTS:
		var mp: Vector2 = m["pos"]
		var sp := _to_screen(mp.x, mp.y)
		_canvas.draw_circle(sp, 13.0, Color(0.05, 0.05, 0.06, 0.85))
		_canvas.draw_arc(sp, 13.0, 0, TAU, 20, Kit.ACCENT, 2.0)
		_canvas.draw_string(font, sp + Vector2(-7, 6), String(m["glyph"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1))
		_canvas.draw_string(font, sp + Vector2(-24, 30), String(m["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.9, 0.75))

	# постройки игрока
	for st in GameState.structures:
		var p3: Vector3 = st["pos"]
		_canvas.draw_rect(Rect2(_to_screen(p3.x, p3.z) - Vector2(3, 3), Vector2(6, 6)),
			Color(0.55, 0.85, 1.0, 0.95), true)

	# метки игрока
	for mk in GameState.map_markers:
		var mv: Vector2 = Vector2(float(mk["x"]), float(mk["z"]))
		var msp := _to_screen(mv.x, mv.y)
		_canvas.draw_line(msp + Vector2(-8, -8), msp + Vector2(8, 8), Color(1, 0.85, 0.25), 3.0)
		_canvas.draw_line(msp + Vector2(8, -8), msp + Vector2(-8, 8), Color(1, 0.85, 0.25), 3.0)

	# игрок + направление взгляда
	var pp: Vector3 = GameState.last_pos
	var psp := _to_screen(pp.x, pp.z)
	_canvas.draw_circle(psp, 8.0, Color(0.2, 0.9, 0.35))
	_canvas.draw_arc(psp, 8.0, 0, TAU, 18, Color(1, 1, 1, 0.95), 2.0)
	var yaw: float = GameState.last_yaw
	_canvas.draw_line(psp, psp + Vector2(sin(yaw), -cos(yaw)) * 20.0, Color(0.2, 0.9, 0.35), 3.0)


# ---------- ввод ----------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _marker_mode:
					var w := _to_world(mb.position)
					GameState.add_marker(w.x, w.y)
					_marker_mode = false
					_hint.text = "Метка поставлена в секторе %s" % _sector_of(w.x, w.y)
					_canvas.queue_redraw()
					return
				_dragging = true
				_drag_from = mb.position
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_offset += (event as InputEventMouseMotion).relative
		_canvas.queue_redraw()
	elif event is InputEventScreenDrag:
		_offset += (event as InputEventScreenDrag).relative
		_canvas.queue_redraw()


func _zoom_at(point: Vector2, factor: float) -> void:
	var before := _zoom
	_zoom = clampf(_zoom * factor, 0.6, 5.0)
	var k := _zoom / before
	_offset = (_offset - point) * k + point
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE or k.keycode == KEY_M:
			_close()


# ---------- интерфейс ----------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.065)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# холст карты (рисуется в _draw через дочерний Control)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)

	# заголовок
	var head := Kit.make_panel(Kit.BG, 10)
	head.position = Vector2(16, 12)
	add_child(head)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	head.add_child(hrow)
	hrow.add_child(Kit.label("КАРТА", 22, Kit.ACCENT))
	var pp: Vector3 = GameState.last_pos
	hrow.add_child(Kit.label("Сектор %s" % _sector_of(pp.x, pp.z), 16, Kit.GOLD))

	# подсказка
	_hint = Kit.label("Перетаскивание — двигать, колесо — масштаб", 13, Kit.TXT_DIM)
	_hint.position = Vector2(16, 62)
	add_child(_hint)

	# правая панель кнопок
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -190
	col.offset_right = -16
	col.offset_top = 12
	add_child(col)

	var mk := Kit.button("ПОСТАВИТЬ МЕТКУ", 15, true, Vector2(174, 48))
	mk.pressed.connect(func() -> void:
		_marker_mode = true
		_hint.text = "Нажмите на карту, чтобы поставить метку"
	)
	col.add_child(mk)

	var clr := Kit.button("УБРАТЬ МЕТКИ", 14, false, Vector2(174, 44))
	clr.pressed.connect(func() -> void:
		GameState.map_markers.clear()
		GameState.save_inventory()
		_canvas.queue_redraw()
		_hint.text = "Метки удалены"
	)
	col.add_child(clr)

	var ctr := Kit.button("К ИГРОКУ", 14, false, Vector2(174, 44))
	ctr.pressed.connect(func() -> void:
		_zoom = 2.0
		var r := _view_rect()
		var p: Vector3 = GameState.last_pos
		var u := (p.x + HALF) / TERRAIN_SIZE
		var v := (p.z + HALF) / TERRAIN_SIZE
		_offset = r.position + r.size * 0.5 - (r.position + Vector2(u * r.size.x, v * r.size.y) * _zoom)
		_canvas.queue_redraw()
	)
	col.add_child(ctr)

	var zin := Kit.button("＋", 20, false, Vector2(174, 44))
	zin.pressed.connect(func() -> void: _zoom_at(get_viewport_rect().size * 0.5, 1.25))
	col.add_child(zin)

	var zout := Kit.button("－", 20, false, Vector2(174, 44))
	zout.pressed.connect(func() -> void: _zoom_at(get_viewport_rect().size * 0.5, 0.8))
	col.add_child(zout)

	var close := Kit.button("ЗАКРЫТЬ", 16, false, Vector2(174, 50))
	close.pressed.connect(_close)
	col.add_child(close)

	# легенда
	var lg := Kit.make_panel(Kit.BG, 10)
	lg.anchor_top = 1.0
	lg.anchor_bottom = 1.0
	lg.offset_left = 16
	lg.offset_top = -104
	lg.offset_bottom = -14
	add_child(lg)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 14)
	lg.add_child(lrow)
	for spec in [["Лес", Color(0.18, 0.32, 0.16)], ["Поле", Color(0.35, 0.42, 0.22)],
			["Скалы", Color(0.45, 0.44, 0.42)], ["Снег", Color(0.92, 0.94, 0.96)],
			["Пляж", Color(0.72, 0.66, 0.45)], ["Вода", Color(0.16, 0.34, 0.50)]]:
		var it := HBoxContainer.new()
		it.add_theme_constant_override("separation", 5)
		var sw := ColorRect.new()
		sw.color = Color(spec[1])
		sw.custom_minimum_size = Vector2(16, 16)
		it.add_child(sw)
		it.add_child(Kit.label(String(spec[0]), 12, Kit.TXT_DIM))
		lrow.add_child(it)


func _close() -> void:
	GameState.return_to_pos = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
