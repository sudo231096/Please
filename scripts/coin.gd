extends Area2D
## Монета, выпадающая из разбойника. Подбирается игроком.

const PixelArt = preload("res://scripts/pixel.gd")

var value := 1
var big := false
var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true

	var col := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 12.0 if big else 9.0
	col.shape = cs
	add_child(col)

	var spr := Sprite2D.new()
	spr.texture = PixelArt.coin_tex(big)
	spr.centered = true
	spr.scale = Vector2(3, 3) if big else Vector2(2, 2)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(spr)

	_base_y = position.y
	body_entered.connect(_on_pick)

	# самоуничтожение, если не подобрали
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 4.0) * 3.0


func _on_pick(body: Node2D) -> void:
	if body and body.is_in_group("player"):
		Progress.add_coins(value)
		queue_free()
