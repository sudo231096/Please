extends StaticBody3D
## Подбираемый сюжетный предмет.

@export var item_id := "battery"
@export var title := "Батарейка"
@export var flag_on_take := "got_battery"

var _taken := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()
	if Story.has_flag(flag_on_take) or Story.has_item(item_id):
		_taken = true
		visible = false
		$CollisionShape3D.disabled = true


func _build() -> void:
	var mi := MeshInstance3D.new()
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	match item_id:
		"battery":
			var b := BoxMesh.new()
			b.size = Vector3(0.25, 0.35, 0.25)
			mesh = b
			mat.albedo_color = Color(0.2, 0.45, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.3, 0.8)
			mat.emission_energy_multiplier = 0.6
		"medallion":
			var c := CylinderMesh.new()
			c.top_radius = 0.18
			c.bottom_radius = 0.18
			c.height = 0.05
			mesh = c
			mat.albedo_color = Color(0.85, 0.7, 0.2)
			mat.metallic = 0.7
			mat.roughness = 0.35
		_:
			var s := SphereMesh.new()
			s.radius = 0.15
			s.height = 0.3
			mesh = s
			mat.albedo_color = Color(0.8, 0.8, 0.8)
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0, 0.4, 0)
	add_child(mi)

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 0.8, 0.6)
	col.shape = bs
	col.position = Vector3(0, 0.4, 0)
	add_child(col)

	var l := Label3D.new()
	l.text = title
	l.font_size = 42
	l.position = Vector3(0, 0.95, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)


func get_prompt() -> String:
	if _taken:
		return ""
	return "[E] Взять: %s" % title


func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	Story.add_item(item_id)
	if flag_on_take != "":
		Story.set_flag(flag_on_take)
	visible = false
	$CollisionShape3D.disabled = true
	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if ui:
		ui.open_dialogue("pickup_%s" % item_id, "Система", [
			"Получено: %s" % title,
		])
