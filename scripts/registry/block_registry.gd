# ---------------------------------------------------------------------------
# BLOCK REGISTRY — Autoload singleton
#
# HOW TO ADD A NEW BLOCK:
#   1. Add a PNG at res://assets/textures/blocks/<Name_With_Underscores>.png
#   2. Add an entry to BLOCKS below.
#   Never reorder or remove existing entries — only append new ones.
#
# AUTOLOAD ORDER: BlockRegistry → ItemRegistry → TileSetBuilder
#
# ---------------------------------------------------------------------------
# MATERIAL SYSTEM
# ---------------------------------------------------------------------------
# "material" defines the physical category of a block. The engine uses it to:
#   • Apply automatic tool efficiency bonuses (axes fast on Wood, etc.)
#   • Drive default sound, burn behavior, and future systems
#
# Allowed materials:
#   Stone | Dirt | Wood | Plant | Metal | Sand | Liquid | Leaves | Unbreakable
#
# ---------------------------------------------------------------------------
# BEHAVIOR SYSTEM
# ---------------------------------------------------------------------------
# "behaviors" is an Array of strings. Each string activates engine-side logic.
#
#   Falling        — block falls when unsupported (sand, gravel)
#   Fluid          — block is a non-solid liquid (water)
#   DamageOnTouch  — deals contact damage to the player
#   Leaves         — treated as foliage by tree-felling system
#   LightSource    — emits light (uses "luminous" value)
#   CraftingStation — opens a crafting UI when interacted with
#   Furnace        — opens a furnace UI when interacted with
#   Container      — opens a container/storage UI when interacted with
#
# ---------------------------------------------------------------------------
# PROPERTY REFERENCE
# ---------------------------------------------------------------------------
#
#  "material"      String   Physical category. See materials above.
#
#  "hardness"      float    Mining time base. break_time = hardness * 1.5
#
#  "resistance"    float    Explosion resistance.
#
#  "drop"          String | Dictionary | Array
#                           STRING  → drop exactly 1:  "drop": "Dirt"
#                           DICT    → random count:    "drop": {"item":"Coal","min":1,"max":3}
#                           ARRAY   → multiple entries, each a String or Dict
#
#  "stack"         int      Max inventory stack. 0 = unstackable.
#
#  "tool"          String   Required tool type: "Axe" "Pickaxe" "Shovel" "Shears" "Hand"
#
#  "tier"          int      Minimum tool tier: 0=Wood 1=Stone 2=Iron 3=Gold 4=Diamond 5=Titanium
#
#  "solid"         bool     true = has collision.
#
#  "breakable"     bool     true = can be mined. false = indestructible.
#
#  "replaceable"   bool     true = world gen can overwrite this block.
#
#  "unbreakable"   bool     true = engine skips mining entirely (Bedrock).
#
#  "luminous"      int      Light emitted (0–15).
#
#  "transparent"   bool     true = light and visibility pass through.
#
#  "contact_damage" int     Damage dealt per tick when touching. 0 = none.
#
#  "behaviors"     Array    List of behavior strings (see above).
#
#  "tags"          Array    Metadata strings for grouping. Used by crafting,
#                           world gen, AI, tool bonuses, and recipe queries.
#                           Tags must NOT replace behaviors.
#
#  "frames"        int      Animation frame count (default 1 = static).
#  "anim_fps"      float    Animation speed in frames/second.
#
# ---------------------------------------------------------------------------
extends Node

const TEXTURE_PATH:       String = "res://assets/textures/blocks/"
const HARDNESS_MULTIPLIER:float  = 1.5

# ---------------------------------------------------------------------------
# MATERIAL → TOOL EFFICIENCY TABLE
# When a tool matches the material's preferred tool, break time is halved
# on top of the normal tier bonus. This is what makes axes fast on Wood
# without you having to write it on every wooden block.
# ---------------------------------------------------------------------------
const MATERIAL_TOOL_BONUS: Dictionary = {
	"Wood":    "Axe",
	"Stone":   "Pickaxe",
	"Metal":   "Pickaxe",
	"Dirt":    "Shovel",
	"Sand":    "Shovel",
	"Leaves":  "Shears",
	"Plant":   "Shears",
}

