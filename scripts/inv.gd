extends Node
## Глобальный инвентарь: ресурсы, инструменты, броня.

signal changed

const MAX_DUR := {
	"axe": 30, "sword": 50, "bow": 40, "crossbow": 55, "rod": 15, "pickaxe": 50,
	"stone_axe": 60, "stone_sword": 100, "stone_bow": 80, "stone_crossbow": 110, "stone_rod": 30, "stone_pickaxe": 100,
}

# slot -> item id ("" empty)
# slots: head, chest, legs, feet
var armor := {"head": "", "chest": "", "legs": "", "feet": ""}

const ARMOR_DEF := {
	"wood_helm": 1, "wood_chest": 2, "wood_legs": 1, "wood_boots": 1,
	"stone_helm": 2, "stone_chest": 4, "stone_legs": 3, "stone_boots": 2,
	"bone_helm": 3, "bone_chest": 5, "bone_legs": 4, "bone_boots": 3,
}

const ARMOR_SLOT := {
	"wood_helm": "head", "stone_helm": "head", "bone_helm": "head",
	"wood_chest": "chest", "stone_chest": "chest", "bone_chest": "chest",
	"wood_legs": "legs", "stone_legs": "legs", "bone_legs": "legs",
	"wood_boots": "feet", "stone_boots": "feet", "bone_boots": "feet",
}

var _items := {}
var _dur := {}


func add(id: String, n: int = 1) -> void:
	_items[id] = _items.get(id, 0) + n
	changed.emit()


func count(id: String) -> int:
	return int(_items.get(id, 0))


func has(id: String, n: int = 1) -> bool:
	return count(id) >= n


func remove(id: String, n: int = 1) -> void:
	_items[id] = max(0, count(id) - n)
	if _items[id] == 0:
		_items.erase(id)
	changed.emit()


func is_tool(id: String) -> bool:
	return MAX_DUR.has(id)


func is_armor(id: String) -> bool:
	return ARMOR_SLOT.has(id)


func armor_slot_of(id: String) -> String:
	return str(ARMOR_SLOT.get(id, ""))


func defense_of(id: String) -> int:
	return int(ARMOR_DEF.get(id, 0))


func total_defense() -> int:
	var d := 0
	for s in armor:
		var id: String = str(armor[s])
		if id != "":
			d += defense_of(id)
	return d


func equip_armor(id: String) -> bool:
	if not is_armor(id) or count(id) <= 0:
		return false
	var slot := armor_slot_of(id)
	if slot == "":
		return false
	# return previous
	var prev: String = str(armor.get(slot, ""))
	if prev != "":
		add(prev, 1)
	remove(id, 1)
	armor[slot] = id
	changed.emit()
	return true


func unequip_armor(slot: String) -> void:
	if not armor.has(slot):
		return
	var id: String = str(armor[slot])
	if id == "":
		return
	armor[slot] = ""
	add(id, 1)
	changed.emit()


func clear_armor() -> void:
	for s in armor.keys():
		var id: String = str(armor[s])
		if id != "":
			_items[id] = _items.get(id, 0) + 1
		armor[s] = ""
	changed.emit()


func max_dur(id: String) -> int:
	return int(MAX_DUR.get(id, 0))


func durability_of(id: String) -> int:
	return int(_dur.get(id, 0))


func give_tool(id: String) -> void:
	_items[id] = 1
	_dur[id] = MAX_DUR[id]
	changed.emit()


func use_tool(id: String) -> void:
	if not MAX_DUR.has(id) or count(id) <= 0:
		return
	var d: int = int(_dur.get(id, MAX_DUR[id])) - 1
	if d <= 0:
		_items[id] = 0
		_items.erase(id)
		_dur.erase(id)
	else:
		_dur[id] = d
	changed.emit()


func snapshot() -> Dictionary:
	return {
		"items": _items.duplicate(true),
		"dur": _dur.duplicate(true),
		"armor": armor.duplicate(true),
	}


func restore(snap: Dictionary) -> void:
	var it: Dictionary = snap.get("items", {})
	var du: Dictionary = snap.get("dur", {})
	var ar: Dictionary = snap.get("armor", {})
	_items = it.duplicate(true)
	_dur = du.duplicate(true)
	armor = {"head": "", "chest": "", "legs": "", "feet": ""}
	for s in armor.keys():
		if ar.has(s):
			armor[s] = str(ar[s])
	changed.emit()
