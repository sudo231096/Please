extends Node3D
## Локация главы 1: лагерь у вышки, склад, часовня, северные ворота.

const PlayerScn := preload("res://scenes/Player.tscn")
const JoystickScr := preload("res://scripts/joystick.gd")
const DialogueScr := preload("res://scripts/dialogue_ui.gd")
const NpcScr := preload("res://scripts/npc.gd")
const PickupScr := preload("res://scripts/pickup.gd")
const GateScr := preload("res://scripts/gate.gd")

var _quest_title: Label
var _quest_desc: Label
var _inv_label: Label
var _toast: Label
var _player: CharacterBody3D


func _ready() -> void:
	_build_env()
	_build_ground()
	_build_landmarks()
	_spawn_actors()
	_build_hud()
	if not Story.quest_changed.is_connected(_on_quest):
		Story.quest_changed.connect(_on_quest)
	if not Story.flags_changed.is_connected(_on_flags):
		Story.flags_changed.connect(_on_flags)
	_on_quest()
	_on_flags()


func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.18, 0.22, 0.3)
	sm.sky_horizon_color = Color(0.55, 0.45, 0.4)
	sm.ground_bottom_color = Color(0.12, 0.11, 0.1)
	sm.ground_horizon_color = Color(0.3, 0.28, 0.25)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.45, 0.42, 0.4)
	env.fog_density = 0.004
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.92, 0.85)
	add_child(sun)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.3, 0.24)
	mat.roughness = 0.95
	mi.mesh = plane
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	col.shape = box
	col.position = Vector3(0, -0.5, 0)
	body.add_child(col)
	add_child(body)

	# path to north
	var path := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.5, 0.05, 70)
	path.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.36, 0.32, 0.26)
	path.material_override = pmat
	path.position = Vector3(0, 0.02, -20)
	add_child(path)


