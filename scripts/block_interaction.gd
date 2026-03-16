extends Node

# ---------------------------------------------------------------------------
# BLOCK INTERACTION
# Attach this as a child node of your Player.
# Handles: breaking blocks (LMB), placing blocks (RMB),
#          interacting with blocks (interact key), reach limiting, item drops.
#
# INTERACTABLE BLOCKS:
#   Add block names to INTERACTABLE matching BlockRegistry names exactly.
#   Assign the corresponding UI nodes in the Inspector.
# ---------------------------------------------------------------------------

@export var reach:                   float       = 160.0
@export var block_size:              int         = 32
@export var drop_scene:              PackedScene
@export var break_effect_scene:      PackedScene
@export var tree_fell_enabled:       bool        = true
@export var tree_fell_max_blocks:    int         = 180

# Assign destroy_indicate.png here in the Inspector
@export var break_indicator_texture: Texture2D

# Assign these in the Inspector to your UI scene nodes
@export var crafting_table_ui: Node
@export var furnace_ui:        Node
@export var anvil_ui:          Node

# ---------------------------------------------------------------------------
# Block name → which exported UI variable opens for it
# ---------------------------------------------------------------------------
const INTERACTABLE: Dictionary = {
	"Crafting Table": "crafting_table_ui",
	"Furnace":        "furnace_ui",
	"Anvil":          "anvil_ui",
}

# ---------------------------------------------------------------------------
var _main:      TileMapLayer = null
var _object:    TileMapLayer = null
var _back_wall: TileMapLayer = null

var _break_timer:    float        = 0.0
var _breaking_cell:  Vector2i     = Vector2i(-9999, -9999)
var _breaking_layer: TileMapLayer = null

# The Sprite2D overlay that shows crack stages on the block being broken
var _indicator: Sprite2D = null

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D

# ---------------------------------------------------------------------------
func _ready() -> void:
	_main      = get_tree().get_first_node_in_group("layer_main")       as TileMapLayer
	_object    = get_tree().get_first_node_in_group("layer_object")     as TileMapLayer
	_back_wall = get_tree().get_first_node_in_group("layer_back_wall")  as TileMapLayer

	if _main == null:
		push_error("BlockInteraction: foreground tilemap not found. Add it to group 'layer_main'.")

# ---------------------------------------------------------------------------
func _get_layer_at(cell: Vector2i) -> TileMapLayer:
	# Break priority: Main → Object → Back Wall
	if _main      != null and _main.get_cell_source_id(cell)      != -1: return _main
	if _object    != null and _object.get_cell_source_id(cell)    != -1: return _object
	if _back_wall != null and _back_wall.get_cell_source_id(cell) != -1: return _back_wall
	return null

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _main == null:
		return

	var cam: Camera2D        = get_viewport().get_camera_2d() as Camera2D
	var mouse_world: Vector2 = cam.get_global_mouse_position() if cam != null \
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
				var atlas_coords: Vector2i = _breaking_layer.get_cell_atlas_coords(hovered_cell)
				var block_name: String     = BlockRegistry.get_name_from_coords(atlas_coords)

				var held: Dictionary  = Inventory.get_selected_item()
				var tool_type: String = ""
				var tool_tier: int    = 0
				if not held.is_empty() and ItemRegistry.is_tool(held["item_name"]):
					tool_type = ItemRegistry.get_tool_type(held["item_name"])
					tool_tier = ItemRegistry.get_tool_tier(held["item_name"])

				var required: float = BlockRegistry.get_break_time(block_name, tool_type, tool_tier)

				if required < 0.0:
					_break_timer = 0.0
					_remove_indicator()
					return

				_break_timer += delta

				# Calculate progress (0.0 → 1.0) and show the correct crack stage
				var progress: float = clamp(_break_timer / required, 0.0, 1.0)
				_update_indicator(hovered_cell, progress)

				if _break_timer >= required:
					_break_block(hovered_cell, _breaking_layer)
					_reset_break()
	else:
		_reset_break()
		if player.visual.has_method("set_mining"):
			player.visual.set_mining(false)

	# --- Interact (single press) ---
	if Input.is_action_just_pressed("interact"):
		_try_interact(hovered_cell)

	# --- Placing (RMB, single press) ---
	if Input.is_action_just_pressed("place_block"):
		_place_block(hovered_cell)
		if player.visual.has_method("set_placing"):
			player.visual.set_placing()

