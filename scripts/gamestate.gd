extends Node
## Глобальное состояние: здоровье, голод, жажда, ресурсы, дерево технологий, настройки.

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
var scrap := 0       # скрап — валюта прокачки (как в Rust)
var meat := 0
var water := 0
var kills := 0

# инструменты
var has_hatchet := false
var has_pickaxe := false
var has_bow := false
var has_spear := false

# настройки
var mouse_sens := 0.0025
var buttons_left := true

var last_pos := Vector3.ZERO  # позиция игрока для карты

# инвентарь / hotbar
var selected_slot := 0
var build_mode := false
var build_kind := ""
var build_rot := 0.0


# --- ДЕРЕВО ТЕХНОЛОГИЙ (как в Rust: изучаешь за скрап) ---
# tech id -> {name, cost (скрап), prereq (id или ""), unlocks (список рецептов)}
const TECH_TREE := {
	"woodwork": {"name": "Обработка дерева", "cost": 50, "prereq": "", "unlocks": ["hatchet", "pickaxe", "campfire", "wall", "floor"]},
	"hunting": {"name": "Охота", "cost": 75, "prereq": "woodwork", "unlocks": ["spear", "bow"]},
	"masonry": {"name": "Каменное дело", "cost": 100, "prereq": "woodwork", "unlocks": ["furnace", "door"]},
	"metallurgy": {"name": "Металлургия", "cost": 150, "prereq": "masonry", "unlocks": ["workbench", "bag"]},
	"advanced_weapons": {"name": "Продвинутое оружие", "cost": 200, "prereq": "hunting", "unlocks": []},
	"fortification": {"name": "Укрепления", "cost": 250, "prereq": "masonry", "unlocks": []},
}

# изученные технологии
var learned_techs := {}

# все рецепты (доступны только после изучения технологии)
const RECIPES := {
	"hatchet": {"name": "Каменный топор", "cost": {"wood": 100, "stone": 50}, "type": "tool", "tech": "woodwork"},
	"pickaxe": {"name": "Каменная кирка", "cost": {"wood": 100, "stone": 50}, "type": "tool", "tech": "woodwork"},
	"spear": {"name": "Копьё", "cost": {"wood": 100, "stone": 25}, "type": "weapon", "tech": "hunting"},
	"bow": {"name": "Лук", "cost": {"wood": 100, "cloth": 50}, "type": "weapon", "tech": "hunting"},
	"campfire": {"name": "Костёр", "cost": {"wood": 100}, "type": "build", "tech": "woodwork"},
	"wall": {"name": "Деревянная стена", "cost": {"wood": 50}, "type": "build", "tech": "woodwork"},
	"floor": {"name": "Деревянный фундамент", "cost": {"wood": 100}, "type": "build", "tech": "woodwork"},
	"furnace": {"name": "Печь", "cost": {"stone": 200, "wood": 50}, "type": "build", "tech": "masonry"},
	"door": {"name": "Деревянная дверь", "cost": {"wood": 100}, "type": "build", "tech": "masonry"},
	"workbench": {"name": "Верстак", "cost": {"wood": 200, "stone": 100}, "type": "build", "tech": "metallurgy"},
	"bag": {"name": "Спальник", "cost": {"cloth": 25}, "type": "build", "tech": "metallurgy"},
}

var built := {"campfire": 0, "furnace": 0, "wall": 0, "floor": 0, "door": 0, "bag": 0, "workbench": 0}
var workbench_built := false


# предметы hotbar
const HOTBAR := [
	["wood", "Дерево", false],
	["stone", "Камень", false],
	["sulfur", "Сера", false],
	["iron", "Железо", false],
	["meat", "Мясо", true],
	["scrap", "Скрап", false],
]


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
	scrap = 0
	meat = 0
	water = 0
	kills = 0
	has_hatchet = false
	has_pickaxe = false
	has_bow = false
	has_spear = false
	workbench_built = false
	learned_techs.clear()
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


func hotbar_count(slot: int) -> int:
	var key: String = HOTBAR[slot][0]
	match key:
		"wood": return wood
		"stone": return stone
		"sulfur": return sulfur
		"iron": return iron
		"meat": return meat
		"scrap": return scrap
	return 0


func use_slot(slot: int) -> String:
	var key: String = HOTBAR[slot][0]
	if key == "meat":
		if meat > 0:
			eat()
			return "Съел мясо"
		return "Нет мяса"
	return ""


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
		"scrap": scrap += n
		"water": water += n
		"meat": meat += n


func harvest_bonus() -> float:
	return 2.0 if has_hatchet else 1.0


func mining_bonus() -> float:
	return 2.0 if has_pickaxe else 1.0


func attack_damage() -> float:
	var d := 30.0
	if has_spear:
		d *= 1.5
	if has_bow:
		d *= 1.25
	return d


# --- дерево технологий ---

func is_tech_learned(id: String) -> bool:
	return learned_techs.has(id)


func tech_available(id: String) -> bool:
	# можно изучить, если изучен пререквизит и ещё не изучена
	if learned_techs.has(id):
		return false
	var t: Dictionary = TECH_TREE[id]
	var prereq: String = t["prereq"]
	return prereq == "" or learned_techs.has(prereq)


func research(id: String) -> bool:
	if not tech_available(id):
		return false
	var t: Dictionary = TECH_TREE[id]
	var cost: int = t["cost"]
	if scrap < cost:
		return false
	scrap -= cost
	learned_techs[id] = true
	return true


func recipe_unlocked(id: String) -> bool:
	var tech: String = RECIPES[id]["tech"]
	return learned_techs.has(tech)


func has_resource(name: String, n: int) -> bool:
	match name:
		"wood": return wood >= n
		"stone": return stone >= n
		"sulfur": return sulfur >= n
		"iron": return iron >= n
		"cloth": return cloth >= n
		"metal": return metal >= n
		"scrap": return scrap >= n
	return false


func take_resource(name: String, n: int) -> void:
	match name:
		"wood": wood -= n
		"stone": stone -= n
		"sulfur": sulfur -= n
		"iron": iron -= n
		"cloth": cloth -= n
		"metal": metal -= n
		"scrap": scrap -= n


func can_craft(id: String) -> bool:
	if not recipe_unlocked(id):
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
		"workbench": workbench_built = true
		_: built[id] = built.get(id, 0) + 1
	return true
