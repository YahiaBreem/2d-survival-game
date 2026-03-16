# ===========================================================================
# WORLD GENERATOR — Chunk-aware rewrite
#
# Attach to any Node in the main scene (does NOT auto-generate on _ready
# anymore — ChunkManager drives generation per-chunk on a worker thread).
#
# LAYER SYSTEM (back → front):
#   layer_background          (z -60) — decorative scenery, non-interactive
#   layer_back_wall           (z -40) — cave/dungeon walls, placeable/breakable
#   layer_object              (z -20) — tree trunks, workstations, furniture
#   layer_main                (z   0) — solid terrain, collision, primary gameplay
#
# KEY CHANGES FROM OLD VERSION:
#   • generate() is gone — ChunkManager calls generate_chunk_data(left_x, width)
#   • generate_chunk_data() is THREAD-SAFE: it only reads noise and returns
#     plain Dictionaries — it never touches TileMapLayer nodes.
#   • Biome, surface height, and landform are cached per x-column inside each
#     chunk call so they are not re-sampled multiple times.
#   • generation_complete signal is emitted once on _ready (for far background
#     data that main.gd uses for parallax scenery).
#
# ADDING A NEW TREE TYPE:
#   1. Add the log and leaves blocks to BlockRegistry (with PNGs).
#   2. Add an entry to TREE_TYPES below — that is it.
# ===========================================================================
extends Node

## Emitted once after noise is initialised.
## Passes mountain height arrays (world-space y pixels) for the far background.
signal generation_complete(seed_val: int, mtn_far: Array, mtn_near: Array)

# ---------------------------------------------------------------------------
const BIOME_BIRCH_FOREST: int = 0
const BIOME_FOREST:       int = 1
const BIOME_PLAINS:       int = 2
const BIOME_DESERT:       int = 3

enum LandformType {
	PLAINS,
	ROLLING_HILLS,
	CLIFFS,
	PLATEAUS,
	VALLEYS,
}

const TREE_TYPES: Array = [
	{
		"log": "Oak Log", "leaves": "Oak Leaves", "surface": "Grass",
		"crown": true, "biomes": [BIOME_FOREST, BIOME_PLAINS],
		"weight": 5, "height_min": 4, "height_max": 7,
	},
	{
		"log": "Birch Log", "leaves": "Birch Leaves", "surface": "Grass",
		"crown": true, "biomes": [BIOME_BIRCH_FOREST, BIOME_PLAINS],
		"weight": 5, "height_min": 5, "height_max": 8,
	},
	{
		"log": "Acacia Log", "leaves": "Acacia Leaves", "surface": "Grass",
		"crown": true, "biomes": [BIOME_PLAINS],
		"weight": 2, "height_min": 5, "height_max": 7,
	},
	{
		"log": "Spruce Log", "leaves": "Spruce Leaves", "surface": "Grass",
		"crown": true, "biomes": [BIOME_FOREST],
		"weight": 3, "height_min": 6, "height_max": 9,
	},
	{
		"log": "Jungle Log", "leaves": "Jungle Leaves", "surface": "Grass",
		"crown": true, "biomes": [BIOME_FOREST],
		"weight": 2, "height_min": 7, "height_max": 10,
	},
	{
		"log": "Dark Oak Log", "leaves": "Dark Oak Leaves", "surface": "Grass",
		"crown": true, "biomes": [BIOME_FOREST],
		"weight": 2, "height_min": 5, "height_max": 7,
	},
	{
		"log": "Cactus", "leaves": "Cactus", "surface": "Sand",
		"crown": false, "biomes": [BIOME_DESERT],
		"weight": 8, "height_min": 3, "height_max": 6,
	},
]

# ---------------------------------------------------------------------------
# EXPORTS
# ---------------------------------------------------------------------------

@export var tilemap_source_id: int = 0

@export_group("Seed")
@export var seed_value: int = 0

@export_group("World Shape")
@export var surface_mid_y: int     = 30
@export var terrain_amplitude: int = 20

@export_group("Main Terrain Shaping")
@export var macro_height_scale: float         = 1.75
@export var plains_scale: float               = 0.26
@export var hills_scale: float                = 0.85
@export var cliffs_scale: float               = 1.35
@export var plateau_scale: float              = 0.70
@export var valley_scale: float               = 1.00
@export var terrain_variation_strength: float = 0.62
@export var terrain_detail_strength: float    = 0.10

@export_group("Landform Thresholds")
@export var landform_plain_threshold: float   = 0.12
@export var landform_hills_threshold: float   = 0.38
@export var landform_cliffs_threshold: float  = 0.62
@export var landform_plateau_threshold: float = 0.82

