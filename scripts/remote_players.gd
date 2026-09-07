extends Node3D
## Отрисовка других игроков, подключённых к тому же серверу.
## Данные приходят только из Net.remote_players (снимок состояния от сервера).

const HumanScr := preload("res://scripts/human_model.gd")

var _avatars: Dictionary = {}   # peer_id -> {node: Node3D, label: Label3D, target: Vector3, yaw: float}


func _ready() -> void:
	if Net.peers_changed.is_connected(_sync):
		return
	Net.peers_changed.connect(_sync)


func _sync() -> void:
	var seen := {}
	for pid in Net.remote_players.keys():
		var d: Dictionary = Net.remote_players[pid]
		seen[pid] = true
		if not _avatars.has(pid):
			_avatars[pid] = _make_avatar(String(d.get("name", "player")))
		var a: Dictionary = _avatars[pid]
		a["target"] = d.get("pos", Vector3.ZERO)
		a["yaw"] = float(d.get("yaw", 0.0))
	for pid in _avatars.keys():
		if not seen.has(pid):
			var a: Dictionary = _avatars[pid]
			(a["node"] as Node3D).queue_free()
			_avatars.erase(pid)


func _make_avatar(pname: String) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var model: Node3D = HumanScr.new()
	root.add_child(model)
	model.call("build", {})
	var lbl := Label3D.new()
	lbl.text = pname
	lbl.position = Vector3(0, 2.1, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	lbl.pixel_size = 0.006
	lbl.modulate = Color(0.95, 0.9, 0.6)
	root.add_child(lbl)
	return {"node": root, "label": lbl, "target": Vector3.ZERO, "yaw": 0.0}


func _process(delta: float) -> void:
	# плавная интерполяция между снимками сервера (15 тиков/сек)
	var t: float = clampf(delta * 12.0, 0.0, 1.0)
	for pid in _avatars.keys():
		var a: Dictionary = _avatars[pid]
		var n: Node3D = a["node"]
		var tgt: Vector3 = a["target"]
		if n.position.distance_to(tgt) > 25.0:
			n.position = tgt
		else:
			n.position = n.position.lerp(tgt, t)
		n.rotation.y = lerp_angle(n.rotation.y, float(a["yaw"]), t)
