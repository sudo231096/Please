extends Node
## Mobile FPS controls bridge.

var move_vector := Vector2.ZERO
var look_delta := Vector2.ZERO
var jump_queued := false
var fire_held := false
var fire_pressed := false
var reload_queued := false
var switch_queued := false
var ui_open := false


func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d
