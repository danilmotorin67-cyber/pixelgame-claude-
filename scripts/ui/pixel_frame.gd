class_name PixelFrame
extends StyleBox

# A PixelLab frame as a nine-patch drawn at art density: the interface is laid out in 480×270 units
# and shown ×2, so one texel of the frame is drawn as half a unit (one screen pixel), like the icons.
var texture: Texture2D
var margin := 8
var tile := false


static func make(tex: Texture2D, texels: int, pad: float, tiled := false) -> PixelFrame:
	var box := PixelFrame.new()
	box.texture = tex
	box.margin = texels
	box.tile = tiled
	var inner := float(texels) * Screen.ART_SCALE + pad
	box.content_margin_left = inner
	box.content_margin_right = inner
	box.content_margin_top = inner
	box.content_margin_bottom = inner
	return box


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if texture == null:
		return
	var s := Screen.ART_SCALE
	var mode := RenderingServer.NINE_PATCH_TILE_FIT if tile else RenderingServer.NINE_PATCH_STRETCH
	var corner := Vector2(margin, margin)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, Vector2(s, s), 0.0, rect.position))
	RenderingServer.canvas_item_add_nine_patch(to_canvas_item, Rect2(Vector2.ZERO, (rect.size / s).round()), Rect2(),
		texture.get_rid(), corner, corner, mode, mode)
	RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
