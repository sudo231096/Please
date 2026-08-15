extends Node
## Загрузка внешних low-poly ассетов (KayKit / samples). Fallback на процедурные модели.

const ROOT := "res://assets"

var _cache: Dictionary = {}  # path -> PackedScene or ArrayMesh-ish Node


func _ready() -> void:
	pass


func has_file(path: String) -> bool:
	return ResourceLoader.exists(path)


func instantiate_scene(path: String) -> Node3D:
	if _cache.has(path):
		var c = _cache[path]
		if c is PackedScene:
			return (c as PackedScene).instantiate() as Node3D
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res == null:
		return null
	var node: Node3D = null
	if res is PackedScene:
		_cache[path] = res
		node = res.instantiate() as Node3D
	elif res is Mesh:
		node = Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = res
		node.add_child(mi)
	else:
		# gltf as ArrayMesh container sometimes comes as Node via GLTFDocument at runtime
		return null
	return node


func spawn_model(path: String, parent: Node, scale: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := instantiate_scene(path)
	if n == null:
		return null
	parent.add_child(n)
	n.position = pos
	n.rotation = rot
	n.scale = scale
	_prepare_visual(n)
	return n


func _prepare_visual(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 220.0
	for c in n.get_children():
		_prepare_visual(c)


func weapon_path(tool_id: String) -> String:
	var base := tool_id.replace("stone_", "")
	match base:
		"sword":
			return ROOT + "/weapons/sword_1handed.gltf"
		"axe":
			return ROOT + "/weapons/axe_1handed.gltf"
		"pickaxe":
			return ROOT + "/weapons/axe_2handed.gltf"
		"crossbow":
			return ROOT + "/weapons/crossbow_2handed.gltf"
		"bow":
			return ROOT + "/weapons/crossbow_1handed.gltf"
		"rod":
			return ROOT + "/weapons/staff.gltf"
		_:
			return ""


func armor_path(piece_id: String) -> String:
	# visual stand-ins: shields as armor plates / badges
	if piece_id.ends_with("helm") or piece_id.ends_with("chest"):
		return ROOT + "/armor/shield_round.gltf"
	if piece_id.ends_with("legs"):
		return ROOT + "/armor/shield_square.gltf"
	if piece_id.ends_with("boots"):
		return ROOT + "/armor/shield_badge.gltf"
	return ROOT + "/armor/shield_round.gltf"


func tree_path(i: int = 0) -> String:
	var opts := [
		ROOT + "/nature/tree_single_A.gltf",
		ROOT + "/nature/tree_single_B.gltf",
		ROOT + "/nature/trees_A_medium.gltf",
		ROOT + "/nature/trees_B_medium.gltf",
		ROOT + "/nature/trees_A_small.gltf",
		ROOT + "/nature/trees_B_small.gltf",
	]
	return opts[i % opts.size()]


func rock_path(i: int = 0) -> String:
	var opts := [
		ROOT + "/nature/rock_single_A.gltf",
		ROOT + "/nature/rock_single_B.gltf",
		ROOT + "/nature/rock_single_C.gltf",
		ROOT + "/nature/rock_single_D.gltf",
		ROOT + "/nature/rock_single_E.gltf",
	]
	return opts[i % opts.size()]


func build_path(piece_id: String) -> String:
	match piece_id:
		"wood_wall", "stone_wall":
			return ROOT + "/build/Wall.gltf"
		"wood_floor":
			return ROOT + "/build/Primitive_Floor.gltf"
		"wood_pillar":
			return ROOT + "/build/Primitive_Pillar.gltf"
		"wood_block", "stone_block":
			return ROOT + "/build/Primitive_Cube.gltf"
		_:
			return ""


func player_path() -> String:
	return ROOT + "/player/Rogue_Hooded.glb"


func animal_path(kind_name: String) -> String:
	match kind_name:
		"CHICKEN":
			return ROOT + "/animals/chicken_proxy.glb"
		"DEER":
			return ROOT + "/animals/deer_proxy.glb"
		"BOAR":
			return ROOT + "/animals/deer_proxy.glb"
		"BEAR":
			return ROOT + "/animals/deer_proxy.glb"
		_:
			return ""
