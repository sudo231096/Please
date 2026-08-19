extends Node3D
## Камерамен, стоящий в главном меню (витрина) — скачанная модель.

const ModelScene := preload("res://models/cameraman.glb")
const MODEL_SCALE := 0.0957
const MODEL_YAW := 180.0
const MODEL_OFFSET := Vector3(0, 0, 0.099)

var _model: Node3D
var _t := 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	_model = ModelScene.instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	_model.rotation_degrees = Vector3(0, MODEL_YAW, 0)
	_model.position = MODEL_OFFSET
	add_child(_model)


func _process(delta: float) -> void:
	_t += delta
	# лёгкое покачивание корпуса и поворот
	position.y = sin(_t * 2.0) * 0.03
	_model.rotation.y = deg_to_rad(MODEL_YAW) + sin(_t * 0.7) * 0.5
