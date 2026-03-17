# ---------------------------------------------------------------------------
# ITEM REGISTRY — Autoload singleton
#
# AUTOLOAD ORDER: BlockRegistry → ItemRegistry → TileSetBuilder
#
# ---------------------------------------------------------------------------
# BUILD ORDER  (runs in _ready, in this exact sequence)
# ---------------------------------------------------------------------------
#   1. RegisterManualItems   — food, ingots, materials, unique items
#   2. RegisterGeneratedTools — all tool types × all tiers (auto-generated)
#   3. RegisterWoodBlocks    — log / leaves / planks for each wood type
#   4. RegisterBlockItems    — every BlockRegistry block with hasItem:true
#   5. BuildLookupTables     — tag index, type index
#   6. ValidateRegistry      — catch duplicates, missing links, bad data
#
# ---------------------------------------------------------------------------
# HOW TO ADD THINGS
# ---------------------------------------------------------------------------
#
#  New food / material / unique item:
#    → Add a manual entry to ITEMS below.
#
#  New tool type (e.g. "Bow"):
#    → Add one entry to TOOL_TYPES. All 7 tiers auto-generate.
#
#  New tool tier (e.g. "Mithril"):
#    → Add one entry to TOOL_TIERS. All tool types get that tier.
#
#  New wood variant:
#    → Add the name to BlockRegistry.WOOD_TYPES. Done here automatically.
#
#  New placeable block:
#    → Add it to BlockRegistry with hasItem:true. Done here automatically.
#
#  Block item needing custom fuel / tags:
#    → Add a small entry to BLOCK_OVERRIDES below.
#
# ---------------------------------------------------------------------------
extends Node

const TEXTURE_PATH_BLOCKS: String = "res://assets/textures/blocks/"
const TEXTURE_PATH_ITEMS:  String = "res://assets/textures/items/"

# ---------------------------------------------------------------------------
# TIER CONSTANTS
# Index into TOOL_TIERS. Must match BlockRegistry "tier" values exactly.
# ---------------------------------------------------------------------------
const TIER_WOOD:     int = 0
const TIER_STONE:    int = 1
const TIER_COPPER:   int = 2
const TIER_GOLD:     int = 3
const TIER_IRON:     int = 4
const TIER_DIAMOND:  int = 5
const TIER_TITANIUM: int = 6

# ---------------------------------------------------------------------------
# TOOL STAT TABLES
# One entry per tier (index matches TIER_* constants above).
# Durability, speed multiplier, and base damage live here — never per-item.
# ---------------------------------------------------------------------------
const TIER_DURABILITY: Array[int]   = [ 60, 120, 200, 40, 250, 1561, 2000 ]
const TIER_SPEED:      Array[float] = [ 1.0, 2.0, 3.0, 2.5, 4.0,  6.0,  8.0  ]
const TIER_DAMAGE:     Array[int]   = [ 1,   2,   3,   2,   4,    5,    6    ]

# ---------------------------------------------------------------------------
# TOOL AUTO-GENERATION TABLES
# ---------------------------------------------------------------------------
const TOOL_TYPES: Array = [
	{ "type": "Pickaxe", "tags": ["tool", "pickaxe"] },
	{ "type": "Axe",     "tags": ["tool", "axe"]     },
	{ "type": "Shovel",  "tags": ["tool", "shovel"]  },
	{ "type": "Sword",   "tags": ["tool", "sword"]   },
	{ "type": "Hoe",     "tags": ["tool", "hoe"]     },
	{ "type": "Shears",  "tags": ["tool", "shears"]  },
]

# Name prefix used in item names ("wooden Axe", "Stone Axe", etc.)
const TOOL_TIERS: Array = [
	{ "name": "wooden",   "tier": TIER_WOOD     },
	{ "name": "Stone",    "tier": TIER_STONE    },
	{ "name": "Copper",   "tier": TIER_COPPER   },
	{ "name": "Gold",     "tier": TIER_GOLD     },
	{ "name": "Iron",     "tier": TIER_IRON     },
	{ "name": "Diamond",  "tier": TIER_DIAMOND  },
	{ "name": "Titanium", "tier": TIER_TITANIUM },
]

