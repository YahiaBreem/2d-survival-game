# ---------------------------------------------------------------------------
# ENTITY BASE
# Base class for all mobs. Handles:
#   - Gravity + physics (CharacterBody2D, same feel as player)
#   - Health, damage, death
#   - Drop spawning on death
#   - Damage flash visual feedback
#   - Facing direction
#
# SCENE SETUP:
#   - CharacterBody2D (this script)
#     ├── CollisionShape2D
#     └── Visual (Node2D)  ← optional, flipped to face movement direction
#
# EXTENDING:
#   extends entity_base
#   Override _state_process(delta) for AI.
#   Override _get_drops() to return drop data.
# ---------------------------------------------------------------------------
extends CharacterBody2D

# ---------------------------------------------------------------------------
# PHYSICS
# ---------------------------------------------------------------------------
@export_group("Physics")
@export var gravity:          float = 1200.0
@export var fall_gravity:     float = 1800.0
@export var terminal_velocity:float = 1000.0
@export var move_speed:       float = 80.0
@export var ground_friction:  float = 1200.0

# ---------------------------------------------------------------------------
# HEALTH
# ---------------------------------------------------------------------------
@export_group("Health")
@export var max_health: int = 10

# ---------------------------------------------------------------------------
# DROPS
# ---------------------------------------------------------------------------
@export_group("Drops")
@export var drop_scene: PackedScene

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal died(entity: CharacterBody2D)
signal health_changed(current: int, maximum: int)

# ---------------------------------------------------------------------------
# INTERNAL STATE
# ---------------------------------------------------------------------------
var health:       int   = max_health
var _facing:      float = 1.0    # 1.0 = right, -1.0 = left
var _flash_timer: float = 0.0

const FLASH_DURATION: float = 0.12

@onready var visual: Node2D = get_node_or_null("Visual") as Node2D

# ---------------------------------------------------------------------------
func _ready() -> void:
	health = max_health
	_on_ready()

## Override in subclass for additional setup.
func _on_ready() -> void:
	pass

# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_state_process(delta)
	move_and_slide()
	_update_facing()
	_tick_flash(delta)

# ---------------------------------------------------------------------------
# GRAVITY
# ---------------------------------------------------------------------------
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y > 0.0:
			velocity.y = 0.0
		return
	var grav: float = fall_gravity if velocity.y > 0.0 else gravity
	velocity.y = min(velocity.y + grav * delta, terminal_velocity)

# ---------------------------------------------------------------------------
# AI — override in subclass
# ---------------------------------------------------------------------------
## Called every physics frame. Subclass sets velocity.x here.
func _state_process(_delta: float) -> void:
	pass

# ---------------------------------------------------------------------------
# FACING
# ---------------------------------------------------------------------------
func _update_facing() -> void:
	if abs(velocity.x) > 5.0:
		_facing = sign(velocity.x)
	if visual != null:
		visual.scale.x = _facing

# ---------------------------------------------------------------------------
# HEALTH & DAMAGE
# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	health_changed.emit(health, max_health)
	_start_flash()
	if health <= 0:
		_die()

func _die() -> void:
	died.emit(self)
	_spawn_drops()
	queue_free()

# ---------------------------------------------------------------------------
# DROPS
# ---------------------------------------------------------------------------
## Override in subclass. Return Array of {"item": String, "count": int}.
func _get_drops() -> Array:
	return []

func _spawn_drops() -> void:
	if drop_scene == null:
		return
	for drop_data in _get_drops():
		var drop: Node = drop_scene.instantiate()
		drop.global_position = global_position + Vector2(
			randf_range(-10.0, 10.0),
			randf_range(-8.0, 0.0)
		)
		if drop.has_method("setup"):
			drop.setup(drop_data["item"], drop_data["count"])
		get_tree().current_scene.add_child(drop)

# ---------------------------------------------------------------------------
# DAMAGE FLASH
# ---------------------------------------------------------------------------
func _start_flash() -> void:
	_flash_timer = FLASH_DURATION
	if visual != null:
		visual.modulate = Color(1.5, 0.3, 0.3)

func _tick_flash(delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = 0.0
		if visual != null:
			visual.modulate = Color.WHITE

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func get_facing() -> float:
	return _facing

func is_alive() -> bool:
	return health > 0
