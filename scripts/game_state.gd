extends Node
## Match state: score, weapons unlock flags.

signal score_changed
signal match_over(won: bool)

var player_kills := 0
var bot_kills := 0
var kill_limit := 10
var match_active := false


func reset_match() -> void:
	player_kills = 0
	bot_kills = 0
	match_active = true
	score_changed.emit()


func add_player_kill() -> void:
	if not match_active:
		return
	player_kills += 1
	score_changed.emit()
	if player_kills >= kill_limit:
		match_active = false
		match_over.emit(true)


func add_bot_kill() -> void:
	if not match_active:
		return
	bot_kills += 1
	score_changed.emit()
	if bot_kills >= kill_limit:
		match_active = false
		match_over.emit(false)