func _box(parent: Node, size: Vector3, color: Color, pos: Vector3, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


func _build_landmarks() -> void:
	# campfire
	var camp := Node3D.new()
	camp.position = Vector3(0, 0, 0)
	add_child(camp)
	_box(camp, Vector3(1.2, 0.2, 1.2), Color(0.2, 0.15, 0.1), Vector3(0, 0.1, 0))
	var fire := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.25
	fs.height = 0.5
	fire.mesh = fs
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.45, 0.1)
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.35, 0.05)
	fm.emission_energy_multiplier = 2.0
	fire.material_override = fm
	fire.position = Vector3(0, 0.4, 0)
	camp.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.8
	light.omni_range = 12.0
	light.position = Vector3(0, 1.0, 0)
	camp.add_child(light)
	var cl := Label3D.new()
	cl.text = "Костёр"
	cl.font_size = 40
	cl.position = Vector3(0, 1.6, 0)
	cl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	camp.add_child(cl)

	# tower
	var tower := Node3D.new()
	tower.position = Vector3(-6, 0, -4)
	add_child(tower)
	_box(tower, Vector3(1.5, 8, 1.5), Color(0.35, 0.35, 0.38), Vector3(0, 4, 0))
	_box(tower, Vector3(2.4, 0.3, 2.4), Color(0.3, 0.3, 0.32), Vector3(0, 8.1, 0))
	var tl := Label3D.new()
	tl.text = "Вышка"
	tl.font_size = 42
	tl.position = Vector3(0, 9, 0)
	tl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tower.add_child(tl)

	# warehouse east
	var wh := StaticBody3D.new()
	wh.position = Vector3(18, 0, 2)
	add_child(wh)
	_box(wh, Vector3(8, 3.2, 6), Color(0.4, 0.38, 0.34), Vector3(0, 1.6, 0))
	_box(wh, Vector3(2.2, 2.4, 0.2), Color(0.2, 0.2, 0.22), Vector3(0, 1.2, 3.1))
	var wcol := CollisionShape3D.new()
	var wcs := BoxShape3D.new()
	wcs.size = Vector3(8, 3.2, 6)
	wcol.shape = wcs
	wcol.position = Vector3(0, 1.6, 0)
	wh.add_child(wcol)
	var wl := Label3D.new()
	wl.text = "Склад"
	wl.font_size = 48
	wl.position = Vector3(0, 3.8, 0)
	wl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wh.add_child(wl)

	# chapel west
	var ch := StaticBody3D.new()
	ch.position = Vector3(-20, 0, -2)
	add_child(ch)
	_box(ch, Vector3(7, 3.5, 5), Color(0.45, 0.43, 0.4), Vector3(0, 1.75, 0))
	_box(ch, Vector3(1.5, 1.5, 1.5), Color(0.4, 0.38, 0.36), Vector3(0, 4.0, 0))
	_box(ch, Vector3(0.3, 2.0, 0.3), Color(0.55, 0.5, 0.35), Vector3(0, 5.2, 0))
	var ccol := CollisionShape3D.new()
	var ccs := BoxShape3D.new()
	ccs.size = Vector3(7, 3.5, 5)
	ccol.shape = ccs
	ccol.position = Vector3(0, 1.75, 0)
	ch.add_child(ccol)
	var chl := Label3D.new()
	chl.text = "Часовня"
	chl.font_size = 48
	chl.position = Vector3(0, 4.5, 0)
	chl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ch.add_child(chl)

	# rocks/decor
	for i in range(18):
		var r := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = randf_range(0.4, 1.0)
		sm.height = randf_range(0.5, 1.2)
		sm.radial_segments = 8
		sm.rings = 4
		r.mesh = sm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.35, 0.34, 0.32)
		r.material_override = rm
		r.position = Vector3(randf_range(-40, 40), 0.2, randf_range(-50, 20))
		r.scale = Vector3(randf_range(1.0, 1.6), randf_range(0.5, 0.9), randf_range(1.0, 1.5))
		add_child(r)

	# low walls around camp
	_box(self, Vector3(14, 0.8, 0.4), Color(0.3, 0.28, 0.25), Vector3(0, 0.4, 8))
	_box(self, Vector3(0.4, 0.8, 14), Color(0.3, 0.28, 0.25), Vector3(8, 0.4, 0))
	_box(self, Vector3(0.4, 0.8, 14), Color(0.3, 0.28, 0.25), Vector3(-8, 0.4, 0))


