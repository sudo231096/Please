extends Node
## Глобальное состояние выживания: здоровье, голод, жажда, инвентарь.

const SAVE_PATH := "user://scraplands.cfg"

var hp := 100.0
var max_hp := 100.0
var hunger := 100.0   # 0 = голодный (теряет HP)
var thirst := 100.0   # 0 = жажда (теряет HP)
var stone := 1        # камень при появлении
var meat := 0         # еда (мясо)
var water := 0        # вода
var kills := 0


func _ready() -> void:
	reset_run()


func reset_run() -> void:
	hp = 100.0
	max_hp = 100.0
	hunger = 100.0
	thirst = 100.0
	stone = 1   # камень при появлении
	meat = 0
	water = 0
	kills = 0


func tick(delta: float) -> void:
	# голод и жажда медленно падают
	hunger = maxf(0.0, hunger - delta * 0.35)
	thirst = maxf(0.0, thirst - delta * 0.5)
	# если голоден/жажден — теряем здоровье
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
