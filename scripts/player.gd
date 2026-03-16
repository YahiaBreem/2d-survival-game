extends CharacterBody2D

# ---------------------------------------------------------------------------
# MINECRAFT-STYLE MOVEMENT
#
# Key characteristics:
#   - Instant direction change on ground (no acceleration, snap to speed)
#   - Very quick stop on ground (high friction, not instant)
#   - Almost zero air control — you commit to your jump direction
#   - Fixed jump height, no variable jump (no jump cut)
#   - Fast falling gravity — falls feel weighty
#   - Terminal velocity cap
#   - No coyote time, no jump buffer — simple and direct like Minecraft
# ---------------------------------------------------------------------------

@export_group("Movement")
@export var walk_speed: float     = 220.0   # horizontal speed on ground
@export var ground_friction: float = 1600.0  # how quickly you stop on ground
@export var air_speed: float      = 220.0   # max horizontal speed in air
@export var air_accel: float      = 180.0   # very low — almost no air control

@export_group("Jump & Gravity")
@export var jump_force: float       = -340.0  # fixed jump velocity (no variable height)
@export var gravity: float          = 1200.0  # base gravity
@export var fall_gravity: float     = 1800.0  # stronger gravity when falling — snappy landing
@export var terminal_velocity: float = 1000.0  # max fall speed

@export_group("Damage")
# Minimum downward velocity on landing that starts dealing fall damage.
# Tuned so damage starts around 6+ blocks of freefall at current gravity.
@export var fall_damage_threshold: float = 820.0
# How many hearts of damage per 100 px/s above the threshold.
@export var fall_damage_scale: float     = 0.02    # damage = excess * scale

# Seconds between cactus damage ticks (Minecraft: 0.5s)
@export var cactus_damage_interval: float = 0.5

@export_group("Visual")
@export var head_turn_speed: float = 18.0

@onready var visual: Node2D        = $Visual as Node2D
@onready var head: Node2D          = $Visual/Head as Node2D

# ---------------------------------------------------------------------------
# INTERNAL STATE
# ---------------------------------------------------------------------------
var _prev_fall_velocity: float = 0.0   # velocity.y on the frame before landing
var _was_on_floor:       bool  = false # floor state from last frame
var _cactus_timer:       float = 0.0   # cooldown between cactus damage ticks

# ---------------------------------------------------------------------------
func _ready() -> void:
	assert(visual != null, "Visual node not found under Player")
	assert(head != null,   "Head node not found under Player/Visual")

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	# Store downward velocity BEFORE move_and_slide resolves the collision.
	# This is the "impact velocity" we use for fall damage.
	var velocity_before_slide: float = velocity.y

	_apply_gravity(delta)
	_handle_jump()
	_handle_horizontal(delta)
	move_and_slide()
	_update_facing_and_head(delta)

	if visual.has_method("update_animation"):
		visual.update_animation(velocity, is_on_floor(), delta)

	# --- Damage checks (after move_and_slide so collisions are resolved) ---
	_check_fall_damage(velocity_before_slide)
	_check_cactus_damage(delta)

# ---------------------------------------------------------------------------
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return
	var grav: float = fall_gravity if velocity.y > 0.0 else gravity
	velocity.y += grav * delta
	velocity.y  = min(velocity.y, terminal_velocity)

# ---------------------------------------------------------------------------
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

# ---------------------------------------------------------------------------
func _handle_horizontal(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")

	if is_on_floor():
		if direction != 0.0:
			velocity.x = direction * walk_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	else:
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, direction * air_speed, air_accel * delta)