func _spawn_actors() -> void:
	var p := PlayerScn.instantiate()
	p.position = Vector3(0, 2.0, 3)
	p.spawn_pos = p.position
	add_child(p)
	_player = p

	var ira := StaticBody3D.new()
	ira.set_script(NpcScr)
	ira.npc_id = "ira"
	ira.display_name = "Ира"
	ira.position = Vector3(-5.5, 0, -3.2)
	add_child(ira)

	var oldman := StaticBody3D.new()
	oldman.set_script(NpcScr)
	oldman.npc_id = "oldman"
	oldman.display_name = "Старик"
	oldman.position = Vector3(0.5, 0, -48)
	add_child(oldman)

	var bat := StaticBody3D.new()
	bat.set_script(PickupScr)
	bat.item_id = "battery"
	bat.title = "Батарейка"
	bat.flag_on_take = "got_battery"
	bat.position = Vector3(16.5, 0, 4.5)
	add_child(bat)

	var med := StaticBody3D.new()
	med.set_script(PickupScr)
	med.item_id = "medallion"
	med.title = "Медальон"
	med.flag_on_take = "got_medallion"
	med.position = Vector3(-20, 0, -2.5)
	add_child(med)

	var gate := StaticBody3D.new()
	gate.set_script(GateScr)
	gate.position = Vector3(0, 0, -55)
	add_child(gate)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# quest panel
	var qp := PanelContainer.new()
	qp.offset_left = 16
	qp.offset_top = 16
	qp.offset_right = 420
	qp.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.75)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	qp.add_theme_stylebox_override("panel", sb)
	root.add_child(qp)
	var qv := VBoxContainer.new()
	qp.add_child(qv)
	_quest_title = Label.new()
	_quest_title.add_theme_font_size_override("font_size", 24)
	_quest_title.modulate = Color(0.85, 0.95, 1.0)
	qv.add_child(_quest_title)
	_quest_desc = Label.new()
	_quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_desc.add_theme_font_size_override("font_size", 18)
	qv.add_child(_quest_desc)

	_inv_label = Label.new()
	_inv_label.offset_left = 16
	_inv_label.offset_top = 160
	_inv_label.offset_right = 420
	_inv_label.offset_bottom = 220
	_inv_label.add_theme_font_size_override("font_size", 18)
	_inv_label.modulate = Color(0.9, 0.85, 0.6)
	root.add_child(_inv_label)

	# crosshair
	var cross := Control.new()
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	for d in [[-14, -2, 8, 4], [6, -2, 8, 4], [-2, -14, 4, 8], [-2, 6, 4, 8]]:
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0.85)
		r.anchor_left = 0.5
		r.anchor_right = 0.5
		r.anchor_top = 0.5
		r.anchor_bottom = 0.5
		r.offset_left = float(d[0])
		r.offset_top = float(d[1])
		r.offset_right = float(d[0] + d[2])
		r.offset_bottom = float(d[1] + d[3])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(r)

	root.add_child(JoystickScr.new())

	var jump := Button.new()
	jump.text = "ПРЫЖОК"
	jump.focus_mode = Control.FOCUS_NONE
	jump.anchor_left = 1.0
	jump.anchor_right = 1.0
	jump.anchor_top = 1.0
	jump.anchor_bottom = 1.0
	jump.offset_left = -190
	jump.offset_right = -20
	jump.offset_top = -100
	jump.offset_bottom = -20
	jump.add_theme_font_size_override("font_size", 22)
	jump.button_down.connect(func() -> void: Controls.jump_queued = true)
	root.add_child(jump)

	var use := Button.new()
	use.text = "ДЕЙСТВИЕ"
	use.focus_mode = Control.FOCUS_NONE
	use.anchor_left = 1.0
	use.anchor_right = 1.0
	use.anchor_top = 1.0
	use.anchor_bottom = 1.0
	use.offset_left = -190
	use.offset_right = -20
	use.offset_top = -190
	use.offset_bottom = -110
	use.add_theme_font_size_override("font_size", 22)
	use.button_down.connect(func() -> void: Controls.interact_queued = true)
	root.add_child(use)

	var menu := Button.new()
	menu.text = "МЕНЮ"
	menu.focus_mode = Control.FOCUS_NONE
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -140
	menu.offset_right = -16
	menu.offset_top = 16
	menu.offset_bottom = 70
	menu.add_theme_font_size_override("font_size", 20)
	menu.pressed.connect(func() -> void:
		Controls.ui_open = false
		Controls.move_vector = Vector2.ZERO
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	root.add_child(menu)

	var dlg := DialogueScr.new()
	dlg.add_to_group("dialogue_ui")
	add_child(dlg)

	# intro once
	if not Story.has_flag("met_ira") and not Story.has_item("battery"):
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(dlg) and not Story.has_flag("met_ira"):
			dlg.open_dialogue("intro", "???", [
				"Пепел на языке. В ушах — тишина, будто мир выключили.",
				"Где-то рядом треснул костёр. Значит, ты ещё не один.",
				"Встань. Ashveil не любит тех, кто долго лежит.",
			])


func _on_quest() -> void:
	if _quest_title:
		_quest_title.text = "Квест: " + Story.quest_title
	if _quest_desc:
		_quest_desc.text = Story.quest_desc


func _on_flags() -> void:
	if _inv_label == null:
		return
	if Story.inventory.is_empty():
		_inv_label.text = "Инвентарь: пусто"
	else:
		var parts: PackedStringArray = []
		for id in Story.inventory:
			parts.append(Story.item_title(id))
		_inv_label.text = "Инвентарь: " + ", ".join(parts)
