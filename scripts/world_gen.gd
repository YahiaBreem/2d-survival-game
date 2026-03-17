# ---------------------------------------------------------------------------
# WORLD GENERATOR — with built-in Chunk Streaming
#
# LAYER SYSTEM (back → front):
#   layer_background       (z -60) — decorative scenery, non-interactive
#   layer_back_wall        (z -40) — cave/dungeon walls, placeable/breakable
#   layer_object           (z -20) — tree trunks, workstations, furniture
#   layer_main             (z   0) — solid terrain, collision, primary gameplay
#
# HOW THE CHUNK SYSTEM WORKS:
#   1. On startup a background Thread runs _thread_generate(), which builds
#      every block for the entire world into _chunk_data[] — plain Dictionaries,
#      no TileMapLayer writes, so it is fully thread-safe.
#   2. Each frame _process() checks whether the player has moved into a new
#      chunk.  If so, _update_loaded_chunks() loads nearby chunks into the
#      TileMapLayers and unloads distant ones.
#   3. LOAD_RADIUS / UNLOAD_RADIUS create a hysteresis band so the player
#      can walk back and forth on a chunk border without thrashing.
#   4. Far-background and spawn-platform tiles are written once on the main
#      thread after the generation thread finishes (_apply_static_layers).
#
# ADDING A NEW TREE TYPE:
#   1. Add the log and leaves blocks to BlockRegistry (with PNGs).
#   2. Add an entry to TREE_TYPES below — that is it.
# ---------------------------------------------------------------------------
extends Node

## Emitted when the world has fully generated.
## Passes mountain height arrays (world-space y pixels) for the far background.
signal generation_complete(seed_val: int, world_w: int, mtn_far: Array, mtn_near: Array)

# ---------------------------------------------------------------------------
# CHUNK CONSTANTS
# ---------------------------------------------------------------------------
const CHUNK_WIDTH:   int = 16   # columns per chunk
const LOAD_RADIUS:   int = 6    # chunks to keep loaded on each side of the player
const UNLOAD_RADIUS: int = 8    # chunks beyond this are erased from the tilemap

# Far background chunk constants — wider chunks, separate load radii
const FAR_CHUNK_WIDTH:   int   = 64    # far bg chunk width in tiles
const FAR_LOAD_RADIUS:   int   = 3     # far chunks loaded each side of player
const FAR_UNLOAD_RADIUS: int   = 5     # far chunks unloaded beyond this
const FAR_SCALE:         float = 0.55  # tile scale — makes mountains look distant
# Encoding offset — added to y before encoding so negative y values never
# break integer division/modulo. Must be larger than any negative y in the world.
const ENCODE_Y_OFFSET:   int   = 200

# ---------------------------------------------------------------------------
# BIOME / LANDFORM IDs
# ---------------------------------------------------------------------------
const BIOME_BIRCH_FOREST: int = 0
const BIOME_FOREST:       int = 1
const BIOME_PLAINS:       int = 2
const BIOME_DESERT:       int = 3

enum LandformType { PLAINS, ROLLING_HILLS, CLIFFS, PLATEAUS, VALLEYS }

# ---------------------------------------------------------------------------
# TREE TYPES
# ---------------------------------------------------------------------------
const TREE_TYPES: Array = [
	{ "log": "Oak Log",      "leaves": "Oak Leaves",      "surface": "Grass", "crown": true,  "biomes": [BIOME_FOREST, BIOME_PLAINS],       "weight": 5, "height_min": 4, "height_max": 7  },
	{ "log": "Birch Log",    "leaves": "Birch Leaves",    "surface": "Grass", "crown": true,  "biomes": [BIOME_BIRCH_FOREST, BIOME_PLAINS], "weight": 5, "height_min": 5, "height_max": 8  },
	{ "log": "Acacia Log",   "leaves": "Acacia Leaves",   "surface": "Grass", "crown": true,  "biomes": [BIOME_PLAINS],                     "weight": 2, "height_min": 5, "height_max": 7  },
	{ "log": "Spruce Log",   "leaves": "Spruce Leaves",   "surface": "Grass", "crown": true,  "biomes": [BIOME_FOREST],                     "weight": 3, "height_min": 6, "height_max": 9  },
	{ "log": "Jungle Log",   "leaves": "Jungle Leaves",   "surface": "Grass", "crown": true,  "biomes": [BIOME_FOREST],                     "weight": 2, "height_min": 7, "height_max": 10 },
	{ "log": "Dark Oak Log", "leaves": "Dark Oak Leaves", "surface": "Grass", "crown": true,  "biomes": [BIOME_FOREST],                     "weight": 2, "height_min": 5, "height_max": 7  },
	{ "log": "Cactus",       "leaves": "Cactus",          "surface": "Sand",  "crown": false, "biomes": [BIOME_DESERT],                     "weight": 8, "height_min": 3, "height_max": 6  },
]

# ---------------------------------------------------------------------------
# EXPORTS
# ---------------------------------------------------------------------------
@export var tilemap_source_id: int = 0

@export_group("Seed")
@export var seed_value: int = 0

@export_group("World Size")
@export var world_width:       int   = 800
@export var surface_mid_y:     int   = 30
@export var terrain_amplitude: int   = 20

@export_group("Main Terrain Shaping")
@export var macro_height_scale:         float = 1.75
@export var plains_scale:               float = 0.26
@export var hills_scale:                float = 0.85
@export var cliffs_scale:               float = 1.35
@export var plateau_scale:              float = 0.70
@export var valley_scale:               float = 1.00
@export var terrain_variation_strength: float = 0.62
@export var terrain_detail_strength:    float = 0.10

@export_group("Landform Thresholds")
@export var landform_plain_threshold:   float = 0.12
@export var landform_hills_threshold:   float = 0.38
@export var landform_cliffs_threshold:  float = 0.62
@export var landform_plateau_threshold: float = 0.82

@export_group("Cliff / Plateau / Valley Controls")
@export var cliff_sharpness:          float = 2.8
@export var cliff_ledge_step_tiles:   int   = 2
@export var plateau_flatten_strength: float = 0.70
@export var plateau_step_tiles:       int   = 2
@export var valley_depth_strength:    float = 1.20
@export var valley_width_strength:    float = 0.75

@export_group("Surface Smoothing")
@export var main_surface_smooth_radius: int = 1

@export_group("Underground Layers")
@export var dirt_depth:        int = 4
@export var stone_start_depth: int = 5

@export_group("Caves")
@export var cave_threshold: float = 0.62

@export_group("Ores")
@export var coal_threshold:     float = 0.69
@export var copper_threshold:   float = 0.75
@export var iron_threshold:     float = 0.80
@export var gold_threshold:     float = 0.83
@export var diamond_threshold:  float = 0.90
@export var titanium_threshold: float = 0.93

@export var copper_min_depth:       int = 5
@export var copper_max_depth:       int = 24
@export var iron_min_depth:         int = 18
@export var iron_max_depth:         int = 60
@export var gold_shallow_min_depth: int = 8
@export var gold_shallow_max_depth: int = 18
@export var gold_deep_min_depth:    int = 28
@export var gold_deep_max_depth:    int = 60
@export var diamond_min_depth:      int = 42
@export var diamond_max_depth:      int = 80
@export var titanium_min_depth:     int = 50
@export var titanium_max_depth:     int = 100

@export_group("Background Shaping")
@export var bg_mountain_scale:        float = 1.05
@export var bg_mountain_y_offset:     int   = -6
@export var bg_match_main_strength:   float = 0.78
@export var bg_match_main_offset:     int   = 8
@export var bg_match_noise_strength:  float = 3.0
@export var bg_large_shape_scale:     float = 0.95
@export var bg_mid_shape_scale:       float = 0.45
@export var bg_detail_shape_scale:    float = 0.12
@export var bg_shape_power:           float = 1.35
@export var bg_cliff_strength:        float = 0.35
@export var bg_cliff_step_tiles:      int   = 1
@export var bg_surface_smooth_radius: int   = 4
@export var bg_ore_chance:            float = 0.06

@export_group("Far Background Shaping")
@export var far_mtn_width_multiplier:      int   = 4
@export var far_mtn_amplitude:             float = 120.0
@export var near_mtn_amplitude:            float = 70.0
@export var far_bg_mountain_scale:         float = 1.8
@export var far_bg_y_offset:               int   = -4
@export var far_peak_scale:                float = 1.0
@export var far_secondary_scale:           float = 0.22
@export var far_detail_scale:              float = 0.03
@export var far_shape_power:               float = 1.25
@export var far_valley_bias:               float = 0.12
@export var far_bg_cliff_strength:         float = 0.50
@export var far_bg_cliff_step_tiles:       int   = 2
@export var far_bg_cliff_region_threshold: float = 0.72
@export var far_bg_cliff_drop_scale:       float = 0.28
@export var far_bg_smooth_radius:          int   = 12
@export var far_bg_front_band_depth:       int   = 20
@export var far_bg_back_band_depth:        int   = 14
@export var far_bg_back_vertical_offset:   int   = -8
@export var far_bg_back_flatten:           float = 0.60

