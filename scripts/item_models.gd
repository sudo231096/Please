extends RefCounted
## Процедурные 3D-модели инструментов и брони (low-poly, цельные).

static func flat(color: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func metal_mat(stone_tier: bool) -> StandardMaterial3D:
	if stone_tier:
		return flat(Color(0.48, 0.48, 0.52), 0.7)
	return flat(Color(0.72, 0.74, 0.78), 0.45)


static func wood_mat(stone_tier: bool) -> StandardMaterial3D:
	if stone_tier:
		return flat(Color(0.32, 0.20, 0.11), 0.95)
	return flat(Color(0.48, 0.30, 0.15), 0.92)


static func leather_mat() -> StandardMaterial3D:
	return flat(Color(0.35, 0.22, 0.12), 0.9)


static func bone_mat() -> StandardMaterial3D:
	return flat(Color(0.86, 0.82, 0.72), 0.75)


static func armor_mat(piece_id: String) -> StandardMaterial3D:
	if piece_id.begins_with("bone_"):
		return bone_mat()
	if piece_id.begins_with("stone_"):
		return metal_mat(true)
	return wood_mat(false)


static func add_box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func add_cyl(parent: Node3D, r_top: float, r_bot: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, segs := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.material = mat
	mi.mesh = c
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func add_sphere(parent: Node3D, r: float, mat: Material, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 8
	s.material = mat
	mi.mesh = s
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func add_prism(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	p.material = mat
	mi.mesh = p
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## ---- Инструменты (viewmodel, ось Y вверх по рукояти) ----

static func build_tool(parent: Node3D, tool_id: String) -> void:
	var stone_tier: bool = tool_id.begins_with("stone_")
	var base: String = tool_id.replace("stone_", "")
	var wood := wood_mat(stone_tier)
	var metal := metal_mat(stone_tier)
	var wrap := leather_mat()
	var dark := flat(Color(0.12, 0.12, 0.14), 0.9)
	match base:
		"sword":
			_tool_sword(parent, wood, metal, wrap)
		"pickaxe":
			_tool_pickaxe(parent, wood, metal, wrap)
		"axe":
			_tool_axe(parent, wood, metal, wrap)
		"rod":
			_tool_rod(parent, wood, dark, wrap)
		"bow":
			_tool_bow(parent, wood, wrap, dark)
		"crossbow":
			_tool_crossbow(parent, wood, metal, wrap, dark)
		_:
			add_cyl(parent, 0.025, 0.03, 0.4, wood, Vector3(0, 0.15, 0))


static func _tool_sword(p: Node3D, wood: Material, metal: Material, wrap: Material) -> void:
	# рукоять
	add_cyl(p, 0.028, 0.032, 0.16, wood, Vector3(0, 0.06, 0))
	add_cyl(p, 0.034, 0.034, 0.05, wrap, Vector3(0, 0.06, 0))  # обмотка
	# навершие
	add_sphere(p, 0.04, metal, Vector3(0, -0.03, 0), Vector3(1.0, 0.7, 1.0))
	# гарда
	add_box(p, Vector3(0.22, 0.035, 0.06), metal, Vector3(0, 0.15, 0))
	add_cyl(p, 0.02, 0.02, 0.04, metal, Vector3(-0.11, 0.15, 0), Vector3(0, 0, PI * 0.5))
	add_cyl(p, 0.02, 0.02, 0.04, metal, Vector3(0.11, 0.15, 0), Vector3(0, 0, PI * 0.5))
	# клинок
	add_box(p, Vector3(0.055, 0.42, 0.018), metal, Vector3(0, 0.38, 0))
	add_box(p, Vector3(0.02, 0.40, 0.022), flat(Color(0.85, 0.88, 0.92), 0.35), Vector3(0, 0.38, 0))  # дола
	# остриё
	add_prism(p, Vector3(0.055, 0.10, 0.018), metal, Vector3(0, 0.64, 0))


static func _tool_pickaxe(p: Node3D, wood: Material, metal: Material, wrap: Material) -> void:
	add_cyl(p, 0.025, 0.032, 0.52, wood, Vector3(0, 0.22, 0))
	add_cyl(p, 0.036, 0.036, 0.08, wrap, Vector3(0, 0.08, 0))
	# головка
	add_box(p, Vector3(0.10, 0.08, 0.08), metal, Vector3(0, 0.48, 0))
	# левый/правый шип
	for si2 in range(2):
		var s2: float = -1.0 if si2 == 0 else 1.0
		add_box(p, Vector3(0.16, 0.05, 0.05), metal, Vector3(s2 * 0.12, 0.48, 0), Vector3(0, 0, s2 * 0.15))
		add_prism(p, Vector3(0.06, 0.12, 0.05), metal, Vector3(s2 * 0.24, 0.48, 0), Vector3(0, 0, s2 * 1.2))


static func _tool_axe(p: Node3D, wood: Material, metal: Material, wrap: Material) -> void:
	add_cyl(p, 0.026, 0.034, 0.50, wood, Vector3(0, 0.20, 0))
	add_cyl(p, 0.038, 0.038, 0.09, wrap, Vector3(0, 0.10, 0))
	# обух
	add_box(p, Vector3(0.10, 0.10, 0.08), metal, Vector3(0.02, 0.46, 0))
	# лезвие топора (веер)
	add_box(p, Vector3(0.14, 0.16, 0.04), metal, Vector3(0.14, 0.46, 0))
	add_prism(p, Vector3(0.14, 0.18, 0.035), metal, Vector3(0.24, 0.46, 0), Vector3(0, 0, -PI * 0.5))
	# верхний/нижний скос
	add_box(p, Vector3(0.10, 0.04, 0.035), metal, Vector3(0.16, 0.55, 0), Vector3(0, 0, -0.4))
	add_box(p, Vector3(0.10, 0.04, 0.035), metal, Vector3(0.16, 0.37, 0), Vector3(0, 0, 0.4))


static func _tool_rod(p: Node3D, wood: Material, dark: Material, wrap: Material) -> void:
	# удочка: сегменты, утончение, леска, поплавок
	add_cyl(p, 0.018, 0.028, 0.35, wood, Vector3(0, 0.12, 0))
	add_cyl(p, 0.012, 0.018, 0.30, wood, Vector3(0, 0.42, 0))
	add_cyl(p, 0.006, 0.012, 0.22, wood, Vector3(0, 0.66, 0))
	add_cyl(p, 0.032, 0.032, 0.07, wrap, Vector3(0, 0.05, 0))
	# кольца
	for y in [0.25, 0.40, 0.55, 0.70]:
		add_cyl(p, 0.02, 0.02, 0.012, dark, Vector3(0, y, 0))
	# кончик + леска вперёд
	add_cyl(p, 0.004, 0.006, 0.12, dark, Vector3(0, 0.82, 0))
	add_cyl(p, 0.003, 0.003, 0.35, flat(Color(0.9, 0.9, 0.95), 0.5), Vector3(0.0, 0.78, 0.16), Vector3(PI * 0.5, 0, 0))
	# поплавок
	add_sphere(p, 0.03, flat(Color(0.9, 0.2, 0.15)), Vector3(0.0, 0.78, 0.34), Vector3(0.7, 1.2, 0.7))
	add_sphere(p, 0.018, flat(Color(0.95, 0.95, 0.2)), Vector3(0.0, 0.82, 0.34))


static func _tool_bow(p: Node3D, wood: Material, wrap: Material, dark: Material) -> void:
	# рукоять
	add_box(p, Vector3(0.04, 0.14, 0.05), wrap, Vector3(0, 0.12, 0))
	# плечи — дуга из сегментов
	for i in range(5):
		var t: float = (float(i) - 2.0) / 2.0  # -1..1
		var y: float = 0.12 + float(t) * 0.32
		var x: float = absf(float(t)) * 0.12
		var z: float = -0.02 - absf(float(t)) * 0.02
		add_cyl(p, 0.014, 0.018, 0.12, wood, Vector3(x * 0.15, y, z), Vector3(0, 0, t * 0.55))
		add_cyl(p, 0.014, 0.018, 0.12, wood, Vector3(-x * 0.15, y, z), Vector3(0, 0, -t * 0.55))
	# концы
	add_sphere(p, 0.02, wood, Vector3(0.08, 0.44, -0.04))
	add_sphere(p, 0.02, wood, Vector3(-0.08, 0.44, -0.04))
	add_sphere(p, 0.02, wood, Vector3(0.08, -0.18, -0.04))
	add_sphere(p, 0.02, wood, Vector3(-0.08, -0.18, -0.04))
	# тетива
	add_cyl(p, 0.004, 0.004, 0.58, dark, Vector3(0.07, 0.13, 0.02), Vector3(0, 0, 0.05))
	add_cyl(p, 0.004, 0.004, 0.58, dark, Vector3(-0.07, 0.13, 0.02), Vector3(0, 0, -0.05))
	# стрела на луке
	add_cyl(p, 0.008, 0.008, 0.40, wood, Vector3(0, 0.14, 0.04), Vector3(PI * 0.5, 0, 0))
	add_prism(p, Vector3(0.03, 0.05, 0.02), metal_mat(false), Vector3(0, 0.14, -0.18), Vector3(PI * 0.5, 0, 0))


static func _tool_crossbow(p: Node3D, wood: Material, metal: Material, wrap: Material, dark: Material) -> void:
	# ложа
	add_box(p, Vector3(0.07, 0.10, 0.42), wood, Vector3(0, 0.08, 0.02))
	add_box(p, Vector3(0.06, 0.08, 0.16), wrap, Vector3(0, 0.05, 0.14))  # приклад
	# жёлоб
	add_box(p, Vector3(0.03, 0.02, 0.30), dark, Vector3(0, 0.14, -0.02))
	# дуга
	add_box(p, Vector3(0.48, 0.04, 0.05), wood, Vector3(0, 0.14, -0.16))
	add_cyl(p, 0.02, 0.02, 0.08, wood, Vector3(-0.24, 0.14, -0.16), Vector3(0, 0, PI * 0.5))
	add_cyl(p, 0.02, 0.02, 0.08, wood, Vector3(0.24, 0.14, -0.16), Vector3(0, 0, PI * 0.5))
	# тетива
	add_cyl(p, 0.004, 0.004, 0.46, dark, Vector3(0, 0.16, -0.10), Vector3(0, 0, PI * 0.5))
	# спусковая скоба / механизм
	add_box(p, Vector3(0.04, 0.05, 0.06), metal, Vector3(0, 0.02, 0.0))
	# болт
	add_cyl(p, 0.007, 0.007, 0.28, wood, Vector3(0, 0.15, -0.02), Vector3(PI * 0.5, 0, 0))
	add_prism(p, Vector3(0.025, 0.04, 0.02), metal, Vector3(0, 0.15, -0.18), Vector3(PI * 0.5, 0, 0))


## ---- Броня (на теле игрока, Y вверх, ноги у 0) ----

static func build_armor_piece(parent: Node3D, piece_id: String) -> void:
	var mat: Material = armor_mat(piece_id)
	var trim: Material = flat(Color(0.15, 0.12, 0.10), 0.9)
	if piece_id.begins_with("bone_"):
		trim = flat(Color(0.55, 0.5, 0.4), 0.8)
	elif piece_id.begins_with("stone_"):
		trim = flat(Color(0.3, 0.3, 0.32), 0.7)
	var slot: String = ""
	if piece_id.ends_with("helm"):
		slot = "head"
	elif piece_id.ends_with("chest"):
		slot = "chest"
	elif piece_id.ends_with("legs"):
		slot = "legs"
	elif piece_id.ends_with("boots"):
		slot = "feet"
	match slot:
		"head":
			_armor_helm(parent, mat, trim, piece_id)
		"chest":
			_armor_chest(parent, mat, trim, piece_id)
		"legs":
			_armor_legs(parent, mat, trim)
		"feet":
			_armor_boots(parent, mat, trim)


static func _armor_helm(p: Node3D, mat: Material, trim: Material, id: String) -> void:
	# камера на y=1.6 — открытый шлем (лицо свободно для FPS)
	var y: float = 1.62
	# купол
	add_sphere(p, 0.23, mat, Vector3(0, y + 0.08, -0.02), Vector3(1.1, 0.85, 1.05))
	# задняя пластина
	add_box(p, Vector3(0.36, 0.22, 0.10), mat, Vector3(0, y + 0.02, -0.16))
	# обод
	add_cyl(p, 0.25, 0.25, 0.05, trim, Vector3(0, y - 0.04, 0))
	# козырёк сверху спереди (не закрывает обзор)
	add_box(p, Vector3(0.30, 0.04, 0.14), mat, Vector3(0, y + 0.12, 0.14))
	if id.begins_with("stone_") or id.begins_with("bone_"):
		add_box(p, Vector3(0.045, 0.14, 0.24), trim, Vector3(0, y + 0.22, -0.02))
	# нащёчники по бокам
	add_box(p, Vector3(0.07, 0.16, 0.14), mat, Vector3(-0.20, y + 0.0, 0.02))
	add_box(p, Vector3(0.07, 0.16, 0.14), mat, Vector3(0.20, y + 0.0, 0.02))
	# ремешок подбородка
	add_cyl(p, 0.015, 0.015, 0.18, trim, Vector3(-0.12, y - 0.12, 0.08), Vector3(0.6, 0, 0.5))
	add_cyl(p, 0.015, 0.015, 0.18, trim, Vector3(0.12, y - 0.12, 0.08), Vector3(0.6, 0, -0.5))


static func _armor_chest(p: Node3D, mat: Material, trim: Material, id: String) -> void:
	var y: float = 1.15
	# торс
	add_box(p, Vector3(0.55, 0.55, 0.32), mat, Vector3(0, y, 0.02))
	# плечи
	add_sphere(p, 0.14, mat, Vector3(-0.32, y + 0.18, 0), Vector3(1.1, 0.8, 1.0))
	add_sphere(p, 0.14, mat, Vector3(0.32, y + 0.18, 0), Vector3(1.1, 0.8, 1.0))
	# ворот
	add_cyl(p, 0.14, 0.16, 0.08, trim, Vector3(0, y + 0.28, 0.02))
	# ремни / пластины
	add_box(p, Vector3(0.50, 0.06, 0.34), trim, Vector3(0, y + 0.08, 0.02))
	add_box(p, Vector3(0.50, 0.06, 0.34), trim, Vector3(0, y - 0.10, 0.02))
	if id.begins_with("bone_"):
		for i in range(3):
			add_box(p, Vector3(0.08, 0.35, 0.04), trim, Vector3(-0.15 + i * 0.15, y, 0.18))
	# рукава-наплечья чуть вниз
	add_cyl(p, 0.09, 0.11, 0.22, mat, Vector3(-0.36, y - 0.05, 0), Vector3(0, 0, 0.4))
	add_cyl(p, 0.09, 0.11, 0.22, mat, Vector3(0.36, y - 0.05, 0), Vector3(0, 0, -0.4))


static func _armor_legs(p: Node3D, mat: Material, trim: Material) -> void:
	# поножи / штаны
	var y: float = 0.55
	add_box(p, Vector3(0.48, 0.22, 0.28), mat, Vector3(0, y + 0.25, 0))  # пояс/бёдра
	add_box(p, Vector3(0.50, 0.05, 0.30), trim, Vector3(0, y + 0.34, 0))
	# ноги
	add_cyl(p, 0.10, 0.12, 0.45, mat, Vector3(-0.12, y - 0.05, 0))
	add_cyl(p, 0.10, 0.12, 0.45, mat, Vector3(0.12, y - 0.05, 0))
	# наколенники
	add_sphere(p, 0.09, trim, Vector3(-0.12, y - 0.12, 0.08), Vector3(1.0, 0.8, 0.7))
	add_sphere(p, 0.09, trim, Vector3(0.12, y - 0.12, 0.08), Vector3(1.0, 0.8, 0.7))


static func _armor_boots(p: Node3D, mat: Material, trim: Material) -> void:
	for si in range(2):
		var s: float = -1.0 if si == 0 else 1.0
		var x: float = s * 0.12
		# голенище
		add_cyl(p, 0.09, 0.10, 0.22, mat, Vector3(x, 0.18, 0.02))
		# стопа
		add_box(p, Vector3(0.14, 0.10, 0.28), mat, Vector3(x, 0.06, 0.06))
		# носок
		add_sphere(p, 0.07, mat, Vector3(x, 0.06, 0.18), Vector3(1.0, 0.7, 1.1))
		# подошва
		add_box(p, Vector3(0.15, 0.04, 0.30), trim, Vector3(x, 0.02, 0.05))
