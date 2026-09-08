extends Node3D
## Случайные мировые события: аирдроп, конвой, падение самолёта, заражённая зона,
## лагерь бандитов, редкий ресурс, особый контейнер.
## События появляются периодически, живут ограниченное время, не спавнятся у базы игрока.

const BanditScr := preload("res://scripts/bandit.gd")
const AirdropScr := preload("res://scripts/airdrop.gd")

const SAFE_FROM_BASE := 45.0     # не ближе к постройкам игрока
const FIRST_DELAY := 90.0        # первое событие через полторы минуты
const PERIOD_MIN := 150.0
const PERIOD_MAX := 260.0

var _timer := FIRST_DELAY
var _rng := RandomNumberGenerator.new()
var _terrain: Node3D
var active: Array = []           # [{kind, name, pos, ttl, node}]


func _ready() -> void:
	add_to_group("world_events")
	_rng.seed = randi()
	_terrain = get_tree().get_first_node_in_group("terrain")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(PERIOD_MIN, PERIOD_MAX)
		_start_random()
	# срок жизни событий
	var dead: Array = []
	for e in active:
		e["ttl"] = float(e["ttl"]) - delta
		if float(e["ttl"]) <= 0.0:
			dead.append(e)
	for e in dead:
		var n = e.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
		active.erase(e)


func _ground(x: float, z: float) -> float:
	if _terrain and _terrain.has_method("_surface_height"):
		return _terrain._surface_height(x, z)
	return 0.0


func _on_land(x: float, z: float) -> bool:
	if _terrain and _terrain.has_method("_on_land"):
		return _terrain._on_land(x, z)
	return true


## Точка подальше от базы игрока
func _pick_spot() -> Vector3:
	for attempt in range(40):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(70.0, 360.0)
		var x := cos(a) * r
		var z := sin(a) * r
		if not _on_land(x, z):
			continue
		var too_close := false
		for st in GameState.structures:
			var sp: Vector3 = st["pos"]
			if Vector2(sp.x - x, sp.z - z).length() < SAFE_FROM_BASE:
				too_close = true
				break
		if too_close:
			continue
		return Vector3(x, _ground(x, z), z)
	return Vector3(120.0, _ground(120.0, 120.0), 120.0)


func _sector(pos: Vector3) -> String:
	var cx: int = clampi(int((pos.x + 512.0) / 1024.0 * 12.0), 0, 11)
	var cz: int = clampi(int((pos.z + 512.0) / 1024.0 * 12.0), 0, 11)
	return "%s%d" % [char(65 + cx), cz + 1]


func _notify(text: String, pos: Vector3) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("toast"):
		hud.toast("%s — сектор %s" % [text, _sector(pos)])


func _start_random() -> void:
	var kinds := ["airdrop", "convoy", "crash", "toxic", "camp", "resource", "container"]
	_start(kinds[_rng.randi() % kinds.size()])


## Публичный запуск события (используется и для теста)
func _start(kind: String) -> void:
	var pos := _pick_spot()
	match kind:
		"airdrop": _ev_airdrop(pos)
		"convoy": _ev_convoy(pos)
		"crash": _ev_crash(pos)
		"toxic": _ev_toxic(pos)
		"camp": _ev_camp(pos)
		"resource": _ev_resource(pos)
		"container": _ev_container(pos)