# ---------------------------------------------------------------------------
# BLOCK ITEM OVERRIDES
# Auto-registered block items have stack=64, placeable=true, fuel=0, food=0.
# Add an entry here ONLY to override fuel, food, or tags.
# Never copy hardness / physics / tool data — those stay in BlockRegistry.
# ---------------------------------------------------------------------------
const BLOCK_OVERRIDES: Dictionary = {
	"Oak Log":         { "fuel": 15.0, "tags": ["log", "wood"]   },
	"Birch Log":       { "fuel": 15.0, "tags": ["log", "wood"]   },
	"Spruce Log":      { "fuel": 15.0, "tags": ["log", "wood"]   },
	"Jungle Log":      { "fuel": 15.0, "tags": ["log", "wood"]   },
	"Acacia Log":      { "fuel": 15.0, "tags": ["log", "wood"]   },
	"Dark Oak Log":    { "fuel": 15.0, "tags": ["log", "wood"]   },
	"Oak Planks":      { "fuel": 15.0, "tags": ["plank", "wood"] },
	"Birch Planks":    { "fuel": 15.0, "tags": ["plank", "wood"] },
	"Spruce Planks":   { "fuel": 15.0, "tags": ["plank", "wood"] },
	"Jungle Planks":   { "fuel": 15.0, "tags": ["plank", "wood"] },
	"Acacia Planks":   { "fuel": 15.0, "tags": ["plank", "wood"] },
	"Dark Oak Planks": { "fuel": 15.0, "tags": ["plank", "wood"] },
	"Oak Leaves":      { "tags": ["leaves"] },
	"Birch Leaves":    { "tags": ["leaves"] },
	"Spruce Leaves":   { "tags": ["leaves"] },
	"Jungle Leaves":   { "tags": ["leaves"] },
	"Acacia Leaves":   { "tags": ["leaves"] },
	"Dark Oak Leaves": { "tags": ["leaves"] },
	"Crafting Table":  { "fuel": 15.0 },
	"Furnace":         { "fuel": 15.0 },
}

# ---------------------------------------------------------------------------
# MANUAL ITEM DEFINITIONS
# Only items that are NOT blocks and NOT auto-generated tools.
# ---------------------------------------------------------------------------
const ITEMS: Dictionary = {

	# -----------------------------------------------------------------------
	# FOOD
	# -----------------------------------------------------------------------
	"Raw Beef": {
		"type": "food", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 3,
		"tags": ["food", "meat"],
		"texture": TEXTURE_PATH_ITEMS + "Raw_Beef.png",
	},
	"Cooked Beef": {
		"type": "food", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 8,
		"tags": ["food", "meat"],
		"texture": TEXTURE_PATH_ITEMS + "Cooked_Beef.png",
	},
	"Leather": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"tags": ["material", "leather"],
		"texture": TEXTURE_PATH_ITEMS + "Leather.png",
	},
	"Apple": {
		"type": "food", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 4,
		"tags": ["food"],
		"texture": TEXTURE_PATH_ITEMS + "Apple.png",
	},

	# -----------------------------------------------------------------------
	# MATERIALS
	# -----------------------------------------------------------------------
	"Stick": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 5.0, "food": 0,
		"tags": ["material"],
		"texture": TEXTURE_PATH_ITEMS + "Stick.png",
	},
	"Coal": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 80.0, "food": 0,
		"tags": ["material", "fuel"],
		"texture": TEXTURE_PATH_ITEMS + "Coal.png",
	},
	"Iron Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"tags": ["material", "metal", "ingot"],
		"texture": TEXTURE_PATH_ITEMS + "Iron_Ingot.png",
	},
	"Copper Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"tags": ["material", "metal", "ingot"],
		"texture": TEXTURE_PATH_ITEMS + "Copper_Ingot.png",
	},
	"Gold Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"tags": ["material", "metal", "ingot"],
		"texture": TEXTURE_PATH_ITEMS + "Gold_Ingot.png",
	},
	"Diamond": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"tags": ["material", "gem"],
		"texture": TEXTURE_PATH_ITEMS + "Diamond.png",
	},
	"Titanium Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"tags": ["material", "metal", "ingot"],
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Ingot.png",
	},
}

# ---------------------------------------------------------------------------
# RUNTIME DATA
# ---------------------------------------------------------------------------
var _all_items:      Dictionary = {}
var _tag_index:      Dictionary = {}   # tag -> Array[String] item names
var _type_index:     Dictionary = {}   # type -> Array[String] item names
var _texture_cache:  Dictionary = {}

# ---------------------------------------------------------------------------
# PHASE 1–6 BUILD SEQUENCE
# ---------------------------------------------------------------------------
func _ready() -> void:
	_register_manual_items()
	_register_generated_tools()
	_register_wood_blocks()
	_register_block_items()
	_build_lookup_tables()
	_validate_registry()
	print("ItemRegistry: %d items registered." % _all_items.size())

# ---------------------------------------------------------------------------
# PHASE 1 — Manual items (food, materials, unique items)
# ---------------------------------------------------------------------------
func _register_manual_items() -> void:
	for iname in ITEMS.keys():
		_all_items[iname] = ITEMS[iname]