@export_group("Cliff / Plateau / Valley Controls")
@export var cliff_sharpness: float          = 2.8
@export var cliff_ledge_step_tiles: int     = 2
@export var plateau_flatten_strength: float = 0.70
@export var plateau_step_tiles: int         = 2
@export var valley_depth_strength: float    = 1.20
@export var valley_width_strength: float    = 0.75

@export_group("Surface Smoothing")
@export var main_surface_smooth_radius: int = 1

@export_group("Underground Layers")
@export var dirt_depth: int        = 4
@export var stone_start_depth: int = 5

@export_group("Caves")
@export var cave_threshold: float = 0.62

@export_group("Ores")
@export var coal_threshold: float     = 0.69
@export var copper_threshold: float   = 0.75
@export var iron_threshold: float     = 0.80
@export var gold_threshold: float     = 0.83
@export var diamond_threshold: float  = 0.90
@export var titanium_threshold: float = 0.93

@export var copper_min_depth: int       = 5
@export var copper_max_depth: int       = 24
@export var iron_min_depth: int         = 18
@export var iron_max_depth: int         = 60
@export var gold_shallow_min_depth: int = 8
@export var gold_shallow_max_depth: int = 18
@export var gold_deep_min_depth: int    = 28
@export var gold_deep_max_depth: int    = 60
@export var diamond_min_depth: int      = 42
@export var diamond_max_depth: int      = 80
@export var titanium_min_depth: int     = 50
@export var titanium_max_depth: int     = 100

@export_group("Background Shaping")
@export var bg_mountain_scale: float        = 1.05
@export var bg_mountain_y_offset: int       = -6
@export var bg_match_main_strength: float   = 0.78
@export var bg_match_main_offset: int       = 8
@export var bg_match_noise_strength: float  = 3.0
@export var bg_large_shape_scale: float     = 0.95
@export var bg_mid_shape_scale: float       = 0.45
@export var bg_detail_shape_scale: float    = 0.12
@export var bg_shape_power: float           = 1.35
@export var bg_cliff_strength: float        = 0.35
@export var bg_cliff_step_tiles: int        = 1
@export var bg_surface_smooth_radius: int   = 4

@export_group("Far Background Shaping")
@export var far_mtn_width_multiplier: int   = 4
@export var far_mtn_amplitude: float        = 120.0
@export var near_mtn_amplitude: float       = 70.0
@export var far_bg_mountain_scale: float    = 1.8
@export var far_bg_y_offset: int            = -4
@export var far_shape_power: float          = 1.25
@export var far_valley_bias: float          = 0.12
@export var far_bg_cliff_step_tiles: int    = 2
@export var far_bg_smooth_radius: int       = 12

@export_group("Water")
@export var sea_level: int            = 36
@export var lake_attempt_ratio: float = 0.025
@export var lake_min_radius: int      = 3
@export var lake_max_radius: int      = 6
@export var lake_min_depth: int       = 2
@export var lake_max_depth: int       = 4

@export_group("Bedrock")
@export var bedrock_base_layers: int  = 3
@export var bedrock_extra_layers: int = 2

@export_group("Trees")
@export var tree_chance: float   = 0.4
@export var tree_min_height: int = 4
@export var tree_max_height: int = 7

# ---------------------------------------------------------------------------
# NOISE INSTANCES  (read-only after _setup_noise — safe to read from threads)
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

# ---------------------------------------------------------------------------
# CACHED ATLAS COORDS  (set once in _cache_atlas_coords, then read-only)
# ---------------------------------------------------------------------------
var _c_grass:    Vector2i = Vector2i(-1, -1)
var _c_dirt:     Vector2i = Vector2i(-1, -1)
var _c_sand:     Vector2i = Vector2i(-1, -1)
var _c_water:    Vector2i = Vector2i(-1, -1)
var _c_bedrock:  Vector2i = Vector2i(-1, -1)
var _c_stone:    Vector2i = Vector2i(-1, -1)
var _c_gravel:   Vector2i = Vector2i(-1, -1)
var _c_diorite:  Vector2i = Vector2i(-1, -1)
var _c_granite:  Vector2i = Vector2i(-1, -1)
var _c_andesite: Vector2i = Vector2i(-1, -1)
var _c_coal:     Vector2i = Vector2i(-1, -1)
var _c_iron:     Vector2i = Vector2i(-1, -1)
var _c_copper:   Vector2i = Vector2i(-1, -1)
var _c_gold:     Vector2i = Vector2i(-1, -1)
var _c_diamond:  Vector2i = Vector2i(-1, -1)
var _c_titanium: Vector2i = Vector2i(-1, -1)

var _tree_type_coords: Array   = []
var _last_mtn_far:  Array[float] = []
var _last_mtn_near: Array[float] = []
var _ready_for_generation: bool  = false