@export_group("Water")
@export var sea_level:          int   = 36
@export var lake_attempt_ratio: float = 0.025
@export var lake_min_radius:    int   = 3
@export var lake_max_radius:    int   = 6
@export var lake_min_depth:     int   = 2
@export var lake_max_depth:     int   = 4

@export_group("Bedrock")
@export var bedrock_base_layers:  int = 3
@export var bedrock_extra_layers: int = 2

@export_group("Trees")
@export var tree_chance:     float = 0.4
@export var tree_min_height: int   = 4
@export var tree_max_height: int   = 7

@export_group("Spawn")
## Tile column the player spawns at. -1 = auto (center of world).
@export var spawn_tile_x: int = -1

# ---------------------------------------------------------------------------
# TILEMAP LAYER REFERENCES
# ---------------------------------------------------------------------------
var _main:                TileMapLayer = null
var _object:              TileMapLayer = null
var _back_wall:           TileMapLayer = null
var _background:          TileMapLayer = null
var _far_background_front:TileMapLayer = null
var _far_background_back: TileMapLayer = null

# ---------------------------------------------------------------------------
# NOISE INSTANCES
# ---------------------------------------------------------------------------
var _continental_noise:       FastNoiseLite = FastNoiseLite.new()
var _terrain_variation_noise: FastNoiseLite = FastNoiseLite.new()
var _landform_noise:          FastNoiseLite = FastNoiseLite.new()
var _cliff_control_noise:     FastNoiseLite = FastNoiseLite.new()
var _plateau_control_noise:   FastNoiseLite = FastNoiseLite.new()
var _valley_control_noise:    FastNoiseLite = FastNoiseLite.new()
var _detail_noise:            FastNoiseLite = FastNoiseLite.new()
var _bg_macro_noise:          FastNoiseLite = FastNoiseLite.new()
var _bg_mid_noise:            FastNoiseLite = FastNoiseLite.new()
var _bg_detail_noise:         FastNoiseLite = FastNoiseLite.new()
var _far_primary_noise:       FastNoiseLite = FastNoiseLite.new()
var _far_secondary_noise:     FastNoiseLite = FastNoiseLite.new()
var _far_detail_noise:        FastNoiseLite = FastNoiseLite.new()
var _far_valley_noise:        FastNoiseLite = FastNoiseLite.new()
var _cave_noise:              FastNoiseLite = FastNoiseLite.new()
var _ore_noise:               FastNoiseLite = FastNoiseLite.new()
var _bg_ore_noise:            FastNoiseLite = FastNoiseLite.new()
var _biome_noise:             FastNoiseLite = FastNoiseLite.new()
var _tree_noise:              FastNoiseLite = FastNoiseLite.new()
var _rng:                     RandomNumberGenerator = RandomNumberGenerator.new()

# ---------------------------------------------------------------------------
# CACHED ATLAS COORDS
# ---------------------------------------------------------------------------
var _c_grass:    Vector2i = Vector2i(-1,-1)
var _c_dirt:     Vector2i = Vector2i(-1,-1)
var _c_sand:     Vector2i = Vector2i(-1,-1)
var _c_water:    Vector2i = Vector2i(-1,-1)
var _c_bedrock:  Vector2i = Vector2i(-1,-1)
var _c_stone:    Vector2i = Vector2i(-1,-1)
var _c_gravel:   Vector2i = Vector2i(-1,-1)
var _c_diorite:  Vector2i = Vector2i(-1,-1)
var _c_granite:  Vector2i = Vector2i(-1,-1)
var _c_andesite: Vector2i = Vector2i(-1,-1)
var _c_coal:     Vector2i = Vector2i(-1,-1)
var _c_iron:     Vector2i = Vector2i(-1,-1)
var _c_copper:   Vector2i = Vector2i(-1,-1)
var _c_gold:     Vector2i = Vector2i(-1,-1)
var _c_diamond:  Vector2i = Vector2i(-1,-1)
var _c_titanium: Vector2i = Vector2i(-1,-1)
var _tree_type_coords: Array = []

# ---------------------------------------------------------------------------
# CHUNK DATA
# _chunk_data[cx] = { "main":{}, "back_wall":{}, "object":{}, "background":{} }
# Keys are encoded ints: (y + ENCODE_Y_OFFSET) * 100000 + local_x  (local_x in 0..CHUNK_WIDTH-1)
# ---------------------------------------------------------------------------
var _chunk_data:     Array      = []
var _loaded_chunks:  Dictionary = {}   # cx -> true
var _gen_complete:   bool       = false
var _surface_heights:Array[int] = []

var _gen_thread:  Thread = Thread.new()
var _thread_done: bool   = false

var _last_mtn_far:  Array[float] = []
var _last_mtn_near: Array[float] = []
var _last_player_chunk:     int = -99999

# Far background chunk data (separate from main _chunk_data)
# _far_chunk_data[cx] = { "front":{}, "back":{} }
# Total columns = world_width * far_mtn_width_multiplier
# cx is in far-tile space (1 far tile = 1 normal tile at FAR_SCALE size)
var _far_chunk_data:        Array      = []
## Set after generation — main.gd reads this to place the player correctly.
var spawn_world_position:    Vector2   = Vector2.ZERO
## X offset main.gd should apply to both far background layers for centering.
var far_bg_center_offset_x:  float     = 0.0
var _far_loaded_chunks:     Dictionary = {}   # cx -> true
var _last_player_far_chunk: int        = -99999
var _far_total_width:       int        = 0    # set during generation

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	_main               = get_tree().get_first_node_in_group("layer_main")               as TileMapLayer
	_object             = get_tree().get_first_node_in_group("layer_object")             as TileMapLayer
	_back_wall          = get_tree().get_first_node_in_group("layer_back_wall")          as TileMapLayer
	_background         = get_tree().get_first_node_in_group("layer_background")         as TileMapLayer
	_far_background_front = get_tree().get_first_node_in_group("layer_far_background_front") as TileMapLayer
	if _far_background_front == null:
		_far_background_front = get_tree().get_first_node_in_group("layer_far_background") as TileMapLayer
	_far_background_back  = get_tree().get_first_node_in_group("layer_far_background_back")  as TileMapLayer

	if _main == null:
		push_error("WorldGen: 'layer_main' group not found. Aborting.")
		return
	if _object    == null: push_warning("WorldGen: 'layer_object' not found.")
	if _back_wall == null: push_warning("WorldGen: 'layer_back_wall' not found.")
	if _background== null: push_warning("WorldGen: 'layer_background' not found.")

	await get_tree().process_frame
	await get_tree().process_frame

	if not TileSetBuilder.tileset_ready:
		push_error("WorldGen: TileSetBuilder did not finish. Aborting.")
		return

	if seed_value == 0:
		seed_value = randi()
	print("WorldGen: seed = %d" % seed_value)

	_cache_atlas_coords()
	_setup_noise()
	_gen_thread.start(_thread_generate)

# ---------------------------------------------------------------------------
# PROCESS — poll thread completion + drive chunk streaming
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not _gen_complete:
		if _thread_done:
			_gen_thread.wait_to_finish()
			_gen_complete = true
			_apply_static_layers()
			print("WorldGen: complete. Chunk streaming active.")
			# Emit signal — main.gd polls _gen_complete each frame and will catch it
			_emit_generation_complete()
		return

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var cx: int = _world_x_to_chunk(player.global_position.x)
	if cx != _last_player_chunk:
		_last_player_chunk = cx
		_update_loaded_chunks(cx)

	# Far background chunk streaming (wider chunks, own radius)
	var far_cx: int = _world_x_to_far_chunk(player.global_position.x)
	if far_cx != _last_player_far_chunk:
		_last_player_far_chunk = far_cx
		_update_far_loaded_chunks(far_cx)

