# ---------------------------------------------------------------------------
# DEBUG MENU
#
# Shows a toggleable overlay with four tabs:
#   Items | Blocks | Recipes | Trees
#
# SETUP:
#   1. Create a CanvasLayer node in your main scene, set Layer = 100
#   2. Attach this script to it
#   3. Press F3 in-game to toggle the menu
#   4. Click the tab buttons to switch sections
#
# The CanvasLayer needs NO child nodes — this script builds everything at runtime.
# ---------------------------------------------------------------------------
extends CanvasLayer

const TOGGLE_KEY:   Key    = KEY_F3
const PRINT_KEY:    Key    = KEY_P
const BG_COLOR:     Color  = Color(0.05, 0.05, 0.08, 0.92)
const HEADER_COLOR: Color  = Color(0.15, 0.15, 0.22, 1.0)
const TAB_ACTIVE:   Color  = Color(0.25, 0.55, 1.00, 1.0)
const TAB_INACTIVE: Color  = Color(0.12, 0.12, 0.18, 1.0)
const TEXT_COLOR:   Color  = Color(0.90, 0.90, 0.90, 1.0)
const DIM_COLOR:    Color  = Color(0.55, 0.55, 0.60, 1.0)
const ACCENT_COLOR: Color  = Color(0.30, 0.80, 0.50, 1.0)

const FONT_SIZE_TITLE: int = 15
const FONT_SIZE_BODY:  int = 13
const FONT_SIZE_SMALL: int = 11

# Tab indices
const TAB_ITEMS:   int = 0
const TAB_BLOCKS:  int = 1
const TAB_RECIPES: int = 2
const TAB_TREES:   int = 3
const TAB_NAMES:   Array = ["Items", "Blocks", "Recipes", "Trees"]

var _visible:      bool = false
var _active_tab:   int  = TAB_ITEMS
var _scroll:       int  = 0        # line scroll offset within a tab
var _lines:        Array[String] = []  # current tab's display lines

# UI nodes (built in _ready)
var _root:         PanelContainer
var _tab_buttons:  Array[Button] = []
var _count_label:  Label
var _scroll_label: Label
var _content:      RichTextLabel
var _search_edit:  LineEdit
var _search_term:  String = ""

# ---------------------------------------------------------------------------
func _ready() -> void:
	layer = 100
	_build_ui()
	_root.visible = false

# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == TOGGLE_KEY:
			_toggle()
			get_viewport().set_input_as_handled()
			return

	if not _visible:
		return

	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_ESCAPE:
				_toggle()
			KEY_UP:
				_scroll = max(0, _scroll - 3)
				_refresh_content()
			KEY_DOWN:
				_scroll += 3
				_refresh_content()
			KEY_PAGEUP:
				_scroll = max(0, _scroll - 20)
				_refresh_content()
			KEY_PAGEDOWN:
				_scroll += 20
				_refresh_content()
			KEY_P:
				_print_current_tab()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# BUILD UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_stylebox_override("panel", _make_stylebox(BG_COLOR))
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_root.add_child(vbox)

	# ── Header ──
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _make_stylebox(HEADER_COLOR))
	header.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(header)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	header.add_child(hrow)

	var title := Label.new()
	title.text = "  DEBUG REGISTRY"
	title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(200, 0)
	hrow.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(spacer)

	# Search
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search..."
	_search_edit.custom_minimum_size = Vector2(180, 0)
	_search_edit.text_changed.connect(_on_search_changed)
	hrow.add_child(_search_edit)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	_count_label.add_theme_color_override("font_color", DIM_COLOR)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.custom_minimum_size = Vector2(120, 0)
	hrow.add_child(_count_label)

	var print_btn := Button.new()
	print_btn.text = "  Print Log  "
	print_btn.pressed.connect(_print_current_tab)
	hrow.add_child(print_btn)

	var close_btn := Button.new()
	close_btn.text = "  ✕  "
	close_btn.pressed.connect(_toggle)
	hrow.add_child(close_btn)

	# ── Tab bar ──
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 2)
	tab_bar.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(tab_bar)

	for i in TAB_NAMES.size():
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
		var tab_idx := i
		btn.pressed.connect(func(): _switch_tab(tab_idx))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	# ── Content ──
	_content = RichTextLabel.new()
	_content.bbcode_enabled  = true
	_content.scroll_active   = true
	_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_font_size_override("normal_font_size", FONT_SIZE_BODY)
	_content.add_theme_font_size_override("mono_font_size",   FONT_SIZE_BODY)
	_content.add_theme_color_override("default_color", TEXT_COLOR)
	vbox.add_child(_content)

	# ── Footer ──
	var footer := Label.new()
	footer.text = "  F3 toggle  ·  ↑↓ / PgUp PgDn scroll  ·  P print log  ·  ESC close"
	footer.add_theme_font_size_override("font_size", FONT_SIZE_SMALL)
	footer.add_theme_color_override("font_color", DIM_COLOR)
	footer.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(footer)

	_update_tab_style()