# RNG is NOT shared between threads — each chunk gets its own seeded instance.
# This mutex just protects the one-time initialisation RNG used for seeding.
var _seed_mutex: Mutex = Mutex.new()

# ===========================================================================
# _ready — main thread initialisation
# ===========================================================================
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if not TileSetBuilder.tileset_ready:
		push_error("WorldGen: TileSetBuilder did not finish. Aborting.")
		return

	if seed_value == 0:
		seed_value = randi()
	print("WorldGen: seed = %d" % seed_value)

	_setup_noise()
	_cache_atlas_coords()
	_build_tree_type_coords()
	_generate_far_background_data()
	_ready_for_generation = true
	print("WorldGen: ready. ChunkManager will drive generation.")

# ===========================================================================
# NOISE SETUP  (main thread only, called once)
# ===========================================================================
func _setup_noise() -> void:
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

	_bg_macro_noise.seed            = seed_value + 40
	_bg_macro_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_bg_macro_noise.frequency       = 0.0018
	_bg_macro_noise.fractal_octaves = 2

	_bg_mid_noise.seed            = seed_value + 41
	_bg_mid_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_bg_mid_noise.frequency       = 0.004
	_bg_mid_noise.fractal_octaves = 2

	_bg_detail_noise.seed            = seed_value + 42
	_bg_detail_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_bg_detail_noise.frequency       = 0.009
	_bg_detail_noise.fractal_octaves = 2

	_far_primary_noise.seed               = seed_value + 50
	_far_primary_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_far_primary_noise.frequency          = 0.003
	_far_primary_noise.fractal_octaves    = 3
	_far_primary_noise.fractal_gain       = 0.50

	_far_secondary_noise.seed            = seed_value + 51
	_far_secondary_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_far_secondary_noise.frequency       = 0.0085
	_far_secondary_noise.fractal_octaves = 2
	_far_secondary_noise.fractal_gain    = 0.46

	_far_detail_noise.seed            = seed_value + 52
	_far_detail_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_far_detail_noise.frequency       = 0.018
	_far_detail_noise.fractal_octaves = 1

	_far_valley_noise.seed            = seed_value + 53
	_far_valley_noise.noise_type      = FastNoiseLite.TYPE_PERLIN
	_far_valley_noise.frequency       = 0.0032
	_far_valley_noise.fractal_octaves = 2

# ===========================================================================
# ATLAS COORD CACHE
# ===========================================================================
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

func _build_tree_type_coords() -> void:
	_tree_type_coords.clear()
	for tree_def: Dictionary in TREE_TYPES:
		var lc: Vector2i = BlockRegistry.get_coords_from_name(tree_def["log"])
		var lv: Vector2i = BlockRegistry.get_coords_from_name(tree_def["leaves"])
		if lc == Vector2i(-1, -1):
			push_warning("WorldGen: log '%s' not in registry." % tree_def["log"])
			continue
		if lv == Vector2i(-1, -1):
			push_warning("WorldGen: leaves '%s' not in registry." % tree_def["leaves"])
			continue
		_tree_type_coords.append({
			"log":        lc,
			"leaves":     lv,
			"surface":    tree_def["surface"],
			"crown":      tree_def.get("crown", true),
			"biomes":     tree_def.get("biomes", [BIOME_FOREST, BIOME_PLAINS, BIOME_BIRCH_FOREST]),
			"weight":     int(tree_def.get("weight", 1)),
			"height_min": int(tree_def.get("height_min", tree_min_height)),
			"height_max": int(tree_def.get("height_max", tree_max_height)),
			"log_name":   tree_def["log"],
		})
	print("WorldGen: %d tree type(s) loaded." % _tree_type_coords.size())

# ===========================================================================
# FAR BACKGROUND DATA  (generated once on _ready, main thread only)
# ===========================================================================
func _generate_far_background_data() -> void:
	_last_mtn_far  = _generate_far_silhouette_heights(far_mtn_amplitude)
	_last_mtn_near = _generate_far_silhouette_heights(near_mtn_amplitude * 0.9)
	generation_complete.emit(seed_value, _last_mtn_far, _last_mtn_near)
	call_deferred("_emit_deferred")

func _emit_deferred() -> void:
	generation_complete.emit(seed_value, _last_mtn_far, _last_mtn_near)

func get_far_background_data() -> Dictionary:
	return { "seed": seed_value, "mtn_far": _last_mtn_far, "mtn_near": _last_mtn_near }

# ===========================================================================
# CHUNK DATA GENERATION  — THREAD-SAFE
# Called by ChunkManager on the worker thread.
# Returns plain Dictionaries — never reads or writes TileMapLayer.
# ===========================================================================