# ---------------------------------------------------------------------------
# BACKGROUND THREAD — pure data, never touches nodes
# ---------------------------------------------------------------------------
func _thread_generate() -> void:
	var nc: int = _chunk_count()
	_chunk_data.resize(nc)
	for i in nc:
		_chunk_data[i] = { "main": {}, "back_wall": {}, "object": {}, "background": {} }

	_surface_heights = _generate_main_surface_heights()

	for x in world_width:
		_generate_column_data(x, _surface_heights[x])

	_generate_lakes_data()
	_generate_sea_level_data()
	_generate_background_data()

	for x in world_width:
		_generate_tree_data(x, _surface_heights[x])

	_settle_physical_data()

	_generate_far_chunk_data()
	_last_mtn_far  = _generate_far_silhouette_heights(far_mtn_amplitude)
	_last_mtn_near = _generate_far_silhouette_heights(near_mtn_amplitude * 0.9)
	_thread_done   = true

# ---------------------------------------------------------------------------
# CHUNK STREAMING  (main thread — safe to call Godot API)
# ---------------------------------------------------------------------------
func _update_loaded_chunks(player_chunk: int) -> void:
	var nc: int = _chunk_count()
	for cx in range(max(0, player_chunk - LOAD_RADIUS),
	                min(nc,  player_chunk + LOAD_RADIUS + 1)):
		if not _loaded_chunks.has(cx):
			_load_chunk(cx)
	var to_unload: Array = []
	for cx in _loaded_chunks.keys():
		if abs(cx - player_chunk) > UNLOAD_RADIUS:
			to_unload.append(cx)
	for cx in to_unload:
		_unload_chunk(cx)

func _load_chunk(chunk_x: int) -> void:
	if chunk_x < 0 or chunk_x >= _chunk_count():
		return
	var data:    Dictionary = _chunk_data[chunk_x]
	var x_start: int        = chunk_x * CHUNK_WIDTH
	_write_layer_cells(_main,       data["main"],       x_start)
	_write_layer_cells(_back_wall,  data["back_wall"],  x_start)
	_write_layer_cells(_object,     data["object"],     x_start)
	_write_layer_cells(_background, data["background"], x_start)
	_loaded_chunks[chunk_x] = true

func _unload_chunk(chunk_x: int) -> void:
	var x_start:      int = chunk_x * CHUNK_WIDTH
	var world_bottom: int = _world_bottom()
	var world_top:    int = surface_mid_y - terrain_amplitude - 40
	for x in range(x_start, x_start + CHUNK_WIDTH):
		for y in range(world_top, world_bottom):
			var cell: Vector2i = Vector2i(x, y)
			_main.erase_cell(cell)
			if _back_wall  != null: _back_wall.erase_cell(cell)
			if _object     != null: _object.erase_cell(cell)
			if _background != null: _background.erase_cell(cell)
	_loaded_chunks.erase(chunk_x)

func _write_layer_cells(layer: TileMapLayer, cells: Dictionary, x_start: int) -> void:
	if layer == null:
		return
	for encoded: int in cells.keys():
		var local_x: int    = encoded % 100000
		var y:       int    = encoded / 100000 - ENCODE_Y_OFFSET
		var atlas:   Vector2i = cells[encoded]
		layer.set_cell(Vector2i(x_start + local_x, y), tilemap_source_id, atlas)

# ---------------------------------------------------------------------------
# STATIC LAYERS  (far background + spawn platform — written once on main thread)
# ---------------------------------------------------------------------------
func _apply_static_layers() -> void:
	if _far_background_front != null: _far_background_front.clear()
	if _far_background_back  != null: _far_background_back.clear()
	# Apply scale so tiles appear smaller / more distant
	if _far_background_front != null: _far_background_front.scale = Vector2(FAR_SCALE, FAR_SCALE)
	if _far_background_back  != null: _far_background_back.scale  = Vector2(FAR_SCALE, FAR_SCALE)
	# Calculate centering offset but do NOT apply it here — main.gd applies it
	# once in _on_generation_complete after capturing the parallax base position.
	var tile_px:   float = 32.0 * FAR_SCALE
	far_bg_center_offset_x = -float((_far_total_width - world_width) / 2) * tile_px
	_carve_spawn_platform()
	# Trigger the initial far chunk load — player position may not have changed
	# yet so _process won't catch it without this explicit call.
	# Use spawn_world_position so chunks load around where the player actually starts.
	var start_x: float = spawn_world_position.x if spawn_world_position != Vector2.ZERO else float(world_width / 2) * 32.0
	# Main chunks
	var spawn_cx: int = _world_x_to_chunk(start_x)
	_last_player_chunk = spawn_cx
	_update_loaded_chunks(spawn_cx)
	# Far chunks
	var far_cx: int = _world_x_to_far_chunk(start_x)
	_last_player_far_chunk = far_cx
	_update_far_loaded_chunks(far_cx)
	if not _far_chunk_data.is_empty():
		var sample: Dictionary = _far_chunk_data[0]

