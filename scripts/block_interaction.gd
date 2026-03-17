extends Node

# ---------------------------------------------------------------------------
# BLOCK INTERACTION
# Attach as a child of your Player node.
# Handles: breaking (LMB), placing (RMB), interacting (E), reach limiting.
#
# Group names expected:
#   layer_main      — foreground tilemap (collision)
#   layer_object    — objects layer (tree trunks, workstations)
#   layer_back_wall — interactive wall layer
# ---------------------------------------------------------------------------

@export var reach:                   float       = 160.0
@export var block_size:              int         = 32
@export var drop_scene:              PackedScene
@export var break_effect_scene:      PackedScene
@export var tree_fell_enabled:       bool        = true
@export var tree_fell_max_blocks:    int         = 180
@export var break_indicator_texture: Texture2D

@export var crafting_table_ui: Node
@export var furnace_ui:        Node
@export var anvil_ui:          Node

# ---------------------------------------------------------------------------
# Behavior → UI variable name mapping.
# Blocks with these behaviors open the corresponding UI on interact.
# ---------------------------------------------------------------------------
const BEHAVIOR_UI: Dictionary = {
	"CraftingStation": "crafting_table_ui",
	"Furnace":         "furnace_ui",
	"Container":       "anvil_ui",
}

# ---------------------------------------------------------------------------
var _main:     TileMapLayer = null
var _object:   TileMapLayer = null
var _wall:     TileMapLayer = null

# Cached array — built once, never rebuilt per frame
var _all_layers: Array[TileMapLayer] = []

var _break_timer:    float        = 0.0
var _breaking_cell:  Vector2i     = Vector2i(-9999, -9999)
var _breaking_layer: TileMapLayer = null
var _indicator:      Sprite2D     = null

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

# ---------------------------------------------------------------------------
func _ready() -> void:
	_main   = get_tree().get_first_node_in_group("layer_main")       as TileMapLayer
	_object = get_tree().get_first_node_in_group("layer_object")     as TileMapLayer
	_wall   = get_tree().get_first_node_in_group("layer_back_wall")  as TileMapLayer

	if _main == null:
		push_error("BlockInteraction: 'layer_main' group not found.")
		return

	# Build cached layer array once
	if _main   != null: _all_layers.append(_main)
	if _object != null: _all_layers.append(_object)
	if _wall   != null: _all_layers.append(_wall)

# ---------------------------------------------------------------------------
func _get_layer_at(cell: Vector2i) -> TileMapLayer:
	for layer in _all_layers:
		if layer.get_cell_source_id(cell) != -1:
			return layer
	return null

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _main == null:
		return

	var cam:         Camera2D = get_viewport().get_camera_2d() as Camera2D
	var mouse_world: Vector2  = cam.get_global_mouse_position() if cam != null \
								else player.get_global_mouse_position()

	if player.global_position.distance_to(mouse_world) > reach:
		_reset_break()
		return

	var hovered_cell: Vector2i = _main.local_to_map(_main.to_local(mouse_world))

	# --- Breaking (hold LMB) ---
	if Input.is_action_pressed("break_block"):
		if player.visual.has_method("set_mining"):
			player.visual.set_mining(true)

		if hovered_cell != _breaking_cell:
			_break_timer    = 0.0
			_breaking_cell  = hovered_cell
			_breaking_layer = _get_layer_at(hovered_cell)
			_remove_indicator()

		if _breaking_layer != null:
			var tile_data: TileData = _breaking_layer.get_cell_tile_data(hovered_cell)
			if tile_data != null:
				var atlas:      Vector2i = _breaking_layer.get_cell_atlas_coords(hovered_cell)
				var block_name: String   = BlockRegistry.get_name_from_coords(atlas)

				# Truly unbreakable — skip entirely (Bedrock)
				if BlockRegistry.is_unbreakable(block_name):
					_break_timer = 0.0
					_remove_indicator()
					return

				var held:      Dictionary = Inventory.get_selected_item()
				var tool_type: String     = ""
				var tool_tier: int        = 0
				if not held.is_empty() and ItemRegistry.is_tool(held["item_name"]):
					tool_type = ItemRegistry.get_tool_type(held["item_name"])
					tool_tier = ItemRegistry.get_tool_tier(held["item_name"])

				var required: float = BlockRegistry.get_break_time(block_name, tool_type, tool_tier)
				# get_break_time only returns -1 for truly unbreakable blocks (already
				# caught above). All other blocks always have a valid break time.
				if required < 0.0:
					_break_timer = 0.0
					_remove_indicator()
					return

				_break_timer += delta
				var progress: float = clamp(_break_timer / required, 0.0, 1.0)
				_update_indicator(hovered_cell, progress)

				if _break_timer >= required:
					_break_block(hovered_cell, _breaking_layer)
					_reset_break()
	else:
		_reset_break()
		if player.visual.has_method("set_mining"):
			player.visual.set_mining(false)

	# --- Interact (E) ---
	if Input.is_action_just_pressed("interact"):
		_try_interact(hovered_cell)

	# --- Placing (RMB) ---
	if Input.is_action_just_pressed("place_block"):
		_place_block(hovered_cell)
		if player.visual.has_method("set_placing"):
			player.visual.set_placing()

