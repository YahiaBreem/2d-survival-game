extends Control

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
const COLOR_SLOT_NORMAL:  Color = Color(0.0, 0.0, 0.0, 0.0)
const COLOR_SLOT_HOVER:   Color = Color(1.0, 1.0, 1.0, 0.15)
const COLOR_SLOT_SELECT:  Color = Color(1.0, 1.0, 1.0, 0.3)
const COLOR_RESULT_READY: Color = Color(0.3, 1.0, 0.3, 0.25)
const ICON_MARGIN: int = 2
const PLAYER_UI_OFFSET: Vector2 = Vector2(0.0, -120.0)

@export_group("UI")
@export var ui_scale: float = 1.2

@export_group("Follow Physics")
@export var follow_stiffness: float = 26.0
@export var follow_damping: float = 0.90
@export var max_follow_speed: float = 1800.0
@export var sway_strength: float = 0.12
@export var sway_max_radians: float = 0.16
@export var trail_from_velocity_scale: float = 0.10
@export var trail_offset_max: float = 60.0
@export var trail_response: float = 10.0

# ---------------------------------------------------------------------------
# VARIABLES
# ---------------------------------------------------------------------------
var bag_slots:    Array   = []
var hotbar_slots: Array   = []
var craft_slots:  Array   = []
var result_slot:  Control = null

var _lmb_held: bool = false
var _rmb_held: bool = false
var _player: Node2D = null
var _canvas_layer: CanvasLayer = null
var _root_control: Control = null
var _ui_pos: Vector2 = Vector2.ZERO
var _ui_vel: Vector2 = Vector2.ZERO
var _ui_initialized: bool = false
var _trail_offset: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# READY
# ---------------------------------------------------------------------------
func _ready() -> void:
	_collect_slots()
	_build_slot_visuals()
	_connect_slot_signals()

	Inventory.inventory_changed.connect(_refresh_all)
	Inventory.hotbar_slot_changed.connect(_update_hotbar_selection)
	Inventory.craft_changed.connect(_refresh_craft_result)

	visible = false
	scale = Vector2.ONE * ui_scale
	_canvas_layer = get_parent() as CanvasLayer
	_root_control = self
	_player = _find_player()
	_refresh_all()
	_update_hotbar_selection(Inventory.selected_hotbar_slot)

func _process(delta: float) -> void:
	if not visible:
		return
	_update_canvas_position(delta)

# ---------------------------------------------------------------------------
# COLLECT SLOT NODES
# ---------------------------------------------------------------------------
func _collect_slots() -> void:
	for i in Inventory.BAG_SIZE:
		var node := find_child("inventory_slot%d" % i, true, false)
		if node == null:
			push_error("InventoryUI: missing 'inventory_slot%d'" % i)
		bag_slots.append(node)

	for i in range(1, Inventory.HOTBAR_SIZE + 1):
		var node := find_child("hotbar_slot%d" % i, true, false)
		if node == null:
			push_error("InventoryUI: missing 'hotbar_slot%d'" % i)
		hotbar_slots.append(node)

	for i in range(1, Inventory.INV_CRAFT_SIZE + 1):
		var node := find_child("crafting_slot%d" % i, true, false)
		if node == null:
			node = find_child("crafting_slot_%d" % i, true, false)
		if node == null:
			push_error("InventoryUI: missing crafting_slot%d (tried with and without underscore)" % i)
		craft_slots.append(node)

	result_slot = find_child("crafting_slot_result", true, false) as Control
	if result_slot == null:
		push_error("InventoryUI: missing 'crafting_slot_result'")

# ---------------------------------------------------------------------------
# BUILD SLOT VISUALS
# ---------------------------------------------------------------------------
func _build_slot_visuals() -> void:
	var all: Array = bag_slots + hotbar_slots + craft_slots
	if result_slot != null:
		all.append(result_slot)
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

	# Count: bottom-right corner, small font
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
# INPUT — toggle, release drag on mouse-up anywhere
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and Input.is_action_just_pressed("toggle_inventory"):
		visible = !visible
		if visible:
			_snap_canvas_to_target()
		if not visible:
			Inventory.drop_cursor_to_inventory()
			Inventory.return_craft_grid(Inventory.inv_craft)
			_end_drag()

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
# SLOT INPUT
# ---------------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, array: Array,
		index: int, is_craft: bool) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return

	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.shift_pressed:
			var target: Array = _get_shift_target(array)
			Inventory.handle_shift_click(array, index, target, is_craft)
		elif mb.double_click:
			Inventory.handle_double_click([Inventory.bag, Inventory.hotbar, Inventory.inv_craft])
		else:
			var had_cursor := Inventory.has_cursor()
			Inventory.handle_slot_click(array, index, false, is_craft)
			# Only begin LMB drag when we just picked something UP (cursor was empty before)
			if not had_cursor and Inventory.has_cursor():
				_lmb_held = true
				Inventory.begin_drag(MOUSE_BUTTON_LEFT)

	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if Inventory.has_cursor():
			# Place 1 immediately on click, then arm drag for subsequent slots
			Inventory.handle_slot_click(array, index, true, is_craft)
			_rmb_held = true
			Inventory.begin_drag(MOUSE_BUTTON_RIGHT)
		else:
			Inventory.handle_slot_click(array, index, true, is_craft)