## Main entry called by ChunkManager._generate_chunk_data().
## left_x: world tile x of the leftmost column.
## width:  number of columns (ChunkManager.CHUNK_WIDTH).
func generate_chunk_data(left_x: int, width: int) -> Dictionary:
	if not _ready_for_generation:
		push_warning("WorldGen: generate_chunk_data called before ready.")
		return {}

	var main_cells: Dictionary = {}
	var obj_cells:  Dictionary = {}
	var wall_cells: Dictionary = {}
	var bg_cells:   Dictionary = {}

	var world_bottom: int = surface_mid_y + terrain_amplitude + 80
	var world_top:    int = surface_mid_y - terrain_amplitude - 40

	# Pad the surface array so trees and spacing checks have neighbour data.
	var pad:   int = 4
	var total: int = width + pad * 2

	# --- Per-column caches (sampled once each) ---
	var biome_ids:    Array[int] = []
	var landform_ids: Array[int] = []
	var raw_heights:  Array[int] = []
	biome_ids.resize(total)
	landform_ids.resize(total)
	raw_heights.resize(total)

	for i in total:
		var tx: int = left_x - pad + i
		biome_ids[i]    = _get_biome_id(tx)
		landform_ids[i] = _get_landform_type(tx)
		raw_heights[i]  = _get_surface_height_cached(tx, biome_ids[i], landform_ids[i])

	var surface_heights: Array[int] = _smooth_int_array(raw_heights, main_surface_smooth_radius)

	# The chunk-only slice returned to ChunkManager
	var chunk_surface: Array[int] = []
	chunk_surface.resize(width)
	for i in width:
		chunk_surface[i] = surface_heights[pad + i]

	# Pass 1: foreground terrain
	for i in width:
		var tx:        int  = left_x + i
		var si:        int  = pad + i
		var surf_y:    int  = surface_heights[si]
		var biome_id:  int  = biome_ids[si]
		var is_desert: bool = biome_id == BIOME_DESERT
		_fill_column_data(tx, surf_y, biome_id, is_desert, world_bottom, main_cells, wall_cells)

	# Pass 2: background
	_fill_background_data(left_x, width, pad, surface_heights, biome_ids,
		world_top, world_bottom, bg_cells)

	# Pass 3: water
	_fill_water_data(left_x, width, pad, surface_heights, main_cells)

	# Pass 4: trees
	_fill_tree_data(left_x, width, pad, surface_heights, biome_ids,
		main_cells, obj_cells, wall_cells)

	# Pass 5: settle physical blocks
	_settle_physical_data(left_x, width, world_top, world_bottom, main_cells)

	return {
		"main":            main_cells,
		"object":          obj_cells,
		"back_wall":       wall_cells,
		"background":      bg_cells,
		"surface_heights": chunk_surface,
	}

# ===========================================================================
# FOREGROUND COLUMN
# ===========================================================================
func _fill_column_data(
		x: int, surface_y: int, biome_id: int, is_desert: bool,
		world_bottom: int,
		main_out: Dictionary, wall_out: Dictionary) -> void:

	for y in range(surface_y, world_bottom):
		var depth: int     = y - surface_y
		var cell: Vector2i = Vector2i(x, y)

		if _is_bedrock_cell(x, y, world_bottom):
			var bc: Vector2i = _c_bedrock if _c_bedrock != Vector2i(-1, -1) else _c_stone
			main_out[cell] = bc
			wall_out[cell] = bc
			continue

		var is_cave: bool = false
		if depth > 2:
			var fx: float = float(x)
			var fy: float = float(y)
			var cave_v: float  = (_cave_noise.get_noise_2d(fx, fy) + 1.0) * 0.5
			var cutoff: float  = cave_threshold - (0.05 if depth > 20 else 0.0)
			if cave_v > cutoff:
				is_cave = true
			elif depth > 5:
				var tun: float = (_cave_noise.get_noise_2d(fx * 1.7, fy * 0.75 + 140.0) + 1.0) * 0.5
				if tun > cutoff + 0.08:
					is_cave = true

		var atlas: Vector2i = _pick_fg_block(x, y, depth, biome_id, is_desert)
		if atlas == Vector2i(-1, -1):
			continue

		if is_cave:
			wall_out[cell] = atlas
		else:
			main_out[cell] = atlas
			wall_out[cell] = atlas

