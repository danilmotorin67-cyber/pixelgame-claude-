class_name BuildingArt
extends RefCounted

# PixelLab building sprites (tools/build_art.py): cropped to their pixels, drawn at
# Screen.ART_SCALE with the bottom centre on the owner's origin, which keeps Y sorting.
# Textures stay referenced here: a texture freed right after a draw call leaves the
# canvas pointing at a dead resource, which renders as a white box.
static var _cache := {}


# Chimney tops in each sprite's own pixels (cropped sprite), for the smoke.
const CHIMNEYS := {"house_1": [[118, 3]], "house_3": [[126, 5]], "village_03": [[87, 28]], "village_04": [[22, 38]],
	"village_05": [[82, 33]], "village_06": [[15, 26], [86, 25]], "village_09": [[90, 28]], "village_10": [[34, 6]],
	"village_12": [[24, 10]], "village_15": [[35, 5]], "village_16": [[95, 30]], "village_19": [[32, 8]],
	"village_20": [[20, 10]], "helga_hut": [[82, 8]]}


static func texture(id: String) -> Texture2D:
	if not _cache.has(id):
		_cache[id] = load("res://assets/sprites/buildings/%s.png" % id) as Texture2D
	return _cache[id]


static func draw(canvas: CanvasItem, id: String, offset := Vector2.ZERO) -> void:
	var tex := texture(id)
	if tex == null:
		return
	var size := tex.get_size() * Screen.ART_SCALE
	canvas.draw_texture_rect(tex, Rect2(offset + Vector2(-size.x / 2.0, -size.y), size), false)


# Fitted to a footprint: at most 90% of the plot's width and two tiles taller than it, centred and
# standing on its bottom edge, so the roof rises a little above the walled plot.
# Where the chimneys of a building drawn with draw() (at Screen.ART_SCALE) stand.
static func chimneys_at(id: String, offset: Vector2) -> Array:
	var tex := texture(id)
	if tex == null:
		return []
	var size := tex.get_size() * Screen.ART_SCALE
	var out: Array = []
	for c in CHIMNEYS.get(id, []):
		out.append(offset + Vector2(-size.x / 2.0, -size.y) + Vector2(float(c[0]), float(c[1])) * Screen.ART_SCALE)
	return out


# The same for a building fitted to its plot with draw_fit().
static func chimneys_fit(id: String, plot: Rect2) -> Array:
	var tex := texture(id)
	if tex == null:
		return []
	var k := minf(plot.size.x * 0.9 / tex.get_size().x, (plot.size.y + 32.0) / tex.get_size().y)
	var size := tex.get_size() * k
	var origin := Vector2(plot.get_center().x - size.x / 2.0, plot.end.y - size.y)
	var out: Array = []
	for c in CHIMNEYS.get(id, []):
		out.append(origin + Vector2(float(c[0]), float(c[1])) * k)
	return out


static func draw_fit(canvas: CanvasItem, id: String, plot: Rect2) -> bool:
	var tex := texture(id)
	if tex == null:
		return false
	var k := minf(plot.size.x * 0.9 / tex.get_size().x, (plot.size.y + 32.0) / tex.get_size().y)
	var size := tex.get_size() * k
	canvas.draw_texture_rect(tex, Rect2(Vector2(plot.get_center().x - size.x / 2.0, plot.end.y - size.y), size), false)
	return true
