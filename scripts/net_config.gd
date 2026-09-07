extends Node
## Конфигурация игровых серверов.
## Адреса и порты вынесены сюда, чтобы их можно было заменить без правки логики.
## Значения по умолчанию можно переопределить файлом user://servers.cfg
## (он подхватывается при запуске и имеет приоритет), например:
##
##   [server1]
##   host="150.230.10.55"
##   port=27015
##
## Порт статуса задаётся отдельно (status_port), по умолчанию game_port + 100,
## чтобы он не пересекался с игровым портом соседнего сервера.
## HTTP GET http://host:status_port/status → {"players":N,"max":85}

const MAX_PLAYERS := 85         # жёсткий лимит реальных игроков на сервер
const OVERRIDE_PATH := "user://servers.cfg"

# host == "" → сервер ещё не развёрнут, в меню показывается NOT DEPLOYED
var servers: Array = [
	{"id": 1, "name": "Server 1", "region": "EU", "host": "", "port": 27015, "status_port": 27115},
	{"id": 2, "name": "Server 2", "region": "EU", "host": "", "port": 27016, "status_port": 27116},
	{"id": 3, "name": "Server 3", "region": "US", "host": "", "port": 27017, "status_port": 27117},
	{"id": 4, "name": "Server 4", "region": "US", "host": "", "port": 27018, "status_port": 27118},
	{"id": 5, "name": "Server 5", "region": "ASIA", "host": "", "port": 27019, "status_port": 27119},
]


func _ready() -> void:
	load_overrides()


func load_overrides() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(OVERRIDE_PATH) != OK:
		return
	for s in servers:
		var sec: String = "server%d" % int(s["id"])
		if not cfg.has_section(sec):
			continue
		s["host"] = String(cfg.get_value(sec, "host", s["host"]))
		s["port"] = int(cfg.get_value(sec, "port", s["port"]))
		s["status_port"] = int(cfg.get_value(sec, "status_port", s.get("status_port", int(s["port"]) + 100)))
		s["name"] = String(cfg.get_value(sec, "name", s["name"]))
		s["region"] = String(cfg.get_value(sec, "region", s["region"]))


func save_overrides() -> void:
	var cfg := ConfigFile.new()
	for s in servers:
		var sec: String = "server%d" % int(s["id"])
		cfg.set_value(sec, "host", s["host"])
		cfg.set_value(sec, "port", s["port"])
		cfg.set_value(sec, "status_port", s.get("status_port", int(s["port"]) + 100))
		cfg.set_value(sec, "name", s["name"])
		cfg.set_value(sec, "region", s["region"])
	cfg.save(OVERRIDE_PATH)


func get_server(id: int) -> Dictionary:
	for s in servers:
		if int(s["id"]) == id:
			return s
	return {}


func status_url(s: Dictionary) -> String:
	return "http://%s:%d/status" % [String(s["host"]), status_port_of(s)]


func status_port_of(s: Dictionary) -> int:
	return int(s.get("status_port", int(s["port"]) + 100))


func is_deployed(s: Dictionary) -> bool:
	return String(s["host"]).strip_edges() != ""


## Отдельное сохранение прогресса для каждого сервера: Server N → Player Data N
func save_path_for(server_id: int) -> String:
	return "user://player_data_%d.cfg" % server_id
