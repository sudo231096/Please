extends Node
## Сетевой слой Scraplands. Один автолоад — и клиент, и выделенный сервер,
## чтобы пути RPC (/root/Net) совпадали на обеих сторонах.
##
## Запуск выделенного сервера (headless, без графики):
##   godot --headless --path . -- --server --id=1 --port=27015
##
## Клиент подключается по публичному IP из scripts/net_config.gd (или user://servers.cfg).
## Транспорт — ENet поверх UDP: работает через интернет из любой страны,
## сервер авторитетен по составу игроков, лимиту и состоянию мира.

signal connection_state_changed(state: String)   # offline / connecting / online / error
signal peers_changed()
signal server_message(text: String)

const PROTOCOL_VERSION := 1
const TICK_RATE := 15.0                # апдейтов позиции в секунду
const CLIENT_TIMEOUT := 12.0           # сек без пакета от клиента → кик
const RECONNECT_DELAY := 3.0

# --- общее ---
var is_server := false
var state := "offline"
var last_error := ""

# --- клиент ---
var current_server: Dictionary = {}
var my_id := 0
var remote_players: Dictionary = {}    # peer_id -> {pos, yaw, hp, name}
var server_player_count := 0
var server_max_players := 85

# --- сервер ---
var server_id := 0
var clients: Dictionary = {}           # peer_id -> {name, pos, yaw, hp, last_seen, joined}
var world_seed := 0

var _peer: ENetMultiplayerPeer = null
var _acc := 0.0
var _reconnect_acc := 0.0
var _want_reconnect := false
var _status_server: TCPServer = null
var _status_conns: Array = []


func _ready() -> void:
	set_process(true)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	var args := _parse_args()
	if args.has("server"):
		start_dedicated(int(args.get("id", "1")), int(args.get("port", "27015")), int(args.get("status-port", "0")))


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			s = s.substr(2)
		if s.contains("="):
			var parts := s.split("=", true, 1)
			out[parts[0]] = parts[1]
		elif s != "":
			out[s] = "1"
	return out


# =====================================================================
#  СЕРВЕРНАЯ ЧАСТЬ (авторитетная)
# =====================================================================

func start_dedicated(id: int, port: int, status_port: int = 0) -> bool:
	is_server = true
	server_id = id
	world_seed = _stable_seed(id)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, NetConfig.MAX_PLAYERS + 8)
	if err != OK:
		push_error("Не удалось поднять сервер на порту %d (код %d)" % [port, err])
		return false
	multiplayer.multiplayer_peer = _peer
	_state("online")
	var sp := status_port if status_port > 0 else port + 100
	_start_status_endpoint(sp)
	print("[Scraplands] Server %d слушает UDP :%d, лимит %d игроков, seed=%d" % [id, port, NetConfig.MAX_PLAYERS, world_seed])
	print("[Scraplands] HTTP-статус на :%d/status" % sp)
	return true


func _stable_seed(id: int) -> int:
	# у каждого сервера своё, но детерминированное состояние мира
	return 1000003 * id + 777


func _on_peer_connected(pid: int) -> void:
	if not is_server:
		return
	# место резервируем только после srv_join (проверка лимита там же)
	if clients.size() >= NetConfig.MAX_PLAYERS:
		rpc_id(pid, "cl_join_rejected", "Сервер заполнен (%d/%d)" % [clients.size(), NetConfig.MAX_PLAYERS])
		await get_tree().create_timer(0.4).timeout
		_kick(pid)


func _kick(pid: int) -> void:
	# аккуратное отключение: пир мог уже отвалиться сам
	var mp := multiplayer.multiplayer_peer
	if mp == null:
		return
	if mp is ENetMultiplayerPeer and (mp as ENetMultiplayerPeer).get_peer(pid) != null:
		(mp as ENetMultiplayerPeer).disconnect_peer(pid)


func _on_peer_disconnected(pid: int) -> void:
	if not is_server:
		return
	if clients.erase(pid):
		print("[Scraplands] Игрок %d отключился (%d/%d)" % [pid, clients.size(), NetConfig.MAX_PLAYERS])
		for other in clients.keys():
			rpc_id(int(other), "cl_player_left", pid, clients.size())


@rpc("any_peer", "call_remote", "reliable")
func srv_join(ver: int, pname: String) -> void:
	if not is_server:
		return
	var pid := multiplayer.get_remote_sender_id()
	if ver != PROTOCOL_VERSION:
		rpc_id(pid, "cl_join_rejected", "Версия клиента не совпадает с сервером")
		return
	if clients.has(pid):
		return
	if clients.size() >= NetConfig.MAX_PLAYERS:
		rpc_id(pid, "cl_join_rejected", "Сервер заполнен (%d/%d)" % [clients.size(), NetConfig.MAX_PLAYERS])
		return
	clients[pid] = {
		"name": pname.substr(0, 24),
		"pos": Vector3.ZERO,
		"yaw": 0.0,
		"hp": 100.0,
		"last_seen": Time.get_ticks_msec(),
	}
	print("[Scraplands] Игрок %d (%s) вошёл (%d/%d)" % [pid, pname, clients.size(), NetConfig.MAX_PLAYERS])
	rpc_id(pid, "cl_join_accepted", pid, clients.size(), NetConfig.MAX_PLAYERS, world_seed)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_update(pos: Vector3, yaw: float, hp: float) -> void:
	if not is_server:
		return
	var pid := multiplayer.get_remote_sender_id()
	if not clients.has(pid):
		return
	var c: Dictionary = clients[pid]
	# авторитетная валидация: не пускаем за границы мира и не даём «телепорт» вне карты
	c["pos"] = Vector3(clampf(pos.x, -520.0, 520.0), clampf(pos.y, -60.0, 300.0), clampf(pos.z, -520.0, 520.0))
	c["yaw"] = yaw
	c["hp"] = clampf(hp, 0.0, 500.0)
	c["last_seen"] = Time.get_ticks_msec()


