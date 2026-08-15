extends StaticBody3D
## Поставленный игроком блок/стена. Можно сломать и вернуть часть ресурсов.

@export var piece_id := "wood_block"
@export var hp := 4

const DROP := {
	"wood_block": {"wood": 1},
	"wood_wall": {"wood": 2},
	"wood_floor": {"wood": 1},
	"wood_pillar": {"wood": 1},
	"stone_block": {"stone": 1},
	"stone_wall": {"stone": 2},
	"campfire": {"wood": 2, "sulfur": 1},
}


func hit(damage: int = 1) -> void:
	hp -= damage
	if hp <= 0:
		var d: Dictionary = DROP.get(piece_id, {})
		for k in d:
			Inv.add(str(k), int(d[k]))
		queue_free()
