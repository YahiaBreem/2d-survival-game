extends Node2D

# ---------------------------------------------------------------------------
# PLAYER MODEL — handles skin application, held-item display, and all
# procedural animations.
#
# ANIMATION STATE PRIORITY (highest wins):
#   1. Mining  (LMB held)
#   2. Placing (RMB just pressed — one-shot swing)
#   3. In-air  (jumping / falling)
#   4. Walking
#   5. Idle    (breathe only)
#
# PUBLIC API (called by player.gd / block_interaction.gd):
#   set_mining(bool)   — call every frame: true while LMB held
#   set_placing()      — call once on RMB press (triggers one-shot swing)
#   update_animation(velocity, on_floor, delta)
#   update_held_item()
#   apply_skin(tex)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# SKIN REGIONS  (pixels inside the skin PNG)
# ---------------------------------------------------------------------------
const REGION_HEAD:      Rect2 = Rect2(0,  0,  16, 16)
const REGION_BACK_ARM:  Rect2 = Rect2(0,  16, 8,  24)
const REGION_BODY:      Rect2 = Rect2(8,  16, 8,  24)
const REGION_FRONT_ARM: Rect2 = Rect2(16, 16, 8,  24)
const REGION_FRONT_LEG: Rect2 = Rect2(0,  40, 8,  24)
const REGION_BACK_LEG:  Rect2 = Rect2(8,  40, 8,  24)

# ---------------------------------------------------------------------------
# TUNABLE PARAMETERS
# ---------------------------------------------------------------------------

@export_group("Walk")
@export var walk_cycle_speed: float  = 7.5    # rad/s of the sine cycle
@export var walk_leg_amp:     float  = 30.0   # degrees, Minecraft-like leg swing
@export var walk_arm_amp:     float  = 30.0   # degrees, opposite to legs

@export_group("Idle")
@export var idle_breathe_speed: float = 1.0
@export var idle_breathe_amp:   float = 0.0   # Minecraft idle is mostly rigid

@export_group("Mining")
@export var mine_cycle_speed:    float = 6.0
@export var mine_raise_deg:      float = -65.0
@export var mine_strike_deg:     float = 35.0
@export var mine_passive_deg:    float = 0.0

@export_group("Placing")
@export var place_swing_speed:  float = 12.0
@export var place_raise_deg:    float = -55.0
@export var place_extend_deg:   float = 25.0
@export var place_duration:     float = 0.16

@export_group("Air")
@export var jump_leg_deg:   float =  8.0
@export var fall_leg_deg:   float =  12.0
@export var jump_arm_deg:   float = -10.0
@export var fall_arm_deg:   float =  10.0
@export var air_snap_speed: float =  16.0
@export var land_snap_speed: float =  16.0

@export_group("Transition Speeds")
# How fast (lerp factor per second) rotations chase their target.
# Higher = snappier. These make the difference between "robotic" and "punchy".
@export var arm_lerp_speed:  float = 20.0
@export var leg_lerp_speed:  float = 20.0
@export var head_bob_speed:  float = 14.0

@export_group("Skin")
@export var skin: Texture2D

@export_group("Held Item Pose")
@export var held_default_rotation_deg: float = 0.0
@export var held_tool_rotation_deg: float = 45.0
@export var held_rod_rotation_deg: float = 45.0
@export var held_default_offset: Vector2 = Vector2(0.0, 24.0)
@export var held_tool_offset: Vector2 = Vector2(6.0, 20.0)
@export var held_rod_offset: Vector2 = Vector2(6.0, 20.0)
@export var held_default_scale: Vector2 = Vector2(0.35, 0.35)
@export var held_tool_scale: Vector2 = Vector2(1.0, 1.0)
@export var held_rod_scale: Vector2 = Vector2(1.0, 1.0)

# ---------------------------------------------------------------------------
# SCENE NODES
# ---------------------------------------------------------------------------
@onready var spr_head:      Sprite2D = $Head/Head
@onready var spr_body:      Sprite2D = $Body/Body
@onready var spr_front_arm: Sprite2D = $"Front Arm"/"Front Arm"
@onready var spr_back_arm:  Sprite2D = $"Back Arm"/"Back Arm"
@onready var spr_front_leg: Sprite2D = $"Front Leg"/"Front Leg"
@onready var spr_back_leg:  Sprite2D = $"Back Leg"/"Back Leg"

@onready var head:       Node2D = $Head
@onready var front_arm:  Node2D = $"Front Arm"
@onready var back_arm:   Node2D = $"Back Arm"
@onready var front_leg:  Node2D = $"Front Leg"
@onready var back_leg:   Node2D = $"Back Leg"

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------
var held_item: Sprite2D

