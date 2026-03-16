# ---------------------------------------------------------------------------
# MAIN SCENE CONTROLLER
#
# Responsibilities:
#   1. Loading screen — shown while WorldGen works on its background thread.
#      Hides automatically when WorldGen emits generation_complete.
#   2. Death & respawn — listens to PlayerStats.died, shows a death screen,
#      respawns the player after a short delay.
#   3. Parallax scrolling — drives the decorative far-background layers.
#
# SCENE SETUP — add each node to its group in the Godot editor (Node > Groups):
#   "world_gen"                  — your WorldGen node
#   "player"                     — your Player node
#   "loading_screen"             — CanvasLayer > Control (loading screen root)
#   "loading_label"              — Label inside the loading screen
#   "death_screen"               — CanvasLayer > Control (death screen root)
#   "death_label"                — Label inside the death screen
#   "layer_background"           — near background TileMapLayer
#   "layer_far_background_front" — far front TileMapLayer (optional)
#   "layer_far_background_back"  — far back TileMapLayer  (optional)
# ---------------------------------------------------------------------------
extends Node2D

@export_group("Parallax")
@export var background_parallax_factor:           float = 0.88
@export var far_background_front_parallax_factor: float = 0.82
@export var far_background_back_parallax_factor:  float = 0.92

@export_group("Respawn")
@export var spawn_position: Vector2 = Vector2(0.0, -64.0)
@export var respawn_delay:  float   = 3.0

var _layer_bg:           Node2D          = null
var _layer_far_bg_front: Node2D          = null
var _layer_far_bg_back:  Node2D          = null
var _cam:                Camera2D        = null
var _loading_screen:     CanvasItem      = null
var _death_screen:       CanvasItem      = null
var _loading_label:      Label           = null
var _death_label:        Label           = null
var _player:             CharacterBody2D = null
var _world_gen:          Node            = null

var _bg_base_pos:           Vector2 = Vector2.ZERO
var _far_bg_front_base_pos: Vector2 = Vector2.ZERO
var _far_bg_back_base_pos:  Vector2 = Vector2.ZERO
var _base_cam_x:            float   = 0.0

var _world_ready:   bool  = false
var _player_dead:   bool  = false
var _respawn_timer: float = 0.0

var _load_dots:      int   = 0
var _load_dot_timer: float = 0.0
const LOAD_DOT_INTERVAL: float = 0.4

func _ready() -> void:
	_layer_bg           = get_tree().get_first_node_in_group("layer_background")           as Node2D
	_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background_front") as Node2D
	if _layer_far_bg_front == null:
		_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background") as Node2D
	_layer_far_bg_back  = get_tree().get_first_node_in_group("layer_far_background_back")  as Node2D
	_loading_screen = get_tree().get_first_node_in_group("loading_screen") as CanvasItem
	_death_screen   = get_tree().get_first_node_in_group("death_screen")   as CanvasItem
	_loading_label  = get_tree().get_first_node_in_group("loading_label")  as Label
	_death_label    = get_tree().get_first_node_in_group("death_label")    as Label
	_player    = get_tree().get_first_node_in_group("player")    as CharacterBody2D
	_world_gen = get_tree().get_first_node_in_group("world_gen") as Node
	_cam = get_viewport().get_camera_2d()

	if _layer_bg           != null: _bg_base_pos           = _layer_bg.position
	if _layer_far_bg_front != null: _far_bg_front_base_pos = _layer_far_bg_front.position
	if _layer_far_bg_back  != null: _far_bg_back_base_pos  = _layer_far_bg_back.position
	if _cam                != null: _base_cam_x            = _cam.global_position.x

	_set_loading_visible(true)
	_set_death_visible(false)

	if _world_gen != null and _world_gen.has_signal("generation_complete"):
		_world_gen.generation_complete.connect(_on_generation_complete)
		# Generation may have already finished before we connected — check now.
		if _world_gen.get("_gen_complete") == true:
			_on_generation_complete(0, 0, [], [])
	else:
		push_warning("Main: WorldGen not found or missing generation_complete signal.")
		_set_loading_visible(false)
		_world_ready = true

	if not PlayerStats.died.is_connected(_on_player_died):
		PlayerStats.died.connect(_on_player_died)

func _process(delta: float) -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_2d()

	_try_resolve_layers()

	if not _world_ready and _loading_label != null:
		_load_dot_timer += delta
		if _load_dot_timer >= LOAD_DOT_INTERVAL:
			_load_dot_timer = 0.0
			_load_dots = (_load_dots + 1) % 4
			_loading_label.text = "Generating world" + ".".repeat(_load_dots)

	if _world_ready and _cam != null:
		_update_parallax()

	if _player_dead:
		_respawn_timer -= delta
		if _death_label != null:
			_death_label.text = "You died!\nRespawning in %d..." % max(1, int(ceil(_respawn_timer)))
		if _respawn_timer <= 0.0:
			_do_respawn()

func _on_generation_complete(_seed_val: int, _world_w: int, _mtn_far: Array, _mtn_near: Array) -> void:
	_world_ready = true
	_set_loading_visible(false)

func _on_player_died() -> void:
	if _player_dead:
		return
	_player_dead   = true
	_respawn_timer = respawn_delay
	_set_death_visible(true)
	if _player != null:
		_player.set_physics_process(false)
		_player.set_process(false)

func _do_respawn() -> void:
	_player_dead = false
	_set_death_visible(false)
	if _player != null:
		_player.set_physics_process(true)
		_player.set_process(true)
		_player.global_position = spawn_position
		_player.velocity        = Vector2.ZERO
	PlayerStats.respawn()
	if _world_gen != null and _world_gen.has_method("force_load_around"):
		_world_gen.force_load_around(spawn_position.x)

func _update_parallax() -> void:
	var dx: float = _cam.global_position.x - _base_cam_x
	if _layer_bg != null:
		_layer_bg.position.x = _bg_base_pos.x
	if _layer_far_bg_front != null:
		_layer_far_bg_front.position.x = _far_bg_front_base_pos.x \
			- dx * (1.0 - clamp(far_background_front_parallax_factor, 0.0, 1.0))
	if _layer_far_bg_back != null:
		_layer_far_bg_back.position.x = _far_bg_back_base_pos.x \
			- dx * (1.0 - clamp(far_background_back_parallax_factor, 0.0, 1.0))

func _set_loading_visible(is_visible: bool) -> void:
	if _loading_screen != null:
		_loading_screen.visible = is_visible
	if _player != null:
		_player.set_physics_process(not is_visible)
		_player.set_process(not is_visible)

func _set_death_visible(is_visible: bool) -> void:
	if _death_screen != null:
		_death_screen.visible = is_visible

func _try_resolve_layers() -> void:
	if _layer_bg == null:
		_layer_bg = get_tree().get_first_node_in_group("layer_background") as Node2D
		if _layer_bg != null: _bg_base_pos = _layer_bg.position
	if _layer_far_bg_front == null:
		_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background_front") as Node2D
		if _layer_far_bg_front == null:
			_layer_far_bg_front = get_tree().get_first_node_in_group("layer_far_background") as Node2D
		if _layer_far_bg_front != null: _far_bg_front_base_pos = _layer_far_bg_front.position
	if _layer_far_bg_back == null:
		_layer_far_bg_back = get_tree().get_first_node_in_group("layer_far_background_back") as Node2D
		if _layer_far_bg_back != null: _far_bg_back_base_pos = _layer_far_bg_back.position
