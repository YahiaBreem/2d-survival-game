# ---------------------------------------------------------------------------
# INVENTORY — Autoload singleton
#
# Pure data layer. No UI code here whatsoever.
#
# AUTOLOAD ORDER:
#   BlockRegistry → ItemRegistry → CraftingRegistry → Inventory → TileSetBuilder
#
# SLOT FORMAT:
#   Filled : { "item_name": String, "count": int }
#   Empty  : {}
#
# MINECRAFT CONTROLS IMPLEMENTED:
#   LMB on slot          — pick up full stack / place full stack / swap
#   RMB on slot          — pick up half / place one
#   LMB drag (hold+move) — split picked stack evenly across dragged slots
#   RMB drag (hold+move) — place exactly 1 into each dragged slot
#   Shift+LMB            — move full stack to the other container instantly
#   Double-click LMB     — collect all matching items into cursor (up to max stack)
#
# SIGNALS:
#   inventory_changed          — any bag/hotbar slot changed
#   hotbar_slot_changed(slot)  — selected hotbar index changed (0-based internally)
#   cursor_changed             — cursor item changed
#   craft_changed              — inv_craft grid changed, result recomputed
# ---------------------------------------------------------------------------
extends Node

# ---------------------------------------------------------------------------
# SIZES
# ---------------------------------------------------------------------------
const HOTBAR_SIZE:    int = 9
const BAG_SIZE:       int = 27
const BAG_ROWS:       int = 3
const BAG_COLS:       int = 9
const INV_CRAFT_SIZE: int = 4

# ---------------------------------------------------------------------------
# STATE
# ---------------------------------------------------------------------------
var hotbar:     Array = []
var bag:        Array = []
var inv_craft:  Array = []
var inv_result: Dictionary = {}

var cursor: Dictionary = {}

var selected_hotbar_slot: int = 0

# ---------------------------------------------------------------------------
# DRAG STATE
# Used by UI to implement LMB-drag and RMB-drag across slots.
# ---------------------------------------------------------------------------
var _drag_button:       int   = -1    # MOUSE_BUTTON_LEFT or MOUSE_BUTTON_RIGHT
var _drag_origin_count: int   = 0     # count on cursor when drag started
var _drag_slots:        Array = []    # Array of { "array": Array, "index": int, "base": Dictionary }

# ---------------------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------------------
signal inventory_changed
signal hotbar_slot_changed(slot: int)
signal cursor_changed
signal craft_changed

# ---------------------------------------------------------------------------
func _ready() -> void:
	hotbar.resize(HOTBAR_SIZE)
	bag.resize(BAG_SIZE)
	inv_craft.resize(INV_CRAFT_SIZE)
	for i in HOTBAR_SIZE:    hotbar[i]    = {}
	for i in BAG_SIZE:       bag[i]       = {}
	for i in INV_CRAFT_SIZE: inv_craft[i] = {}

# ---------------------------------------------------------------------------
# HOTBAR SELECTION
# ---------------------------------------------------------------------------
func get_selected_item() -> Dictionary:
	return hotbar[selected_hotbar_slot]

func select_slot(slot: int) -> void:
	selected_hotbar_slot = clamp(slot, 0, HOTBAR_SIZE - 1)
	hotbar_slot_changed.emit(selected_hotbar_slot)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				select_slot(posmod(selected_hotbar_slot - 1, HOTBAR_SIZE))
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				select_slot(posmod(selected_hotbar_slot + 1, HOTBAR_SIZE))
	if event is InputEventKey:
		for i in HOTBAR_SIZE:
			if Input.is_action_just_pressed("hotbar_" + str(i + 1)):
				select_slot(i)

# ---------------------------------------------------------------------------
# ADD / REMOVE  (used by world — block drops, etc.)
# ---------------------------------------------------------------------------
func add_item(item_name: String, count: int = 1) -> bool:
	var max_stack: int = ItemRegistry.get_stack_size(item_name)
	if max_stack == 0:
		for _i in count:
			if not (_fill_empty(hotbar, item_name, 1, 1) or
					_fill_empty(bag,    item_name, 1, 1)):
				return false
		inventory_changed.emit()
		return true

	var remaining: int = count
	remaining = _stack_into(hotbar, item_name, remaining, max_stack)
	if remaining > 0:
		remaining = _stack_into(bag, item_name, remaining, max_stack)
	while remaining > 0:
		var batch: int = min(remaining, max_stack)
		if _fill_empty(hotbar, item_name, batch, max_stack):
			remaining -= batch
		elif _fill_empty(bag, item_name, batch, max_stack):
			remaining -= batch
		else:
			inventory_changed.emit()
			return false
	inventory_changed.emit()
	return true