func _pick_fg_block(x: int, y: int, depth: int, biome_id: int, is_desert: bool) -> Vector2i:
	if depth == 0:
		return _c_sand if is_desert else _c_grass

	var sub_depth: int = dirt_depth + (3 if biome_id == BIOME_DESERT else (1 if biome_id == BIOME_PLAINS else 0))
	if depth <= sub_depth:
		return _c_sand if is_desert else _c_dirt

	if depth >= stone_start_depth:
		var fx:    float = float(x)
		var fy:    float = float(y)
		var ore_a: float = (_ore_noise.get_noise_2d(fx, fy) + 1.0) * 0.5
		var ore_b: float = (_ore_noise.get_noise_2d(fx * 0.73 + 97.0, fy * 1.21 - 41.0) + 1.0) * 0.5

		if _in_depth_band(depth, titanium_min_depth, titanium_max_depth) and _c_titanium != Vector2i(-1,-1) and ore_b > titanium_threshold:
			return _c_titanium
		if _in_depth_band(depth, diamond_min_depth, diamond_max_depth) and _c_diamond != Vector2i(-1,-1) and ore_b > diamond_threshold:
			return _c_diamond
		if _in_depth_band(depth, iron_min_depth, iron_max_depth) and _c_iron != Vector2i(-1,-1) and ore_a > iron_threshold:
			return _c_iron
		var gold_band: bool = _in_depth_band(depth, gold_shallow_min_depth, gold_shallow_max_depth) or \
							  _in_depth_band(depth, gold_deep_min_depth, gold_deep_max_depth)
		if gold_band and _c_gold != Vector2i(-1,-1) and ore_b > gold_threshold:
			return _c_gold
		if _in_depth_band(depth, copper_min_depth, copper_max_depth) and _c_copper != Vector2i(-1,-1) and ore_a > copper_threshold:
			return _c_copper
		if _c_coal != Vector2i(-1,-1) and ore_a > coal_threshold:
			return _c_coal
		return _pick_stone_variant(x, y, depth)

	return _c_dirt

# ===========================================================================
# BACKGROUND
# ===========================================================================
func _fill_background_data(
		left_x: int, width: int, pad: int,
		surface_heights: Array[int], biome_ids: Array[int],
		world_top: int, world_bottom: int,
		bg_out: Dictionary) -> void:

	var bg_surf: Array = []
	bg_surf.resize(width)
	var ms: float = clamp(bg_match_main_strength, 0.0, 1.0)
	for i in width:
		var tx: int = left_x + i
		var si: int = pad + i
		var shaped:    int   = _get_bg_surface_height(tx) + bg_mountain_y_offset
		var matched:   int   = surface_heights[si] + bg_match_main_offset
		var blend:     float = lerp(float(shaped), float(matched), ms)
		var noise_off: float = _bg_detail_noise.get_noise_2d(float(tx), 137.0) * bg_match_noise_strength
		bg_surf[i] = int(round(blend + noise_off))
	bg_surf = _smooth_plain_array(bg_surf, bg_surface_smooth_radius)

	for i in width:
		var tx:        int  = left_x + i
		var bg_sy:     int  = bg_surf[i]
		var biome_id:  int  = biome_ids[pad + i]
		var is_desert: bool = biome_id == BIOME_DESERT
		var fill_from: int  = max(world_top, bg_sy)
		for y in range(fill_from, world_bottom):
			var depth: int = y - bg_sy
			var atlas: Vector2i = _pick_bg_block(tx, y, depth, is_desert)
			if atlas != Vector2i(-1, -1):
				bg_out[Vector2i(tx, y)] = atlas

func _pick_bg_block(x: int, y: int, depth: int, is_desert: bool) -> Vector2i:
	if depth == 0:
		return _c_sand if is_desert else _c_grass
	if depth <= dirt_depth:
		return _c_sand if is_desert else _c_dirt
	if depth >= stone_start_depth:
		if bg_cliff_step_tiles > 1 and depth < stone_start_depth + 8:
			var ls: float = float(bg_cliff_step_tiles)
			var ld: int   = int(floor(float(depth) / ls) * ls)
			return _pick_stone_variant(x, y + ld, depth)
		return _pick_stone_variant(x, y, depth)
	return _c_dirt

