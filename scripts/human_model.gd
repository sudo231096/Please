extends Node3D
## Процедурная модель человека (как в survival-играх): голова, торс, руки, ноги.
## Отображает надетую одежду/броню (по GameState.equipped).

const SKIN := Color(0.86, 0.68, 0.52)
const SKIN_DARK := Color(0.74, 0.56, 0.42)
const CLOTH := Color(0.55, 0.5, 0.42)
const CLOTH_DARK := Color(0.42, 0.38, 0.32)
const BONE := Color(0.82, 0.78, 0.68)
const BOOT := Color(0.28, 0.22, 0.16)


func build(equipped: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()

	# определяем цвета частей по экипировке
	var torso_color := SKIN
	var legs_color := SKIN
	var feet_color := SKIN_DARK
	var head_gear := false
	if equipped.has("chest"):
		var cid: String = equipped["chest"]
		torso_color = BONE if cid == "bone_armor" else CLOTH
	if equipped.has("legs"):
		legs_color = CLOTH
	if equipped.has("feet"):
		feet_color = BOOT
	if equipped.has("head"):
		head_gear = true

	# голова
	_sphere(0.22, Vector3(0, 1.55, 0), SKIN)
	if head_gear:
		_cyl(0.235, 0.12, CLOTH, Vector3(0, 1.66, 0))
	# шея
	_cyl(0.09, 0.12, SKIN, Vector3(0, 1.4, 0))
	# торс
	_box(Vector3(0.52, 0.62, 0.28), Vector3(0, 1.05, 0), torso_color)
	# грудь (две мышцы — видны только без одежды/брони)
	if torso_color == SKIN:
		_sphere(0.14, Vector3(-0.14, 1.18, 0.13), SKIN_DARK)
		_sphere(0.14, Vector3(0.14, 1.18, 0.13), SKIN_DARK)
	elif equipped.get("chest", "") == "bone_armor":
		_box(Vector3(0.4, 0.34, 0.1), Vector3(0, 1.18, 0.15), BONE)
	# трусы (под одеждой не видны)
	if legs_color == SKIN:
		_box(Vector3(0.5, 0.26, 0.3), Vector3(0, 0.66, 0), Color(0.42, 0.42, 0.44))
	# руки
	_cyl(0.09, 0.55, SKIN, Vector3(-0.33, 1.05, 0))
	_cyl(0.09, 0.55, SKIN, Vector3(0.33, 1.05, 0))
	_cyl(0.08, 0.45, SKIN_DARK, Vector3(-0.33, 0.72, 0))
	_cyl(0.08, 0.45, SKIN_DARK, Vector3(0.33, 0.72, 0))
	# ноги
	_cyl(0.11, 0.55, legs_color, Vector3(-0.13, 0.45, 0))
	_cyl(0.11, 0.55, legs_color, Vector3(0.13, 0.45, 0))
	# голени и ступни
	_cyl(0.09, 0.4, legs_color if legs_color != SKIN else SKIN_DARK, Vector3(-0.13, 0.15, 0))
	_cyl(0.09, 0.4, legs_color if legs_color != SKIN else SKIN_DARK, Vector3(0.13, 0.15, 0))
	_box(Vector3(0.14, 0.09, 0.26), Vector3(-0.13, 0.04, 0.05), feet_color)
	_box(Vector3(0.14, 0.09, 0.26), Vector3(0.13, 0.04, 0.05), feet_color)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
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
	mat.roughness = 0.9
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
	mat.roughness = 0.9
	m.material_override = mat
	m.position = pos
	add_child(m)
