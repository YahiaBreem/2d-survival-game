# ---------------------------------------------------------------------------
# BLOCK BREAK EFFECT
# Spawns both chunk particles and a dust effect when a block is broken.
#
# SCENE STRUCTURE:
#   Node2D               <- root, attach this script
#     Chunks             <- CPUParticles2D
#     Dust               <- CPUParticles2D
#
# HOW IT WORKS:
#   - block_interaction.gd calls spawn() with the block's texture & position
#   - Chunks: 6-10 small spinning sprites that fly out and fall with gravity
#   - Dust:   many tiny pixels that puff outward and fade quickly
#   - The whole node deletes itself once particles finish
# ---------------------------------------------------------------------------
extends Node2D

@onready var chunks: CPUParticles2D = $Chunks
@onready var dust: CPUParticles2D   = $Dust

# ---------------------------------------------------------------------------
func setup(texture: Texture2D) -> void:
	_setup_chunks(texture)
	_setup_dust(texture)

	chunks.emitting = true
	dust.emitting   = true

	# Self-destruct after longest lifetime + a small buffer
	var longest: float = max(chunks.lifetime, dust.lifetime)
	await get_tree().create_timer(longest + 0.2).timeout
	queue_free()

# ---------------------------------------------------------------------------
func _setup_chunks(texture: Texture2D) -> void:
	chunks.texture                  = texture

	# Emission
	chunks.amount                   = 8
	chunks.lifetime                 = 0.6
	chunks.one_shot                 = true
	chunks.explosiveness            = 0.95   # all burst at once

	# Shape — emit from a small area around block center
	chunks.emission_shape           = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	chunks.emission_rect_extents    = Vector2(12.0, 12.0)

	# Direction & spread
	chunks.direction                = Vector2(0.0, -1.0)
	chunks.spread                   = 180.0  # full circle burst
	chunks.initial_velocity_min     = 60.0
	chunks.initial_velocity_max     = 130.0

	# Gravity pulls chunks down
	chunks.gravity                  = Vector2(0.0, 300.0)

	# Spin
	chunks.angular_velocity_min     = -180.0
	chunks.angular_velocity_max     =  180.0

	# Scale: small chunks (about 1/4 of block size)
	chunks.scale_amount_min         = 0.18
	chunks.scale_amount_max         = 0.28

	# Fade out toward end of life
	var chunk_gradient              := Gradient.new()
	chunk_gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	chunk_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	chunks.color_ramp               = chunk_gradient

# ---------------------------------------------------------------------------
func _setup_dust(texture: Texture2D) -> void:
	dust.texture                    = texture

	# Emission
	dust.amount                     = 20
	dust.lifetime                   = 0.35
	dust.one_shot                   = true
	dust.explosiveness              = 0.9

	# Tiny emit area
	dust.emission_shape             = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents      = Vector2(14.0, 14.0)

	# Spread outward in all directions, slower than chunks
	dust.direction                  = Vector2(0.0, -1.0)
	dust.spread                     = 180.0
	dust.initial_velocity_min       = 20.0
	dust.initial_velocity_max       = 55.0

	# Very slight gravity so dust drifts down gently
	dust.gravity                    = Vector2(0.0, 40.0)

	# No spin — dust is just tiny pixels
	dust.angular_velocity_min       = 0.0
	dust.angular_velocity_max       = 0.0

	# Very small — just pixel-sized specks
	dust.scale_amount_min           = 0.06
	dust.scale_amount_max           = 0.10

	# Fade out quickly
	var dust_gradient               := Gradient.new()
	dust_gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.7))
	dust_gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	dust.color_ramp                 = dust_gradient