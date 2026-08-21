extends Node
## Глобальное состояние: уровни, очки, монеты, прокачка, рекорд.

const SAVE_PATH := "user://skibidi.cfg"
const MAX_LEVEL := 50

const BASE_DAMAGE := 34.0
const DAMAGE_PER_LEVEL := 6.0
const BASE_MAX_HP := 100
const HP_PER_LEVEL := 15

const PROMO_CODE := "SKIBIDI"
const PROMO_REWARD := 1000000

var high_score := 0
var score := 0
var unlocked := 1   # сколько уровней открыто
var current := 1    # какой уровень играем
var coins := 0
var damage_level := 0
var hp_level := 0
var promo_redeemed := false
var selected_hero := 0  # 0 = камерамен, 1 = спикер-мен, 2 = ТВ-мен


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("g", "high_score", 0))
		unlocked = clampi(int(cfg.get_value("g", "unlocked", 1)), 1, MAX_LEVEL)
		coins = int(cfg.get_value("g", "coins", 0))
		damage_level = int(cfg.get_value("g", "damage_level", 0))
		hp_level = int(cfg.get_value("g", "hp_level", 0))
		promo_redeemed = bool(cfg.get_value("g", "promo_redeemed", false))
		selected_hero = int(cfg.get_value("g", "selected_hero", 0))


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("g", "high_score", high_score)
	cfg.set_value("g", "unlocked", unlocked)
	cfg.set_value("g", "coins", coins)
	cfg.set_value("g", "damage_level", damage_level)
	cfg.set_value("g", "hp_level", hp_level)
	cfg.set_value("g", "promo_redeemed", promo_redeemed)
	cfg.set_value("g", "selected_hero", selected_hero)
	cfg.save(SAVE_PATH)


func start_level(level: int) -> void:
	current = clampi(level, 1, MAX_LEVEL)
	score = 0


func complete_level(level: int) -> void:
	if level >= unlocked and unlocked < MAX_LEVEL:
		unlocked = level + 1
		save_data()


func add_score(n: int) -> void:
	score += n
	if score > high_score:
		high_score = score
		save_data()


func add_coins(n: int) -> void:
	coins += n
	save_data()


# --- прокачка ---
func damage_upgrade_cost() -> int:
	return 40 + damage_level * 25


func hp_upgrade_cost() -> int:
	return 40 + hp_level * 25


func buy_damage() -> bool:
	var c := damage_upgrade_cost()
	if coins >= c:
		coins -= c
		damage_level += 1
		save_data()
		return true
	return false


func buy_hp() -> bool:
	var c := hp_upgrade_cost()
	if coins >= c:
		coins -= c
		hp_level += 1
		save_data()
		return true
	return false


func player_damage() -> float:
	return BASE_DAMAGE + damage_level * DAMAGE_PER_LEVEL


func player_max_hp() -> float:
	return float(BASE_MAX_HP + hp_level * HP_PER_LEVEL)


func select_hero(id: int) -> void:
	selected_hero = clampi(id, 0, 2)
	save_data()


# --- промокод ---
func redeem_promo(code: String) -> String:
	if promo_redeemed:
		return "Промокод уже использован"
	var c := code.strip_edges().to_upper()
	if c == PROMO_CODE:
		promo_redeemed = true
		coins += PROMO_REWARD
		save_data()
		return "Промокод принят! +%d монет" % PROMO_REWARD
	return "Неверный промокод"