# Global walk timer — advances only while walking so the cycle phase is stable.
var _walk_time: float = 0.0

# Global idle timer — always ticks for the breathe oscillation.
var _idle_time: float = 0.0

# Mining
var _is_mining:      bool  = false
var _mine_time:      float = 0.0   # only advances while mining
var _was_mining:     bool  = false # edge-detect to reset phase cleanly

# Placing (one-shot swing)
var _is_placing:     bool  = false
var _place_time:     float = 0.0   # 0→place_duration

# Whether the player was on the floor last frame — used for landing snap.
var _was_on_floor:   bool  = true

# ---------------------------------------------------------------------------
func _ready() -> void:
	var tex: Texture2D = skin if skin else load("res://assets/player/skin.png")
	if tex:
		apply_skin(tex)

	held_item          = Sprite2D.new()
	held_item.name     = "HeldItem"
	held_item.centered = true
	held_item.scale    = held_default_scale
	held_item.z_as_relative = false
	held_item.z_index = 20
	held_item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front_arm.add_child(held_item)
	held_item.position = held_default_offset

	Inventory.inventory_changed.connect(update_held_item)
	Inventory.hotbar_slot_changed.connect(func(_s: int) -> void: update_held_item())
	update_held_item()

# ---------------------------------------------------------------------------
# SKIN
# ---------------------------------------------------------------------------
func apply_skin(tex: Texture2D) -> void:
	_apply(spr_head,      tex, REGION_HEAD)
	_apply(spr_body,      tex, REGION_BODY)
	_apply(spr_front_arm, tex, REGION_FRONT_ARM)
	_apply(spr_back_arm,  tex, REGION_BACK_ARM)
	_apply(spr_front_leg, tex, REGION_FRONT_LEG)
	_apply(spr_back_leg,  tex, REGION_BACK_LEG)

func _apply(spr: Sprite2D, tex: Texture2D, region: Rect2) -> void:
	spr.texture        = tex
	spr.region_enabled = true
	spr.region_rect    = region

# ---------------------------------------------------------------------------
# HELD ITEM
# ---------------------------------------------------------------------------
func update_held_item() -> void:
	if held_item == null:
		return
	var slot: Dictionary = Inventory.get_selected_item()
	if slot.is_empty():
		held_item.texture = null
		held_item.visible = false
		_apply_held_item_pose("")
		return
	var item_name: String = slot.get("item_name", "")
	# Try ItemRegistry first (tools, materials, planks, etc.)
	# then fall back to BlockRegistry for placeable blocks
	var tex: Texture2D = ItemRegistry.get_texture(item_name)
	if tex == null:
		tex = BlockRegistry.get_texture(item_name)
	held_item.texture = tex
	held_item.visible = tex != null
	_apply_held_item_pose(item_name)

func _apply_held_item_pose(item_name: String) -> void:
	held_item.rotation = deg_to_rad(held_default_rotation_deg)
	held_item.position = held_default_offset
	held_item.scale = held_default_scale

	if item_name.is_empty():
		return
	if not ItemRegistry.has_item(item_name):
		return

	if ItemRegistry.is_tool(item_name):
		held_item.rotation = deg_to_rad(held_tool_rotation_deg)
		held_item.position = held_tool_offset
		held_item.scale = held_tool_scale
		return

	if item_name == "Stick":
		held_item.rotation = deg_to_rad(held_rod_rotation_deg)
		held_item.position = held_rod_offset
		held_item.scale = held_rod_scale

# ---------------------------------------------------------------------------
# PUBLIC: called by block_interaction.gd every frame while LMB is held.
# ---------------------------------------------------------------------------
func set_mining(mining: bool) -> void:
	_is_mining = mining
	# Only reset the cycle timer on the leading edge (first frame of new mine).
	# This prevents the phase jumping when set_mining(true) is called repeatedly.
	if mining and not _was_mining:
		_mine_time = 0.0
	_was_mining = mining

# ---------------------------------------------------------------------------
# PUBLIC: called by block_interaction.gd on RMB just_pressed.
# Starts a one-shot place swing only if we're not already mid-swing.
# ---------------------------------------------------------------------------
func set_placing() -> void:
	_is_placing = true
	_place_time = 0.0