# ---------------------------------------------------------------------------
# PHASE 2 — Generated tools
# ---------------------------------------------------------------------------
func _register_generated_tools() -> void:
	for tool_def in TOOL_TYPES:
		var tool_type: String = tool_def["type"]
		var base_tags: Array  = tool_def["tags"]
		for tier_def in TOOL_TIERS:
			var prefix:    String = tier_def["name"]
			var tier_idx:  int    = tier_def["tier"]
			var item_name: String = prefix + " " + tool_type
			var tags: Array = base_tags.duplicate()
			tags.append(prefix.to_lower())
			_all_items[item_name] = {
				"type":       "tool",
				"stack":      0,
				"placeable":  false,
				"fuel":       0.0,
				"food":       0,
				"tool_type":  tool_type,
				"tool_tier":  tier_idx,
				"durability": TIER_DURABILITY[tier_idx],
				"speed":      TIER_SPEED[tier_idx],
				"damage":     TIER_DAMAGE[tier_idx],
				"tags":       tags,
			}

# ---------------------------------------------------------------------------
# PHASE 3 — Wood block items
# BlockRegistry owns wood names — ItemRegistry just mirrors them.
# ---------------------------------------------------------------------------
func _register_wood_blocks() -> void:
	for wood in BlockRegistry.WOOD_TYPES:
		var log_name:    String = wood + " Log"
		var leaves_name: String = wood + " Leaves"
		var planks_name: String = wood + " Planks"
		for item_name in [log_name, leaves_name, planks_name]:
			var override: Dictionary = BLOCK_OVERRIDES.get(item_name, {})
			_all_items[item_name] = {
				"type":      "block",
				"stack":     64,
				"placeable": true,
				"fuel":      override.get("fuel", 0.0),
				"food":      0,
				"tags":      override.get("tags", []),
			}

# ---------------------------------------------------------------------------
# PHASE 4 — All other block items
# Scans BlockRegistry for blocks with hasItem:true, skips wood
# (already registered in phase 3) and skips duplicates.
# ---------------------------------------------------------------------------
func _register_block_items() -> void:
	# Build a set of wood block names to skip (already done in phase 3)
	var wood_names: Dictionary = {}
	for wood in BlockRegistry.WOOD_TYPES:
		wood_names[wood + " Log"]    = true
		wood_names[wood + " Leaves"] = true
		wood_names[wood + " Planks"] = true

	for block_name in BlockRegistry._all_blocks.keys():
		if wood_names.has(block_name):
			continue
		if not BlockRegistry.has_item(block_name):
			continue
		if _all_items.has(block_name):
			continue   # manual item overrides block item
		var override: Dictionary = BLOCK_OVERRIDES.get(block_name, {})
		_all_items[block_name] = {
			"type":      "block",
			"stack":     BlockRegistry.get_stack_size(block_name),
			"placeable": true,
			"fuel":      override.get("fuel", 0.0),
			"food":      0,
			"tags":      override.get("tags", []),
		}

# ---------------------------------------------------------------------------
# PHASE 5 — Build lookup tables
# ---------------------------------------------------------------------------
func _build_lookup_tables() -> void:
	_tag_index.clear()
	_type_index.clear()
	for iname in _all_items.keys():
		var d: Dictionary = _all_items[iname]
		# Type index
		var itype: String = d.get("type", "material")
		if not _type_index.has(itype):
			_type_index[itype] = []
		_type_index[itype].append(iname)
		# Tag index
		for tag in d.get("tags", []):
			if not _tag_index.has(tag):
				_tag_index[tag] = []
			_tag_index[tag].append(iname)

# ---------------------------------------------------------------------------
# PHASE 6 — Validate registry
# ---------------------------------------------------------------------------
func _validate_registry() -> void:
	var errors: int = 0

	for iname in _all_items.keys():
		var d: Dictionary = _all_items[iname]
		var itype: String = d.get("type", "")

		# Missing type
		if itype == "":
			push_warning("ItemRegistry [VALIDATE]: '%s' has no type." % iname)
			errors += 1
			continue

		# Block items must have a matching block
		if itype == "block" and not BlockRegistry._all_blocks.has(iname):
			push_warning("ItemRegistry [VALIDATE]: block item '%s' has no matching BlockRegistry entry." % iname)
			errors += 1

		# Tools must have valid tier
		if itype == "tool":
			var tier: int = d.get("tool_tier", -1)
			if tier < 0 or tier >= TOOL_TIERS.size():
				push_warning("ItemRegistry [VALIDATE]: tool '%s' has invalid tier %d." % [iname, tier])
				errors += 1
			var tool_type: String = d.get("tool_type", "")
			var valid_types: Array = TOOL_TYPES.map(func(t): return t["type"])
			if tool_type not in valid_types:
				push_warning("ItemRegistry [VALIDATE]: tool '%s' has unknown tool_type '%s'." % [iname, tool_type])
				errors += 1

	if errors == 0:
		print("ItemRegistry [VALIDATE]: all %d items passed." % _all_items.size())
	else:
		push_warning("ItemRegistry [VALIDATE]: %d error(s) found." % errors)

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func get_item(item_name: String) -> Dictionary:
	if _all_items.has(item_name):
		return _all_items[item_name]
	push_warning("ItemRegistry: unknown item '%s', using fallback." % item_name)
	return {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0, "tags": [],
	}

