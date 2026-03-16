# ---------------------------------------------------------------------------
# WORLD GENERATOR
# Attach to any Node in your main scene.
#
# LAYER SYSTEM (back → front):
#   layer_background (z -60) — background:  decorative scenery, non-interactive
#   layer_back_wall  (z -40) — back wall:   cave/dungeon walls, placeable/breakable
#   layer_object     (z -20) — objects:     tree trunks, workstations, furniture
#   layer_main       (z   0) — main:        solid terrain, collision, primary gameplay
#
# Set the z_index on each TileMapLayer node in the Godot editor to match the
# values above.  The group names are what the scripts use to find each layer.
#
# BACKGROUND LAYER is generated independently with:
#   - Its own mountain heightmap (higher amplitude, slower noise)
#   - Scattered background ores (visual only, not mineable)
#   - Cave walls where the foreground has caves
#
# ADDING A NEW TREE TYPE:
#   1. Add the log and leaves blocks to BlockRegistry (with PNGs)
#   2. Add an entry to TREE_TYPES below — that's it.
# ---------------------------------------------------------------------------
extends Node

## Emitted when the world has fully generated.
## Passes mountain height arrays (world-space y pixels) for the far background.
signal generation_complete(seed_val: int, world_w: int, mtn_far: Array, mtn_near: Array)

const BIOME_BIRCH_FOREST: int = 0
const BIOME_FOREST: int = 1
const BIOME_PLAINS: int = 2
const BIOME_DESERT: int = 3

enum LandformType {
	PLAINS,
	ROLLING_HILLS,
	CLIFFS,
	PLATEAUS,
	VALLEYS,
}

const TREE_TYPES: Array = [
	{
		"log":     "Oak Log",
		"leaves":  "Oak Leaves",
		"surface": "Grass",
		"crown":   true,    # true = diamond leaf crown on top
		"biomes":  [BIOME_FOREST, BIOME_PLAINS],
		"weight":  5,
		"height_min": 4,
		"height_max": 7,
	},
	{
		"log":     "Birch Log",
		"leaves":  "Birch Leaves",
		"surface": "Grass",
		"crown":   true,
		"biomes":  [BIOME_BIRCH_FOREST, BIOME_PLAINS],
		"weight":  5,
		"height_min": 5,
		"height_max": 8,
	},
	{
		"log":     "Acacia Log",
		"leaves":  "Acacia Leaves",
		"surface": "Grass",
		"crown":   true,
		"biomes":  [BIOME_PLAINS],
		"weight":  2,
		"height_min": 5,
		"height_max": 7,
	},
	{
		"log":     "Spruce Log",
		"leaves":  "Spruce Leaves",
		"surface": "Grass",
		"crown":   true,
		"biomes":  [BIOME_FOREST],
		"weight":  3,
		"height_min": 6,
		"height_max": 9,
	},{
		"log":     "Jungle Log",
		"leaves":  "Jungle Leaves",
		"surface": "Grass",
		"crown":   true,
		"biomes":  [BIOME_FOREST],
		"weight":  2,
		"height_min": 7,
		"height_max": 10,
	},{
		"log":     "Dark Oak Log",
		"leaves":  "Dark Oak Leaves",
		"surface": "Grass",
		"crown":   true,
		"biomes":  [BIOME_FOREST],
		"weight":  2,
		"height_min": 5,
		"height_max": 7,
	},
	{
		"log":     "Cactus",
		"leaves":  "Cactus",
		"surface": "Sand",
		"crown":   false,   # false = no crown, just a straight column
		"biomes":  [BIOME_DESERT],
		"weight":  8,
		"height_min": 3,
		"height_max": 6,
	},
]

# ---------------------------------------------------------------------------
@export var tilemap_source_id: int = 0

@export_group("Seed")
@export var seed_value: int = 0

@export_group("World Size")
@export var world_width: int       = 400
@export var surface_mid_y: int     = 30
@export var terrain_amplitude: int = 20

@export_group("Main Terrain Shaping")
@export var macro_height_scale: float      = 1.75
@export var plains_scale: float            = 0.26
@export var hills_scale: float             = 0.85
@export var cliffs_scale: float            = 1.35
@export var plateau_scale: float           = 0.70
@export var valley_scale: float            = 1.00
@export var terrain_variation_strength: float = 0.62
@export var terrain_detail_strength: float = 0.10

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
@export var cave_threshold: float  = 0.62

@export_group("Ores")
@export var coal_threshold: float       = 0.69
@export var copper_threshold: float     = 0.75
@export var iron_threshold: float       = 0.80
@export var gold_threshold: float       = 0.83
@export var diamond_threshold: float    = 0.90
@export var titanium_threshold: float   = 0.93

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
@export var bg_ore_chance: float            = 0.06

@export_group("Far Background Shaping")
@export var far_mtn_width_multiplier: int   = 4
@export var far_mtn_amplitude: float        = 120.0
@export var near_mtn_amplitude: float       = 70.0
@export var far_bg_mountain_scale: float    = 1.8
@export var far_bg_y_offset: int            = -4
@export var far_peak_scale: float           = 1.0
@export var far_secondary_scale: float      = 0.22
@export var far_detail_scale: float         = 0.03
@export var far_shape_power: float          = 1.25
@export var far_valley_bias: float          = 0.12
@export var far_bg_cliff_strength: float    = 0.50
@export var far_bg_cliff_step_tiles: int    = 2
@export var far_bg_cliff_region_threshold: float = 0.72
@export var far_bg_cliff_drop_scale: float  = 0.28
@export var far_bg_smooth_radius: int       = 12
@export var far_bg_front_band_depth: int    = 20
@export var far_bg_back_band_depth: int     = 14
@export var far_bg_back_vertical_offset: int = -8
@export var far_bg_back_flatten: float      = 0.60

@export_group("Water")
@export var sea_level: int             = 36
@export var lake_attempt_ratio: float  = 0.025
@export var lake_min_radius: int       = 3
@export var lake_max_radius: int       = 6
@export var lake_min_depth: int        = 2
@export var lake_max_depth: int        = 4

@export_group("Bedrock")
@export var bedrock_base_layers: int   = 3
@export var bedrock_extra_layers: int  = 2

@export_group("Trees")
@export var tree_chance: float     = 0.4
@export var tree_min_height: int   = 4
@export var tree_max_height: int   = 7

# ---------------------------------------------------------------------------
var _main:        TileMapLayer = null
var _object:      TileMapLayer = null
var _back_wall:   TileMapLayer = null
var _background:  TileMapLayer = null
var _far_background_front: TileMapLayer = null
var _far_background_back: TileMapLayer = null