# ---------------------------------------------------------------------------
func _toggle() -> void:
	_visible = not _visible
	_root.visible = _visible
	if _visible:
		_scroll = 0
		_search_term = ""
		if _search_edit != null:
			_search_edit.text = ""
		_refresh_content()

func _switch_tab(idx: int) -> void:
	_active_tab  = idx
	_scroll      = 0
	_search_term = ""
	if _search_edit != null:
		_search_edit.text = ""
	_update_tab_style()
	_refresh_content()

func _on_search_changed(new_text: String) -> void:
	_search_term = new_text.to_lower()
	_scroll      = 0
	_refresh_content()

func _update_tab_style() -> void:
	for i in _tab_buttons.size():
		var btn: Button = _tab_buttons[i]
		var color: Color = TAB_ACTIVE if i == _active_tab else TAB_INACTIVE
		btn.add_theme_stylebox_override("normal", _make_stylebox(color))
		btn.add_theme_stylebox_override("hover",  _make_stylebox(color.lightened(0.1)))

# ---------------------------------------------------------------------------
# CONTENT BUILDERS
# ---------------------------------------------------------------------------
func _refresh_content() -> void:
	match _active_tab:
		TAB_ITEMS:   _build_items()
		TAB_BLOCKS:  _build_blocks()
		TAB_RECIPES: _build_recipes()
		TAB_TREES:   _build_trees()

func _build_items() -> void:
	var lines: Array[String] = []
	var items: Dictionary = ItemRegistry.ITEMS

	# Group by type
	var by_type: Dictionary = {}
	for iname in items.keys():
		if _search_term != "" and not (iname as String).to_lower().contains(_search_term):
			continue
		var itype: String = items[iname].get("type", "unknown")
		if not by_type.has(itype):
			by_type[itype] = []
		by_type[itype].append(iname)

	var total: int = 0
	for itype in by_type.keys():
		var group: Array = by_type[itype]
		group.sort()
		lines.append("[color=#5090ff][b]%s[/b][/color]  [color=#555566](%d)[/color]" % [itype.to_upper(), group.size()])
		for iname in group:
			var d: Dictionary = items[iname]
			var tags: Array   = d.get("tags", [])
			var fuel: float   = d.get("fuel", 0.0)
			var food: int     = d.get("food", 0)
			var stack: int    = d.get("stack", 64)
			var extras: String = ""
			if tags.size() > 0:
				extras += "  [color=#448866]#" + "  #".join(tags) + "[/color]"
			if fuel > 0:
				extras += "  [color=#cc8833]fuel:%.0fs[/color]" % fuel
			if food > 0:
				extras += "  [color=#33cc66]food:%d[/color]" % food
			if stack == 0:
				extras += "  [color=#aa5555]unstackable[/color]"
			lines.append("  [color=#bbbbcc]%s[/color]%s" % [iname, extras])
			total += 1
		lines.append("")

	_set_content(lines, total, "items")

