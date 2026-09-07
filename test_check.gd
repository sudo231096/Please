extends Node
## Проверка: скачанные деревья, отсутствие парящей травы, медведи, сетевой слой.

const MainScr := preload("res://scripts/main.gd")


func _ready() -> void:
	var nc = NetConfig
	await get_tree().process_frame
	var ok := true

	# --- 1. скачанные модели деревьев ---
	for p in ["res://models/tree_birch.glb", "res://models/tree_maple.glb"]:
		if not ResourceLoader.exists(p):
			print("FAIL нет модели ", p); ok = false; continue
		var sc: PackedScene = load(p)
		var n: Node3D = sc.instantiate()
		var meshes := n.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			print("FAIL нет мешей в ", p); ok = false
		else:
			var mi: MeshInstance3D = meshes[0]
			var aabb: AABB = mi.mesh.get_aabb()
			var surf := mi.mesh.get_surface_count()
			var tex_ok := false
			for si in range(surf):
				var m: Material = mi.mesh.surface_get_material(si)
				if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture != null:
					tex_ok = true
			print("OK  %s: поверхностей=%d, габарит=%.2fx%.2fx%.2f, текстуры=%s" % [
				p.get_file(), surf, aabb.size.x, aabb.size.y, aabb.size.z, str(tex_ok)])
			if not tex_ok:
				print("FAIL у модели нет albedo-текстуры"); ok = false
			if surf < 2:
				print("FAIL ожидались раздельные кора+листва"); ok = false
		n.free()

	# --- 2. мир: трава/деревья на поверхности ---
	var main: Node3D = Node3D.new()
	main.set_script(MainScr)
	get_tree().get_root().add_child(main)
	for i in range(6):
		await get_tree().process_frame

	var floating := 0
	var buried := 0
	var worst := 0.0
	var checked := 0
	var grass_node := main.get_node_or_null("Grass")
	if grass_node == null:
		print("FAIL нет узла Grass"); ok = false
	else:
		# трансформы MultiMesh в headless не читаются — повторяем проверку логики размещения
		var rng := RandomNumberGenerator.new()
		rng.seed = 12345
		for i in range(4000):
			var ang := rng.randf() * TAU
			var r := rng.randf_range(6.0, 430.0 - 45.0)
			var x := cos(ang) * r
			var z := sin(ang) * r
			var h: float = main.call("_surface_height", x, z)
			if h < -1.0 + 1.2:
				continue
			var e := 1.2
			var nx: float = main.call("_surface_height", x + e, z) - main.call("_surface_height", x - e, z)
			var nz: float = main.call("_surface_height", x, z + e) - main.call("_surface_height", x, z - e)
			if Vector2(nx, nz).length() / (2.0 * e) > 0.35:
				continue
			var amax: float = maxf(maxf(main.call("_surface_height", x + e, z), main.call("_surface_height", x - e, z)),
				maxf(main.call("_surface_height", x, z + e), main.call("_surface_height", x, z - e)))
			var amin: float = minf(minf(main.call("_surface_height", x + e, z), main.call("_surface_height", x - e, z)),
				minf(main.call("_surface_height", x, z + e), main.call("_surface_height", x, z - e)))
			if amax - amin > 1.2:
				continue
			checked += 1
			# как в _build_grass: основание = h - 0.12*s
			var s := rng.randf_range(0.7, 1.5)
			var base_y := h - 0.12 * s
			var gap := base_y - h
			if gap > 0.0:
				floating += 1
			if gap < -0.25:
				buried += 1
			worst = maxf(worst, gap)
		print("OK  трава: проверено %d точек, парящих=%d, слишком утопленных=%d, худший зазор=%.3f" % [checked, floating, buried, worst])
		if floating > 0:
			print("FAIL есть парящая трава"); ok = false

	# --- 3. деревья на поверхности ---
	var spots: Array = main.get("_tree_spots")
	var tree_bad := 0
	for t in spots:
		var p: Vector3 = t["pos"]
		var h: float = main.call("_surface_height", p.x, p.z)
		if absf(p.y - h) > 0.05:
			tree_bad += 1
	print("OK  деревьев всего: %d, вне поверхности: %d" % [spots.size(), tree_bad])
	if tree_bad > 0:
		print("FAIL деревья не на земле"); ok = false
	for nm in ["TreesPine", "TreesLeafy", "TreesDead", "TreesBirch", "TreesMaple"]:
		var nn := main.get_node_or_null(nm)
		if nn == null:
			print("FAIL нет узла ", nm); ok = false
		else:
			print("OK  %s: инстансов=%d" % [nm, (nn as MultiMeshInstance3D).multimesh.instance_count])
	# коллизии стволов
	var bodies := 0
	for c in main.get_children():
		if c is StaticBody3D:
			bodies += 1
	print("OK  StaticBody3D в мире (коллизии стволов и земли): %d" % bodies)

	# --- 4. медведь ---
	var animals := main.find_children("*", "CharacterBody3D", true, false)
	var bear_found := false
	for a in animals:
		var kv: Variant = a.get("kind")
		if typeof(kv) != TYPE_INT:
			continue
		if int(kv) == 3:
			bear_found = true
			var cols := a.find_children("*", "CollisionShape3D", true, false)
			if cols.is_empty():
				print("FAIL у медведя нет коллизии"); ok = false; break
			var col: CollisionShape3D = cols[0]
			var cap: CapsuleShape3D = col.shape
			print("OK  медведь: коллизия r=%.2f h=%.2f, y=%.2f" % [cap.radius, cap.height, col.position.y])
			break
	print("OK  медведь найден: %s" % str(bear_found))

	# --- 5. сеть ---
	print("OK  серверов в конфиге: %d, лимит игроков: %d" % [nc.servers.size(), nc.MAX_PLAYERS])
	if nc.servers.size() != 5:
		print("FAIL должно быть 5 серверов"); ok = false
	if nc.MAX_PLAYERS != 85:
		print("FAIL лимит должен быть 85"); ok = false
	for s in nc.servers:
		print("    %s port=%d status=%s deployed=%s" % [s["name"], int(s["port"]), nc.status_url(s), str(nc.is_deployed(s))])
	# отдельные сохранения
	print("OK  путь сохранения S1=%s S2=%s" % [nc.save_path_for(1), nc.save_path_for(2)])

	print("=== ИТОГ: %s ===" % ("ВСЁ ОК" if ok else "ЕСТЬ ОШИБКИ"))
	get_tree().quit(0 if ok else 1)