func remove_item(item_name: String, count: int = 1) -> bool:
	if _remove_from(hotbar, item_name, count):
		inventory_changed.emit()
		return true
	if _remove_from(bag, item_name, count):
		inventory_changed.emit()
		return true
	return false

func has_item(item_name: String, count: int = 1) -> bool:
	var total: int = 0
	for slot in hotbar:
		if not slot.is_empty() and slot["item_name"] == item_name:
			total += slot["count"]
	for slot in bag:
		if not slot.is_empty() and slot["item_name"] == item_name:
			total += slot["count"]
	return total >= count

# ---------------------------------------------------------------------------
# CURSOR ITEM
# ---------------------------------------------------------------------------
func set_cursor(item_name: String, count: int) -> void:
	if item_name == "" or count <= 0:
		clear_cursor()
		return
	cursor = {"item_name": item_name, "count": count}
	cursor_changed.emit()

func clear_cursor() -> void:
	cursor = {}
	cursor_changed.emit()

func has_cursor() -> bool:
	return not cursor.is_empty()

# ---------------------------------------------------------------------------
# SLOT CLICK — LMB / RMB on a slot (no drag, no shift)
# ---------------------------------------------------------------------------
func handle_slot_click(array: Array, index: int,
		is_right: bool, is_craft_grid: bool = false) -> void:

	var slot: Dictionary = array[index]

	if not has_cursor():
		if slot.is_empty():
			return
		if is_right:
			var half: int = ceili(slot["count"] / 2.0)
			set_cursor(slot["item_name"], half)
			slot["count"] -= half
			if slot["count"] <= 0:
				array[index] = {}
			else:
				array[index] = slot
		else:
			set_cursor(slot["item_name"], slot["count"])
			array[index] = {}
	else:
		var cur_name:  String = cursor["item_name"]
		var cur_count: int    = cursor["count"]
		var max_stack: int    = ItemRegistry.get_stack_size(cur_name)

		if slot.is_empty():
			if is_right:
				array[index] = {"item_name": cur_name, "count": 1}
				cur_count -= 1
			else:
				var place: int = cur_count if max_stack == 0 else min(cur_count, max_stack)
				array[index] = {"item_name": cur_name, "count": place}
				cur_count -= place
			if cur_count <= 0:
				clear_cursor()
			else:
				set_cursor(cur_name, cur_count)

		elif slot["item_name"] == cur_name and max_stack != 0:
			var space: int = max_stack - int(slot["count"])
			if space > 0:
				var place: int = min(cur_count, space) if not is_right else 1
				slot["count"] += place
				cur_count     -= place
				array[index]   = slot
				if cur_count <= 0:
					clear_cursor()
				else:
					set_cursor(cur_name, cur_count)
		else:
			if not is_right:
				set_cursor(slot["item_name"], slot["count"])
				array[index] = {"item_name": cur_name, "count": cur_count}

	if is_craft_grid:
		_recompute_inv_craft()
	inventory_changed.emit()

# ---------------------------------------------------------------------------
# SHIFT-CLICK — move full stack to the other container instantly
#
# source_array : the array the clicked slot belongs to
# index        : slot index within source_array
# target_array : the array to move the stack into (bag ↔ hotbar, etc.)
# is_craft_grid: true if source or target needs craft recompute
# ---------------------------------------------------------------------------
func handle_shift_click(source_array: Array, index: int,
		target_array: Array, is_craft_grid: bool = false) -> void:

	var slot: Dictionary = source_array[index]
	if slot.is_empty():
		return

	var item_name: String = slot["item_name"]
	var count:     int    = slot["count"]
	var max_stack: int    = ItemRegistry.get_stack_size(item_name)

	# Try to stack into existing stacks first
	var remaining: int = _stack_into(target_array, item_name, count, max_stack)
	# Then fill empty slots
	while remaining > 0:
		var batch: int = min(remaining, max_stack if max_stack > 0 else remaining)
		if _fill_empty(target_array, item_name, batch, max_stack):
			remaining -= batch
		else:
			break

	# Whatever couldn't fit stays in the source slot
	if remaining <= 0:
		source_array[index] = {}
	else:
		source_array[index] = {"item_name": item_name, "count": remaining}

	if is_craft_grid:
		_recompute_inv_craft()
	inventory_changed.emit()

