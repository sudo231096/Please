extends Control
## Карта мира: вид сверху на всю местность, позиция игрока, монументы, лужи.
## Можно двигать (перетаскивание) и приближать (колесо мыши / щипок).

const TERRAIN_SIZE := 1024.0
const MAP_N := 64  # разрешение карты (тайлов на сторону)
const HALF := TERRAIN_SIZE * 0.5

const MOUNTAINS := [
	[200.0, 200.0, 13.0, 60.0],
	[-280.0, -150.0, 16.0, 70.0],
	[120.0, -320.0, 11.0, 55.0],
	[-100.0, 300.0, 14.0, 65.0],
]

# монументы (совпадает с main.gd)
const MONUMENTS := [
	{"kind": "Склад", "pos": Vector3(-300.0, 0, -250.0)},
	{"kind": "Парковка", "pos": Vector3(320.0, 0, -180.0)},
	{"kind": "Завод", "pos": Vector3(-260.0, 0, 320.0)},
	{"kind": "АЭС", "pos": Vector3(310.0, 0, 290.0)},
]

var _puddles: Array = []
var _zoom := 1.0
var _offset := Vector2.ZERO
var _mouse := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# лужи (тот же сид, что и в main.gd)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in range(30):
		_puddles.append(Vector3(
			rng.randf_range(-HALF + 50.0, HALF - 50.0),
			0,
			rng.randf_range(-HALF + 50.0, HALF - 50.0)
		))
	_build_ui()
	queue_redraw()


func _ground_height(x: float, z: float) -> float:
	var h := 0.0
	h += 2.5 * sin(x * 0.006 + 1.3) * cos(z * 0.007 + 0.7)
	h += 1.5 * sin(x * 0.013 + 0.5) * sin(z * 0.011 + 2.1)
	for p in MOUNTAINS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var d2: float = dx * dx + dz * dz
		h += p[2] * exp(-d2 / (2.0 * p[3] * p[3]))
	return h


func _to_screen(wx: float, wz: float) -> Vector2:
	var s := (size.x * _zoom) / TERRAIN_SIZE
	return Vector2((wx + HALF) * s + _offset.x, (wz + HALF) * s + _offset.y)


func _draw() -> void:
	var s := (size.x * _zoom) / TERRAIN_SIZE
	var cell := s * (TERRAIN_SIZE / MAP_N)
	for ty in range(MAP_N):
		for tx in range(MAP_N):
			var wx := -HALF + (tx + 0.5) * (TERRAIN_SIZE / MAP_N)
			var wz := -HALF + (ty + 0.5) * (TERRAIN_SIZE / MAP_N)
			var h := _ground_height(wx, wz)
			var c: Color
			if h > 9.0:
				c = Color(0.9, 0.92, 0.95)
			elif h > 5.0:
				c = Color(0.4, 0.4, 0.42)
			elif h > 2.0:
				c = Color(0.22, 0.42, 0.16)
			else:
				c = Color(0.18, 0.34, 0.13)
			var sp := _to_screen(wx, wz)
			draw_rect(Rect2(sp.x - cell * 0.5, sp.y - cell * 0.5, cell + 1, cell + 1), c)

	# лужи (синие пятна)
	for p in _puddles:
		var sp := _to_screen(p.x, p.z)
		draw_circle(sp, 6.0 * _zoom, Color(0.15, 0.4, 0.6, 0.85))

	# монументы (метки)
	var font := ThemeDB.fallback_font
	for m in MONUMENTS:
		var mp: Vector3 = m["pos"]
		var sp := _to_screen(mp.x, mp.z)
		draw_circle(sp, 5.0, Color(1.0, 0.75, 0.2))
		draw_arc(sp, 8.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 1.5)
		draw_string(font, sp + Vector2(8, -8), m["kind"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.4))

	# маркер игрока
	var p := GameState.last_pos
	var mp := _to_screen(p.x, p.z)
	draw_circle(mp, 6.0, Color(1, 0.2, 0.2))
	draw_arc(mp, 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse = event.position
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_offset += event.relative
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(_mouse, 1.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(_mouse, 0.8)
	elif event is InputEventScreenDrag:
		_offset += event.relative
		queue_redraw()
	elif event is InputEventScreenTouch and event.pressed and event.double_tap:
		_zoom = 1.0
		_offset = Vector2.ZERO
		queue_redraw()


func _zoom_at(point: Vector2, factor: float) -> void:
	var s := (size.x * _zoom) / TERRAIN_SIZE
	var before := (point - _offset) / s  # мировые координаты под курсором
	_zoom = clampf(_zoom * factor, 0.4, 8.0)
	var s2 := (size.x * _zoom) / TERRAIN_SIZE
	_offset = point - before * s2
	queue_redraw()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "КАРТА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.3
	title.anchor_right = 0.7
	title.offset_top = 12
	title.offset_bottom = 52
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(0.95, 0.9, 0.7)
	add_child(title)

	var back := Button.new()
	back.text = "НАЗАД"
	back.focus_mode = Control.FOCUS_NONE
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = 20
	back.offset_top = -80
	back.offset_right = 180
	back.offset_bottom = -30
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	add_child(back)

	var legend := Label.new()
	legend.text = "● — ты   ■ — монумент   ● — лужа\nперетаскивай — двигать · колесо — масштаб"
	legend.anchor_left = 0.02
	legend.anchor_top = 0.02
	legend.add_theme_font_size_override("font_size", 15)
	legend.modulate = Color(1, 1, 1, 0.8)
	add_child(legend)
