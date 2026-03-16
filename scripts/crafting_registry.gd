# ---------------------------------------------------------------------------
# CRAFTING REGISTRY — Autoload singleton
#
# Holds every crafting recipe in the game.
# Supports shaped (pattern matters) and shapeless (any order) recipes.
# Handles both 2x2 (inventory) and 3x3 (crafting table) grids.
#
# ---------------------------------------------------------------------------
# TAG-BASED INGREDIENTS
# ---------------------------------------------------------------------------
# Recipe keys (shaped) and ingredient names (shapeless) can reference item
# TAGS instead of specific item names by prefixing with "#".
#
# Example:
#   "keys": {"X": "#plank"}   ← matches ANY item tagged "plank"
#   "keys": {"X": "#log"}     ← matches ANY item tagged "log"
#
# Tags are defined in ItemRegistry under the "tags" array on each item:
#   "Oak Planks":   { ..., "tags": ["plank", "wood"] }
#   "Birch Planks": { ..., "tags": ["plank", "wood"] }
#
# Adding a new wood type is now just:
#   1. Add the item to ItemRegistry with "tags": ["plank", "wood"]
#   2. Add a shapeless log→planks recipe below
#   Done — all plank recipes (sticks, tools, crafting table, etc.) work for free.
#
# ---------------------------------------------------------------------------
# SHAPED RECIPE FORMAT:
#   {
#     "pattern": ["XXX", "X X", "XXX"],   # rows of the grid, space = empty
#     "keys":    {"X": "#plank"},          # letter → item name OR #tag
#     "result":  "Crafting Table",
#     "count":   1,
#     "grid":    0,   # 0=both, 2=2x2 only, 3=3x3 only
#   }
#
# SHAPELESS RECIPE FORMAT:
#   {
#     "ingredients": {"#log": 1},          # item name OR #tag → required count
#     "result":  "Oak Planks",
#     "count":   4,
#     "grid":    0,
#   }
# ---------------------------------------------------------------------------
extends Node

# ---------------------------------------------------------------------------
# SHAPED RECIPES
# ---------------------------------------------------------------------------
const SHAPED_RECIPES: Array = [

	# -----------------------------------------------------------------------
	# BASIC BLOCKS
	# -----------------------------------------------------------------------
	{
		# Any 4 planks (any wood type) in a 2x2 = Crafting Table
		"pattern": ["XX", "XX"],
		"keys":    {"X": "#plank"},
		"result":  "Crafting Table", "count": 1, "grid": 0,
	},
	{
		# Any 2 planks stacked vertically = 4 Sticks
		"pattern": ["X", "X"],
		"keys":    {"X": "#plank"},
		"result":  "Stick", "count": 4, "grid": 0,
	},
	{
		"pattern": ["XXX", "X X", "XXX"],
		"keys":    {"X": "Cobblestone"},
		"result":  "Furnace", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " X ", "XXX"],
		"keys":    {"X": "Iron Ingot"},
		"result":  "Anvil", "count": 1, "grid": 3,
	},

	# -----------------------------------------------------------------------
	# PICKAXES
	# -----------------------------------------------------------------------
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "#plank", "S": "Stick"},
		"result":  "wooden Pickaxe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "Cobblestone", "S": "Stick"},
		"result":  "Stone Pickaxe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "Copper Ingot", "S": "Stick"},
		"result":  "Copper Pickaxe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "Gold Ingot", "S": "Stick"},
		"result":  "Gold Pickaxe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "Iron Ingot", "S": "Stick"},
		"result":  "Iron Pickaxe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "Diamond", "S": "Stick"},
		"result":  "Diamond Pickaxe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XXX", " S ", " S "],
		"keys":    {"X": "Titanium Ingot", "S": "Stick"},
		"result":  "Titanium Pickaxe", "count": 1, "grid": 3,
	},

	# -----------------------------------------------------------------------
	# AXES
	# -----------------------------------------------------------------------
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "#plank", "S": "Stick"},
		"result":  "wooden Axe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "Cobblestone", "S": "Stick"},
		"result":  "Stone Axe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "Copper Ingot", "S": "Stick"},
		"result":  "Copper Axe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "Gold Ingot", "S": "Stick"},
		"result":  "Gold Axe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "Iron Ingot", "S": "Stick"},
		"result":  "Iron Axe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "Diamond", "S": "Stick"},
		"result":  "Diamond Axe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX", "XS", " S"],
		"keys":    {"X": "Titanium Ingot", "S": "Stick"},
		"result":  "Titanium Axe", "count": 1, "grid": 3,
	},

	# -----------------------------------------------------------------------
	# SHOVELS
	# -----------------------------------------------------------------------
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "#plank", "S": "Stick"},
		"result":  "wooden Shovel", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "Cobblestone", "S": "Stick"},
		"result":  "Stone Shovel", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "Copper Ingot", "S": "Stick"},
		"result":  "Copper Shovel", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "Gold Ingot", "S": "Stick"},
		"result":  "Gold Shovel", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "Iron Ingot", "S": "Stick"},
		"result":  "Iron Shovel", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "Diamond", "S": "Stick"},
		"result":  "Diamond Shovel", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "S", "S"],
		"keys":    {"X": "Titanium Ingot", "S": "Stick"},
		"result":  "Titanium Shovel", "count": 1, "grid": 3,
	},

	# -----------------------------------------------------------------------
	# SWORDS
	# -----------------------------------------------------------------------
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "#plank", "S": "Stick"},
		"result":  "wooden Sword", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "Cobblestone", "S": "Stick"},
		"result":  "Stone Sword", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "Copper Ingot", "S": "Stick"},
		"result":  "Copper Sword", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "Gold Ingot", "S": "Stick"},
		"result":  "Gold Sword", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "Iron Ingot", "S": "Stick"},
		"result":  "Iron Sword", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "Diamond", "S": "Stick"},
		"result":  "Diamond Sword", "count": 1, "grid": 3,
	},
	{
		"pattern": ["X", "X", "S"],
		"keys":    {"X": "Titanium Ingot", "S": "Stick"},
		"result":  "Titanium Sword", "count": 1, "grid": 3,
	},

	# -----------------------------------------------------------------------
	# HOES
	# -----------------------------------------------------------------------
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "#plank", "S": "Stick"},
		"result":  "wooden Hoe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "Cobblestone", "S": "Stick"},
		"result":  "Stone Hoe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "Copper Ingot", "S": "Stick"},
		"result":  "Copper Hoe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "Gold Ingot", "S": "Stick"},
		"result":  "Gold Hoe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "Iron Ingot", "S": "Stick"},
		"result":  "Iron Hoe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "Diamond", "S": "Stick"},
		"result":  "Diamond Hoe", "count": 1, "grid": 3,
	},
	{
		"pattern": ["XX ", " S ", " S "],
		"keys":    {"X": "Titanium Ingot", "S": "Stick"},
		"result":  "Titanium Hoe", "count": 1, "grid": 3,
	},

	# -----------------------------------------------------------------------
	# SHEARS
	# -----------------------------------------------------------------------
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "#plank"},
		"result":  "wooden Shears", "count": 1, "grid": 0,
	},
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "Cobblestone"},
		"result":  "Stone Shears", "count": 1, "grid": 0,
	},
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "Copper Ingot"},
		"result":  "Copper Shears", "count": 1, "grid": 0,
	},
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "Gold Ingot"},
		"result":  "Gold Shears", "count": 1, "grid": 0,
	},
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "Iron Ingot"},
		"result":  "Iron Shears", "count": 1, "grid": 0,
	},
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "Diamond"},
		"result":  "Diamond Shears", "count": 1, "grid": 0,
	},
	{
		"pattern": [" X", "X "],
		"keys":    {"X": "Titanium Ingot"},
		"result":  "Titanium Shears", "count": 1, "grid": 0,
	},
]

