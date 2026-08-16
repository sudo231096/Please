extends Node
## Прогресс по уровням (1..250) + монеты + магазин (урон, скины).

const SAVE_PATH := "user://progress.cfg"
const MAX_LEVEL := 250

const BASE_DAMAGE := 34
const DAMAGE_PER_LEVEL := 8
const BASE_MAX_HP := 100

## Скины: id -> описание. 1 = щит, 2 = +урон, 3 = +HP.
const SKIN_INFO := {
	1: {"name": "Щит", "desc": "Щит на 2 удара", "cost": 200},
	2: {"name": "Сила", "desc": "+15,5% урона", "cost": 400},
	3: {"name": "Здоровье", "desc": "+50,2% HP", "cost": 600},
}

signal coins_changed
signal shop_changed

var unlocked := 1
var current := 1
var coins := 0
var damage_level := 0
var owned_skins := {}   # {1: true, ...}
var selected_skin := 0  # 0 = без скина


func _ready() -> void:
	load_data()


# --- Экономика ---
func damage_upgrade_cost() -> int:
	return 50 * (damage_level + 1)


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit()
	save_data()


func buy_damage_upgrade() -> bool:
	var cost := damage_upgrade_cost()
	if coins >= cost:
		coins -= cost
		damage_level += 1
		save_data()
		shop_changed.emit()
		coins_changed.emit()
		return true
	return false


func buy_skin(id: int) -> bool:
	if not SKIN_INFO.has(id) or owned_skins.has(id):
		return false
	var cost: int = SKIN_INFO[id]["cost"]
	if coins >= cost:
		coins -= cost
		owned_skins[id] = true
		selected_skin = id
		save_data()
		shop_changed.emit()
		coins_changed.emit()
		return true
	return false


func select_skin(id: int) -> void:
	selected_skin = id
	save_data()
	shop_changed.emit()


# --- Баффы (для игрока) ---
func player_max_hp() -> int:
	var hp := BASE_MAX_HP
	if selected_skin == 3:
		hp = int(round(hp * 1.502))
	return hp


func player_damage() -> int:
	var d := float(BASE_DAMAGE)
	if selected_skin == 2:
		d *= 1.155
	d += float(damage_level * DAMAGE_PER_LEVEL)
	return int(round(d))


func shield_hits() -> int:
	return 2 if selected_skin == 1 else 0


# --- Сохранение ---
func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlocked = clampi(int(cfg.get_value("p", "unlocked", 1)), 1, MAX_LEVEL)
		coins = int(cfg.get_value("p", "coins", 0))
		damage_level = int(cfg.get_value("p", "damage_level", 0))
		selected_skin = int(cfg.get_value("p", "selected_skin", 0))
		for k in [1, 2, 3]:
			if cfg.get_value("p", "skin_" + str(k), false):
				owned_skins[k] = true
	else:
		unlocked = 1
		save_data()


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "unlocked", unlocked)
	cfg.set_value("p", "coins", coins)
	cfg.set_value("p", "damage_level", damage_level)
	cfg.set_value("p", "selected_skin", selected_skin)
	for k in [1, 2, 3]:
		cfg.set_value("p", "skin_" + str(k), owned_skins.has(k))
	cfg.save(SAVE_PATH)


func complete_level(level: int) -> void:
	if level >= unlocked and unlocked < MAX_LEVEL:
		unlocked = level + 1
		save_data()
