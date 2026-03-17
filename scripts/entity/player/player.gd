extends CharacterBody2D

# --------------------
# SPEED
# --------------------
@export var walk_speed:         float = 220.0
@export var sprint_speed:       float = 300.0
@export var acceleration:       float = 800.0
@export var air_acceleration:   float = 300.0
@export var ground_friction:    float = 900.0
## Seconds between two taps to trigger sprint
@export var double_tap_window:  float = 0.25
## Horizontal speed multiplier when jumping while sprinting
@export var sprint_jump_boost:  float = 1.3

# --------------------
# GRAVITY / JUMP
# --------------------
@export var gravity:              float = 900.0
@export var fall_gravity:         float = 1100.0
@export var jump_force:           float = -420.0
@export var terminal_velocity:    float = 1400.0
## How long the jump button can be held to extend height (seconds)
@export var jump_hold_duration:   float = 0.20
## Extra upward force applied each frame while holding jump
@export var jump_hold_force:      float = 600.0

# --------------------
# DAMAGE
# --------------------
@export var fall_damage_threshold: float = 820.0
@export var fall_damage_scale:     float = 0.02
@export var cactus_damage_interval:float = 0.5

# --------------------
# VISUAL
# --------------------
@export var head_turn_speed: float = 18.0

@onready var visual: Node2D = $Visual as Node2D
@onready var head:   Node2D = $Visual/Head as Node2D

# --------------------
# INTERNAL STATE
# --------------------
var _was_on_floor:   bool  = false
var _cactus_timer:   float = 0.0
var _jump_hold_time: float = 0.0   # how long jump has been held this airtime
var _is_jumping:     bool  = false  # true while holding jump after leaving floor

# Sprint double-tap detection
var _is_sprinting:        bool  = false
var _last_tap_direction:  float = 0.0   # direction of last tap (-1 or 1)
var _last_tap_time:       float = 0.0   # time of last tap
var _double_tap_window:   float = 0.25  # seconds allowed between taps

# Sprint jump boost
var _sprint_jump_boost:   float = 1.3   # multiplier on horizontal speed during sprint jump

# --------------------
# MAIN
# --------------------
func _physics_process(delta: float) -> void:
	var velocity_before: float = velocity.y

	_apply_gravity(delta)
	_handle_sprint(delta)
	_handle_jump(delta)
	_handle_horizontal(delta)
	move_and_slide()
	_update_facing_and_head(delta)

	if visual != null and visual.has_method("update_animation"):
		visual.update_animation(velocity, is_on_floor(), delta)

	_check_fall_damage(velocity_before)
	_check_cactus_damage(delta)

# --------------------
# GRAVITY
# --------------------
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return
	var grav: float = fall_gravity if velocity.y > 0.0 else gravity
	velocity.y = min(velocity.y + grav * delta, terminal_velocity)

# --------------------
# JUMP  (holdable — Minecraft style)
# --------------------
func _handle_jump(delta: float) -> void:
	# Initial jump — only on the frame we hit the floor
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y      = jump_force
		_is_jumping     = true
		_jump_hold_time = 0.0
		# Sprint jump boost — extra horizontal momentum like Minecraft
		if _is_sprinting and abs(velocity.x) > 10.0:
			velocity.x *= sprint_jump_boost

	# Clear jump state when we land
	if is_on_floor():
		_is_jumping     = false
		_jump_hold_time = 0.0

	# Hold to extend — only while still rising and within hold window
	if _is_jumping and Input.is_action_pressed("jump"):
		if _jump_hold_time < jump_hold_duration and velocity.y < 0.0:
			velocity.y      -= jump_hold_force * delta
			_jump_hold_time += delta
		else:
			_is_jumping = false

	# Release early = short hop
	if Input.is_action_just_released("jump"):
		_is_jumping = false