# ===========================================================================
# WATER
# ===========================================================================
func _fill_water_data(
		left_x: int, width: int, pad: int,
		surface_heights: Array[int],
		main_out: Dictionary) -> void:

	if _c_water == Vector2i(-1, -1):
		return

	# Sea-level fill
	for i in width:
		var tx:     int = left_x + i
		var surf_y: int = surface_heights[pad + i]
		if surf_y <= sea_level:
			continue
		for y in range(sea_level, surf_y):
			var cell: Vector2i = Vector2i(tx, y)
			if not main_out.has(cell):
				main_out[cell] = _c_water

	# Lakes — deterministic per-chunk
	var local_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	local_rng.seed = hash(Vector2i(left_x, seed_value))

	var attempts: int = max(1, int(float(width) * max(0.0, lake_attempt_ratio)))
	for _i in attempts:
		var cx: int = left_x + local_rng.randi_range(0, width - 1)
		var si: int = pad + (cx - left_x)
		if si < 0 or si >= surface_heights.size():
			continue
		if _get_biome_id(cx) == BIOME_DESERT:
			continue
		var c_surf: int = surface_heights[si]
		if c_surf >= sea_level - 1:
			continue

		var radius: int = local_rng.randi_range(lake_min_radius, max(lake_min_radius, lake_max_radius))
		var depth:  int = local_rng.randi_range(lake_min_depth, max(lake_min_depth, lake_max_depth))
		var lake_top: int = c_surf + 1

		for dx in range(-radius, radius + 1):
			var lx: int = cx + dx
			if lx < left_x or lx >= left_x + width:
				continue
			var li: int = pad + (lx - left_x)
			if li < 0 or li >= surface_heights.size():
				continue
			var edge_factor: float = 1.0 - (abs(float(dx)) / float(radius + 1))
			var local_depth: int   = max(1, int(round(float(depth) * edge_factor)))
			var local_surf:  int   = surface_heights[li]
			for y in range(local_surf, local_surf + local_depth + 1):
				main_out.erase(Vector2i(lx, y))
			for y in range(lake_top, local_surf + local_depth + 1):
				var wc: Vector2i = Vector2i(lx, y)
				if not main_out.has(wc):
					main_out[wc] = _c_water

# ===========================================================================
# TREES
# ===========================================================================
func _fill_tree_data(
		left_x: int, width: int, pad: int,
		surface_heights: Array[int], biome_ids: Array[int],
		main_out: Dictionary, obj_out: Dictionary, wall_out: Dictionary) -> void:

	if _tree_type_coords.is_empty():
		return

	var local_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	local_rng.seed = hash(Vector2i(left_x + 99991, seed_value))

	for i in width:
		var tx:        int  = left_x + i
		var si:        int  = pad + i
		var surface_y: int  = surface_heights[si]
		var biome_id:  int  = biome_ids[si]

		var surf_atlas: Vector2i = main_out.get(Vector2i(tx, surface_y), Vector2i(-1, -1))
		var surf_name:  String   = BlockRegistry.get_name_from_coords(surf_atlas)

		var valid_types: Array = []
		for tt: Dictionary in _tree_type_coords:
			if tt["surface"] == surf_name and tt["biomes"].has(biome_id):
				valid_types.append(tt)
		if valid_types.is_empty():
			continue

		if _c_water != Vector2i(-1, -1):
			if main_out.get(Vector2i(tx, surface_y - 1), Vector2i(-1,-1)) == _c_water:
				continue

		var t: float = (_tree_noise.get_noise_2d(float(tx), 500.0) + 1.0) * 0.5
		var density: float = tree_chance
		if biome_id == BIOME_FOREST or biome_id == BIOME_BIRCH_FOREST:
			density += 0.16
		elif biome_id == BIOME_DESERT:
			density -= 0.06
		if t >= clamp(density, 0.05, 0.95):
			continue

		# Spacing check within padded range
		var too_close: bool = false
		for nx in range(tx - 2, tx + 3):
			if nx == tx:
				continue
			var ni: int = si + (nx - tx)
			if ni < 0 or ni >= surface_heights.size():
				continue
			var trunk_check: Vector2i = obj_out.get(Vector2i(nx, surface_heights[ni] - 1), Vector2i(-1,-1))
			for tt: Dictionary in _tree_type_coords:
				if trunk_check == tt["log"]:
					too_close = true
					break
			if too_close:
				break
		if too_close:
			continue

		var chosen: Dictionary = _pick_weighted_tree(valid_types, local_rng)
		var c_log:    Vector2i = chosen["log"]
		var c_leaves: Vector2i = chosen["leaves"]
		var h_min: int = chosen["height_min"]
		var h_max: int = max(h_min, chosen["height_max"])
		var height: int = h_min + (local_rng.randi() % (h_max - h_min + 1))
		var crown_top_y: int = surface_y - height - 1

		if chosen["crown"]:
			for k in height:
				obj_out[Vector2i(tx, surface_y - 1 - k)] = c_log
			for row: Dictionary in _get_crown_rows(chosen["log_name"], biome_id):
				var cy: int = crown_top_y + row["dy"]
				for cx in range(tx - row["half_w"], tx + row["half_w"] + 1):
					var lc: Vector2i = Vector2i(cx, cy)
					if not main_out.has(lc): main_out[lc] = c_leaves
					if not wall_out.has(lc): wall_out[lc] = c_leaves
		else:
			for k in height:
				var lc: Vector2i = Vector2i(tx, surface_y - 1 - k)
				if not main_out.has(lc):
					main_out[lc] = c_log

