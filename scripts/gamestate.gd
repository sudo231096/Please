extends Node
## Глобальное состояние: здоровье, голод, жажда, ресурсы, крафт, настройки.

const SAVE_PATH := "user://scraplands.cfg"

var hp := 100.0
var max_hp := 100.0
var hunger := 100.0
var thirst := 100.0

# ресурсы
var wood := 0
var stone := 1
var sulfur := 0
var iron := 0
var cloth := 0
var metal := 0
var meat := 0
var water := 0
var kills := 0

# инструменты (бусты)
var has_hatchet := false   # топор: x2 дерево
var has_pickaxe := false   # кирка: x2 камень/руда
var has_bow := false       # лук: +урон дальний (упрощённо +урон)
var has_spear := false     # копьё: +урон

# настройки
var mouse_sens := 0.0025
var buttons_left := true

# инвентарь / hotbar
var selected_slot := 0       # активный слот hotbar (0..5)
# режим строительства
var build_mode := false      # строим «призраком»
var build_kind := ""         # что строим
var build_rot := 0.0         # поворот постройки (рад)


# предметы hotbar: [ключ ресурса, название, можно использовать?]
const HOTBAR := [
	["wood", "Дерево", false],
	["stone", "Камень", false],
	["sulfur", "Сера", false],
	["iron", "Железо", false],
	["meat", "Мясо", true],   # съесть
	["water", "Вода", true],  # выпить
]


# рецепты: имя -> {затраты, даёт}
const RECIPES := {
	"hatchet": {"name": "Каменный топор", "cost": {"wood": 100, "stone": 50}, "type": "tool"},
	"pickaxe": {"name": "Каменная кирка", "cost": {"wood": 100, "stone": 50}, "type": "tool"},
	"bow": {"name": "Лук", "cost": {"wood": 100, "cloth": 50}, "type": "weapon"},
	"spear": {"name": "Копьё", "cost": {"wood": 100, "stone": 25}, "type": "weapon"},
	"campfire": {"name": "Костёр", "cost": {"wood": 100}, "type": "build"},
	"furnace": {"name": "Печь", "cost": {"stone": 200, "wood": 50}, "type": "build"},
	"wall": {"name": "Деревянная стена", "cost": {"wood": 50}, "type": "build"},
	"floor": {"name": "Деревянный фундамент", "cost": {"wood": 100}, "type": "build"},
	"door": {"name": "Деревянная дверь", "cost": {"wood": 100}, "type": "build"},
	"bag": {"name": "Спальник", "cost": {"cloth": 25}, "type": "build"},
}

# счётчики построек
var built := {"campfire": 0, "furnace": 0, "wall": 0, "floor": 0, "door": 0, "bag": 0}


func _ready() -> void:
	load_settings()
	reset_run()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		mouse_sens = float(cfg.get_value("s", "mouse_sens", 0.0025))
		buttons_left = bool(cfg.get_value("s", "buttons_left", true))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("s", "mouse_sens", mouse_sens)
	cfg.set_value("s", "buttons_left", buttons_left)
	cfg.save(SAVE_PATH)


func reset_run() -> void:
	hp = 100.0
	max_hp = 100.0
	hunger = 100.0
	thirst = 100.0
	wood = 0
	stone = 1
	sulfur = 0
	iron = 0
	cloth = 0
	metal = 0
	meat = 0
	water = 0
	kills = 0
	has_hatchet = false
	has_pickaxe = false
	has_bow = false
	has_spear = false
	for k in built:
		built[k] = 0


func tick(delta: float) -> void:
	hunger = maxf(0.0, hunger - delta * 0.35)
	thirst = maxf(0.0, thirst - delta * 0.5)
	if hunger <= 0.0:
		hp = maxf(0.0, hp - delta * 1.2)
	if thirst <= 0.0:
		hp = maxf(0.0, hp - delta * 2.0)


func eat() -> void:
	if meat > 0:
		meat -= 1
		hunger = minf(100.0, hunger + 30.0)
		hp = minf(max_hp, hp + 10.0)


func drink() -> void:
	if water > 0:
		water -= 1
		thirst = minf(100.0, thirst + 40.0)


# ресурс активного слота hotbar
func hotbar_res(slot: int) -> String:
	return HOTBAR[slot][0]


func hotbar_count(slot: int) -> int:
	var key: String = HOTBAR[slot][0]
	match key:
		"wood": return wood
		"stone": return stone
		"sulfur": return sulfur
		"iron": return iron
		"meat": return meat
		"water": return water
	return 0


# использовать предмет в слоте (съесть мясо / выпить воду) -> сообщение
func use_slot(slot: int) -> String:
	var key: String = HOTBAR[slot][0]
	if key == "meat":
		if meat > 0:
			eat()
			return "Съел мясо"
		return "Нет мяса"
	elif key == "water":
		if water > 0:
			drink()
			return "Выпил воду"
		return "Нет воды"
	return ""


# начать строительство
func begin_build(kind: String) -> void:
	build_mode = true
	build_kind = kind
	build_rot = 0.0


func add_meat(n: int) -> void:
	meat += n


func add_resource(name: String, n: int) -> void:
	match name:
		"wood": wood += n
		"stone": stone += n
		"sulfur": sulfur += n
		"iron": iron += n
		"cloth": cloth += n
		"metal": metal += n
		"water": water += n
		"meat": meat += n


# множитель добычи дерева/камня с учётом инструментов
func harvest_bonus() -> float:
	var m := 1.0
	if has_hatchet:
		m *= 2.0
	return m


func mining_bonus() -> float:
	var m := 1.0
	if has_pickaxe:
		m *= 2.0
	return m


func attack_damage() -> float:
	var d := 30.0
	if has_spear:
		d *= 1.5
	if has_bow:
		d *= 1.25
	return d


func has_resource(name: String, n: int) -> bool:
	var have := 0
	match name:
		"wood": have = wood
		"stone": have = stone
		"sulfur": have = sulfur
		"iron": have = iron
		"cloth": have = cloth
		"metal": have = metal
	return have >= n


func take_resource(name: String, n: int) -> void:
	match name:
		"wood": wood -= n
		"stone": stone -= n
		"sulfur": sulfur -= n
		"iron": iron -= n
		"cloth": cloth -= n
		"metal": metal -= n


func can_craft(id: String) -> bool:
	if not RECIPES.has(id):
		return false
	var cost: Dictionary = RECIPES[id]["cost"]
	for r in cost:
		if not has_resource(r, cost[r]):
			return false
	return true


func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var cost: Dictionary = RECIPES[id]["cost"]
	for r in cost:
		take_resource(r, cost[r])
	match id:
		"hatchet": has_hatchet = true
		"pickaxe": has_pickaxe = true
		"bow": has_bow = true
		"spear": has_spear = true
		_: built[id] = built.get(id, 0) + 1
	return true
