# ---------------------------------------------------------------------------
# COW VISUAL
# Procedural animation for a quadruped using a single spritesheet.
#
# ---------------------------------------------------------------------------
# SPRITESHEET LAYOUT  (design your PNG to match these regions exactly)
# ---------------------------------------------------------------------------
#
#   All regions assume a 64×32 px sheet at 2x pixel art scale (32×16 source):
#
#   Region           x   y   w   h    Notes
#   ─────────────────────────────────────────────────────────────────────────
#   HEAD            0,  0, 16, 16    square head
#   BODY            16,  0, 24, 16    wide torso
#   FRONT_LEG_F     40,  0,  6, 16    front-right leg (rendered front)
#   FRONT_LEG_B     46,  0,  6, 16    front-left leg  (rendered back)
#   BACK_LEG_F      52,  0,  6, 16    rear-right leg  (rendered front)
#   BACK_LEG_B      58,  0,  6, 16    rear-left leg   (rendered back)
#
#   All coords in PIXELS on the actual PNG file.
#   Adjust the constants below if your sheet differs.
#
# ---------------------------------------------------------------------------
# SCENE TREE  (build Cow.tscn to match this exactly)
# ---------------------------------------------------------------------------
#
#   CharacterBody2D          ← mob_cow.gd
#   └── CollisionShape2D     ← CapsuleShape2D, ~18×28 px
#   └── Visual  (Node2D)     ← THIS script (cow_visual.gd)
#       ├── BackFrontLeg     (Node2D)  z_index = -1
#       │   └── Sprite2D
#       ├── BackRearLeg      (Node2D)  z_index = -1
#       │   └── Sprite2D
#       ├── Body             (Node2D)
#       │   └── Sprite2D
#       ├── Head             (Node2D)
#       │   └── Sprite2D
#       ├── FrontFrontLeg    (Node2D)
#       │   └── Sprite2D
#       └── FrontRearLeg     (Node2D)
#           └── Sprite2D
#
#   z_index -1 on back legs so they render behind the body.
#   All Sprite2D nodes: centered = false, texture_filter = Nearest.
# ---------------------------------------------------------------------------
extends Node2D

# ---------------------------------------------------------------------------
# SPRITESHEET REGIONS  — adjust to match your PNG
# ---------------------------------------------------------------------------
# Spritesheet: 56×24 px
# Body  = x:0  w:36  h:24
# Head  = x:36 w:12  h:24
# Leg   = x:48 w:8   h:24  (same region for all 4 legs)
const REGION_BODY:         Rect2 = Rect2( 0, 0, 36, 24)
const REGION_HEAD:         Rect2 = Rect2(36, 0, 12, 24)
const REGION_FRONT_LEG_F:  Rect2 = Rect2(48, 0,  8, 24)
const REGION_FRONT_LEG_B:  Rect2 = Rect2(48, 0,  8, 24)
const REGION_BACK_LEG_F:   Rect2 = Rect2(48, 0,  8, 24)
const REGION_BACK_LEG_B:   Rect2 = Rect2(48, 0,  8, 24)

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# ANIMATION PARAMETERS
# ---------------------------------------------------------------------------
@export_group("Walk")
@export var walk_cycle_speed: float = 8.0    # rad/s
@export var leg_amp_deg:      float = 28.0   # max leg swing in degrees

@export_group("Idle")
@export var idle_breathe_speed: float = 1.2
@export var idle_breathe_amp:   float = 1.5  # degrees, subtle

@export_group("Head")
@export var head_turn_speed:    float = 5.0  # lerp speed toward player
@export var head_max_angle_deg: float = 45.0 # clamp
@export var head_detect_range:  float = 220.0

@export_group("Transition")
@export var leg_lerp_speed:   float = 18.0
@export var head_lerp_speed:  float = 12.0

@export_group("Skin")
@export var spritesheet: Texture2D

# ---------------------------------------------------------------------------
# NODES — resolved at runtime by index, not by name.
# The Visual node must have children in this order:
#   0: BackFrontLeg  (z=-1)
#   1: BackRearLeg   (z=-1)
#   2: Body
#   3: Head
#   4: FrontFrontLeg
#   5: FrontRearLeg
# Name them anything you like — order is what matters.
# ---------------------------------------------------------------------------
var spr_head:         Sprite2D = null
var spr_body:         Sprite2D = null
var spr_front_leg_f:  Sprite2D = null
var spr_front_leg_b:  Sprite2D = null
var spr_back_leg_f:   Sprite2D = null
var spr_back_leg_b:   Sprite2D = null

var node_head:        Node2D   = null
var node_front_leg_f: Node2D   = null
var node_front_leg_b: Node2D   = null
var node_back_leg_f:  Node2D   = null
var node_back_leg_b:  Node2D   = null

# ---------------------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------------------
var _walk_time: float = 0.0
var _idle_time: float = 0.0
var _player:    Node2D = null

# ---------------------------------------------------------------------------
func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_find_nodes()
	if spritesheet != null:
		_apply_regions()

