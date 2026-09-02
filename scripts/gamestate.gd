extends Node
## Глобальное состояние выживания: здоровье, голод, жажда, инвентарь, настройки.

const SAVE_PATH := "user://scraplands.cfg"

var hp := 100.0
var max_hp := 100.0
var hunger := 100.0
var thirst := 100.0
var stone := 1
var meat := 0
var water := 0
var kills := 0

# настройки
var mouse_sens := 0.0025
var buttons_left := true  # true = джойстик слева, false = справа


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
	stone = 1
	meat = 0
	water = 0
	kills = 0


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


func add_meat(n: int) -> void:
	meat += n
