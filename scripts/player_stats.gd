# ---------------------------------------------------------------------------
# PLAYER STATS — Autoload singleton
#
# Pure data layer for health and hunger. No UI code here.
#
# AUTOLOAD SETUP:
#   Project → Project Settings → Autoload
#   Name : "PlayerStats"
#   Path : res://player_stats.gd
#   Add it AFTER Inventory in the load order.
#
# HEALTH  (0–20):
#   • take_damage(amount)  — reduces health, emits health_changed, emits died at 0
#   • heal(amount)         — increases health up to MAX_HEALTH
#
# HUNGER  (0–20):
#   • feed(amount)         — increases hunger up to MAX_HUNGER
#   • Drains automatically over time (HUNGER_DRAIN_INTERVAL seconds per point)
#   • At hunger == 0 → health drains 1 per STARVE_INTERVAL seconds
#   • At hunger == MAX_HUNGER → health regenerates 1 per REGEN_INTERVAL seconds
#
# SIGNALS:
#   health_changed(new_health : int)
#   hunger_changed(new_hunger : int)
#   died                               — emitted once when health reaches 0
# ---------------------------------------------------------------------------
extends Node

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
const MAX_HEALTH: int = 20
const MAX_HUNGER: int = 20

# Seconds between each -1 hunger tick while alive
const HUNGER_DRAIN_INTERVAL: float = 30.0

# Seconds between each -1 health tick while starving (hunger == 0)
const STARVE_INTERVAL: float = 4.0

# Seconds between each +1 health tick while full (hunger == MAX_HUNGER)
const REGEN_INTERVAL: float = 1.0

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var health: int = MAX_HEALTH
var hunger: int = MAX_HUNGER

var _dead: bool          = false   # prevents repeated died emissions

var _hunger_timer: float = 0.0
var _starve_timer: float = 0.0
var _regen_timer:  float = 0.0

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal health_changed(new_health: int)
signal hunger_changed(new_hunger: int)
signal died

# ---------------------------------------------------------------------------
# PROCESS — tick-based drain / regen
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _dead:
		return

	# --- Hunger drain ---
	_hunger_timer += delta
	if _hunger_timer >= HUNGER_DRAIN_INTERVAL:
		_hunger_timer -= HUNGER_DRAIN_INTERVAL
		_set_hunger(hunger - 1)

	# --- Starvation damage ---
	if hunger <= 0:
		_starve_timer += delta
		if _starve_timer >= STARVE_INTERVAL:
			_starve_timer -= STARVE_INTERVAL
			_set_health(health - 1)
	else:
		_starve_timer = 0.0

	# --- Natural regeneration (only when hunger is full) ---
	if hunger >= MAX_HUNGER and health < MAX_HEALTH:
		_regen_timer += delta
		if _regen_timer >= REGEN_INTERVAL:
			_regen_timer -= REGEN_INTERVAL
			_set_health(health + 1)
	else:
		_regen_timer = 0.0

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------

## Deal damage to the player. Clamps to 0 and emits died if fatal.
func take_damage(amount: int) -> void:
	if _dead:
		return
	_set_health(health - amount)

## Heal the player. Clamps to MAX_HEALTH.
func heal(amount: int) -> void:
	if _dead:
		return
	_set_health(health + amount)

## Feed the player. Clamps to MAX_HUNGER.
## Call this when the player eats a food item.
## Pass ItemRegistry.get_food_value(item_name) as the amount.
func feed(amount: int) -> void:
	_set_hunger(hunger + amount)

## Respawn — reset stats and clear the dead flag.
func respawn() -> void:
	_dead   = false
	_hunger_timer = 0.0
	_starve_timer = 0.0
	_regen_timer  = 0.0
	_set_health(MAX_HEALTH)
	_set_hunger(MAX_HUNGER)

# ---------------------------------------------------------------------------
# INTERNAL SETTERS — always go through these so signals fire correctly
# ---------------------------------------------------------------------------
func _set_health(value: int) -> void:
	var clamped: int = clamp(value, 0, MAX_HEALTH)
	if clamped == health:
		return
	health = clamped
	health_changed.emit(health)
	if health <= 0 and not _dead:
		_dead = true
		died.emit()

func _set_hunger(value: int) -> void:
	var clamped: int = clamp(value, 0, MAX_HUNGER)
	if clamped == hunger:
		return
	hunger = clamped
	hunger_changed.emit(hunger)