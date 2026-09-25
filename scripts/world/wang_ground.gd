class_name WangGround
extends RefCounted

# Draws ground from PixelLab Wang tilesets (tools/build_art.py). A map is a grid of
# corner terrains; every 16-unit cell looks at its four corners and takes the atlas
# cell whose corners match. Each tileset pairs grass (lower) with one terrain (upper).
const CELL := 16
const GRASS := 0

static var _cache := {}


static func tileset(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var info := {}
	var tex := load("res://assets/tilesets/%s.png" % id) as Texture2D
	var file := FileAccess.open("res://assets/tilesets/%s.json" % id, FileAccess.READ)
	if tex and file:
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		info = {"texture": tex, "tile": int(data["tile"]), "cells": data["cells"]}
	_cache[id] = info
	return info


# terrains: terrain id -> tileset base name without the season ("tiles_grass_cliff").
# corners: PackedInt32Array of (w + 1) * (h + 1) terrain ids, row by row.
static func draw(canvas: CanvasItem, origin: Vector2, w: int, h: int, corners: PackedInt32Array,
		terrains: Dictionary, season: String) -> void:
	var grass := tileset("%s_%s" % [terrains.values()[0], season])
	for y in h:
		for x in w:
			var c := [corners[y * (w + 1) + x], corners[y * (w + 1) + x + 1],
				corners[(y + 1) * (w + 1) + x], corners[(y + 1) * (w + 1) + x + 1]]
			# The first non-grass corner picks the tileset; other terrains fall back to grass.
			var terrain := GRASS
			for t in c:
				if t != GRASS:
					terrain = t
					break
			var info := grass if terrain == GRASS else tileset("%s_%s" % [terrains[terrain], season])
			if info.is_empty():
				continue
			var key := ""
			for t in c:
				key += "1" if t == terrain and terrain != GRASS else "0"
			var index := int(info["cells"].get(key, info["cells"]["0000"]))
			var size: int = info["tile"]
			canvas.draw_texture_rect_region(info["texture"],
				Rect2(origin + Vector2(x, y) * CELL, Vector2(CELL, CELL)),
				Rect2((index % 4) * size, (index / 4) * size, size, size))


static func single(id: String) -> Texture2D:
	var key := "single/" + id
	if not _cache.has(key):
		_cache[key] = load("res://assets/tilesets/single/%s.png" % id) as Texture2D
	return _cache[key]
