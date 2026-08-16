extends Node
## Глобальное состояние: очки, волна, рекорд.

const SAVE_PATH := "user://skibidi.cfg"

var high_score := 0
var score := 0
var wave := 1


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("g", "high_score", 0))


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("g", "high_score", high_score)
	cfg.save(SAVE_PATH)


func reset_run() -> void:
	score = 0
	wave = 1


func add_score(n: int) -> void:
	score += n
	if score > high_score:
		high_score = score
		save_data()
