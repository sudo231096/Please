extends RefCounted
## Процедурные 3D-модели инструментов (FPS viewmodel) и брони.

func mat(color: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	return m


func metal(stone_tier: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D
	if stone_tier:
		m = mat(Color(0.55, 0.55, 0.58), 0.65)
	else:
		m = mat(Color(0.78, 0.80, 0.85), 0.35)
		m.metallic = 0.55
	return m


func wood(stone_tier: bool) -> StandardMaterial3D:
	if stone_tier:
		return mat(Color(0.34, 0.21, 0.12), 0.95)
	return mat(Color(0.52, 0.33, 0.16), 0.92)


func leather() -> StandardMaterial3D:
	return mat(Color(0.38, 0.24, 0.14), 0.9)


func bone() -> StandardMaterial3D:
	return mat(Color(0.88, 0.84, 0.74), 0.7)


func armor_mat(piece_id: String) -> StandardMaterial3D:
	if piece_id.begins_with("bone_"):
		return bone()
	if piece_id.begins_with("stone_"):
		return metal(true)
	return wood(false)


func box(parent: Node3D, size: Vector3, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func ball(parent: Node3D, r: float, material: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 8
	mi.mesh = s
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func prism(parent: Node3D, size: Vector3, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	mi.mesh = p
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Инструмент в FPS: локально +Z вперёд от камеры, +Y вверх, рукоять у начала.
func build_tool(parent: Node3D, tool_id: String) -> void:
	var stone_tier: bool = tool_id.begins_with("stone_")
	var base: String = tool_id.replace("stone_", "")
	var w: Material = wood(stone_tier)
	var m: Material = metal(stone_tier)
	var wrap: Material = leather()
	var dark: Material = mat(Color(0.12, 0.12, 0.14), 0.9)
	match base:
		"sword":
			_sword(parent, w, m, wrap)
		"pickaxe":
			_pickaxe(parent, w, m, wrap)
		"axe":
			_axe(parent, w, m, wrap)
		"rod":
			_rod(parent, w, dark, wrap)
		"bow":
			_bow(parent, w, wrap, dark, m)
		"crossbow":
			_crossbow(parent, w, m, wrap, dark)
		_:
			cyl(parent, 0.03, 0.035, 0.5, w, Vector3(0, 0, -0.2), Vector3(PI * 0.5, 0, 0))


func _sword(p: Node3D, w: Material, m: Material, wrap: Material) -> void:
	# Меч СТОЙМЯ: рукоять внизу у кулака, клинок вверх (+Y)
	# лёгкий наклон вперёд к центру экрана
	cyl(p, 0.028, 0.032, 0.16, w, Vector3(0, 0.06, 0.0))  # рукоять
	cyl(p, 0.034, 0.034, 0.05, wrap, Vector3(0, 0.06, 0.0))  # обмотка
	ball(p, 0.04, m, Vector3(0, -0.04, 0.0), Vector3(1.0, 0.75, 1.0))  # навершие
	box(p, Vector3(0.22, 0.04, 0.05), m, Vector3(0, 0.15, 0.0))  # гарда
	box(p, Vector3(0.055, 0.48, 0.02), m, Vector3(0, 0.42, 0.0))  # клинок вверх
	box(p, Vector3(0.018, 0.46, 0.024), mat(Color(0.9, 0.92, 0.95), 0.3), Vector3(0, 0.42, 0.0))
	prism(p, Vector3(0.055, 0.10, 0.02), m, Vector3(0, 0.70, 0.0))  # остриё вверх


func _pickaxe(p: Node3D, w: Material, m: Material, wrap: Material) -> void:
	cyl(p, 0.028, 0.034, 0.55, w, Vector3(0, 0, -0.10), Vector3(PI * 0.5, 0, 0))
	cyl(p, 0.04, 0.04, 0.09, wrap, Vector3(0, 0, 0.08), Vector3(PI * 0.5, 0, 0))
	box(p, Vector3(0.12, 0.10, 0.10), m, Vector3(0, 0, -0.38))
	box(p, Vector3(0.42, 0.06, 0.06), m, Vector3(0, 0, -0.38))
	prism(p, Vector3(0.07, 0.14, 0.05), m, Vector3(-0.24, 0, -0.38), Vector3(0, 0, PI * 0.5))
	prism(p, Vector3(0.07, 0.14, 0.05), m, Vector3(0.24, 0, -0.38), Vector3(0, 0, -PI * 0.5))


func _axe(p: Node3D, w: Material, m: Material, wrap: Material) -> void:
	cyl(p, 0.028, 0.036, 0.52, w, Vector3(0, 0, -0.08), Vector3(PI * 0.5, 0, 0))
	cyl(p, 0.042, 0.042, 0.10, wrap, Vector3(0, 0, 0.08), Vector3(PI * 0.5, 0, 0))
	box(p, Vector3(0.12, 0.12, 0.10), m, Vector3(0.02, 0, -0.34))
	box(p, Vector3(0.18, 0.20, 0.05), m, Vector3(0.16, 0, -0.34))
	prism(p, Vector3(0.16, 0.20, 0.04), m, Vector3(0.28, 0, -0.34), Vector3(0, 0, -PI * 0.5))


func _rod(p: Node3D, w: Material, dark: Material, wrap: Material) -> void:
	cyl(p, 0.02, 0.03, 0.35, w, Vector3(0, 0, 0.0), Vector3(PI * 0.5, 0, 0))
	cyl(p, 0.012, 0.02, 0.32, w, Vector3(0, 0, -0.30), Vector3(PI * 0.5, 0, 0))
	cyl(p, 0.006, 0.012, 0.28, w, Vector3(0, 0, -0.55), Vector3(PI * 0.5, 0, 0))
	cyl(p, 0.034, 0.034, 0.08, wrap, Vector3(0, 0, 0.12), Vector3(PI * 0.5, 0, 0))
	# леска + поплавок
	cyl(p, 0.004, 0.004, 0.40, mat(Color(0.85, 0.85, 0.9), 0.4), Vector3(0, -0.12, -0.55), Vector3(0.9, 0, 0))
	ball(p, 0.035, mat(Color(0.9, 0.15, 0.12)), Vector3(0, -0.30, -0.55), Vector3(0.7, 1.3, 0.7))
	ball(p, 0.02, mat(Color(0.95, 0.9, 0.2)), Vector3(0, -0.24, -0.55))


func _bow(p: Node3D, w: Material, wrap: Material, dark: Material, m: Material) -> void:
	box(p, Vector3(0.05, 0.14, 0.06), wrap, Vector3(0, 0, 0.0))
	# плечи
	cyl(p, 0.016, 0.02, 0.36, w, Vector3(0.04, 0.16, -0.04), Vector3(0, 0, 0.5))
	cyl(p, 0.016, 0.02, 0.36, w, Vector3(-0.04, 0.16, -0.04), Vector3(0, 0, -0.5))
	cyl(p, 0.016, 0.02, 0.36, w, Vector3(0.04, -0.16, -0.04), Vector3(0, 0, -0.5))
	cyl(p, 0.016, 0.02, 0.36, w, Vector3(-0.04, -0.16, -0.04), Vector3(0, 0, 0.5))
	# тетива
	cyl(p, 0.005, 0.005, 0.55, dark, Vector3(0.08, 0, 0.04))
	cyl(p, 0.005, 0.005, 0.55, dark, Vector3(-0.08, 0, 0.04))
	# стрела
	cyl(p, 0.01, 0.01, 0.45, w, Vector3(0, 0, -0.12), Vector3(PI * 0.5, 0, 0))
	prism(p, Vector3(0.04, 0.06, 0.02), m, Vector3(0, 0, -0.36), Vector3(PI * 0.5, 0, 0))


func _crossbow(p: Node3D, w: Material, m: Material, wrap: Material, dark: Material) -> void:
	box(p, Vector3(0.08, 0.10, 0.48), w, Vector3(0, 0.02, -0.08))
	box(p, Vector3(0.07, 0.09, 0.16), wrap, Vector3(0, 0.0, 0.16))
	box(p, Vector3(0.04, 0.03, 0.34), dark, Vector3(0, 0.08, -0.10))
	box(p, Vector3(0.52, 0.05, 0.06), w, Vector3(0, 0.08, -0.28))
	cyl(p, 0.005, 0.005, 0.50, dark, Vector3(0, 0.10, -0.20), Vector3(0, 0, PI * 0.5))
	box(p, Vector3(0.05, 0.06, 0.07), m, Vector3(0, -0.04, 0.0))
	cyl(p, 0.009, 0.009, 0.32, w, Vector3(0, 0.09, -0.10), Vector3(PI * 0.5, 0, 0))
	prism(p, Vector3(0.03, 0.05, 0.02), m, Vector3(0, 0.09, -0.28), Vector3(PI * 0.5, 0, 0))


## Броня: координаты под тело игрока (ноги ~0, голова ~1.6).
## Для FPS-накладок head/chest — отдельные локальные сборки.
func build_armor_piece(parent: Node3D, piece_id: String, fps_attach: bool = false) -> void:
	var material: Material = armor_mat(piece_id)
	var trim: Material = mat(Color(0.18, 0.14, 0.12), 0.9)
	if piece_id.begins_with("bone_"):
		trim = mat(Color(0.6, 0.55, 0.45), 0.8)
	elif piece_id.begins_with("stone_"):
		trim = mat(Color(0.32, 0.32, 0.35), 0.7)
	if piece_id.ends_with("helm"):
		if fps_attach:
			_helm_fps(parent, material, trim, piece_id)
		else:
			_helm(parent, material, trim, piece_id)
	elif piece_id.ends_with("chest"):
		if fps_attach:
			_chest_fps(parent, material, trim, piece_id)
		else:
			_chest(parent, material, trim, piece_id)
	elif piece_id.ends_with("legs"):
		_legs(parent, material, trim)
	elif piece_id.ends_with("boots"):
		_boots(parent, material, trim)


func _helm(p: Node3D, material: Material, trim: Material, id: String) -> void:
	var y: float = 1.62
	ball(p, 0.24, material, Vector3(0, y + 0.08, -0.02), Vector3(1.1, 0.85, 1.05))
	box(p, Vector3(0.38, 0.22, 0.12), material, Vector3(0, y + 0.02, -0.16))
	cyl(p, 0.26, 0.26, 0.05, trim, Vector3(0, y - 0.04, 0))
	box(p, Vector3(0.32, 0.045, 0.14), material, Vector3(0, y + 0.12, 0.14))
	if id.begins_with("stone_") or id.begins_with("bone_"):
		box(p, Vector3(0.05, 0.14, 0.24), trim, Vector3(0, y + 0.22, -0.02))
	box(p, Vector3(0.08, 0.16, 0.14), material, Vector3(-0.22, y, 0.02))
	box(p, Vector3(0.08, 0.16, 0.14), material, Vector3(0.22, y, 0.02))


func _helm_fps(p: Node3D, material: Material, trim: Material, id: String) -> void:
	# Локально у камеры: обод и края в поле зрения
	# верх
	box(p, Vector3(0.55, 0.08, 0.45), material, Vector3(0, 0.28, -0.05))
	# бока
	box(p, Vector3(0.08, 0.28, 0.40), material, Vector3(-0.30, 0.10, -0.02))
	box(p, Vector3(0.08, 0.28, 0.40), material, Vector3(0.30, 0.10, -0.02))
	# низ-зад
	box(p, Vector3(0.50, 0.08, 0.20), material, Vector3(0, -0.12, -0.18))
	# козырёк
	box(p, Vector3(0.48, 0.04, 0.16), trim, Vector3(0, 0.20, 0.18))
	if id.begins_with("stone_") or id.begins_with("bone_"):
		box(p, Vector3(0.06, 0.12, 0.30), trim, Vector3(0, 0.34, -0.05))


func _chest(p: Node3D, material: Material, trim: Material, id: String) -> void:
	var y: float = 1.15
	box(p, Vector3(0.58, 0.58, 0.34), material, Vector3(0, y, 0.02))
	ball(p, 0.15, material, Vector3(-0.34, y + 0.18, 0), Vector3(1.1, 0.8, 1.0))
	ball(p, 0.15, material, Vector3(0.34, y + 0.18, 0), Vector3(1.1, 0.8, 1.0))
	cyl(p, 0.15, 0.17, 0.08, trim, Vector3(0, y + 0.30, 0.02))
	box(p, Vector3(0.52, 0.06, 0.36), trim, Vector3(0, y + 0.08, 0.02))
	box(p, Vector3(0.52, 0.06, 0.36), trim, Vector3(0, y - 0.12, 0.02))
	if id.begins_with("bone_"):
		for i in range(3):
			box(p, Vector3(0.08, 0.36, 0.04), trim, Vector3(-0.16 + float(i) * 0.16, y, 0.20))
	cyl(p, 0.10, 0.12, 0.24, material, Vector3(-0.38, y - 0.06, 0), Vector3(0, 0, 0.45))
	cyl(p, 0.10, 0.12, 0.24, material, Vector3(0.38, y - 0.06, 0), Vector3(0, 0, -0.45))


func _chest_fps(p: Node3D, material: Material, trim: Material, id: String) -> void:
	# Внизу экрана FPS — нагрудник
	box(p, Vector3(0.9, 0.45, 0.25), material, Vector3(0, -0.55, -0.35))
	box(p, Vector3(0.85, 0.06, 0.27), trim, Vector3(0, -0.40, -0.35))
	box(p, Vector3(0.85, 0.06, 0.27), trim, Vector3(0, -0.65, -0.35))
	ball(p, 0.16, material, Vector3(-0.42, -0.35, -0.30), Vector3(1.2, 0.8, 1.0))
	ball(p, 0.16, material, Vector3(0.42, -0.35, -0.30), Vector3(1.2, 0.8, 1.0))
	if id.begins_with("bone_"):
		for i in range(3):
			box(p, Vector3(0.08, 0.30, 0.04), trim, Vector3(-0.2 + float(i) * 0.2, -0.55, -0.22))


func _legs(p: Node3D, material: Material, trim: Material) -> void:
	var y: float = 0.55
	box(p, Vector3(0.50, 0.24, 0.30), material, Vector3(0, y + 0.25, 0))
	box(p, Vector3(0.52, 0.05, 0.32), trim, Vector3(0, y + 0.35, 0))
	cyl(p, 0.11, 0.13, 0.48, material, Vector3(-0.13, y - 0.05, 0))
	cyl(p, 0.11, 0.13, 0.48, material, Vector3(0.13, y - 0.05, 0))
	ball(p, 0.10, trim, Vector3(-0.13, y - 0.12, 0.09), Vector3(1.0, 0.8, 0.7))
	ball(p, 0.10, trim, Vector3(0.13, y - 0.12, 0.09), Vector3(1.0, 0.8, 0.7))


func _boots(p: Node3D, material: Material, trim: Material) -> void:
	for si in range(2):
		var s: float = -1.0 if si == 0 else 1.0
		var x: float = s * 0.13
		cyl(p, 0.095, 0.105, 0.24, material, Vector3(x, 0.20, 0.02))
		box(p, Vector3(0.15, 0.11, 0.30), material, Vector3(x, 0.07, 0.07))
		ball(p, 0.075, material, Vector3(x, 0.07, 0.20), Vector3(1.0, 0.7, 1.15))
		box(p, Vector3(0.16, 0.04, 0.32), trim, Vector3(x, 0.02, 0.06))