func _build_blocks() -> void:
	var lines: Array[String] = []
	var blocks: Dictionary = BlockRegistry.BLOCKS
	var names: Array = blocks.keys()
	names.sort()

	var shown: int = 0
	for bname in names:
		if _search_term != "" and not (bname as String).to_lower().contains(_search_term):
			continue
		var d: Dictionary   = blocks[bname]
		var hardness: float = d.get("hardness", 0.0)
		var solid: bool     = d.get("solid", true)
		var tool            = d.get("tool", 0)
		var drop            = d.get("drop", bname)
		var flags: String   = ""
		if d.get("luminous", 0) > 0:
			flags += "  [color=#ffee44]✦ light:%d[/color]" % d.get("luminous", 0)
		if d.get("flammable", false):
			flags += "  [color=#ff6633]✦ flammable[/color]"
		if d.get("physical", false):
			flags += "  [color=#aa88ff]✦ falls[/color]"
		if d.get("contact_damage", 0) > 0:
			flags += "  [color=#ff4444]✦ dmg:%d[/color]" % d.get("contact_damage", 0)
		if not solid:
			flags += "  [color=#555577]passable[/color]"

		var tool_str: String = "hand"
		if tool is Array and tool.size() >= 2:
			tool_str = "%s t%d+" % [tool[0], tool[1]]
		elif tool is int and tool > 0:
			tool_str = "any tool"

		lines.append(
			"[color=#bbbbcc]%s[/color]  [color=#555566]hard:%.1f  tool:%s[/color]%s" \
			% [bname, hardness, tool_str, flags]
		)
		shown += 1

	_set_content(lines, shown, "blocks")

func _build_recipes() -> void:
	var lines: Array[String] = []
	var shown: int = 0

	lines.append("[color=#5090ff][b]SHAPED  (%d)[/b][/color]" % CraftingRegistry.SHAPED_RECIPES.size())
	for recipe in CraftingRegistry.SHAPED_RECIPES:
		var result: String  = recipe.get("result", "?")
		var count: int      = recipe.get("count", 1)
		var pattern: Array  = recipe.get("pattern", [])
		var keys: Dictionary= recipe.get("keys", {})
		var grid: int       = recipe.get("grid", 0)
		var display: String = result if count == 1 else "%s ×%d" % [result, count]
		if _search_term != "" and not display.to_lower().contains(_search_term):
			var skip: bool = true
			for v in keys.values():
				if (v as String).to_lower().contains(_search_term):
					skip = false
					break
			if skip:
				continue
		var grid_str: String = "2×2" if grid == 2 else ("3×3" if grid == 3 else "any")
		var key_parts: Array[String] = []
		for k in keys.keys():
			key_parts.append("%s→%s" % [k, keys[k]])
		var key_list: String = "  ".join(key_parts)
		lines.append("  [color=#88ddaa]→ %s[/color]  [color=#555566]%s  |  %s[/color]" % [display, grid_str, key_list])
		for row in pattern:
			lines.append("    [color=#334455][%s][/color]" % row)
		lines.append("")
		shown += 1

	lines.append("[color=#5090ff][b]SHAPELESS  (%d)[/b][/color]" % CraftingRegistry.SHAPELESS_RECIPES.size())
	for recipe in CraftingRegistry.SHAPELESS_RECIPES:
		var result: String       = recipe.get("result", "?")
		var count: int           = recipe.get("count", 1)
		var ings: Dictionary     = recipe.get("ingredients", {})
		var display: String      = result if count == 1 else "%s ×%d" % [result, count]
		if _search_term != "" and not display.to_lower().contains(_search_term):
			var skip: bool = true
			for k in ings.keys():
				if (k as String).to_lower().contains(_search_term):
					skip = false
					break
			if skip:
				continue
		var ing_parts: Array[String] = []
		for k in ings.keys():
			ing_parts.append("%s×%d" % [k, ings[k]])
		var ing_str: String = "  ".join(ing_parts)
		lines.append("  [color=#88ddaa]→ %s[/color]  [color=#555566]%s[/color]" % [display, ing_str])
		shown += 1

	_set_content(lines, shown, "recipes")

