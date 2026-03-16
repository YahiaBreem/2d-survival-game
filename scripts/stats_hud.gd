extends Control

# ---------------------------------------------------------------------------
# STATS HUD — Always-visible health hearts and hunger icons.
#
# Draws 10 heart icons (left of center) and 10 food icons (right of center)
# directly above the hotbar, using your spritesheet for all icons.
#
# SCENE SETUP:
#   Add this as a sibling of HotbarHUD inside the same CanvasLayer:
#
#   CanvasLayer  "HotbarLayer"  (Layer = 10)
#     ├─ Control  "HotbarHUD"   ← hotbar_hud.gd   (already set up)
#     └─ Control  "StatsHUD"    ← THIS script
#          • Anchor Preset → Full Rect
#          • Mouse Filter  → Ignore
#
#   In the Inspector, assign:
#     • stats_texture → your icons spritesheet PNG  (54×45)
#
# SPRITESHEET LAYOUT (9×9 px per icon, no gaps):
#   heart_empty : Rect2( 0,  0, 9, 9)   — r0c0
#   heart_full  : Rect2(36,  0, 9, 9)   — r0c4
#   heart_half  : Rect2(45,  0, 9, 9)   — r0c5
#   food_empty  : Rect2( 0,  9, 9, 9)   — r1c0
#   food_full   : Rect2( 9,  9, 9, 9)   — r1c1
#   food_half   : Rect2(18,  9, 9, 9)   — r1c2
#
# DEPENDENCIES: Autoloads — PlayerStats
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# EXPORT — assign your icons spritesheet in the Inspector
# ---------------------------------------------------------------------------
@export var stats_texture: Texture2D = null

# ---------------------------------------------------------------------------
# SPRITESHEET REGIONS  (pixel coords, 9×9 each, no gaps)
# ---------------------------------------------------------------------------
const REGION_HEART_EMPTY := Rect2( 0,  0, 9, 9)
const REGION_HEART_FULL  := Rect2(36,  0, 9, 9)
const REGION_HEART_HALF  := Rect2(45,  0, 9, 9)
const REGION_FOOD_EMPTY  := Rect2( 0,  9, 9, 9)
const REGION_FOOD_FULL   := Rect2( 9,  9, 9, 9)
const REGION_FOOD_HALF   := Rect2(18,  9, 9, 9)

# ---------------------------------------------------------------------------
# CONSTANTS — must match hotbar_hud.gd values so rows align
# ---------------------------------------------------------------------------
const HOTBAR_SCALE:   int = 3          # same SCALE as hotbar_hud.gd
const HOTBAR_BAR_H:   int = 22 * HOTBAR_SCALE   # 66 px
const HOTBAR_MARGIN:  int = 8          # same BOTTOM_MARGIN as hotbar_hud.gd

# Each icon is 9 source px, scaled up
const ICON_SIZE:      int = 9 * HOTBAR_SCALE     # 27 px on screen
const ICON_GAP:       int = 2          # px between icons in a row
const ROW_GAP:        int = 6          # px between stats row and top of hotbar

# 10 icons per stat = 20 half-points total
const ICON_COUNT:     int = 10
const LOW_HEALTH_SHAKE_THRESHOLD: int = 6
const LOW_HUNGER_WOBBLE_THRESHOLD: int = 6
const HEART_SHAKE_PIXELS: float = 2.0
const HUNGER_WOBBLE_PIXELS: float = 1.5
const HEART_SHAKE_SPEED: float = 28.0
const HUNGER_WOBBLE_SPEED: float = 10.0

# ---------------------------------------------------------------------------
# CACHED ATLAS TEXTURES  (built once in _ready)
# ---------------------------------------------------------------------------
var _tex_heart_empty: AtlasTexture = null
var _tex_heart_full:  AtlasTexture = null
var _tex_heart_half:  AtlasTexture = null
var _tex_food_empty:  AtlasTexture = null
var _tex_food_full:   AtlasTexture = null
var _tex_food_half:   AtlasTexture = null

