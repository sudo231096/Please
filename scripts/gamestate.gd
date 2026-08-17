extends Node
## Глобальное состояние: уровни, очки, рекорд.

const SAVE_PATH := "user://skibidi.cfg"
const MAX_LEVEL := 50

var high_score := 0
var score := 0
var unlocked := 1   # сколько уровней открыто
var current := 1    # какой уровень играем


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("g", "high_score", 0))
		unlocked = clampi(int(cfg.get_value("g", "unlocked", 1)), 1, MAX_LEVEL)


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("g", "high_score", high_score)
	cfg.set_value("g", "unlocked", unlocked)
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