# ---------------------------------------------------------------------------
# WOOD TYPE AUTO-GENERATION
# Each entry here automatically registers: Log, Leaves, Planks
# You only need to add the PNG files and one line here.
# ---------------------------------------------------------------------------
const WOOD_TYPES: Array[String] = [
	"Oak", "Birch", "Spruce", "Jungle", "Acacia", "Dark Oak"
]

# ---------------------------------------------------------------------------
# BLOCK DEFINITIONS
# ---------------------------------------------------------------------------
const BLOCKS: Dictionary = {

	# -----------------------------------------------------------------------
	# TERRAIN — SOFT
	# -----------------------------------------------------------------------
	"Grass": {
		"hasItem":    true,
		"material":   "Dirt",
		"hardness":   0.6,   "resistance": 0.0,
		"drop":       "Dirt", "stack": 64,
		"tool":       "Shovel", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["natural"],
		"behaviors":  [],
	},
	"Dirt": {
		"hasItem":    true,
		"material":   "Dirt",
		"hardness":   0.5,   "resistance": 0.0,
		"drop":       "Dirt", "stack": 64,
		"tool":       "Shovel", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": true,
		"transparent":false, "luminous": 0,
		"tags":       ["natural"],
		"behaviors":  [],
	},
	"Sand": {
		"hasItem":    true,
		"material":   "Sand",
		"hardness":   0.5,   "resistance": 0.0,
		"drop":       "Sand", "stack": 64,
		"tool":       "Shovel", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": true,
		"transparent":false, "luminous": 0,
		"tags":       ["natural"],
		"behaviors":  ["Falling"],
	},
	"Gravel": {
		"hasItem":    true,
		"material":   "Sand",
		"hardness":   0.5,   "resistance": 0.0,
		"drop":       "Gravel", "stack": 64,
		"tool":       "Shovel", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": true,
		"transparent":false, "luminous": 0,
		"tags":       ["natural"],
		"behaviors":  ["Falling"],
	},

	# -----------------------------------------------------------------------
	# TERRAIN — STONE
	# -----------------------------------------------------------------------
	"Stone": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   1.5,   "resistance": 6.0,
		"drop":       "Cobblestone", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "natural"],
		"behaviors":  [],
	},
	"Diorite": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   1.5,   "resistance": 6.0,
		"drop":       "Diorite", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "natural"],
		"behaviors":  [],
	},
	"Granite": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   1.5,   "resistance": 6.0,
		"drop":       "Granite", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "natural"],
		"behaviors":  [],
	},
	"Andesite": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   1.5,   "resistance": 6.0,
		"drop":       "Andesite", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "natural"],
		"behaviors":  [],
	},
	"Cobblestone": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   2.0,   "resistance": 6.0,
		"drop":       "Cobblestone", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone"],
		"behaviors":  [],
	},

	# -----------------------------------------------------------------------
	# ORES
	# -----------------------------------------------------------------------
	"Coal Ore": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   3.0,   "resistance": 3.0,
		"drop":       {"item": "Coal", "min": 1, "max": 3}, "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "ore", "natural"],
		"behaviors":  [],
	},
	"Iron Ore": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   3.0,   "resistance": 3.0,
		"drop":       "Iron Ore", "stack": 64,
		"tool":       "Pickaxe", "tier": 1,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "ore", "natural"],
		"behaviors":  [],
	},
	"Copper Ore": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   3.0,   "resistance": 3.0,
		"drop":       "Copper Ore", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "ore", "natural"],
		"behaviors":  [],
	},
	"Gold Ore": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   3.0,   "resistance": 3.0,
		"drop":       "Gold Ingot", "stack": 64,
		"tool":       "Pickaxe", "tier": 3,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "ore", "natural"],
		"behaviors":  [],
	},
	"Diamond Ore": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   3.2,   "resistance": 3.2,
		"drop":       "Diamond", "stack": 64,
		"tool":       "Pickaxe", "tier": 4,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "ore", "natural"],
		"behaviors":  [],
	},
	"Titanium Ore": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   3.4,   "resistance": 3.4,
		"drop":       "Titanium Ore", "stack": 64,
		"tool":       "Pickaxe", "tier": 5,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone", "ore", "natural"],
		"behaviors":  [],
	},

	# -----------------------------------------------------------------------
	# PLANTS
	# -----------------------------------------------------------------------
	"Cactus": {
		"hasItem":    true,
		"material":   "Plant",
		"hardness":   0.2,   "resistance": 0.0,
		"drop":       "Cactus", "stack": 64,
		"tool":       "Shears", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"contact_damage": 1,
		"tags":       ["plant", "natural", "flammable"],
		"behaviors":  ["DamageOnTouch"],
	},

	# -----------------------------------------------------------------------
	# LIQUID
	# -----------------------------------------------------------------------
	"Water": {
		"hasItem":    false,
		"material":   "Liquid",
		"hardness":   0.0,   "resistance": 100.0,
		"drop":       "", "stack": 64,
		"tool":       "Hand", "tier": 0,
		"solid":      false, "breakable": false, "replaceable": true,
		"transparent":true,  "luminous": 0,
		"tags":       ["liquid"],
		"behaviors":  ["Fluid"],
		"frames":     32, "anim_fps": 12.0,
	},

	# -----------------------------------------------------------------------
	# UNBREAKABLE
	# -----------------------------------------------------------------------
	"Bedrock": {
		"hasItem":    false,
		"material":   "Unbreakable",
		"hardness":   0.0,   "resistance": 3600000.0,
		"drop":       "", "stack": 64,
		"tool":       "Hand", "tier": 0,
		"solid":      true,  "breakable": false, "replaceable": false,
		"unbreakable":true,
		"transparent":false, "luminous": 0,
		"tags":       [],
		"behaviors":  [],
	},

	# -----------------------------------------------------------------------
	# WORKSTATIONS
	# -----------------------------------------------------------------------
	"Crafting Table": {
		"hasItem":    true,
		"material":   "Wood",
		"hardness":   2.5,   "resistance": 0.0,
		"drop":       "Crafting Table", "stack": 64,
		"tool":       "Axe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["wood", "flammable"],
		"behaviors":  ["CraftingStation"],
	},
	"Furnace": {
		"hasItem":    true,
		"material":   "Stone",
		"hardness":   2.5,   "resistance": 0.0,
		"drop":       "Furnace", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["stone"],
		"behaviors":  ["Furnace", "Container"],
	},
	"Anvil": {
		"hasItem":    true,
		"material":   "Metal",
		"hardness":   4.0,   "resistance": 12.0,
		"drop":       "Anvil", "stack": 64,
		"tool":       "Pickaxe", "tier": 0,
		"solid":      true,  "breakable": true, "replaceable": false,
		"transparent":false, "luminous": 0,
		"tags":       ["metal"],
		"behaviors":  ["Container"],
	},
}

