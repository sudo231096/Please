extends Node
## Прогресс по уровням (1..250).

const SAVE_PATH := "user://progress.cfg"
const MAX_LEVEL := 250

var unlocked := 1
var current := 1


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		unlocked = clampi(int(cfg.get_value("p", "unlocked", 1)), 1, MAX_LEVEL)
	else:
		unlocked = 1
		save_data()


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "unlocked", unlocked)
	cfg.save(SAVE_PATH)


func complete_level(level: int) -> void:
	if level >= unlocked and unlocked < MAX_LEVEL:
		unlocked = level + 1
		save_data()
