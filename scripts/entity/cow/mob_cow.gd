# ---------------------------------------------------------------------------
# MOB — COW
# Extends entity_base.
#
# States:
#   IDLE   — stands still for a random duration, then picks a new wander target
#   WANDER — walks toward a target tile, then goes idle
#   FLEE   — runs away from the player briefly after taking damage
#
# Drops on death:
#   Raw Beef  × 1–3
#   Leather   × 0–2
#
# SCENE SETUP (create a scene, save as Cow.tscn):
#   CharacterBody2D  ← attach mob_cow.gd
#   ├── CollisionShape2D  (CapsuleShape2D, ~14×26)
#   └── Visual (Node2D)
#       └── Sprite2D  (assign your cow texture)
#
# Set drop_scene in the Inspector to your BlockDrop.tscn.
# ---------------------------------------------------------------------------
extends "res://scripts/entity/entity_base.gd"

# ---------------------------------------------------------------------------
# EXPORTS
# ---------------------------------------------------------------------------
@export_group("AI")
@export var wander_speed:      float = 55.0
@export var flee_speed:        float = 130.0
@export var idle_time_min:     float = 2.0
@export var idle_time_max:     float = 5.0
@export var wander_distance:   float = 80.0   # max pixels to wander per trip
@export var flee_duration:     float = 2.5    # seconds to flee after being hit
@export var player_detect_range: float = 300.0 # not used for aggro, only flee

# ---------------------------------------------------------------------------
# STATE MACHINE
# ---------------------------------------------------------------------------
enum State { IDLE, WANDER, FLEE }

var _state:           State   = State.IDLE
var _state_timer:     float   = 0.0
var _wander_target_x: float   = 0.0
var _flee_dir:        float   = 1.0

# ---------------------------------------------------------------------------
@onready var _visual: Node2D = get_node_or_null("Visual") as Node2D

func _on_ready() -> void:
	_enter_idle()

# ---------------------------------------------------------------------------
# MAIN AI LOOP
# ---------------------------------------------------------------------------
func _state_process(delta: float) -> void:
	_state_timer -= delta

	# Drive visual animation
	if _visual != null and _visual.has_method("update_animation"):
		_visual.update_animation(velocity, is_on_floor(), delta)

	match _state:
		State.IDLE:
			_process_idle()
		State.WANDER:
			_process_wander()
		State.FLEE:
			_process_flee(delta)

	# Drive the visual model animations
	if visual != null and visual.has_method("update_animation"):
		visual.update_animation(velocity, is_on_floor(), delta)

# ---------------------------------------------------------------------------
# IDLE
# ---------------------------------------------------------------------------
func _enter_idle() -> void:
	_state       = State.IDLE
	_state_timer = randf_range(idle_time_min, idle_time_max)
	velocity.x   = 0.0

func _process_idle() -> void:
	# Friction
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * get_physics_process_delta_time())
	if _state_timer <= 0.0:
		_enter_wander()

# ---------------------------------------------------------------------------
# WANDER
# ---------------------------------------------------------------------------
func _enter_wander() -> void:
	_state           = State.WANDER
	_state_timer     = 6.0   # max time before giving up
	var dir: float   = 1.0 if randf() > 0.5 else -1.0
	_wander_target_x = global_position.x + dir * randf_range(wander_distance * 0.4, wander_distance)

func _process_wander() -> void:
	var diff: float = _wander_target_x - global_position.x
	if abs(diff) < 4.0 or _state_timer <= 0.0:
		_enter_idle()
		return
	velocity.x = sign(diff) * wander_speed
	# Stop at walls
	if is_on_wall():
		_enter_idle()

# ---------------------------------------------------------------------------
# FLEE
# ---------------------------------------------------------------------------
func _enter_flee() -> void:
	_state       = State.FLEE
	_state_timer = flee_duration
	# Flee away from the player
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_flee_dir = sign(global_position.x - player.global_position.x)
		if _flee_dir == 0.0:
			_flee_dir = 1.0
	else:
		_flee_dir = 1.0 if randf() > 0.5 else -1.0

func _process_flee(_delta: float) -> void:
	velocity.x = _flee_dir * flee_speed
	if is_on_wall():
		_flee_dir *= -1.0
	if _state_timer <= 0.0:
		_enter_idle()

# ---------------------------------------------------------------------------
# DAMAGE OVERRIDE — triggers flee
# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if is_alive() and _state != State.FLEE:
		_enter_flee()

# ---------------------------------------------------------------------------
# DROPS
# ---------------------------------------------------------------------------
func _get_drops() -> Array:
	var drops: Array = []
	var beef_count: int   = randi_range(1, 3)
	var leather_count:int = randi_range(0, 2)
	drops.append({"item": "Raw Beef",  "count": beef_count})
	if leather_count > 0:
		drops.append({"item": "Leather", "count": leather_count})
	return drops
