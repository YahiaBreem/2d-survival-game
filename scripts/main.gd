# ===========================================================================
# MAIN — Scene root script
#
# Responsibilities:
#   1. Wire up ChunkManager with layer nodes and WorldGen.
#   2. Drive ChunkManager.update() every frame with the player's tile position.
#   3. Parallax scrolling for far-background layers.
#   4. Death → loading screen → respawn flow.
#   5. Loading screen: shows an overlay until the first batch of chunks
#      around the spawn point is LOADED.
#
# SCENE SETUP (Godot editor):
#   • WorldGen node must be in the group "world_gen".
#   • TileMapLayer nodes in groups:
#       "layer_main", "layer_object", "layer_back_wall", "layer_background"
#   • Player CharacterBody2D in group "player".
#   • Optional far-background Sprite2D/Node2D in groups:
#       "layer_far_background_front", "layer_far_background_back"
#   • Optional CanvasLayer with a ColorRect in group "loading_screen".
#     The ColorRect should be Anchor Full Rect so it covers the screen.
#   • Optional Label child of that ColorRect in group "loading_label".
# ===========================================================================
extends Node2D

@export_group("Parallax")
@export var far_background_front_parallax: float = 0.82
@export var far_background_back_parallax:  float = 0.92

@export_group("Spawn")
## World tile x column the player spawns/respawns on.
@export var spawn_tile_x: int = 0

@export_group("Loading Screen")
## Chunks to load on each side of the player before hiding the loading screen.
@export var loading_min_chunks: int = 3

# ---------------------------------------------------------------------------
var _player:           CharacterBody2D = null
var _world_gen:        Node            = null
var _layer_main:       TileMapLayer    = null
var _layer_object:     TileMapLayer    = null
var _layer_back_wall:  TileMapLayer    = null
var _layer_background: TileMapLayer    = null
var _layer_far_front:  Node2D          = null
var _layer_far_back:   Node2D          = null
var _cam:              Camera2D        = null

var _far_front_base_x: float = 0.0
var _far_back_base_x:  float = 0.0
var _base_cam_x:       float = 0.0

var _loading_overlay: CanvasItem = null
var _loading_label:   Label      = null
var _loading_done:    bool       = false

# ---------------------------------------------------------------------------
func _ready() -> void:
	_layer_main       = get_tree().get_first_node_in_group("layer_main")       as TileMapLayer
	_layer_object     = get_tree().get_first_node_in_group("layer_object")     as TileMapLayer
	_layer_back_wall  = get_tree().get_first_node_in_group("layer_back_wall")  as TileMapLayer
	_layer_background = get_tree().get_first_node_in_group("layer_background") as TileMapLayer

	_layer_far_front = get_tree().get_first_node_in_group("layer_far_background_front") as Node2D
	if _layer_far_front == null:
		_layer_far_front = get_tree().get_first_node_in_group("layer_far_background") as Node2D
	_layer_far_back = get_tree().get_first_node_in_group("layer_far_background_back") as Node2D

	_world_gen = get_tree().get_first_node_in_group("world_gen")
	_player    = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_cam       = get_viewport().get_camera_2d()

	_loading_overlay = get_tree().get_first_node_in_group("loading_screen") as CanvasItem
	_loading_label   = get_tree().get_first_node_in_group("loading_label")  as Label

	if _loading_overlay != null:
		_loading_overlay.visible = true
	if _loading_label != null:
		_loading_label.text = "Generating world..."

	if _layer_far_front != null: _far_front_base_x = _layer_far_front.position.x
	if _layer_far_back  != null: _far_back_base_x  = _layer_far_back.position.x
	if _cam             != null: _base_cam_x        = _cam.global_position.x

	# Wire ChunkManager
	if _layer_main != null:
		ChunkManager.init_layers(_layer_main, _layer_object, _layer_back_wall, _layer_background)
	else:
		push_error("Main: 'layer_main' not found — chunk system cannot run.")

	if _world_gen != null:
		ChunkManager.init_world_gen(_world_gen)
	else:
		push_error("Main: 'world_gen' not found — chunk system cannot run.")

	# Wire death signal
	if not PlayerStats.died.is_connected(_on_player_died):
		PlayerStats.died.connect(_on_player_died)

	_place_player_at_spawn()

# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	_refresh_refs()
	if _player == null:
		return

	var player_tile_x: int = _get_player_tile_x()
	ChunkManager.update(player_tile_x)

	if not _loading_done:
		_check_loading_complete(player_tile_x)

	_update_parallax()

# ---------------------------------------------------------------------------
# SPAWN
# ---------------------------------------------------------------------------
func _place_player_at_spawn() -> void:
	if _player == null:
		return
	var tile_size: float = 32.0
	var wx: float = float(spawn_tile_x) * tile_size + tile_size * 0.5
	var wy: float = 0.0
	if _world_gen != null:
		var mid: int = _world_gen.get("surface_mid_y") if _world_gen.get("surface_mid_y") != null else 30
		wy = float(mid) * tile_size
	_player.global_position = Vector2(wx, wy - tile_size * 5)

# ---------------------------------------------------------------------------
# LOADING SCREEN
# ---------------------------------------------------------------------------
func _check_loading_complete(player_tile_x: int) -> void:
	var total_needed: int = loading_min_chunks * 2 + 1
	var chunks_ready: int = 0
	for i in range(-loading_min_chunks, loading_min_chunks + 1):
		if ChunkManager.is_loaded(player_tile_x + i * ChunkManager.CHUNK_WIDTH):
			chunks_ready += 1

	if _loading_label != null:
		_loading_label.text = "Loading world... %d / %d" % [chunks_ready, total_needed]

	if chunks_ready >= total_needed:
		_loading_done = true
		if _loading_overlay != null:
			_loading_overlay.visible = false
		# Snap player to actual surface height now that terrain is loaded
		var surf_y: int = ChunkManager.get_surface_height(spawn_tile_x)
		if surf_y > 0 and _player != null:
			var ts: float = 32.0
			_player.global_position.y = float(surf_y) * ts - ts

# ---------------------------------------------------------------------------
# DEATH / RESPAWN
# ---------------------------------------------------------------------------
func _on_player_died() -> void:
	_loading_done = false
	if _loading_overlay != null:
		_loading_overlay.visible = true
	if _loading_label != null:
		_loading_label.text = "You died..."
	await get_tree().create_timer(2.0).timeout
	PlayerStats.respawn()
	_place_player_at_spawn()
	if _loading_label != null:
		_loading_label.text = "Respawning..."

# ---------------------------------------------------------------------------
# PARALLAX
# ---------------------------------------------------------------------------
func _update_parallax() -> void:
	if _cam == null:
		return
	var dx: float = _cam.global_position.x - _base_cam_x
	if _layer_far_front != null:
		_layer_far_front.position.x = _far_front_base_x - dx * (1.0 - clamp(far_background_front_parallax, 0.0, 1.0))
	if _layer_far_back != null:
		_layer_far_back.position.x = _far_back_base_x - dx * (1.0 - clamp(far_background_back_parallax, 0.0, 1.0))

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _get_player_tile_x() -> int:
	if _player == null:
		return spawn_tile_x
	return int(floor(_player.global_position.x / 32.0))

func _refresh_refs() -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
		if _cam != null:
			_base_cam_x = _cam.global_position.x
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _layer_far_front == null:
		_layer_far_front = get_tree().get_first_node_in_group("layer_far_background_front") as Node2D
		if _layer_far_front == null:
			_layer_far_front = get_tree().get_first_node_in_group("layer_far_background") as Node2D
		if _layer_far_front != null:
			_far_front_base_x = _layer_far_front.position.x
	if _layer_far_back == null:
		_layer_far_back = get_tree().get_first_node_in_group("layer_far_background_back") as Node2D
		if _layer_far_back != null:
			_far_back_base_x = _layer_far_back.position.x