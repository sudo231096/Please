extends Node
## Сохраняемые данные: монеты, агент, промокоды.

signal data_changed

const SAVE_PATH := "user://save.cfg"

var coins := 100
var selected_agent := "camera_man"
var unlocked_agents: Array = ["camera_man"]
var used_promos: Array = []

const AGENTS := {
	"camera_man": {
		"name": "Камера Мен",
		"desc": "Стартовый агент. Камера на голове, меткий взгляд.",
		"price": 0,
		"color": Color(0.25, 0.45, 0.75),
		"accent": Color(0.4, 0.85, 1.0),
	},
	"speakerman": {
		"name": "Спикер Мен",
		"desc": "Громкий боец. Колонки вместо головы.",
		"price": 250,
		"color": Color(0.35, 0.35, 0.4),
		"accent": Color(0.9, 0.75, 0.2),
	},
	"tv_man": {
		"name": "ТВ Мен",
		"desc": "Экран вместо лица. Сильный и редкий.",
		"price": 500,
		"color": Color(0.15, 0.15, 0.18),
		"accent": Color(0.7, 0.3, 1.0),
	},
}

const PROMOS := {
	"SKIBIDI": {"coins": 150, "msg": "+150 монет!"},
	"CAMERA": {"coins": 100, "msg": "+100 монет!"},
	"TOILET": {"coins": 200, "msg": "+200 монет!"},
	"FREE100": {"coins": 100, "msg": "+100 монет!"},
}


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		save_data()
		return
	coins = int(cfg.get_value("player", "coins", 100))
	selected_agent = str(cfg.get_value("player", "selected_agent", "camera_man"))
	unlocked_agents = cfg.get_value("player", "unlocked_agents", ["camera_man"])
	used_promos = cfg.get_value("player", "used_promos", [])
	if typeof(unlocked_agents) != TYPE_ARRAY:
		unlocked_agents = ["camera_man"]
	if typeof(used_promos) != TYPE_ARRAY:
		used_promos = []
	if not ("camera_man" in unlocked_agents):
		unlocked_agents.append("camera_man")
	if not AGENTS.has(selected_agent):
		selected_agent = "camera_man"
	data_changed.emit()


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "coins", coins)
	cfg.set_value("player", "selected_agent", selected_agent)
	cfg.set_value("player", "unlocked_agents", unlocked_agents)
	cfg.set_value("player", "used_promos", used_promos)
	cfg.save(SAVE_PATH)
	data_changed.emit()


func agent_name(id: String) -> String:
	if AGENTS.has(id):
		return str(AGENTS[id]["name"])
	return id


func is_unlocked(id: String) -> bool:
	return id in unlocked_agents


func try_buy(id: String) -> String:
	if not AGENTS.has(id):
		return "Нет такого агента"
	if id in unlocked_agents:
		return "Уже куплено"
	var price := int(AGENTS[id]["price"])
	if coins < price:
		return "Не хватает монет"
	coins -= price
	unlocked_agents.append(id)
	selected_agent = id
	save_data()
	return "Куплено: %s" % agent_name(id)


func select_agent(id: String) -> String:
	if not (id in unlocked_agents):
		return "Сначала купи агента"
	selected_agent = id
	save_data()
	return "Выбран: %s" % agent_name(id)


func try_promo(code: String) -> String:
	var c := code.strip_edges().to_upper()
	if c == "":
		return "Введи промокод"
	if not PROMOS.has(c):
		return "Промокод не найден"
	if c in used_promos:
		return "Уже активирован"
	var reward: Dictionary = PROMOS[c]
	coins += int(reward["coins"])
	used_promos.append(c)
	save_data()
	return str(reward["msg"])