# ---------------------------------------------------------------------------
# FALL DAMAGE
# Triggered the exact frame the player lands (was airborne, now on floor).
# Uses the velocity captured BEFORE move_and_slide zeroes it out.
# ---------------------------------------------------------------------------
func _check_fall_damage(velocity_before: float) -> void:
	var just_landed: bool = is_on_floor() and not _was_on_floor
	_was_on_floor = is_on_floor()

	if not just_landed:
		return

	# velocity_before is positive when falling down
	if velocity_before <= fall_damage_threshold:
		return

	var excess: float = velocity_before - fall_damage_threshold
	var damage: int   = max(1, int(excess * fall_damage_scale))
	PlayerStats.take_damage(damage)

# ---------------------------------------------------------------------------
# CACTUS DAMAGE
# After move_and_slide, iterate over all collisions this frame.
# If any colliding body is a TileMapLayer, check the block name at the
# contact point. If it has "damage" > 0 in BlockRegistry, deal damage
# on a cooldown timer.
# ---------------------------------------------------------------------------
func _check_cactus_damage(delta: float) -> void:
	# Tick the cooldown regardless so it drains while not touching cactus
	if _cactus_timer > 0.0:
		_cactus_timer -= delta

	var touching_damaging_block: bool = false

	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null:
			continue

		var collider: Object = col.get_collider()
		if not (collider is TileMapLayer):
			continue

		var tilemap: TileMapLayer = collider as TileMapLayer

		# Convert the collision contact point to a tile cell.
		# Nudge the point slightly inward along the collision normal
		# so it lands inside the tile rather than on the edge seam.
		var contact: Vector2  = col.get_position()
		var normal:  Vector2  = col.get_normal()
		var nudged:  Vector2  = contact - normal * 2.0   # 2px inside the tile
		var cell:    Vector2i = tilemap.local_to_map(tilemap.to_local(nudged))

		var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(cell)
		if atlas_coords == Vector2i(-1, -1):
			continue

		var block_name: String = BlockRegistry.get_name_from_coords(atlas_coords)
		var damage: int        = BlockRegistry.get_contact_damage(block_name)

		if damage > 0:
			touching_damaging_block = true
			break

	if touching_damaging_block and _cactus_timer <= 0.0:
		# Deal damage and reset the cooldown
		var block_damage: int = _get_highest_contact_damage()
		PlayerStats.take_damage(block_damage)
		_cactus_timer = cactus_damage_interval

# ---------------------------------------------------------------------------
# Returns the highest contact_damage value among all currently colliding
# damaging blocks. Called only when we know at least one exists.
# ---------------------------------------------------------------------------
func _get_highest_contact_damage() -> int:
	var highest: int = 0
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null:
			continue
		var collider: Object = col.get_collider()
		if not (collider is TileMapLayer):
			continue
		var tilemap: TileMapLayer = collider as TileMapLayer
		var contact: Vector2      = col.get_position()
		var normal:  Vector2      = col.get_normal()
		var nudged:  Vector2      = contact - normal * 2.0
		var cell:    Vector2i     = tilemap.local_to_map(tilemap.to_local(nudged))
		var atlas:   Vector2i     = tilemap.get_cell_atlas_coords(cell)
		if atlas == Vector2i(-1, -1):
			continue
		var name:   String = BlockRegistry.get_name_from_coords(atlas)
		var damage: int    = BlockRegistry.get_contact_damage(name)
		if damage > highest:
			highest = damage
	return highest

# ---------------------------------------------------------------------------
func _update_facing_and_head(delta: float) -> void:
	var mouse_world: Vector2 = get_global_mouse_position()

	var to_mouse: Vector2 = mouse_world - global_position
	if abs(to_mouse.x) > 0.001:
		visual.scale.x = 1.0 if to_mouse.x > 0.0 else -1.0

	var dir: Vector2  = mouse_world - head.global_position
	var target: float = head.get_parent().get_global_transform().basis_xform_inv(dir).angle()
	var limit: float  = deg_to_rad(90.0)
	target            = clamp(target, -limit, limit)
	var t: float      = clamp(head_turn_speed * delta, 0.0, 1.0)
	head.rotation     = lerp_angle(head.rotation, target, t)