var _rng: RandomNumberGenerator    = RandomNumberGenerator.new()
var _continental_noise: FastNoiseLite = FastNoiseLite.new()   # macro baseline
var _terrain_variation_noise: FastNoiseLite = FastNoiseLite.new()
var _landform_noise: FastNoiseLite = FastNoiseLite.new()
var _cliff_control_noise: FastNoiseLite = FastNoiseLite.new()
var _plateau_control_noise: FastNoiseLite = FastNoiseLite.new()
var _valley_control_noise: FastNoiseLite = FastNoiseLite.new()
var _detail_noise: FastNoiseLite   = FastNoiseLite.new()      # micro post-detail

var _bg_macro_noise: FastNoiseLite = FastNoiseLite.new()
var _bg_mid_noise: FastNoiseLite = FastNoiseLite.new()
var _bg_detail_noise: FastNoiseLite = FastNoiseLite.new()

var _far_primary_noise: FastNoiseLite = FastNoiseLite.new()
var _far_secondary_noise: FastNoiseLite = FastNoiseLite.new()
var _far_detail_noise: FastNoiseLite = FastNoiseLite.new()
var _far_valley_noise: FastNoiseLite = FastNoiseLite.new()

var _cave_noise: FastNoiseLite     = FastNoiseLite.new()
var _ore_noise: FastNoiseLite      = FastNoiseLite.new()
var _bg_ore_noise: FastNoiseLite   = FastNoiseLite.new()   # separate ore noise for bg
var _biome_noise: FastNoiseLite    = FastNoiseLite.new()
var _tree_noise: FastNoiseLite     = FastNoiseLite.new()

var _c_grass: Vector2i = Vector2i(-1, -1)
var _c_dirt: Vector2i  = Vector2i(-1, -1)
var _c_sand: Vector2i  = Vector2i(-1, -1)
var _c_water: Vector2i = Vector2i(-1, -1)
var _c_bedrock: Vector2i = Vector2i(-1, -1)
var _c_stone: Vector2i = Vector2i(-1, -1)
var _c_gravel: Vector2i = Vector2i(-1, -1)
var _c_diorite: Vector2i = Vector2i(-1, -1)
var _c_granite: Vector2i = Vector2i(-1, -1)
var _c_andesite: Vector2i = Vector2i(-1, -1)
var _c_coal: Vector2i  = Vector2i(-1, -1)
var _c_iron: Vector2i  = Vector2i(-1, -1)
var _c_copper: Vector2i = Vector2i(-1, -1)
var _c_gold: Vector2i = Vector2i(-1, -1)
var _c_diamond: Vector2i = Vector2i(-1, -1)
var _c_titanium: Vector2i = Vector2i(-1, -1)

var _tree_type_coords: Array = []
var _last_mtn_far: Array[float] = []
var _last_mtn_near: Array[float] = []

# ---------------------------------------------------------------------------
func _ready() -> void:
	_main       = get_tree().get_first_node_in_group("layer_main")        as TileMapLayer
	_object     = get_tree().get_first_node_in_group("layer_object")      as TileMapLayer
	_back_wall  = get_tree().get_first_node_in_group("layer_back_wall")   as TileMapLayer
	_background = get_tree().get_first_node_in_group("layer_background")  as TileMapLayer
	_far_background_front = get_tree().get_first_node_in_group("layer_far_background_front") as TileMapLayer
	if _far_background_front == null:
		_far_background_front = get_tree().get_first_node_in_group("layer_far_background") as TileMapLayer
	_far_background_back = get_tree().get_first_node_in_group("layer_far_background_back") as TileMapLayer

	if _main == null:
		push_error("WorldGen: 'layer_main' group not found. Aborting.")
		return
	if _object     == null: push_warning("WorldGen: 'layer_object' layer not found.")
	if _back_wall  == null: push_warning("WorldGen: 'layer_back_wall' layer not found.")
	if _background == null: push_warning("WorldGen: 'layer_background' layer not found.")
	if _far_background_front == null: push_warning("WorldGen: far background front layer not found (optional).")
	if _far_background_back == null: push_warning("WorldGen: far background back layer not found (optional).")

	await get_tree().process_frame
	await get_tree().process_frame

	if not TileSetBuilder.tileset_ready:
		push_error("WorldGen: TileSetBuilder did not finish. Aborting.")
		return

	if seed_value == 0:
		seed_value = randi()
	print("WorldGen: seed = %d" % seed_value)

	_setup_noise()
	generate()

# ---------------------------------------------------------------------------
func _setup_noise() -> void:
	_rng.seed = seed_value

	# Main terrain: macro baseline + landform controls + light detail.
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

	_landform_noise.seed               = seed_value + 32
	_landform_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_landform_noise.frequency          = 0.0022
	_landform_noise.fractal_octaves    = 2

	_cliff_control_noise.seed               = seed_value + 33
	_cliff_control_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_cliff_control_noise.frequency          = 0.008
	_cliff_control_noise.fractal_octaves    = 2

	_plateau_control_noise.seed               = seed_value + 34
	_plateau_control_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_plateau_control_noise.frequency          = 0.006
	_plateau_control_noise.fractal_octaves    = 2

	_valley_control_noise.seed               = seed_value + 35
	_valley_control_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_valley_control_noise.frequency          = 0.0035
	_valley_control_noise.fractal_octaves    = 2

	# Caves
	_cave_noise.seed                  = seed_value + 1
	_cave_noise.noise_type            = FastNoiseLite.TYPE_PERLIN
	_cave_noise.frequency             = 0.04
	_cave_noise.fractal_octaves       = 2

	# Foreground ores
	_ore_noise.seed                   = seed_value + 2
	_ore_noise.noise_type             = FastNoiseLite.TYPE_PERLIN
	_ore_noise.frequency              = 0.09
	_ore_noise.fractal_octaves        = 1

	# Background ores — different seed so they don't mirror foreground
	_bg_ore_noise.seed                = seed_value + 20
	_bg_ore_noise.noise_type          = FastNoiseLite.TYPE_PERLIN
	_bg_ore_noise.frequency           = 0.12
	_bg_ore_noise.fractal_octaves     = 1

	# Biome — very slow, smooth transitions between grass/desert
	_biome_noise.seed                 = seed_value + 3
	_biome_noise.noise_type           = FastNoiseLite.TYPE_PERLIN
	_biome_noise.frequency            = 0.008
	_biome_noise.fractal_octaves      = 1

	# Trees
	_tree_noise.seed                  = seed_value + 4
	_tree_noise.noise_type            = FastNoiseLite.TYPE_PERLIN
	_tree_noise.frequency             = 0.15
	_tree_noise.fractal_octaves       = 1

	# Light post-shape detail.
	_detail_noise.seed                = seed_value + 5
	_detail_noise.noise_type          = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency           = 0.03
	_detail_noise.fractal_octaves     = 2

	# Near background: broad masses + restrained medium/detail shapes.
	_bg_macro_noise.seed               = seed_value + 40
	_bg_macro_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_bg_macro_noise.frequency          = 0.0018
	_bg_macro_noise.fractal_octaves    = 2

	_bg_mid_noise.seed               = seed_value + 41
	_bg_mid_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_bg_mid_noise.frequency          = 0.004
	_bg_mid_noise.fractal_octaves    = 2

	_bg_detail_noise.seed               = seed_value + 42
	_bg_detail_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_bg_detail_noise.frequency          = 0.012
	_bg_detail_noise.fractal_octaves    = 1

	# Far background: dedicated mountain silhouette noises.
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

	_far_detail_noise.seed               = seed_value + 52
	_far_detail_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_far_detail_noise.frequency          = 0.018
	_far_detail_noise.fractal_octaves    = 1

	_far_valley_noise.seed               = seed_value + 53
	_far_valley_noise.noise_type         = FastNoiseLite.TYPE_PERLIN
	_far_valley_noise.frequency          = 0.0032
	_far_valley_noise.fractal_octaves    = 2

