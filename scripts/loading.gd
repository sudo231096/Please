extends Control
## Загрузочный экран: случайный совет + переход в игру.

const TIPS := [
	"Руби деревья — дерево нужно почти для всего.",
	"Следи за голодом: если он на нуле, теряешь здоровье.",
	"Кабан атакует только если подойти близко. Медведь — всегда.",
	"Собери камень и дерево, чтобы скрафтить топор.",
	"Топор удваивает добычу дерева.",
	"Кирка удваивает добычу камня и руды.",
	"Копьё и лук повышают твой урон.",
	"Сера и железо нужны для будущих крафтов.",
	"Убил оленя — получил много мяса. Съешь его (E).",
	"Забирайся на горы — оттуда видно всю пустошь.",
	"Нажимай C, чтобы открыть меню крафта.",
	"Ночью звери ближе, чем кажется.",
	"Построй костёр, чтобы было куда возвращаться.",
	"Спальник отмечает точку возрождения.",
	"Не заходи в воду без нужды — жажда растёт.",
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	# короткая пауза, затем игра
	await get_tree().create_timer(2.0).timeout
	_start()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "SCRAPLANDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.05
	title.anchor_right = 0.95
	title.anchor_top = 0.3
	title.anchor_bottom = 0.42
	title.add_theme_font_size_override("font_size", 52)
	title.modulate = Color(0.95, 0.85, 0.6)
	add_child(title)

	# случайный совет
	var tip: String = TIPS[randi() % TIPS.size()]
	var tip_label := Label.new()
	tip_label.text = "Совет: " + tip
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tip_label.anchor_left = 0.1
	tip_label.anchor_right = 0.9
	tip_label.anchor_top = 0.45
	tip_label.anchor_bottom = 0.65
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.add_theme_font_size_override("font_size", 26)
	tip_label.modulate = Color(0.85, 0.9, 0.85)
	add_child(tip_label)

	var loading := Label.new()
	loading.text = "Загрузка..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.anchor_top = 1.0
	loading.anchor_bottom = 1.0
	loading.offset_top = -80
	loading.offset_bottom = -40
	loading.add_theme_font_size_override("font_size", 22)
	loading.modulate = Color(0.6, 0.65, 0.6)
	add_child(loading)


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
