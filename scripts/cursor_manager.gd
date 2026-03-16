extends Node

# ---------------------------------------------------------------------------
# CURSOR MANAGER — Autoload singleton
# Single cursor sprite on top of ALL UI. Shows item + count label.
# Setup: Add as Autoload named "CursorManager".
# ---------------------------------------------------------------------------

var _layer:  CanvasLayer = null
var _sprite: TextureRect = null
var _count:  Label       = null

func _ready() -> void:
	_layer       = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_sprite                     = TextureRect.new()
	_sprite.name                = "GlobalCursorSprite"
	_sprite.custom_minimum_size = Vector2(32, 32)
	_sprite.size                = Vector2(32, 32)
	_sprite.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_sprite.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_sprite.visible             = false
	_layer.add_child(_sprite)

	# Count label — bottom-right of the cursor sprite
	_count                  = Label.new()
	_count.name             = "CursorCount"
	_count.anchor_left      = 1.0
	_count.anchor_top       = 1.0
	_count.anchor_right     = 1.0
	_count.anchor_bottom    = 1.0
	_count.offset_left      = -18
	_count.offset_top       = -12
	_count.offset_right     = -1
	_count.offset_bottom    = -1
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	_count.add_theme_font_size_override("font_size", 7)
	_count.add_theme_color_override("font_color",         Color.WHITE)
	_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_count.add_theme_constant_override("outline_size", 3)
	_count.visible          = false
	_sprite.add_child(_count)

	Inventory.cursor_changed.connect(_on_cursor_changed)

func _process(_delta: float) -> void:
	if _sprite == null or not _sprite.visible:
		return
	var vp:       Viewport = get_viewport()
	var vp_size:  Vector2  = vp.get_visible_rect().size
	var win_size: Vector2  = Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	var scale: Vector2 = vp_size / win_size
	var mouse: Vector2 = vp.get_mouse_position() / scale
	_sprite.position   = mouse - Vector2(16.0, 16.0)

func _on_cursor_changed() -> void:
	if _sprite == null:
		return
	if not Inventory.has_cursor():
		_sprite.visible = false
		_count.visible  = false
		_sprite.texture = null
		return
	_sprite.texture = ItemRegistry.get_texture(Inventory.cursor["item_name"])
	_sprite.visible = true

	var n: int     = Inventory.cursor.get("count", 1)
	_count.text    = "" if n <= 1 else str(n)
	_count.visible = n > 1