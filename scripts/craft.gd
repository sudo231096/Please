extends RefCounted
class_name CraftDB
## Статические рецепты крафта.

# id -> { "name": str, "cost": {res: n}, "tool": bool }
const RECIPES := {
	"axe": {
		"name": "Топор",
		"desc": "Рубка деревьев быстрее",
		"cost": {"wood": 5, "stone": 2},
		"tool": true,
	},
	"pickaxe": {
		"name": "Кирка",
		"desc": "Добыча камня и серы быстрее",
		"cost": {"wood": 4, "stone": 3},
		"tool": true,
	},
	"sword": {
		"name": "Меч",
		"desc": "Больше урона животным",
		"cost": {"wood": 3, "stone": 4},
		"tool": true,
	},
	"bow": {
		"name": "Лук",
		"desc": "Дальний бой (скоро)",
		"cost": {"wood": 6, "stone": 1},
		"tool": true,
	},
	"crossbow": {
		"name": "Арбалет",
		"desc": "Мощный дальний бой (скоро)",
		"cost": {"wood": 8, "stone": 4, "sulfur": 2},
		"tool": true,
	},
	"rod": {
		"name": "Удочка",
		"desc": "Рыбалка (скоро)",
		"cost": {"wood": 4},
		"tool": true,
	},
	"stone_axe": {
		"name": "Каменный топор",
		"desc": "Прочный топор",
		"cost": {"wood": 6, "stone": 8},
		"tool": true,
	},
	"stone_pickaxe": {
		"name": "Каменная кирка",
		"desc": "Прочная кирка",
		"cost": {"wood": 5, "stone": 10},
		"tool": true,
	},
	"stone_sword": {
		"name": "Каменный меч",
		"desc": "Прочный меч",
		"cost": {"wood": 4, "stone": 10},
		"tool": true,
	},
	"stone_bow": {
		"name": "Каменный лук",
		"desc": "Прочный лук",
		"cost": {"wood": 8, "stone": 6},
		"tool": true,
	},
	"stone_crossbow": {
		"name": "Каменный арбалет",
		"desc": "Прочный арбалет",
		"cost": {"wood": 10, "stone": 8, "sulfur": 4},
		"tool": true,
	},
	"stone_rod": {
		"name": "Каменная удочка",
		"desc": "Прочная удочка",
		"cost": {"wood": 5, "stone": 4},
		"tool": true,
	},
}


static func order() -> Array:
	return [
		"axe", "pickaxe", "sword", "bow", "crossbow", "rod",
		"stone_axe", "stone_pickaxe", "stone_sword", "stone_bow", "stone_crossbow", "stone_rod",
	]


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
