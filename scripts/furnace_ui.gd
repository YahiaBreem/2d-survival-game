# ---------------------------------------------------------------------------
# FURNACE UI
# ---------------------------------------------------------------------------
extends Control

const COLOR_SLOT_NORMAL:   Color = Color(0.0, 0.0, 0.0, 0.0)
const COLOR_SLOT_HOVER:    Color = Color(1.0, 1.0, 1.0, 0.15)
const COLOR_SLOT_SELECTED: Color = Color(1.0, 1.0, 1.0, 0.3)
const COLOR_RESULT_READY:  Color = Color(0.3, 1.0, 0.3, 0.25)
const ICON_MARGIN:         int   = 2

const SMELT_TIME: float = 10.0

const SMELT_RECIPES: Dictionary = {
	"Iron Ore":  "Iron Ingot",
	"Copper Ore": "Copper Ingot",
	"Gold Ore": "Gold Ingot",
	"Titanium Ore": "Titanium Ingot",
	"Coal Ore":  "Coal",
	"Oak Log":   "Coal",
	"Birch Log": "Coal",
	"Sand":      "Stone",
}

# ---------------------------------------------------------------------------
var input_slot:   Control = null
var fuel_slot:    Control = null
var result_slot:  Control = null
var bag_slots:    Array   = []
var hotbar_slots: Array   = []

var input_item:  Dictionary = {}
var fuel_item:   Dictionary = {}
var output_item: Dictionary = {}

var fuel_time_remaining: float = 0.0
var fuel_time_total:     float = 0.0
var smelt_progress:      float = 0.0
var _is_smelting:        bool  = false

var _lmb_held: bool = false
var _rmb_held: bool = false

@onready var progress_bar: ProgressBar = get_node_or_null("ProgressBar")
@onready var fuel_bar:     ProgressBar = get_node_or_null("FuelBar")

# World-anchor support
var _block_world_pos:  Vector2     = Vector2.ZERO
var _player:           Node2D      = null
var _canvas_layer:     CanvasLayer = null
const AUTO_CLOSE_DISTANCE: float   = 200.0
const BLOCK_OFFSET: Vector2        = Vector2(0.0, -48.0)

@export_group("UI")
@export var ui_scale: float = 1.2

# ---------------------------------------------------------------------------
func _ready() -> void:
	_collect_slots()
	_build_slot_visuals()
	_connect_slot_signals()

	Inventory.inventory_changed.connect(_refresh_bag_hotbar)
	Inventory.hotbar_slot_changed.connect(_update_hotbar_selection)

	_canvas_layer = get_parent() as CanvasLayer
	_player       = get_tree().get_first_node_in_group("player") as Node2D
	scale = Vector2.ONE * ui_scale

	visible = false
	_refresh_all()

# ---------------------------------------------------------------------------
func open(block_world_pos: Vector2 = Vector2.ZERO) -> void:
	_block_world_pos = block_world_pos
	visible = true
	_update_canvas_position()
	_refresh_all()

func close() -> void:
	if not visible:
		return
	visible = false
	_end_drag()
	Inventory.drop_cursor_to_inventory()

func _process(delta: float) -> void:
	if not visible:
		return
	_update_canvas_position()
	if _player != null and _block_world_pos != Vector2.ZERO:
		if _player.global_position.distance_to(_block_world_pos) > AUTO_CLOSE_DISTANCE:
			close()
			return
	_tick_smelting(delta)

func _update_canvas_position() -> void:
	if _canvas_layer == null:
		return
	var screen_pos: Vector2 = _world_to_screen(_block_world_pos)
	var bg: TextureRect = get_child(0) as TextureRect
	var ui_size: Vector2 = bg.size if bg != null and bg.size != Vector2.ZERO \
						else Vector2(200.0, 200.0)
	ui_size *= ui_scale
	_canvas_layer.offset = screen_pos + BLOCK_OFFSET - Vector2(ui_size.x * 0.5, ui_size.y)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d() as Camera2D
	if cam == null:
		return world_pos
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	return (world_pos - cam.global_position) * cam.zoom + vp_size * 0.5