# ===========================================================================
# PHYSICAL BLOCK SETTLING
# ===========================================================================
func _settle_physical_data(
		left_x: int, width: int,
		world_top: int, world_bottom: int,
		main_out: Dictionary) -> void:

	for i in width:
		var tx: int = left_x + i
		for y in range(world_top, world_bottom):
			var cell: Vector2i = Vector2i(tx, y)
			if not main_out.has(cell):
				continue
			var atlas: Vector2i = main_out[cell]
			if not BlockRegistry.is_physical(BlockRegistry.get_name_from_coords(atlas)):
				continue
			var drop_y: int = y
			while drop_y + 1 < world_bottom and not main_out.has(Vector2i(tx, drop_y + 1)):
				drop_y += 1
			if drop_y != y:
				main_out.erase(cell)
				main_out[Vector2i(tx, drop_y)] = atlas

# ===========================================================================
# SURFACE HEIGHT HELPERS
# ===========================================================================

## Height using pre-computed biome and landform — avoids double noise sampling
func _get_surface_height_cached(x: int, biome_id: int, landform_id: int) -> int:
	var macro:     float = _continental_noise.get_noise_2d(float(x), 0.0) * macro_height_scale
	var variation: float = _terrain_variation_noise.get_noise_2d(float(x), 0.0) * terrain_variation_strength
	var base_h:    float = float(surface_mid_y) + (macro + variation) * float(terrain_amplitude)
	var shaped:    float = _apply_landform_shape(x, base_h, landform_id)
	var detail:    float = _detail_noise.get_noise_2d(float(x), 0.0) * terrain_detail_strength * float(terrain_amplitude)
	var bias: float = -0.8 if biome_id == BIOME_DESERT else (0.35 if biome_id == BIOME_FOREST else 0.0)
	return int(round(shaped + detail + bias))

func _get_bg_surface_height(x: int) -> int:
	var large: float = _bg_macro_noise.get_noise_2d(float(x), 0.0) * bg_large_shape_scale
	var mid:   float = _bg_mid_noise.get_noise_2d(float(x), 0.0) * bg_mid_shape_scale
	var tiny:  float = _bg_detail_noise.get_noise_2d(float(x), 0.0) * bg_detail_shape_scale
	var raw:   float = clamp(large + mid + tiny, -1.0, 1.0)
	var signed:float = sign(raw) * pow(abs(raw), max(0.25, bg_shape_power))
	var ridge: float = (1.0 - abs(raw)) * 2.0 - 1.0
	var n: float = lerp(signed, ridge, clamp(bg_cliff_strength, 0.0, 1.0) * 0.35)
	var h: float = float(surface_mid_y) + n * float(terrain_amplitude) * bg_mountain_scale
	return int(floor(h / float(max(1, bg_cliff_step_tiles))) * float(max(1, bg_cliff_step_tiles)))