# ---------------------------------------------------------------------------
# DOUBLE-CLICK — collect all matching items into cursor (up to max stack)
# ---------------------------------------------------------------------------
func handle_double_click(arrays: Array) -> void:
	if not has_cursor():
		return
	var cur_name:  String = cursor["item_name"]
	var cur_count: int    = cursor["count"]
	var max_stack: int    = ItemRegistry.get_stack_size(cur_name)
	if max_stack == 0:
		return  # unstackable

	for arr in arrays:
		for i in (arr as Array).size():
			if cur_count >= max_stack:
				break
			var slot: Dictionary = arr[i]
			if slot.is_empty() or slot["item_name"] != cur_name:
				continue
			var take: int  = min(slot["count"], max_stack - cur_count)
			cur_count     += take
			slot["count"] -= take
			if slot["count"] <= 0:
				arr[i] = {}
			else:
				arr[i] = slot

	set_cursor(cur_name, cur_count)
	inventory_changed.emit()

# ---------------------------------------------------------------------------
# DRAG — LMB drag: distribute stack evenly; RMB drag: place 1 per slot
#
# Call begin_drag() when the mouse button goes down on a slot with a cursor.
# Call handle_drag_enter(array, index) as the cursor enters each new slot.
# Call end_drag() when the mouse button is released.
# ---------------------------------------------------------------------------
func begin_drag(button: int) -> void:
	if not has_cursor():
		return
	_drag_button       = button
	_drag_origin_count = cursor["count"]
	_drag_slots        = []

func handle_drag_enter(array: Array, index: int, is_craft_grid: bool = false) -> void:
	if _drag_button == -1 or not has_cursor():
		return
	var cur_name: String = cursor["item_name"]
	var slot: Dictionary = array[index]

	# Only enter slots that are empty or have the same item
	if not slot.is_empty() and slot["item_name"] != cur_name:
		return

	# Avoid duplicate entries
	for entry in _drag_slots:
		if entry["array"] == array and entry["index"] == index:
			return

	_drag_slots.append({
		"array": array,
		"index": index,
		"is_craft": is_craft_grid,
		"base": slot.duplicate(true),
	})
	_apply_drag()

func end_drag() -> void:
	# Recompute craft result if any dragged slot was a craft slot
	var touched_craft := false
	for entry in _drag_slots:
		if entry["array"] == inv_craft:
			touched_craft = true
			break
	_drag_button       = -1
	_drag_origin_count = 0
	_drag_slots        = []
	if touched_craft:
		_recompute_inv_craft()
	inventory_changed.emit()

func _apply_drag() -> void:
	if _drag_slots.is_empty() or not has_cursor():
		return

	var cur_name:  String = cursor["item_name"]
	var max_stack: int    = ItemRegistry.get_stack_size(cur_name)
	var stack_cap: int    = 1 if max_stack == 0 else max_stack

	if _drag_button == MOUSE_BUTTON_RIGHT:
		# RMB drag: add exactly 1 to each visited slot (if capacity), relative to base.
		var placed: int = 0
		for entry in _drag_slots:
			var arr: Array = entry["array"]
			var idx: int = entry["index"]
			var base: Dictionary = entry["base"]
			if placed >= _drag_origin_count:
				arr[idx] = base.duplicate(true)
				continue

			var base_count: int = 0
			if not base.is_empty():
				if base["item_name"] != cur_name:
					arr[idx] = base.duplicate(true)
					continue
				base_count = int(base["count"])
			if base_count >= stack_cap:
				arr[idx] = base.duplicate(true)
				continue

			arr[idx] = {"item_name": cur_name, "count": base_count + 1}
			placed += 1
		# Update cursor count
		var remaining: int = _drag_origin_count - placed
		if remaining <= 0:
			clear_cursor()
		else:
			cursor = {"item_name": cur_name, "count": remaining}
			cursor_changed.emit()

	elif _drag_button == MOUSE_BUTTON_LEFT:
		# LMB drag: distribute cursor stack evenly across visited slots, relative to base.
		var n: int = _drag_slots.size()
		var per_slot: int = _drag_origin_count / n
		var leftover: int = _drag_origin_count % n
		var total_placed: int = 0
		for i in _drag_slots.size():
			var entry: Dictionary = _drag_slots[i]
			var arr: Array = entry["array"]
			var idx: int = entry["index"]
			var base: Dictionary = entry["base"]

			var base_count: int = 0
			if not base.is_empty():
				if base["item_name"] != cur_name:
					arr[idx] = base.duplicate(true)
					continue
				base_count = int(base["count"])

			var add: int = per_slot + (1 if i < leftover else 0)
			var space: int = max(0, stack_cap - base_count)
			var place: int = min(add, space)
			if place <= 0:
				arr[idx] = base.duplicate(true)
				continue

			arr[idx] = {"item_name": cur_name, "count": base_count + place}
			total_placed += place

		var remaining: int = _drag_origin_count - total_placed
		if remaining <= 0:
			clear_cursor()
		else:
			cursor = {"item_name": cur_name, "count": remaining}
			cursor_changed.emit()

	# Recompute craft result if any dragged slot belongs to inv_craft
	var touched_craft := false
	for entry in _drag_slots:
		if entry["array"] == inv_craft:
			touched_craft = true
			break
	if touched_craft:
		_recompute_inv_craft()
	inventory_changed.emit()