# ---------------------------------------------------------------------------
# SMELTING
# ---------------------------------------------------------------------------
func _tick_smelting(delta: float) -> void:
	var can_smelt := _can_smelt()

	if fuel_time_remaining > 0.0:
		fuel_time_remaining -= delta
		if fuel_time_remaining < 0.0:
			fuel_time_remaining = 0.0

	if fuel_time_remaining <= 0.0 and can_smelt:
		if not fuel_item.is_empty():
			var burn := ItemRegistry.get_fuel_time(fuel_item["item_name"])
			if burn > 0.0:
				fuel_time_total     = burn
				fuel_time_remaining = burn
				fuel_item["count"] -= 1
				if fuel_item["count"] <= 0:
					fuel_item = {}
				_refresh_fuel_slot()

	_is_smelting = can_smelt and fuel_time_remaining > 0.0
	if _is_smelting:
		smelt_progress += delta
		if smelt_progress >= SMELT_TIME:
			smelt_progress = 0.0
			_complete_smelt()
	else:
		if smelt_progress > 0.0:
			smelt_progress = max(0.0, smelt_progress - delta * 2.0)

	_update_progress_bars()

func _can_smelt() -> bool:
	if input_item.is_empty():
		return false
	var result_name := _get_smelt_result(input_item["item_name"])
	if result_name == "":
		return false
	if output_item.is_empty():
		return true
	if output_item["item_name"] != result_name:
		return false
	return output_item["count"] < ItemRegistry.get_stack_size(result_name)

func _get_smelt_result(item_name: String) -> String:
	return SMELT_RECIPES.get(item_name, "")

func _complete_smelt() -> void:
	var result_name := _get_smelt_result(input_item["item_name"])
	if result_name == "":
		return
	input_item["count"] -= 1
	if input_item["count"] <= 0:
		input_item = {}
	if output_item.is_empty():
		output_item = {"item_name": result_name, "count": 1}
	else:
		output_item["count"] += 1
	_refresh_input_slot()
	_refresh_output_slot()

func _update_progress_bars() -> void:
	if progress_bar != null:
		progress_bar.value = (smelt_progress / SMELT_TIME) * 100.0
	if fuel_bar != null:
		fuel_bar.value = (fuel_time_remaining / fuel_time_total * 100.0) \
						if fuel_time_total > 0.0 else 0.0

# ---------------------------------------------------------------------------
# NODE COLLECTION
# ---------------------------------------------------------------------------
func _collect_slots() -> void:
	input_slot  = find_child("furnace_slot0",       true, false) as Control
	fuel_slot   = find_child("furnace_slot1",       true, false) as Control
	result_slot = find_child("furnace_slot_result", true, false) as Control

	if input_slot  == null: push_error("FurnaceUI: missing 'furnace_slot0'")
	if fuel_slot   == null: push_error("FurnaceUI: missing 'furnace_slot1'")
	if result_slot == null: push_error("FurnaceUI: missing 'furnace_slot_result'")

	for i in Inventory.BAG_SIZE:
		var node := find_child("inventory_slot%d" % i, true, false)
		if node == null: push_error("FurnaceUI: missing 'inventory_slot%d'" % i)
		bag_slots.append(node)

	for i in range(1, Inventory.HOTBAR_SIZE + 1):
		var node := find_child("hotbar_slot%d" % i, true, false)
		if node == null: push_error("FurnaceUI: missing 'hotbar_slot%d'" % i)
		hotbar_slots.append(node)

# ---------------------------------------------------------------------------
# BUILD VISUALS
# ---------------------------------------------------------------------------
func _build_slot_visuals() -> void:
	var all: Array = bag_slots + hotbar_slots
	for node in [input_slot, fuel_slot, result_slot]:
		if node != null:
			all.append(node)
	for node in all:
		if node != null:
			_init_slot(node)