# ---------------------------------------------------------------------------
# MAIN ANIMATION UPDATE — called from player.gd every physics frame.
# ---------------------------------------------------------------------------
func update_animation(velocity: Vector2, on_floor: bool, delta: float) -> void:
	# --- Advance global timers ---
	_idle_time += delta
	if abs(velocity.x) > 10.0 and on_floor:
		_walk_time += delta
	# Mining timer advances ONLY while actively mining — keeps phase stable.
	if _is_mining:
		_mine_time += delta
	# Place timer advances during one-shot swing.
	if _is_placing:
		_place_time += delta
		if _place_time >= place_duration:
			_is_placing = false

	# --- Derived state flags ---
	var is_walking: bool   = abs(velocity.x) > 10.0 and on_floor
	var is_jumping: bool   = not on_floor and velocity.y < 0.0
	var is_falling: bool   = not on_floor and velocity.y > 0.0
	var just_landed: bool  = on_floor and not _was_on_floor
	_was_on_floor = on_floor

	# --- Limb assignment ---
	# The Visual node's scale.x is flipped by player.gd to face left/right.
	# That flip already mirrors front↔back visually, so front_arm is ALWAYS
	# the rendered-front limb regardless of facing direction.
	# Never swap nodes or multiply by dir_sign — the parent flip does it all.
	var active_arm: Node2D  = front_arm
	var passive_arm: Node2D = back_arm
	var active_leg: Node2D  = front_leg
	var passive_leg: Node2D = back_leg

	# --- Choose lerp speed for this frame ---
	var a_spd: float = air_snap_speed if not on_floor else arm_lerp_speed
	var l_spd: float = air_snap_speed if not on_floor else leg_lerp_speed
	var a_t: float   = clamp(a_spd * delta, 0.0, 1.0)
	var l_t: float   = clamp(l_spd * delta, 0.0, 1.0)

	# =========================================================================
	# LEG TARGETS
	# =========================================================================
	var active_leg_target:  float
	var passive_leg_target: float

	if is_jumping:
		active_leg_target  =  deg_to_rad(jump_leg_deg)
		passive_leg_target = -deg_to_rad(jump_leg_deg)
	elif is_falling:
		active_leg_target  =  deg_to_rad(fall_leg_deg)
		passive_leg_target = -deg_to_rad(fall_leg_deg)
	elif is_walking:
		var swing: float   = sin(_walk_time * walk_cycle_speed) * deg_to_rad(walk_leg_amp)
		active_leg_target  =  swing
		passive_leg_target = -swing
	else:
		active_leg_target  = 0.0
		passive_leg_target = 0.0

	active_leg.rotation  = lerp_angle(active_leg.rotation,  active_leg_target,  l_t)
	passive_leg.rotation = lerp_angle(passive_leg.rotation, passive_leg_target, l_t)

	# =========================================================================
	# ARM TARGETS — priority: mining > placing > air > walking > idle
	# =========================================================================
	var active_arm_target:  float
	var passive_arm_target: float

	if _is_mining:
		# Simple Minecraft-like looped hit swing on active arm.
		var cycle_period: float = 1.0 / mine_cycle_speed
		var t: float = fmod(_mine_time, cycle_period) / cycle_period
		var arm_deg: float = lerp(mine_raise_deg, mine_strike_deg, (sin(t * TAU) + 1.0) * 0.5)
		active_arm_target  = deg_to_rad(arm_deg)
		passive_arm_target = deg_to_rad(mine_passive_deg)

	elif _is_placing:
		# One-shot use/place swing.
		var t: float = clamp(_place_time / place_duration, 0.0, 1.0)
		var arm_deg: float = lerp(place_raise_deg, place_extend_deg, sin(t * PI))
		active_arm_target  = deg_to_rad(arm_deg)
		passive_arm_target = 0.0

	elif is_jumping:
		active_arm_target  =  deg_to_rad(jump_arm_deg)
		passive_arm_target = -deg_to_rad(jump_arm_deg)

	elif is_falling:
		active_arm_target  =  deg_to_rad(fall_arm_deg)
		passive_arm_target = -deg_to_rad(fall_arm_deg)

	elif is_walking:
		var swing: float   = sin(_walk_time * walk_cycle_speed) * deg_to_rad(walk_arm_amp)
		active_arm_target  = -swing
		passive_arm_target =  swing

	else:
		var breathe: float = sin(_idle_time * idle_breathe_speed) * deg_to_rad(idle_breathe_amp)
		active_arm_target  = breathe
		passive_arm_target = breathe

	active_arm.rotation  = lerp_angle(active_arm.rotation,  active_arm_target,  a_t)
	passive_arm.rotation = lerp_angle(passive_arm.rotation, passive_arm_target, a_t)