func _build_trees() -> void:
	var lines: Array[String] = []
	var world_gen: Node = get_tree().get_first_node_in_group("world_gen") as Node
	if world_gen == null:
		_content.text = "[color=#ff5555]WorldGen node not found (group: world_gen)[/color]"
		return

	# GDScript exposes const arrays as gettable properties on the node instance
	var raw = world_gen.get("TREE_TYPES")
	if raw == null:
		_content.text = "[color=#ff5555]TREE_TYPES not accessible. Make sure world_gen.gd is attached.[/color]"
		return

	var biome_names: Dictionary = {0: "Birch Forest", 1: "Forest", 2: "Plains", 3: "Desert"}
	var shown: int = 0
	for tt in raw:
		var log: String    = tt.get("log", "?")
		var leaves: String = tt.get("leaves", "?")
		if _search_term != "" and not log.to_lower().contains(_search_term) \
				and not leaves.to_lower().contains(_search_term):
			continue
		var biomes: Array  = tt.get("biomes", [])
		var biome_parts: Array[String] = []
		for b in biomes:
			biome_parts.append(biome_names.get(b, "?"))
		var biome_str: String = "  ".join(biome_parts)
		var h_min: int = tt.get("height_min", 0)
		var h_max: int = tt.get("height_max", 0)
		var weight: int= tt.get("weight", 1)
		var crown: bool= tt.get("crown", true)
		lines.append("[color=#88ddaa][b]%s[/b][/color]" % log)
		lines.append("  leaves:  [color=#bbbbcc]%s[/color]" % leaves)
		lines.append("  biomes:  [color=#bbbbcc]%s[/color]" % biome_str)
		lines.append("  height:  [color=#bbbbcc]%d – %d[/color]" % [h_min, h_max])
		lines.append("  weight:  [color=#bbbbcc]%d[/color]" % weight)
		lines.append("  crown:   [color=#bbbbcc]%s[/color]" % ("yes" if crown else "no (column)"))
		lines.append("")
		shown += 1

	_set_content(lines, shown, "tree types")

# ---------------------------------------------------------------------------
# PRINT LOG
# ---------------------------------------------------------------------------
func _print_current_tab() -> void:
	var tab_name: String = TAB_NAMES[_active_tab]
	var filter_note: String = (" [filter: \"%s\"]" % _search_term) if _search_term != "" else ""
	print("\n=== DEBUG REGISTRY: %s%s ===" % [tab_name.to_upper(), filter_note])

	# Rebuild lines without BBCode for clean output
	var plain_lines: Array[String] = []
	match _active_tab:
		TAB_ITEMS:   plain_lines = _get_plain_items()
		TAB_BLOCKS:  plain_lines = _get_plain_blocks()
		TAB_RECIPES: plain_lines = _get_plain_recipes()
		TAB_TREES:   plain_lines = _get_plain_trees()

	for line in plain_lines:
		print(line)
	print("=== END %s (%d entries) ===\n" % [tab_name.to_upper(), plain_lines.size()])

func _strip_bbcode(text: String) -> String:
	var result: String = text
	var in_tag: bool = false
	var out: String = ""
	for ch in result:
		if ch == "[": in_tag = true
		elif ch == "]": in_tag = false
		elif not in_tag: out += ch
	return out

func _get_plain_items() -> Array[String]:
	var lines: Array[String] = []
	var items: Dictionary = ItemRegistry.ITEMS
	var by_type: Dictionary = {}
	for iname in items.keys():
		if _search_term != "" and not (iname as String).to_lower().contains(_search_term):
			continue
		var itype: String = items[iname].get("type", "unknown")
		if not by_type.has(itype): by_type[itype] = []
		by_type[itype].append(iname)
	for itype in by_type.keys():
		var group: Array = by_type[itype]
		group.sort()
		lines.append("[ %s ]" % itype.to_upper())
		for iname in group:
			var d: Dictionary = items[iname]
			var tags: Array   = d.get("tags", [])
			var fuel: float   = d.get("fuel", 0.0)
			var food: int     = d.get("food", 0)
			var extra: String = ""
			if tags.size() > 0: extra += "  tags:%s" % ",".join(tags)
			if fuel > 0: extra += "  fuel:%.0fs" % fuel
			if food > 0: extra += "  food:%d" % food
			lines.append("  %s%s" % [iname, extra])
	return lines

