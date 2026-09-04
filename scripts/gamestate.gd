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
var return_to_pos := false    # вернуться на сохранённую позицию (после карты)

# инвентарь / hotbar
var selected_slot := 0
var build_mode := false
var build_kind := ""
var build_rot := 0.0


# --- ДЕРЕВО ТЕХНОЛОГИЙ (изучается в верстаке за скрап, как в Rust) ---
# tech id -> {name, cost (скрап), prereq (id или ""), unlocks (список рецептов)}
const TECH_TREE := {
	"gathering": {"name": "Собирательство", "cost": 75, "prereq": "", "unlocks": []},
	"masonry": {"name": "Каменное дело", "cost": 100, "prereq": "", "unlocks": ["furnace", "door"]},
	"metallurgy": {"name": "Металлургия", "cost": 150, "prereq": "masonry", "unlocks": ["bag"]},
	"weapons": {"name": "Оружейник", "cost": 200, "prereq": "", "unlocks": []},
}

# изученные технологии
var learned_techs := {}

# все рецепты (доступны только после изучения технологии)
const RECIPES := {
	"hatchet": {"name": "Каменный топор", "cost": {"wood": 25}, "type": "tool", "cat": "Инструменты", "tech": "", "time": 3.0},
	"pickaxe": {"name": "Каменная кирка", "cost": {"wood": 25}, "type": "tool", "cat": "Инструменты", "tech": "", "time": 3.0},
	"torch": {"name": "Факел", "cost": {"wood": 15, "cloth": 5}, "type": "tool", "cat": "Инструменты", "tech": "", "time": 2.0},
	"spear": {"name": "Копьё", "cost": {"wood": 50, "stone": 15}, "type": "weapon", "cat": "Оружие", "tech": "", "time": 5.0},
	"bow": {"name": "Лук", "cost": {"wood": 50, "cloth": 25}, "type": "weapon", "cat": "Оружие", "tech": "", "time": 5.0},
	"arrow": {"name": "Стрелы (x5)", "cost": {"wood": 20, "stone": 10}, "type": "ammo", "cat": "Оружие", "tech": "", "time": 2.0},
	"bandage": {"name": "Тканевый бинт", "cost": {"cloth": 10}, "type": "med", "cat": "Медицина", "tech": "", "time": 1.5},
	"campfire": {"name": "Костёр", "cost": {"wood": 100}, "type": "build", "cat": "Строительство", "tech": "", "time": 2.0},
	"wall": {"name": "Деревянная стена", "cost": {"wood": 50}, "type": "build", "cat": "Строительство", "tech": "", "time": 1.0},
	"floor": {"name": "Деревянный фундамент", "cost": {"wood": 100}, "type": "build", "cat": "Строительство", "tech": "", "time": 2.0},
	"furnace": {"name": "Печь", "cost": {"stone": 200, "wood": 50}, "type": "build", "cat": "Строительство", "tech": "masonry", "time": 6.0},
	"door": {"name": "Деревянная дверь", "cost": {"wood": 100}, "type": "build", "cat": "Строительство", "tech": "masonry", "time": 3.0},
	"workbench": {"name": "Верстак", "cost": {"wood": 200, "stone": 100}, "type": "build", "cat": "Строительство", "tech": "", "time": 8.0},
	"bag": {"name": "Спальник", "cost": {"cloth": 25}, "type": "build", "cat": "Строительство", "tech": "metallurgy", "time": 4.0},
	"cloth_shirt": {"name": "Тканевая рубаха", "cost": {"cloth": 20}, "type": "clothing", "cat": "Одежда", "tech": "", "time": 3.0},
	"cloth_pants": {"name": "Тканевые штаны", "cost": {"cloth": 15}, "type": "clothing", "cat": "Одежда", "tech": "", "time": 3.0},
	"boots": {"name": "Сапоги", "cost": {"cloth": 10}, "type": "clothing", "cat": "Одежда", "tech": "", "time": 2.0},
	"headband": {"name": "Повязка", "cost": {"cloth": 5}, "type": "clothing", "cat": "Одежда", "tech": "", "time": 1.5},
	"bone_armor": {"name": "Костяная броня", "cost": {"cloth": 20, "metal": 10}, "type": "clothing", "cat": "Броня", "tech": "", "time": 6.0},
}

