# ---------------------------------------------------------------------------
# ITEM REGISTRY — Autoload singleton
#
# Single source of truth for every item in the game.
# Covers blocks (placeable), materials, and tools.
# BlockRegistry remains the authority for tilemap/world data.
# ItemRegistry is the authority for inventory/crafting data.
#
# AUTOLOAD SETUP:
#   Project → Project Settings → Autoload
#   Name: "ItemRegistry"
#   Order: BlockRegistry → ItemRegistry → TileSetBuilder
#
# HOW TO ADD A NEW ITEM:
#   1. Add a PNG at the correct texture path (see TEXTURE_PATH_* below).
#   2. Add an entry to ITEMS below. That's it.
#   Never reorder or remove existing entries — only append new ones.
#
# ---------------------------------------------------------------------------
# ITEM TYPES
# ---------------------------------------------------------------------------
#   "block"     — placeable tile; must match a name in BlockRegistry
#   "material"  — crafting ingredient, not placeable
#   "tool"      — has tool_type and tool_tier; not stackable
#
# ---------------------------------------------------------------------------
# PROPERTY REFERENCE
# ---------------------------------------------------------------------------
#
#  "type"        String   "block" | "material" | "tool"
#
#  "stack"       int      Max stack size.
#                         0 = unstackable (tools, unique items).
#                         Overrides BlockRegistry stack for blocks.
#
#  "texture"     String   Path to the item's inventory icon PNG.
#                         Blocks reuse their block texture automatically
#                         if this key is absent.
#
#  "tags"        Array    Optional list of tag strings.
#                         Used by CraftingRegistry for tag-based recipes.
#                         Example: ["plank", "wood"] on any plank item.
#                         In recipes, reference a tag with a "#" prefix:
#                           "X": "#plank"  matches any item tagged "plank".
#
#  "tool_type"   String   Only on type="tool".
#                         "Pickaxe" | "Axe" | "Shovel" | "Sword"
#                         | "Hoe" | "Shears"
#
#  "tool_tier"   int      Only on type="tool".
#                         1=Wood 2=Stone 3=Copper 4=Gold 5=Iron
#                         6=Diamond 7=Titanium
#                         Matches the tier values used in BlockRegistry.
#
#  "placeable"   bool     true if placing this item puts a block in the world.
#                         Always true for type="block", always false otherwise.
#
#  "fuel"        float    Seconds of smelting fuel. 0.0 = not a fuel.
#
#  "food"        int      Hunger points restored. 0 = not edible.
#
# ---------------------------------------------------------------------------
extends Node

const TEXTURE_PATH_BLOCKS: String = "res://assets/textures/blocks/"
const TEXTURE_PATH_ITEMS:  String = "res://assets/textures/items/"

# ---------------------------------------------------------------------------
# TIER CONSTANTS  — shared with BlockRegistry tool requirement arrays
# ---------------------------------------------------------------------------
const TIER_WOOD:     int = 1
const TIER_STONE:    int = 2
const TIER_COPPER:   int = 3
const TIER_GOLD:     int = 4
const TIER_IRON:     int = 5
const TIER_DIAMOND:  int = 6
const TIER_TITANIUM: int = 7