# ---------------------------------------------------------------------------
# ICON NODES
# Four arrays of 10 TextureRects each:
#   - base empty icons (always visible)
#   - overlay icons (full/half/hidden)
# ---------------------------------------------------------------------------
var _heart_base_icons: Array = []      # Array[TextureRect]
var _heart_overlay_icons: Array = []   # Array[TextureRect]
var _food_base_icons: Array = []       # Array[TextureRect]
var _food_overlay_icons: Array = []    # Array[TextureRect]
var _heart_base_positions: Array = []  # Array[Vector2]
var _food_base_positions: Array = []   # Array[Vector2]

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if stats_texture == null:
		push_error("StatsHUD: 'stats_texture' is not set in the Inspector!")
		return

	_build_atlas_textures()
	_build_icon_nodes()
	_reposition()
	_refresh_hearts(PlayerStats.health)
	_refresh_food(PlayerStats.hunger)

	PlayerStats.health_changed.connect(_refresh_hearts)
	PlayerStats.hunger_changed.connect(_refresh_food)

# ---------------------------------------------------------------------------
# BUILD ATLAS TEXTURES — crop the spritesheet once and cache
# ---------------------------------------------------------------------------
func _build_atlas_textures() -> void:
	_tex_heart_empty = _make_atlas(REGION_HEART_EMPTY)
	_tex_heart_full  = _make_atlas(REGION_HEART_FULL)
	_tex_heart_half  = _make_atlas(REGION_HEART_HALF)
	_tex_food_empty  = _make_atlas(REGION_FOOD_EMPTY)
	_tex_food_full   = _make_atlas(REGION_FOOD_FULL)
	_tex_food_half   = _make_atlas(REGION_FOOD_HALF)

func _make_atlas(region: Rect2) -> AtlasTexture:
	var atlas        := AtlasTexture.new()
	atlas.atlas       = stats_texture
	atlas.region      = region
	atlas.filter_clip = true
	return atlas

# ---------------------------------------------------------------------------
# BUILD ICON NODES — 10 hearts + 10 food TextureRects
# ---------------------------------------------------------------------------
func _build_icon_nodes() -> void:
	for i in ICON_COUNT:
		var hb: TextureRect = _make_icon_node("HeartBase%d" % i)
		hb.texture = _tex_heart_empty
		_heart_base_icons.append(hb)

		var ho: TextureRect = _make_icon_node("HeartOverlay%d" % i)
		ho.visible = false
		_heart_overlay_icons.append(ho)

		var fb: TextureRect = _make_icon_node("FoodBase%d" % i)
		fb.texture = _tex_food_empty
		_food_base_icons.append(fb)

		var fo: TextureRect = _make_icon_node("FoodOverlay%d" % i)
		fo.visible = false
		_food_overlay_icons.append(fo)

func _make_icon_node(node_name: String) -> TextureRect:
	var tr              := TextureRect.new()
	tr.name              = node_name
	tr.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	tr.size              = Vector2(ICON_SIZE, ICON_SIZE)
	tr.expand_mode       = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode      = TextureRect.STRETCH_SCALE
	tr.mouse_filter      = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr

