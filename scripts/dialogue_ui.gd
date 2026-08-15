extends CanvasLayer
## Окно диалога.

signal closed

var _panel: PanelContainer
var _name_l: Label
var _text_l: Label
var _btn: Button
var _lines: Array = []
var _idx := 0
var _dialogue_id := ""


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.94
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.96)
	sb.border_color = Color(0.55, 0.7, 0.85, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)

	_name_l = Label.new()
	_name_l.add_theme_font_size_override("font_size", 26)
	_name_l.modulate = Color(0.75, 0.9, 1.0)
	v.add_child(_name_l)

	_text_l = Label.new()
	_text_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_l.add_theme_font_size_override("font_size", 22)
	_text_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text_l)

	_btn = Button.new()
	_btn.text = "Далее"
	_btn.custom_minimum_size = Vector2(0, 52)
	_btn.add_theme_font_size_override("font_size", 22)
	_btn.pressed.connect(_advance)
	v.add_child(_btn)


func open_dialogue(id: String, speaker: String, lines: Array) -> void:
	_dialogue_id = id
	_lines = lines.duplicate()
	_idx = 0
	_name_l.text = speaker
	visible = true
	Controls.ui_open = true
	Controls.move_vector = Vector2.ZERO
	_show_line()


func _show_line() -> void:
	if _idx >= _lines.size():
		_close()
		return
	_text_l.text = str(_lines[_idx])
	_btn.text = "Далее" if _idx < _lines.size() - 1 else "Закрыть"


func _advance() -> void:
	_idx += 1
	_show_line()


func _close() -> void:
	visible = false
	Controls.ui_open = false
	Story.dialogue_finished.emit(_dialogue_id)
	closed.emit()