# --------------------
# SPRINT  (double-tap to start, stop on collision or idle)
# --------------------
func _handle_sprint(delta: float) -> void:
	_last_tap_time += delta

	var left_pressed:  bool = Input.is_action_just_pressed("move_left")
	var right_pressed: bool = Input.is_action_just_pressed("move_right")

	if left_pressed or right_pressed:
		var tapped_dir: float = -1.0 if left_pressed else 1.0
		# Double tap in the same direction within the window = start sprint
		if tapped_dir == _last_tap_direction and _last_tap_time <= double_tap_window:
			_is_sprinting = true
		_last_tap_direction = tapped_dir
		_last_tap_time      = 0.0

	# Stop sprinting if direction reverses or no input
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction == 0.0 and is_on_floor():
		_is_sprinting = false
	if _is_sprinting and direction != 0.0:
		var moving_right: bool = velocity.x > 0.0
		if (moving_right and direction < 0.0) or (not moving_right and direction > 0.0):
			_is_sprinting = false

# --------------------
# HORIZONTAL
# --------------------
func _handle_horizontal(delta: float) -> void:
	var direction:    float = Input.get_axis("move_left", "move_right")
	var target_speed: float = sprint_speed if _is_sprinting else walk_speed

	if is_on_floor():
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, direction * target_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
			# Stop sprinting when the player stops moving
			if abs(velocity.x) < 5.0:
				_is_sprinting = false
	else:
		# In air: cap to current target speed, no extra acceleration boost
		var air_cap: float = target_speed
		if direction != 0.0:
			velocity.x = move_toward(velocity.x, direction * air_cap, air_acceleration * delta)

# --------------------
# FACING / HEAD
# --------------------
func _update_facing_and_head(delta: float) -> void:
	if visual == null or head == null:
		return
	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse:    Vector2 = mouse_world - global_position

	if abs(to_mouse.x) > 0.001:
		visual.scale.x = 1.0 if to_mouse.x > 0.0 else -1.0

	var dir:    Vector2 = mouse_world - head.global_position
	var target: float   = head.get_parent().get_global_transform().basis_xform_inv(dir).angle()
	target = clamp(target, deg_to_rad(-90.0), deg_to_rad(90.0))
	head.rotation = lerp_angle(head.rotation, target, clamp(head_turn_speed * delta, 0.0, 1.0))

# --------------------
# FALL DAMAGE
# --------------------
func _check_fall_damage(velocity_before: float) -> void:
	var just_landed: bool = is_on_floor() and not _was_on_floor
	_was_on_floor = is_on_floor()
	if not just_landed:
		return
	if velocity_before <= fall_damage_threshold:
		return
	var excess: float = velocity_before - fall_damage_threshold
	PlayerStats.take_damage(max(1, int(excess * fall_damage_scale)))

# --------------------
# CACTUS / CONTACT DAMAGE
# --------------------
func _check_cactus_damage(delta: float) -> void:
	if _cactus_timer > 0.0:
		_cactus_timer -= delta

	var touching: bool = false
	for i in get_slide_collision_count():
		var col: KinematicCollision2D = get_slide_collision(i)
		if col == null: continue
		var collider: Object = col.get_collider()
		if not (collider is TileMapLayer): continue
		var tilemap: TileMapLayer = collider as TileMapLayer
		var contact: Vector2  = col.get_position()
		var normal:  Vector2  = col.get_normal()
		var cell:    Vector2i = tilemap.local_to_map(tilemap.to_local(contact - normal * 2.0))
		var atlas:   Vector2i = tilemap.get_cell_atlas_coords(cell)
		if atlas == Vector2i(-1, -1): continue
		if BlockRegistry.get_contact_damage(BlockRegistry.get_name_from_coords(atlas)) > 0:
			touching = true
			break

	if touching and _cactus_timer <= 0.0:
		var highest: int = 0
		for i in get_slide_collision_count():
			var col: KinematicCollision2D = get_slide_collision(i)
			if col == null: continue
			var collider: Object = col.get_collider()
			if not (collider is TileMapLayer): continue
			var tilemap: TileMapLayer = collider as TileMapLayer
			var contact: Vector2  = col.get_position()
			var normal:  Vector2  = col.get_normal()
			var cell:    Vector2i = tilemap.local_to_map(tilemap.to_local(contact - normal * 2.0))
			var atlas:   Vector2i = tilemap.get_cell_atlas_coords(cell)
			if atlas == Vector2i(-1, -1): continue
			var dmg: int = BlockRegistry.get_contact_damage(BlockRegistry.get_name_from_coords(atlas))
			if dmg > highest: highest = dmg
		PlayerStats.take_damage(highest)
		_cactus_timer = cactus_damage_interval