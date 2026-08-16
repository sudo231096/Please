extends Area3D
## Снаряд камерамена.

var dir := Vector3(0, 0, -1)
var speed := 22.0
var damage := 34.0
var life := 2.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # враги (слой 3)
	monitoring = true
	body_entered.connect(_on_hit)
	_build()


func _build() -> void:
	var col := CollisionShape3D.new()
	var cs := SphereShape3D.new()
	cs.radius = 0.18
	col.shape = cs
	add_child(col)

	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	add_child(m)


func _physics_process(delta: float) -> void:
	global_position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_hit(body: Node3D) -> void:
	if body and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
