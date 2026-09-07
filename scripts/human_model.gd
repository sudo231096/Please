extends Node3D
## Процедурная модель взрослого человека в survival-стиле: реалистичные пропорции,
## голова с лицом и волосами, плечи, руки с кистями, ноги со ступнями.
## Отображает надетую одежду/броню (по GameState.equipped).

const SKIN := Color(0.85, 0.66, 0.5)
const SKIN_DARK := Color(0.72, 0.54, 0.4)
const HAIR := Color(0.24, 0.18, 0.13)
const CLOTH := Color(0.5, 0.45, 0.38)
const BONE := Color(0.82, 0.78, 0.68)
const BOOT := Color(0.3, 0.24, 0.17)


func build(equipped: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()

	var torso_color := SKIN
	var legs_color := SKIN
	var feet_color := SKIN_DARK
	var has_headgear := equipped.has("head")
	if equipped.has("chest"):
		torso_color = BONE if equipped["chest"] == "bone_armor" else CLOTH
	if equipped.has("legs"):
		legs_color = CLOTH
	if equipped.has("feet"):
		feet_color = BOOT

	# --- голова (реалистичная) ---
	_sphere(0.2, Vector3(0, 1.62, 0), SKIN)
	# волосы (шапочка сверху-сзади)
	_sphere(0.205, Vector3(0, 1.68, -0.02), HAIR)
	if has_headgear:
		_cyl(0.215, 0.12, CLOTH, Vector3(0, 1.73, 0))
	# лицо: глаза, нос, рот
	_sphere(0.03, Vector3(-0.07, 1.63, 0.19), Color(0.2, 0.2, 0.22))
	_sphere(0.03, Vector3(0.07, 1.63, 0.19), Color(0.2, 0.2, 0.22))
	_box(Vector3(0.05, 0.09, 0.05), Vector3(0, 1.6, 0.21), SKIN_DARK)
	_box(Vector3(0.1, 0.02, 0.02), Vector3(0, 1.52, 0.2), Color(0.5, 0.3, 0.28))
	# уши
	_sphere(0.05, Vector3(-0.2, 1.62, 0), SKIN)
	_sphere(0.05, Vector3(0.2, 1.62, 0), SKIN)

	# --- шея ---
	_cyl(0.09, 0.14, SKIN, Vector3(0, 1.44, 0))

	# --- плечи (широкие) ---
	_box(Vector3(0.58, 0.2, 0.26), Vector3(0, 1.32, 0), torso_color)

	# --- торс ---
	_box(Vector3(0.5, 0.6, 0.26), Vector3(0, 1.02, 0), torso_color)
	if torso_color == SKIN:
		# грудные мышцы + пресс
		_sphere(0.13, Vector3(-0.13, 1.2, 0.14), SKIN_DARK)
		_sphere(0.13, Vector3(0.13, 1.2, 0.14), SKIN_DARK)
		_box(Vector3(0.3, 0.24, 0.02), Vector3(0, 0.95, 0.14), SKIN_DARK)
	elif equipped.get("chest", "") == "bone_armor":
		_box(Vector3(0.42, 0.36, 0.12), Vector3(0, 1.16, 0.15), BONE)

	# --- таз / трусы ---
	if legs_color == SKIN:
		_box(Vector3(0.46, 0.24, 0.28), Vector3(0, 0.7, 0), Color(0.42, 0.42, 0.44))
	else:
		_box(Vector3(0.46, 0.24, 0.28), Vector3(0, 0.7, 0), CLOTH)

	# --- руки (плечо + предплечье + кисть) ---
	_cyl(0.09, 0.34, torso_color if torso_color != SKIN else SKIN, Vector3(-0.36, 1.16, 0))
	_cyl(0.09, 0.34, torso_color if torso_color != SKIN else SKIN, Vector3(0.36, 1.16, 0))
	_cyl(0.075, 0.34, SKIN, Vector3(-0.38, 0.85, 0))
	_cyl(0.075, 0.34, SKIN, Vector3(0.38, 0.85, 0))
	_box(Vector3(0.12, 0.16, 0.1), Vector3(-0.39, 0.62, 0), SKIN)
	_box(Vector3(0.12, 0.16, 0.1), Vector3(0.39, 0.62, 0), SKIN)

	# --- ноги (бедро + голень) ---
	_cyl(0.11, 0.5, legs_color, Vector3(-0.14, 0.5, 0))
	_cyl(0.11, 0.5, legs_color, Vector3(0.14, 0.5, 0))
	_cyl(0.085, 0.42, legs_color if legs_color != SKIN else SKIN_DARK, Vector3(-0.14, 0.18, 0))
	_cyl(0.085, 0.42, legs_color if legs_color != SKIN else SKIN_DARK, Vector3(0.14, 0.18, 0))

	# --- ступни ---
	_box(Vector3(0.13, 0.1, 0.28), Vector3(-0.14, 0.05, 0.07), feet_color)
	_box(Vector3(0.13, 0.1, 0.28), Vector3(0.14, 0.05, 0.07), feet_color)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	m.material_override = mat
	m.position = pos
	add_child(m)


func _sphere(r: float, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	m.material_override = mat
	m.position = pos
	add_child(m)


func _cyl(r: float, h: float, color: Color, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	m.material_override = mat
	m.position = pos
	add_child(m)