# ---------------------------------------------------------------------------
func generate() -> void:
	_main.clear()
	if _object     != null: _object.clear()
	if _back_wall  != null: _back_wall.clear()
	if _background != null: _background.clear()
	if _far_background_front != null: _far_background_front.clear()
	if _far_background_back != null: _far_background_back.clear()

	_c_grass  = BlockRegistry.get_coords_from_name("Grass")
	_c_dirt   = BlockRegistry.get_coords_from_name("Dirt")
	_c_sand   = BlockRegistry.get_coords_from_name("Sand")
	_c_water  = BlockRegistry.get_coords_from_name("Water")
	_c_bedrock = BlockRegistry.get_coords_from_name("Bedrock")
	_c_stone  = BlockRegistry.get_coords_from_name("Stone")
	_c_gravel = BlockRegistry.get_coords_from_name("Gravel")
	_c_diorite = BlockRegistry.get_coords_from_name("Diorite")
	_c_granite = BlockRegistry.get_coords_from_name("Granite")
	_c_andesite = BlockRegistry.get_coords_from_name("Andesite")
	_c_coal   = BlockRegistry.get_coords_from_name("Coal Ore")
	_c_iron   = BlockRegistry.get_coords_from_name("Iron Ore")
	_c_copper = BlockRegistry.get_coords_from_name("Copper Ore")
	_c_gold = BlockRegistry.get_coords_from_name("Gold Ore")
	_c_diamond = BlockRegistry.get_coords_from_name("Diamond Ore")
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
			"log":    lc,
			"leaves": lv,
			"surface": tree_def["surface"],
			"crown":  tree_def.get("crown", true),
			"biomes": tree_def.get("biomes", [BIOME_FOREST, BIOME_PLAINS, BIOME_BIRCH_FOREST]),
			"weight": int(tree_def.get("weight", 1)),
			"height_min": int(tree_def.get("height_min", tree_min_height)),
			"height_max": int(tree_def.get("height_max", tree_max_height)),
			"log_name": tree_def["log"],
		})

	print("WorldGen: %d tree type(s) loaded." % _tree_type_coords.size())

	if _c_grass == Vector2i(-1,-1) and _c_stone == Vector2i(-1,-1):
		push_error("WorldGen: terrain coords all (-1,-1). Aborting.")
		return

	# Pass 1 — foreground terrain
	var surface_heights: Array[int] = _generate_main_surface_heights()
	for x in world_width:
		_fill_column(x, surface_heights[x])

	# Pass 2 — background layer (independent mountains + ores)
	_fill_background(surface_heights)
	_fill_far_background(surface_heights)

	# Pass 3 — lakes and sea fill
	_fill_lakes(surface_heights)
	_fill_sea_level_water(surface_heights)

	# Pass 4 — trees
	for x in world_width:
		_try_place_tree(x, surface_heights[x], surface_heights)

	# Pass 5 — flat spawn strip
	_carve_spawn_platform(surface_heights)

	# Pass 6 — settle physical blocks
	_settle_physical_blocks()

	print("WorldGen: generation complete.")
	var mtn_far:  Array[float] = _generate_far_silhouette_heights(far_mtn_amplitude)
	var mtn_near: Array[float] = _generate_far_silhouette_heights(near_mtn_amplitude * 0.9)
	_last_mtn_far = mtn_far
	_last_mtn_near = mtn_near
	_emit_generation_complete()
	call_deferred("_emit_generation_complete")

func _emit_generation_complete() -> void:
	if _last_mtn_far.is_empty() or _last_mtn_near.is_empty():
		return
	generation_complete.emit(seed_value, world_width, _last_mtn_far, _last_mtn_near)

func get_far_background_data() -> Dictionary:
	return {
		"seed": seed_value,
		"world_width": world_width,
		"mtn_far": _last_mtn_far,
		"mtn_near": _last_mtn_near,
	}

# ---------------------------------------------------------------------------
# SURFACE HEIGHT
# Terrain is shaped in layers:
# macro baseline -> landform type -> region shaping -> light detail -> smoothing.
# ---------------------------------------------------------------------------
func _get_surface_height(x: int) -> int:
	var macro: float = _continental_noise.get_noise_2d(float(x), 0.0) * macro_height_scale
	var variation: float = _terrain_variation_noise.get_noise_2d(float(x), 0.0) * terrain_variation_strength
	var base_h: float = float(surface_mid_y) + (macro + variation) * float(terrain_amplitude)
	var landform: int = _get_landform_type(x)
	var shaped: float = _apply_landform_shape(x, base_h, landform)
	var detail: float = _detail_noise.get_noise_2d(float(x), 0.0) * terrain_detail_strength * float(terrain_amplitude)
	var biome_id: int = _get_biome_id(x)
	var biome_bias: float = 0.0
	if biome_id == BIOME_DESERT:
		biome_bias = -0.8
	elif biome_id == BIOME_FOREST:
		biome_bias = 0.35
	return int(round(shaped + detail + biome_bias))