var built := {"campfire": 0, "furnace": 0, "wall": 0, "floor": 0, "door": 0, "bag": 0, "workbench": 0}
var workbench_built := false
var arrows := 0
var has_torch := false

# очередь крафта: [{id, name, remaining, total}]
var _crafting: Array = []
var pending_build := ""  # постройка, завершившая крафт — войти в режим строительства


# --- БАЗА ПРЕДМЕТОВ (собственные названия/иконки/описания — НЕ копия Oxide) ---
# kind: resource/инструмент/оружие/боеприпас/медицина/одежда/броня
const ITEMS := {
	"wood": {"name": "Дерево", "icon": "wood", "stack": 9999, "cat": "Ресурсы", "desc": "Базовый материал для строительства и крафта."},
	"stone": {"name": "Камень", "icon": "stone", "stack": 9999, "cat": "Ресурсы", "desc": "Нужен для инструментов и построек."},
	"sulfur": {"name": "Сера", "icon": "sulfur", "stack": 9999, "cat": "Ресурсы", "desc": "Полезный ресурс для будущих рецептов."},
	"iron": {"name": "Железо", "icon": "iron", "stack": 9999, "cat": "Ресурсы", "desc": "Руда для металла."},
	"cloth": {"name": "Ткань", "icon": "cloth", "stack": 9999, "cat": "Ресурсы", "desc": "Для одежды и бинтов."},
	"metal": {"name": "Металл", "icon": "metal", "stack": 9999, "cat": "Ресурсы", "desc": "Прочный металл для брони и построек."},
	"scrap": {"name": "Скрап", "icon": "scrap", "stack": 9999, "cat": "Ресурсы", "desc": "Валюта изучения технологий."},
	"meat": {"name": "Мясо", "icon": "meat", "stack": 50, "cat": "Еда", "desc": "Восстанавливает голод. Съешь через хотбар."},
	"water": {"name": "Вода", "icon": "water", "stack": 50, "cat": "Еда", "desc": "Утоляет жажду."},
	"hatchet": {"name": "Каменный топор", "icon": "hatchet", "stack": 1, "cat": "Инструменты", "desc": "Добыча дерева в 2 раза быстрее."},
	"pickaxe": {"name": "Каменная кирка", "icon": "pickaxe", "stack": 1, "cat": "Инструменты", "desc": "Добыча камня и руды в 2 раза быстрее."},
	"torch": {"name": "Факел", "icon": "campfire", "stack": 1, "cat": "Инструменты", "desc": "Простой источник света."},
	"spear": {"name": "Копьё", "icon": "spear", "stack": 1, "cat": "Оружие", "desc": "+50% к урону в ближнем бою."},
	"bow": {"name": "Лук", "icon": "bow", "stack": 1, "cat": "Оружие", "desc": "+25% к урону."},
	"arrow": {"name": "Стрела", "icon": "spear", "stack": 64, "cat": "Боеприпасы", "desc": "Боеприпас для лука."},
	"bandage": {"name": "Бинт", "icon": "cloth", "stack": 10, "cat": "Медицина", "desc": "Восстанавливает 30 здоровья."},
	"cloth_shirt": {"name": "Тканевая рубаха", "icon": "cloth", "stack": 1, "cat": "Одежда", "slot": "chest", "desc": "Лёгкая рубаха из ткани."},
	"cloth_pants": {"name": "Тканевые штаны", "icon": "cloth", "stack": 1, "cat": "Одежда", "slot": "legs", "desc": "Простые штаны."},
	"boots": {"name": "Сапоги", "icon": "cloth", "stack": 1, "cat": "Одежда", "slot": "feet", "desc": "Прочная обувь."},
	"headband": {"name": "Повязка", "icon": "cloth", "stack": 1, "cat": "Одежда", "slot": "head", "desc": "Головная повязка."},
	"bone_armor": {"name": "Костяная броня", "icon": "metal", "stack": 1, "cat": "Броня", "slot": "chest", "desc": "Защищает грудь от урона."},
}