func _on_slot_mouse_entered(array: Array, index: int, is_craft: bool) -> void:
	if _lmb_held or _rmb_held:
		Inventory.handle_drag_enter(array, index, is_craft)

func _on_result_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.shift_pressed:
		_shift_take_result()
	else:
		Inventory.handle_result_click([], 0, Inventory.inv_craft, 2, false)

func _shift_take_result() -> void:
	while not Inventory.inv_result.is_empty():
		var res_name:  String = Inventory.inv_result["result"]
		var res_count: int    = Inventory.inv_result["count"]
		var max_stack: int    = ItemRegistry.get_stack_size(res_name)
		var can_take: bool    = not Inventory.has_cursor() or (
			Inventory.cursor["item_name"] == res_name and
			Inventory.cursor["count"] + res_count <= max_stack
		)
		if not can_take:
			break
		Inventory.handle_result_click([], 0, Inventory.inv_craft, 2, false)

func _get_shift_target(source: Array) -> Array:
	if source == Inventory.bag:
		return Inventory.hotbar
	return Inventory.bag

func _end_drag() -> void:
	_lmb_held = false
	_rmb_held = false
	Inventory.end_drag()

# ---------------------------------------------------------------------------
# CONNECT SIGNALS
# ---------------------------------------------------------------------------
func _connect_slot_signals() -> void:
	for i in bag_slots.size():
		var node := bag_slots[i] as Control
		if node == null:
			continue
		var idx := i
		node.gui_input.connect(func(ev): _on_slot_gui_input(ev, Inventory.bag, idx, false))
		node.mouse_entered.connect(func(): _on_slot_mouse_entered(Inventory.bag, idx, false))
		_add_hover(node)

	for i in hotbar_slots.size():
		var node := hotbar_slots[i] as Control
		if node == null:
			continue
		var idx := i
		node.gui_input.connect(func(ev): _on_slot_gui_input(ev, Inventory.hotbar, idx, false))
		node.mouse_entered.connect(func(): _on_slot_mouse_entered(Inventory.hotbar, idx, false))
		node.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					if not Inventory.has_cursor():
						Inventory.select_slot(idx)
		)
		_add_hover(node)

	for i in craft_slots.size():
		var node := craft_slots[i] as Control
		if node == null:
			continue
		var idx := i
		node.gui_input.connect(func(ev): _on_slot_gui_input(ev, Inventory.inv_craft, idx, true))
		node.mouse_entered.connect(func(): _on_slot_mouse_entered(Inventory.inv_craft, idx, true))
		_add_hover(node)

	if result_slot != null:
		result_slot.gui_input.connect(_on_result_gui_input)
		_add_hover(result_slot)

func _add_hover(node: Control) -> void:
	node.mouse_entered.connect(func() -> void: _set_highlight(node, true))
	node.mouse_exited.connect(func()  -> void: _set_highlight(node, false))

func _set_highlight(node: Control, hovered: bool) -> void:
	var style := node.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	style.bg_color = COLOR_SLOT_HOVER if hovered else COLOR_SLOT_NORMAL

# ---------------------------------------------------------------------------
# REFRESH
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_refresh_slots(bag_slots,    Inventory.bag)
	_refresh_slots(hotbar_slots, Inventory.hotbar)
	_refresh_slots(craft_slots,  Inventory.inv_craft)
	_refresh_craft_result()
	_update_hotbar_selection(Inventory.selected_hotbar_slot)

func _refresh_slots(nodes: Array, data: Array) -> void:
	for i in nodes.size():
		if nodes[i] == null or i >= data.size():
			continue
		_draw_slot(nodes[i], data[i])