# ---------------------------------------------------------------------------
# BREAK INDICATOR
# ---------------------------------------------------------------------------
func _update_indicator(cell: Vector2i, progress: float) -> void:
	if break_indicator_texture == null:
		return
	if _indicator == null:
		_indicator          = Sprite2D.new()
		_indicator.texture  = break_indicator_texture
		_indicator.hframes  = 10
		_indicator.vframes  = 1
		_indicator.centered = true
		_indicator.z_index  = 10
		get_tree().current_scene.add_child(_indicator)
	_indicator.global_position = _main.to_global(_main.map_to_local(cell))
	_indicator.frame = min(int(progress * 10.0), 9)

func _remove_indicator() -> void:
	if _indicator != null:
		_indicator.queue_free()
		_indicator = null

# ---------------------------------------------------------------------------
# INTERACT
# Uses behavior system: opens the UI mapped to the block's first matching behavior.
# ---------------------------------------------------------------------------
func _try_interact(cell: Vector2i) -> void:
	var layer: TileMapLayer = _get_layer_at(cell)
	if layer == null:
		return

	var atlas:      Vector2i = layer.get_cell_atlas_coords(cell)
	var block_name: String   = BlockRegistry.get_name_from_coords(atlas)
	var behaviors:  Array    = BlockRegistry.get_behaviors(block_name)

	var block_world_pos: Vector2 = _main.to_global(_main.map_to_local(cell))

	for behavior in behaviors:
		if not BEHAVIOR_UI.has(behavior):
			continue
		var ui_var: String = BEHAVIOR_UI[behavior]
		var ui: Node = null
		match ui_var:
			"crafting_table_ui": ui = crafting_table_ui
			"furnace_ui":        ui = furnace_ui
			"anvil_ui":          ui = anvil_ui
		if ui == null:
			push_warning("BlockInteraction: no UI assigned for behavior '%s' on '%s'." % [behavior, block_name])
			continue
		if ui.has_method("open"):
			ui.open(block_world_pos)
		return  # open only the first matching UI

# ---------------------------------------------------------------------------
# BREAK
# ---------------------------------------------------------------------------
func _reset_break() -> void:
	_break_timer    = 0.0
	_breaking_cell  = Vector2i(-9999, -9999)
	_breaking_layer = null
	_remove_indicator()

func _break_block(cell: Vector2i, layer: TileMapLayer) -> void:
	var atlas:      Vector2i = layer.get_cell_atlas_coords(cell)
	var block_name: String   = BlockRegistry.get_name_from_coords(atlas)

	# Use tag-based tree detection
	if tree_fell_enabled and _should_fell_tree(cell, layer, block_name):
		_break_connected_tree(cell, layer)
		return
	_break_single_block(cell, layer)