# ---------------------------------------------------------------------------
# Creates the indicator Sprite2D on first call, then every frame:
#   - snaps it to the centre of the block being broken
#   - sets the correct frame (0–9) based on progress
# ---------------------------------------------------------------------------
func _update_indicator(cell: Vector2i, progress: float) -> void:
	if break_indicator_texture == null:
		return

	# Spawn the Sprite2D once and add it to the scene
	if _indicator == null:
		_indicator              = Sprite2D.new()
		_indicator.texture      = break_indicator_texture
		_indicator.hframes      = 10          # 10 stages side-by-side in the sheet
		_indicator.vframes      = 1
		_indicator.centered     = true
		_indicator.z_index      = 10          # above Main Layer (z 0), below Entities (z 20)
		get_tree().current_scene.add_child(_indicator)

	# Snap the indicator to the centre of the block in world space
	_indicator.global_position = _main.to_global(_main.map_to_local(cell))

	# Map progress to one of the 10 frames (0 = first crack, 9 = almost broken)
	_indicator.frame = min(int(progress * 10.0), 9)

# ---------------------------------------------------------------------------
# Removes the indicator Sprite2D from the scene and clears the reference
# ---------------------------------------------------------------------------
func _remove_indicator() -> void:
	if _indicator != null:
		_indicator.queue_free()
		_indicator = null

# ---------------------------------------------------------------------------
func _try_interact(cell: Vector2i) -> void:
	var layer: TileMapLayer = _get_layer_at(cell)
	if layer == null:
		return

	var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
	var block_name: String     = BlockRegistry.get_name_from_coords(atlas_coords)

	if not INTERACTABLE.has(block_name):
		return

	var block_world_pos: Vector2 = _main.to_global(_main.map_to_local(cell))

	var ui: Node = null
	match INTERACTABLE[block_name]:
		"crafting_table_ui": ui = crafting_table_ui
		"furnace_ui":        ui = furnace_ui
		"anvil_ui":          ui = anvil_ui

	if ui == null:
		push_warning("BlockInteraction: no UI assigned for '%s'. Assign it in the Inspector." % block_name)
		return

	if ui.has_method("open"):
		ui.open(block_world_pos)

# ---------------------------------------------------------------------------
func _reset_break() -> void:
	_break_timer    = 0.0
	_breaking_cell  = Vector2i(-9999, -9999)
	_breaking_layer = null
	_remove_indicator()

# ---------------------------------------------------------------------------
func _break_block(cell: Vector2i, layer: TileMapLayer) -> void:
	var atlas_coords: Vector2i  = layer.get_cell_atlas_coords(cell)
	var block_name: String      = BlockRegistry.get_name_from_coords(atlas_coords)
	if tree_fell_enabled and _should_fell_tree(cell, layer, block_name):
		_break_connected_tree(cell, layer)
		return

	_break_single_block(cell, layer)

func _break_single_block(cell: Vector2i, layer: TileMapLayer) -> void:
	var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
	var block_name: String = BlockRegistry.get_name_from_coords(atlas_coords)
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

	# Resolve drops — handles String, Dictionary, and Array formats
	if drop_scene != null:
		var drops: Array = BlockRegistry.resolve_drops(block_name)
		for drop_data in drops:
			var drop: Node = drop_scene.instantiate()
			# Spread multiple drops slightly so they don't stack perfectly
			drop.global_position = world_pos + Vector2(randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
			if drop.has_method("setup"):
				drop.setup(drop_data["item"], drop_data["count"])
			get_tree().current_scene.add_child(drop)

func _break_connected_tree(start_cell: Vector2i, start_layer: TileMapLayer) -> void:
	var start_name: String = BlockRegistry.get_name_from_coords(start_layer.get_cell_atlas_coords(start_cell))
	var target_leaf_name: String = _leaf_name_for_log(start_name)

	var queue: Array[Dictionary] = [{"cell": start_cell, "layer": start_layer}]
	var visited_logs: Dictionary = {}
	var log_parts: Array[Dictionary] = []
	var max_nodes: int = max(1, tree_fell_max_blocks)
	var log_dirs: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1),
	]

	# 1) Collect only same-species logs, and never below the block you mined.
	while not queue.is_empty() and log_parts.size() < max_nodes:
		var node: Dictionary = queue.pop_front()
		var cell: Vector2i = node["cell"]
		var layer: TileMapLayer = node["layer"]
		if cell.y > start_cell.y:
			continue
		var key: String = _cell_layer_key(cell, layer)
		if visited_logs.has(key):
			continue
		visited_logs[key] = true

		if layer == null or layer.get_cell_source_id(cell) == -1:
			continue
		var name: String = BlockRegistry.get_name_from_coords(layer.get_cell_atlas_coords(cell))
		if name != start_name:
			continue

		log_parts.append({"cell": cell, "layer": layer})

		# Same cell across layers.
		for l: TileMapLayer in _all_world_layers():
			var lk: String = _cell_layer_key(cell, l)
			if not visited_logs.has(lk):
				queue.append({"cell": cell, "layer": l})

		# Grow through trunk/body directions only (no downward propagation).
		for d: Vector2i in log_dirs:
			var nc: Vector2i = cell + d
			for l: TileMapLayer in _all_world_layers():
				var nk: String = _cell_layer_key(nc, l)
				if not visited_logs.has(nk):
					queue.append({"cell": nc, "layer": l})

	# 2) Collect matching leaves near collected logs (same species canopy only).
	var leaves_queue: Array[Dictionary] = []
	var visited_leaves: Dictionary = {}
	var leaf_parts: Array[Dictionary] = []
	var leaf_seed_radius: int = 2
	for part: Dictionary in log_parts:
		var base: Vector2i = part["cell"]
		for y in range(base.y - leaf_seed_radius, base.y + leaf_seed_radius + 1):
			for x in range(base.x - leaf_seed_radius, base.x + leaf_seed_radius + 1):
				var c: Vector2i = Vector2i(x, y)
				for l: TileMapLayer in _all_world_layers():
					leaves_queue.append({"cell": c, "layer": l})

	var leaf_dirs: Array[Vector2i] = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                  Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
	]
	while not leaves_queue.is_empty() and (log_parts.size() + leaf_parts.size()) < max_nodes:
		var node: Dictionary = leaves_queue.pop_front()
		var cell: Vector2i = node["cell"]
		var layer: TileMapLayer = node["layer"]
		var key: String = _cell_layer_key(cell, layer)
		if visited_leaves.has(key):
			continue
		visited_leaves[key] = true

		if layer == null or layer.get_cell_source_id(cell) == -1:
			continue
		var name: String = BlockRegistry.get_name_from_coords(layer.get_cell_atlas_coords(cell))
		if target_leaf_name == "" or name != target_leaf_name:
			continue

		leaf_parts.append({"cell": cell, "layer": layer})
		for d: Vector2i in leaf_dirs:
			var nc: Vector2i = cell + d
			for l: TileMapLayer in _all_world_layers():
				var nk: String = _cell_layer_key(nc, l)
				if not visited_leaves.has(nk):
					leaves_queue.append({"cell": nc, "layer": l})

	for part: Dictionary in log_parts:
		_break_single_block(part["cell"], part["layer"])
	for part: Dictionary in leaf_parts:
		_break_single_block(part["cell"], part["layer"])

