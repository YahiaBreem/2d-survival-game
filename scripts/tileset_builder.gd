# ---------------------------------------------------------------------------
# TILE SET BUILDER  —  Autoload singleton
#
# Builds a single TileSet from individual block PNGs and assigns it to all
# four TileMapLayer nodes. Only the foreground layer gets collision polygons.
#
# LAYER GROUPS (add each TileMapLayer to its group in the Godot editor):
#   "layer_main"       — z   0: main terrain blocks  (has collision)
#   "layer_object"     — z -20: objects / workstations (no collision)
#   "layer_back_wall"  — z -40: back wall tiles        (no collision)
#   "layer_background" — z -60: background / décor     (no collision)
#   "layer_far_background_front" — z -80: far background front mountains (no collision)
#   "layer_far_background_back"  — z -90: far background back mountains  (no collision)
#   "layer_far_background"       — legacy fallback for front layer
#
# AUTOLOAD ORDER:
#   BlockRegistry  →  TileSetBuilder  →  (WorldGen is a scene node, not autoload)
# ---------------------------------------------------------------------------
extends Node

const TILE_SIZE: int = 32
const SOURCE_ID: int = 0

var tileset_ready: bool = false

# ---------------------------------------------------------------------------
func _ready() -> void:
	await get_tree().process_frame
	build()