# ---------------------------------------------------------------------------
# ITEM DEFINITIONS
# ---------------------------------------------------------------------------
const ITEMS: Dictionary = {
	# -----------------------------------------------------------------------
	# Consumables
	# -----------------------------------------------------------------------
	"Apple": {
		"type": "food", "stack": 64, "placeable": false,
		"fuel": 0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Apple.png",
	},
	# -----------------------------------------------------------------------
	# BLOCKS — placeable tiles (texture pulled from BlockRegistry if absent)
	# -----------------------------------------------------------------------
	"Grass": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Dirt": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Sand": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Stone": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Diorite": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Granite": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Andesite": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Cobblestone": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Oak Log": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["log", "wood"],
	},
	"Oak Leaves": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
		"tags": ["leaves"],
	},
	"Birch Log": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["log", "wood"],
	},
	"Birch Leaves": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
		"tags": ["leaves"],
	},
	"Jungle Log": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["log", "wood"],
	},
	"Jungle Leaves": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
		"tags": ["leaves"],
	},
	"Dark Oak Log": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["log", "wood"],
	},
	"Dark Oak Leaves": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
		"tags": ["leaves"],
	},
	"Spruce Log": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["log", "wood"],
	},
	"Spruce Leaves": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
		"tags": ["leaves"],
	},
	"Acacia Log": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["log", "wood"],
	},
	"Acacia Leaves": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
		"tags": ["leaves"],
	},
	"Cactus": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Coal Ore": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Iron Ore": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Copper Ore": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Gold Ore": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Diamond Ore": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Titanium Ore": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},
	"Crafting Table": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
	},
	"Furnace": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
	},
	"Anvil": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 0.0, "food": 0,
	},

	# -----------------------------------------------------------------------
	# PLANKS — tagged "plank" and "wood" so recipes can use #plank
	# -----------------------------------------------------------------------
	"Oak Planks": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["plank", "wood"],
	},
	"Birch Planks": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["plank", "wood"],
	},
	"Dark Oak Planks": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["plank", "wood"],
	},
	"Spruce Planks": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["plank", "wood"],
	},
	"Acacia Planks": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["plank", "wood"],
	},
	"Jungle Planks": {
		"type": "block", "stack": 64, "placeable": true,
		"fuel": 15.0, "food": 0,
		"tags": ["plank", "wood"],
	},

	# -----------------------------------------------------------------------
	# MATERIALS — crafting ingredients, not placeable
	# -----------------------------------------------------------------------
	"Stick": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 5.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stick.png",
	},
	"Coal": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 80.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Coal.png",
	},
	"Iron Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Ingot.png",
	},
	"Copper Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Ingot.png",
	},
	"Gold Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Ingot.png",
	},
	"Diamond": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond.png",
	},
	"Titanium Ingot": {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Ingot.png",
	},

	# -----------------------------------------------------------------------
	# TOOLS — Pickaxes
	# -----------------------------------------------------------------------
	"wooden Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_WOOD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "wooden_Pickaxe.png",
	},
	"Stone Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_STONE,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stone_Pickaxe.png",
	},
	"Copper Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_COPPER,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Pickaxe.png",
	},
	"Gold Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_GOLD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Pickaxe.png",
	},
	"Iron Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_IRON,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Pickaxe.png",
	},
	"Diamond Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_DIAMOND,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond_Pickaxe.png",
	},
	"Titanium Pickaxe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Pickaxe", "tool_tier": TIER_TITANIUM,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Pickaxe.png",
	},

	# -----------------------------------------------------------------------
	# TOOLS — Axes
	# -----------------------------------------------------------------------
	"wooden Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_WOOD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "wooden_Axe.png",
	},
	"Stone Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_STONE,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stone_Axe.png",
	},
	"Copper Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_COPPER,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Axe.png",
	},
	"Gold Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_GOLD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Axe.png",
	},
	"Iron Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_IRON,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Axe.png",
	},
	"Diamond Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_DIAMOND,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond_Axe.png",
	},
	"Titanium Axe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Axe", "tool_tier": TIER_TITANIUM,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Axe.png",
	},

	# -----------------------------------------------------------------------
	# TOOLS — Shovels
	# -----------------------------------------------------------------------
	"wooden Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_WOOD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "wooden_Shovel.png",
	},
	"Stone Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_STONE,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stone_Shovel.png",
	},
	"Copper Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_COPPER,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Shovel.png",
	},
	"Gold Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_GOLD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Shovel.png",
	},
	"Iron Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_IRON,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Shovel.png",
	},
	"Diamond Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_DIAMOND,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond_Shovel.png",
	},
	"Titanium Shovel": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shovel", "tool_tier": TIER_TITANIUM,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Shovel.png",
	},

	# -----------------------------------------------------------------------
	# TOOLS — Swords
	# -----------------------------------------------------------------------
	"wooden Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_WOOD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "wooden_Sword.png",
	},
	"Stone Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_STONE,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stone_Sword.png",
	},
	"Copper Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_COPPER,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Sword.png",
	},
	"Gold Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_GOLD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Sword.png",
	},
	"Iron Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_IRON,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Sword.png",
	},
	"Diamond Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_DIAMOND,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond_Sword.png",
	},
	"Titanium Sword": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Sword", "tool_tier": TIER_TITANIUM,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Sword.png",
	},

	# -----------------------------------------------------------------------
	# TOOLS — Hoes
	# -----------------------------------------------------------------------
	"wooden Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_WOOD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "wooden_Hoe.png",
	},
	"Stone Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_STONE,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stone_Hoe.png",
	},
	"Copper Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_COPPER,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Hoe.png",
	},
	"Gold Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_GOLD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Hoe.png",
	},
	"Iron Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_IRON,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Hoe.png",
	},
	"Diamond Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_DIAMOND,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond_Hoe.png",
	},
	"Titanium Hoe": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Hoe", "tool_tier": TIER_TITANIUM,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Hoe.png",
	},

	# -----------------------------------------------------------------------
	# TOOLS — Shears
	# -----------------------------------------------------------------------
	"wooden Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_WOOD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "wooden_Shears.png",
	},
	"Stone Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_STONE,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Stone_Shears.png",
	},
	"Copper Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_COPPER,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Copper_Shears.png",
	},
	"Gold Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_GOLD,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Gold_Shears.png",
	},
	"Iron Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_IRON,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Iron_Shears.png",
	},
	"Diamond Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_DIAMOND,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Diamond_Shears.png",
	},
	"Titanium Shears": {
		"type": "tool", "stack": 0, "placeable": false,
		"tool_type": "Shears", "tool_tier": TIER_TITANIUM,
		"fuel": 0.0, "food": 0,
		"texture": TEXTURE_PATH_ITEMS + "Titanium_Shears.png",
	},
}