func _break_single_block(cell: Vector2i, layer: TileMapLayer) -> void:
	var atlas:        Vector2i  = layer.get_cell_atlas_coords(cell)
	var block_name:   String    = BlockRegistry.get_name_from_coords(atlas)
	var tile_texture: Texture2D = BlockRegistry.get_texture(block_name)

	layer.erase_cell(cell)

	if layer == _main:
		PhysicsManager.notify_broken(cell)

	var world_pos: Vector2 = _main.to_global(_main.map_to_local(cell))

	if break_effect_scene != null and tile_texture != null:
		var effect: Node2D = break_effect_scene.instantiate() as Node2D
		effect.global_position = world_pos
		get_tree().current_scene.add_child(effect)
		if effect.has_method("setup"):
			effect.setup(tile_texture)

	# Only spawn drops if the player's tool can actually harvest this block.
	# Wrong tier = block breaks but drops nothing (like real Minecraft).
	var held:      Dictionary = Inventory.get_selected_item()
	var tool_type: String     = ""
	var tool_tier: int        = 0
	if not held.is_empty() and ItemRegistry.is_tool(held["item_name"]):
		tool_type = ItemRegistry.get_tool_type(held["item_name"])
		tool_tier = ItemRegistry.get_tool_tier(held["item_name"])

	if drop_scene != null and BlockRegistry.can_harvest(block_name, tool_type, tool_tier):
		var drops: Array = BlockRegistry.resolve_drops(block_name)
		for drop_data in drops:
			var drop: Node = drop_scene.instantiate()
			drop.global_position = world_pos + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
			if drop.has_method("setup"):
				drop.setup(drop_data["item"], drop_data["count"])
			get_tree().current_scene.add_child(drop)

# ---------------------------------------------------------------------------
# TREE FELLING
# Now uses BlockRegistry.has_tag("log") and has_behavior("Leaves")
# instead of string suffix checks.
# ---------------------------------------------------------------------------
func _break_connected_tree(start_cell: Vector2i, start_layer: TileMapLayer) -> void:
	var start_name:       String = BlockRegistry.get_name_from_coords(start_layer.get_cell_atlas_coords(start_cell))
	var target_leaf_name: String = _leaf_name_for_log(start_name)

	var queue:       Array[Dictionary] = [{"cell": start_cell, "layer": start_layer}]
	var visited_logs:Dictionary        = {}
	var log_parts:   Array[Dictionary] = []
	var max_nodes:   int               = max(1, tree_fell_max_blocks)
	var log_dirs:    Array[Vector2i]   = [
		Vector2i(0,-1), Vector2i(-1,0), Vector2i(1,0),
		Vector2i(-1,-1), Vector2i(1,-1),
	]

	while not queue.is_empty() and log_parts.size() < max_nodes:
		var node:  Dictionary   = queue.pop_front()
		var cell:  Vector2i     = node["cell"]
		var layer: TileMapLayer = node["layer"]
		if cell.y > start_cell.y:
			continue
		var key: String = _cell_key(cell, layer)
		if visited_logs.has(key):
			continue
		visited_logs[key] = true
		if layer == null or layer.get_cell_source_id(cell) == -1:
			continue
		var bname: String = BlockRegistry.get_name_from_coords(layer.get_cell_atlas_coords(cell))
		if bname != start_name:
			continue
		log_parts.append({"cell": cell, "layer": layer})
		for l in _all_layers:
			var lk: String = _cell_key(cell, l)
			if not visited_logs.has(lk):
				queue.append({"cell": cell, "layer": l})
		for d in log_dirs:
			var nc: Vector2i = cell + d
			for l in _all_layers:
				var nk: String = _cell_key(nc, l)
				if not visited_logs.has(nk):
					queue.append({"cell": nc, "layer": l})

	var leaves_queue:   Array[Dictionary] = []
	var visited_leaves: Dictionary        = {}
	var leaf_parts:     Array[Dictionary] = []
	var leaf_seed_radius: int = 2
	for part in log_parts:
		var base: Vector2i = part["cell"]
		for y in range(base.y - leaf_seed_radius, base.y + leaf_seed_radius + 1):
			for x in range(base.x - leaf_seed_radius, base.x + leaf_seed_radius + 1):
				for l in _all_layers:
					leaves_queue.append({"cell": Vector2i(x,y), "layer": l})

	var leaf_dirs: Array[Vector2i] = [
		Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),
		Vector2i(-1, 0),               Vector2i(1, 0),
		Vector2i(-1, 1),Vector2i(0, 1),Vector2i(1, 1),
	]
	while not leaves_queue.is_empty() and (log_parts.size() + leaf_parts.size()) < max_nodes:
		var node:  Dictionary   = leaves_queue.pop_front()
		var cell:  Vector2i     = node["cell"]
		var layer: TileMapLayer = node["layer"]
		var key:   String       = _cell_key(cell, layer)
		if visited_leaves.has(key):
			continue
		visited_leaves[key] = true
		if layer == null or layer.get_cell_source_id(cell) == -1:
			continue
		var bname: String = BlockRegistry.get_name_from_coords(layer.get_cell_atlas_coords(cell))
		if target_leaf_name == "" or bname != target_leaf_name:
			continue
		leaf_parts.append({"cell": cell, "layer": layer})
		for d in leaf_dirs:
			var nc: Vector2i = cell + d
			for l in _all_layers:
				var nk: String = _cell_key(nc, l)
				if not visited_leaves.has(nk):
					leaves_queue.append({"cell": nc, "layer": l})

	for part in log_parts:
		_break_single_block(part["cell"], part["layer"])
	for part in leaf_parts:
		_break_single_block(part["cell"], part["layer"])