func _refresh_craft_result() -> void:
	if result_slot == null:
		return
	if Inventory.inv_result.is_empty():
		_draw_slot(result_slot, {})
	else:
		_draw_slot(result_slot, {
			"item_name": Inventory.inv_result["result"],
			"count":     Inventory.inv_result["count"],
		})
	var style := result_slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.bg_color = COLOR_RESULT_READY if not Inventory.inv_result.is_empty() \
						else COLOR_SLOT_NORMAL

func _draw_slot(node: Control, slot: Dictionary) -> void:
	var icon:  TextureRect = node.find_child("Icon",  false, false) as TextureRect
	var count: Label       = node.find_child("Count", false, false) as Label
	if icon == null:
		return
	if slot.is_empty() or not slot.has("item_name"):
		icon.texture = null
		if count != null:
			count.text = ""
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
			style.bg_color            = COLOR_SLOT_SELECT
			style.border_color        = Color(1.0, 0.85, 0.2, 1.0)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
		else:
			style.bg_color            = COLOR_SLOT_NORMAL
			style.border_color        = Color(0, 0, 0, 0)
			style.border_width_left   = 0
			style.border_width_right  = 0
			style.border_width_top    = 0
			style.border_width_bottom = 0

func _get_target_canvas_offset() -> Vector2:
	if _canvas_layer == null or _player == null:
		return Vector2.ZERO
	var screen_pos: Vector2 = _world_to_screen(_player.global_position)
	var bg: TextureRect = get_child(0) as TextureRect
	var ui_size: Vector2 = bg.size if bg != null and bg.size != Vector2.ZERO else size
	ui_size *= ui_scale
	return screen_pos + PLAYER_UI_OFFSET + _player_velocity_offset() - Vector2(ui_size.x * 0.5, ui_size.y * 0.5)

func _get_target_control_position() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var screen_pos: Vector2 = _world_to_screen(_player.global_position)
	var bg: TextureRect = get_child(0) as TextureRect
	var ui_size: Vector2 = bg.size if bg != null and bg.size != Vector2.ZERO else size
	ui_size *= ui_scale
	return screen_pos + PLAYER_UI_OFFSET + _player_velocity_offset() - Vector2(ui_size.x * 0.5, ui_size.y * 0.5)

func _snap_canvas_to_target() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	_ui_pos = _get_target_canvas_offset() if _canvas_layer != null else _get_target_control_position()
	_ui_vel = Vector2.ZERO
	_trail_offset = Vector2.ZERO
	if _canvas_layer != null:
		_canvas_layer.offset = _ui_pos
	elif _root_control != null:
		_root_control.position = _ui_pos
	rotation = 0.0
	_ui_initialized = true

func _update_canvas_position(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return

	_update_trail_offset(delta)
	var target: Vector2 = _get_target_canvas_offset() if _canvas_layer != null else _get_target_control_position()
	if not _ui_initialized:
		_ui_pos = target
		_ui_vel = Vector2.ZERO
		_ui_initialized = true

	# Critically-damped-ish spring follow.
	var accel: Vector2 = (target - _ui_pos) * follow_stiffness
	_ui_vel += accel * delta
	_ui_vel *= pow(clamp(follow_damping, 0.0, 1.0), delta * 60.0)
	_ui_vel = _ui_vel.limit_length(max_follow_speed)
	_ui_pos += _ui_vel * delta

	if _canvas_layer != null:
		_canvas_layer.offset = _ui_pos
	elif _root_control != null:
		_root_control.position = _ui_pos

	# Small rotational sway based on follow velocity.
	var sway: float = clamp(_ui_vel.x * sway_strength * 0.001, -sway_max_radians, sway_max_radians)
	rotation = -sway

func _find_player() -> Node2D:
	var by_group: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if by_group != null:
		return by_group
	var named: Node = get_tree().root.find_child("Player", true, false)
	if named is Node2D:
		return named as Node2D
	return null

func _player_velocity_offset() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	if not ("velocity" in _player):
		return Vector2.ZERO
	return _trail_offset

func _update_trail_offset(delta: float) -> void:
	if _player == null or not ("velocity" in _player):
		_trail_offset = Vector2.ZERO
		return
	var v: Vector2 = _player.get("velocity")
	var desired: Vector2 = (-v) * trail_from_velocity_scale
	desired = desired.limit_length(trail_offset_max)
	var t: float = clamp(trail_response * delta, 0.0, 1.0)
	_trail_offset = _trail_offset.lerp(desired, t)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var cam: Camera2D = get_viewport().get_camera_2d() as Camera2D
	if cam == null:
		return world_pos
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	return (world_pos - cam.global_position) * cam.zoom + vp_size * 0.5
