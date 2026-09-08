extends Control
## Загрузочный экран: совет + прогресс, затем переход в игру.

const Kit := preload("res://scripts/ui_kit.gd")

const TIPS := [
	"Руби деревья — дерево нужно почти для всего.",
	"Следи за голодом: на нуле начнёшь терять здоровье.",
	"Кабан атакует, только если подойти близко. Медведь — всегда.",
	"Собери дерево и камень, чтобы скрафтить топор.",
	"Топор удваивает добычу дерева, кирка — камня и руды.",
	"Открой строительство и поставь фундамент — с него начинается база.",
	"Зелёный контур постройки — можно ставить, красный — нельзя.",
	"Постройки можно улучшать до камня и разбирать с возвратом ресурсов.",
	"Ставь метки на карте, чтобы не потерять базу.",
	"Разбивай бочки — из них сыпется скрап.",
	"Подойди к ящику и нажми «ВЗЯТЬ», чтобы забрать лут.",
	"В монументах лежат лучшие ящики — но там опасно.",
	"Построй верстак, чтобы изучать технологии за скрап.",
	"Компас сверху показывает, куда ты смотришь.",
]

var _bar: ProgressBar
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.065)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -320
	col.offset_right = 320
	col.offset_top = -120
	col.offset_bottom = 120
	col.add_theme_constant_override("separation", 16)
	add_child(col)

	var t := Kit.label("SCRAPLANDS", 52, Kit.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)

	var srv := "Одиночный мир"
	if GameState.active_server_id > 0:
		srv = "Сервер %d" % GameState.active_server_id
	var sl := Kit.label(srv, 18, Kit.GOLD)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sl)

	var tip := Kit.label(TIPS[randi() % TIPS.size()], 17, Kit.TXT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(0, 60)
	col.add_child(tip)

	_bar = Kit.bar(0, 100, Kit.ACCENT, 14.0)
	col.add_child(_bar)

	var l := Kit.label("Загрузка мира…", 14, Kit.TXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)


func _process(delta: float) -> void:
	_t += delta
	_bar.value = minf(100.0, _t / 1.6 * 100.0)
	if _t >= 1.7:
		set_process(false)
		GameState.run_active = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
