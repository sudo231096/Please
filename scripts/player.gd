extends CharacterBody3D
## FPS-герой сюжетки.

const GRAV := 24.0
const SPEED := 6.2
const JUMP := 7.2

var _yaw := 0.0
var _pitch := 0.0
var _cam: Camera3D
var _ray: RayCast3D
var _prompt: Label
var _bob := 0.0
var spawn_pos := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	_cam = $Camera3D
	_ray = $Camera3D/RayCast3D
	_ray.target_position = Vector3(0, 0, -3.2)
	_ray.collision_mask = 1
	_build_hand()
	_build_prompt()


func _build_hand() -> void:
	var hand := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.12, 0.12, 0.35)
	hand.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.68, 0.52)
	hand.material_override = mat
	hand.position = Vector3(0.28, -0.28, -0.45)
	hand.rotation_degrees = Vector3(12, 8, 0)
	_cam.add_child(hand)


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.2
	_prompt.anchor_right = 0.8
	_prompt.anchor_top = 0.72
	_prompt.anchor_bottom = 0.8
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.modulate = Color(1, 1, 0.85)
	_prompt.visible = false
	layer.add_child(_prompt)


func _input(event: InputEvent) -> void:
	if Controls.ui_open:
		return
	if event is InputEventScreenDrag:
		var size := get_viewport().get_visible_rect().size
		if event.position.x > size.x * 0.45:
			_yaw -= event.relative.x * 0.004
			_pitch -= event.relative.y * 0.004
			_pitch = clampf(_pitch, -1.2, 1.2)


func _physics_process(delta: float) -> void:
	if Controls.ui_open:
		_prompt.visible = false
		return

	_cam.rotation = Vector3(_pitch, 0, 0)
	rotation.y = _yaw

	velocity.y -= GRAV * delta
	var basis := global_transform.basis
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()

	var mv := Vector3.ZERO
	mv += right * Controls.move_vector.x
	mv += fwd * -Controls.move_vector.y
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv += fwd
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv -= fwd
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv += right
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv -= right
	if mv.length() > 0.01:
		mv = mv.normalized()
		_bob += delta * 10.0
	velocity.x = mv.x * SPEED
	velocity.z = mv.z * SPEED

	if (Controls.jump_queued or Input.is_physical_key_pressed(KEY_SPACE)) and is_on_floor():
		velocity.y = JUMP
	Controls.jump_queued = false

	move_and_slide()
	_cam.position = Vector3(0, 1.6 + sin(_bob) * 0.03 * mv.length(), 0)

	_update_prompt()
	if Controls.interact_queued or Input.is_physical_key_pressed(KEY_E):
		Controls.interact_queued = false
		_try_interact()


func _update_prompt() -> void:
	_ray.force_raycast_update()
	if _ray.is_colliding():
		var col = _ray.get_collider()
		if col and col.has_method("get_prompt"):
			var t := str(col.get_prompt())
			if t != "":
				_prompt.text = t
				_prompt.visible = true
				return
	_prompt.visible = false


func _try_interact() -> void:
	_ray.force_raycast_update()
	if not _ray.is_colliding():
		return
	var col = _ray.get_collider()
	if col and col.has_method("interact"):
		col.interact(self)