# ---------------------------------------------------------------------------
# WOOD BLOCK TEMPLATES
# Auto-generated from WOOD_TYPES — do not add logs/leaves/planks manually.
# ---------------------------------------------------------------------------
const _LOG_TEMPLATE: Dictionary = {
	"hasItem":    true,
	"material":   "Wood",
	"hardness":   2.0,   "resistance": 0.0,
	"stack":      64,
	"tool":       "Axe", "tier": 0,
	"solid":      true,  "breakable": true, "replaceable": false,
	"transparent":false, "luminous": 0,
	"tags":       ["wood", "log", "natural", "flammable"],
	"behaviors":  [],
}
const _LEAVES_TEMPLATE: Dictionary = {
	"hasItem":    true,
	"material":   "Leaves",
	"hardness":   0.2,   "resistance": 0.0,
	"drop":       {"item": "Stick", "min": 0, "max": 1},
	"stack":      64,
	"tool":       "Shears", "tier": 0,
	"solid":      false, "breakable": true, "replaceable": false,
	"transparent":true,  "luminous": 0,
	"tags":       ["leaves", "foliage", "natural", "flammable"],
	"behaviors":  ["Leaves"],
}
const _PLANKS_TEMPLATE: Dictionary = {
	"hasItem":    true,
	"material":   "Wood",
	"hardness":   2.0,   "resistance": 0.0,
	"stack":      64,
	"tool":       "Axe", "tier": 0,
	"solid":      true,  "breakable": true, "replaceable": false,
	"transparent":false, "luminous": 0,
	"tags":       ["wood", "plank", "flammable"],
	"behaviors":  [],
}

# ---------------------------------------------------------------------------
# RUNTIME DATA  (built at startup — never edit)
# ---------------------------------------------------------------------------
var _all_blocks:     Dictionary = {}   # merged BLOCKS + auto-generated wood
var _name_to_coords: Dictionary = {}
var _coords_to_name: Dictionary = {}
var BLOCKS_BY_COORDS:Dictionary = {}
var _texture_cache:  Dictionary = {}

# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_all_blocks()
	_build_coord_tables()

func _build_all_blocks() -> void:
	# Start with hand-written blocks
	for k in BLOCKS.keys():
		_all_blocks[k] = BLOCKS[k]

	# Auto-generate wood variants
	for wood in WOOD_TYPES:
		var log_name:    String = wood + " Log"
		var leaves_name: String = wood + " Leaves"
		var planks_name: String = wood + " Planks"

		var log: Dictionary = _LOG_TEMPLATE.duplicate(true)
		log["drop"] = log_name
		_all_blocks[log_name] = log

		var leaves: Dictionary = _LEAVES_TEMPLATE.duplicate(true)
		_all_blocks[leaves_name] = leaves

		var planks: Dictionary = _PLANKS_TEMPLATE.duplicate(true)
		planks["drop"] = planks_name
		_all_blocks[planks_name] = planks

func _build_coord_tables() -> void:
	var col: int = 0
	for block_name: String in _all_blocks.keys():
		var coords: Vector2i        = Vector2i(col, 0)
		var frames: int             = max(1, int(_all_blocks[block_name].get("frames", 1)))
		_name_to_coords[block_name] = coords
		_coords_to_name[coords]     = block_name
		BLOCKS_BY_COORDS[coords]    = block_name
		col += frames
	print("BlockRegistry: registered %d blocks." % _all_blocks.size())

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func get_block(block_name: String) -> Dictionary:
	if _all_blocks.has(block_name):
		return _all_blocks[block_name]
	push_warning("BlockRegistry: unknown block '%s', using fallback." % block_name)
	return {
		"material": "Stone", "hardness": 1.0, "resistance": 0.0,
		"drop": block_name, "stack": 64, "tool": "Pickaxe", "tier": 0,
		"solid": true, "breakable": true, "replaceable": false,
		"unbreakable": false, "luminous": 0, "transparent": false,
		"contact_damage": 0, "behaviors": [], "tags": [],
	}

# ---------------------------------------------------------------------------
# BREAK TIME
# Incorporates material bonus: matching tool type gets a 2× speed multiplier
# on top of the normal tier-based bonus.
# ---------------------------------------------------------------------------
func get_break_time(block_name: String, tool_type: String = "", tool_tier: int = 0) -> float:
	var data: Dictionary = get_block(block_name)

	# Truly unbreakable — engine skips mining entirely
	if data.get("unbreakable", false):
		return -1.0

	# breakable:false — also indestructible (Water etc.)
	if not data.get("breakable", true):
		return -1.0

	var base:     float  = data["hardness"] * HARDNESS_MULTIPLIER
	var req_tool: String = data.get("tool", "Hand")
	var req_tier: int    = data.get("tier", 0)

	# No tool required — hand breakable at normal speed
	if req_tool == "Hand":
		return base

	# Wrong tool type — always breakable, just very slow (5× base)
	if tool_type != req_tool:
		return base * 5.0

	# Correct tool type but insufficient tier — breakable, slow (3× base)
	# Drops are suppressed separately by can_harvest()
	if tool_tier < req_tier:
		return base * 3.0

	# Correct tool and tier — apply speed bonuses
	var tier_mult: float = 1.0 + float(tool_tier) * 0.8

	# Material bonus — matching tool gets extra 2× speed
	var mat: String       = data.get("material", "")
	var preferred: String = MATERIAL_TOOL_BONUS.get(mat, "")
	var mat_mult:  float  = 2.0 if (preferred != "" and tool_type == preferred) else 1.0

	return max(base / (tier_mult * mat_mult), 0.05)

# Returns true if the held tool is good enough to actually collect drops.
# Breaking is always allowed — only harvesting requires the correct tier.
func can_harvest(block_name: String, tool_type: String = "", tool_tier: int = 0) -> bool:
	var data: Dictionary = get_block(block_name)
	if data.get("unbreakable", false):
		return false
	if not data.get("breakable", true):
		return false
	var req_tool: String = data.get("tool", "Hand")
	var req_tier: int    = data.get("tier", 0)
	if req_tool == "Hand":
		return true
	if tool_type != req_tool:
		return false
	return tool_tier >= req_tier