func _mat(c: Color, emis := Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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


func _spawn_bandit(pos: Vector3, tier: int) -> Node3D:
	var b: CharacterBody3D = BanditScr.new()
	get_parent().add_child(b)
	b.global_position = Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	b.setup(tier)
	return b


# ---------- сами события ----------

func _ev_airdrop(pos: Vector3) -> void:
	var drop: Node3D = AirdropScr.new()
	get_parent().add_child(drop)
	drop.setup(Vector2(pos.x, pos.z), _ground(pos.x, pos.z))
	active.append({"kind": "airdrop", "name": "Аирдроп", "pos": pos, "ttl": 420.0, "node": drop})
	_notify("✈ Сброс груза", pos)


func _ev_convoy(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	get_parent().add_child(root)
	# бронемашины
	for i in range(3):
		var off := Vector3(i * 7.0 - 7.0, 0, 0)
		var gy := _ground(pos.x + off.x, pos.z + off.z) - pos.y
		_box(root, Vector3(3.0, 1.2, 6.0), off + Vector3(0, gy + 0.9, 0), Color(0.25, 0.28, 0.2))
		_box(root, Vector3(2.4, 0.9, 2.6), off + Vector3(0, gy + 1.9, -0.6), Color(0.22, 0.25, 0.18))
		for sx in [-1.3, 1.3]:
			for sz in [-2.0, 2.0]:
				_box(root, Vector3(0.5, 0.9, 0.9), off + Vector3(sx, gy + 0.45, sz), Color(0.1, 0.1, 0.11))
	# охрана
	for i in range(3):
		_spawn_bandit(pos + Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9)), 1)
	active.append({"kind": "convoy", "name": "Военный конвой", "pos": pos, "ttl": 360.0, "node": root})
	_notify("🚚 Военный конвой", pos)


func _ev_crash(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	get_parent().add_child(root)
	# обломки фюзеляжа
	_box(root, Vector3(3.4, 2.6, 9.0), Vector3(0, 1.3, 0), Color(0.42, 0.44, 0.46)).rotation = Vector3(0.2, 0.4, 0.1)
	_box(root, Vector3(12.0, 0.4, 2.4), Vector3(-4.0, 0.6, 3.0), Color(0.4, 0.42, 0.44)).rotation = Vector3(0, 0.9, 0.3)
	_box(root, Vector3(5.0, 0.3, 1.6), Vector3(6.0, 0.4, -3.0), Color(0.38, 0.4, 0.42)).rotation = Vector3(0, -0.5, 0.15)
	# огонь и дым
	for i in range(4):
		_box(root, Vector3(0.8, 1.4, 0.8), Vector3(_rng.randf_range(-3, 3), 0.7, _rng.randf_range(-4, 4)),
			Color(1.0, 0.45, 0.12, 0.7), Color(1.0, 0.4, 0.05))
	for i in range(2):
		_spawn_bandit(pos + Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12)), 1)
	# лут на месте крушения
	active.append({"kind": "crash", "name": "Падение самолёта", "pos": pos, "ttl": 400.0, "node": root, "loot": true})
	_notify("💥 Упал самолёт", pos)