# ---------------------------------------------------------------------------
# REPOSITION — places all icons at the correct screen position.
# Hearts: left half, centered on screen.
# Food:   right half, centered on screen.
# Both sit directly above the hotbar.
# ---------------------------------------------------------------------------
func _reposition() -> void:
	var vp_size: Vector2  = get_viewport_rect().size

	# Y: sit above the hotbar
	var hotbar_top_y: float = vp_size.y - HOTBAR_BAR_H - HOTBAR_MARGIN
	var row_y: float        = hotbar_top_y - ICON_SIZE - ROW_GAP

	# Total width of one row of 10 icons
	var row_w: float = ICON_COUNT * ICON_SIZE + (ICON_COUNT - 1) * ICON_GAP

	# Center point of the screen
	var cx: float = vp_size.x / 2.0

	# Hearts start at center-left, food starts at center-right
	# Small center gap equal to ICON_GAP keeps them separated
	var hearts_x: float = cx - row_w - ICON_GAP
	var food_x:   float = cx + ICON_GAP

	for i in ICON_COUNT:
		var offset: float = i * (ICON_SIZE + ICON_GAP)
		var heart_pos: Vector2 = Vector2(hearts_x + offset, row_y)
		var food_pos: Vector2  = Vector2(food_x + offset, row_y)
		if _heart_base_positions.size() <= i:
			_heart_base_positions.append(heart_pos)
		else:
			_heart_base_positions[i] = heart_pos
		if _food_base_positions.size() <= i:
			_food_base_positions.append(food_pos)
		else:
			_food_base_positions[i] = food_pos
		(_heart_base_icons[i] as TextureRect).position = heart_pos
		(_heart_overlay_icons[i] as TextureRect).position = heart_pos
		(_food_base_icons[i] as TextureRect).position = food_pos
		(_food_overlay_icons[i] as TextureRect).position = food_pos

# ---------------------------------------------------------------------------
# PROCESS — reposition on viewport resize
# ---------------------------------------------------------------------------
var _last_vp_size: Vector2 = Vector2.ZERO
var _fx_time: float = 0.0

func _process(delta: float) -> void:
	_fx_time += delta
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size != _last_vp_size:
		_last_vp_size = vp_size
		_reposition()
	_apply_low_stat_effects()

func _apply_low_stat_effects() -> void:
	var low_health: bool = PlayerStats.health <= LOW_HEALTH_SHAKE_THRESHOLD
	var low_hunger: bool = PlayerStats.hunger <= LOW_HUNGER_WOBBLE_THRESHOLD

	for i in ICON_COUNT:
		var heart_base: Vector2 = _heart_base_positions[i]
		var food_base: Vector2 = _food_base_positions[i]
		var heart_offset := Vector2.ZERO
		var food_offset := Vector2.ZERO

		if low_health:
			var dir: float = -1.0 if (i % 2 == 0) else 1.0
			var jitter: float = sin(_fx_time * HEART_SHAKE_SPEED + float(i) * 0.9) * HEART_SHAKE_PIXELS
			heart_offset.y = jitter
			heart_offset.x = dir * abs(jitter) * 0.35

		if low_hunger:
			food_offset.y = sin(_fx_time * HUNGER_WOBBLE_SPEED + float(i) * 0.8) * HUNGER_WOBBLE_PIXELS

		(_heart_base_icons[i] as TextureRect).position = heart_base + heart_offset
		(_heart_overlay_icons[i] as TextureRect).position = heart_base + heart_offset
		(_food_base_icons[i] as TextureRect).position = food_base + food_offset
		(_food_overlay_icons[i] as TextureRect).position = food_base + food_offset

# ---------------------------------------------------------------------------
# REFRESH HEARTS
# health is 0–20. Each icon covers 2 points.
#   icon i covers points [i*2, i*2+1]
#   full  = value >= i*2 + 2
#   half  = value == i*2 + 1
#   empty = value <= i*2
# ---------------------------------------------------------------------------
func _refresh_hearts(value: int) -> void:
	for i in ICON_COUNT:
		var tr: TextureRect = _heart_overlay_icons[i] as TextureRect
		var points: int     = value - i * 2
		if points >= 2:
			tr.texture = _tex_heart_full
			tr.visible = true
		elif points == 1:
			tr.texture = _tex_heart_half
			tr.visible = true
		else:
			tr.visible = false

# ---------------------------------------------------------------------------
# REFRESH FOOD
# hunger is 0–20. Same half-point logic as hearts.
# ---------------------------------------------------------------------------
func _refresh_food(value: int) -> void:
	for i in ICON_COUNT:
		var tr: TextureRect = _food_overlay_icons[i] as TextureRect
		var points: int     = value - (ICON_COUNT - 1 - i) * 2
		if points >= 2:
			tr.texture = _tex_food_full
			tr.visible = true
		elif points == 1:
			tr.texture = _tex_food_half
			tr.visible = true
		else:
			tr.visible = false