func _is_log_block(block_name: String) -> bool:
	return block_name.ends_with(" Log")

func _is_leaf_block(block_name: String) -> bool:
	# Prefer tags, fallback to naming in case ItemRegistry entries are missing/typoed.
	return ItemRegistry.item_has_tag(block_name, "leaves") or block_name.ends_with(" Leaves")

func _is_tree_block(block_name: String) -> bool:
	return _is_log_block(block_name) or _is_leaf_block(block_name)

func _leaf_name_for_log(log_name: String) -> String:
	if not _is_log_block(log_name):
		return ""
	return log_name.trim_suffix(" Log") + " Leaves"

func _should_fell_tree(cell: Vector2i, layer: TileMapLayer, block_name: String) -> bool:
	if not _is_log_block(block_name):
		return false
	# Worldgen trunks are placed on the object layer; those are safe to auto-fell.
	if layer == _object:
		return true
	# For foreground logs (often player-built), only fell if leaves are nearby.
	return _has_nearby_leaves(cell, 4)

func _has_nearby_leaves(center: Vector2i, radius: int) -> bool:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var c: Vector2i = Vector2i(x, y)
			for l: TileMapLayer in _all_world_layers():
				if l == null or l.get_cell_source_id(c) == -1:
					continue
				var name: String = BlockRegistry.get_name_from_coords(l.get_cell_atlas_coords(c))
				if _is_leaf_block(name):
					return true
	return false

func _all_world_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	if _main      != null: layers.append(_main)
	if _object    != null: layers.append(_object)
	if _back_wall != null: layers.append(_back_wall)
	return layers

func _cell_layer_key(cell: Vector2i, layer: TileMapLayer) -> String:
	var ln: String = "null" if layer == null else layer.name
	return "%s:%d:%d" % [ln, cell.x, cell.y]

# ---------------------------------------------------------------------------
func _place_block(cell: Vector2i) -> void:
	var player_cell: Vector2i      = _main.local_to_map(_main.to_local(player.global_position))
	var player_cell_head: Vector2i = player_cell - Vector2i(0, 1)
	if cell == player_cell or cell == player_cell_head:
		return

	# Don't place on top of an existing main-layer block
	if _main.get_cell_source_id(cell) != -1:
		return

	var selected: Dictionary = Inventory.get_selected_item()
	if selected.is_empty():
		return

	var item_name: String      = selected["item_name"]
	var atlas_coords: Vector2i = BlockRegistry.get_coords_from_name(item_name)
	if atlas_coords == Vector2i(-1, -1):
		return

	# Workstation-type blocks go to the Object layer; everything else to Main.
	var target_layer: TileMapLayer
	if BlockRegistry.is_object_layer_block(item_name) and _object != null:
		target_layer = _object
	else:
		target_layer = _main

	target_layer.set_cell(cell, 0, atlas_coords)
	Inventory.remove_item(item_name)