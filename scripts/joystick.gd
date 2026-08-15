extends Control
## Виртуальный джойстик.

const RADIUS := 110.0
const KNOB := 44.0

var _knob := Vector2.ZERO
var _touch := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	anchor_top = 1.0
	anchor_bottom = 1.0
	var m := 24.0
	offset_left = m
	offset_right = m + RADIUS * 2.0
	offset_top = -m - RADIUS * 2.0
	offset_bottom = -m


func _gui_input(event: InputEvent) -> void:
	if Controls.ui_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)


func _update(local_pos: Vector2) -> void:
	var d := local_pos - size * 0.5
	d = d.limit_length(RADIUS)
	_knob = d
	Controls.move_vector = d / RADIUS
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	Controls.move_vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(0.05, 0.07, 0.1, 0.45))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
	draw_circle(c + _knob, KNOB, Color(0.85, 0.9, 1.0, 0.85))