func _find_nodes() -> void:
	# Find all Node2D children of Visual — order: back_leg_b, back_leg_f, body, head, front_leg_f, front_leg_b
	# We identify them by z_index and position in child order.
	var children: Array[Node2D] = []
	for child in get_children():
		if child is Node2D:
			children.append(child as Node2D)
	
	if children.size() < 6:
		push_warning("CowVisual: expected 6 Node2D children, got %d. Check scene tree." % children.size())
		return
	
	# z_index layout:
	#   1 = back legs (render behind body)
	#   2 = body + head
	#   3 = front legs (render in front of body)
	var back_nodes:  Array[Node2D] = []
	var mid_nodes:   Array[Node2D] = []
	var front_nodes: Array[Node2D] = []
	for c in children:
		if c.z_index == 1:
			back_nodes.append(c)
		elif c.z_index == 2:
			mid_nodes.append(c)
		elif c.z_index == 3:
			front_nodes.append(c)
	
	# back_nodes[0]  = BackFrontLeg, back_nodes[1]  = BackRearLeg
	# mid_nodes[0]   = Body,         mid_nodes[1]   = Head
	# front_nodes[0] = FrontFrontLeg, front_nodes[1] = FrontRearLeg
	if back_nodes.size() >= 2:
		node_front_leg_b = back_nodes[0]
		node_back_leg_b  = back_nodes[1]
		spr_front_leg_b  = _get_sprite(back_nodes[0])
		spr_back_leg_b   = _get_sprite(back_nodes[1])

	if mid_nodes.size() >= 2:
		spr_body = _get_sprite(mid_nodes[0])
		node_head = mid_nodes[1]
		spr_head  = _get_sprite(mid_nodes[1])

	if front_nodes.size() >= 2:
		node_front_leg_f = front_nodes[0]
		node_back_leg_f  = front_nodes[1]
		spr_front_leg_f  = _get_sprite(front_nodes[0])
		spr_back_leg_f   = _get_sprite(front_nodes[1])
	
	print("CowVisual: nodes resolved — head=%s body=%s" % [
		node_head.name if node_head else "NULL",
		"OK" if spr_body else "NULL"
	])

func _get_sprite(parent: Node2D) -> Sprite2D:
	for child in parent.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

# ---------------------------------------------------------------------------
# PUBLIC — called by mob_cow.gd every physics frame
# ---------------------------------------------------------------------------
func update_animation(vel: Vector2, on_floor: bool, delta: float) -> void:
	_idle_time += delta
	var is_walking: bool = abs(vel.x) > 8.0 and on_floor
	if is_walking:
		_walk_time += delta

	_animate_legs(is_walking, delta)
	_animate_head(delta)

# ---------------------------------------------------------------------------
# LEGS
# Quadruped gait: front-left & back-right move together, then swap.
# Achieved by giving rear legs a half-phase offset (PI).
# ---------------------------------------------------------------------------
func _animate_legs(is_walking: bool, delta: float) -> void:
	var l_t: float = clamp(leg_lerp_speed * delta, 0.0, 1.0)

	var front_target: float
	var rear_target:  float

	if is_walking:
		var swing: float   = sin(_walk_time * walk_cycle_speed) * deg_to_rad(leg_amp_deg)
		front_target =  swing
		rear_target  = -swing   # opposite phase = natural trot
	else:
		# Idle breathe — very subtle bob
		var breathe: float = sin(_idle_time * idle_breathe_speed) * deg_to_rad(idle_breathe_amp)
		front_target = breathe
		rear_target  = breathe

	# Front pair: front leg (F) leads, back leg (B) opposite
	node_front_leg_f.rotation = lerp_angle(node_front_leg_f.rotation,  front_target, l_t)
	node_front_leg_b.rotation = lerp_angle(node_front_leg_b.rotation, -front_target, l_t)

	# Rear pair: half-phase offset relative to front
	node_back_leg_f.rotation  = lerp_angle(node_back_leg_f.rotation,   rear_target,  l_t)
	node_back_leg_b.rotation  = lerp_angle(node_back_leg_b.rotation,  -rear_target,  l_t)

# ---------------------------------------------------------------------------
# HEAD — rotates to look at the player when nearby
# ---------------------------------------------------------------------------
func _animate_head(delta: float) -> void:
	if node_head == null:
		return

	var target_rot: float = 0.0   # default: face forward

	if _player != null:
		var dist: float = global_position.distance_to(_player.global_position)
		if dist < head_detect_range:
			# Direction from head to player in local space
			var to_player: Vector2 = _player.global_position - node_head.global_position
			# Account for parent flip so angle is always relative to facing direction
			var local_dir: Vector2 = get_global_transform().basis_xform_inv(to_player)
			var angle: float = local_dir.angle()
			var limit: float = deg_to_rad(head_max_angle_deg)
			target_rot = clamp(angle, -limit, limit)

	var h_t: float = clamp(head_lerp_speed * delta, 0.0, 1.0)
	node_head.rotation = lerp_angle(node_head.rotation, target_rot, h_t)

# ---------------------------------------------------------------------------
# SPRITESHEET APPLICATION
# ---------------------------------------------------------------------------
func _apply_regions() -> void:
	_apply(spr_head,        spritesheet, REGION_HEAD)
	_apply(spr_body,        spritesheet, REGION_BODY)
	_apply(spr_front_leg_f, spritesheet, REGION_FRONT_LEG_F)
	_apply(spr_front_leg_b, spritesheet, REGION_FRONT_LEG_B)
	_apply(spr_back_leg_f,  spritesheet, REGION_BACK_LEG_F)
	_apply(spr_back_leg_b,  spritesheet, REGION_BACK_LEG_B)

func _apply(spr: Sprite2D, tex: Texture2D, region: Rect2) -> void:
	if spr == null:
		return
	spr.texture        = tex
	spr.region_enabled = true
	spr.region_rect    = region