func _get_biome_id(x: int) -> int:
	var b: float = clamp((_biome_noise.get_noise_2d(float(x), 0.0) + 1.0) * 0.5, 0.0, 1.0)
	if b > 0.78: return BIOME_DESERT
	if b > 0.57: return BIOME_PLAINS
	if b > 0.32: return BIOME_FOREST
	return BIOME_BIRCH_FOREST

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
			var c: float = (_cliff_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var s: float = sign(c - 0.5) * pow(abs(c - 0.5) * 2.0, cliff_sharpness)
			var h: float = base_h + s * float(terrain_amplitude) * cliffs_scale
			return floor(h / float(max(1, cliff_ledge_step_tiles))) * float(max(1, cliff_ledge_step_tiles))
		LandformType.PLATEAUS:
			var p: float = (_plateau_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var flat: float = floor(base_h / float(max(1, plateau_step_tiles))) * float(max(1, plateau_step_tiles))
			return lerp(base_h + (p - 0.5) * float(terrain_amplitude) * plateau_scale, flat, clamp(plateau_flatten_strength, 0.0, 1.0))
		_:
			var bowl: float = (_valley_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			return base_h + pow(1.0 - bowl, max(0.2, valley_width_strength)) * float(terrain_amplitude) * valley_scale * valley_depth_strength

# ===========================================================================
# SMOOTHING
# ===========================================================================
func _smooth_int_array(raw: Array[int], radius: int) -> Array[int]:
	var r: int = max(0, radius)
	if r == 0:
		return raw
	var out: Array[int] = []
	out.resize(raw.size())
	for x in raw.size():
		var total: float = 0.0
		var count: int   = 0
		for k in range(-r, r + 1):
			var sx: int = clamp(x + k, 0, raw.size() - 1)
			total += float(raw[sx])
			count += 1
		out[x] = int(round(total / float(max(1, count))))
	return out

func _smooth_plain_array(raw: Array, radius: int) -> Array:
	var r: int = max(0, radius)
	if r == 0:
		return raw
	var out: Array = []
	out.resize(raw.size())
	for x in raw.size():
		var total: float = 0.0
		var count: int   = 0
		for k in range(-r, r + 1):
			var sx: int = clamp(x + k, 0, raw.size() - 1)
			total += float(raw[sx])
			count += 1
		out[x] = int(round(total / float(max(1, count))))
	return out

# ===========================================================================
# MISC
# ===========================================================================
func _in_depth_band(depth: int, min_d: int, max_d: int) -> bool:
	return depth >= min_d and depth <= max_d

func _pick_stone_variant(x: int, y: int, depth: int) -> Vector2i:
	var n: float = (_detail_noise.get_noise_2d(float(x) * 0.55 + 31.0, float(y) * 0.55 - 19.0) + 1.0) * 0.5
	if depth >= stone_start_depth + 3 and _c_gravel  != Vector2i(-1,-1) and n > 0.965: return _c_gravel
	if _c_granite  != Vector2i(-1,-1) and n < 0.18:                                    return _c_granite
	if _c_diorite  != Vector2i(-1,-1) and n > 0.82:                                    return _c_diorite
	if _c_andesite != Vector2i(-1,-1) and n > 0.47 and n < 0.59:                       return _c_andesite
	return _c_stone

func _is_bedrock_cell(x: int, y: int, world_bottom: int) -> bool:
	var base:        int = max(1, bedrock_base_layers)
	var extra:       int = max(0, bedrock_extra_layers)
	var bottom_y:    int = world_bottom - 1
	var threshold_y: int = bottom_y - (base - 1)
	if y >= threshold_y:
		return true
	if extra == 0:
		return false
	var top_y: int = threshold_y - extra
	if y < top_y:
		return false
	var row: int    = y - top_y
	var ratio:float = float(row + 1) / float(extra + 1)
	var n: float    = (_detail_noise.get_noise_2d(float(x) * 0.37 + 77.0, float(y) * 0.91 - 53.0) + 1.0) * 0.5
	return n < ratio

func _pick_weighted_tree(valid_types: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for tt: Dictionary in valid_types:
		total += max(1, int(tt.get("weight", 1)))
	if total <= 0:
		return valid_types[rng.randi() % valid_types.size()]
	var roll: int = rng.randi_range(1, total)
	var acc:  int = 0
	for tt: Dictionary in valid_types:
		acc += max(1, int(tt.get("weight", 1)))
		if roll <= acc:
			return tt
	return valid_types[0]

func _get_crown_rows(log_name: String, biome_id: int) -> Array[Dictionary]:
	if log_name == "Spruce Log":
		return [{"dy":0,"half_w":0},{"dy":1,"half_w":1},{"dy":2,"half_w":2},{"dy":3,"half_w":1}]
	if log_name == "Dark Oak Log":
		return [{"dy":0,"half_w":2},{"dy":1,"half_w":3},{"dy":2,"half_w":2}]
	if biome_id == BIOME_BIRCH_FOREST:
		return [{"dy":0,"half_w":1},{"dy":1,"half_w":1},{"dy":2,"half_w":2}]
	return [{"dy":0,"half_w":1},{"dy":1,"half_w":2},{"dy":2,"half_w":2},{"dy":3,"half_w":1}]

# ===========================================================================
# FAR BACKGROUND SILHOUETTE  (main thread only — called once)
# ===========================================================================
func _generate_far_silhouette_heights(amplitude: float) -> Array[float]:
	var tile_size:  float = 32.0
	var total_cols: int   = 400 * max(1, far_mtn_width_multiplier)
	var base_y:     float = float(surface_mid_y) * tile_size
	var heights: Array[float] = []
	heights.resize(total_cols)
	for xi in total_cols:
		var tx:        float = float(xi)
		var p1:        float = (_far_primary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var p2:        float = (_far_secondary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var primary:   float = 1.0 - abs(2.0 * p1 - 1.0)
		var secondary: float = (1.0 - abs(2.0 * p2 - 1.0)) * 0.5
		var detail:    float = _far_detail_noise.get_noise_2d(tx, 0.0) * 0.2
		var vmask:     float = (_far_valley_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var n: float = clamp(primary + secondary + detail - (1.0 - vmask) * far_valley_bias, 0.0, 1.0)
		heights[xi] = base_y - pow(n, max(0.25, far_shape_power)) * amplitude * tile_size
	return heights