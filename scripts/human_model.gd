extends Node3D
## Процедурная модель человека в трусах (стартовый персонаж как в Rust).

const SKIN := Color(0.86, 0.68, 0.52)
const SKIN_DARK := Color(0.74, 0.56, 0.42)
const UNDERWEAR := Color(0.42, 0.42, 0.44)


func build() -> void:
	# голова
	_sphere(0.22, Vector3(0, 1.55, 0), SKIN)
	# шея
	_cyl(0.09, 0.12, SKIN, Vector3(0, 1.4, 0))
	# торс (грудь голая)
	_box(Vector3(0.52, 0.62, 0.28), Vector3(0, 1.05, 0), SKIN)
	# грудь (две мышцы)
	_sphere(0.14, Vector3(-0.14, 1.18, 0.13), SKIN_DARK)
	_sphere(0.14, Vector3(0.14, 1.18, 0.13), SKIN_DARK)
	# трусы
	_box(Vector3(0.5, 0.26, 0.3), Vector3(0, 0.66, 0), UNDERWEAR)
	# руки
	_cyl(0.09, 0.55, SKIN, Vector3(-0.33, 1.05, 0))
	_cyl(0.09, 0.55, SKIN, Vector3(0.33, 1.05, 0))
	# предплечья
	_cyl(0.08, 0.45, SKIN_DARK, Vector3(-0.33, 0.72, 0))
	_cyl(0.08, 0.45, SKIN_DARK, Vector3(0.33, 0.72, 0))
	# ноги
	_cyl(0.11, 0.55, SKIN, Vector3(-0.13, 0.45, 0))
	_cyl(0.11, 0.55, SKIN, Vector3(0.13, 0.45, 0))
	# голени
	_cyl(0.09, 0.4, SKIN_DARK, Vector3(-0.13, 0.15, 0))
	_cyl(0.09, 0.4, SKIN_DARK, Vector3(0.13, 0.15, 0))
	# ступни
	_box(Vector3(0.14, 0.09, 0.26), Vector3(-0.13, 0.04, 0.05), SKIN_DARK)
	_box(Vector3(0.14, 0.09, 0.26), Vector3(0.13, 0.04, 0.05), SKIN_DARK)


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