const EQUIP_SLOTS := ["head", "chest", "legs", "feet"]

# дискретные предметы (всё кроме ресурсов) — id -> кол-во
var items := {}
# надетое снаряжение: слот -> id предмета
var equipped := {}
# хотбар: 6 слотов с id предметов (или "")
var hotbar: Array = ["wood", "stone", "sulfur", "iron", "meat", "scrap"]
# предмет «в руке» при перетаскивании: {id, count} или {}
var held := {}
# выбранный слот хотбара для назначения (в инвентаре)
var assigning_hotbar := -1


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
	arrows = 0
	has_hatchet = false
	has_pickaxe = false
	has_bow = false
	has_spear = false
	has_torch = false
	workbench_built = false
	items.clear()
	equipped.clear()
	hotbar = ["wood", "stone", "sulfur", "iron", "meat", "scrap"]
	held = {}
	assigning_hotbar = -1
	learned_techs.clear()
	for k in built:
		built[k] = 0
	_crafting.clear()
	pending_build = ""


const SURVIVAL_PERIOD := 600.0  # 10 минут на цикл списания
const THIRST_DRAIN := 15.0       # -15 жажды за 10 минут
const HUNGER_DRAIN := 10.0       # -10 голода за 10 минут (медленнее)

var _survival_acc := 0.0


func tick(delta: float) -> void:
	# списание голода/жажды по накопительному таймеру (раз в 10 минут),
	# чтобы не ускоряться при открытии меню и не давать двойного списания
	_survival_acc += delta
	var steps := 0
	while _survival_acc >= SURVIVAL_PERIOD:
		_survival_acc -= SURVIVAL_PERIOD
		steps += 1
	if steps > 0:
		thirst = maxf(0.0, thirst - THIRST_DRAIN * steps)
		hunger = maxf(0.0, hunger - HUNGER_DRAIN * steps)
	# урон только если показатель на нуле
	if hunger <= 0.0:
		hp = maxf(0.0, hp - delta * 1.2)
	if thirst <= 0.0:
		hp = maxf(0.0, hp - delta * 2.0)
	tick_craft(delta)


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
	if slot < 0 or slot >= hotbar.size():
		return 0
	var key: String = hotbar[slot]
	if key == "":
		return 0
	return count(key)


func use_slot(slot: int) -> String:
	if slot < 0 or slot >= hotbar.size():
		return ""
	var key: String = hotbar[slot]
	if key == "":
		return ""
	if key == "meat":
		if meat > 0:
			eat()
			return "Съел мясо"
		return "Нет мяса"
	elif key == "water":
		if water > 0:
			drink()
			return "Выпил воды"
		return "Нет воды"
	elif key == "bandage":
		if count("bandage") > 0:
			remove_item("bandage", 1)
			hp = minf(max_hp, hp + 30.0)
			return "Перевязал раны"
		return "Нет бинтов"
	return ""


# --- предметы и инвентарь ---

func count(id: String) -> int:
	match id:
		"wood": return wood
		"stone": return stone
		"sulfur": return sulfur
		"iron": return iron
		"cloth": return cloth
		"metal": return metal
		"scrap": return scrap
		"meat": return meat
		"water": return water
		_: return int(items.get(id, 0))


func item_name(id: String) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else id


func item_icon(id: String) -> String:
	return ITEMS[id]["icon"] if ITEMS.has(id) else "wood"


func item_desc(id: String) -> String:
	return ITEMS[id]["desc"] if ITEMS.has(id) else ""


func item_stack(id: String) -> int:
	return ITEMS[id]["stack"] if ITEMS.has(id) else 1


func item_cat(id: String) -> String:
	return ITEMS[id]["cat"] if ITEMS.has(id) else ""


