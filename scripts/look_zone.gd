extends Control
## Right half look pad + fire if dragging near fire btn is separate.

var _touch := -1
var _last := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# right 55% of screen for look
	anchor_left = 0.45


func _gui_input(event: InputEvent) -> void:
	if Controls.ui_open:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_last = event.position
		elif (not event.pressed) and event.index == _touch:
			_touch = -1
	elif event is InputEventScreenDrag and event.index == _touch:
		var d: Vector2 = event.position - _last
		_last = event.position
		Controls.look_delta += d
