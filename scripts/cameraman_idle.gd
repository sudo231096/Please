extends Node3D
## Камерамен, стоящий в главном меню (витрина).

var _head: Node3D
var _t := 0.0


func _ready() -> void:
	_build()


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _cyl(r: float, h: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)
	return m


func _build() -> void:
	var navy := Color(0.16, 0.2, 0.32)
	# ноги
	_box(Vector3(0.24, 0.5, 0.24), Vector3(-0.18, 0.5, 0), Color(0.1, 0.1, 0.14))
	_box(Vector3(0.24, 0.5, 0.24), Vector3(0.18, 0.5, 0), Color(0.1, 0.1, 0.14))
	# торс
	_box(Vector3(0.7, 0.9, 0.45), Vector3(0, 1.05, 0), navy)
	# руки
	_box(Vector3(0.2, 0.6, 0.2), Vector3(-0.5, 1.05, 0), navy)
	_box(Vector3(0.2, 0.6, 0.2), Vector3(0.5, 1.05, 0), navy)
	# шея
	_box(Vector3(0.16, 0.2, 0.16), Vector3(0, 1.55, 0), Color(0.93, 0.78, 0.62))

	# голова-камера (отдельный узел для анимации)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.85, 0)
	add_child(_head)
	_box(Vector3(0.55, 0.55, 0.55), Vector3(0, 0, 0), Color(0.2, 0.22, 0.26), )
	# объектив
	var lens := _cyl(0.13, 0.16, Color(0.05, 0.05, 0.08))
	lens.position = Vector3(0, 0, -0.3)
	lens.rotation_degrees = Vector3(-90, 0, 0)
	lens.reparent(_head)
	# красная лампочка записи
	var lamp := _box(Vector3(0.08, 0.08, 0.08), Vector3(0, 0.29, 0), Color(1.0, 0.2, 0.2))
	lamp.reparent(_head)


func _process(delta: float) -> void:
	_t += delta
	# лёгкое покачивание корпуса и поворот головы-камеры
	position.y = sin(_t * 2.0) * 0.03
	_head.rotation.y = sin(_t * 0.7) * 0.6
