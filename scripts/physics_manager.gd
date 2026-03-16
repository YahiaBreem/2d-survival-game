# ---------------------------------------------------------------------------
# PHYSICS MANAGER — Autoload singleton
#
# Handles runtime falling of physical blocks (sand, gravel, etc.)
# when support is removed beneath them by the player.
#
# SETUP:
#   Project → Project Settings → Autoload
#   Name: "PhysicsManager"
#
# HOW IT WORKS:
#   - block_interaction.gd calls SandPhysics.notify_broken(cell) after any
#     block is erased from the foreground layer.
#   - We check the cell above the broken block and any physical blocks found
#     are added to a pending queue.
#   - Each physics frame we process the queue: drop each block one cell at a
#     time until it lands. This gives a smooth step-by-step falling effect.
# ---------------------------------------------------------------------------
extends Node

# How many cells a physical block falls per second
const FALL_SPEED: float = 18.0

var _main: TileMapLayer = null

# Each entry: { "cell": Vector2i, "atlas": Vector2i, "accum": float }
var _falling: Array = []

# ---------------------------------------------------------------------------
func _ready() -> void:
	await get_tree().process_frame
	_main = get_tree().get_first_node_in_group("layer_main") as TileMapLayer

# ---------------------------------------------------------------------------
# Call this from block_interaction after erasing any foreground cell.
# Checks if the cell directly above is a physical block and starts it falling.
func notify_broken(cell: Vector2i) -> void:
	if _main == null:
		return
	_check_cell(Vector2i(cell.x, cell.y - 1))

func _check_cell(cell: Vector2i) -> void:
	if _main == null:
		return
	if _main.get_cell_source_id(cell) == -1:
		return
	var atlas: Vector2i = _main.get_cell_atlas_coords(cell)
	var name: String    = BlockRegistry.get_name_from_coords(atlas)
	if not BlockRegistry.is_physical(name):
		return
	# Don't add duplicates
	for entry in _falling:
		if entry["cell"] == cell:
			return
	_main.erase_cell(cell)
	_falling.append({ "cell": cell, "atlas": atlas, "accum": 0.0 })
	# Also check above this cell in case of stacked sand
	_check_cell(Vector2i(cell.x, cell.y - 1))

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _falling.is_empty() or _main == null:
		return

	var still_falling: Array = []

	for entry in _falling:
		entry["accum"] += delta * FALL_SPEED
		# Move down by however many whole cells accumulated
		while entry["accum"] >= 1.0:
			entry["accum"] -= 1.0
			var below: Vector2i = Vector2i(entry["cell"].x, entry["cell"].y + 1)
			if _main.get_cell_source_id(below) == -1:
				# Air below — fall one cell
				entry["cell"] = below
			else:
				# Landed — place the block and stop
				_main.set_cell(entry["cell"], 0, entry["atlas"])
				# Notify in case something physical was resting here
				notify_broken(entry["cell"])
				entry["accum"] = -1.0   # sentinel: done
				break

		if entry["accum"] != -1.0:
			still_falling.append(entry)

	_falling = still_falling