# ---------------------------------------------------------------------------
# SHAPELESS RECIPES
# ---------------------------------------------------------------------------
const SHAPELESS_RECIPES: Array = [

	# Each log type → its own planks (specific item, not tag-based)
	# To add a new wood type: add ONE entry here + tag the planks with "plank"
	{
		"ingredients": {"Oak Log": 1},
		"result": "Oak Planks", "count": 4, "grid": 0,
	},
	{
		"ingredients": {"Birch Log": 1},
		"result": "Birch Planks", "count": 4, "grid": 0,
	},
	{
		"ingredients": {"Spruce Log": 1},
		"result": "Spruce Planks", "count": 4, "grid": 0,
	},
	{
		"ingredients": {"Acacia Log": 1},
		"result": "Acacia Planks", "count": 4, "grid": 0,
	},
	{
		"ingredients": {"Jungle Log": 1},
		"result": "Jungle Planks", "count": 4, "grid": 0,
	},
	{
		"ingredients": {"Dark Oak Log": 1},
		"result": "Dark Oak Planks", "count": 4, "grid": 0,
	},
]

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func find_recipe(grid_items: Array, grid_size: int) -> Dictionary:
	var shaped := _match_shaped(grid_items, grid_size)
	if not shaped.is_empty():
		return shaped
	return _match_shapeless(grid_items, grid_size)

func has_recipe(grid_items: Array, grid_size: int) -> bool:
	return not find_recipe(grid_items, grid_size).is_empty()

func get_recipes_using(item_name: String) -> Array[String]:
	var results: Array[String] = []
	for recipe in SHAPED_RECIPES:
		for v in (recipe["keys"] as Dictionary).values():
			var val: String = v as String
			if val.begins_with("#"):
				if ItemRegistry.item_has_tag(item_name, val.substr(1)):
					results.append(recipe["result"])
					break
			elif val == item_name:
				results.append(recipe["result"])
				break
	for recipe in SHAPELESS_RECIPES:
		for ing in (recipe["ingredients"] as Dictionary).keys():
			var ing_str: String = ing as String
			if ing_str.begins_with("#"):
				if ItemRegistry.item_has_tag(item_name, ing_str.substr(1)):
					results.append(recipe["result"])
					break
			elif ing_str == item_name:
				results.append(recipe["result"])
				break
	return results