func _ev_toxic(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	get_parent().add_child(root)
	# зелёное облако
	for i in range(9):
		var a := TAU * i / 9.0
		var r := _rng.randf_range(4.0, 13.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var gy := _ground(pos.x + x, pos.z + z) - pos.y
		var s := _rng.randf_range(4.0, 7.0)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = s * 0.5
		sm.height = s * 0.6
		mi.mesh = sm
		mi.material_override = _mat(Color(0.45, 0.85, 0.3, 0.28), Color(0.2, 0.5, 0.1))
		mi.position = Vector3(x, gy + 1.6, z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	# бочки с отходами
	for i in range(5):
		var bx := _rng.randf_range(-9, 9)
		var bz := _rng.randf_range(-9, 9)
		_box(root, Vector3(0.9, 1.2, 0.9), Vector3(bx, _ground(pos.x + bx, pos.z + bz) - pos.y + 0.6, bz),
			Color(0.5, 0.75, 0.25))
	active.append({"kind": "toxic", "name": "Заражённая зона", "pos": pos, "ttl": 300.0, "node": root, "damage": true, "radius": 15.0})
	_notify("☣ Заражённая зона", pos)


func _ev_camp(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	get_parent().add_child(root)
	# палатки и костёр
	for i in range(3):
		var a := TAU * i / 3.0
		var x := cos(a) * 5.0
		var z := sin(a) * 5.0
		var gy := _ground(pos.x + x, pos.z + z) - pos.y
		_box(root, Vector3(3.0, 1.8, 3.0), Vector3(x, gy + 0.9, z), Color(0.3, 0.32, 0.24))
	_box(root, Vector3(1.2, 0.5, 1.2), Vector3(0, 0.25, 0), Color(1.0, 0.5, 0.12), Color(1.0, 0.4, 0.06))
	# охрана лагеря — сложнее обычной
	var n := 3 + _rng.randi() % 2
	for i in range(n):
		_spawn_bandit(pos + Vector3(_rng.randf_range(-10, 10), 0, _rng.randf_range(-10, 10)), 1 + (_rng.randi() % 2))
	active.append({"kind": "camp", "name": "Лагерь бандитов", "pos": pos, "ttl": 420.0, "node": root})
	_notify("🏕 Лагерь бандитов", pos)


func _ev_resource(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	get_parent().add_child(root)
	# жила редкого ресурса
	for i in range(7):
		var x := _rng.randf_range(-3.5, 3.5)
		var z := _rng.randf_range(-3.5, 3.5)
		var gy := _ground(pos.x + x, pos.z + z) - pos.y
		var h := _rng.randf_range(0.7, 1.6)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = _rng.randf_range(0.2, 0.4)
		cm.height = h
		mi.mesh = cm
		mi.material_override = _mat(Color(0.95, 0.8, 0.25), Color(0.7, 0.5, 0.05))
		mi.position = Vector3(x, gy + h * 0.5, z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	active.append({"kind": "resource", "name": "Редкая жила", "pos": pos, "ttl": 300.0, "node": root, "loot": true})
	_notify("💎 Редкое месторождение", pos)


func _ev_container(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	get_parent().add_child(root)
	_box(root, Vector3(2.6, 2.4, 6.0), Vector3(0, 1.2, 0), Color(0.2, 0.45, 0.55))
	_box(root, Vector3(2.7, 0.2, 6.1), Vector3(0, 2.4, 0), Color(0.16, 0.36, 0.45))
	_box(root, Vector3(0.2, 1.6, 0.2), Vector3(1.35, 1.2, 2.6), Color(0.8, 0.7, 0.2), Color(0.5, 0.4, 0.05))
	for i in range(2):
		_spawn_bandit(pos + Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)), 2)
	active.append({"kind": "container", "name": "Особый контейнер", "pos": pos, "ttl": 380.0, "node": root, "loot": true})
	_notify("📦 Особый контейнер", pos)


## Собрать лут события рядом с игроком
func try_loot(origin: Vector3) -> String:
	for e in active:
		if not bool(e.get("loot", false)):
			continue
		var p: Vector3 = e["pos"]
		if p.distance_to(origin) > 7.0:
			continue
		e["loot"] = false
		var got: Array = []
		match String(e["kind"]):
			"resource":
				GameState.add_item("sulfur", 120 + randi() % 100)
				GameState.add_item("metal", 60 + randi() % 60)
				got.append("сера и металл")
			"crash":
				GameState.add_item("metal", 90 + randi() % 80)
				GameState.add_item("scrap", 120 + randi() % 100)
				got.append("металл и скрап")
			"container":
				GameState.add_item("metal", 150 + randi() % 100)
				GameState.add_item("sulfur", 100 + randi() % 100)
				GameState.add_item("scrap", 200 + randi() % 150)
				got.append("богатый лут")
		GameState.add_xp(35)
		GameState.save_inventory()
		return "Собрано: %s (%s)" % [String(e["name"]), ", ".join(got)]
	return ""


## Урон от заражённых зон (вызывается из main каждый тик)
func tick_hazards(player_pos: Vector3, delta: float) -> float:
	var dmg := 0.0
	for e in active:
		if not bool(e.get("damage", false)):
			continue
		var p: Vector3 = e["pos"]
		if Vector2(p.x - player_pos.x, p.z - player_pos.z).length() < float(e.get("radius", 12.0)):
			dmg += 4.0 * delta
	return dmg


## Список активных событий для карты
func markers() -> Array:
	var out: Array = []
	for e in active:
		out.append({"name": String(e["name"]), "pos": e["pos"], "kind": String(e["kind"])})
	return out