func _server_tick() -> void:
	var now := Time.get_ticks_msec()
	# кик «мертвых» соединений
	for pid in clients.keys():
		var c: Dictionary = clients[pid]
		if now - int(c["last_seen"]) > int(CLIENT_TIMEOUT * 1000.0):
			print("[Scraplands] Таймаут игрока %d" % pid)
			_kick(int(pid))
			clients.erase(pid)
	# рассылка состояния мира
	var snapshot := {}
	for pid in clients.keys():
		var c: Dictionary = clients[pid]
		snapshot[pid] = {"pos": c["pos"], "yaw": c["yaw"], "hp": c["hp"], "name": c["name"]}
	var cnt := clients.size()
	for pid in clients.keys():
		rpc_id(int(pid), "cl_world_state", snapshot, cnt)


# ---- HTTP-эндпоинт статуса: реальное число подключённых игроков ----

func _start_status_endpoint(port: int) -> void:
	_status_server = TCPServer.new()
	if _status_server.listen(port) != OK:
		push_warning("Не удалось открыть порт статуса %d" % port)
		_status_server = null


func _poll_status_endpoint() -> void:
	if _status_server == null:
		return
	while _status_server.is_connection_available():
		var c := _status_server.take_connection()
		if c != null:
			_status_conns.append({"c": c, "t": 0.0})
	var keep := []
	for e in _status_conns:
		var c: StreamPeerTCP = e["c"]
		c.poll()
		if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		if c.get_available_bytes() > 0:
			c.get_data(c.get_available_bytes())
			var body := '{"server":%d,"players":%d,"max":%d,"online":true}' % [server_id, clients.size(), NetConfig.MAX_PLAYERS]
			var resp := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.length(), body]
			c.put_data(resp.to_utf8_buffer())
			c.disconnect_from_host()
		else:
			keep.append(e)
	_status_conns = keep


# =====================================================================
#  КЛИЕНТСКАЯ ЧАСТЬ
# =====================================================================

func is_online() -> bool:
	return state == "online" and not is_server


func connect_to_server(s: Dictionary) -> bool:
	if is_server:
		return false
	disconnect_from_server(false)
	if not NetConfig.is_deployed(s):
		last_error = "Сервер не развёрнут: в конфигурации нет адреса"
		_state("error")
		return false
	current_server = s
	_want_reconnect = true
	return _do_connect()


func _do_connect() -> bool:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(String(current_server["host"]), int(current_server["port"]))
	if err != OK:
		last_error = "Не удалось создать клиента (код %d)" % err
		_state("error")
		return false
	multiplayer.multiplayer_peer = _peer
	_state("connecting")
	return true


func disconnect_from_server(keep_reconnect: bool = false) -> void:
	_want_reconnect = keep_reconnect
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	remote_players.clear()
	my_id = 0
	_state("offline")
	peers_changed.emit()


func _on_connected() -> void:
	my_id = multiplayer.get_unique_id()
	_state("online")
	rpc_id(1, "srv_join", PROTOCOL_VERSION, GameState.player_name)


func _on_connect_failed() -> void:
	last_error = "Не удалось подключиться к %s:%s" % [current_server.get("host", "?"), str(current_server.get("port", 0))]
	multiplayer.multiplayer_peer = null
	_peer = null
	_state("offline" if _want_reconnect else "error")


func _on_server_disconnected() -> void:
	last_error = "Соединение потеряно, переподключаюсь…"
	multiplayer.multiplayer_peer = null
	_peer = null
	remote_players.clear()
	peers_changed.emit()
	server_message.emit(last_error)
	_state("offline")


@rpc("authority", "call_remote", "reliable")
func cl_join_accepted(pid: int, count: int, maxp: int, wseed: int) -> void:
	my_id = pid
	server_player_count = count
	server_max_players = maxp
	GameState.world_seed = wseed
	server_message.emit("Вы на %s — %d/%d" % [current_server.get("name", "?"), count, maxp])


@rpc("authority", "call_remote", "reliable")
func cl_join_rejected(reason: String) -> void:
	last_error = reason
	_want_reconnect = false
	server_message.emit(reason)
	disconnect_from_server(false)
	_state("error")


@rpc("authority", "call_remote", "unreliable_ordered")
func cl_world_state(states: Dictionary, count: int) -> void:
	server_player_count = count
	remote_players.clear()
	for k in states.keys():
		var pid := int(k)
		if pid == my_id:
			continue
		remote_players[pid] = states[k]
	peers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func cl_player_left(pid: int, count: int) -> void:
	remote_players.erase(pid)
	server_player_count = count
	peers_changed.emit()


func _push_local_state() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("local_player")
	if players.is_empty():
		return
	var p: Node3D = players[0]
	rpc_id(1, "srv_update", p.global_position, p.global_rotation.y, GameState.hp)


func _state(s: String) -> void:
	if state != s:
		state = s
		connection_state_changed.emit(s)


func _process(delta: float) -> void:
	if is_server:
		_acc += delta
		if _acc >= 1.0 / TICK_RATE:
			_acc = 0.0
			_server_tick()
		_poll_status_endpoint()
		return
	if state == "offline" and _want_reconnect:
		_reconnect_acc += delta
		if _reconnect_acc >= RECONNECT_DELAY:
			_reconnect_acc = 0.0
			_do_connect()
		return
	if state != "online":
		return
	_acc += delta
	if _acc >= 1.0 / TICK_RATE:
		_acc = 0.0
		_push_local_state()
