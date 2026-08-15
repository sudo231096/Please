extends Node
## Сюжет, квесты, флаги.

signal quest_changed
signal flags_changed
signal dialogue_finished(id: String)

var flags := {}
var quest_id := "wake"
var quest_title := "Проснись"
var quest_desc := "Осмотрись. Найди, кто ещё жив."
var inventory: Array[String] = []
var chapter := 1

const QUESTS := {
	"wake": {
		"title": "Пепел на ветру",
		"desc": "Ты очнулся у костра. Поговори с Ирой у вышки.",
	},
	"radio": {
		"title": "Мёртвый эфир",
		"desc": "Ира просит найти батарейку для рации. Ищи у склада.",
	},
	"gate": {
		"title": "Северный проход",
		"desc": "Рация ожила. Отнеси весть Старику у северных ворот.",
	},
	"key": {
		"title": "Ключ от тумана",
		"desc": "Старик даст ключ, если принесёшь ему медальон из часовни.",
	},
	"finale": {
		"title": "За завесой",
		"desc": "Открой ворота ключом и узнай, что скрывает Ashveil.",
	},
	"done": {
		"title": "Глава 1 завершена",
		"desc": "Ты открыл проход. История только начинается…",
	},
}


func _ready() -> void:
	reset()


func reset() -> void:
	flags = {
		"met_ira": false,
		"got_battery": false,
		"radio_fixed": false,
		"met_oldman": false,
		"got_medallion": false,
		"got_key": false,
		"opened_gate": false,
	}
	inventory.clear()
	chapter = 1
	set_quest("wake")


func set_flag(id: String, val: bool = true) -> void:
	flags[id] = val
	flags_changed.emit()
	_recompute_quest()


func has_flag(id: String) -> bool:
	return bool(flags.get(id, false))


func add_item(id: String) -> void:
	if id in inventory:
		return
	inventory.append(id)
	flags_changed.emit()
	_recompute_quest()


func has_item(id: String) -> bool:
	return id in inventory


func consume_item(id: String) -> void:
	inventory.erase(id)
	flags_changed.emit()


func set_quest(id: String) -> void:
	if not QUESTS.has(id):
		return
	quest_id = id
	quest_title = str(QUESTS[id]["title"])
	quest_desc = str(QUESTS[id]["desc"])
	quest_changed.emit()


func _recompute_quest() -> void:
	if has_flag("opened_gate"):
		set_quest("done")
	elif has_flag("got_key"):
		set_quest("finale")
	elif has_flag("met_oldman") and not has_flag("got_medallion"):
		set_quest("key")
	elif has_flag("radio_fixed"):
		set_quest("gate")
	elif has_flag("met_ira") and not has_flag("got_battery"):
		set_quest("radio")
	elif has_flag("met_ira") and has_flag("got_battery") and not has_flag("radio_fixed"):
		set_quest("radio")
	else:
		set_quest("wake")


func item_title(id: String) -> String:
	match id:
		"battery":
			return "Батарейка"
		"medallion":
			return "Медальон"
		"gate_key":
			return "Ключ от ворот"
		_:
			return id