func is_resource(id: String) -> bool:
	return id in ["wood", "stone", "sulfur", "iron", "cloth", "metal", "scrap", "meat", "water"]


func add_item(id: String, n: int) -> void:
	if is_resource(id):
		add_resource(id, n)
	else:
		items[id] = int(items.get(id, 0)) + n
	_sync_tools()


func remove_item(id: String, n: int) -> bool:
	if count(id) < n:
		return false
	if is_resource(id):
		take_resource(id, n)
	else:
		items[id] = int(items.get(id, 0)) - n
		if items[id] <= 0:
			items.erase(id)
	_sync_tools()
	return true


# держать флаги инструментов в согласии с предметами инвентаря
func _sync_tools() -> void:
	has_hatchet = items.has("hatchet")
	has_pickaxe = items.has("pickaxe")
	has_bow = items.has("bow")
	has_spear = items.has("spear")
	has_torch = items.has("torch")
	arrows = int(items.get("arrow", 0))


func can_stack(id: String, cur: int, add: int) -> bool:
	return cur + add <= item_stack(id)


# экипировать предмет из инвентаря в слот
func equip_item(id: String) -> bool:
	var slot: String = ITEMS[id].get("slot", "")
	if slot == "":
		return false
	if count(id) <= 0:
		return false
	# вернуть старый предмет слота обратно в инвентарь
	if equipped.has(slot):
		add_item(equipped[slot], 1)
	remove_item(id, 1)
	equipped[slot] = id
	return true


# снять предмет со слота обратно в инвентарь
func unequip(slot: String) -> void:
	if equipped.has(slot):
		add_item(equipped[slot], 1)
		equipped.erase(slot)


# слот экипировки для предмета (если это одежда/броня)
func equip_slot_of(id: String) -> String:
	return ITEMS[id].get("slot", "") if ITEMS.has(id) else ""


# надет ли предмет с заданным id
func is_equipped(id: String) -> bool:
	return equipped.values().has(id)


# --- сохранение инвентаря ---

func save_inventory() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("res", "wood", wood)
	cfg.set_value("res", "stone", stone)
	cfg.set_value("res", "sulfur", sulfur)
	cfg.set_value("res", "iron", iron)
	cfg.set_value("res", "cloth", cloth)
	cfg.set_value("res", "metal", metal)
	cfg.set_value("res", "scrap", scrap)
	cfg.set_value("res", "meat", meat)
	cfg.set_value("res", "water", water)
	cfg.set_value("inv", "items", items)
	cfg.set_value("inv", "equipped", equipped)
	cfg.set_value("inv", "hotbar", hotbar)
	cfg.save(SAVE_PATH)


func load_inventory() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	if not cfg.has_section("inv"):
		return false
	wood = int(cfg.get_value("res", "wood", wood))
	stone = int(cfg.get_value("res", "stone", stone))
	sulfur = int(cfg.get_value("res", "sulfur", sulfur))
	iron = int(cfg.get_value("res", "iron", iron))
	cloth = int(cfg.get_value("res", "cloth", cloth))
	metal = int(cfg.get_value("res", "metal", metal))
	scrap = int(cfg.get_value("res", "scrap", scrap))
	meat = int(cfg.get_value("res", "meat", meat))
	water = int(cfg.get_value("res", "water", water))
	items = cfg.get_value("inv", "items", {})
	equipped = cfg.get_value("inv", "equipped", {})
	var hb = cfg.get_value("inv", "hotbar", hotbar)
	if hb is Array and hb.size() == 6:
		hotbar = hb
	# синхронизировать флаги инструментов с предметами
	has_hatchet = items.has("hatchet")
	has_pickaxe = items.has("pickaxe")
	has_bow = items.has("bow")
	has_spear = items.has("spear")
	has_torch = items.has("torch")
	arrows = int(items.get("arrow", 0))
	return true


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
	var b := 2.0 if has_hatchet else 1.0
	if is_tech_learned("gathering"):
		b *= 1.5
	return b