# ---------------------------------------------------------------------------
# TREE HELPERS — now use tags/behaviors from registry
# ---------------------------------------------------------------------------
func _is_log_block(block_name: String) -> bool:
	return BlockRegistry.has_tag(block_name, "log")

func _is_leaf_block(block_name: String) -> bool:
	return BlockRegistry.has_behavior(block_name, "Leaves")

func _leaf_name_for_log(log_name: String) -> String:
	if not _is_log_block(log_name):
		return ""
	# Strip " Log" suffix and add " Leaves"
	return log_name.trim_suffix(" Log") + " Leaves"

func _should_fell_tree(cell: Vector2i, layer: TileMapLayer, block_name: String) -> bool:
	if not _is_log_block(block_name):
		return false
	if layer == _object:
		return true
	return _has_nearby_leaves(cell, 4)

func _has_nearby_leaves(center: Vector2i, radius: int) -> bool:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			for l in _all_layers:
				if l == null or l.get_cell_source_id(Vector2i(x,y)) == -1:
					continue
				if _is_leaf_block(BlockRegistry.get_name_from_coords(l.get_cell_atlas_coords(Vector2i(x,y)))):
					return true
	return false

func _cell_key(cell: Vector2i, layer: TileMapLayer) -> String:
	var ln: String = "null" if layer == null else layer.name
	return "%s:%d:%d" % [ln, cell.x, cell.y]

# ---------------------------------------------------------------------------
# PLACE
# ---------------------------------------------------------------------------
func _place_block(cell: Vector2i) -> void:
	var player_cell:      Vector2i = _main.local_to_map(_main.to_local(player.global_position))
	var player_cell_head: Vector2i = player_cell - Vector2i(0, 1)
	if cell == player_cell or cell == player_cell_head:
		return
	if _main.get_cell_source_id(cell) != -1:
		return

	var selected: Dictionary = Inventory.get_selected_item()
	if selected.is_empty():
		return

	var item_name:   String   = selected["item_name"]
	var atlas_coords:Vector2i = BlockRegistry.get_coords_from_name(item_name)
	if atlas_coords == Vector2i(-1, -1):
		return

	_main.set_cell(cell, 0, atlas_coords)
	Inventory.remove_item(item_name)