# ---------------------------------------------------------------------------
# INGREDIENT MATCHING HELPER
# ---------------------------------------------------------------------------
# Returns true if the item in the grid slot satisfies the recipe ingredient.
# ingredient can be:
#   "#tagname"   — item must have that tag
#   "Item Name"  — item must match exactly
# ---------------------------------------------------------------------------
func _ingredient_matches(item: String, ingredient: String) -> bool:
	if item == "":
		return false
	if ingredient.begins_with("#"):
		return ItemRegistry.item_has_tag(item, ingredient.substr(1))
	return item == ingredient

# ---------------------------------------------------------------------------
# SHAPED MATCHING
# ---------------------------------------------------------------------------
func _match_shaped(grid_items: Array, grid_size: int) -> Dictionary:
	var bounds := _get_filled_bounds(grid_items, grid_size)
	if bounds.is_empty():
		return {}

	var content_w: int = bounds["w"]
	var content_h: int = bounds["h"]
	var content: Array = bounds["items"]

	for recipe in SHAPED_RECIPES:
		var req_grid: int = recipe["grid"]
		if req_grid != 0 and req_grid != grid_size:
			continue

		var pattern: Array   = recipe["pattern"]
		var keys: Dictionary = recipe["keys"]
		var pat_h: int       = pattern.size()
		var pat_w: int       = 0
		for row in pattern:
			pat_w = max(pat_w, (row as String).length())

		if pat_w != content_w or pat_h != content_h:
			continue

		# For tag-based keys, all slots that share the same key letter
		# must resolve to the SAME item (can't mix Oak Planks and Birch Planks
		# in the same recipe — consistent within one craft).
		var key_resolved: Dictionary = {}  # letter → resolved item name
		var matched := true

		for r in pat_h:
			if not matched:
				break
			var row_str: String = pattern[r]
			for c in pat_w:
				var pat_char: String = row_str[c] if c < row_str.length() else " "
				var item: String     = content[r * content_w + c]

				if pat_char == " ":
					if item != "":
						matched = false
						break
				else:
					var ingredient: String = keys.get(pat_char, "")
					if not _ingredient_matches(item, ingredient):
						matched = false
						break
					# For tag ingredients: enforce consistency per key letter
					if ingredient.begins_with("#"):
						if key_resolved.has(pat_char):
							if key_resolved[pat_char] != item:
								matched = false
								break
						else:
							key_resolved[pat_char] = item

		if matched:
			return {"result": recipe["result"], "count": recipe["count"]}

	return {}

# ---------------------------------------------------------------------------
# Shrinks the grid down to the tightest bounding box of non-empty cells.
# ---------------------------------------------------------------------------
func _get_filled_bounds(grid_items: Array, grid_size: int) -> Dictionary:
	var min_r := grid_size
	var max_r := -1
	var min_c := grid_size
	var max_c := -1

	for i in grid_items.size():
		if (grid_items[i] as String) == "":
			continue
		var r := i / grid_size
		var c := i % grid_size
		min_r = min(min_r, r)
		max_r = max(max_r, r)
		min_c = min(min_c, c)
		max_c = max(max_c, c)

	if max_r == -1:
		return {}

	var w := max_c - min_c + 1
	var h := max_r - min_r + 1
	var items: Array = []
	for r in range(min_r, max_r + 1):
		for c in range(min_c, max_c + 1):
			items.append(grid_items[r * grid_size + c])

	return {"w": w, "h": h, "items": items}

# ---------------------------------------------------------------------------
# SHAPELESS MATCHING
# ---------------------------------------------------------------------------
func _match_shapeless(grid_items: Array, grid_size: int) -> Dictionary:
	# Tally what's actually in the grid
	var present: Dictionary = {}
	for item in grid_items:
		if (item as String) == "":
			continue
		present[item] = present.get(item, 0) + 1

	if present.is_empty():
		return {}

	for recipe in SHAPELESS_RECIPES:
		var req_grid: int = recipe["grid"]
		if req_grid != 0 and req_grid != grid_size:
			continue

		var ingredients: Dictionary = recipe["ingredients"]

		# For each ingredient requirement, check if the grid satisfies it.
		# Tag ingredients consume items that match the tag.
		var remaining: Dictionary = present.duplicate()
		var matched := true

		for ing in ingredients:
			var ing_str:       String = ing as String
			var needed:        int    = ingredients[ing]
			var found:         int    = 0

			if ing_str.begins_with("#"):
				# Sum up all items in the grid that carry this tag
				for grid_item in remaining:
					if ItemRegistry.item_has_tag(grid_item, ing_str.substr(1)):
						found += remaining[grid_item]
			else:
				found = remaining.get(ing_str, 0)

			if found < needed:
				matched = false
				break

		# Also make sure there are no extra items beyond what the recipe needs
		if matched:
			var total_needed: int = 0
			for ing in ingredients:
				total_needed += ingredients[ing]
			var total_present: int = 0
			for item in present:
				total_present += present[item]
			if total_present != total_needed:
				matched = false

		if matched:
			return {"result": recipe["result"], "count": recipe["count"]}

	return {}