# ---------------------------------------------------------------------------
# COLUMN DATA BUILDER
# ---------------------------------------------------------------------------
func _generate_column_data(x: int, surface_y: int) -> void:
	var world_bottom: int = _world_bottom()
	var biome_id:     int = _get_biome_id(x)
	var is_desert:    bool= biome_id == BIOME_DESERT
	var cx:           int = x / CHUNK_WIDTH
	var lx:           int = x % CHUNK_WIDTH
	var md: Dictionary = _chunk_data[cx]["main"]
	var wd: Dictionary = _chunk_data[cx]["back_wall"]

	for y in range(surface_y, world_bottom):
		var depth: int = y - surface_y
		var key:   int = (y + ENCODE_Y_OFFSET) * 100000 + lx

		if _is_bedrock_cell(x, y, world_bottom):
			var bc: Vector2i = _c_bedrock if _c_bedrock != Vector2i(-1,-1) else _c_stone
			md[key] = bc
			wd[key] = bc
			continue

		var is_cave: bool = false
		if depth > 2:
			var cave_v: float = (_cave_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var cutoff: float = cave_threshold - (0.05 if depth > 20 else 0.0)
			if cave_v > cutoff:
				is_cave = true
			elif depth > 10:
				var tunnel: float = (_cave_noise.get_noise_2d(float(x) * 1.7, float(y) * 0.75 + 140.0) + 1.0) * 0.5
				if tunnel > cutoff + 0.08:
					is_cave = true

		var atlas: Vector2i = _pick_fg_block(x, y, depth, biome_id, is_desert)
		if atlas == Vector2i(-1,-1):
			continue

		if is_cave:
			wd[key] = atlas
		else:
			md[key] = atlas
			wd[key] = atlas

# ---------------------------------------------------------------------------
# BACKGROUND DATA BUILDER
# ---------------------------------------------------------------------------
func _generate_background_data() -> void:
	# NOTE: do NOT check _background != null here — this runs on the worker
	# thread where node refs are meaningless. The null check lives in
	# _write_layer_cells() which only runs on the main thread.
	var world_top:    int        = surface_mid_y - terrain_amplitude - 40
	var world_bottom: int        = _world_bottom()
	var bg_heights:   Array[int] = _compute_bg_surface_heights()

	for x in world_width:
		var bg_y:   int  = bg_heights[x]
		var biome:  int  = _get_biome_id(x)
		var desert: bool = biome == BIOME_DESERT
		var cx:     int  = x / CHUNK_WIDTH
		var lx:     int  = x % CHUNK_WIDTH
		var bd: Dictionary = _chunk_data[cx]["background"]

		for y in range(max(world_top, bg_y), world_bottom):
			var depth: int     = y - bg_y
			var atlas: Vector2i = _pick_bg_block(x, y, depth, desert)
			if atlas != Vector2i(-1,-1):
				bd[(y + ENCODE_Y_OFFSET) * 100000 + lx] = atlas

func _compute_bg_surface_heights() -> Array[int]:
	var h:   Array[int] = []
	h.resize(world_width)
	var ms: float = clamp(bg_match_main_strength, 0.0, 1.0)
	for x in world_width:
		var shaped: int   = _get_bg_surface_height(x) + bg_mountain_y_offset
		var matched:int   = _surface_heights[x] + bg_match_main_offset
		var blend:  float = lerp(float(shaped), float(matched), ms)
		var noise:  float = _bg_detail_noise.get_noise_2d(float(x), 137.0) * bg_match_noise_strength
		h[x] = int(round(blend + noise))
	return _smooth_surface_heights(h, bg_surface_smooth_radius)

# ---------------------------------------------------------------------------
# LAKE DATA BUILDER
# ---------------------------------------------------------------------------
func _generate_lakes_data() -> void:
	if _c_water == Vector2i(-1,-1) or world_width < 12:
		return
	var attempts: int = max(1, int(float(world_width) * max(0.0, lake_attempt_ratio)))
	for _i in attempts:
		var cx_world: int = _rng.randi_range(6, world_width - 7)
		if _get_biome_id(cx_world) == BIOME_DESERT:
			continue
		var surf:   int = _surface_heights[cx_world]
		if surf >= sea_level - 1:
			continue
		var radius:   int = _rng.randi_range(lake_min_radius, max(lake_min_radius, lake_max_radius))
		var depth:    int = _rng.randi_range(lake_min_depth,  max(lake_min_depth,  lake_max_depth))
		var lake_top: int = surf + 1

		for dx in range(-radius, radius + 1):
			var x: int = cx_world + dx
			if x < 0 or x >= world_width:
				continue
			var edge:   float = 1.0 - abs(float(dx)) / float(radius + 1)
			var ldepth: int   = max(1, int(round(float(depth) * edge)))
			var lsurf:  int   = _surface_heights[x]
			var ch:     int   = x / CHUNK_WIDTH
			var lx:     int   = x % CHUNK_WIDTH
			var md: Dictionary = _chunk_data[ch]["main"]
			var wd: Dictionary = _chunk_data[ch]["back_wall"]

			for y in range(lsurf, lsurf + ldepth + 1):
				md.erase((y + ENCODE_Y_OFFSET) * 100000 + lx)
				if y == lsurf:
					wd.erase((y + ENCODE_Y_OFFSET) * 100000 + lx)
			for y in range(lake_top, lsurf + ldepth + 1):
				var k: int = (y + ENCODE_Y_OFFSET) * 100000 + lx
				if not md.has(k):
					md[k] = _c_water

func _generate_sea_level_data() -> void:
	if _c_water == Vector2i(-1,-1):
		return
	for x in world_width:
		var surf: int = _surface_heights[x]
		if surf <= sea_level:
			continue
		var ch: int        = x / CHUNK_WIDTH
		var lx: int        = x % CHUNK_WIDTH
		var md: Dictionary = _chunk_data[ch]["main"]
		for y in range(sea_level, surf):
			var k: int = (y + ENCODE_Y_OFFSET) * 100000 + lx
			if not md.has(k):
				md[k] = _c_water

# ---------------------------------------------------------------------------
# TREE DATA BUILDER
# ---------------------------------------------------------------------------
func _generate_tree_data(x: int, surface_y: int) -> void:
	if _tree_type_coords.is_empty():
		return
	var ch: int = x / CHUNK_WIDTH
	var lx: int = x % CHUNK_WIDTH
	var md: Dictionary = _chunk_data[ch]["main"]
	var wd: Dictionary = _chunk_data[ch]["back_wall"]

	var surf_atlas: Vector2i = md.get((surface_y + ENCODE_Y_OFFSET) * 100000 + lx, Vector2i(-1,-1))
	var surf_name:  String   = BlockRegistry.get_name_from_coords(surf_atlas)
	var biome_id:   int      = _get_biome_id(x)

	var valid: Array = []
	for tt: Dictionary in _tree_type_coords:
		if tt["surface"] == surf_name and tt["biomes"].has(biome_id):
			valid.append(tt)
	if valid.is_empty():
		return

	if md.get((surface_y - 1 + ENCODE_Y_OFFSET) * 100000 + lx, Vector2i(-1,-1)) == _c_water:
		return

	var t: float = (_tree_noise.get_noise_2d(float(x), 500.0) + 1.0) * 0.5
	var density: float = tree_chance
	if biome_id == BIOME_FOREST or biome_id == BIOME_BIRCH_FOREST: density += 0.16
	elif biome_id == BIOME_DESERT: density -= 0.06
	if t >= clamp(density, 0.05, 0.95):
		return

	for nx in range(x - 2, x + 3):
		if nx == x or nx < 0 or nx >= world_width:
			continue
		var nch: int = nx / CHUNK_WIDTH
		var nlx: int = nx % CHUNK_WIDTH
		var nh:  int = _surface_heights[nx]
		if _chunk_data[nch]["object"].has((nh - 1 + ENCODE_Y_OFFSET) * 100000 + nlx):
			return

	var chosen:      Dictionary = _pick_weighted_tree(valid)
	var c_log:       Vector2i   = chosen["log"]
	var c_leaves:    Vector2i   = chosen["leaves"]
	var h_min:       int        = chosen["height_min"]
	var h_max:       int        = max(h_min, chosen["height_max"])
	var height:      int        = h_min + (_rng.randi() % (h_max - h_min + 1))
	var crown_top_y: int        = surface_y - height - 1

	if chosen["crown"]:
		for i in height:
			var ty:  int = surface_y - 1 - i
			var tch: int = x / CHUNK_WIDTH
			var tlx: int = x % CHUNK_WIDTH
			_chunk_data[tch]["object"][(ty + ENCODE_Y_OFFSET) * 100000 + tlx] = c_log

		for row: Dictionary in _get_crown_rows(chosen["log_name"], biome_id):
			var cy: int = crown_top_y + row["dy"]
			for cx_off in range(-row["half_w"], row["half_w"] + 1):
				var lc: int = x + cx_off
				if lc < 0 or lc >= world_width:
					continue
				var lch: int = lc / CHUNK_WIDTH
				var llx: int = lc % CHUNK_WIDTH
				var lk:  int = (cy + ENCODE_Y_OFFSET) * 100000 + llx
				if not _chunk_data[lch]["main"].has(lk):
					_chunk_data[lch]["main"][lk] = c_leaves
				if not _chunk_data[lch]["back_wall"].has(lk):
					_chunk_data[lch]["back_wall"][lk] = c_leaves
	else:
		for i in height:
			var ty: int = surface_y - 1 - i
			var k:  int = (ty + ENCODE_Y_OFFSET) * 100000 + lx
			if not md.has(k):
				md[k] = c_log

# ---------------------------------------------------------------------------
# PHYSICAL BLOCK SETTLING
# ---------------------------------------------------------------------------
func _settle_physical_data() -> void:
	var world_bottom: int = _world_bottom()
	var world_top:    int = surface_mid_y - terrain_amplitude - 10
	for cx in range(_chunk_count()):
		var md:      Dictionary = _chunk_data[cx]["main"]
		var x_start: int        = cx * CHUNK_WIDTH
		for lx in CHUNK_WIDTH:
			var x: int = x_start + lx
			if x >= world_width:
				break
			for y in range(world_top, world_bottom):
				var k:     int      = (y + ENCODE_Y_OFFSET) * 100000 + lx
				var atlas: Vector2i = md.get(k, Vector2i(-1,-1))
				if atlas == Vector2i(-1,-1):
					continue
				if not BlockRegistry.is_physical(BlockRegistry.get_name_from_coords(atlas)):
					continue
				var drop_y: int = y
				while drop_y + 1 < world_bottom and not md.has((drop_y + 1) * 100000 + lx):
					drop_y += 1
				if drop_y != y:
					md.erase(k)
					md[(drop_y + ENCODE_Y_OFFSET) * 100000 + lx] = atlas

# ---------------------------------------------------------------------------
# SURFACE HEIGHT COMPUTATION
# ---------------------------------------------------------------------------
func _get_surface_height(x: int) -> int:
	var macro:   float = _continental_noise.get_noise_2d(float(x), 0.0) * macro_height_scale
	var vary:    float = _terrain_variation_noise.get_noise_2d(float(x), 0.0) * terrain_variation_strength
	var base_h:  float = float(surface_mid_y) + (macro + vary) * float(terrain_amplitude)
	var shaped:  float = _apply_landform_shape(x, base_h, _get_landform_type(x))
	var detail:  float = _detail_noise.get_noise_2d(float(x), 0.0) * terrain_detail_strength * float(terrain_amplitude)
	var biome:   int   = _get_biome_id(x)
	var bias:    float = 0.35 if biome == BIOME_FOREST else (-0.8 if biome == BIOME_DESERT else 0.0)
	return int(round(shaped + detail + bias))

func _get_bg_surface_height(x: int) -> int:
	var large:  float = _bg_macro_noise.get_noise_2d(float(x), 0.0)  * bg_large_shape_scale
	var mid:    float = _bg_mid_noise.get_noise_2d(float(x), 0.0)    * bg_mid_shape_scale
	var tiny:   float = _bg_detail_noise.get_noise_2d(float(x), 0.0) * bg_detail_shape_scale
	var raw:    float = clamp(large + mid + tiny, -1.0, 1.0)
	var signed: float = sign(raw) * pow(abs(raw), max(0.25, bg_shape_power))
	var ridge:  float = (1.0 - abs(raw)) * 2.0 - 1.0
	var n:      float = lerp(signed, ridge, clamp(bg_cliff_strength, 0.0, 1.0) * 0.35)
	var h:      float = float(surface_mid_y) + n * float(terrain_amplitude) * bg_mountain_scale
	return int(floor(h / float(max(1, bg_cliff_step_tiles))) * float(max(1, bg_cliff_step_tiles)))

func _generate_main_surface_heights() -> Array[int]:
	var h: Array[int] = []
	h.resize(world_width)
	for x in world_width:
		h[x] = _get_surface_height(x)
	return _smooth_surface_heights(h, main_surface_smooth_radius)

func _get_landform_type(x: int) -> int:
	var lf: float = (_landform_noise.get_noise_2d(float(x), 0.0) + 1.0) * 0.5
	if lf < landform_plain_threshold:   return LandformType.PLAINS
	if lf < landform_hills_threshold:   return LandformType.ROLLING_HILLS
	if lf < landform_cliffs_threshold:  return LandformType.CLIFFS
	if lf < landform_plateau_threshold: return LandformType.PLATEAUS
	return LandformType.VALLEYS

func _apply_landform_shape(x: int, base_h: float, landform: int) -> float:
	var tx: float = float(x)
	match landform:
		LandformType.PLAINS:
			return base_h + _terrain_variation_noise.get_noise_2d(tx * 0.6, 121.0) * float(terrain_amplitude) * plains_scale
		LandformType.ROLLING_HILLS:
			return base_h + _terrain_variation_noise.get_noise_2d(tx * 0.9, -82.0) * float(terrain_amplitude) * hills_scale
		LandformType.CLIFFS:
			var c:  float = (_cliff_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var s:  float = sign(c - 0.5) * pow(abs(c - 0.5) * 2.0, cliff_sharpness)
			var h:  float = base_h + s * float(terrain_amplitude) * cliffs_scale
			return floor(h / float(max(1, cliff_ledge_step_tiles))) * float(max(1, cliff_ledge_step_tiles))
		LandformType.PLATEAUS:
			var p:  float = (_plateau_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var ft: float = floor(base_h / float(max(1, plateau_step_tiles))) * float(max(1, plateau_step_tiles))
			return lerp(base_h + (p - 0.5) * float(terrain_amplitude) * plateau_scale, ft, clamp(plateau_flatten_strength, 0.0, 1.0))
		_:
			var bowl:   float = (_valley_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var carved: float = pow(1.0 - bowl, max(0.2, valley_width_strength))
			return base_h + carved * float(terrain_amplitude) * valley_scale * valley_depth_strength

func _smooth_surface_heights(raw: Array[int], radius: int) -> Array[int]:
	var r: int = max(0, radius)
	if r == 0: return raw
	var out: Array[int] = []
	out.resize(raw.size())
	for x in raw.size():
		var total: float = 0.0
		var count: int   = 0
		for k in range(-r, r + 1):
			total += float(raw[clamp(x + k, 0, raw.size() - 1)])
			count += 1
		out[x] = int(round(total / float(max(1, count))))
	return out

# ---------------------------------------------------------------------------
# BIOME
# ---------------------------------------------------------------------------
func _get_biome_id(x: int) -> int:
	var b: float = clamp((_biome_noise.get_noise_2d(float(x), 0.0) + 1.0) * 0.5, 0.0, 1.0)
	if b > 0.78: return BIOME_DESERT
	if b > 0.57: return BIOME_PLAINS
	if b > 0.32: return BIOME_FOREST
	return BIOME_BIRCH_FOREST

# ---------------------------------------------------------------------------
# BLOCK PICKERS
# ---------------------------------------------------------------------------
func _pick_fg_block(x: int, y: int, depth: int, biome_id: int, is_desert: bool) -> Vector2i:
	if depth == 0:
		return _c_sand if is_desert else _c_grass
	var sub: int = dirt_depth + (3 if biome_id == BIOME_DESERT else (1 if biome_id == BIOME_PLAINS else 0))
	if depth <= sub:
		return _c_sand if is_desert else _c_dirt
	if depth >= stone_start_depth:
		var on:  float = (_ore_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
		var on2: float = (_ore_noise.get_noise_2d(float(x) * 0.73 + 97.0, float(y) * 1.21 - 41.0) + 1.0) * 0.5
		if _in_depth_band(depth, titanium_min_depth, titanium_max_depth) and _c_titanium != Vector2i(-1,-1) and on2 > titanium_threshold: return _c_titanium
		if _in_depth_band(depth, diamond_min_depth,  diamond_max_depth)  and _c_diamond  != Vector2i(-1,-1) and on2 > diamond_threshold:  return _c_diamond
		if _in_depth_band(depth, iron_min_depth,     iron_max_depth)     and _c_iron     != Vector2i(-1,-1) and on  > iron_threshold:     return _c_iron
		var gold_in: bool = _in_depth_band(depth, gold_shallow_min_depth, gold_shallow_max_depth) or _in_depth_band(depth, gold_deep_min_depth, gold_deep_max_depth)
		if gold_in and _c_gold != Vector2i(-1,-1) and on2 > gold_threshold: return _c_gold
		if _in_depth_band(depth, copper_min_depth, copper_max_depth) and _c_copper != Vector2i(-1,-1) and on > copper_threshold: return _c_copper
		if _c_coal != Vector2i(-1,-1) and on > coal_threshold: return _c_coal
		return _pick_stone_variant(x, y, depth)
	return _c_dirt

func _pick_bg_block(x: int, y: int, depth: int, is_desert: bool) -> Vector2i:
	if depth == 0: return _c_sand if is_desert else _c_grass
	if depth <= dirt_depth: return _c_sand if is_desert else _c_dirt
	if depth >= stone_start_depth:
		if bg_cliff_step_tiles > 1 and depth < stone_start_depth + 8:
			var ld: int = int(floor(float(depth) / float(bg_cliff_step_tiles)) * float(bg_cliff_step_tiles))
			return _pick_stone_variant(x, y + ld, depth)
		return _pick_stone_variant(x, y, depth)
	return _c_dirt

func _pick_far_bg_block(x: int, y: int, depth: int, is_desert: bool) -> Vector2i:
	if depth == 0: return _c_sand if is_desert else _c_grass
	if depth <= dirt_depth + 1: return _c_sand if is_desert else _c_dirt
	return _pick_stone_variant(x, y, depth + 10)

func _pick_stone_variant(x: int, y: int, depth: int) -> Vector2i:
	var n: float = (_detail_noise.get_noise_2d(float(x) * 0.55 + 31.0, float(y) * 0.55 - 19.0) + 1.0) * 0.5
	if depth >= stone_start_depth + 3 and _c_gravel  != Vector2i(-1,-1) and n > 0.965: return _c_gravel
	if _c_granite  != Vector2i(-1,-1) and n < 0.18:              return _c_granite
	if _c_diorite  != Vector2i(-1,-1) and n > 0.82:              return _c_diorite
	if _c_andesite != Vector2i(-1,-1) and n > 0.47 and n < 0.59: return _c_andesite
	return _c_stone

# ---------------------------------------------------------------------------
# BEDROCK
# ---------------------------------------------------------------------------
func _is_bedrock_cell(x: int, y: int, world_bottom: int) -> bool:
	var base:      int   = max(1, bedrock_base_layers)
	var extra:     int   = max(0, bedrock_extra_layers)
	var bottom_y:  int   = world_bottom - 1
	var thresh_y:  int   = bottom_y - (base - 1)
	if y >= thresh_y: return true
	if extra == 0:    return false
	var top_y: int = thresh_y - extra
	if y < top_y:  return false
	var row:  int   = y - top_y
	var fill: float = float(row + 1) / float(extra + 1)
	var n:    float = (_detail_noise.get_noise_2d(float(x) * 0.37 + 77.0, float(y) * 0.91 - 53.0) + 1.0) * 0.5
	return n < fill


func _generate_far_back_surface(front: Array[int]) -> Array[int]:
	if front.is_empty(): return front
	var out:      Array[int] = []
	out.resize(front.size())
	var flatten:  float = clamp(far_bg_back_flatten, 0.0, 1.0)
	var horizon:  float = float(surface_mid_y) - float(terrain_amplitude) * 0.35 + float(far_bg_y_offset)
	for x in front.size():
		var h: float = lerp(float(front[x]), horizon, flatten) + float(far_bg_back_vertical_offset)
		h += _far_secondary_noise.get_noise_2d(float(x) * 0.55, 909.0) * 2.0
		out[x] = int(round(h))
	return _smooth_surface_heights(out, max(far_bg_smooth_radius + 4, 8))

func _generate_far_surface_heights() -> Array[int]:
	var out:     Array[int]    = []
	out.resize(world_width)
	var horizon: float         = float(surface_mid_y) - float(terrain_amplitude) * 0.35 + float(far_bg_y_offset)
	var peak:    float         = float(terrain_amplitude) * far_bg_mountain_scale
	var pts:     Array[Vector2i] = _generate_far_profile_points(horizon, peak)
	if pts.size() < 2:
		for x in world_width: out[x] = int(horizon)
		return out
	var seg: int = 0
	for x in world_width:
		while seg < pts.size() - 2 and x > pts[seg + 1].x:
			seg += 1
		var a: Vector2i = pts[seg]
		var b: Vector2i = pts[min(seg + 1, pts.size() - 1)]
		var t: float    = 0.0 if b.x == a.x else clamp(float(x - a.x) / float(b.x - a.x), 0.0, 1.0)
		out[x] = int(lerp(float(a.y), float(b.y), t))
	out = _smooth_surface_heights(out, far_bg_smooth_radius)
	out = _apply_far_cliff_regions(out, horizon, peak)
	out = _apply_far_cliff_features(out)
	var step: float = float(max(1, far_bg_cliff_step_tiles))
	for x in out.size():
		out[x] = int(floor(float(out[x]) / step) * step)
	return out

func _apply_far_cliff_regions(raw: Array[int], horizon: float, peak: float) -> Array[int]:
	var out:   Array[int] = raw.duplicate()
	var s:     float      = clamp(far_bg_cliff_strength, 0.0, 1.0)
	if s <= 0.01: return out
	var n: int = out.size()
	var i: int = 1
	while i < n - 2:
		var rm: float = (_cliff_control_noise.get_noise_2d(float(i) * 0.22, 1107.0) + 1.0) * 0.5
		if rm < far_bg_cliff_region_threshold:
			i += 1; continue
		var seg_len: int   = _rng.randi_range(12, 34)
		var end_i:   int   = min(n - 1, i + seg_len)
		var dm:      float = (_valley_control_noise.get_noise_2d(float(i) * 0.5, -813.0) + 1.0) * 0.5
		var drop:    float = lerp(3.0, max(4.0, peak * far_bg_cliff_drop_scale), dm) * s
		var sh:      float = float(out[i])
		var eh:      float = clamp(sh + drop, horizon - peak, horizon + peak * 0.75)
		for x in range(i, end_i + 1):
			var wt: float = pow(clamp(float(x - i) / float(max(1, end_i - i)), 0.0, 1.0), 0.58)
			out[x] = int(round(lerp(sh, eh, wt)))
		i = end_i + 1
	return _smooth_surface_heights(out, 1)

func _apply_far_cliff_features(raw: Array[int]) -> Array[int]:
	var s: float = clamp(far_bg_cliff_strength, 0.0, 1.0)
	if s <= 0.01: return raw
	var out: Array[int] = raw.duplicate()
	for x in range(1, out.size() - 1):
		var mask:  float = (_cliff_control_noise.get_noise_2d(float(x) * 0.45, 731.0) + 1.0) * 0.5
		if mask < 0.60: continue
		var slope: float = float(raw[x + 1] - raw[x - 1])
		if abs(slope) < 1.5: continue
		var lt:  float = clamp((mask - 0.60) / 0.40, 0.0, 1.0) * s
		var lh:  float = lerp(float(raw[x]), float(out[x - 1]), lt * 0.85)
		var fp:  float = sign(slope) * (1.0 + floor(lt * 3.0))
		out[x] = int(round(lh + fp))
	return _smooth_surface_heights(out, 1)

func _generate_far_profile_points(horizon: float, peak: float) -> Array[Vector2i]:
	var pts:     Array[Vector2i] = [Vector2i(0, int(horizon))]
	var x:       int   = 0
	var y:       int   = int(horizon)
	var heading: float = -1.0
	while x < world_width:
		var sw:  int   = _rng.randi_range(42, 96)
		var nx:  int   = min(world_width - 1, x + sw)
		if nx <= x: break
		var tx:  float = float(nx)
		var mp:  float = (_far_primary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var mv:  float = (_far_valley_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var drift:float= _far_secondary_noise.get_noise_2d(tx, 0.0) * peak * 0.14
		var cb:  float = (0.32 + mp * 0.50) * peak
		var db:  float = (1.0 - mv) * peak * (far_valley_bias + 0.16)
		if _rng.randf() < 0.12: heading *= -1.0
		var ty:  float = float(y) + heading * float(_rng.randi_range(5, 12)) - cb * 0.24 + db * 0.30 + drift
		y = int(clamp(ty, horizon - peak, horizon + peak * 0.45))
		pts.append(Vector2i(nx, y))
		x = nx
	return pts

func _generate_far_silhouette_heights(amplitude: float) -> Array[float]:
	var tile_size:  float       = 32.0
	var total_cols: int         = world_width * max(1, far_mtn_width_multiplier)
	var base_y:     float       = float(surface_mid_y) * tile_size
	var heights:    Array[float]= []
	heights.resize(total_cols)
	for x in range(total_cols):
		var tx: float = float(x)
		var p1: float = (_far_primary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var p2: float = (_far_secondary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var prim: float  = 1.0 - abs(2.0 * p1 - 1.0)
		var sec:  float  = (1.0 - abs(2.0 * p2 - 1.0)) * 0.5
		var det:  float  = _far_detail_noise.get_noise_2d(tx, 0.0) * 0.2
		var vm:   float  = (_far_valley_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var n:    float  = clamp(prim + sec + det - (1.0 - vm) * far_valley_bias, 0.0, 1.0)
		heights[x] = base_y - pow(n, max(0.25, far_shape_power)) * amplitude * tile_size
	return heights


# ---------------------------------------------------------------------------
# FAR BACKGROUND CHUNK DATA BUILDER  (runs on worker thread)
# Generates far_total_width columns = world_width * far_mtn_width_multiplier.
# Centered so the playable world sits in the middle of the extended range.
# ---------------------------------------------------------------------------
func _generate_far_chunk_data() -> void:
	_far_total_width = world_width * max(1, far_mtn_width_multiplier)
	var nc: int = int(ceil(float(_far_total_width) / float(FAR_CHUNK_WIDTH)))
	_far_chunk_data.resize(nc)
	for i in nc:
		_far_chunk_data[i] = { "front": {}, "back": {} }

	var world_top:    int        = surface_mid_y - terrain_amplitude - 80
	var world_bottom: int        = surface_mid_y + int(float(terrain_amplitude) * 0.15)
	# Generate surface heights across the full extended width
	var front: Array[int] = _generate_far_surface_heights_wide(_far_total_width)
	var back:  Array[int] = _generate_far_back_surface(front)

	for x in _far_total_width:
		var cx:  int = x / FAR_CHUNK_WIDTH
		var lx:  int = x % FAR_CHUNK_WIDTH
		var fd:  Dictionary = _far_chunk_data[cx]["front"]
		var bd:  Dictionary = _far_chunk_data[cx]["back"]
		# Back band
		var by:     int = back[x]
		var from_b: int = max(world_top, by)
		var to_b:   int = min(world_bottom, by + max(4, far_bg_back_band_depth))
		for y in range(from_b, to_b):
			var d: int = y - by
			if d < 0: continue
			var atlas: Vector2i = _pick_stone_variant(x, y, d + 12)
			if atlas != Vector2i(-1,-1):
				bd[(y + ENCODE_Y_OFFSET) * 100000 + lx] = atlas
		# Front band
		var fy:     int  = front[x]
		# Use world-center x for biome so far bg biome matches the playable world
		var world_x:int  = x - (_far_total_width - world_width) / 2
		var biome:  int  = _get_biome_id(clamp(world_x, 0, world_width - 1))
		var desert: bool = biome == BIOME_DESERT
		var from_f: int  = max(world_top, fy)
		var to_f:   int  = min(world_bottom, fy + max(5, far_bg_front_band_depth))
		for y in range(from_f, to_f):
			var d: int = y - fy
			if d < 0: continue
			var atlas: Vector2i = _pick_far_bg_block(x, y, d, desert)
			if atlas != Vector2i(-1,-1):
				fd[(y + ENCODE_Y_OFFSET) * 100000 + lx] = atlas

func _generate_far_surface_heights_wide(total_cols: int) -> Array[int]:
	var out:     Array[int]      = []
	out.resize(total_cols)
	var horizon: float           = float(surface_mid_y) - float(terrain_amplitude) * 0.35 + float(far_bg_y_offset)
	var peak:    float           = float(terrain_amplitude) * far_bg_mountain_scale
	var pts:     Array[Vector2i] = _generate_far_profile_points_wide(horizon, peak, total_cols)
	if pts.size() < 2:
		for x in total_cols: out[x] = int(horizon)
		return out
	var seg: int = 0
	for x in total_cols:
		while seg < pts.size() - 2 and x > pts[seg + 1].x:
			seg += 1
		var a: Vector2i = pts[seg]
		var b: Vector2i = pts[min(seg + 1, pts.size() - 1)]
		var t: float    = 0.0 if b.x == a.x else clamp(float(x - a.x) / float(b.x - a.x), 0.0, 1.0)
		out[x] = int(lerp(float(a.y), float(b.y), t))
	out = _smooth_surface_heights(out, far_bg_smooth_radius)
	out = _apply_far_cliff_regions(out, horizon, peak)
	out = _apply_far_cliff_features(out)
	var step: float = float(max(1, far_bg_cliff_step_tiles))
	for x in out.size():
		out[x] = int(floor(float(out[x]) / step) * step)
	return out

func _generate_far_profile_points_wide(horizon: float, peak: float, total_cols: int) -> Array[Vector2i]:
	var pts:     Array[Vector2i] = [Vector2i(0, int(horizon))]
	var x:       int   = 0
	var y:       int   = int(horizon)
	var heading: float = -1.0
	while x < total_cols:
		var sw:  int   = _rng.randi_range(42, 96)
		var nx:  int   = min(total_cols - 1, x + sw)
		if nx <= x: break
		var tx:   float = float(nx)
		var mp:   float = (_far_primary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var mv:   float = (_far_valley_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var drift:float = _far_secondary_noise.get_noise_2d(tx, 0.0) * peak * 0.14
		var cb:   float = (0.32 + mp * 0.50) * peak
		var db:   float = (1.0 - mv) * peak * (far_valley_bias + 0.16)
		if _rng.randf() < 0.12: heading *= -1.0
		var ty:   float = float(y) + heading * float(_rng.randi_range(5, 12)) - cb * 0.24 + db * 0.30 + drift
		y = int(clamp(ty, horizon - peak, horizon + peak * 0.45))
		pts.append(Vector2i(nx, y))
		x = nx
	return pts

# ---------------------------------------------------------------------------
# FAR BACKGROUND CHUNK STREAMING  (main thread)
# Far tiles are placed in far-tile coordinates. Because the TileMapLayer has
# scale = FAR_SCALE, each tile is rendered at FAR_SCALE * 32 px in world space.
# The layers are offset so the playable section sits in the center of the wider
# extended background.
# ---------------------------------------------------------------------------
func _update_far_loaded_chunks(player_far_chunk: int) -> void:
	if _far_chunk_data.is_empty():
		return
	var nc: int = _far_chunk_data.size()
	for cx in range(max(0, player_far_chunk - FAR_LOAD_RADIUS),
	                min(nc,  player_far_chunk + FAR_LOAD_RADIUS + 1)):
		if not _far_loaded_chunks.has(cx):
			_load_far_chunk(cx)
	var to_unload: Array = []
	for cx in _far_loaded_chunks.keys():
		if abs(cx - player_far_chunk) > FAR_UNLOAD_RADIUS:
			to_unload.append(cx)
	for cx in to_unload:
		_unload_far_chunk(cx)

func _load_far_chunk(chunk_x: int) -> void:
	if chunk_x < 0 or chunk_x >= _far_chunk_data.size():
		return
	var data:    Dictionary = _far_chunk_data[chunk_x]
	var x_start: int = chunk_x * FAR_CHUNK_WIDTH
	_write_far_layer_cells(_far_background_front, data["front"], x_start)
	_write_far_layer_cells(_far_background_back,  data["back"],  x_start)
	_far_loaded_chunks[chunk_x] = true
	# Debug: confirm tiles are actually in the tilemap after writing
	if _far_background_front != null:
		var used: Array = _far_background_front.get_used_cells()
		if used.size() > 0:
			var c: Vector2i = used[0]
			var wp: Vector2 = _far_background_front.map_to_local(c)

func _unload_far_chunk(chunk_x: int) -> void:
	var x_start:  int = chunk_x * FAR_CHUNK_WIDTH
	var world_top:int = surface_mid_y - terrain_amplitude - 80
	var world_bot:int = surface_mid_y + int(float(terrain_amplitude) * 0.15) + 2
	for x in range(x_start, x_start + FAR_CHUNK_WIDTH):
		for y in range(world_top, world_bot):
			var cell: Vector2i = Vector2i(x, y)
			if _far_background_front != null: _far_background_front.erase_cell(cell)
			if _far_background_back  != null: _far_background_back.erase_cell(cell)
	_far_loaded_chunks.erase(chunk_x)

func _write_far_layer_cells(layer: TileMapLayer, cells: Dictionary, x_start: int) -> void:
	if layer == null:
		return
	for encoded: int in cells.keys():
		var local_x: int     = encoded % 100000
		var y:       int     = encoded / 100000 - ENCODE_Y_OFFSET
		var atlas:   Vector2i = cells[encoded]
		layer.set_cell(Vector2i(x_start + local_x, y), tilemap_source_id, atlas)

func _world_x_to_far_chunk(world_x_pixels: float) -> int:
	if _far_total_width <= 0 or _far_chunk_data.is_empty():
		return 0
	# Convert world pixel x to far-tile x (accounting for offset and scale)
	var offset:    int   = (_far_total_width - world_width) / 2
	var far_tile_x:int   = int(world_x_pixels / (32.0 * FAR_SCALE)) + offset
	var nc:        int   = _far_chunk_data.size()
	return clamp(far_tile_x / FAR_CHUNK_WIDTH, 0, nc - 1)

# ---------------------------------------------------------------------------
# SPAWN PLATFORM  (written directly on main thread after thread finishes)
# ---------------------------------------------------------------------------
func _carve_spawn_platform() -> void:
	if _surface_heights.is_empty():
		return
	# Default spawn is the center of the world so the player is never on a chunk edge.
	var spawn_x: int = (world_width / 2) if spawn_tile_x < 0 else clamp(spawn_tile_x, 0, world_width - 1)
	var target_y: int = _surface_heights[spawn_x]
	var half_w:   int = 3
	for x in range(max(0, spawn_x - half_w), min(world_width, spawn_x + half_w + 1)):
		var col_y: int = _surface_heights[x]
		if col_y == target_y:
			continue
		if col_y < target_y:
			for y in range(col_y, target_y):
				_main.erase_cell(Vector2i(x, y))
				if _back_wall != null: _back_wall.erase_cell(Vector2i(x, y))
			_main.set_cell(Vector2i(x, target_y), tilemap_source_id, _c_grass)
		else:
			for y in range(target_y + 1, col_y):
				_main.set_cell(Vector2i(x, y), tilemap_source_id, _c_dirt)
			_main.set_cell(Vector2i(x, target_y), tilemap_source_id, _c_grass)
	# Store the exact world-pixel spawn position so main.gd can place the player.
	# Player should stand ON the surface tile, so y is one tile above target_y.
	# target_y is the tile row of the surface block.
	# Top edge of that tile in pixels = target_y * 32.
	# Place the player origin just above that so physics lands them cleanly.
	# Using target_y * 32 - 1 gives a 1px gap above the surface — enough for
	# CharacterBody2D to detect the floor on the first physics frame.
	# Scan downward from world top to find the actual highest solid tile at spawn_x.
	# This is more reliable than surface_heights which can change after lake/platform edits.
	var world_top_scan: int  = surface_mid_y - terrain_amplitude - 20
	var highest_solid_y: int = target_y
	for scan_y in range(world_top_scan, _world_bottom()):
		if _main.get_cell_source_id(Vector2i(spawn_x, scan_y)) != -1:
			highest_solid_y = scan_y
			break
	# Place 2 tiles (64px) above the highest solid block so the player
	# never spawns inside terrain regardless of collision shape origin.
	spawn_world_position = Vector2(
		float(spawn_x) * 32.0 + 16.0,
		float(highest_solid_y) * 32.0 - 64.0
	)
	print("WorldGen: spawn position = tile(%d,%d) world(%.0f,%.0f)" % [spawn_x, target_y, spawn_world_position.x, spawn_world_position.y])

# ---------------------------------------------------------------------------
# TREE HELPERS
# ---------------------------------------------------------------------------
func _pick_weighted_tree(valid: Array) -> Dictionary:
	var total: int = 0
	for tt: Dictionary in valid: total += max(1, int(tt.get("weight", 1)))
	if total <= 0: return valid[_rng.randi() % valid.size()]
	var roll: int = _rng.randi_range(1, total)
	var acc:  int = 0
	for tt: Dictionary in valid:
		acc += max(1, int(tt.get("weight", 1)))
		if roll <= acc: return tt
	return valid[0]

func _get_crown_rows(log_name: String, biome_id: int) -> Array[Dictionary]:
	if log_name == "Spruce Log":
		return [{"dy":0,"half_w":0},{"dy":1,"half_w":1},{"dy":2,"half_w":2},{"dy":3,"half_w":1}]
	if log_name == "Dark Oak Log":
		return [{"dy":0,"half_w":2},{"dy":1,"half_w":3},{"dy":2,"half_w":2}]
	if biome_id == BIOME_BIRCH_FOREST:
		return [{"dy":0,"half_w":1},{"dy":1,"half_w":1},{"dy":2,"half_w":2}]
	return [{"dy":0,"half_w":1},{"dy":1,"half_w":2},{"dy":2,"half_w":2},{"dy":3,"half_w":1}]

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
## Force chunk re-evaluation — call after a player teleport.
func force_load_around(world_x_pixels: float) -> void:
	if not _gen_complete:
		return
	_last_player_chunk = -99999
	_update_loaded_chunks(_world_x_to_chunk(world_x_pixels))

func get_far_background_data() -> Dictionary:
	return { "seed": seed_value, "world_width": world_width, "mtn_far": _last_mtn_far, "mtn_near": _last_mtn_near }

# ---------------------------------------------------------------------------
# SIGNAL
# ---------------------------------------------------------------------------
func _emit_generation_complete() -> void:
	if _last_mtn_far.is_empty() or _last_mtn_near.is_empty():
		return
	generation_complete.emit(seed_value, world_width, _last_mtn_far, _last_mtn_near)

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _chunk_count() -> int:
	return int(ceil(float(world_width) / float(CHUNK_WIDTH)))

func _world_x_to_chunk(world_x_pixels: float) -> int:
	var tile_x: int = int(world_x_pixels / 32.0)
	return clamp(tile_x / CHUNK_WIDTH, 0, _chunk_count() - 1)

func _world_bottom() -> int:
	return surface_mid_y + terrain_amplitude + 80

func _in_depth_band(depth: int, min_d: int, max_d: int) -> bool:
	return depth >= min_d and depth <= max_d

# ---------------------------------------------------------------------------
# NOISE SETUP
# ---------------------------------------------------------------------------
func _setup_noise() -> void:
	_rng.seed = seed_value

	_continental_noise.seed               = seed_value + 30
	_continental_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_continental_noise.frequency          = 0.0015
	_continental_noise.fractal_octaves    = 2
	_continental_noise.fractal_gain       = 0.52
	_continental_noise.fractal_lacunarity = 2.0

	_terrain_variation_noise.seed               = seed_value + 31
	_terrain_variation_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_terrain_variation_noise.frequency          = 0.0048
	_terrain_variation_noise.fractal_octaves    = 3
	_terrain_variation_noise.fractal_gain       = 0.5
	_terrain_variation_noise.fractal_lacunarity = 2.0

	_landform_noise.seed            = seed_value + 32
	_landform_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_landform_noise.frequency       = 0.0022
	_landform_noise.fractal_octaves = 2

	_cliff_control_noise.seed            = seed_value + 33
	_cliff_control_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_cliff_control_noise.frequency       = 0.008
	_cliff_control_noise.fractal_octaves = 2

	_plateau_control_noise.seed            = seed_value + 34
	_plateau_control_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_plateau_control_noise.frequency       = 0.006
	_plateau_control_noise.fractal_octaves = 2

	_valley_control_noise.seed            = seed_value + 35
	_valley_control_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_valley_control_noise.frequency       = 0.0035
	_valley_control_noise.fractal_octaves = 2

	_detail_noise.seed            = seed_value + 5
	_detail_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency       = 0.03
	_detail_noise.fractal_octaves = 2

	_cave_noise.seed            = seed_value + 1
	_cave_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_cave_noise.frequency       = 0.04
	_cave_noise.fractal_octaves = 2

	_ore_noise.seed            = seed_value + 2
	_ore_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_ore_noise.frequency       = 0.09
	_ore_noise.fractal_octaves = 1

	_bg_ore_noise.seed            = seed_value + 20
	_bg_ore_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_bg_ore_noise.frequency       = 0.12
	_bg_ore_noise.fractal_octaves = 1

	_biome_noise.seed            = seed_value + 3
	_biome_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_biome_noise.frequency       = 0.008
	_biome_noise.fractal_octaves = 1

	_tree_noise.seed            = seed_value + 4
	_tree_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_tree_noise.frequency       = 0.15
	_tree_noise.fractal_octaves = 1

	_bg_macro_noise.seed               = seed_value + 40
	_bg_macro_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_bg_macro_noise.frequency          = 0.0018
	_bg_macro_noise.fractal_octaves    = 2

	_bg_mid_noise.seed            = seed_value + 41
	_bg_mid_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_bg_mid_noise.frequency       = 0.004
	_bg_mid_noise.fractal_octaves = 2

	_bg_detail_noise.seed            = seed_value + 42
	_bg_detail_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_bg_detail_noise.frequency       = 0.012
	_bg_detail_noise.fractal_octaves = 1

	_far_primary_noise.seed               = seed_value + 50
	_far_primary_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_far_primary_noise.frequency          = 0.0038
	_far_primary_noise.fractal_octaves    = 3
	_far_primary_noise.fractal_gain       = 0.5

	_far_secondary_noise.seed               = seed_value + 51
	_far_secondary_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_far_secondary_noise.frequency          = 0.0085
	_far_secondary_noise.fractal_octaves    = 2
	_far_secondary_noise.fractal_gain       = 0.46

	_far_detail_noise.seed            = seed_value + 52
	_far_detail_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_far_detail_noise.frequency       = 0.018
	_far_detail_noise.fractal_octaves = 1

	_far_valley_noise.seed               = seed_value + 53
	_far_valley_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_far_valley_noise.frequency          = 0.0032
	_far_valley_noise.fractal_octaves    = 2

# ---------------------------------------------------------------------------
# ATLAS COORD CACHE  (called on main thread before thread starts)
# ---------------------------------------------------------------------------
func _cache_atlas_coords() -> void:
	_c_grass    = BlockRegistry.get_coords_from_name("Grass")
	_c_dirt     = BlockRegistry.get_coords_from_name("Dirt")
	_c_sand     = BlockRegistry.get_coords_from_name("Sand")
	_c_water    = BlockRegistry.get_coords_from_name("Water")
	_c_bedrock  = BlockRegistry.get_coords_from_name("Bedrock")
	_c_stone    = BlockRegistry.get_coords_from_name("Stone")
	_c_gravel   = BlockRegistry.get_coords_from_name("Gravel")
	_c_diorite  = BlockRegistry.get_coords_from_name("Diorite")
	_c_granite  = BlockRegistry.get_coords_from_name("Granite")
	_c_andesite = BlockRegistry.get_coords_from_name("Andesite")
	_c_coal     = BlockRegistry.get_coords_from_name("Coal Ore")
	_c_iron     = BlockRegistry.get_coords_from_name("Iron Ore")
	_c_copper   = BlockRegistry.get_coords_from_name("Copper Ore")
	_c_gold     = BlockRegistry.get_coords_from_name("Gold Ore")
	_c_diamond  = BlockRegistry.get_coords_from_name("Diamond Ore")
	_c_titanium = BlockRegistry.get_coords_from_name("Titanium Ore")

	_tree_type_coords.clear()
	for tree_def: Dictionary in TREE_TYPES:
		var lc: Vector2i = BlockRegistry.get_coords_from_name(tree_def["log"])
		var lv: Vector2i = BlockRegistry.get_coords_from_name(tree_def["leaves"])
		if lc == Vector2i(-1,-1):
			push_warning("WorldGen: log '%s' not in registry — skipping." % tree_def["log"])
			continue
		if lv == Vector2i(-1,-1):
			push_warning("WorldGen: leaves '%s' not in registry — skipping." % tree_def["leaves"])
			continue
		_tree_type_coords.append({
			"log": lc, "leaves": lv,
			"surface":    tree_def["surface"],
			"crown":      tree_def.get("crown", true),
			"biomes":     tree_def.get("biomes", [BIOME_FOREST, BIOME_PLAINS, BIOME_BIRCH_FOREST]),
			"weight":     int(tree_def.get("weight", 1)),
			"height_min": int(tree_def.get("height_min", tree_min_height)),
			"height_max": int(tree_def.get("height_max", tree_max_height)),
			"log_name":   tree_def["log"],
		})
	print("WorldGen: %d tree type(s) loaded." % _tree_type_coords.size())