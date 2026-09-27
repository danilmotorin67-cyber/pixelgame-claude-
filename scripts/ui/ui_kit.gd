class_name UiKit
extends RefCounted

# The interface kit: the Tiny5 pixel font (Cyrillic, 8 px, SIL OFL) and the PixelLab frames and
# HUD icons (tools/build_ui.py). theme() styles every Control in the game from the root window.
const INK := Color("#121a26")
const PAPER := Color("#eadcb8")
const GOLD := Color("#ffe9a8")
const BRASS := Color("#b08f6c")
const MUTED := Color("#9a9ca3")
const FONT_PATH := "res://assets/fonts/Tiny5.ttf"

static var _font: FontFile
static var _boxes := {}
static var _icons := {}
static var _meta := {}


# Tiny5 is drawn on its own 8-px grid: no smoothing, and any size is snapped to a whole multiple
# of 8 (9 and 10 read as 8, titles of 12 and more as 16).
static func font() -> Font:
	if _font == null:
		_font = (load(FONT_PATH) as FontFile).duplicate() as FontFile
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.fixed_size = 8
		_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return _font


static func _frames() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists("res://assets/ui/frames.json"):
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/frames.json"))
	return _meta


static func has_box(name: String) -> bool:
	return _frames().has(name)


# A frame by name as a StyleBox; a flat ink panel with a brass line when the art is missing.
static func box(name: String) -> StyleBox:
	if not _boxes.has(name):
		var m: Dictionary = _frames().get(name, {})
		var path := "res://assets/ui/frames/%s.png" % name
		if not m.is_empty() and ResourceLoader.exists(path):
			_boxes[name] = PixelFrame.make(load(path), int(m["margin"]), float(m.get("pad", 2)), bool(m.get("tile", false)))
		else:
			var flat := StyleBoxFlat.new()
			flat.bg_color = INK
			flat.border_color = BRASS
			flat.set_border_width_all(1)
			flat.set_content_margin_all(4)
			_boxes[name] = flat
	return _boxes[name]


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://assets/ui/icons/%s.png" % name
		_icons[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[name]


# Draws a HUD icon (32 px art) into a 16-unit cell; false when the icon is missing.
static func draw_icon(canvas: CanvasItem, name: String, at: Vector2, size := 16.0, tint := Color.WHITE) -> bool:
	var tex := icon(name)
	if tex == null:
		return false
	canvas.draw_texture_rect(tex, Rect2(at, Vector2(size, size)), false, tint)
	return true


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 8
	for type in ["Panel", "PanelContainer"]:
		t.set_stylebox("panel", type, box("panel"))
	t.set_color("font_color", "Label", PAPER)
	t.set_constant("line_spacing", "Label", 1)
	var pressed := "button_pressed" if has_box("button_pressed") else "inset"
	t.set_stylebox("normal", "Button", box("button") if has_box("button") else box("panel"))
	t.set_stylebox("hover", "Button", box("button_hover") if has_box("button_hover") else box("tooltip"))
	t.set_stylebox("pressed", "Button", box(pressed))
	t.set_stylebox("disabled", "Button", box("inset"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "ItemList", box("inset"))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	var picked := StyleBoxFlat.new()
	picked.bg_color = Color(0.69, 0.56, 0.42, 0.35)
	t.set_stylebox("selected", "ItemList", picked)
	t.set_stylebox("selected_focus", "ItemList", picked)
	t.set_stylebox("hovered", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", PAPER)
	t.set_color("font_selected_color", "ItemList", GOLD)
	t.set_constant("v_separation", "ItemList", 1)
	t.set_stylebox("normal", "LineEdit", box("inset"))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_stylebox("panel", "TooltipPanel", box("tooltip"))
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_stylebox("background", "ProgressBar", box("inset"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#e9a64a")
	t.set_stylebox("fill", "ProgressBar", fill)
	return t


# Merges the kit into the engine's default theme (Controls under a CanvasLayer do not inherit the
# window's theme) and sets the fallback font for custom-drawn text.
static func install(_tree: SceneTree) -> void:
	var base := ThemeDB.get_default_theme()
	base.merge_with(theme())
	base.default_font = font()
	base.default_font_size = 8
	ThemeDB.fallback_font = font()
	ThemeDB.fallback_font_size = 8
