# ---------------------------------------------------------------------------
# BLOCK REGISTRY — Autoload singleton
#
# HOW TO ADD A NEW BLOCK — only two things needed:
#   1. Add a PNG at res://assets/textures/blocks/<n>.png
#      (spaces → underscores: "Oak Log" → Oak_Log.png)
#   2. Add an entry to BLOCKS below. That's it.
#
# Atlas coords and tilemap lookups are built automatically at startup
# from the order entries appear in BLOCKS.
# Never reorder or remove existing entries — only append new ones at the bottom.
#
# AUTOLOAD SETUP:
#   Project → Project Settings → Autoload
#   Name: "BlockRegistry"
#   Must be listed BEFORE TileSetBuilder in the autoload order.
#
# ---------------------------------------------------------------------------
# PROPERTY REFERENCE
# ---------------------------------------------------------------------------
#
#  "hardness"      float   Controls how long the block takes to break.
#                          Break time (seconds) = hardness * 1.5
#                          Using the correct tool type + tier reduces this.
#
#  "drop"          String | Dictionary | Array
#                          What the block drops when broken.
#
#                          STRING  — drop exactly 1 of that item:
#                            "drop": "Dirt"
#
#                          DICTIONARY — drop a random quantity:
#                            "drop": { "item": "Coal", "min": 1, "max": 3 }
#                            Rolls a random int between min and max (inclusive).
#
#                          ARRAY — multiple independent drops (each entry is
#                          a String or Dictionary as above):
#                            "drop": [
#                              { "item": "Coal",      "min": 1, "max": 3 },
#                              { "item": "Coal Ore",  "min": 0, "max": 1 },
#                            ]
#                          Each entry is resolved independently.
#                          Entries with a resolved count of 0 are skipped.
#
#  "stack"         int     Max stack size in inventory.
#                          0 = unstackable (only 1 per slot).
#
#  "tool"          int|Array
#                          0           = hand-breakable, no tool needed.
#                          ["Type", N] = requires tool of this type at tier N+.
#                          Tool types: "Pickaxe" "Axe" "Shovel" "Shears" "Sword"
#                          Tiers: 1=Wood 2=Stone 3=Copper 4=Iron 5=Diamond
#                          Examples:
#                            0              → bare hand, always obtainable
#                            ["Pickaxe", 0] → any pickaxe, or hand is fine too
#                            ["Axe",     3] → copper axe minimum
#                            ["Shovel",  1] → any shovel minimum
#
#  "blast_resist"  float   Explosion resistance.
#
#  "luminous"      int     Light emitted. 0 = none. 15 = maximum.
#
#  "transparent"   bool    true  = light and visibility pass through.
#
#  "flammable"     bool    true  = fire can destroy this block.
#
#  "physical"      bool    true  = falls when unsupported (sand, gravel).
#
#  "solid"         bool    true  = has collision with entities.
#
#  "contact_damage" int    Damage dealt when touching the block.
#                          0 = no contact damage (default).
#
#  "object_layer"   bool   true = block is placed on / breaks from the Object
#                          layer (z -20) rather than the Main layer (z 0).
#                          Use for workstations, furniture, and other non-terrain
#                          objects that should sit in front of Back Wall tiles
#                          but behind terrain and entities.
#                          Default: false (omitting the key = Main layer).
#
# ---------------------------------------------------------------------------
extends Node

const TEXTURE_PATH: String = "res://assets/textures/blocks/"

# Hardness is multiplied by this to get base break time in seconds.
const HARDNESS_MULTIPLIER: float = 1.5