func mining_bonus() -> float:
	var b := 2.0 if has_pickaxe else 1.0
	if is_tech_learned("gathering"):
		b *= 1.5
	return b


func attack_damage() -> float:
	var d := 30.0
	if has_spear:
		d *= 1.5
	if has_bow:
		d *= 1.25
	if is_tech_learned("weapons"):
		d *= 1.4
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
	if tech == "":
		return true
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
	# базовые рецепты доступны сразу, продвинутые — только после изучения в верстаке
	if not RECIPES.has(id):
		return false
	if not recipe_unlocked(id):
		return false
	var cost: Dictionary = RECIPES[id]["cost"]
	for r in cost:
		if not has_resource(r, cost[r]):
			return false
	return true


func craft(id: String) -> bool:
	# мгновенный крафт (совместимость) — реально используется start_craft
	if not can_craft(id):
		return false
	var cost: Dictionary = RECIPES[id]["cost"]
	for r in cost:
		take_resource(r, cost[r])
	_finish_craft(id)
	return true


func start_craft(id: String) -> bool:
	# крафт с затратой времени: списываем ресурсы и ставим в очередь
	if not can_craft(id):
		return false
	var cost: Dictionary = RECIPES[id]["cost"]
	for r in cost:
		take_resource(r, cost[r])
	var t: float = RECIPES[id].get("time", 0.0)
	if t <= 0.0:
		_finish_craft(id)
	else:
		_crafting.append({"id": id, "name": RECIPES[id]["name"], "remaining": t, "total": t})
	return true


func tick_craft(delta: float) -> void:
	if _crafting.is_empty():
		return
	var done: Array = []
	for c in _crafting:
		c["remaining"] -= delta
		if c["remaining"] <= 0.0:
			done.append(c)
	for c in done:
		_crafting.erase(c)
		_finish_craft(c["id"])


func _finish_craft(id: String) -> void:
	match id:
		"hatchet":
			items["hatchet"] = int(items.get("hatchet", 0)) + 1
			has_hatchet = true
			auto_assign_hotbar("hatchet")
		"pickaxe":
			items["pickaxe"] = int(items.get("pickaxe", 0)) + 1
			has_pickaxe = true
			auto_assign_hotbar("pickaxe")
		"bow":
			items["bow"] = int(items.get("bow", 0)) + 1
			has_bow = true
			auto_assign_hotbar("bow")
		"spear":
			items["spear"] = int(items.get("spear", 0)) + 1
			has_spear = true
			auto_assign_hotbar("spear")
		"torch":
			items["torch"] = int(items.get("torch", 0)) + 1
			has_torch = true
			auto_assign_hotbar("torch")
		"arrow":
			items["arrow"] = int(items.get("arrow", 0)) + 5
			arrows += 5
		"bandage":
			items["bandage"] = int(items.get("bandage", 0)) + 1
		"cloth_shirt", "cloth_pants", "boots", "headband", "bone_armor":
			items[id] = int(items.get(id, 0)) + 1
		"workbench": workbench_built = true
		_:
			if RECIPES[id]["type"] == "build":
				built[id] = built.get(id, 0) + 1
				pending_build = id


# автоматически положить инструмент в первый свободный слот хотбара
func auto_assign_hotbar(id: String) -> void:
	if hotbar.has(id):
		return  # уже в хотбаре
	for i in range(hotbar.size()):
		if hotbar[i] == "":
			hotbar[i] = id
			return
	# нет свободного — кладём в выбранный слот
	hotbar[selected_slot] = id


# отменить крафт в очереди (вернуть ресурсы)
func cancel_craft(index: int) -> bool:
	if index < 0 or index >= _crafting.size():
		return false
	var c: Dictionary = _crafting[index]
	var cost: Dictionary = RECIPES[c["id"]]["cost"]
	for r in cost:
		add_resource(r, cost[r])
	_crafting.remove_at(index)
	return true


func crafting_queue() -> Array:
	return _crafting
