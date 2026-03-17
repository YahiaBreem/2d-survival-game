extends Control

# ---------------------------------------------------------------------------
# HOTBAR HUD — Always-visible hotbar using your spritesheet texture.
#
# SCENE SETUP (do this once in the editor):
#   1. In your main scene, add a CanvasLayer node.
#      • Name it "HotbarLayer"
#      • Set its "Layer" property to 10
#   2. Add a Control node as a child of HotbarLayer.
#      • Name it "HotbarHUD"
#      • Attach THIS script to it
#      • Set Anchor Preset → "Full Rect"  (so it fills the viewport)
#      • Set Mouse Filter → "Ignore"
#   3. In the Inspector for HotbarHUD, set the exported variable:
#      • hotbar_texture → your hotbar.png file
#
# TEXTURE LAYOUT (hotbar.png — 182×46):
#   Top region    (0,  0, 182, 22) — the 9-slot bar strip
#   Bottom region (0, 22,  24, 24) — the selector square
#   Each slot is 20×22 px inside the bar strip.
#   Slot 0 starts at x=0, slot N starts at x = N * 20.
#
# DEPENDENCIES: Autoloads — Inventory, ItemRegistry
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# EXPORTS — set hotbar_texture in the Inspector
# ---------------------------------------------------------------------------
@export var hotbar_texture: Texture2D = null

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------

# Texture regions (pixel coords inside hotbar.png)
const BAR_REGION:      Rect2 = Rect2(0,  0,  182, 22)   # full 9-slot bar
const SEL_REGION:      Rect2 = Rect2(0,  22,  24, 24)   # selector square
const SLOT_TEX_W:      int   = 20    # width of one slot in the texture
const SLOT_TEX_H:      int   = 22    # height of the bar strip

# Display scale — increase for bigger HUD (2 = Minecraft-style pixel doubling)
const SCALE:           int   = 3

# Derived display sizes (all in screen pixels)
const BAR_W:           int   = 182 * SCALE   # 546
const BAR_H:           int   = 22  * SCALE   # 66
const SLOT_W:          int   = 20  * SCALE   # 60  — screen width of one slot
const SEL_W:           int   = 24  * SCALE   # 72
const SEL_H:           int   = 24  * SCALE   # 72

const BOTTOM_MARGIN:   int   = 8             # px gap from screen bottom edge

# Icon inset inside each slot (screen pixels)
const ICON_MARGIN:     int   = SCALE * 4     # 12 px

# ---------------------------------------------------------------------------
# INTERNAL NODES (built in _ready)
# ---------------------------------------------------------------------------
var _bar_rect:    TextureRect = null   # the bar background strip
var _sel_rect:    TextureRect = null   # the moving selector square
var _icons:       Array       = []     # Array[TextureRect]  size=9
var _counts:      Array       = []     # Array[Label]        size=9

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	# This Control fills the viewport but never eats mouse input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_hud()
	_refresh_all()
	_update_selector(Inventory.selected_hotbar_slot)

	Inventory.inventory_changed.connect(_refresh_all)
	Inventory.hotbar_slot_changed.connect(_update_selector)