func _get_plain_blocks() -> Array[String]:
	var lines: Array[String] = []
	var blocks: Dictionary   = BlockRegistry.BLOCKS
	var names: Array         = blocks.keys()
	names.sort()
	for bname in names:
		if _search_term != "" and not (bname as String).to_lower().contains(_search_term):
			continue
		var d: Dictionary   = blocks[bname]
		var tool            = d.get("tool", 0)
		var tool_str: String = "hand"
		if tool is Array and tool.size() >= 2:
			tool_str = "%s t%d+" % [tool[0], tool[1]]
		var flags: Array[String] = []
		if d.get("luminous", 0) > 0:     flags.append("light:%d" % d.get("luminous", 0))
		if d.get("flammable", false):     flags.append("flammable")
		if d.get("physical", false):      flags.append("falls")
		if d.get("contact_damage",0) > 0: flags.append("dmg:%d" % d.get("contact_damage", 0))
		var flag_str: String = ("  [%s]" % ",".join(flags)) if flags.size() > 0 else ""
		lines.append("  %s  hard:%.1f  tool:%s%s" % [bname, d.get("hardness", 0.0), tool_str, flag_str])
	return lines

func _get_plain_recipes() -> Array[String]:
	var lines: Array[String] = []
	lines.append("-- SHAPED --")
	for recipe in CraftingRegistry.SHAPED_RECIPES:
		var result: String   = recipe.get("result", "?")
		var count: int       = recipe.get("count", 1)
		var keys: Dictionary = recipe.get("keys", {})
		var pattern: Array   = recipe.get("pattern", [])
		var display: String  = result if count == 1 else "%s x%d" % [result, count]
		if _search_term != "" and not display.to_lower().contains(_search_term):
			var skip: bool = true
			for v in keys.values():
				if (v as String).to_lower().contains(_search_term): skip = false
			if skip: continue
		lines.append("  -> %s" % display)
		for row in pattern: lines.append("     [%s]" % row)
	lines.append("-- SHAPELESS --")
	for recipe in CraftingRegistry.SHAPELESS_RECIPES:
		var result: String       = recipe.get("result", "?")
		var count: int           = recipe.get("count", 1)
		var ings: Dictionary     = recipe.get("ingredients", {})
		var display: String      = result if count == 1 else "%s x%d" % [result, count]
		if _search_term != "" and not display.to_lower().contains(_search_term):
			var skip: bool = true
			for k in ings.keys():
				if (k as String).to_lower().contains(_search_term): skip = false
			if skip: continue
		var ing_parts: Array[String] = []
		for k in ings.keys(): ing_parts.append("%s x%d" % [k, ings[k]])
		lines.append("  -> %s  (%s)" % [display, "  ".join(ing_parts)])
	return lines

func _get_plain_trees() -> Array[String]:
	var lines: Array[String] = []
	var world_gen: Node = get_tree().get_first_node_in_group("world_gen") as Node
	if world_gen == null: return ["WorldGen node not found"]
	var raw = world_gen.get("TREE_TYPES")
	if raw == null: return ["TREE_TYPES not accessible"]
	var biome_names: Dictionary = {0:"Birch Forest", 1:"Forest", 2:"Plains", 3:"Desert"}
	for tt in raw:
		var log: String = tt.get("log", "?")
		if _search_term != "" and not log.to_lower().contains(_search_term): continue
		var biomes: Array = tt.get("biomes", [])
		var bparts: Array[String] = []
		for b in biomes: bparts.append(biome_names.get(b, "?"))
		lines.append("  %s  leaves:%s  biomes:%s  h:%d-%d  w:%d" % [
			log, tt.get("leaves","?"), ",".join(bparts),
			tt.get("height_min",0), tt.get("height_max",0), tt.get("weight",1)
		])
	return lines

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------
func _set_content(lines: Array[String], count: int, label: String) -> void:
	if _count_label != null:
		var filter_note: String = (" · filter: \"%s\"" % _search_term) if _search_term != "" else ""
		_count_label.text = "%d %s%s" % [count, label, filter_note]

	# Apply scroll
	var start: int = min(_scroll, max(0, lines.size() - 1))
	var visible_lines: Array[String] = []
	for i in range(start, lines.size()):
		visible_lines.append(lines[i])

	_content.text = "\n".join(visible_lines)

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color           = color
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left   = 8
	sb.content_margin_right  = 8
	sb.content_margin_top    = 4
	sb.content_margin_bottom = 4
	return sb