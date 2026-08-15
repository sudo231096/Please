extends StaticBody3D
## Северные ворота — финал главы 1.

var _open := false
var _door: Node3D
var _label: Label3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()
	if Story.has_flag("opened_gate"):
		_set_open(true)


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.26, 0.3)
	mat.metallic = 0.4
	mat.roughness = 0.7

	var left := MeshInstance3D.new()
	var b1 := BoxMesh.new()
	b1.size = Vector3(1.2, 4.0, 0.4)
	left.mesh = b1
	left.material_override = mat
	left.position = Vector3(-2.0, 2.0, 0)
	add_child(left)

	var right := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(1.2, 4.0, 0.4)
	right.mesh = b2
	right.material_override = mat
	right.position = Vector3(2.0, 2.0, 0)
	add_child(right)

	var arch := MeshInstance3D.new()
	var b3 := BoxMesh.new()
	b3.size = Vector3(5.4, 0.6, 0.5)
	arch.mesh = b3
	arch.material_override = mat
	arch.position = Vector3(0, 4.2, 0)
	add_child(arch)

	_door = Node3D.new()
	add_child(_door)
	var door_m := MeshInstance3D.new()
	var bd := BoxMesh.new()
	bd.size = Vector3(2.8, 3.6, 0.25)
	door_m.mesh = bd
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.35, 0.22, 0.14)
	door_m.material_override = dm
	door_m.position = Vector3(0, 1.9, 0)
	_door.add_child(door_m)

	var col := CollisionShape3D.new()
	col.name = "DoorCol"
	var cs := BoxShape3D.new()
	cs.size = Vector3(2.8, 3.6, 0.4)
	col.shape = cs
	col.position = Vector3(0, 1.9, 0)
	add_child(col)

	_label = Label3D.new()
	_label.text = "Северные ворота"
	_label.font_size = 48
	_label.position = Vector3(0, 4.8, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)


func get_prompt() -> String:
	if _open:
		return ""
	if Story.has_item("gate_key") or Story.has_flag("got_key"):
		return "[E] Открыть ворота ключом"
	return "[E] Ворота заперты"


func interact(_player: Node) -> void:
	if _open:
		return
	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if Story.has_item("gate_key") or Story.has_flag("got_key"):
		if Story.has_item("gate_key"):
			Story.consume_item("gate_key")
		Story.set_flag("opened_gate")
		_set_open(true)
		if ui:
			ui.open_dialogue("gate_open", "Ashveil", [
				"Замок щёлкает. Металл стонет, как старый рассказчик.",
				"За воротами — серый свет и дорога, которой нет на картах.",
				"Глава 1 завершена. Ты сделал первый шаг сквозь пепел.",
			])
	else:
		if ui:
			ui.open_dialogue("gate_locked", "Система", [
				"Ворота закрыты. Нужен ключ.",
			])


func _set_open(v: bool) -> void:
	_open = v
	if _door:
		_door.rotation.y = -1.4 if v else 0.0
		_door.position.x = 1.2 if v else 0.0
	var c = get_node_or_null("DoorCol")
	if c:
		c.disabled = v
	if _label:
		_label.text = "Проход открыт" if v else "Северные ворота"