func _get_bg_surface_height(x: int) -> int:
	var large: float = _bg_macro_noise.get_noise_2d(float(x), 0.0) * bg_large_shape_scale
	var mid: float = _bg_mid_noise.get_noise_2d(float(x), 0.0) * bg_mid_shape_scale
	var tiny: float = _bg_detail_noise.get_noise_2d(float(x), 0.0) * bg_detail_shape_scale
	var raw: float = clamp(large + mid + tiny, -1.0, 1.0)
	var signed: float = sign(raw) * pow(abs(raw), max(0.25, bg_shape_power))
	var ridge: float = 1.0 - abs(raw)
	ridge = ridge * 2.0 - 1.0
	var n: float = lerp(signed, ridge, clamp(bg_cliff_strength, 0.0, 1.0) * 0.35)
	var h: float = float(surface_mid_y) + n * float(terrain_amplitude) * bg_mountain_scale
	return int(floor(h / float(max(1, bg_cliff_step_tiles))) * float(max(1, bg_cliff_step_tiles)))

func _generate_main_surface_heights() -> Array[int]:
	var heights: Array[int] = []
	heights.resize(world_width)
	for x in world_width:
		heights[x] = _get_surface_height(x)
	return _smooth_surface_heights(heights, main_surface_smooth_radius)

func _get_landform_type(x: int) -> int:
	var lf: float = (_landform_noise.get_noise_2d(float(x), 0.0) + 1.0) * 0.5
	if lf < landform_plain_threshold:
		return LandformType.PLAINS
	if lf < landform_hills_threshold:
		return LandformType.ROLLING_HILLS
	if lf < landform_cliffs_threshold:
		return LandformType.CLIFFS
	if lf < landform_plateau_threshold:
		return LandformType.PLATEAUS
	return LandformType.VALLEYS