# ---------------------------------------------------------------------------
# TEXTURE CACHE
# ---------------------------------------------------------------------------
var _texture_cache: Dictionary = {}

# ---------------------------------------------------------------------------
func _ready() -> void:
	print("ItemRegistry: %d items registered." % ITEMS.size())

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

func get_item(item_name: String) -> Dictionary:
	if ITEMS.has(item_name):
		return ITEMS[item_name]
	push_warning("ItemRegistry: unknown item '%s', using fallback." % item_name)
	return {
		"type": "material", "stack": 64, "placeable": false,
		"fuel": 0.0, "food": 0,
	}

func has_item(item_name: String) -> bool:
	return ITEMS.has(item_name)

# ---------------------------------------------------------------------------
# TAG HELPERS
# ---------------------------------------------------------------------------

# Returns the tags array for an item, or [] if none.
func get_tags(item_name: String) -> Array:
	return get_item(item_name).get("tags", [])

# Returns true if the item has the given tag.
func item_has_tag(item_name: String, tag: String) -> bool:
	return tag in get_tags(item_name)

# Returns every item name that carries a given tag.
func get_all_with_tag(tag: String) -> Array[String]:
	var result: Array[String] = []
	for iname in ITEMS.keys():
		if tag in ITEMS[iname].get("tags", []):
			result.append(iname)
	return result

# ---------------------------------------------------------------------------
# PROPERTY HELPERS
# ---------------------------------------------------------------------------

func get_stack_size(item_name: String) -> int:
	return get_item(item_name)["stack"]

func is_placeable(item_name: String) -> bool:
	return get_item(item_name)["placeable"]

func get_type(item_name: String) -> String:
	return get_item(item_name)["type"]

func is_tool(item_name: String) -> bool:
	return get_item(item_name)["type"] == "tool"

func get_tool_type(item_name: String) -> String:
	var data := get_item(item_name)
	return data.get("tool_type", "")

func get_tool_tier(item_name: String) -> int:
	var data := get_item(item_name)
	return data.get("tool_tier", 0)

func get_fuel_time(item_name: String) -> float:
	return get_item(item_name)["fuel"]

func get_food_value(item_name: String) -> int:
	return get_item(item_name)["food"]

# ---------------------------------------------------------------------------
# TEXTURE LOADER
# Blocks fall back to BlockRegistry textures automatically.
# ---------------------------------------------------------------------------
func get_texture(item_name: String) -> Texture2D:
	if _texture_cache.has(item_name):
		var cached: Texture2D = _texture_cache[item_name]
		if cached != null:
			return cached

	var data := get_item(item_name)

	if data.has("texture"):
		var path: String = data["texture"]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			_texture_cache[item_name] = tex
			return tex
		push_warning("ItemRegistry: texture not found at '%s'." % path)

	# Fallback for item/material/tool textures when explicit path casing
	# or naming does not match the actual file on disk.
	var inferred_item_path: String = TEXTURE_PATH_ITEMS + item_name.to_lower().replace(" ", "_") + ".png"
	if ResourceLoader.exists(inferred_item_path):
		var inferred_tex := load(inferred_item_path) as Texture2D
		_texture_cache[item_name] = inferred_tex
		return inferred_tex

	var gold_alias_path: String = inferred_item_path.replace("/gold_", "/golden_")
	if gold_alias_path != inferred_item_path and ResourceLoader.exists(gold_alias_path):
		var gold_alias_tex := load(gold_alias_path) as Texture2D
		_texture_cache[item_name] = gold_alias_tex
		return gold_alias_tex

	if data["type"] == "block":
		var tex: Texture2D = BlockRegistry.get_texture(item_name)
		_texture_cache[item_name] = tex
		return tex

	push_warning("ItemRegistry: no texture for '%s'." % item_name)
	_texture_cache[item_name] = null
	return null

# ---------------------------------------------------------------------------
# CONVENIENCE
# ---------------------------------------------------------------------------
func get_all_of_type(item_type: String) -> Array[String]:
	var result: Array[String] = []
	for iname in ITEMS.keys():
		if ITEMS[iname]["type"] == item_type:
			result.append(iname)
	return result

func get_all_tools_of_type(tool_type: String) -> Array[String]:
	var result: Array[String] = []
	for iname in ITEMS.keys():
		var data: Dictionary = ITEMS[iname]
		if data["type"] == "tool" and data.get("tool_type", "") == tool_type:
			result.append(iname)
	return result