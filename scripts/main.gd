# ---------------------------------------------------------------------------
# MAIN SCENE CONTROLLER
# ---------------------------------------------------------------------------
extends Node2D

@export_group("Parallax")
@export var background_parallax_factor:           float = 0.88
@export var far_background_front_parallax_factor: float = 0.82
@export var far_background_back_parallax_factor:  float = 0.92

@export_group("Respawn")
@export var respawn_delay: float = 3.0

@export_group("Mobs")
@export var cow_scene: PackedScene

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

var _spawn_position:  Vector2 = Vector2.ZERO
var _world_ready:     bool    = false
var _player_dead:     bool    = false
var _respawn_timer:   float   = 0.0
var _load_dots:       int     = 0
var _load_dot_timer:  float   = 0.0

const LOAD_DOT_INTERVAL: float = 0.4

# ---------------------------------------------------------------------------
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
	_cam       = get_viewport().get_camera_2d()

	# Freeze player immediately — keep at a safe off-screen position
	# until we know the real spawn point from WorldGen.
	_freeze_player(Vector2(-99999, -99999))

	# Show loading screen
	if _loading_screen != null:
		_loading_screen.visible = true
	if _death_screen != null:
		_death_screen.visible = false

	# Connect WorldGen signal
	if _world_gen == null:
		push_warning("Main: WorldGen not found — skipping loading screen.")
		_unfreeze_player()
		_world_ready = true

	# Connect death signal
	if not PlayerStats.died.is_connected(_on_player_died):
		PlayerStats.died.connect(_on_player_died)

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_2d()

	_try_resolve_layers()

	# Loading label animation
	if not _world_ready:
		# Poll WorldGen each frame — more reliable than signals for cross-node timing
		if _world_gen != null and _world_gen.get("_gen_complete") == true:
			on_world_ready()
		if _loading_label != null:
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

# ---------------------------------------------------------------------------
# GENERATION COMPLETE
# ---------------------------------------------------------------------------
## Called by polling loop in _process once WorldGen._gen_complete is true.
func on_world_ready() -> void:
	if _world_ready:
		return
	_world_ready = true  # set first to stop polling loop

	# Read spawn position from WorldGen
	if _world_gen != null and "spawn_world_position" in _world_gen:
		var wpos: Vector2 = _world_gen.spawn_world_position
		if wpos != Vector2.ZERO:
			_spawn_position = wpos

	# Apply far background centering offset
	var far_offset: float = 0.0
	if _world_gen != null and "far_bg_center_offset_x" in _world_gen:
		far_offset = _world_gen.far_bg_center_offset_x
	if _layer_far_bg_front != null:
		_layer_far_bg_front.position.x = far_offset
	if _layer_far_bg_back != null:
		_layer_far_bg_back.position.x  = far_offset

	# Capture parallax bases after offset applied
	if _layer_bg           != null: _bg_base_pos           = _layer_bg.position
	if _layer_far_bg_front != null: _far_bg_front_base_pos = _layer_far_bg_front.position
	if _layer_far_bg_back  != null: _far_bg_back_base_pos  = _layer_far_bg_back.position
	if _cam                != null: _base_cam_x            = _cam.global_position.x

	# Place player at correct spawn and unfreeze
	_unfreeze_player()

	# Register mob spawns — world is ready so tilemap is populated
	_register_spawns()

	# Hide loading screen
	if _loading_screen != null:
		_loading_screen.visible = false

func _register_spawns() -> void:
	if cow_scene == null:
		push_warning("Main: cow_scene not assigned in Inspector — no cows will spawn.")
		return
	MobSpawner.register(cow_scene, {
		"max":            8,
		"interval":       15.0,
		"valid_tiles":    ["Grass"],
		"spawn_dist_min": 200.0,
		"spawn_dist_max": 600.0,
		"group":          "cows",
	})
	print("Main: mob spawns registered.")

func _on_generation_complete(_seed_val: int, _world_w: int, _mtn_far: Array, _mtn_near: Array) -> void:
	pass  # kept for signal compatibility — logic is in on_world_ready

# ---------------------------------------------------------------------------
# DEATH & RESPAWN
# ---------------------------------------------------------------------------
func _on_player_died() -> void:
	if _player_dead:
		return
	_player_dead   = true
	_respawn_timer = respawn_delay
	if _death_screen != null:
		_death_screen.visible = true
	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_DISABLED

func _do_respawn() -> void:
	_player_dead = false
	if _death_screen != null:
		_death_screen.visible = false
	PlayerStats.respawn()
	_unfreeze_player()
	if _world_gen != null and _world_gen.has_method("force_load_around"):
		_world_gen.force_load_around(_spawn_position.x)

# ---------------------------------------------------------------------------
# PLAYER FREEZE / UNFREEZE
# ---------------------------------------------------------------------------
func _freeze_player(at_position: Vector2) -> void:
	if _player == null:
		return
	_player.process_mode    = Node.PROCESS_MODE_DISABLED
	_player.global_position = at_position
	_player.velocity        = Vector2.ZERO

func _unfreeze_player() -> void:
	if _player == null:
		return
	_player.global_position = _spawn_position
	_player.velocity        = Vector2.ZERO
	_player.process_mode    = Node.PROCESS_MODE_INHERIT

# ---------------------------------------------------------------------------
# PARALLAX
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
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