# ---------------------------------------------------------------------------
func build() -> void:
	# -----------------------------------------------------------------------
	# Find all four layers — foreground is required, others are optional but
	# should all be present for the full layer system to work.
	# -----------------------------------------------------------------------
	var fg:   TileMapLayer = get_tree().get_first_node_in_group("layer_main")        as TileMapLayer
	var obj:  TileMapLayer = get_tree().get_first_node_in_group("layer_object")      as TileMapLayer
	var wall: TileMapLayer = get_tree().get_first_node_in_group("layer_back_wall")   as TileMapLayer
	var bg:   TileMapLayer = get_tree().get_first_node_in_group("layer_background")  as TileMapLayer
	var far_bg_front: TileMapLayer = get_tree().get_first_node_in_group("layer_far_background_front") as TileMapLayer
	if far_bg_front == null:
		far_bg_front = get_tree().get_first_node_in_group("layer_far_background") as TileMapLayer
	var far_bg_back: TileMapLayer = get_tree().get_first_node_in_group("layer_far_background_back") as TileMapLayer

	if fg == null:
		push_error("TileSetBuilder: 'layer_main' group not found. Aborting.")
		return
	if obj  == null: push_warning("TileSetBuilder: 'layer_object' layer not found.")
	if wall == null: push_warning("TileSetBuilder: 'layer_back_wall' layer not found.")
	if bg   == null: push_warning("TileSetBuilder: 'layer_background' layer not found.")
	if far_bg_front == null: push_warning("TileSetBuilder: far background front layer not found.")
	if far_bg_back == null: push_warning("TileSetBuilder: far background back layer not found.")

	# -----------------------------------------------------------------------
	# Collect and sort base block coords
	# -----------------------------------------------------------------------
	var coord_list: Array = BlockRegistry.BLOCKS_BY_COORDS.keys()
	coord_list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	if coord_list.is_empty():
		push_error("TileSetBuilder: BLOCKS_BY_COORDS is empty. Aborting.")
		return

	var max_col: int = 0
	var max_row: int = 0
	for coord: Vector2i in coord_list:
		var block_name: String = BlockRegistry.BLOCKS_BY_COORDS[coord]
		var block_def: Dictionary = BlockRegistry.get_block(block_name)
		var frames: int = max(1, int(block_def.get("frames", 1)))
		max_col = max(max_col, coord.x + frames - 1)
		max_row = max(max_row, coord.y)

	var atlas_w: int = (max_col + 1) * TILE_SIZE
	var atlas_h: int = (max_row + 1) * TILE_SIZE

	# -----------------------------------------------------------------------
	# Stitch atlas image
	# -----------------------------------------------------------------------
	var atlas_image: Image = Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))

	var missing: Array[String] = []
	for coord: Vector2i in coord_list:
		var block_name: String = BlockRegistry.BLOCKS_BY_COORDS[coord]
		var block_def: Dictionary = BlockRegistry.get_block(block_name)
		var frames: int = max(1, int(block_def.get("frames", 1)))
		var tex: Texture2D     = BlockRegistry.get_texture(block_name)
		if tex == null:
			missing.append(block_name)
			continue
		var src: Image = tex.get_image()
		if src == null:
			missing.append(block_name)
			continue
		if src.get_format() != Image.FORMAT_RGBA8:
			src.convert(Image.FORMAT_RGBA8)

		# Animated tiles are expected as a vertical strip: TILE_SIZE by TILE_SIZE * N.
		if frames == 1:
			if src.get_width() != TILE_SIZE or src.get_height() != TILE_SIZE:
				src.resize(TILE_SIZE, TILE_SIZE, Image.INTERPOLATE_NEAREST)
			atlas_image.blit_rect(src, Rect2i(0, 0, TILE_SIZE, TILE_SIZE),
				Vector2i(coord.x * TILE_SIZE, coord.y * TILE_SIZE))
		else:
			# Keep full strip height; only normalize width to tile width.
			if src.get_width() != TILE_SIZE:
				src.resize(TILE_SIZE, src.get_height(), Image.INTERPOLATE_NEAREST)
			for frame in range(frames):
				var frame_y: int = frame * TILE_SIZE
				if frame_y + TILE_SIZE > src.get_height():
					break
				atlas_image.blit_rect(src, Rect2i(0, frame_y, TILE_SIZE, TILE_SIZE),
					Vector2i((coord.x + frame) * TILE_SIZE, coord.y * TILE_SIZE))

	if missing.size() > 0:
		print("TileSetBuilder: missing textures for: ", missing)

	var atlas_texture: ImageTexture = ImageTexture.create_from_image(atlas_image)

	# -----------------------------------------------------------------------
	# Build atlas source — shared by all layers
	# -----------------------------------------------------------------------
	var atlas_source: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source.texture             = atlas_texture
	atlas_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord: Vector2i in coord_list:
		if not atlas_source.has_tile(coord):
			atlas_source.create_tile(coord)
		var block_name: String = BlockRegistry.BLOCKS_BY_COORDS[coord]
		var block_def: Dictionary = BlockRegistry.get_block(block_name)
		var frames: int = max(1, int(block_def.get("frames", 1)))
		var anim_fps: float = float(block_def.get("anim_fps", 8.0))
		if frames > 1:
			_configure_tile_animation(atlas_source, coord, frames, anim_fps)

	# -----------------------------------------------------------------------
	# Build TileSet WITH collision — used by the foreground layer only
	# -----------------------------------------------------------------------
	var ts_solid: TileSet = TileSet.new()
	ts_solid.tile_size    = Vector2i(TILE_SIZE, TILE_SIZE)
	ts_solid.add_physics_layer()
	ts_solid.set_physics_layer_collision_layer(0, 1)
	ts_solid.set_physics_layer_collision_mask(0, 1)
	ts_solid.add_source(atlas_source, SOURCE_ID)

	# Add full-tile collision only to solid blocks.
	var half: float = TILE_SIZE * 0.5
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(-half, -half), Vector2( half, -half),
		Vector2( half,  half), Vector2(-half,  half),
	])
	for coord: Vector2i in coord_list:
		var block_name: String = BlockRegistry.BLOCKS_BY_COORDS[coord]
		if not BlockRegistry.is_solid(block_name):
			continue
		var td: TileData = atlas_source.get_tile_data(coord, 0)
		if td == null:
			continue
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, poly)

	fg.tile_set = ts_solid

	# -----------------------------------------------------------------------
	# Build TileSet WITHOUT collision — shared by all non-solid layers.
	# We build a second TileSet using a fresh atlas source (same image) so
	# the collision polygons on ts_solid don't bleed through.
	# -----------------------------------------------------------------------
	var atlas_source_nc: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas_source_nc.texture             = atlas_texture   # same image, no collision data
	atlas_source_nc.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for coord: Vector2i in coord_list:
		if not atlas_source_nc.has_tile(coord):
			atlas_source_nc.create_tile(coord)
		var block_name: String = BlockRegistry.BLOCKS_BY_COORDS[coord]
		var block_def: Dictionary = BlockRegistry.get_block(block_name)
		var frames: int = max(1, int(block_def.get("frames", 1)))
		var anim_fps: float = float(block_def.get("anim_fps", 8.0))
		if frames > 1:
			_configure_tile_animation(atlas_source_nc, coord, frames, anim_fps)

	var ts_no_collision: TileSet = TileSet.new()
	ts_no_collision.tile_size    = Vector2i(TILE_SIZE, TILE_SIZE)
	ts_no_collision.add_source(atlas_source_nc, SOURCE_ID)

	if obj  != null: obj.tile_set  = ts_no_collision
	if wall != null: wall.tile_set = ts_no_collision
	if bg   != null: bg.tile_set   = ts_no_collision
	if far_bg_front != null: far_bg_front.tile_set = ts_no_collision
	if far_bg_back != null: far_bg_back.tile_set = ts_no_collision

	tileset_ready = true
	print("TileSetBuilder: atlas %dx%d px, %d tiles — assigned to all layers." \
		% [atlas_w, atlas_h, coord_list.size()])

func _configure_tile_animation(source: TileSetAtlasSource, coord: Vector2i, frames: int, anim_fps: float) -> void:
	if not source.has_method("set_tile_animation_frames_count"):
		push_warning("TileSetBuilder: this Godot version lacks tile animation API; '%s' will be static."
			% BlockRegistry.BLOCKS_BY_COORDS.get(coord, "tile"))
		return

	source.set_tile_animation_frames_count(coord, frames)
	source.set_tile_animation_columns(coord, frames)
	source.set_tile_animation_separation(coord, Vector2i.ZERO)
	source.set_tile_animation_speed(coord, max(0.1, anim_fps))
	for i in range(frames):
		source.set_tile_animation_frame_duration(coord, i, 1.0)
