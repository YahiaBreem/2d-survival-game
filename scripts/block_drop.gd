extends RigidBody2D

# ---------------------------------------------------------------------------
# BLOCK DROP
#
# COLLISION LAYERS:
#   Layer 1 = world (TileMapLayer)
#   Layer 2 = player
#   Layer 3 = drops
#
# PICKUP BEHAVIOUR:
#   - Short delay before pickup is allowed (so you don't insta-grab what you broke)
#   - Magnet range: drop slides toward player smoothly
#   - Pickup range: drop is collected when close enough
#   - Merging: runs at spawn AND continuously for drops that land near each other
# ---------------------------------------------------------------------------

@export var pickup_delay:   float = 0.8    # seconds before pickup is allowed
@export var magnet_radius:  float = 64.0   # distance at which drop starts sliding to player
@export var pickup_radius:  float = 20.0   # distance at which drop is collected
@export var magnet_speed:   float = 180.0  # pixels/sec pull speed toward player
@export var merge_radius:   float = 40.0   # distance within which same-item drops merge

var item_name:   String = ""
var stack_count: int    = 1
var _can_pickup: bool   = false
var _merging:    bool   = false   # prevents double-merge during queue_free frame

@onready var sprite: Sprite2D = $Sprite2D

# ---------------------------------------------------------------------------
func _ready() -> void:
	gravity_scale = 3.0
	linear_damp   = 4.0   # high damp = settles fast, no endless sliding
	lock_rotation = true

	# Layer 3, collides with world + player + other drops
	collision_layer = 4
	collision_mask  = 7

	# Small random pop on spawn
	linear_velocity = Vector2(randf_range(-40.0, 40.0), randf_range(-80.0, -40.0))

	# Add collision shape if not present in scene
	if get_node_or_null("CollisionShape2D") == null:
		var col:   CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D    = CircleShape2D.new()
		shape.radius = 5.0
		col.shape    = shape
		add_child(col)

	add_to_group("drops")
	_apply_texture()

	# After delay: allow pickup and stop colliding with player
	await get_tree().create_timer(pickup_delay).timeout
	if not is_inside_tree():
		return
	_can_pickup  = true
	collision_mask = 5   # 0b101 = world + other drops only, no player push

	_try_merge()

# ---------------------------------------------------------------------------
# Called by block_interaction.gd right after instantiation.
# ---------------------------------------------------------------------------
func setup(p_item_name: String, p_count: int = 1) -> void:
	item_name   = p_item_name
	stack_count = p_count

# ---------------------------------------------------------------------------
# PHYSICS — magnet pull + pickup check
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not _can_pickup:
		return

	# Find closest player
	var closest_player: Node2D = null
	var closest_dist:   float  = INF
	for body in get_tree().get_nodes_in_group("player"):
		if body is Node2D:
			var d: float = global_position.distance_to((body as Node2D).global_position)
			if d < closest_dist:
				closest_dist   = d
				closest_player = body as Node2D

	if closest_player == null:
		return

	# Pickup
	if closest_dist <= pickup_radius:
		_collect()
		return

	# Magnet pull — slide toward player smoothly
	if closest_dist <= magnet_radius:
		var dir: Vector2    = (closest_player.global_position - global_position).normalized()
		# Ramp speed up as it gets closer
		var t:   float      = 1.0 - (closest_dist / magnet_radius)
		var spd: float      = magnet_speed * (0.4 + t * 0.6)
		linear_velocity     = dir * spd

	# Continuous merge check — catches drops that rolled next to each other after spawn
	_try_merge()

# ---------------------------------------------------------------------------
func _collect() -> void:
	if _merging:
		return
	_merging = true
	Inventory.add_item(item_name, stack_count)
	queue_free()

# ---------------------------------------------------------------------------
# MERGE — combines nearby drops of the same item into one stack
# ---------------------------------------------------------------------------
func _try_merge() -> void:
	if _merging:
		return
	for drop in get_tree().get_nodes_in_group("drops"):
		if drop == self or not drop is RigidBody2D:
			continue
		if drop.get("_merging"):
			continue
		if drop.get("item_name") != item_name:
			continue
		if not drop.get("_can_pickup"):
			continue
		if global_position.distance_to((drop as Node2D).global_position) > merge_radius:
			continue
		# Absorb the other drop into this one
		var other_count: int = drop.get("stack_count") if drop.get("stack_count") != null else 1
		stack_count += other_count
		drop.set("_merging", true)
		drop.queue_free()
		_update_count_label()

# ---------------------------------------------------------------------------
# TEXTURE — checks ItemRegistry first, falls back to BlockRegistry
# ---------------------------------------------------------------------------
func _apply_texture() -> void:
	if item_name.is_empty() or sprite == null:
		return

	var tex: Texture2D = null

	# Try ItemRegistry first (tools, materials, etc.)
	if Engine.has_singleton("ItemRegistry") or get_node_or_null("/root/ItemRegistry") != null:
		tex = ItemRegistry.get_texture(item_name)

	# Fallback to BlockRegistry for block drops
	if tex == null:
		tex = BlockRegistry.get_texture(item_name)

	if tex == null:
		push_warning("BlockDrop: no texture found for '%s'" % item_name)
		return

	sprite.texture = tex
	sprite.scale   = Vector2(0.5, 0.5)

# ---------------------------------------------------------------------------
# COUNT LABEL
# ---------------------------------------------------------------------------
func _update_count_label() -> void:
	var lbl: Label = get_node_or_null("CountLabel") as Label
	if lbl == null and stack_count > 1:
		lbl          = Label.new()
		lbl.name     = "CountLabel"
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color",         Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.position = Vector2(-4.0, 6.0)
		add_child(lbl)
	if lbl != null:
		lbl.text = "" if stack_count <= 1 else str(stack_count)