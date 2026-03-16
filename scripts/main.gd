extends Node2D

@export_group("Parallax")
## Near block background hills (layer_background): fixed in world space.
@export var background_parallax_factor: float = 0.88
## Far front mountains (layer_far_background_front): follows camera less.
@export var far_background_front_parallax_factor: float = 0.82
## Far back mountains (layer_far_background_back): follows camera least.
@export var far_background_back_parallax_factor: float = 0.92

var _layer_bg: Node2D = null
var _layer_far_bg_front: Node2D = null
var _layer_far_bg_back: Node2D = null
var _cam: Camera2D = null
var _bg_base_pos: Vector2 = Vector2.ZERO
var _far_bg_front_base_pos: Vector2 = Vector2.ZERO
var _far_bg_back_base_pos: Vector2 = Vector2.ZERO
var _base_cam_x: float = 0.0

func _ready() -> void:
	_layer_bg = get_tree().get_first_node_in_group("layer_background") as Node2D
	_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background_front") as Node2D
	if _layer_far_bg_front == null:
		_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background") as Node2D
	_layer_far_bg_back = get_tree().get_first_node_in_group("layer_far_background_back") as Node2D
	_cam = get_viewport().get_camera_2d()

	if _layer_bg != null:
		_bg_base_pos = _layer_bg.position
	if _layer_far_bg_front != null:
		_far_bg_front_base_pos = _layer_far_bg_front.position
	if _layer_far_bg_back != null:
		_far_bg_back_base_pos = _layer_far_bg_back.position
	if _cam != null:
		_base_cam_x = _cam.global_position.x

func _process(_delta: float) -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
		if _cam == null:
			return
	if _layer_bg == null:
		_layer_bg = get_tree().get_first_node_in_group("layer_background") as Node2D
		if _layer_bg != null:
			_bg_base_pos = _layer_bg.position
	if _layer_far_bg_front == null:
		_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background_front") as Node2D
		if _layer_far_bg_front == null:
			_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background") as Node2D
		if _layer_far_bg_front != null:
			_far_bg_front_base_pos = _layer_far_bg_front.position
	if _layer_far_bg_back == null:
		_layer_far_bg_back = get_tree().get_first_node_in_group("layer_far_background_back") as Node2D
		if _layer_far_bg_back != null:
			_far_bg_back_base_pos = _layer_far_bg_back.position

	var dx: float = _cam.global_position.x - _base_cam_x

	# Keep near background fixed so it matches terrain composition better.
	if _layer_bg != null:
		_layer_bg.position.x = _bg_base_pos.x
	# Move far background bands with different parallax strengths.
	if _layer_far_bg_front != null:
		_layer_far_bg_front.position.x = _far_bg_front_base_pos.x - dx * (1.0 - clamp(far_background_front_parallax_factor, 0.0, 1.0))
	if _layer_far_bg_back != null:
		_layer_far_bg_back.position.x = _far_bg_back_base_pos.x - dx * (1.0 - clamp(far_background_back_parallax_factor, 0.0, 1.0))
