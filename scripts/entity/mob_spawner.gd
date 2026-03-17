# ---------------------------------------------------------------------------
# MOB SPAWNER — Autoload singleton
#
# Periodically attempts to spawn mobs near the player.
# Respects max population, spawn distance, and only spawns on valid tiles.
#
# AUTOLOAD SETUP:
#   Project → Project Settings → Autoload
#   Name: "MobSpawner"
#
# USAGE:
#   MobSpawner.register(cow_scene, {
#       "max":          8,        # max alive at once
#       "interval":     12.0,     # seconds between spawn attempts
#       "valid_tiles":  ["Grass"],# block names the mob can stand on
#       "biomes":       [],       # [] = any biome
#       "spawn_dist_min": 200.0,  # don't spawn too close to player
#       "spawn_dist_max": 600.0,  # don't spawn too far
#   })
#
# Call register() from your main scene's _ready() once WorldGen is done.
# ---------------------------------------------------------------------------
extends Node

# ---------------------------------------------------------------------------
const TILE_SIZE:       int   = 32
const SCAN_ATTEMPTS:   int   = 12   # candidate positions tried per spawn tick

# ---------------------------------------------------------------------------
class SpawnEntry:
	var scene:         PackedScene
	var max_count:     int
	var interval:      float
	var timer:         float
	var valid_tiles:   Array
	var spawn_dist_min:float
	var spawn_dist_max:float
	var group_name:    String   # all spawned mobs added to this group

# ---------------------------------------------------------------------------
var _entries:   Array       = []
var _tilemap:   TileMapLayer = null
var _player:    Node2D      = null

# ---------------------------------------------------------------------------
func _ready() -> void:
	# Defer tilemap + player lookup so the scene tree is fully ready
	await get_tree().process_frame
	_tilemap = get_tree().get_first_node_in_group("layer_main") as TileMapLayer
	_player  = get_tree().get_first_node_in_group("player")     as Node2D

# ---------------------------------------------------------------------------
func register(scene: PackedScene, config: Dictionary) -> void:
	var entry          := SpawnEntry.new()
	entry.scene         = scene
	entry.max_count     = config.get("max",           8)
	entry.interval      = config.get("interval",      15.0)
	entry.timer         = randf_range(5.0, entry.interval)  # stagger first spawn
	var vt: Array = config.get("valid_tiles", ["Grass"])
	entry.valid_tiles = vt
	entry.spawn_dist_min= config.get("spawn_dist_min",200.0)
	entry.spawn_dist_max= config.get("spawn_dist_max",600.0)
	entry.group_name    = config.get("group",         scene.resource_path.get_file().get_basename())
	_entries.append(entry)

# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _tilemap == null:
		_tilemap = get_tree().get_first_node_in_group("layer_main") as TileMapLayer
	if _player == null or _tilemap == null:
		return

	for entry in _entries:
		entry.timer -= delta
		if entry.timer <= 0.0:
			entry.timer = entry.interval
			_try_spawn(entry)

# ---------------------------------------------------------------------------
func _try_spawn(entry: SpawnEntry) -> void:
	# Count how many of this type are alive
	var alive: int = get_tree().get_nodes_in_group(entry.group_name).size()
	print("MobSpawner: attempt spawn '%s' — alive=%d max=%d" % [entry.group_name, alive, entry.max_count])
	if alive >= entry.max_count:
		print("MobSpawner: at cap, skipping.")
		return

	# Try a number of random candidate positions
	for _i in SCAN_ATTEMPTS:
		var pos: Vector2 = _pick_candidate_position(entry)
		if pos == Vector2.ZERO:
			continue
		if not _is_valid_spawn(pos, entry):
			continue
		_spawn_at(pos, entry)
		return   # one spawn per tick

# ---------------------------------------------------------------------------
func _pick_candidate_position(entry: SpawnEntry) -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var angle:  float = randf() * TAU
	var dist:   float = randf_range(entry.spawn_dist_min, entry.spawn_dist_max)
	var candidate: Vector2 = _player.global_position + Vector2(cos(angle), 0.0) * dist
	# Snap to tile grid x
	candidate.x = floor(candidate.x / TILE_SIZE) * TILE_SIZE + TILE_SIZE * 0.5
	return candidate

# ---------------------------------------------------------------------------
func _is_valid_spawn(world_pos: Vector2, entry: SpawnEntry) -> bool:
	if _tilemap == null:
		return false

	var cell: Vector2i = _tilemap.local_to_map(_tilemap.to_local(world_pos))

	# Find the surface — scan downward from above until we hit a solid tile
	var surface_y: int = -1
	for dy in range(-4, 20):
		var check: Vector2i = Vector2i(cell.x, cell.y + dy)
		if _tilemap.get_cell_source_id(check) != -1:
			var atlas:      Vector2i = _tilemap.get_cell_atlas_coords(check)
			var block_name: String   = BlockRegistry.get_name_from_coords(atlas)
			if BlockRegistry.is_solid(block_name):
				surface_y = check.y
				break

	if surface_y == -1:
		return false

	# Check the surface tile is in the valid list
	var surface_cell:  Vector2i = Vector2i(cell.x, surface_y)
	var surface_atlas: Vector2i = _tilemap.get_cell_atlas_coords(surface_cell)
	var surface_name:  String   = BlockRegistry.get_name_from_coords(surface_atlas)
	if surface_name not in entry.valid_tiles:
		print("MobSpawner: invalid tile '%s'" % surface_name)
		return false

	# The two tiles above the surface must be empty (room for the mob)
	for dy in [1, 2]:
		var above: Vector2i = Vector2i(cell.x, surface_y - dy)
		if _tilemap.get_cell_source_id(above) != -1:
			return false

	return true

# ---------------------------------------------------------------------------
func _spawn_at(world_pos: Vector2, entry: SpawnEntry) -> void:
	if _tilemap == null:
		return

	# Place mob on top of the surface tile
	var cell:      Vector2i = _tilemap.local_to_map(_tilemap.to_local(world_pos))
	var surface_y: int      = _find_surface_y(cell.x)
	if surface_y == -1:
		return

	# World Y position = top edge of the surface tile
	var spawn_world: Vector2 = _tilemap.to_global(
		_tilemap.map_to_local(Vector2i(cell.x, surface_y - 1))
	)

	var mob: Node = entry.scene.instantiate()
	mob.global_position = spawn_world
	mob.add_to_group(entry.group_name)
	get_tree().current_scene.add_child(mob)
	print("MobSpawner: spawned '%s' at %s" % [entry.group_name, spawn_world])

# ---------------------------------------------------------------------------
func _find_surface_y(tile_x: int) -> int:
	if _tilemap == null or _player == null:
		return -1
	var approx_y: int = int(_player.global_position.y / TILE_SIZE)
	for dy in range(-10, 30):
		var check: Vector2i = Vector2i(tile_x, approx_y + dy)
		if _tilemap.get_cell_source_id(check) != -1:
			var atlas:      Vector2i = _tilemap.get_cell_atlas_coords(check)
			var block_name: String   = BlockRegistry.get_name_from_coords(atlas)
			if BlockRegistry.is_solid(block_name):
				return check.y
	return -1
