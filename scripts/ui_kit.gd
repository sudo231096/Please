extends RefCounted
class_name UIKit
## Общие элементы интерфейса в стиле Rust Mobile: полупрозрачные панели,
## крупные сенсорные кнопки, подсветка выбранного, плавные анимации.

const BG := Color(0.07, 0.075, 0.085, 0.88)      # фон панели
const BG_SOFT := Color(0.11, 0.115, 0.13, 0.82)  # фон вложенной панели
const LINE := Color(0.32, 0.33, 0.36, 0.9)       # рамка
const ACCENT := Color(0.85, 0.45, 0.16)          # оранжевый акцент Rust
const ACCENT_DIM := Color(0.5, 0.28, 0.12)
const TXT := Color(0.90, 0.90, 0.88)
const TXT_DIM := Color(0.62, 0.63, 0.65)
const OK := Color(0.45, 0.85, 0.4)
const BAD := Color(0.92, 0.35, 0.32)
const GOLD := Color(1.0, 0.82, 0.28)

# минимальный размер сенсорной кнопки (комфортно пальцем)
const TOUCH := 52.0


static func panel(bg: Color = BG, radius: int = 10, border: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border:
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = LINE
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func make_panel(bg: Color = BG, radius: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel(bg, radius))
	return p


## Кнопка с крупной областью нажатия и подсветкой
static func button(text: String, font_size: int = 20, accent: bool = false, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = min_size if min_size != Vector2.ZERO else Vector2(0, TOUCH)
	var base := ACCENT if accent else Color(0.16, 0.165, 0.19, 0.95)
	var normal := panel(base, 8)
	var hover := panel(base.lightened(0.12), 8)
	var pressed := panel(base.darkened(0.18), 8)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", normal)
	var dis := panel(Color(0.13, 0.13, 0.14, 0.7), 8)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04) if accent else TXT)
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.04, 0.03) if accent else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", TXT_DIM)
	return b


## Круглая/квадратная иконочная кнопка (для боковых панелей меню)
static func icon_button(glyph: String, caption: String, size: float = 58.0) -> Button:
	var b := button(glyph, 24, false, Vector2(size, size))
	b.tooltip_text = caption
	return b


static func label(text: String, size: int = 18, color: Color = TXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Полоска прогресса (опыт, здоровье, голод…)
static func bar(value: float, maxv: float, color: Color, height: float = 12.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = maxv
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.05, 0.05, 0.06, 0.9)
	bgs.corner_radius_top_left = 5
	bgs.corner_radius_top_right = 5
	bgs.corner_radius_bottom_left = 5
	bgs.corner_radius_bottom_right = 5
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.corner_radius_top_left = 5
	fg.corner_radius_top_right = 5
	fg.corner_radius_bottom_left = 5
	fg.corner_radius_bottom_right = 5
	pb.add_theme_stylebox_override("background", bgs)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


## Плашка валюты: иконка + число + кнопка «+»
static func currency(glyph: String, amount: int, color: Color) -> PanelContainer:
	var p := make_panel(Color(0.05, 0.05, 0.06, 0.85), 14)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	h.add_child(label(glyph, 16, color))
	var l := label(_fmt(amount), 16, Color(0.95, 0.95, 0.92))
	l.name = "Amount"
	h.add_child(l)
	return p


static func _fmt(n: int) -> String:
	# 1234567 → 1.2M, 12345 → 12.3K
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.1fK" % (n / 1000.0)
	return str(n)


## Плавное появление элемента
static func fade_in(node: CanvasItem, dur: float = 0.18) -> void:
	node.modulate.a = 0.0
	var t := node.create_tween()
	t.tween_property(node, "modulate:a", 1.0, dur)


## Пульсация для привлечения внимания (например, «награда готова»)
static func pulse(node: CanvasItem) -> void:
	var t := node.create_tween().set_loops()
	t.tween_property(node, "modulate:a", 0.55, 0.6)
	t.tween_property(node, "modulate:a", 1.0, 0.6)