func _init_slot(node: Control) -> void:
	if node.find_child("Icon", false, false) != null:
		return

	var icon := TextureRect.new()
	icon.name          = "Icon"
	icon.anchor_left   = 0.0
	icon.anchor_top    = 0.0
	icon.anchor_right  = 1.0
	icon.anchor_bottom = 1.0
	icon.offset_left   = ICON_MARGIN
	icon.offset_top    = ICON_MARGIN
	icon.offset_right  = -ICON_MARGIN
	icon.offset_bottom = -ICON_MARGIN
	icon.expand_mode   = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	node.add_child(icon)

	var lbl := Label.new()
	lbl.name                 = "Count"
	lbl.anchor_left          = 1.0
	lbl.anchor_top           = 1.0
	lbl.anchor_right         = 1.0
	lbl.anchor_bottom        = 1.0
	lbl.offset_left          = -18
	lbl.offset_top           = -12
	lbl.offset_right         = -1
	lbl.offset_bottom        = -1
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 7)
	lbl.add_theme_color_override("font_color",         Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	node.add_child(lbl)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_NORMAL
	node.add_theme_stylebox_override("panel", style)

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (
		Input.is_action_just_pressed("toggle_inventory") or
		Input.is_action_just_pressed("interact")
	):
		close()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if not mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT and _lmb_held:
				_lmb_held = false
				Inventory.end_drag()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and _rmb_held:
				_rmb_held = false
				Inventory.end_drag()

# ---------------------------------------------------------------------------
# SLOT CLICK HANDLERS
# ---------------------------------------------------------------------------
func _on_input_slot_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	# Only allow smeltable items
	if Inventory.has_cursor():
		if not SMELT_RECIPES.has(Inventory.cursor["item_name"]):
			return
	var arr := [input_item]
	if mb.button_index == MOUSE_BUTTON_LEFT:
		Inventory.handle_slot_click(arr, 0, false, false)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		Inventory.handle_slot_click(arr, 0, true, false)
	input_item = arr[0]
	_refresh_input_slot()

func _on_fuel_slot_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	# Only allow fuel items
	if Inventory.has_cursor():
		if ItemRegistry.get_fuel_time(Inventory.cursor["item_name"]) <= 0.0:
			return
	var arr := [fuel_item]
	if mb.button_index == MOUSE_BUTTON_LEFT:
		Inventory.handle_slot_click(arr, 0, false, false)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		Inventory.handle_slot_click(arr, 0, true, false)
	fuel_item = arr[0]
	_refresh_fuel_slot()

func _on_result_slot_click(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if output_item.is_empty():
		return

	var res_name:  String = output_item["item_name"]
	var res_count: int    = output_item["count"]
	var max_stack: int    = ItemRegistry.get_stack_size(res_name)

	var can_take: bool = not Inventory.has_cursor() or (
		Inventory.cursor["item_name"] == res_name and
		Inventory.cursor["count"] + res_count <= max_stack
	)
	if not can_take:
		return

	if not Inventory.has_cursor():
		Inventory.set_cursor(res_name, res_count)
	else:
		Inventory.set_cursor(res_name, Inventory.cursor["count"] + res_count)
	output_item = {}
	_refresh_output_slot()

func _on_bag_slot_click(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.shift_pressed:
			Inventory.handle_shift_click(Inventory.bag, index, Inventory.hotbar, false)
		elif mb.double_click:
			Inventory.handle_double_click([Inventory.bag, Inventory.hotbar])
		else:
			var had_cursor := Inventory.has_cursor()
			Inventory.handle_slot_click(Inventory.bag, index, false, false)
			if not had_cursor and Inventory.has_cursor():
				_lmb_held = true
				Inventory.begin_drag(MOUSE_BUTTON_LEFT)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if Inventory.has_cursor():
			# Place 1 immediately on click, then arm drag for subsequent slots
			Inventory.handle_slot_click(Inventory.bag, index, true, false)
			_rmb_held = true
			Inventory.begin_drag(MOUSE_BUTTON_RIGHT)
		else:
			Inventory.handle_slot_click(Inventory.bag, index, true, false)

func _on_bag_slot_entered(index: int) -> void:
	if _lmb_held or _rmb_held:
		Inventory.handle_drag_enter(Inventory.bag, index, false)

func _on_hotbar_slot_click(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.shift_pressed:
			Inventory.handle_shift_click(Inventory.hotbar, index, Inventory.bag, false)
		elif mb.double_click:
			Inventory.handle_double_click([Inventory.bag, Inventory.hotbar])
		else:
			Inventory.handle_slot_click(Inventory.hotbar, index, false, false)
			if not Inventory.has_cursor():
				Inventory.select_slot(index)
			else:
				_lmb_held = true
				Inventory.begin_drag(MOUSE_BUTTON_LEFT)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if Inventory.has_cursor():
			# Place 1 immediately on click, then arm drag for subsequent slots
			Inventory.handle_slot_click(Inventory.hotbar, index, true, false)
			_rmb_held = true
			Inventory.begin_drag(MOUSE_BUTTON_RIGHT)
		else:
			Inventory.handle_slot_click(Inventory.hotbar, index, true, false)

func _on_hotbar_slot_entered(index: int) -> void:
	if _lmb_held or _rmb_held:
		Inventory.handle_drag_enter(Inventory.hotbar, index, false)

func _end_drag() -> void:
	_lmb_held = false
	_rmb_held = false
	Inventory.end_drag()

# ---------------------------------------------------------------------------
# REFRESH
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_refresh_input_slot()
	_refresh_fuel_slot()
	_refresh_output_slot()
	_refresh_bag_hotbar()
	_update_hotbar_selection(Inventory.selected_hotbar_slot)

func _refresh_input_slot() -> void:
	if input_slot != null:
		_draw_slot(input_slot, input_item)

func _refresh_fuel_slot() -> void:
	if fuel_slot != null:
		_draw_slot(fuel_slot, fuel_item)

func _refresh_output_slot() -> void:
	if result_slot == null:
		return
	_draw_slot(result_slot, output_item)
	var style := result_slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = COLOR_RESULT_READY if not output_item.is_empty() \
						else COLOR_SLOT_NORMAL

func _refresh_bag_hotbar() -> void:
	for i in bag_slots.size():
		if bag_slots[i] == null or i >= Inventory.bag.size():
			continue
		_draw_slot(bag_slots[i], Inventory.bag[i])
	for i in hotbar_slots.size():
		if hotbar_slots[i] == null or i >= Inventory.hotbar.size():
			continue
		_draw_slot(hotbar_slots[i], Inventory.hotbar[i])

func _draw_slot(node: Control, slot: Dictionary) -> void:
	var icon  := node.find_child("Icon",  false, false) as TextureRect
	var count := node.find_child("Count", false, false) as Label
	if icon == null:
		return
	if slot.is_empty() or not slot.has("item_name"):
		icon.texture = null
		if count != null: count.text = ""
		return
	icon.texture = ItemRegistry.get_texture(slot["item_name"])
	if count != null:
		var n: int = slot.get("count", 1)
		count.text = "" if n <= 1 else str(n)

# ---------------------------------------------------------------------------
# HOTBAR SELECTION
# ---------------------------------------------------------------------------
func _update_hotbar_selection(selected: int) -> void:
	for i in hotbar_slots.size():
		var node := hotbar_slots[i] as Control
		if node == null:
			continue
		var style := node.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		if i == selected:
			style.bg_color            = COLOR_SLOT_SELECTED
			style.border_color        = Color(1.0, 0.85, 0.2, 1.0)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
		else:
			style.bg_color            = COLOR_SLOT_NORMAL
			style.border_color        = Color(0.0, 0.0, 0.0, 0.0)
			style.border_width_left   = 0
			style.border_width_right  = 0
			style.border_width_top    = 0
			style.border_width_bottom = 0

# ---------------------------------------------------------------------------
# CONNECT SIGNALS
# ---------------------------------------------------------------------------
func _connect_slot_signals() -> void:
	if input_slot != null:
		input_slot.gui_input.connect(_on_input_slot_click)
		_add_hover(input_slot)

	if fuel_slot != null:
		fuel_slot.gui_input.connect(_on_fuel_slot_click)
		_add_hover(fuel_slot)

	if result_slot != null:
		result_slot.gui_input.connect(_on_result_slot_click)
		_add_hover(result_slot)

	for i in bag_slots.size():
		var node := bag_slots[i] as Control
		if node == null: continue
		var idx := i
		node.gui_input.connect(func(ev): _on_bag_slot_click(ev, idx))
		node.mouse_entered.connect(func(): _on_bag_slot_entered(idx))
		_add_hover(node)

	for i in hotbar_slots.size():
		var node := hotbar_slots[i] as Control
		if node == null: continue
		var idx := i
		node.gui_input.connect(func(ev): _on_hotbar_slot_click(ev, idx))
		node.mouse_entered.connect(func(): _on_hotbar_slot_entered(idx))
		_add_hover(node)

func _add_hover(node: Control) -> void:
	node.mouse_entered.connect(func() -> void: _set_highlight(node, true))
	node.mouse_exited.connect(func()  -> void: _set_highlight(node, false))

func _set_highlight(node: Control, hovered: bool) -> void:
	var style := node.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null: return
	style.bg_color = COLOR_SLOT_HOVER if hovered else COLOR_SLOT_NORMAL
