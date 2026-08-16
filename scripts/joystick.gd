extends Control
## Виртуальный джойстик.

signal dir_changed(dir: Vector2)

var _radius := 80.0
var _knob_r := 34.0
var _knob_pos := Vector2.ZERO
var _touch := -1
var _dir := Vector2.ZERO


func _ready() -> void:
	size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, _radius, Color(1, 1, 1, 0.12))
	draw_arc(c, _radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	draw_circle(c + _knob_pos, _knob_r, Color(1, 1, 1, 0.45))


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			var c := position + size * 0.5
			if (event.position - c).length() <= _radius + 60.0:
				_touch = event.index
				_update(event.position)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_knob_pos = Vector2.ZERO
			_dir = Vector2.ZERO
			queue_redraw()
			dir_changed.emit(_dir)
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)


func _update(pos: Vector2) -> void:
	var c := position + size * 0.5
	var d := pos - c
	if d.length() > _radius:
		d = d.normalized() * _radius
	_knob_pos = d
	_dir = d / _radius
	queue_redraw()
	dir_changed.emit(_dir)
