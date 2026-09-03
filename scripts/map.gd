extends Control
## Карта мира: вид сверху на всю местность + позиция игрока.

const TERRAIN_SIZE := 1024.0
const MAP_N := 64  # разрешение карты (тайлов на сторону)

const MOUNTAINS := [
	[200.0, 200.0, 13.0, 60.0],
	[-280.0, -150.0, 16.0, 70.0],
	[120.0, -320.0, 11.0, 55.0],
	[-100.0, 300.0, 14.0, 65.0],
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	queue_redraw()


func _ground_height(x: float, z: float) -> float:
	var h := 0.0
	h += 1.8 * sin(x * 0.006 + 1.3) * cos(z * 0.007 + 0.7)
	h += 1.1 * sin(x * 0.013 + 0.5) * sin(z * 0.011 + 2.1)
	for p in MOUNTAINS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		var d2: float = dx * dx + dz * dz
		h += p[2] * exp(-d2 / (2.0 * p[3] * p[3]))
	return h


func _draw() -> void:
	var sz := size
	var cell := sz.x / float(MAP_N)
	# рисуем рельеф
	for ty in range(MAP_N):
		for tx in range(MAP_N):
			var wx := -TERRAIN_SIZE * 0.5 + (tx + 0.5) * (TERRAIN_SIZE / MAP_N)
			var wz := -TERRAIN_SIZE * 0.5 + (ty + 0.5) * (TERRAIN_SIZE / MAP_N)
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
			draw_rect(Rect2(tx * cell, ty * cell, cell + 1, cell + 1), c)
	# маркер игрока
	var p := GameState.last_pos
	var mx := (p.x + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * sz.x
	var my := (p.z + TERRAIN_SIZE * 0.5) / TERRAIN_SIZE * sz.y
	draw_circle(Vector2(mx, my), 6.0, Color(1, 0.2, 0.2))
	draw_arc(Vector2(mx, my), 9.0, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "КАРТА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.3
	title.anchor_right = 0.7
	title.offset_top = 16
	title.offset_bottom = 60
	title.add_theme_font_size_override("font_size", 36)
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
	legend.text = "● — ты\nзелёный — лес · серый — камни · белый — снег"
	legend.anchor_left = 0.02
	legend.anchor_top = 0.02
	legend.add_theme_font_size_override("font_size", 16)
	legend.modulate = Color(1, 1, 1, 0.8)
	add_child(legend)