# ---------------------------------------------------------------------------
# BUILD — called once; constructs all child nodes procedurally
# ---------------------------------------------------------------------------
func _build_hud() -> void:
	if hotbar_texture == null:
		push_error("HotbarHUD: 'hotbar_texture' is not set in the Inspector!")
		return

	# --- Bar background ---
	_bar_rect = TextureRect.new()
	_bar_rect.name         = "Bar"
	_bar_rect.texture      = _make_atlas(BAR_REGION)
	_bar_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_bar_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bar_rect.custom_minimum_size = Vector2(BAR_W, BAR_H)
	_bar_rect.size                = Vector2(BAR_W, BAR_H)
	_bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_rect)

	# --- Selector square (child of bar so it shares the same origin) ---
	_sel_rect = TextureRect.new()
	_sel_rect.name         = "Selector"
	_sel_rect.texture      = _make_atlas(SEL_REGION)
	_sel_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_sel_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_sel_rect.custom_minimum_size = Vector2(SEL_W, SEL_H)
	_sel_rect.size                = Vector2(SEL_W, SEL_H)
	_sel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Selector is slightly taller than the bar; offset it upward so it
	# wraps around the bar slot symmetrically.
	# vertical center: bar center = BAR_H/2; sel center = SEL_H/2
	# So top of selector = BAR_H/2 - SEL_H/2
	_sel_rect.position.y = float(BAR_H) / 2.0 - float(SEL_H) / 2.0
	_bar_rect.add_child(_sel_rect)

	# --- Per-slot icon + count label ---
	for i in Inventory.HOTBAR_SIZE:
		# Icon
		var icon := TextureRect.new()
		icon.name          = "Icon%d" % i
		icon.expand_mode   = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(SLOT_W - ICON_MARGIN * 2,
										   BAR_H  - ICON_MARGIN * 2)
		icon.size = icon.custom_minimum_size
		icon.position = Vector2(i * SLOT_W + ICON_MARGIN, ICON_MARGIN)
		_bar_rect.add_child(icon)
		_icons.append(icon)

		# Count label
		var lbl := Label.new()
		lbl.name         = "Count%d" % i
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
		var lbl_w: int = SLOT_W - 4
		var lbl_h: int = 16
		lbl.custom_minimum_size = Vector2(lbl_w, lbl_h)
		lbl.size = lbl.custom_minimum_size
		lbl.position = Vector2(i * SLOT_W + (SLOT_W - lbl_w) / 2,
							   BAR_H - lbl_h - 2)
		var font_size: int = max(8, SCALE * 4)
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color",         Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size",    4)
		_bar_rect.add_child(lbl)
		_counts.append(lbl)

	# Position the bar at the bottom-center of the screen
	_reposition()

# ---------------------------------------------------------------------------
# REPOSITION — places the bar at bottom-center; called on resize
# ---------------------------------------------------------------------------
func _reposition() -> void:
	if _bar_rect == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	_bar_rect.position = Vector2(
		floor((vp_size.x - BAR_W) / 2.0),
		vp_size.y - BAR_H - BOTTOM_MARGIN
	)

# ---------------------------------------------------------------------------
# PROCESS — reposition if the viewport was resized
# ---------------------------------------------------------------------------
var _last_vp_size: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size != _last_vp_size:
		_last_vp_size = vp_size
		_reposition()

# ---------------------------------------------------------------------------
# REFRESH — redraw all 9 slot icons/counts from Inventory data
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	for i in Inventory.HOTBAR_SIZE:
		_draw_slot(i, Inventory.hotbar[i])

func _draw_slot(index: int, slot: Dictionary) -> void:
	var icon:  TextureRect = _icons[index]  as TextureRect
	var count: Label       = _counts[index] as Label

	if slot.is_empty() or not slot.has("item_name"):
		icon.texture = null
		count.text   = ""
		return

	icon.texture = ItemRegistry.get_texture(slot["item_name"])
	var n: int = slot.get("count", 1)
	count.text = "" if n <= 1 else str(n)

# ---------------------------------------------------------------------------
# SELECTOR — slide the selector rect to sit over the active slot
# ---------------------------------------------------------------------------
func _update_selector(selected: int) -> void:
	if _sel_rect == null:
		return
	# Center the selector horizontally over its slot.
	# Slot N occupies x = [N*SLOT_W, N*SLOT_W + SLOT_W).
	var slot_center_x: float = selected * SLOT_W + SLOT_W / 2.0
	_sel_rect.position.x = slot_center_x - SEL_W / 2.0

# ---------------------------------------------------------------------------
# HELPER — create an AtlasTexture that crops hotbar_texture to a sub-region
# ---------------------------------------------------------------------------
func _make_atlas(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas  = hotbar_texture
	atlas.region = region
	return atlas
