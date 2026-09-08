extends Node3D
## Аирдроп: самолёт пролетает над картой, сбрасывает ящик на парашюте.
## Ящик физически снижается до земли, затем его можно открыть.

signal landed(pos: Vector3)

const FALL_SPEED := 5.5
const PLANE_SPEED := 42.0

var _plane: Node3D
var _crate: Node3D
var _chute: MeshInstance3D
var _target := Vector3.ZERO
var _state := "fly"        # fly / drop / landed / looted
var _plane_from := Vector3.ZERO
var _plane_to := Vector3.ZERO
var _t := 0.0
var _ground_y := 0.0
var _beacon: MeshInstance3D
var _opened := false


func setup(target_xz: Vector2, ground_y: float) -> void:
	_target = Vector3(target_xz.x, ground_y, target_xz.y)
	_ground_y = ground_y
	var dir := Vector2(cos(randf() * TAU), sin(randf() * TAU)).normalized()
	_plane_from = Vector3(_target.x - dir.x * 420.0, ground_y + 145.0, _target.z - dir.y * 420.0)
	_plane_to = Vector3(_target.x + dir.x * 420.0, ground_y + 145.0, _target.z + dir.y * 420.0)
	_build_plane()


func _mat(c: Color, emis := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emis.a > 0.0:
		m.emission_enabled = true
		m.emission = emis
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, emis := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, emis)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_plane() -> void:
	_plane = Node3D.new()
	_plane.position = _plane_from
	add_child(_plane)
	var body := Color(0.38, 0.4, 0.42)
	_box(_plane, Vector3(3.0, 2.6, 14.0), Vector3.ZERO, body)
	_box(_plane, Vector3(19.0, 0.4, 2.6), Vector3(0, 0.6, 0.5), body.darkened(0.1))
	_box(_plane, Vector3(0.4, 2.6, 2.0), Vector3(0, 1.6, -6.0), body.darkened(0.15))
	_box(_plane, Vector3(6.0, 0.3, 1.4), Vector3(0, 1.0, -6.2), body.darkened(0.1))
	# мигающие огни
	_box(_plane, Vector3(0.5, 0.5, 0.5), Vector3(-9.4, 0.7, 0.5), Color(1, 0.25, 0.2), Color(1, 0.2, 0.15))
	_box(_plane, Vector3(0.5, 0.5, 0.5), Vector3(9.4, 0.7, 0.5), Color(0.3, 1, 0.35), Color(0.2, 1, 0.3))
	_plane.look_at_from_position(_plane_from, _plane_to, Vector3.UP)


func _build_crate() -> void:
	_crate = Node3D.new()
	_crate.position = Vector3(_target.x, _plane.global_position.y - 3.0, _target.z)
	add_child(_crate)
	# ящик
	_box(_crate, Vector3(1.6, 1.4, 1.6), Vector3(0, 0.7, 0), Color(0.55, 0.42, 0.16))
	_box(_crate, Vector3(1.7, 0.18, 1.7), Vector3(0, 1.42, 0), Color(0.4, 0.3, 0.12))
	_box(_crate, Vector3(1.66, 0.14, 0.2), Vector3(0, 0.7, 0), Color(0.75, 0.6, 0.15), Color(0.5, 0.4, 0.05))
	# парашют
	_chute = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.6
	sm.height = 3.0
	sm.is_hemisphere = true
	_chute.mesh = sm
	_chute.material_override = _mat(Color(0.9, 0.55, 0.2))
	_chute.position = Vector3(0, 4.4, 0)
	_chute.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crate.add_child(_chute)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var rope := _box(_crate, Vector3(0.06, 3.2, 0.06), Vector3(sx * 0.7, 2.8, sz * 0.7), Color(0.85, 0.8, 0.7))
	# сигнальный дым/маяк
	_beacon = _box(_crate, Vector3(0.5, 22.0, 0.5), Vector3(0, 11.0, 0), Color(1.0, 0.5, 0.15, 0.35), Color(1.0, 0.45, 0.1))
	var bm: StandardMaterial3D = _beacon.material_override
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _process(delta: float) -> void:
	match _state:
		"fly":
			_t += delta * PLANE_SPEED / _plane_from.distance_to(_plane_to)
			_plane.global_position = _plane_from.lerp(_plane_to, _t)
			if _t >= 0.5:
				_state = "drop"
				_build_crate()
		"drop":
			_t += delta * PLANE_SPEED / _plane_from.distance_to(_plane_to)
			if _t <= 1.0:
				_plane.global_position = _plane_from.lerp(_plane_to, _t)
			else:
				_plane.visible = false
			# ящик снижается
			_crate.position.y -= FALL_SPEED * delta
			_crate.rotation.y += delta * 0.35
			if _crate.position.y <= _ground_y:
				_crate.position.y = _ground_y
				_state = "landed"
				if _chute:
					var tw := create_tween()
					tw.tween_property(_chute, "scale", Vector3(1, 0.05, 1), 0.8)
					tw.tween_callback(_chute.hide)
				landed.emit(_crate.global_position)
				var hud := get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("toast"):
					hud.toast("Аирдроп приземлился!")
		"landed":
			if _beacon:
				var a: float = 0.2 + absf(sin(Time.get_ticks_msec() / 400.0)) * 0.25
				(_beacon.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.5, 0.15, a)


## Позиция ящика для карты и взаимодействия
func crate_position() -> Vector3:
	return _crate.global_position if _crate else _target


func is_ready() -> bool:
	return _state == "landed" and not _opened


## Открыть ящик — редкий лут
func open() -> String:
	if not is_ready():
		return ""
	_opened = true
	_state = "looted"
	var parts: Array = []
	var loot := {
		"metal": 120 + randi() % 120,
		"scrap": 150 + randi() % 200,
		"sulfur": 80 + randi() % 120,
		"cloth": 60 + randi() % 60,
	}
	for k in loot:
		GameState.add_item(String(k), int(loot[k]))
		parts.append("%s x%d" % [GameState.item_name(String(k)), int(loot[k])])
	# редкий предмет
	if randf() < 0.6:
		GameState.add_item("bone_armor", 1)
		parts.append("Костяная броня")
	if randf() < 0.45:
		GameState.add_item("bow", 1)
		GameState.add_item("arrow", 30)
		parts.append("Лук и стрелы")
	GameState.add_xp(60)
	GameState.save_inventory()
	# ящик становится пустым
	if _beacon:
		_beacon.queue_free()
	return ", ".join(parts)