func has_item(item_name: String) -> bool:
	return _all_items.has(item_name)

# ---------------------------------------------------------------------------
# TAG HELPERS  (use pre-built index for O(1) lookups)
# ---------------------------------------------------------------------------
func get_tags(item_name: String) -> Array:
	return get_item(item_name).get("tags", [])

func item_has_tag(item_name: String, tag: String) -> bool:
	return tag in get_tags(item_name)

func get_all_with_tag(tag: String) -> Array:
	return _tag_index.get(tag, [])

# ---------------------------------------------------------------------------
# PROPERTY HELPERS
# ---------------------------------------------------------------------------
func get_stack_size(item_name: String) -> int:
	return get_item(item_name).get("stack", 64)

func is_placeable(item_name: String) -> bool:
	return get_item(item_name).get("placeable", false)

func get_type(item_name: String) -> String:
	return get_item(item_name).get("type", "material")

func is_tool(item_name: String) -> bool:
	return get_item(item_name).get("type", "") == "tool"

func is_food(item_name: String) -> bool:
	return get_item(item_name).get("type", "") == "food"

func get_tool_type(item_name: String) -> String:
	return get_item(item_name).get("tool_type", "")

func get_tool_tier(item_name: String) -> int:
	return get_item(item_name).get("tool_tier", 0)

func get_tool_durability(item_name: String) -> int:
	return get_item(item_name).get("durability", 0)

func get_tool_speed(item_name: String) -> float:
	return get_item(item_name).get("speed", 1.0)

func get_tool_damage(item_name: String) -> int:
	return get_item(item_name).get("damage", 1)

func get_fuel_time(item_name: String) -> float:
	return get_item(item_name).get("fuel", 0.0)

func get_food_value(item_name: String) -> int:
	return get_item(item_name).get("food", 0)

# ---------------------------------------------------------------------------
# CONVENIENCE QUERIES  (use pre-built type index for O(1) lookups)
# ---------------------------------------------------------------------------
func get_all_of_type(item_type: String) -> Array:
	return _type_index.get(item_type, [])

func get_all_tools_of_type(tool_type: String) -> Array[String]:
	var result: Array[String] = []
	for iname in get_all_of_type("tool"):
		if _all_items[iname].get("tool_type", "") == tool_type:
			result.append(iname)
	return result

# ---------------------------------------------------------------------------
# TEXTURE LOADER
# Resolution order:
#   1. Explicit "texture" field
#   2. TEXTURE_PATH_ITEMS + snake_case_name.png
#   3. Gold alias (gold_ → golden_)
#   4. BlockRegistry texture (for block-type items)
# ---------------------------------------------------------------------------
func get_texture(item_name: String) -> Texture2D:
	if _texture_cache.has(item_name):
		var cached: Texture2D = _texture_cache[item_name]
		if cached != null:
			return cached

	var data: Dictionary = get_item(item_name)

	if data.has("texture"):
		var path: String = data["texture"]
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path) as Texture2D
			_texture_cache[item_name] = tex
			return tex
		push_warning("ItemRegistry: texture not found at '%s'." % path)

	var inferred: String = TEXTURE_PATH_ITEMS + item_name.to_lower().replace(" ", "_") + ".png"
	if ResourceLoader.exists(inferred):
		var tex: Texture2D = load(inferred) as Texture2D
		_texture_cache[item_name] = tex
		return tex

	var gold_alias: String = inferred.replace("/gold_", "/golden_")
	if gold_alias != inferred and ResourceLoader.exists(gold_alias):
		var tex: Texture2D = load(gold_alias) as Texture2D
		_texture_cache[item_name] = tex
		return tex

	if data.get("type", "") == "block":
		var tex: Texture2D = BlockRegistry.get_texture(item_name)
		_texture_cache[item_name] = tex
		return tex

	push_warning("ItemRegistry: no texture for '%s'." % item_name)
	_texture_cache[item_name] = null
	return null