# ---------------------------------------------------------------------------
# BEHAVIOR QUERIES
# ---------------------------------------------------------------------------
func has_behavior(block_name: String, behavior: String) -> bool:
	return behavior in get_block(block_name).get("behaviors", [])

func get_behaviors(block_name: String) -> Array:
	return get_block(block_name).get("behaviors", [])

func has_tag(block_name: String, tag: String) -> bool:
	return tag in get_block(block_name).get("tags", [])

func get_tags(block_name: String) -> Array:
	return get_block(block_name).get("tags", [])

# ---------------------------------------------------------------------------
# PROPERTY HELPERS  (all code that used to check "physical", "flammable" etc
# now calls has_behavior or has_tag instead)
# ---------------------------------------------------------------------------
func is_physical(block_name: String) -> bool:
	return has_behavior(block_name, "Falling")

func is_solid(block_name: String) -> bool:
	return get_block(block_name).get("solid", true)

func is_transparent(block_name: String) -> bool:
	return get_block(block_name).get("transparent", false)

func is_flammable(block_name: String) -> bool:
	return has_tag(block_name, "flammable")

func is_unbreakable(block_name: String) -> bool:
	return get_block(block_name).get("unbreakable", false)

func is_breakable(block_name: String) -> bool:
	return get_block(block_name).get("breakable", true)

func is_replaceable(block_name: String) -> bool:
	return get_block(block_name).get("replaceable", false)

func get_material(block_name: String) -> String:
	return get_block(block_name).get("material", "")

func get_luminosity(block_name: String) -> int:
	return get_block(block_name).get("luminous", 0)

func get_contact_damage(block_name: String) -> int:
	return int(get_block(block_name).get("contact_damage", 0))

func get_blast_resistance(block_name: String) -> float:
	return get_block(block_name).get("resistance", 0.0)

func get_stack_size(block_name: String) -> int:
	return get_block(block_name).get("stack", 64)

# ---------------------------------------------------------------------------
# DROP RESOLVER
# ---------------------------------------------------------------------------
func resolve_drops(block_name: String) -> Array:
	return _resolve_drop_entry(get_block(block_name).get("drop", ""))

func _resolve_drop_entry(entry) -> Array:
	var results: Array = []
	if typeof(entry) == TYPE_STRING:
		if (entry as String) != "":
			results.append({"item": entry, "count": 1})
	elif typeof(entry) == TYPE_DICTIONARY:
		var item:  String = entry.get("item", "")
		var min_c: int    = entry.get("min", 1)
		var max_c: int    = entry.get("max", min_c)
		var count: int    = randi_range(min_c, max_c)
		if item != "" and count > 0:
			results.append({"item": item, "count": count})
	elif typeof(entry) == TYPE_ARRAY:
		for sub in entry:
			results.append_array(_resolve_drop_entry(sub))
	return results

# ---------------------------------------------------------------------------
# ATLAS COORD HELPERS
# ---------------------------------------------------------------------------
func get_coords_from_name(block_name: String) -> Vector2i:
	if _name_to_coords.has(block_name):
		return _name_to_coords[block_name]
	push_warning("BlockRegistry: no coords for '%s'." % block_name)
	return Vector2i(-1, -1)

func get_name_from_coords(atlas_coords: Vector2i) -> String:
	return _coords_to_name.get(atlas_coords, "Unknown")

# ---------------------------------------------------------------------------
# TEXTURE LOADER
# ---------------------------------------------------------------------------
func get_texture(block_name: String) -> Texture2D:
	if _texture_cache.has(block_name):
		return _texture_cache[block_name]
	var filename: String = block_name.replace(" ", "_") + ".png"
	var path:     String = TEXTURE_PATH + filename
	if not ResourceLoader.exists(path):
		push_warning("BlockRegistry: texture not found at '%s'." % path)
		_texture_cache[block_name] = null
		return null
	var tex: Texture2D         = load(path) as Texture2D
	_texture_cache[block_name] = tex
	return tex

func has_item(block_name: String) -> bool:
	return get_block(block_name).get("hasItem", true)

# Kept for compatibility with any code that still calls item_has_tag
func item_has_tag(block_name: String, tag: String) -> bool:
	return has_tag(block_name, tag)

# Kept for any code still calling get_drop_name
func get_drop_name(block_name: String) -> String:
	var raw = get_block(block_name).get("drop", "")
	if typeof(raw) == TYPE_STRING:
		return raw as String
	return ""