# ---------------------------------------------------------------------------
# RESULT SLOT CLICK
# ---------------------------------------------------------------------------
func handle_result_click(result_array: Array, result_index: int,
		craft_array: Array, craft_size: int, is_right: bool = false) -> void:

	if inv_result.is_empty():
		return
	if is_right:
		return

	var res_name:  String = inv_result["result"]
	var res_count: int    = inv_result["count"]
	var max_stack: int    = ItemRegistry.get_stack_size(res_name)

	var can_take: bool = false
	if not has_cursor():
		can_take = true
	elif cursor["item_name"] == res_name and max_stack != 0:
		can_take = cursor["count"] + res_count <= max_stack

	if not can_take:
		return

	for i in craft_array.size():
		if craft_array[i].is_empty():
			continue
		craft_array[i]["count"] -= 1
		if craft_array[i]["count"] <= 0:
			craft_array[i] = {}

	if not has_cursor():
		set_cursor(res_name, res_count)
	else:
		set_cursor(cursor["item_name"], cursor["count"] + res_count)

	_recompute_inv_craft()
	inventory_changed.emit()

# ---------------------------------------------------------------------------
# CRAFTING GRID
# ---------------------------------------------------------------------------
func _recompute_inv_craft() -> void:
	var grid_items: Array = []
	for slot in inv_craft:
		grid_items.append("" if slot.is_empty() else slot["item_name"])
	inv_result = CraftingRegistry.find_recipe(grid_items, 2)
	craft_changed.emit()

func recompute_craft_result(grid: Array, grid_size: int) -> Dictionary:
	return CraftingRegistry.find_recipe(grid, grid_size)

# ---------------------------------------------------------------------------
# DROP CURSOR
# ---------------------------------------------------------------------------
func drop_cursor_to_inventory() -> void:
	if not has_cursor():
		return
	var name:  String = cursor["item_name"]
	var count: int    = cursor["count"]
	clear_cursor()
	if not add_item(name, count):
		push_warning("Inventory full — cursor item lost: %s x%d" % [name, count])

# ---------------------------------------------------------------------------
# RETURN CRAFT GRID TO INVENTORY
# ---------------------------------------------------------------------------
func return_craft_grid(grid: Array) -> void:
	for i in grid.size():
		if grid[i].is_empty():
			continue
		add_item(grid[i]["item_name"], grid[i]["count"])
		grid[i] = {}
	inventory_changed.emit()

# ---------------------------------------------------------------------------
# INTERNAL HELPERS
# ---------------------------------------------------------------------------
func _stack_into(arr: Array, item_name: String,
		count: int, max_stack: int) -> int:
	var remaining: int = count
	for i in arr.size():
		if remaining <= 0:
			break
		var slot: Dictionary = arr[i]
		if slot.is_empty() or slot["item_name"] != item_name:
			continue
		if slot["count"] >= max_stack:
			continue
		var space: int = max_stack - int(slot["count"])
		var add:   int = min(remaining, space)
		slot["count"] += add
		arr[i]         = slot
		remaining      -= add
	return remaining

func _fill_empty(arr: Array, item_name: String,
		count: int, _max_stack: int) -> bool:
	for i in arr.size():
		if arr[i].is_empty():
			arr[i] = {"item_name": item_name, "count": count}
			return true
	return false

func _remove_from(arr: Array, item_name: String, count: int) -> bool:
	for i in arr.size():
		var slot: Dictionary = arr[i]
		if slot.is_empty() or slot["item_name"] != item_name:
			continue
		slot["count"] -= count
		if slot["count"] <= 0:
			arr[i] = {}
		else:
			arr[i] = slot
		return true
	return false

func count_item(item_name: String) -> int:
	var total: int = 0
	for slot in hotbar:
		if not slot.is_empty() and slot["item_name"] == item_name:
			total += slot["count"]
	for slot in bag:
		if not slot.is_empty() and slot["item_name"] == item_name:
			total += slot["count"]
	return total
