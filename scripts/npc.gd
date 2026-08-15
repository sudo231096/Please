extends StaticBody3D
## NPC для диалогов.

@export var npc_id := "ira"
@export var display_name := "Ира"

var _label: Label3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build_visual()
	_label = Label3D.new()
	_label.text = display_name
	_label.font_size = 48
	_label.position = Vector3(0, 2.15, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.85, 0.95, 1.0)
	add_child(_label)


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.2
	body.mesh = cap
	var mat := StandardMaterial3D.new()
	match npc_id:
		"ira":
			mat.albedo_color = Color(0.35, 0.45, 0.55)
		"oldman":
			mat.albedo_color = Color(0.4, 0.32, 0.28)
		_:
			mat.albedo_color = Color(0.4, 0.4, 0.45)
	body.material_override = mat
	body.position = Vector3(0, 1.0, 0)
	add_child(body)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	head.mesh = sm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.86, 0.7, 0.55)
	head.material_override = hm
	head.position = Vector3(0, 1.75, 0)
	add_child(head)

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.5
	col.shape = cs
	col.position = Vector3(0, 1.05, 0)
	add_child(col)


func get_prompt() -> String:
	return "[E] Говорить: %s" % display_name


func interact(_player: Node) -> void:
	var ui = get_tree().get_first_node_in_group("dialogue_ui")
	if ui == null:
		return
	match npc_id:
		"ira":
			_talk_ira(ui)
		"oldman":
			_talk_oldman(ui)


func _talk_ira(ui: Node) -> void:
	if not Story.has_flag("met_ira"):
		Story.set_flag("met_ira")
		ui.open_dialogue("ira_intro", "Ира", [
			"Ты… живой. Хорошо. Я уже думала, костёр сторожит только ветер.",
			"Меня зовут Ира. Держимся у вышки — тут хоть связь иногда ловит.",
			"Рация молчит. Нужна батарейка. На складе у обрыва ещё валялись ящики.",
			"Принеси — и попробуем услышать, кто ещё дышит в Ashveil.",
		])
	elif Story.has_item("battery") and not Story.has_flag("radio_fixed"):
		Story.consume_item("battery")
		Story.set_flag("radio_fixed")
		ui.open_dialogue("ira_radio", "Ира", [
			"Есть! Давай сюда…",
			"…Шшш. Слышишь? Северные ворота. Голос старый, хриплый.",
			"Это Старик. Он не пускает никого без причины. Иди к нему.",
			"И… будь осторожен. Туман там гуще, чем должен быть.",
		])
	elif Story.has_flag("radio_fixed") and not Story.has_flag("opened_gate"):
		ui.open_dialogue("ira_wait", "Ира", [
			"Я останусь на частоте. Если ворота откроются — дам знать лагерю.",
			"Ты справишься. Просто не слушай шёпот в тумане слишком долго.",
		])
	elif Story.has_flag("opened_gate"):
		ui.open_dialogue("ira_end", "Ира", [
			"Ты открыл проход… Значит, история не кончилась вместе с пеплом.",
			"Иди. А я прикрою тебе спину по рации.",
		])
	else:
		ui.open_dialogue("ira_hint", "Ира", [
			"Склад у обрыва, к востоку от костра. Ищи ящик с синей меткой.",
		])


func _talk_oldman(ui: Node) -> void:
	if not Story.has_flag("radio_fixed"):
		ui.open_dialogue("old_no", "Старик", [
			"Не сейчас, странник. Сначала пусть мёртвый эфир оживёт.",
			"Без вести с вышки я никого за ворота не пущу.",
		])
		return
	if not Story.has_flag("met_oldman"):
		Story.set_flag("met_oldman")
		ui.open_dialogue("old_intro", "Старик", [
			"Слышал твой голос в рации. Или её. Неважно.",
			"За воротами — не спасение. Там память Ashveil, и она голодная.",
			"Если всё же хочешь пройти — принеси медальон из часовни на западе.",
			"Только тогда ключ будет твоим. И ответственность — тоже.",
		])
	elif Story.has_item("medallion") and not Story.has_flag("got_key"):
		Story.consume_item("medallion")
		Story.add_item("gate_key")
		Story.set_flag("got_key")
		ui.open_dialogue("old_key", "Старик", [
			"Медальон… Значит, часовня ещё помнит имена.",
			"Держи ключ. Северные ворота больше не удержат тебя.",
			"Что бы ты ни увидел — помни: пепел врёт. Люди — реже.",
		])
	elif Story.has_flag("got_key") and not Story.has_flag("opened_gate"):
		ui.open_dialogue("old_go", "Старик", [
			"Ключ у тебя. Ворота ждут. Я — нет.",
		])
	elif Story.has_flag("opened_gate"):
		ui.open_dialogue("old_end", "Старик", [
			"Итак, ты открыл путь. Теперь Ashveil смотрит в ответ.",
			"Глава первая кончена. Дальше будет тише… и хуже.",
		])
	else:
		ui.open_dialogue("old_hint", "Старик", [
			"Часовня на западе. Медальон на алтаре. Не трогай колокол.",
		])