func _apply_landform_shape(x: int, base_h: float, landform: int) -> float:
	var tx: float = float(x)
	match landform:
		LandformType.PLAINS:
			var n: float = _terrain_variation_noise.get_noise_2d(tx * 0.6, 121.0)
			return base_h + n * float(terrain_amplitude) * plains_scale
		LandformType.ROLLING_HILLS:
			var n: float = _terrain_variation_noise.get_noise_2d(tx * 0.9, -82.0)
			return base_h + n * float(terrain_amplitude) * hills_scale
		LandformType.CLIFFS:
			var c: float = (_cliff_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var signed: float = sign(c - 0.5) * pow(abs(c - 0.5) * 2.0, cliff_sharpness)
			var h: float = base_h + signed * float(terrain_amplitude) * cliffs_scale
			return floor(h / float(max(1, cliff_ledge_step_tiles))) * float(max(1, cliff_ledge_step_tiles))
		LandformType.PLATEAUS:
			var p: float = (_plateau_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var flat_target: float = floor(base_h / float(max(1, plateau_step_tiles))) * float(max(1, plateau_step_tiles))
			var h: float = lerp(base_h + (p - 0.5) * float(terrain_amplitude) * plateau_scale, flat_target, clamp(plateau_flatten_strength, 0.0, 1.0))
			return h
		_:
			var bowl: float = (_valley_control_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
			var carved: float = pow(1.0 - bowl, max(0.2, valley_width_strength))
			return base_h + carved * float(terrain_amplitude) * valley_scale * valley_depth_strength

func _smooth_surface_heights(raw_heights: Array[int], radius: int) -> Array[int]:
	var r: int = max(0, radius)
	if r == 0:
		return raw_heights
	var out: Array[int] = []
	out.resize(raw_heights.size())
	for x in raw_heights.size():
		var total: float = 0.0
		var count: int = 0
		for k in range(-r, r + 1):
			var sx: int = clamp(x + k, 0, raw_heights.size() - 1)
			total += float(raw_heights[sx])
			count += 1
		out[x] = int(round(total / float(max(1, count))))
	return out

func _get_biome(x: int) -> float:
	var n: float = _biome_noise.get_noise_2d(float(x), 0.0)
	return clamp((n + 1.0) * 0.5, 0.0, 1.0)

func _get_biome_id(x: int) -> int:
	var b: float = _get_biome(x)
	if b > 0.78:
		return BIOME_DESERT
	if b > 0.57:
		return BIOME_PLAINS
	if b > 0.32:
		return BIOME_FOREST
	return BIOME_BIRCH_FOREST

# ---------------------------------------------------------------------------
# FOREGROUND COLUMN
# ---------------------------------------------------------------------------
func _fill_column(x: int, surface_y: int) -> void:
	var world_bottom: int = surface_mid_y + terrain_amplitude + 80
	var biome_id: int     = _get_biome_id(x)
	var is_desert: bool   = biome_id == BIOME_DESERT

	for y in range(surface_y, world_bottom):
		var depth: int = y - surface_y
		if _is_bedrock_cell(x, y, world_bottom):
			if _c_bedrock != Vector2i(-1, -1):
				_main.set_cell(Vector2i(x, y), tilemap_source_id, _c_bedrock)
				if _back_wall != null:
					_back_wall.set_cell(Vector2i(x, y), tilemap_source_id, _c_bedrock)
			else:
				_main.set_cell(Vector2i(x, y), tilemap_source_id, _c_stone)
				if _back_wall != null:
					_back_wall.set_cell(Vector2i(x, y), tilemap_source_id, _c_stone)
			continue

		var is_cave: bool = false
		if depth > 2:
			var cave_main: float = (_cave_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var cave_tunnel: float = (_cave_noise.get_noise_2d(float(x) * 1.7, float(y) * 0.75 + 140.0) + 1.0) * 0.5
			var cave_cutoff: float = cave_threshold
			if depth > 20:
				cave_cutoff -= 0.05
			if cave_main > cave_cutoff or cave_tunnel > cave_cutoff + 0.08:
				is_cave = true

		var atlas: Vector2i = _pick_fg_block(x, y, depth, biome_id, is_desert)
		if atlas == Vector2i(-1, -1):
			continue

		if is_cave:
			# Cave air on fg — wall layer shows the cave wall behind it
			if _back_wall != null:
				_back_wall.set_cell(Vector2i(x, y), tilemap_source_id, atlas)
		else:
			_main.set_cell(Vector2i(x, y), tilemap_source_id, atlas)
			# Wall layer mirrors fg so cave entrances don't show sky
			if _back_wall != null:
				_back_wall.set_cell(Vector2i(x, y), tilemap_source_id, atlas)

# ---------------------------------------------------------------------------
func _pick_fg_block(x: int, y: int, depth: int, biome_id: int, is_desert: bool) -> Vector2i:
	# Surface
	if depth == 0:
		return _c_sand if is_desert else _c_grass

	# Subsurface — desert has deeper sand, grass biome has dirt
	var sub_depth: int = dirt_depth
	if biome_id == BIOME_DESERT:
		sub_depth += 3
	elif biome_id == BIOME_PLAINS:
		sub_depth += 1
	if depth <= sub_depth:
		return _c_sand if is_desert else _c_dirt

	# Stone layer with ores
	if depth >= stone_start_depth:
		var ore_n: float = (_ore_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
		var ore_n2: float = (_ore_noise.get_noise_2d(float(x) * 0.73 + 97.0, float(y) * 1.21 - 41.0) + 1.0) * 0.5

		# Very deep ores first.
		if _in_depth_band(depth, titanium_min_depth, titanium_max_depth) and _c_titanium != Vector2i(-1, -1) and ore_n2 > titanium_threshold:
			return _c_titanium
		if _in_depth_band(depth, diamond_min_depth, diamond_max_depth) and _c_diamond != Vector2i(-1, -1) and ore_n2 > diamond_threshold:
			return _c_diamond

		# Mid/deep bands.
		if _in_depth_band(depth, iron_min_depth, iron_max_depth) and _c_iron != Vector2i(-1, -1) and ore_n > iron_threshold:
			return _c_iron
		var gold_in_band: bool = _in_depth_band(depth, gold_shallow_min_depth, gold_shallow_max_depth) or _in_depth_band(depth, gold_deep_min_depth, gold_deep_max_depth)
		if gold_in_band and _c_gold != Vector2i(-1, -1) and ore_n2 > gold_threshold:
			return _c_gold
		if _in_depth_band(depth, copper_min_depth, copper_max_depth) and _c_copper != Vector2i(-1, -1) and ore_n > copper_threshold:
			return _c_copper

		# Coal almost everywhere underground.
		if _c_coal != Vector2i(-1, -1) and ore_n > coal_threshold:
			return _c_coal

		return _pick_stone_variant(x, y, depth)

	return _c_dirt

# ---------------------------------------------------------------------------
# BACKGROUND LAYER
# Independently generated — taller mountains, different ore scatter.
# Never has caves (it IS the cave wall) — always filled solid.
# ---------------------------------------------------------------------------
func _fill_background(surface_heights: Array[int]) -> void:
	if _background == null:
		return

	var world_top: int = surface_mid_y - terrain_amplitude - 40
	var world_bottom: int = surface_mid_y + terrain_amplitude + 80
	var bg_surface_heights: Array[int] = []
	bg_surface_heights.resize(world_width)
	var match_strength: float = clamp(bg_match_main_strength, 0.0, 1.0)

	for x in world_width:
		var shaped_bg: int = _get_bg_surface_height(x) + bg_mountain_y_offset
		var main_matched: int = surface_heights[x] + bg_match_main_offset
		var blend_h: float = lerp(float(shaped_bg), float(main_matched), match_strength)
		var blend_noise: float = _bg_detail_noise.get_noise_2d(float(x), 137.0) * bg_match_noise_strength
		bg_surface_heights[x] = int(round(blend_h + blend_noise))
	bg_surface_heights = _smooth_surface_heights(bg_surface_heights, bg_surface_smooth_radius)

	for x in world_width:
		var bg_surface_y: int = bg_surface_heights[x]
		var biome_id: int     = _get_biome_id(x)
		var is_desert: bool   = biome_id == BIOME_DESERT

		var fill_from: int = max(world_top, bg_surface_y)

		for y in range(fill_from, world_bottom):
			var cell: Vector2i = Vector2i(x, y)
			var depth: int     = y - bg_surface_y

			var atlas: Vector2i = _pick_bg_block(x, y, depth, is_desert)
			if atlas != Vector2i(-1, -1):
				_background.set_cell(cell, tilemap_source_id, atlas)

func _pick_bg_block(x: int, y: int, depth: int, is_desert: bool) -> Vector2i:
	# Surface of background
	if depth == 0:
		return _c_sand if is_desert else _c_grass

	if depth <= dirt_depth:
		return _c_sand if is_desert else _c_dirt

	# Block-based mountain body (no ore noise in far scenery)
	if depth >= stone_start_depth:
		if bg_cliff_step_tiles > 1 and depth < stone_start_depth + 8:
			var ledge_step: float = float(bg_cliff_step_tiles)
			var ledge_depth: int = int(floor(float(depth) / ledge_step) * ledge_step)
			return _pick_stone_variant(x, y + ledge_depth, depth)
		return _pick_stone_variant(x, y, depth)

	return _c_dirt

# ---------------------------------------------------------------------------
# FAR BACKGROUND TILE LAYER (optional)
# Uses the same block set, but pushed farther up to read as distant mountains.
# ---------------------------------------------------------------------------
func _fill_far_background(surface_heights: Array[int]) -> void:
	if _far_background_front == null and _far_background_back == null:
		return

	var world_top: int = surface_mid_y - terrain_amplitude - 80
	# Keep far mountains as distant bands, not a full-depth dark wall.
	var world_bottom: int = surface_mid_y + int(float(terrain_amplitude) * 0.15)
	var front_surface: Array[int] = _generate_far_surface_heights()
	var back_surface: Array[int] = _generate_far_back_surface(front_surface)

	# Back band: smoother, slightly higher, stone-only silhouette.
	for x in world_width:
		var back_y: int = back_surface[x]
		var fill_from_back: int = max(world_top, back_y)
		var fill_to_back: int = min(world_bottom, back_y + max(4, far_bg_back_band_depth))
		for y in range(fill_from_back, fill_to_back):
			var depth_back: int = y - back_y
			if depth_back < 0:
				continue
			var atlas_back: Vector2i = _pick_stone_variant(x, y, depth_back + 12)
			if atlas_back != Vector2i(-1, -1):
				if _far_background_back != null:
					_far_background_back.set_cell(Vector2i(x, y), tilemap_source_id, atlas_back)
				elif _far_background_front != null:
					_far_background_front.set_cell(Vector2i(x, y), tilemap_source_id, atlas_back)

	for x in world_width:
		var bg_surface_y: int = front_surface[x]
		var biome_id: int = _get_biome_id(x)
		var is_desert: bool = biome_id == BIOME_DESERT
		var fill_from: int = max(world_top, bg_surface_y)
		var fill_to: int = min(world_bottom, bg_surface_y + max(5, far_bg_front_band_depth))
		if fill_from >= fill_to:
			continue

		for y in range(fill_from, fill_to):
			var depth: int = y - bg_surface_y
			if depth < 0:
				continue

			var atlas: Vector2i = _pick_far_bg_block(x, y, depth, is_desert)
			if atlas != Vector2i(-1, -1):
				if _far_background_front != null:
					_far_background_front.set_cell(Vector2i(x, y), tilemap_source_id, atlas)
				elif _far_background_back != null:
					_far_background_back.set_cell(Vector2i(x, y), tilemap_source_id, atlas)

func _generate_far_back_surface(front_surface: Array[int]) -> Array[int]:
	if front_surface.is_empty():
		return front_surface
	var out: Array[int] = []
	out.resize(front_surface.size())
	var flatten: float = clamp(far_bg_back_flatten, 0.0, 1.0)
	var horizon_y: float = float(surface_mid_y) - float(terrain_amplitude) * 0.35 + float(far_bg_y_offset)
	for x in front_surface.size():
		var f: float = float(front_surface[x])
		var h: float = lerp(f, horizon_y, flatten) + float(far_bg_back_vertical_offset)
		h += _far_secondary_noise.get_noise_2d(float(x) * 0.55, 909.0) * 2.0
		out[x] = int(round(h))
	out = _smooth_surface_heights(out, max(far_bg_smooth_radius + 4, 8))
	return out

func _generate_far_surface_heights() -> Array[int]:
	var far_surface: Array[int] = []
	far_surface.resize(world_width)
	var horizon_y: float = float(surface_mid_y) - float(terrain_amplitude) * 0.35 + float(far_bg_y_offset)
	var peak_height: float = float(terrain_amplitude) * far_bg_mountain_scale
	var points: Array[Vector2i] = _generate_far_profile_points(horizon_y, peak_height)
	if points.size() < 2:
		for x in world_width:
			far_surface[x] = int(horizon_y)
		return far_surface

	var seg: int = 0
	for x in world_width:
		while seg < points.size() - 2 and x > points[seg + 1].x:
			seg += 1
		var a: Vector2i = points[seg]
		var b: Vector2i = points[min(seg + 1, points.size() - 1)]
		var t: float = 0.0
		if b.x != a.x:
			t = clamp((float(x - a.x) / float(b.x - a.x)), 0.0, 1.0)
		var h: float = lerp(float(a.y), float(b.y), t)
		far_surface[x] = int(h)

	# Smooth piecewise profile into broader mountain masses.
	far_surface = _smooth_surface_heights(far_surface, far_bg_smooth_radius)
	far_surface = _apply_far_cliff_regions(far_surface, horizon_y, peak_height)
	far_surface = _apply_far_cliff_features(far_surface)

	# Keep the pixel-art stepped look from your sketch.
	var step_tiles: float = float(max(1, far_bg_cliff_step_tiles))
	for x in far_surface.size():
		far_surface[x] = int(floor(float(far_surface[x]) / step_tiles) * step_tiles)
	return far_surface

func _apply_far_cliff_regions(raw_heights: Array[int], horizon_y: float, peak_height: float) -> Array[int]:
	if raw_heights.is_empty():
		return raw_heights
	var out: Array[int] = raw_heights.duplicate()
	var strength: float = clamp(far_bg_cliff_strength, 0.0, 1.0)
	if strength <= 0.01:
		return out

	var n: int = out.size()
	var i: int = 1
	while i < n - 2:
		var region_mask: float = (_cliff_control_noise.get_noise_2d(float(i) * 0.22, 1107.0) + 1.0) * 0.5
		if region_mask < far_bg_cliff_region_threshold:
			i += 1
			continue

		# Build short/medium steep segments so far bg contains visible cliff walls,
		# while mountain spans remain the dominant silhouette.
		var seg_len: int = _rng.randi_range(12, 34)
		var end_i: int = min(n - 1, i + seg_len)
		var drop_mask: float = (_valley_control_noise.get_noise_2d(float(i) * 0.5, -813.0) + 1.0) * 0.5
		var drop_tiles: float = lerp(3.0, max(4.0, peak_height * far_bg_cliff_drop_scale), drop_mask) * strength
		var start_h: float = float(out[i])
		var end_h: float = start_h + drop_tiles
		end_h = clamp(end_h, horizon_y - peak_height, horizon_y + peak_height * 0.75)

		for x in range(i, end_i + 1):
			var t: float = clamp(float(x - i) / float(max(1, end_i - i)), 0.0, 1.0)
			# Ease-in steep wall with slight stair feeling.
			var wall_t: float = pow(t, 0.58)
			var h: float = lerp(start_h, end_h, wall_t)
			out[x] = int(round(h))

		i = end_i + 1

	# Light smooth to avoid sawtooth artifacts after forced wall spans.
	out = _smooth_surface_heights(out, 1)
	return out

func _apply_far_cliff_features(raw_heights: Array[int]) -> Array[int]:
	if raw_heights.is_empty():
		return raw_heights
	var strength: float = clamp(far_bg_cliff_strength, 0.0, 1.0)
	if strength <= 0.01:
		return raw_heights

	var out: Array[int] = raw_heights.duplicate()
	var n: int = out.size()
	for x in range(1, n - 1):
		var mask: float = (_cliff_control_noise.get_noise_2d(float(x) * 0.45, 731.0) + 1.0) * 0.5
		if mask < 0.60:
			continue

		var slope: float = float(raw_heights[x + 1] - raw_heights[x - 1])
		if abs(slope) < 1.5:
			continue

		var ledge_t: float = clamp((mask - 0.60) / 0.40, 0.0, 1.0) * strength
		var ledge_h: float = lerp(float(raw_heights[x]), float(out[x - 1]), ledge_t * 0.85)
		var face_push: float = sign(slope) * (1.0 + floor(ledge_t * 3.0))
		out[x] = int(round(ledge_h + face_push))

	out = _smooth_surface_heights(out, 1)
	return out

func _generate_far_profile_points(horizon_y: float, peak_height: float) -> Array[Vector2i]:
	var pts: Array[Vector2i] = []
	var x: int = 0
	var y: int = int(horizon_y)
	pts.append(Vector2i(0, y))
	var heading: float = -1.0 # -1 up, +1 down

	while x < world_width:
		# Wider segments create broader mountain masses, not tiny triangles.
		var seg_w: int = _rng.randi_range(42, 96)
		var nx: int = min(world_width - 1, x + seg_w)
		if nx <= x:
			break
		var tx: float = float(nx)
		var macro_peak: float = (_far_primary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var macro_valley: float = (_far_valley_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var drift: float = _far_secondary_noise.get_noise_2d(tx, 0.0) * peak_height * 0.14
		var depth_bias: float = (1.0 - macro_valley) * peak_height * (far_valley_bias + 0.16)
		var crest_bias: float = (0.32 + macro_peak * 0.50) * peak_height

		# Keep general ridge flow and only occasionally flip direction.
		if _rng.randf() < 0.12:
			heading *= -1.0

		var target_y: float = float(y) + heading * (_rng.randi_range(5, 12))
		target_y -= crest_bias * 0.24
		target_y += depth_bias * 0.30
		target_y += drift

		y = int(clamp(target_y, horizon_y - peak_height, horizon_y + peak_height * 0.45))
		pts.append(Vector2i(nx, y))
		x = nx

	return pts

func _pick_far_bg_block(x: int, y: int, depth: int, is_desert: bool) -> Vector2i:
	if depth == 0:
		return _c_sand if is_desert else _c_grass
	if depth <= dirt_depth + 1:
		return _c_sand if is_desert else _c_dirt
	return _pick_stone_variant(x, y, depth + 10)

# ---------------------------------------------------------------------------
# TREE PLACEMENT
# ---------------------------------------------------------------------------
func _try_place_tree(x: int, surface_y: int, surface_heights: Array) -> void:
	if _tree_type_coords.is_empty():
		return

	var surface_name: String = BlockRegistry.get_name_from_coords(
		_main.get_cell_atlas_coords(Vector2i(x, surface_y))
	)

	var valid_types: Array = []
	var biome_id: int = _get_biome_id(x)
	for tt: Dictionary in _tree_type_coords:
		if tt["surface"] == surface_name and tt["biomes"].has(biome_id):
			valid_types.append(tt)

	if valid_types.is_empty():
		return

	# Don't grow trees when the column is submerged.
	if _c_water != Vector2i(-1, -1):
		var above_surface: Vector2i = _main.get_cell_atlas_coords(Vector2i(x, surface_y - 1))
		if above_surface == _c_water:
			return

	var t: float = (_tree_noise.get_noise_2d(float(x), 500.0) + 1.0) * 0.5
	var local_density: float = tree_chance
	if biome_id == BIOME_FOREST or biome_id == BIOME_BIRCH_FOREST:
		local_density += 0.16
	elif biome_id == BIOME_DESERT:
		local_density -= 0.06
	local_density = clamp(local_density, 0.05, 0.95)
	if t >= local_density:
		return

	if _object != null:
		for nx in range(x - 2, x + 3):
			if nx == x or nx < 0 or nx >= world_width:
				continue
			var trunk_check: Vector2i  = Vector2i(nx, surface_heights[nx] - 1)
			var coords_there: Vector2i = _object.get_cell_atlas_coords(trunk_check)
			for tt: Dictionary in _tree_type_coords:
				if coords_there == tt["log"]:
					return

	var chosen: Dictionary = _pick_weighted_tree(valid_types)
	var c_log:    Vector2i = chosen["log"]
	var c_leaves: Vector2i = chosen["leaves"]

	var h_min: int = chosen["height_min"]
	var h_max: int = max(h_min, chosen["height_max"])
	var height: int = h_min + (_rng.randi() % (h_max - h_min + 1))
	var trunk_top_y: int    = surface_y - height
	var crown_top_y: int    = trunk_top_y - 1

	if chosen["crown"]:
		# Normal tree — trunk on objects layer, leaf crown on fg + wall
		if _object != null:
			for i in height:
				_object.set_cell(Vector2i(x, surface_y - 1 - i), tilemap_source_id, c_log)

		var crown_rows: Array[Dictionary] = _get_crown_rows(chosen["log_name"], biome_id)
		for row: Dictionary in crown_rows:
			var cy: int = crown_top_y + row["dy"]
			for cx in range(x - row["half_w"], x + row["half_w"] + 1):
				var lc: Vector2i = Vector2i(cx, cy)
				if _main.get_cell_source_id(lc) == -1:
					_main.set_cell(lc, tilemap_source_id, c_leaves)
				if _back_wall != null and _back_wall.get_cell_source_id(lc) == -1:
					_back_wall.set_cell(lc, tilemap_source_id, c_leaves)
	else:
		# No-crown plant (cactus etc.) — straight column on foreground only
		for i in height:
			var lc: Vector2i = Vector2i(x, surface_y - 1 - i)
			if _main.get_cell_source_id(lc) == -1:
				_main.set_cell(lc, tilemap_source_id, c_log)

# ---------------------------------------------------------------------------
# WATER
# ---------------------------------------------------------------------------
func _fill_lakes(surface_heights: Array[int]) -> void:
	if _c_water == Vector2i(-1, -1):
		push_warning("WorldGen: Water block not in registry — skipping lakes.")
		return
	if world_width < 12:
		return

	var attempts: int = max(1, int(float(world_width) * max(0.0, lake_attempt_ratio)))
	for _i in attempts:
		var cx: int = _rng.randi_range(6, world_width - 7)
		var biome_id: int = _get_biome_id(cx)
		if biome_id == BIOME_DESERT:
			continue

		var center_surface: int = surface_heights[cx]
		if center_surface >= sea_level - 1:
			continue

		var radius: int = _rng.randi_range(lake_min_radius, max(lake_min_radius, lake_max_radius))
		var depth: int = _rng.randi_range(lake_min_depth, max(lake_min_depth, lake_max_depth))
		var lake_top: int = center_surface + 1

		for dx in range(-radius, radius + 1):
			var x: int = cx + dx
			if x < 0 or x >= world_width:
				continue
			var edge_factor: float = 1.0 - (abs(float(dx)) / float(radius + 1))
			var local_depth: int = max(1, int(round(float(depth) * edge_factor)))
			var local_surface: int = surface_heights[x]

			for y in range(local_surface, local_surface + local_depth + 1):
				var cell: Vector2i = Vector2i(x, y)
				_main.erase_cell(cell)
				if _back_wall != null and y == local_surface:
					_back_wall.erase_cell(cell)

			for y in range(lake_top, local_surface + local_depth + 1):
				var water_cell: Vector2i = Vector2i(x, y)
				if _main.get_cell_source_id(water_cell) == -1:
					_main.set_cell(water_cell, tilemap_source_id, _c_water)

			surface_heights[x] = _find_surface_height(x, surface_heights[x])

func _fill_sea_level_water(surface_heights: Array[int]) -> void:
	if _c_water == Vector2i(-1, -1):
		push_warning("WorldGen: Water block not in registry — skipping sea fill.")
		return

	for x in world_width:
		var surface_y: int = surface_heights[x]
		if surface_y <= sea_level:
			continue
		for y in range(sea_level, surface_y):
			var cell: Vector2i = Vector2i(x, y)
			if _main.get_cell_source_id(cell) == -1:
				_main.set_cell(cell, tilemap_source_id, _c_water)

func _find_surface_height(x: int, fallback: int) -> int:
	var world_top: int = surface_mid_y - terrain_amplitude - 20
	var world_bottom: int = surface_mid_y + terrain_amplitude + 80
	for y in range(world_top, world_bottom):
		if _main.get_cell_source_id(Vector2i(x, y)) != -1:
			return y
	return fallback

func _in_depth_band(depth: int, min_depth: int, max_depth: int) -> bool:
	return depth >= min_depth and depth <= max_depth

func _pick_stone_variant(x: int, y: int, depth: int) -> Vector2i:
	var stone_n: float = (_detail_noise.get_noise_2d(float(x) * 0.55 + 31.0, float(y) * 0.55 - 19.0) + 1.0) * 0.5
	if depth >= stone_start_depth + 3 and _c_gravel != Vector2i(-1, -1) and stone_n > 0.965:
		return _c_gravel
	if _c_granite != Vector2i(-1, -1) and stone_n < 0.18:
		return _c_granite
	if _c_diorite != Vector2i(-1, -1) and stone_n > 0.82:
		return _c_diorite
	if _c_andesite != Vector2i(-1, -1) and stone_n > 0.47 and stone_n < 0.59:
		return _c_andesite
	return _c_stone

func _is_bedrock_cell(x: int, y: int, world_bottom: int) -> bool:
	var max_extra: int = max(0, bedrock_extra_layers)
	var base_layers: int = max(1, bedrock_base_layers)
	var bottom_y: int = world_bottom - 1
	var threshold_y: int = bottom_y - (base_layers - 1)
	if y >= threshold_y:
		return true
	if max_extra == 0:
		return false
	var top_y: int = threshold_y - max_extra
	if y < top_y:
		return false

	# Deterministic per-column/per-row variation: always solid at the bottom,
	# then increasingly sparse toward the top of the bedrock band.
	var row_from_top: int = y - top_y
	var fill_ratio: float = float(row_from_top + 1) / float(max_extra + 1)
	var n: float = (_detail_noise.get_noise_2d(float(x) * 0.37 + 77.0, float(y) * 0.91 - 53.0) + 1.0) * 0.5
	return n < fill_ratio

# ---------------------------------------------------------------------------
# FAR BACKGROUND MOUNTAIN GENERATION
# Produces a height array wider than the world (far_mtn_width_multiplier × world_width).
# Heights are stored as world-space y pixel values.
# Peaks sit well above surface_mid_y for a dramatic silhouette.
# ---------------------------------------------------------------------------
func _generate_far_silhouette_heights(amplitude: float) -> Array[float]:
	var tile_size:   float = 32.0
	var total_cols:  int   = world_width * max(1, far_mtn_width_multiplier)
	var base_y:      float = float(surface_mid_y) * tile_size
	var heights: Array[float] = []
	heights.resize(total_cols)
	for x: int in range(total_cols):
		var tx: float = float(x)
		var p1: float = (_far_primary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var p2: float = (_far_secondary_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var primary: float = 1.0 - abs(2.0 * p1 - 1.0)
		var secondary: float = (1.0 - abs(2.0 * p2 - 1.0)) * 0.5
		var detail: float = _far_detail_noise.get_noise_2d(tx, 0.0) * 0.2
		var valley_mask: float = (_far_valley_noise.get_noise_2d(tx, 0.0) + 1.0) * 0.5
		var n: float = clamp(primary + secondary + detail - (1.0 - valley_mask) * far_valley_bias, 0.0, 1.0)
		n = pow(n, max(0.25, far_shape_power))
		heights[x] = base_y - n * amplitude * tile_size
	return heights

# Backward-compatible wrapper if anything still calls the old API.
func _generate_far_mountains(_noise: FastNoiseLite, amplitude: float) -> Array[float]:
	return _generate_far_silhouette_heights(amplitude)

# ---------------------------------------------------------------------------
func _pick_weighted_tree(valid_types: Array) -> Dictionary:
	var total_weight: int = 0
	for tt: Dictionary in valid_types:
		total_weight += max(1, int(tt.get("weight", 1)))
	if total_weight <= 0:
		return valid_types[_rng.randi() % valid_types.size()]
	var roll: int = _rng.randi_range(1, total_weight)
	var acc: int = 0
	for tt: Dictionary in valid_types:
		acc += max(1, int(tt.get("weight", 1)))
		if roll <= acc:
			return tt
	return valid_types[0]

func _get_crown_rows(log_name: String, biome_id: int) -> Array[Dictionary]:
	if log_name == "Spruce Log":
		return [
			{"dy": 0, "half_w": 0},
			{"dy": 1, "half_w": 1},
			{"dy": 2, "half_w": 2},
			{"dy": 3, "half_w": 1},
		]
	if log_name == "Dark Oak Log":
		return [
			{"dy": 0, "half_w": 2},
			{"dy": 1, "half_w": 3},
			{"dy": 2, "half_w": 2},
		]
	if biome_id == BIOME_BIRCH_FOREST:
		return [
			{"dy": 0, "half_w": 1},
			{"dy": 1, "half_w": 1},
			{"dy": 2, "half_w": 2},
		]
	return [
		{"dy": 0, "half_w": 1},
		{"dy": 1, "half_w": 2},
		{"dy": 2, "half_w": 2},
		{"dy": 3, "half_w": 1},
	]

# ---------------------------------------------------------------------------
# PHYSICAL BLOCK SETTLING
# ---------------------------------------------------------------------------
func _settle_physical_blocks() -> void:
	var world_bottom: int = surface_mid_y + terrain_amplitude + 80
	var world_top: int    = surface_mid_y - terrain_amplitude - 10

	for x in world_width:
		for y in range(world_top, world_bottom):
			var cell: Vector2i = Vector2i(x, y)
			if _main.get_cell_source_id(cell) == -1:
				continue
			var atlas: Vector2i = _main.get_cell_atlas_coords(cell)
			var name: String    = BlockRegistry.get_name_from_coords(atlas)
			if not BlockRegistry.is_physical(name):
				continue
			var drop_y: int = y
			while drop_y + 1 < world_bottom and _main.get_cell_source_id(Vector2i(x, drop_y + 1)) == -1:
				drop_y += 1
			if drop_y != y:
				_main.erase_cell(cell)
				_main.set_cell(Vector2i(x, drop_y), tilemap_source_id, atlas)

# ---------------------------------------------------------------------------
# SPAWN PLATFORM
# ---------------------------------------------------------------------------
func _carve_spawn_platform(surface_heights: Array) -> void:
	var spawn_x: int    = 0
	var target_y: int   = surface_heights[spawn_x]
	var half_width: int = 3

	for x in range(max(0, spawn_x - half_width),
				   min(world_width, spawn_x + half_width + 1)):
		var col_y: int = surface_heights[x]
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