# ---------------------------------------------------------------------------
# BLOCK DEFINITIONS
# ---------------------------------------------------------------------------
const BLOCKS: Dictionary = {

	# -----------------------------------------------------------------------
	# NATURAL / SOFT
	# -----------------------------------------------------------------------
	"Grass": {
		"hardness":     0.6,
		"drop":         "Dirt",
		"stack":        64,
		"tool":         ["Shovel", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Dirt": {
		"hardness":     0.5,
		"drop":         "Dirt",
		"stack":        64,
		"tool":         ["Shovel", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Sand": {
		"hardness":     0.5,
		"drop":         "Sand",
		"stack":        64,
		"tool":         ["Shovel", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     true,
		"solid":        true,
	},
	"Gravel": {
		"hardness":     0.5,
		"drop":         "Gravel",
		"stack":        64,
		"tool":         ["Shovel", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     true,
		"solid":        true,
	},
	"Water": {
		"hardness":     1000.0,
		"drop":         "Water",
		"stack":        64,
		"tool":         0,
		"blast_resist": 100.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    false,
		"physical":     false,
		"solid":        false,
		"frames":       32,
		"anim_fps":     12.0,
	},
	"Bedrock": {
		"hardness":     99999.0,
		"drop":         "",
		"stack":        64,
		"tool":         ["Pickaxe", 99],
		"blast_resist": 3600000.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},

	# -----------------------------------------------------------------------
	# WOOD / ORGANIC
	# -----------------------------------------------------------------------
	"Oak Log": {
		"hardness":     2.0,
		"drop":         "Oak Log",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Birch Log": {
		"hardness":     2.0,
		"drop":         "Birch Log",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Jungle Log": {
		"hardness":     2.0,
		"drop":         "Jungle Log",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Spruce Log": {
		"hardness":     2.0,
		"drop":         "Spruce Log",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Dark Oak Log": {
		"hardness":     2.0,
		"drop":         "Dark Oak Log",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Acacia Log": {
		"hardness":     2.0,
		"drop":         "Acacia Log",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Oak Leaves": {
		"hardness":     0.2,
		"drop":         {"item": "Stick", "min": 0, "max": 1},
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    true,
		"physical":     false,
		"solid":        false,
	},
	"Jungle Leaves": {
		"hardness":     0.2,
		"drop":         {"item": "Stick", "min": 0, "max": 1},
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    true,
		"physical":     false,
		"solid":        false,
	},
	"Dark Oak Leaves": {
		"hardness":     0.2,
		"drop":         {"item": "Stick", "min": 0, "max": 1},
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    true,
		"physical":     false,
		"solid":        false,
	},
	"Birch Leaves": {
		"hardness":     0.2,
		"drop":         {"item": "Stick", "min": 0, "max": 1},
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    true,
		"physical":     false,
		"solid":        false,
	},
	"Spruce Leaves": {
		"hardness":     0.2,
		"drop":         {"item": "Stick", "min": 0, "max": 1},
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    true,
		"physical":     false,
		"solid":        false,
	},
	"Acacia Leaves": {
		"hardness":     0.2,
		"drop":         {"item": "Stick", "min": 0, "max": 1},
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  true,
		"flammable":    true,
		"physical":     false,
		"solid":        false,
	},
	"Cactus": {
		"hardness":     0.2,
		"drop":         "Cactus",
		"stack":        64,
		"tool":         ["Shears", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
		"contact_damage": 1,
	},

	# -----------------------------------------------------------------------
	# STONE
	# -----------------------------------------------------------------------
	"Stone": {
		"hardness":     1.5,
		"drop":         "Cobblestone",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 6.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Diorite": {
		"hardness":     1.5,
		"drop":         "Diorite",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 6.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Granite": {
		"hardness":     1.5,
		"drop":         "Granite",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 6.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Andesite": {
		"hardness":     1.5,
		"drop":         "Andesite",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 6.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Cobblestone": {
		"hardness":     2.0,
		"drop":         "Cobblestone",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 6.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},

	# -----------------------------------------------------------------------
	# ORES
	# -----------------------------------------------------------------------
	"Coal Ore": {
		"hardness":     3.0,
		# Drops 1-3 Coal when mined
		"drop":         {"item": "Coal", "min": 1, "max": 3},
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 3.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Iron Ore": {
		"hardness":     3.0,
		# Drops the raw ore block (needs smelting)
		"drop":         "Iron Ore",
		"stack":        64,
		"tool":         ["Pickaxe", 2],
		"blast_resist": 3.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Copper Ore": {
		"hardness":     3.0,
		"drop":         "Copper Ore",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 3.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Gold Ore": {
		"hardness":     3.0,
		"drop":         "Gold Ingot",
		"stack":        64,
		"tool":         ["Pickaxe", 2],
		"blast_resist": 3.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Diamond Ore": {
		"hardness":     3.2,
		"drop":         "Diamond",
		"stack":        64,
		"tool":         ["Pickaxe", 4],
		"blast_resist": 3.2,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},
	"Titanium Ore": {
		"hardness":     3.4,
		"drop":         "Titanium Ore",
		"stack":        64,
		"tool":         ["Pickaxe", 4],
		"blast_resist": 3.4,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
	},

	# -----------------------------------------------------------------------
	# CRAFTED BLOCKS
	# -----------------------------------------------------------------------
	"Oak Planks": {
		"hardness":     2.0,
		"drop":         "Oak Planks",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Birch Planks": {
		"hardness":     2.0,
		"drop":         "Birch Planks",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Acacia Planks": {
		"hardness":     2.0,
		"drop":         "Acacia Planks",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Spruce Planks": {
		"hardness":     2.0,
		"drop":         "Spruce Planks",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Dark Oak Planks": {
		"hardness":     2.0,
		"drop":         "Dark Oak Planks",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Jungle Planks": {
		"hardness":     2.0,
		"drop":         "Jungle Planks",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
	},
	"Crafting Table": {
		"hardness":     2.5,
		"drop":         "Crafting Table",
		"stack":        64,
		"tool":         ["Axe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
		"object_layer": true,
	},
	"Furnace": {
		"hardness":     2.5,
		"drop":         "Furnace",
		"stack":        64,
		"tool":         ["Pickaxe", 0],
		"blast_resist": 0.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    true,
		"physical":     false,
		"solid":        true,
		"object_layer": true,
	},
	"Anvil": {
		"hardness":     4.0,
		"drop":         "Anvil",
		"stack":        64,
		"tool":         ["Pickaxe", 1],
		"blast_resist": 12.0,
		"luminous":     0,
		"transparent":  false,
		"flammable":    false,
		"physical":     false,
		"solid":        true,
		"object_layer": true,
	},
}

# ---------------------------------------------------------------------------
# AUTO-GENERATED LOOKUP TABLES  (never edit — built at startup)
# ---------------------------------------------------------------------------
var _name_to_coords: Dictionary  = {}
var _coords_to_name: Dictionary  = {}
var BLOCKS_BY_COORDS: Dictionary = {}
var _texture_cache: Dictionary   = {}

# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_coord_tables()

func _build_coord_tables() -> void:
	var col: int = 0
	for block_name: String in BLOCKS.keys():
		var coords: Vector2i        = Vector2i(col, 0)
		var frames: int             = max(1, int(BLOCKS[block_name].get("frames", 1)))
		_name_to_coords[block_name] = coords
		_coords_to_name[coords]     = block_name
		BLOCKS_BY_COORDS[coords]    = block_name
		col += frames
	print("BlockRegistry: registered %d blocks." % col)

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func get_block(block_name: String) -> Dictionary:
	if BLOCKS.has(block_name):
		return BLOCKS[block_name]
	push_warning("BlockRegistry: unknown block '%s', using fallback." % block_name)
	return {
		"hardness": 1.0, "drop": block_name, "stack": 64,
		"tool": 0, "blast_resist": 0.0, "luminous": 0,
		"transparent": false, "flammable": false,
		"physical": false, "solid": true, "contact_damage": 0,
	}

# ---------------------------------------------------------------------------
# BREAK TIME
# ---------------------------------------------------------------------------
func get_break_time(block_name: String, tool_type: String = "", tool_tier: int = 0) -> float:
	var data: Dictionary = get_block(block_name)
	var base: float      = data["hardness"] * HARDNESS_MULTIPLIER
	var req              = data["tool"]

	if typeof(req) == TYPE_INT:
		return base

	var req_type: String = req[0]
	var req_tier: int    = req[1]

	if tool_type != req_type:
		if req_tier > 0:
			return -1.0
		return base

	if tool_tier < req_tier:
		return -1.0

	var speed_mult: float = 1.0 + float(tool_tier) * 0.8
	return max(base / speed_mult, 0.05)

func can_harvest(block_name: String, tool_type: String = "", tool_tier: int = 0) -> bool:
	return get_break_time(block_name, tool_type, tool_tier) != -1.0

# ---------------------------------------------------------------------------
# DROP RESOLVER
# ---------------------------------------------------------------------------
# Resolves the "drop" field into a flat Array of { "item", "count" } dicts.
# Handles all three formats: String, Dictionary, and Array of either.
# Entries that resolve to count=0 are excluded.
# ---------------------------------------------------------------------------
func resolve_drops(block_name: String) -> Array:
	var raw = get_block(block_name)["drop"]
	return _resolve_drop_entry(raw)

func _resolve_drop_entry(entry) -> Array:
	var results: Array = []

	if typeof(entry) == TYPE_STRING:
		# Simple string — always drop exactly 1
		if (entry as String) != "":
			results.append({"item": entry, "count": 1})

	elif typeof(entry) == TYPE_DICTIONARY:
		# { "item": "...", "min": N, "max": M }
		var item:  String = entry.get("item", "")
		var min_c: int    = entry.get("min", 1)
		var max_c: int    = entry.get("max", min_c)
		var count: int    = randi_range(min_c, max_c)
		if item != "" and count > 0:
			results.append({"item": item, "count": count})

	elif typeof(entry) == TYPE_ARRAY:
		# Array of strings or dicts — resolve each independently
		for sub_entry in entry:
			results.append_array(_resolve_drop_entry(sub_entry))

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
	if _coords_to_name.has(atlas_coords):
		return _coords_to_name[atlas_coords]
	return "Unknown"

func get_break_time_from_coords(atlas_coords: Vector2i) -> float:
	return get_break_time(get_name_from_coords(atlas_coords))

# ---------------------------------------------------------------------------
# TEXTURE LOADER
# ---------------------------------------------------------------------------
func get_texture(block_name: String) -> Texture2D:
	if _texture_cache.has(block_name):
		return _texture_cache[block_name]
	var filename: String = block_name.replace(" ", "_") + ".png"
	var path: String     = TEXTURE_PATH + filename
	if not ResourceLoader.exists(path):
		push_warning("BlockRegistry: texture not found at '%s'." % path)
		_texture_cache[block_name] = null
		return null
	var tex: Texture2D         = load(path) as Texture2D
	_texture_cache[block_name] = tex
	return tex

# ---------------------------------------------------------------------------
# INDIVIDUAL PROPERTY HELPERS
# ---------------------------------------------------------------------------

# Returns the raw drop field (String/Dict/Array) — use resolve_drops() instead
# if you need the actual spawnable items.
func get_drop_name(block_name: String) -> String:
	var raw = get_block(block_name)["drop"]
	if typeof(raw) == TYPE_STRING:
		return raw as String
	# For complex drops return empty — callers should use resolve_drops()
	return ""

func get_stack_size(block_name: String) -> int:
	return get_block(block_name)["stack"]

func get_tool_requirement(block_name: String):
	return get_block(block_name)["tool"]

func get_blast_resistance(block_name: String) -> float:
	return get_block(block_name)["blast_resist"]

func get_luminosity(block_name: String) -> int:
	return get_block(block_name)["luminous"]

func is_transparent(block_name: String) -> bool:
	return get_block(block_name)["transparent"]

func is_flammable(block_name: String) -> bool:
	return get_block(block_name)["flammable"]

func is_physical(block_name: String) -> bool:
	return get_block(block_name)["physical"]

func is_solid(block_name: String) -> bool:
	return get_block(block_name)["solid"]

func get_contact_damage(block_name: String) -> int:
	return int(get_block(block_name).get("contact_damage", 0))

func is_object_layer_block(block_name: String) -> bool:
	return bool(get_block(block_name).get("object_layer", false))