extends RefCounted

## Рецепты: инструменты, стройка, броня.

const RECIPES := {
	"axe": {"name": "Топор", "desc": "Рубка деревьев быстрее", "cost": {"wood": 5, "stone": 2}, "tool": true},
	"pickaxe": {"name": "Кирка", "desc": "Добыча камня и серы быстрее", "cost": {"wood": 4, "stone": 3}, "tool": true},
	"sword": {"name": "Меч", "desc": "Больше урона животным", "cost": {"wood": 3, "stone": 4}, "tool": true},
	"bow": {"name": "Лук", "desc": "Дальний бой (скоро)", "cost": {"wood": 6, "stone": 1}, "tool": true},
	"crossbow": {"name": "Арбалет", "desc": "Мощный дальний бой (скоро)", "cost": {"wood": 8, "stone": 4, "sulfur": 2}, "tool": true},
	"rod": {"name": "Удочка", "desc": "Рыбалка (скоро)", "cost": {"wood": 4}, "tool": true},
	"stone_axe": {"name": "Каменный топор", "desc": "Прочный топор", "cost": {"wood": 6, "stone": 8}, "tool": true},
	"stone_pickaxe": {"name": "Каменная кирка", "desc": "Прочная кирка", "cost": {"wood": 5, "stone": 10}, "tool": true},
	"stone_sword": {"name": "Каменный меч", "desc": "Прочный меч", "cost": {"wood": 4, "stone": 10}, "tool": true},
	"stone_bow": {"name": "Каменный лук", "desc": "Прочный лук", "cost": {"wood": 8, "stone": 6}, "tool": true},
	"stone_crossbow": {"name": "Каменный арбалет", "desc": "Прочный арбалет", "cost": {"wood": 10, "stone": 8, "sulfur": 4}, "tool": true},
	"stone_rod": {"name": "Каменная удочка", "desc": "Прочная удочка", "cost": {"wood": 5, "stone": 4}, "tool": true},
	# стройка
	"wood_block": {"name": "Дер. блок", "desc": "Кубик 1×1", "cost": {"wood": 2}, "tool": false},
	"wood_wall": {"name": "Дер. стена", "desc": "Стена 1×2", "cost": {"wood": 4}, "tool": false},
	"wood_floor": {"name": "Дер. пол", "desc": "Плита пола", "cost": {"wood": 3}, "tool": false},
	"wood_pillar": {"name": "Дер. столб", "desc": "Опора", "cost": {"wood": 3}, "tool": false},
	"stone_block": {"name": "Кам. блок", "desc": "Каменный кубик", "cost": {"stone": 3}, "tool": false},
	"stone_wall": {"name": "Кам. стена", "desc": "Каменная стена", "cost": {"stone": 5}, "tool": false},
	"campfire": {"name": "Костёр", "desc": "Свет и уют", "cost": {"wood": 5, "sulfur": 1}, "tool": false},
	# броня дерево
	"wood_helm": {"name": "Дер. шлем", "desc": "Защита головы +1", "cost": {"wood": 6}, "tool": false, "armor": true},
	"wood_chest": {"name": "Дер. нагрудник", "desc": "Защита груди +2", "cost": {"wood": 10}, "tool": false, "armor": true},
	"wood_legs": {"name": "Дер. поножи", "desc": "Защита ног +1", "cost": {"wood": 8}, "tool": false, "armor": true},
	"wood_boots": {"name": "Дер. ботинки", "desc": "Защита ступней +1", "cost": {"wood": 5}, "tool": false, "armor": true},
	# броня камень
	"stone_helm": {"name": "Кам. шлем", "desc": "Защита головы +2", "cost": {"stone": 8, "wood": 2}, "tool": false, "armor": true},
	"stone_chest": {"name": "Кам. нагрудник", "desc": "Защита груди +4", "cost": {"stone": 14, "wood": 3}, "tool": false, "armor": true},
	"stone_legs": {"name": "Кам. поножи", "desc": "Защита ног +3", "cost": {"stone": 12, "wood": 2}, "tool": false, "armor": true},
	"stone_boots": {"name": "Кам. ботинки", "desc": "Защита ступней +2", "cost": {"stone": 6, "wood": 2}, "tool": false, "armor": true},
	# броня кость (мясо как трофей)
	"bone_helm": {"name": "Кост. шлем", "desc": "Защита головы +3", "cost": {"meat": 6, "stone": 2}, "tool": false, "armor": true},
	"bone_chest": {"name": "Кост. нагрудник", "desc": "Защита груди +5", "cost": {"meat": 12, "stone": 4}, "tool": false, "armor": true},
	"bone_legs": {"name": "Кост. поножи", "desc": "Защита ног +4", "cost": {"meat": 10, "stone": 3}, "tool": false, "armor": true},
	"bone_boots": {"name": "Кост. ботинки", "desc": "Защита ступней +3", "cost": {"meat": 5, "stone": 2}, "tool": false, "armor": true},
}

const BUILD_ORDER := ["wood_block", "wood_wall", "wood_floor", "wood_pillar", "stone_block", "stone_wall", "campfire"]
const ARMOR_ORDER := [
	"wood_helm", "wood_chest", "wood_legs", "wood_boots",
	"stone_helm", "stone_chest", "stone_legs", "stone_boots",
	"bone_helm", "bone_chest", "bone_legs", "bone_boots",
]


static func order() -> Array:
	return [
		"axe", "pickaxe", "sword", "bow", "crossbow", "rod",
		"stone_axe", "stone_pickaxe", "stone_sword", "stone_bow", "stone_crossbow", "stone_rod",
		"wood_block", "wood_wall", "wood_floor", "wood_pillar", "stone_block", "stone_wall", "campfire",
		"wood_helm", "wood_chest", "wood_legs", "wood_boots",
		"stone_helm", "stone_chest", "stone_legs", "stone_boots",
		"bone_helm", "bone_chest", "bone_legs", "bone_boots",
	]


static func is_build_piece(id: String) -> bool:
	return id in BUILD_ORDER


static func is_armor(id: String) -> bool:
	return id in ARMOR_ORDER


static func can_craft(id: String) -> bool:
	if not RECIPES.has(id):
		return false
	var cost: Dictionary = RECIPES[id]["cost"]
	for res in cost:
		if Inv.count(str(res)) < int(cost[res]):
			return false
	return true


static func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var rec: Dictionary = RECIPES[id]
	var cost: Dictionary = rec["cost"]
	for res in cost:
		Inv.remove(str(res), int(cost[res]))
	if bool(rec.get("tool", false)):
		Inv.give_tool(id)
	else:
		Inv.add(id, 1)
	return true
